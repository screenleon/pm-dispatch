#!/usr/bin/env bash
# codex-watch.sh
#
# Tail the most recent codex dispatch's JSONL trace and print a one-line
# human-readable summary of each event as it arrives. Use to watch a long
# dispatch in real time without knowing the timestamp.
#
# Usage:
#   codex-watch.sh [--cd <work_dir>]
#
# Defaults to $PWD's .agent-trace/latest.jsonl.

set -euo pipefail

WORK_DIR="${PWD}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

TRACE="$WORK_DIR/.agent-trace/latest.jsonl"
if [[ ! -e "$TRACE" ]]; then
  echo "no trace yet at $TRACE" >&2
  echo "(run codex-dispatch.sh first, or wait for the trace symlink to appear)" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "watch needs jq; falling back to raw tail -F" >&2
  exec tail -F "$TRACE"
fi

# Each codex event is one JSON object per line. Pretty-print only the fields
# a watcher cares about: type, item type, command (truncated), exit code,
# token usage on turn.completed.
exec tail -F "$TRACE" | jq -r --unbuffered '
  if .type == "turn.started" then
    "[\(.type)]"
  elif .type == "turn.completed" then
    "[\(.type)] tokens: in=\(.usage.input_tokens // 0) cached=\(.usage.cached_input_tokens // 0) out=\(.usage.output_tokens // 0)"
  elif .type == "item.completed" and .item.type == "command_execution" then
    "[cmd] exit=\(.item.exit_code // "?") \(.item.command | tostring | .[0:120])"
  elif .type == "item.completed" and .item.type == "agent_message" then
    "[msg] \(.item.text | tostring | .[0:200] | gsub("\n"; " "))"
  elif .type == "item.completed" and .item.type == "file_change" then
    "[edit] \(.item.path // .item.file // "?")"
  else
    "[\(.type)]"
  end
'
