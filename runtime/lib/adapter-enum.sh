#!/usr/bin/env bash
# Shared adapter-name validation sourced by release and live-E2E entry points.

if ! declare -F pm_identifier_adapter_is_valid >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/identifier-policy.sh
  # shellcheck disable=SC1091
  . "$(dirname "${BASH_SOURCE[0]}")/identifier-policy.sh"
fi
if ! declare -F adapter_manifest_dispatch_path >/dev/null 2>&1 \
    || ! declare -F pm_identifier_adapter_is_valid >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/adapter-manifest.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/adapter-manifest.sh"
fi

pm_adapter_is_valid() { # pm_adapter_is_valid <repo-root> <adapter|auto>
  local repo_root="$1" adapter="$2"
  [[ "$adapter" == auto ]] && return 0
  adapter_manifest_dispatch_path "$repo_root" "$adapter" >/dev/null 2>&1
}

pm_adapter_expected_values() { # pm_adapter_expected_values <repo-root>
  local repo_root="$1" adapter
  printf 'auto'
  while IFS= read -r adapter; do
    [[ -n "$adapter" ]] && printf '|%s' "$adapter"
  done < <(adapter_manifest_names "$repo_root")
}
