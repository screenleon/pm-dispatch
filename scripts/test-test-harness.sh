#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LC_ALL=C.UTF-8

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass_case() {
  printf 'PASS: %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail_case() {
  printf 'FAIL: %s: %s\n' "$1" "$2"
  FAIL_COUNT=$((FAIL_COUNT + 1))
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

case_harness_should_run_empty_filter
case_harness_should_run_filter_match
case_harness_should_run_list_records_case
case_harness_pass_fail_counters
case_harness_summary_exit_code_zero
case_harness_summary_exit_code_one
case_harness_summary_no_match_filter

printf '%s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
