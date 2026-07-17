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
. "$REPO_ROOT/runtime/lib/detached-launch.sh"

# Capture the parent-supplied sentinel nonce and immediately unset it so
# pr-gate.sh (and any reviewer session it spawns) cannot read it and forge the
# sentinel path.
_sentinel_nonce="${PM_GATE_SUPERVISOR_NONCE:-}"
unset PM_GATE_SUPERVISOR_NONCE

gate_id=""

# Writes the authoritative sentinel /tmp/pm-gate-sentinel-<gate_id>-<nonce> that
# `pmctl gate wait` polls for. Only written when gate_id/nonce are both known
# and well-formed, mirroring dispatch-supervisor.sh's _write_sentinel.
_write_sentinel() {
  local _state="${1:-failed}" _rc="${2:-2}" _result="${3:-}"
  if [[ "$gate_id" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]] && [[ -n "$_sentinel_nonce" ]]; then
    local _sentinel_path
    _sentinel_path="$(detached_launch_sentinel_path "pm-gate" "$gate_id" "$_sentinel_nonce")"
    local -a _pairs=("final_state=$_state" "exit_code=$_rc")
    [[ -n "$_result" ]] && _pairs+=("result_file=$_result")
    detached_launch_write_sentinel "$_sentinel_path" "${_pairs[@]}"
  fi
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

[[ "$gate_id" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]] || _die "invalid --gate-id: ${gate_id:-<empty>}"
[[ -n "$cd_arg" ]] || _die "--cd is required"
[[ -n "$run_dir" ]] || _die "--run-dir is required"

mkdir -p "$run_dir" || _die "failed to create run dir: $run_dir"

# ── Run pr-gate.sh out-of-band, capturing its stdout for result-path discovery ─
_log="$run_dir/supervisor-stdout.log"
_rc=0
"$REPO_ROOT/runtime/bin/pr-gate.sh" --run-dir "$run_dir" --cd "$cd_arg" ${native[@]+"${native[@]}"} \
  > "$_log" 2>&1 || _rc=$?

# pr-gate.sh prints `result: <path>` on completion (runtime/bin/pr-gate.sh:1493,
# both the GO and integrity-checked NO-GO paths); extract it for the sentinel
# so `pmctl gate wait` can surface it without re-deriving OUTPUT_FILE naming.
_result_file="$(grep -m1 '^result: ' "$_log" 2>/dev/null | sed 's/^result: //')" || _result_file=""

case "$_rc" in
  0) _state="GO" ;;
  1) _state="NO-GO" ;;
  *) _state="failed" ;;
esac

_write_sentinel "$_state" "$_rc" "$_result_file"
exit "$_rc"
