#!/usr/bin/env bash
# Fixture-driven regression suite for log-usage.sh and claude-usage.sh.
#
# Usage:
#   scripts/test-usage-tracker.sh           # print PASS per case
#   VERBOSE=1 scripts/test-usage-tracker.sh # include diagnostics on failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_SCRIPT="$SCRIPT_DIR/log-usage.sh"
VIEW_SCRIPT="$SCRIPT_DIR/claude-usage.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0

fail() {
  local name="$1" detail="${2:-}"
  printf '  FAIL  %s\n' "$name"
  [[ -n "$detail" ]] && printf '        %s\n' "$detail"
  exit 1
}

pass_case() {
  PASS=$((PASS + 1))
  printf '  PASS  %s\n' "$1"
}

assert_exit() {
  local name="$1" actual="$2" expected="$3"
  [[ "$actual" == "$expected" ]] || fail "$name" "expected exit=$expected, got exit=$actual"
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  grep -qF -- "$needle" "$file" || fail "$name" "missing: $needle"
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  grep -qF -- "$needle" "$file" && fail "$name" "unexpected: $needle" || true
}

assert_line_count() {
  local name="$1" file="$2" expected="$3"
  local actual
  actual=$(wc -l < "$file")
  [[ "$actual" -eq "$expected" ]] || fail "$name" "expected $expected lines, got $actual"
}

new_home() {
  local h="$TMP_ROOT/$1"
  mkdir -p "$h/.claude"
  printf '%s\n' "$h"
}

run_log() {
  local home="$1"; shift
  HOME="$home" /bin/bash "$LOG_SCRIPT" "$@"
}

run_view() {
  local home="$1" out="$2"; shift 2
  HOME="$home" /bin/bash "$VIEW_SCRIPT" "$@" > "$out" 2> "$out.err" || true
}

# ---------------------------------------------------------------------------
# log-usage.sh tests
# ---------------------------------------------------------------------------

echo "== log-usage =="

case_happy_path() {
  local name="happy_path" home status
  home="$(new_home "$name")"
  run_log "$home" pr_gate_full 390000 "JapanJob PR #24"; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  [[ -f "$logfile" ]] || fail "$name" "logfile not created"
  assert_contains "$name" "$logfile" '"type":"pr_gate_full"'
  assert_contains "$name" "$logfile" '"tokens":390000'
  assert_contains "$name" "$logfile" '"note":"JapanJob PR #24"'
  assert_line_count "$name" "$logfile" 1
  pass_case "$name"
}

case_note_single_quote() {
  local name="note_single_quote" home status out
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  run_log "$home" pm_analysis 5000 "it's done" > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  assert_contains "$name" "$logfile" '"note":"it'"'"'s done"'
  assert_line_count "$name" "$logfile" 1
  pass_case "$name"
}

case_note_double_quote() {
  local name="note_double_quote" home status
  home="$(new_home "$name")"
  run_log "$home" codex_task 10000 'fix "thing"'; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  assert_contains "$name" "$logfile" '"note":"fix \"thing\""'
  assert_line_count "$name" "$logfile" 1
  pass_case "$name"
}

case_note_backslash() {
  local name="note_backslash" home status
  home="$(new_home "$name")"
  run_log "$home" codex_task 10000 'path\to\thing'; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  assert_contains "$name" "$logfile" '"note":"path\\to\\thing"'
  assert_line_count "$name" "$logfile" 1
  pass_case "$name"
}

case_note_unicode() {
  local name="note_unicode" home status
  home="$(new_home "$name")"
  run_log "$home" pm_synthesis 3000 "已完成 #14 重構"; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  assert_contains "$name" "$logfile" '"note":"已完成 #14 重構"'
  assert_line_count "$name" "$logfile" 1
  pass_case "$name"
}

case_note_injection_attempt() {
  # Confirm that a crafted note does NOT execute code and produces valid JSON
  local name="note_injection_attempt" home status
  home="$(new_home "$name")"
  local sentinel="$TMP_ROOT/injection_sentinel"
  local evil_note="a', __import__('os').system('touch $sentinel') or 'b"
  run_log "$home" codex_task 1 "$evil_note"; status=$?
  assert_exit "$name" "$status" 0
  [[ ! -f "$sentinel" ]] || fail "$name" "injection sentinel was created — code executed"
  # Output must be valid JSON
  local logfile="$home/.claude/usage-tracker.jsonl"
  jq -e . "$logfile" > /dev/null 2>&1 || fail "$name" "output is not valid JSON"
  assert_line_count "$name" "$logfile" 1
  pass_case "$name"
}

case_tokens_not_integer() {
  local name="tokens_not_integer" home status out
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  run_log "$home" codex_task "notanumber" "some note" > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 2
  local logfile="$home/.claude/usage-tracker.jsonl"
  [[ ! -f "$logfile" ]] || assert_line_count "$name" "$logfile" 0
  pass_case "$name"
}

case_tokens_float_rejected() {
  local name="tokens_float_rejected" home status
  home="$(new_home "$name")"
  run_log "$home" codex_task "3.14" "pi" > /dev/null 2>&1; status=$?
  assert_exit "$name" "$status" 2
  pass_case "$name"
}

case_multiple_appends() {
  local name="multiple_appends" home
  home="$(new_home "$name")"
  run_log "$home" pr_gate_express 80000 "first"
  run_log "$home" codex_task      50000 "second"
  run_log "$home" pm_synthesis    15000 "third"
  assert_line_count "$name" "$home/.claude/usage-tracker.jsonl" 3
  pass_case "$name"
}

case_idempotent_json_per_line() {
  local name="idempotent_json_per_line" home
  home="$(new_home "$name")"
  run_log "$home" codex_task 42 "x"
  # Every line must independently parse as JSON
  while IFS= read -r line; do
    printf '%s\n' "$line" | jq -e . > /dev/null 2>&1 \
      || fail "$name" "line is not valid JSON: $line"
  done < "$home/.claude/usage-tracker.jsonl"
  pass_case "$name"
}

case_file_permissions() {
  local name="file_permissions" home perms
  home="$(new_home "$name")"
  run_log "$home" codex_task 1 ""
  perms=$(stat -c '%a' "$home/.claude/usage-tracker.jsonl")
  [[ "$perms" == "600" ]] || fail "$name" "expected 600 perms, got $perms"
  pass_case "$name"
}

# ---------------------------------------------------------------------------
# claude-usage.sh tests
# ---------------------------------------------------------------------------

echo "== claude-usage =="

write_log() {
  local home="$1" ts="$2" type="$3" tokens="$4" note="${5:-}"
  local logfile="$home/.claude/usage-tracker.jsonl"
  jq -nc --arg ts "$ts" --arg type "$type" --argjson tokens "$tokens" \
         --arg note "$note" --arg session "testsession" \
    '{ts:$ts,session:$session,type:$type,tokens:$tokens,note:$note}' >> "$logfile"
}

case_view_missing_logfile() {
  local name="view_missing_logfile" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "No usage log"
  pass_case "$name"
}

case_view_empty_logfile() {
  local name="view_empty_logfile" home out status
  home="$(new_home "$name")"
  touch "$home/.claude/usage-tracker.jsonl"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "Total"
  pass_case "$name"
}

case_view_all_mode() {
  local name="view_all_mode" home out status
  home="$(new_home "$name")"
  write_log "$home" "2020-01-01T00:00:00Z" "codex_task" 50000 "old entry"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "all time"
  assert_contains "$name" "$out" "50,000"
  pass_case "$name"
}

case_view_today_mode() {
  local name="view_today_mode" home out status
  home="$(new_home "$name")"
  local now_ts
  now_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  write_log "$home" "$now_ts" "pm_analysis" 40000 "today entry"
  write_log "$home" "2020-01-01T00:00:00Z" "codex_task" 99999 "old entry"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --today > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "today (UTC)"
  assert_contains "$name" "$out" "40,000"
  assert_not_contains "$name" "$out" "99,999"
  pass_case "$name"
}

case_view_unknown_mode() {
  local name="view_unknown_mode" home out status
  home="$(new_home "$name")"
  touch "$home/.claude/usage-tracker.jsonl"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --foobar > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 2
  pass_case "$name"
}

case_view_malformed_line_skipped() {
  local name="view_malformed_line_skipped" home out status
  home="$(new_home "$name")"
  local logfile="$home/.claude/usage-tracker.jsonl"
  printf 'not json\n' >> "$logfile"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 5000 "good"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out.err" "skipped"
  assert_contains "$name" "$out" "5,000"
  pass_case "$name"
}

case_view_missing_ts_skipped() {
  local name="view_missing_ts_skipped" home out status
  home="$(new_home "$name")"
  local logfile="$home/.claude/usage-tracker.jsonl"
  printf '{"type":"codex_task","tokens":9999}\n' >> "$logfile"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "pm_analysis" 1000 "good"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out.err" "skipped"
  assert_contains "$name" "$out" "1,000"
  assert_not_contains "$name" "$out" "9,999"
  pass_case "$name"
}

case_view_malformed_calibration_warns() {
  local name="view_malformed_calibration_warns" home out status
  home="$(new_home "$name")"
  printf 'not json\n' > "$home/.claude/usage-calibration.json"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out.err" "malformed"
  pass_case "$name"
}

case_round_trip() {
  # Entry written by log-usage.sh is readable and counted by claude-usage.sh
  local name="round_trip" home out status
  home="$(new_home "$name")"
  HOME="$home" /bin/bash "$LOG_SCRIPT" reviewer_critic 80000 "round-trip test"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "80,000"
  assert_contains "$name" "$out" "reviewer_critic"
  pass_case "$name"
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

case_happy_path
case_note_single_quote
case_note_double_quote
case_note_backslash
case_note_unicode
case_note_injection_attempt
case_tokens_not_integer
case_tokens_float_rejected
case_multiple_appends
case_idempotent_json_per_line
case_file_permissions

case_view_missing_logfile
case_view_empty_logfile
case_view_all_mode
case_view_today_mode
case_view_unknown_mode
case_view_malformed_line_skipped
case_view_missing_ts_skipped
case_view_malformed_calibration_warns
case_round_trip

echo
echo "----"
echo "$PASS passed, 0 failed"
echo "test-usage-tracker: all cases pass"
