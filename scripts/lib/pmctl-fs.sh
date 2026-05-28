#!/usr/bin/env bash
# Sourceable filesystem helpers for pmctl.

pmctl_validate_adapter_name() {
  local name="${1:-}"

  [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || {
    printf 'pmctl: invalid adapter name: %s\n' "$name" >&2
    return 1
  }
}

pmctl_write_new_file() {
  local path="${1:-}" mode="${2:-0644}"

  [[ -n "$path" ]] || {
    printf 'pmctl: pmctl_write_new_file requires <path> [mode]\n' >&2
    return 2
  }

  [[ -e "$path" ]] && {
    printf 'pmctl: refusing to overwrite: %s\n' "$path" >&2
    return 1
  }

  umask 022
  cat >"$path"
  chmod "$mode" "$path"
}

export -f pmctl_validate_adapter_name
export -f pmctl_write_new_file
