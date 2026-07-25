#!/usr/bin/env bash
# guard-log-claude-usage.sh — Stop hook: auto-log Claude session tokens.
# Receives JSON payload via stdin from Claude Code Stop event.
set -euo pipefail

payload=$(cat)
transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null || true)
session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)

[[ -z "$transcript" || ! -f "$transcript" ]] && exit 0

tokens=$(jq -rRs '
  [split("\n")[] | select(length>0) | try fromjson catch null | select(. != null) |
   ((.usage.input_tokens // .message.usage.input_tokens // 0) +
    (.usage.output_tokens // .message.usage.output_tokens // 0))]
  | add // 0
' "$transcript" 2>/dev/null) || tokens=0

[[ "${tokens:-0}" -gt 0 ]] || exit 0
# Require session_id: without a stable key we cannot deduplicate repeated Stop events.
[[ -n "${session_id:-}" ]] || exit 0

# Delta-based logging: only log tokens not yet recorded for this session.
# Prevents duplicate entries if Stop fires multiple times for the same session.
_tracker="${PM_DISPATCH_USAGE_LOG_FILE:-${HOME}/.pm-dispatch/usage-tracker.jsonl}"
_tokens_to_log="$tokens"
if [[ -f "$_tracker" && -n "${session_id:-}" ]]; then
    _already=$(jq -rRs --arg sid "$session_id" '
      [split("\n")[] | select(length>0) | try fromjson catch null | select(. != null) |
       select(.session == $sid and .type == "session_total") | .tokens // 0]
      | add // 0
    ' "$_tracker" 2>/dev/null) || _already=0
    _tokens_to_log=$(( tokens - ${_already:-0} ))
fi
[[ "${_tokens_to_log:-0}" -gt 0 ]] || exit 0

: "${PM_GUARD_LOG_DIR:=${PM_HOOK_LOG_DIR:-}}"  # deprecated alias
_log_file="${PM_GUARD_LOG_DIR:+${PM_GUARD_LOG_DIR}/hooks.log}"
_log_file="${_log_file:-${HOME}/.claude/logs/hooks.log}"
mkdir -p "$(dirname "$_log_file")"
if ! bash "${HOME}/.claude/scripts/log-usage.sh" \
     "session_total" "$_tokens_to_log" "auto: stop hook" "${session_id:-}" "claude" \
     2>>"$_log_file"; then
  echo "[$(date -Is)] guard-log-claude-usage: log-usage.sh failed (session=${session_id:-?})" \
    >> "$_log_file"
else
  [[ -n "${PM_GUARD_LOG_DIR:-}" ]] && \
    echo "[$(date -Is)] guard-log-claude-usage: logged ${_tokens_to_log} tokens (session=${session_id:-?})" \
      >> "$_log_file"
fi

exit 0
