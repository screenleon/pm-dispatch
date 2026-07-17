#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

SUITE_NAMES=(
  lint-agents
  lint-scripts
  lint-script-domain-inventory
  lint-portable-repo-paths
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
  test-pmctl-pm
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
  test-run-tests
  test-timeout-resolve
  test-dispatch-common
  test-detached-launch
  test-lint-model-aliases
  test-lint-portable-repo-paths
  test-reasoning-effort
  test-core-schemas
  test-host-manifest
  test-host-write-codex
  test-host-write-opencode
  test-host-write-parity
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
  test-lint-shellcheck
  test-script-domain-inventory
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
    lint-agents) printf 'tools/lint/lint-agents.sh\n' ;;
    lint-scripts) printf 'tools/lint/lint-scripts.sh\n' ;;
    lint-script-domain-inventory) printf 'tools/lint/lint-script-domain-inventory.sh\n' ;;
    lint-portable-repo-paths) printf 'tools/lint/lint-portable-repo-paths.sh\n' ;;
    lint-test-docstrings) printf 'tools/lint/lint-test-docstrings.sh\n' ;;
    test-guards) printf 'tests/shell/test-guards.sh\n' ;;
    test-guard-framework) printf 'tests/shell/test-guard-framework.sh\n' ;;
    test-migrate) printf 'tests/shell/test-migrate-routing-log.sh\n' ;;
    test-migrate-to-events) printf 'tests/shell/test-migrate-routing-to-events.sh\n' ;;
    test-install) printf 'tests/shell/test-install.sh\n' ;;
    test-uninstall) printf 'tests/shell/test-uninstall.sh\n' ;;
    test-usage-weekly) printf 'tests/shell/test-usage-weekly.sh\n' ;;
    test-usage-tracker) printf 'tests/shell/test-usage-tracker.sh\n' ;;
    test-pm-scripts) printf 'pm/scripts/test/run-tests.sh\n' ;;
    test-codex-dispatch) printf 'tests/shell/test-codex-dispatch.sh\n' ;;
    test-pmctl-dispatch) printf 'tests/shell/test-pmctl-dispatch.sh\n' ;;
    test-pmctl-pm) printf 'tests/shell/test-pmctl-pm.sh\n' ;;
    test-dispatch-record) printf 'tests/shell/test-dispatch-record.sh\n' ;;
    test-dispatch-lifecycle) printf 'tests/shell/test-dispatch-lifecycle.sh\n' ;;
    test-gate-lifecycle) printf 'tests/shell/test-gate-lifecycle.sh\n' ;;
    test-claude-dispatch) printf 'tests/shell/test-claude-dispatch.sh\n' ;;
    test-opencode-dispatch) printf 'tests/shell/test-opencode-dispatch.sh\n' ;;
    test-layer-boundaries) printf 'tests/shell/test-layer-boundaries.sh\n' ;;
    test-executor-router) printf 'tests/shell/test-executor-router.sh\n' ;;
    test-runner-kind) printf 'tests/shell/test-runner-kind.sh\n' ;;
    test-pmctl-adapter-generate) printf 'tests/shell/test-pmctl-adapter-generate.sh\n' ;;
    test-pr-gate) printf 'tests/shell/test-pr-gate.sh\n' ;;
    test-setup-project) printf 'tests/shell/test-setup-project.sh\n' ;;
    test-patch-gitignore) printf 'tests/shell/test-patch-gitignore.sh\n' ;;
    test-portable) printf 'tests/shell/test-portable.sh\n' ;;
    test-doctor) printf 'tests/shell/test-doctor.sh\n' ;;
    test-hook-profile-parity) printf 'tests/shell/test-hook-profile-parity.sh\n' ;;
    test-lint-frontmatter) printf 'tests/shell/test-lint-frontmatter.sh\n' ;;
    test-lint-test-docstrings) printf 'tests/shell/test-lint-test-docstrings.sh\n' ;;
    test-test-harness) printf 'tests/shell/test-test-harness.sh\n' ;;
    test-check-docs-freshness) printf 'tests/shell/test-check-docs-freshness.sh\n' ;;
    test-commands) printf 'tests/shell/test-commands.sh\n' ;;
    test-commands-runner) printf 'tests/shell/test-commands-runner.sh\n' ;;
    test-dispatch-handover) printf 'tests/shell/test-dispatch-handover.sh\n' ;;
    test-handover-validate) printf 'tests/shell/test-handover-validate.sh\n' ;;
    test-dispatch-post-verify) printf 'tests/shell/test-dispatch-post-verify.sh\n' ;;
    test-skill-refine) printf 'tests/shell/test-skill-refine.sh\n' ;;
    test-pr-gate-profile) printf 'tests/shell/test-pr-gate-profile.sh\n' ;;
    test-run-all-tests) printf 'tests/shell/test-run-all-tests.sh\n' ;;
    test-run-tests) printf 'tests/shell/test-run-tests.sh\n' ;;
    test-timeout-resolve) printf 'tests/shell/test-timeout-resolve.sh\n' ;;
    test-dispatch-common) printf 'tests/shell/test-dispatch-common.sh\n' ;;
    test-detached-launch) printf 'tests/shell/test-detached-launch.sh\n' ;;
    test-lint-model-aliases) printf 'tests/shell/test-lint-model-aliases.sh\n' ;;
    test-lint-portable-repo-paths) printf 'tests/shell/test-lint-portable-repo-paths.sh\n' ;;
    test-reasoning-effort) printf 'tests/shell/test-reasoning-effort.sh\n' ;;
    test-host-manifest)   printf 'tests/shell/test-host-manifest.sh\n' ;;
    test-host-write-codex) printf 'tests/shell/test-host-write-codex.sh\n' ;;
    test-host-write-opencode) printf 'tests/shell/test-host-write-opencode.sh\n' ;;
    test-host-write-parity) printf 'tests/shell/test-host-write-parity.sh\n' ;;
    test-core-schemas) printf 'tests/shell/test-core-schemas.sh\n' ;;
    test-pm-prep-snapshot) printf 'tests/shell/test-pm-prep-snapshot.sh\n' ;;
    test-schema-task-mirrors-backlog) printf 'tests/shell/test-schema-task-mirrors-backlog.sh\n' ;;
    test-state-store) printf 'tests/shell/test-state-store.sh\n' ;;
    test-state-paths) printf 'tests/shell/test-state-paths.sh\n' ;;
    test-pmctl-artifacts) printf 'tests/shell/test-pmctl-artifacts.sh\n' ;;
    test-state-layout-parity) printf 'tests/shell/test-state-layout-parity.sh\n' ;;
    test-state-store-rotation) printf 'tests/shell/test-state-store-rotation.sh\n' ;;
    test-pmctl-trace) printf 'tests/shell/test-pmctl-trace.sh\n' ;;
    test-pmctl-task) printf 'tests/shell/test-pmctl-task.sh\n' ;;
    test-pmctl-decision) printf 'tests/shell/test-pmctl-decision.sh\n' ;;
    test-pmctl-gate) printf 'tests/shell/test-pmctl-gate.sh\n' ;;
    test-pmctl-safe) printf 'tests/shell/test-pmctl-safe.sh\n' ;;
    test-pmctl-validate) printf 'tests/shell/test-pmctl-validate.sh\n' ;;
    test-brief-validate) printf 'tests/shell/test-brief-validate.sh\n' ;;
    test-archive-closed-backlog) printf 'tests/shell/test-archive-closed-backlog.sh\n' ;;
    test-lint-shellcheck) printf 'tests/shell/test-lint-shellcheck.sh\n' ;;
    test-script-domain-inventory) printf 'tests/shell/test-script-domain-inventory.sh\n' ;;
    test-pmctl-context)  printf 'tests/shell/test-pmctl-context.sh\n' ;;
    test-pmctl-memory)   printf 'tests/shell/test-pmctl-memory.sh\n' ;;
    test-pmctl-backlog)   printf 'tests/shell/test-pmctl-backlog.sh\n' ;;
    test-pmctl-guard)     printf 'tests/shell/test-pmctl-guard.sh\n' ;;
    test-pmctl-ship)      printf 'tests/shell/test-pmctl-ship.sh\n' ;;
    test-pmctl-worktree)  printf 'tests/shell/test-pmctl-worktree.sh\n' ;;
    test-pre-release)     printf 'tests/shell/test-pre-release.sh\n' ;;
    test-release-verify)  printf 'tests/shell/test-release-verify.sh\n' ;;
    test-e2e-script)      printf 'tests/shell/test-e2e-script.sh\n' ;;
    *) return 1 ;;
  esac
}

make_fixture_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts/lib" "$repo/runtime/lib" "$repo/tests/bin" "$repo/tests/lib" \
    "$repo/pm/scripts/test" "$repo/core/schema"
  cp "$REPO_ROOT/tests/bin/run-all-tests.sh" "$repo/tests/bin/run-all-tests.sh"
  cp "$REPO_ROOT/tests/bin/run-tests.sh" "$repo/tests/bin/run-tests.sh"
  cp "$SCRIPT_DIR/../lib/test-suite-runner.sh" "$repo/tests/lib/test-suite-runner.sh"
  cp "$SCRIPT_DIR/../lib/test-result.sh" "$repo/tests/lib/test-result.sh"
  cp "$REPO_ROOT/runtime/lib/artifact-paths.sh" "$repo/runtime/lib/artifact-paths.sh"
  cp "$REPO_ROOT/core/schema/test-result.schema.json" "$repo/core/schema/test-result.schema.json"
  chmod +x "$repo/tests/bin/run-all-tests.sh" "$repo/tests/bin/run-tests.sh" "$repo/tests/lib/test-suite-runner.sh"
  git -C "$repo" init -q
  git -C "$repo" add .
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
  local bin="$1" cmd
  mkdir -p "$bin"
  # Keep the runner/test-result dependencies but deliberately omit codex.
  for cmd in bash dirname mktemp mkdir cat rm sleep timeout git jq sha256sum awk sort readlink date mv chmod; do
    ln -s "$(command -v "$cmd")" "$bin/$cmd"
  done
  if command -v nproc >/dev/null 2>&1; then ln -s "$(command -v nproc)" "$bin/nproc"; fi
  printf '%s\n' "$bin"
}

make_path_without_timeout() {
  # Keep only the startup utilities the aggregator needs before its timeout
  # prerequisite check. Deliberately omit both timeout and gtimeout.
  local bin="$1"
  mkdir -p "$bin"
  ln -s /usr/bin/bash "$bin/bash"
  ln -s /usr/bin/dirname "$bin/dirname"
  printf '%s\n' "$bin"
}

make_path_with_gtimeout_only() {
  # Exercise fallback selection without claiming a macOS integration test: the
  # shim delegates to this Linux host's GNU timeout, while PATH has no timeout.
  local bin="$1" marker="$2" timeout_bin cmd
  timeout_bin="$(command -v timeout)"
  mkdir -p "$bin"
  printf '#!/bin/sh\n: > %s\nexec %s "$@"\n' "$marker" "$timeout_bin" > "$bin/gtimeout"
  chmod +x "$bin/gtimeout"
  printf '#!/bin/sh\nexit 0\n' > "$bin/codex"
  chmod +x "$bin/codex"
  for cmd in bash dirname mktemp mkdir cat rm sleep git jq sha256sum awk sort readlink date mv chmod; do
    ln -s "$(command -v "$cmd")" "$bin/$cmd"
  done
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

wait_for_log_pattern() {
  local file="$1" pattern="$2" tries="${3:-300}" i=0
  while ! grep -q "$pattern" "$file" 2>/dev/null; do
    i=$((i + 1))
    [[ "$i" -ge "$tries" ]] && return 1
    sleep 0.02
  done
  return 0
}

run_aggregator() {
  local repo="$1"
  shift
  bash "$repo/tests/bin/run-all-tests.sh" "$@" 2>&1
}

test_list() {
  local name="list"
  # Behavior: --list prints all registered suite names and exits 0.
  # Steps: invoke --list; assert each SUITE_NAMES entry appears in output.
  local out status=0 suite
  out=$(bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --list 2>&1) || status=$?
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
  out=$(bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --list 2>&1) || status=$?
  actual_count="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  if [[ "$status" -eq 0 && "$SUITE_TOTAL" -eq "$expected_count" && "$actual_count" -eq "$expected_count" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status SUITE_TOTAL=$SUITE_TOTAL listed=$actual_count expected=$expected_count out=$out"
  fi
}

test_suite_filter_list() {
  local name="suite-filter-list"
  # Behavior: repeated --suite flags select known suites in registry order for --list.
  # Steps: request two suites in reverse order; assert only those two are listed in canonical order.
  local out status=0
  out=$(bash "$SCRIPT_DIR/../lib/test-suite-runner.sh" --suite test-pr-gate --suite lint-agents --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == $'lint-agents\ntest-pr-gate' ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_suite_filter_runs_only_selected() {
  local name="suite-filter-runs-only-selected"
  # Behavior: --suite runs only the positive selection and does not count all other suites as skipped.
  # Steps: pass-stub all suites; select lint-agents; assert exactly one pass and no unrelated START line.
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" bash "$repo/tests/lib/test-suite-runner.sh" --suite lint-agents 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"1 passed, 0 failed, 0 skipped"* &&
        "$out" == *"START lint-agents"* && "$out" != *"START lint-scripts"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_suite_filter_rejects_unknown() {
  local name="suite-filter-rejects-unknown"
  # Behavior: an unknown --suite value fails before any suite starts.
  # Steps: request a typo; assert exit 2 and a precise diagnostic with no START output.
  local out status=0
  out=$(bash "$SCRIPT_DIR/../lib/test-suite-runner.sh" --suite does-not-exist 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"unknown suite requested by --suite: does-not-exist"* &&
        "$out" != *"START "* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
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
  out=$(PATH="$path" bash "$repo/tests/bin/run-all-tests.sh" 2>&1) || status=$?
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
  out=$(bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --skip 2>&1) || status=$?
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
  out=$(bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --foobar 2>&1) || status=$?
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

  local hooks_path="$repo/tests/shell/test-guards.sh"
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

  local install_path="$repo/tests/shell/test-install.sh"
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
  out=$(bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --jobs 0 2>&1) || status=$?
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
  out=$(bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --jobs abc 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"--jobs requires a positive integer"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_suite_timeout_invalid_zero() {
  # Behavior: --suite-timeout 0 exits 2 because a suite deadline must be positive.
  # Steps: invoke the aggregator with zero; assert the flag-specific validation message.
  local name="suite-timeout-invalid-zero"
  local out status=0
  out=$(bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --suite-timeout 0 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"--suite-timeout requires a positive integer"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_timeout_binary_missing_fails_loudly() {
  # Behavior: no timeout or gtimeout binary fails closed before any suite starts.
  # Steps: use a minimal PATH deliberately lacking both binaries; invoke --list;
  #        assert exit 2 and the actionable prerequisite diagnostic.
  local name="timeout-binary-missing-fails-loudly"
  local path out status=0
  path="$(make_path_without_timeout "$TMP_ROOT/$name-bin")"
  out=$(PATH="$path" bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --list 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"requires GNU timeout (timeout or gtimeout)"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_gtimeout_fallback_runs_suites() {
  # Behavior: when timeout is absent but gtimeout exists, the runner selects gtimeout.
  # Steps: use a PATH with a marker-writing GNU-timeout shim named only gtimeout; pass-stub
  #        every suite; assert all suites pass and the shim was invoked at least once.
  local name="gtimeout-fallback-runs-suites"
  local repo="$TMP_ROOT/$name" path marker out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  marker="$TMP_ROOT/$name-gtimeout-used"
  path="$(make_path_with_gtimeout_only "$repo/bin" "$marker")"
  out=$(PATH="$path" run_aggregator "$repo" --jobs 1 2>&1) || status=$?
  if [[ "$status" -eq 0 && -e "$marker" &&
        "$out" == *"$SUITE_TOTAL passed, 0 failed, 0 skipped"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status gtimeout_used=$([[ -e "$marker" ]] && echo yes || echo no) out=$out"
  fi
}

test_suite_timeout_fails_loudly() {
  # Behavior: a suite exceeding --suite-timeout is failed with an explicit timeout marker.
  # Steps: make lint-agents sleep past a one-second deadline; pass-stub every other suite;
  #        run sequentially and assert the aggregate finishes non-zero, names the timed-out
  #        suite, and preserves the timeout diagnostic for a gate log reader.
  local name="suite-timeout-fails-loudly"
  local repo="$TMP_ROOT/$name" path out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  local slow_stub
  slow_stub="$repo/$(suite_path lint-agents)"
  printf '#!/bin/sh\nsleep 2\n' > "$slow_stub"
  chmod +x "$slow_stub"
  path="$(make_path_with_codex "$repo/bin")"
  out=$(PATH="$path" run_aggregator "$repo" --jobs 1 --suite-timeout 1 2>&1) || status=$?
  if [[ "$status" -ne 0 && "$out" == *"TIMEOUT lint-agents (1s)"* &&
        "$out" == *"FAIL lint-agents"* && "$out" == *"failed suites:"*"lint-agents"* ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out"
  fi
}

test_suite_result_artifact_records_ordered_outcomes() {
  # Behavior: the internal result sink records registry-ordered per-suite
  # pass/fail outcomes with exit codes and durations in machine-readable JSON.
  # Steps: run two selected stubs in parallel with one failure; assert the
  # result array preserves registry order and captures both outcomes exactly.
  local name="suite-result-artifact-records-ordered-outcomes"
  local repo="$TMP_ROOT/$name" path result out status=0
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  write_suite_stub "$repo" lint-scripts 7
  path="$(make_path_with_codex "$repo/bin")"
  result="$TMP_ROOT/$name.json"
  out=$(PATH="$path" PM_TEST_SUITE_RESULTS_FILE="$result" \
    "$repo/tests/lib/test-suite-runner.sh" --suite lint-agents --suite lint-scripts --jobs 2 2>&1) || status=$?
  if [[ "$status" -ne 0 ]] && jq -e '
      [.[].name] == ["lint-agents","lint-scripts"] and
      .[0].status == "pass" and .[0].exit_code == 0 and
      .[1].status == "fail" and .[1].exit_code == 7 and
      (all(.[]; (.duration_seconds | type == "number" and . >= 0)))
    ' "$result" >/dev/null 2>&1; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out result=$(cat "$result" 2>/dev/null)"
  fi
}

test_suite_result_artifact_records_timeout() {
  # Behavior: a per-suite deadline is represented as timeout rather than a
  # generic failure in the machine-readable result artifact.
  # Steps: run one sleeping suite with a one-second deadline; assert exit 124,
  # timeout status, and a non-negative duration in the emitted JSON.
  local name="suite-result-artifact-records-timeout"
  local repo="$TMP_ROOT/$name" path result out status=0 slow_stub
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  slow_stub="$repo/$(suite_path lint-agents)"
  printf '#!/bin/sh\nsleep 2\n' > "$slow_stub"
  chmod +x "$slow_stub"
  path="$(make_path_with_codex "$repo/bin")"
  result="$TMP_ROOT/$name.json"
  out=$(PATH="$path" PM_TEST_SUITE_RESULTS_FILE="$result" \
    "$repo/tests/lib/test-suite-runner.sh" --suite lint-agents --jobs 1 --suite-timeout 1 2>&1) || status=$?
  if [[ "$status" -ne 0 ]] && jq -e '
      length == 1 and .[0].name == "lint-agents" and
      .[0].status == "timeout" and .[0].exit_code == 124 and .[0].duration_seconds >= 0
    ' "$result" >/dev/null 2>&1; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out result=$(cat "$result" 2>/dev/null)"
  fi
}

test_result_sinks_do_not_leak_into_suites() {
  # Behavior: gate and suite result-sink variables belong to the outer runner
  # and are absent from suite processes, including suites that launch another
  # run-tests instance.
  # Steps: make one selected stub fail if either sink is non-empty; invoke the
  # runner with both outer sinks set; assert the suite passes and the parent
  # still writes its own ordered result artifact.
  local name="result-sinks-do-not-leak-into-suites"
  local repo="$TMP_ROOT/$name" path result outer out status=0 stub
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  stub="$repo/$(suite_path lint-agents)"
  cat > "$stub" <<'STUB'
#!/bin/sh
[ -z "${PM_TEST_SUITE_RESULTS_FILE:-}" ] || exit 31
[ -z "${PM_DISPATCH_PREFLIGHT_TEST_RESULT:-}" ] || exit 32
exit 0
STUB
  chmod +x "$stub"
  path="$(make_path_with_codex "$repo/bin")"
  result="$TMP_ROOT/$name.json"
  outer="$TMP_ROOT/$name-outer.json"
  out=$(PATH="$path" PM_TEST_SUITE_RESULTS_FILE="$result" PM_DISPATCH_PREFLIGHT_TEST_RESULT="$outer" \
    "$repo/tests/lib/test-suite-runner.sh" --suite lint-agents --jobs 1 2>&1) || status=$?
  if [[ "$status" -eq 0 ]] && jq -e '
      length == 1 and .[0].name == "lint-agents" and .[0].status == "pass"
    ' "$result" >/dev/null 2>&1 && [[ ! -e "$outer" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$out result=$(cat "$result" 2>/dev/null)"
  fi
}

test_parallel_progress_reports_slow_suite() {
  # Behavior: a still-running parallel suite emits one visible progress line before it finishes.
  # Steps: block the first suite, set the progress interval to one second, wait past it, and
  #        assert the aggregate log identifies the suite and elapsed time; release and finish.
  local name="parallel-progress-reports-slow-suite"
  local repo="$TMP_ROOT/$name" path status
  make_fixture_repo "$repo"
  write_pass_stubs "$repo"
  local marker="$TMP_ROOT/$name-markers"; mkdir -p "$marker"
  write_gated_stub "$repo" lint-agents "$marker"
  path="$(make_path_with_codex "$repo/bin")"
  local logf="$TMP_ROOT/$name.log"
  ( PM_DISPATCH_TEST_PROGRESS_SECS=1 PATH="$path" run_aggregator "$repo" --jobs 2 > "$logf" 2>&1; echo $? > "$marker/rc" ) &
  local agg_pid=$!

  if ! wait_for_file "$marker/started-lint-agents" 300; then
    fail_case "$name" "blocked suite never started"
    touch "$marker/release-lint-agents"
    wait "$agg_pid" 2>/dev/null; return
  fi
  if ! wait_for_log_pattern "$logf" 'RUNNING lint-agents (.*s)' 300; then
    fail_case "$name" "missing progress line: $(cat "$logf" 2>/dev/null)"
    touch "$marker/release-lint-agents"
    wait "$agg_pid" 2>/dev/null; return
  fi
  touch "$marker/release-lint-agents"
  wait "$agg_pid" 2>/dev/null
  status="$(cat "$marker/rc" 2>/dev/null || echo 1)"
  if [[ "$status" -eq 0 ]]; then
    pass_case "$name"
  else
    fail_case "$name" "status=$status out=$(cat "$logf" 2>/dev/null)"
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
  # Behavior: below the safety cap, default parallelism equals detected nproc.
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
test_suite_filter_list
test_suite_filter_runs_only_selected
test_suite_filter_rejects_unknown
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
test_suite_timeout_invalid_zero
test_timeout_binary_missing_fails_loudly
test_gtimeout_fallback_runs_suites
test_suite_timeout_fails_loudly
test_suite_result_artifact_records_ordered_outcomes
test_suite_result_artifact_records_timeout
test_result_sinks_do_not_leak_into_suites
test_parallel_progress_reports_slow_suite
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
