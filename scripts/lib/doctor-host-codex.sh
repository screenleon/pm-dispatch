#!/usr/bin/env bash
# Sourceable codex-host doctor module.
#
# Host-specific doctor probes for the codex host (Codex CLI as the PM runtime).
# Sourced by scripts/doctor.sh's generic host-module loader
# (lib/doctor-host-*.sh glob); never executed standalone. The loader calls
# doctor_host_codex_run() — the single required entry point of the host-module
# interface. emit_check/emit_capability and codex_available come from doctor.sh.
#
# Read-only by contract: every probe here only tests for the existence of
# well-known files or PATH binaries. It must never run a codex CLI command that
# could mutate state, hang on a trust prompt, or incur cost.
#
# The codex host has no install write path yet, so an unwired capability is
# reported as ok with provider=none (an observed state, not an install defect)
# — unlike the claude host where unwired means the install contract is broken.
# Once a host manifest declares codex wiring targets, the declared values move
# out of this file into the manifest; the module interface stays the same.

# Capability probe for the codex hook surface. hooks.json under CODEX_HOME is
# the hook wiring target (same hooks-block shape as Claude settings.json, not
# a config.toml section). Coverage is partial by observation: command payloads
# map directly to guard checks, while file-write payloads embed the path in
# patch text and need a parser before a file guard can bind. Headless runs also
# require an explicit hook-trust bypass flag, so wiring alone is not effective
# enforcement — hence confidence stays at probed, stability at evolving.
_doctor_host_codex_hooks() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  if [[ -f "$codex_home/hooks.json" ]]; then
    if command -v jq >/dev/null 2>&1 && ! jq . "$codex_home/hooks.json" >/dev/null 2>&1; then
      emit_capability host.codex.hooks warn codex command_guard \
        host_hook none none evolving probed \
        "codex hooks.json exists but is not valid JSON ($codex_home/hooks.json)"
      return
    fi
    emit_capability host.codex.hooks ok codex command_guard \
      host_hook blocking partial evolving probed \
      "codex hook surface wired ($codex_home/hooks.json; command coverage full, file-write needs patch parsing)"
  else
    emit_capability host.codex.hooks ok codex command_guard \
      none none none evolving probed \
      "codex hook surface not wired (no $codex_home/hooks.json; install write path pending)"
  fi
}

# Host-module entry point (required by doctor.sh's generic loader).
doctor_host_codex_run() {
  if ! codex_available; then
    emit_capability host.codex.binary ok codex pm_command_interface \
      none none none evolving probed \
      "codex binary not on PATH — codex-host capability probes skipped"
    return
  fi
  emit_capability host.codex.binary ok codex pm_command_interface \
    host_native none full evolving probed \
    "codex binary on PATH"
  _doctor_host_codex_hooks
}
