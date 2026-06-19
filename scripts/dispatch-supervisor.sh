#!/usr/bin/env bash
# Detached-supervised dispatch executor.
#
# Owns exactly the post-preflight executor tail: invoke the adapter, capture and
# persist the stdout footer, run post-verify, and write the terminal durable run
# state + result record. It reads a pmctl-produced run-spec (--run-spec <path>),
# never raw adapter paths or inline briefs.
#
# Security boundary: the supervisor is NOT a bypass door. Before invoking any
# executor it re-runs the SAME security preflight pmctl dispatch run does —
# adapter name validation, dispatch.sh symlink/containment guard, route
# allowlist, and `pmctl guard check` for the brief write. A tampered run-spec can
# therefore never reach an executor that `pmctl dispatch run` would have refused.
# REPO_ROOT is derived from this script's own resolved location (mirroring
# cli/pmctl), so the spec cannot redirect the trust anchor.
#
# Launched by pmctl_dispatch_run via setsid/nohup for true detachment. The parent
# returns a run_id immediately; `pmctl dispatch wait <run_id> --cd <work_dir>`
# later resolves the terminal outcome from the durable dispatch record.
set -euo pipefail

# Resolve the real script path through symlinks so REPO_ROOT is the actual repo
# directory regardless of how the supervisor is launched (pattern from cli/pmctl).
_self="${BASH_SOURCE[0]}"
while [[ -L "$_self" ]]; do
  _dir="$(cd "$(dirname "$_self")" && pwd)"
  _self="$(readlink "$_self")"
  [[ "$_self" == /* ]] || _self="$_dir/$_self"
done
REPO_ROOT="$(cd "$(dirname "$_self")/.." && pwd)"
unset _self _dir

for _lib in pmctl-config portable runner-kind executor-router pmctl-guard dispatch-record pmctl-dispatch; do
  # shellcheck source=/dev/null
  [[ -r "$REPO_ROOT/scripts/lib/$_lib.sh" ]] && . "$REPO_ROOT/scripts/lib/$_lib.sh"
done
unset _lib

# Capture the parent-supplied sentinel nonce from the environment and immediately
# unset it so the adapter subprocess cannot read it and forge the sentinel path.
# The nonce is NOT written to the run-spec (which is workspace-readable), so an
# executor that can read the workspace run-spec cannot derive the sentinel path.
_sentinel_nonce="${PM_SUPERVISOR_NONCE:-}"
unset PM_SUPERVISOR_NONCE

# Write the supervisor sentinel to /tmp so pmctl dispatch wait can authenticate
# that the supervisor (not the executor) signalled completion. The sentinel path
# includes a nonce known only to the parent and supervisor: because the nonce is
# not in the workspace run-spec and is unset from the environment before the
# adapter runs, an executor cannot forge the correct path to fake completion.
# Takes final_state (ok|failed) and exit_code as arguments.
_write_sentinel() {
  local _state="${1:-failed}" _rc="${2:-2}"
  if [[ "${spec_run_id:-}" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]] \
     && [[ -n "${_sentinel_nonce:-}" ]]; then
    printf 'final_state=%s\nexit_code=%s\n' "$_state" "$_rc" \
      > "/tmp/pm-supervisor-sentinel-${spec_run_id}-${_sentinel_nonce}" 2>/dev/null || true
  fi
}

_die() {
  printf 'dispatch-supervisor: %s\n' "$*" >&2
  # Write a failed dispatch record so pmctl dispatch wait observes failure
  # quickly instead of blocking until timeout. Only possible after the run-spec
  # has been parsed and the run_id + work_dir are valid.
  if [[ "${spec_run_id:-}" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]] \
    && [[ -n "${spec_work_dir:-}" ]] \
    && declare -F dispatch_record_write >/dev/null 2>&1; then
    local _finished_ts
    _finished_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
    dispatch_record_write "$spec_run_id" "" "${spec_adapter:-}" "${spec_model:-}" \
      "${spec_brief_file:-}" "$spec_work_dir" 2 "failed" \
      "supervisor preflight failed: $*" "" "" "" \
      "${spec_created_ts:-}" "$_finished_ts" 2>/dev/null || true
  fi
  _write_sentinel "failed" 2
  # Only unlink the parent-created brief snapshot, never an arbitrary path from the
  # run-spec. Validate that the path matches the /tmp/brief-<run_id>.md pattern
  # that the parent writes before launching the supervisor. A tampered run-spec
  # cannot cause _die to delete an arbitrary file by pointing brief_file elsewhere.
  local _expected_brief="/tmp/brief-${spec_run_id:-}.md"
  if [[ -n "${spec_run_id:-}" \
        && "${spec_brief_file:-}" == "$_expected_brief" ]]; then
    rm -f "$spec_brief_file" 2>/dev/null || true
  fi
  exit 2
}

# ── Parse args ──────────────────────────────────────────────────────────────
run_spec=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-spec)
      [[ $# -ge 2 ]] || _die "missing value for --run-spec"
      run_spec="$2"
      shift 2
      ;;
    *)
      _die "unexpected argument: $1"
      ;;
  esac
done
[[ -n "$run_spec" ]] || _die "--run-spec <path> is required"
[[ -f "$run_spec" ]] || _die "run-spec not found: $run_spec"

# ── Read run-spec (schema v2) ───────────────────────────────────────────────
# Scalars are key=value (first '=' splits, so values may contain '=' or spaces).
# `cd_arg` and `brief_file` are the trusted core args; the `native_b64:` section
# holds ONLY the non-core adapter passthrough args (no --cd / --brief-file), one
# base64 token per line. The supervisor never word-splits user-influenced tokens.
spec_schema="" spec_run_id="" spec_adapter="" spec_work_dir="" spec_cd_arg=""
spec_brief_file="" spec_model="" spec_created_ts="" spec_print_cmd=""
spec_initial_state_written="0"
native=()
in_native=0
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$in_native" -eq 1 ]]; then
    [[ -z "$line" ]] && continue
    arg="$(printf '%s' "$line" | base64 -d 2>/dev/null)" || _die "malformed base64 arg in run-spec"
    native+=("$arg")
    continue
  fi
  case "$line" in
    native_b64:) in_native=1 ;;
    schema_version=*) spec_schema="${line#schema_version=}" ;;
    run_id=*)       spec_run_id="${line#run_id=}" ;;
    adapter=*)      spec_adapter="${line#adapter=}" ;;
    work_dir=*)     spec_work_dir="${line#work_dir=}" ;;
    cd_arg=*)       spec_cd_arg="${line#cd_arg=}" ;;
    brief_file=*)   spec_brief_file="${line#brief_file=}" ;;
    model=*)        spec_model="${line#model=}" ;;
    created_ts=*)   spec_created_ts="${line#created_ts=}" ;;
    print_cmd=*)    spec_print_cmd="${line#print_cmd=}" ;;
    initial_state_written=*) spec_initial_state_written="${line#initial_state_written=}" ;;
    *) : ;;  # ignore unknown keys (forward-compatible)
  esac
done < "$run_spec"

# ── Validate the spec's own fields (independent of pmctl) ────────────────────
[[ "$spec_schema" == "2" ]] || _die "unsupported run-spec schema_version: ${spec_schema:-<empty>}"
[[ "$spec_run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]] || _die "invalid run_id in run-spec: ${spec_run_id:-<empty>}"
[[ -n "$spec_adapter" ]] || _die "missing adapter in run-spec"
[[ -n "$spec_work_dir" ]] || _die "missing work_dir in run-spec"
[[ -n "$spec_cd_arg" ]] || _die "missing cd_arg in run-spec"
[[ -n "$spec_brief_file" ]] || _die "missing brief_file in run-spec"
case "$spec_print_cmd" in 0|1) : ;; *) _die "invalid print_cmd in run-spec: ${spec_print_cmd:-<empty>}" ;; esac
case "$spec_initial_state_written" in 0|1) : ;; *) _die "invalid initial_state_written in run-spec: ${spec_initial_state_written:-<empty>}" ;; esac

# The native passthrough args must NOT smuggle in their own --cd / --brief-file:
# those are trusted scalars the supervisor reconstructs below, so a second copy in
# the native section would let a tampered run-spec point the adapter at a brief or
# work dir different from the one guarded and validated. Reject any such token.
for arg in ${native[@]+"${native[@]}"}; do
  case "$arg" in
    --cd|--brief-file)
      _die "run-spec native args must not contain $arg (it is a trusted scalar, not a passthrough)"
      ;;
  esac
done

# ── Re-run the full security preflight (defense in depth — not a bypass door) ─
# spec_brief_file points at the parent's durable snapshot committed atomically
# before dispatch run returned; the original temp brief may be gone by now.
# resolve adapter (name/containment/route) -> validate the snapshot ->
# guard the snapshot -> execute the same snapshot.  No TOCTOU window because
# validate, guard, and execute all operate on the identical on-disk bytes.
# Identical contract to `pmctl dispatch run`, so the supervisor can never
# launch what pmctl would refuse, even from a hand-crafted run-spec.
declare -F pmctl_dispatch_resolve_adapter >/dev/null || _die "pmctl-dispatch lib unavailable"
adapter_path="$(pmctl_dispatch_resolve_adapter "$REPO_ROOT" "$spec_adapter")" \
  || _die "adapter resolution failed for $spec_adapter"

declare -F pmctl_dispatch_validate_brief >/dev/null || _die "pmctl_dispatch_validate_brief unavailable"
pmctl_dispatch_validate_brief "$REPO_ROOT" "$spec_brief_file" \
  || _die "brief validation failed: $spec_brief_file"

declare -F pmctl_guard_check >/dev/null || _die "guard unavailable (pmctl-guard not sourced)"
if ! pmctl_guard_check "$REPO_ROOT" --event pre-write --role executor --runtime "$spec_adapter" --file "$spec_brief_file"; then
  _die "guard denied dispatch for adapter $spec_adapter"
fi

# ── Rebuild the adapter forward args from trusted scalars + native passthrough ─
# --cd / --brief-file come ONLY from the validated scalars, so the brief and work
# dir the adapter runs are exactly the ones guarded and validated above.
forward=(--cd "$spec_cd_arg" --brief-file "$spec_brief_file")
forward+=(${native[@]+"${native[@]}"})

# ── Run the shared post-preflight tail ──────────────────────────────────────
declare -F pmctl_dispatch_execute_tail >/dev/null || _die "pmctl_dispatch_execute_tail unavailable"
_execute_rc=0
PMCTL_DISPATCH_INITIAL_STATE_WRITTEN="$spec_initial_state_written" \
  pmctl_dispatch_execute_tail "$REPO_ROOT" "$spec_work_dir" "$spec_adapter" "$adapter_path" \
  "$spec_run_id" "$spec_model" "$spec_brief_file" "$spec_created_ts" "$spec_print_cmd" \
  "${forward[@]}" || _execute_rc=$?

# The terminal dispatch record is a human-readable observability artifact; pmctl
# dispatch wait resolves from the supervisor sentinel written below, NOT from this
# record. Ensure a record always exists when the supervisor exits so that humans
# inspecting .dispatch-results/ can see what happened, regardless of outcome.
# This covers both the error path (adapter failed before writing a record) and
# the rare case where execute_tail succeeded but the soft record write silently
# failed (e.g. filesystem full or permissions on .dispatch-results/).
if ! dispatch_record_read_state "$spec_work_dir" "$spec_run_id" >/dev/null 2>&1; then
  _fallback_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  _fallback_state="$( [[ "$_execute_rc" -eq 0 ]] && printf 'ok' || printf 'failed' )"
  dispatch_record_write "$spec_run_id" "" "${spec_adapter:-}" "${spec_model:-}" \
    "${spec_brief_file:-}" "$spec_work_dir" "$_execute_rc" "$_fallback_state" \
    "supervisor fallback record (execute_tail rc=$_execute_rc; original record write missed)" \
    "" "" "" "${spec_created_ts:-}" "$_fallback_ts" 2>/dev/null \
    || printf 'dispatch-supervisor: WARN: fallback record write also failed for %s\n' "$spec_run_id" >&2
fi

# Write the authoritative supervisor sentinel to /tmp before exiting. This
# sentinel is the only signal pmctl dispatch wait trusts. Its path includes the
# nonce captured at startup (now unset from env), so an executor that read the
# workspace run-spec cannot derive the correct path and cannot forge completion.
# The sentinel records the real execute_tail exit code.
_finished_state="$( [[ "$_execute_rc" -eq 0 ]] && printf 'ok' || printf 'failed' )"
_write_sentinel "$_finished_state" "$_execute_rc"

# Best-effort cleanup of the durable brief snapshot now that the adapter has
# finished. The snapshot at spec_brief_file (/tmp/brief-<run_id>.md) was
# created by the parent before returning the run_id; it is no longer needed
# once the supervisor exits and a terminal record exists. Only delete the
# expected parent-created path; a tampered run-spec cannot delete other files.
if [[ "${spec_brief_file:-}" == "/tmp/brief-${spec_run_id}.md" ]]; then
  rm -f "$spec_brief_file" 2>/dev/null || true
fi

exit "$_execute_rc"
