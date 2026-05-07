#!/usr/bin/env bash
#
# log-usage.sh — append a token usage entry to the tracker
#
# Usage:
#   bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note] [session_id]
#
# Types (standardized):
#   pr_gate_full        — full-tier PR gate (5 reviewers)
#   pr_gate_standard    — standard-tier PR gate (3 reviewers)
#   pr_gate_express     — express-tier PR gate (2 reviewers)
#   codex_task          — codex-executor dispatch
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
TYPE="${1:?usage: log-usage.sh <type> <tokens> [note] [session_id]}"
TOKENS="${2:?usage: log-usage.sh <type> <tokens> [note] [session_id]}"
NOTE="${3:-}"
SESSION="${4:-$(date +%s | sha256sum | head -c 8)}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

ENTRY=$(python3 -c "
import json
print(json.dumps({
    'ts': '$TS',
    'session': '$SESSION',
    'type': '$TYPE',
    'tokens': $TOKENS,
    'note': '$NOTE'
}))
")

echo "$ENTRY" >> "$LOGFILE"
echo "✓ Logged: $TYPE  $TOKENS tokens  [$NOTE]"
