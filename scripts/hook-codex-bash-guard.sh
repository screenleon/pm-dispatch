#!/usr/bin/env bash
# PreToolUse guard: codex-executor subagent may only run codex-dispatch.sh and
# read-only verify commands. Anything else (including `codex exec` directly) is
# blocked.
#
# Wired into ~/.claude/settings.json as a PreToolUse hook with matcher "Bash".
# No-op for any other agent.
#
# Bypass: set CLAUDE_HOOK_CODEX_GUARD=off in the environment to disable.

set -euo pipefail

[[ "${CLAUDE_HOOK_CODEX_GUARD:-}" == "off" ]] && exit 0

input="$(cat)"

agent_type="$(jq -r '.agent_type // ""' <<<"$input")"
tool_name="$(jq -r '.tool_name // ""' <<<"$input")"

[[ "$agent_type" != "codex-executor" ]] && exit 0
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(jq -r '.tool_input.command // ""' <<<"$input")"
if [[ -z "$command" ]]; then
  echo "codex-bash-guard: tool_input.command missing — refusing." >&2
  exit 2
fi

# Strip leading whitespace; first significant token decides allow/deny.
trimmed="${command#"${command%%[![:space:]]*}"}"
first_word="${trimmed%%[[:space:]]*}"

dispatch_path="/home/screenleon/github/claude-config/scripts/codex-dispatch.sh"

case "$first_word" in
  "$dispatch_path"|"$HOME/github/claude-config/scripts/codex-dispatch.sh"|"~/github/claude-config/scripts/codex-dispatch.sh")
    exit 0
    ;;
  git|cat|ls|head|tail|wc|grep|find|realpath|test|true|false|echo)
    exit 0
    ;;
esac

cat >&2 <<EOF
codex-executor is restricted to the dispatch script and read-only verify commands.

  attempted: $command
  allowed:
    - $dispatch_path ...
    - git / cat / ls / head / tail / wc / grep / find / realpath  (verify steps)

Never call \`codex exec\` directly — the dispatch script encodes sandbox / approval /
trace-capture flags that the rest of the pipeline relies on.

If you genuinely need to bypass for one turn, the user can set
CLAUDE_HOOK_CODEX_GUARD=off in the environment.
EOF
exit 2
