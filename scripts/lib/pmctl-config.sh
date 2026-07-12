#!/usr/bin/env bash
# Shared ~/.pm-dispatch/config reader for dispatch adapters.
#
# Call pm_config_load once in the main shell (NOT a subshell) before reading
# the output globals:
#   PM_CFG_TIMEOUT       — dispatch.default_timeout (integer string), or ""
#   PM_CFG_DEFAULT_MODEL — dispatch.default_model (alias/id), or ""
#   PM_CFG_AUTO_PACK     — dispatch.auto_pack (on|off), or ""
#   PM_CFG_LIFECYCLE     — dispatch.lifecycle (foreground|detached), or ""
#   PM_CFG_MEMORY_DIR    — dispatch.memory_dir (absolute path), or ""
#   PM_CFG_MEMORY_DIR_INVALID — 1 when dispatch.memory_dir was present but invalid
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
PM_CFG_USAGE_LOG_PATH=""

pm_config_load() {
  local _cfg_path="${PM_DISPATCH_CONFIG_FILE:-${HOME}/.pm-dispatch/config}"
  local _line_no=0 _line _key _value

  PM_CFG_TIMEOUT=""
  PM_CFG_DEFAULT_MODEL=""
  PM_CFG_AUTO_PACK=""
  PM_CFG_LIFECYCLE=""
  PM_CFG_MEMORY_DIR=""
  PM_CFG_MEMORY_DIR_INVALID=0
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
          PM_CFG_MEMORY_DIR="$_value"
        else
          PM_CFG_MEMORY_DIR_INVALID=1
          printf 'pm-dispatch: config: warning: malformed value for dispatch.memory_dir in %s:%d (must be absolute path); ignoring\n' "$_cfg_path" "$_line_no" >&2
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
}
