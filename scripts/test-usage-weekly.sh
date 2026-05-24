#!/usr/bin/env bash
# Fixture-driven regression suite for usage-weekly.sh.
#
# Usage:
#   scripts/test-usage-weekly.sh           # print PASS per case
#   VERBOSE=1 scripts/test-usage-weekly.sh # include command diagnostics on failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USAGE="$SCRIPT_DIR/usage-weekly.sh"
CURRENT_DATE="$(date -d '4 days ago' +%F 2>/dev/null || date -v -4d +%F 2>/dev/null || printf '2026-05-01')"

# touch_days_ago FILE DAYS — portable mtime setter (GNU + BSD).
touch_days_ago() {
  local file="$1" days="$2" stamp=""
  stamp="$(date -d "$days days ago" +%Y%m%d%H%M 2>/dev/null \
    || date -v -${days}d +%Y%m%d%H%M 2>/dev/null \
    || true)"
  if [ -n "$stamp" ]; then
    touch -t "$stamp" "$file"
  fi
}

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init --format=indent-2sp --fail-fast "$@"
TMP_ROOT="$tmp_root"

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -q -F -- "$needle" "$file"; then
    fail "$name" "unexpected substring: $needle"
  fi
}

assert_matches() {
  local name="$1" file="$2" pattern="$3"
  if ! grep -E -q -- "$pattern" "$file"; then
    fail "$name" "missing pattern: $pattern"
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

# make_path_with_bsd_tools — prepend PATH with fake date/stat that fail the GNU
# -d / -c flags and succeed on BSD -v / -r / -f flags (via real GNU under the
# hood). All other PATH commands remain accessible from the original PATH.
make_path_with_bsd_tools() {
  local bin real_date real_stat
  bin="$TMP_ROOT/bsd-tools-bin"
  real_date="$(command -v date)"
  real_stat="$(command -v stat)"
  mkdir -p "$bin"
  cat > "$bin/date" << FAKEDATE
#!/bin/bash
case "\${1:-}" in
  -d) exit 1 ;;
  -v)
    adj="\${2:-0d}"; n="\${adj#-}"; n="\${n%d}"
    shift 2; exec $real_date -d "\$n days ago" "\$@" ;;
  -r)
    shift; exec $real_date -d "@\$1" "\${@:2}" ;;
  *) exec $real_date "\$@" ;;
esac
FAKEDATE
  chmod +x "$bin/date"
  cat > "$bin/stat" << FAKESTAT
#!/bin/bash
case "\${1:-}" in
  -c) exit 1 ;;
  -f)
    fmt="\${2:-}"; file="\${3:-}"
    case "\$fmt" in
      %m) exec $real_stat -c %Y "\$file" ;;
      %z) exec $real_stat -c %s "\$file" ;;
      *) exit 1 ;;
    esac ;;
  *) exec $real_stat "\$@" ;;
esac
FAKESTAT
  chmod +x "$bin/stat"
  for cmd in find jq du; do
    local p
    p="$(command -v "$cmd" 2>/dev/null || true)"
    [ -n "$p" ] && ln -sf "$p" "$bin/$cmd"
  done
  printf '%s:%s\n' "$bin" "$PATH"
}

case_happy_path_dailyActivity_array() {
  local name="happy_path_dailyActivity_array" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[{\"date\":\"$CURRENT_DATE\",\"messageCount\":100,\"sessionCount\":5,\"toolCallCount\":50}]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 100 | 5 | 50 |"
  pass "$name"
}

case_schema_dailyActivity_object() {
  local name="schema_dailyActivity_object" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":{\"$CURRENT_DATE\":{\"messages\":101,\"sessions\":6,\"toolCalls\":51}}}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 101 | 6 | 51 |"
  pass "$name"
}

case_schema_days_array() {
  local name="schema_days_array" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputed\":\"$CURRENT_DATE\",\"days\":[{\"date\":\"$CURRENT_DATE\",\"message_count\":102,\"session_count\":7,\"tool_calls\":52}]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 102 | 7 | 52 |"
  pass "$name"
}

case_schema_daily_object() {
  local name="schema_daily_object" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"computedAt\":\"${CURRENT_DATE}T00:00:00Z\",\"daily\":{\"$CURRENT_DATE\":{\"messageCount\":103,\"sessionCount\":8,\"toolUseCount\":53}}}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 103 | 8 | 53 |"
  pass "$name"
}

case_empty_dailyActivity_array() {
  local name="empty_dailyActivity_array" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_not_contains "$name" "$out" "schema-mismatch"
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 0 | 0 | 0 |"
  pass "$name"
}

case_missing_stats_cache() {
  local name="missing_stats_cache" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "(stats-cache.json not found)"
  pass "$name"
}

case_stale_boundary_2d() {
  # Verifies that a stats-cache.json modified 2 days ago produces no stale
  # warning (boundary: ≤2d is considered fresh).
  # Steps:
  #   1. Write stats file and set mtime to 2 days ago with touch_days_ago
  #   2. Run usage and assert neither stale marker appears in the output
  local name="stale_boundary_2d" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"
  touch_days_ago "$home/.claude/stats-cache.json" 2

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_not_contains "$name" "$out" "(slightly stale"
  assert_not_contains "$name" "$out" "(stale"
  pass "$name"
}

case_stale_boundary_3d() {
  # Verifies that a stats-cache.json modified 3 days ago emits a soft stale
  # warning "(slightly stale, last computed YYYY-MM-DD)" (threshold: >2d).
  # Steps:
  #   1. Write stats file and set mtime to 3 days ago with touch_days_ago
  #   2. Run usage and assert the soft-stale pattern matches and hard-stale does not
  local name="stale_boundary_3d" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"
  touch_days_ago "$home/.claude/stats-cache.json" 3

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_matches "$name" "$out" '\(slightly stale, last computed [0-9]{4}-[0-9]{2}-[0-9]{2}\)'
  assert_not_contains "$name" "$out" "(stale >"
  pass "$name"
}

case_stale_boundary_14d() {
  local name="stale_boundary_14d" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"
  touch_days_ago "$home/.claude/stats-cache.json" 14

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_not_contains "$name" "$out" "(stale >14d"
  pass "$name"
}

case_stale_boundary_15d() {
  local name="stale_boundary_15d" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"
  touch_days_ago "$home/.claude/stats-cache.json" 15

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_matches "$name" "$out" '\(stale >14d, last computed [0-9]{4}-[0-9]{2}-[0-9]{2}\)'
  pass "$name"
}

case_model_tokens_array() {
  # Verifies that dailyModelTokens in array form is aggregated over the 7-day
  # window and printed as "- model: tokens" lines.
  # Steps:
  #   1. Write stats with dailyModelTokens as an array containing one entry for today
  #   2. Run usage and assert the model/token line appears in the output
  local name="model_tokens_array" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[],\"dailyModelTokens\":[{\"date\":\"$CURRENT_DATE\",\"tokensByModel\":{\"claude-sonnet-4-6\":1234}}]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "- claude-sonnet-4-6: 1234"
  pass "$name"
}

case_model_tokens_object() {
  # Verifies that dailyModelTokens in object form (keyed by date) is
  # aggregated and printed as "- model: tokens" lines.
  # Steps:
  #   1. Write stats with dailyModelTokens as an object with one date key for today
  #   2. Run usage and assert the model/token line appears in the output
  local name="model_tokens_object" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[],\"dailyModelTokens\":{\"$CURRENT_DATE\":{\"tokensByModel\":{\"claude-opus-4-7\":5678}}}}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "- claude-opus-4-7: 5678"
  pass "$name"
}

case_corrupt_json() {
  local name="corrupt_json" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  printf '{not valid json\n' > "$home/.claude/stats-cache.json"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 0 | 0 | 0 |"
  pass "$name"
}

case_jq_missing() {
  local name="jq_missing" home out status no_jq_path
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  no_jq_path="$(make_path_without_jq)"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"

  run_usage "$home" "$out" "$no_jq_path"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "(tool missing: jq)"
  pass "$name"
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
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 1 |"
  pass "$name"
}

case_read_only_invariant() {
  local name="read_only_invariant" home out status before after stat_before stat_after
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[{\"date\":\"$CURRENT_DATE\",\"messageCount\":1,\"sessionCount\":1,\"toolCallCount\":1}]}"
  stat_before="$(stat -c '%i %Y' "$home/.claude/stats-cache.json" 2>/dev/null || stat -f '%i %m' "$home/.claude/stats-cache.json" 2>/dev/null || true)"
  before="$TMP_ROOT/$name.before"
  after="$TMP_ROOT/$name.after"
  snapshot_home "$home" "$before"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  stat_after="$(stat -c '%i %Y' "$home/.claude/stats-cache.json" 2>/dev/null || stat -f '%i %m' "$home/.claude/stats-cache.json" 2>/dev/null || true)"
  if [[ "$stat_after" != "$stat_before" ]]; then
    fail "$name" "stats-cache.json inode/mtime changed"
  fi
  snapshot_home "$home" "$after"
  if ! cmp -s "$before" "$after"; then
    [[ "${VERBOSE:-}" ]] && diff -u "$before" "$after" || true
    fail "$name" "HOME directory listing changed"
  fi
  pass "$name"
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
  assert_file_contains "$name" "$out" "## Claude"
  assert_file_contains "$name" "$out" "## Codex"
  if [[ "$last" != Data\ freshness:* ]]; then
    fail "$name" "unexpected final line: $last"
  fi
  pass "$name"
}

case_mixed_schema_empty_preferred_populated_alternate() {
  # Verifies that when the preferred key (dailyActivity) is an empty array and
  # an alternate key (days) has populated entries, the populated key wins.
  # Steps:
  #   1. Write stats with dailyActivity:[] and days:[{populated}] for today
  #   2. Run usage and assert the populated days data is displayed in the table
  local name="mixed_schema_empty_preferred_populated_alternate" home out status
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[],\"days\":[{\"date\":\"$CURRENT_DATE\",\"message_count\":99,\"session_count\":3,\"tool_calls\":33}]}"

  run_usage "$home" "$out"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 99 | 3 | 33 |"
  pass "$name"
}

case_bsd_date_fallback() {
  # Verifies that date_for_offset and epoch_to_date use the BSD -v / -r
  # fallback when GNU date -d fails, producing a valid weekly report.
  # Steps:
  #   1. Write stats without a lastComputedDate field so epoch_to_date is exercised
  #   2. Run usage with a PATH containing a BSD-only fake date (fails GNU -d)
  #   3. Assert exit 0, a valid header date range, and a real date in the footer
  local name="bsd_date_fallback" home out status bsd_path
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  write_stats "$home" "{\"dailyActivity\":[]}"
  bsd_path="$(make_path_with_bsd_tools)"

  run_usage "$home" "$out" "$bsd_path"; status=$?
  assert_exit "$name" "$status" 0
  assert_matches "$name" "$out" '^# Weekly Usage Report [0-9]{4}-[0-9]{2}-[0-9]{2} ~ [0-9]{4}-[0-9]{2}-[0-9]{2}$'
  # epoch_to_date via BSD date -r must produce a real date, not "n/a"
  assert_matches "$name" "$out" 'Data freshness: Claude stats-cache\.json last computed [0-9]{4}-[0-9]{2}-[0-9]{2}\.'
  pass "$name"
}

case_bsd_stat_fallback() {
  # Verifies that file_size uses the BSD stat -f fallback when GNU stat -c
  # fails, reporting a non-zero byte count for a codex session file.
  # Steps:
  #   1. Write a codex session JSONL file for today with known content
  #   2. Run usage with a PATH containing a BSD-only fake stat (fails GNU -c)
  #   3. Assert exit 0 and the codex table shows 1 session with non-zero bytes
  local name="bsd_stat_fallback" home out status bsd_path y m d dir
  home="$(new_home "$name")"
  out="$TMP_ROOT/$name.out"
  y="${CURRENT_DATE:0:4}"
  m="${CURRENT_DATE:5:2}"
  d="${CURRENT_DATE:8:2}"
  dir="$home/.codex/sessions/$y/$m/$d"
  mkdir -p "$dir"
  printf '{"type":"event"}\n' > "$dir/session.jsonl"
  write_stats "$home" "{\"lastComputedDate\":\"$CURRENT_DATE\",\"dailyActivity\":[]}"
  bsd_path="$(make_path_with_bsd_tools)"

  run_usage "$home" "$out" "$bsd_path"; status=$?
  assert_exit "$name" "$status" 0
  assert_file_contains "$name" "$out" "| $CURRENT_DATE | 1 |"
  assert_not_contains "$name" "$out" "| $CURRENT_DATE | 1 | 0 |"
  pass "$name"
}

run_case() {
  local name="$1" fn="$2"
  should_run "$name" || return 0
  "$fn"
}

if ! $LIST; then
  echo "== usage-weekly =="
fi

run_case "happy_path_dailyActivity_array" case_happy_path_dailyActivity_array
run_case "schema_dailyActivity_object" case_schema_dailyActivity_object
run_case "schema_days_array" case_schema_days_array
run_case "schema_daily_object" case_schema_daily_object
run_case "empty_dailyActivity_array" case_empty_dailyActivity_array
run_case "mixed_schema_empty_preferred_populated_alternate" case_mixed_schema_empty_preferred_populated_alternate
run_case "missing_stats_cache" case_missing_stats_cache
run_case "stale_boundary_2d" case_stale_boundary_2d
run_case "stale_boundary_3d" case_stale_boundary_3d
run_case "stale_boundary_14d" case_stale_boundary_14d
run_case "stale_boundary_15d" case_stale_boundary_15d
run_case "model_tokens_array" case_model_tokens_array
run_case "model_tokens_object" case_model_tokens_object
run_case "corrupt_json" case_corrupt_json
run_case "jq_missing" case_jq_missing
run_case "bsd_date_fallback" case_bsd_date_fallback
run_case "bsd_stat_fallback" case_bsd_stat_fallback
run_case "codex_session_filename_with_space" case_codex_session_filename_with_space
run_case "read_only_invariant" case_read_only_invariant
run_case "output_contract" case_output_contract

if ! $LIST; then
  echo
  echo "----"
fi
th_summary
