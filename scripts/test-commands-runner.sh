#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_UNDER_TEST="$SCRIPT_DIR/../scripts/test-commands.sh"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

assert_exit() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$name" "expected exit=$expected, got exit=$actual"
    return 1
  fi
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -Fq -- "$needle" "$file"; then
    fail "$name" "missing substring: $needle"
    return 1
  fi
}

assert_all_case_lines_match() {
  local file="$1" line_pattern="$2" required_substring="$3" line
  while IFS= read -r line; do
    if [[ "$line" != *"$required_substring"* ]]; then
      printf 'expected filtered case line to contain %q, got: %s\n' "$required_substring" "$line"
      return 1
    fi
  done < <(grep -E "$line_pattern" "$file" || true)
}

run_test_commands() {
  local out="$1" err="$2"
  shift 2
  bash "$SCRIPT_UNDER_TEST" "$@" > "$out" 2> "$err"
  RUN_STATUS=$?
}

# Behavior: --list prints only real case names.
# Steps: 1. Invoke test-commands.sh with --list; 2. Assert exit 0; 3. Assert every non-blank stdout line exists in real verbose case lines.
case_list_mode_starts_with_case_name() {
  local name="cli-list-mode-starts-with-case-name" out err verbose_out real_cases status list_line list_count real_count
  should_run "$name" || return 0
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  verbose_out="$tmp_root/$name.verbose.out"
  real_cases="$tmp_root/$name.real-cases"

  bash "$SCRIPT_UNDER_TEST" --list > "$out" 2> "$err"
  status=$?

  assert_exit "$name" "$status" 0 || return 0
  VERBOSE=1 bash "$SCRIPT_UNDER_TEST" > "$verbose_out" 2> /dev/null || true
  sed -n -E 's/^  (PASS|FAIL) //p' "$verbose_out" > "$real_cases"
  if [[ ! -s "$real_cases" ]]; then
    fail "$name" "expected at least one real case name, got none"
    return 0
  fi
  list_count=$(grep -c '[^[:space:]]' "$out" 2>/dev/null || true)
  list_count=${list_count:-0}
  if [[ "$list_count" -eq 0 ]]; then
    fail "$name" "expected non-empty --list output, got empty"
    return 0
  fi
  while IFS= read -r list_line; do
    [[ -z "$list_line" ]] && continue
    if ! grep -Fx -- "$list_line" "$real_cases" > /dev/null; then
      fail "$name" "list output line is not a real case name: $list_line"
      return 0
    fi
  done < "$out"
  real_count=$(wc -l < "$real_cases" | tr -d '[:space:]')
  if [[ "$list_count" -ne "$real_count" ]]; then
    fail "$name" "list output has $list_count case names but verbose run shows $real_count real cases"
    return 0
  fi
  pass "$name"
}

# Behavior: --filter with a middle-of-name pattern proves contains-substring matching, not prefix matching.
# Steps: 1. Invoke test-commands.sh with VERBOSE=1 and --filter "Rules:"; 2. Assert exit 0; 3. Assert per-case PASS/FAIL lines include "Rules:" and exclude non-matching cases.
case_filter_valid_pattern_passes() {
  local name="cli-filter-valid-pattern-passes" out err case_lines status detail
  should_run "$name" || return 0
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  case_lines="$tmp_root/$name.case-lines"

  VERBOSE=1 bash "$SCRIPT_UNDER_TEST" --filter "Rules:" > "$out" 2> "$err"
  status=$?

  assert_exit "$name" "$status" 0 || return 0
  grep -E '^  (PASS|FAIL) ' "$out" > "$case_lines" || true
  assert_contains "$name" "$case_lines" "Rules:" || return 0
  if ! detail="$(assert_all_case_lines_match "$out" '^  (PASS|FAIL) ' "Rules:")"; then
    fail "$name" "$detail"
    return 0
  fi
  pass "$name"
}

# Behavior: --filter with no matching cases exits nonzero and reports no matches.
# Steps: 1. Invoke test-commands.sh with --filter zzznomatch_cc053; 2. Assert exit 1; 3. Assert stderr contains "no tests matched".
case_filter_zero_match_fails() {
  local name="cli-filter-zero-match-fails" out err status
  should_run "$name" || return 0
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"

  run_test_commands "$out" "$err" --filter zzznomatch_cc053
  status=$RUN_STATUS

  assert_exit "$name" "$status" 1 || return 0
  assert_contains "$name" "$err" "no tests matched" || return 0
  pass "$name"
}

# Behavior: Unknown CLI options exit nonzero and report an unknown option error.
# Steps: 1. Invoke test-commands.sh with --unknown_cc053; 2. Assert exit 1; 3. Assert stderr contains "error: unknown option".
case_unknown_option_fails() {
  local name="cli-unknown-option-fails" out err status
  should_run "$name" || return 0
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"

  run_test_commands "$out" "$err" --unknown_cc053
  status=$RUN_STATUS

  assert_exit "$name" "$status" 1 || return 0
  assert_contains "$name" "$err" "error: unknown option" || return 0
  pass "$name"
}

# Behavior: --filter without a value exits nonzero and reports the missing argument.
# Steps: 1. Invoke test-commands.sh with --filter only; 2. Assert exit 1; 3. Assert stderr contains "error: --filter requires an argument".
case_missing_filter_argument_fails() {
  local name="cli-missing-filter-argument-fails" out err status
  should_run "$name" || return 0
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"

  run_test_commands "$out" "$err" --filter
  status=$RUN_STATUS

  assert_exit "$name" "$status" 1 || return 0
  assert_contains "$name" "$err" "error: --filter requires an argument" || return 0
  pass "$name"
}

case_list_mode_starts_with_case_name
case_filter_valid_pattern_passes
case_filter_zero_match_fails
case_unknown_option_fails
case_missing_filter_argument_fails

th_summary
