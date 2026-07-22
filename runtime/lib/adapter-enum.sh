#!/usr/bin/env bash
# Shared adapter-name validation sourced by release and live-E2E entry points.

pm_adapter_is_valid() { # pm_adapter_is_valid <repo-root> <adapter|auto>
  local repo_root="$1" adapter="$2"
  [[ "$adapter" == auto ]] && return 0
  [[ "$adapter" =~ ^[a-z0-9][a-z0-9-]*$ ]] || return 1
  [[ -f "$repo_root/adapters/$adapter/adapter.yaml" && ! -L "$repo_root/adapters/$adapter/adapter.yaml" ]]
}

pm_adapter_expected_values() { # pm_adapter_expected_values <repo-root>
  local repo_root="$1" manifest
  printf 'auto'
  for manifest in "$repo_root"/adapters/*/adapter.yaml; do
    [[ -f "$manifest" && ! -L "$manifest" ]] || continue
    printf '|%s' "$(basename "$(dirname "$manifest")")"
  done
}
