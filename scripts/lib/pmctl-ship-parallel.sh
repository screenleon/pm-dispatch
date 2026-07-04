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

# Lane tracking (reg_dir/tracking-file/append/refresh, ship-lanes.jsonl) and
# per-lane status resolution now live in pmctl-ship.sh as
# _pmctl_ship_lanes_* / _pmctl_ship_lane_status -- CC-442/CC-443 unified them
# because a `--worktree` lane created outside `--parallel` (via the single-
# ticket `pmctl ship <id> --worktree`/`--adapter` entry, pmctl_ship_run) needs
# the exact same tracking file `status`/`list` below already read; keeping a
# second, --parallel-only copy would silently miss those lanes again.

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
  # Same option-shaped/missing-operand rejection as pmctl_ship_run (CC-443
  # gate finding) -- without it `--adapter --no-auto-pack` silently takes
  # `--no-auto-pack` as the adapter NAME before any ticket is even validated.
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --from)
        [[ $((i+1)) -lt ${#args[@]} && "${args[$((i+1))]}" != -* ]] || { printf 'pmctl ship-parallel run: --from requires a value\n' >&2; return 2; }
        from="${args[$((i+1))]}"; i=$((i+2)) ;;
      --isolation)
        [[ $((i+1)) -lt ${#args[@]} && "${args[$((i+1))]}" != -* ]] || { printf 'pmctl ship-parallel run: --isolation requires a value\n' >&2; return 2; }
        isolation="${args[$((i+1))]}"; i=$((i+2)) ;;
      --model)
        [[ $((i+1)) -lt ${#args[@]} && "${args[$((i+1))]}" != -* ]] || { printf 'pmctl ship-parallel run: --model requires a value\n' >&2; return 2; }
        model="${args[$((i+1))]}"; i=$((i+2)) ;;
      --adapter)
        [[ $((i+1)) -lt ${#args[@]} && "${args[$((i+1))]}" != -* ]] || { printf 'pmctl ship-parallel run: --adapter requires a value\n' >&2; return 2; }
        adapter="${args[$((i+1))]}"; i=$((i+2)) ;;
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
  # See the same guard in pmctl_ship_parallel_status: lane tracking is
  # defined in pmctl-ship.sh, not this file.
  if ! declare -F _pmctl_ship_lanes_reg_dir >/dev/null; then
    printf 'pmctl ship-parallel run: pmctl-ship.sh (lane tracking) not loaded\n' >&2
    return 2
  fi

  local reg_dir
  reg_dir="$(_pmctl_ship_lanes_reg_dir "$repo_root" "$work_dir")" || {
    printf 'pmctl ship-parallel run: cannot resolve worktree registry dir from %s\n' "$work_dir" >&2
    return 1
  }
  local tracking_file
  tracking_file="$(_pmctl_ship_lanes_tracking_file "$reg_dir")"

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
            live_status="$(_pmctl_ship_lane_status "$tracked_path" "$tracked_run_id")"
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

  # Requirement 4 (CC-442/CC-443): each lane is now a single call into the
  # unified start entry point (pmctl_ship_run, pmctl-ship.sh) -- worktree
  # create, brief write, dispatch, and tracking-append all live there,
  # exactly once, shared with the standalone `pmctl ship <id> --adapter`
  # path instead of duplicated here. This loop stays responsible only for
  # per-lane argv assembly and the batch fail-count summary; the in-flight
  # re-check just above is a batch-wide pre-flight (belt), pmctl_ship_run's
  # own single-ticket in-flight guard is the per-call recheck (suspenders).
  local fail_count=0
  for t in "${tickets[@]}"; do
    if ! pmctl_ship_run "$repo_root" "$work_dir" "$t" \
           --worktree --adapter "$adapter" \
           ${from:+--from "$from"} --isolation "$isolation" \
           ${model:+--model "$model"} ${auto_pack_flag:+"$auto_pack_flag"} >/dev/null; then
      printf '[%s] dispatch failed -- see above for the specific reason\n' "$t" >&2
      fail_count=$((fail_count+1))
      continue
    fi
    printf '[%s] dispatched: run_id=%s lane=%s\n' "$t" "$PMCTL_SHIP_RUN_ID" "$PMCTL_SHIP_RUN_LANE_PATH"
  done

  if [[ "$fail_count" -gt 0 ]]; then
    printf 'ship-parallel run: %d/%d lane(s) failed to dispatch; see above\n' "$fail_count" "${#tickets[@]}" >&2
    return 1
  fi
  return 0
}

# Per-lane status resolution is `_pmctl_ship_lane_status` (pmctl-ship.sh) --
# shared with pmctl_ship_run's own in-flight guard, see the note near the
# top of this file.

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

  # Lane tracking now lives in pmctl-ship.sh (_pmctl_ship_lanes_*, moved
  # there in CC-442/CC-443 so both this batch orchestrator and the
  # single-ticket `pmctl_ship_run` share one tracking file) -- fail closed
  # with a clear message rather than an unbound-function crash if a direct
  # function-level consumer sources this file without pmctl-ship.sh.
  if ! declare -F _pmctl_ship_lanes_reg_dir >/dev/null; then
    printf 'pmctl ship status: pmctl-ship.sh (lane tracking) not loaded\n' >&2
    return 2
  fi

  local reg_dir tracking_file
  reg_dir="$(_pmctl_ship_lanes_reg_dir "$repo_root" "$work_dir")" || true
  tracking_file="$(_pmctl_ship_lanes_tracking_file "$reg_dir")"
  if [[ ! -f "$tracking_file" ]]; then
    # CC-442/CC-443 renamed the tracking file from ship-parallel.jsonl to
    # ship-lanes.jsonl (it now covers manual --worktree lanes too, not just
    # --parallel). No migration/dual-read path is added on purpose -- this
    # is pre-1.0 internal tooling and CLAUDE.md's own guidance is to avoid
    # permanent backwards-compat shims -- but silently reporting "no tracked
    # lanes" when a pre-upgrade ship-parallel.jsonl still exists would hide
    # real (if stale) lane state from the user. Detect and say so plainly
    # instead; the user decides whether the old lanes still matter.
    if [[ -f "$reg_dir/ship-parallel.jsonl" ]]; then
      printf 'pmctl ship status: found a legacy ship-parallel.jsonl at %s (this pm-dispatch version tracks lanes in ship-lanes.jsonl instead; the old file is not read) -- inspect it manually if you have lanes from before this upgrade.\n' "$reg_dir/ship-parallel.jsonl" >&2
    fi
    [[ "$json_out" -eq 1 ]] && printf '[]\n' || printf 'No tracked ship lanes.\n'
    return 0
  fi

  pmctl_worktree_ensure_writer "$repo_root" || return $?

  local updated
  updated="$(pmctl_ship_lanes_tracking_refresh "$reg_dir" "$json_out")"

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
