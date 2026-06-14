#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-runner-kind" "$@"

# shellcheck source=scripts/lib/runner-kind.sh
. "$SCRIPT_DIR/lib/runner-kind.sh"

# assert_emits <name> <expected> <cmd...>: run cmd, compare stdout to expected.
assert_emits() {
  local name="$1" expected="$2"; shift 2
  local actual status
  actual="$("$@" 2>/dev/null)" && status=0 || status=$?
  if [[ "$status" -eq 0 && "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "expected='$expected' actual='$actual' status=$status"
  fi
}

# assert_rejects <name> <cmd...>: cmd must exit 2 (validation reject).
assert_rejects() {
  local name="$1"; shift
  local status=0
  "$@" >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status"
  fi
}

# --- runner_kind_valid ------------------------------------------------------
runner_kind_valid cli-subprocess && pass "valid/cli-subprocess" || fail "valid/cli-subprocess" "rejected"
runner_kind_valid host-native    && pass "valid/host-native"    || fail "valid/host-native" "rejected"
runner_kind_valid bogus          && fail "valid/bogus-rejected" "accepted unknown kind" || pass "valid/bogus-rejected"
runner_kind_valid ""             && fail "valid/empty-rejected" "accepted empty" || pass "valid/empty-rejected"

# --- default mapping: cli-subprocess (codex topology) -----------------------
assert_emits "default/cli/route"      "main_thread_bash_background" runner_kind_default_flag cli-subprocess dispatch_route
assert_emits "default/cli/guardmode"  "hook"                        runner_kind_default_flag cli-subprocess write_guard_mode
assert_emits "default/cli/bashguard"  "true"                        runner_kind_default_flag cli-subprocess needs_bash_guard

# --- default mapping: host-native (claude topology) -------------------------
assert_emits "default/host/route"     "agent_executor"             runner_kind_default_flag host-native dispatch_route
assert_emits "default/host/guardmode" "cli-only"                   runner_kind_default_flag host-native write_guard_mode
assert_emits "default/host/bashguard" "false"                      runner_kind_default_flag host-native needs_bash_guard

# dispatch_route values must stay within the closed core enum.
assert_file_contains "route/enum-cli"  "$REPO_ROOT/core/policy/dispatch-routes.yaml" "main_thread_bash_background" && pass "route/enum-cli"
assert_file_contains "route/enum-host" "$REPO_ROOT/core/policy/dispatch-routes.yaml" "agent_executor" && pass "route/enum-host"

# --- bad inputs to the mapping ----------------------------------------------
assert_rejects "default/unknown-kind" runner_kind_default_flag bogus dispatch_route
assert_rejects "default/unknown-flag" runner_kind_default_flag cli-subprocess bogus_flag
assert_rejects "default/arity"        runner_kind_default_flag cli-subprocess

# --- resolve: no override falls back to default -----------------------------
assert_emits "resolve/default"      "true"  runner_kind_resolve_flag cli-subprocess needs_bash_guard
assert_emits "resolve/empty-arg"    "true"  runner_kind_resolve_flag cli-subprocess needs_bash_guard ""

# --- resolve: valid override wins (the asymmetry seam) ----------------------
# A cli-subprocess adapter that does not need the bash guard declares it without
# a core edit — proves the override path future adapters (opencode/agy) rely on.
assert_emits "resolve/override-bashguard" "false"          runner_kind_resolve_flag cli-subprocess needs_bash_guard false
assert_emits "resolve/override-guardmode" "cli-only"       runner_kind_resolve_flag cli-subprocess write_guard_mode cli-only
assert_emits "resolve/override-route"     "agent_executor" runner_kind_resolve_flag cli-subprocess dispatch_route agent_executor

# --- resolve: invalid override rejected, not silently passed through --------
assert_rejects "resolve/bad-bashguard"  runner_kind_resolve_flag cli-subprocess needs_bash_guard yes
assert_rejects "resolve/bad-guardmode"  runner_kind_resolve_flag cli-subprocess write_guard_mode preToolUse
assert_rejects "resolve/bad-route"      runner_kind_resolve_flag cli-subprocess dispatch_route foreground

# --- manifest field reader --------------------------------------------------
assert_emits "manifest/read-codex" "cli-subprocess" \
  runner_kind_manifest_field "$REPO_ROOT/adapters/codex/adapter.yaml" runner_kind
assert_emits "manifest/read-claude" "host-native" \
  runner_kind_manifest_field "$REPO_ROOT/adapters/claude/adapter.yaml" runner_kind
# absent key prints nothing and exits 0 (caller falls back to a default)
assert_emits "manifest/absent-key" "" \
  runner_kind_manifest_field "$REPO_ROOT/adapters/codex/adapter.yaml" no_such_key

# --- backfilled manifests must declare the kind that matches their topology --
assert_file_matches "manifest/codex-kind"  "$REPO_ROOT/adapters/codex/adapter.yaml"  "^runner_kind:[[:space:]]*cli-subprocess" && pass "manifest/codex-kind"
assert_file_matches "manifest/claude-kind" "$REPO_ROOT/adapters/claude/adapter.yaml" "^runner_kind:[[:space:]]*host-native" && pass "manifest/claude-kind"

# --- end-to-end: read a real manifest, derive its full flag set -------------
# Mirrors how the host PM (claude OR codex) will resolve any executor's topology
# from the manifest alone — no PM-host assumption baked in.
for adapter in codex claude; do
  kind="$(runner_kind_manifest_field "$REPO_ROOT/adapters/$adapter/adapter.yaml" runner_kind)"
  route="$(runner_kind_resolve_flag "$kind" dispatch_route "")"
  case "$adapter" in
    codex)  [[ "$route" == "main_thread_bash_background" ]] && pass "e2e/$adapter-route" || fail "e2e/$adapter-route" "got $route" ;;
    claude) [[ "$route" == "agent_executor" ]]              && pass "e2e/$adapter-route" || fail "e2e/$adapter-route" "got $route" ;;
  esac
done

# --- generator template emits runner_kind for new adapters ------------------
assert_file_contains "generator/emits-field" "$SCRIPT_DIR/lib/pmctl-adapter.sh" "runner_kind: cli-subprocess" && pass "generator/emits-field"

th_summary
