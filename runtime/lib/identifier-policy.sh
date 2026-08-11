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
  [[ "${1:-}" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]]
}

pm_identifier_operation_is_valid() {
  [[ "${1:-}" =~ ^op-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$ ]]
}

pm_identifier_gate_is_valid() {
  [[ "${1:-}" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]
}
