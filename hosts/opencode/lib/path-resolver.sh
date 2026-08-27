#!/usr/bin/env bash
# Resolve OpenCode-owned manifest path templates without leaking XDG-specific
# environment rules into the shared manifest reader.

opencode_host_config_root() {
  host_simple_config_root opencode XDG_CONFIG_HOME .config
}

opencode_host_resolve_path() {
  local path="$1" root
  root="$(opencode_host_config_root)" || return $?
  host_manifest_expand_root_template opencode "\$XDG_CONFIG_HOME" "$root" "$path"
}
