#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LC_ALL=C.UTF-8

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"

PASS_COUNT=0
FAIL_COUNT=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass_case() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

fail_case() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED_CASES+=("$1")
  printf 'FAIL: %s: %s\n' "$1" "$2"
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle" ]]; then
    fail_case "$name" "missing output: $needle"
    return 1
  fi
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

case_harness_preset_colon_flat() {
  local name="preset-colon-flat"
  local expected_out expected_err
  expected_out=$'PASS: foo\nFAIL: bar: detail\n1 passed, 1 failed'
  expected_err=$'failed cases: bar'
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=colon-flat; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_colon_mixed() {
  local name="preset-colon-mixed"
  local expected_out expected_err
  expected_out=$'PASS: foo\n  FAIL  bar\n        detail\n1 passed, 1 failed'
  expected_err=$'failed cases: bar'
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=colon-mixed; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_indent_1sp() {
  local name="preset-indent-1sp-verbose"
  local expected_on expected_on_err expected_off expected_off_err
  expected_off=$'  FAIL bar\n        detail\n0 passed, 1 failed'
  expected_off_err=''
  expected_on=$'  PASS foo\n  FAIL bar\n        detail\n1 passed, 1 failed'
  expected_on_err=$'failed cases: bar'
  run_harness_probe "${name}-off" 1 "$expected_off" "$expected_off_err" \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-1sp; fail 'bar' 'detail'; th_summary"
  run_harness_probe "$name" 1 "$expected_on" "$expected_on_err" \
    "VERBOSE=1; source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-1sp; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_indent_2sp() {
  local name="preset-indent-2sp"
  local expected_out expected_err
  expected_out=$'  PASS  foo\n  FAIL  bar\n        detail\n1 passed, 1 failed'
  expected_err=$'failed cases: bar'
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "VERBOSE=1; source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-2sp; pass 'foo'; fail 'bar' 'detail'; th_summary"
}

case_harness_preset_indent_2sp_quiet() {
  local name="preset-indent-2sp-quiet"
  local expected_on expected_off
  expected_off=$'  FAIL  bar\ndetail\n1 passed, 1 failed'
  expected_on=$'  PASS  foo\n  FAIL  bar\ndetail\n1 passed, 1 failed'
  run_harness_probe "${name}-off" 1 "$expected_off" '' \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-2sp-quiet; pass 'foo'; fail 'bar' 'detail'; th_summary"
  run_harness_probe "$name" 1 "$expected_on" 'failed cases: bar' \
    "VERBOSE=1; source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-2sp-quiet; pass 'foo'; fail 'bar' 'detail'; th_summary"
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
    source "$SCRIPT_DIR/lib/test-harness.sh"
    th_init
    pass "foo"
    fail "bar" "detail"
    th_summary
  ) > "$out_default" 2> "$err_default"
  rc_default=$?

  (
    source "$SCRIPT_DIR/lib/test-harness.sh"
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
  bash -c "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=bogus" > "$out" 2> "$err"
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
  expected_out=$'PASS: foo\nFAIL: fail-point: reason\n1 passed, 1 failed'
  expected_err=$'failed cases: fail-point'
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --fail-fast; pass 'foo'; fail 'fail-point' 'reason'; pass 'after-sentinel'"
}

case_harness_fail_fast_off() {
  local name="fail-fast-off"
  local expected_out expected_err
  expected_out=$'  FAIL  bad-one\n        one\n  FAIL  bad-two\n        two\n0 passed, 2 failed'
  expected_err=$'failed cases: bad-one bad-two'
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-2sp; fail 'bad-one' 'one'; fail 'bad-two' 'two'; th_summary"
}

case_harness_fail_fast_no_failures() {
  local name="fail-fast-no-failures"
  local expected_out expected_err
  expected_out=$'PASS: happy\n1 passed, 0 failed'
  expected_err=''
  run_harness_probe "$name" 0 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --fail-fast; pass 'happy'; th_summary"
}

case_harness_fail_fast_and_format_orthogonal() {
  local name="fail-fast-orthogonal"
  local expected_out expected_err
  expected_out=$'  FAIL  stop\n        reason\n0 passed, 1 failed'
  expected_err=$'failed cases: stop'
  run_harness_probe "$name" 1 "$expected_out" "$expected_err" \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-2sp --fail-fast; fail 'stop' 'reason'"
}

case_assert_exit_pass() {
  local name="assert-exit-pass"
  local expected_out
  expected_out=$'PASS: assert-exit-pass\n1 passed, 0 failed'
  run_harness_probe "$name" 0 "$expected_out" '' \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init; assert_exit 'assert-exit-pass' 0 0 && pass 'assert-exit-pass'; th_summary"
}

case_assert_exit_fail() {
  local name="assert-exit-fail"
  local expected_out
  expected_out=$'FAIL: assert-exit-fail: assert_exit: actual and expected mismatch (name=assert-exit-fail actual=0 expected=1)\n0 passed, 1 failed'
  run_harness_probe "$name" 1 "$expected_out" '' \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init; assert_exit 'assert-exit-fail' 0 1; th_summary"
}

case_assert_file_contains_pass() {
  local name="assert-file-contains-pass"
  local tmp_file="$TMP_ROOT/$name.txt"
  local expected_out
  expected_out=$'PASS: assert-file-contains-pass\n1 passed, 0 failed'
  run_harness_probe "$name" 0 "$expected_out" '' \
    "tmp_file='${tmp_file}'; source '$SCRIPT_DIR/lib/test-harness.sh'; th_init; printf 'hello world' > \"$tmp_file\"; assert_file_contains 'assert-file-contains-pass' \"$tmp_file\" 'hello' && pass 'assert-file-contains-pass'; th_summary"
}

case_assert_file_contains_fail() {
  local name="assert-file-contains-fail"
  local tmp_file="$TMP_ROOT/$name.txt"
  local expected_out
  expected_out=$'FAIL: assert-file-contains-fail: assert_file_contains: file did not contain literal substring (name=assert-file-contains-fail file='
  expected_out+="$tmp_file"
  expected_out=$expected_out$' needle=missing)\n0 passed, 1 failed'
  run_harness_probe "$name" 1 "$expected_out" '' \
    "tmp_file='${tmp_file}'; source '$SCRIPT_DIR/lib/test-harness.sh'; th_init; printf 'hello world' > \"$tmp_file\"; assert_file_contains 'assert-file-contains-fail' \"$tmp_file\" 'missing'; th_summary"
}

case_assert_file_matches_pass() {
  local name="assert-file-matches-pass"
  local tmp_file="$TMP_ROOT/$name.txt"
  local expected_out
  expected_out=$'PASS: assert-file-matches-pass\n1 passed, 0 failed'
  run_harness_probe "$name" 0 "$expected_out" '' \
    "tmp_file='${tmp_file}'; source '$SCRIPT_DIR/lib/test-harness.sh'; th_init; printf 'abc123' > \"$tmp_file\"; assert_file_matches 'assert-file-matches-pass' \"$tmp_file\" '^[a-z]+[0-9]+$' && pass 'assert-file-matches-pass'; th_summary"
}

case_assert_file_matches_fail() {
  local name="assert-file-matches-fail"
  local tmp_file="$TMP_ROOT/$name.txt"
  local expected_out
  expected_out=$'FAIL: assert-file-matches-fail: assert_file_matches: file did not match regex (name=assert-file-matches-fail file='
  expected_out+="$tmp_file"
  expected_out=$expected_out$' regex=^[0-9]+\x24)\n0 passed, 1 failed'
  run_harness_probe "$name" 1 "$expected_out" '' \
    "tmp_file='${tmp_file}'; source '$SCRIPT_DIR/lib/test-harness.sh'; th_init; printf 'abc123' > \"$tmp_file\"; assert_file_matches 'assert-file-matches-fail' \"$tmp_file\" '^[0-9]+$'; th_summary"
}

case_assert_string_contains_pass() {
  local name="assert-string-contains-pass"
  local expected_out
  expected_out=$'PASS: assert-string-contains-pass\n1 passed, 0 failed'
  run_harness_probe "$name" 0 "$expected_out" '' \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init; assert_string_contains 'assert-string-contains-pass' 'the quick brown fox' 'quick' && pass 'assert-string-contains-pass'; th_summary"
}

case_assert_string_contains_fail() {
  local name="assert-string-contains-fail"
  local expected_out
  expected_out=$'FAIL: assert-string-contains-fail: assert_string_contains: string did not contain needle (name=assert-string-contains-fail haystack=the quick brown fox needle=slow)\n0 passed, 1 failed'
  run_harness_probe "$name" 1 "$expected_out" '' \
    "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init; assert_string_contains 'assert-string-contains-fail' 'the quick brown fox' 'slow'; th_summary"
}

case_harness_filter_still_works() {
  local name="filter-still-works"
  local out err rc
  local expected_out='match'
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"
  set +e
  bash -c "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-2sp --filter foo; if should_run 'foo-match'; then printf 'match\n'; fi; if should_run 'zz'; then printf 'nope\n'; fi" > "$out" 2> "$err"
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
  bash -c "source '$SCRIPT_DIR/lib/test-harness.sh'; th_init --format=indent-2sp --list; should_run 'first'; should_run 'second'; should_run 'skipped'; th_summary" > "$out" 2> "$err"
  rc=$?
  set -e
  if [[ "$rc" -eq 0 && "$(< "$out")" == "$expected_out" && ! -s "$err" ]]; then
    pass_case "$name"
  else
    fail_case "$name" "rc=$rc out=$(cat "$out") err=$(cat "$err")"
  fi
}

case_harness_should_run_empty_filter
case_harness_should_run_filter_match
case_harness_should_run_list_records_case
case_harness_pass_fail_counters
case_harness_summary_exit_code_zero
case_harness_summary_exit_code_one
case_harness_summary_no_match_filter
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
case_assert_exit_pass
case_assert_exit_fail
case_assert_file_contains_pass
case_assert_file_contains_fail
case_assert_file_matches_pass
case_assert_file_matches_fail
case_assert_string_contains_pass
case_assert_string_contains_fail

printf '%s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
