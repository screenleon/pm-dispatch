#!/usr/bin/env bash
# PreToolUse guard for the `codex-executor` subagent — Write/Edit tool.
#
# Threat model: codex-executor is a thin dispatcher; it must never write
# arbitrary source or config files. The only legitimate Write use is creating a
# brief file in /tmp before calling codex-dispatch.sh.
#
# Allowed paths: /tmp/brief-<anything>.md
# Denied:        everything else (source tree, home dir, /etc, …).
#
# Wired into ~/.claude/settings.json as a PreToolUse hook with matcher
# "Edit|Write". No-op for any agent other than codex-executor.
#
# Bypass: set PM_HOOK_CODEX_WRITE_GUARD=off in the environment (logged).
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# $PM_HOOK_LOG_DIR/hooks.log (default ~/.claude/logs/hooks.log).

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"

# Deprecated-name compat shims — remove after v0.5.0
[[ -z "${PM_HOOK_LOG_DIR:-}"            && -n "${CLAUDE_HOOK_LOG_DIR:-}"            ]] && { printf '[pm-dispatch] CLAUDE_HOOK_LOG_DIR deprecated; use PM_HOOK_LOG_DIR\n' >&2;             PM_HOOK_LOG_DIR="${CLAUDE_HOOK_LOG_DIR}"; }
[[ -z "${PM_HOOK_CODEX_WRITE_GUARD:-}"  && -n "${CLAUDE_HOOK_CODEX_WRITE_GUARD:-}"  ]] && { printf '[pm-dispatch] CLAUDE_HOOK_CODEX_WRITE_GUARD deprecated; use PM_HOOK_CODEX_WRITE_GUARD\n' >&2; PM_HOOK_CODEX_WRITE_GUARD="${CLAUDE_HOOK_CODEX_WRITE_GUARD}"; }

HOOK_NAME="hook-codex-write-guard"
LOG_DIR="${PM_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"
HK_BYPASS_ENV="PM_HOOK_CODEX_WRITE_GUARD"
# shellcheck source=scripts/lib/hook-framework.sh
. "$_SCRIPT_DIR/lib/hook-framework.sh"
unset _SCRIPT_DIR

# ---------- helpers ----------

hk_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
codex-executor: blocked by $HOOK_NAME — $reason

  attempted: $HK_TOOL_NAME on ${file_path:-(empty)}
  allowed:   /tmp/brief-<task>.md

codex-executor Write/Edit is restricted to brief temp files only.
Write the brief to /tmp/brief-<task>.md, then dispatch via codex-dispatch.sh.

Bypass for one turn: set PM_HOOK_CODEX_WRITE_GUARD=off (logged).
EOF
}

# ---------- preflight ----------

hk_require_jq
hk_require_realpath

# ---------- parse input ----------

hk_read_json

# No-op for any caller other than codex-executor on Edit/Write.
[[ "$HK_AGENT_TYPE" != "codex-executor" ]] && exit 0
[[ "$HK_TOOL_NAME" != "Edit" && "$HK_TOOL_NAME" != "Write" ]] && exit 0

file_path="$(hk_jq '.tool_input.file_path // ""')" || {
  hk_audit deny "jq failed on tool_input.file_path" ""
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
HK_TARGET="$file_path"

# Bypass AFTER parse so the audit line records the actual call being bypassed.
hk_check_bypass PM_HOOK_CODEX_WRITE_GUARD

hk_validate_path "$file_path"
abs_path="$HK_ABS_PATH"

# Pattern check: must match /tmp/brief-<something>.md
case "$abs_path" in
  /tmp/brief-*.md) ;;
  *) hk_deny "path outside allowed brief pattern (resolved to $abs_path)" "$file_path" ;;
esac

# Reject existing symlinks — a symlink at /tmp/brief-task.md pointing to a
# source or config file would pass the pattern check but redirect the write
# to the symlink target, bypassing the guard's intent.
if [[ -L "$abs_path" ]]; then
  hk_deny "brief path is an existing symlink (symlink attack vector: $abs_path)" "$file_path"
fi

# Verify the parent directory resolves to /tmp (guards against /tmp itself
# being a symlink or path traversal via dirname).
if ! [[ -d "$(dirname "$abs_path")" ]]; then
  hk_deny "parent directory does not exist (resolved to $(dirname "$abs_path"))" "$file_path"
fi
real_parent="$(realpath_m "$(dirname "$abs_path")" 2>/dev/null)" || {
  hk_deny "realpath of parent directory failed" "$file_path"
}
[[ "$real_parent" == "/tmp" ]] || hk_deny "parent directory resolves outside /tmp (got: $real_parent)" "$file_path"

hk_allow "brief temp file" "$file_path"
