#!/usr/bin/env bash
# Detached-supervised gate runner (CC-423).
#
# Thin detach+sentinel wrapper around runtime/bin/pr-gate.sh, launched by
# pmctl_gate_run_detached under setsid/nohup. Unlike dispatch-supervisor.sh,
# this supervisor does NOT re-run adapter/guard preflight: runtime/bin/pr-gate.sh
# is a trusted in-repo script (not an arbitrary untrusted executor/brief), so
# the only job here is to run it out-of-band and record a nonce-authenticated
# sentinel that `pmctl gate wait <gate_id>` can trust.
#
# Launched as:
#   gate-supervisor.sh --gate-id <id> --cd <effective_cd> --run-dir <gate_run_dir> \
#     -- <native pr-gate.sh args>
set -euo pipefail

# REPO_ROOT resolution stays inline (BEGIN/END markers below): this script
# must resolve its own root before it can `source` the shared lib, so the
# resolver cannot itself live in the lib it bootstraps. Duplicated verbatim
# in dispatch-supervisor.sh; tests/shell/test-detached-launch.sh diffs the two
# marked blocks to catch drift (see docs/spikes/CC-433.md angle a3).
# BEGIN resolve-root
_self="${BASH_SOURCE[0]}"
while [[ -L "$_self" ]]; do
  _dir="$(cd "$(dirname "$_self")" && pwd)"
  _self="$(readlink "$_self")"
  [[ "$_self" == /* ]] || _self="$_dir/$_self"
done
REPO_ROOT="$(cd "$(dirname "$_self")/../.." && pwd)"
unset _self _dir
# END resolve-root

# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/identifier-policy.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/detached-launch.sh"

# Capture the parent-supplied sentinel nonce and immediately unset it so
# pr-gate.sh (and any reviewer session it spawns) cannot read it and forge the
# sentinel path.
_sentinel_nonce="${PM_GATE_SUPERVISOR_NONCE:-}"
unset PM_GATE_SUPERVISOR_NONCE
_terminal_written=false

gate_id=""

# Writes the authoritative per-user private sentinel that `pmctl gate wait`
# polls for. Only written when gate_id/nonce are both known and well-formed.
_write_sentinel() {
  local _state="${1:-failed}" _rc="${2:-2}" _result="${3:-}"
  if pm_identifier_gate_is_valid "$gate_id" && [[ -n "$_sentinel_nonce" ]]; then
    local _sentinel_path
    _sentinel_path="$(detached_launch_private_sentinel_path "pm-gate-dispatch" "pm-gate" "$gate_id" "$_sentinel_nonce")"
    local -a _pairs=("final_state=$_state" "exit_code=$_rc")
    [[ -n "$_result" ]] && _pairs+=("result_file=$_result")
    [[ -n "${PM_GATE_PARENT_OPERATION:-}" ]] && _pairs+=("parent_operation=$PM_GATE_PARENT_OPERATION")
    detached_launch_write_sentinel "$_sentinel_path" "${_pairs[@]}"
    _terminal_written=true
  fi
}

# A child dispatch can terminate the supervisor before pr-gate.sh reaches its
# normal result handoff.  Always publish a failed terminal claim on ordinary
# shell exits so wait/reconcile never leave the parent operation apparently
# running with only readiness evidence. SIGKILL remains inherently
# uncatchable; its unresolved state is still reported as indeterminate.
# shellcheck disable=SC2317 # invoked indirectly by the EXIT trap.
_supervisor_exit() {
  local rc=$?
  if [[ "$_terminal_written" != true ]]; then
    _write_sentinel "failed" "${rc:-2}" ""
  fi
  exit "$rc"
}
trap _supervisor_exit EXIT

# Publish startup evidence only after the supervisor has parsed its arguments,
# validated the run directory, and can prove its own PID identity.  The launcher
# authenticates this nonce-derived path before it returns a detached gate ID;
# therefore a successful `pmctl gate run` means more than a shell fork.
_write_ready() {
  local _ready_path _identity _pid _starttime
  pm_identifier_gate_is_valid "$gate_id" || return 1
  [[ -n "$_sentinel_nonce" ]] || return 1
  _identity="$(detached_launch_capture_identity "$$" 1 2>/dev/null)" || return 1
  _pid="$(printf '%s\n' "$_identity" | grep -m1 '^pid=' | cut -d= -f2-)" || return 1
  _starttime="$(printf '%s\n' "$_identity" | grep -m1 '^starttime=' | cut -d= -f2-)" || return 1
  [[ "$_pid" == "$$" && -n "$_starttime" ]] || return 1
  _ready_path="$(detached_launch_private_sentinel_path "pm-gate-dispatch" "pm-gate-ready" "$gate_id" "$_sentinel_nonce")"
  detached_launch_write_sentinel "$_ready_path" "state=ready" "pid=$_pid" "starttime=$_starttime"
}

_die() {
  printf 'gate-supervisor: %s\n' "$*" >&2
  _write_sentinel "failed" 2 ""
  exit 2
}

# ── Parse args ────────────────────────────────────────────────────────────
cd_arg="" run_dir=""
native=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gate-id)
      [[ $# -ge 2 ]] || _die "missing value for --gate-id"
      gate_id="$2"
      shift 2
      ;;
    --cd)
      [[ $# -ge 2 ]] || _die "missing value for --cd"
      cd_arg="$2"
      shift 2
      ;;
    --run-dir)
      [[ $# -ge 2 ]] || _die "missing value for --run-dir"
      run_dir="$2"
      shift 2
      ;;
    --)
      shift
      native=("$@")
      break
      ;;
    *)
      _die "unexpected argument: $1"
      ;;
  esac
done

pm_identifier_gate_is_valid "$gate_id" || _die "invalid --gate-id: ${gate_id:-<empty>}"
[[ -n "$cd_arg" ]] || _die "--cd is required"
[[ -n "$run_dir" ]] || _die "--run-dir is required"

mkdir -p "$run_dir" || _die "failed to create run dir: $run_dir"

# shellcheck disable=SC2317 # invoked indirectly by the TERM/INT trap.
_cancel_supervisor() {
  _write_sentinel "cancelled" 130 ""
  exit 130
}
trap _cancel_supervisor TERM INT

if [[ -n "${PM_GATE_PARENT_OPERATION:-}" ]]; then
  # Register the already-isolated supervisor as the producer before readiness
  # or any pre-review work is published.  A cancellation that won the launch
  # race records the identity but refuses to release pr-gate.sh.
  # shellcheck source=/dev/null
  . "$REPO_ROOT/runtime/lib/pmctl-operation.sh"
  _producer_register_rc=0
  pmctl_operation_register_producer "$REPO_ROOT" gate "$PM_GATE_PARENT_OPERATION" \
    "$cd_arg" "$$" || _producer_register_rc=$?
  if [[ "$_producer_register_rc" -eq 130 ]]; then
    _write_sentinel "cancelled" 130 ""
    exit 130
  fi
  [[ "$_producer_register_rc" -eq 0 ]] \
    || _die "failed to register detached producer identity"
fi

_write_ready || _die "failed to publish supervisor readiness evidence"

# ── Run pr-gate.sh out-of-band, capturing its stdout for result-path discovery ─
_log="$run_dir/supervisor-stdout.log"
_rc=0
"$REPO_ROOT/runtime/bin/pr-gate.sh" --run-dir "$run_dir" --cd "$cd_arg" ${native[@]+"${native[@]}"} \
  > "$_log" 2>&1 || _rc=$?

# pr-gate.sh prints `result: <path>` for publishable outcomes and
# `failure-result: <path>` for protocol failures; extract either for the
# sentinel so `pmctl gate wait` can surface an inspectable artifact without
# re-deriving OUTPUT_FILE naming. Which label produced the path is load-bearing
# and must be preserved: only `result:` means "pr-gate verified this artifact".
_result_line="$(grep -m1 -E '^(result|failure-result): ' "$_log" 2>/dev/null)" || _result_line=""
_result_file=""
_result_verified=false
case "$_result_line" in
  'result: '*)         _result_file="${_result_line#*: }"; _result_verified=true ;;
  'failure-result: '*) _result_file="${_result_line#*: }" ;;
esac

_terminal_rc="$_rc"
if [[ "$_result_verified" != true && ( "$_rc" -eq 0 || "$_rc" -eq 1 ) ]]; then
  # Exit 0/1 is only a GO/NO-GO verdict after pr-gate publishes the verified
  # `result:` handoff. Without it, finalization or result publication failed;
  # never encode that infrastructure failure as a verdict in the sentinel.
  #
  # A `failure-result:` path is a post-mortem artifact, not a verdict, so it
  # must not satisfy this guard merely by being non-empty. A rejected synthesis
  # is retained for inspection and can still contain its own `Final: GO` line;
  # reporting that as NO-GO invites a reader to take the document's word over
  # the gate's. Protocol failure is an infrastructure outcome (`failed`,
  # exit 2), categorically distinct from a reviewer verdict.
  _state="failed"
  _terminal_rc=2
else
  case "$_rc" in
    0) _state="GO" ;;
    1) _state="NO-GO" ;;
    *) _state="failed" ;;
  esac
fi

_write_sentinel "$_state" "$_terminal_rc" "$_result_file"
exit "$_terminal_rc"
