#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_UNDER_TEST="$SCRIPT_DIR/../scripts/test-commands.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# --filter <pattern>  run only cases whose name contains <pattern>
# --list              print all case names and exit
FILTER=""
LIST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      if [[ $# -lt 2 ]]; then
        printf 'error: --filter requires an argument\n' >&2
        exit 1
      fi
      FILTER="$2"
      shift 2
      ;;
    --list)
      LIST=true
      shift
      ;;
    *)
      printf 'error: unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

PASS=0
FAIL=0
ALL_CASES=()
FAILED_CASES=()
RUN_STATUS=0

should_run() {
  if $LIST; then
    ALL_CASES+=("$1")
    return 1
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

pass_case() {
  local name="$1"
  PASS=$((PASS + 1))
  printf 'PASS  %s\n' "$name"
}

fail_case() {
  local name="$1" detail="${2:-}"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$name")
  printf 'FAIL  %s\n' "$name"
  if [[ -n "$detail" ]]; then
    printf '      %s\n' "$detail"
  fi
}

assert_exit() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail_case "$name" "expected exit=$expected, got exit=$actual"
    return 1
  fi
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -Fq -- "$needle" "$file"; then
    fail_case "$name" "missing substring: $needle"
    return 1
  fi
}

assert_first_line_not() {
  local name="$1" file="$2" forbidden="$3" first_line
  first_line="$(sed -n '1p' "$file")"
  if [[ -z "$first_line" ]]; then
    fail_case "$name" "expected first output line, got empty stdout"
    return 1
  fi
  if [[ "$first_line" == "$forbidden" ]]; then
    fail_case "$name" "unexpected first line: $first_line"
    return 1
  fi
}

run_test_commands() {
  local out="$1" err="$2"
  shift 2
  bash "$SCRIPT_UNDER_TEST" "$@" > "$out" 2> "$err"
  RUN_STATUS=$?
}

# Behavior: --list prints case names without the normal banner line.
# Steps: 1. Invoke test-commands.sh with --list; 2. Assert exit 0; 3. Assert first stdout line is not the banner.
case_list_mode_starts_with_case_name() {
  local name="cli-list-mode-starts-with-case-name" out err status
  should_run "$name" || return 0
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"

  run_test_commands "$out" "$err" --list
  status=$RUN_STATUS

  assert_exit "$name" "$status" 0 || return 0
  assert_first_line_not "$name" "$out" "test-commands.sh" || return 0
  pass_case "$name"
}

# Behavior: --filter with a matching pattern runs matching cases and reports passes.
# Steps: 1. Invoke test-commands.sh with --filter caveman; 2. Assert exit 0; 3. Assert the reported pass count is greater than zero.
case_filter_valid_pattern_passes() {
  local name="cli-filter-valid-pattern-passes" out err status pass_count
  should_run "$name" || return 0
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"

  run_test_commands "$out" "$err" --filter caveman
  status=$RUN_STATUS

  assert_exit "$name" "$status" 0 || return 0
  pass_count="$(awk '/^[0-9]+ passed, [0-9]+ failed$/ { print $1; exit }' "$out")"
  if [[ -z "$pass_count" || "$pass_count" -le 0 ]]; then
    fail_case "$name" "expected PASS count > 0, got ${pass_count:-empty}"
    return 0
  fi
  pass_case "$name"
}

# Behavior: --filter with no matching cases exits nonzero and reports no matches.
# Steps: 1. Invoke test-commands.sh with --filter zzznomatch_cc053; 2. Assert exit 1; 3. Assert stderr contains "no tests matched".
case_filter_zero_match_fails() {
  local name="cli-filter-zero-match-fails" out err status
  should_run "$name" || return 0
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"

  run_test_commands "$out" "$err" --filter zzznomatch_cc053
  status=$RUN_STATUS

  assert_exit "$name" "$status" 1 || return 0
  assert_contains "$name" "$err" "no tests matched" || return 0
  pass_case "$name"
}

# Behavior: Unknown CLI options exit nonzero and report an unknown option error.
# Steps: 1. Invoke test-commands.sh with --unknown_cc053; 2. Assert exit 1; 3. Assert stderr contains "error: unknown option".
case_unknown_option_fails() {
  local name="cli-unknown-option-fails" out err status
  should_run "$name" || return 0
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"

  run_test_commands "$out" "$err" --unknown_cc053
  status=$RUN_STATUS

  assert_exit "$name" "$status" 1 || return 0
  assert_contains "$name" "$err" "error: unknown option" || return 0
  pass_case "$name"
}

# Behavior: --filter without a value exits nonzero and reports the missing argument.
# Steps: 1. Invoke test-commands.sh with --filter only; 2. Assert exit 1; 3. Assert stderr contains "error: --filter requires an argument".
case_missing_filter_argument_fails() {
  local name="cli-missing-filter-argument-fails" out err status
  should_run "$name" || return 0
  out="$TMP_ROOT/$name.out"
  err="$TMP_ROOT/$name.err"

  run_test_commands "$out" "$err" --filter
  status=$RUN_STATUS

  assert_exit "$name" "$status" 1 || return 0
  assert_contains "$name" "$err" "error: --filter requires an argument" || return 0
  pass_case "$name"
}

case_list_mode_starts_with_case_name
case_filter_valid_pattern_passes
case_filter_zero_match_fails
case_unknown_option_fails
case_missing_filter_argument_fails

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

if [[ -n "$FILTER" && $((PASS + FAIL)) -eq 0 ]]; then
  printf 'no tests matched filter %q -- check --list for available case names\n' "$FILTER" >&2
  exit 1
fi

printf '\n----\n'
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases:\n' >&2
  for case_name in "${FAILED_CASES[@]}"; do
    printf '  - %s\n' "$case_name" >&2
  done
  exit 1
fi
exit 0
