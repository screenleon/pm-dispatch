#!/usr/bin/env bash
# Shared timeout precedence resolver for adapter dispatch scripts.
# Provides tr_resolve_timeout — sets TR_RESOLVED_TIMEOUT.

# shellcheck disable=SC2034  # TR_RESOLVED_TIMEOUT is read by callers after sourcing this lib
TR_RESOLVED_TIMEOUT=""

# tr_resolve_timeout <flag_val> <env_var_name> <config_key> <default>
# Precedence: flag_val (non-empty wins) > env_var_name env var > config_key (PM_CFG_TIMEOUT)
#             > default.
# Pass config_key="" to skip the config layer (post-verify case).
# Sets TR_RESOLVED_TIMEOUT; no other side effects.
tr_resolve_timeout() {
  local flag_val="$1" env_var_name="$2" config_key="$3" default_val="$4"
  if [[ -n "$flag_val" ]]; then
    TR_RESOLVED_TIMEOUT="$flag_val"
    return 0
  fi
  local env_val="${!env_var_name:-}"
  if [[ -n "$env_val" ]]; then
    TR_RESOLVED_TIMEOUT="$env_val"
    return 0
  fi
  if [[ -n "$config_key" ]]; then
    local cfg_val="${!config_key:-}"
    if [[ -n "$cfg_val" ]]; then
      TR_RESOLVED_TIMEOUT="$cfg_val"
      return 0
    fi
  fi
  TR_RESOLVED_TIMEOUT="$default_val"
}
