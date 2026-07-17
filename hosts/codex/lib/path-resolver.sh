#!/usr/bin/env bash
# Resolve Codex-owned manifest path templates without leaking Codex-specific
# environment rules into the shared manifest reader.

codex_host_config_root() {
  local root="${CODEX_HOME:-}"

  if [[ -z "$root" ]]; then
    if [[ -n "${HOME:-}" ]]; then
      root="$HOME/.codex"
    else
      printf 'codex path resolver: HOME is required when CODEX_HOME is unset or empty\n' >&2
      return 2
    fi
  fi

  printf '%s\n' "$root"
}

codex_host_resolve_path() {
  local path="$1" root
  root="$(codex_host_config_root)" || return $?
  host_manifest_expand_root_template codex "\$CODEX_HOME" "$root" "$path"
}
