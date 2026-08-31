#!/usr/bin/env bash
# Generic JSON Schema structural validation for Gate artifacts.
#
# This module contains no Gate field names, enums, or shapes. Those are loaded
# from the generated bundle, which is built from core/schema/gate-*.schema.json.

_gate_structural_verify_dir="${BASH_SOURCE[0]%/*}"
_gate_structural_verify_filter="$_gate_structural_verify_dir/gate-structural-validator.jq"
_gate_structural_verify_bundle="$_gate_structural_verify_dir/gate-structural-schemas.json"

# Computes the raw {path, message, value} issue array on stdout. Private:
# both gate_structural_schema_verify (prints every issue) and
# gate_structural_schema_first_error (formats just the first, for a
# handwritten verifier's single-line diagnostic) share this so the schema
# bundle is only ever read/interpreted through one code path.
_gate_structural_schema_errors() {
  local schema_name="${1-}" instance_file="${2-}"
  [[ -r "$_gate_structural_verify_filter" && -r "$_gate_structural_verify_bundle" ]] || {
    printf 'gate-structural-verify: generated validator assets are unavailable\n' >&2
    return 2
  }
  # The validator reports an unknown schema itself (exit 9), so this used to
  # be two jq processes -- a `has($name)` probe and then the pass that already
  # receives $name -- for one question. Schema validation runs about thirty
  # times per gate, so the probe alone was roughly 8% of the gate's jq
  # start-up cost (CC-579).
  local issues rc=0
  issues="$(jq -n -r \
    --arg name "$schema_name" \
    --slurpfile schemas "$_gate_structural_verify_bundle" \
    --slurpfile instance "$instance_file" \
    -f "$_gate_structural_verify_filter")" || rc=$?
  # Deliberately not branching on the status. The validator exits 9 for an
  # unknown schema and jq exits with its own codes for anything else, but both
  # are execution failures with the same obligation: say nothing on stdout, so
  # no caller can read a validation verdict out of a run that never judged the
  # instance. The 9 is a distinct, greppable value for a human reading stderr,
  # not a value this code depends on.
  [[ "$rc" -eq 0 ]] || return 2
  printf '%s\n' "$issues"
}

gate_structural_schema_verify() {
  local schema_name="${1-}" instance_file="${2-}" label="${3:-${1-}}"
  local errors
  [[ $# -ge 2 && $# -le 3 && -n "$schema_name" && -s "$instance_file" ]] || {
    printf 'gate-structural-verify: expected <schema-name> <instance-file> [label]\n' >&2
    return 2
  }
  errors="$(_gate_structural_schema_errors "$schema_name" "$instance_file")" || {
    printf 'Error: %s structural validation could not execute\n' "$label" >&2
    return 1
  }
  if [[ "$errors" != '[]' ]]; then
    printf 'Error: %s failed schema-derived structural validation\n' "$label" >&2
    jq -r '.[] | "  \(.path): \(.message)"' <<<"$errors" >&2
    return 1
  fi
}

# gate_structural_schema_first_error <schema-name> <instance-file>
#
# Prints a single-line "<path>: <message> (got: <value>)" diagnostic for the
# FIRST schema violation found, or nothing (exit 1, no stdout) when the
# instance is structurally valid. This is the single-authority replacement
# for a handwritten verifier's own "X is not one of A/B/C" style messages:
# call this before running any semantic-only (non-schema-representable)
# checks, and use its output as the diagnostic when it fails, instead of
# hand-rolling an equivalent shape check. Returns 0 when valid (no error to
# report), 1 when an error was found and printed, 2 on execution failure.
gate_structural_schema_first_error() {
  local schema_name="${1-}" instance_file="${2-}"
  local errors first
  [[ $# -eq 2 && -n "$schema_name" && -s "$instance_file" ]] || {
    printf 'gate-structural-verify: expected <schema-name> <instance-file>\n' >&2
    return 2
  }
  errors="$(_gate_structural_schema_errors "$schema_name" "$instance_file")" || return 2
  [[ "$errors" != '[]' ]] || return 0
  first="$(jq -r '.[0] |
    "\(.path): \(.message)" +
    (if .value == null then "" else " (got: " + (.value | tojson) + ")" end)
  ' <<<"$errors")" || return 2
  printf '%s\n' "$first"
  return 1
}

gate_structural_schema_verify_json() {
  local schema_name="${1-}" json_value="${2-}" label="${3:-${1-}}"
  local instance_file rc
  [[ $# -ge 2 && $# -le 3 && -n "$schema_name" && -n "$json_value" ]] || {
    printf 'gate-structural-verify: expected <schema-name> <json> [label]\n' >&2
    return 2
  }
  instance_file="$(mktemp "${TMPDIR:-/tmp}/gate-structural-instance.XXXXXX")" || return 2
  printf '%s\n' "$json_value" > "$instance_file"
  gate_structural_schema_verify "$schema_name" "$instance_file" "$label"
  rc=$?
  rm -f -- "$instance_file"
  return "$rc"
}
