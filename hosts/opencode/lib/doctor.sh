#!/usr/bin/env bash
# Sourceable OpenCode-host doctor module discovered from the host manifest.

_doctor_host_opencode_config_path() {
  host_manifest_target_path "$REPO_ROOT" opencode config opencode-config-json true
}

_doctor_host_opencode_commands_path() {
  host_manifest_target_path "$REPO_ROOT" opencode commands copy-tree true
}

_doctor_host_opencode_tools_path() {
  host_manifest_target_path "$REPO_ROOT" opencode tools copy-tree true
}

_doctor_host_opencode_pm_command() {
  local commands tools command_file tool_file expected_pmctl="$REPO_ROOT/cli/pmctl"
  commands="$(_doctor_host_opencode_commands_path)" || {
    emit_capability host.opencode.pm-command warn opencode pm_command_interface \
      none none none evolving probed \
      "hosts/opencode/host.yaml has no managed commands target"
    return
  }
  tools="$(_doctor_host_opencode_tools_path)" || {
    emit_capability host.opencode.pm-command warn opencode pm_command_interface \
      none none none evolving probed \
      "hosts/opencode/host.yaml has no managed tools target"
    return
  }
  command_file="$commands/pm.md"
  tool_file="$tools/pm_prepare.ts"
  # shellcheck disable=SC2016  # Backticks are literal OpenCode command prose.
  if [[ -f "$command_file" && -f "$tool_file" ]] \
      && grep -Fq -- 'custom `pm_prepare` tool' "$command_file" \
      && grep -Fq -- "const PMCTL = \"$expected_pmctl\"" "$tool_file"; then
    emit_capability host.opencode.pm-command ok opencode pm_command_interface \
      host_native none partial evolving probed \
      "OpenCode /pm command + argv-safe prepare tool wired to this checkout ($command_file)"
  else
    emit_capability host.opencode.pm-command ok opencode pm_command_interface \
      none none none evolving probed \
      "OpenCode /pm custom command not wired (opt-in via install.sh --enable-host opencode)"
  fi
}

_doctor_host_opencode_policy() {
  local config
  config="$(_doctor_host_opencode_config_path)" || {
    emit_check host.opencode.manifest-parity warn \
      "hosts/opencode/host.yaml has no opencode-config-json target"
    return
  }
  if [[ ! -f "$config" ]]; then
    emit_capability host.opencode.command-guard ok opencode command_guard \
      none none none evolving probed \
      "OpenCode command guard not configured (stage 3 write path not installed; expected at $config)"
    return
  fi
  if ! command -v jq >/dev/null 2>&1 || ! jq empty "$config" >/dev/null 2>&1; then
    emit_capability host.opencode.command-guard warn opencode command_guard \
      none none none evolving probed \
      "OpenCode config exists but is not valid JSON ($config)"
    return
  fi
  local pmctl_pattern="$REPO_ROOT/cli/pmctl *"
  if jq -e --arg pattern "$pmctl_pattern" \
      '.permission.bash | type == "object" and .["*"] == "deny" and .[$pattern] == "allow"' \
      "$config" >/dev/null 2>&1; then
    emit_capability host.opencode.command-guard ok opencode command_guard \
      host_policy blocking full evolving probed \
      "OpenCode native catch-all Bash deny with checkout-specific pmctl allow detected ($config)"
  elif jq -e '.permission.bash == "deny"' "$config" >/dev/null 2>&1; then
    emit_capability host.opencode.command-guard warn opencode command_guard \
      host_policy blocking full evolving probed \
      "OpenCode native bash deny policy uses bare-string form; CC-476 requires per-pattern object form before managed wiring"
  else
    emit_capability host.opencode.command-guard ok opencode command_guard \
      none none none evolving probed \
      "OpenCode config found without the probed managed command-guard shape ($config)"
  fi
}

doctor_host_opencode_run() {
  if ! command -v opencode >/dev/null 2>&1; then
    emit_capability host.opencode.binary ok opencode pm_command_interface \
      none none none evolving assumed \
      "opencode binary not on PATH — PM command interface remains unverified"
    return
  fi
  emit_capability host.opencode.binary ok opencode pm_command_interface \
    cli_wrapper none partial evolving probed \
    "opencode binary on PATH; pmctl is available as the batch coordination spine"
  _doctor_host_opencode_pm_command
  _doctor_host_opencode_policy
}
