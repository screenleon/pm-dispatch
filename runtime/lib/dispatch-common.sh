#!/usr/bin/env bash
# dispatch-common.sh — shared init helpers for adapter dispatch.sh scripts.
# Sourced by adapters; do NOT set -euo pipefail here (callers carry their own flags).

# dc_snapshot_copy_libs <snapshot_dir> <repo_root>
# Copy all shared lib files needed by dispatch adapters into snapshot_dir/lib/.
# Call this from within the self-snapshot block (initial run only) before exec.
dc_snapshot_copy_libs() {
  local snapshot_dir="$1" repo_root="$2"
  mkdir -p -- "$snapshot_dir/lib"
  local _lib
  for _lib in identifier-policy.sh state-writer.sh state-paths.sh portable.sh model-aliases.sh \
              reasoning-effort.sh timeout-resolve.sh dispatch-common.sh; do
    if [[ -r "$repo_root/runtime/lib/$_lib" ]]; then
      cp -- "$repo_root/runtime/lib/$_lib" "$snapshot_dir/lib/$_lib" || true
    fi
  done
}

# dc_validate_args <work_dir> <brief_file> <print_cmd> <timeout>
# Validates common dispatch args. Sets DC_BRIEF to the brief contents on success.
# Returns 2 on validation failure (caller should `|| exit 2`).
dc_validate_args() {
  local work_dir="$1" brief_file="$2" print_cmd="$3" timeout="$4"
  DC_BRIEF=""
  if [[ -z "$work_dir" ]]; then
    echo "Error: --cd <dir> is required" >&2; return 2
  fi
  if [[ ! -d "$work_dir" ]]; then
    echo "Error: working dir not found: $work_dir" >&2; return 2
  fi
  if [[ -n "$brief_file" ]]; then
    if [[ ! -f "$brief_file" || ! -r "$brief_file" ]]; then
      echo "Error: brief file not found or not readable: $brief_file" >&2; return 2
    fi
    DC_BRIEF="$(<"$brief_file")"
  fi
  if [[ -z "$DC_BRIEF" && "$print_cmd" -ne 1 ]]; then
    echo "Error: brief is required; pass --brief-file <path>" >&2; return 2
  fi
  if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
    echo "Error: --timeout must be a non-negative integer (got: $timeout)" >&2; return 2
  fi
  return 0
}

# dc_setup_trace_dir <override> <work_dir> <prefix> <ts>
# Resolves and creates the trace directory for the current run.
# Sets DC_TRACE_DIR, DC_TRACE, DC_LAST, DC_STDERR_LOG.
# Returns 2 if sw_resolve_trace_dir is unavailable or fails (caller should `|| exit 2`).
dc_setup_trace_dir() {
  local override="$1" work_dir="$2" prefix="$3" ts="$4"
  DC_TRACE_DIR="" DC_TRACE="" DC_LAST="" DC_STDERR_LOG=""
  if ! declare -F sw_resolve_trace_dir >/dev/null 2>&1; then
    echo "Error: trace-path helper unavailable (state-paths.sh not loaded)" >&2; return 2
  fi
  DC_TRACE_DIR="$(sw_resolve_trace_dir "$override" "$work_dir/.agent-trace")" || return 2
  mkdir -p "$DC_TRACE_DIR"
  # shellcheck disable=SC2034
  DC_TRACE="$DC_TRACE_DIR/$prefix-$ts.jsonl"
  # shellcheck disable=SC2034
  DC_LAST="$DC_TRACE_DIR/$prefix-$ts.last"
  # shellcheck disable=SC2034
  DC_STDERR_LOG="$DC_TRACE_DIR/$prefix-$ts.stderr"
  return 0
}

# dc_refresh_latest_pointers <prefix> <trace_dir> <ts>
# Updates latest.{jsonl,last,stderr} convenience symlinks. Best-effort; never aborts.
dc_refresh_latest_pointers() {
  local prefix="$1" trace_dir="$2" ts="$3"
  ln -sfn "$prefix-$ts.jsonl"  "$trace_dir/latest.jsonl"  2>/dev/null || true
  ln -sfn "$prefix-$ts.last"   "$trace_dir/latest.last"   2>/dev/null || true
  ln -sfn "$prefix-$ts.stderr" "$trace_dir/latest.stderr" 2>/dev/null || true
}

# dc_print_footer <trace> <last> <stderr_log> <exit_code> <model>
# Prints the standard executor footer block and cats <last> when non-empty.
# Does NOT call exit — callers must exit themselves.
dc_print_footer() {
  local trace="$1" last="$2" stderr_log="$3" exit_code="$4" model="$5"
  echo "---"
  echo "trace:  $trace"
  echo "last:   $last"
  echo "stderr: $stderr_log"
  echo "exit:   $exit_code"
  echo "model:  $model"
  echo "---"
  if [[ -s "$last" ]]; then
    echo "=== final message ==="
    cat "$last"
  fi
}
