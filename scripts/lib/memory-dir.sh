#!/usr/bin/env bash
# Shared project-memory discovery helpers for installer/migrator paths.

encode_path() {
  local cwd="$1" enc
  enc="-${cwd#/}"
  printf '%s' "${enc//\//-}"
}

find_memory_dir() {
  local cwd="$1" config_dir projects_dir current candidate parent

  if [[ -n "${CLAUDE_ROUTING_LOG_DIR:-}" ]]; then
    [[ -d "$CLAUDE_ROUTING_LOG_DIR" ]] && { printf '%s' "$CLAUDE_ROUTING_LOG_DIR"; return 0; }
  fi

  config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  projects_dir="$config_dir/projects"
  current="${cwd%/}"

  while [[ -n "$current" ]]; do
    candidate="$projects_dir/$(encode_path "$current")/memory"
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
    parent="$(dirname "$current")"
    [[ "$parent" == "$current" ]] && break
    current="$parent"
  done

  return 1
}
