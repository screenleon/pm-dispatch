#!/usr/bin/env bash
# shellcheck disable=SC2034  # DC_* output globals are read by the sourcing adapter after each call
# dispatch-common.sh — shared init helpers for adapter dispatch.sh scripts.
# Sourced by adapters; do NOT set -euo pipefail here (callers carry their own flags).

# dc_snapshot_lib_names
# Print the canonical shared-library dependency set for built-in Adapter
# snapshots. Installer copy bundles consume this same inventory so bootstrap and
# self-snapshot dependencies cannot drift into two independently maintained
# lists.
dc_snapshot_lib_names() {
  printf '%s\n' \
    identifier-policy.sh \
    state-writer.sh \
    state-paths.sh \
    portable.sh \
    model-aliases.sh \
    reasoning-effort.sh \
    timeout-resolve.sh \
    dispatch-common.sh
}

# dc_installed_adapter_lib_names
# Print the complete library bundle required by an installed built-in Adapter.
# The first group is also used by detached self-snapshots; the final two files
# provide manifest/route authority before the Adapter entrypoint is launched.
dc_installed_adapter_lib_names() {
  dc_snapshot_lib_names
  printf '%s\n' runner-kind.sh adapter-manifest.sh
}

# dc_snapshot_copy_libs <snapshot_dir> <repo_root>
# Copy all shared lib files needed by dispatch adapters into snapshot_dir/lib/.
# Call this from within the self-snapshot block (initial run only) before exec.
dc_snapshot_copy_libs() {
  local snapshot_dir="$1" repo_root="$2"
  mkdir -p -- "$snapshot_dir/lib"
  local _lib
  while IFS= read -r _lib; do
    [[ -n "$_lib" ]] || continue
    if [[ -r "$repo_root/runtime/lib/$_lib" ]]; then
      cp -- "$repo_root/runtime/lib/$_lib" "$snapshot_dir/lib/$_lib" || true
    fi
  done < <(dc_snapshot_lib_names)
}

# dc_snapshot_copy_extras <snapshot_dir> <repo_root> <src_rel> <dst_rel> [<src_rel> <dst_rel> ...]
# Copy the per-adapter non-lib snapshot assets (model-alias tsv, isolation map,
# log-usage.sh, adapter.yaml) declared by the caller. Each pair is a repo-root-
# relative source and a snapshot-dir-relative destination. A source that is not
# readable is skipped silently (matches the historical `|| true` behavior); the
# destination's parent dir is created as needed. The list stays per-adapter data
# passed in by the caller so this shared helper never names an adapter.
dc_snapshot_copy_extras() {
  local snapshot_dir="$1" repo_root="$2"
  shift 2
  local src dst
  while [[ $# -ge 2 ]]; do
    src="$1" dst="$2"; shift 2
    [[ -r "$repo_root/$src" ]] || continue
    mkdir -p -- "$snapshot_dir/$(dirname -- "$dst")"
    cp -- "$repo_root/$src" "$snapshot_dir/$dst" || true
  done
}

# dc_run_timestamp
# Sets DC_TS to the canonical per-run trace timestamp: YYYYMMDD-HHMMSS-<pid>.
# One definition instead of four identical `TS=$(date +%Y%m%d-%H%M%S)-$$` copies.
dc_run_timestamp() {
  DC_TS="$(date +%Y%m%d-%H%M%S)-$$"
}

# dc_resolve_sibling_file <destvar> <candidate> [<candidate> ...]
# Set <destvar> to the first candidate that exists as a regular file; return 0.
# If none exist, set <destvar> to the LAST candidate (its expected location) and
# return 1 — quietly, with no output. The caller decides whether "missing" is an
# error and prints its own adapter-labelled diagnostic (isolation map: required;
# model-alias tsv: optional, its resolver handles absence). Replaces the
# per-adapter 3-line `[[ -f ]] ||` walk. printf -v avoids a subshell so the
# caller's `set -e` stays intact.
dc_resolve_sibling_file() {
  local destvar="$1"
  shift
  local cand last=""
  for cand in "$@"; do
    last="$cand"
    if [[ -f "$cand" ]]; then
      printf -v "$destvar" '%s' "$cand"
      return 0
    fi
  done
  printf -v "$destvar" '%s' "$last"
  return 1
}

# dc_parse_common_flags "$@"
# Parse the flag set every adapter shares and hand the rest back untouched.
# Sets: DC_WORK_DIR DC_MODEL DC_ISOLATION DC_BRIEF_FILE DC_TRACE_DIR_OVERRIDE
#       (value or ""), DC_PRINT_CMD DC_HELP (1/0), DC_TIMEOUT (value or ""),
#       and the DC_RESIDUAL_ARGS array (every token not consumed here, in order,
#       including `--` and everything after it — codex's inline `-- <brief>` and
#       each adapter's native flags live there).
# Returns 2 when a recognised value-flag is missing its value.
dc_parse_common_flags() {
  DC_WORK_DIR="" DC_MODEL="" DC_ISOLATION="" DC_BRIEF_FILE="" DC_TRACE_DIR_OVERRIDE=""
  DC_TIMEOUT="" DC_PRINT_CMD=0 DC_HELP=0
  DC_RESIDUAL_ARGS=()
  local flag
  while [[ $# -gt 0 ]]; do
    flag="$1"
    case "$flag" in
      --cd|--model|--isolation|--timeout|--brief-file|--trace-dir)
        if [[ $# -lt 2 ]]; then
          printf 'dispatch: %s requires a value\n' "$flag" >&2
          return 2
        fi
        case "$flag" in
          --cd)         DC_WORK_DIR="$2";;
          --model)      DC_MODEL="$2";;
          --isolation)  DC_ISOLATION="$2";;
          --timeout)    DC_TIMEOUT="$2";;
          --brief-file) DC_BRIEF_FILE="$2";;
          --trace-dir)  DC_TRACE_DIR_OVERRIDE="$2";;
        esac
        shift 2;;
      --print-cmd) DC_PRINT_CMD=1; shift;;
      -h|--help)   DC_HELP=1; break;;
      --)          DC_RESIDUAL_ARGS+=("$@"); break;;
      *)           DC_RESIDUAL_ARGS+=("$1"); shift;;
    esac
  done
  return 0
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
  DC_TRACE="$DC_TRACE_DIR/$prefix-$ts.jsonl"
  DC_LAST="$DC_TRACE_DIR/$prefix-$ts.last"
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

# dc_print_footer <trace> <last> <stderr_log> <exit_code> <model> [fallback_used]
# Prints the standard executor footer block and cats <last> when non-empty.
# fallback_used is optional (only opencode's model fallback_chain sets it);
# the "fallback:" line is omitted entirely when empty, so pmctl-dispatch.sh's
# footer grep sees nothing to parse for adapters without a fallback concept.
# Does NOT call exit — callers must exit themselves.
dc_print_footer() {
  local trace="$1" last="$2" stderr_log="$3" exit_code="$4" model="$5" fallback_used="${6:-}"
  echo "---"
  echo "trace:  $trace"
  echo "last:   $last"
  echo "stderr: $stderr_log"
  echo "exit:   $exit_code"
  echo "model:  $model"
  [[ -n "$fallback_used" ]] && echo "fallback: $fallback_used"
  echo "---"
  if [[ -s "$last" ]]; then
    echo "=== final message ==="
    cat "$last"
  fi
}
