#!/usr/bin/env bash
# shellcheck disable=SC2034  # PROFILE and settings state are consumed by manifest-declared doctor modules
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# Resolve symlink to find the actual runtime/bin directory.
if [[ -L "${BASH_SOURCE[0]}" ]]; then
  _real="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || readlink "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
  SCRIPT_DIR="$(cd "$(dirname "$_real")" 2>/dev/null && pwd || printf '%s' "$SCRIPT_DIR")"
  unset _real
fi
DOCTOR_INSTALL_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

# Source libs with graceful fallback for copy-mode (Windows) where lib/ is absent.
if [[ -f "$SCRIPT_DIR/../lib/portable.sh" ]]; then
  # shellcheck source=runtime/lib/portable.sh
  . "$SCRIPT_DIR/../lib/portable.sh"
  # shellcheck source=runtime/lib/allowlist.sh
  [[ -f "$SCRIPT_DIR/../lib/allowlist.sh" ]] && . "$SCRIPT_DIR/../lib/allowlist.sh"
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
  # undefined function when lib/ is absent.
  codex_available() { command -v codex >/dev/null 2>&1; }
fi

if [[ "$_PORTABLE_AVAILABLE" -eq 1 && -f "$SCRIPT_DIR/../lib/memory-dir.sh" ]]; then
  # shellcheck source=runtime/lib/memory-dir.sh
  . "$SCRIPT_DIR/../lib/memory-dir.sh"
  _MEMORY_DIR_AVAILABLE=1
else
  _MEMORY_DIR_AVAILABLE=0
fi

if [[ -f "$SCRIPT_DIR/../lib/runner-kind.sh" ]]; then
  # shellcheck source=runtime/lib/runner-kind.sh
  . "$SCRIPT_DIR/../lib/runner-kind.sh"
  _RUNNER_KIND_AVAILABLE=1
else
  _RUNNER_KIND_AVAILABLE=0
fi

if [[ -f "$SCRIPT_DIR/../lib/host-manifest.sh" ]]; then
  # shellcheck source=runtime/lib/host-manifest.sh
  . "$SCRIPT_DIR/../lib/host-manifest.sh"
  _HOST_MANIFEST_AVAILABLE=1
else
  _HOST_MANIFEST_AVAILABLE=0
fi

if [[ "$_PORTABLE_AVAILABLE" -eq 1 \
   && -f "$SCRIPT_DIR/../lib/state-paths.sh" \
   && -f "$SCRIPT_DIR/../lib/detached-launch.sh" \
   && -f "$SCRIPT_DIR/../lib/pmctl-dispatch.sh" ]]; then
  # shellcheck source=runtime/lib/state-paths.sh
  . "$SCRIPT_DIR/../lib/state-paths.sh"
  # shellcheck source=runtime/lib/detached-launch.sh
  . "$SCRIPT_DIR/../lib/detached-launch.sh"
  # shellcheck source=runtime/lib/pmctl-dispatch.sh
  . "$SCRIPT_DIR/../lib/pmctl-dispatch.sh"
  _DISPATCH_RECONCILE_AVAILABLE=1
else
  _DISPATCH_RECONCILE_AVAILABLE=0
fi

_DOCTOR_HOST_NAMES=()

load_doctor_host_modules() {
  _DOCTOR_HOST_NAMES=()
  [[ "$_HOST_MANIFEST_AVAILABLE" -eq 1 ]] || return 0

  local host module_path entrypoint
  while IFS= read -r host; do
    module_path="$(host_manifest_module_path "$REPO_ROOT" "$host" doctor_module)" || return 1
    # shellcheck disable=SC1090
    . "$module_path"
    entrypoint="doctor_host_${host}_run"
    declare -F "$entrypoint" >/dev/null || {
      printf 'doctor: doctor_module for %s lacks %s\n' "$host" "$entrypoint" >&2
      return 1
    }
    _DOCTOR_HOST_NAMES+=("$host")
  done < <(host_manifest_names "$REPO_ROOT")
}

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

# Emit the final doctor envelope consistently for normal completion and
# fail-fast setup paths. JSON mode stays JSONL-only on stdout.
emit_summary() {
  local exit_code="$1"
  if [[ "$JSON" -eq 1 ]]; then
    printf '{"summary":true,"ok":%d,"warn":%d,"fail":%d,"exit_code":%d}\n' \
      "$_OK_COUNT" "$_WARN_COUNT" "$_FAIL_COUNT" "$exit_code"
  else
    printf '\nSummary: %d OK, %d WARN, %d FAIL\n' "$_OK_COUNT" "$_WARN_COUNT" "$_FAIL_COUNT"
  fi
}

# Capability record emitter for host modules. Same status envelope and
# counters as emit_check, plus the structured capability object fields the
# host axis reports on (provider/enforcement/coverage/stability/confidence),
# so JSON consumers can distinguish "what the host can do" records from plain
# environment checks. Host-agnostic plumbing — host-specific values live in
# lib/doctor-host-<name>.sh modules.
#
# Usage: emit_capability <slug> <status: ok|warn|fail> <host> <capability> \
#          <provider> <enforcement> <coverage> <stability> <confidence> \
#          <message> [fix]
emit_capability() {
  local slug="$1" status="$2" host="$3" capability="$4" provider="$5"
  local enforcement="$6" coverage="$7" stability="$8" confidence="$9"
  local msg="${10}" fix="${11-}"
  if [[ "$JSON" -eq 1 ]]; then
    case "$status" in
      ok)   _OK_COUNT=$((_OK_COUNT + 1));   [[ "$QUIET" -eq 1 ]] && return 0 ;;
      warn) _WARN_COUNT=$((_WARN_COUNT + 1)) ;;
      fail) _FAIL_COUNT=$((_FAIL_COUNT + 1)) ;;
    esac
    local fld=""
    [[ -n "$fix" ]] && fld=',"fix":"'"$(_json_esc "$fix")"'"'
    printf '{"check":"%s","status":"%s","message":"%s","host":"%s","capability":"%s","provider":"%s","enforcement":"%s","coverage":"%s","stability":"%s","confidence":"%s"%s}\n' \
      "$slug" "$status" "$(_json_esc "$msg")" "$(_json_esc "$host")" \
      "$(_json_esc "$capability")" "$(_json_esc "$provider")" \
      "$(_json_esc "$enforcement")" "$(_json_esc "$coverage")" \
      "$(_json_esc "$stability")" "$(_json_esc "$confidence")" "$fld"
  else
    # Human mode: reuse emit_check's tagged formatting; the message carries
    # the readable state, the capability tuple rides in a compact suffix.
    emit_check "$slug" "$status" "$msg [$host/$capability: $provider/$enforcement]" "$fix"
  fi
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

# Best-effort, non-interactive auth probe for a non-interactive executor.
# Returns 0 (authed) when a known credential file or an API-key/OAuth env var is
# present, 1 (unauthed) otherwise. Heuristic by design — it never runs the CLI
# (which could hang or incur cost) and never reads secret contents; it only tests
# for the existence of well-known credential locations. On hosts that store
# credentials elsewhere (e.g. macOS Keychain) this can false-negative; the
# supported platform (Linux/WSL2) uses files, and the dispatch-time semantic
# terminal-event check is the authoritative backstop (an unauthed run emits no
# terminal event → post-verify fails). See docs/executor-contract.md.
executor_authed() {
  local executor="$1"
  case "$executor" in
    codex)
      [[ -n "${OPENAI_API_KEY:-}" ]] && return 0
      [[ -s "${HOME}/.codex/auth.json" ]] && return 0
      ;;
    claude)
      [[ -n "${ANTHROPIC_API_KEY:-}" ]] && return 0
      [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] && return 0
      [[ -s "${HOME}/.claude/.credentials.json" ]] && return 0
      ;;
    grok)
      [[ -n "${XAI_API_KEY:-}" ]] && return 0
      [[ -n "${GROK_API_KEY:-}" ]] && return 0
      [[ -s "${HOME}/.grok/auth.json" ]] && return 0
      [[ -n "${GROK_HOME:-}" && -s "${GROK_HOME}/auth.json" ]] && return 0
      ;;
  esac
  return 1
}

check_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    emit_check claude warn "claude not found — hooks in settings.json work independently of the claude binary" \
      "Install Claude Code: https://docs.anthropic.com/claude-code"
    return
  fi
  # Binary present: an unauthenticated executor must fail loud, not silently
  # produce a broken trace at dispatch time.
  if executor_authed claude; then
    emit_check claude ok "claude available and authenticated"
  else
    emit_check claude fail "claude present but not authenticated — dispatch would fail (no result event)" \
      "Run 'claude' once to log in, or export ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN"
  fi
}

check_codex() {
  if ! codex_available; then
    emit_check codex warn "codex not found — dispatch to the codex adapter (pmctl dispatch run --adapter codex) is unavailable" \
      "Install Codex CLI if you dispatch tasks to codex (optional)"
    return
  fi
  # Binary present: an unauthenticated executor must fail loud, not silently
  # produce a broken trace at dispatch time.
  if executor_authed codex; then
    emit_check codex ok "codex available and authenticated"
  else
    emit_check codex fail "codex present but not authenticated — dispatch would fail (no turn.completed event)" \
      "Run 'codex login' to authenticate, or export OPENAI_API_KEY"
  fi
}

check_grok() {
  if ! command -v grok >/dev/null 2>&1; then
    emit_check grok warn "grok not found — dispatch to the grok adapter (pmctl dispatch run --adapter grok) is unavailable" \
      "Install Grok Build CLI if you dispatch tasks to grok (optional)"
    return
  fi
  if executor_authed grok; then
    emit_check grok ok "grok available and authenticated"
  else
    emit_check grok fail "grok present but not authenticated — dispatch would fail (no end event)" \
      "Run 'grok' once to log in, or export XAI_API_KEY / GROK_API_KEY"
  fi
}

pmctl_fix() {
  case "$(detect_platform)" in
    windows) printf "Add '%s/cli' to PATH; do not copy pmctl because copied files cannot resolve repo libs" "$REPO_ROOT" ;;
    *) printf "bash '%s/install.sh'  (then add '%s' to PATH if prompted)" "$REPO_ROOT" "${PMCTL_BIN_DIR:-$HOME/.local/bin}" ;;
  esac
}

# Canonicalize a path through symlinks so a ~/.local/bin/pmctl symlink and the
# checkout's cli/pmctl compare equal. Defensive across copy-mode (portable.sh
# may be absent): realpath_m -> realpath -> readlink -f -> raw.
_pmctl_canon() {
  local p="$1"
  if declare -F realpath_m >/dev/null 2>&1; then
    realpath_m "$p" 2>/dev/null || printf '%s' "$p"
  elif command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null || printf '%s' "$p"
  else
    readlink -f "$p" 2>/dev/null || printf '%s' "$p"
  fi
}

check_pmctl() {
  local resolved
  if ! resolved="$(command -v pmctl 2>/dev/null)"; then
    emit_check pmctl warn "pmctl not found on PATH" "$(pmctl_fix)"
    return
  fi
  # A bare `command -v pmctl` success is not enough: a foreign pmctl on PATH can
  # shadow this checkout's CLI, leaving the user running an unrelated tool while
  # appearing installed. Verify the resolved pmctl belongs to this checkout.
  local want
  want="$REPO_ROOT/cli/pmctl"
  if [[ "$(_pmctl_canon "$resolved")" == "$(_pmctl_canon "$want")" ]]; then
    emit_check pmctl ok "pmctl available (this checkout)"
  else
    emit_check pmctl warn "pmctl on PATH ($resolved) does not belong to this checkout ($want)" "$(pmctl_fix)"
  fi
}

# Copy-mode degraded fallback for the claude-host checks. Runs only when no
# lib/doctor-host-*.sh module loaded (doctor.sh installed as a lone copied
# file, e.g. native Windows). Keeps the settings-file / dispatch-allowlist /
# manifest slugs and their pass/fail semantics concrete; the hooks inventory
# needs the full jq matchers that live in lib/doctor-host-claude.sh, so it
# degrades to a single warn here instead of duplicating them. Keep slugs and
# semantics in sync with lib/doctor-host-claude.sh.
check_host_fallback_copy_mode() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

  # settings-file (concrete, mirrors module semantics)
  _SETTINGS_FILE_FAILED=0
  _SETTINGS_FILE_INVALID=0
  if [[ ! -f "$settings" ]]; then
    _SETTINGS_FILE_FAILED=1
    emit_check settings-file fail "settings.json missing" "bash '${REPO_ROOT}/install.sh'"
  elif command -v jq >/dev/null 2>&1 && ! jq . "$settings" >/dev/null 2>&1; then
    _SETTINGS_FILE_INVALID=1
    emit_check settings-file fail "settings.json exists but is not valid JSON" \
      "printf '{}\\n' > ~/.claude/settings.json  then re-run install-guards.sh"
  else
    emit_check settings-file ok "settings.json present"
  fi

  # hooks (degraded: full inventory matchers live in lib/doctor-host-claude.sh)
  emit_check hooks warn \
    "hook inventory check unavailable in copy-mode (lib/ absent)" \
    "run doctor from the checkout: bash '${REPO_ROOT}/runtime/bin/doctor.sh'"

  # dispatch-allowlist (concrete inline scan)
  if [[ "$_SETTINGS_FILE_FAILED" -eq 0 && "$_SETTINGS_FILE_INVALID" -eq 0 ]]; then
    if ! command -v jq >/dev/null 2>&1; then
      emit_check dispatch-allowlist warn "jq not available — cannot verify dispatch-allowlist"
    else
      local all_ok=1 any=0 f rel
      for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
        [[ -f "$f" ]] || continue
        any=1; rel="${f#"$HOME/"}"
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
    fi
  fi

  # manifest (concrete, mirrors module semantics)
  local manifest_path="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.pm-dispatch/install-manifest.json"
  if [[ ! -f "$manifest_path" ]]; then
    emit_check manifest warn "install manifest missing — uninstall.sh cannot track files" \
      "bash '${REPO_ROOT}/install.sh' to regenerate"
  elif command -v jq >/dev/null 2>&1 && ! jq -e '.manifest_version == 1' "$manifest_path" >/dev/null 2>&1; then
    emit_check manifest warn "install manifest has unexpected version" \
      "bash '${REPO_ROOT}/install.sh' to regenerate"
  else
    emit_check manifest ok "install manifest present"
  fi
}

check_scripts_executable() {
  local -a scripts=(
    runtime/hooks/guard-pm-write.sh
    runtime/hooks/guard-reviewer-write.sh
    hosts/claude/hooks/log-usage.sh
    runtime/hooks/guard-session-summary.sh
    runtime/hooks/guard-inject-memory.sh
    runtime/hooks/guard-inject-context.sh
    hosts/claude/hooks/save-rate-limits.sh
    ops/usage/token-usage.sh
    ops/usage/log-usage.sh
    runtime/bin/pr-gate.sh
    ops/setup/setup-project.sh
    ops/setup/patch-gitignore.sh
    runtime/bin/doctor.sh
  )
  local -a missing=()
  local script
  for script in "${scripts[@]}"; do
    if [[ ! -x "${REPO_ROOT}/${script}" ]]; then
      missing+=("$script")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    emit_check scripts-executable fail "non-executable scripts: ${missing[*]}" \
      "restore executable modes under runtime/, hosts/, and ops/"
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
      "bash '${REPO_ROOT}/ops/setup/setup-project.sh' or start a Claude Code session here"
  fi
}

check_frontmatter_lint() {
  # In copy-mode (no lib/), lint-frontmatter.sh is not co-installed with doctor.sh.
  # This check degrades to WARN in that case.
  # Always run the installed (trusted) linter; never execute scripts from --repo target.
  local lint_script="$DOCTOR_INSTALL_ROOT/tools/lint/lint-frontmatter.sh"
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
    "bash '$REPO_ROOT/tools/lint/lint-frontmatter.sh' --repo-root '${REPO_ROOT}' for details"
}

# Read-only stale-detached-run diagnostics (CC-499). Goes through the public
# `pmctl_dispatch_reconcile --all --dry-run` (same entry point `pmctl dispatch
# reconcile` uses) rather than re-deriving the run listing or reaching into a
# private classifier — one implementation of "walk this work dir's runs" for
# both the CLI and doctor. Dry-run never writes a terminal claim; convergence
# is opt-in via the real reconcile command, printed as the fix hint below.
check_detached_runs() {
  if [[ "$_DISPATCH_RECONCILE_AVAILABLE" -eq 0 ]]; then
    emit_check detached-runs warn "detached-run diagnostics skipped (dispatch libs not available)"
    return
  fi

  local out rc=0
  out="$(pmctl_dispatch_reconcile "$REPO_ROOT" --all --cd "$REPO_ROOT" --dry-run 2>/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 && -z "$out" ]]; then
    emit_check detached-runs warn "detached-run diagnostics skipped (state-paths unavailable)"
    return
  fi

  # Split stale runs by whether `reconcile --all` (no --dry-run) would
  # actually converge them: orphaned/process-gone-without-evidence are
  # provable-absent and DO converge; indeterminate (e.g. PID-reuse-suspected)
  # never does — reconcile refuses to guess. The fix hint must not promise
  # convergence it will not deliver (gate critic finding, CC-499).
  local line total=0 reconcilable=0 indeterminate=0
  while IFS= read -r line; do
    [[ "$line" == run:\ * ]] || continue
    total=$((total + 1))
    case "$line" in
      *"status: orphaned"*|*"status: process-gone-without-evidence"*)
        reconcilable=$((reconcilable + 1)) ;;
      *"status: indeterminate"*)
        indeterminate=$((indeterminate + 1)) ;;
    esac
  done <<<"$out"
  local stale=$((reconcilable + indeterminate))

  if [[ "$total" -eq 0 ]]; then
    emit_check detached-runs ok "no detached dispatch runs recorded"
  elif [[ "$stale" -eq 0 ]]; then
    emit_check detached-runs ok "$total detached run(s) recorded, none stale"
  elif [[ "$indeterminate" -eq 0 ]]; then
    emit_check detached-runs warn "$reconcilable of $total detached run(s) look stale (crash/reboot/orphan)" \
      "pmctl dispatch reconcile --all --cd '$REPO_ROOT' --dry-run   # inspect, then drop --dry-run to converge"
  elif [[ "$reconcilable" -eq 0 ]]; then
    emit_check detached-runs warn "$indeterminate of $total detached run(s) are indeterminate (e.g. possible PID reuse)" \
      "pmctl dispatch reconcile --all --cd '$REPO_ROOT' --dry-run   # inspect; these require manual investigation, reconcile will not auto-converge them"
  else
    emit_check detached-runs warn "$reconcilable of $total detached run(s) look stale (crash/reboot/orphan), $indeterminate more are indeterminate (e.g. possible PID reuse) and will not auto-converge" \
      "pmctl dispatch reconcile --all --cd '$REPO_ROOT' --dry-run   # inspect first; dropping --dry-run only converges the reconcilable ones"
  fi
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
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd || printf '%s/..' "$SCRIPT_DIR")"
    if [[ "$_PORTABLE_AVAILABLE" -eq 0 && ! -f "$REPO_ROOT/install.sh" ]]; then
      emit_check "repo-root" "fail" \
        "copy-mode install: repo root could not be inferred (got: $REPO_ROOT)" \
        "re-run with: bash $(basename "${BASH_SOURCE[0]}") --repo <path-to-pm-dispatch-checkout>"
      emit_summary 1
      exit 1
    fi
  fi

  if ! load_doctor_host_modules; then
    emit_check "host-modules" "fail" \
      "host manifest doctor modules could not be loaded" \
      "repair the failing hosts/<name>/host.yaml doctor_module declaration"
    emit_summary 1
    exit 1
  fi

  # Native Windows Git Bash is not an officially supported platform; WSL2
  # (treated as Linux) is the supported path. Surface that up front so the checks
  # below are not mistaken for a supported baseline; some may report
  # platform-specific false failures. JSON mode stays clean (machine consumers
  # parse the summary). See docs/platform-support.md.
  if [[ "$JSON" -ne 1 && "$(detect_platform)" == "windows" ]]; then
    printf '\nNote: native Windows (Git Bash) is not officially supported during core development.\n'
    printf '  pm-dispatch targets Linux & WSL2; run under WSL2 (treated as Linux) for a supported setup.\n'
    printf '  Checks below may report platform-specific false failures. See docs/platform-support.md.\n\n'
  fi

  check_jq
  check_claude
  check_codex
  check_grok
  check_pmctl
  # Host axis: generic dispatch into manifest-declared doctor modules. Copy-mode
  # (no manifest library available) degrades to the compact fallback instead.
  if [[ ${#_DOCTOR_HOST_NAMES[@]} -gt 0 ]]; then
    local _host
    for _host in "${_DOCTOR_HOST_NAMES[@]}"; do
      "doctor_host_${_host}_run"
    done
  else
    check_host_fallback_copy_mode
  fi
  check_scripts_executable
  check_memory_dir
  check_frontmatter_lint
  check_detached_runs

  local ec=0
  [[ $_FAIL_COUNT -gt 0 ]] && ec=1
  emit_summary "$ec"

  exit "$ec"
}

main "$@"
