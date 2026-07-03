#!/usr/bin/env bash
# pmctl ship prepare/finish -- the deterministic, scriptable bookends of the
# ship contract (commands/ship.md, CC-439): Step 0 (ticket-id validate +
# consistency-check surface) and Step 1 (branch) live in `prepare`; Step 3
# (one gate round) and Step 4 (PR on GO) live in `finish`. Step 2 (implement)
# is NOT scriptable -- it requires an agent (this session, or a dispatched
# executor) to actually read/write code -- so it is never a pmctl
# subcommand; it happens between one `prepare` call and one-or-more `finish`
# calls (finish is re-invoked after each round of fixes, same NO-GO loop
# discipline `/ship` already uses, just with the mechanical parts scripted).
#
# `pmctl ship --parallel` (pmctl-ship-parallel.sh) is the N-lane extension:
# each lane still runs prepare (as a worktree create) once, dispatches
# Step 2 + repeated `finish` calls to an executor, same contract, same
# bookend primitives, just executed inside a worktree by a dispatched
# executor instead of inline by this session.

pmctl_ship_usage() {
  printf 'usage: pmctl ship prepare <ticket-id> [--cd <work_dir>]\n' >&2
  printf '       pmctl ship finish  <ticket-id> [--cd <work_dir>] [--reviewers <r,...>]\n' >&2
  printf '       pmctl ship --parallel <ticket-id> [<ticket-id>...] [--from <base>] [--adapter <codex|claude|opencode>] [--isolation <level>] [--model <alias>] [--cd <work_dir>]\n' >&2
  printf '       pmctl ship status [--cd <work_dir>] [--json]\n' >&2
  printf '       pmctl ship list   [--cd <work_dir>] [--json]\n' >&2
}

# _pmctl_ship_id_shape_ok <ticket_id>
_pmctl_ship_id_shape_ok() {
  [[ "$1" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]]
}

# pmctl_ship_prepare <repo_root> <work_dir> <ticket-id>
# Step 0 (id validation only -- the DECISIONS.md/Dependencies consistency
# judgment stays the CALLER's job; that is PM-level judgment, not a
# deterministic bash check, per commands/ship.md Step 0) + Step 1 (dirty-tree
# precondition + branch), IN PLACE in work_dir -- no worktree, matching
# /ship's existing single-ticket behavior exactly.
pmctl_ship_prepare() {
  local repo_root="${1:-}" work_dir="${2:-}" ticket_id="${3:-}"
  [[ -n "$work_dir" ]] || work_dir="$repo_root"

  if [[ -z "$ticket_id" ]]; then
    printf 'pmctl ship prepare: empty argument\n' >&2
    return 1
  fi
  if ! _pmctl_ship_id_shape_ok "$ticket_id"; then
    printf 'pmctl ship prepare: malformed shape: %s\n' "$ticket_id" >&2
    return 1
  fi
  if ! grep -q "^## $ticket_id" "$work_dir/BACKLOG.md" 2>/dev/null; then
    if grep -q "^## $ticket_id" "$work_dir/BACKLOG-ARCHIVE.md" 2>/dev/null; then
      printf 'pmctl ship prepare: ticket already archived: %s\n' "$ticket_id" >&2
    else
      printf 'pmctl ship prepare: no such ticket: %s\n' "$ticket_id" >&2
    fi
    return 1
  fi

  if [[ -n "$(git -C "$work_dir" status --porcelain 2>/dev/null)" ]]; then
    printf 'pmctl ship prepare: tree is dirty -- commit or stash before preparing %s\n' "$ticket_id" >&2
    return 1
  fi

  local branch="feat/$ticket_id"
  if ! git -C "$work_dir" checkout -b "$branch" 2>&1; then
    printf 'pmctl ship prepare: branch checkout failed for %s\n' "$branch" >&2
    return 1
  fi
  printf '%s\n' "$branch"
}

# pmctl_ship_finish <repo_root> <work_dir> <ticket-id> [--reviewers <r,...>]
# Runs ONE gate round in work_dir. GO: push + open PR, print the PR URL.
# NO-GO: print the verdict/result path and exit 1 -- the caller (agent) is
# expected to fix findings and call `finish` again, same loop discipline as
# `/ship` Step 3, just with the gate-invoke/read/push/PR mechanics scripted.
pmctl_ship_finish() {
  local repo_root="${1:-}" work_dir="${2:-}" ticket_id="${3:-}"
  shift 3 || true
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  local reviewers="" args=("$@") i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --reviewers) reviewers="${args[$((i+1))]:-}"; i=$((i+2)) ;;
      -h|--help) pmctl_ship_usage; return 0 ;;
      *) i=$((i+1)) ;;
    esac
  done

  if [[ -z "$ticket_id" ]]; then
    printf 'pmctl ship finish: <ticket-id> is required\n' >&2
    return 2
  fi
  if ! declare -F pmctl_gate_run >/dev/null; then
    printf 'pmctl ship finish: pmctl gate unavailable\n' >&2
    return 2
  fi

  local gate_args=(--executor codex --cd "$work_dir" --lifecycle foreground)
  [[ -n "$reviewers" ]] && gate_args+=(--reviewers "$reviewers")
  local gate_out gate_status=0
  gate_out="$(pmctl_gate_run "$repo_root" "${gate_args[@]}" 2>&1)" || gate_status=$?
  printf '%s\n' "$gate_out"

  # Source of truth is the RESULT FILE's `Final:` line, not the captured
  # exit code or any stdout text -- pr-gate.sh prints `result: <path>` near
  # the end of its run; read that file directly rather than trust output
  # that could be truncated/reordered by capture.
  local result_path final_verdict
  result_path="$(printf '%s\n' "$gate_out" | grep -m1 '^result: ' | sed 's/^result: *//')"
  if [[ -z "$result_path" || ! -f "$result_path" ]]; then
    printf 'pmctl ship finish: could not locate gate result file (gate exit %s) -- see output above\n' "$gate_status" >&2
    return 1
  fi
  final_verdict="$(grep -m1 '^Final: ' "$result_path" 2>/dev/null | awk '{print $2}')"
  if [[ "$final_verdict" != "GO" ]]; then
    printf 'pmctl ship finish: %s -- fix findings and re-run finish. Result: %s\n' "${final_verdict:-NO VERDICT}" "$result_path" >&2
    return 1
  fi

  local branch
  branch="$(git -C "$work_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ -z "$branch" || "$branch" == HEAD ]]; then
    printf 'pmctl ship finish: cannot resolve current branch in %s\n' "$work_dir" >&2
    return 1
  fi
  if ! git -C "$work_dir" push -u origin "$branch"; then
    printf 'pmctl ship finish: git push failed for %s\n' "$branch" >&2
    return 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    # Backtick below is a literal Markdown code span, not command substitution.
    # shellcheck disable=SC2016
    printf 'pmctl ship finish: pushed %s, but `gh` is unavailable -- open the PR manually\n' "$branch" >&2
    return 0
  fi
  local pr_url pr_status=0
  pr_url="$(cd "$work_dir" && gh pr create --title "chore(${ticket_id}): ship" \
    --body "$(printf 'Ticket: %s\n\nGate: GO\n' "$ticket_id")")" || pr_status=$?
  printf '%s\n' "$pr_url"
  if [[ "$pr_status" -ne 0 ]]; then
    return "$pr_status"
  fi

  # Durable, structured GO+PR marker inside work_dir -- this is what
  # `pmctl ship status`/`list` (pmctl-ship-parallel.sh) read to detect a
  # lane's GO state. Grepping a dispatched executor's own free-text summary
  # for "Final: GO" is unreliable (an executor may report the verdict in
  # prose/another language, e.g. "Gate 通過（GO）" -- confirmed to false-
  # negative during CC-441's real e2e validation); this file is written by
  # `pmctl ship finish` ITSELF only on a confirmed GO, so its mere presence
  # is the source of truth.
  local marker
  marker="$work_dir/.pm-dispatch-ship-finish.json"
  jq -n --arg ticket "$ticket_id" --arg branch "$branch" --arg pr_url "$pr_url" \
    --arg result_path "$result_path" --arg finished_ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)" \
    '{ticket: $ticket, verdict: "GO", branch: $branch, pr_url: $pr_url, result_path: $result_path, finished_ts: $finished_ts}' \
    > "$marker" 2>/dev/null || true
}
