#!/usr/bin/env bash
# Wait for a pm-dispatch detached run from a Codex host terminal.
#
# This is intentionally host-owned glue. pmctl remains responsible for the
# authenticated sentinel and durable records; this wrapper makes the terminal
# result unambiguous to the Codex main thread so it can continue from the
# verified outcome. It is equally safe in a foreground terminal, which is the
# compatibility fallback for older Codex clients without background terminals.

set -uo pipefail

usage() {
  cat >&2 <<'EOF'
usage: wait-dispatch.sh --repo-root <pm-dispatch-root> --run-id <run-id> --cd <work-dir> [--timeout <seconds>]

Waits for a detached pmctl dispatch and emits a stable continuation envelope.
Run it in a Codex background terminal when that host capability is available;
run it foreground on older clients. Its exit code is pmctl dispatch wait's
authenticated result and must not be replaced by the envelope.
EOF
}

repo_root="" run_id="" work_dir="" timeout=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }; repo_root="$2"; shift 2 ;;
    --run-id) [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }; run_id="$2"; shift 2 ;;
    --cd) [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }; work_dir="$2"; shift 2 ;;
    --timeout) [[ $# -ge 2 && "${2:-}" =~ ^[1-9][0-9]*$ ]] || { usage; exit 2; }; timeout="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'wait-dispatch.sh: unknown argument: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

[[ "$repo_root" == /* && -x "$repo_root/cli/pmctl" ]] || {
  printf 'wait-dispatch.sh: --repo-root must be a pm-dispatch checkout with executable cli/pmctl\n' >&2
  exit 2
}
[[ "$run_id" =~ ^run-[A-Za-z0-9._-]+$ ]] || {
  printf 'wait-dispatch.sh: invalid --run-id: %s\n' "$run_id" >&2
  exit 2
}
[[ "$work_dir" == /* && -d "$work_dir" ]] || {
  printf 'wait-dispatch.sh: --cd must be an existing absolute directory\n' >&2
  exit 2
}

pmctl_bin="${PM_DISPATCH_CODEX_PMCTL_BIN:-$repo_root/cli/pmctl}"
[[ -x "$pmctl_bin" ]] || {
  printf 'wait-dispatch.sh: pmctl is not executable: %s\n' "$pmctl_bin" >&2
  exit 2
}

wait_args=(dispatch wait "$run_id" --cd "$work_dir")
[[ -n "$timeout" ]] && wait_args+=(--timeout "$timeout")

set +e
"$pmctl_bin" "${wait_args[@]}"
wait_rc=$?
set -e

case "$wait_rc" in
  0) state="completed"; next="read the durable dispatch record and continue the implementation or verification" ;;
  1) state="failed"; next="read the durable dispatch record and supervisor stderr before deciding a repair" ;;
  3) state="indeterminate"; next="do not treat the workspace record as success; inspect pmctl artifacts show and use foreground lifecycle for a new attempt if detached survival is unavailable" ;;
  124) state="timed_out"; next="do not re-dispatch; retry this same wait once, then inspect pmctl artifacts show or cancel the run deliberately" ;;
  130) state="cancelled"; next="treat the run as terminally cancelled; start a new dispatch only after reviewing the durable record" ;;
  *) state="failed"; next="read the durable dispatch record and supervisor stderr before deciding a repair" ;;
esac

printf '\n--- pm-dispatch continuation ---\n'
printf 'run_id: %s\nworking_dir: %s\nwait_exit_code: %s\nstate: %s\nnext: %s\n' \
  "$run_id" "$work_dir" "$wait_rc" "$state" "$next"
printf 'artifacts: %q artifacts show %q --cd %q\n' "$pmctl_bin" "$run_id" "$work_dir"
printf '%s\n' '--- end pm-dispatch continuation ---'

exit "$wait_rc"
