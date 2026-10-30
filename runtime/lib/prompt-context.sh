#!/usr/bin/env bash
# Shared prompt-context scan primitive.
#
# Host adapters normalize their native event payload into
# PM_PROMPT_CONTEXT_CWD and PM_PROMPT_CONTEXT_PROMPT, then call
# pm_prompt_context_scan.  This layer intentionally knows nothing about a
# host's JSON shape, hook timeout, or configuration home.

# Keeping the index fresh is not the prompt's job (issue #741, DECISIONS 2026-10-30): by default the prompt is
# answered from the index as it is, and a refresh runs in the background. At most one runs per repository: a
# directory lock holds the start time, a lock older than PM_PROMPT_CONTEXT_REFRESH_LOCK_SECS (900) is taken as
# left by a run that was killed, and the run removes its lock when it ends. Each run is a resumable, time-budgeted
# `pmctl context index`, repeated until nothing is left or the lifetime (900 s) is spent, so a first build
# becomes searchable after its first batch. A failed run leaves its output in refresh.log beside the index.
_pm_prompt_context_start_background_index() {
  local repo_root="$1" pmctl_cli="$2" budget_ms="$3"
  local ctx_dir="$repo_root/.pm-dispatch/ctx" lock now started stale_secs="${PM_PROMPT_CONTEXT_REFRESH_LOCK_SECS:-900}"
  local lock="$ctx_dir/refresh.lockdir"
  [[ "$stale_secs" =~ ^[1-9][0-9]{0,6}$ ]] || stale_secs=900
  printf -v now '%(%s)T' -1
  if [[ -d "$lock" ]]; then
    started=""
    read -r started < "$lock/started" 2>/dev/null || true
    # No start time yet means the owner is between mkdir and its first write: it is running.
    if [[ -z "$started" ]]; then
      [[ -n "$(find "$lock" -maxdepth 0 -mmin "+$((stale_secs / 60))" 2>/dev/null)" ]] || return 0
    elif [[ "$started" =~ ^[0-9]+$ ]] && (( now - started < stale_secs )); then
      return 0
    fi
    rm -rf -- "$lock" 2>/dev/null || return 0
  fi
  mkdir -p "$ctx_dir" 2>/dev/null || return 0
  mkdir "$lock" 2>/dev/null || return 0
  printf '%s\n' "$now" > "$lock/started"
  ( _pm_prompt_context_index_worker "$repo_root" "$pmctl_cli" "$budget_ms" "$lock" ) >/dev/null 2>&1 </dev/null &
  disown 2>/dev/null || true
  return 0
}

_pm_prompt_context_index_worker() {
  local repo_root="$1" pmctl_cli="$2" budget_ms="$3" lock="$4"
  local ctx_dir="$repo_root/.pm-dispatch/ctx" db="$repo_root/.pm-dispatch/ctx/context.db" out now deadline rows
  local -a cmd
  trap 'rm -rf -- "$lock"' EXIT
  printf -v deadline '%(%s)T' -1
  deadline=$((deadline + 900))
  while :; do
    cmd=(bash "$pmctl_cli" context index "$repo_root")
    [[ -z "$budget_ms" ]] || cmd+=(--budget-ms "$budget_ms")
    command -v timeout >/dev/null 2>&1 && cmd=(timeout 300 "${cmd[@]}")
    out="$("${cmd[@]}" 2>&1)" || { printf '%s\n' "$out" > "$ctx_dir/refresh.log" 2>/dev/null; break; }
    [[ "$out" == *"left for the next run"* ]] || break
    printf -v now '%(%s)T' -1
    (( now < deadline )) || break
  done
  # A first build that stored nothing leaves nothing behind, so the next prompt starts it again.
  rows="$(sqlite3 "$db" 'SELECT count(*) FROM files;' 2>/dev/null || true)"
  if [[ -f "$db" && ! "$rows" =~ ^[1-9][0-9]*$ ]]; then
    rm -f -- "$db" "${db}-wal" "${db}-shm" 2>/dev/null || true
  fi
}

pm_prompt_context_scan() {
  local cwd="${PM_PROMPT_CONTEXT_CWD:-}" prompt="${PM_PROMPT_CONTEXT_PROMPT:-}"
  local repo_root pmctl_cli context_db indexed_files initial_build timeout_secs scan_rc=0 out

  [[ -n "$cwd" && -d "$cwd" && ${#prompt} -ge 12 ]] || return 0
  # Without sqlite3 there is no index to scan, so start nothing else (not even git).
  command -v sqlite3 >/dev/null 2>&1 || return 0
  repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [[ -n "$repo_root" ]] || return 0

  pmctl_cli="${PM_DISPATCH_PROMPT_CONTEXT_PMCTL:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/cli/pmctl}"
  [[ -f "$pmctl_cli" ]] || return 0

  context_db="$repo_root/.pm-dispatch/ctx/context.db"
  initial_build=0
  if [[ ! -f "$context_db" ]]; then
    initial_build=1
  else
    indexed_files="$(sqlite3 "$context_db" 'SELECT count(*) FROM files;' 2>/dev/null || true)"
    if [[ "$indexed_files" == "0" ]]; then
      initial_build=1
    fi
  fi
  if [[ "$initial_build" -eq 1 ]]; then
    timeout_secs="${PM_PROMPT_CONTEXT_INITIAL_TIMEOUT:-120}"
  else
    timeout_secs="${PM_PROMPT_CONTEXT_TIMEOUT:-45}"
  fi
  if [[ ! "$timeout_secs" =~ ^[0-9]+$ ]]; then
    if [[ "$initial_build" -eq 1 ]]; then
      timeout_secs=120
    else
      timeout_secs=45
    fi
  fi

  # The index run stops extracting at this budget and the next prompt continues (issue #741). A host that sets
  # none leaves the run unbounded; the Claude hook validates its values and supplies the defaults.
  local budget_ms="${PM_PROMPT_CONTEXT_BUDGET_MS:-}"
  [[ "$initial_build" -eq 1 ]] && budget_ms="${PM_PROMPT_CONTEXT_INITIAL_BUDGET_MS:-}"

  # --defer-event: the scan's telemetry write must not hold the prompt (CC-690). One argument list for both
  # launches, so neither can lose the flag.
  # The flag goes last: callers and test doubles read the repository as the third argument.
  local -a scan_cmd=(bash "$pmctl_cli" context prompt-scan "$repo_root" "$prompt" --defer-event)
  if [[ "${PM_PROMPT_CONTEXT_REFRESH:-background}" == sync ]]; then
    [[ -z "$budget_ms" ]] || scan_cmd+=(--index-budget-ms "$budget_ms")
  else
    # Background (the default): answer from the index as it is; a refresh runs beside this prompt.
    _pm_prompt_context_start_background_index "$repo_root" "$pmctl_cli" "$budget_ms" || true
    scan_cmd+=(--no-refresh)
    timeout_secs="${PM_PROMPT_CONTEXT_TIMEOUT:-45}"
    [[ "$timeout_secs" =~ ^[0-9]+$ ]] || timeout_secs=45
  fi
  command -v timeout >/dev/null 2>&1 && scan_cmd=(timeout "$timeout_secs" "${scan_cmd[@]}")
  out="$(PM_DISPATCH_CONTEXT_AUTOBUILD=1 "${scan_cmd[@]}" 2>/dev/null)" || scan_rc=$?
  if [[ "$scan_rc" -ne 0 ]]; then
    # Only the synchronous mode builds in this call; in the background the worker owns the database.
    if [[ "$initial_build" -eq 1 && "${PM_PROMPT_CONTEXT_REFRESH:-background}" == sync ]]; then
      indexed_files="$(sqlite3 "$context_db" 'SELECT count(*) FROM files;' 2>/dev/null || true)"
      if [[ ! "$indexed_files" =~ ^[1-9][0-9]*$ ]]; then
        rm -f -- "$context_db" "${context_db}-wal" "${context_db}-shm" 2>/dev/null || true
      fi
    fi
    return 0
  fi
  [[ -n "$out" && "$out" != "knowledge_hits: []" ]] || return 0
  grep -q '^knowledge_hits:' <<<"$out" || return 0
  printf '=== auto-context: knowledge index hits ===\n'
  printf 'Repo: %s | pointer-only; cite refs instead of re-deriving from full-file reads\n' "$repo_root"
  printf '%s\n' "$out"
  printf 'More: pmctl context query %s --domain knowledge <term>\n' "$repo_root"
  printf '=== end auto-context ===\n'
}
