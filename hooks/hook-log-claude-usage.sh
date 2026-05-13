#!/usr/bin/env bash
# hook-log-claude-usage.sh — Stop hook: auto-log Claude session tokens.
# Receives JSON payload via stdin from Claude Code Stop event.
set -euo pipefail

payload=$(cat)
transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null || true)
session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)

[[ -z "$transcript" || ! -f "$transcript" ]] && exit 0

tokens=$(python3 - "$transcript" << 'PYEOF'
import json, sys
total = 0
try:
    for line in open(sys.argv[1]):
        line = line.strip()
        if not line:
            continue
        try:
            m = json.loads(line)
            # Try multiple possible locations for usage data in Claude transcripts.
            usage = (m.get('usage')
                     or m.get('message', {}).get('usage', {})
                     or {})
            total += (usage.get('input_tokens', 0) + usage.get('output_tokens', 0))
        except (json.JSONDecodeError, AttributeError):
            continue
except Exception:
    pass
print(total)
PYEOF
)

[[ "${tokens:-0}" -gt 0 ]] || exit 0

bash "${HOME}/.claude/scripts/log-usage.sh" \
  "session_total" "$tokens" "auto: stop hook" "${session_id:-}" "claude" 2>/dev/null || true

exit 0
