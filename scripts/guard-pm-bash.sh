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
# scripts/hook-codex-command-guard.sh, which calls `pmctl guard check --role
# pm --runtime <host> --event pre-bash`. No-op for any other agent identity.
#
# Bypass: set PM_GUARD_PM_BASH=off in the environment to skip enforcement.
# Each bypass is logged.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# ~/.claude/logs/hooks.log (or $PM_GUARD_LOG_DIR/hooks.log in tests).
#
# Extending the denylist: this is a ratchet, not a final list — add a pattern
# below with a one-line reason when a new destructive command class is
# identified. Prefer denying a specific dangerous invocation shape over a
# broad command name (e.g. deny `git push.*--force`, not `git push` outright).

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"

GUARD_NAME="guard-pm-bash"
LOG_DIR="${PM_GUARD_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"
G_BYPASS_ENV="PM_GUARD_PM_BASH"
# shellcheck source=scripts/lib/guard-framework.sh
. "$_SCRIPT_DIR/lib/guard-framework.sh"
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
G_TARGET="$command_str"

g_check_bypass PM_GUARD_PM_BASH

if [[ -z "$command_str" ]]; then
  g_deny "tool_input.command empty"
fi

# Denylist: extended-regex patterns (bash =~), matched case-sensitively (see
# the match loop below for why). Each entry pairs a pattern with the one-line
# reason it exists.
declare -a DENY_PATTERNS=(
  'rm[[:space:]]+(-[a-z]*r[a-z]*f[a-z]*|-[a-z]*f[a-z]*r[a-z]*)[[:space:]]'  # rm -rf / -fr: recursive+force delete
  'git[[:space:]]+push([[:space:]]+[^|;&]*)?[[:space:]](-f|--force)([[:space:]]|$)'  # force push: can overwrite upstream history
  'git[[:space:]]+reset[[:space:]]+--hard'                                 # discards uncommitted work irreversibly
  'git[[:space:]]+clean[[:space:]]+-[a-z]*f'                               # deletes untracked files irreversibly
  'git[[:space:]]+branch[[:space:]]+-D'                                    # force-deletes a branch, bypassing merge check
  '\-\-no-verify\b'                                                        # skips commit/push hooks
  '\-\-no-gpg-sign\b'                                                      # bypasses commit signing
  '(curl|wget)[^|]*\|[[:space:]]*(ba)?sh\b'                                # pipe-to-shell remote code execution
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
for _pattern in "${DENY_PATTERNS[@]}"; do
  if [[ "$command_str" =~ $_pattern ]]; then
    g_deny "matches denylisted pattern: $_pattern"
  fi
done

g_allow "no denylisted pattern matched"
