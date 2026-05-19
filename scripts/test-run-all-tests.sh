#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

SUITE_NAMES=(
  lint-agents
  lint-scripts
  test-hooks
  test-migrate
  test-install
  test-usage-weekly
  test-usage-tracker
  test-pm-scripts
  test-codex-dispatch
  test-pr-gate
  test-setup-project
  test-patch-gitignore
  test-portable
  test-lint-frontmatter
  test-commands
  test-commands-runner
  test-dispatch-handover
  test-skill-refine
  test-pr-gate-profile
  test-claude-executor
  test-run-all-tests
)

pass() {
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
  printf 'FAIL: %s: %s\n' "$1" "$2"
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$name" "missing output: $needle"
    return 1
  fi
}

suite_path() {
  case "$1" in
    lint-agents) printf 'scripts/lint-agents.sh\n' ;;
    lint-scripts) printf 'scripts/lint-scripts.sh\n' ;;
    test-hooks) printf 'scripts/test-hooks.sh\n' ;;
    test-migrate) printf 'scripts/test-migrate-routing-log.sh\n' ;;
    test-install) printf 'scripts/test-install.sh\n' ;;
    test-usage-weekly) printf 'scripts/test-usage-weekly.sh\n' ;;
    test-usage-tracker) printf 'scripts/test-usage-tracker.sh\n' ;;
    test-pm-scripts) printf 'pm/scripts/test/run-tests.sh\n' ;;
    test-codex-dispatch) printf 'scripts/test-codex-dispatch.sh\n' ;;
    test-pr-gate) printf 'scripts/test-pr-gate.sh\n' ;;
    test-setup-project) printf 'scripts/test-setup-project.sh\n' ;;
    test-patch-gitignore) printf 'scripts/test-patch-gitignore.sh\n' ;;
    test-portable) printf 'scripts/test-portable.sh\n' ;;
    test-lint-frontmatter) printf 'scripts/test-lint-frontmatter.sh\n' ;;
    test-commands) printf 'scripts/test-commands.sh\n' ;;
    test-commands-runner) printf 'scripts/test-commands-runner.sh\n' ;;
    test-dispatch-handover) printf 'scripts/test-dispatch-handover.sh\n' ;;
    test-skill-refine) printf 'scripts/test-skill-refine.sh\n' ;;
    test-pr-gate-profile) printf 'scripts/test-pr-gate-profile.sh\n' ;;
    test-claude-executor) printf 'scripts/test-claude-executor.sh\n' ;;
    test-run-all-tests) printf 'scripts/test-run-all-tests.sh\n' ;;
    *) return 1 ;;
  esac
}

make_fixture_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts" "$repo/pm/scripts/test"
  cp "$REPO_ROOT/scripts/run-all-tests.sh" "$repo/scripts/run-all-tests.sh"
  chmod +x "$repo/scripts/run-all-tests.sh"
}

write_suite_stub() {
  local repo="$1" name="$2" status="$3"
  local path
  path="$repo/$(suite_path "$name")"
  mkdir -p "$(dirname "$path")"
  printf '#!/bin/sh\nexit %s\n' "$status" > "$path"
  chmod +x "$path"
}

write_pass_stubs() {
  local repo="$1" omit="${2:-}"
  local suite
  for suite in "${SUITE_NAMES[@]}"; do
    [[ "$suite" == "$omit" ]] && continue
    write_suite_stub "$repo" "$suite" 0
  done
}

make_path_with_codex() {
  local bin="$1"
  mkdir -p "$bin"
  printf '#!/bin/sh\nexit 0\n' > "$bin/codex"
  chmod +x "$bin/codex"
  printf '%s:%s\n' "$bin" "$PATH"
}

make_path_without_codex() {
  local bin="$1"
  mkdir -p "$bin"
  ln -s /usr/bin/bash "$bin/bash"
  ln -s /usr/bin/dirname "$bin/dirname"
  printf '%s\n' "$bin"
}

run_aggregator() {
  local repo="$1"
  shift
  bash "$repo/scripts/run-all-tests.sh" "$@" 2>&1
}

test_list() {
  local name="list"
  local out status=0 suite
  out=$(bash "$REPO_ROOT/scripts/run-all-tests.sh" --list 2>&1) || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "--list exited $status: $out"
    return
  fi
  for suite in "${SUITE_NAMES[@]}"; do
    assert_contains "$name" "$out" "$suite" || return
  done
  pass "$name"
}

test_skip_unknown_suite() {
  local name="skip-unknown-suite"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --skip nonexistent-suite 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"21 passed, 0 failed, 0 skipped"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_skip_known_suite() {
  local name="skip-known-suite"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --skip lint-agents 2>&1) || status=$?
  if [[ "$status" -eq 0 &&
        "$out" == *"SKIP lint-agents (requested)"* &&
        "$out" == *"20 passed, 0 failed, 1 skipped"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_suite_not_found_skip() {
  local name="suite-not-found-skip"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo" lint-scripts
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" 2>&1) || status=$?
  if [[ "$status" -eq 1 &&
        "$out" == *"FAIL lint-scripts (not found or not executable)"* &&
        "$out" == *"20 passed, 1 failed, 0 skipped"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_codex_missing_skips_codex_dispatch() {
  local name="codex-missing-skips-codex-dispatch"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_without_codex "$repo/bin")"
  out=$(PATH="$path" /usr/bin/bash "$repo/scripts/run-all-tests.sh" 2>&1) || status=$?
  if [[ "$status" -eq 0 &&
        "$out" == *"SKIP test-codex-dispatch (codex not on PATH)"* &&
        "$out" == *"20 passed, 0 failed, 1 skipped"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_fail_on_suite_error() {
  local name="fail-on-suite-error"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  write_suite_stub "$repo" test-pr-gate 1
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" 2>&1) || status=$?
  if [[ "$status" -eq 1 &&
        "$out" == *"FAIL test-pr-gate"* &&
        "$out" == *"20 passed, 1 failed, 0 skipped"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_list
test_skip_unknown_suite
test_skip_known_suite
test_suite_not_found_skip
test_codex_missing_skips_codex_dispatch
test_fail_on_suite_error

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
