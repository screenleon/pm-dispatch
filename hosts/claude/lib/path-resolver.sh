#!/usr/bin/env bash
# Resolve Claude-owned manifest path templates without leaking Claude-specific
# environment rules into the shared manifest reader.

claude_host_config_root() {
  local canonical="${CLAUDE_CONFIG_DIR:-}"
  local legacy="${CLAUDE_HOME:-}"
  local root

  if [[ -n "$canonical" && -n "$legacy" && "$canonical" != "$legacy" ]]; then
    printf 'claude path resolver: CLAUDE_CONFIG_DIR and legacy CLAUDE_HOME disagree\n' >&2
    return 2
  fi
  if [[ -n "$canonical" ]]; then
    root="$canonical"
  elif [[ -n "$legacy" ]]; then
    root="$legacy"
  elif [[ -n "${HOME:-}" ]]; then
    root="$HOME/.claude"
  else
    printf 'claude path resolver: HOME is required when CLAUDE_CONFIG_DIR and CLAUDE_HOME are unset or empty\n' >&2
    return 2
  fi

  printf '%s\n' "$root"
}

claude_host_resolve_path() {
  local path="$1" root
  root="$(claude_host_config_root)" || return $?
  host_manifest_expand_root_template claude "\$CLAUDE_CONFIG_DIR" "$root" "$path"
}
