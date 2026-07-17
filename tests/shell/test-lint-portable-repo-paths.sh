#!/usr/bin/env bash
# Regression tests for the operational repository-path portability ratchet.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-portable-repo-paths.sh"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

make_fake_repo() {
  local root="$1"
  mkdir -p "$root/tools/lint" "$root/agents" "$root/docs/spikes" "$root/tests/fixtures"
  cp "$LINTER" "$root/tools/lint/lint-portable-repo-paths.sh"
  printf 'Use ${PM_DISPATCH_REPOS_ROOT}/project.\n' > "$root/agents/project-pm.md"
}

case_current_tree_passes() {
  # behavior: current operational tree contains no maintainer-local repo layout literals
  # Steps: run the ratchet against the checkout; assert success
  local name="lint-portable-repo-paths/current tree passes" status=0 out
  should_run "$name" || return 0
  out="$(bash "$LINTER" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"OK"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_operational_literal_fails() {
  # behavior: a forbidden layout literal in an operational file fails the ratchet
  # Steps: inject the literal into an agent file; assert non-zero and file provenance
  local name="lint-portable-repo-paths/operational literal fails" root status=0 out
  should_run "$name" || return 0
  root="$tmp_root/operational"
  make_fake_repo "$root"
  printf 'scan ~%s/project\n' '/github' > "$root/agents/project-pm.md"
  out="$(bash "$root/tools/lint/lint-portable-repo-paths.sh" 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$out" == *"agents/project-pm.md"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_historical_spike_is_excluded() {
  # behavior: historical spike evidence may retain observed machine paths
  # Steps: inject a forbidden literal only under docs/spikes; assert success
  local name="lint-portable-repo-paths/historical spikes excluded" root status=0 out
  should_run "$name" || return 0
  root="$tmp_root/spike"
  make_fake_repo "$root"
  printf 'historical ~%s/project\n' '/github' > "$root/docs/spikes/evidence.md"
  out="$(bash "$root/tools/lint/lint-portable-repo-paths.sh" 2>&1)" || status=$?
  if [[ "$status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_current_tree_passes
case_operational_literal_fails
case_historical_spike_is_excluded
th_summary
