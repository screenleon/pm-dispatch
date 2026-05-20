#!/usr/bin/env bash
# Shared project-memory discovery helpers for installer/migrator paths.

# shellcheck source=scripts/lib/memory.sh
. "$(dirname "${BASH_SOURCE[0]}")/memory.sh"

# Installer/migrator callers support the routing log directory override.
# Hook callers source memory.sh directly and must NOT inherit this routing-specific
# behavior; they always use project memory from CLAUDE_CONFIG_DIR.
find_memory_dir() {
  local routing_dir="${CLAUDE_ROUTING_LOG_DIR:-}"
  if [[ -n "$routing_dir" && -d "$routing_dir" ]]; then
    printf '%s' "$routing_dir"; return 0
  fi
  local cwd="$1"
  local config_dir="${2:-${CLAUDE_CONFIG_DIR:-${HOME}/.claude}}"
  local projects_dir current candidate parent
  projects_dir="$config_dir/projects"
  current="${cwd%/}"
  while true; do
    candidate="$projects_dir/$(encode_path "$current")/memory"
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"; return 0
    fi
    parent="$(dirname "$current")"
    [[ "$parent" != "$current" ]] || return 1
    current="$parent"
  done
}
