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
[[ -t 1 ]] && COLOR=1

_OK_COUNT=0
_WARN_COUNT=0
_FAIL_COUNT=0
_SETTINGS_FILE_FAILED=0

usage() {
  cat <<'EOF'
Usage: doctor.sh [--json] [--quiet] [--no-color] [--repo <path>]

Run pm-dispatch environment health checks.

Options:
  --json        Emit JSON Lines output and disable color
  --quiet       Suppress OK lines in human output
  --no-color    Disable colorized human output
  --repo PATH   Repository root to check (default: script directory parent)
  --help        Show this help
EOF
}

_json_esc() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
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
  if command -v codex >/dev/null 2>&1; then
    emit_check codex ok "codex available"
  else
    emit_check codex warn "codex not found — full-profile hooks (hook-codex-bash-guard.sh etc.) will be skipped; minimal profile active" \
      "Install Codex CLI for full-profile hooks (optional)"
  fi
}

check_settings_file() {
  local settings="$HOME/.claude/settings.json"
  _SETTINGS_FILE_FAILED=0
  if [[ ! -f "$settings" ]]; then
    _SETTINGS_FILE_FAILED=1
    emit_check settings-file fail "settings.json missing" "bash '${REPO_ROOT}/install.sh'"
    return
  fi

  if command -v jq >/dev/null 2>&1 && ! jq . "$settings" >/dev/null 2>&1; then
    emit_check settings-file warn "settings.json exists but is not valid JSON" \
      "printf '{}\\n' > ~/.claude/settings.json  then re-run install-hooks.sh"
    return
  fi

  emit_check settings-file ok "settings.json present"
}

hook_present() {
  local basename="$1" settings="$2"
  jq -e --arg basename "$basename" '
    def managed_hook:
      (.command? // "") as $cmd |
      (($cmd | split("/") | last) == $basename and ($cmd | split("/") | .[-2]) == "scripts");
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
        (($cmd | split("/") | last) == $basename and ($cmd | split("/") | .[-2]) == "scripts"))
    )
  ' "$settings" >/dev/null 2>&1
}

check_hooks() {
  local settings="$HOME/.claude/settings.json"
  if [[ "$_SETTINGS_FILE_FAILED" -eq 1 ]]; then
    emit_check hooks fail "settings.json missing — cannot check hooks" "bash '${REPO_ROOT}/install.sh'"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    emit_check hooks warn "jq not available — cannot verify hooks"
    return
  fi

  local profile="minimal"
  local -a hooks=(
    hook-pm-write-guard.sh
    hook-tool-trace.sh
    hook-log-claude-usage.sh
    hook-session-summary.sh
    hook-inject-memory.sh
    hook-save-rate-limits.sh
  )
  if command -v codex >/dev/null 2>&1; then
    profile="full"
    hooks+=(
      hook-codex-bash-guard.sh
      hook-codex-write-guard.sh
      hook-routing-log.sh
    )
  fi

  local -a missing=()
  local hook
  for hook in "${hooks[@]}"; do
    if ! hook_present "$hook" "$settings"; then
      missing+=("$hook")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    emit_check hooks fail "missing hooks: ${missing[*]}" "bash '${REPO_ROOT}/scripts/install-hooks.sh'"
  else
    emit_check hooks ok "${#hooks[@]} hooks present ($profile profile)"
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
      "chmod +x '${REPO_ROOT}/scripts/hook-*.sh'"
  else
    emit_check scripts-executable ok "hook scripts are executable"
  fi
}

check_memory_dir() {
  if [[ "$_MEMORY_DIR_AVAILABLE" -eq 0 ]]; then
    emit_check memory-dir warn "memory-dir check skipped (lib/memory-dir.sh not available)"
    return
  fi

  local result=""
  result="$(find_memory_dir "$PWD" 2>/dev/null || true)"
  if [[ -n "$result" && -d "$result" ]]; then
    emit_check memory-dir ok "memory directory exists: $result"
  else
    emit_check memory-dir warn "no memory directory for current path — created on first Claude Code session" \
      "bash '${REPO_ROOT}/scripts/setup-project.sh' or start a Claude Code session here"
  fi
}

check_manifest() {
  local manifest_path="$HOME/.claude/.pm-dispatch/install-manifest.json"
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
  fi

  check_jq
  check_claude
  check_codex
  check_settings_file
  check_hooks
  check_scripts_executable
  check_memory_dir
  check_manifest

  local ec=0
  [[ $_WARN_COUNT -gt 0 ]] && ec=1
  [[ $_FAIL_COUNT -gt 0 ]] && ec=2
  if [[ "$JSON" -eq 1 ]]; then
    printf '{"summary":true,"ok":%d,"warn":%d,"fail":%d,"exit_code":%d}\n' \
      "$_OK_COUNT" "$_WARN_COUNT" "$_FAIL_COUNT" "$ec"
  else
    printf '\nSummary: %d OK, %d WARN, %d FAIL\n' "$_OK_COUNT" "$_WARN_COUNT" "$_FAIL_COUNT"
  fi

  exit "$ec"
}

main "$@"
