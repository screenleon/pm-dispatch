#!/usr/bin/env bash
# Source-safe Gate option coordinate helpers.

_gate_set_mode_requested() {
  local candidate="$1" spelling="$2"
  if [[ "$MODE_OPTION_SEEN" == false ]]; then
    MODE_REQUESTED="$candidate"
    MODE_OPTION_SEEN=true
    MODE_OPTION_SPELLING="$spelling"
    return 0
  fi
  if [[ "$MODE_REQUESTED" != "$candidate" ]]; then
    printf 'Error: conflicting gate mode options: %s requested %s, but %s requested %s\n' \
      "$MODE_OPTION_SPELLING" "$MODE_REQUESTED" "$spelling" "$candidate" >&2
    return 2
  fi
  return 0
}
_gate_set_pass_requested() {
  local candidate="$1" spelling="$2" syntax_source="$3"
  if [[ "$PASS_OPTION_SEEN" == false ]]; then
    PASS_KIND_REQUESTED="$candidate"
    PASS_OPTION_SEEN=true
    PASS_OPTION_SPELLING="$spelling"
    PASS_SYNTAX_SOURCE="$syntax_source"
    return 0
  fi
  if [[ "$PASS_KIND_REQUESTED" != "$candidate" ]]; then
    printf 'Error: conflicting gate pass options: %s requested %s, but %s requested %s\n' \
      "$PASS_OPTION_SPELLING" "$PASS_KIND_REQUESTED" "$spelling" "$candidate" >&2
    return 2
  fi
  if [[ "$PASS_OPTION_SPELLING" != "$spelling" ]]; then
    # shellcheck disable=SC2034  # Consumed by the entrypoint after parsing.
    PASS_SYNTAX_SOURCE="mixed"
  fi
  return 0
}
