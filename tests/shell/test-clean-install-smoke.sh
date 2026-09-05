#!/usr/bin/env bash
# Focused CLI and evidence-contract tests for the CC-447 clean-install smoke.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SMOKE="$REPO_ROOT/ops/release/clean-install-smoke.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "test-clean-install-smoke" "$@"

# Behavior: help documents the single-checkout and evidence CLI contract.
# Steps: invoke --help and inspect the stable maintainer-facing flags.
test_help_contract() {
  local name="clean-install-smoke-help-contract" out
  should_run "$name" || return 0
  out="$(bash "$SMOKE" --help 2>&1)"
  if [[ "$out" == *"--repo-dir PATH"* && "$out" == *"--artifact-dir PATH"* \
      && "$out" == *"--keep-sandbox"* && "$out" == *"no-residue verification"* ]]; then
    pass "$name"
  else
    fail "$name" "help is missing the checkout/evidence contract"
  fi
}

# Behavior: a missing option argument is a usage error and cannot run installation.
# Steps: invoke --repo-dir without PATH and assert exit 2.
test_missing_args_exit_two() {
  local name="clean-install-smoke-missing-args-exit-two" rc=0
  should_run "$name" || return 0
  bash "$SMOKE" --repo-dir >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "expected exit 2, got $rc"; fi
}

# Behavior: the harness records all required clean-install evidence classes.
# Steps: inspect the harness for the five stages, assertions, and summary schema keys.
test_evidence_contract_is_complete() {
  local name="clean-install-smoke-evidence-contract-is-complete" token
  should_run "$name" || return 0
  for token in CC-447 dry-run install doctor uninstall no-residue dry-run-tree-unchanged \
    doctor-zero-fail 'schema_version:1' candidate_sha stages assertions summary.json; do
    if ! grep -Fq "$token" "$SMOKE"; then
      fail "$name" "missing evidence token: $token"
      return
    fi
  done
  pass "$name"
}

test_help_contract
test_missing_args_exit_two
test_evidence_contract_is_complete
th_summary
