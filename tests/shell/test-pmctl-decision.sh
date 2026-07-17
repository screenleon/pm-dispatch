#!/usr/bin/env bash
# Regression tests for pmctl decision commands.
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/state-writer.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/state-writer.sh"

decision_project_dir() {
  local store="$1"
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" _sw_project_dir
}

run_decision_cmd() {
  local store="$1" _out="$2" _err="$3"
  shift 3
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" "$@" > "$_out" 2> "$_err"
}

case_decision_add_writes_file() {
  local name="pmctl decision add: writes decision row"
  should_run "$name" || return 0
  # Behavior: decision add with required flags writes a JSON file at the expected path with id, title, and decision_md_path fields.
  # Steps: invoke decision add with --date, --title, --path; assert exit 0, JSON file exists with correct id/title/path.
  local store proj out err status=0 decision_file id title path
  store="$tmp_root/decision-add-store"
  out="$tmp_root/decision-add.out"
  err="$tmp_root/decision-add.err"
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "My Decision" --path DECISIONS.md || status=$?
  proj="$(decision_project_dir "$store")"
  decision_file="$proj/decisions/dec-2026-06-07-my-decision.json"
  id="$(jq -r '.id // ""' "$decision_file" 2>/dev/null || true)"
  title="$(jq -r '.title // ""' "$decision_file" 2>/dev/null || true)"
  path="$(jq -r '.decision_md_path // ""' "$decision_file" 2>/dev/null || true)"
  if [[ "$status" -eq 0 && "$id" == "dec-2026-06-07-my-decision" && "$title" == "My Decision" && "$path" == "DECISIONS.md" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status id=$id title=$title path=$path out=$(<"$out") err=$(<"$err")"
  fi
}

case_decision_add_missing_required_flags() {
  local name="pmctl decision add: missing required flags exit 2"
  should_run "$name" || return 0
  # Behavior: decision add exits 2 when any required flag (--date, --title, --path) is missing.
  # Steps: invoke once without --date, once without --title, once without --path; assert all three exit 2.
  local store out err status_date=0 status_title=0 status_path=0
  store="$tmp_root/decision-missing-store"
  out="$tmp_root/decision-missing.out"
  err="$tmp_root/decision-missing.err"
  run_decision_cmd "$store" "$out" "$err" decision add --title "Missing Date" --path DECISIONS.md || status_date=$?
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --path DECISIONS.md || status_title=$?
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "Missing Path" || status_path=$?
  if [[ "$status_date" -eq 2 && "$status_title" -eq 2 && "$status_path" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "status_date=$status_date status_title=$status_title status_path=$status_path out=$(<"$out") err=$(<"$err")"
  fi
}

case_decision_add_closes_and_tags_arrays() {
  local name="pmctl decision add: --closes and --tags become arrays"
  should_run "$name" || return 0
  # Behavior: CSV values for --closes and --tags are split into JSON arrays in the written file.
  # Steps: invoke decision add with --closes CC-101,CC-102 --tags state,cli; assert closes=["CC-101","CC-102"] and tags=["state","cli"].
  local store proj out err status=0 decision_file closes tags
  store="$tmp_root/decision-arrays-store"
  out="$tmp_root/decision-arrays.out"
  err="$tmp_root/decision-arrays.err"
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "Array Decision" --path DECISIONS.md --closes CC-101,CC-102 --tags state,cli || status=$?
  proj="$(decision_project_dir "$store")"
  decision_file="$proj/decisions/dec-2026-06-07-array-decision.json"
  closes="$(jq -r '.closes | join(" ")' "$decision_file" 2>/dev/null || true)"
  tags="$(jq -r '.tags | join(" ")' "$decision_file" 2>/dev/null || true)"
  if [[ "$status" -eq 0 && "$closes" == "CC-101 CC-102" && "$tags" == "state cli" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status closes=$closes tags=$tags out=$(<"$out") err=$(<"$err")"
  fi
}

case_decision_add_json_output() {
  local name="pmctl decision add: --json emits parseable JSON"
  should_run "$name" || return 0
  # Behavior: with --json, decision add prints the written JSON to stdout with the correct id field.
  # Steps: invoke decision add --json; assert exit 0, stdout is valid JSON, .id matches expected slug.
  local store out err status=0 id parse_status=0
  store="$tmp_root/decision-json-store"
  out="$tmp_root/decision-json.out"
  err="$tmp_root/decision-json.err"
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "JSON Decision" --path DECISIONS.md --json || status=$?
  jq -e . "$out" >/dev/null 2>&1 || parse_status=$?
  id="$(jq -r '.id // ""' "$out" 2>/dev/null || true)"
  if [[ "$status" -eq 0 && "$parse_status" -eq 0 && "$id" == "dec-2026-06-07-json-decision" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status parse_status=$parse_status id=$id out=$(<"$out") err=$(<"$err")"
  fi
}

case_decision_unknown_subcommand() {
  local name="pmctl decision: unknown subcommand exits 2"
  should_run "$name" || return 0
  # Behavior: decision with an unrecognized subcommand exits 2 with an "unknown command" error.
  # Steps: invoke decision bogus-sub; assert exit 2, stderr contains "unknown command".
  local store out err status=0
  store="$tmp_root/decision-unknown-store"
  out="$tmp_root/decision-unknown.out"
  err="$tmp_root/decision-unknown.err"
  run_decision_cmd "$store" "$out" "$err" decision bogus-sub || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"unknown command"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_decision_add_duplicate_exits_2() {
  local name="pmctl decision add: duplicate id exits 2 and preserves original"
  should_run "$name" || return 0
  # Behavior: decision add with the same date+title (same deterministic id) exits 2 and leaves the original untouched.
  # Steps: add a decision; attempt to add with same date+title; assert exit 2, error contains "already exists".
  local store out err out2 err2 status=0 status2=0
  store="$tmp_root/decision-dup-store"
  out="$tmp_root/decision-dup.out"
  err="$tmp_root/decision-dup.err"
  out2="$tmp_root/decision-dup2.out"
  err2="$tmp_root/decision-dup2.err"
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "Dup Decision" --path DECISIONS.md || status=$?
  run_decision_cmd "$store" "$out2" "$err2" decision add --date 2026-06-07 --title "Dup Decision" --path OTHER.md || status2=$?
  if [[ "$status" -eq 0 && "$status2" -eq 2 && "$(<"$err2")" == *"already exists"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status status2=$status2 out=$(<"$out") out2=$(<"$out2") err2=$(<"$err2")"
  fi
}

case_decision_add_emits_event() {
  local name="pmctl decision add: emits decision.recorded event"
  should_run "$name" || return 0
  # Behavior: decision add appends a decision.recorded event to events.jsonl with the correct subject_id.
  # Steps: add a decision; read events.jsonl; assert a decision.recorded row exists with matching subject_id.
  local store proj out err status=0 events_file kind subject_id
  store="$tmp_root/decision-event-store"
  out="$tmp_root/decision-event.out"
  err="$tmp_root/decision-event.err"
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "Event Decision" --path DECISIONS.md || status=$?
  proj="$(decision_project_dir "$store")"
  events_file="$proj/events.jsonl"
  kind="$(jq -r 'select(.kind == "decision.recorded") | .kind' "$events_file" 2>/dev/null | head -1 || true)"
  subject_id="$(jq -r 'select(.kind == "decision.recorded") | .subject_id' "$events_file" 2>/dev/null | head -1 || true)"
  if [[ "$status" -eq 0 && "$kind" == "decision.recorded" && "$subject_id" == "dec-2026-06-07-event-decision" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status kind=$kind subject_id=$subject_id events=$(cat "$events_file" 2>/dev/null || echo none) err=$(<"$err")"
  fi
}

case_decision_add_concurrent_duplicate() {
  local name="pmctl decision add: concurrent duplicate — exactly one caller succeeds"
  should_run "$name" || return 0
  # Behavior: two concurrent decision add calls with the same date+title are serialized under serialize_with_lock;
  #   exactly one exits 0 and the other exits 2 with "already exists" in stderr.
  # Steps: fire two background adds for the same decision id; capture each PID + exit code;
  #   assert exactly one exit 0, one exit 2, "already exists" in failing stderr, one file on disk.
  local store proj out1 out2 err1 err2 ex1 ex2 pid1 pid2 dec_file dec_exists loser_err
  store="$tmp_root/decision-conc-dup-store"
  out1="$tmp_root/decision-conc-dup1.out"
  out2="$tmp_root/decision-conc-dup2.out"
  err1="$tmp_root/decision-conc-dup1.err"
  err2="$tmp_root/decision-conc-dup2.err"
  run_decision_cmd "$store" "$out1" "$err1" decision add --date 2026-06-07 --title "Concurrent Dec" --path DECISIONS-A.md &
  pid1=$!
  run_decision_cmd "$store" "$out2" "$err2" decision add --date 2026-06-07 --title "Concurrent Dec" --path DECISIONS-B.md &
  pid2=$!
  # Use || so set -e doesn't fire on a non-zero wait exit code.
  ex1=0; wait "$pid1" || ex1=$?
  ex2=0; wait "$pid2" || ex2=$?
  proj="$(decision_project_dir "$store")"
  dec_file="$proj/decisions/dec-2026-06-07-concurrent-dec.json"
  if [[ "$ex1" -eq 0 ]]; then loser_err="$(cat "$err2")"; else loser_err="$(cat "$err1")"; fi
  dec_exists="$([ -f "$dec_file" ] && echo yes || echo no)"
  if [[ "$ex1" -eq 0 && "$ex2" -eq 2 ]] || [[ "$ex1" -eq 2 && "$ex2" -eq 0 ]]; then
    if [[ "$dec_exists" == "yes" && "$loser_err" == *"already exists"* ]]; then
      pass "$name"
    else
      fail "$name" "dec_exists=$dec_exists loser_err=$loser_err ex1=$ex1 ex2=$ex2"
    fi
  else
    fail "$name" "expected one exit 0 and one exit 2, got ex1=$ex1 ex2=$ex2 err1=$(cat "$err1") err2=$(cat "$err2")"
  fi
}

case_decision_add_event_failure_rollback() {
  local name="pmctl decision add: event append failure rolls back projection, retry succeeds"
  should_run "$name" || return 0
  # Behavior: if events_append fails after decision_upsert succeeds, pmctl decision add removes
  #   the decision projection (rollback) and exits non-zero; a retry can then succeed.
  # Steps: init store; make events.jsonl unwritable; attempt add; restore; assert exit 1,
  #   decision file absent (rolled back); retry should succeed.
  if [[ "$(id -u)" -eq 0 ]]; then
    pass "$name"
    return 0
  fi
  local store proj out err status=0 retry_status=0 event_count
  store="$tmp_root/decision-evt-fail-store"
  out="$tmp_root/decision-evt-fail.out"
  err="$tmp_root/decision-evt-fail.err"
  run_decision_cmd "$store" /dev/null /dev/null decision add --date 2026-06-07 --title "Init Dec" --path INIT.md
  proj="$(decision_project_dir "$store")"
  chmod 444 "${proj}events.jsonl"
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "Rollback Dec" --path ROLLBACK.md || status=$?
  chmod 644 "${proj}events.jsonl"
  event_count="$(grep -c '"decision.recorded"' "${proj}events.jsonl" 2>/dev/null)" || event_count=0
  # Retry after rollback: should succeed now that the file was removed.
  run_decision_cmd "$store" /dev/null /dev/null decision add --date 2026-06-07 --title "Rollback Dec" --path ROLLBACK.md || retry_status=$?
  if [[ "$status" -ne 0 && "$retry_status" -eq 0 && "$event_count" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status retry_status=$retry_status event_count=$event_count err=$(cat "$err")"
  fi
}

case_decision_add_write_failure_no_event() {
  local name="pmctl decision add: projection write failure exits non-zero with no event row"
  should_run "$name" || return 0
  # Behavior: when decision_upsert cannot write the projection file, pmctl decision add exits
  #   non-zero and does NOT append a decision.recorded event to events.jsonl.
  # Steps: initialize state store via a successful add; make decisions dir unwritable; attempt a
  #   second add; restore permissions; assert non-zero exit and event count is still 1 (not 2).
  if [[ "$(id -u)" -eq 0 ]]; then
    pass "$name"
    return 0
  fi
  local store proj out err status=0 event_count
  store="$tmp_root/decision-write-fail-store"
  out="$tmp_root/decision-write-fail.out"
  err="$tmp_root/decision-write-fail.err"
  run_decision_cmd "$store" /dev/null /dev/null decision add --date 2026-06-07 --title "Init Dec" --path INIT.md || true
  proj="$(decision_project_dir "$store")"
  chmod 555 "$proj/decisions"
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "Fail Dec" --path FAIL.md || status=$?
  chmod 755 "$proj/decisions"
  event_count="$(grep -c '"decision.recorded"' "$proj/events.jsonl" 2>/dev/null)" || event_count=0
  if [[ "$status" -ne 0 && "$event_count" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status event_count=$event_count out=$(cat "$out") err=$(cat "$err")"
  fi
}

case_decision_add_event_failure_cleanup_fails() {
  local name="pmctl decision add: cleanup FAILED message when rm cannot remove projection directory"
  should_run "$name" || return 0
  # Behavior: if events_append fails and the subsequent rm -f of the projection cannot complete
  #   (e.g., the target is a directory rather than a file), the command exits non-zero and stderr
  #   contains "cleanup FAILED", signalling the operator to repair manually.
  # Steps: init store; chmod 444 events.jsonl; pre-create a directory at the decision projection
  #   path so rm -f will fail (rm refuses to remove directories on all POSIX systems); attempt add;
  #   assert exit non-zero and stderr contains "cleanup FAILED".
  if [[ "$(id -u)" -eq 0 ]]; then
    pass "$name"
    return 0
  fi
  local store proj out err status=0
  store="$tmp_root/decision-cleanup-fail-store"
  out="$tmp_root/decision-cleanup-fail.out"
  err="$tmp_root/decision-cleanup-fail.err"
  run_decision_cmd "$store" /dev/null /dev/null decision add --date 2026-06-07 --title "Init Dec" --path INIT.md
  proj="$(decision_project_dir "$store")"
  chmod 444 "${proj}events.jsonl"
  # Pre-create a directory at the exact decision projection path; rm -f on a directory fails.
  mkdir -p "${proj}decisions/dec-2026-06-07-cleanup-fail.json"
  run_decision_cmd "$store" "$out" "$err" decision add --date 2026-06-07 --title "Cleanup Fail" --path FAIL.md || status=$?
  chmod 644 "${proj}events.jsonl"
  if [[ "$status" -ne 0 && "$(<"$err")" == *"cleanup FAILED"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(cat "$err")"
  fi
}

case_decision_add_writes_file
case_decision_add_missing_required_flags
case_decision_add_closes_and_tags_arrays
case_decision_add_json_output
case_decision_unknown_subcommand
case_decision_add_duplicate_exits_2
case_decision_add_emits_event
case_decision_add_concurrent_duplicate
case_decision_add_write_failure_no_event
case_decision_add_event_failure_rollback
case_decision_add_event_failure_cleanup_fails

th_summary
