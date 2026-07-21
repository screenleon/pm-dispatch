#!/usr/bin/env bash
# Regression tests for tools/lint/lint-surface-coverage.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-surface-coverage.sh"
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

make_fixture() {
  local root="$1"
  mkdir -p "$root/tools/lint" "$root/tests" "$root/commands" "$root/agents" "$root/skills/example"
  cp "$LINTER" "$root/tools/lint/"
  : > "$root/commands/pm.md"; : > "$root/agents/project-pm.md"; : > "$root/skills/example/SKILL.md"
  printf '%s\n' \
    $'command:pm\te2e\treason: primary command smoke' \
    $'agent:project-pm\topt-in\treason: focused contract tests' \
    $'skill:example\tunit\treason: focused skill tests' > "$root/tests/surface-coverage.tsv"
}

# Behavior: A complete current-surface declaration registry passes.
# Steps: Build a minimal commands, agents, and skills fixture with one valid row each.
test_complete_registry_passes() {
  local name="lint-surface-coverage/complete-registry-passes" root output status
  should_run "$name" || return 0; root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"
  if output="$(bash "$root/tools/lint/lint-surface-coverage.sh" --repo-root "$root" 2>&1)"; then status=0; else status=$?; fi
  [[ "$status" -eq 0 ]] && pass "$name" || fail "$name" "status=$status output=$output"
}

# Behavior: New user-facing surfaces cannot bypass a coverage declaration.
# Steps: Add a command fixture without adding its registry row and assert the precise failure.
test_missing_surface_declaration_fails() {
  local name="lint-surface-coverage/missing-surface-declaration-fails" root output status
  should_run "$name" || return 0; root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"; : > "$root/commands/new-command.md"
  if output="$(bash "$root/tools/lint/lint-surface-coverage.sh" --repo-root "$root" 2>&1)"; then status=0; else status=$?; fi
  [[ "$status" -ne 0 && "$output" == *'surface missing coverage declaration: command:new-command'* ]] && pass "$name" || fail "$name" "status=$status output=$output"
}

# Behavior: Coverage rows require an allowed tier and a useful reason.
# Steps: Replace a valid row with an unsupported tier and assert rejection.
test_invalid_coverage_tier_fails() {
  local name="lint-surface-coverage/invalid-coverage-tier-fails" root output status
  should_run "$name" || return 0; root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"
  sed -i 's/command:pm\te2e/command:pm\tunknown/' "$root/tests/surface-coverage.tsv"
  if output="$(bash "$root/tools/lint/lint-surface-coverage.sh" --repo-root "$root" 2>&1)"; then status=0; else status=$?; fi
  [[ "$status" -ne 0 && "$output" == *'invalid coverage tier for command:pm: unknown'* ]] && pass "$name" || fail "$name" "status=$status output=$output"
}

test_complete_registry_passes
test_missing_surface_declaration_fails
test_invalid_coverage_tier_fails
th_summary
