#!/usr/bin/env bash
# PreToolUse guard: project-pm subagent may only Edit/Write inside the memory dir.
#
# Wired into ~/.claude/settings.json as a PreToolUse hook with matcher "Edit|Write".
# No-op for any other agent (main thread, other subagents) so the hook is safe to
# install globally. Exit 2 with stderr message blocks the call and feeds the message
# back to Claude.
#
# Bypass: set CLAUDE_HOOK_PM_GUARD=off in the environment to disable.

set -euo pipefail

[[ "${CLAUDE_HOOK_PM_GUARD:-}" == "off" ]] && exit 0

input="$(cat)"

agent_type="$(jq -r '.agent_type // ""' <<<"$input")"
tool_name="$(jq -r '.tool_name // ""' <<<"$input")"

[[ "$agent_type" != "project-pm" ]] && exit 0
[[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]] && exit 0

file_path="$(jq -r '.tool_input.file_path // ""' <<<"$input")"
if [[ -z "$file_path" ]]; then
  echo "pm-write-guard: tool_input.file_path missing — refusing." >&2
  exit 2
fi

# Resolve to absolute (the path may not exist yet for Write; use realpath -m).
abs_path="$(realpath -m -- "$file_path")"

allowed_prefix="/home/screenleon/.claude/projects/-home-screenleon-github/memory/"

case "$abs_path" in
  "$allowed_prefix"*) exit 0 ;;
esac

cat >&2 <<EOF
project-pm is not permitted to $tool_name files outside the memory directory.

  attempted: $abs_path
  allowed:   ${allowed_prefix}**

If a code change is needed, write a brief and hand it back to the main thread for
codex-executor dispatch (see ~/github/claude-config/docs/codex-brief.md).
If you genuinely need to bypass for one turn, the user can set
CLAUDE_HOOK_PM_GUARD=off in the environment.
EOF
exit 2
