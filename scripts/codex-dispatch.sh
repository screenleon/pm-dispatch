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
#   --timeout  ${CODEX_DISPATCH_TIMEOUT:-1200}   seconds; 0 disables
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
  cp -- "${BASH_SOURCE[0]}" "$__codex_dispatch_snapshot"
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
TIMEOUT="${CODEX_DISPATCH_TIMEOUT:-1200}"
BRIEF=""
BRIEF_FILE=""
BRIEF_FROM_ARGV=0
PRINT_CMD=0

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

# PM-facing alias → wire-format model mapping used by dispatch.
# Source-of-truth user config (confirmed via PM): /home/screenleon/.codex/config.toml
declare -A MODEL_ALIAS_TO_ID=(
  [codex-spark]="gpt-5.3-codex-spark"
)
declare -A MODEL_ALIAS_TO_EFFORT=(
  [codex-spark]="high"
)

MODEL_RESOLVED="$MODEL"
MODEL_RESOLVED_EFFORT=""
MODEL_ALIAS_MATCH=0
if [[ -n "$MODEL" ]]; then
  if [[ -n "${MODEL_ALIAS_TO_ID[$MODEL]+x}" ]]; then
    MODEL_RESOLVED="${MODEL_ALIAS_TO_ID[$MODEL]}"
    MODEL_RESOLVED_EFFORT="${MODEL_ALIAS_TO_EFFORT[$MODEL]}"
    MODEL_ALIAS_MATCH=1
  fi
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
