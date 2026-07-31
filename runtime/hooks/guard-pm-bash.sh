#!/usr/bin/env bash
# PreToolUse guard for the `project-pm` role's own Bash execution.
#
# Threat model: on a claude-hosted PM, project-pm is a planner that never
# touches Bash itself — the write-guard's threat model. On a codex-hosted PM
# (hosts/codex/host.yaml), the PM session IS the one running Bash constantly;
# there is no separate "main thread" layer to defer judgment to.
# This guard is the mechanical stand-in for the same risk categories Claude
# Code's own harness already asks an interactive PM session to judge before
# acting (see this repo's own operating instructions, "Executing actions with
# care"): deny a curated set of destructive / hard-to-reverse commands,
# allow everything else. It is intentionally a denylist, not an allowlist —
# project-pm's normal operation (git, pmctl, file reads, package managers,
# build tools) is far too broad to enumerate safely as an allowlist without
# constantly breaking legitimate work.
#
# Wired into a codex-host's hooks.json PreToolUse (matcher "Bash") via
# hosts/codex/hooks/command-guard.sh, which calls `pmctl guard check --role
# pm --runtime <host> --event pre-bash`. No-op for any other agent identity.
#
# Bypass: set PM_GUARD_PM_BASH=off in the environment to skip enforcement.
# Each bypass is logged.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# the product-owned guard log (or $PM_GUARD_LOG_DIR/hooks.log in tests) — with
# common secret-shaped substrings (API keys, bearer tokens, password/token/
# secret flag values) redacted first (see _redact_secrets below). The
# denylist itself still matches against the RAW, unredacted command — only
# what gets displayed/persisted (the audit log line and the stderr deny
# message) is redacted.
#
# Extending the denylist: this is a ratchet, not a final list — add a pattern
# below with a one-line reason when a new destructive command class is
# identified. Prefer denying a specific dangerous invocation shape over a
# broad command name (e.g. deny `git push.*--force`, not `git push` outright).

# No `-e` here, unlike the other guard hooks: the no-op fast paths below use
# `[[ cond ]] && exit 0`, which returns non-zero when the condition is false —
# under `set -e` that would abort the guard with a failure exit on every
# non-PM Bash call, turning the no-op path into a hard block. This guard must
# always run to an explicit allow/deny verdict. The shell-options symmetry
# test pins this exemption; if `-e` is ever wanted, rewrite the fast paths as
# `if` statements first.
set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=runtime/lib/portable.sh
. "$_SCRIPT_DIR/../lib/portable.sh"
# shellcheck source=runtime/lib/guard-log.sh
. "$_SCRIPT_DIR/../lib/guard-log.sh"

GUARD_NAME="guard-pm-bash"
LOG_DIR="$(pm_guard_log_dir)"
LOG_FILE="$LOG_DIR/hooks.log"
G_BYPASS_ENV="PM_GUARD_PM_BASH"
# shellcheck source=runtime/lib/guard-framework.sh
. "$_SCRIPT_DIR/../lib/guard-framework.sh"
unset _SCRIPT_DIR

g_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
project-pm: blocked by $GUARD_NAME — $reason

  attempted: $G_TOOL_NAME ${G_TARGET:-(empty)}

This command matches a denylisted destructive/hard-to-reverse pattern. If it
is genuinely needed, run it yourself outside the PM session, or set
PM_GUARD_PM_BASH=off for one turn (logged) after confirming the risk.
EOF
}

# Best-effort redaction of common secret shapes before a command string is
# displayed or persisted (audit log line, stderr deny message). Order matters:
# specific token shapes are masked before the generic `key=value`/`--flag
# value` fallback so a matched token isn't partially re-matched by a later
# broader pattern. Not a complete secret scanner — a command containing a
# secret in an unrecognized shape still gets logged as-is; this closes the
# common cases (API keys, bearer tokens, password/token/secret flags), not
# every possible one.
#
# The generic keyword pattern matches the keyword ANYWHERE in a flag name
# (e.g. `--client-secret`, `--db-password`), not just as the whole flag, and
# accepts `=`, `:`, or plain whitespace as the separator — a prior version
# only matched `=`/`:`, so a long-form flag using a space separator (e.g.
# `--client-secret value`) was logged with its value unredacted.
_redact_secrets() {
  local s="$1"
  s="${s//$'\n'/ }"
  sed -E \
    -e 's/sk-[A-Za-z0-9_-]{16,}/***REDACTED***/g' \
    -e 's/gh[ps]_[A-Za-z0-9]{20,}/***REDACTED***/g' \
    -e 's/AKIA[0-9A-Z]{16}/***REDACTED***/g' \
    -e 's/([Bb]earer[[:space:]]+)[A-Za-z0-9._-]+/\1***REDACTED***/g' \
    -e 's/(-p|--password|--pass)([=[:space:]])[^[:space:]]+/\1\2***REDACTED***/g' \
    -e 's/(-{0,2}[A-Za-z0-9][A-Za-z0-9_-]*)?([Pp]assword|[Tt]oken|[Ss]ecret|[Cc]redential|[Aa][Pp][Ii]_?[Kk][Ee][Yy])([A-Za-z0-9_-]*)([=:[:space:]])[^[:space:]]+/\1\2\3\4***REDACTED***/g' \
    <<<"$s"
}

g_require_jq
g_read_json

# No-op for any caller other than the project-pm role on Bash.
[[ "$G_AGENT_TYPE" != "project-pm" ]] && exit 0
[[ "$G_TOOL_NAME" != "Bash" ]] && exit 0

command_str="$(g_jq '.tool_input.command // ""')" || {
  g_audit deny "jq failed on tool_input.command" ""
  echo "$GUARD_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
# G_TARGET drives both the audit log line and the stderr deny message — never
# the raw command. The denylist match below uses $command_str (unredacted)
# directly, so redaction can never weaken the policy itself.
G_TARGET="$(_redact_secrets "$command_str")"

g_check_bypass PM_GUARD_PM_BASH

if [[ -z "$command_str" ]]; then
  g_deny "tool_input.command empty"
fi

# Shell-expansion normalization: the denylist below matches literal
# whitespace ([[:space:]], which already covers real tabs/newlines/CR since
# bash treats those as ordinary characters in a JSON string, not shell
# metacharacters at match time). But `$IFS`/`${IFS}` and ANSI-C whitespace
# escapes (`$'\x20'`, `$'\t'`, `$' '`, ...) are still literal text in
# command_str at match time — bash only expands them when the string is
# later *executed*, which happens downstream of this guard, not inside it.
# A command shaped like `rm${IFS}-rf${IFS}/tmp/x` therefore reached Bash's
# real word-splitting as `rm -rf /tmp/x` while evading every pattern above
# because the raw text has no literal space between tokens. Fold the known
# whitespace-producing spellings into a real space BEFORE denylist matching
# (matching only — G_TARGET/audit/deny-message text above is built from the
# original command_str, so this normalization cannot suppress or alter what
# gets logged, only what gets evaluated against the patterns).
#
# Quote/escape collapsing: bash reconstructs a single word from adjacent
# quoted/unquoted/escaped fragments with no separator between them — e.g.
# `r'm' -rf /tmp/x` executes as `rm -rf /tmp/x` (the quotes around `m` are
# just removed by the shell, they do not introduce a word boundary), and
# `r\m -rf /tmp/x` does the same via a single-char backslash escape. The
# denylist patterns above look for the literal substring `rm` — quote/escape
# characters sitting between `r` and `m` defeat that even after IFS
# normalization. Strip quote characters and collapse backslash-escaped single
# characters before matching, same rationale as the IFS folding above: this
# can only make a pattern match MORE often (never fewer), so it cannot turn a
# true positive into a bypass — at worst it's a false-positive over-match on
# an unusual quoting style, which is the safe direction for a denylist.
#
# This closes the specific reported bypass classes, not every conceivable
# shell-expansion trick: brace expansion (`{rm,-rf,/tmp/x}`), variable
# indirection (`x=rf; rm -$x`), and `eval`/command-substitution-built
# commands are NOT normalized here and remain a known, accepted residual gap
# (same category as the case-sensitivity gap documented below) — a
# denylist inspecting a single string can never fully replace a real shell
# parser. Extend this normalization if a new bypass shape is found; do not
# try to make it a general shell evaluator (in particular: never `eval`
# command_str itself to tokenize it — that would execute the very thing this
# guard exists to stop evaluating).
_normalize_for_denylist() {
  local s="$1"
  local first_word
  _has_shell_control_operator() {
    awk '
      BEGIN { sq=0; dq=0; esc=0; found=0 }
      {
        for (i=1; i<=length($0); i++) {
          c=substr($0, i, 1)
          if (esc) { esc=0; continue }
          if (c == "\\") { esc=1; continue }
          if (sq) { if (c == "\047") sq=0; continue }
          if (dq) { if (c == "\042") dq=0; continue }
          if (c == "\047") { sq=1; continue }
          if (c == "\042") { dq=1; continue }
          if (c ~ /[;&|<>]/) found=1
        }
      }
      END { exit(found ? 0 : 1) }
    ' <<<"$1"
  }
  first_word="$(awk '{print $1}' <<<"$s")"
  case "$first_word" in
    rg|grep|egrep|fgrep)
      # Search expressions are data, not commands.  Keep the denylist
      # conservative for normal shell commands, but mask quoted search
      # operands so a reviewer cannot be blocked merely for searching source
      # text that contains `rm -rf` or another denylisted spelling.  If the
      # command contains command substitution, retain the original input: the
      # substitution is executable shell syntax even when nested in a search
      # operand, so the security guard must remain conservative.
      if [[ "$s" != *\$\(* && "$s" != *\`* ]] \
          && ! _has_shell_control_operator "$s"; then
        s="$(awk '
        BEGIN { sq=0; dq=0; esc=0 }
        {
          out=""
          for (i=1; i<=length($0); i++) {
            c=substr($0, i, 1)
            if (sq) {
              if (c == "\047") sq=0
              out=out " "
            } else if (dq) {
              if (esc) { esc=0; out=out " " }
              else if (c == "\\") { esc=1; out=out " " }
              else { if (c == "\042") dq=0; out=out " " }
            } else if (c == "\047") { sq=1; out=out " "
            } else if (c == "\042") { dq=1; out=out " "
            } else out=out c
          }
          print out
        }
        ' <<<"$s")"
      fi
      ;;
  esac
  s="${s//\$\{IFS\}/ }"
  s="${s//\$IFS/ }"
  # ANSI-C quoted whitespace: $'\x20' $'\x09' $'\x0a' $'\t' $'\n' $' '
  s="$(sed -E "s/\\\$'(\\\\x20|\\\\x09|\\\\x0a|\\\\t|\\\\n| )'/ /g" <<<"$s")"
  # Quote-removal + single-char backslash-escape collapse (see comment
  # above): does not model quote-context nuances (e.g. double-quote-only
  # backslash escapes) exactly — a blanket, conservative simplification that
  # only ever merges tokens closer together, never splits a real match apart.
  s="${s//\'/}"
  s="${s//\"/}"
  s="$(sed -E 's/\\(.)/\1/g' <<<"$s")"
  printf '%s' "$s"
}

# Denylist: extended-regex patterns (bash =~), matched case-sensitively (see
# the match loop below for why). Each entry pairs a pattern with the one-line
# reason it exists.
declare -a DENY_PATTERNS=(
  # rm -rf / -Rf / -fr / -fR (rm accepts both -r and -R for recursive; only
  # lowercase -f is valid, but the recursive letter's case must not matter):
  # combined single-flag-token form, either letter order, any other short
  # flags mixed into the SAME token (e.g. -rfv), end-of-string or
  # space-terminated. Matched anywhere after `rm` (not just as the first
  # token) so a preceding unrelated option does not shield the cluster —
  # `rm -v -rf x` and `rm --one-file-system -rf x` are denied too, not just
  # `rm -rf x`.
  'rm\b.*[[:space:]](-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*)([[:space:]]|$)'
  # rm with recursive and force passed as SEPARATE flags (either order),
  # short or long form: `rm -r -f`, `rm --force --recursive`, etc.
  'rm\b.*(-r\b|-R\b|--recursive\b).*(-f\b|--force\b)'
  'rm\b.*(-f\b|--force\b).*(-r\b|-R\b|--recursive\b)'
  # git subcommand patterns below all use `git\b.*[[:space:]]<subcmd>\b`
  # rather than `git[[:space:]]+<subcmd>` so a Git global option before the
  # subcommand does not shield it — `git -C /tmp reset --hard` and
  # `git -c foo=bar push --force` are denied too, not just the bare form
  # (same fix shape as the rm cluster pattern above).
  # force push: bare `-f`/`--force` plus the safer-looking variants that still
  # rewrite or delete remote refs — `--force-with-lease`/`--force-if-includes`
  # (optionally with a `=<refspec>` value, hence the `=` alternative in the
  # trailing boundary) still force-overwrite, and `--mirror` can delete remote
  # refs/branches wholesale.
  'git\b.*[[:space:]]push\b([[:space:]]+[^|;&]*)?[[:space:]](-f|--force(-with-lease|-if-includes)?|--mirror)([[:space:]=]|$)'
  # force-refspec push: `git push origin +main`, `git push +HEAD:main` — a
  # `+` prefix on a refspec argument means "force this update" without
  # spelling `-f`/`--force`, so it must be matched independently of the
  # pattern above (anywhere after `push`, not just as the first argument).
  'git\b.*[[:space:]]push\b.*[[:space:]]\+[^[:space:]]'
  'git\b.*[[:space:]]reset\b[[:space:]]+--hard'                            # discards uncommitted work irreversibly
  # git clean force flag: matched anywhere after `clean` (not just the
  # immediately-following token) so `git clean -d -f` (force passed as a
  # SEPARATE token from -d) is denied too, not just the combined `-df`/`-fd` form.
  'git\b.*[[:space:]]clean\b.*[[:space:]](-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]]|$)'
  'git\b.*[[:space:]]branch\b[[:space:]]+-D'                               # force-deletes a branch, bypassing merge check
  '\-\-no-verify\b'                                                        # skips commit/push hooks
  '\-\-no-gpg-sign\b'                                                      # bypasses commit signing
  # pipe-to-shell remote code execution: `| sh`, `| bash`, plus common
  # equivalent spellings — an absolute/relative interpreter path (`/bin/sh`,
  # `./sh`), an `env`-wrapped invocation (`env bash`), and `sudo`-prefixed
  # forms, any of which reach the same shell interpreter as the bare form.
  '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(([[:alnum:]_./-]*/)?env[[:space:]]+)?([[:alnum:]_./-]*/)?(ba|da|z)?sh\b'
  '\bsudo\b'                                                               # PM sessions should never need root
  '\bmkfs(\.[a-z0-9]+)?\b'                                                 # filesystem-format, irreversibly destroys data
  '\bdd[[:space:]]+.*of=/dev/'                                             # raw block-device write
  'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/'                       # recursive world-writable from root
  '\b(shutdown|reboot|poweroff|halt)\b'                                    # host power-state changes
)

# Matched case-sensitively, not lowercased: several patterns rely on case to
# distinguish a safe form from a destructive one (git branch -D force-delete
# vs -d safe-delete; chmod -R vs -r). A command spelled in unusual case (e.g.
# `SUDO`) evades this v1 denylist — a known, accepted gap, not a silent one.
_normalized_command_str="$(_normalize_for_denylist "$command_str")"
for _pattern in "${DENY_PATTERNS[@]}"; do
  if [[ "$_normalized_command_str" =~ $_pattern ]]; then
    g_deny "matches denylisted pattern: $_pattern"
  fi
done

# Allow-path audit target is a bounded class + hash, NOT the (even redacted)
# command text: this guard fires on EVERY Bash call in a codex-hosted PM
# session, so the allow path is the highest-volume line in the audit log —
# persisting full command text there for every benign command multiplies the
# window in which an unrecognized-shape secret (the one _redact_secrets does
# not catch) ends up on disk. The deny path keeps full redacted text (see
# g_deny above) because it fires rarely and the text is the diagnostic value
# of that log line; the hash here still lets an operator correlate an allow
# entry back to a specific command if they have it in shell history.
_allow_audit_summary() {
  local s="$1" first_word hash
  first_word="$(awk '{print $1}' <<<"$s")"
  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$s" | sha256sum 2>/dev/null | cut -c1-12)"
  else
    hash="$(printf '%s' "$s" | shasum -a 256 2>/dev/null | cut -c1-12)"
  fi
  printf '%s#%s' "${first_word:-?}" "${hash:-nohash}"
}

g_allow "no denylisted pattern matched" "$(_allow_audit_summary "$command_str")"
