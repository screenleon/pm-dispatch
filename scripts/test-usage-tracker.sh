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

assert_occurrences() {
  local name="$1" file="$2" needle="$3" expected="$4"
  local actual
  actual=$(grep -oF -- "$needle" "$file" | wc -l)
  [[ "$actual" -eq "$expected" ]] || fail "$name" "expected $expected occurrence(s) of $needle, got $actual"
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
  local home="$1" ts="$2" type="$3" tokens="$4" note="${5:-}" pool="${6:-}"
  local logfile="$home/.claude/usage-tracker.jsonl"
  jq -nc --arg ts "$ts" --arg type "$type" --argjson tokens "$tokens" \
         --arg note "$note" --arg session "testsession" --arg pool "$pool" \
    '{ts:$ts,session:$session,type:$type,tokens:$tokens,note:$note}
     + (if $pool == "" then {} else {pool:$pool} end)' >> "$logfile"
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
# log-usage.sh pool field tests
# ---------------------------------------------------------------------------

echo "== log-usage: pool field =="

case_log_pool_codex() {
  local name="log_pool_codex" home status
  home="$(new_home "$name")"
  run_log "$home" codex_dispatch 1100 "dispatch" "" codex; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$home/.claude/usage-tracker.jsonl" '"pool":"codex"'
  pass_case "$name"
}

case_log_pool_default() {
  local name="log_pool_default" home status
  home="$(new_home "$name")"
  run_log "$home" session_total 2200 "session"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$home/.claude/usage-tracker.jsonl" '"pool":"claude"'
  pass_case "$name"
}

case_log_pool_spark() {
  local name="log_pool_spark" home status
  home="$(new_home "$name")"
  run_log "$home" codex_dispatch 3300 "spark dispatch" "" spark; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$home/.claude/usage-tracker.jsonl" '"pool":"spark"'
  pass_case "$name"
}

case_remaining_excludes_codex_pool() {
  local name="remaining_excludes_codex_pool" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "session_total" 100000 "claude op" claude
  write_log "$home" "$t2" "codex_dispatch" 5000000 "codex op" codex
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 50 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "Tokens used (Claude pool) : 100,000"
  assert_contains "$name" "$out" "Inferred total limit      : 200,000"
  assert_contains "$name" "$out" "Separate quota tokens     : Codex 5,000,000"
  assert_not_contains "$name" "$out" "10,200,000"
  pass_case "$name"
}

case_remaining_no_claude_log() {
  local name="remaining_no_claude_log" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_dispatch" 200000 "codex op1" codex
  write_log "$home" "$t2" "codex_dispatch" 300000 "codex op2" codex
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 50 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "no Claude log data"
  assert_contains "$name" "$out" "rate unknown"
  pass_case "$name"
}

case_remaining_mixed_pools_correct_total() {
  local name="remaining_mixed_pools_correct_total" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "session_total" 100000 "claude op" claude
  write_log "$home" "$t2" "codex_dispatch" 200000 "codex op" codex
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 50 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "Claude  : 100,000"
  assert_contains "$name" "$out" "Codex   : 200,000"
  assert_contains "$name" "$out" "Total   : 300,000"
  assert_contains "$name" "$out" "Inferred total limit      : 200,000"
  pass_case "$name"
}

# ---------------------------------------------------------------------------
# Helpers for --remaining tests
# ---------------------------------------------------------------------------

write_calib() {
  local home="$1" limit="${2:-null}"
  jq -nc --argjson limit "$limit" \
    '{known_limit_tokens:$limit,rate_limit_events:[],typical_cost_tokens:{}}' \
    > "$home/.claude/usage-calibration.json"
}

# ---------------------------------------------------------------------------
# --remaining flag tests
# ---------------------------------------------------------------------------

echo "== claude-usage: --remaining =="

case_remaining_basic_no_calibration() {
  local name="remaining_basic_no_calibration" home out
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_task"   120000 "first op"
  write_log "$home" "$t2" "pm_analysis"   80000 "second op"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 60 > "$out" 2> "$out.err"
  assert_contains "$name" "$out" "Remaining Capacity Estimate"
  assert_contains "$name" "$out" "Inferred total limit"
  assert_contains "$name" "$out" "Remaining tokens"
  assert_contains "$name" "$out" "tokens/hr"
  pass_case "$name"
}

case_remaining_with_calibration() {
  local name="remaining_with_calibration" home out
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_task" 120000 "op1"
  write_log "$home" "$t2" "codex_task"  80000 "op2"
  write_calib "$home" 600000
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 60 > "$out" 2> "$out.err"
  assert_contains "$name" "$out" "Calibrated limit"
  assert_contains "$name" "$out" "600,000"
  assert_contains "$name" "$out" "from calibration"
  assert_contains "$name" "$out" "Inferred total limit"
  pass_case "$name"
}

case_remaining_out_of_range_high() {
  local name="remaining_out_of_range_high" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --remaining 101 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 2
  assert_contains "$name" "$out.err" "0"
  pass_case "$name"
}

case_remaining_out_of_range_low() {
  local name="remaining_out_of_range_low" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --remaining -5 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 2
  assert_contains "$name" "$out.err" "0"
  pass_case "$name"
}

case_remaining_not_a_number() {
  local name="remaining_not_a_number" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --remaining abc > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 2
  assert_contains "$name" "$out.err" "must be a number"
  pass_case "$name"
}

case_remaining_missing_value() {
  local name="remaining_missing_value" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --remaining > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 2
  assert_contains "$name" "$out.err" "requires a value"
  pass_case "$name"
}

case_remaining_100_no_calibration() {
  local name="remaining_100_no_calibration" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 50000 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 100 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "cannot estimate"
  pass_case "$name"
}

case_remaining_0_percent() {
  local name="remaining_0_percent" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_task" 100000 "op1"
  write_log "$home" "$t2" "codex_task" 100000 "op2"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 0 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "0  [inferred"
  assert_not_contains "$name" "$out" "tokens/hr"
  pass_case "$name"
}

case_remaining_calibration_divergence_warning() {
  local name="remaining_calibration_divergence" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_task" 200000 "op1"  # infers ~500k total
  write_log "$home" "$t2" "codex_task"       0 ""
  write_calib "$home" 900000  # calibrated = 900k, inferred = 500k → 80% diff
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 60 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out.err" "differs"
  pass_case "$name"
}

case_remaining_codex_dispatch_counted() {
  local name="remaining_codex_dispatch" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "pm_analysis" 50000 "claude op"
  write_log "$home" "$t2" "codex_dispatch" 155000 "codex op" codex
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "Codex   : 155,000 tokens  (1 logged)"
  assert_contains "$name" "$out" "205,000"
  assert_not_contains "$name" "$out" "310,000"
  assert_occurrences "$name" "$out" "Codex   : 155,000" 1
  pass_case "$name"
}

case_codex_old_log_excluded() {
  local name="codex_old_log_excluded" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "pm_analysis" 50000 "claude op"
  write_log "$home" "2020-01-01T00:00:00Z" "codex_dispatch" 999000 "old codex op" codex
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --5h > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "last 5h"
  assert_not_contains "$name" "$out" "999,000"
  pass_case "$name"
}

case_one_dispatch_one_count() {
  local name="one_dispatch_one_count" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_dispatch" 155000 "codex op" codex
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "155,000"
  assert_not_contains "$name" "$out" "310,000"
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

case_log_pool_codex
case_log_pool_default
case_log_pool_spark
case_remaining_excludes_codex_pool
case_remaining_no_claude_log
case_remaining_mixed_pools_correct_total

case_remaining_basic_no_calibration
case_remaining_with_calibration
case_remaining_out_of_range_high
case_remaining_out_of_range_low
case_remaining_not_a_number
case_remaining_missing_value
case_remaining_100_no_calibration
case_remaining_0_percent
case_remaining_calibration_divergence_warning
case_remaining_codex_dispatch_counted
case_codex_old_log_excluded
case_one_dispatch_one_count

echo
echo "----"
echo "$PASS passed, 0 failed"
echo "test-usage-tracker: all cases pass"
