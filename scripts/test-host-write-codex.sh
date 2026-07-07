#!/usr/bin/env bash
# Regression suite for the codex-host install write path:
# scripts/lib/host-manifest.sh, scripts/install-guards-codex.sh,
# scripts/uninstall-guards-codex.sh, scripts/hook-codex-command-guard.sh, and
# the install.sh/uninstall.sh integration points that call them.
#
# Every case runs against a throwaway $CODEX_HOME under $tmp_root — never the
# real ~/.codex. CODEX_HOME is exported per-case (not left set across cases)
# so a bug that reads a stale global never silently passes.
#
# Runs via: scripts/test-host-write-codex.sh
# Filter:   scripts/test-host-write-codex.sh --filter <pattern>
# List:     scripts/test-host-write-codex.sh --list

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-host-write-codex" "$@"

# shellcheck source=scripts/lib/host-manifest.sh
. "$SCRIPT_DIR/lib/host-manifest.sh"

# th_init already created $tmp_root with its own EXIT trap; reuse it.

# --- host-manifest.sh reader --------------------------------------------

test_host_manifest_reads_codex_install_targets() {
  local name="host-manifest-reads-codex-install-targets"
  should_run "$name" || return 0
  local manifest found=0
  manifest="$(host_manifest_file "$REPO_ROOT" codex)"
  while IFS=$'\t' read -r id path fmt managed; do
    if [[ "$id" == "hooks" && "$fmt" == "codex-hooks-json" && "$managed" == "true" ]]; then
      found=1
    fi
  done < <(host_manifest_install_targets "$manifest")
  [[ "$found" -eq 1 ]] && pass "$name" || fail "$name" "expected a managed hooks/codex-hooks-json install_target row"
}

test_host_manifest_expand_path_uses_env_override() {
  local name="host-manifest-expand-path-uses-env-override"
  should_run "$name" || return 0
  local expanded
  expanded="$(CODEX_HOME=/tmp/fake-codex-home host_manifest_expand_path '$CODEX_HOME/hooks.json')"
  [[ "$expanded" == "/tmp/fake-codex-home/hooks.json" ]] && pass "$name" || fail "$name" "got: $expanded"
}

test_host_manifest_expand_path_default_when_unset() {
  local name="host-manifest-expand-path-default-when-unset"
  should_run "$name" || return 0
  local expanded
  expanded="$(unset CODEX_HOME; host_manifest_expand_path '$CODEX_HOME/hooks.json')"
  [[ "$expanded" == "$HOME/.codex/hooks.json" ]] && pass "$name" || fail "$name" "got: $expanded"
}

# --- install-guards-codex.sh ---------------------------------------------

test_install_guards_codex_dry_run_no_side_effect() {
  local name="install-guards-codex-dry-run-no-side-effect"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-dryrun/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" --dry-run >/dev/null 2>&1
  [[ ! -e "$codex_home" ]] && pass "$name" || fail "$name" "$codex_home should not exist after --dry-run"
}

test_install_guards_codex_wires_hook() {
  local name="install-guards-codex-wires-hook"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-wire/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  if [[ ! -f "$codex_home/hooks.json" ]]; then
    fail "$name" "hooks.json not created"
    return
  fi
  if jq -e '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.command | endswith("hook-codex-command-guard.sh"))' \
      "$codex_home/hooks.json" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "expected PreToolUse Bash hook not found in $codex_home/hooks.json"
  fi
}

test_install_guards_codex_idempotent() {
  local name="install-guards-codex-idempotent"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-idem/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  local before after
  before="$(jq -c '.hooks.PreToolUse' "$codex_home/hooks.json")"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  after="$(jq -c '.hooks.PreToolUse' "$codex_home/hooks.json")"
  [[ "$before" == "$after" ]] && [[ "$(jq '.hooks.PreToolUse | length' "$codex_home/hooks.json")" == "1" ]] \
    && pass "$name" || fail "$name" "re-running should not duplicate the managed hook entry"
}

test_install_guards_codex_missing_manifest_target_errors() {
  local name="install-guards-codex-missing-managed-target-errors"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-nomanifest/.codex"
  local mock_repo="$tmp_root/ic-nomanifest-repo"
  mkdir -p "$mock_repo/hosts/codex" "$mock_repo/scripts/lib"
  printf 'schema_version: 1\nhost_name: codex\ninstall_targets:\n  - id: config\n    path: "$CODEX_HOME/config.toml"\n    format: codex-config-toml\n    managed: false\n' \
    > "$mock_repo/hosts/codex/host.yaml"
  cp "$SCRIPT_DIR/lib/host-manifest.sh" "$mock_repo/scripts/lib/host-manifest.sh"
  cp "$SCRIPT_DIR/install-guards-codex.sh" "$mock_repo/scripts/install-guards-codex.sh"
  cp "$SCRIPT_DIR/hook-codex-command-guard.sh" "$mock_repo/scripts/hook-codex-command-guard.sh"
  local rc=0
  CODEX_HOME="$codex_home" bash "$mock_repo/scripts/install-guards-codex.sh" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && pass "$name" || fail "$name" "expected non-zero exit when no managed hooks install_target is declared"
}

# --- uninstall-guards-codex.sh --------------------------------------------

test_uninstall_guards_codex_removes_hook() {
  local name="uninstall-guards-codex-removes-hook"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-remove/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1
  local content
  content="$(jq -c . "$codex_home/hooks.json")"
  [[ "$content" == "{}" ]] && pass "$name" || fail "$name" "expected empty hooks.json, got: $content"
}

test_uninstall_guards_codex_preserves_unrelated_hook() {
  local name="uninstall-guards-codex-preserves-unrelated-hook"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-preserve/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  jq '.hooks.PreToolUse += [{"matcher":"Bash","hooks":[{"type":"command","command":"/some/other/tool/hook.sh"}]}]' \
    "$codex_home/hooks.json" > "$codex_home/hooks.json.tmp" && mv "$codex_home/hooks.json.tmp" "$codex_home/hooks.json"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1
  if jq -e '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.command=="/some/other/tool/hook.sh")' \
      "$codex_home/hooks.json" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "unrelated hook entry should survive uninstall"
  fi
}

test_uninstall_guards_codex_idempotent_when_absent() {
  local name="uninstall-guards-codex-idempotent-when-absent"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-absent/.codex"
  local rc=0
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 0 ]] && pass "$name" || fail "$name" "expected exit 0 when nothing is wired"
}

# --- hook-codex-command-guard.sh ------------------------------------------

test_hook_codex_command_guard_allows_benign_command() {
  local name="hook-codex-command-guard-allows-benign-command"
  should_run "$name" || return 0
  local rc=0
  printf '{"tool_input":{"command":"git status","cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/guard-logs" "$SCRIPT_DIR/hook-codex-command-guard.sh" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 0 ]] && pass "$name" || fail "$name" "expected exit 0 for a benign command, got rc=$rc"
}

test_hook_codex_command_guard_denies_destructive_command() {
  local name="hook-codex-command-guard-denies-destructive-command"
  should_run "$name" || return 0
  local stderr_file rc
  stderr_file="$(mktemp)"
  printf '{"tool_input":{"command":"rm -rf /tmp/whatever","cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/guard-logs" "$SCRIPT_DIR/hook-codex-command-guard.sh" 2>"$stderr_file" 1>/dev/null
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "denylisted pattern" "$stderr_file"; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit + denylist message, got rc=$rc stderr=$(cat "$stderr_file")"
  fi
  rm -f "$stderr_file"
}

test_hook_codex_command_guard_missing_command_denies() {
  local name="hook-codex-command-guard-missing-command-denies"
  should_run "$name" || return 0
  local rc=0
  printf '{"tool_input":{"cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/guard-logs" "$SCRIPT_DIR/hook-codex-command-guard.sh" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && pass "$name" || fail "$name" "expected non-zero exit for missing tool_input.command"
}

# --- install.sh / uninstall.sh integration --------------------------------

test_install_default_never_touches_codex_home() {
  local name="install-default-never-touches-codex-home"
  should_run "$name" || return 0
  local claude_home="$tmp_root/int-default/.claude"
  local codex_home="$tmp_root/int-default/.codex"
  local pmctl_bin_dir="$tmp_root/int-default/pmctl-bin"
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/install.sh" --profile minimal >/dev/null 2>&1
  [[ ! -e "$codex_home" ]] && pass "$name" || fail "$name" "\$CODEX_HOME should stay untouched without --enable-codex-command-guard"
}

test_install_opt_in_wires_codex_and_uninstall_removes_it() {
  local name="install-opt-in-wires-codex-and-uninstall-removes-it"
  should_run "$name" || return 0
  local claude_home="$tmp_root/int-optin/.claude"
  local codex_home="$tmp_root/int-optin/.codex"
  local pmctl_bin_dir="$tmp_root/int-optin/pmctl-bin"
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/install.sh" --profile minimal --enable-codex-command-guard >/dev/null 2>&1
  if [[ ! -f "$codex_home/hooks.json" ]] || ! jq -e '.hooks.PreToolUse[]? | select(.matcher=="Bash")' "$codex_home/hooks.json" >/dev/null 2>&1; then
    fail "$name" "install.sh --enable-codex-command-guard should wire the codex hook"
    return
  fi
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
  local content
  content="$(jq -c . "$codex_home/hooks.json" 2>/dev/null)"
  [[ "$content" == "{}" ]] && pass "$name" || fail "$name" "uninstall.sh should symmetrically remove the codex hook, got: $content"
}

test_uninstall_removes_codex_hook_when_codex_not_on_path() {
  # Regression lock: uninstall.sh must not gate codex-host teardown on
  # codex_available — a codex uninstall/reinstall or PATH change between
  # install and uninstall must not leave a stale global hook behind.
  local name="uninstall-removes-codex-hook-when-codex-not-on-path"
  should_run "$name" || return 0
  local claude_home="$tmp_root/int-nopath/.claude"
  local codex_home="$tmp_root/int-nopath/.codex"
  local pmctl_bin_dir="$tmp_root/int-nopath/pmctl-bin"
  local minimal_path="/usr/bin:/bin"
  PATH="$minimal_path" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/install.sh" --profile minimal --enable-codex-command-guard >/dev/null 2>&1
  if [[ ! -f "$codex_home/hooks.json" ]]; then
    fail "$name" "setup: install --enable-codex-command-guard should wire the hook even without codex on PATH"
    return
  fi
  PATH="$minimal_path" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
  local content
  content="$(jq -c . "$codex_home/hooks.json" 2>/dev/null)"
  [[ "$content" == "{}" ]] && pass "$name" || fail "$name" "uninstall.sh left the codex hook behind when codex was not on PATH, got: $content"
}

test_host_manifest_reads_codex_install_targets
test_host_manifest_expand_path_uses_env_override
test_host_manifest_expand_path_default_when_unset
test_install_guards_codex_dry_run_no_side_effect
test_install_guards_codex_wires_hook
test_install_guards_codex_idempotent
test_install_guards_codex_missing_manifest_target_errors
test_uninstall_guards_codex_removes_hook
test_uninstall_guards_codex_preserves_unrelated_hook
test_uninstall_guards_codex_idempotent_when_absent
test_hook_codex_command_guard_allows_benign_command
test_hook_codex_command_guard_denies_destructive_command
test_hook_codex_command_guard_missing_command_denies
test_install_default_never_touches_codex_home
test_install_opt_in_wires_codex_and_uninstall_removes_it
test_uninstall_removes_codex_hook_when_codex_not_on_path

th_summary
