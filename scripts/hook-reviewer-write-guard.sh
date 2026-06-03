#!/usr/bin/env bash
# PreToolUse guard for reviewer agent roles.
#
# Threat model: reviewers consume diff content — prompt-injection payloads
# embedded in a diff can instruct a reviewer to write arbitrary files.
# Only writes to .gate-results/ are legitimate reviewer output.
#
# One fixed rule: reviewer Write/Edit must resolve to a path whose immediate
# parent directory is named .gate-results. This covers both sequential
# (gate-<ts>.md) and parallel (reviewer-<r>-<ts>.md) modes without enumerating
# filenames. Binding the directory, not the filename, is intentional — adding
# or removing reviewers / changing tier never touches this guard.
#
# Role → agent-type mapping (CC-297: role ≠ agent-type):
#   reviewer role → critic | qa-tester | architecture-reviewer
#                   security-reviewer | risk-reviewer
#
# NOT wired as a PreToolUse hook. Called exclusively via explicit
# `pmctl guard check --role reviewer` in reviewer briefs (both sequential and
# parallel routes). No-op for any agent not in the reviewer role.
#
# Bypass: set CLAUDE_HOOK_REVIEWER_GUARD=off (logged). Operators using
# --output outside .gate-results/ must set this bypass explicitly.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# $CLAUDE_HOOK_LOG_DIR/hooks.log (default ~/.claude/logs/hooks.log).

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"

HOOK_NAME="hook-reviewer-write-guard"
LOG_DIR="${CLAUDE_HOOK_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"
HK_BYPASS_ENV="CLAUDE_HOOK_REVIEWER_GUARD"
# shellcheck source=scripts/lib/hook-framework.sh
. "$_SCRIPT_DIR/lib/hook-framework.sh"
# Repo root = the grandparent of this script. pmctl invokes the policy-backing
# hook at <repo>/scripts/hook-reviewer-write-guard.sh (see scripts/lib/pmctl-guard.sh:298),
# so <repo> is one level up from $_SCRIPT_DIR. Binding the allow-list to THIS
# repo's .gate-results/ (not merely any directory named .gate-results anywhere)
# matches the printed allow message and closes the off-repo write gap.
# CLAUDE_HOOK_GATE_REPO_ROOT overrides it for tests that use a sandbox repo.
GATE_REPO_ROOT="${CLAUDE_HOOK_GATE_REPO_ROOT:-$(cd "$_SCRIPT_DIR/.." 2>/dev/null && pwd)}"
unset _SCRIPT_DIR

# ---------- helpers ----------

hk_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
reviewer: blocked by $HOOK_NAME — $reason

  attempted: $HK_TOOL_NAME on ${file_path:-(empty)}
  allowed:   <repo>/.gate-results/<filename>

Reviewer Write/Edit is restricted to the .gate-results/ directory.
This guard prevents prompt-injection payloads in diff content from
inducing a reviewer to write arbitrary files.

To use --output outside .gate-results/, set CLAUDE_HOOK_REVIEWER_GUARD=off
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
hk_check_bypass CLAUDE_HOOK_REVIEWER_GUARD

hk_validate_path "$file_path"
abs_path="$HK_ABS_PATH"

# The immediate parent directory must be THIS repo's .gate-results/ — not merely
# any directory named .gate-results anywhere on disk. realpath_m resolves symlinks
# in all directory components on both sides, so a .gate-results/ symlink pointing
# elsewhere resolves to a path that no longer equals the expected dir — caught here.
gate_results_dir="$(dirname "$abs_path")"
expected_gate_dir="$(realpath_m "$GATE_REPO_ROOT/.gate-results" 2>/dev/null)"
if [[ -z "$expected_gate_dir" || "$gate_results_dir" != "$expected_gate_dir" ]]; then
  hk_deny "target is not <repo>/.gate-results (got: $gate_results_dir, expected: ${expected_gate_dir:-<unresolved>}, resolved: $abs_path)" "$file_path"
fi

# Reject existing symlinks at the target path (symlink swap attack: a symlink
# pre-planted at the expected output path would pass the pattern check but
# redirect the write to the symlink target).
if [[ -L "$abs_path" ]]; then
  hk_deny "target path is an existing symlink (symlink attack vector: $abs_path)" "$file_path"
fi

hk_allow "inside .gate-results/" "$file_path"
