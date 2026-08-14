#!/usr/bin/env bash
# Source-safe reviewer artifact contract helpers.

# verify_reviewer_artifact_hashes <hash_cmd> <name> <path> <baseline> [...]
# Print every reviewer whose artifact differs from its captured baseline.
verify_reviewer_artifact_hashes() {
  local hash_cmd="$1" name path baseline current
  shift
  while [[ $# -ge 3 ]]; do
    name="$1" path="$2" baseline="$3"; shift 3
    [[ "$baseline" == "none" ]] && continue
    current="$(cat "$path" 2>/dev/null | $hash_cmd || echo 'missing')"
    [[ "$current" != "$baseline" ]] && printf '%s\n' "$name"
  done
}

_gate_reviewer_protocol_append_blocks() {
  local destination="$1" artifact reviewer verdict
  shift
  if grep -q '^```reviewer_result_v1$' "$destination"; then
    printf 'Error: reviewer protocol INCOMPLETE: synthesis emitted machine-owned reviewer blocks\n' >&2
    return 1
  fi
  {
    printf '\n## Reviewer Protocol Evidence\n'
    printf 'Validated selected-reviewer reports are preserved verbatim below.\n\n'
    for artifact in "$@"; do
      reviewer="$(
        _gate_reviewer_protocol_documents "$artifact" |
          jq -sr '.[0].reviewer // empty'
      )" || return 1
      verdict="$(
        _gate_reviewer_protocol_verdict_extract "$artifact" "$reviewer"
      )" || return 1
      printf '## %s -- %s\n' "$reviewer" "$verdict"
      # shellcheck disable=SC2016 # Literal Markdown fence delimiters.
      sed -n '/^```reviewer_result_v1$/,/^```$/p' "$artifact"
      printf '\n'
    done
  } >> "$destination"
}
