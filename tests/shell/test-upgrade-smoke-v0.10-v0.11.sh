#!/usr/bin/env bash
# Focused CLI and evidence-contract tests for the CC-447 upgrade smoke.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SMOKE="$REPO_ROOT/ops/release/upgrade-smoke-v0.10-v0.11.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "test-upgrade-smoke-v0.10-v0.11" "$@"

# Behavior: help documents the two-checkout isolation and evidence destination.
# Steps: invoke --help and inspect the stable maintainer-facing flags.
test_help_contract() {
  local name="upgrade-smoke-help-contract" out
  should_run "$name" || return 0
  out="$(bash "$SMOKE" --help 2>&1)"
  if [[ "$out" == *"--baseline-dir PATH"* && "$out" == *"--candidate-dir PATH"* \
      && "$out" == *"--artifact-dir PATH"* && "$out" == *"independent git checkouts/worktrees"* ]]; then
    pass "$name"
  else
    fail "$name" "help is missing the checkout/evidence contract"
  fi
}

# Behavior: missing required checkout arguments is a usage error with no mutation.
# Steps: invoke with no arguments and assert exit 2.
test_missing_args_exit_two() {
  local name="upgrade-smoke-missing-args-exit-two" rc=0
  should_run "$name" || return 0
  bash "$SMOKE" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $rc"
  fi
}

# Behavior: the release blocker records every required CC-447 evidence class.
# Steps: inspect the harness for stage, doctor, refresh, and preservation records.
test_evidence_contract_is_complete() {
  local name="upgrade-smoke-evidence-contract-is-complete" token
  should_run "$name" || return 0
  for token in baseline_sha candidate_sha candidate-install candidate-doctor candidate-dry-run \
    candidate-uninstall old-to-new-targets retired-targets canonical-memory-byte-preserved \
    opencode-config-byte-preserved user-data-byte-preserved; do
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
