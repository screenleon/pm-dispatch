#!/usr/bin/env bash
# Canonical reader and validator for core/policy/gate-assurance.yaml.

_GATE_ASSURANCE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_GATE_ASSURANCE_POLICY_FILE="${GATE_ASSURANCE_POLICY_FILE:-$_GATE_ASSURANCE_LIB_DIR/../../core/policy/gate-assurance.yaml}"
if [[ ! -r "$_GATE_ASSURANCE_POLICY_FILE" && -r "$_GATE_ASSURANCE_LIB_DIR/../core/policy/gate-assurance.yaml" ]]; then
  # Portable gate bundles place lib/ and core/ beside pr-gate.sh.
  _GATE_ASSURANCE_POLICY_FILE="$_GATE_ASSURANCE_LIB_DIR/../core/policy/gate-assurance.yaml"
fi

_gate_assurance_require_policy() {
  [[ -r "$_GATE_ASSURANCE_POLICY_FILE" ]] || {
    printf 'gate-assurance: policy source is unavailable: %s\n' "$_GATE_ASSURANCE_POLICY_FILE" >&2
    return 2
  }
}

# Read one scalar property from a named item in a top-level policy section.
_gate_assurance_property() {
  local section="$1" item="$2" property="$3"
  _gate_assurance_require_policy || return
  awk -v section="$section" -v item="$item" -v property="$property" '
    $0 == section ":" { in_section=1; next }
    in_section && /^[^ ]/ { exit }
    in_section && $0 == "  " item ":" { in_item=1; next }
    in_item && /^  [^ ]/ { exit }
    in_item && $0 ~ "^    " property ":" {
      sub("^    " property ":[[:space:]]*", "")
      gsub(/^\[|\]$/, ""); gsub(/,[[:space:]]*/, " ")
      print; exit
    }
  ' "$_GATE_ASSURANCE_POLICY_FILE"
}

gate_assurance_tier_rank() { _gate_assurance_property tiers "$1" rank; }
gate_assurance_default_reviewers() { _gate_assurance_property tiers "$1" default_reviewers; }
gate_assurance_mode_topology() { _gate_assurance_property modes "$1" session_topology; }
gate_assurance_mode_independence() { _gate_assurance_property modes "$1" per_reviewer_independent; }
gate_assurance_mode_evidence() { _gate_assurance_property modes "$1" session_evidence; }

gate_assurance_valid_tier() { [[ -n "$(gate_assurance_tier_rank "$1")" ]]; }
gate_assurance_valid_mode() { [[ -n "$(gate_assurance_mode_topology "$1")" ]]; }

export -f gate_assurance_tier_rank gate_assurance_default_reviewers \
  gate_assurance_mode_topology gate_assurance_mode_independence \
  gate_assurance_mode_evidence gate_assurance_valid_tier gate_assurance_valid_mode
