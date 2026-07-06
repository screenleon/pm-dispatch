#!/usr/bin/env bash
# Sourceable claude-host doctor module.
#
# Host-specific doctor checks for the claude host (Claude Code as the PM
# runtime). Sourced by scripts/doctor.sh's generic host-module loader
# (lib/doctor-host-*.sh glob); never executed standalone. The loader calls
# doctor_host_claude_run() — the single required entry point of the host-module
# interface. Everything this module needs (emit_check, emit_capability,
# _json_esc, REPO_ROOT, PROFILE, JSON/QUIET/COLOR, codex_available,
# detect_platform, runner-kind helpers, _SETTINGS_FILE_* flags) is provided by
# doctor.sh before main() runs.
#
# Adding a new host must NOT require editing this file or doctor.sh core —
# drop a new lib/doctor-host-<name>.sh defining doctor_host_<name>_run().
#
# Copy-mode caveat: when doctor.sh is installed as a lone copied file (no lib/,
# e.g. native Windows), this module is absent and doctor.sh runs a compact
# degraded fallback for the same check slugs. Keep the check slugs and their
# pass/fail semantics in sync with that fallback (see
# check_host_fallback_copy_mode in doctor.sh).
#
# shellcheck disable=SC2153  # REPO_ROOT/PROFILE are doctor.sh globals, assigned before main() dispatches here

_doctor_host_claude_check_settings_file() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  _SETTINGS_FILE_FAILED=0
  _SETTINGS_FILE_INVALID=0
  if [[ ! -f "$settings" ]]; then
    _SETTINGS_FILE_FAILED=1
    emit_check settings-file fail "settings.json missing" "bash '${REPO_ROOT}/install.sh'"
    return
  fi

  if command -v jq >/dev/null 2>&1 && ! jq . "$settings" >/dev/null 2>&1; then
    _SETTINGS_FILE_INVALID=1
    emit_check settings-file fail "settings.json exists but is not valid JSON" \
      "printf '{}\\n' > ~/.claude/settings.json  then re-run install-guards.sh"
    return
  fi

  emit_check settings-file ok "settings.json present"
}

_doctor_host_claude_hook_present() {
  local basename="$1" settings="$2"
  jq -e --arg basename "$basename" '
    # install-guards.sh shell-escapes managed command paths (printf %q), so a repo
    # under a path with a space stores a backslash-escaped command. Strip those
    # shell-escape backslashes (a backslash before any non-alphanumeric char)
    # BEFORE the Windows backslash->slash conversion, which only applies to native
    # path separators (a backslash before a component name, i.e. alphanumeric).
    def normalize_path:
      gsub("\\\\(?<c>[^A-Za-z0-9])"; .c)
      | if test("^[A-Za-z]:[/\\\\]") then
          "/" + (.[0:1] | ascii_downcase) + "/" + (.[3:] | gsub("\\\\"; "/"))
        else gsub("\\\\"; "/") end;
    def managed_hook:
      (.command? // "") as $cmd |
      ($cmd | normalize_path) as $ncmd |
      (($ncmd | split("/") | last) == $basename and ($ncmd | split("/") | .[-2]) == "scripts");
    ([
      ((.hooks // {}).PreToolUse[]? | (.hooks // [])[]? | select(managed_hook)),
      ((.hooks // {}).PostToolUse[]? | (.hooks // [])[]? | select(managed_hook)),
      ((.hooks // {}).Stop[]? | (.hooks // [])[]? | select(managed_hook)),
      ((.hooks // {}).UserPromptSubmit[]? | (.hooks // [])[]? | select(managed_hook))
    ] | length > 0)
    or
    (
      $basename == "guard-save-rate-limits.sh" and
      ((.statusLine.command? // "") as $cmd |
        ($cmd | normalize_path) as $ncmd |
        (($ncmd | split("/") | last) == $basename and ($ncmd | split("/") | .[-2]) == "scripts"))
    )
  ' "$settings" >/dev/null 2>&1
}

_doctor_host_claude_adapter_bg_present() {
  local adapter_name="$1" settings="$2"
  jq -e --arg adapter_name "$adapter_name" '
    def normalize_path:
      gsub("\\\\(?<c>[^A-Za-z0-9])"; .c)
      | if test("^[A-Za-z]:[/\\\\]") then
          "/" + (.[0:1] | ascii_downcase) + "/" + (.[3:] | gsub("\\\\"; "/"))
        else gsub("\\\\"; "/") end;
    def managed_bg_hook:
      (.command? // "") as $cmd |
      ($cmd | normalize_path) as $ncmd |
      (($ncmd | split("/") | last) == "bash-guard.sh"
       and ($ncmd | split("/") | .[-2]) == $adapter_name
       and ($ncmd | split("/") | .[-3]) == "adapters");
    ([
      ((.hooks // {}).PreToolUse[]? | (.hooks // [])[]? | select(managed_bg_hook))
    ] | length > 0)
  ' "$settings" >/dev/null 2>&1
}

_doctor_host_claude_stale_hook_commands() {
  local settings="$1" repo_root="$2"
  jq -r --arg repo_root "$repo_root" '
    # Normalize Windows drive paths (C:/...) to POSIX form (/c/...) so that
    # comparisons work regardless of which format the shell or installer used.
    # First strip printf %q shell-escape backslashes (a backslash before any
    # non-alphanumeric char) so an escaped command path written for a spaced repo
    # root compares equal to the raw repo root.
    def normalize_path:
      gsub("\\\\(?<c>[^A-Za-z0-9])"; .c)
      | if test("^[A-Za-z]:[/\\\\]") then
          "/" + (.[0:1] | ascii_downcase) + "/" + (.[3:] | gsub("\\\\"; "/"))
        else . end;
    [
      ((.hooks // {}) | .PreToolUse[]?  | (.hooks // [])[]?),
      ((.hooks // {}) | .PostToolUse[]? | (.hooks // [])[]?),
      ((.hooks // {}) | .Stop[]?        | (.hooks // [])[]?),
      ((.hooks // {}) | .UserPromptSubmit[]? | (.hooks // [])[]?),
      (if .statusLine then {command: (.statusLine.command // "")} else empty end)
    ]
    | map(select(
        (.command? // "") as $cmd |
        ($cmd | normalize_path) as $ncmd |
        ($ncmd | length) > 0 and
        (
          (
            ($ncmd | split("/") | .[-2]) == "scripts" and
            (($ncmd | split("/") | last) | IN(
              "guard-pm-write.sh",
              "guard-log-claude-usage.sh",
              "guard-session-summary.sh",
              "guard-inject-memory.sh",
              "guard-save-rate-limits.sh"
            ))
          ) or
          (
            ($ncmd | split("/") | last) == "bash-guard.sh" and
            ($ncmd | split("/") | .[-3]) == "adapters"
          )
        ) and
        ($ncmd | startswith(($repo_root | normalize_path) + "/") | not)
      ) | .command)
    | unique[]
  ' "$settings" 2>/dev/null
}

_doctor_host_claude_check_hooks() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  if [[ "$_SETTINGS_FILE_FAILED" -eq 1 ]]; then
    emit_check hooks fail "settings.json missing — cannot check hooks" "bash '${REPO_ROOT}/install.sh'"
    return
  fi
  if [[ "$_SETTINGS_FILE_INVALID" -eq 1 ]]; then
    emit_check hooks fail "settings.json is not valid JSON — cannot check hooks"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    emit_check hooks warn "jq not available — cannot verify hooks"
    return
  fi

  local profile
  local -a hooks=(
    guard-pm-write.sh
    guard-log-claude-usage.sh
    guard-session-summary.sh
    guard-inject-memory.sh
    guard-save-rate-limits.sh
  )
  local _want_full=0
  case "$PROFILE" in
    full)    _want_full=1 ;;
    minimal) _want_full=0 ;;
    *)       if [[ "$(detect_platform)" == "windows" ]]; then
               _want_full=0
             elif codex_available; then
               _want_full=1
             else
               _want_full=0
             fi ;;
  esac

  # Collect adapter bash guards from manifests (full profile only).
  local -a _adapter_bg_names=()
  if [[ "$_want_full" -eq 1 && "$_RUNNER_KIND_AVAILABLE" -eq 1 ]]; then
    local _manifest _adapter_name _rk _nbg_override _nbg
    for _manifest in "$REPO_ROOT"/adapters/*/adapter.yaml; do
      [[ -f "$_manifest" ]] || continue
      _adapter_name="$(basename "$(dirname "$_manifest")")"
      _rk="$(runner_kind_manifest_field "$_manifest" runner_kind)"
      [[ -n "$_rk" ]] || continue
      _nbg_override="$(runner_kind_manifest_field "$_manifest" needs_bash_guard)"
      _nbg="$(runner_kind_resolve_flag "$_rk" needs_bash_guard "$_nbg_override")"
      [[ "$_nbg" == "true" ]] && _adapter_bg_names+=("$_adapter_name")
    done
  fi

  if [[ "$_want_full" -eq 1 ]]; then
    profile="full"
  else
    profile="minimal"
  fi

  local -a missing=()
  local hook
  for hook in "${hooks[@]}"; do
    if ! _doctor_host_claude_hook_present "$hook" "$settings"; then
      missing+=("$hook")
    fi
  done
  if [[ "$_want_full" -eq 1 ]]; then
    local _aname
    for _aname in "${_adapter_bg_names[@]+"${_adapter_bg_names[@]}"}"; do
      if ! _doctor_host_claude_adapter_bg_present "$_aname" "$settings"; then
        missing+=("adapters/$_aname/bash-guard.sh")
      fi
    done
  fi

  # Compute stale list before emitting any status so we emit a single line.
  local -a _stale=()
  if command -v jq >/dev/null 2>&1; then
    local _sc
    while IFS= read -r _sc; do
      [[ -n "$_sc" ]] && _stale+=("$_sc")
    done < <(_doctor_host_claude_stale_hook_commands "$settings" "$REPO_ROOT")
  fi

  local _total_hooks=${#hooks[@]}
  if [[ "$_want_full" -eq 1 ]]; then
    _total_hooks=$(( _total_hooks + ${#_adapter_bg_names[@]} ))
  fi
  if [[ "${#missing[@]}" -gt 0 ]]; then
    emit_check hooks fail "missing hooks: ${missing[*]}" "bash '${REPO_ROOT}/scripts/install-guards.sh'"
  elif [[ "${#_stale[@]}" -gt 0 ]]; then
    emit_check hooks warn \
      "${#_stale[@]} hook(s) wired from a different checkout (e.g. $(basename "${_stale[0]}"))" \
      "bash '${REPO_ROOT}/install.sh' to re-wire hooks to this checkout"
  else
    emit_check hooks ok "$_total_hooks hooks present ($profile profile)"
  fi
}

_doctor_host_claude_check_dispatch_allowlist() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  if [[ "$_SETTINGS_FILE_FAILED" -eq 1 || "$_SETTINGS_FILE_INVALID" -eq 1 ]]; then
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    emit_check dispatch-allowlist warn "jq not available — cannot verify dispatch-allowlist"
    return
  fi

  # Consume the shared dispatch_allowlist_entries() helper (sourced by doctor.sh
  # from scripts/lib/allowlist.sh).  Entries arrive in abs+tilde pairs; at least
  # one form per script must be present in settings.json.  Falls back to inline
  # scan when allowlist.sh is absent (this module present without it is unusual
  # but possible in a partial checkout).
  local all_ok=1 any=0
  if declare -f dispatch_allowlist_entries >/dev/null 2>&1; then
    local _abs _tilde
    while IFS= read -r _abs && IFS= read -r _tilde; do
      any=1
      jq -e --arg a "$_abs" --arg t "$_tilde" \
        '(.permissions.allow // []) | (index($a) != null or index($t) != null)' \
        "$settings" >/dev/null 2>&1 || all_ok=0
    done < <(dispatch_allowlist_entries)
  else
    local f rel
    for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
      [[ -f "$f" ]] || continue
      any=1; rel="${f#"$HOME/"}"
      jq -e --arg a "Bash($f:*)" --arg t "Bash(~/$rel:*)" \
        '(.permissions.allow // []) | (index($a) != null or index($t) != null)' \
        "$settings" >/dev/null 2>&1 || all_ok=0
    done
  fi

  if [[ $any -eq 0 || $all_ok -eq 0 ]]; then
    emit_check dispatch-allowlist fail "dispatch allowlist incomplete or missing" \
      "bash '${REPO_ROOT}/install.sh'"
  else
    emit_check dispatch-allowlist ok "dispatch allowlist present (all adapters)"
  fi
}

_doctor_host_claude_check_manifest() {
  local manifest_path="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.pm-dispatch/install-manifest.json"
  if [[ ! -f "$manifest_path" ]]; then
    emit_check manifest warn "install manifest missing — uninstall.sh cannot track files" \
      "bash '${REPO_ROOT}/install.sh' to regenerate"
    return
  fi

  if command -v jq >/dev/null 2>&1 && ! jq -e '.manifest_version == 1' "$manifest_path" >/dev/null 2>&1; then
    emit_check manifest warn "install manifest has unexpected version" \
      "bash '${REPO_ROOT}/install.sh' to regenerate"
    return
  fi

  emit_check manifest ok "install manifest present"
}

# Capability view of the claude host: one record per desired capability,
# derived from the same wiring signals the checks above verify. Wiring is the
# install contract for the claude host, so an unwired capability is warn (with
# the install fix), unlike hosts whose install write path does not exist yet.
_doctor_host_claude_capabilities() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  if [[ "$_SETTINGS_FILE_FAILED" -eq 1 || "$_SETTINGS_FILE_INVALID" -eq 1 ]] \
    || ! command -v jq >/dev/null 2>&1; then
    emit_check host.claude.capabilities warn \
      "claude host capability probes skipped (settings.json unreadable or jq missing)"
    return
  fi

  if _doctor_host_claude_hook_present guard-pm-write.sh "$settings"; then
    emit_capability host.claude.command-guard ok claude command_guard \
      host_hook blocking full stable probed \
      "write guard wired (PreToolUse hook)"
  else
    emit_capability host.claude.command-guard warn claude command_guard \
      none none none stable probed \
      "write guard not wired" "bash '${REPO_ROOT}/scripts/install-guards.sh'"
  fi

  if _doctor_host_claude_hook_present guard-session-summary.sh "$settings"; then
    emit_capability host.claude.session-lifecycle ok claude session_lifecycle \
      host_hook advisory full stable probed \
      "session summary wired (Stop hook)"
  else
    emit_capability host.claude.session-lifecycle warn claude session_lifecycle \
      none none none stable probed \
      "session summary not wired" "bash '${REPO_ROOT}/scripts/install-guards.sh'"
  fi

  if _doctor_host_claude_hook_present guard-save-rate-limits.sh "$settings"; then
    emit_capability host.claude.statusline ok claude statusline \
      host_hook advisory full stable probed \
      "statusline wired"
  else
    emit_capability host.claude.statusline warn claude statusline \
      none none none stable probed \
      "statusline not wired" "bash '${REPO_ROOT}/scripts/install-guards.sh'"
  fi

  if [[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/pm.md" ]]; then
    emit_capability host.claude.command-interface ok claude pm_command_interface \
      host_native none full stable probed \
      "PM command interface installed (commands/pm.md)"
  else
    emit_capability host.claude.command-interface warn claude pm_command_interface \
      none none none stable probed \
      "PM command interface not installed" "bash '${REPO_ROOT}/install.sh'"
  fi
}

# Host-module entry point (required by doctor.sh's generic loader).
doctor_host_claude_run() {
  _doctor_host_claude_check_settings_file
  _doctor_host_claude_check_hooks
  _doctor_host_claude_check_dispatch_allowlist
  _doctor_host_claude_check_manifest
  _doctor_host_claude_capabilities
}
