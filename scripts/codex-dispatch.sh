#!/usr/bin/env bash
# codex-dispatch.sh
#
# Wrapper for invoking `codex exec` from Claude (PM → worker dispatch).
# Captures the final agent message and a full JSONL trace for later review.
# Bounds runtime with a timeout so a silent codex hang cannot block the caller
# indefinitely; logs wrapper start/end + codex stderr to a sibling .stderr file
# so failed dispatches leave forensic evidence; maintains a stable
# .agent-trace/latest.{jsonl,last,stderr} symlink set so observers can tail
# the most recent run without knowing the timestamp.
#
# Usage:
#   codex-dispatch.sh --cd <dir> [--model <m>] [--sandbox <mode>]
#                     [--approval <mode>] [--skip-git-check]
#                     [--timeout <seconds>] [--print-cmd] --brief-file <path>
#   codex-dispatch.sh --cd <dir> [--model <m>] [--sandbox <mode>]
#                     [--approval <mode>] [--skip-git-check]
#                     [--timeout <seconds>] [--print-cmd] -- <brief...>
#
# --print-cmd prints the final CMD array (`CMD=${CMD[*]}`) and exits 0
# before invoking codex.
#
# Prefer --brief-file for all real dispatches. The inline -- <brief...> form is
# retained only for trivial smoke checks; shell quoting, hook validation, and
# multiline briefs are much easier to get wrong inline.
#
# Defaults:
#   --sandbox  workspace-write   (read-only | workspace-write | danger-full-access)
#   --approval never             (never | on-failure | on-request | untrusted)
#   --timeout  precedence: brief field > CODEX_DISPATCH_TIMEOUT env >
#             ~/.pm-dispatch/config [dispatch.default_timeout] > 1200 fallback
#
# Outputs:
#   .agent-trace/codex-<ts>.jsonl   full event stream (codex stdout)
#   .agent-trace/codex-<ts>.last    final agent message (--output-last-message)
#   .agent-trace/codex-<ts>.stderr  wrapper banner + codex stderr (forensic log)
#   .agent-trace/latest.jsonl       symlink → most recent .jsonl
#   .agent-trace/latest.last        symlink → most recent .last
#   .agent-trace/latest.stderr      symlink → most recent .stderr
#   stdout: brief summary + paths

set -euo pipefail

# Self-snapshot to avoid mid-flight modification when a dispatched Codex session
# edits this script (e.g. when the dispatch target is pm-dispatch itself).
# Bash reads scripts incrementally; rewriting the on-disk file under a running
# interpreter can corrupt the next read. We re-exec from a /tmp copy so the
# on-disk file is decoupled from the running process.
#
# Trigger: snapshot only when BASH_SOURCE looks like an on-disk script path,
# not when it already matches the mktemp snapshot pattern. Avoids relying on
# inherited env (which would let a polluted environment bypass the protection
# or trick a cleanup trap into deleting an arbitrary file).
if ! [[ "${BASH_SOURCE[0]}" =~ /codex-dispatch\.[A-Za-z0-9]{6}/codex-dispatch\.sh$ ]]; then
  __codex_dispatch_snapshot_dir="$(mktemp -d -t codex-dispatch.XXXXXX)"
  __codex_dispatch_snapshot="$__codex_dispatch_snapshot_dir/codex-dispatch.sh"
  __codex_dispatch_source_repo="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  __codex_dispatch_alias_source="$__codex_dispatch_source_repo/share/model-aliases.tsv"
  cp -- "${BASH_SOURCE[0]}" "$__codex_dispatch_snapshot"
  [[ -r "$__codex_dispatch_alias_source" ]] && cp -- "$__codex_dispatch_alias_source" "$__codex_dispatch_snapshot_dir/model-aliases.tsv" || true
  mkdir -p -- "$__codex_dispatch_snapshot_dir/lib"
  [[ -r "$__codex_dispatch_source_repo/scripts/lib/state-writer.sh" ]] && \
    cp -- "$__codex_dispatch_source_repo/scripts/lib/state-writer.sh" "$__codex_dispatch_snapshot_dir/lib/state-writer.sh" || true
  [[ -r "$__codex_dispatch_source_repo/scripts/lib/portable.sh" ]] && \
    cp -- "$__codex_dispatch_source_repo/scripts/lib/portable.sh" "$__codex_dispatch_snapshot_dir/lib/portable.sh" || true
  chmod +x -- "$__codex_dispatch_snapshot"
  exec "$__codex_dispatch_snapshot" "$@"
fi
# Running from the snapshot copy — we own the directory, clean it up on exit.
__codex_dispatch_snapshot_dir="$(dirname "${BASH_SOURCE[0]}")"
trap 'rm -rf -- "$__codex_dispatch_snapshot_dir"' EXIT

WORK_DIR=""
MODEL=""
SANDBOX="workspace-write"
APPROVAL="never"
SKIP_GIT_CHECK=0
SCRIPT_DIR="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PM_DISPATCH_CONFIG_FILE="${HOME}/.pm-dispatch/config"
PM_DISPATCH_ALIAS_FILE="${SCRIPT_DIR}/model-aliases.tsv"
[[ -f "$PM_DISPATCH_ALIAS_FILE" ]] || PM_DISPATCH_ALIAS_FILE="${SCRIPT_DIR}/../share/model-aliases.tsv"
TIMEOUT=""
BRIEF=""
BRIEF_FILE=""
BRIEF_FROM_ARGV=0
PRINT_CMD=0

# shellcheck source=scripts/lib/state-writer.sh
. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true

_load_config_timeout() {
  local config_path="${PM_DISPATCH_CONFIG_FILE}"
  local config_timeout=""
  local config_default_model=""
  local line_no=0
  local line key value

  if [[ -r "$config_path" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      ((line_no += 1))
      line="${line%$'\r'}"
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" ]] && continue

      if [[ "$line" != *"="* ]]; then
        echo "codex-dispatch: warning: malformed config line in ${config_path}:${line_no}" >&2
        continue
      fi

      key="${line%%=*}"
      value="${line#*=}"
      key="${key#"${key%%[![:space:]]*}"}"
      key="${key%"${key##*[![:space:]]}"}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"

      if [[ "$key" == "dispatch.default_timeout" ]]; then
        if [[ "$value" =~ ^[0-9]+$ ]]; then
          config_timeout="$value"
        else
          echo "codex-dispatch: warning: malformed value for dispatch.default_timeout in ${config_path}:${line_no}" >&2
        fi
      elif [[ "$key" == "dispatch.default_model" ]]; then
        config_default_model="$value"
        # Reserved for future default-model support; intentionally not consumed in axis 2.
      fi
      # Unknown keys are intentionally ignored for future axes.
    done < "$config_path"
  fi

  if [[ -n "${CODEX_DISPATCH_TIMEOUT:-}" ]]; then
    echo "$CODEX_DISPATCH_TIMEOUT"
    return 0
  fi

  : "$config_default_model"

  if [[ -n "$config_timeout" ]]; then
    echo "$config_timeout"
    return 0
  fi

  echo "1200"
}

_resolve_model_alias() {
  local query_model="$1"
  local line_no=0
  local line
  local alias_value model_id reasoning_effort

  if [[ ! -f "$PM_DISPATCH_ALIAS_FILE" ]]; then
    echo "codex-dispatch: error: model alias source-of-truth not found: $PM_DISPATCH_ALIAS_FILE" >&2
    echo "Expected file path: share/model-aliases.tsv (copied to snapshot at runtime)." >&2
    return 1
  fi
  if ! [[ -r "$PM_DISPATCH_ALIAS_FILE" ]]; then
    echo "codex-dispatch: error: model alias source-of-truth unreadable: $PM_DISPATCH_ALIAS_FILE" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_no += 1))
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue

    IFS=$'\t' read -r alias_value model_id reasoning_effort rest <<< "$line"
    if [[ -z "$alias_value" || -z "$model_id" || -z "$reasoning_effort" || -n "$rest" ]]; then
      echo "codex-dispatch: error: malformed model-alias entry in ${PM_DISPATCH_ALIAS_FILE}:${line_no}" >&2
      echo "Expected one tab-separated line: <alias><TAB><model_id><TAB><reasoning_effort>" >&2
      return 1
    fi

    if [[ "$alias_value" == "$query_model" ]]; then
      MODEL_RESOLVED="$model_id"
      MODEL_RESOLVED_EFFORT="$reasoning_effort"
      MODEL_ALIAS_MATCH=1
      return 0
    fi
  done < "$PM_DISPATCH_ALIAS_FILE"

  return 0
}

TIMEOUT="$(_load_config_timeout)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --sandbox) SANDBOX="$2"; shift 2;;
    --approval) APPROVAL="$2"; shift 2;;
    --skip-git-check) SKIP_GIT_CHECK=1; shift;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --print-cmd) PRINT_CMD=1; shift;;
    --brief-file) BRIEF_FILE="$2"; shift 2;;
    --) shift; BRIEF="$*"; BRIEF_FROM_ARGV=1; break;;
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
if [[ -n "$BRIEF_FILE" && "$BRIEF_FROM_ARGV" -eq 1 ]]; then
  echo "Error: --brief-file and -- <brief...> are mutually exclusive" >&2
  exit 2
fi
if [[ -n "$BRIEF_FILE" ]]; then
  if [[ ! -f "$BRIEF_FILE" || ! -r "$BRIEF_FILE" ]]; then
    echo "Error: brief file not found or not readable: $BRIEF_FILE" >&2
    exit 2
  fi
  BRIEF="$(<"$BRIEF_FILE")"
fi
if [[ -z "$BRIEF" ]]; then
  if [[ -n "$BRIEF_FILE" ]]; then
    echo "Error: brief file is empty: $BRIEF_FILE" >&2
  else
    echo "Error: brief is required; prefer --brief-file <path> (inline form after -- is only for trivial smoke checks)" >&2
  fi
  exit 2
fi
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "Error: --timeout must be a non-negative integer (got: $TIMEOUT)" >&2
  exit 2
fi

MODEL_RESOLVED="$MODEL"
MODEL_RESOLVED_EFFORT=""
MODEL_ALIAS_MATCH=0
if [[ -n "$MODEL" ]]; then
  _resolve_model_alias "$MODEL" || exit 2
fi

MODEL_DISPLAY="$MODEL"
if [[ -z "$MODEL_DISPLAY" ]]; then
  MODEL_DISPLAY="<default>"
elif [[ "$MODEL_ALIAS_MATCH" -eq 1 ]]; then
  MODEL_DISPLAY="$MODEL → $MODEL_RESOLVED (effort=$MODEL_RESOLVED_EFFORT)"
fi

TS=$(date +%Y%m%d-%H%M%S)-$$
LAST="/dev/null"
STDERR_LOG="/dev/null"
TRACE="<print-only>"

if [[ "$PRINT_CMD" -ne 1 ]]; then
  TRACE_DIR="$WORK_DIR/.agent-trace"
  mkdir -p "$TRACE_DIR"
  TRACE="$TRACE_DIR/codex-$TS.jsonl"
  LAST="$TRACE_DIR/codex-$TS.last"
  STDERR_LOG="$TRACE_DIR/codex-$TS.stderr"
fi

CMD=(codex exec
  --cd "$WORK_DIR"
  --sandbox "$SANDBOX"
  -c "approval_policy=\"$APPROVAL\""
  --json
  --output-last-message "$LAST"
)
[[ -n "$MODEL" ]] && CMD+=(-m "$MODEL_RESOLVED")
[[ -n "$MODEL_RESOLVED_EFFORT" ]] && CMD+=(-c "model_reasoning_effort=\"$MODEL_RESOLVED_EFFORT\"")
[[ "$SKIP_GIT_CHECK" -eq 1 ]] && CMD+=(--skip-git-repo-check)
# Pass brief via stdin ("-") to avoid codex treating a multi-line positional
# argument as an incomplete prompt and blocking on stdin.
CMD+=("-")

# Wrapper banner — also written to console so the caller can see what's happening.
{
  echo "[$(date -Is)] codex-dispatch starting"
  echo "  cwd:      $WORK_DIR"
  echo "  model:    $MODEL_DISPLAY"
  echo "  sandbox:  $SANDBOX"
  echo "  approval: $APPROVAL"
  echo "  timeout:  ${TIMEOUT}s"
  echo "  trace:    $TRACE"
  if [[ -n "$BRIEF_FILE" ]]; then
    echo "  brief:    $BRIEF_FILE (file)"
  else
    echo "  brief:    $BRIEF"
  fi
} | tee -a "$STDERR_LOG" >&2

if [[ "$PRINT_CMD" -eq 1 ]]; then
  echo "CMD=${CMD[*]}"
  exit 0
fi

# Refresh latest.* symlinks before launch so observers can attach immediately.
ln -sfn "codex-$TS.jsonl"   "$TRACE_DIR/latest.jsonl"
ln -sfn "codex-$TS.last"    "$TRACE_DIR/latest.last"
ln -sfn "codex-$TS.stderr"  "$TRACE_DIR/latest.stderr"

set +e
if [[ "$TIMEOUT" -gt 0 ]]; then
  printf '%s\n' "$BRIEF" | timeout --foreground --kill-after=15 "$TIMEOUT" "${CMD[@]}" >"$TRACE" 2>>"$STDERR_LOG"
else
  printf '%s\n' "$BRIEF" | "${CMD[@]}" >"$TRACE" 2>>"$STDERR_LOG"
fi
EXIT=$?
set -e

# --- state store: append Run row (best-effort; never fatal) ---
{
  # Extract task_id from brief file (first match of ^task_id: <ID>), fallback UNKN-0.
  _SW_TASK_ID="UNKN-0"
  if [[ -n "${BRIEF_FILE:-}" && -f "${BRIEF_FILE}" ]]; then
    _SW_TID=$(grep -oE '^task_id:[[:space:]]*[A-Z]{1,4}-[0-9]+[a-z]?' \
      "${BRIEF_FILE}" 2>/dev/null | head -1 | \
      sed 's/task_id:[[:space:]]*//' 2>/dev/null || true)
    [[ -n "$_SW_TID" ]] && _SW_TASK_ID="$_SW_TID"
  fi
  if [[ "$_SW_TASK_ID" == "UNKN-0" && -n "${BRIEF:-}" ]]; then
    _SW_TID=$(printf '%s' "$BRIEF" | grep -oE '^task_id:[[:space:]]*[A-Z]{1,4}-[0-9]+[a-z]?' \
      2>/dev/null | head -1 | \
      sed 's/task_id:[[:space:]]*//' 2>/dev/null || true)
    [[ -n "$_SW_TID" ]] && _SW_TASK_ID="$_SW_TID"
  fi
  _SW_STATE="failed"
  [[ "$EXIT" -eq 0 ]] && _SW_STATE="ok"
  _SW_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  _SW_HEX=$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
  _SW_RUN_ID="run-$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)-${_SW_HEX:0:6}"
  _SW_TRACE_PATH="${TRACE:-}"
  _SW_WORK_DIR="${WORK_DIR:-}"
  _SW_MODEL_VAL="${MODEL:-}"
  _SW_BRIEF_FILE_VAL="${BRIEF_FILE:-}"
  # Route run row to target project partition, not the caller's cwd partition.
  _SW_REPO_ROOT="${WORK_DIR:-}"
  # Build JSON via jq to safely escape all string field values.
  _SW_RUN_JSON="$(jq -cn \
    --arg id "$_SW_RUN_ID" \
    --arg task_id "$_SW_TASK_ID" \
    --arg state "$_SW_STATE" \
    --argjson exit_code "$EXIT" \
    --arg model "$_SW_MODEL_VAL" \
    --arg brief_file "$_SW_BRIEF_FILE_VAL" \
    --arg working_dir "$_SW_WORK_DIR" \
    --arg trace_path "$_SW_TRACE_PATH" \
    --arg created_ts "$_SW_TS" \
    '{schema_version:1,id:$id,task_id:$task_id,executor:"codex",state:$state,exit_code:$exit_code,model:$model,brief_file:$brief_file,working_dir:$working_dir,trace_path:$trace_path,created_ts:$created_ts}' \
    2>/dev/null || true)"
  if [[ -n "$_SW_RUN_JSON" && "$(type -t runs_append 2>/dev/null)" == function ]]; then
    runs_append "$_SW_RUN_JSON" 2>/dev/null || true
  fi
} 2>/dev/null || true

# --- auto-log token usage to usage-tracker.jsonl ---
if [[ "$EXIT" -eq 0 && -f "$TRACE" ]]; then
  _CODEX_TOKENS=$(python3 -c "
import json, sys
for line in open(sys.argv[1]):
    try:
        e = json.loads(line.strip())
        if e.get('type') == 'turn.completed':
            u = e.get('usage', {})
            print(u.get('input_tokens',0) + u.get('output_tokens',0))
            sys.exit(0)
    except Exception: pass
print(0)
" "$TRACE" 2>/dev/null || echo 0)
  if [[ "$_CODEX_TOKENS" -gt 0 ]]; then
    _POOL="codex"
    # Pooling uses the user-facing MODEL token (pre-resolution) to preserve
    # existing routing semantics in the PM dispatch contract and existing tests.
    [[ "${MODEL:-}" == *spark* ]] && _POOL="spark"
    _NOTE="auto: $(basename "$WORK_DIR")"
    bash "${HOME}/.claude/scripts/log-usage.sh" "codex_dispatch" "$_CODEX_TOKENS" "$_NOTE" "" "$_POOL" 2>>"$STDERR_LOG" || \
      echo "[$(date -Is)] codex-dispatch: usage log failed (pool=$_POOL tokens=$_CODEX_TOKENS)" \
        >> "$STDERR_LOG"
  fi
fi

# Closing banner — captures exit code so post-mortem can spot timeouts (124).
{
  echo "[$(date -Is)] codex-dispatch finished"
  echo "  exit:     $EXIT"
  if [[ "$EXIT" -eq 124 ]]; then
    echo "  note:     hit ${TIMEOUT}s timeout (silent hang likely; rerun or extend --timeout)"
  fi
} | tee -a "$STDERR_LOG" >&2

echo "---"
echo "trace:  $TRACE"
echo "last:   $LAST"
echo "stderr: $STDERR_LOG"
echo "exit:   $EXIT"
echo "---"
if [[ -s "$LAST" ]]; then
  echo "=== final message ==="
  cat "$LAST"
fi

exit $EXIT
