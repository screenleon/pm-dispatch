#!/usr/bin/env bash
# opencode-dispatch (adapters/opencode/dispatch.sh)
#
# Thin opencode executor adapter, symmetric to adapters/codex/dispatch.sh and
# adapters/claude/dispatch.sh. Invokes headless `opencode run` as an
# independent subprocess driven by `pmctl dispatch run --adapter opencode`.
#
# Key differences from codex/claude adapters:
#   - Prompt is delivered as a CLI argument (opencode does not read stdin)
#   - Format flag is --format json (JSONL event stream, one event per line)
#   - Terminal event: step_finish (opencode may exit before emitting it —
#     known upstream bug; missing event → post-verify fails closed, correct)
#   - Exit code 0 even on API errors (upstream bug); dispatch.sh compensates
#     by scanning JSONL for session.error events after every run
#   - Model fallback chain: when --model is not specified, models are tried
#     in the order declared in fallback_chain (adapter.yaml); first success
#     breaks the loop. Per-attempt timeout = total / chain-length (min 120s)
#   - Permission model: only --dangerously-skip-permissions exists as a CLI
#     flag; fine-grained control is user's responsibility via opencode.json
#
# Usage:
#   dispatch.sh --cd <dir> [--model <m>] [--isolation <level>]
#               [--timeout <seconds>] [--print-cmd] --brief-file <path>
#
# --print-cmd prints the resolved model and exits 0 (no opencode invocation).
#
# Outputs (executor-agnostic contract — only latest.last is load-bearing):
#   .agent-trace/opencode-<ts>.jsonl   full JSONL event stream (opencode stdout)
#   .agent-trace/opencode-<ts>.last    final agent message (from step_finish)
#   .agent-trace/opencode-<ts>.stderr  wrapper banner + opencode stderr
#   .agent-trace/latest.{jsonl,last,stderr}  symlinks → most recent

set -euo pipefail

# Self-snapshot to avoid mid-flight modification when a dispatched opencode
# session edits this script (e.g. when the dispatch target is pm-dispatch
# itself). Bash reads scripts incrementally; rewriting the on-disk file under
# a running interpreter can corrupt the next read. Re-exec from a /tmp copy.
if ! [[ "${BASH_SOURCE[0]}" =~ /opencode-dispatch\.[A-Za-z0-9]{6}/opencode-dispatch\.sh$ ]]; then
  __oc_dispatch_snapshot_dir="$(mktemp -d -t opencode-dispatch.XXXXXX)"
  __oc_dispatch_snapshot="$__oc_dispatch_snapshot_dir/opencode-dispatch.sh"
  __oc_dispatch_real="${BASH_SOURCE[0]}"
  while [[ -L "$__oc_dispatch_real" ]]; do
    __oc_dispatch_link_dir="$(cd -P -- "$(dirname "$__oc_dispatch_real")" && pwd)"
    __oc_dispatch_real="$(readlink "$__oc_dispatch_real")"
    [[ "$__oc_dispatch_real" == /* ]] || __oc_dispatch_real="$__oc_dispatch_link_dir/$__oc_dispatch_real"
  done
  __oc_dispatch_source_repo="$(cd -P -- "$(dirname "$__oc_dispatch_real")/../.." && pwd)"
  __oc_dispatch_alias_source="$__oc_dispatch_source_repo/share/opencode-model-aliases.tsv"
  __oc_dispatch_isolation_source="$__oc_dispatch_source_repo/adapters/opencode/isolation-map.yaml"
  __oc_dispatch_adapter_source="$__oc_dispatch_source_repo/adapters/opencode/adapter.yaml"
  cp -- "${BASH_SOURCE[0]}" "$__oc_dispatch_snapshot"
  [[ -r "$__oc_dispatch_alias_source" ]] && cp -- "$__oc_dispatch_alias_source" "$__oc_dispatch_snapshot_dir/opencode-model-aliases.tsv" || true
  if [[ -r "$__oc_dispatch_isolation_source" ]]; then
    mkdir -p -- "$__oc_dispatch_snapshot_dir/adapters/opencode"
    cp -- "$__oc_dispatch_isolation_source" "$__oc_dispatch_snapshot_dir/adapters/opencode/isolation-map.yaml"
  fi
  if [[ -r "$__oc_dispatch_adapter_source" ]]; then
    mkdir -p -- "$__oc_dispatch_snapshot_dir/adapters/opencode"
    cp -- "$__oc_dispatch_adapter_source" "$__oc_dispatch_snapshot_dir/adapters/opencode/adapter.yaml"
  fi
  mkdir -p -- "$__oc_dispatch_snapshot_dir/lib"
  [[ -r "$__oc_dispatch_source_repo/scripts/lib/state-writer.sh" ]] && \
    cp -- "$__oc_dispatch_source_repo/scripts/lib/state-writer.sh" "$__oc_dispatch_snapshot_dir/lib/state-writer.sh" || true
  [[ -r "$__oc_dispatch_source_repo/scripts/lib/state-paths.sh" ]] && \
    cp -- "$__oc_dispatch_source_repo/scripts/lib/state-paths.sh" "$__oc_dispatch_snapshot_dir/lib/state-paths.sh" || true
  [[ -r "$__oc_dispatch_source_repo/scripts/lib/portable.sh" ]] && \
    cp -- "$__oc_dispatch_source_repo/scripts/lib/portable.sh" "$__oc_dispatch_snapshot_dir/lib/portable.sh" || true
  [[ -r "$__oc_dispatch_source_repo/scripts/lib/model-aliases.sh" ]] && \
    cp -- "$__oc_dispatch_source_repo/scripts/lib/model-aliases.sh" "$__oc_dispatch_snapshot_dir/lib/model-aliases.sh" || true
  [[ -r "$__oc_dispatch_source_repo/scripts/lib/timeout-resolve.sh" ]] && \
    cp -- "$__oc_dispatch_source_repo/scripts/lib/timeout-resolve.sh" "$__oc_dispatch_snapshot_dir/lib/timeout-resolve.sh" || true
  chmod +x -- "$__oc_dispatch_snapshot"
  exec "$__oc_dispatch_snapshot" "$@"
fi
# Running from the snapshot copy — we own the directory, clean it up on exit.
__oc_dispatch_snapshot_dir="$(dirname "${BASH_SOURCE[0]}")"
trap 'rm -rf -- "$__oc_dispatch_snapshot_dir"' EXIT

WORK_DIR=""
MODEL=""
ISOLATION=""
SCRIPT_DIR="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT=""
BRIEF=""
BRIEF_FILE=""
PRINT_CMD=0
TRACE_DIR_OVERRIDE=""
NATIVE_FLAGS=()

# shellcheck source=scripts/lib/state-writer.sh
. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/model-aliases.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/timeout-resolve.sh"

# ── Model alias resolution ────────────────────────────────────────────────────
PM_OC_ALIAS_FILE="$SCRIPT_DIR/opencode-model-aliases.tsv"
[[ -f "$PM_OC_ALIAS_FILE" ]] || PM_OC_ALIAS_FILE="$SCRIPT_DIR/../../share/opencode-model-aliases.tsv"

_resolve_oc_model_alias() {
  local query_model="$1"
  [[ -f "$PM_OC_ALIAS_FILE" ]] || return 0
  ma_resolve_alias "$PM_OC_ALIAS_FILE" "$query_model" "opencode-dispatch" || return 0
  [[ "$MA_RESOLVE_MATCH" == "1" ]] && MODEL="$MA_RESOLVE_MODEL"
  return 0
}

# ── fallback_chain reader ─────────────────────────────────────────────────────
# Reads fallback_chain list from adapter.yaml into FALLBACK_CHAIN array.
FALLBACK_CHAIN=()
_read_fallback_chain() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local _in=0 _line
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    _line="${_line%$'\r'}"
    [[ "${_line:0:1}" == "#" ]] && continue
    if [[ "$_line" =~ ^fallback_chain:[[:space:]]*$ ]]; then
      _in=1; continue
    fi
    [[ "$_in" -eq 0 ]] && continue
    # Non-indented non-list line ends the block
    if [[ ! "$_line" =~ ^[[:space:]] ]]; then
      _in=0; continue
    fi
    # YAML list item: "  - value"
    if [[ "$_line" =~ ^[[:space:]]+-[[:space:]]+(.+)[[:space:]]*$ ]]; then
      local _entry="${BASH_REMATCH[1]}"
      # Strip optional inline YAML quotes
      _entry="${_entry#\'}"; _entry="${_entry%\'}"; _entry="${_entry#\"}"; _entry="${_entry%\"}"
      FALLBACK_CHAIN+=("$_entry")
    fi
  done < "$file"
}

_ADAPTER_YAML="$SCRIPT_DIR/adapters/opencode/adapter.yaml"
[[ -f "$_ADAPTER_YAML" ]] || _ADAPTER_YAML="$SCRIPT_DIR/adapter.yaml"
_read_fallback_chain "$_ADAPTER_YAML"

# ── Isolation-level → native_flags ───────────────────────────────────────────
_resolve_isolation() {
  local level="$1"
  local map="$SCRIPT_DIR/adapters/opencode/isolation-map.yaml"
  [[ -f "$map" ]] || map="$SCRIPT_DIR/../adapters/opencode/isolation-map.yaml"
  [[ -f "$map" ]] || map="$SCRIPT_DIR/isolation-map.yaml"
  if [[ ! -f "$map" ]]; then
    printf 'opencode-dispatch: error: adapters/opencode/isolation-map.yaml not found\n' >&2
    return 1
  fi
  local _in=0 _found=0 _line _cur
  NATIVE_FLAGS=()
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    _line="${_line%$'\r'}"
    if [[ "$_line" =~ ^[[:space:]]{2}([a-z-]+):[[:space:]]*$ ]]; then
      _cur="${BASH_REMATCH[1]}"
      if [[ "$_cur" == "$level" ]]; then
        _in=1; _found=1
      else
        _in=0
      fi
      continue
    fi
    [[ "$_in" -eq 0 ]] && continue
    # native_flags list item: "      - '--flag'" or '      - "--flag"'
    if [[ "$_line" =~ ^[[:space:]]+-[[:space:]]+\'(.+)\'[[:space:]]*$ ]]; then
      NATIVE_FLAGS+=("${BASH_REMATCH[1]}")
    elif [[ "$_line" =~ ^[[:space:]]+-[[:space:]]+\"(.+)\"[[:space:]]*$ ]]; then
      NATIVE_FLAGS+=("${BASH_REMATCH[1]}")
    fi
  done < "$map"
  # An empty NATIVE_FLAGS is valid for workspace-write (opencode's default behavior).
  # Fail closed when the level is not in isolation-map.yaml — unsupported levels
  # (read-only, workspace-network, sandboxed) are intentionally absent because
  # opencode has no CLI mechanism to enforce them.
  if [[ "$_found" -eq 0 ]]; then
    printf 'opencode-dispatch: error: isolation level %q is not supported by the opencode adapter (no CLI enforcement); use none or workspace-write\n' "$level" >&2
    return 1
  fi
  return 0
}

# ── Timeout defaults ──────────────────────────────────────────────────────────
tr_resolve_timeout "" "OPENCODE_DISPATCH_TIMEOUT" "PM_CFG_TIMEOUT" "1200"
TIMEOUT="$TR_RESOLVED_TIMEOUT"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd)        WORK_DIR="$2"; shift 2;;
    --model)     MODEL="$2"; shift 2;;
    --isolation) ISOLATION="$2"; shift 2;;
    --timeout)   TIMEOUT="$2"; shift 2;;
    --print-cmd) PRINT_CMD=1; shift;;
    --brief-file) BRIEF_FILE="$2"; shift 2;;
    --trace-dir) TRACE_DIR_OVERRIDE="$2"; shift 2;;
    # Codex/claude-only flags: accepted but not supported; warn so callers notice.
    --sandbox|--approval)
      printf 'opencode-dispatch: warning: %s is not supported by the opencode adapter and will be ignored\n' "$1" >&2
      shift 2;;
    --skip-git-check) shift;;
    -h|--help)
      sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

[[ -z "$WORK_DIR" ]] && { echo "Error: --cd <dir> is required" >&2; exit 2; }
[[ ! -d "$WORK_DIR" ]] && { echo "Error: working dir not found: $WORK_DIR" >&2; exit 2; }
if [[ -n "$BRIEF_FILE" ]]; then
  [[ ! -f "$BRIEF_FILE" || ! -r "$BRIEF_FILE" ]] && { echo "Error: brief file not found or not readable: $BRIEF_FILE" >&2; exit 2; }
  BRIEF="$(<"$BRIEF_FILE")"
fi
[[ -z "$BRIEF" && "$PRINT_CMD" -ne 1 ]] && { echo "Error: brief is required; pass --brief-file <path>" >&2; exit 2; }
! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] && { echo "Error: --timeout must be a non-negative integer (got: $TIMEOUT)" >&2; exit 2; }

# ── Isolation resolution ──────────────────────────────────────────────────────
if [[ -n "$ISOLATION" ]]; then
  _resolve_isolation "$ISOLATION" || exit 2
fi

# ── Model resolution ──────────────────────────────────────────────────────────
# If --model given: resolve alias, use only that model (no fallback).
# If not given: check PM_CFG_DEFAULT_MODEL, otherwise use fallback_chain.
MODELS_TO_TRY=()
if [[ -n "$MODEL" ]]; then
  _resolve_oc_model_alias "$MODEL"
  MODELS_TO_TRY=("$MODEL")
elif [[ -n "${PM_CFG_DEFAULT_MODEL:-}" ]]; then
  MODEL="${PM_CFG_DEFAULT_MODEL}"
  _resolve_oc_model_alias "$MODEL"
  MODELS_TO_TRY=("$MODEL")
elif [[ ${#FALLBACK_CHAIN[@]} -gt 0 ]]; then
  MODELS_TO_TRY=("${FALLBACK_CHAIN[@]}")
else
  # No fallback_chain in manifest and no --model: fail loudly
  echo "Error: no --model specified and fallback_chain is empty in adapter.yaml" >&2
  exit 2
fi

MODEL_DISPLAY="${MODELS_TO_TRY[0]}"
[[ ${#MODELS_TO_TRY[@]} -gt 1 ]] && MODEL_DISPLAY="${MODELS_TO_TRY[*]} (fallback chain)"

TS=$(date +%Y%m%d-%H%M%S)-$$
LAST="/dev/null"
STDERR_LOG="/dev/null"
TRACE="<print-only>"
TRACE_DIR=""
if [[ "$PRINT_CMD" -ne 1 ]]; then
  # Trace output location: --trace-dir flag > PM_DISPATCH_TRACE_DIR env > legacy
  # in-repo $WORK_DIR/.agent-trace (default UNCHANGED). Precedence + absolute-path
  # validation live in sw_resolve_trace_dir (scripts/lib/state-paths.sh), sourced
  # via state-writer.sh above and copied into the snapshot lib dir. Resolved only
  # when trace is actually written (--print-cmd writes none, so it needs no lib).
  if ! declare -F sw_resolve_trace_dir >/dev/null 2>&1; then
    echo "Error: trace-path helper unavailable (state-paths.sh not loaded)" >&2
    exit 2
  fi
  TRACE_DIR="$(sw_resolve_trace_dir "$TRACE_DIR_OVERRIDE" "$WORK_DIR/.agent-trace")" || exit 2
  mkdir -p "$TRACE_DIR"
  TRACE="$TRACE_DIR/opencode-$TS.jsonl"
  LAST="$TRACE_DIR/opencode-$TS.last"
  STDERR_LOG="$TRACE_DIR/opencode-$TS.stderr"
fi

if [[ "$PRINT_CMD" -eq 1 ]]; then
  echo "MODELS_TO_TRY=${MODELS_TO_TRY[*]}"
  echo "NATIVE_FLAGS=${NATIVE_FLAGS[*]:-}"
  exit 0
fi

# ── latest.* helpers ──────────────────────────────────────────────────────────
_refresh_latest_pointers() {
  ln -sfn "opencode-$TS.jsonl"   "$TRACE_DIR/latest.jsonl"  2>/dev/null || true
  ln -sfn "opencode-$TS.last"    "$TRACE_DIR/latest.last"   2>/dev/null || true
  ln -sfn "opencode-$TS.stderr"  "$TRACE_DIR/latest.stderr" 2>/dev/null || true
}

# ── JSONL health checks ───────────────────────────────────────────────────────
# opencode exits 0 even on API errors; scan JSONL to compensate.
#
# _trace_slice: emit only the bytes from $offset onward so health checks are
# scoped to the current fallback attempt rather than the cumulative trace.
_trace_slice() {
  local trace="$1" offset="${2:-0}"
  if [[ "$offset" -gt 0 ]]; then
    tail -c +"$((offset + 1))" "$trace"
  else
    cat "$trace"
  fi
}

_has_terminal_event() {
  local trace="$1" offset="${2:-0}"
  [[ -s "$trace" ]] || return 1
  # opencode writes both human-readable error logs and JSONL to stdout;
  # grep for lines starting with '{' to skip non-JSON log lines before jq.
  _trace_slice "$trace" "$offset" | grep '^{' 2>/dev/null | jq -e 'select(.type == "step_finish")' >/dev/null 2>&1
}

_has_session_error() {
  local trace="$1" offset="${2:-0}"
  [[ -s "$trace" ]] || return 1
  _trace_slice "$trace" "$offset" | grep '^{' 2>/dev/null | jq -e 'select(.type == "session.error")' >/dev/null 2>&1
}

# ── Wrapper banner ────────────────────────────────────────────────────────────
{
  echo "[$(date -Is)] opencode-dispatch starting"
  echo "  cwd:      $WORK_DIR"
  echo "  models:   $MODEL_DISPLAY"
  [[ -n "$ISOLATION" ]] && echo "  isolation: $ISOLATION → flags: ${NATIVE_FLAGS[*]:-<none>}"
  echo "  timeout:  ${TIMEOUT}s"
  echo "  trace:    $TRACE"
  [[ -n "$BRIEF_FILE" ]] && echo "  brief:    $BRIEF_FILE (file)"
} | tee -a "$STDERR_LOG" >&2

_refresh_latest_pointers

# ── Per-attempt timeout ───────────────────────────────────────────────────────
# Distribute budget evenly across the fallback chain so a single hanging model
# cannot exhaust the full timeout. Floor at 120s per attempt.
# Reject positive totals below 120s: they cannot complete even one attempt and
# would silently run far longer than requested after the floor is applied.
_chain_len=${#MODELS_TO_TRY[@]}
# TIMEOUT=0 means no limit; skip all budget math for zero.
_attempt_timeout=0
if [[ "$TIMEOUT" -gt 0 ]]; then
  if [[ "$TIMEOUT" -lt 120 ]]; then
    printf '[%s] opencode-dispatch: --timeout %ds is below the 120s per-attempt minimum; use 0 (no limit) or >= 120\n' \
      "$(date -Is)" "$TIMEOUT" | tee -a "$STDERR_LOG" >&2
    exit 2
  fi
  _attempt_timeout=$(( TIMEOUT / _chain_len ))
  if [[ "$_attempt_timeout" -lt 120 ]]; then
    _attempt_timeout=120
    printf '[%s] opencode-dispatch: per-attempt timeout floored at 120s (requested %ds across %d models); total may exceed --timeout\n' \
      "$(date -Is)" "$TIMEOUT" "$_chain_len" | tee -a "$STDERR_LOG" >&2
  fi
fi

# ── Fallback dispatch loop ────────────────────────────────────────────────────
EXIT=1
USED_MODEL=""
_attempt=0

for _model in "${MODELS_TO_TRY[@]}"; do
  (( _attempt++ )) || true

  # Record trace byte-offset before this attempt so health checks are scoped
  # to only the current attempt's output, not the cumulative trace.
  # Guard with -f to avoid a false stderr line when the trace file doesn't
  # exist yet (first attempt before any opencode run has written to it).
  _trace_offset=0
  [[ -f "$TRACE" ]] && _trace_offset=$(wc -c < "$TRACE" 2>/dev/null || echo 0)

  {
    echo "[$(date -Is)] opencode-dispatch attempt ${_attempt}/${_chain_len}: model=${_model} timeout=${_attempt_timeout}s"
  } | tee -a "$STDERR_LOG" >&2

  # Build command array
  _CMD=(opencode run
    --dir "$WORK_DIR"
    --format json
    --model "$_model"
  )
  for _flag in "${NATIVE_FLAGS[@]:-}"; do
    [[ -n "$_flag" ]] && _CMD+=("$_flag")
  done
  # Brief as final positional argument (opencode does not read stdin)
  _CMD+=("$BRIEF")

  set +e
  if [[ "$_attempt_timeout" -gt 0 ]]; then
    # Redirect stdin from /dev/null: opencode reads stdin by default and will
    # hang indefinitely when stdin is connected to a socket (non-interactive
    # context). This must be the first redirect so opencode sees no stdin.
    timeout --foreground --kill-after=15 "$_attempt_timeout" "${_CMD[@]}" </dev/null >>"$TRACE" 2>>"$STDERR_LOG"
  else
    "${_CMD[@]}" </dev/null >>"$TRACE" 2>>"$STDERR_LOG"
  fi
  _RUN_EXIT=$?
  set -e

  if [[ "$_RUN_EXIT" -eq 124 ]]; then
    printf '[%s] opencode-dispatch: attempt %d timed out after %ds, trying next model\n' \
      "$(date -Is)" "$_attempt" "$_attempt_timeout" | tee -a "$STDERR_LOG" >&2
    continue
  fi

  # Compensate for opencode exit-0-on-error bug
  if _has_session_error "$TRACE" "$_trace_offset"; then
    printf '[%s] opencode-dispatch: attempt %d detected session.error in trace, trying next model\n' \
      "$(date -Is)" "$_attempt" | tee -a "$STDERR_LOG" >&2
    continue
  fi

  if [[ "$_RUN_EXIT" -ne 0 ]]; then
    printf '[%s] opencode-dispatch: attempt %d exited %d, trying next model\n' \
      "$(date -Is)" "$_attempt" "$_RUN_EXIT" | tee -a "$STDERR_LOG" >&2
    continue
  fi

  if ! _has_terminal_event "$TRACE" "$_trace_offset"; then
    printf '[%s] opencode-dispatch: attempt %d missing step_finish event (upstream bug), trying next model\n' \
      "$(date -Is)" "$_attempt" | tee -a "$STDERR_LOG" >&2
    continue
  fi

  # Success
  EXIT=0
  USED_MODEL="$_model"
  printf '[%s] opencode-dispatch: attempt %d succeeded with model %s\n' \
    "$(date -Is)" "$_attempt" "$_model" | tee -a "$STDERR_LOG" >&2
  break
done

# ── Extract .last from accumulated text events ────────────────────────────────
# opencode JSONL structure (confirmed empirically):
#   {"type":"text","part":{"text":"<response>"},...}  -- one or more per turn
#   {"type":"step_finish","part":{"reason":"stop","tokens":{...}},...}  -- terminal
# The response text lives in `text` type events (.part.text), NOT in step_finish.
# Collect all text events' .part.text and join them; fallback to last JSONL line.
#
# On success, scope to the winning attempt's byte range to prevent failed-attempt
# text from contaminating the final artifact. On total failure use the full trace
# for best-effort forensic extraction.
if [[ -s "$TRACE" ]]; then
  _extract_offset=0
  [[ "$EXIT" -eq 0 ]] && _extract_offset="${_trace_offset:-0}"
  if ! _trace_slice "$TRACE" "$_extract_offset" | grep '^{' 2>/dev/null | \
       jq -re '[select(.type == "text") | .part.text // empty] | join("")' \
       > "$LAST" 2>/dev/null \
     || [[ ! -s "$LAST" ]]; then
    # Fallback: last non-empty JSON line of the scoped slice
    _trace_slice "$TRACE" "$_extract_offset" | grep '^{' 2>/dev/null | tail -1 > "$LAST" || true
  fi
fi

# ── Re-point latest.* now that per-run files exist ────────────────────────────
_refresh_latest_pointers

# ── Closing banner ────────────────────────────────────────────────────────────
{
  echo "[$(date -Is)] opencode-dispatch finished"
  echo "  exit:     $EXIT"
  echo "  model:    ${USED_MODEL:-<none succeeded>}"
  if [[ "$EXIT" -ne 0 && "$_attempt" -ge "$_chain_len" ]]; then
    echo "  note:     all ${_chain_len} models in fallback chain failed"
  fi
} | tee -a "$STDERR_LOG" >&2

echo "---"
echo "trace:  $TRACE"
echo "last:   $LAST"
echo "stderr: $STDERR_LOG"
echo "exit:   $EXIT"
echo "model:  ${USED_MODEL:-<none>}"
echo "---"
if [[ -s "$LAST" ]]; then
  echo "=== final message ==="
  cat "$LAST"
fi

exit $EXIT
