#!/usr/bin/env bash
# Sourceable policy enum helpers for pmctl.
#
# pmctl-policy.sh - list-only YAML reader for core/policy/*.yaml files.
# Reads files with a top-level 'values:' list (one value per "  - <value>" line).
# This is NOT a general YAML parser; it will silently misread nested mappings,
# inline sequences, or multi-line scalars. Keep policy files as flat value lists.

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
