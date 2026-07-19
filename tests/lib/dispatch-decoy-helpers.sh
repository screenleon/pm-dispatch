#!/usr/bin/env bash
# Shared isolated-decoy-process helpers for dispatch cancel/reconcile tests
# (CC-495/CC-499). Both suites need a real, killable, isolated-process-group
# process to forge/verify trusted identity fixtures against — extracted here
# so a fix to the readiness poll or kill sequence lands once, not twice.

# Launch `setsid tail -f /dev/null` in its own session/process-group and poll
# until /proc/<pid>/stat is readable. Prints the pid on success.
dispatch_test_isolated_decoy() {
  command -v setsid >/dev/null 2>&1 || return 1
  setsid tail -f /dev/null </dev/null >/dev/null 2>&1 &
  local pid=$!
  local _poll
  for _poll in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [[ -r "/proc/$pid/stat" ]] && break
    : "$_poll"
  done
  [[ -r "/proc/$pid/stat" ]] || { kill -KILL "$pid" 2>/dev/null || true; return 1; }
  printf '%s\n' "$pid"
}

# SIGKILL a decoy pid and its process group, then reap it. Best-effort;
# never fails the caller.
dispatch_test_kill_pid_quiet() {
  local pid="${1:-}"
  [[ -n "$pid" ]] || return 0
  kill -KILL "$pid" 2>/dev/null || true
  kill -KILL -- "-$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  return 0
}

# Trusted out-of-repo artifact dir (.agent-trace) for <work_dir>/<run_id>,
# derived the same way pmctl dispatch does (via sw_project_run_dir).
dispatch_test_run_trace_dir() {
  ( cd "$1" 2>/dev/null && printf '%s/.agent-trace\n' "$(sw_project_run_dir "$2")" )
}
