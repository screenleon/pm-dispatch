#!/usr/bin/env bash
# Shared host-name policy for host-neutral pmctl surfaces.

if ! declare -F pm_identifier_host_is_valid >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/identifier-policy.sh
  # shellcheck disable=SC1091
  . "$(dirname "${BASH_SOURCE[0]}")/identifier-policy.sh"
fi

pmctl_host_is_valid() { pm_identifier_host_is_valid "$@"; }
