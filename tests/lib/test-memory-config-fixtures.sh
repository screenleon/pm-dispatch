#!/usr/bin/env bash
# Shared project-scoped memory-config fixture helpers.
# Source from tests after their temporary root is initialized.

memory_fixture_project_key() {
  local repo="$1" root common_dir
  common_dir="$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null || true)"
  if [[ "$common_dir" == /* ]]; then
    # Linked worktrees share the primary checkout's project identity.
    root="$(dirname "$common_dir")"
  else
    root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || (cd "$repo" && pwd -P))"
  fi
  root="$(cd "$root" 2>/dev/null && pwd -P || printf '%s' "$root")"
  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s\n' "$root" | sha1sum | awk '{print $1}'
  else
    printf '%s\n' "$root" | shasum -a 1 | awk '{print $1}'
  fi
}

write_project_memory_config() {
  local config="$1" repo="$2" memory_dir="$3"
  printf 'memory.projects.%s.dir = %s\n' "$(memory_fixture_project_key "$repo")" "$memory_dir" > "$config"
}
