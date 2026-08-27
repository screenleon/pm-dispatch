#!/usr/bin/env bash
# Resolve Grok-owned manifest path templates without leaking Grok-specific
# environment rules into the shared manifest reader.

grok_host_config_root() {
  host_simple_config_root grok GROK_HOME .grok
}

grok_host_resolve_path() {
  local path="$1" root
  root="$(grok_host_config_root)" || return $?
  host_manifest_expand_root_template grok "\$GROK_HOME" "$root" "$path"
}
