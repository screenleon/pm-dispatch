#!/usr/bin/env bash
# Regression tests for tools/lint/lint-surface-coverage.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-surface-coverage.sh"
# shellcheck disable=SC1091
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

run_fixture_linter() {
  local root="$1"
  if output="$(bash "$root/tools/lint/lint-surface-coverage.sh" --repo-root "$root" 2>&1)"; then status=0; else status=$?; fi
}

# Behavior: A complete current-surface declaration registry passes.
# Steps: Build a minimal commands, agents, and skills fixture with one valid row each.
test_complete_registry_passes() {
  local name="lint-surface-coverage/complete-registry-passes" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"
  run_fixture_linter "$root"
  if [[ "$status" -eq 0 ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

# Behavior: New user-facing surfaces cannot bypass a coverage declaration.
# Steps: Add a command fixture without adding its registry row and assert the precise failure.
test_missing_surface_declaration_fails() {
  local name="lint-surface-coverage/missing-surface-declaration-fails" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"; : > "$root/commands/new-command.md"
  run_fixture_linter "$root"
  if [[ "$status" -ne 0 && "$output" == *'surface missing coverage declaration: command:new-command'* ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

# Behavior: Coverage rows require an allowed tier and a useful reason.
# Steps: Replace a valid row with an unsupported tier and assert rejection.
test_invalid_coverage_tier_fails() {
  local name="lint-surface-coverage/invalid-coverage-tier-fails" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"
  sed -i 's/command:pm\te2e/command:pm\tunknown/' "$root/tests/surface-coverage.tsv"
  run_fixture_linter "$root"
  if [[ "$status" -ne 0 && "$output" == *'invalid coverage tier for command:pm: unknown'* ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

# Behavior: The registry file itself is mandatory.
# Steps: Remove the fixture TSV and assert the required-file diagnostic.
test_missing_registry_fails() {
  local name="lint-surface-coverage/missing-registry-fails" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"; rm "$root/tests/surface-coverage.tsv"
  run_fixture_linter "$root"
  if [[ "$status" -ne 0 && "$output" == *'missing required file: tests/surface-coverage.tsv'* ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

# Behavior: Coverage rows must have exactly three populated columns.
# Steps: Append a two-column row and assert malformed-declaration rejection.
test_malformed_declaration_fails() {
  local name="lint-surface-coverage/malformed-declaration-fails" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"; printf '%s\n' $'command:bad\tunit' >> "$root/tests/surface-coverage.tsv"
  run_fixture_linter "$root"
  if [[ "$status" -ne 0 && "$output" == *$'malformed declaration: command:bad\tunit'* ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

# Behavior: Surface identifiers must use the supported kind/name grammar.
# Steps: Replace one valid identifier with an invalid uppercase name and assert rejection.
test_invalid_surface_name_fails() {
  local name="lint-surface-coverage/invalid-surface-name-fails" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"
  sed -i 's/command:pm/command:Bad_Name/' "$root/tests/surface-coverage.tsv"
  run_fixture_linter "$root"
  if [[ "$status" -ne 0 && "$output" == *'invalid surface name: command:Bad_Name'* ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

# Behavior: Every declaration carries a reviewable one-line reason.
# Steps: Remove the required reason prefix from a fixture row and assert rejection.
test_reason_format_fails() {
  local name="lint-surface-coverage/reason-format-fails" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"
  sed -i 's/reason: primary command smoke/unexplained/' "$root/tests/surface-coverage.tsv"
  run_fixture_linter "$root"
  if [[ "$status" -ne 0 && "$output" == *'coverage declaration needs one-line reason: command:pm'* ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

# Behavior: A surface may be classified only once.
# Steps: Duplicate one valid TSV row and assert duplicate-declaration rejection.
test_duplicate_declaration_fails() {
  local name="lint-surface-coverage/duplicate-declaration-fails" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"
  printf '%s\n' $'command:pm\te2e\treason: duplicate fixture row' >> "$root/tests/surface-coverage.tsv"
  run_fixture_linter "$root"
  if [[ "$status" -ne 0 && "$output" == *'duplicate coverage declaration: command:pm'* ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

# Behavior: Stale rows cannot classify a surface that no longer exists.
# Steps: Append a declaration for a non-existent command and assert stale-row rejection.
test_stale_declaration_fails() {
  local name="lint-surface-coverage/stale-declaration-fails" root output status
  should_run "$name" || return 0; # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/surface-XXXXXX")"; make_fixture "$root"
  printf '%s\n' $'command:removed\tdeprecated\treason: stale fixture row' >> "$root/tests/surface-coverage.tsv"
  run_fixture_linter "$root"
  if [[ "$status" -ne 0 && "$output" == *'coverage declaration names no current surface: command:removed'* ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_complete_registry_passes
test_missing_surface_declaration_fails
test_invalid_coverage_tier_fails
test_missing_registry_fails
test_malformed_declaration_fails
test_invalid_surface_name_fails
test_reason_format_fails
test_duplicate_declaration_fails
test_stale_declaration_fails
th_summary
