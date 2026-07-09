#!/usr/bin/env bash
# claude-dispatch (adapters/claude/dispatch.sh)
#
# Thin claude executor adapter, symmetric to adapters/codex/dispatch.sh.
# Invokes headless `claude --print` as the canonical, host-independent claude
# executor — NOT Agent()-spawn (which only exists when Claude is the main thread).
# Driven by `pmctl dispatch run --adapter claude`, which owns the shared flow
# (brief-validate / guard / route / post-verify). This adapter is a leaf: it only
# builds the claude invocation and writes the executor-agnostic output contract.
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
# scripts/lib/reasoning-effort.sh). Wired straight through to claude's native
# `--effort` flag.
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
#   .agent-trace/claude-<ts>.jsonl   full claude --output-format stream-json JSONL event stream
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
  # shellcheck disable=SC1091
  . "$__claude_dispatch_source_repo/scripts/lib/dispatch-common.sh"
  dc_snapshot_copy_libs "$__claude_dispatch_snapshot_dir" "$__claude_dispatch_source_repo"
  chmod +x -- "$__claude_dispatch_snapshot"
  exec "$__claude_dispatch_snapshot" "$@"
fi
# Running from the snapshot copy — we own the directory, clean it up on exit.
__claude_dispatch_snapshot_dir="$(dirname "${BASH_SOURCE[0]}")"
trap 'rm -rf -- "$__claude_dispatch_snapshot_dir"' EXIT

WORK_DIR=""
MODEL=""
EFFORT=""
ALIAS_EFFORT=""
DEFAULT_DISPATCH_MODEL="default"   # resolved via share/claude-model-aliases.tsv → claude-sonnet-4-6
ISOLATION=""
SCRIPT_DIR="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT=""
BRIEF=""
BRIEF_FILE=""
PRINT_CMD=0
TRACE_DIR_OVERRIDE=""
PERMISSION_MODE="acceptEdits"   # default = workspace-write equivalent

# shellcheck source=scripts/lib/state-writer.sh  # sourced for snapshot support only; pmctl owns state writes.
. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/model-aliases.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/reasoning-effort.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/timeout-resolve.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/dispatch-common.sh"

# Model alias resolution — share/claude-model-aliases.tsv (3-column: alias, wire_id, effort).
# Snapshot copies the tsv alongside this script; fall back to repo-source paths.
PM_CLAUDE_ALIAS_FILE="$SCRIPT_DIR/claude-model-aliases.tsv"
[[ -f "$PM_CLAUDE_ALIAS_FILE" ]] || PM_CLAUDE_ALIAS_FILE="$SCRIPT_DIR/../../share/claude-model-aliases.tsv"

_resolve_claude_model_alias() {
  local query_model="$1"
  [[ -f "$PM_CLAUDE_ALIAS_FILE" ]] || return 0
  ma_resolve_alias "$PM_CLAUDE_ALIAS_FILE" "$query_model" "claude-dispatch" || return 0
  if [[ "$MA_RESOLVE_MATCH" == "1" ]]; then
    MODEL="$MA_RESOLVE_MODEL"
    ALIAS_EFFORT="$MA_RESOLVE_EFFORT"
  fi
  return 0
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

tr_resolve_timeout "" "CLAUDE_DISPATCH_TIMEOUT" "PM_CFG_TIMEOUT" "1200"
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

dc_validate_args "$WORK_DIR" "$BRIEF_FILE" "$PRINT_CMD" "$TIMEOUT" || exit 2
BRIEF="$DC_BRIEF"

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

# --effort overrides the alias's own effort column; --effort > alias effort >
# global default (medium). claude's native --effort accepts low/medium/high/
# xhigh/max, but pm-dispatch only exposes the low/medium/high intersection with
# codex — see scripts/lib/reasoning-effort.sh. ALIAS_EFFORT may hold a stale
# non-low/medium/high value (e.g. the legacy "normal"/"high" column in
# share/claude-model-aliases.tsv); re_resolve_effort treats that as absent and
# falls through to the global default. re_resolve_effort validates $EFFORT
# itself (returns 1 on an invalid flag value), so there is no separate
# pre-check here.
re_resolve_effort "$EFFORT" "$ALIAS_EFFORT" || {
  printf 'claude-dispatch: error: --effort must be one of: %s (got: %s)\n' "$RE_VALID_EFFORTS" "$EFFORT" >&2
  exit 2
}
RESOLVED_EFFORT="$RE_RESOLVED_EFFORT"

MODEL_DISPLAY="$MODEL"; [[ -z "$MODEL_DISPLAY" ]] && MODEL_DISPLAY="<default>"

TS=$(date +%Y%m%d-%H%M%S)-$$
LAST="/dev/null"
STDERR_LOG="/dev/null"
TRACE="<print-only>"
if [[ "$PRINT_CMD" -ne 1 ]]; then
  # Trace output location: --trace-dir flag > PM_DISPATCH_TRACE_DIR env > legacy
  # in-repo $WORK_DIR/.agent-trace (default UNCHANGED). Precedence + absolute-path
  # validation live in sw_resolve_trace_dir (scripts/lib/state-paths.sh), sourced
  # via state-writer.sh above and copied into the snapshot lib dir. Resolved only
  # when trace is actually written (--print-cmd writes none, so it needs no lib).
  dc_setup_trace_dir "$TRACE_DIR_OVERRIDE" "$WORK_DIR" "claude" "$TS" || exit 2
  TRACE_DIR="$DC_TRACE_DIR"; TRACE="$DC_TRACE"; LAST="$DC_LAST"; STDERR_LOG="$DC_STDERR_LOG"
fi

CMD=(claude -p
  --permission-mode "$PERMISSION_MODE"
  --output-format stream-json
  --verbose
)
[[ -n "$MODEL" ]] && CMD+=(--model "$MODEL")
[[ -n "$RESOLVED_EFFORT" ]] && CMD+=(--effort "$RESOLVED_EFFORT")

{
  echo "[$(date -Is)] claude-dispatch starting"
  echo "  cwd:        $WORK_DIR"
  echo "  model:      $MODEL_DISPLAY"
  echo "  effort:     $RESOLVED_EFFORT"
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

# Point latest.* convenience pointers at this run's files. Best-effort: on
# symlink-less hosts (Windows Git Bash) `ln -s` copy-falls-back, and a missing
# pointer must never abort dispatch — post-verify reads the per-run footer path,
# not latest.*. Called before launch (Unix observers attach immediately) and again
# after the run (symlink-less hosts get a usable copy once the targets exist).
dc_refresh_latest_pointers "claude" "$TRACE_DIR" "$TS"

# Run claude in the work dir; brief is delivered on stdin as the prompt. JSONL
# event stream stdout → TRACE (.jsonl); claude stderr → STDERR_LOG. Bounded by timeout.
set +e
if [[ "$TIMEOUT" -gt 0 ]]; then
  printf '%s' "$BRIEF" | ( cd "$WORK_DIR" && timeout --foreground --kill-after=15 "$TIMEOUT" "${CMD[@]}" ) >"$TRACE" 2>>"$STDERR_LOG"
else
  printf '%s' "$BRIEF" | ( cd "$WORK_DIR" && "${CMD[@]}" ) >"$TRACE" 2>>"$STDERR_LOG"
fi
EXIT=$?
set -e

# Extract the final agent message (.result) into the output contract (.last).
# stream-json emits JSONL: one event per line; the terminal event has .type=="result".
# Use -re so jq exits 1 for a null/absent .result — triggering the raw fallback —
# rather than writing a bare newline that would pass -s but carry no content.
# This is the ONLY load-bearing artifact pmctl/post-verify read.
if [[ -s "$TRACE" ]]; then
  if ! jq -re 'select(.type == "result") | .result' "$TRACE" > "$LAST" 2>/dev/null \
     || [[ ! -s "$LAST" ]]; then
    # Parse failure, null result, or no result event: fall back to raw stdout.
    cp -- "$TRACE" "$LAST" 2>/dev/null || true
  fi
  # A claude is_error:true downgrades a 0 exit to failure so post-verify/state agree.
  if [[ "$EXIT" -eq 0 ]] && \
     [[ "$(jq -r 'select(.type == "result") | .is_error // false' "$TRACE" 2>/dev/null | tail -1)" == "true" ]]; then
    EXIT=1
  fi
fi

# Re-point latest.* now that the per-run files exist (usable copies on
# symlink-less hosts; idempotent symlink refresh on Unix).
dc_refresh_latest_pointers "claude" "$TRACE_DIR" "$TS"

# --- auto-log token usage to usage-tracker.jsonl (best-effort) ---
if [[ "$EXIT" -eq 0 && -s "$TRACE" ]]; then
  _CLAUDE_TOKENS=$(jq -r 'select(.type == "result") | ((.usage.input_tokens // 0) + (.usage.output_tokens // 0))' "$TRACE" 2>/dev/null | tail -1 || echo 0)
  if [[ "$_CLAUDE_TOKENS" =~ ^[0-9]+$ && "$_CLAUDE_TOKENS" -gt 0 ]]; then
    _NOTE="auto: $(basename "$WORK_DIR")"
    # PM_CFG_USAGE_LOG_PATH (dispatch.usage_log_path in ~/.pm-dispatch/config,
    # exported by pmctl-dispatch.sh) overrides the claude-host-assumed default
    # path below — set it when the PM's own host is not claude
    # (docs/host-contract.md).
    bash "${PM_CFG_USAGE_LOG_PATH:-${HOME}/.claude/scripts/log-usage.sh}" "claude_dispatch" "$_CLAUDE_TOKENS" "$_NOTE" "" "claude" 2>>"$STDERR_LOG" || \
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

dc_print_footer "$TRACE" "$LAST" "$STDERR_LOG" "$EXIT" "$MODEL"

exit $EXIT
