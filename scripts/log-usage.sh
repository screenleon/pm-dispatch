#!/usr/bin/env bash
#
# log-usage.sh — append a token usage entry to the tracker
#
# Usage:
#   bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note] [session_id] [pool]
#
# Types (standardized):
#   pr_gate_full        — full-tier PR gate (5 reviewers)
#   pr_gate_standard    — standard-tier PR gate (3 reviewers)
#   pr_gate_express     — express-tier PR gate (2 reviewers)
#   codex_task          — codex-executor dispatch
#   codex_dispatch      — Codex CLI dispatch auto-log
#   pm_analysis         — project-pm analysis
#   pm_synthesis        — project-pm gate synthesis
#   reviewer_critic     — critic agent
#   reviewer_qa         — qa-tester agent
#   reviewer_arch       — architecture-reviewer agent
#   reviewer_security   — security-reviewer agent
#   reviewer_risk       — risk-reviewer agent
#   session_total       — end-of-session manual summary
#
# Example:
#   bash ~/.claude/scripts/log-usage.sh pr_gate_full 390000 "JapanJob PR #24"
#   bash ~/.claude/scripts/log-usage.sh codex_task 99918 "BACKLOG #14 block fix"

set -euo pipefail

LOGFILE="$HOME/.claude/usage-tracker.jsonl"
TYPE="${1:?usage: log-usage.sh <type> <tokens> [note] [session_id] [pool]}"
TOKENS="${2:?usage: log-usage.sh <type> <tokens> [note] [session_id] [pool]}"
NOTE="${3:-}"
SESSION="${4:-$(date +%s | sha256sum | head -c 8)}"
POOL="${5:-claude}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Validate TOKENS is a non-negative integer before building JSON
if ! [[ "$TOKENS" =~ ^[0-9]+$ ]]; then
  echo "log-usage: TOKENS must be a non-negative integer, got: $TOKENS" >&2
  exit 2
fi

case "$POOL" in
  claude|codex|spark) ;;
  *)
    echo "log-usage: unknown pool '$POOL'; using claude" >&2
    POOL="claude"
    ;;
esac

# Build JSON safely via jq — all values passed as typed args, never interpolated
# into source. Prevents injection through NOTE/TYPE/SESSION containing quotes,
# backslashes, or shell metacharacters.
ENTRY=$(jq -nc \
  --arg     ts      "$TS"      \
  --arg     session "$SESSION" \
  --arg     type    "$TYPE"    \
  --argjson tokens  "$TOKENS"  \
  --arg     note    "$NOTE"    \
  --arg     pool    "$POOL"    \
  '{ts:$ts, session:$session, type:$type, tokens:$tokens, note:$note, pool:$pool}')

# Ensure log directory exists and file is created with restricted permissions
mkdir -p "$(dirname "$LOGFILE")"
# JSONL append: O_APPEND atomicity holds for entries < PIPE_BUF (4KB on Linux).
# Keep NOTE short to stay safely under that limit.
( umask 077 && touch "$LOGFILE" )
echo "$ENTRY" >> "$LOGFILE"
echo "Logged: $TYPE  $TOKENS tokens  [$NOTE]"
