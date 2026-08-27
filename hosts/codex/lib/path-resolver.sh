#!/usr/bin/env bash
# Resolve Codex-owned manifest path templates without leaking Codex-specific
# environment rules into the shared manifest reader.

codex_host_config_root() {
  host_simple_config_root codex CODEX_HOME .codex
}

codex_host_resolve_path() {
  local path="$1" root
  root="$(codex_host_config_root)" || return $?
  host_manifest_expand_root_template codex "\$CODEX_HOME" "$root" "$path"
}
