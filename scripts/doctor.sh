#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# Resolve symlink to find actual repo scripts/ directory.
if [[ -L "${BASH_SOURCE[0]}" ]]; then
  _real="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || readlink "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
  SCRIPT_DIR="$(cd "$(dirname "$_real")" 2>/dev/null && pwd || printf '%s' "$SCRIPT_DIR")"
  unset _real
fi

# Source libs with graceful fallback for copy-mode (Windows) where lib/ is absent.
if [[ -f "$SCRIPT_DIR/lib/portable.sh" ]]; then
  # shellcheck source=scripts/lib/portable.sh
  . "$SCRIPT_DIR/lib/portable.sh"
  # shellcheck source=scripts/lib/allowlist.sh
  [[ -f "$SCRIPT_DIR/lib/allowlist.sh" ]] && . "$SCRIPT_DIR/lib/allowlist.sh"
  _PORTABLE_AVAILABLE=1
else
  _PORTABLE_AVAILABLE=0
  detect_platform() {
    case "${OSTYPE:-}" in
      linux*) printf 'linux\n' ;;
      darwin*) printf 'macos\n' ;;
      msys*|cygwin*) printf 'windows\n' ;;
      *)
        case "$(uname -s 2>/dev/null)" in
          Linux*) printf 'linux\n' ;;
          Darwin*) printf 'macos\n' ;;
          MINGW*|MSYS*) printf 'windows\n' ;;
          *) printf 'unknown\n' ;;
        esac ;;
    esac
  }
  # Copy-mode parity: portable.sh would supply codex_available(); define a
  # matching fallback so check_codex() / the hook-profile case do not hit an
  # undefined function when lib/ is absent (CC-201).
  codex_available() { command -v codex >/dev/null 2>&1; }
fi

if [[ "$_PORTABLE_AVAILABLE" -eq 1 && -f "$SCRIPT_DIR/lib/memory-dir.sh" ]]; then
  # shellcheck source=scripts/lib/memory-dir.sh
  . "$SCRIPT_DIR/lib/memory-dir.sh"
  _MEMORY_DIR_AVAILABLE=1
else
  _MEMORY_DIR_AVAILABLE=0
fi

JSON=0
QUIET=0
COLOR=0
REPO_ROOT=""
PROFILE="auto"
[[ -t 1 ]] && COLOR=1

_OK_COUNT=0
_WARN_COUNT=0
_FAIL_COUNT=0
_SETTINGS_FILE_FAILED=0
_SETTINGS_FILE_INVALID=0

usage() {
  cat <<'EOF'
Usage: doctor.sh [--json] [--quiet] [--no-color] [--repo <path>] [--profile auto|minimal|full]

Run pm-dispatch environment health checks.

Options:
  --json        Emit JSON Lines output and disable color
  --quiet       Suppress OK lines in human output
  --no-color    Disable colorized human output
  --repo PATH   Repository root to check (default: script directory parent)
  --profile auto|minimal|full
                Override hook-profile detection (default: auto)
  --help        Show this help
EOF
}

_json_esc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

_print_tagged() {
  local plain_tag="$1" color_tag="$2" msg="$3"
  if [[ "$COLOR" -eq 1 ]]; then
    printf "${color_tag} %s\n" "$msg"
  else
    printf '%s %s\n' "$plain_tag" "$msg"
  fi
}

# Usage: emit_check <slug> <status: ok|warn|fail> <message> [fix]
emit_check() {
  local slug="$1" status="$2" msg="$3" fix="${4-}"
  case "$status" in
    ok)
      _OK_COUNT=$((_OK_COUNT + 1))
      [[ "$QUIET" -eq 1 ]] && return 0
      if [[ "$JSON" -eq 1 ]]; then
        printf '{"check":"%s","status":"ok","message":"%s"}\n' "$slug" "$(_json_esc "$msg")"
      else
        _print_tagged "[OK]  " "\033[32m[OK]\033[0m  " "$msg"
      fi
      ;;
    warn)
      _WARN_COUNT=$((_WARN_COUNT + 1))
      if [[ "$JSON" -eq 1 ]]; then
        local fld=""
        [[ -n "$fix" ]] && fld=',"fix":"'"$(_json_esc "$fix")"'"'
        printf '{"check":"%s","status":"warn","message":"%s"%s}\n' "$slug" "$(_json_esc "$msg")" "$fld"
      else
        _print_tagged "[WARN]" "\033[33m[WARN]\033[0m" "$msg"
        if [[ -n "$fix" ]]; then
          printf '       Fix: %s\n' "$fix"
        fi
      fi
      ;;
    fail)
      _FAIL_COUNT=$((_FAIL_COUNT + 1))
      if [[ "$JSON" -eq 1 ]]; then
        local fld=""
        [[ -n "$fix" ]] && fld=',"fix":"'"$(_json_esc "$fix")"'"'
        printf '{"check":"%s","status":"fail","message":"%s"%s}\n' "$slug" "$(_json_esc "$msg")" "$fld"
      else
        _print_tagged "[FAIL]" "\033[31m[FAIL]\033[0m" "$msg"
        if [[ -n "$fix" ]]; then
          printf '       Fix: %s\n' "$fix"
        fi
      fi
      ;;
  esac
}

jq_fix() {
  case "$(detect_platform)" in
    linux) printf 'sudo apt install jq  (or: sudo dnf install jq / sudo pacman -S jq)' ;;
    macos) printf 'brew install jq' ;;
    windows) printf 'winget install jqlang.jq' ;;
    *) printf 'see https://stedolan.github.io/jq/download/' ;;
  esac
}

check_jq() {
  if command -v jq >/dev/null 2>&1; then
    emit_check jq ok "jq available"
  else
    emit_check jq fail "jq not found" "$(jq_fix)"
  fi
}

check_claude() {
  if command -v claude >/dev/null 2>&1; then
    emit_check claude ok "claude available"
  else
    emit_check claude warn "claude not found — hooks in settings.json work independently of the claude binary" \
      "Install Claude Code: https://docs.anthropic.com/claude-code"
  fi
}

check_codex() {
  if codex_available; then
    emit_check codex ok "codex available"
  else
    emit_check codex warn "codex not found — full-profile hooks (hook-codex-bash-guard.sh etc.) will be skipped; minimal profile active" \
      "Install Codex CLI for full-profile hooks (optional)"
  fi
}

check_settings_file() {
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
      "printf '{}\\n' > ~/.claude/settings.json  then re-run install-hooks.sh"
    return
  fi

  emit_check settings-file ok "settings.json present"
}

hook_present() {
  local basename="$1" settings="$2"
  jq -e --arg basename "$basename" '
    def normalize_path:
      if test("^[A-Za-z]:[/\\\\]") then
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
      $basename == "hook-save-rate-limits.sh" and
      ((.statusLine.command? // "") as $cmd |
        ($cmd | normalize_path) as $ncmd |
        (($ncmd | split("/") | last) == $basename and ($ncmd | split("/") | .[-2]) == "scripts"))
    )
  ' "$settings" >/dev/null 2>&1
}

stale_hook_commands() {
  local settings="$1" repo_root="$2"
  jq -r --arg repo_root "$repo_root" '
    # Normalize Windows drive paths (C:/...) to POSIX form (/c/...) so that
    # comparisons work regardless of which format the shell or installer used.
    def normalize_path:
      if test("^[A-Za-z]:[/\\\\]") then
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
        ($ncmd | split("/") | .[-2]) == "scripts" and
        (($ncmd | split("/") | last) | IN(
          "hook-pm-write-guard.sh",
          "hook-tool-trace.sh",
          "hook-log-claude-usage.sh",
          "hook-session-summary.sh",
          "hook-inject-memory.sh",
          "hook-save-rate-limits.sh",
          "hook-routing-log.sh",
          "hook-codex-bash-guard.sh",
          "hook-codex-write-guard.sh"
        )) and
        ($ncmd | startswith(($repo_root | normalize_path) + "/") | not)
      ) | .command)
    | unique[]
  ' "$settings" 2>/dev/null
}

check_hooks() {
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
    hook-pm-write-guard.sh
    hook-tool-trace.sh
    hook-log-claude-usage.sh
    hook-session-summary.sh
    hook-inject-memory.sh
    hook-save-rate-limits.sh
    hook-routing-log.sh
  )
  local _want_full=0
  case "$PROFILE" in
    full)    _want_full=1 ;;
    minimal) _want_full=0 ;;
    *)       if codex_available; then _want_full=1; else _want_full=0; fi ;;
  esac
  if [[ "$_want_full" -eq 1 ]]; then
    profile="full"
    hooks+=(
      hook-codex-bash-guard.sh
      hook-codex-write-guard.sh
    )
  else
    profile="minimal"
  fi

  local -a missing=()
  local hook
  for hook in "${hooks[@]}"; do
    if ! hook_present "$hook" "$settings"; then
      missing+=("$hook")
    fi
  done

  # Compute stale list before emitting any status so we emit a single line.
  local -a _stale=()
  if command -v jq >/dev/null 2>&1; then
    local _sc
    while IFS= read -r _sc; do
      [[ -n "$_sc" ]] && _stale+=("$_sc")
    done < <(stale_hook_commands "$settings" "$REPO_ROOT")
  fi

  if [[ "${#missing[@]}" -gt 0 ]]; then
    emit_check hooks fail "missing hooks: ${missing[*]}" "bash '${REPO_ROOT}/scripts/install-hooks.sh'"
  elif [[ "${#_stale[@]}" -gt 0 ]]; then
    emit_check hooks warn \
      "${#_stale[@]} hook(s) wired from a different checkout (e.g. $(basename "${_stale[0]}"))" \
      "bash '${REPO_ROOT}/install.sh' to re-wire hooks to this checkout"
  else
    emit_check hooks ok "${#hooks[@]} hooks present ($profile profile)"
  fi
}

check_dispatch_allowlist() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  if [[ "$_SETTINGS_FILE_FAILED" -eq 1 || "$_SETTINGS_FILE_INVALID" -eq 1 ]]; then
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    emit_check dispatch-allowlist warn "jq not available — cannot verify dispatch-allowlist"
    return
  fi

  # Check each dispatch script: settings must contain abs OR tilde form.
  # Scanning adapters/* makes this adapter-agnostic — no hardcoded executor names.
  local f rel all_ok=1 any=0
  f="$REPO_ROOT/scripts/codex-dispatch.sh"
  if [[ -f "$f" ]]; then
    any=1
    rel="${f#"$HOME/"}"
    jq -e --arg a "Bash($f:*)" --arg t "Bash(~/$rel:*)" \
      '(.permissions.allow // []) | (index($a) != null or index($t) != null)' \
      "$settings" >/dev/null 2>&1 || all_ok=0
  fi
  for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
    [[ -f "$f" ]] || continue
    any=1
    rel="${f#"$HOME/"}"
    jq -e --arg a "Bash($f:*)" --arg t "Bash(~/$rel:*)" \
      '(.permissions.allow // []) | (index($a) != null or index($t) != null)' \
      "$settings" >/dev/null 2>&1 || all_ok=0
  done

  if [[ $any -eq 0 || $all_ok -eq 0 ]]; then
    emit_check dispatch-allowlist fail "dispatch allowlist incomplete or missing" \
      "bash '${REPO_ROOT}/install.sh'"
  else
    emit_check dispatch-allowlist ok "dispatch allowlist present (all adapters)"
  fi
}

check_scripts_executable() {
  local -a scripts=(
    hook-pm-write-guard.sh
    hook-codex-bash-guard.sh
    hook-codex-write-guard.sh
    hook-tool-trace.sh
    hook-routing-log.sh
    hook-log-claude-usage.sh
    hook-session-summary.sh
    hook-inject-memory.sh
    hook-save-rate-limits.sh
    token-usage.sh
    log-usage.sh
    pr-gate.sh
    codex-dispatch.sh
    setup-project.sh
    patch-gitignore.sh
    doctor.sh
  )
  local -a missing=()
  local script
  for script in "${scripts[@]}"; do
    if [[ ! -x "${REPO_ROOT}/scripts/${script}" ]]; then
      missing+=("$script")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    emit_check scripts-executable fail "non-executable scripts: ${missing[*]}" \
      "chmod +x '${REPO_ROOT}/scripts/'*.sh"
  else
    emit_check scripts-executable ok "managed scripts are executable"
  fi
}

check_memory_dir() {
  if [[ "$_MEMORY_DIR_AVAILABLE" -eq 0 ]]; then
    emit_check memory-dir warn "memory-dir check skipped (lib/memory-dir.sh not available)"
    return
  fi

  local result=""
  result="$(find_memory_dir "$REPO_ROOT" 2>/dev/null || true)"
  if [[ -n "$result" && -d "$result" ]]; then
    emit_check memory-dir ok "memory directory exists: $result"
  else
    emit_check memory-dir warn "no memory directory for current path — created on first Claude Code session" \
      "bash '${REPO_ROOT}/scripts/setup-project.sh' or start a Claude Code session here"
  fi
}

check_manifest() {
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

check_frontmatter_lint() {
  # In copy-mode (no lib/), lint-frontmatter.sh is not co-installed with doctor.sh.
  # This check degrades to WARN in that case. See CC-225 for v2 resolution.
  # Always run the installed (trusted) linter; never execute scripts from --repo target.
  local lint_script="${SCRIPT_DIR}/lint-frontmatter.sh"
  if [[ ! -x "$lint_script" ]]; then
    emit_check frontmatter-lint warn "lint-frontmatter.sh not found or not executable" \
      "bash '${REPO_ROOT}/install.sh' to restore managed scripts"
    return
  fi
  local out
  out="$("$lint_script" --repo-root "$REPO_ROOT" 2>&1)" && {
    emit_check frontmatter-lint ok "frontmatter lint passed"
    return
  }
  emit_check frontmatter-lint fail "frontmatter lint errors detected: ${out%%$'\n'*}" \
    "bash '${SCRIPT_DIR}/lint-frontmatter.sh' --repo-root '${REPO_ROOT}' for details"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        JSON=1
        COLOR=0
        shift
        ;;
      --quiet)
        QUIET=1
        shift
        ;;
      --no-color)
        COLOR=0
        shift
        ;;
      --repo)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          printf 'doctor: --repo requires a path\n' >&2
          exit 2
        fi
        REPO_ROOT="$2"
        shift 2
        ;;
      --profile)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          printf 'doctor: --profile requires auto|minimal|full\n' >&2
          exit 2
        fi
        case "${2}" in
          auto|minimal|full) PROFILE="$2" ;;
          *)
            printf 'doctor: --profile must be auto, minimal, or full\n' >&2
            exit 2
            ;;
        esac
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        printf 'doctor: unknown flag %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || printf '%s/..' "$SCRIPT_DIR")"
    if [[ "$_PORTABLE_AVAILABLE" -eq 0 && ! -f "$REPO_ROOT/install.sh" ]]; then
      emit_check "repo-root" "fail" \
        "copy-mode install: repo root could not be inferred (got: $REPO_ROOT)" \
        "re-run with: bash $(basename "${BASH_SOURCE[0]}") --repo <path-to-pm-dispatch-checkout>"
      if [[ "$JSON" -eq 1 ]]; then
        printf '{"summary":true,"ok":%d,"warn":%d,"fail":%d,"exit_code":1}\n' \
          "$_OK_COUNT" "$_WARN_COUNT" "$_FAIL_COUNT"
      else
        printf '\nSummary: %d OK, %d WARN, %d FAIL\n' "$_OK_COUNT" "$_WARN_COUNT" "$_FAIL_COUNT"
      fi
      exit 1
    fi
  fi

  check_jq
  check_claude
  check_codex
  check_settings_file
  check_hooks
  check_dispatch_allowlist
  check_scripts_executable
  check_memory_dir
  check_manifest
  check_frontmatter_lint

  local ec=0
  [[ $_FAIL_COUNT -gt 0 ]] && ec=1
  if [[ "$JSON" -eq 1 ]]; then
    printf '{"summary":true,"ok":%d,"warn":%d,"fail":%d,"exit_code":%d}\n' \
      "$_OK_COUNT" "$_WARN_COUNT" "$_FAIL_COUNT" "$ec"
  else
    printf '\nSummary: %d OK, %d WARN, %d FAIL\n' "$_OK_COUNT" "$_WARN_COUNT" "$_FAIL_COUNT"
  fi

  exit "$ec"
}

main "$@"
