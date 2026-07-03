#!/usr/bin/env bash
# `pmctl ship --parallel` / `pmctl ship status` / `pmctl ship list` -- thin
# N-lane orchestrator built on top of CC-014's pmctl worktree
# (create/list/remove/gc) and the existing pmctl dispatch run/dispatch-record
# primitives. Reuses the ship contract (CC-439) unchanged: every lane's
# dispatch brief tells the executor to run the SAME implement -> gate ->
# fix -> gate -> PR steps `/ship` already runs on the main thread for a
# single ticket (via the `pmctl ship finish` bookend in pmctl-ship.sh); this
# orchestrator only adds lane creation/tracking/notification/gc.auto
# pre-flight around N of them run in parallel. It never removes a worktree
# itself (manual-only, per CC-441 Requirement 4) and never invents a new
# worktree convention (per CC-441 Framing).

pmctl_ship_parallel_usage() {
  printf 'usage: pmctl ship --parallel <ticket-id> [<ticket-id>...] [--from <base-branch>] [--adapter <codex|claude|opencode>] [--isolation <level>] [--model <alias>] [--auto-pack|--no-auto-pack] [--cd <work_dir>]\n' >&2
  printf '       pmctl ship status [--cd <work_dir>] [--json]\n' >&2
  printf '       pmctl ship list   [--cd <work_dir>] [--json]\n' >&2
}

# _pmctl_ship_parallel_reg_dir <repo_root> <work_dir>
# Same partition CC-014's `pmctl worktree` uses (sw_project_worktree_dir) --
# ship-parallel tracking is a sibling file under it, not a new state root.
_pmctl_ship_parallel_reg_dir() {
  local repo_root="$1" work_dir="$2"
  pmctl_worktree_ensure_state_paths "$repo_root" >/dev/null 2>&1 || true
  sw_project_worktree_dir "$work_dir"
}

_pmctl_ship_parallel_tracking_file() {
  printf '%s/ship-parallel.jsonl\n' "$1"
}

# _pmctl_ship_parallel_tracking_append_inner <json_line> <tracking_file>
# Runs inside serialize_with_lock -- same locked-append primitive shape as
# pmctl_worktree_manifest_append (pmctl-worktree.sh).
_pmctl_ship_parallel_tracking_append_inner() {
  local json_line="$1" tracking_file="$2" compact
  compact="$(_sw_compact_json_line "$json_line")" || return $?
  printf '%s\n' "$compact" >> "$tracking_file"
}

# pmctl_ship_parallel_tracking_append <reg_dir> <json_line>
# The ONLY way `run` should append a new lane entry -- serialized against
# `pmctl_ship_parallel_tracking_refresh` so a concurrent status refresh's
# read-modify-write can never observe a half-written line nor silently drop
# an append that lands mid-refresh.
pmctl_ship_parallel_tracking_append() {
  local reg_dir="$1" json_line="$2" tracking_file
  mkdir -p "$reg_dir" 2>/dev/null || { printf 'pmctl ship: mkdir failed: %s\n' "$reg_dir" >&2; return 1; }
  tracking_file="$(_pmctl_ship_parallel_tracking_file "$reg_dir")"
  serialize_with_lock "$reg_dir/ship-parallel" _pmctl_ship_parallel_tracking_append_inner "$json_line" "$tracking_file"
}

# _pmctl_ship_parallel_tracking_refresh_inner <tracking_file> <lane_status_fn>
# Runs inside serialize_with_lock: re-reads the CURRENT file content (not a
# snapshot taken before acquiring the lock), recomputes each line's status,
# and writes the result back atomically (tmp + mv). This is the ONLY code
# path that should overwrite ship-parallel.jsonl wholesale -- doing the
# read+recompute+write inside one locked critical section is what makes it
# safe against a concurrent `run`'s append (pmctl_ship_parallel_tracking_append
# above), which is serialized against the SAME lock. Prints the recomputed
# content on stdout (caller captures it for --json rendering) and prints one
# human-readable line per lane to stderr, matching the un-locked version's
# prior behavior.
_pmctl_ship_parallel_tracking_refresh_inner() {
  local tracking_file="$1" json_out="$2" tmp content line updated=""
  content=""
  [[ -f "$tracking_file" ]] && content="$(cat "$tracking_file")"
  [[ -n "$content" ]] || return 0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    local ticket branch path run_id new_status
    ticket="$(jq -r '.ticket' <<<"$line")"
    branch="$(jq -r '.branch' <<<"$line")"
    path="$(jq -r '.path' <<<"$line")"
    run_id="$(jq -r '.run_id' <<<"$line")"
    new_status="$(_pmctl_ship_parallel_lane_status "$path" "$run_id")"
    line="$(jq -c --arg s "$new_status" '.status = $s' <<<"$line")"
    updated="${updated}${line}
"
    if [[ "$json_out" -eq 0 ]]; then
      printf '[%s] %-12s branch=%-20s run_id=%s\n' "$ticket" "$new_status" "$branch" "$run_id" >&2
    fi
  done <<<"$content"
  tmp="$(mktemp "$(dirname "$tracking_file")/.ship-parallel.XXXXXX")" || return 1
  printf '%s' "$updated" > "$tmp"
  mv -f "$tmp" "$tracking_file"
  printf '%s' "$updated"
}

# pmctl_ship_parallel_tracking_refresh <reg_dir> <json_out 0|1>
pmctl_ship_parallel_tracking_refresh() {
  local reg_dir="$1" json_out="$2" tracking_file
  tracking_file="$(_pmctl_ship_parallel_tracking_file "$reg_dir")"
  [[ -f "$tracking_file" ]] || return 0
  serialize_with_lock "$reg_dir/ship-parallel" _pmctl_ship_parallel_tracking_refresh_inner "$tracking_file" "$json_out"
}

# _pmctl_ship_parallel_gc_auto_save <work_dir>
# Prints "set:<value>" if git config gc.auto is currently set, "unset"
# otherwise. Never substitutes git's own runtime default (256) for an
# actually-unset key -- CC-440 spike found that bug in an earlier draft.
_pmctl_ship_parallel_gc_auto_save() {
  local work_dir="$1" value
  if value="$(git -C "$work_dir" config --get gc.auto 2>/dev/null)"; then
    printf 'set:%s\n' "$value"
  else
    printf 'unset\n'
  fi
}

# _pmctl_ship_parallel_gc_auto_restore <work_dir> <saved>
_pmctl_ship_parallel_gc_auto_restore() {
  local work_dir="$1" saved="$2"
  if [[ "$saved" == unset ]]; then
    git -C "$work_dir" config --unset gc.auto 2>/dev/null || true
  else
    git -C "$work_dir" config gc.auto "${saved#set:}" 2>/dev/null || true
  fi
}

# _pmctl_ship_parallel_gc_auto_restore_trap
# Bare-name trap target (no string interpolation of caller-controlled data)
# -- reads the work_dir/saved-value pair from global state set immediately
# before `trap` is registered in pmctl_ship_parallel_run.
_pmctl_ship_parallel_gc_auto_restore_trap() {
  _pmctl_ship_parallel_gc_auto_restore "$_PMCTL_SHIP_PARALLEL_GC_WORK_DIR" "$_PMCTL_SHIP_PARALLEL_GC_SAVED"
}

# _pmctl_ship_parallel_ticket_active <work_dir> <ticket_id>
# Same fail-fast shape as /ship Step 0's ticket-id validation: an active
# `## <ticket-id>` heading in BACKLOG.md. Checked against <work_dir> (the
# TARGET repo passed via --cd), never <repo_root> (the pm-dispatch
# installation whose scripts/lib/*.sh this orchestrator runs from) -- those
# are two different repos whenever ship-parallel operates on a project other
# than pm-dispatch itself. Full Dependencies/DECISIONS consistency judgment
# stays a per-lane, per-ticket PM-level call (each lane's dispatch brief
# tells the executor to re-run that check itself, same as a standalone
# /ship invocation would) -- the orchestrator only does the cheap,
# deterministic pre-check before spending a worktree+dispatch on an id that
# cannot possibly resolve.
_pmctl_ship_parallel_ticket_active() {
  local work_dir="$1" ticket_id="$2"
  # Delegates to the ONE shared shape+exact-heading check pmctl-ship.sh
  # defines (_pmctl_ship_id_shape_ok / _pmctl_ship_heading_exists), also
  # used by `pmctl ship prepare` -- a second, independent implementation
  # here previously drifted into a real bug: an unanchored prefix compare
  # let ticket id `CC-90` false-match an unrelated `## CC-9001 -- ...`
  # heading. One implementation, one place it can be wrong.
  if declare -F _pmctl_ship_id_shape_ok >/dev/null; then
    _pmctl_ship_id_shape_ok "$ticket_id" || return 1
  fi
  if declare -F _pmctl_ship_heading_exists >/dev/null; then
    _pmctl_ship_heading_exists "$work_dir/BACKLOG.md" "$ticket_id"
    return $?
  fi
  # pmctl-ship.sh not loaded (should not happen via cli/pmctl, which always
  # sources both) -- fail closed rather than fall back to an unsafe check.
  return 1
}

# _pmctl_ship_parallel_brief_write <repo_root> <ticket_id> <lane_work_dir> <branch> <out_path>
# Writes a dispatch brief whose instructions are /ship's own Steps 2-5
# (implement -> gate loop foreground -> PR, no auto-merge) re-targeted at the
# lane's worktree, with Step 1 (branch) dropped -- the orchestrator already
# created and checked out <branch> via `pmctl worktree create`.
_pmctl_ship_parallel_brief_write() {
  local repo_root="$1" ticket_id="$2" lane_work_dir="$3" branch="$4" out_path="$5"
  # Backticks below are literal Markdown code spans, not command substitution.
  # shellcheck disable=SC2016
  {
    printf 'schema_version: 1\n'
    printf 'working_dir: %s\n' "$lane_work_dir"
    printf 'goal: Ship %s end-to-end inside this pre-created worktree lane -- implement, gate to GO, open a PR. Do not merge.\n' "$ticket_id"
    printf 'context:\n'
    printf -- '  - This lane was created by `pmctl ship --parallel` as one of N parallel lanes. The branch `%s` is already checked out here (i.e. `pmctl ship prepare` already ran); do not create or switch branches.\n' "$branch"
    printf -- '  - The ship contract this brief reuses is defined in `commands/ship.md` (CC-439) -- read it once for the exact stop conditions and gate-loop discipline; do not re-derive them from scratch.\n'
    printf 'files:\n'
    printf -- '  - read: BACKLOG.md (section `## %s`) for Problem/Requirement/Dependencies\n' "$ticket_id"
    printf -- '  - read: commands/ship.md for the exact implement/gate/PR steps to reproduce\n'
    printf -- '  - edit: files named by the ticket'\''s own Requirement section\n'
    printf 'constraints:\n'
    printf -- '  - Re-run the ticket-id consistency check yourself (Dependencies terminal-state, DECISIONS.md conflict scan) before implementing -- the orchestrator only did the cheap active-heading check, not this.\n'
    printf -- '  - Do not run `git checkout -b` or otherwise switch branches; `%s` is already checked out.\n' "$branch"
    printf -- '  - Do not run `pmctl worktree remove` or otherwise touch worktree lifecycle -- that is manual, user-triggered, and out of this lane'\''s scope.\n'
    printf -- '  - Before running `pmctl ship finish`, `export PM_DISPATCH_STATE_ROOT=%s/.pm-dispatch-state` in this shell. `pmctl gate run`'\''s nested reviewer dispatch writes run/trace records to the out-of-repo state store; the default location resolves under `$HOME`, which is OUTSIDE this sandbox'\''s writable root (workspace-write only permits writes under this working_dir) and the write is rejected. Redirecting the state root to a path INSIDE this working_dir keeps every nested pmctl write inside the sandbox boundary. This is scoped to this one lane'\''s own dispatch tree; it does not touch the orchestrator'\''s or any other lane'\''s state.\n' "$lane_work_dir"
    printf -- '  - Gate + PR: run `pmctl ship finish %s --cd "%s"` -- it runs one gate round and, on GO, pushes and opens the PR (never merges). On NO-GO it prints the result path and exits 1: fix every finding -- high/medium/low, hard-gate and advisory -- and re-run `pmctl ship finish %s --cd "%s"`; repeat.\n' "$ticket_id" "$lane_work_dir" "$ticket_id" "$lane_work_dir"
    printf -- '  - Stop and report instead of continuing only if the ticket'\''s own premise turns out wrong, or a fix would require contradicting a DECISIONS.md constraint, or a gate round produces no new progress after Rule A'\''s 3-strike audit already ran -- same stopping rule as `/ship`, not a new one.\n'
    # Shell-quote lane_work_dir before embedding it in the generated cmd:
    # string -- a state-store path containing a space would otherwise split
    # into multiple `git -C` arguments and produce an invalid command.
    local quoted_lane_work_dir
    printf -v quoted_lane_work_dir '%q' "$lane_work_dir"
    printf 'self_verify:\n'
    printf -- '  - cmd: "git -C %s rev-parse --abbrev-ref HEAD | grep -qx %s"\n' "$quoted_lane_work_dir" "$branch"
    printf -- '  - git-status no-collateral-damage\n'
    printf 'acceptance:\n'
    printf -- '  - Gate final verdict is GO, or the run stopped at one of the explicit stopping conditions above with a stated reason\n'
    printf -- '  - PR opened when GO (report the URL); no merge performed\n'
    printf -- '  - self_verify all pass\n'
  } > "$out_path"
}

# pmctl_ship_parallel_run <repo_root> <work_dir> <ticket-id...> [--from <base>] [--isolation <level>] [--model <alias>]
pmctl_ship_parallel_run() {
  local repo_root="${1:-}" work_dir="${2:-}"
  shift 2 || true
  [[ -n "$work_dir" ]] || work_dir="$repo_root"

  # Default lane-implementation executor is `claude`, not `codex` -- distinct
  # from the gate REVIEWER inside `pmctl ship finish`, which stays `codex` on
  # purpose (independent review perspective from whatever implemented). This
  # default is overridable via --adapter so a caller can still route
  # implementation to codex/opencode per lane batch.
  #
  # Default isolation is `workspace-network`, NOT `workspace-write`: every
  # lane's brief tells the executor to call `pmctl ship finish`, which
  # dispatches its OWN nested gate-reviewer executor (`pmctl gate run
  # --executor codex`) -- that inner dispatch needs real outbound network to
  # reach the model API. Under plain `workspace-write` the outer sandbox
  # blocks that egress entirely and the nested gate call fails closed
  # (`failed to connect to websocket ... Operation not permitted`), so the
  # lane implements correctly but can never reach GO. Confirmed via a real
  # e2e run (CC-004/CC-214 mock tickets) during CC-441 development.
  local from="" isolation="workspace-network" model="" auto_pack_flag="" adapter="claude" tickets=()
  local args=("$@") i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --from) from="${args[$((i+1))]:-}"; i=$((i+2)) ;;
      --isolation) isolation="${args[$((i+1))]:-workspace-network}"; i=$((i+2)) ;;
      --model) model="${args[$((i+1))]:-}"; i=$((i+2)) ;;
      --adapter) adapter="${args[$((i+1))]:-claude}"; i=$((i+2)) ;;
      --cd) work_dir="${args[$((i+1))]:-$work_dir}"; i=$((i+2)) ;;
      --no-auto-pack) auto_pack_flag="--no-auto-pack"; i=$((i+1)) ;;
      --auto-pack) auto_pack_flag="--auto-pack"; i=$((i+1)) ;;
      -h|--help) pmctl_ship_parallel_usage; return 0 ;;
      *) tickets+=("${args[$i]}"); i=$((i+1)) ;;
    esac
  done

  if [[ "${#tickets[@]}" -eq 0 ]]; then
    printf 'pmctl ship-parallel run: at least one <ticket-id> is required\n' >&2
    pmctl_ship_parallel_usage
    return 2
  fi

  # Pre-flight validation for ALL tickets before touching any worktree -- a
  # batch with one bad id should not leave the good ids' lanes half-created.
  local t
  local -A _seen_tickets=()
  for t in "${tickets[@]}"; do
    if [[ -n "${_seen_tickets[$t]:-}" ]]; then
      printf 'pmctl ship-parallel run: %s appears more than once in this batch -- refusing before any worktree is created (a duplicate would dispatch the first occurrence, then fail the second on a worktree-slug collision, leaving a live lane with no way to cancel it from this command).\n' "$t" >&2
      return 1
    fi
    _seen_tickets[$t]=1
    if ! _pmctl_ship_parallel_ticket_active "$work_dir" "$t"; then
      printf 'pmctl ship-parallel run: %s is not an active BACKLOG.md ticket (check id/shape, or BACKLOG-ARCHIVE.md for already-terminal tickets)\n' "$t" >&2
      return 1
    fi
  done

  if ! declare -F pmctl_worktree_create >/dev/null; then
    printf 'pmctl ship-parallel run: pmctl worktree unavailable\n' >&2
    return 2
  fi

  local reg_dir
  reg_dir="$(_pmctl_ship_parallel_reg_dir "$repo_root" "$work_dir")" || {
    printf 'pmctl ship-parallel run: cannot resolve worktree registry dir from %s\n' "$work_dir" >&2
    return 1
  }
  local tracking_file
  tracking_file="$(_pmctl_ship_parallel_tracking_file "$reg_dir")"

  # Refuse to re-dispatch a ticket whose PRIOR lane is still in flight
  # (dispatched/running, not yet a terminal go/no-go/failed). Without this,
  # re-running the same ticket while its earlier dispatch's process is still
  # alive lets `pmctl worktree remove --force` (the only manual cleanup path
  # this orchestrator documents) delete the directory out from under that
  # still-running executor, then recreate a NEW worktree at the identical
  # path -- two live processes then race on the same files. Confirmed as a
  # real failure mode during CC-441's own e2e validation. The caller must
  # first confirm via `pmctl ship status` that the prior run has actually
  # terminated (or that its process is truly gone) before clearing the
  # tracking entry and retrying.
  if [[ -f "$tracking_file" ]]; then
    local line
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      local tracked_ticket tracked_status tracked_run_id tracked_path
      tracked_ticket="$(jq -r '.ticket' <<<"$line")"
      for t in "${tickets[@]}"; do
        [[ "$t" == "$tracked_ticket" ]] || continue
        tracked_status="$(jq -r '.status' <<<"$line")"
        tracked_run_id="$(jq -r '.run_id' <<<"$line")"
        tracked_path="$(jq -r '.path' <<<"$line")"
        case "$tracked_status" in
          dispatched|running)
            # Re-check live state (not just the last-cached status) before refusing.
            local live_status
            live_status="$(_pmctl_ship_parallel_lane_status "$tracked_path" "$tracked_run_id")"
            if [[ "$live_status" == dispatched || "$live_status" == running ]]; then
              # Backtick below is a literal Markdown code span, not command substitution.
              # shellcheck disable=SC2016
              printf 'pmctl ship-parallel run: %s already has an in-flight lane (run_id=%s, status=%s) -- refusing to re-dispatch. Check `pmctl ship status`; only retry after it reaches a terminal state (go/no-go/failed).\n' \
                "$t" "$tracked_run_id" "$live_status" >&2
              return 1
            fi
            ;;
        esac
      done
    done < "$tracking_file"
  fi

  # Requirement 2: gc.auto override scoped to THIS loop's own `git worktree
  # add` calls (the thing CC-440 spike flagged), restored on every exit path
  # -- success, partial failure, or interrupt -- never left at 0 nor
  # clobbered with git's runtime default of 256.
  local gc_saved
  gc_saved="$(_pmctl_ship_parallel_gc_auto_save "$work_dir")"
  git -C "$work_dir" config gc.auto 0 2>/dev/null || true
  # A caller-controlled work_dir containing a single quote would break the
  # string-interpolated trap form (`trap "... '$work_dir' ..." EXIT`) --
  # potentially executing unintended shell when the trap fires. Route
  # through global state + a bare trap function name instead: `trap` with no
  # expansion in its argument is safe regardless of what work_dir/gc_saved
  # contain.
  _PMCTL_SHIP_PARALLEL_GC_WORK_DIR="$work_dir"
  _PMCTL_SHIP_PARALLEL_GC_SAVED="$gc_saved"
  trap _pmctl_ship_parallel_gc_auto_restore_trap EXIT INT TERM

  local fail_count=0
  for t in "${tickets[@]}"; do
    local branch="feat/$t" lane_path create_out
    # `pmctl_worktree_create` prints the resolved worktree path as its LAST
    # stdout line (`git worktree add`'s own progress chatter -- "Preparing
    # worktree...", "HEAD is now at..." -- precedes it, uncaptured/
    # unsuppressed by that function). Take only the final line as the path.
    if ! create_out="$(pmctl_worktree_create "$repo_root" "$work_dir" "$branch" ${from:+--from "$from"} --name "$t")"; then
      printf '[%s] worktree create failed -- skipping this lane\n' "$t" >&2
      fail_count=$((fail_count+1))
      continue
    fi
    lane_path="$(printf '%s\n' "$create_out" | tail -1)"

    local brief_path
    brief_path="$(mktemp -p /tmp "brief-ship-parallel-$t-XXXXXX.md")" || {
      printf '[%s] mktemp failed for brief -- skipping this lane\n' "$t" >&2
      fail_count=$((fail_count+1))
      continue
    }
    chmod 0600 "$brief_path" 2>/dev/null || true
    _pmctl_ship_parallel_brief_write "$repo_root" "$t" "$lane_path" "$branch" "$brief_path"

    local dispatch_args=(--adapter "$adapter" --cd "$lane_path" --isolation "$isolation" --lifecycle detached --brief-file "$brief_path")
    [[ -n "$model" ]] && dispatch_args+=(--model "$model")
    [[ -n "$auto_pack_flag" ]] && dispatch_args+=("$auto_pack_flag")

    local run_id
    if ! run_id="$(pmctl_dispatch_run "$repo_root" "${dispatch_args[@]}")"; then
      printf '[%s] dispatch run failed -- lane worktree stays at %s for manual inspection\n' "$t" "$lane_path" >&2
      fail_count=$((fail_count+1))
      continue
    fi
    run_id="$(printf '%s\n' "$run_id" | tail -1 | tr -d '[:space:]')"

    local created_ts json_line
    created_ts="$(date -Is 2>/dev/null || date)"
    json_line="$(printf '{"ticket":%s,"branch":%s,"path":%s,"run_id":%s,"status":%s,"created_ts":%s}' \
      "$(jq -Rn --arg v "$t" '$v')" \
      "$(jq -Rn --arg v "$branch" '$v')" \
      "$(jq -Rn --arg v "$lane_path" '$v')" \
      "$(jq -Rn --arg v "$run_id" '$v')" \
      "$(jq -Rn --arg v "dispatched" '$v')" \
      "$(jq -Rn --arg v "$created_ts" '$v')")"
    if ! pmctl_ship_parallel_tracking_append "$reg_dir" "$json_line"; then
      printf '[%s] tracking write failed -- lane dispatched (run_id=%s) but not tracked; check %s\n' "$t" "$run_id" "$tracking_file" >&2
    fi

    printf '[%s] dispatched: run_id=%s lane=%s\n' "$t" "$run_id" "$lane_path"
  done

  if [[ "$fail_count" -gt 0 ]]; then
    printf 'ship-parallel run: %d/%d lane(s) failed to dispatch; see above\n' "$fail_count" "${#tickets[@]}" >&2
    return 1
  fi
  return 0
}

# _pmctl_ship_parallel_lane_status <lane_path> <run_id>
# Prints one of: dispatched | running | go | no-go | partial | failed
#
# GO detection reads ONLY `pmctl ship finish`'s own structured marker file
# (.pm-dispatch-ship-finish.json, written INSIDE lane_path only on a
# confirmed GO+PR) -- never the dispatched executor's free-text summary.
# Grepping DISPATCH_RECORD_SUMMARY for "Final: GO" was the original
# heuristic; a real CC-441 e2e run (claude executor) reported the verdict as
# prose ("Gate 通過（**GO**）") instead of that literal string, producing a
# false "no-go" for a lane that had actually reached GO and opened a PR --
# fixed by adding the marker as a first check, but an EARLIER version of
# that fix still fell back to the same free-text grep when the marker was
# ABSENT, which is unsafe in the other direction: an executor whose own
# narration happens to contain the string "Final: GO" (echoing the gate
# result verbatim, translating it, or the model simply mentioning it) could
# be reported as `go` even though `pmctl ship finish` never actually ran to
# completion and never wrote the marker -- exactly the "reported ready
# without proof" failure mode critic/architecture-reviewer/risk-reviewer
# converged on in gate round 6. No marker file == not go, full stop; the
# free-text branch below only distinguishes no-go/failed/running, never go.
_pmctl_ship_parallel_lane_status() {
  local lane_path="$1" run_id="$2"
  if [[ -f "$lane_path/.pm-dispatch-ship-finish.json" ]]; then
    # `pmctl ship finish` also writes this marker with verdict=PUSHED_NO_PR
    # when the gate passed and the branch pushed but `gh` was unavailable to
    # open the PR -- that is NOT a complete "go" (ship contract = gate GO
    # *and* PR opened), so only the literal GO verdict maps to status=go.
    local marker_verdict
    marker_verdict="$(jq -r '.verdict // ""' "$lane_path/.pm-dispatch-ship-finish.json" 2>/dev/null)"
    case "$marker_verdict" in
      GO) printf 'go\n' ;;
      # Distinct from plain no-go: the branch IS live on origin (a real,
      # recoverable remote side effect) even though no PR exists yet --
      # operationally different from "gate never passed, nothing pushed"
      # and needs its own recovery action (open the PR manually / retry),
      # not the ship contract's default "fix findings and re-run".
      PUSHED_NO_PR|PUSHED_PR_FAILED) printf 'partial\n' ;;
      *) printf 'no-go\n' ;;
    esac
    return 0
  fi
  if ! declare -F dispatch_record_read_state >/dev/null; then
    printf 'dispatched\n'
    return 0
  fi
  if ! dispatch_record_read_state "$lane_path" "$run_id" >/dev/null 2>&1; then
    printf 'running\n'
    return 0
  fi
  case "$DISPATCH_RECORD_STATE" in
    # `ok` here means the DISPATCH (the executor process) exited cleanly --
    # it says nothing about whether the SHIP contract (gate GO + PR opened)
    # was satisfied. Without the marker checked above, that is never
    # provable from this record alone, so it is always no-go, regardless of
    # what the executor's own free-text summary claims.
    ok) printf 'no-go\n' ;;
    partial) printf 'no-go\n' ;;
    failed) printf 'failed\n' ;;
    *) printf 'running\n' ;;
  esac
}

# pmctl_ship_parallel_status <repo_root> <work_dir> [--json]
# Refreshes tracked lane statuses in place (read-current-terminal-state, not
# a live push notification -- each invocation independently reflects each
# lane's latest known state without waiting on the others, per Requirement 3)
# and prints them.
pmctl_ship_parallel_status() {
  local repo_root="${1:-}" work_dir="${2:-}" json_out=0
  shift 2 || true
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  local args=("$@") i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --cd) work_dir="${args[$((i+1))]:-$work_dir}"; i=$((i+2)) ;;
      --json) json_out=1; i=$((i+1)) ;;
      -h|--help) pmctl_ship_parallel_usage; return 0 ;;
      *) i=$((i+1)) ;;
    esac
  done

  local reg_dir tracking_file
  reg_dir="$(_pmctl_ship_parallel_reg_dir "$repo_root" "$work_dir")" || true
  tracking_file="$(_pmctl_ship_parallel_tracking_file "$reg_dir")"
  [[ -f "$tracking_file" ]] || { [[ "$json_out" -eq 1 ]] && printf '[]\n' || printf 'No tracked ship-parallel lanes.\n'; return 0; }

  pmctl_worktree_ensure_writer "$repo_root" || return $?

  local updated
  updated="$(pmctl_ship_parallel_tracking_refresh "$reg_dir" "$json_out")"

  if [[ "$json_out" -eq 1 ]]; then
    printf '%s' "$updated" | jq -s -c '[.[] | select(. != null)]'
  fi
}

# pmctl_ship_parallel_list <repo_root> <work_dir> [--json]
# Requirement 4: the "GO but not yet merged" tracking list. Refreshes status
# first (same read as `status`), then filters to status == go.
pmctl_ship_parallel_list() {
  local repo_root="${1:-}" work_dir="${2:-}"
  shift 2 || true
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  local json_out=0 args=("$@") i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --cd) work_dir="${args[$((i+1))]:-$work_dir}"; i=$((i+2)) ;;
      --json) json_out=1; i=$((i+1)) ;;
      -h|--help) pmctl_ship_parallel_usage; return 0 ;;
      *) i=$((i+1)) ;;
    esac
  done

  local all go_only
  all="$(pmctl_ship_parallel_status "$repo_root" "$work_dir" --json 2>/dev/null)" || true
  [[ -n "$all" ]] || all="[]"
  go_only="$(jq -c '[.[] | select(.status == "go")]' <<<"$all")"

  if [[ "$json_out" -eq 1 ]]; then
    printf '%s\n' "$go_only"
    return 0
  fi

  if [[ "$(jq 'length' <<<"$go_only")" -eq 0 ]]; then
    printf 'No lanes are GO-but-unmerged.\n'
    return 0
  fi
  printf '%-20s %-30s %s\n' TICKET BRANCH PR_URL
  jq -r '.[] | [.ticket, .branch, .path] | @tsv' <<<"$go_only" | while IFS=$'\t' read -r ticket branch path; do
    local pr_url
    pr_url="$(jq -r '.pr_url // "?"' "$path/.pm-dispatch-ship-finish.json" 2>/dev/null)"
    printf '%-20s %-30s %s\n' "$ticket" "$branch" "${pr_url:-?}"
  done
}
