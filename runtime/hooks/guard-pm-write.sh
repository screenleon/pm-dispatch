#!/usr/bin/env bash
# PreToolUse guard for the `project-pm` subagent.
#
# Threat model: PM is a planner; it must never modify code or arbitrary files.
# Canonical project-memory writes are owned by the locked `pmctl memory`
# surfaces. Direct Edit/Write is therefore not a memory capability; all
# arbitrary paths are blocked except the narrow brief/spike handoff zones.
#
# Wired into ~/.claude/settings.json as a PreToolUse hook with matcher
# "Edit|Write". No-op for any other agent (main thread, other subagents).
#
# Bypass: set PM_GUARD_PM_WRITE=off in the environment to skip enforcement.
# Each bypass is logged.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to the
# product-owned guard log. No-ops for other agents are not logged.

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=runtime/lib/portable.sh
. "$_SCRIPT_DIR/../lib/portable.sh"
# shellcheck source=runtime/lib/guard-log.sh
. "$_SCRIPT_DIR/../lib/guard-log.sh"

GUARD_NAME="guard-pm-write"
: "${PM_GUARD_LOG_DIR:=${PM_HOOK_LOG_DIR:-}}"    # deprecated alias
: "${PM_GUARD_PM_WRITE:=${PM_HOOK_PM_GUARD:-}}"  # deprecated alias
LOG_DIR="$(pm_guard_log_dir)"
LOG_FILE="$LOG_DIR/hooks.log"
G_BYPASS_ENV="PM_GUARD_PM_WRITE"
REPO_ROOT="$(cd "$_SCRIPT_DIR/../.." 2>/dev/null && pwd)"
# shellcheck source=runtime/lib/guard-framework.sh
. "$_SCRIPT_DIR/../lib/guard-framework.sh"
unset _SCRIPT_DIR

# ---------- helpers ----------

g_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
project-pm: blocked by $GUARD_NAME — $reason

  attempted: $G_TOOL_NAME on ${file_path:-(empty)}
  allowed:   /tmp/<slug>/<file>.md  (task-slug briefs)
             <any-repo>/docs/spikes/{CC-NNN*,*-scope,*-rfc}.md

  canonical memory changes: use pmctl memory append-episode or the
  host-owned canonical memory writer; direct file edits are intentionally
  denied.

If a code change is needed, hand a brief back to the main thread for executor
dispatch via pmctl dispatch run (schema: \${PM_DISPATCH_REPO}/docs/dispatch-brief.md).

Bypass for one turn: set PM_GUARD_PM_WRITE=off (logged).
EOF
}

# Resolve the repository that owns a prospective spike path.  The file itself
# may not exist yet, so walk to the nearest existing parent before asking git.
# Print the canonical repository root only when the path is directly in that
# repository's docs/spikes handoff directory.
_pm_spike_repo_root() {
  local candidate="$1" parent repo_root
  parent="$(dirname "$candidate")"
  while [[ ! -e "$parent" ]]; do
    [[ "$parent" != "/" ]] || return 1
    parent="$(dirname "$parent")"
  done
  [[ -d "$parent" ]] || return 1
  repo_root="$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null)" || return 1
  repo_root="$(cd "$repo_root" 2>/dev/null && pwd -P)" || return 1
  case "$candidate" in
    "$repo_root"/docs/spikes/*) printf '%s\n' "$repo_root" ;;
    *) return 1 ;;
  esac
}

# ---------- preflight ----------

g_require_jq
g_require_realpath

# ---------- parse input ----------
# Read input first so bypass and audit lines can include agent/tool/path identity.

g_read_json

# No-op for any caller other than the project-pm subagent on Edit/Write.
[[ "$G_AGENT_TYPE" != "project-pm" ]] && exit 0
[[ "$G_TOOL_NAME" != "Edit" && "$G_TOOL_NAME" != "Write" ]] && exit 0

file_path="$(g_jq '.tool_input.file_path // ""')" || {
  g_audit deny "jq failed on tool_input.file_path" ""
  echo "$GUARD_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
G_TARGET="$file_path"

# Bypass AFTER parse so audit line records the actual call being bypassed.
g_check_bypass PM_GUARD_PM_WRITE

g_validate_path "$file_path"
abs_path="$G_ABS_PATH"

# For all allow rules: check the lexical path (PM intent) to prevent cross-rule
# symlink escapes where abs_path matches a different rule than the intended one.
# Each rule additionally verifies abs_path is safe within the same rule's scope.
lex_path="$(realpath_m_lex "$file_path")" || lex_path="$abs_path"

# Rule A: /tmp/<slug>/<file>.md — exactly two segments below /tmp, .md suffix.
# Both lex_path and abs_path must match so symlinks cannot route abs_path here
# from an unrelated file_path (cross-rule symlink escape).
if [[ "$lex_path" =~ ^/tmp/[a-z][^/]*/[^/]+\.md$ ]]; then
  if [[ "$abs_path" =~ ^/tmp/[a-z][^/]*/[^/]+\.md$ ]]; then
    g_allow "tmp task-slug brief" "$file_path"
  fi
fi

# Rule B: a real git repository's docs/spikes/<name>.md — CC-NNN*, *-scope,
# *-rfc only.  Repository ownership, rather than a blanket /tmp exclusion,
# keeps temporary worktrees usable while rejecting lookalike paths.  Lexical
# and resolved paths must belong to the same repository to prevent symlink
# cross-rule escapes.
if [[ "$lex_path" =~ /docs/spikes/(CC-[0-9][^/]*|[^/]+-scope|[^/]+-rfc)\.md$ ]] && \
   lex_repo="$(_pm_spike_repo_root "$lex_path" 2>/dev/null)"; then
  if [[ "$abs_path" =~ /docs/spikes/(CC-[0-9][^/]*|[^/]+-scope|[^/]+-rfc)\.md$ ]] && \
     abs_repo="$(_pm_spike_repo_root "$abs_path" 2>/dev/null)" && \
     [[ "$lex_repo" == "$abs_repo" ]]; then
    g_allow "docs/spikes PM-authored file" "$file_path"
  fi
fi

g_deny "outside direct-write handoff zones (canonical memory is writer-owned; resolved to $abs_path)" "$file_path"
