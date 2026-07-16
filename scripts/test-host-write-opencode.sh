#!/usr/bin/env bash
# Regression suite for OpenCode host stage-3 config/command ownership.
# shellcheck disable=SC1091,SC2015,SC2154,SC2016
# SC1091/SC2154: the test harness is a runtime source and owns tmp_root.
# SC2015: compact pass/fail assertions intentionally use the harness idiom.
# SC2016: jq programs and literal OpenCode $ARGUMENTS must not shell-expand.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-host-write-opencode" "$@"

install_oc() {
  XDG_CONFIG_HOME="$1" bash "$REPO_ROOT/hosts/opencode/bin/install.sh" \
    --repo-root "$REPO_ROOT" "${@:2}"
}
uninstall_oc() {
  XDG_CONFIG_HOME="$1" bash "$REPO_ROOT/hosts/opencode/bin/uninstall.sh" \
    --repo-root "$REPO_ROOT" "${@:2}"
}

# Behavior: the OpenCode manifest declares symmetric stage-3 write modules.
# Steps: inspect both manifest scalars and require their repository paths.
test_manifest_declares_stage3_modules() {
  local name="opencode-manifest-declares-stage3-modules"
  should_run "$name" || return 0
  grep -q '^install_module: hosts/opencode/bin/install.sh$' "$REPO_ROOT/hosts/opencode/host.yaml" \
    && grep -q '^uninstall_module: hosts/opencode/bin/uninstall.sh$' "$REPO_ROOT/hosts/opencode/host.yaml" \
    && grep -q '^doctor_module: hosts/opencode/lib/doctor.sh$' "$REPO_ROOT/hosts/opencode/host.yaml" \
    && pass "$name" || fail "$name" "OpenCode write modules are not declared"
}

# Behavior: legacy OpenCode entrypoints remain thin, stderr-only compatibility shims.
# Steps: compare both dry-run surfaces, then install and uninstall through the legacy paths.
test_legacy_entrypoints_forward_without_behavior_drift() {
  local name="opencode-legacy-entrypoints-forward-without-behavior-drift"
  should_run "$name" || return 0
  local xdg="$tmp_root/legacy/config" legacy_out="$tmp_root/legacy.out"
  local module_out="$tmp_root/module.out" legacy_err="$tmp_root/legacy.err"
  local legacy_uninstall_out="$tmp_root/legacy-uninstall.out"
  local module_uninstall_out="$tmp_root/module-uninstall.out"
  local legacy_uninstall_err="$tmp_root/legacy-uninstall.err"
  mkdir -p "$tmp_root/legacy"
  XDG_CONFIG_HOME="$xdg" bash "$REPO_ROOT/hosts/opencode/bin/install.sh" \
    --repo-root "$REPO_ROOT" --dry-run >"$module_out" 2>/dev/null
  XDG_CONFIG_HOME="$xdg" bash "$REPO_ROOT/scripts/install-host-opencode.sh" \
    --dry-run >"$legacy_out" 2>"$legacy_err"
  if ! cmp -s "$module_out" "$legacy_out" \
      || ! grep -q 'deprecated path' "$legacy_err" \
      || [[ -e "$xdg" ]]; then
    fail "$name" "legacy dry-run changed stdout or filesystem behavior"
    return
  fi
  XDG_CONFIG_HOME="$xdg" bash "$REPO_ROOT/scripts/install-host-opencode.sh" \
    >/dev/null 2>/dev/null
  uninstall_oc "$xdg" --dry-run >"$module_uninstall_out" 2>/dev/null
  XDG_CONFIG_HOME="$xdg" bash "$REPO_ROOT/scripts/uninstall-host-opencode.sh" \
    --dry-run >"$legacy_uninstall_out" 2>"$legacy_uninstall_err"
  if ! cmp -s "$module_uninstall_out" "$legacy_uninstall_out" \
      || ! grep -q 'deprecated path' "$legacy_uninstall_err" \
      || [[ ! -e "$xdg/opencode/opencode.json" ]]; then
    fail "$name" "legacy uninstall dry-run changed stdout or filesystem behavior"
    return
  fi
  XDG_CONFIG_HOME="$xdg" bash "$REPO_ROOT/scripts/uninstall-host-opencode.sh" \
    >/dev/null 2>/dev/null
  [[ ! -e "$xdg/opencode/opencode.json" ]] \
    && pass "$name" || fail "$name" "legacy uninstall did not remove the managed config"
}

# Behavior: OpenCode dry-run reports a plan without creating config state.
# Steps: run against an absent XDG root and assert the root remains absent.
test_dry_run_has_no_side_effect() {
  local name="opencode-install-dry-run-has-no-side-effect"
  should_run "$name" || return 0
  local xdg="$tmp_root/dry/config"
  install_oc "$xdg" --dry-run >/dev/null 2>&1
  [[ ! -e "$xdg" ]] && pass "$name" || fail "$name" "dry-run created $xdg"
}

# Behavior: a fresh install writes the complete policy/command/tool receipt once.
# Steps: install twice, then inspect the managed JSON and generated artifacts.
test_fresh_install_and_idempotency() {
  local name="opencode-fresh-install-and-idempotency"
  should_run "$name" || return 0
  local xdg="$tmp_root/fresh/config" config command pattern="$REPO_ROOT/cli/pmctl *"
  config="$xdg/opencode/opencode.json"
  command="$xdg/opencode/commands/pm.md"
  local tool_file="$xdg/opencode/tools/pm_prepare.ts"
  install_oc "$xdg" >/dev/null 2>&1
  install_oc "$xdg" >/dev/null 2>&1
  if jq -e --arg p "$pattern" '.permission.bash["*"]=="deny" and .permission.bash[$p]=="allow" and .permission.pm_prepare=="allow"' "$config" >/dev/null \
      && grep -Fq -- 'custom `pm_prepare` tool' "$command" \
      && grep -Fq -- '$ARGUMENTS' "$command" \
      && grep -Fq -- "const PMCTL = \"$REPO_ROOT/cli/pmctl\"" "$tool_file" \
      && [[ -f "$config.pm-dispatch-receipt.json" ]]; then
    pass "$name"
  else
    fail "$name" "managed permission/command/receipt state is incomplete"
  fi
}

# Behavior: uninstall restores a pre-existing user config byte-for-byte.
# Steps: save custom config bytes, install/uninstall, and compare the result.
test_existing_config_restored_byte_exact() {
  local name="opencode-existing-config-restored-byte-exact"
  should_run "$name" || return 0
  local xdg="$tmp_root/restore/config" config before="$tmp_root/restore-before"
  config="$xdg/opencode/opencode.json"
  mkdir -p "$(dirname "$config")"
  printf '{\n  "theme": "custom"\n}\n' > "$config"
  cp "$config" "$before"
  install_oc "$xdg" >/dev/null 2>&1
  uninstall_oc "$xdg" >/dev/null 2>&1
  cmp -s "$before" "$config" && pass "$name" || fail "$name" "original config bytes were not restored"
}

# Behavior: an ordering-sensitive user Bash policy is refused without mutation.
# Steps: seed permission.bash, install, then verify exit 1 and unchanged bytes.
test_existing_bash_policy_refused() {
  local name="opencode-existing-bash-policy-refused"
  should_run "$name" || return 0
  local xdg="$tmp_root/conflict/config" config before="$tmp_root/conflict-before" rc=0
  config="$xdg/opencode/opencode.json"
  mkdir -p "$(dirname "$config")"
  printf '{"permission":{"bash":"allow"}}\n' > "$config"
  cp "$config" "$before"
  install_oc "$xdg" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 1 ]] && cmp -s "$before" "$config" \
    && [[ ! -e "$config.pm-dispatch-receipt.json" && ! -e "$xdg/opencode/commands/pm.md" ]] \
    && pass "$name" || fail "$name" "existing Bash policy was not refused without mutation (rc=$rc)"
}

# Behavior: a user-owned permission shorthand is never replaced by an object.
# Steps: seed shorthand JSON, install, and assert refusal with no receipt.
test_existing_permission_shorthand_refused() {
  local name="opencode-existing-permission-shorthand-refused"
  should_run "$name" || return 0
  local xdg="$tmp_root/shorthand/config" config rc=0
  config="$xdg/opencode/opencode.json"
  mkdir -p "$(dirname "$config")"
  printf '{"permission":"allow"}\n' > "$config"
  install_oc "$xdg" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 1 ]] && grep -q '"permission":"allow"' "$config" \
    && [[ ! -e "$config.pm-dispatch-receipt.json" ]] \
    && pass "$name" || fail "$name" "permission shorthand was not preserved (rc=$rc)"
}

# Behavior: uninstall preserves managed config changed after installation.
# Steps: install, mutate a non-schema field, then assert fail-closed teardown.
test_modified_managed_config_blocks_uninstall() {
  local name="opencode-modified-managed-config-blocks-uninstall"
  should_run "$name" || return 0
  local xdg="$tmp_root/modified/config" config tmp rc=0
  config="$xdg/opencode/opencode.json"
  install_oc "$xdg" >/dev/null 2>&1
  tmp="$config.tmp"
  jq '.theme="changed-after-install"' "$config" > "$tmp" && mv "$tmp" "$config"
  uninstall_oc "$xdg" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 1 && -f "$config.pm-dispatch-receipt.json" ]] \
    && jq -e '.theme=="changed-after-install"' "$config" >/dev/null \
    && pass "$name" || fail "$name" "uninstall overwrote or lost modified config (rc=$rc)"
}

# Behavior: an OpenCode-added $schema field does not block safe uninstall.
# Steps: install, add only $schema, then assert managed state is removed.
test_host_schema_normalization_allows_uninstall() {
  local name="opencode-host-schema-normalization-allows-uninstall"
  should_run "$name" || return 0
  local xdg="$tmp_root/schema-normalize/config" config tmp
  config="$xdg/opencode/opencode.json"
  install_oc "$xdg" >/dev/null 2>&1
  tmp="$config.tmp"
  jq '."$schema"="https://opencode.ai/config.json"' "$config" > "$tmp" && mv "$tmp" "$config"
  if uninstall_oc "$xdg" >/dev/null 2>&1 && [[ ! -e "$config" ]]; then
    pass "$name"
  else
    fail "$name" "host-added schema normalization incorrectly blocked uninstall"
  fi
}

# Behavior: uninstall removes every artifact from a fresh managed install.
# Steps: install into an empty XDG root, uninstall, and check all owned paths.
test_fresh_uninstall_removes_managed_files() {
  local name="opencode-fresh-uninstall-removes-managed-files"
  should_run "$name" || return 0
  local xdg="$tmp_root/remove/config" config
  config="$xdg/opencode/opencode.json"
  install_oc "$xdg" >/dev/null 2>&1
  uninstall_oc "$xdg" >/dev/null 2>&1
  [[ ! -e "$config" && ! -e "$xdg/opencode/commands/pm.md" && ! -e "$xdg/opencode/tools/pm_prepare.ts" && ! -e "$config.pm-dispatch-receipt.json" ]] \
    && pass "$name" || fail "$name" "fresh managed files remain after uninstall"
}

# Behavior: doctor reports the effective native PM and command-guard tuples.
# Steps: install, stub the host binary, source the doctor module, inspect output.
test_doctor_reports_wired_effective_capabilities() {
  local name="opencode-doctor-reports-wired-effective-capabilities"
  should_run "$name" || return 0
  local xdg="$tmp_root/doctor/config" fakebin="$tmp_root/doctor/bin" out
  install_oc "$xdg" >/dev/null 2>&1
  mkdir -p "$fakebin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/opencode"
  chmod +x "$fakebin/opencode"
  out="$(
    XDG_CONFIG_HOME="$xdg" PATH="$fakebin:$PATH" bash -c '
      set -u
      REPO_ROOT="$1"
      . "$REPO_ROOT/scripts/lib/host-manifest.sh"
      emit_capability() { printf "%s|%s|%s|%s\n" "$1" "$5" "$6" "$7"; }
      emit_check() { :; }
      . "$REPO_ROOT/hosts/opencode/lib/doctor.sh"
      doctor_host_opencode_run
    ' _ "$REPO_ROOT"
  )"
  if grep -q '^host.opencode.pm-command|host_native|none|partial$' <<<"$out" \
      && grep -q '^host.opencode.command-guard|host_policy|blocking|full$' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "doctor did not report wired PM/guard tuples: $out"
  fi
}

# Behavior: the shared doctor discovers OpenCode through doctor_module, not a scripts/lib glob.
# Steps: install in a sandbox, invoke the real doctor, and assert the OpenCode capability record exists.
test_doctor_loader_follows_manifest_module() {
  local name="opencode-doctor-loader-follows-manifest-module"
  should_run "$name" || return 0
  local home="$tmp_root/doctor-loader/home" xdg="$tmp_root/doctor-loader/config"
  local codex="$tmp_root/doctor-loader/codex" fakebin="$tmp_root/doctor-loader/bin" out rc=0
  install_oc "$xdg" >/dev/null 2>&1
  mkdir -p "$fakebin" "$home"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/opencode"
  chmod +x "$fakebin/opencode"
  out="$(HOME="$home" XDG_CONFIG_HOME="$xdg" CODEX_HOME="$codex" \
    CLAUDE_CONFIG_DIR="$home/.claude" PATH="$fakebin:$PATH" \
    bash "$REPO_ROOT/scripts/doctor.sh" --json --repo "$REPO_ROOT" 2>/dev/null)" || rc=$?
  if printf '%s\n' "$out" | jq -e \
      'select(.check == "host.opencode.pm-command" and .host == "opencode")' \
      >/dev/null; then
    pass "$name"
  else
    fail "$name" "manifest-declared OpenCode doctor module was not loaded (rc=$rc)"
  fi
}

# Behavior: the generic dispatcher installs and removes OpenCode symmetrically.
# Steps: run top-level install/uninstall and inspect the OpenCode managed surface.
test_generic_install_uninstall_integration() {
  local name="opencode-generic-install-uninstall-integration"
  should_run "$name" || return 0
  local home="$tmp_root/integration/home" xdg="$tmp_root/integration/config"
  local claude="$tmp_root/integration/claude" codex="$tmp_root/integration/codex" bin="$tmp_root/integration/bin"
  HOME="$home" XDG_CONFIG_HOME="$xdg" CLAUDE_HOME="$claude" CODEX_HOME="$codex" PMCTL_BIN_DIR="$bin" \
    bash "$REPO_ROOT/install.sh" --profile minimal --enable-host opencode >/dev/null 2>&1
  [[ -f "$xdg/opencode/commands/pm.md" ]] || { fail "$name" "generic install did not wire OpenCode"; return; }
  HOME="$home" XDG_CONFIG_HOME="$xdg" CLAUDE_HOME="$claude" CODEX_HOME="$codex" PMCTL_BIN_DIR="$bin" \
    bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
  [[ ! -e "$xdg/opencode/opencode.json" && ! -e "$xdg/opencode/commands/pm.md" && ! -e "$xdg/opencode/tools/pm_prepare.ts" ]] \
    && pass "$name" || fail "$name" "generic uninstall left OpenCode wiring"
}

# Behavior: quote/newline checkout characters stay inside one inert TS literal.
# Steps: clone required files under a hostile path, install, compare serialization.
test_hostile_checkout_path_is_typescript_escaped() {
  local name="opencode-hostile-checkout-path-is-typescript-escaped"
  should_run "$name" || return 0
  local hostile_root xdg tool_file expected_literal expected_line
  hostile_root="$tmp_root/hostile-\";globalThis.PWNED=true;"$'\n'"next"
  mkdir -p "$hostile_root"
  cp -R "$REPO_ROOT/scripts" "$REPO_ROOT/hosts" "$REPO_ROOT/cli" "$hostile_root/"
  xdg="$tmp_root/hostile-config"
  XDG_CONFIG_HOME="$xdg" bash "$hostile_root/hosts/opencode/bin/install.sh" \
    --repo-root "$hostile_root" >/dev/null 2>&1
  tool_file="$xdg/opencode/tools/pm_prepare.ts"
  expected_literal="$(jq -Rn --arg v "$hostile_root/cli/pmctl" '$v')"
  expected_line="const PMCTL = $expected_literal"
  if [[ "$(grep -c '^const PMCTL = ' "$tool_file")" -eq 1 ]] \
      && grep -Fxq -- "$expected_line" "$tool_file" \
      && [[ "$(grep -c 'globalThis.PWNED' "$tool_file")" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "hostile checkout path was not serialized as one inert literal"
  fi
}

# Behavior: a host policy conflict is detected before any Claude/base write.
# Steps: seed a conflict, run generic install, and assert all base roots absent.
test_generic_conflict_preflight_leaves_base_untouched() {
  local name="opencode-generic-conflict-preflight-leaves-base-untouched"
  should_run "$name" || return 0
  local home="$tmp_root/generic-conflict/home" xdg="$tmp_root/generic-conflict/config"
  local claude="$tmp_root/generic-conflict/claude" codex="$tmp_root/generic-conflict/codex"
  local bin="$tmp_root/generic-conflict/bin" config before rc=0
  config="$xdg/opencode/opencode.json"
  mkdir -p "$(dirname "$config")"
  printf '{"permission":{"bash":"allow"}}\n' > "$config"
  before="$tmp_root/generic-conflict-before"
  cp "$config" "$before"
  HOME="$home" XDG_CONFIG_HOME="$xdg" CLAUDE_HOME="$claude" CODEX_HOME="$codex" PMCTL_BIN_DIR="$bin" \
    bash "$REPO_ROOT/install.sh" --profile minimal --enable-host opencode >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 1 ]] && cmp -s "$before" "$config" \
      && [[ ! -e "$claude" && ! -e "$bin" && ! -e "$config.pm-dispatch-receipt.json" ]]; then
    pass "$name"
  else
    fail "$name" "generic conflict left partial base install state (rc=$rc)"
  fi
}

test_manifest_declares_stage3_modules
test_legacy_entrypoints_forward_without_behavior_drift
test_dry_run_has_no_side_effect
test_fresh_install_and_idempotency
test_existing_config_restored_byte_exact
test_existing_bash_policy_refused
test_existing_permission_shorthand_refused
test_modified_managed_config_blocks_uninstall
test_host_schema_normalization_allows_uninstall
test_fresh_uninstall_removes_managed_files
test_doctor_reports_wired_effective_capabilities
test_doctor_loader_follows_manifest_module
test_generic_install_uninstall_integration
test_hostile_checkout_path_is_typescript_escaped
test_generic_conflict_preflight_leaves_base_untouched

th_summary
