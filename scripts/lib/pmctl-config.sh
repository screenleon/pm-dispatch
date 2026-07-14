#!/usr/bin/env bash
# Shared ~/.pm-dispatch/config reader for dispatch adapters.
#
# Call pm_config_load once in the main shell (NOT a subshell) before reading
# the output globals:
#   PM_CFG_TIMEOUT       — dispatch.default_timeout (integer string), or ""
#   PM_CFG_DEFAULT_MODEL — dispatch.default_model (alias/id), or ""
#   PM_CFG_AUTO_PACK     — dispatch.auto_pack (on|off), or ""
#   PM_CFG_LIFECYCLE     — dispatch.lifecycle (foreground|detached), or ""
#   PM_CFG_MEMORY_DIR    — memory.projects.<project_key>.dir for the requested
#                          project (absolute path), or ""
#   PM_CFG_MEMORY_DIR_INVALID — 1 when the matched project entry is invalid, or
#                               when only unsafe legacy dispatch.memory_dir exists
#   PM_CFG_MEMORY_CONFIG_STATUS — none|matched|matched-invalid|legacy-global
#   PM_CFG_LEGACY_MEMORY_DIR — deprecated machine-wide dispatch.memory_dir
#   PM_CFG_USAGE_LOG_PATH — dispatch.usage_log_path (absolute path to log-usage.sh), or ""
#
# Config file: ${PM_DISPATCH_CONFIG_FILE:-~/.pm-dispatch/config}
# Format: key = value lines; # comments; unknown keys silently ignored.

# shellcheck disable=SC2034  # globals consumed by callers (pmctl-dispatch.sh)
PM_CFG_TIMEOUT=""
PM_CFG_DEFAULT_MODEL=""
PM_CFG_AUTO_PACK=""
PM_CFG_LIFECYCLE=""
PM_CFG_MEMORY_DIR=""
PM_CFG_MEMORY_DIR_INVALID=0
PM_CFG_MEMORY_CONFIG_STATUS="none"
PM_CFG_LEGACY_MEMORY_DIR=""
PM_CFG_LEGACY_MEMORY_DIR_INVALID=0
PM_CFG_USAGE_LOG_PATH=""

# Resolve the same stable identity used by project state. Git worktrees share
# their primary checkout's key; non-git diagnostic fixtures fall back to a
# canonical-path hash instead of the unsafe state-store "global" partition.
pm_config_project_key() {
  local repo_root="$1" project_key=""
  if declare -F _sw_worktree_project_key >/dev/null 2>&1; then
    project_key="$(_SW_REPO_ROOT="$repo_root" _sw_worktree_project_key 2>/dev/null || true)"
  fi
  if [[ -z "$project_key" || "$project_key" == "global" ]] && declare -F _portable_sha1 >/dev/null 2>&1; then
    repo_root="$(cd "$repo_root" 2>/dev/null && pwd -P || printf '%s' "$repo_root")"
    project_key="$(printf '%s\n' "$repo_root" | _portable_sha1 2>/dev/null || true)"
  fi
  [[ "$project_key" =~ ^[0-9a-f]{40}$ ]] || return 1
  printf '%s\n' "$project_key"
}

pm_config_load() {
  local _memory_project_key="${1:-}"
  local _cfg_path="${PM_DISPATCH_CONFIG_FILE:-${HOME}/.pm-dispatch/config}"
  local _line_no=0 _line _key _value _memory_match_count=0

  PM_CFG_TIMEOUT=""
  PM_CFG_DEFAULT_MODEL=""
  PM_CFG_AUTO_PACK=""
  PM_CFG_LIFECYCLE=""
  PM_CFG_MEMORY_DIR=""
  PM_CFG_MEMORY_DIR_INVALID=0
  PM_CFG_MEMORY_CONFIG_STATUS="none"
  PM_CFG_LEGACY_MEMORY_DIR=""
  PM_CFG_LEGACY_MEMORY_DIR_INVALID=0
  PM_CFG_USAGE_LOG_PATH=""

  [[ -r "$_cfg_path" ]] || return 0

  while IFS= read -r _line || [[ -n "$_line" ]]; do
    ((_line_no += 1)) || true
    _line="${_line%$'\r'}"
    _line="${_line%%#*}"
    _line="${_line#"${_line%%[![:space:]]*}"}"
    _line="${_line%"${_line##*[![:space:]]}"}"
    [[ -z "$_line" ]] && continue
    if [[ "$_line" != *"="* ]]; then
      printf 'pm-dispatch: config: warning: malformed line in %s:%d\n' "$_cfg_path" "$_line_no" >&2
      continue
    fi
    _key="${_line%%=*}"; _value="${_line#*=}"
    _key="${_key#"${_key%%[![:space:]]*}"}"; _key="${_key%"${_key##*[![:space:]]}"}"
    _value="${_value#"${_value%%[![:space:]]*}"}"; _value="${_value%"${_value##*[![:space:]]}"}"
    case "$_key" in
      dispatch.default_timeout)
        if [[ "$_value" =~ ^[0-9]+$ ]]; then
          PM_CFG_TIMEOUT="$_value"
        else
          printf 'pm-dispatch: config: warning: malformed dispatch.default_timeout in %s:%d\n' "$_cfg_path" "$_line_no" >&2
        fi
        ;;
      dispatch.default_model)
        if [[ "$_value" =~ ^[a-z][a-z0-9.-]{0,30}$ ]]; then
          PM_CFG_DEFAULT_MODEL="$_value"
        else
          printf 'pm-dispatch: config: warning: malformed value for dispatch.default_model in %s:%d; ignoring\n' "$_cfg_path" "$_line_no" >&2
        fi
        ;;
      dispatch.auto_pack)
        if [[ "$_value" == "on" || "$_value" == "off" ]]; then
          PM_CFG_AUTO_PACK="$_value"
        else
          printf 'pm-dispatch: config: warning: malformed value for dispatch.auto_pack in %s:%d; ignoring\n' "$_cfg_path" "$_line_no" >&2
        fi
        ;;
      dispatch.lifecycle)
        if [[ "$_value" == "foreground" || "$_value" == "detached" ]]; then
          PM_CFG_LIFECYCLE="$_value"
        else
          printf 'pm-dispatch: config: warning: malformed value for dispatch.lifecycle in %s:%d; ignoring\n' "$_cfg_path" "$_line_no" >&2
        fi
        ;;
      dispatch.memory_dir)
        if [[ "$_value" == /* ]]; then
          PM_CFG_LEGACY_MEMORY_DIR="$_value"
        else
          PM_CFG_LEGACY_MEMORY_DIR_INVALID=1
        fi
        ;;
      memory.projects.*.dir)
        if [[ "$_key" =~ ^memory\.projects\.([0-9a-f]{40})\.dir$ ]]; then
          if [[ -n "$_memory_project_key" && "${BASH_REMATCH[1]}" == "$_memory_project_key" ]]; then
            _memory_match_count=$((_memory_match_count + 1))
            if [[ "$_memory_match_count" -gt 1 ]]; then
              PM_CFG_MEMORY_DIR=""
              PM_CFG_MEMORY_CONFIG_STATUS="matched-invalid"
              PM_CFG_MEMORY_DIR_INVALID=1
              printf 'pm-dispatch: config: warning: duplicate project memory key in %s:%d: %s\n' "$_cfg_path" "$_line_no" "$_key" >&2
            elif [[ "$_value" == /* ]]; then
              PM_CFG_MEMORY_DIR="$_value"
              PM_CFG_MEMORY_CONFIG_STATUS="matched"
              PM_CFG_MEMORY_DIR_INVALID=0
            else
              PM_CFG_MEMORY_DIR=""
              PM_CFG_MEMORY_CONFIG_STATUS="matched-invalid"
              PM_CFG_MEMORY_DIR_INVALID=1
              printf 'pm-dispatch: config: warning: malformed value for %s in %s:%d (must be absolute path)\n' "$_key" "$_cfg_path" "$_line_no" >&2
            fi
          fi
        elif [[ -n "$_memory_project_key" ]]; then
          printf 'pm-dispatch: config: warning: malformed project memory key in %s:%d: %s\n' "$_cfg_path" "$_line_no" "$_key" >&2
        fi
        ;;
      dispatch.usage_log_path)
        if [[ "$_value" == /* ]]; then
          PM_CFG_USAGE_LOG_PATH="$_value"
        else
          printf 'pm-dispatch: config: warning: malformed value for dispatch.usage_log_path in %s:%d (must be absolute path); ignoring\n' "$_cfg_path" "$_line_no" >&2
        fi
        ;;
    esac
  done < "$_cfg_path"

  if [[ -n "$_memory_project_key" && "$PM_CFG_MEMORY_CONFIG_STATUS" == "none" \
        && ( -n "$PM_CFG_LEGACY_MEMORY_DIR" || "$PM_CFG_LEGACY_MEMORY_DIR_INVALID" -eq 1 ) ]]; then
    PM_CFG_MEMORY_CONFIG_STATUS="legacy-global"
    PM_CFG_MEMORY_DIR_INVALID=1
    printf 'pm-dispatch: config: warning: unsafe global dispatch.memory_dir in %s is ignored; migrate it to memory.projects.%s.dir\n' \
      "$_cfg_path" "$_memory_project_key" >&2
  fi
}
