#!/usr/bin/env bash
# Unified PreToolUse / pmctl-guard-check guard for the executor role's brief-file
# write, across ALL executor runtimes (codex, claude, …). Collapses the former
# per-runtime hook-codex-write-guard.sh + hook-claude-write-guard.sh, which carried
# a byte-identical brief-path policy.
#
# Threat model: an executor must never write arbitrary source or config files. The
# only legitimate Write/Edit at dispatch time is creating the brief at
# /tmp/brief-<task>.md before invoking the adapter.
#   Allowed:  /tmp/brief-<anything>.md
#   Denied:   everything else (source tree, home dir, /etc, …).
#
# The runtime is derived from the agent_type (<runtime>-executor), and the policy
# is one shared rule — so adding an executor runtime needs no new guard file.
#
# Live-hook vs CLI-only (the security-relevant asymmetry) — keyed on the resolved
# write_guard_mode, read from the adapter manifest, never inferred from file
# existence:
#   - write_guard_mode=hook: a thin dispatcher whose executor subagent self-writes
#     its brief via the host Write tool — gated by a LIVE PreToolUse hook, enforced
#     on every Write/Edit. No shipped adapter is in this class today (reserved for
#     a no-headless-CLI fallback runtime).
#   - write_guard_mode=cli-only (both shipped adapters, codex and claude): the
#     brief is pmctl-landed and the executor runs as an independent headless
#     subprocess (or, for a host-native runtime, self-executes under the host
#     harness) — a live PreToolUse hook must NOT gate those. So when this wrapper
#     fires LIVE for a cli-only runtime it no-ops; the brief-location check is
#     still enforced when driven by `pmctl guard check` (PM_GUARD_CHECK_CLI set).
#
# Wired into settings.json as a PreToolUse hook with matcher "Edit|Write" for
# hook-mode runtimes; no-op for any non-executor agent.
#
# Bypass: set PM_GUARD_<RUNTIME>_WRITE=off in the environment (logged), e.g.
# PM_GUARD_CODEX_WRITE=off.
#
# Audit: every evaluated firing (allow / deny / bypass) is appended to
# $PM_GUARD_LOG_DIR/hooks.log (default product-owned state log).

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_REPO_ROOT="$(cd "$_SCRIPT_DIR/../.." 2>/dev/null && pwd)"
# shellcheck source=runtime/lib/portable.sh
. "$_SCRIPT_DIR/../lib/portable.sh"
# shellcheck source=runtime/lib/runner-kind.sh
. "$_SCRIPT_DIR/../lib/runner-kind.sh"
# shellcheck source=runtime/lib/guard-log.sh
. "$_SCRIPT_DIR/../lib/guard-log.sh"

GUARD_NAME="guard-executor-write"
: "${PM_GUARD_LOG_DIR:=${PM_HOOK_LOG_DIR:-}}"  # deprecated alias
LOG_DIR="$(pm_guard_log_dir)"
LOG_FILE="$LOG_DIR/hooks.log"
G_BYPASS_ENV=""   # set per-runtime after agent_type is known
# shellcheck source=runtime/lib/guard-framework.sh
. "$_SCRIPT_DIR/../lib/guard-framework.sh"

# ---------- helpers ----------

g_deny_message() {
  local reason="$1"
  cat >&2 <<EOF
${RUNTIME:-executor}-executor: blocked by $GUARD_NAME — $reason

  attempted: $G_TOOL_NAME on ${file_path:-(empty)}
  allowed:   /tmp/brief-<task>.md

Executor Write/Edit is restricted to brief temp files at dispatch time.
Write the brief to /tmp/brief-<task>.md, then dispatch via
pmctl dispatch run --adapter ${RUNTIME:-<runtime>}.

Bypass for one turn: set ${G_BYPASS_ENV:-PM_GUARD_<RUNTIME>_WRITE}=off (logged).
EOF
}

# refuse <reason> — fail closed under pmctl guard check (return 2 / deny), but
# no-op (exit 0) when fired as a LIVE PreToolUse hook so an unrelated agent or an
# unregistered runtime is never blocked by a live hook it does not own.
refuse() {
  local reason="$1"
  if [[ -n "${PM_GUARD_CHECK_CLI:-}" ]]; then
    g_deny "$reason" "${file_path:-}"
  fi
  exit 0
}

# ---------- preflight ----------

g_require_jq
g_require_realpath

# ---------- parse input ----------

g_read_json

# No-op for any caller that is not an <runtime>-executor on Edit/Write.
[[ "$G_AGENT_TYPE" == *-executor ]] || exit 0
[[ "$G_TOOL_NAME" == "Edit" || "$G_TOOL_NAME" == "Write" ]] || exit 0

RUNTIME="${G_AGENT_TYPE%-executor}"
[[ "$RUNTIME" =~ ^[a-z][a-z0-9_-]*$ ]] || exit 0

# Resolve the runtime's write-guard mode from its adapter manifest. The
# strict-identifier check above keeps RUNTIME safe to interpolate into the path.
manifest="$_REPO_ROOT/adapters/$RUNTIME/adapter.yaml"
[[ -f "$manifest" && ! -L "$manifest" ]] || refuse "unregistered runtime: $RUNTIME (no valid adapter manifest)"
runner_kind="$(runner_kind_manifest_field "$manifest" runner_kind)" || refuse "cannot read runner_kind for runtime: $RUNTIME"
runner_kind_valid "$runner_kind" || refuse "invalid runner_kind for runtime $RUNTIME: $runner_kind"
# runner_kind_resolve_flag's 3rd arg is the OVERRIDE candidate: the manifest's
# explicit write_guard_mode field if present (may be empty), else the resolver
# falls back to the runner_kind-derived default for that flag.
write_guard_mode="$(runner_kind_resolve_flag "$runner_kind" write_guard_mode "$(runner_kind_manifest_field "$manifest" write_guard_mode)")" || refuse "cannot resolve write_guard_mode for runtime: $RUNTIME"

# Live PreToolUse context (no PM_GUARD_CHECK_CLI marker): a cli-only runtime
# self-executes under the host harness, so a live hook must not gate it.
if [[ -z "${PM_GUARD_CHECK_CLI:-}" && "$write_guard_mode" != "hook" ]]; then
  exit 0
fi

# Per-runtime bypass env (PM_GUARD_<RUNTIME>_WRITE; '-' → '_' for validity).
_bypass_suffix="${RUNTIME^^}"
G_BYPASS_ENV="PM_GUARD_${_bypass_suffix//-/_}_WRITE"
# Accept deprecated PM_HOOK_<RUNTIME>_WRITE_GUARD if new var is unset.
_old_bypass="PM_HOOK_${_bypass_suffix//-/_}_WRITE_GUARD"
[[ -z "${!G_BYPASS_ENV:-}" && -n "${!_old_bypass:-}" ]] && export "${G_BYPASS_ENV}=${!_old_bypass}"
unset _old_bypass _bypass_suffix

file_path="$(g_jq '.tool_input.file_path // ""')" || {
  g_audit deny "jq failed on tool_input.file_path" ""
  echo "$GUARD_NAME: malformed JSON on stdin — denying" >&2
  exit 2
}
G_TARGET="$file_path"

# Bypass AFTER parse so the audit line records the actual call being bypassed.
g_check_bypass "$G_BYPASS_ENV"

g_validate_path "$file_path"
abs_path="$G_ABS_PATH"

# Pattern check: must match /tmp/brief-<something>.md
case "$abs_path" in
  /tmp/brief-*.md) ;;
  *) g_deny "path outside allowed brief pattern (resolved to $abs_path)" "$file_path" ;;
esac

# Reject existing symlinks — a symlink at /tmp/brief-task.md pointing to a source
# or config file would pass the pattern check but redirect the write to the
# symlink target, bypassing the guard's intent.
if [[ -L "$abs_path" ]]; then
  g_deny "brief path is an existing symlink (symlink attack vector: $abs_path)" "$file_path"
fi

# Verify the parent directory resolves to /tmp (guards against /tmp itself being a
# symlink or path traversal via dirname).
if ! [[ -d "$(dirname "$abs_path")" ]]; then
  g_deny "parent directory does not exist (resolved to $(dirname "$abs_path"))" "$file_path"
fi
real_parent="$(realpath_m "$(dirname "$abs_path")" 2>/dev/null)" || {
  g_deny "realpath of parent directory failed" "$file_path"
}
[[ "$real_parent" == "/tmp" ]] || g_deny "parent directory resolves outside /tmp (got: $real_parent)" "$file_path"

g_allow "brief temp file" "$file_path"
