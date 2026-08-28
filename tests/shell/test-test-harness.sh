#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LC_ALL=C.UTF-8

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"

PASS_COUNT=0
FAIL_COUNT=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Uses own pass_case/fail_case counter (not harness pass/fail): tests the harness itself via subprocess probes.
pass_case() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

fail_case() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED_CASES+=("$1")
  printf 'FAIL: %s: %s\n' "$1" "$2"
}

assert_file_equals() {
  local name="$1" actual="$2" expected="$3"
  local expected_file="$TMP_ROOT/$name.expected"
  printf '%s\n' "$expected" > "$expected_file"
  if ! cmp -s "$actual" "$expected_file"; then
    fail_case "$name" "output mismatch: expected=$(cat "$expected_file") actual=$(cat "$actual")"
    return 1
  fi
}

run_harness_probe() {
  local name="$1" expected_rc="$2" expected_out="$3" expected_err="$4" code="$5"
  local out err rc
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"

  set +e
  bash -c "$code" > "$out" 2> "$err"
  rc=$?
  set -e

  if [[ "$rc" -ne "$expected_rc" ]]; then
    fail_case "$name" "expected rc=$expected_rc, got rc=$rc"
    return 1
  fi
  if [[ -n "$expected_out" ]]; then
    assert_file_equals "$name" "$out" "$expected_out" || return 1
  fi
  if [[ -n "$expected_err" ]]; then
    assert_file_equals "$name.err" "$err" "$expected_err" || return 1
  fi
  pass_case "$name"
}

case_harness_should_run_empty_filter() {
  local name="test-harness-should-run-empty-filter"
  if th_init && should_run "portable-realpath-m-existing-absolute-file"; then
    pass_case "$name"
  else
    fail_case "$name" "should_run with empty filter returned false"
  fi
}

case_harness_should_run_filter_match() {
  local name="test-harness-should-run-filter"
  local rc_match=1
  local rc_nonmatch=0
  th_init --filter "foo"
  should_run "portable-foo-case" && rc_match=0 || rc_match=$?
  should_run "portable-bar-case" && rc_nonmatch=0 || rc_nonmatch=$?
  if [[ "$rc_match" -eq 0 && "$rc_nonmatch" -eq 1 ]]; then
    pass_case "$name"
  else
    fail_case "$name" "match rc=$rc_match non-match rc=$rc_nonmatch"
  fi
}

case_harness_should_run_list_records_case() {
  local name="test-harness-should-run-list"
  local rc_match
  local listed
  th_init --list
  if should_run "portable-list-case"; then
    rc_match=0
  else
    rc_match=$?
  fi
  listed="${ALL_CASES[0]:-}"
  if [[ "$rc_match" -ne 0 && "$listed" == "portable-list-case" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc_match listed='${listed}'"
  fi
}

case_harness_pass_fail_counters() {
  local name="test-harness-pass-fail-counters"
  th_init
  pass "example-pass"
  fail "example-fail" "reason"
  if [[ "$PASS" -eq 1 && "$FAIL" -eq 1 ]]; then
    pass_case "$name"
  else
    fail_case "$name" "PASS=$PASS FAIL=$FAIL"
  fi
}

case_harness_summary_exit_code_zero() {
  local name="test-harness-summary-exit-0"
  local rc
  (
    th_init
    th_summary
  ) || rc=$?
  rc=${rc:-0}
  if [[ "$rc" -eq 0 ]]; then
    pass_case "$name"
  else
    fail_case "$name" "expected exit 0, got $rc"
  fi
}

case_harness_summary_exit_code_one() {
  local name="test-harness-summary-exit-1"
  local rc
  (
    th_init
    fail "example-fail" "reason"
    th_summary
  ) || rc=$?
  rc=${rc:-0}
  if [[ "$rc" -eq 1 ]]; then
    pass_case "$name"
  else
    fail_case "$name" "expected exit 1, got $rc"
  fi
}

case_harness_summary_no_match_filter() {
  local name="test-harness-filter-no-match"
  local rc
  (
    th_init --filter "definitely-missing"
    th_summary
  ) || rc=$?
  rc=${rc:-0}
  if [[ "$rc" -eq 1 ]]; then
    pass_case "$name"
  else
    fail_case "$name" "expected exit 1, got $rc"
  fi
}

# --- case-level skip() primitive (test-governance Batch 1) ------------------

# Behavior: skip() with a reason increments SKIP (not PASS), records the reason,
# and does not touch FAIL.
case_harness_skip_counter() {
  local name="test-harness-skip-counter"
  th_init
  pass "sc-p"
  skip "sc-s" "dep absent"
  if [[ "$PASS" -eq 1 && "$SKIP" -eq 1 && "$FAIL" -eq 0 \
        && "${SKIPPED_CASES[0]:-}" == "sc-s: dep absent" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "PASS=$PASS SKIP=$SKIP FAIL=$FAIL skipped='${SKIPPED_CASES[0]:-}'"
  fi
}

# Behavior: a reasonless skip is recorded as a failure, never a silent pass.
case_harness_skip_without_reason_fails() {
  local name="test-harness-skip-no-reason"
  th_init
  skip "sr-x" ""
  if [[ "$SKIP" -eq 0 && "$FAIL" -eq 1 && "${FAILED_CASES[0]:-}" == "sr-x" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "SKIP=$SKIP FAIL=$FAIL failed='${FAILED_CASES[0]:-}'"
  fi
}

# Behavior: th_summary reports "N passed, M failed, K skipped" and a skip alone
# does not change the exit code (a skip is not a failure).
case_harness_summary_counts_skips_exit_zero() {
  local name="test-harness-summary-skip-exit-0"
  local out="$TMP_ROOT/$name.out" rc
  (
    th_init
    pass "ss-p"
    skip "ss-s" "dep absent"
    th_summary
  ) > "$out" 2>&1 || rc=$?
  rc=${rc:-0}
  if [[ "$rc" -eq 0 ]] \
    && grep -qx '1 passed, 0 failed, 1 skipped' "$out" \
    && grep -q 'skipped cases:' "$out" \
    && grep -q '  ss-s: dep absent' "$out"; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc out=$(cat "$out")"
  fi
}

# Behavior: a skip does not mask a real failure -- exit stays 1.
case_harness_skip_does_not_mask_failure() {
  local name="test-harness-skip-plus-fail-exit-1"
  local out="$TMP_ROOT/$name.out" rc
  (
    th_init
    skip "sf-s" "dep absent"
    fail "sf-f" "boom"
    th_summary
  ) > "$out" 2>&1 || rc=$?
  rc=${rc:-0}
  if [[ "$rc" -eq 1 ]] && grep -qx '0 passed, 1 failed, 1 skipped' "$out"; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc out=$(cat "$out")"
  fi
}

# Behavior: a --filter that selects only a skipped case is not "no tests matched".
case_harness_filter_only_skip_is_not_no_match() {
  local name="test-harness-filter-only-skip"
  local out="$TMP_ROOT/$name.out" rc
  (
    th_init --filter "keep"
    should_run "keepme" && skip "keepme" "dep absent"
    should_run "dropme" && pass "dropme"
    th_summary
  ) > "$out" 2>&1 || rc=$?
  rc=${rc:-0}
  if [[ "$rc" -eq 0 ]] \
    && grep -qx '0 passed, 0 failed, 1 skipped' "$out" \
    && ! grep -q 'no tests matched filter' "$out"; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc out=$(cat "$out")"
  fi
}

# Behavior: with PM_TEST_CASE_SKIPS_FILE set, th_summary appends the suite's
# total skip count once; with it unset, skip() still works and the suite still
# exits 0.
case_harness_case_skips_file_gets_count() {
  local name="test-harness-case-skips-file"
  local csfile="$TMP_ROOT/$name.cs" unset_out="$TMP_ROOT/$name.unset" rc1 rc2
  : > "$csfile"
  (
    export PM_TEST_CASE_SKIPS_FILE="$csfile"
    th_init
    pass "cf-p"
    skip "cf-a" "dep1 absent"
    skip "cf-b" "dep2 absent"
    th_summary
  ) >/dev/null 2>&1 || rc1=$?
  rc1=${rc1:-0}
  (
    unset PM_TEST_CASE_SKIPS_FILE
    th_init
    skip "cf-c" "dep absent"
    th_summary
  ) > "$unset_out" 2>&1 || rc2=$?
  rc2=${rc2:-0}
  if [[ "$rc1" -eq 0 && "$rc2" -eq 0 ]] \
    && [[ "$(cat "$csfile")" == "2" ]] \
    && grep -qx '0 passed, 0 failed, 1 skipped' "$unset_out"; then
    pass_case "$name"
  else
    fail_case "$name" "rc1=$rc1 rc2=$rc2 cs='$(cat "$csfile" 2>/dev/null)' unset_out=$(cat "$unset_out")"
  fi
}

# Behavior: when PM_TEST_CASE_SKIPS_FILE is set but the append fails (unwritable
# sink), a suite with a skip must exit non-zero and print a diagnostic -- a lost
# count would let the runner emit a silently false authoritative PASS. When the
# variable is unset there is no sink and no failure.
case_harness_case_skips_write_failure_fails_suite() {
  local name="test-harness-case-skips-write-failure-fails"
  local out="$TMP_ROOT/$name.out" rc
  (
    export PM_TEST_CASE_SKIPS_FILE="$TMP_ROOT/$name/no-such-dir/sink"
    th_init
    skip "wf-a" "dep absent"
    th_summary
  ) > "$out" 2>&1 || rc=$?
  rc=${rc:-0}
  if [[ "$rc" -ne 0 ]] && grep -q 'could not record .* case skip' "$out"; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc out=$(cat "$out")"
  fi
}

# Behavior: the sample sites migrated in this slice call skip(), not
# pass-as-skip -- a regression that reverts one should fail here.
case_harness_migrated_sample_sites_use_skip() {
  local name="test-harness-migrated-sites-use-skip"
  local root bad=0
  root="$(cd "$SCRIPT_DIR/.." && pwd)"
  grep -q 'skip "$name" "perl not on PATH' "$root/shell/test-detached-launch.sh" || bad=1
  grep -q 'skip "$name" "sqlite3 not on PATH' "$root/shell/test-pmctl-pm.sh" || bad=1
  grep -q 'skip "$name" "filesystem does not preserve symlinks' "$root/shell/test-state-store.sh" || bad=1
  grep -q 'skip "$name" "platform/filesystem cannot create a hardlink' "$root/shell/test-pmctl-context.sh" || bad=1
  grep -q 'skip "$name" "jq not on PATH (cannot inspect the pack JSON)' "$root/shell/test-pmctl-context.sh" || bad=1
  grep -q 'skip "$name" "jq unavailable in the isolated PATH fixture' "$root/shell/test-doctor.sh" || bad=1
  if [[ "$bad" -eq 0 ]]; then
    pass_case "$name"
  else
    fail_case "$name" "a migrated skip() call site is missing or reverted to pass-as-skip"
  fi
}

# Behavior: every variable the canonical inventory marks fixture_scrub=yes is
# cleared from a suite's environment, no matter what the caller exported.
# Steps: export each declared name in a child shell, source the harness, and
# assert none survived.
# A test that asserts a DEFAULT measures the caller's environment unless this
# holds, and the resulting failure names a default the subject was never at --
# the CC-561 failure this isolation exists to end.
case_fixture_inputs_are_cleared() {
  local name="fixture-inputs-are-cleared"
  local repo_root names probe survivors n
  local -a env_args=()
  repo_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  # shellcheck source=tests/lib/test-env-isolation.sh
  # shellcheck disable=SC1091 # CI runs shellcheck without -x; the source= hint above names the file.
  . "$repo_root/tests/lib/test-env-isolation.sh"
  names="$(test_env_fixture_input_names "$repo_root")"
  if [[ -z "$names" ]]; then
    fail_case "$name" "inventory declares no fixture_scrub entries to prove"
    return
  fi
  while IFS= read -r n; do
    [[ -n "$n" && "$n" != *'*' ]] || continue
    env_args+=("$n=leaked-from-caller")
  done <<< "$names"

  # The probe re-derives the names from the same inventory rather than being
  # handed a list, so a scrub that silently covers fewer names than the
  # inventory declares is still caught.
  probe="$TMP_ROOT/fixture-scrub-probe.sh"
  cat > "$probe" <<PROBE
#!/usr/bin/env bash
set -uo pipefail
. "$repo_root/tests/lib/test-harness.sh"
th_init
while IFS= read -r probe_name; do
  [[ -n "\$probe_name" && "\$probe_name" != *'*' ]] || continue
  [[ -n "\${!probe_name:-}" ]] && printf '%s\n' "\$probe_name"
done < <(test_env_fixture_input_names "$repo_root")
exit 0
PROBE

  survivors="$(env "${env_args[@]}" bash "$probe" 2>/dev/null)"
  if [[ -z "$survivors" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "survived the scrub: $(printf '%s' "$survivors" | tr '\n' ' ')"
  fi
}

# Behavior: a pattern row clears every currently-set variable sharing its
# prefix, not just a name spelled with a literal asterisk.
# Steps: declare a PREFIX_* row in an isolated inventory, export two matching
# variables plus one that only looks similar, and assert exactly the two are
# cleared.
# Unsetting the literal name would clear nothing and still report success, so
# without this the pattern form is isolation that silently does not happen.
case_fixture_isolation_expands_pattern_rows() {
  local name="fixture-isolation-expands-pattern-rows"
  local repo_root fake_root inventory probe survivors
  repo_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  fake_root="$TMP_ROOT/pattern-row-repo"
  inventory="$fake_root/docs/architecture/script-variable-inventory.tsv"
  mkdir -p "$(dirname "$inventory")"
  {
    head -n 1 "$repo_root/docs/architecture/script-variable-inventory.tsv"
    printf 'PM_PATTERN_PROBE_*	test-harness	test-injection	unset	explicit env only	none	none	clear after each case	yes
'
  } > "$inventory"

  probe="$TMP_ROOT/pattern-probe.sh"
  cat > "$probe" <<PROBE
#!/usr/bin/env bash
set -uo pipefail
. "$repo_root/tests/lib/test-env-isolation.sh"
test_env_scrub_fixture_inputs "$fake_root" || exit 1
for probe_name in PM_PATTERN_PROBE_ONE PM_PATTERN_PROBE_TWO PM_PATTERN_OTHER; do
  [[ -n "\${!probe_name:-}" ]] && printf '%s\n' "\$probe_name"
done
exit 0
PROBE

  survivors="$(env PM_PATTERN_PROBE_ONE=leaked PM_PATTERN_PROBE_TWO=leaked \
    PM_PATTERN_OTHER=kept bash "$probe" 2>/dev/null)"
  # PM_PATTERN_OTHER shares no prefix with the declared row, so a scrub that
  # cleared it would be over-broad -- the assertion pins both directions.
  if [[ "$survivors" == "PM_PATTERN_OTHER" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "expected only PM_PATTERN_OTHER to survive, got: $(printf '%s' "$survivors" | tr '\n' ' ')"
  fi
}

# Behavior: the isolation module fails closed when the inventory is readable but
# declares nothing to scrub, instead of reporting isolation over an empty set.
# Steps: build an isolated inventory whose every row sets fixture_scrub=no, run
# the scrub against it, and assert a non-zero exit naming the empty declaration.
# This is the second of the module's two fail-closed guards. The unreadable-file
# guard below covers the other; without this one, deleting the declared-count
# check would restore false isolation while every existing test stayed green.
case_fixture_isolation_rejects_empty_declaration() {
  local name="fixture-isolation-rejects-empty-declaration"
  local repo_root fake_root inventory rc=0 err
  repo_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  fake_root="$TMP_ROOT/empty-declaration-repo"
  inventory="$fake_root/docs/architecture/script-variable-inventory.tsv"
  mkdir -p "$(dirname "$inventory")"
  {
    head -n 1 "$repo_root/docs/architecture/script-variable-inventory.tsv"
    printf 'PM_EXAMPLE_ONLY	test-harness	test-config	unset	explicit env only	none	none	none	no
'
  } > "$inventory"

  err="$(bash -c ". '$repo_root/tests/lib/test-env-isolation.sh'; test_env_scrub_fixture_inputs '$fake_root'" 2>&1)" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    fail_case "$name" "an inventory with no fixture_scrub=yes rows was reported as isolated"
  elif [[ "$err" != *"declares no fixture_scrub entries"* ]]; then
    fail_case "$name" "exit was non-zero but the diagnostic did not name the empty declaration: $err"
  else
    pass_case "$name"
  fi
}

# Behavior: the isolation module fails closed when it cannot read the canonical
# inventory, instead of reporting isolation it never applied.
# Steps: point it at a missing repo root and assert a non-zero exit.
# A silent no-op here would recreate the original defect while looking healthy.
case_fixture_isolation_fails_closed() {
  local name="fixture-isolation-fails-closed"
  local repo_root rc=0
  repo_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  bash -c ". '$repo_root/tests/lib/test-env-isolation.sh'; test_env_scrub_fixture_inputs '$TMP_ROOT/definitely-not-a-repo'" \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass_case "$name"
  else
    fail_case "$name" "unreadable inventory was reported as isolated"
  fi
}

case_harness_preset_colon_flat() {
  local name="preset-colon-flat"
  local expected_out expected_err
  expected_out=$'PASS: foo\nFAIL: bar: detail\n1 passed, 1 failed, 0 skipped\nfailed cases: bar'
  expected_err=''
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=colon-flat; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_colon_mixed() {
  local name="preset-colon-mixed"
  local expected_out expected_err
  expected_out=$'PASS: foo\n  FAIL  bar\n        detail\n1 passed, 1 failed, 0 skipped\nfailed cases: bar'
  expected_err=''
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=colon-mixed; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_indent_1sp() {
  local name="preset-indent-1sp-verbose"
  local expected_on expected_on_err expected_off expected_off_err
  expected_off=$'  FAIL bar\n        detail\n0 passed, 1 failed, 0 skipped\nfailed cases: bar'
  expected_off_err=''
  expected_on=$'  PASS foo\n  FAIL bar\n        detail\n1 passed, 1 failed, 0 skipped\nfailed cases: bar'
  expected_on_err=''
  run_harness_probe "${name}-off" 1 "$expected_off" "$expected_off_err" \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-1sp; fail 'bar' 'detail'; th_summary"
  run_harness_probe "$name" 1 "$expected_on" "$expected_on_err" \
    "VERBOSE=1; source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-1sp; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_indent_2sp() {
  local name="preset-indent-2sp"
  local expected_out expected_err
  expected_out=$'  PASS  foo\n  FAIL  bar\n        detail\n1 passed, 1 failed, 0 skipped\nfailed cases: bar'
  expected_err=''
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "VERBOSE=1; source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-2sp; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_indent_2sp_quiet() {
  local name="preset-indent-2sp-quiet"
  local expected_on expected_off
  expected_off=$'  FAIL  bar\ndetail\n1 passed, 1 failed, 0 skipped\nfailed cases: bar'
  expected_on=$'  PASS  foo\n  FAIL  bar\ndetail\n1 passed, 1 failed, 0 skipped\nfailed cases: bar'
  run_harness_probe "${name}-off" 1 "$expected_off" '' \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-2sp-quiet; pass 'foo'; fail 'bar' 'detail'; th_summary"
  run_harness_probe "$name" 1 "$expected_on" '' \
    "VERBOSE=1; source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-2sp-quiet; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_default_matches_colon_flat() {
  local name="preset-default-matches-colon-flat"
  local out_default err_default out_flat err_flat
  out_default="$TMP_ROOT/$name.default.out"
  err_default="$TMP_ROOT/$name.default.err"
  out_flat="$TMP_ROOT/$name.flat.out"
  err_flat="$TMP_ROOT/$name.flat.err"
  local rc_default=0 rc_flat=0

  set +e
  (
    source "$SCRIPT_DIR/../lib/test-harness.sh"
    th_init
    pass "foo"
    fail "bar" "detail"
    th_summary
  ) > "$out_default" 2> "$err_default"
  rc_default=$?

  (
    source "$SCRIPT_DIR/../lib/test-harness.sh"
    th_init --format=colon-flat
    pass "foo"
    fail "bar" "detail"
    th_summary
  ) > "$out_flat" 2> "$err_flat"
  rc_flat=$?
  set -e

  if [[ "$rc_default" -ne 1 || "$rc_flat" -ne 1 ]]; then
    fail_case "$name" "expected compare probes to return 1; default=$rc_default flat=$rc_flat"
    return
  fi
  if ! cmp -s "$out_default" "$out_flat" || ! cmp -s "$err_default" "$err_flat"; then
    fail_case "$name" "default output differs from --format=colon-flat"
    return
  fi
  pass_case "$name"
}

case_harness_preset_unknown() {
  local name="preset-unknown"
  local out err rc
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"
  set +e
  bash -c "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=bogus" > "$out" 2> "$err"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 && ! -s "$out" ]]; then
    if [[ "$(< "$err")" == *"bogus"* && "$(< "$err")" == *"colon-flat"* && "$(< "$err")" == *"colon-mixed"* \
      && "$(< "$err")" == *"indent-1sp"* && "$(< "$err")" == *"indent-2sp"* && "$(< "$err")" == *"indent-2sp-quiet"* ]]; then
      pass_case "$name"
      return
    fi
  fi
  fail_case "$name" "unknown format should fail with full preset list; rc=$rc err=$(< "$err")"
}

case_harness_fail_fast_on() {
  local name="fail-fast-on"
  local expected_out expected_err
  expected_out=$'PASS: foo\nFAIL: fail-point: reason\n1 passed, 1 failed, 0 skipped\nfailed cases: fail-point'
  expected_err=''
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --fail-fast; pass 'foo'; fail 'fail-point' 'reason'; pass 'after-sentinel'"
}

case_harness_fail_fast_off() {
  local name="fail-fast-off"
  local expected_out expected_err
  expected_out=$'  FAIL  bad-one\n        one\n  FAIL  bad-two\n        two\n0 passed, 2 failed, 0 skipped\nfailed cases: bad-one bad-two'
  expected_err=''
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-2sp; fail 'bad-one' 'one'; fail 'bad-two' 'two'; th_summary"
}

case_harness_fail_fast_no_failures() {
  local name="fail-fast-no-failures"
  local expected_out expected_err
  expected_out=$'PASS: happy\n1 passed, 0 failed, 0 skipped'
  expected_err=''
  run_harness_probe "$name" 0 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --fail-fast; pass 'happy'; th_summary"
}

case_harness_fail_fast_and_format_orthogonal() {
  local name="fail-fast-orthogonal"
  local expected_out expected_err
  expected_out=$'  FAIL  stop\n        reason\n0 passed, 1 failed, 0 skipped\nfailed cases: stop'
  expected_err=''
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-2sp --fail-fast; fail 'stop' 'reason'"
}

case_assert_exit_pass() {
  local name="assert-exit-pass"
  local expected_out
  expected_out=$'PASS: assert-exit-pass\n1 passed, 0 failed, 0 skipped'
  run_harness_probe "$name" 0 "$expected_out" '' \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init; assert_exit 'assert-exit-pass' 0 0 && pass 'assert-exit-pass'; th_summary"
}

case_assert_exit_fail() {
  local name="assert-exit-fail"
  local expected_out
  expected_out=$'FAIL: assert-exit-fail: assert_exit: actual and expected mismatch (name=assert-exit-fail actual=0 expected=1)\n0 passed, 1 failed, 0 skipped\nfailed cases: assert-exit-fail'
  run_harness_probe "$name" 1 "$expected_out" '' \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init; assert_exit 'assert-exit-fail' 0 1; th_summary"
}

case_assert_file_contains_pass() {
  local name="assert-file-contains-pass"
  local tmp_file="$TMP_ROOT/$name.txt"
  local expected_out
  expected_out=$'PASS: assert-file-contains-pass\n1 passed, 0 failed, 0 skipped'
  run_harness_probe "$name" 0 "$expected_out" '' \
    "tmp_file='${tmp_file}'; source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init; printf 'hello world' > \"$tmp_file\"; assert_file_contains 'assert-file-contains-pass' \"$tmp_file\" 'hello' && pass 'assert-file-contains-pass'; th_summary"
}

case_assert_file_contains_fail() {
  local name="assert-file-contains-fail"
  local tmp_file="$TMP_ROOT/$name.txt"
  local expected_out
  expected_out=$'FAIL: assert-file-contains-fail: assert_file_contains: file did not contain literal substring (name=assert-file-contains-fail file='
  expected_out+="$tmp_file"
  expected_out=$expected_out$' needle=missing)\n0 passed, 1 failed, 0 skipped\nfailed cases: assert-file-contains-fail'
  run_harness_probe "$name" 1 "$expected_out" '' \
    "tmp_file='${tmp_file}'; source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init; printf 'hello world' > \"$tmp_file\"; assert_file_contains 'assert-file-contains-fail' \"$tmp_file\" 'missing'; th_summary"
}

case_assert_file_matches_pass() {
  local name="assert-file-matches-pass"
  local tmp_file="$TMP_ROOT/$name.txt"
  local expected_out
  expected_out=$'PASS: assert-file-matches-pass\n1 passed, 0 failed, 0 skipped'
  run_harness_probe "$name" 0 "$expected_out" '' \
    "tmp_file='${tmp_file}'; source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init; printf 'abc123' > \"$tmp_file\"; assert_file_matches 'assert-file-matches-pass' \"$tmp_file\" '^[a-z]+[0-9]+$' && pass 'assert-file-matches-pass'; th_summary"
}

case_assert_file_matches_fail() {
  local name="assert-file-matches-fail"
  local tmp_file="$TMP_ROOT/$name.txt"
  local expected_out
  expected_out=$'FAIL: assert-file-matches-fail: assert_file_matches: file did not match regex (name=assert-file-matches-fail file='
  expected_out+="$tmp_file"
  expected_out=$expected_out$' regex=^[0-9]+\x24)\n0 passed, 1 failed, 0 skipped\nfailed cases: assert-file-matches-fail'
  run_harness_probe "$name" 1 "$expected_out" '' \
    "tmp_file='${tmp_file}'; source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init; printf 'abc123' > \"$tmp_file\"; assert_file_matches 'assert-file-matches-fail' \"$tmp_file\" '^[0-9]+$'; th_summary"
}

case_assert_string_contains_pass() {
  local name="assert-string-contains-pass"
  local expected_out
  expected_out=$'PASS: assert-string-contains-pass\n1 passed, 0 failed, 0 skipped'
  run_harness_probe "$name" 0 "$expected_out" '' \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init; assert_string_contains 'assert-string-contains-pass' 'the quick brown fox' 'quick' && pass 'assert-string-contains-pass'; th_summary"
}

case_assert_string_contains_fail() {
  local name="assert-string-contains-fail"
  local expected_out
  expected_out=$'FAIL: assert-string-contains-fail: assert_string_contains: string did not contain needle (name=assert-string-contains-fail haystack=the quick brown fox needle=slow)\n0 passed, 1 failed, 0 skipped\nfailed cases: assert-string-contains-fail'
  run_harness_probe "$name" 1 "$expected_out" '' \
    "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init; assert_string_contains 'assert-string-contains-fail' 'the quick brown fox' 'slow'; th_summary"
}

case_harness_filter_still_works() {
  local name="filter-still-works"
  local out err rc
  local expected_out='match'
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"
  set +e
  bash -c "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-2sp --filter foo; if should_run 'foo-match'; then printf 'match\n'; fi; if should_run 'zz'; then printf 'nope\n'; fi" > "$out" 2> "$err"
  rc=$?
  set -e
  if [[ "$rc" -eq 0 && "$(< "$out")" == "$expected_out" && ! -s "$err" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc out=$expected_out got=$(cat "$out") err=$(cat "$err")"
  fi
}

case_harness_list_still_works() {
  local name="list-still-works"
  local out err rc
  local expected_out=$'first\nsecond\nskipped'
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"
  set +e
  bash -c "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --format=indent-2sp --list; should_run 'first'; should_run 'second'; should_run 'skipped'; th_summary" > "$out" 2> "$err"
  rc=$?
  set -e
  if [[ "$rc" -eq 0 && "$(< "$out")" == "$expected_out" && ! -s "$err" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc out=$(cat "$out") err=$(cat "$err")"
  fi
}

case_harness_shard_is_stable_and_partitions_list() {
  local name="shard-is-stable-and-partitions-list"
  local out err rc expected_out=$'alpha\ngamma'
  out="$TMP_ROOT/$name.out"; err="$TMP_ROOT/$name.err"
  set +e
  bash -c "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --list --shard 1/2; should_run alpha; should_run beta; should_run gamma; should_run delta; th_summary" > "$out" 2> "$err"
  rc=$?
  set -e
  # Assert the exact, documented round-robin-by-call-position partition for
  # this fixed input set -- not just "some non-empty disjoint split" -- so a
  # future change to the counting/assignment arithmetic that reshuffles
  # allocation is caught here. Positions 1,3 (alpha,gamma) land in shard 1;
  # positions 2,4 (beta,delta) land in shard 2.
  local all one two
  all="$(printf '%s\n' alpha beta gamma delta | sort)"
  one="$(bash -c "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --list --shard 1/2; should_run alpha; should_run beta; should_run gamma; should_run delta; th_summary" | sort)"
  two="$(bash -c "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --list --shard 2/2; should_run alpha; should_run beta; should_run gamma; should_run delta; th_summary" | sort)"
  if [[ "$rc" -eq 0 && ! -s "$err" && "$(cat "$out")" == "$expected_out" &&
        "$(printf '%s\n%s\n' "$one" "$two" | sort)" == "$all" &&
        -n "$one" && -n "$two" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc out=$(cat "$out") expected=$expected_out one=$one two=$two all=$all err=$(cat "$err")"
  fi
}

case_harness_shard_invalid_spec_rejected() {
  local name="shard-invalid-spec-rejected"
  local spec out err rc all_ok=true
  for spec in "0/2" "2/1" "abc" "1/0" "1" "1/2/3" "-1/2"; do
    local safe_spec="${spec//\//_}"
    out="$TMP_ROOT/$name.$safe_spec.out"; err="$TMP_ROOT/$name.$safe_spec.err"
    set +e
    bash -c "source '$SCRIPT_DIR/../lib/test-harness.sh'; th_init --shard '$spec'" > "$out" 2> "$err"
    rc=$?
    set -e
    if [[ "$rc" -ne 2 || ! -s "$err" ]]; then
      all_ok=false
      fail_case "$name" "spec=$spec rc=$rc err=$(cat "$err" 2>/dev/null)"
      break
    fi
  done
  [[ "$all_ok" == true ]] && pass_case "$name"
}

case_harness_should_run_empty_filter
case_harness_should_run_filter_match
case_harness_should_run_list_records_case
case_harness_pass_fail_counters
case_harness_summary_exit_code_zero
case_harness_summary_exit_code_one
case_harness_summary_no_match_filter
case_harness_skip_counter
case_harness_skip_without_reason_fails
case_harness_summary_counts_skips_exit_zero
case_harness_skip_does_not_mask_failure
case_harness_filter_only_skip_is_not_no_match
case_harness_case_skips_file_gets_count
case_harness_case_skips_write_failure_fails_suite
case_harness_migrated_sample_sites_use_skip
case_harness_preset_colon_flat
case_harness_preset_colon_mixed
case_harness_preset_indent_1sp
case_harness_preset_indent_2sp
case_harness_preset_indent_2sp_quiet
case_harness_preset_default_matches_colon_flat
case_harness_preset_unknown
case_harness_fail_fast_on
case_harness_fail_fast_off
case_harness_fail_fast_no_failures
case_harness_fail_fast_and_format_orthogonal
case_harness_filter_still_works
case_harness_list_still_works
case_harness_shard_is_stable_and_partitions_list
case_harness_shard_invalid_spec_rejected
case_assert_exit_pass
case_assert_exit_fail
case_assert_file_contains_pass
case_assert_file_contains_fail
case_assert_file_matches_pass
case_assert_file_matches_fail
case_assert_string_contains_pass
case_assert_string_contains_fail
case_fixture_inputs_are_cleared
case_fixture_isolation_expands_pattern_rows
case_fixture_isolation_rejects_empty_declaration
case_fixture_isolation_fails_closed

printf '%s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
