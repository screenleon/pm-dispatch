#!/usr/bin/env bash
# Sourceable validation helpers for codex_dispatch_handover_v1 metadata.
# No shell options are set here; callers own their execution policy.

METADATA_REJECT_CHARS=${METADATA_REJECT_CHARS:-'single quote, double quote, backtick, dollar, semicolon, ampersand, pipe, redirect chars (< >), parens, braces, backslash, CR, LF, leading/trailing whitespace'}

handover_validate_metadata_value() {
  local field_name=${1-}
  local value=${2-}

  if [[ $# -ne 2 ]]; then
    printf 'reject %s: expected field_name and value\n' "${field_name:-<unknown>}" >&2
    return 1
  fi

  if [[ "$value" != "${value#"${value%%[![:space:]]*}"}" || "$value" != "${value%"${value##*[![:space:]]}"}" ]]; then
    printf 'reject %s: leading or trailing whitespace is not allowed\n' "$field_name" >&2
    return 1
  fi

  if [[ "$value" == *$'\r'* || "$value" == *$'\n'* ]]; then
    printf 'reject %s: control newline is not allowed\n' "$field_name" >&2
    return 1
  fi

  if [[ "$value" == *["'\"\`\$\;\&\|\<\>\(\)\{\}\\"]* ]]; then
    printf 'reject %s: shell metacharacter is not allowed\n' "$field_name" >&2
    return 1
  fi

  return 0
}

handover_safe_argv() {
  local field_name=${1-}
  local value=${2-}

  if ! handover_validate_metadata_value "$field_name" "$value"; then
    return 1
  fi

  printf '%q\n' "$value"
}

export METADATA_REJECT_CHARS
export -f handover_validate_metadata_value
export -f handover_safe_argv
