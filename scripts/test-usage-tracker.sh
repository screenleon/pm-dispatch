#!/usr/bin/env bash
# Fixture-driven regression suite for log-usage.sh and token-usage.sh.
#
# Usage:
#   scripts/test-usage-tracker.sh           # print PASS per case
#   VERBOSE=1 scripts/test-usage-tracker.sh # include diagnostics on failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_SCRIPT="$SCRIPT_DIR/log-usage.sh"
VIEW_SCRIPT="$SCRIPT_DIR/token-usage.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init --format=indent-2sp --fail-fast "$@"
TMP_ROOT="$tmp_root"

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

if ! $LIST; then
  echo "== log-usage =="
fi

case_happy_path() {
  local name="happy_path" home status
  home="$(new_home "$name")"
  run_log "$home" pr_gate_full 390000 "JapanJob PR #24"; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  [[ -f "$logfile" ]] || fail "$name" "logfile not created"
  assert_file_contains "$name" "$logfile" '"type":"pr_gate_full"'
  assert_file_contains "$name" "$logfile" '"tokens":390000'
  assert_file_contains "$name" "$logfile" '"note":"JapanJob PR #24"'
  assert_line_count "$name" "$logfile" 1
  pass "$name"
}

case_note_single_quote() {
  local name="note_single_quote" home status out
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  run_log "$home" pm_analysis 5000 "it's done" > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  assert_file_contains "$name" "$logfile" '"note":"it'"'"'s done"'
  assert_line_count "$name" "$logfile" 1
  pass "$name"
}

case_note_double_quote() {
  local name="note_double_quote" home status
  home="$(new_home "$name")"
  run_log "$home" codex_task 10000 'fix "thing"'; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  assert_file_contains "$name" "$logfile" '"note":"fix \"thing\""'
  assert_line_count "$name" "$logfile" 1
  pass "$name"
}

case_note_backslash() {
  local name="note_backslash" home status
  home="$(new_home "$name")"
  run_log "$home" codex_task 10000 'path\to\thing'; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  assert_file_contains "$name" "$logfile" '"note":"path\\to\\thing"'
  assert_line_count "$name" "$logfile" 1
  pass "$name"
}

case_note_unicode() {
  local name="note_unicode" home status
  home="$(new_home "$name")"
  run_log "$home" pm_synthesis 3000 "已完成 #14 重構"; status=$?
  assert_exit "$name" "$status" 0
  local logfile="$home/.claude/usage-tracker.jsonl"
  assert_file_contains "$name" "$logfile" '"note":"已完成 #14 重構"'
  assert_line_count "$name" "$logfile" 1
  pass "$name"
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
  pass "$name"
}

case_tokens_not_integer() {
  local name="tokens_not_integer" home status out
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  run_log "$home" codex_task "notanumber" "some note" > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 2
  local logfile="$home/.claude/usage-tracker.jsonl"
  [[ ! -f "$logfile" ]] || assert_line_count "$name" "$logfile" 0
  pass "$name"
}

case_tokens_float_rejected() {
  local name="tokens_float_rejected" home status
  home="$(new_home "$name")"
  run_log "$home" codex_task "3.14" "pi" > /dev/null 2>&1; status=$?
  assert_exit "$name" "$status" 2
  pass "$name"
}

case_multiple_appends() {
  local name="multiple_appends" home
  home="$(new_home "$name")"
  run_log "$home" pr_gate_express 80000 "first"
  run_log "$home" codex_task      50000 "second"
  run_log "$home" pm_synthesis    15000 "third"
  assert_line_count "$name" "$home/.claude/usage-tracker.jsonl" 3
  pass "$name"
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
  pass "$name"
}

case_file_permissions() {
  local name="file_permissions" home perms
  home="$(new_home "$name")"
  run_log "$home" codex_task 1 ""
  perms=$(stat -c '%a' "$home/.claude/usage-tracker.jsonl")
  [[ "$perms" == "600" ]] || fail "$name" "expected 600 perms, got $perms"
  pass "$name"
}

# ---------------------------------------------------------------------------
# token-usage.sh tests
# ---------------------------------------------------------------------------

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
  assert_file_contains "$name" "$out" "No usage log"
  pass "$name"
}

case_view_empty_logfile() {
  local name="view_empty_logfile" home out status
  home="$(new_home "$name")"
  touch "$home/.claude/usage-tracker.jsonl"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "Total"
  pass "$name"
}

case_view_all_mode() {
  local name="view_all_mode" home out status
  home="$(new_home "$name")"
  write_log "$home" "2020-01-01T00:00:00Z" "codex_task" 50000 "old entry"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "all time"
  assert_file_contains "$name" "$out" "50,000"
  pass "$name"
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
  assert_file_contains "$name" "$out" "today (UTC)"
  assert_file_contains "$name" "$out" "40,000"
  assert_not_contains "$name" "$out" "99,999"
  pass "$name"
}

case_view_unknown_mode() {
  local name="view_unknown_mode" home out status
  home="$(new_home "$name")"
  touch "$home/.claude/usage-tracker.jsonl"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --foobar > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 2
  pass "$name"
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
  assert_file_contains "$name" "$out.err" "skipped"
  assert_file_contains "$name" "$out" "5,000"
  pass "$name"
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
  assert_file_contains "$name" "$out.err" "skipped"
  assert_file_contains "$name" "$out" "1,000"
  assert_not_contains "$name" "$out" "9,999"
  pass "$name"
}

case_view_malformed_calibration_warns() {
  local name="view_malformed_calibration_warns" home out status
  home="$(new_home "$name")"
  printf 'not json\n' > "$home/.claude/usage-calibration.json"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out.err" "malformed"
  pass "$name"
}

case_round_trip() {
  # Entry written by log-usage.sh is readable and counted by token-usage.sh
  local name="round_trip" home out status
  home="$(new_home "$name")"
  HOME="$home" /bin/bash "$LOG_SCRIPT" reviewer_critic 80000 "round-trip test"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2>&1; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "80,000"
  assert_file_contains "$name" "$out" "reviewer_critic"
  pass "$name"
}

# ---------------------------------------------------------------------------
# log-usage.sh pool field tests
# ---------------------------------------------------------------------------

case_log_pool_codex() {
  local name="log_pool_codex" home status
  home="$(new_home "$name")"
  run_log "$home" codex_dispatch 1100 "dispatch" "" codex; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$home/.claude/usage-tracker.jsonl" '"pool":"codex"'
  pass "$name"
}

case_log_pool_default() {
  local name="log_pool_default" home status
  home="$(new_home "$name")"
  run_log "$home" session_total 2200 "session"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$home/.claude/usage-tracker.jsonl" '"pool":"claude"'
  pass "$name"
}

case_log_pool_spark() {
  local name="log_pool_spark" home status
  home="$(new_home "$name")"
  run_log "$home" codex_dispatch 3300 "spark dispatch" "" spark; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$home/.claude/usage-tracker.jsonl" '"pool":"spark"'
  pass "$name"
}

case_log_pool_invalid() {
  local name="log_pool_invalid" home status err
  home="$(new_home "$name")"
  err="$TMP_ROOT/$name.err"
  HOME="$home" /bin/bash "$LOG_SCRIPT" codex_dispatch 1100 "test" "" badpool > /dev/null 2> "$err"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$home/.claude/usage-tracker.jsonl" '"pool":"claude"'
  assert_file_contains "$name" "$err" "unknown pool"
  pass "$name"
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
  assert_file_contains "$name" "$out" "Tokens used (Claude pool) : 100,000"
  assert_file_contains "$name" "$out" "Inferred total limit      : 200,000"
  assert_file_contains "$name" "$out" "Separate quota tokens     : Codex 5,000,000"
  assert_not_contains "$name" "$out" "10,200,000"
  pass "$name"
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
  assert_file_contains "$name" "$out" "no Claude log data"
  assert_file_contains "$name" "$out" "rate unknown"
  pass "$name"
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
  assert_file_contains "$name" "$out" "Claude  : 100,000"
  assert_file_contains "$name" "$out" "Codex   : 200,000"
  assert_file_contains "$name" "$out" "Total   : 300,000"
  assert_file_contains "$name" "$out" "Inferred total limit      : 200,000"
  pass "$name"
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

case_remaining_basic_no_calibration() {
  local name="remaining_basic_no_calibration" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_task"   120000 "first op"
  write_log "$home" "$t2" "pm_analysis"   80000 "second op"
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 60 > "$out" 2> "$out.err"; status=$?
  assert_file_contains "$name" "$out" "Remaining Capacity Estimate"
  assert_file_contains "$name" "$out" "Inferred total limit"
  assert_file_contains "$name" "$out" "Remaining tokens"
  assert_file_contains "$name" "$out" "tokens/hr"
  assert_exit "$name" "$status" 0
  pass "$name"
}

case_remaining_with_calibration() {
  local name="remaining_with_calibration" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)"
  local t2; t2="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_task" 120000 "op1"
  write_log "$home" "$t2" "codex_task"  80000 "op2"
  write_calib "$home" 600000
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 60 > "$out" 2> "$out.err"; status=$?
  assert_file_contains "$name" "$out" "Calibrated limit"
  assert_file_contains "$name" "$out" "600,000"
  assert_file_contains "$name" "$out" "from calibration"
  assert_file_contains "$name" "$out" "Inferred total limit"
  assert_exit "$name" "$status" 0
  pass "$name"
}

case_remaining_out_of_range_high() {
  local name="remaining_out_of_range_high" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --remaining 101 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 2
  assert_file_contains "$name" "$out.err" "0"
  pass "$name"
}

case_remaining_out_of_range_low() {
  local name="remaining_out_of_range_low" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --remaining -5 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 2
  assert_file_contains "$name" "$out.err" "0"
  pass "$name"
}

case_remaining_not_a_number() {
  local name="remaining_not_a_number" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --remaining abc > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 2
  assert_file_contains "$name" "$out.err" "must be a number"
  pass "$name"
}

case_remaining_missing_value() {
  local name="remaining_missing_value" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --remaining > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out.err" "not found"
  pass "$name"
}

case_remaining_100_no_calibration() {
  local name="remaining_100_no_calibration" home out status
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 50000 ""
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all --remaining 100 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "cannot estimate"
  pass "$name"
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
  assert_file_contains "$name" "$out" "0  [inferred"
  assert_not_contains "$name" "$out" "tokens/hr"
  pass "$name"
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
  assert_file_contains "$name" "$out.err" "differs"
  pass "$name"
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
  assert_file_contains "$name" "$out" "Codex   : 155,000 tokens  (1 logged)"
  assert_file_contains "$name" "$out" "205,000"
  assert_not_contains "$name" "$out" "310,000"
  assert_occurrences "$name" "$out" "Codex   : 155,000" 1
  pass "$name"
}

case_remaining_auto_valid_file() {
  # Verifies that --remaining auto-reads a fresh rate-limits.json and prints
  # the derived remaining percentage without requiring a manual argument.
  # Steps:
  #   1. Write a rate-limits.json with five_hour.used_percentage=25 and a current timestamp
  #   2. Run token-usage.sh --remaining (no N argument) with CLAUDE_CONFIG_DIR pointing to the file
  #   3. Assert exit 0 and output contains "Remaining (from dashboard): 75"
  local name="remaining_auto_valid_file" home out status rl_dir rl_file
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  rl_dir="$(mktemp -d)"
  rl_file="$rl_dir/rate-limits.json"
  python3 -c "import json,time; json.dump({'updated_at':int(time.time()),'five_hour':{'used_percentage':25,'resets_at':9999999999},'seven_day':{'used_percentage':10,'resets_at':9999999999}}, open('$rl_file','w'))"
  out="$TMP_ROOT/$name.out"
  HOME="$home" CLAUDE_CONFIG_DIR="$rl_dir" /bin/bash "$VIEW_SCRIPT" --remaining > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "Remaining (from dashboard): 75"
  rm -rf "$rl_dir"
  pass "$name"
}

case_remaining_auto_stale_warning() {
  # Verifies that a rate-limits.json with a very old updated_at causes a staleness
  # warning on stderr while still exiting 0 and printing a percentage.
  # Steps:
  #   1. Write a rate-limits.json with updated_at=1000000 (epoch far in the past)
  #   2. Run token-usage.sh --remaining with CLAUDE_CONFIG_DIR pointing to the file
  #   3. Assert exit 0 and stderr contains "old" or "stale"
  local name="remaining_auto_stale_warning" home out status rl_dir
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  rl_dir="$(mktemp -d)"
  python3 -c "import json; json.dump({'updated_at':1000000,'five_hour':{'used_percentage':30,'resets_at':9999999999}}, open('$rl_dir/rate-limits.json','w'))"
  out="$TMP_ROOT/$name.out"
  HOME="$home" CLAUDE_CONFIG_DIR="$rl_dir" /bin/bash "$VIEW_SCRIPT" --remaining > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  if grep -Eq "old|stale" "$out.err"; then
    rm -rf "$rl_dir"
    pass "$name"
  else
    rm -rf "$rl_dir"
    fail "$name" "expected staleness warning, got: $(head -5 "$out.err")"
  fi
}

case_remaining_auto_missing_file() {
  # Verifies that --remaining auto-mode exits 0 and emits a "not found" note when
  # rate-limits.json does not exist (guides user to install the StatusLine hook).
  # Steps:
  #   1. Point CLAUDE_CONFIG_DIR to an empty directory (no rate-limits.json)
  #   2. Run token-usage.sh --remaining
  #   3. Assert exit 0 and stderr contains "not found" or "rate-limits"
  local name="remaining_auto_missing_file" home out status rl_dir
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  rl_dir="$(mktemp -d)"
  out="$TMP_ROOT/$name.out"
  HOME="$home" CLAUDE_CONFIG_DIR="$rl_dir" /bin/bash "$VIEW_SCRIPT" --remaining > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  if grep -Eqi "not found|rate-limits" "$out.err"; then
    rm -rf "$rl_dir"
    pass "$name"
  else
    rm -rf "$rl_dir"
    fail "$name" "expected missing-file note, got: $(head -3 "$out.err")"
  fi
}

case_remaining_auto_out_of_range_percentage() {
  # Verifies that a rate-limits.json with five_hour.used_percentage outside 0-100
  # emits an "out of range" warning, exits 0, and does not print a derived percentage.
  # Steps:
  #   1. Write a rate-limits.json with five_hour.used_percentage=150
  #   2. Run token-usage.sh --remaining with CLAUDE_CONFIG_DIR pointing to the file
  #   3. Assert exit 0, stderr contains "out of range", stdout has no "Remaining (from dashboard)"
  local name="remaining_auto_out_of_range_percentage" home out status rl_dir
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  rl_dir="$(mktemp -d)"
  python3 -c "import json,time; json.dump({'updated_at':int(time.time()),'five_hour':{'used_percentage':150,'resets_at':9999999999}}, open('$rl_dir/rate-limits.json','w'))"
  out="$TMP_ROOT/$name.out"
  HOME="$home" CLAUDE_CONFIG_DIR="$rl_dir" /bin/bash "$VIEW_SCRIPT" --remaining > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  if grep -qi "out of range" "$out.err" && ! grep -q "Remaining (from dashboard)" "$out"; then
    rm -rf "$rl_dir"
    pass "$name"
  else
    rm -rf "$rl_dir"
    fail "$name" "expected out-of-range warning and no derived percentage, got stderr: $(head -3 "$out.err")"
  fi
}

case_remaining_auto_no_five_hour_key() {
  # Verifies that a rate-limits.json missing five_hour.used_percentage emits a
  # warning and exits 0 without printing a derived remaining percentage.
  # Steps:
  #   1. Write a rate-limits.json that has seven_day but no five_hour key
  #   2. Run token-usage.sh --remaining with CLAUDE_CONFIG_DIR pointing to the file
  #   3. Assert exit 0 and stderr contains "no five_hour"
  local name="remaining_auto_no_five_hour_key" home out status rl_dir
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  rl_dir="$(mktemp -d)"
  python3 -c "import json,time; json.dump({'updated_at':int(time.time()),'seven_day':{'used_percentage':10,'resets_at':9999999999}}, open('$rl_dir/rate-limits.json','w'))"
  out="$TMP_ROOT/$name.out"
  HOME="$home" CLAUDE_CONFIG_DIR="$rl_dir" /bin/bash "$VIEW_SCRIPT" --remaining > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  if grep -qi "no five_hour" "$out.err"; then
    rm -rf "$rl_dir"
    pass "$name"
  else
    rm -rf "$rl_dir"
    fail "$name" "expected no-five_hour warning, got: $(head -3 "$out.err")"
  fi
}

case_remaining_auto_malformed_json() {
  # Verifies that a malformed rate-limits.json exits 0, emits a "could not read"
  # warning, and does not print a derived remaining percentage.
  # Steps:
  #   1. Write a non-JSON file as rate-limits.json
  #   2. Run token-usage.sh --remaining with CLAUDE_CONFIG_DIR pointing to the file
  #   3. Assert exit 0 and stderr contains "could not read"
  local name="remaining_auto_malformed_json" home out status rl_dir
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  rl_dir="$(mktemp -d)"
  printf 'not valid json{{{\n' > "$rl_dir/rate-limits.json"
  out="$TMP_ROOT/$name.out"
  HOME="$home" CLAUDE_CONFIG_DIR="$rl_dir" /bin/bash "$VIEW_SCRIPT" --remaining > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  if grep -qi "could not read" "$out.err"; then
    rm -rf "$rl_dir"
    pass "$name"
  else
    rm -rf "$rl_dir"
    fail "$name" "expected could-not-read warning, got: $(head -3 "$out.err")"
  fi
}

case_remaining_manual_n_unchanged() {
  # Verifies that providing an explicit N value to --remaining uses that value
  # directly and ignores any rate-limits.json in the config directory.
  # Steps:
  #   1. Point CLAUDE_CONFIG_DIR to an empty directory (no rate-limits.json)
  #   2. Run token-usage.sh --remaining 60
  #   3. Assert exit 0 and output contains "Remaining (from dashboard): 60"
  local name="remaining_manual_N_unchanged" home out status rl_dir
  home="$(new_home "$name")"
  write_log "$home" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "codex_task" 1 ""
  rl_dir="$(mktemp -d)"
  out="$TMP_ROOT/$name.out"
  HOME="$home" CLAUDE_CONFIG_DIR="$rl_dir" /bin/bash "$VIEW_SCRIPT" --remaining 60 > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "Remaining (from dashboard): 60"
  rm -rf "$rl_dir"
  pass "$name"
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
  assert_file_contains "$name" "$out" "last 5h"
  assert_not_contains "$name" "$out" "999,000"
  pass "$name"
}

case_one_dispatch_one_count() {
  local name="one_dispatch_one_count" home out status
  home="$(new_home "$name")"
  local t1; t1="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
  write_log "$home" "$t1" "codex_dispatch" 155000 "codex op" codex
  out="$TMP_ROOT/$name.out"
  HOME="$home" /bin/bash "$VIEW_SCRIPT" --all > "$out" 2> "$out.err"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "155,000"
  assert_not_contains "$name" "$out" "310,000"
  pass "$name"
}

run_case() {
  local name="$1" fn="$2"
  should_run "$name" || return 0
  "$fn"
}

run_case "happy_path" case_happy_path
run_case "note_single_quote" case_note_single_quote
run_case "note_double_quote" case_note_double_quote
run_case "note_backslash" case_note_backslash
run_case "note_unicode" case_note_unicode
run_case "note_injection_attempt" case_note_injection_attempt
run_case "tokens_not_integer" case_tokens_not_integer
run_case "tokens_float_rejected" case_tokens_float_rejected
run_case "multiple_appends" case_multiple_appends
run_case "idempotent_json_per_line" case_idempotent_json_per_line
run_case "file_permissions" case_file_permissions

if ! $LIST; then
  echo
  echo "== token-usage =="
fi

run_case "view_missing_logfile" case_view_missing_logfile
run_case "view_empty_logfile" case_view_empty_logfile
run_case "view_all_mode" case_view_all_mode
run_case "view_today_mode" case_view_today_mode
run_case "view_unknown_mode" case_view_unknown_mode
run_case "view_malformed_line_skipped" case_view_malformed_line_skipped
run_case "view_missing_ts_skipped" case_view_missing_ts_skipped
run_case "view_malformed_calibration_warns" case_view_malformed_calibration_warns
run_case "round_trip" case_round_trip

if ! $LIST; then
  echo
  echo "== log-usage: pool field =="
fi

run_case "log_pool_codex" case_log_pool_codex
run_case "log_pool_default" case_log_pool_default
run_case "log_pool_spark" case_log_pool_spark
run_case "log_pool_invalid" case_log_pool_invalid
run_case "remaining_excludes_codex_pool" case_remaining_excludes_codex_pool
run_case "remaining_no_claude_log" case_remaining_no_claude_log
run_case "remaining_mixed_pools_correct_total" case_remaining_mixed_pools_correct_total

if ! $LIST; then
  echo
  echo "== token-usage: --remaining =="
fi

run_case "remaining_basic_no_calibration" case_remaining_basic_no_calibration
run_case "remaining_with_calibration" case_remaining_with_calibration
run_case "remaining_out_of_range_high" case_remaining_out_of_range_high
run_case "remaining_out_of_range_low" case_remaining_out_of_range_low
run_case "remaining_not_a_number" case_remaining_not_a_number
run_case "remaining_missing_value" case_remaining_missing_value
run_case "remaining_100_no_calibration" case_remaining_100_no_calibration
run_case "remaining_0_percent" case_remaining_0_percent
run_case "remaining_calibration_divergence_warning" case_remaining_calibration_divergence_warning
run_case "remaining_codex_dispatch_counted" case_remaining_codex_dispatch_counted
run_case "remaining_auto_valid_file" case_remaining_auto_valid_file
run_case "remaining_auto_stale_warning" case_remaining_auto_stale_warning
run_case "remaining_auto_missing_file" case_remaining_auto_missing_file
run_case "remaining_auto_out_of_range_percentage" case_remaining_auto_out_of_range_percentage
run_case "remaining_auto_no_five_hour_key" case_remaining_auto_no_five_hour_key
run_case "remaining_auto_malformed_json" case_remaining_auto_malformed_json
run_case "remaining_manual_n_unchanged" case_remaining_manual_n_unchanged
run_case "codex_old_log_excluded" case_codex_old_log_excluded
run_case "one_dispatch_one_count" case_one_dispatch_one_count

if ! $LIST; then
  echo
  echo "----"
fi
th_summary
