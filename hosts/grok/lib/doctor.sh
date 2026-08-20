#!/usr/bin/env bash
# Sourceable grok-host doctor module discovered from the host manifest.
#
# Host-specific doctor probes for the grok host (Grok Build TUI as the PM
# runtime). Sourced by runtime/bin/doctor.sh's manifest-driven host-module
# loader; never executed standalone. The loader calls doctor_host_grok_run()
# — the single required entry point. emit_check/emit_capability come from
# doctor.sh.
#
# Read-only by contract: only PATH and well-known file probes. Never run a
# grok CLI command that could hang, mutate state, or incur cost.
#
# MVP has no install write path (install_module: null), so capabilities that
# are not wired are reported as ok with provider=none — the expected default
# state, not an install defect.

_doctor_host_grok_config_path() {
  local manifest="$REPO_ROOT/hosts/grok/host.yaml"
  local id path fmt _managed
  while IFS=$'\t' read -r id path fmt _managed; do
    [[ "$id" == "config" && "$fmt" == "grok-config-toml" ]] || continue
    host_manifest_expand_path "$REPO_ROOT" grok "$path"
    return 0
  done < <(host_manifest_install_targets "$manifest")
  return 1
}

_doctor_host_grok_binary() {
  if command -v grok >/dev/null 2>&1; then
    emit_check host.grok.binary ok "grok available on PATH ($(command -v grok))"
  else
    emit_check host.grok.binary warn "grok not found on PATH — host and executor routes are unavailable" \
      "Install Grok Build CLI and ensure 'grok' is on \$PATH"
  fi
}

_doctor_host_grok_config() {
  local config
  config="$(_doctor_host_grok_config_path)" || {
    emit_check host.grok.config warn "hosts/grok/host.yaml has no grok-config-toml target"
    return
  }
  if [[ -f "$config" ]]; then
    emit_check host.grok.config ok "grok config present ($config)"
  else
    emit_check host.grok.config ok "grok config not yet created (expected at $config after first grok run)"
  fi
}

_doctor_host_grok_pm_command() {
  # Batch-only MVP: pmctl pm is the command interface. No native /pm install.
  emit_capability host.grok.pm-command ok grok pm_command_interface \
    cli_wrapper none partial evolving assumed \
    "batch PM via pmctl pm prepare/run --host grok (no native slash command wired in MVP)"
}

_doctor_host_grok_unguarded() {
  # Honest none declarations for capabilities not yet probed or wired.
  emit_capability host.grok.command-guard ok grok command_guard \
    none none none evolving assumed \
    "Grok command guard not wired (MVP has no install_module; opt-in hooks deferred)"
  emit_capability host.grok.file-guard ok grok file_guard \
    none none none evolving assumed \
    "Grok file guard not evaluated (closure-of-all-paths not claimed)"
  emit_capability host.grok.statusline ok grok statusline \
    none none none evolving assumed \
    "Grok statusline not evaluated"
}

doctor_host_grok_run() {
  doctor_check_executor_auth grok grok \
    "grok not found — dispatch to the grok adapter (pmctl dispatch run --adapter grok) is unavailable" \
    "Install Grok Build CLI if you dispatch tasks to grok (optional)" \
    "grok present but not authenticated — dispatch would fail (no end event)" \
    "Run 'grok' once to log in, or export XAI_API_KEY / GROK_API_KEY"
  _doctor_host_grok_binary
  _doctor_host_grok_config
  _doctor_host_grok_pm_command
  _doctor_host_grok_unguarded
}
