#!/usr/bin/env bash
# Shared project-scoped memory-config fixture helpers.
# Source from tests after their temporary root is initialized.

memory_fixture_project_key() {
  local repo="$1" root main_worktree
  root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || (cd "$repo" && pwd -P))"
  # Match pm_config_project_key(): linked worktrees intentionally share their
  # primary checkout's memory partition, so a fixture must not key on the
  # transient linked-worktree path.
  main_worktree="$(git -C "$repo" worktree list --porcelain 2>/dev/null | awk '/^worktree / { sub(/^worktree /, ""); print; exit }')"
  [[ -z "$main_worktree" ]] || root="$(cd "$main_worktree" && pwd -P)"
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
