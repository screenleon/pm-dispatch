#!/usr/bin/env bash
# Resolve OpenCode-owned manifest path templates without leaking XDG-specific
# environment rules into the shared manifest reader.

opencode_host_config_root() {
  local root="${XDG_CONFIG_HOME:-}"

  if [[ -z "$root" ]]; then
    if [[ -n "${HOME:-}" ]]; then
      root="$HOME/.config"
    else
      printf 'opencode path resolver: HOME is required when XDG_CONFIG_HOME is unset or empty\n' >&2
      return 2
    fi
  fi

  printf '%s\n' "$root"
}

opencode_host_resolve_path() {
  local path="$1" root
  root="$(opencode_host_config_root)" || return $?
  case "$path" in
    \$XDG_CONFIG_HOME|\$XDG_CONFIG_HOME/*)
      printf '%s\n' "${path//\$XDG_CONFIG_HOME/$root}"
      ;;
    *)
      printf 'opencode path resolver: unsupported manifest path template: %s\n' "$path" >&2
      return 2
      ;;
  esac
}
