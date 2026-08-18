#!/usr/bin/env bash
# Generic JSON Schema structural validation for Gate artifacts.
#
# This module contains no Gate field names, enums, or shapes. Those are loaded
# from the generated bundle, which is built from core/schema/gate-*.schema.json.

_gate_structural_verify_dir="${BASH_SOURCE[0]%/*}"
_gate_structural_verify_filter="$_gate_structural_verify_dir/gate-structural-validator.jq"
_gate_structural_verify_bundle="$_gate_structural_verify_dir/gate-structural-schemas.json"

gate_structural_schema_verify() {
  local schema_name="${1-}" instance_file="${2-}" label="${3:-${1-}}"
  local errors
  [[ $# -ge 2 && $# -le 3 && -n "$schema_name" && -s "$instance_file" ]] || {
    printf 'gate-structural-verify: expected <schema-name> <instance-file> [label]\n' >&2
    return 2
  }
  [[ -r "$_gate_structural_verify_filter" && -r "$_gate_structural_verify_bundle" ]] || {
    printf 'gate-structural-verify: generated validator assets are unavailable\n' >&2
    return 2
  }
  jq -e --arg name "$schema_name" 'has($name)' \
    "$_gate_structural_verify_bundle" >/dev/null || {
    printf 'gate-structural-verify: unknown schema: %s\n' "$schema_name" >&2
    return 2
  }
  errors="$(jq -n -r \
    --arg name "$schema_name" \
    --slurpfile schemas "$_gate_structural_verify_bundle" \
    --slurpfile instance "$instance_file" \
    -f "$_gate_structural_verify_filter")" || {
    printf 'Error: %s structural validation could not execute\n' "$label" >&2
    return 1
  }
  if [[ "$errors" != '[]' ]]; then
    printf 'Error: %s failed schema-derived structural validation\n' "$label" >&2
    jq -r '.[] | "  \(.path): \(.message)"' <<<"$errors" >&2
    return 1
  fi
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
