#!/usr/bin/env bash
# Sourceable policy enum helpers for pmctl.
#
# pmctl-policy.sh - list-only YAML reader for core/policy/*.yaml files.
# Reads a named top-level list (one value per "  - <value>" line).
# This is NOT a general YAML parser; it will silently misread nested mappings,
# inline sequences, or multi-line scalars. Keep policy files as flat value lists.

pmctl_policy_values() {
  local file="${1:-}" key="${2:-}"

  [[ -n "$file" ]] || {
    printf 'pmctl: pmctl_policy_values requires <file>\n' >&2
    return 2
  }

  [[ -r "$file" ]] || {
    printf 'pmctl: policy file is not readable: %s\n' "$file" >&2
    return 1
  }

  awk -v wanted="$key" '
    function clean(value) {
      sub(/[[:space:]]+#.*$/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    /^[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]*(#.*)?$/ {
      current=$0
      sub(/:.*/, "", current)
      if (wanted == "" && selected == "") selected=current
      active=(current == (wanted == "" ? selected : wanted))
      next
    }
    active && /^  -[[:space:]]+/ {
      value=$0
      sub(/^  -[[:space:]]+/, "", value)
      value=clean(value)
      if (value != "") print value
      next
    }
    active && /^[^[:space:]#]/ { active=0 }
  ' "$file" | tr -d '\r'
}

pmctl_policy_contains() {
  local file="${1:-}" value="${2:-}" key="${3:-}"

  [[ $# -ge 2 && $# -le 3 ]] || {
    printf 'pmctl: pmctl_policy_contains requires <file> <value> [key]\n' >&2
    return 2
  }

  pmctl_policy_values "$file" "$key" | grep -Fx -- "$value" >/dev/null
}

export -f pmctl_policy_values
export -f pmctl_policy_contains
