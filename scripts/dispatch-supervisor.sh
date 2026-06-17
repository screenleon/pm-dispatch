#!/usr/bin/env bash
# Detached-supervised dispatch executor (CC-391 Phase 7c-2a).
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
# 7c-2a invokes the supervisor SYNCHRONOUSLY from pmctl_dispatch_run, so detached
# dispatch is behavior-equivalent to foreground. True setsid/nohup detachment,
# immediate run_id return, and `pmctl dispatch wait <run_id>` arrive in 7c-2b.
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

_die() {
  printf 'dispatch-supervisor: %s\n' "$*" >&2
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

# ── Read run-spec ───────────────────────────────────────────────────────────
# Scalars are key=value (first '=' splits, so values may contain '=' or spaces);
# forward args follow the `forward_b64:` marker, one base64 token per line. The
# supervisor never word-splits or re-parses user-influenced tokens.
spec_schema="" spec_run_id="" spec_adapter="" spec_work_dir=""
spec_brief_file="" spec_model="" spec_created_ts="" spec_print_cmd=""
forward=()
in_forward=0
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$in_forward" -eq 1 ]]; then
    [[ -z "$line" ]] && continue
    arg="$(printf '%s' "$line" | base64 -d 2>/dev/null)" || _die "malformed base64 forward arg in run-spec"
    forward+=("$arg")
    continue
  fi
  case "$line" in
    forward_b64:) in_forward=1 ;;
    schema_version=*) spec_schema="${line#schema_version=}" ;;
    run_id=*)       spec_run_id="${line#run_id=}" ;;
    adapter=*)      spec_adapter="${line#adapter=}" ;;
    work_dir=*)     spec_work_dir="${line#work_dir=}" ;;
    brief_file=*)   spec_brief_file="${line#brief_file=}" ;;
    model=*)        spec_model="${line#model=}" ;;
    created_ts=*)   spec_created_ts="${line#created_ts=}" ;;
    print_cmd=*)    spec_print_cmd="${line#print_cmd=}" ;;
    *) : ;;  # ignore unknown keys (forward-compatible)
  esac
done < "$run_spec"

# ── Validate the spec's own fields (independent of pmctl) ────────────────────
[[ "$spec_schema" == "1" ]] || _die "unsupported run-spec schema_version: ${spec_schema:-<empty>}"
[[ "$spec_run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]] || _die "invalid run_id in run-spec: ${spec_run_id:-<empty>}"
[[ -n "$spec_adapter" ]] || _die "missing adapter in run-spec"
[[ -n "$spec_work_dir" ]] || _die "missing work_dir in run-spec"
[[ -n "$spec_brief_file" ]] || _die "missing brief_file in run-spec"
case "$spec_print_cmd" in 0|1) : ;; *) _die "invalid print_cmd in run-spec: ${spec_print_cmd:-<empty>}" ;; esac

# ── Re-run the security preflight (defense in depth — not a bypass door) ─────
declare -F pmctl_dispatch_resolve_adapter >/dev/null || _die "pmctl-dispatch lib unavailable"
adapter_path="$(pmctl_dispatch_resolve_adapter "$REPO_ROOT" "$spec_adapter")" || exit 2

declare -F pmctl_guard_check >/dev/null || _die "guard unavailable (pmctl-guard not sourced)"
if ! pmctl_guard_check "$REPO_ROOT" --event pre-write --role executor --runtime "$spec_adapter" --file "$spec_brief_file"; then
  _die "guard denied dispatch for adapter $spec_adapter"
fi

# ── Run the shared post-preflight tail ──────────────────────────────────────
declare -F pmctl_dispatch_execute_tail >/dev/null || _die "pmctl_dispatch_execute_tail unavailable"
pmctl_dispatch_execute_tail "$REPO_ROOT" "$spec_work_dir" "$spec_adapter" "$adapter_path" \
  "$spec_run_id" "$spec_model" "$spec_brief_file" "$spec_created_ts" "$spec_print_cmd" \
  ${forward[@]+"${forward[@]}"}
exit $?
