#!/usr/bin/env bash
# Fixture-driven regression suite for usage-weekly.sh.
#
# Usage:
#   scripts/test-usage-weekly.sh           # print PASS per case
#   VERBOSE=1 scripts/test-usage-weekly.sh # include command diagnostics on failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USAGE="$SCRIPT_DIR/usage-weekly.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
CURRENT_DATE="$(date -d '4 days ago' +%F 2>/dev/null || printf '2026-05-01')"

fail() {
  local name="$1" detail="${2:-}"
  printf '  FAIL  %s\n' "$name"
  if [[ -n "$detail" ]]; then
    printf '        %s\n' "$detail"
  fi
  exit 1
}

pass_case() {
  local name="$1"
  PASS=$((PASS + 1))
  printf '  PASS  %s\n' "$name"
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -q -F -- "$needle" "$file"; then
    fail "$name" "missing substring: $needle"
  fi
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -q -F -- "$needle" "$file"; then
    fail "$name" "unexpected substring: $needle"
  fi
}

assert_exit() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$name" "expected exit=$expected, got exit=$actual"
  fi
}

new_home() {
  local name="$1"
  local home="$TMP_ROOT/$name"
  mkdir -p "$home/.claude" "$home/.codex/sessions"
  printf '%s\n' "$home"
}

write_stats() {
  local home="$1" body="$2"
  printf '%s\n' "$body" > "$home/.claude/stats-cache.json"
}

run_usage() {
  local home="$1" outfile="$2" path_value="${3:-$PATH}"
  HOME="$home" PATH="$path_value" /bin/bash "$USAGE" > "$outfile" 2> "$outfile.err"
}

snapshot_home() {
  local home="$1" outfile="$2"
  (cd "$home" && find . -printf '%y %p %s %T@\n' | sort) > "$outfile"
}

make_path_without_jq() {
  local bin="$TMP_ROOT/no-jq-bin"
  mkdir -p "$bin"
  ln -s "$(command -v date)" "$bin/date"
  ln -s "$(command -v find)" "$bin/find"
  ln -s "$(command -v stat)" "$bin/stat"
  ln -s "$(command -v du)" "$bin/du"
  printf '%s\n' "$bin"
}

case_happy_path_dailyActivity_array() {
  local name="happy_path_dailyActivity_array" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[{\"date\":\"$CURRENT_DATE\",\"messageCount\":100,\"sessionCount\":5,\"toolCallCount\":50}]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "| $CURRENT_DATE | 100 | 5 | 50 |"
  pass_case "$name"
}

case_schema_dailyActivity_object() {
  local name="schema_dailyActivity_object" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":{\"$CURRENT_DATE\":{\"messages\":101,\"sessions\":6,\"toolCalls\":51}}}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "| $CURRENT_DATE | 101 | 6 | 51 |"
  pass_case "$name"
}

case_schema_days_array() {
  local name="schema_days_array" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputed\":\"$CURRENT_DATE\",\"days\":[{\"date\":\"$CURRENT_DATE\",\"message_count\":102,\"session_count\":7,\"tool_calls\":52}]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "| $CURRENT_DATE | 102 | 7 | 52 |"
  pass_case "$name"
}

case_schema_daily_object() {
  local name="schema_daily_object" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"computedAt\":\"${CURRENT_DATE}T00:00:00Z\",\"daily\":{\"$CURRENT_DATE\":{\"messageCount\":103,\"sessionCount\":8,\"toolUseCount\":53}}}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "| $CURRENT_DATE | 103 | 8 | 53 |"
  pass_case "$name"
}

case_empty_dailyActivity_array() {
  local name="empty_dailyActivity_array" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_not_contains "$name" "$out" "schema-mismatch"
  assert_contains "$name" "$out" "| $CURRENT_DATE | 0 | 0 | 0 |"
  pass_case "$name"
}

case_missing_stats_cache() {
  local name="missing_stats_cache" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "(missing)"
  pass_case "$name"
}

case_stale_boundary_14d() {
  local name="stale_boundary_14d" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"
  touch -d "14 days ago" "$home/.claude/stats-cache.json"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_not_contains "$name" "$out" "(stale"
  pass_case "$name"
}

case_stale_boundary_15d() {
  local name="stale_boundary_15d" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"
  touch -d "15 days ago" "$home/.claude/stats-cache.json"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "(stale, last computed"
  pass_case "$name"
}

case_corrupt_json() {
  local name="corrupt_json" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  printf '{not valid json\n' > "$home/.claude/stats-cache.json"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "| $CURRENT_DATE | 0 | 0 | 0 |"
  pass_case "$name"
}

case_jq_missing() {
  local name="jq_missing" home out status no_jq_path
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  no_jq_path="$(make_path_without_jq)"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"

  run_usage "$home" "$out" "$no_jq_path"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "(tool missing: jq)"
  pass_case "$name"
}

case_codex_session_filename_with_space() {
  local name="codex_session_filename_with_space" home out status y m d dir
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  y="${CURRENT_DATE:0:4}"
  m="${CURRENT_DATE:5:2}"
  d="${CURRENT_DATE:8:2}"
  dir="$home/.codex/sessions/$y/$m/$d"
  mkdir -p "$dir"
  printf '{"type":"event"}\n' > "$dir/session a b.jsonl"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "| $CURRENT_DATE | 1 |"
  pass_case "$name"
}

case_read_only_invariant() {
  local name="read_only_invariant" home out status before after stat_before stat_after
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[{\"date\":\"$CURRENT_DATE\",\"messageCount\":1,\"sessionCount\":1,\"toolCallCount\":1}]}"
  stat_before="$(stat -c '%i %Y' "$home/.claude/stats-cache.json")"
  before="$TMP_ROOT/$name.before"
  after="$TMP_ROOT/$name.after"
  snapshot_home "$home" "$before"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  stat_after="$(stat -c '%i %Y' "$home/.claude/stats-cache.json")"
  if [[ "$stat_after" != "$stat_before" ]]; then
    fail "$name" "stats-cache.json inode/mtime changed"
  fi
  snapshot_home "$home" "$after"
  if ! cmp -s "$before" "$after"; then
    [[ "${VERBOSE:-}" ]] && diff -u "$before" "$after" || true
    fail "$name" "HOME directory listing changed"
  fi
  pass_case "$name"
}

case_output_contract() {
  local name="output_contract" home out status first last
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  first="$(head -n 1 "$out")"
  last="$(tail -n 1 "$out")"
  if [[ ! "$first" =~ ^#\ Weekly\ Usage\ Report\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ \~\ [0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    fail "$name" "unexpected first line: $first"
  fi
  assert_contains "$name" "$out" "## Claude"
  assert_contains "$name" "$out" "## Codex"
  if [[ "$last" != Data\ freshness:* ]]; then
    fail "$name" "unexpected final line: $last"
  fi
  pass_case "$name"
}

echo "== usage-weekly =="

case_happy_path_dailyActivity_array
case_schema_dailyActivity_object
case_schema_days_array
case_schema_daily_object
case_empty_dailyActivity_array
case_missing_stats_cache
case_stale_boundary_14d
case_stale_boundary_15d
case_corrupt_json
case_jq_missing
case_codex_session_filename_with_space
case_read_only_invariant
case_output_contract

echo
echo "----"
echo "$PASS passed, 0 failed"
echo "test-usage-weekly: all cases pass"
