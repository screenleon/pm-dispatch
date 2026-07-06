#!/usr/bin/env bash
# Regression tests for scripts/lint-test-docstrings.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINTER="$REPO_ROOT/scripts/lint-test-docstrings.sh"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

should_run() {
  if $LIST; then ALL_CASES+=("$1"); return 1; fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

# fixture_repo <content>: build a scratch repo_root with scripts/fixture.sh
# holding <content>, print the repo_root path.
fixture_repo() {
  local content="$1" root
  root="$(mktemp -d "$tmp_root/lint-test-docstrings-XXXXXX")"
  mkdir -p "$root/scripts"
  printf '%s' "$content" > "$root/scripts/fixture.sh"
  printf '%s\n' "$root"
}

run_linter() {
  local root="$1"
  bash "$LINTER" --repo-root "$root" --allow scripts/fixture.sh 2>&1
}

# Behavior: a test_* function preceded by a "# Behavior:" line passes.
# Steps: build a fixture with one conforming test function, run the
# linter, and assert exit 0.
test_conforming_function_passes() {
  local name="lint-test-docstrings/conforming-function-passes"
  should_run "$name" || return 0
  local root output status
  root="$(fixture_repo '# Behavior: does a thing.
test_ok() {
  echo hi
}
')"
  output="$(run_linter "$root")"; status=$?
  if [[ $status -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0, got $status; output: $output"
  fi
}

# Behavior: a test_* function with no comment block above it fails.
# Steps: build a fixture with an undocumented test function, run the
# linter, and assert non-zero exit and a FAIL line naming the function's
# line number.
test_missing_docstring_fails() {
  local name="lint-test-docstrings/missing-docstring-fails"
  should_run "$name" || return 0
  local root output status
  root="$(fixture_repo 'test_bad() {
  echo hi
}
')"
  output="$(run_linter "$root")"; status=$?
  if [[ $status -ne 0 ]] && [[ "$output" == *"FAIL: scripts/fixture.sh:1"* ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit with a line-1 FAIL, got $status; output: $output"
  fi
}

# Behavior: a comment block that mentions "Steps:" but never "Behavior:"
# still fails -- the marker word itself is required, not just a comment.
# Steps: build a fixture where the only preceding comment lacks
# "Behavior:", run the linter, and assert non-zero exit.
test_steps_only_fails() {
  local name="lint-test-docstrings/steps-only-fails"
  should_run "$name" || return 0
  local root output status
  root="$(fixture_repo '# Steps: run it and assert.
test_bad() {
  echo hi
}
')"
  output="$(run_linter "$root")"; status=$?
  if [[ $status -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit, got $status; output: $output"
  fi
}

# Behavior: a "# Behavior:" comment separated from the declaration by a
# blank line does not count -- the block must be directly adjacent.
# Steps: build a fixture with a Behavior comment, a blank line, then the
# declaration, run the linter, and assert non-zero exit.
test_blank_line_break_fails() {
  local name="lint-test-docstrings/blank-line-break-fails"
  should_run "$name" || return 0
  local root output status
  root="$(fixture_repo '# Behavior: does a thing.

test_bad() {
  echo hi
}
')"
  output="$(run_linter "$root")"; status=$?
  if [[ $status -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit, got $status; output: $output"
  fi
}

# Behavior: a mix of one conforming and one non-conforming function in the
# same file reports exactly one violation, not zero and not two.
# Steps: build a fixture with a documented function followed by an
# undocumented one, run the linter, and assert non-zero exit with exactly
# one FAIL line.
test_mixed_file_reports_only_bad_one() {
  local name="lint-test-docstrings/mixed-file-reports-only-bad-one"
  should_run "$name" || return 0
  local root output status fail_count
  root="$(fixture_repo '# Behavior: first one is fine.
test_good() {
  echo hi
}

test_bad() {
  echo hi
}
')"
  output="$(run_linter "$root")"; status=$?
  fail_count="$(grep -c '^FAIL:' <<< "$output" || true)"
  if [[ $status -ne 0 ]] && [[ "$fail_count" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "expected exactly 1 FAIL line, got $fail_count (status=$status); output: $output"
  fi
}

# Behavior: the real allowlisted files (the default ALLOWLIST, no
# --allow override) are clean right now -- this is the actual gate that
# runs in CI/run-all-tests, so it must pass against the live repo.
# Steps: run the linter with no arguments against the real repo, and
# assert exit 0.
test_default_allowlist_is_clean() {
  local name="lint-test-docstrings/default-allowlist-is-clean"
  should_run "$name" || return 0
  local output status
  output="$(cd "$REPO_ROOT" && bash "$LINTER" 2>&1)"; status=$?
  if [[ $status -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 against the real repo, got $status; output: $output"
  fi
}

# Behavior: an allowlisted path that does not exist is a controlled error
# (exit 2), not a silent skip or an unbound-variable crash.
# Steps: run the linter with --allow pointing at a nonexistent file, and
# assert exit 2.
test_missing_allowlisted_file_errors() {
  local name="lint-test-docstrings/missing-allowlisted-file-errors"
  should_run "$name" || return 0
  local root output status
  root="$(mktemp -d "$tmp_root/lint-test-docstrings-XXXXXX")"
  output="$(bash "$LINTER" --repo-root "$root" --allow scripts/no-such-file.sh 2>&1)"; status=$?
  if [[ $status -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status; output: $output"
  fi
}

test_conforming_function_passes
test_missing_docstring_fails
test_steps_only_fails
test_blank_line_break_fails
test_mixed_file_reports_only_bad_one
test_default_allowlist_is_clean
test_missing_allowlisted_file_errors

th_summary
