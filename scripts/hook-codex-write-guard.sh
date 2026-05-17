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
# Bypass: set CLAUDE_HOOK_CODEX_WRITE_GUARD=off in the environment (logged).
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# $CLAUDE_HOOK_LOG_DIR/hooks.log (default ~/.claude/logs/hooks.log).

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"
unset _SCRIPT_DIR

HOOK_NAME="hook-codex-write-guard"
LOG_DIR="${CLAUDE_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"

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
codex-executor: blocked by $HOOK_NAME — $reason

  attempted: $tool_name on ${file_path:-(empty)}
  allowed:   /tmp/brief-<task>.md

codex-executor Write/Edit is restricted to brief temp files only.
Write the brief to /tmp/brief-<task>.md, then dispatch via codex-dispatch.sh.

Bypass for one turn: set CLAUDE_HOOK_CODEX_WRITE_GUARD=off (logged).
EOF
  exit 2
}

allow() {
  audit allow "${1:-ok}" "${file_path:-}"
  exit 0
}

# ---------- preflight ----------

if ! command -v jq >/dev/null 2>&1; then
  echo "$HOOK_NAME: jq missing on PATH — install jq or set CLAUDE_HOOK_CODEX_WRITE_GUARD=off" >&2
  exit 2
fi

if [[ "$(detect_platform)" != "windows" ]] && ! command -v realpath >/dev/null 2>&1; then
  echo "$HOOK_NAME: realpath missing on PATH — install coreutils or set CLAUDE_HOOK_CODEX_WRITE_GUARD=off" >&2
  exit 2
fi

# ---------- parse input ----------

input="$(cat)"

agent_type="$(jq -r '.agent_type // ""' <<<"$input" 2>/dev/null)" || {
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
tool_name="$(jq -r '.tool_name // ""' <<<"$input" 2>/dev/null)" || {
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}

# No-op for any caller other than codex-executor on Edit/Write.
[[ "$agent_type" != "codex-executor" ]] && exit 0
[[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]] && exit 0

file_path="$(jq -r '.tool_input.file_path // ""' <<<"$input" 2>/dev/null)" || {
  audit deny "jq failed on tool_input.file_path" ""
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}

# Bypass AFTER parse so the audit line records the actual call being bypassed.
if [[ "${CLAUDE_HOOK_CODEX_WRITE_GUARD:-}" == "off" ]]; then
  audit bypass "CLAUDE_HOOK_CODEX_WRITE_GUARD=off" "$file_path"
  exit 0
fi

if [[ -z "$file_path" ]]; then
  deny "tool_input.file_path empty"
fi

if [[ "$file_path" != /* ]]; then
  deny "file_path must be absolute (got: $file_path)"
fi

# Normalize path (tolerates non-existent Write targets).
abs_path="$(realpath_m "$file_path" 2>/dev/null)" || {
  deny "realpath failed on file_path"
}

# Pattern check: must match /tmp/brief-<something>.md
case "$abs_path" in
  /tmp/brief-*.md) ;;
  *) deny "path outside allowed brief pattern (resolved to $abs_path)" ;;
esac

# Reject existing symlinks — a symlink at /tmp/brief-task.md pointing to a
# source or config file would pass the pattern check but redirect the write
# to the symlink target, bypassing the guard's intent.
if [[ -L "$abs_path" ]]; then
  deny "brief path is an existing symlink (symlink attack vector: $abs_path)"
fi

# Verify the parent directory resolves to /tmp (guards against /tmp itself
# being a symlink or path traversal via dirname).
if ! [[ -d "$(dirname "$abs_path")" ]]; then
  deny "parent directory does not exist (resolved to $(dirname "$abs_path"))"
fi
real_parent="$(realpath_m "$(dirname "$abs_path")" 2>/dev/null)" || {
  deny "realpath of parent directory failed"
}
[[ "$real_parent" == "/tmp" ]] || deny "parent directory resolves outside /tmp (got: $real_parent)"

allow "brief temp file"
