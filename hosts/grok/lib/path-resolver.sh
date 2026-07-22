#!/usr/bin/env bash
# Resolve Grok-owned manifest path templates without leaking Grok-specific
# environment rules into the shared manifest reader.

grok_host_config_root() {
  local root="${GROK_HOME:-}"

  if [[ -z "$root" ]]; then
    if [[ -n "${HOME:-}" ]]; then
      root="$HOME/.grok"
    else
      printf 'grok path resolver: HOME is required when GROK_HOME is unset or empty\n' >&2
      return 2
    fi
  fi

  printf '%s\n' "$root"
}

grok_host_resolve_path() {
  local path="$1" root
  root="$(grok_host_config_root)" || return $?
  host_manifest_expand_root_template grok "\$GROK_HOME" "$root" "$path"
}
