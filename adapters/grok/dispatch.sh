#!/usr/bin/env bash
# grok-dispatch (adapters/grok/dispatch.sh)
#
# Thin grok executor adapter, symmetric to adapters/claude/dispatch.sh and
# adapters/opencode/dispatch.sh. Invokes headless `grok --prompt-file` as an
# independent subprocess driven by `pmctl dispatch run --adapter grok`.
#
# Key differences from the claude adapter:
#   - Prompt is delivered via --prompt-file (not stdin)
#   - Format flag is --output-format streaming-json
#   - Terminal event: end (JSONL .type == "end")
#   - Dual isolation: --sandbox <profile> AND --permission-mode <mode>
#     via adapters/grok/isolation-map.yaml
#   - .last is the concatenation of type=="text" .data chunks
#
# Usage:
#   dispatch.sh --cd <dir> [--model <m>] [--effort <low|medium|high>]
#               [--isolation <level>]
#               [--timeout <seconds>] [--print-cmd] --brief-file <path>
#
# --print-cmd prints the final CMD array (`CMD=${CMD[*]}`) and exits 0.
#
# --effort overrides the resolved model alias's own effort column; absent a
# flag or a valid alias value, the global default is `medium` (see
# runtime/lib/reasoning-effort.sh). Wired to grok's native --reasoning-effort.
#
# Isolation: --isolation <level> is translated to dual native flags via
# adapters/grok/isolation-map.yaml. Default (no --isolation) is
# sandbox=workspace + permission_mode=acceptEdits (workspace-write).
#
# Codex-only flags (--sandbox / --approval / --skip-git-check) are accepted and
# ignored as no-ops: the isolation map owns the grok-native --sandbox value so
# a raw codex-forwarded --sandbox never double-binds.
#
# Outputs (the contract pmctl/post-verify read — only latest.last is load-bearing):
#   .agent-trace/grok-<ts>.jsonl   full streaming-json JSONL event stream
#   .agent-trace/grok-<ts>.last    final agent message (joined text chunks)
#   .agent-trace/grok-<ts>.stderr  wrapper banner + grok stderr (forensic log)
#   .agent-trace/latest.{jsonl,last,stderr}  symlinks → most recent

set -euo pipefail

# Self-snapshot to avoid mid-flight modification when a dispatched grok session
# edits this script (e.g. when the dispatch target is pm-dispatch itself). Bash
# reads scripts incrementally; rewriting the on-disk file under a running
# interpreter can corrupt the next read. Re-exec from a /tmp copy so the on-disk
# file is decoupled from the running process. Trigger keys on BASH_SOURCE shape
# (not env), so a polluted environment cannot bypass the protection.
if ! [[ "${BASH_SOURCE[0]}" =~ /grok-dispatch\.[A-Za-z0-9]{6}/grok-dispatch\.sh$ ]]; then
  __grok_dispatch_snapshot_dir="$(mktemp -d -t grok-dispatch.XXXXXX)"
  __grok_dispatch_snapshot="$__grok_dispatch_snapshot_dir/grok-dispatch.sh"
  # Resolve through symlinks, then ascend two levels (adapters/grok → repo root).
  __grok_dispatch_real="${BASH_SOURCE[0]}"
  while [[ -L "$__grok_dispatch_real" ]]; do
    __grok_dispatch_link_dir="$(cd -P -- "$(dirname "$__grok_dispatch_real")" && pwd)"
    __grok_dispatch_real="$(readlink "$__grok_dispatch_real")"
    [[ "$__grok_dispatch_real" == /* ]] || __grok_dispatch_real="$__grok_dispatch_link_dir/$__grok_dispatch_real"
  done
  __grok_dispatch_source_repo="$(cd -P -- "$(dirname "$__grok_dispatch_real")/../.." && pwd)"
  __grok_dispatch_isolation_source="$__grok_dispatch_source_repo/adapters/grok/isolation-map.yaml"
  __grok_dispatch_alias_source="$__grok_dispatch_source_repo/share/grok-model-aliases.tsv"
  __grok_dispatch_usage_log_source="$__grok_dispatch_source_repo/ops/usage/log-usage.sh"
  cp -- "${BASH_SOURCE[0]}" "$__grok_dispatch_snapshot"
  [[ -r "$__grok_dispatch_usage_log_source" ]] && cp -- "$__grok_dispatch_usage_log_source" "$__grok_dispatch_snapshot_dir/log-usage.sh" || true
  if [[ -r "$__grok_dispatch_isolation_source" ]]; then
    mkdir -p -- "$__grok_dispatch_snapshot_dir/adapters/grok"
    cp -- "$__grok_dispatch_isolation_source" "$__grok_dispatch_snapshot_dir/adapters/grok/isolation-map.yaml"
  fi
  [[ -r "$__grok_dispatch_alias_source" ]] && cp -- "$__grok_dispatch_alias_source" "$__grok_dispatch_snapshot_dir/grok-model-aliases.tsv" || true
  # shellcheck disable=SC1091
  . "$__grok_dispatch_source_repo/runtime/lib/dispatch-common.sh"
  dc_snapshot_copy_libs "$__grok_dispatch_snapshot_dir" "$__grok_dispatch_source_repo"
  chmod +x -- "$__grok_dispatch_snapshot"
  exec "$__grok_dispatch_snapshot" "$@"
fi
# Running from the snapshot copy — we own the directory, clean it up on exit.
__grok_dispatch_snapshot_dir="$(dirname "${BASH_SOURCE[0]}")"
trap 'rm -rf -- "$__grok_dispatch_snapshot_dir"' EXIT

WORK_DIR=""
MODEL=""
EFFORT=""
ALIAS_EFFORT=""
DEFAULT_DISPATCH_MODEL="default"   # resolved via share/grok-model-aliases.tsv → grok-4.5
ISOLATION=""
SCRIPT_DIR="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT=""
BRIEF=""
BRIEF_FILE=""
PRINT_CMD=0
TRACE_DIR_OVERRIDE=""
SANDBOX="workspace"             # default = workspace-write sandbox profile
PERMISSION_MODE="acceptEdits"   # default = workspace-write permission mode

# shellcheck source=runtime/lib/state-writer.sh  # sourced for snapshot support only; pmctl owns state writes.
. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/model-aliases.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/reasoning-effort.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/timeout-resolve.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/dispatch-common.sh"

# Model alias resolution — share/grok-model-aliases.tsv (3-column).
PM_GROK_ALIAS_FILE="$SCRIPT_DIR/grok-model-aliases.tsv"
[[ -f "$PM_GROK_ALIAS_FILE" ]] || PM_GROK_ALIAS_FILE="$SCRIPT_DIR/../../share/grok-model-aliases.tsv"

_resolve_grok_model_alias() {
  local query_model="$1"
  [[ -f "$PM_GROK_ALIAS_FILE" ]] || return 0
  ma_resolve_alias "$PM_GROK_ALIAS_FILE" "$query_model" "grok-dispatch" || return 0
  if [[ "$MA_RESOLVE_MATCH" == "1" ]]; then
    MODEL="$MA_RESOLVE_MODEL"
    ALIAS_EFFORT="$MA_RESOLVE_EFFORT"
  fi
  return 0
}

# Resolve isolation_level → sandbox + permission_mode from isolation-map.yaml.
# Sets SANDBOX and PERMISSION_MODE on success; returns 1 on unknown level.
_resolve_isolation() {
  local level="$1"
  local map="$SCRIPT_DIR/adapters/grok/isolation-map.yaml"
  [[ -f "$map" ]] || map="$SCRIPT_DIR/../adapters/grok/isolation-map.yaml"
  [[ -f "$map" ]] || map="$SCRIPT_DIR/isolation-map.yaml"
  if [[ ! -f "$map" ]]; then
    printf 'grok-dispatch: error: adapters/grok/isolation-map.yaml not found (expected at %s)\n' "$map" >&2
    return 1
  fi
  local _sandbox="" _mode="" _in=0 _line _cur
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    _line="${_line%$'\r'}"
    if [[ "$_line" =~ ^[[:space:]]{2}([a-z-]+):[[:space:]]*$ ]]; then
      _cur="${BASH_REMATCH[1]}"
      [[ "$_cur" == "$level" ]] && _in=1 || _in=0
      continue
    fi
    [[ "$_in" -eq 0 ]] && continue
    if [[ "$_line" =~ ^[[:space:]]{4}sandbox:[[:space:]]*(.+)$ ]]; then
      _sandbox="${BASH_REMATCH[1]}"
      _sandbox="${_sandbox#\'}"; _sandbox="${_sandbox%\'}"; _sandbox="${_sandbox#\"}"; _sandbox="${_sandbox%\"}"
      continue
    fi
    if [[ "$_line" =~ ^[[:space:]]{4}permission_mode:[[:space:]]*(.+)$ ]]; then
      _mode="${BASH_REMATCH[1]}"
      _mode="${_mode#\'}"; _mode="${_mode%\'}"; _mode="${_mode#\"}"; _mode="${_mode%\"}"
      continue
    fi
  done < "$map"
  if [[ -z "$_sandbox" || -z "$_mode" ]]; then
    printf 'grok-dispatch: error: unknown isolation_level %q (not in adapters/grok/isolation-map.yaml)\n' "$level" >&2
    return 1
  fi
  SANDBOX="$_sandbox"
  PERMISSION_MODE="$_mode"
  return 0
}

tr_resolve_timeout "" "GROK_DISPATCH_TIMEOUT" "PM_CFG_TIMEOUT" "1200"
TIMEOUT="$TR_RESOLVED_TIMEOUT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --effort) EFFORT="$2"; shift 2;;
    --isolation) ISOLATION="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --print-cmd) PRINT_CMD=1; shift;;
    --brief-file) BRIEF_FILE="$2"; shift 2;;
    --trace-dir) TRACE_DIR_OVERRIDE="$2"; shift 2;;
    # Codex-only flags accepted as no-ops. Grok-native --sandbox is driven
    # exclusively by the isolation map so a raw codex-forwarded --sandbox
    # never double-binds.
    --sandbox) shift 2;;
    --approval) shift 2;;
    --skip-git-check) shift;;
    -h|--help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

dc_validate_args "$WORK_DIR" "$BRIEF_FILE" "$PRINT_CMD" "$TIMEOUT" || exit 2
BRIEF="$DC_BRIEF"

if [[ -n "$ISOLATION" ]]; then
  _resolve_isolation "$ISOLATION" || exit 2
fi

# Default model resolution — pin pm-dispatch's own default through the alias
# table so omitting --model always resolves to grok-4.5, decoupled from the
# grok CLI built-in default. Precedence: --model flag >
# PM_CFG_DEFAULT_MODEL > built-in `default` alias.
if [[ -z "$MODEL" ]]; then
  MODEL="${PM_CFG_DEFAULT_MODEL:-$DEFAULT_DISPATCH_MODEL}"
fi

# Resolve PM-facing alias before passing to the grok CLI. Unknown values pass
# through unchanged.
[[ -n "$MODEL" ]] && _resolve_grok_model_alias "$MODEL"

# --effort overrides the alias's own effort column; --effort > alias effort >
# global default (medium).
re_resolve_effort "$EFFORT" "$ALIAS_EFFORT" || {
  printf 'grok-dispatch: error: --effort must be one of: %s (got: %s)\n' "$RE_VALID_EFFORTS" "$EFFORT" >&2
  exit 2
}
RESOLVED_EFFORT="$RE_RESOLVED_EFFORT"

MODEL_DISPLAY="$MODEL"; [[ -z "$MODEL_DISPLAY" ]] && MODEL_DISPLAY="<default>"

TS=$(date +%Y%m%d-%H%M%S)-$$
LAST="/dev/null"
STDERR_LOG="/dev/null"
TRACE="<print-only>"
if [[ "$PRINT_CMD" -ne 1 ]]; then
  dc_setup_trace_dir "$TRACE_DIR_OVERRIDE" "$WORK_DIR" "grok" "$TS" || exit 2
  TRACE_DIR="$DC_TRACE_DIR"; TRACE="$DC_TRACE"; LAST="$DC_LAST"; STDERR_LOG="$DC_STDERR_LOG"
fi

# Brief is delivered via --prompt-file (absolute path). Working directory is
# set with --cwd so the adapter does not need to cd for the brief path.
CMD=(grok
  --prompt-file "$BRIEF_FILE"
  --cwd "$WORK_DIR"
  --output-format streaming-json
  --sandbox "$SANDBOX"
  --permission-mode "$PERMISSION_MODE"
)
[[ -n "$MODEL" ]] && CMD+=(--model "$MODEL")
[[ -n "$RESOLVED_EFFORT" ]] && CMD+=(--reasoning-effort "$RESOLVED_EFFORT")

{
  echo "[$(date -Is)] grok-dispatch starting"
  echo "  cwd:        $WORK_DIR"
  echo "  model:      $MODEL_DISPLAY"
  echo "  effort:     $RESOLVED_EFFORT"
  echo "  sandbox:    $SANDBOX"
  echo "  permission: $PERMISSION_MODE"
  [[ -n "$ISOLATION" ]] && echo "  isolation:  $ISOLATION"
  echo "  timeout:    ${TIMEOUT}s"
  echo "  trace:      $TRACE"
  if [[ -n "$BRIEF_FILE" ]]; then
    echo "  brief:      $BRIEF_FILE (file)"
  fi
  # Observable isolation narrowing: every write-capable Grok OS sandbox also
  # permits ~/.grok (session/config store). See adapters/grok/isolation-map.yaml.
  case "$SANDBOX" in
    workspace|strict|read-only)
      echo "  note:       grok sandbox also allows writes under ~/.grok (Grok session/config store; product invariant — not cleaned up by pm-dispatch)"
      ;;
  esac
} | tee -a "$STDERR_LOG" >&2

if [[ "$PRINT_CMD" -eq 1 ]]; then
  echo "CMD=${CMD[*]}"
  exit 0
fi

dc_refresh_latest_pointers "grok" "$TRACE_DIR" "$TS"

# Run grok; JSONL event stream stdout → TRACE; grok stderr → STDERR_LOG.
# Bounded by timeout. --prompt-file + --cwd mean we do not need to cd or pipe.
set +e
if [[ "$TIMEOUT" -gt 0 ]]; then
  ( timeout --foreground --kill-after=15 "$TIMEOUT" "${CMD[@]}" ) >"$TRACE" 2>>"$STDERR_LOG"
else
  ( "${CMD[@]}" ) >"$TRACE" 2>>"$STDERR_LOG"
fi
EXIT=$?
set -e

# Extract the final agent message into the output contract (.last).
# streaming-json emits JSONL: type=="text" chunks carry .data; terminal is type=="end".
# Join all text chunks; fall back to raw stdout on empty/missing.
if [[ -s "$TRACE" ]]; then
  if ! jq -r 'select(.type == "text") | .data // empty' "$TRACE" 2>/dev/null | awk 'NF{p=1} {printf "%s", $0} END{if(!p) exit 1}' > "$LAST" \
     || [[ ! -s "$LAST" ]]; then
    # No text events: fall back to raw stdout.
    cp -- "$TRACE" "$LAST" 2>/dev/null || true
  fi
  # A type=="error" event (or missing terminal end with exit 0) downgrades success.
  if [[ "$EXIT" -eq 0 ]]; then
    if jq -e 'select(.type == "error")' "$TRACE" >/dev/null 2>&1; then
      EXIT=1
    elif ! jq -e 'select(.type == "end")' "$TRACE" >/dev/null 2>&1; then
      # Structurally whole but no terminal event — leave exit 0; post-verify
      # terminal_event check is the authoritative semantic gate.
      :
    fi
  fi
fi

dc_refresh_latest_pointers "grok" "$TRACE_DIR" "$TS"

# --- auto-log token usage to usage-tracker.jsonl (best-effort) ---
if [[ "$EXIT" -eq 0 && -s "$TRACE" ]]; then
  _GROK_TOKENS=$(jq -r 'select(.type == "end") | ((.usage.input_tokens // 0) + (.usage.output_tokens // 0))' "$TRACE" 2>/dev/null | tail -1 || echo 0)
  if [[ "$_GROK_TOKENS" =~ ^[0-9]+$ && "$_GROK_TOKENS" -gt 0 ]]; then
    _NOTE="auto: $(basename "$WORK_DIR")"
    bash "${PM_CFG_USAGE_LOG_PATH:-${SCRIPT_DIR}/log-usage.sh}" "grok_dispatch" "$_GROK_TOKENS" "$_NOTE" "" "grok" 2>>"$STDERR_LOG" || \
      echo "[$(date -Is)] grok-dispatch: usage log failed (tokens=$_GROK_TOKENS)" >> "$STDERR_LOG"
  fi
fi

{
  echo "[$(date -Is)] grok-dispatch finished"
  echo "  exit:       $EXIT"
  if [[ "$EXIT" -eq 124 ]]; then
    echo "  note:       hit ${TIMEOUT}s timeout (rerun or extend --timeout)"
  fi
} | tee -a "$STDERR_LOG" >&2

dc_print_footer "$TRACE" "$LAST" "$STDERR_LOG" "$EXIT" "$MODEL"

exit $EXIT
