#!/usr/bin/env bash
# Deliver a completed detached dispatch back into a Codex App Server thread.
#
# This program belongs in a host-owned background terminal. Unlike a shell job,
# it has an explicit delivery step: after the authenticated pmctl wait finishes,
# it starts a new turn in the originating Codex thread. A caller without a
# thread id or App Server control socket must use wait-dispatch.sh foreground.

set -uo pipefail

usage() {
  cat >&2 <<'EOF'
usage: continue-dispatch.sh --repo-root <pm-dispatch-root> --run-id <run-id> --cd <work-dir> --thread-id <codex-thread-id> [--timeout <seconds>] [--app-server-socket <path>]

Waits for a detached dispatch, then asks Codex App Server to start a new turn
in --thread-id containing the authenticated result. Run this only in a
host-owned background terminal after preflight has confirmed the App Server
control socket is reachable. If that bridge is unavailable, run
wait-dispatch.sh foreground instead.
EOF
}

repo_root="" run_id="" work_dir="" thread_id="" timeout="" socket=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }; repo_root="$2"; shift 2 ;;
    --run-id) [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }; run_id="$2"; shift 2 ;;
    --cd) [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }; work_dir="$2"; shift 2 ;;
    --thread-id) [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }; thread_id="$2"; shift 2 ;;
    --timeout) [[ $# -ge 2 && "${2:-}" =~ ^[1-9][0-9]*$ ]] || { usage; exit 2; }; timeout="$2"; shift 2 ;;
    --app-server-socket) [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }; socket="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'continue-dispatch.sh: unknown argument: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

[[ "$thread_id" =~ ^[A-Za-z0-9._:-]+$ ]] || { printf 'continue-dispatch.sh: invalid --thread-id\n' >&2; exit 2; }
[[ -z "$socket" || "$socket" == /* ]] || { printf 'continue-dispatch.sh: --app-server-socket must be absolute\n' >&2; exit 2; }

waiter="$repo_root/hosts/codex/bin/wait-dispatch.sh"
[[ -x "$waiter" ]] || { printf 'continue-dispatch.sh: waiter is not executable: %s\n' "$waiter" >&2; exit 2; }
proxy_bin="${PM_DISPATCH_CODEX_APP_SERVER_PROXY_BIN:-codex}"
command -v "$proxy_bin" >/dev/null 2>&1 || {
  printf 'continue-dispatch.sh: Codex App Server bridge unavailable (%s not on PATH); run wait-dispatch.sh foreground\n' "$proxy_bin" >&2
  exit 2
}

# Keep dynamic values single-line so they cannot alter JSON-RPC framing.
case "$work_dir$repo_root$run_id$thread_id$socket" in
  *$'\n'*|*$'\r'*|*$'\t'*) printf 'continue-dispatch.sh: arguments must not contain control characters\n' >&2; exit 2 ;;
esac

wait_args=(--repo-root "$repo_root" --run-id "$run_id" --cd "$work_dir")
[[ -n "$timeout" ]] && wait_args+=(--timeout "$timeout")
result_file="$(mktemp "${TMPDIR:-/tmp}/pm-dispatch-codex-continuation.XXXXXX")" || exit 2
trap 'rm -f "$result_file"' EXIT

set +e
"$waiter" "${wait_args[@]}" >"$result_file" 2>&1
wait_rc=$?
set -e
envelope="$(<"$result_file")"

json_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "$value"
}

message=$'A detached pm-dispatch run has reached a verified terminal result. Continue the requested implementation now; do not redispatch solely because this notification arrived.\n\n'
message+="$envelope"
init_request='{"id":1,"method":"initialize","params":{"clientInfo":{"name":"pm-dispatch","version":"1"}}}'
turn_request=$(printf '{"id":2,"method":"turn/start","params":{"threadId":%s,"cwd":%s,"input":[{"type":"text","text":%s}]}}' \
  "$(json_quote "$thread_id")" "$(json_quote "$work_dir")" "$(json_quote "$message")")

proxy_args=(app-server proxy)
[[ -n "$socket" ]] && proxy_args+=(--sock "$socket")
set +e
proxy_output="$(printf '%s\n%s\n' "$init_request" "$turn_request" | "$proxy_bin" "${proxy_args[@]}" 2>&1)"
proxy_rc=$?
set -e

if [[ "$proxy_rc" -ne 0 || "$proxy_output" == *'"error"'* || ! "$proxy_output" =~ \"id\"[[:space:]]*:[[:space:]]*2 ]]; then
  printf 'continue-dispatch.sh: unable to deliver continuation to Codex App Server; foreground continuation is required\n' >&2
  [[ -n "$proxy_output" ]] && printf '%s\n' "$proxy_output" >&2
  exit 4
fi

printf 'pm-dispatch continuation delivered to Codex thread %s (wait exit %s)\n' "$thread_id" "$wait_rc"
exit "$wait_rc"
