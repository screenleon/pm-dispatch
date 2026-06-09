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
  test-hook-framework
  test-migrate
  test-migrate-to-events
  test-install
  test-uninstall
  test-usage-weekly
  test-usage-tracker
  test-pm-scripts
  test-codex-dispatch
  test-pmctl-dispatch
  test-claude-dispatch
  test-layer-boundaries
  test-executor-router
  test-pmctl-adapter-generate
  test-pr-gate
  test-setup-project
  test-patch-gitignore
  test-portable
  test-doctor
  test-lint-frontmatter
  test-test-harness
  test-commands
  test-commands-runner
  test-dispatch-handover
  test-handover-validate
  test-dispatch-post-verify
  test-check-docs-freshness
  test-skill-refine
  test-pr-gate-profile
  test-claude-executor
  test-run-all-tests
  test-lint-model-aliases
  test-core-schemas
  test-pm-prep-snapshot
  test-schema-task-mirrors-backlog
  test-state-store
  test-state-layout-parity
  test-state-store-rotation
  test-pmctl-trace
  test-pmctl-task
  test-pmctl-decision
  test-pmctl-gate
  test-pmctl-safe
  test-pmctl-validate
  test-brief-validate
  test-archive-closed-backlog
)
SUITE_TOTAL=${#SUITE_NAMES[@]}
SUITE_MINUS_ONE=$((SUITE_TOTAL - 1))

pass_case() {
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$1"
}

fail_case() {
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
  printf 'FAIL: %s: %s\n' "$1" "$2"
}

# local helper — orchestrator uses pass_case/fail_case, not harness pass/fail.
assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail_case "$name" "missing output: $needle"
    return 1
  fi
}

suite_path() {
  case "$1" in
    lint-agents) printf 'scripts/lint-agents.sh\n' ;;
    lint-scripts) printf 'scripts/lint-scripts.sh\n' ;;
    test-hooks) printf 'scripts/test-hooks.sh\n' ;;
    test-hook-framework) printf 'scripts/test-hook-framework.sh\n' ;;
    test-migrate) printf 'scripts/test-migrate-routing-log.sh\n' ;;
    test-migrate-to-events) printf 'scripts/test-migrate-routing-to-events.sh\n' ;;
    test-install) printf 'scripts/test-install.sh\n' ;;
    test-uninstall) printf 'scripts/test-uninstall.sh\n' ;;
    test-usage-weekly) printf 'scripts/test-usage-weekly.sh\n' ;;
    test-usage-tracker) printf 'scripts/test-usage-tracker.sh\n' ;;
    test-pm-scripts) printf 'pm/scripts/test/run-tests.sh\n' ;;
    test-codex-dispatch) printf 'scripts/test-codex-dispatch.sh\n' ;;
    test-pmctl-dispatch) printf 'scripts/test-pmctl-dispatch.sh\n' ;;
    test-claude-dispatch) printf 'scripts/test-claude-dispatch.sh\n' ;;
    test-layer-boundaries) printf 'scripts/test-layer-boundaries.sh\n' ;;
    test-executor-router) printf 'scripts/test-executor-router.sh\n' ;;
    test-pmctl-adapter-generate) printf 'scripts/test-pmctl-adapter-generate.sh\n' ;;
    test-pr-gate) printf 'scripts/test-pr-gate.sh\n' ;;
    test-setup-project) printf 'scripts/test-setup-project.sh\n' ;;
    test-patch-gitignore) printf 'scripts/test-patch-gitignore.sh\n' ;;
    test-portable) printf 'scripts/test-portable.sh\n' ;;
    test-doctor) printf 'scripts/test-doctor.sh\n' ;;
    test-lint-frontmatter) printf 'scripts/test-lint-frontmatter.sh\n' ;;
    test-test-harness) printf 'scripts/test-test-harness.sh\n' ;;
    test-check-docs-freshness) printf 'scripts/test-check-docs-freshness.sh\n' ;;
    test-commands) printf 'scripts/test-commands.sh\n' ;;
    test-commands-runner) printf 'scripts/test-commands-runner.sh\n' ;;
    test-dispatch-handover) printf 'scripts/test-dispatch-handover.sh\n' ;;
    test-handover-validate) printf 'scripts/test-handover-validate.sh\n' ;;
    test-dispatch-post-verify) printf 'scripts/test-dispatch-post-verify.sh\n' ;;
    test-skill-refine) printf 'scripts/test-skill-refine.sh\n' ;;
    test-pr-gate-profile) printf 'scripts/test-pr-gate-profile.sh\n' ;;
    test-claude-executor) printf 'scripts/test-claude-executor.sh\n' ;;
    test-run-all-tests) printf 'scripts/test-run-all-tests.sh\n' ;;
    test-lint-model-aliases) printf 'scripts/test-lint-model-aliases.sh\n' ;;
    test-core-schemas) printf 'scripts/test-core-schemas.sh\n' ;;
    test-pm-prep-snapshot) printf 'scripts/test-pm-prep-snapshot.sh\n' ;;
    test-schema-task-mirrors-backlog) printf 'scripts/test-schema-task-mirrors-backlog.sh\n' ;;
    test-state-store) printf 'scripts/test-state-store.sh\n' ;;
    test-state-layout-parity) printf 'scripts/test-state-layout-parity.sh\n' ;;
    test-state-store-rotation) printf 'scripts/test-state-store-rotation.sh\n' ;;
    test-pmctl-trace) printf 'scripts/test-pmctl-trace.sh\n' ;;
    test-pmctl-task) printf 'scripts/test-pmctl-task.sh\n' ;;
    test-pmctl-decision) printf 'scripts/test-pmctl-decision.sh\n' ;;
    test-pmctl-gate) printf 'scripts/test-pmctl-gate.sh\n' ;;
    test-pmctl-safe) printf 'scripts/test-pmctl-safe.sh\n' ;;
    test-pmctl-validate) printf 'scripts/test-pmctl-validate.sh\n' ;;
    test-brief-validate) printf 'scripts/test-brief-validate.sh\n' ;;
    test-archive-closed-backlog) printf 'scripts/test-archive-closed-backlog.sh\n' ;;
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
  # Behavior: --list prints all registered suite names and exits 0.
  # Steps: invoke --list; assert each SUITE_NAMES entry appears in output.
  local out status=0 suite
  out=$(bash "$REPO_ROOT/scripts/run-all-tests.sh" --list 2>&1) || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail_case "$name" "--list exited $status: $out"
    return
  fi
  for suite in "${SUITE_NAMES[@]}"; do
    assert_contains "$name" "$out" "$suite" || return
  done
  pass_case "$name"
}

test_known_suite_count() {
  local name="known-suite-count"
  # Behavior: the aggregator has exactly the expected number of registered suites.
  # Steps: invoke --list; count output lines; assert the count is 49.
  local out status=0 actual_count expected_count=49
  out=$(bash "$REPO_ROOT/scripts/run-all-tests.sh" --list 2>&1) || status=$?
  actual_count="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  if [[ "$status" -eq 0 && "$SUITE_TOTAL" -eq "$expected_count" && "$actual_count" -eq "$expected_count" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status SUITE_TOTAL=$SUITE_TOTAL listed=$actual_count expected=$expected_count out=$out"
  fi
}

test_skip_unknown_suite() {
  local name="skip-unknown-suite"
  # Behavior: --skip with an unknown suite name is a no-op; all registered suites run.
  # Steps: invoke --skip nonexistent-suite with all pass-stubs; assert all suites pass, none skipped.
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --skip nonexistent-suite 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_skip_known_suite() {
  local name="skip-known-suite"
  # Behavior: --skip with a known suite name causes exactly that suite to be skipped.
  # Steps: invoke --skip lint-agents; assert SKIP message and TOTAL-1 passed, 1 skipped.
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --skip lint-agents 2>&1) || status=$?
  if [[ "$status" -eq 0 &&
        "$out" == *"SKIP lint-agents (requested)"* &&
        "$out" == *"$SUITE_MINUS_ONE passed, 0 failed, 1 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_suite_not_found_skip() {
  local name="suite-not-found-skip"
  # Behavior: a registered suite whose file is missing or non-executable produces FAIL not SKIP.
  # Steps: omit the lint-scripts stub; run aggregator; assert FAIL lint-scripts and exit 1.
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo" lint-scripts
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" 2>&1) || status=$?
  if [[ "$status" -eq 1 &&
        "$out" == *"FAIL lint-scripts (not found or not executable)"* &&
        "$out" == *"$SUITE_MINUS_ONE passed, 1 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_codex_missing_skips_codex_dispatch() {
  local name="codex-missing-skips-codex-dispatch"
  # Behavior: test-codex-dispatch is auto-skipped when codex is absent from PATH.
  # Steps: put codex-absent PATH; assert SKIP test-codex-dispatch and TOTAL-1 passed, 1 skipped.
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_without_codex "$repo/bin")"
  out=$(PATH="$path" bash "$repo/scripts/run-all-tests.sh" 2>&1) || status=$?
  if [[ "$status" -eq 0 &&
        "$out" == *"SKIP test-codex-dispatch (codex not on PATH)"* &&
        "$out" == *"$SUITE_MINUS_ONE passed, 0 failed, 1 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_fail_on_suite_error() {
  local name="fail-on-suite-error"
  # Behavior: a suite that exits non-zero causes FAIL in output and overall exit 1.
  # Steps: write test-pr-gate stub as exit 1; run aggregator; assert FAIL and exit 1.
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  write_suite_stub "$repo" test-pr-gate 1
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" 2>&1) || status=$?
  if [[ "$status" -eq 1 &&
        "$out" == *"FAIL test-pr-gate"* &&
        "$out" == *"$SUITE_MINUS_ONE passed, 1 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_skip_missing_arg() {
  # Behavior: --skip without a suite name argument exits 2 with an error message.
  # Steps: invoke run-all-tests.sh with --skip as the last arg; assert exit 2 and message.
  local name="skip-missing-arg"
  local out status=0
  out=$(bash "$REPO_ROOT/scripts/run-all-tests.sh" --skip 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"--skip requires a non-empty suite name"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_unknown_flag() {
  # Behavior: an unrecognised flag exits 2 with "unknown flag" in stderr.
  # Steps: invoke run-all-tests.sh with --foobar; assert exit 2 and message.
  local name="unknown-flag"
  local out status=0
  out=$(bash "$REPO_ROOT/scripts/run-all-tests.sh" --foobar 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"unknown flag"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_skip_empty_arg() {
  # Behavior: --skip with an empty string argument exits 2 with a usage error.
  # Steps: run aggregator with --skip ''; assert exit 2 and usage error message.
  local name="skip-empty-arg"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --skip '' 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"--skip"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_skip_option_like_arg() {
  # Behavior: --skip with an option-like value (e.g. --list) exits 2 with a usage error.
  # Steps: run aggregator with --skip --list; assert exit 2 and usage error message.
  local name="skip-option-like-arg"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --skip --list 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"--skip"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_dispatch_hooks_home_override() {
  # Behavior: aggregator sets HOME to CLAUDE_CONFIG_TEST_PREFLIGHT_HOME when invoking test-hooks.
  # Steps: write a test-hooks stub that echoes its HOME; run aggregator with
  #        CLAUDE_CONFIG_TEST_PREFLIGHT_HOME=/sentinel/home; assert stub output contains the sentinel.
  local name="dispatch-hooks-home-override"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo" test-hooks

  local hooks_path="$repo/scripts/test-hooks.sh"
  mkdir -p "$(dirname "$hooks_path")"
  cat > "$hooks_path" <<'STUB'
#!/bin/sh
printf "HOME_IS=%s\n" "$HOME"
exit 0
STUB
  chmod +x "$hooks_path"

  path="$(make_path_with_codex "$repo/bin")"
  out=$(CLAUDE_CONFIG_TEST_PREFLIGHT_HOME=/sentinel/home PATH="$path" run_aggregator "$repo" 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"HOME_IS=/sentinel/home"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_dispatch_install_running_flag() {
  # Behavior: aggregator sets CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 when invoking test-install.
  # Steps: write a test-install stub that exits 0 iff the flag is set; run aggregator;
  #        assert PASS test-install in output.
  local name="dispatch-install-running-flag"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo" test-install

  local install_path="$repo/scripts/test-install.sh"
  mkdir -p "$(dirname "$install_path")"
  cat > "$install_path" <<'STUB'
#!/bin/sh
[ "${CLAUDE_CONFIG_TEST_INSTALL_RUNNING:-0}" = "1" ] || exit 1
exit 0
STUB
  chmod +x "$install_path"

  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"PASS test-install"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_dispatch_pm_scripts_via_bash() {
  # Behavior: aggregator invokes pm/scripts/test/run-tests.sh via explicit bash call.
  # Steps: write a #!/bin/false stub at pm/scripts/test/run-tests.sh (direct execution exits 1);
  #        run aggregator which uses bash "$script" (ignores shebang, exits 0);
  #        assert PASS test-pm-scripts, proving bash invocation is used.
  local name="dispatch-pm-scripts-via-bash"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"

  # Override pm-scripts stub: #!/bin/false shebang fails under direct exec but not bash
  local pm_stub="$repo/pm/scripts/test/run-tests.sh"
  printf '#!/bin/false\nexit 0\n' > "$pm_stub"
  chmod +x "$pm_stub"

  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"PASS test-pm-scripts"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_list
test_known_suite_count
test_skip_unknown_suite
test_skip_known_suite
test_suite_not_found_skip
test_codex_missing_skips_codex_dispatch
test_fail_on_suite_error
test_skip_missing_arg
test_unknown_flag
test_skip_empty_arg
test_skip_option_like_arg
test_dispatch_hooks_home_override
test_dispatch_install_running_flag
test_dispatch_pm_scripts_via_bash

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
