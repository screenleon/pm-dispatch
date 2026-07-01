#!/usr/bin/env bash
# Shared project-memory discovery helpers for installer/migrator paths.

# shellcheck source=scripts/lib/memory.sh
. "$(dirname "${BASH_SOURCE[0]}")/memory.sh"

# Installer/migrator/doctor callers are not on the hook latency path, so they
# additionally honor ~/.pm-dispatch/config `dispatch.memory_dir` (load it if
# no caller already has).
if ! declare -F pm_config_load >/dev/null 2>&1; then
  # shellcheck source=scripts/lib/pmctl-config.sh
  # shellcheck disable=SC1091
  . "$(dirname "${BASH_SOURCE[0]}")/pmctl-config.sh" 2>/dev/null || true
fi

# Installer/migrator callers support the routing log directory override.
# Hook callers source memory.sh directly and must NOT inherit this routing-specific
# behavior; they always use project memory from CLAUDE_CONFIG_DIR.
find_memory_dir() {
  declare -F pm_config_load >/dev/null 2>&1 && [[ -z "${PM_CFG_MEMORY_DIR:-}" ]] && pm_config_load
  local override
  if override="$(_pm_memory_dir_override)"; then
    printf '%s' "$override"; return 0
  fi
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
