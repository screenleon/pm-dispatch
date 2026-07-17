#!/usr/bin/env bash
# Shared repository-layout resolution. User repositories may live anywhere;
# the pm-dispatch checkout only provides a useful sibling-directory default.

pm_dispatch_repos_root() {
  local repo_root="${1:-}"

  if [[ -n "${PM_DISPATCH_REPOS_ROOT:-}" ]]; then
    printf '%s\n' "$PM_DISPATCH_REPOS_ROOT"
    return 0
  fi

  if [[ -n "${PM_DISPATCH_REPO:-}" ]]; then
    dirname "$PM_DISPATCH_REPO"
    return 0
  fi

  if [[ -n "$repo_root" ]]; then
    dirname "$repo_root"
    return 0
  fi

  printf 'pm-dispatch: cannot resolve repositories root; set PM_DISPATCH_REPOS_ROOT\n' >&2
  return 2
}
