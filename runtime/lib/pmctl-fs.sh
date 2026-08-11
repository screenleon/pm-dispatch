#!/usr/bin/env bash
# Sourceable filesystem helpers for pmctl.

if ! declare -F pm_identifier_adapter_is_valid >/dev/null 2>&1; then
  _pmctl_fs_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=runtime/lib/identifier-policy.sh
  # shellcheck disable=SC1091
  . "$_pmctl_fs_lib_dir/identifier-policy.sh"
  unset _pmctl_fs_lib_dir
fi

pmctl_validate_adapter_name() {
  local name="${1:-}"

  pm_identifier_adapter_is_valid "$name" || {
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
