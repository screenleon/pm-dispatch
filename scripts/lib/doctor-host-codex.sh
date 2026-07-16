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
# The codex host's install write path is opt-in (install.sh
# --enable-codex-command-guard), so an unwired capability is reported as ok
# with provider=none (the default, expected state, not an install defect) —
# unlike the claude host where unwired means the install contract is broken.
# Once a host manifest declares codex wiring targets, the declared values move
# out of this file into the manifest; the module interface stays the same.

# Capability probe for the codex hook surface. hooks.json under CODEX_HOME is
# the hook wiring target (same hooks-block shape as Claude settings.json, not
# a config.toml section). Coverage is partial by observation: command payloads
# map directly to guard checks, while file-write payloads embed the path in
# patch text and need a parser before a file guard can bind. Headless runs also
# require an explicit hook-trust bypass flag, so wiring alone is not effective
# enforcement — hence confidence stays at probed, stability at evolving.
#
# "Wired" here means THIS checkout's managed hook is actually present (see
# _doctor_host_codex_target_installed below), not merely that hooks.json
# exists and parses — a hooks.json holding only unrelated or same-basename
# foreign entries must report as unwired here too, matching
# _doctor_host_codex_manifest_parity's determination (the two probes must
# never disagree about the same underlying fact).
_doctor_host_codex_hooks() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  if [[ -f "$codex_home/hooks.json" ]]; then
    if command -v jq >/dev/null 2>&1 && ! jq . "$codex_home/hooks.json" >/dev/null 2>&1; then
      emit_capability host.codex.hooks warn codex command_guard \
        host_hook none none evolving probed \
        "codex hooks.json exists but is not valid JSON ($codex_home/hooks.json)"
      return
    fi
    if _doctor_host_codex_hook_present "$codex_home/hooks.json" command_guard; then
      emit_capability host.codex.hooks ok codex command_guard \
        host_hook blocking partial evolving probed \
        "codex hook surface wired ($codex_home/hooks.json; command coverage full, file-write needs patch parsing)"
    else
      emit_capability host.codex.hooks ok codex command_guard \
        none none none evolving probed \
        "codex hook surface not wired ($codex_home/hooks.json exists but does not contain this checkout's managed hook; opt-in via install.sh --enable-codex-command-guard)"
    fi
    if _doctor_host_codex_hook_present "$codex_home/hooks.json" memory_injection; then
      emit_check host.codex.memory-injection ok "canonical UserPromptSubmit memory injection wired"
    else
      emit_check host.codex.memory-injection ok "canonical UserPromptSubmit memory injection not wired (opt-in host wiring)"
    fi
    if _doctor_host_codex_hook_present "$codex_home/hooks.json" session_lifecycle; then
      emit_capability host.codex.session-lifecycle ok codex session_lifecycle \
        host_hook none partial evolving probed \
        "canonical Stop session writer wired with host=codex"
    else
      emit_capability host.codex.session-lifecycle ok codex session_lifecycle \
        none none none evolving probed \
        "canonical Stop session writer not wired (opt-in host wiring)"
    fi
  else
    emit_capability host.codex.hooks ok codex command_guard \
      none none none evolving probed \
      "codex hook surface not wired (no $codex_home/hooks.json; opt-in via install.sh --enable-codex-command-guard)"
    emit_check host.codex.memory-injection ok "canonical UserPromptSubmit memory injection not wired (no hooks.json)"
    emit_capability host.codex.session-lifecycle ok codex session_lifecycle \
      none none none evolving probed \
      "canonical Stop session writer not wired (no hooks.json)"
  fi
}

_doctor_host_codex_hook_present() {
  local hooks_file="$1" kind="$2" command command_q event matcher=""
  case "$kind" in
    command_guard)
      command="$REPO_ROOT/scripts/hook-codex-command-guard.sh"; event="PreToolUse"; matcher="Bash" ;;
    memory_injection)
      command="$REPO_ROOT/scripts/guard-inject-memory.sh"; event="UserPromptSubmit" ;;
    session_lifecycle)
      command="$REPO_ROOT/scripts/guard-session-summary.sh --host codex"
      command_q="$(printf '%q' "$REPO_ROOT/scripts/guard-session-summary.sh") --host codex"
      event="Stop"
      ;;
    *) return 1 ;;
  esac
  [[ -n "${command_q:-}" ]] || command_q="$(printf '%q' "$command")"
  jq -e --arg event "$event" --arg matcher "$matcher" --arg cmd "$command" --arg cmd_q "$command_q" '
    (.hooks[$event] // [])[]?
    | select(($matcher == "") or (.matcher == $matcher))
    | (.hooks // [])[]?.command
    | select(. == $cmd or . == $cmd_q)
  ' "$hooks_file" >/dev/null 2>&1
}

# Per-target installed check: for the codex-hooks-json format this verifies
# the managed hook COMMAND is actually wired inside the hooks file, not merely
# that the file exists — a hooks.json holding only unrelated entries (e.g. a
# user's own Codex hooks, or a same-basename hook-codex-command-guard.sh
# belonging to a DIFFERENT checkout) must not read as this target being
# installed. Matches the exact command identity this checkout's own installer
# writes (install-guards-codex.sh:59, raw and shell-escaped forms — same
# identity rule uninstall-guards-codex.sh uses), not a basename heuristic.
# Other formats have no content probe yet, so path existence is the best
# available signal for them.
_doctor_host_codex_target_installed() {
  local expanded="$1" fmt="$2"
  if [[ "$fmt" == "codex-hooks-json" ]]; then
    [[ -f "$expanded" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    _doctor_host_codex_hook_present "$expanded" command_guard \
      && _doctor_host_codex_hook_present "$expanded" memory_injection \
      && _doctor_host_codex_hook_present "$expanded" session_lifecycle
    return $?
  fi
  if [[ "$fmt" == "codex-agents-md" ]]; then
    [[ -f "$expanded" ]] || return 1
    grep -Fqx '<!-- pm-dispatch:codex-memory-contract:start -->' "$expanded" \
      && grep -Fqx '<!-- pm-dispatch:codex-memory-contract:end -->' "$expanded"
    return $?
  fi
  [[ -e "$expanded" ]]
}

# Declared-vs-installed parity check: hosts/codex/host.yaml's
# install_targets is the DECLARED layer (docs/host-contract.md); this reports
# which managed targets are actually installed (see
# _doctor_host_codex_target_installed above). Distinct from claude's
# declared-vs-PROBED consistency check (doctor-host-claude.sh) — codex has no
# equivalent live-capability probe yet. codex-host wiring is opt-in (install.sh
# --enable-codex-command-guard), so a missing managed target is the DEFAULT,
# expected state, not a defect — this stays `ok` the same way
# _doctor_host_codex_hooks() above treats an absent hooks.json as ok, never
# warn/fail. Only a broken checkout (manifest or host-manifest.sh missing)
# warrants a warn.
_doctor_host_codex_manifest_parity() {
  if [[ "${_HOST_MANIFEST_AVAILABLE:-0}" -ne 1 ]]; then
    emit_check host.codex.manifest-parity warn \
      "scripts/lib/host-manifest.sh unavailable — cannot check declared-vs-installed parity"
    return
  fi
  local manifest="$REPO_ROOT/hosts/codex/host.yaml"
  if [[ ! -f "$manifest" ]]; then
    emit_check host.codex.manifest-parity warn \
      "hosts/codex/host.yaml missing — cannot check declared-vs-installed parity"
    return
  fi

  local -a present=() missing=()
  local id path fmt managed expanded
  while IFS=$'\t' read -r id path fmt managed; do
    [[ "$managed" == "true" ]] || continue
    expanded="$(host_manifest_expand_path "$REPO_ROOT" codex "$path")"
    if _doctor_host_codex_target_installed "$expanded" "$fmt"; then
      present+=("$id")
    else
      missing+=("$id")
    fi
  done < <(host_manifest_install_targets "$manifest")

  if [[ "${#missing[@]}" -eq 0 ]]; then
    emit_check host.codex.manifest-parity ok \
      "all managed hosts/codex/host.yaml install_targets wired (${present[*]:-none declared managed})"
  else
    emit_check host.codex.manifest-parity ok \
      "managed install_target(s) not wired: ${missing[*]} (expected default — codex-host wiring is opt-in via install.sh --enable-codex-command-guard)"
  fi
}

# Host-module entry point (required by doctor.sh's generic loader).
doctor_host_codex_run() {
  if ! codex_available; then
    emit_capability host.codex.binary ok codex pm_command_interface \
      none none none evolving probed \
      "codex binary not on PATH — batch PM command interface unavailable"
    return
  fi
  emit_capability host.codex.binary ok codex pm_command_interface \
    cli_wrapper none partial evolving probed \
    "codex binary on PATH; pmctl pm provides batch-only orchestration (no interactive clarification loop)"
  _doctor_host_codex_hooks
  _doctor_host_codex_manifest_parity
}
