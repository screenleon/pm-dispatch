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
#                     [--timeout <seconds>] -- <brief...>
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

WORK_DIR=""
MODEL=""
SANDBOX="workspace-write"
APPROVAL="never"
SKIP_GIT_CHECK=0
TIMEOUT="${CODEX_DISPATCH_TIMEOUT:-1200}"
BRIEF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --sandbox) SANDBOX="$2"; shift 2;;
    --approval) APPROVAL="$2"; shift 2;;
    --skip-git-check) SKIP_GIT_CHECK=1; shift;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --) shift; BRIEF="$*"; break;;
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
if [[ -z "$BRIEF" ]]; then
  echo "Error: brief is required (after --)" >&2
  exit 2
fi
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "Error: --timeout must be a non-negative integer (got: $TIMEOUT)" >&2
  exit 2
fi

TRACE_DIR="$WORK_DIR/.agent-trace"
mkdir -p "$TRACE_DIR"
TS=$(date +%Y%m%d-%H%M%S)
TRACE="$TRACE_DIR/codex-$TS.jsonl"
LAST="$TRACE_DIR/codex-$TS.last"
STDERR_LOG="$TRACE_DIR/codex-$TS.stderr"

CMD=(codex exec
  --cd "$WORK_DIR"
  --sandbox "$SANDBOX"
  -c "approval_policy=\"$APPROVAL\""
  --json
  --output-last-message "$LAST"
)
[[ -n "$MODEL" ]] && CMD+=(-m "$MODEL")
[[ "$SKIP_GIT_CHECK" -eq 1 ]] && CMD+=(--skip-git-repo-check)
# Pass brief via stdin ("-") to avoid codex treating a multi-line positional
# argument as an incomplete prompt and blocking on stdin.
CMD+=("-")

# Wrapper banner — also written to console so the caller can see what's happening.
{
  echo "[$(date -Is)] codex-dispatch starting"
  echo "  cwd:      $WORK_DIR"
  echo "  model:    ${MODEL:-<default>}"
  echo "  sandbox:  $SANDBOX"
  echo "  approval: $APPROVAL"
  echo "  timeout:  ${TIMEOUT}s"
  echo "  trace:    $TRACE"
  echo "  brief:    $BRIEF"
} | tee -a "$STDERR_LOG" >&2

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
