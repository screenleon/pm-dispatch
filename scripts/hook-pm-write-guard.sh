#!/usr/bin/env bash
# PreToolUse guard for the `project-pm` subagent.
#
# Threat model: PM is a planner; it must never modify code or arbitrary files.
# Only memory files under ~/.claude/projects/<project>/memory/ are writable.
# All other Edit/Write attempts are blocked.
#
# Wired into ~/.claude/settings.json as a PreToolUse hook with matcher
# "Edit|Write". No-op for any other agent (main thread, other subagents).
#
# Bypass: set PM_HOOK_PM_GUARD=off in the environment to skip enforcement.
# Each bypass is logged.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# ~/.claude/logs/hooks.log. No-ops for other agents are not logged.

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"

HOOK_NAME="hook-pm-write-guard"
LOG_DIR="${PM_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"
HK_BYPASS_ENV="PM_HOOK_PM_GUARD"
# shellcheck source=scripts/lib/hook-framework.sh
. "$_SCRIPT_DIR/lib/hook-framework.sh"
unset _SCRIPT_DIR

ALLOWED_BASE="$HOME/.claude/projects"

# ---------- helpers ----------

hk_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
project-pm: blocked by $HOOK_NAME — $reason

  attempted: $HK_TOOL_NAME on ${file_path:-(empty)}
  allowed:   ${ALLOWED_BASE}/<project>/memory/**

If a code change is needed, hand a brief back to the main thread for codex-executor
dispatch (schema: ~/github/pm-dispatch/docs/dispatch-brief.md).

Bypass for one turn: set PM_HOOK_PM_GUARD=off (logged).
EOF
}

# ---------- preflight ----------

hk_require_jq
hk_require_realpath

# ---------- parse input ----------
# Read input first so bypass and audit lines can include agent/tool/path identity.

hk_read_json

# No-op for any caller other than the project-pm subagent on Edit/Write.
[[ "$HK_AGENT_TYPE" != "project-pm" ]] && exit 0
[[ "$HK_TOOL_NAME" != "Edit" && "$HK_TOOL_NAME" != "Write" ]] && exit 0

file_path="$(hk_jq '.tool_input.file_path // ""')" || {
  hk_audit deny "jq failed on tool_input.file_path" ""
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
HK_TARGET="$file_path"

# Bypass AFTER parse so audit line records the actual call being bypassed.
hk_check_bypass PM_HOOK_PM_GUARD

hk_validate_path "$file_path"
abs_path="$HK_ABS_PATH"

# Pattern: $ALLOWED_BASE/<project>/memory/<file>
# [!/]* = one path segment with no slashes, so memory-evil/ does NOT match.
case "$abs_path" in
  "$ALLOWED_BASE"/[!/]*/memory/*) hk_allow "inside memory dir" "$file_path" ;;
esac

hk_deny "outside memory directory (resolved to $abs_path)" "$file_path"
