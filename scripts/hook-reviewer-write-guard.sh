#!/usr/bin/env bash
# PreToolUse guard for reviewer agent roles.
#
# Threat model: reviewers consume diff content — prompt-injection payloads
# embedded in a diff can instruct a reviewer to write arbitrary files.
# Only writes to .gate-results/ are legitimate reviewer output.
#
# Rule: reviewer Write/Edit must resolve to a path whose immediate parent
# directory is named exactly ".gate-results". This covers both sequential
# (gate-<ts>.md) and parallel (reviewer-<r>-<ts>.md) modes without enumerating
# filenames. Binding the directory name, not the filename or the repo root, is
# intentional — any project can use this guard without coupling the check to the
# pm-dispatch install location (CC-319).
#
# Role → agent-type mapping (CC-297: role ≠ agent-type):
#   reviewer role → critic | qa-tester | architecture-reviewer
#                   security-reviewer | risk-reviewer
#
# NOT wired as a PreToolUse hook. Called exclusively via explicit
# `pmctl guard check --role reviewer` in reviewer briefs (both sequential and
# parallel routes). No-op for any agent not in the reviewer role.
#
# Bypass: set PM_HOOK_REVIEWER_GUARD=off (logged). Operators using
# --output outside .gate-results/ must set this bypass explicitly.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# $PM_HOOK_LOG_DIR/hooks.log (default ~/.claude/logs/hooks.log).

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"

HOOK_NAME="hook-reviewer-write-guard"
LOG_DIR="${PM_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"
HK_BYPASS_ENV="PM_HOOK_REVIEWER_GUARD"
# shellcheck source=scripts/lib/hook-framework.sh
. "$_SCRIPT_DIR/lib/hook-framework.sh"
unset _SCRIPT_DIR

# ---------- helpers ----------

hk_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
reviewer: blocked by $HOOK_NAME — $reason

  attempted: $HK_TOOL_NAME on ${file_path:-(empty)}
  allowed:   <any-project>/.gate-results/<filename>

Reviewer Write/Edit is restricted to the .gate-results/ directory.
This guard prevents prompt-injection payloads in diff content from
inducing a reviewer to write arbitrary files.

To use --output outside .gate-results/, set PM_HOOK_REVIEWER_GUARD=off
(bypass is logged).
EOF
}

# ---------- preflight ----------

hk_require_jq
hk_require_realpath

# ---------- parse input ----------

hk_read_json

# No-op for any agent not in the reviewer role.
# "reviewer" is the synthetic identity used by `pmctl guard check --role reviewer`
# (codex route); the named types are real Claude agent types (claude route).
case "$HK_AGENT_TYPE" in
  critic|qa-tester|architecture-reviewer|security-reviewer|risk-reviewer|reviewer) ;;
  *) exit 0 ;;
esac
[[ "$HK_TOOL_NAME" != "Edit" && "$HK_TOOL_NAME" != "Write" ]] && exit 0

file_path="$(hk_jq '.tool_input.file_path // ""')" || {
  hk_audit deny "jq failed on tool_input.file_path" ""
  echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
HK_TARGET="$file_path"

# Bypass AFTER parse so the audit line records the actual call being bypassed.
hk_check_bypass PM_HOOK_REVIEWER_GUARD

hk_validate_path "$file_path"
abs_path="$HK_ABS_PATH"

# The file's immediate parent directory must be named exactly ".gate-results".
# Binding the directory name (not the repo root) lets any project use this guard
# without coupling the check to the pm-dispatch install path (CC-319).
# realpath_m resolves symlinks so a .gate-results/ symlink is caught.
gate_results_dir="$(dirname "$abs_path")"
if [[ "$(basename "$gate_results_dir")" != ".gate-results" ]]; then
  hk_deny "target is not directly inside a .gate-results directory (got: $gate_results_dir, resolved: $abs_path)" "$file_path"
fi

# Reject existing symlinks at the target path (symlink swap attack: a symlink
# pre-planted at the expected output path would pass the pattern check but
# redirect the write to the symlink target).
if [[ -L "$abs_path" ]]; then
  hk_deny "target path is an existing symlink (symlink attack vector: $abs_path)" "$file_path"
fi

hk_allow "inside .gate-results/" "$file_path"
