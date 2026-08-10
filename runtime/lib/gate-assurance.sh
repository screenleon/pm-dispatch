#!/usr/bin/env bash
# Canonical reader and validator for core/policy/gate-assurance.yaml.

_GATE_ASSURANCE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_GATE_ASSURANCE_POLICY_FILE="${GATE_ASSURANCE_POLICY_FILE:-$_GATE_ASSURANCE_LIB_DIR/../../core/policy/gate-assurance.yaml}"
if [[ ! -r "$_GATE_ASSURANCE_POLICY_FILE" && -r "$_GATE_ASSURANCE_LIB_DIR/../core/policy/gate-assurance.yaml" ]]; then
  # Portable gate bundles place lib/ and core/ beside pr-gate.sh.
  _GATE_ASSURANCE_POLICY_FILE="$_GATE_ASSURANCE_LIB_DIR/../core/policy/gate-assurance.yaml"
fi

# Full tier is a security boundary.  The editable policy may describe smaller
# tiers, but it cannot reduce this compiled mandatory reviewer set.  This makes
# a policy-only candidate change fail closed instead of silently removing the
# security reviewer from a purported full gate.
_GATE_ASSURANCE_MANDATORY_FULL_REVIEWERS='critic qa-tester architecture-reviewer security-reviewer risk-reviewer'

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
      print; found=1; exit
    }
    END { if (!found) exit 1 }
  ' "$_GATE_ASSURANCE_POLICY_FILE"
}

_gate_assurance_items() {
  local section="$1"
  _gate_assurance_require_policy || return
  awk -v section="$section" '
    $0 == section ":" { in_section=1; found=1; next }
    in_section && /^[^ ]/ { exit }
    in_section && /^  [a-z][a-z-]*:$/ { value=$0; sub(/^  /,"",value); sub(/:$/,"",value); print value }
    END { if (!found) exit 1 }
  ' "$_GATE_ASSURANCE_POLICY_FILE"
}

gate_assurance_tier_rank() { _gate_assurance_property tiers "$1" rank; }
gate_assurance_default_reviewers() { _gate_assurance_property tiers "$1" default_reviewers; }
gate_assurance_mandatory_full_reviewers() { printf '%s\n' "$_GATE_ASSURANCE_MANDATORY_FULL_REVIEWERS"; }
gate_assurance_mode_topology() { _gate_assurance_property modes "$1" session_topology; }
gate_assurance_mode_independence() { _gate_assurance_property modes "$1" per_reviewer_independent; }
gate_assurance_mode_evidence() { _gate_assurance_property modes "$1" session_evidence; }

gate_assurance_valid_tier() { [[ -n "$(gate_assurance_tier_rank "$1")" ]]; }
gate_assurance_valid_mode() { [[ -n "$(gate_assurance_mode_topology "$1")" ]]; }

# Fail loudly when the deliberately small policy shape drifts. This is not a
# general YAML parser: it is a strict reader for this contract, and accepting a
# partially parsed policy would be less safe than rejecting formatting changes.
gate_assurance_validate_policy() {
  local tiers modes tier mode rank reviewers topology independent evidence reviewer mandatory_full
  tiers="$(_gate_assurance_items tiers)" || return 2
  modes="$(_gate_assurance_items modes)" || return 2
  [[ "$tiers" == $'express\nstandard\nfull\ntargeted' ]] || {
    printf 'gate-assurance: tier set/order must be express, standard, full, targeted\n' >&2; return 2;
  }
  [[ "$modes" == $'sequential\nparallel' ]] || {
    printf 'gate-assurance: mode set/order must be sequential, parallel\n' >&2; return 2;
  }
  for tier in $tiers; do
    rank="$(gate_assurance_tier_rank "$tier")" || return 2
    reviewers="$(gate_assurance_default_reviewers "$tier")" || return 2
    [[ "$rank" =~ ^[0-9]+$ ]] || { printf 'gate-assurance: invalid rank for %s\n' "$tier" >&2; return 2; }
    for reviewer in $reviewers; do
      [[ "$reviewer" =~ ^[a-z][a-z-]*$ ]] || {
        printf 'gate-assurance: invalid reviewer token for %s: %s\n' "$tier" "$reviewer" >&2; return 2;
      }
    done
    [[ "$tier" == targeted || -n "$reviewers" ]] || {
      printf 'gate-assurance: default reviewer set is empty for %s\n' "$tier" >&2; return 2;
    }
  done
  mandatory_full="$(gate_assurance_mandatory_full_reviewers)"
  reviewers="$(gate_assurance_default_reviewers full)" || return 2
  [[ "$reviewers" == "$mandatory_full" ]] || {
    printf 'gate-assurance: full reviewer set must match mandatory trusted coverage\n' >&2
    return 2
  }
  for mode in $modes; do
    topology="$(gate_assurance_mode_topology "$mode")" || return 2
    independent="$(gate_assurance_mode_independence "$mode")" || return 2
    evidence="$(gate_assurance_mode_evidence "$mode")" || return 2
    [[ "$topology" =~ ^[a-z][a-z-]*$ && "$independent" =~ ^(true|false)$ \
      && "$evidence" =~ ^[a-z][a-z-]*$ ]] || {
      printf 'gate-assurance: invalid mode contract for %s\n' "$mode" >&2; return 2;
    }
  done
}

export -f gate_assurance_tier_rank gate_assurance_default_reviewers \
  gate_assurance_mandatory_full_reviewers \
  gate_assurance_mode_topology gate_assurance_mode_independence \
  gate_assurance_mode_evidence gate_assurance_valid_tier gate_assurance_valid_mode \
  gate_assurance_validate_policy
