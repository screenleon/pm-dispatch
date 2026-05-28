#!/usr/bin/env bash
# Sourceable policy enum helpers for pmctl.

pmctl_policy_values() {
  local file="${1:-}"

  [[ -n "$file" ]] || {
    printf 'pmctl: pmctl_policy_values requires <file>\n' >&2
    return 2
  }

  awk '$1 == "-" { value = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); if (value != "") print value }' "$file"
}

pmctl_policy_contains() {
  local file="${1:-}" value="${2:-}"

  [[ $# -eq 2 ]] || {
    printf 'pmctl: pmctl_policy_contains requires <file> <value>\n' >&2
    return 2
  }

  pmctl_policy_values "$file" | grep -Fx -- "$value" >/dev/null
}

export -f pmctl_policy_values
export -f pmctl_policy_contains
