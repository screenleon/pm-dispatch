#!/usr/bin/env bash
# Shared hook helper library.
#
# Source this file from hook scripts after setting HOOK_NAME and LOG_FILE.
# Callers own shell options and must source portable.sh first when using
# hk_require_realpath or hk_validate_path.

hk_read_json() {
  HK_INPUT="$(cat)"

  HK_AGENT_TYPE="$(jq -r '.agent_type // ""' <<<"$HK_INPUT" 2>/dev/null)" || {
    echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
    exit 2
  }
  HK_TOOL_NAME="$(jq -r '.tool_name // ""' <<<"$HK_INPUT" 2>/dev/null)" || {
    echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
    exit 2
  }
  HK_TOOL_INPUT="$(jq -c '.tool_input // {}' <<<"$HK_INPUT" 2>/dev/null)" || {
    echo "$HOOK_NAME: malformed JSON on stdin — denying" >&2
    exit 2
  }
}

hk_jq() {
  jq -r "$1" <<<"$HK_INPUT" 2>/dev/null
}

hk_audit() {
  local decision="$1" reason="${2:-}" target="${3:-}"
  local log_dir
  log_dir="$(dirname "$LOG_FILE")"
  mkdir -p "$log_dir" 2>/dev/null || return 0
  local ts
  ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
  printf '%s %s agent=%s tool=%s decision=%s reason=%q target=%q\n' \
    "$ts" "$HOOK_NAME" "${HK_AGENT_TYPE:-?}" "${HK_TOOL_NAME:-?}" "$decision" "$reason" "$target" \
    >> "$LOG_FILE" 2>/dev/null || true
}

hk_deny() {
  local reason="$1" target="${2:-${HK_TARGET:-}}"
  hk_audit deny "$reason" "$target"
  if declare -F hk_deny_message >/dev/null 2>&1; then
    hk_deny_message "$reason" "$target"
  else
    echo "$HOOK_NAME: denied — $reason" >&2
  fi
  exit 2
}

hk_allow() {
  local reason="${1:-ok}" target="${2:-${HK_TARGET:-}}"
  hk_audit allow "$reason" "$target"
  exit 0
}

hk_require_jq() {
  local bypass_env="${1:-${HK_BYPASS_ENV:-}}"
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  if [[ -n "$bypass_env" ]]; then
    echo "$HOOK_NAME: jq missing on PATH — install jq or set ${bypass_env}=off" >&2
  else
    echo "$HOOK_NAME: jq missing on PATH — install jq" >&2
  fi
  exit 2
}

hk_require_realpath() {
  local bypass_env="${1:-${HK_BYPASS_ENV:-}}"
  if [[ "$(detect_platform)" == "windows" ]] || command -v realpath >/dev/null 2>&1; then
    return 0
  fi
  if [[ -n "$bypass_env" ]]; then
    echo "$HOOK_NAME: realpath missing on PATH — install coreutils or set ${bypass_env}=off" >&2
  else
    echo "$HOOK_NAME: realpath missing on PATH — install coreutils" >&2
  fi
  exit 2
}

hk_check_bypass() {
  local env_var="$1" target="${2:-${HK_TARGET:-}}"
  if [[ "${!env_var:-}" == "off" ]]; then
    hk_audit bypass "${env_var}=off" "$target"
    exit 0
  fi
}

# Normalize a Windows drive-letter path (C:/... or C:\...) to its POSIX mount
# form via cygpath, so it matches the form realpath_m and the POSIX checks
# expect (e.g. C:/Users/.../Temp -> /tmp). Shared so that every side of a path
# comparison normalizes identically — the reviewer guard normalizes its repo
# root through this too (CC-308), closing the asymmetry where file_path was
# cygpath-normalized but the compared-against root was not.
#
# Echoes the (possibly unchanged) path. Returns:
#   0  no-op or normalized OK (path written to stdout)
#   2  drive-letter path but cygpath unavailable
#   3  drive-letter path but cygpath failed / produced empty output
# No-op on linux/macos and for non-drive-letter paths: the platform/pattern
# guard is never entered, so POSIX behavior is byte-for-byte identical.
hk_to_posix_path() {
  local path="$1" _posix
  if [[ "$(detect_platform)" == "windows" && "$path" == [A-Za-z]:[/\\]* ]]; then
    command -v cygpath >/dev/null 2>&1 || return 2
    if _posix="$(cygpath -u -- "$path" 2>/dev/null)" && [[ -n "$_posix" ]]; then
      printf '%s' "$_posix"
      return 0
    fi
    return 3
  fi
  printf '%s' "$path"
  return 0
}

hk_validate_path() {
  local path="${1:-}"
  HK_ABS_PATH=""
  HK_TARGET="$path"

  if [[ -z "$path" ]]; then
    hk_deny "tool_input.file_path empty" "$path"
  fi

  # Normalize a Windows drive-letter path to POSIX mount form before the
  # absolute-path check and every caller's /tmp/brief-*.md contract apply. Fail
  # closed (naming the real cause) if normalization is impossible — falling
  # through would mis-report a valid-but-unnormalized path as "must be absolute".
  local _np _rc
  _np="$(hk_to_posix_path "$path")"; _rc=$?
  case "$_rc" in
    0) path="$_np" ;;
    2) hk_deny "cannot normalize Windows path — cygpath unavailable: $path" "$path" ;;
    *) hk_deny "failed to normalize Windows path to POSIX form: $path" "$path" ;;
  esac

  if [[ "$path" != /* ]]; then
    hk_deny "file_path must be absolute (got: $path)" "$path"
  fi

  HK_ABS_PATH="$(realpath_m "$path" 2>/dev/null)" || {
    hk_deny "realpath failed on file_path" "$path"
  }
}
