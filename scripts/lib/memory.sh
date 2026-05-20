#!/usr/bin/env bash
# memory.sh - shared helpers for locating project memory directory.
# Source this file; do not execute directly.
# Requires: CLAUDE_CONFIG_DIR env var or ~/.claude default.

encode_path() {
  local p="$1"
  printf '%s' "-${p#/}" | tr '/' '-'
}

find_memory_dir() {
  local cwd="$1"
  local config_dir="${2:-${CLAUDE_CONFIG_DIR:-${HOME}/.claude}}"
  local projects_dir current candidate parent
  projects_dir="$config_dir/projects"
  current="${cwd%/}"
  while true; do
    candidate="$projects_dir/$(encode_path "$current")/memory"
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
    parent="$(dirname "$current")"
    [[ "$parent" != "$current" ]] || return 1
    current="$parent"
  done
}
