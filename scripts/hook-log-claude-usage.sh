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

# Delta-based logging: only log tokens not yet recorded for this session.
# Prevents duplicate entries if Stop fires multiple times for the same session.
_tracker="${HOME}/.claude/usage-tracker.jsonl"
_tokens_to_log="$tokens"
if [[ -f "$_tracker" && -n "${session_id:-}" ]]; then
    _already=$(python3 - "$_tracker" "$session_id" << 'PYEOF'
import json, sys
total = 0
logfile = sys.argv[1]
session_id = sys.argv[2]
try:
    for line in open(logfile):
        try:
            e = json.loads(line.strip())
            if (e.get('session', '') == session_id
                    and e.get('type') == 'session_total'):
                total += e.get('tokens', 0)
        except (json.JSONDecodeError, AttributeError):
            continue
except Exception:
    pass
print(total)
PYEOF
    )
    _tokens_to_log=$(( tokens - ${_already:-0} ))
fi
[[ "${_tokens_to_log:-0}" -gt 0 ]] || exit 0

_log_file="${CLAUDE_HOOK_LOG_DIR:+${CLAUDE_HOOK_LOG_DIR}/hooks.log}"
_log_file="${_log_file:-${HOME}/.claude/logs/hooks.log}"
mkdir -p "$(dirname "$_log_file")"
if ! bash "${HOME}/.claude/scripts/log-usage.sh" \
     "session_total" "$_tokens_to_log" "auto: stop hook" "${session_id:-}" "claude" \
     2>>"$_log_file"; then
  echo "[$(date -Is)] hook-log-claude-usage: log-usage.sh failed (session=${session_id:-?})" \
    >> "$_log_file"
else
  [[ -n "${CLAUDE_HOOK_LOG_DIR:-}" ]] && \
    echo "[$(date -Is)] hook-log-claude-usage: logged ${_tokens_to_log} tokens (session=${session_id:-?})" \
      >> "$_log_file"
fi

exit 0
