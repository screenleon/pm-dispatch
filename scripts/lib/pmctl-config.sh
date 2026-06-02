#!/usr/bin/env bash
# Shared ~/.pm-dispatch/config reader for dispatch adapters.
#
# Call pm_config_load once in the main shell (NOT a subshell) before reading
# the two output globals:
#   PM_CFG_TIMEOUT       — dispatch.default_timeout (integer string), or ""
#   PM_CFG_DEFAULT_MODEL — dispatch.default_model (alias/id), or ""
#
# Config file: ${PM_DISPATCH_CONFIG_FILE:-~/.pm-dispatch/config}
# Format: key = value lines; # comments; unknown keys silently ignored.

PM_CFG_TIMEOUT=""
PM_CFG_DEFAULT_MODEL=""

pm_config_load() {
  local _cfg_path="${PM_DISPATCH_CONFIG_FILE:-${HOME}/.pm-dispatch/config}"
  local _line_no=0 _line _key _value

  PM_CFG_TIMEOUT=""
  PM_CFG_DEFAULT_MODEL=""

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
    esac
  done < "$_cfg_path"
}
