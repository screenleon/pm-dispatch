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

_CLAUDE_HOST_CONFIG_ROOT=""
_CLAUDE_HOST_CONFIG_ROOT_ERROR=""

_doctor_host_claude_resolve_config_root() {
  local out rc=0
  out="$(host_manifest_expand_path "$REPO_ROOT" claude '$CLAUDE_CONFIG_DIR' 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    _CLAUDE_HOST_CONFIG_ROOT_ERROR="$out"
    return "$rc"
  fi
  _CLAUDE_HOST_CONFIG_ROOT="$out"
}

_doctor_host_claude_check_config_root() {
  if [[ -n "$_CLAUDE_HOST_CONFIG_ROOT_ERROR" ]]; then
    local remediation="unset CLAUDE_HOME or set both variables to the same Claude config root"
    if [[ "$_CLAUDE_HOST_CONFIG_ROOT_ERROR" == *"HOME is required"* ]]; then
      remediation="set HOME or set CLAUDE_CONFIG_DIR to the Claude config root"
    fi
    emit_check host.claude.config-root fail \
      "$_CLAUDE_HOST_CONFIG_ROOT_ERROR" \
      "$remediation"
  else
    emit_check host.claude.config-root ok \
      "Claude config root: $_CLAUDE_HOST_CONFIG_ROOT"
  fi
}

_doctor_host_claude_check_settings_file() {
  local settings="$_CLAUDE_HOST_CONFIG_ROOT/settings.json"
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
      ($ncmd | sub(" --host (claude|codex|opencode|generic)$"; "")) as $path |
      (($path | split("/") | last) == $basename and ($path | split("/") | .[-2]) == "scripts") and
      (if $basename == "guard-session-summary.sh" then ($ncmd | endswith("guard-session-summary.sh --host claude")) else true end);
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

_doctor_host_claude_context_timeout_ok() {
  local settings="$1"
  # shellcheck disable=SC1091
  # shellcheck source=scripts/lib/prompt-context-timeouts.sh
  . "$REPO_ROOT/scripts/lib/prompt-context-timeouts.sh"
  jq -e --argjson expected "$CLAUDE_PROMPT_CONTEXT_HOOK_TIMEOUT" '
    [
      (.hooks.UserPromptSubmit[]? | (.hooks // [])[]? |
        select(((.command? // "") | gsub("\\\\"; "/") | split("/") | last) == "guard-inject-context.sh"))
    ] as $hooks |
    ($hooks | length) > 0 and
    all($hooks[]; ((.timeout? // 0) | type) == "number" and (.timeout >= $expected))
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
              "guard-inject-context.sh",
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
  local settings="$_CLAUDE_HOST_CONFIG_ROOT/settings.json"
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
    guard-inject-context.sh
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
  elif ! _doctor_host_claude_context_timeout_ok "$settings"; then
    # shellcheck disable=SC1091
    # shellcheck source=scripts/lib/prompt-context-timeouts.sh
    . "$REPO_ROOT/scripts/lib/prompt-context-timeouts.sh"
    emit_check hooks fail \
      "guard-inject-context.sh timeout missing or below ${CLAUDE_PROMPT_CONTEXT_HOOK_TIMEOUT}s" \
      "bash '${REPO_ROOT}/scripts/install-guards.sh'"
  else
    emit_check hooks ok "$_total_hooks hooks present ($profile profile)"
  fi
}

_doctor_host_claude_check_dispatch_allowlist() {
  local settings="$_CLAUDE_HOST_CONFIG_ROOT/settings.json"
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
  local manifest_path="$_CLAUDE_HOST_CONFIG_ROOT/.pm-dispatch/install-manifest.json"
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

# Single source of truth for the claude host's probed capability tuple — used
# by both the human-facing capability view below and the declared-vs-probed
# consistency check, so the two can never state a different probed value for
# the same capability (docs/host-contract.md "declared and probed layers stay
# mechanically comparable"). Sets _PROBE_* globals; callers read them
# immediately (no subshell — bash 3.2 on macOS has no associative arrays to
# return a tuple through otherwise).
#
# guard-pm-write.sh matches Edit|Write, not Bash — it is a file-write role
# guard, not a command guard, so it probes file_guard. There is no
# corresponding host-level Bash-tool hook for claude's own session at all
# (the "Bash" matcher only ever wires adapters/<name>/bash-guard.sh, gated
# per-adapter by needs_bash_guard for the DISPATCHED-EXECUTOR axis — a
# different capability than guarding the host's own commands), so
# command_guard has no wiring signal to probe and is always none. Both
# file_guard and command_guard stay `none` even when guard-pm-write.sh is
# wired: hosts/claude/host.yaml's closure-of-all-paths analysis (guard-pm-write
# is scoped to one subagent and never closes the Bash-tool bypass) means
# wiring status can never lift either capability's coverage above none — the
# probe only varies the human message, not the tuple, for these two.
_doctor_host_claude_probe() {
  local capability="$1" settings="$2"
  _PROBE_FIX=""
  case "$capability" in
    command_guard)
      _PROBE_WIRED=0; _PROBE_PROVIDER=none; _PROBE_ENFORCEMENT=none; _PROBE_COVERAGE=none
      _PROBE_STABILITY=evolving; _PROBE_CONFIDENCE=probed; _PROBE_STATUS=ok
      _PROBE_MESSAGE="no host-level Bash command guard for claude's own session (adapter bash-guard hooks are the dispatched-executor axis, gated per-adapter by needs_bash_guard; none active today)"
      ;;
    file_guard)
      _PROBE_WIRED=0; _PROBE_PROVIDER=none; _PROBE_ENFORCEMENT=none; _PROBE_COVERAGE=none
      _PROBE_STABILITY=evolving; _PROBE_CONFIDENCE=probed; _PROBE_STATUS=ok
      if _doctor_host_claude_hook_present guard-pm-write.sh "$settings"; then
        _PROBE_MESSAGE="write guard wired (PreToolUse hook, PM subagent Edit|Write only) — does not close the Bash-tool bypass, so file_guard stays unsupported"
      else
        _PROBE_MESSAGE="write guard not wired"
      fi
      ;;
    session_lifecycle)
      if _doctor_host_claude_hook_present guard-session-summary.sh "$settings"; then
        _PROBE_WIRED=1; _PROBE_PROVIDER=host_hook; _PROBE_ENFORCEMENT=advisory; _PROBE_COVERAGE=full
        _PROBE_STABILITY=stable; _PROBE_CONFIDENCE=probed; _PROBE_STATUS=ok
        _PROBE_MESSAGE="session summary wired (Stop hook)"
      else
        _PROBE_WIRED=0; _PROBE_PROVIDER=none; _PROBE_ENFORCEMENT=none; _PROBE_COVERAGE=none
        _PROBE_STABILITY=stable; _PROBE_CONFIDENCE=probed; _PROBE_STATUS=warn
        _PROBE_MESSAGE="session summary not wired"
        _PROBE_FIX="bash '${REPO_ROOT}/scripts/install-guards.sh'"
      fi
      ;;
    statusline)
      if _doctor_host_claude_hook_present guard-save-rate-limits.sh "$settings"; then
        _PROBE_WIRED=1; _PROBE_PROVIDER=host_hook; _PROBE_ENFORCEMENT=advisory; _PROBE_COVERAGE=full
        _PROBE_STABILITY=stable; _PROBE_CONFIDENCE=probed; _PROBE_STATUS=ok
        _PROBE_MESSAGE="statusline wired"
      else
        _PROBE_WIRED=0; _PROBE_PROVIDER=none; _PROBE_ENFORCEMENT=none; _PROBE_COVERAGE=none
        _PROBE_STABILITY=stable; _PROBE_CONFIDENCE=probed; _PROBE_STATUS=warn
        _PROBE_MESSAGE="statusline not wired"
        _PROBE_FIX="bash '${REPO_ROOT}/scripts/install-guards.sh'"
      fi
      ;;
    pm_command_interface)
      if [[ -f "$_CLAUDE_HOST_CONFIG_ROOT/commands/pm.md" ]]; then
        _PROBE_WIRED=1; _PROBE_PROVIDER=host_native; _PROBE_ENFORCEMENT=none; _PROBE_COVERAGE=full
        _PROBE_STABILITY=stable; _PROBE_CONFIDENCE=probed; _PROBE_STATUS=ok
        _PROBE_MESSAGE="PM command interface installed (commands/pm.md)"
      else
        _PROBE_WIRED=0; _PROBE_PROVIDER=none; _PROBE_ENFORCEMENT=none; _PROBE_COVERAGE=none
        _PROBE_STABILITY=stable; _PROBE_CONFIDENCE=probed; _PROBE_STATUS=warn
        _PROBE_MESSAGE="PM command interface not installed"
        _PROBE_FIX="bash '${REPO_ROOT}/install.sh'"
      fi
      ;;
  esac
}

# Capability view of the claude host: one record per guard_bindings
# capability in hosts/claude/host.yaml, derived from _doctor_host_claude_probe
# — the single wiring-signal source of truth shared with the consistency
# check below.
_doctor_host_claude_capabilities() {
  local settings="$_CLAUDE_HOST_CONFIG_ROOT/settings.json"
  if [[ "$_SETTINGS_FILE_FAILED" -eq 1 || "$_SETTINGS_FILE_INVALID" -eq 1 ]] \
    || ! command -v jq >/dev/null 2>&1; then
    emit_check host.claude.capabilities warn \
      "claude host capability probes skipped (settings.json unreadable or jq missing)"
    return
  fi

  local cap slug
  for cap in command_guard file_guard session_lifecycle pm_command_interface statusline; do
    case "$cap" in
      command_guard)        slug=host.claude.command-guard ;;
      file_guard)            slug=host.claude.file-guard ;;
      session_lifecycle)     slug=host.claude.session-lifecycle ;;
      pm_command_interface)  slug=host.claude.command-interface ;;
      statusline)            slug=host.claude.statusline ;;
    esac
    _doctor_host_claude_probe "$cap" "$settings"
    emit_capability "$slug" "$_PROBE_STATUS" claude "$cap" \
      "$_PROBE_PROVIDER" "$_PROBE_ENFORCEMENT" "$_PROBE_COVERAGE" "$_PROBE_STABILITY" "$_PROBE_CONFIDENCE" \
      "$_PROBE_MESSAGE" "$_PROBE_FIX"
  done
}

# Extracts a single field's value from one capability entry of
# hosts/claude/host.yaml's guard_bindings list. Deliberately grep/awk-based
# (no YAML parser dependency), mirroring the block-extraction approach
# scripts/test-host-manifest.sh already uses for the same file.
_doctor_host_claude_manifest_field() {
  local capability="$1" field="$2"
  local manifest="$REPO_ROOT/hosts/claude/host.yaml"
  [[ -f "$manifest" ]] || return 1
  awk -v cap="$capability" -v field="$field" '
    /^[[:space:]]*-[[:space:]]*capability:/ {
      in_block = ($NF == cap)
      next
    }
    in_block && $0 ~ ("^[[:space:]]+" field ":") {
      sub("^[[:space:]]+" field ":[[:space:]]*", "")
      sub("[[:space:]]*#.*$", "")
      print
      exit
    }
  ' "$manifest"
}

# Declared-vs-probed consistency check (docs/host-contract.md "Declared /
# probed / effective layering"): hosts/claude/host.yaml's guard_bindings is
# the DECLARED layer; _doctor_host_claude_probe (shared with the capability
# view above, so there is exactly one source of truth for the probed tuple)
# is the PROBED layer. Every capability is compared, across every tuple field
# doctor tracks (provider/enforcement/coverage/stability/confidence) — but
# only for a capability the probe reports as WIRED (_PROBE_WIRED=1).
# "Not installed yet" is a normal, already-surfaced state (the capability
# warn already emitted above), not a manifest defect, so an unwired
# capability is skipped here rather than flagged. What this does catch:
# hosts/claude/host.yaml edited to declare a different tuple than what a
# live, wired environment actually probes to — drift between the static file
# and reality must be observable, not silent.
_doctor_host_claude_check_manifest_consistency() {
  local settings="$_CLAUDE_HOST_CONFIG_ROOT/settings.json"
  if [[ ! -f "$REPO_ROOT/hosts/claude/host.yaml" ]]; then
    emit_check host.claude.manifest-consistency warn \
      "hosts/claude/host.yaml missing — cannot check declared/probed consistency"
    return
  fi
  if [[ "$_SETTINGS_FILE_FAILED" -eq 1 || "$_SETTINGS_FILE_INVALID" -eq 1 ]] \
    || ! command -v jq >/dev/null 2>&1; then
    emit_check host.claude.manifest-consistency warn \
      "manifest-consistency check skipped (settings.json unreadable or jq missing)"
    return
  fi

  local -a drift=()
  local cap field declared probed

  for cap in command_guard file_guard session_lifecycle pm_command_interface statusline; do
    _doctor_host_claude_probe "$cap" "$settings"
    [[ "$_PROBE_WIRED" -eq 1 ]] || continue
    for field in provider enforcement coverage stability confidence; do
      case "$field" in
        provider)    probed="$_PROBE_PROVIDER" ;;
        enforcement) probed="$_PROBE_ENFORCEMENT" ;;
        coverage)    probed="$_PROBE_COVERAGE" ;;
        stability)   probed="$_PROBE_STABILITY" ;;
        confidence)  probed="$_PROBE_CONFIDENCE" ;;
      esac
      declared="$(_doctor_host_claude_manifest_field "$cap" "$field")"
      [[ "$declared" == "$probed" ]] || \
        drift+=("$cap: wired but manifest declares $field '$declared' (probed: $probed)")
    done
  done

  if [[ "${#drift[@]}" -gt 0 ]]; then
    emit_check host.claude.manifest-consistency fail \
      "declared vs probed mismatch: ${drift[*]}" \
      "revise hosts/claude/host.yaml to match the wired capability (or fix the wiring if the manifest is right)"
  else
    emit_check host.claude.manifest-consistency ok \
      "hosts/claude/host.yaml guard_bindings match probed capability state (for capabilities currently wired)"
  fi
}

# Host-module entry point (required by doctor.sh's generic loader).
doctor_host_claude_run() {
  _doctor_host_claude_resolve_config_root || true
  _doctor_host_claude_check_config_root
  [[ -z "$_CLAUDE_HOST_CONFIG_ROOT_ERROR" ]] || return 0
  _doctor_host_claude_check_settings_file
  _doctor_host_claude_check_hooks
  _doctor_host_claude_check_dispatch_allowlist
  _doctor_host_claude_check_manifest
  _doctor_host_claude_capabilities
  _doctor_host_claude_check_manifest_consistency
}
