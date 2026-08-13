#!/usr/bin/env bash
# Canonical identifier grammar for runtime domains.
#
# This is deliberately source-safe: it defines functions only.  A domain may
# have a different grammar, but all production boundaries for that domain must
# call the corresponding validator instead of embedding a regex.

pm_identifier_adapter_is_valid() {
  [[ "${1:-}" =~ ^[a-z][a-z0-9_-]*$ ]]
}

pm_identifier_host_is_valid() {
  case "${1:-}" in
    claude|codex|opencode|grok|generic) return 0 ;;
    *) return 1 ;;
  esac
}

pm_identifier_run_is_valid() {
  [[ "${1:-}" =~ $(pm_identifier_run_ere_pattern) ]]
}

# Shell and jq consumers use the exact same ERE. Keeping the expression behind
# a function avoids source-time mutable globals while allowing generated
# copy-mode verifier code to derive its structural predicate from this policy.
pm_identifier_run_ere_pattern() {
  printf '%s\n' '^run-[A-Za-z0-9]+-[A-Za-z0-9]+$'
}

pm_identifier_operation_is_valid() {
  [[ "${1:-}" =~ ^op-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$ ]]
}

pm_identifier_gate_is_valid() {
  [[ "${1:-}" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]
}

# Shared artifact storage has a distinct, compatibility-preserving domain:
# producer boundaries validate strict `run-*`/`gate-*` grammars, while this
# resolver also hosts legacy fixture artifact leaves. Keep its safe leaf rule
# centralized rather than duplicating a path predicate in state-paths.sh.
pm_identifier_artifact_leaf_is_valid() {
  local value="${1:-}"
  [[ -n "$value" && "$value" != */* && "$value" != *..* ]]
}
