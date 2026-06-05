#!/usr/bin/env bash
# claude-dispatch (adapters/claude/dispatch.sh)
#
# Thin claude executor adapter (CC-266), symmetric to adapters/codex/dispatch.sh.
# Invokes headless `claude --print` as the canonical, host-independent claude
# executor — NOT Agent()-spawn (which only exists when Claude is the main thread).
# Driven by `pmctl dispatch run --adapter claude`, which owns the shared flow
# (brief-validate / guard / route / post-verify). This adapter is a leaf: it only
# builds the claude invocation and writes the executor-agnostic output contract.
#
# Usage:
#   dispatch.sh --cd <dir> [--model <m>] [--isolation <level>]
#               [--timeout <seconds>] [--print-cmd] --brief-file <path>
#
# --print-cmd prints the final CMD array (`CMD=${CMD[*]}`) and exits 0.
#
# Isolation: --isolation <level> is translated to `claude --permission-mode <m>`
# via adapters/claude/isolation-map.yaml (none→bypassPermissions, read-only→
# default, workspace-write/network/sandboxed→acceptEdits). Default (no --isolation)
# is acceptEdits (the executor's workspace-write default).
#
# Codex-only flags (--sandbox / --approval / --skip-git-check) are accepted and
# ignored as no-ops, per docs/executor-contract.md (claude has no equivalents).
#
# Outputs (the contract pmctl/post-verify read — only latest.last is load-bearing):
#   .agent-trace/claude-<ts>.jsonl   full claude --output-format json stdout
#   .agent-trace/claude-<ts>.last    final agent message (JSON .result)
#   .agent-trace/claude-<ts>.stderr  wrapper banner + claude stderr (forensic log)
#   .agent-trace/latest.{jsonl,last,stderr}  symlinks → most recent

set -euo pipefail

# Self-snapshot to avoid mid-flight modification when a dispatched claude session
# edits this script (e.g. when the dispatch target is pm-dispatch itself). Bash
# reads scripts incrementally; rewriting the on-disk file under a running
# interpreter can corrupt the next read. Re-exec from a /tmp copy so the on-disk
# file is decoupled from the running process. Trigger keys on BASH_SOURCE shape
# (not env), so a polluted environment cannot bypass the protection.
if ! [[ "${BASH_SOURCE[0]}" =~ /claude-dispatch\.[A-Za-z0-9]{6}/claude-dispatch\.sh$ ]]; then
  __claude_dispatch_snapshot_dir="$(mktemp -d -t claude-dispatch.XXXXXX)"
  __claude_dispatch_snapshot="$__claude_dispatch_snapshot_dir/claude-dispatch.sh"
  # Resolve through symlinks (in case a compatibility shim is added later), then
  # ascend two levels (adapters/claude → repo root) for repo-relative sources.
  __claude_dispatch_real="${BASH_SOURCE[0]}"
  while [[ -L "$__claude_dispatch_real" ]]; do
    __claude_dispatch_link_dir="$(cd -P -- "$(dirname "$__claude_dispatch_real")" && pwd)"
    __claude_dispatch_real="$(readlink "$__claude_dispatch_real")"
    [[ "$__claude_dispatch_real" == /* ]] || __claude_dispatch_real="$__claude_dispatch_link_dir/$__claude_dispatch_real"
  done
  __claude_dispatch_source_repo="$(cd -P -- "$(dirname "$__claude_dispatch_real")/../.." && pwd)"
  __claude_dispatch_isolation_source="$__claude_dispatch_source_repo/adapters/claude/isolation-map.yaml"
  __claude_dispatch_alias_source="$__claude_dispatch_source_repo/share/claude-model-aliases.tsv"
  cp -- "${BASH_SOURCE[0]}" "$__claude_dispatch_snapshot"
  if [[ -r "$__claude_dispatch_isolation_source" ]]; then
    mkdir -p -- "$__claude_dispatch_snapshot_dir/adapters/claude"
    cp -- "$__claude_dispatch_isolation_source" "$__claude_dispatch_snapshot_dir/adapters/claude/isolation-map.yaml"
  fi
  [[ -r "$__claude_dispatch_alias_source" ]] && cp -- "$__claude_dispatch_alias_source" "$__claude_dispatch_snapshot_dir/claude-model-aliases.tsv" || true
  mkdir -p -- "$__claude_dispatch_snapshot_dir/lib"
  [[ -r "$__claude_dispatch_source_repo/scripts/lib/state-writer.sh" ]] && \
    cp -- "$__claude_dispatch_source_repo/scripts/lib/state-writer.sh" "$__claude_dispatch_snapshot_dir/lib/state-writer.sh" || true
  [[ -r "$__claude_dispatch_source_repo/scripts/lib/portable.sh" ]] && \
    cp -- "$__claude_dispatch_source_repo/scripts/lib/portable.sh" "$__claude_dispatch_snapshot_dir/lib/portable.sh" || true
  chmod +x -- "$__claude_dispatch_snapshot"
  exec "$__claude_dispatch_snapshot" "$@"
fi
# Running from the snapshot copy — we own the directory, clean it up on exit.
__claude_dispatch_snapshot_dir="$(dirname "${BASH_SOURCE[0]}")"
trap 'rm -rf -- "$__claude_dispatch_snapshot_dir"' EXIT

WORK_DIR=""
MODEL=""
DEFAULT_DISPATCH_MODEL="default"   # resolved via share/claude-model-aliases.tsv → claude-sonnet-4-6
ISOLATION=""
SCRIPT_DIR="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT=""
BRIEF=""
BRIEF_FILE=""
PRINT_CMD=0
PERMISSION_MODE="acceptEdits"   # default = workspace-write equivalent

# shellcheck source=scripts/lib/state-writer.sh  # sourced for snapshot support only; pmctl owns state writes.
. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true

# Model alias resolution — share/claude-model-aliases.tsv (3-column: alias, wire_id, effort).
# Snapshot copies the tsv alongside this script; fall back to repo-source paths.
PM_CLAUDE_ALIAS_FILE="$SCRIPT_DIR/claude-model-aliases.tsv"
[[ -f "$PM_CLAUDE_ALIAS_FILE" ]] || PM_CLAUDE_ALIAS_FILE="$SCRIPT_DIR/../../share/claude-model-aliases.tsv"

_resolve_claude_model_alias() {
  local query_model="$1"
  [[ -f "$PM_CLAUDE_ALIAS_FILE" ]] || return 0   # no alias file → pass through unchanged
  local line alias_value model_id effort rest
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"; line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    IFS=$'\t' read -r alias_value model_id effort rest <<< "$line"
    if [[ -z "$alias_value" || -z "$model_id" || -z "$effort" || -n "$rest" ]]; then
      printf 'claude-dispatch: warning: malformed entry in %s, skipping\n' "$PM_CLAUDE_ALIAS_FILE" >&2
      continue
    fi
    if [[ "$alias_value" == "$query_model" ]]; then
      MODEL="$model_id"
      return 0
    fi
  done < "$PM_CLAUDE_ALIAS_FILE"
  return 0   # no match → pass through unchanged
}

# Resolve isolation_level → permission_mode from adapters/claude/isolation-map.yaml.
# Snapshot executions read the copied adapter file; fall back to repo-source paths.
_resolve_permission_mode() {
  local level="$1"
  local map="$SCRIPT_DIR/adapters/claude/isolation-map.yaml"
  [[ -f "$map" ]] || map="$SCRIPT_DIR/../adapters/claude/isolation-map.yaml"
  [[ -f "$map" ]] || map="$SCRIPT_DIR/isolation-map.yaml"
  if [[ ! -f "$map" ]]; then
    printf 'claude-dispatch: error: adapters/claude/isolation-map.yaml not found (expected at %s)\n' "$map" >&2
    return 1
  fi
  local _mode="" _in=0 _line _cur
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    _line="${_line%$'\r'}"
    if [[ "$_line" =~ ^[[:space:]]{2}([a-z-]+):[[:space:]]*$ ]]; then
      _cur="${BASH_REMATCH[1]}"
      [[ "$_cur" == "$level" ]] && _in=1 || _in=0
      continue
    fi
    [[ "$_in" -eq 0 ]] && continue
    if [[ "$_line" =~ ^[[:space:]]{4}permission_mode:[[:space:]]*(.+)$ ]]; then
      _mode="${BASH_REMATCH[1]}"
      _mode="${_mode#\'}"; _mode="${_mode%\'}"; _mode="${_mode#\"}"; _mode="${_mode%\"}"
      break
    fi
  done < "$map"
  if [[ -z "$_mode" ]]; then
    printf 'claude-dispatch: error: unknown isolation_level %q (not in adapters/claude/isolation-map.yaml)\n' "$level" >&2
    return 1
  fi
  printf '%s\n' "$_mode"
}

# Timeout precedence: --timeout flag (parsed below, wins) > $CLAUDE_DISPATCH_TIMEOUT
# env > PM_CFG_TIMEOUT (exported by pmctl from config) > 1200 default.
# PM_CFG_TIMEOUT is set in this env by `pmctl dispatch run` (CC-293); direct
# adapter invocations fall back to 1200 when the var is absent.
if [[ -n "${CLAUDE_DISPATCH_TIMEOUT:-}" ]]; then
  TIMEOUT="$CLAUDE_DISPATCH_TIMEOUT"
elif [[ -n "${PM_CFG_TIMEOUT:-}" ]]; then
  TIMEOUT="$PM_CFG_TIMEOUT"
else
  TIMEOUT="1200"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --isolation) ISOLATION="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --print-cmd) PRINT_CMD=1; shift;;
    --brief-file) BRIEF_FILE="$2"; shift 2;;
    # Codex-only flags accepted as no-ops (claude has no equivalents).
    --sandbox) shift 2;;
    --approval) shift 2;;
    --skip-git-check) shift;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ -z "$WORK_DIR" ]]; then
  echo "Error: --cd <dir> is required" >&2
  exit 2
fi
if [[ ! -d "$WORK_DIR" ]]; then
  echo "Error: working dir not found: $WORK_DIR" >&2
  exit 2
fi
if [[ -n "$BRIEF_FILE" ]]; then
  if [[ ! -f "$BRIEF_FILE" || ! -r "$BRIEF_FILE" ]]; then
    echo "Error: brief file not found or not readable: $BRIEF_FILE" >&2
    exit 2
  fi
  BRIEF="$(<"$BRIEF_FILE")"
fi
if [[ -z "$BRIEF" && "$PRINT_CMD" -ne 1 ]]; then
  echo "Error: brief is required; pass --brief-file <path>" >&2
  exit 2
fi
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "Error: --timeout must be a non-negative integer (got: $TIMEOUT)" >&2
  exit 2
fi

if [[ -n "$ISOLATION" ]]; then
  PERMISSION_MODE="$(_resolve_permission_mode "$ISOLATION")" || exit 2
fi

# Default model resolution — mirrors codex adapter: pin pm-dispatch's own default
# through the alias table so omitting --model always resolves to claude-sonnet-4-6,
# decoupled from the claude CLI built-in default. Precedence: --model flag >
# PM_CFG_DEFAULT_MODEL (from ~/.pm-dispatch/config dispatch.default_model) >
# built-in `default` alias (→ claude-sonnet-4-6 via share/claude-model-aliases.tsv).
if [[ -z "$MODEL" ]]; then
  MODEL="${PM_CFG_DEFAULT_MODEL:-$DEFAULT_DISPATCH_MODEL}"
fi

# Resolve PM-facing alias (e.g. "light" → "claude-haiku-4-5-20251001") before
# passing to the claude CLI. Unknown values are passed through unchanged.
[[ -n "$MODEL" ]] && _resolve_claude_model_alias "$MODEL"

MODEL_DISPLAY="$MODEL"; [[ -z "$MODEL_DISPLAY" ]] && MODEL_DISPLAY="<default>"

TS=$(date +%Y%m%d-%H%M%S)-$$
LAST="/dev/null"
STDERR_LOG="/dev/null"
TRACE="<print-only>"
if [[ "$PRINT_CMD" -ne 1 ]]; then
  TRACE_DIR="$WORK_DIR/.agent-trace"
  mkdir -p "$TRACE_DIR"
  TRACE="$TRACE_DIR/claude-$TS.jsonl"
  LAST="$TRACE_DIR/claude-$TS.last"
  STDERR_LOG="$TRACE_DIR/claude-$TS.stderr"
fi

CMD=(claude -p
  --permission-mode "$PERMISSION_MODE"
  --output-format json
)
[[ -n "$MODEL" ]] && CMD+=(--model "$MODEL")

{
  echo "[$(date -Is)] claude-dispatch starting"
  echo "  cwd:        $WORK_DIR"
  echo "  model:      $MODEL_DISPLAY"
  echo "  permission: $PERMISSION_MODE"
  [[ -n "$ISOLATION" ]] && echo "  isolation:  $ISOLATION"
  echo "  timeout:    ${TIMEOUT}s"
  echo "  trace:      $TRACE"
  if [[ -n "$BRIEF_FILE" ]]; then
    echo "  brief:      $BRIEF_FILE (file)"
  fi
} | tee -a "$STDERR_LOG" >&2

if [[ "$PRINT_CMD" -eq 1 ]]; then
  echo "CMD=${CMD[*]}"
  exit 0
fi

# Refresh latest.* symlinks before launch so observers can attach immediately.
# 2>/dev/null || true: ln -sfn fails on Windows MSYS when target doesn't yet exist.
ln -sfn "claude-$TS.jsonl"   "$TRACE_DIR/latest.jsonl"  2>/dev/null || true
ln -sfn "claude-$TS.last"    "$TRACE_DIR/latest.last"   2>/dev/null || true
ln -sfn "claude-$TS.stderr"  "$TRACE_DIR/latest.stderr" 2>/dev/null || true

# Run claude in the work dir; brief is delivered on stdin as the prompt. JSON
# stdout → TRACE (.jsonl); claude stderr → STDERR_LOG. Bounded by timeout.
set +e
if [[ "$TIMEOUT" -gt 0 ]]; then
  printf '%s' "$BRIEF" | ( cd "$WORK_DIR" && timeout --foreground --kill-after=15 "$TIMEOUT" "${CMD[@]}" ) >"$TRACE" 2>>"$STDERR_LOG"
else
  printf '%s' "$BRIEF" | ( cd "$WORK_DIR" && "${CMD[@]}" ) >"$TRACE" 2>>"$STDERR_LOG"
fi
EXIT=$?
set -e

# Extract the final agent message (.result) into the output contract (.last).
# This is the ONLY load-bearing artifact pmctl/post-verify read.
if [[ -s "$TRACE" ]]; then
  if ! jq -r '.result // ""' "$TRACE" > "$LAST" 2>/dev/null; then
    # Non-JSON or parse failure: fall back to raw stdout so post-verify has input.
    cp -- "$TRACE" "$LAST" 2>/dev/null || true
  fi
  # A claude is_error:true downgrades a 0 exit to failure so post-verify/state agree.
  if [[ "$EXIT" -eq 0 ]] && [[ "$(jq -r '.is_error // false' "$TRACE" 2>/dev/null)" == "true" ]]; then
    EXIT=1
  fi
fi

# --- auto-log token usage to usage-tracker.jsonl (best-effort) ---
if [[ "$EXIT" -eq 0 && -s "$TRACE" ]]; then
  _CLAUDE_TOKENS=$(jq -r '((.usage.input_tokens // 0) + (.usage.output_tokens // 0))' "$TRACE" 2>/dev/null || echo 0)
  if [[ "$_CLAUDE_TOKENS" =~ ^[0-9]+$ && "$_CLAUDE_TOKENS" -gt 0 ]]; then
    _NOTE="auto: $(basename "$WORK_DIR")"
    bash "${HOME}/.claude/scripts/log-usage.sh" "claude_dispatch" "$_CLAUDE_TOKENS" "$_NOTE" "" "claude" 2>>"$STDERR_LOG" || \
      echo "[$(date -Is)] claude-dispatch: usage log failed (tokens=$_CLAUDE_TOKENS)" >> "$STDERR_LOG"
  fi
fi

{
  echo "[$(date -Is)] claude-dispatch finished"
  echo "  exit:       $EXIT"
  if [[ "$EXIT" -eq 124 ]]; then
    echo "  note:       hit ${TIMEOUT}s timeout (rerun or extend --timeout)"
  fi
} | tee -a "$STDERR_LOG" >&2

echo "---"
echo "trace:  $TRACE"
echo "last:   $LAST"
echo "stderr: $STDERR_LOG"
echo "exit:   $EXIT"
echo "model:  $MODEL"
echo "---"
if [[ -s "$LAST" ]]; then
  echo "=== final message ==="
  cat "$LAST"
fi

exit $EXIT
