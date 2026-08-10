#!/usr/bin/env bash
#
# log-usage.sh — append a token usage entry to the tracker

set -euo pipefail

LOGFILE="${PM_DISPATCH_USAGE_LOG_FILE:-$HOME/.pm-dispatch/usage-tracker.jsonl}"
TYPE="${1:?usage: log-usage.sh <type> <tokens> [note] [session_id] [pool]}"
TOKENS="${2:?usage: log-usage.sh <type> <tokens> [note] [session_id] [pool]}"
NOTE="${3:-}"
SESSION="${4:-$(date +%s | sha256sum | head -c 8)}"
POOL="${5:-claude}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if ! [[ "$TOKENS" =~ ^[0-9]+$ ]]; then
  echo "log-usage: TOKENS must be a non-negative integer, got: $TOKENS" >&2
  exit 2
fi

case "$POOL" in
  claude|codex|spark|opencode|grok) ;;
  *) echo "log-usage: unknown pool '$POOL'; using claude" >&2; POOL="claude" ;;
esac

ENTRY=$(jq -nc \
  --arg ts "$TS" --arg session "$SESSION" --arg type "$TYPE" --argjson tokens "$TOKENS" \
  --arg note "$NOTE" --arg pool "$POOL" \
  '{ts:$ts, session:$session, type:$type, tokens:$tokens, note:$note, pool:$pool}')

mkdir -p "$(dirname "$LOGFILE")"
( umask 077 && touch "$LOGFILE" )
echo "$ENTRY" >> "$LOGFILE"
echo "Logged: $TYPE  $TOKENS tokens  [$NOTE]"
