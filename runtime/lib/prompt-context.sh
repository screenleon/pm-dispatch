#!/usr/bin/env bash
# Shared prompt-context scan primitive.
#
# Host adapters normalize their native event payload into
# PM_PROMPT_CONTEXT_CWD and PM_PROMPT_CONTEXT_PROMPT, then call
# pm_prompt_context_scan.  This layer intentionally knows nothing about a
# host's JSON shape, hook timeout, or configuration home.

# Keeping the index fresh is not the prompt's job in the background mode (issue #741, DECISIONS 2026-10-30): the
# prompt is answered from the index as it is and a refresh runs beside it. At most one runs per repository. The
# lock is a directory whose `heartbeat` file holds the epoch of the worker's last sign of life, renewed before
# every index run. A heartbeat older than PM_PROMPT_CONTEXT_REFRESH_STALE_SECS (180) means the worker was killed
# (a host may stop background processes with the hook). Taking such a lock over is serialized by a second
# directory, the reclaim fence: its holder re-reads the heartbeat (a contender that saw the same stale lock earlier
# may find a fresh one by now), removes the old lock, makes the new one, and only then lets go of the fence.
# mkdir_lock's owner liveness cannot be used here: its owner would be this hook, which exits at once.
# A run that fails writes refresh.failed, and no new run starts for 10 minutes; its output is refresh.log. The worker
# never deletes the database (a reader may have it open; with no rows the scan answers empty), and nothing here writes
# through a link: the cache directories must be real directories, and the two marker files replace whatever entry
# is at their path instead of opening it.
# PM_PROMPT_CONTEXT_REFRESH_TRACE (tests only): every decision of the starter is appended to that file, so a test
# can wait on what happened instead of on time.
_pm_prompt_context_trace() {
  [[ -z "${PM_PROMPT_CONTEXT_REFRESH_TRACE:-}" ]] || printf '%s\n' "$1" >> "$PM_PROMPT_CONTEXT_REFRESH_TRACE"
  return 0
}

# <file> <variable>: the first line of a regular file that is not a link, at most 40 characters and 2 seconds of it,
# or an empty string. A path inside the repository's cache may have been replaced by a link to a device or a FIFO,
# and an unbounded read of that would hold the hook.
_pm_prompt_context_read_small() {
  local __rs_value=""
  if [[ -f "$1" && ! -L "$1" ]]; then
    read -r -n 40 -t 2 __rs_value < "$1" 2>/dev/null || true
  fi
  printf -v "$2" '%s' "$__rs_value"
}

_pm_prompt_context_start_background_index() {
  local repo_root="$1" pmctl_cli="$2" budget_ms="$3"
  local ctx_dir="$repo_root/.pm-dispatch/ctx" lock reclaim now beat beat_again failed took_over=0
  local stale_secs="${PM_PROMPT_CONTEXT_REFRESH_STALE_SECS:-180}"
  lock="$ctx_dir/refresh.lockdir"
  reclaim="$ctx_dir/refresh.reclaimdir"
  [[ "$stale_secs" =~ ^[1-9][0-9]{0,6}$ ]] || stale_secs=180
  if [[ -L "$repo_root/.pm-dispatch" || -L "$ctx_dir" ]]; then
    _pm_prompt_context_trace skipped-unsafe-directory
    return 0
  fi
  printf -v now '%(%s)T' -1
  _pm_prompt_context_read_small "$ctx_dir/refresh.failed" failed
  if [[ "$failed" =~ ^[0-9]+$ ]] && (( now - failed < 600 )); then
    _pm_prompt_context_trace skipped-failed-recently
    return 0
  fi
  if [[ -e "$lock" || -L "$lock" ]]; then
    beat=""
    if [[ -d "$lock" && ! -L "$lock" ]]; then
      _pm_prompt_context_read_small "$lock/heartbeat" beat
      if [[ -z "$beat" ]]; then
        # The owner is between mkdir and its first write, or died there: only the lock's own age tells.
        if [[ -z "$(find "$lock" -maxdepth 0 -mmin "+$(( (stale_secs + 59) / 60 ))" 2>/dev/null)" ]]; then
          _pm_prompt_context_trace skipped-running
          return 0
        fi
      elif [[ "$beat" =~ ^[0-9]+$ ]] && (( now - beat < stale_secs )); then
        _pm_prompt_context_trace skipped-running
        return 0
      fi
    fi
    # Stale (or not a plain directory): take it over under the fence. A fence left by a contender that died is
    # older than a minute and is removed.
    if [[ -d "$reclaim" && -n "$(find "$reclaim" -maxdepth 0 -mmin +1 2>/dev/null)" ]]; then
      rm -rf -- "$reclaim" 2>/dev/null || true
    fi
    if ! mkdir "$reclaim" 2>/dev/null; then
      _pm_prompt_context_trace skipped-reclaiming
      return 0
    fi
    # Under the fence, look again: a lock that is still there with another heartbeat was taken over, or its worker is
    # alive after all; a lock that is gone leaves nothing running.
    if [[ -e "$lock" || -L "$lock" ]]; then
      beat_again=""
      if [[ -d "$lock" && ! -L "$lock" ]]; then
        _pm_prompt_context_read_small "$lock/heartbeat" beat_again
      fi
      if [[ "$beat_again" != "$beat" ]]; then
        rmdir "$reclaim" 2>/dev/null || true
        _pm_prompt_context_trace skipped-replaced
        return 0
      fi
      rm -rf -- "$lock" 2>/dev/null || true
    fi
    took_over=1
    _pm_prompt_context_trace took-over
  fi
  if ! mkdir -p "$ctx_dir" 2>/dev/null || ! mkdir "$lock" 2>/dev/null; then
    (( took_over )) && { rmdir "$reclaim" 2>/dev/null || true; }
    _pm_prompt_context_trace skipped-lost-race
    return 0
  fi
  printf '%s\n' "$now" > "$lock/heartbeat"
  (( took_over )) && { rmdir "$reclaim" 2>/dev/null || true; }
  _pm_prompt_context_trace started
  ( _pm_prompt_context_index_worker "$repo_root" "$pmctl_cli" "$budget_ms" "$lock" ) >/dev/null 2>&1 </dev/null &
  disown 2>/dev/null || true
  return 0
}

# Replace the entry at <dest> with a file holding <content>, never opening what is there: a link a repository put at
# the path is replaced, not followed.
_pm_prompt_context_write_marker() {
  local dest="$1" content="$2" tmp
  [[ ! -d "$dest" ]] || return 0
  tmp="$(mktemp "$(dirname "$dest")/.refresh-marker.XXXXXX" 2>/dev/null)" || return 0
  if printf '%s\n' "$content" > "$tmp" 2>/dev/null; then
    mv -f -- "$tmp" "$dest" 2>/dev/null || rm -f -- "$tmp"
  else
    rm -f -- "$tmp"
  fi
  return 0
}

# The worker's EXIT action. A fixed function reading plain variables, never trap text built from a path (a path
# may hold any character, quotes included), and it removes the lock only while the lock is still this worker's.
_pm_prompt_context_release_lock() {
  local owner=""
  [[ -z "${_PMC_LOCK:-}" ]] || _pm_prompt_context_read_small "$_PMC_LOCK/owner" owner
  if [[ -n "${_PMC_LOCK:-}" && "$owner" == "${_PMC_TOKEN:-}" ]]; then
    rm -rf -- "$_PMC_LOCK"
    _pm_prompt_context_trace worker-removed-lock
  else
    _pm_prompt_context_trace worker-left-lock
  fi
  return 0
}

# One `pmctl context index --budget-ms` run after another until nothing is left or 15 minutes have passed.
_pm_prompt_context_index_worker() {
  local repo_root="$1" pmctl_cli="$2" budget_ms="$3"
  local ctx_dir="$repo_root/.pm-dispatch/ctx" out now deadline
  local -a cmd
  _PMC_LOCK="$4"
  _PMC_TOKEN="$BASHPID"
  printf '%s\n' "$_PMC_TOKEN" > "$_PMC_LOCK/owner" 2>/dev/null
  trap _pm_prompt_context_release_lock EXIT
  printf -v deadline '%(%s)T' -1
  deadline=$((deadline + 900))
  while :; do
    printf '%(%s)T\n' -1 > "$_PMC_LOCK/heartbeat" 2>/dev/null
    cmd=(bash "$pmctl_cli" context index "$repo_root")
    [[ -z "$budget_ms" ]] || cmd+=(--budget-ms "$budget_ms")
    command -v timeout >/dev/null 2>&1 && cmd=(timeout 300 "${cmd[@]}")
    if ! out="$("${cmd[@]}" 2>&1)"; then
      _pm_prompt_context_write_marker "$ctx_dir/refresh.log" "$out"
      printf -v now '%(%s)T' -1
      _pm_prompt_context_write_marker "$ctx_dir/refresh.failed" "$now"
      break
    fi
    [[ -L "$ctx_dir/refresh.failed" ]] || rm -f -- "$ctx_dir/refresh.failed"
    [[ "$out" == *"left for the next run"* ]] || break
    printf -v now '%(%s)T' -1
    (( now < deadline )) || break
  done
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
    indexed_files="$(sqlite3 -cmd '.timeout 2000' "$context_db" 'SELECT count(*) FROM files;' 2>/dev/null || true)"
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
  if [[ "${PM_PROMPT_CONTEXT_REFRESH:-sync}" == sync ]]; then
    [[ -z "$budget_ms" ]] || scan_cmd+=(--index-budget-ms "$budget_ms")
  else
    # Background (the Claude hook sets it): answer from the index as it is; a refresh runs beside this prompt.
    _pm_prompt_context_start_background_index "$repo_root" "$pmctl_cli" "$budget_ms" || true
    scan_cmd+=(--no-refresh)
    timeout_secs="${PM_PROMPT_CONTEXT_TIMEOUT:-45}"
    [[ "$timeout_secs" =~ ^[0-9]+$ ]] || timeout_secs=45
  fi
  command -v timeout >/dev/null 2>&1 && scan_cmd=(timeout "$timeout_secs" "${scan_cmd[@]}")
  out="$(PM_DISPATCH_CONTEXT_AUTOBUILD=1 "${scan_cmd[@]}" 2>/dev/null)" || scan_rc=$?
  if [[ "$scan_rc" -ne 0 ]]; then
    # Only the synchronous mode builds in this call; in the background the worker owns the database.
    if [[ "$initial_build" -eq 1 && "${PM_PROMPT_CONTEXT_REFRESH:-sync}" == sync ]]; then
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
