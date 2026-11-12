#!/usr/bin/env bash
# Shared project-scoped memory-config fixture helpers.
# Source from tests after their temporary root is initialized.

memory_fixture_project_key() {
  local repo="$1" root common_dir in_git=0
  common_dir="$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null || true)"
  if [[ "$common_dir" == /* || "$common_dir" =~ ^[A-Za-z]:[/\\] ]]; then
    # Linked worktrees share the primary checkout's project identity.
    root="$(dirname "$common_dir")"
    in_git=1
  elif root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$root" ]]; then
    in_git=1
  else
    root="$(cd "$repo" && pwd -P)"
  fi
  root="$(cd "$root" 2>/dev/null && pwd -P || printf '%s' "$root")"
  # Inside a repository the product hashes one canonical spelling on native Windows: the drive-letter path with a
  # lower-case drive (c:/Users/...). A directory outside any repository is hashed as the shell spells it (/c/Users/...).
  if [[ "$in_git" -eq 1 && ( "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ) ]]; then
    root="$(cygpath -ml "$root")"
    root="$(printf '%s' "${root:0:1}" | tr '[:upper:]' '[:lower:]')${root:1}"
  fi
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
