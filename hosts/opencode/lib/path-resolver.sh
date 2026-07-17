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
  host_manifest_expand_root_template opencode "\$XDG_CONFIG_HOME" "$root" "$path"
}
