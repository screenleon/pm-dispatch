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
  lint-test-docstrings
  test-guards
  test-guard-framework
  test-migrate
  test-migrate-to-events
  test-install
  test-uninstall
  test-usage-weekly
  test-usage-tracker
  test-pm-scripts
  test-codex-dispatch
  test-pmctl-dispatch
  test-dispatch-record
  test-dispatch-lifecycle
  test-gate-lifecycle
  test-claude-dispatch
  test-opencode-dispatch
  test-layer-boundaries
  test-executor-router
  test-runner-kind
  test-pmctl-adapter-generate
  test-pr-gate
  test-setup-project
  test-patch-gitignore
  test-portable
  test-doctor
  test-hook-profile-parity
  test-lint-frontmatter
  test-lint-test-docstrings
  test-test-harness
  test-commands
  test-commands-runner
  test-dispatch-handover
  test-handover-validate
  test-dispatch-post-verify
  test-check-docs-freshness
  test-skill-refine
  test-pr-gate-profile
  test-run-all-tests
  test-timeout-resolve
  test-dispatch-common
  test-detached-launch
  test-lint-model-aliases
  test-core-schemas
  test-host-manifest
  test-host-write-codex
  test-pm-prep-snapshot
  test-schema-task-mirrors-backlog
  test-state-store
  test-state-paths
  test-pmctl-artifacts
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
  test-pmctl-context
  test-pmctl-memory
  test-pmctl-backlog
  test-pmctl-guard
  test-pmctl-ship
  test-pmctl-worktree
  test-pre-release
  test-release-verify
  test-e2e-script
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
    lint-test-docstrings) printf 'scripts/lint-test-docstrings.sh\n' ;;
    test-guards) printf 'scripts/test-guards.sh\n' ;;
    test-guard-framework) printf 'scripts/test-guard-framework.sh\n' ;;
    test-migrate) printf 'scripts/test-migrate-routing-log.sh\n' ;;
    test-migrate-to-events) printf 'scripts/test-migrate-routing-to-events.sh\n' ;;
    test-install) printf 'scripts/test-install.sh\n' ;;
    test-uninstall) printf 'scripts/test-uninstall.sh\n' ;;
    test-usage-weekly) printf 'scripts/test-usage-weekly.sh\n' ;;
    test-usage-tracker) printf 'scripts/test-usage-tracker.sh\n' ;;
    test-pm-scripts) printf 'pm/scripts/test/run-tests.sh\n' ;;
    test-codex-dispatch) printf 'scripts/test-codex-dispatch.sh\n' ;;
    test-pmctl-dispatch) printf 'scripts/test-pmctl-dispatch.sh\n' ;;
    test-dispatch-record) printf 'scripts/test-dispatch-record.sh\n' ;;
    test-dispatch-lifecycle) printf 'scripts/test-dispatch-lifecycle.sh\n' ;;
    test-gate-lifecycle) printf 'scripts/test-gate-lifecycle.sh\n' ;;
    test-claude-dispatch) printf 'scripts/test-claude-dispatch.sh\n' ;;
    test-opencode-dispatch) printf 'scripts/test-opencode-dispatch.sh\n' ;;
    test-layer-boundaries) printf 'scripts/test-layer-boundaries.sh\n' ;;
    test-executor-router) printf 'scripts/test-executor-router.sh\n' ;;
    test-runner-kind) printf 'scripts/test-runner-kind.sh\n' ;;
    test-pmctl-adapter-generate) printf 'scripts/test-pmctl-adapter-generate.sh\n' ;;
    test-pr-gate) printf 'scripts/test-pr-gate.sh\n' ;;
    test-setup-project) printf 'scripts/test-setup-project.sh\n' ;;
    test-patch-gitignore) printf 'scripts/test-patch-gitignore.sh\n' ;;
    test-portable) printf 'scripts/test-portable.sh\n' ;;
    test-doctor) printf 'scripts/test-doctor.sh\n' ;;
    test-hook-profile-parity) printf 'scripts/test-hook-profile-parity.sh\n' ;;
    test-lint-frontmatter) printf 'scripts/test-lint-frontmatter.sh\n' ;;
    test-lint-test-docstrings) printf 'scripts/test-lint-test-docstrings.sh\n' ;;
    test-test-harness) printf 'scripts/test-test-harness.sh\n' ;;
    test-check-docs-freshness) printf 'scripts/test-check-docs-freshness.sh\n' ;;
    test-commands) printf 'scripts/test-commands.sh\n' ;;
    test-commands-runner) printf 'scripts/test-commands-runner.sh\n' ;;
    test-dispatch-handover) printf 'scripts/test-dispatch-handover.sh\n' ;;
    test-handover-validate) printf 'scripts/test-handover-validate.sh\n' ;;
    test-dispatch-post-verify) printf 'scripts/test-dispatch-post-verify.sh\n' ;;
    test-skill-refine) printf 'scripts/test-skill-refine.sh\n' ;;
    test-pr-gate-profile) printf 'scripts/test-pr-gate-profile.sh\n' ;;
    test-run-all-tests) printf 'scripts/test-run-all-tests.sh\n' ;;
    test-timeout-resolve) printf 'scripts/test-timeout-resolve.sh\n' ;;
    test-dispatch-common) printf 'scripts/test-dispatch-common.sh\n' ;;
    test-detached-launch) printf 'scripts/test-detached-launch.sh\n' ;;
    test-lint-model-aliases) printf 'scripts/test-lint-model-aliases.sh\n' ;;
    test-host-manifest)   printf 'scripts/test-host-manifest.sh\n' ;;
    test-host-write-codex) printf 'scripts/test-host-write-codex.sh\n' ;;
    test-core-schemas) printf 'scripts/test-core-schemas.sh\n' ;;
    test-pm-prep-snapshot) printf 'scripts/test-pm-prep-snapshot.sh\n' ;;
    test-schema-task-mirrors-backlog) printf 'scripts/test-schema-task-mirrors-backlog.sh\n' ;;
    test-state-store) printf 'scripts/test-state-store.sh\n' ;;
    test-state-paths) printf 'scripts/test-state-paths.sh\n' ;;
    test-pmctl-artifacts) printf 'scripts/test-pmctl-artifacts.sh\n' ;;
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
    test-pmctl-context)  printf 'scripts/test-pmctl-context.sh\n' ;;
    test-pmctl-memory)   printf 'scripts/test-pmctl-memory.sh\n' ;;
    test-pmctl-backlog)   printf 'scripts/test-pmctl-backlog.sh\n' ;;
    test-pmctl-guard)     printf 'scripts/test-pmctl-guard.sh\n' ;;
    test-pmctl-ship)      printf 'scripts/test-pmctl-ship.sh\n' ;;
    test-pmctl-worktree)  printf 'scripts/test-pmctl-worktree.sh\n' ;;
    test-pre-release)     printf 'scripts/test-pre-release.sh\n' ;;
    test-release-verify)  printf 'scripts/test-release-verify.sh\n' ;;
    test-e2e-script)      printf 'scripts/test-e2e-script.sh\n' ;;
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
  # Parallel path in run-all-tests needs these external tools:
  ln -s "$(command -v mktemp)" "$bin/mktemp"
  ln -s "$(command -v mkdir)"  "$bin/mkdir"
  ln -s "$(command -v cat)"    "$bin/cat"
  ln -s "$(command -v rm)"     "$bin/rm"
  ln -s "$(command -v sleep)"  "$bin/sleep"
  if command -v nproc >/dev/null 2>&1; then ln -s "$(command -v nproc)" "$bin/nproc"; fi
  printf '%s\n' "$bin"
}

# Build a PATH whose `codex` is a no-op stub and whose `nproc` is a stub with a
# caller-supplied body (real PATH appended). Lets a test pin the default-jobs
# detection: `echo N` makes nproc report N; `exit 1` makes `nproc||echo 1` fall
# back to the sequential default. The stub bin is prepended so it shadows any
# real nproc/codex on the host.
make_path_codex_nproc_stub() {
  local bin="$1" nproc_body="$2"
  mkdir -p "$bin"
  printf '#!/bin/sh\nexit 0\n' > "$bin/codex"
  chmod +x "$bin/codex"
  printf '#!/bin/sh\n%s\n' "$nproc_body" > "$bin/nproc"
  chmod +x "$bin/nproc"
  printf '%s:%s\n' "$bin" "$PATH"
}

# Write a suite stub that records a "started" marker then blocks until a matching
# "release" marker appears, so a test can deterministically observe how many
# suites the aggregator launches concurrently. A 30s safety bound prevents an
# orphaned stub from blocking forever if the test bails before releasing it.
write_gated_stub() {
  local repo="$1" sname="$2" marker="$3"
  local path
  path="$repo/$(suite_path "$sname")"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
#!/bin/sh
echo started > "$marker/started-$sname"
i=0
while [ ! -e "$marker/release-$sname" ]; do
  i=\$((i + 1)); [ "\$i" -ge 1500 ] && break
  sleep 0.02
done
exit 0
EOF
  chmod +x "$path"
}

# Poll (bounded) until a file exists. Returns 1 on timeout so callers fail loudly
# instead of hanging when the aggregator never reaches the expected state.
wait_for_file() {
  local f="$1" tries="${2:-200}" i=0
  while [[ ! -e "$f" ]]; do
    i=$((i + 1))
    [[ "$i" -ge "$tries" ]] && return 1
    sleep 0.02
  done
  return 0
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
  # Steps: invoke --list; count output lines; assert the count matches SUITE_TOTAL.
  local out status=0 actual_count expected_count=$SUITE_TOTAL
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
  # Behavior: aggregator sets HOME to CLAUDE_CONFIG_TEST_PREFLIGHT_HOME when invoking test-guards.
  # Steps: write a test-guards stub that echoes its HOME; run aggregator with
  #        CLAUDE_CONFIG_TEST_PREFLIGHT_HOME=/sentinel/home; assert stub output contains the sentinel.
  local name="dispatch-hooks-home-override"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo" test-guards

  local hooks_path="$repo/scripts/test-guards.sh"
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

test_jobs_parallel_all_pass() {
  # Behavior: --jobs 2 runs all suites in parallel and exits 0 with correct totals.
  # Steps: write pass stubs for all suites; run aggregator --jobs 2; assert exit 0 and
  #        total line shows SUITE_TOTAL passed.
  local name="jobs-parallel-all-pass"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --jobs 2 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_parallel_one_fail() {
  # Behavior: --jobs 2 with one failing suite exits 1 and names the failed suite.
  # Steps: write pass stubs; override lint-agents stub to exit 1; run --jobs 2;
  #        assert exit != 0, FAIL lint-agents in output, and failed suites line names it.
  local name="jobs-parallel-one-fail"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  write_suite_stub "$repo" lint-agents 1
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --jobs 2 2>&1) || status=$?
  if [[ "$status" -ne 0 && "$out" == *"FAIL lint-agents"* && "$out" == *"failed suites:"*"lint-agents"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_parallel_skip_accounting() {
  # Behavior: --jobs 2 with --skip reflects the skipped suite in totals.
  # Steps: write pass stubs; run --jobs 2 --skip lint-agents; assert SKIP message and
  #        total shows SUITE_TOTAL-1 passed and 1 skipped.
  local name="jobs-parallel-skip-accounting"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --jobs 2 --skip lint-agents 2>&1) || status=$?
  local expected_pass=$(( SUITE_TOTAL - 1 ))
  if [[ "$status" -eq 0 &&
        "$out" == *"SKIP lint-agents (requested)"* &&
        "$out" == *"$expected_pass passed, 0 failed, 1 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_invalid_zero() {
  # Behavior: --jobs 0 exits 2 with an error message.
  # Steps: invoke run-all-tests.sh --jobs 0; assert exit 2 and error message contains
  #        "--jobs requires a positive integer".
  local name="jobs-invalid-zero"
  local out status=0
  out=$(bash "$REPO_ROOT/scripts/run-all-tests.sh" --jobs 0 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"--jobs requires a positive integer"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_invalid_string() {
  # Behavior: --jobs with a non-numeric argument exits 2 with an error message.
  # Steps: invoke run-all-tests.sh --jobs abc; assert exit 2 and error message contains
  #        "--jobs requires a positive integer".
  local name="jobs-invalid-string"
  local out status=0
  out=$(bash "$REPO_ROOT/scripts/run-all-tests.sh" --jobs abc 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"--jobs requires a positive integer"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_no_arg_default() {
  # Behavior: no --jobs flag uses default parallelism (nproc or 1 fallback); exits 0.
  # Steps: write pass stubs; run aggregator without --jobs; assert exit 0 and correct totals.
  local name="jobs-no-arg-default"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_larger_than_suite_count() {
  # Behavior: --jobs N where N exceeds total suite count runs all suites without error.
  # Steps: write pass stubs; run --jobs 9999; assert exit 0 and correct totals.
  local name="jobs-larger-than-suite-count"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --jobs 9999 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_explicit_sequential() {
  # Behavior: --jobs 1 forces the sequential code path and preserves pass/fail/skip accounting.
  # Steps: write pass stubs; run --jobs 1; assert exit 0 and total line shows SUITE_TOTAL passed;
  #        write a failing stub for lint-agents; run --jobs 1 again; assert exit 1 and
  #        "FAIL lint-agents" plus "failed suites: lint-agents" in output.
  local name="jobs-explicit-sequential"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --jobs 1 2>&1) || status=$?
  if [[ "$status" -ne 0 || "$out" != *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    fail_case "$name (all-pass)" "status=$status out=$out"
    return
  fi
  write_suite_stub "$repo" lint-agents 1
  status=0
  out=$(PATH="$path" run_aggregator "$repo" --jobs 1 2>&1) || status=$?
  if [[ "$status" -ne 0 && "$out" == *"FAIL lint-agents"* && "$out" == *"failed suites:"*"lint-agents"* ]]; then
    pass_case "$name"
  else
    fail_case "$name (one-fail)" "status=$status out=$out"
  fi
}

test_jobs_concurrency_and_max_inflight() {
  # Behavior: --jobs 2 launches exactly 2 suites concurrently and holds further
  #           launches until a slot frees (max-in-flight enforcement + drain/launch).
  # Steps: gate the first 3 registered suites; run aggregator --jobs 2 in background;
  #        assert suites 1 and 2 both start (concurrency) while suite 3 stays held
  #        (max=2); release suite 1 and assert suite 3 then starts (drain frees a slot);
  #        release the rest; assert exit 0 and full pass totals.
  local name="jobs-concurrency-max-inflight"
  local repo="$TMP_ROOT/$name" path status
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  local marker="$TMP_ROOT/$name-markers"; mkdir -p "$marker"
  write_gated_stub "$repo" lint-agents "$marker"
  write_gated_stub "$repo" lint-scripts "$marker"
  write_gated_stub "$repo" test-guards "$marker"
  path="$(make_path_with_codex "$repo/bin")"
  local logf="$TMP_ROOT/$name.log"
  ( PATH="$path" run_aggregator "$repo" --jobs 2 > "$logf" 2>&1; echo $? > "$marker/rc" ) &
  local agg_pid=$!

  if ! wait_for_file "$marker/started-lint-agents" 300 || \
     ! wait_for_file "$marker/started-lint-scripts" 300; then
    fail_case "$name" "two suites did not start concurrently (parallel path not taken)"
    touch "$marker/release-lint-agents" "$marker/release-lint-scripts" "$marker/release-test-guards"
    wait "$agg_pid" 2>/dev/null; return
  fi
  # Both slots occupied by blocked stubs -> the third suite must not have launched.
  if [[ -e "$marker/started-test-guards" ]]; then
    fail_case "$name" "third suite started while 2 slots busy (max-JOBS not enforced)"
    touch "$marker/release-lint-agents" "$marker/release-lint-scripts" "$marker/release-test-guards"
    wait "$agg_pid" 2>/dev/null; return
  fi
  # Free one slot -> the held suite should now launch.
  touch "$marker/release-lint-agents"
  if ! wait_for_file "$marker/started-test-guards" 300; then
    fail_case "$name" "third suite never launched after a slot freed (drain broken)"
    touch "$marker/release-lint-scripts" "$marker/release-test-guards"
    wait "$agg_pid" 2>/dev/null; return
  fi
  touch "$marker/release-lint-scripts" "$marker/release-test-guards"
  wait "$agg_pid" 2>/dev/null
  status="$(cat "$marker/rc" 2>/dev/null || echo 1)"
  local out; out="$(cat "$logf" 2>/dev/null)"
  if [[ "$status" -eq 0 && "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_default_fallback_no_nproc() {
  # Behavior: when nproc is unavailable, no-arg default falls back to JOBS=1 (sequential),
  #           running suites strictly one at a time while still producing correct totals.
  # Steps: gate the first 2 suites; prepend a failing nproc stub so `nproc||echo 1` -> 1;
  #        run aggregator with no --jobs in background; assert suite 1 starts but suite 2
  #        stays held while suite 1 runs (sequential proof); release suite 1 and assert
  #        suite 2 then starts; release all; assert exit 0 and full pass totals.
  local name="jobs-default-fallback-no-nproc"
  local repo="$TMP_ROOT/$name" path status
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  local marker="$TMP_ROOT/$name-markers"; mkdir -p "$marker"
  write_gated_stub "$repo" lint-agents "$marker"
  write_gated_stub "$repo" lint-scripts "$marker"
  path="$(make_path_codex_nproc_stub "$repo/bin" 'exit 1')"
  local logf="$TMP_ROOT/$name.log"
  ( PATH="$path" run_aggregator "$repo" > "$logf" 2>&1; echo $? > "$marker/rc" ) &
  local agg_pid=$!

  if ! wait_for_file "$marker/started-lint-agents" 300; then
    fail_case "$name" "first suite never started"
    touch "$marker/release-lint-agents" "$marker/release-lint-scripts"
    wait "$agg_pid" 2>/dev/null; return
  fi
  # Sequential: while suite 1 blocks, no slot frees, so suite 2 can never launch.
  if [[ -e "$marker/started-lint-scripts" ]]; then
    fail_case "$name" "second suite started concurrently; fallback is not sequential (JOBS!=1)"
    touch "$marker/release-lint-agents" "$marker/release-lint-scripts"
    wait "$agg_pid" 2>/dev/null; return
  fi
  touch "$marker/release-lint-agents"
  if ! wait_for_file "$marker/started-lint-scripts" 300; then
    fail_case "$name" "second suite never ran after first finished (sequential path broken)"
    touch "$marker/release-lint-scripts"
    wait "$agg_pid" 2>/dev/null; return
  fi
  touch "$marker/release-lint-scripts"
  wait "$agg_pid" 2>/dev/null
  status="$(cat "$marker/rc" 2>/dev/null || echo 1)"
  local out; out="$(cat "$logf" 2>/dev/null)"
  if [[ "$status" -eq 0 && "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_jobs_default_uses_detected_nproc() {
  # Behavior: with no --jobs, default parallelism equals the detected nproc value.
  # Steps: gate the first 4 suites; prepend an nproc stub reporting 3; run aggregator with
  #        no --jobs in background; assert exactly suites 1-3 start concurrently and suite 4
  #        stays held (max=3 from nproc, not a hardcoded 1 or unbounded); release one slot
  #        and assert suite 4 then starts; release all; assert exit 0 and full pass totals.
  local name="jobs-default-detected-nproc"
  local repo="$TMP_ROOT/$name" path status
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  local marker="$TMP_ROOT/$name-markers"; mkdir -p "$marker"
  write_gated_stub "$repo" lint-agents "$marker"
  write_gated_stub "$repo" lint-scripts "$marker"
  write_gated_stub "$repo" test-guards "$marker"
  write_gated_stub "$repo" test-guard-framework "$marker"
  path="$(make_path_codex_nproc_stub "$repo/bin" 'echo 3')"
  local logf="$TMP_ROOT/$name.log"
  ( PATH="$path" run_aggregator "$repo" > "$logf" 2>&1; echo $? > "$marker/rc" ) &
  local agg_pid=$!

  _release_all_gated() {
    touch "$marker/release-lint-agents" "$marker/release-lint-scripts" \
          "$marker/release-test-guards" "$marker/release-test-guard-framework"
  }
  if ! wait_for_file "$marker/started-lint-agents" 300 || \
     ! wait_for_file "$marker/started-lint-scripts" 300 || \
     ! wait_for_file "$marker/started-test-guards" 300; then
    fail_case "$name" "fewer than 3 suites started; default did not honor nproc=3"
    _release_all_gated; wait "$agg_pid" 2>/dev/null; return
  fi
  if [[ -e "$marker/started-test-guard-framework" ]]; then
    fail_case "$name" "4th suite started; default exceeded detected nproc=3"
    _release_all_gated; wait "$agg_pid" 2>/dev/null; return
  fi
  touch "$marker/release-lint-agents"
  if ! wait_for_file "$marker/started-test-guard-framework" 300; then
    fail_case "$name" "4th suite never launched after a slot freed"
    _release_all_gated; wait "$agg_pid" 2>/dev/null; return
  fi
  _release_all_gated
  wait "$agg_pid" 2>/dev/null
  status="$(cat "$marker/rc" 2>/dev/null || echo 1)"
  local out; out="$(cat "$logf" 2>/dev/null)"
  if [[ "$status" -eq 0 && "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_live_db_exclusive_suites_never_overlap() {
  # Behavior: test-pmctl-context and test-release-verify both touch the live
  #           $REPO_ROOT/.pm-dispatch/ctx/context.db, so the parallel scheduler
  #           must never run them concurrently even when slots are free.
  # Steps: gate both exclusive suites; pass-stub the rest; run --jobs 4 (slots
  #        are NOT the limiter); assert the earlier suite (test-pmctl-context)
  #        starts but test-release-verify stays held while it runs; release the
  #        first and assert the second then starts; release it; assert exit 0.
  local name="live-db-exclusive-no-overlap"
  local repo="$TMP_ROOT/$name" path status
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  local marker="$TMP_ROOT/$name-markers"; mkdir -p "$marker"
  write_gated_stub "$repo" test-pmctl-context "$marker"
  write_gated_stub "$repo" test-release-verify "$marker"
  path="$(make_path_with_codex "$repo/bin")"
  local logf="$TMP_ROOT/$name.log"
  ( PATH="$path" run_aggregator "$repo" --jobs 4 > "$logf" 2>&1; echo $? > "$marker/rc" ) &
  local agg_pid=$!

  if ! wait_for_file "$marker/started-test-pmctl-context" 300; then
    fail_case "$name" "first exclusive suite (test-pmctl-context) never started"
    touch "$marker/release-test-pmctl-context" "$marker/release-test-release-verify"
    wait "$agg_pid" 2>/dev/null; return
  fi
  # Slots are free (--jobs 4) yet the second exclusive suite must stay held while
  # the first is in-flight. If exclusion is broken it would start within ~2s.
  if wait_for_file "$marker/started-test-release-verify" 100; then
    fail_case "$name" "test-release-verify started while test-pmctl-context in-flight (exclusion broken)"
    touch "$marker/release-test-pmctl-context" "$marker/release-test-release-verify"
    wait "$agg_pid" 2>/dev/null; return
  fi
  # Release the first exclusive suite -> the second must now launch.
  touch "$marker/release-test-pmctl-context"
  if ! wait_for_file "$marker/started-test-release-verify" 300; then
    fail_case "$name" "test-release-verify never launched after test-pmctl-context finished"
    touch "$marker/release-test-release-verify"
    wait "$agg_pid" 2>/dev/null; return
  fi
  touch "$marker/release-test-release-verify"
  wait "$agg_pid" 2>/dev/null
  status="$(cat "$marker/rc" 2>/dev/null || echo 1)"
  local out; out="$(cat "$logf" 2>/dev/null)"
  if [[ "$status" -eq 0 && "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
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
test_jobs_parallel_all_pass
test_jobs_parallel_one_fail
test_jobs_parallel_skip_accounting
test_jobs_invalid_zero
test_jobs_invalid_string
test_jobs_no_arg_default
test_jobs_larger_than_suite_count
test_jobs_explicit_sequential
test_jobs_concurrency_and_max_inflight
test_jobs_default_fallback_no_nproc
test_jobs_default_uses_detected_nproc
test_live_db_exclusive_suites_never_overlap

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
