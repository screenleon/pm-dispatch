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
# Bypass: set CLAUDE_HOOK_PM_GUARD=off in the environment to skip enforcement.
# Each bypass is logged.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# ~/.claude/logs/hooks.log. No-ops for other agents are not logged.

set -uo pipefail

HOOK_NAME="hook-pm-write-guard"
LOG_DIR="${CLAUDE_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"

ALLOWED_BASE="$HOME/.claude/projects"

# ---------- helpers ----------

audit() {
  local decision="$1" reason="${2:-}" target="${3:-}"
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  local ts
  ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
  printf '%s %s agent=%s tool=%s decision=%s reason=%q target=%q\n' \
    "$ts" "$HOOK_NAME" "${agent_type:-?}" "${tool_name:-?}" "$decision" "$reason" "$target" \
    >> "$LOG_FILE" 2>/dev/null || true
}

deny() {
  local reason="$1"
  audit deny "$reason" "${file_path:-}"
  cat >&2 <<EOF
project-pm: blocked by $HOOK_NAME — $reason

  attempted: $tool_name on ${file_path:-(empty)}
  allowed:   ${ALLOWED_BASE}/<project>/memory/**

If a code change is needed, hand a brief back to the main thread for codex-executor
dispatch (schema: ~/github/claude-config/docs/codex-brief.md).

Bypass for one turn: set CLAUDE_HOOK_PM_GUARD=off (logged).
EOF
  exit 2
}

allow() {
  audit allow "${1:-ok}" "${file_path:-}"
  exit 0
}

# ---------- preflight ----------

if ! command -v jq >/dev/null 2>&1; then
  echo "$HOOK_NAME: jq missing on PATH — install jq or set CLAUDE_HOOK_PM_GUARD=off" >&2
  exit 2
fi

if ! command -v realpath >/dev/null 2>&1; then
  echo "$HOOK_NAME: realpath missing on PATH — install coreutils or set CLAUDE_HOOK_PM_GUARD=off" >&2
  exit 2
fi

# ---------- parse input ----------
# Read input first so bypass and audit lines can include agent/tool/path identity.

input="$(cat)"

agent_type="$(jq -r '.agent_type // ""' <<<"$input" 2>/dev/null)" || {
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
tool_name="$(jq -r '.tool_name // ""' <<<"$input" 2>/dev/null)" || {
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}

# No-op for any caller other than the project-pm subagent on Edit/Write.
[[ "$agent_type" != "project-pm" ]] && exit 0
[[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]] && exit 0

file_path="$(jq -r '.tool_input.file_path // ""' <<<"$input" 2>/dev/null)" || {
  audit deny "jq failed on tool_input.file_path" ""
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}

# Bypass AFTER parse so audit line records the actual call being bypassed.
if [[ "${CLAUDE_HOOK_PM_GUARD:-}" == "off" ]]; then
  audit bypass "CLAUDE_HOOK_PM_GUARD=off" "$file_path"
  exit 0
fi

if [[ -z "$file_path" ]]; then
  deny "tool_input.file_path empty"
fi

# Require absolute path. Edit/Write tools enforce this upstream, but assert
# defensively — a relative path would be resolved against the hook's CWD,
# which is not the agent's CWD.
if [[ "$file_path" != /* ]]; then
  deny "file_path must be absolute (got: $file_path)"
fi

# Normalize traversal (`..`) and resolve symlinks where they exist. realpath -m
# tolerates non-existent path components (Write's target file may not exist yet).
abs_path="$(realpath -m -- "$file_path" 2>/dev/null)" || {
  deny "realpath failed on file_path"
}

# Pattern: $ALLOWED_BASE/<project>/memory/<file>
# [!/]* = one path segment with no slashes, so memory-evil/ does NOT match.
case "$abs_path" in
  "$ALLOWED_BASE"/[!/]*/memory/*) allow "inside memory dir" ;;
esac

deny "outside memory directory (resolved to $abs_path)"
