#!/usr/bin/env bash
# codex-dispatch.sh
#
# Wrapper for invoking `codex exec` from Claude (PM → worker dispatch).
# Captures the final agent message and a full JSONL trace for later review.
#
# Usage:
#   codex-dispatch.sh --cd <dir> [--model <m>] [--sandbox <mode>]
#                     [--approval <mode>] [--skip-git-check]
#                     -- <brief...>
#
# Defaults:
#   --sandbox workspace-write   (read-only | workspace-write | danger-full-access)
#   --approval never            (never | on-failure | on-request | untrusted)
#
# Outputs:
#   .agent-trace/codex-<ts>.jsonl   full event stream
#   .agent-trace/codex-<ts>.last    final agent message
#   stdout: brief summary + paths

set -euo pipefail

WORK_DIR=""
MODEL=""
SANDBOX="workspace-write"
APPROVAL="never"
SKIP_GIT_CHECK=0
BRIEF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --sandbox) SANDBOX="$2"; shift 2;;
    --approval) APPROVAL="$2"; shift 2;;
    --skip-git-check) SKIP_GIT_CHECK=1; shift;;
    --) shift; BRIEF="$*"; break;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
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

TRACE_DIR="$WORK_DIR/.agent-trace"
mkdir -p "$TRACE_DIR"
TS=$(date +%Y%m%d-%H%M%S)
TRACE="$TRACE_DIR/codex-$TS.jsonl"
LAST="$TRACE_DIR/codex-$TS.last"

CMD=(codex exec
  --cd "$WORK_DIR"
  --sandbox "$SANDBOX"
  -c "approval_policy=\"$APPROVAL\""
  --json
  --output-last-message "$LAST"
)
[[ -n "$MODEL" ]] && CMD+=(-m "$MODEL")
[[ "$SKIP_GIT_CHECK" -eq 1 ]] && CMD+=(--skip-git-repo-check)
CMD+=("$BRIEF")

{
  echo "[$(date -Is)] codex-dispatch starting"
  echo "  cwd:      $WORK_DIR"
  echo "  model:    ${MODEL:-<default>}"
  echo "  sandbox:  $SANDBOX"
  echo "  approval: $APPROVAL"
  echo "  brief:    $BRIEF"
} >&2

set +e
"${CMD[@]}" >"$TRACE"
EXIT=$?
set -e

echo "---"
echo "trace: $TRACE"
echo "last:  $LAST"
echo "exit:  $EXIT"
echo "---"
if [[ -s "$LAST" ]]; then
  echo "=== final message ==="
  cat "$LAST"
fi

exit $EXIT
