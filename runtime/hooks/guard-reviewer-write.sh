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
# pm-dispatch install location.
#
# Role → agent-type mapping (role ≠ agent-type):
#   reviewer role → critic | qa-tester | architecture-reviewer
#                   security-reviewer | risk-reviewer
#
# NOT wired as a PreToolUse hook. Called exclusively via explicit
# `pmctl guard check --role reviewer` in reviewer briefs (both sequential and
# parallel routes). No-op for any agent not in the reviewer role.
#
# Bypass: set PM_GUARD_REVIEWER_WRITE=off (logged). Operators using
# --output outside .gate-results/ must set this bypass explicitly.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# $PM_GUARD_LOG_DIR/hooks.log (default product-owned state log).

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=runtime/lib/portable.sh
. "$_SCRIPT_DIR/../lib/portable.sh"
# shellcheck source=runtime/lib/guard-log.sh
. "$_SCRIPT_DIR/../lib/guard-log.sh"

GUARD_NAME="guard-reviewer-write"
: "${PM_GUARD_LOG_DIR:=${PM_HOOK_LOG_DIR:-}}"             # deprecated alias
: "${PM_GUARD_REVIEWER_WRITE:=${PM_HOOK_REVIEWER_GUARD:-}}"  # deprecated alias
LOG_DIR="$(pm_guard_log_dir)"
LOG_FILE="$LOG_DIR/hooks.log"
G_BYPASS_ENV="PM_GUARD_REVIEWER_WRITE"
# shellcheck source=runtime/lib/guard-framework.sh
. "$_SCRIPT_DIR/../lib/guard-framework.sh"
unset _SCRIPT_DIR

# ---------- helpers ----------

g_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
reviewer: blocked by $GUARD_NAME — $reason

  attempted: $G_TOOL_NAME on ${file_path:-(empty)}
  allowed:   <any-project>/.gate-results/<filename>

Reviewer Write/Edit is restricted to the .gate-results/ directory.
This guard prevents prompt-injection payloads in diff content from
inducing a reviewer to write arbitrary files.

To use --output outside .gate-results/, set PM_GUARD_REVIEWER_WRITE=off
(bypass is logged).
EOF
}

# ---------- preflight ----------

g_require_jq
g_require_realpath

# ---------- parse input ----------

g_read_json

# No-op for any agent not in the reviewer role.
# "reviewer" is the synthetic identity used by `pmctl guard check --role reviewer`
# (codex route); the named types are real Claude agent types (claude route).
case "$G_AGENT_TYPE" in
  critic|qa-tester|architecture-reviewer|security-reviewer|risk-reviewer|reviewer) ;;
  *) exit 0 ;;
esac
[[ "$G_TOOL_NAME" != "Edit" && "$G_TOOL_NAME" != "Write" ]] && exit 0

file_path="$(g_jq '.tool_input.file_path // ""')" || {
  g_audit deny "jq failed on tool_input.file_path" ""
  echo "$GUARD_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
G_TARGET="$file_path"

# Bypass AFTER parse so the audit line records the actual call being bypassed.
g_check_bypass PM_GUARD_REVIEWER_WRITE

g_validate_path "$file_path"
abs_path="$G_ABS_PATH"

# The file's immediate parent directory must be named exactly ".gate-results".
# Binding the directory name (not the repo root) lets any project use this guard
# without coupling the check to the pm-dispatch install path.
# realpath_m resolves symlinks so a .gate-results/ symlink is caught.
gate_results_dir="$(dirname "$abs_path")"
if [[ "$(basename "$gate_results_dir")" != ".gate-results" ]]; then
  g_deny "target is not directly inside a .gate-results directory (got: $gate_results_dir, resolved: $abs_path)" "$file_path"
fi

# Reject existing symlinks at the target path (symlink swap attack: a symlink
# pre-planted at the expected output path would pass the pattern check but
# redirect the write to the symlink target).
if [[ -L "$abs_path" ]]; then
  g_deny "target path is an existing symlink (symlink attack vector: $abs_path)" "$file_path"
fi

g_allow "inside .gate-results/" "$file_path"
