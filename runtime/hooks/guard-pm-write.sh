#!/usr/bin/env bash
# PreToolUse guard for the `project-pm` subagent.
#
# Threat model: PM is a planner; it must never modify code or arbitrary files.
# Only memory files under ~/.claude/projects/<project>/memory/ are writable.
# All other Edit/Write attempts are blocked.
#
# Wired into ~/.claude/settings.json as a PreToolUse hook with matcher
# "Edit|Write". No-op for any other agent (main thread, other subagents).
#
# Bypass: set PM_GUARD_PM_WRITE=off in the environment to skip enforcement.
# Each bypass is logged.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# ~/.claude/logs/hooks.log. No-ops for other agents are not logged.

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=runtime/lib/portable.sh
. "$_SCRIPT_DIR/../lib/portable.sh"

GUARD_NAME="guard-pm-write"
: "${PM_GUARD_LOG_DIR:=${PM_HOOK_LOG_DIR:-}}"    # deprecated alias
: "${PM_GUARD_PM_WRITE:=${PM_HOOK_PM_GUARD:-}}"  # deprecated alias
LOG_DIR="${PM_GUARD_LOG_DIR:-$HOME/.claude/logs}"
LOG_FILE="$LOG_DIR/hooks.log"
G_BYPASS_ENV="PM_GUARD_PM_WRITE"
REPO_ROOT="$(cd "$_SCRIPT_DIR/../.." 2>/dev/null && pwd)"
# shellcheck source=runtime/lib/guard-framework.sh
. "$_SCRIPT_DIR/../lib/guard-framework.sh"
unset _SCRIPT_DIR

ALLOWED_BASE="$HOME/.claude/projects"

# ---------- helpers ----------

g_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
project-pm: blocked by $GUARD_NAME — $reason

  attempted: $G_TOOL_NAME on ${file_path:-(empty)}
  allowed:   ${ALLOWED_BASE}/<project>/memory/**
             /tmp/<slug>/<file>.md  (task-slug briefs)
             <any-repo>/docs/spikes/{CC-NNN*,*-scope,*-rfc}.md

If a code change is needed, hand a brief back to the main thread for executor
dispatch via pmctl dispatch run (schema: ~/github/pm-dispatch/docs/dispatch-brief.md).

Bypass for one turn: set PM_GUARD_PM_WRITE=off (logged).
EOF
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

# Memory rule: PM intends to write inside this project's memory dir.
if [[ "$lex_path" =~ ^"$ALLOWED_BASE"/[^/]+/memory/.+ ]]; then
  if [[ "$abs_path" == "$lex_path" ]]; then
    # No symlinks followed — direct memory write.
    g_allow "inside memory dir" "$file_path"
  else
    # Symlink(s) were followed. Allow only when abs_path stays inside the
    # resolved memory directory target, covering the symlinked-memory-dir use
    # case (Rule C) while denying file-symlink and nested-dir-symlink escapes.
    if [[ "$lex_path" =~ ^"$ALLOWED_BASE"/([^/]+)/memory/.+ ]]; then
      real_mem_dir="$(realpath_m "$ALLOWED_BASE/${BASH_REMATCH[1]}/memory" 2>/dev/null)" \
        || real_mem_dir=""
      if [[ -n "$real_mem_dir" && "$abs_path" == "$real_mem_dir/"* ]]; then
        # Deny when abs_path falls into a Rule A or Rule B zone — that would be
        # a cross-rule escape via a memory/ dir symlink pointing to /tmp/<slug>/
        # or docs/spikes/, both of which are distinct allow zones with their own
        # lex_path requirements.  Only allow when abs_path stays outside those
        # zones (i.e. memory is legitimately symlinked to an external storage).
        if [[ "$abs_path" =~ ^/tmp/[a-z][^/]*/[^/]+\.md$ ]] || \
           [[ "$abs_path" != /tmp/* && "$abs_path" =~ /docs/spikes/(CC-[0-9][^/]*|[^/]+-scope|[^/]+-rfc)\.md$ ]]; then
          : # fall through to g_deny
        else
          g_allow "inside memory dir (lex)" "$file_path"
        fi
      fi
    fi
  fi
fi

# Rule A: /tmp/<slug>/<file>.md — exactly two segments below /tmp, .md suffix.
# Both lex_path and abs_path must match so symlinks cannot route abs_path here
# from an unrelated file_path (cross-rule symlink escape).
if [[ "$lex_path" =~ ^/tmp/[a-z][^/]*/[^/]+\.md$ ]]; then
  if [[ "$abs_path" =~ ^/tmp/[a-z][^/]*/[^/]+\.md$ ]]; then
    g_allow "tmp task-slug brief" "$file_path"
  fi
fi

# Rule B: any repo's docs/spikes/<name>.md — CC-NNN*, *-scope, *-rfc only.
# Paths in /tmp/ are excluded (those belong to Rule A's zone).  Both lex_path
# and abs_path must satisfy the same predicate (cross-rule escape prevention).
if [[ "$lex_path" != /tmp/* ]] && \
   [[ "$lex_path" =~ /docs/spikes/(CC-[0-9][^/]*|[^/]+-scope|[^/]+-rfc)\.md$ ]]; then
  if [[ "$abs_path" != /tmp/* ]] && \
     [[ "$abs_path" =~ /docs/spikes/(CC-[0-9][^/]*|[^/]+-scope|[^/]+-rfc)\.md$ ]]; then
    g_allow "docs/spikes PM-authored file" "$file_path"
  fi
fi

g_deny "outside memory directory (resolved to $abs_path)" "$file_path"
