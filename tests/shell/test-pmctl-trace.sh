#!/usr/bin/env bash
# Regression tests for pmctl trace tail.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/state-writer.sh
. "$REPO_ROOT/runtime/lib/state-writer.sh"

trace_project_dir() {
  local store="$1" proj_dir
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" _sw_project_dir)"
  mkdir -p "$proj_dir/archive"
  printf '%s\n' "$proj_dir"
}

event_json() {
  local id="$1" ts="$2" kind="$3" subject_id="$4" actor="${5:-pmctl}" operation_id="${6:-}"
  jq -cn \
    --arg id "$id" \
    --arg ts "$ts" \
    --arg kind "$kind" \
    --arg subject_id "$subject_id" \
    --arg actor "$actor" \
    --arg operation_id "$operation_id" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,subject_type:"run",subject_id:$subject_id,actor:$actor,payload:{}} + (if $operation_id == "" then {} else {operation_id:$operation_id} end)'
}

run_trace() {
  local store="$1" out="$2" err="$3"
  shift 3
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" trace tail "$@" > "$out" 2> "$err"
}

line_count() {
  wc -l < "$1" | tr -d ' '
}

case_trace_filter_kind() {
  local name="pmctl trace tail: --kind filters exact event kind"
  should_run "$name" || return 0
  local store proj out err status=0 bad count
  store="$tmp_root/kind-store"
  proj="$(trace_project_dir "$store")"
  {
    event_json evt-kind-1 2026-06-06T00:00:00Z run.pending RUN-1
    event_json evt-kind-2 2026-06-06T00:01:00Z run.completed RUN-1
    event_json evt-kind-3 2026-06-06T00:02:00Z run.failed RUN-2
  } > "$proj/events.jsonl"
  out="$tmp_root/kind.out"
  err="$tmp_root/kind.err"
  run_trace "$store" "$out" "$err" --kind run.completed --all --json || status=$?
  count="$(line_count "$out")"
  bad="$(jq -r 'select(.kind != "run.completed") | .id' "$out")"
  if [[ "$status" -eq 0 && "$count" == "1" && -z "$bad" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status count=$count bad=$bad err=$(<"$err")"
  fi
}

case_trace_filter_subject() {
  local name="pmctl trace tail: --task and --subject filter subject_id"
  should_run "$name" || return 0
  local store proj out_task out_subject err_task err_subject status_task=0 status_subject=0 ids_task ids_subject
  store="$tmp_root/subject-store"
  proj="$(trace_project_dir "$store")"
  {
    event_json evt-subject-1 2026-06-06T00:00:00Z run.pending RUN-1
    event_json evt-subject-2 2026-06-06T00:01:00Z run.completed RUN-2
    event_json evt-subject-3 2026-06-06T00:02:00Z run.failed RUN-1
  } > "$proj/events.jsonl"
  out_task="$tmp_root/task.out"
  err_task="$tmp_root/task.err"
  out_subject="$tmp_root/subject.out"
  err_subject="$tmp_root/subject.err"
  run_trace "$store" "$out_task" "$err_task" --task RUN-1 --all --json || status_task=$?
  run_trace "$store" "$out_subject" "$err_subject" --subject RUN-1 --all --json || status_subject=$?
  ids_task="$(jq -r '.subject_id' "$out_task" | sort -u | tr '\n' ' ')"
  ids_subject="$(jq -r '.subject_id' "$out_subject" | sort -u | tr '\n' ' ')"
  if [[ "$status_task" -eq 0 && "$status_subject" -eq 0 &&
        "$(line_count "$out_task")" == "2" && "$(line_count "$out_subject")" == "2" &&
        "$ids_task" == "RUN-1 " && "$ids_subject" == "RUN-1 " ]]; then
    pass "$name"
  else
    fail "$name" "task_status=$status_task subject_status=$status_subject task_ids=$ids_task subject_ids=$ids_subject"
  fi
}

case_trace_filter_id() {
  local name="pmctl trace tail: --id returns the matching event"
  should_run "$name" || return 0
  local store proj out err status=0 got
  store="$tmp_root/id-store"
  proj="$(trace_project_dir "$store")"
  {
    event_json evt-id-1 2026-06-06T00:00:00Z run.pending RUN-1
    event_json evt-id-2 2026-06-06T00:01:00Z run.completed RUN-1
  } > "$proj/events.jsonl"
  out="$tmp_root/id.out"
  err="$tmp_root/id.err"
  run_trace "$store" "$out" "$err" --id evt-id-2 --all --json || status=$?
  got="$(jq -r '.id' "$out")"
  if [[ "$status" -eq 0 && "$(line_count "$out")" == "1" && "$got" == "evt-id-2" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status got=$got err=$(<"$err")"
  fi
}

case_trace_time_window_inclusive() {
  local name="pmctl trace tail: --since and --until are inclusive"
  should_run "$name" || return 0
  local store proj out err status=0 ids
  store="$tmp_root/window-store"
  proj="$(trace_project_dir "$store")"
  {
    event_json evt-window-1 2026-06-06T00:00:00Z run.pending RUN-1
    event_json evt-window-2 2026-06-06T00:01:00Z run.dispatched RUN-1
    event_json evt-window-3 2026-06-06T00:02:00Z run.completed RUN-1
    event_json evt-window-4 2026-06-06T00:03:00Z run.failed RUN-2
  } > "$proj/events.jsonl"
  out="$tmp_root/window.out"
  err="$tmp_root/window.err"
  run_trace "$store" "$out" "$err" --since 2026-06-06T00:01:00Z --until 2026-06-06T00:02:00Z --all --json || status=$?
  ids="$(jq -r '.id' "$out" | tr '\n' ' ')"
  if [[ "$status" -eq 0 && "$ids" == "evt-window-2 evt-window-3 " ]]; then
    pass "$name"
  else
    fail "$name" "status=$status ids=$ids err=$(<"$err")"
  fi
}

case_trace_limit_default_and_all() {
  local name="pmctl trace tail: default, -n, --limit, and --all caps"
  should_run "$name" || return 0
  local store proj out_default out_n out_limit out_all err status_default=0 status_n=0 status_limit=0 status_all=0 first_n first_limit
  store="$tmp_root/limit-store"
  proj="$(trace_project_dir "$store")"
  for i in $(seq -w 1 25); do
    event_json "evt-limit-$i" "2026-06-06T00:${i}:00Z" run.completed "RUN-$i"
  done > "$proj/events.jsonl"
  out_default="$tmp_root/default.out"
  out_n="$tmp_root/n.out"
  out_limit="$tmp_root/limit.out"
  out_all="$tmp_root/all.out"
  err="$tmp_root/limit.err"
  run_trace "$store" "$out_default" "$err" --json || status_default=$?
  run_trace "$store" "$out_n" "$err" -n 2 --json || status_n=$?
  run_trace "$store" "$out_limit" "$err" --limit 3 --json || status_limit=$?
  run_trace "$store" "$out_all" "$err" --all --json || status_all=$?
  first_n="$(jq -r 'select(input_line_number == 1) | .id' "$out_n")"
  first_limit="$(jq -r 'select(input_line_number == 1) | .id' "$out_limit")"
  if [[ "$status_default" -eq 0 && "$status_n" -eq 0 && "$status_limit" -eq 0 && "$status_all" -eq 0 &&
        "$(line_count "$out_default")" == "20" && "$(line_count "$out_n")" == "2" &&
        "$(line_count "$out_limit")" == "3" && "$(line_count "$out_all")" == "25" &&
        "$first_n" == "evt-limit-24" && "$first_limit" == "evt-limit-23" ]]; then
    pass "$name"
  else
    fail "$name" "counts default=$(line_count "$out_default") n=$(line_count "$out_n") limit=$(line_count "$out_limit") all=$(line_count "$out_all") first_n=$first_n first_limit=$first_limit"
  fi
}

case_trace_json_passthrough() {
  local name="pmctl trace tail: --json emits compact parseable JSONL"
  should_run "$name" || return 0
  local store proj out err status=0 row got parse_status=0
  store="$tmp_root/json-store"
  proj="$(trace_project_dir "$store")"
  row="$(event_json evt-json-1 2026-06-06T00:00:00Z run.completed RUN-1 pmctl op-20260606T000000Z-abcdef)"
  printf '%s\n' "$row" > "$proj/events.jsonl"
  out="$tmp_root/json.out"
  err="$tmp_root/json.err"
  run_trace "$store" "$out" "$err" --id evt-json-1 --json || status=$?
  got="$(<"$out")"
  jq -e . "$out" >/dev/null 2>&1 || parse_status=$?
  if [[ "$status" -eq 0 && "$parse_status" -eq 0 && "$got" == "$row" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status parse=$parse_status got=$got row=$row err=$(<"$err")"
  fi
}

case_trace_human_format() {
  local name="pmctl trace tail: default human format"
  should_run "$name" || return 0
  local store proj out err status=0 expected
  store="$tmp_root/human-store"
  proj="$(trace_project_dir "$store")"
  {
    event_json evt-human-1 2026-06-06T00:00:00Z run.pending RUN-1 | jq -c 'del(.actor)'
    event_json evt-human-2 2026-06-06T00:01:00Z run.completed RUN-1 pmctl op-20260606T000100Z-abcdef
  } > "$proj/events.jsonl"
  out="$tmp_root/human.out"
  err="$tmp_root/human.err"
  run_trace "$store" "$out" "$err" --all || status=$?
  expected=$'2026-06-06T00:00:00Z  run.pending  run/RUN-1  [no-actor]\n2026-06-06T00:01:00Z  run.completed  run/RUN-1  pmctl op=op-20260606T000100Z-abcdef'
  if [[ "$status" -eq 0 && "$(<"$out")" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_trace_equal_ts_append_order() {
  local name="pmctl trace tail: equal timestamps preserve append order"
  should_run "$name" || return 0
  local store proj out err status=0 ids
  store="$tmp_root/equal-ts-store"
  proj="$(trace_project_dir "$store")"
  {
    event_json evt-equal-1 2026-06-06T00:00:00Z run.pending RUN-1
    event_json evt-equal-2 2026-06-06T00:00:00Z run.dispatched RUN-1
    event_json evt-equal-3 2026-06-06T00:00:00Z run.completed RUN-1
  } > "$proj/events.jsonl"
  out="$tmp_root/equal-ts.out"
  err="$tmp_root/equal-ts.err"
  run_trace "$store" "$out" "$err" --all --json || status=$?
  ids="$(jq -r '.id' "$out" | tr '\n' ' ')"
  if [[ "$status" -eq 0 && "$ids" == "evt-equal-1 evt-equal-2 evt-equal-3 " ]]; then
    pass "$name"
  else
    fail "$name" "status=$status ids=$ids err=$(<"$err")"
  fi
}

case_trace_corrupt_row_tolerance() {
  local name="pmctl trace tail: malformed rows are skipped with warning"
  should_run "$name" || return 0
  local store proj out err status=0 ids
  store="$tmp_root/corrupt-store"
  proj="$(trace_project_dir "$store")"
  {
    event_json evt-corrupt-1 2026-06-06T00:00:00Z run.pending RUN-1
    printf '%s\n' '{"id":'
    event_json evt-corrupt-2 2026-06-06T00:01:00Z run.completed RUN-1
  } > "$proj/events.jsonl"
  out="$tmp_root/corrupt.out"
  err="$tmp_root/corrupt.err"
  run_trace "$store" "$out" "$err" --all --json || status=$?
  ids="$(jq -r '.id' "$out" | tr '\n' ' ')"
  if [[ "$status" -eq 0 && "$ids" == "evt-corrupt-1 evt-corrupt-2 " ]] &&
     grep -Fq 'trace: skipped 1 malformed row(s)' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status ids=$ids err=$(<"$err")"
  fi
}

case_trace_active_archive_merge() {
  local name="pmctl trace tail: active and archive rows merge chronologically"
  should_run "$name" || return 0
  local store proj out err status=0 ids archive_row
  if ! command -v gzip >/dev/null 2>&1; then
    pass "$name"
    return 0
  fi
  store="$tmp_root/archive-store"
  proj="$(trace_project_dir "$store")"
  {
    event_json evt-merge-1 2026-06-06T00:01:00Z run.pending RUN-1
    event_json evt-merge-3 2026-06-06T00:03:00Z run.completed RUN-1
  } > "$proj/events.jsonl"
  archive_row="$(event_json evt-merge-2 2026-06-06T00:02:00Z run.dispatched RUN-1)"
  printf '%s\n' "$archive_row" | gzip -c > "$proj/archive/events-202606.jsonl.gz"
  out="$tmp_root/archive.out"
  err="$tmp_root/archive.err"
  run_trace "$store" "$out" "$err" --all --json || status=$?
  ids="$(jq -r '.id' "$out" | tr '\n' ' ')"
  if [[ "$status" -eq 0 && "$ids" == "evt-merge-1 evt-merge-2 evt-merge-3 " ]]; then
    pass "$name"
  else
    fail "$name" "status=$status ids=$ids err=$(<"$err")"
  fi
}

case_trace_large_partition_streaming() {
  local name="pmctl trace tail: large archive+active partition stays ordered in one pass"
  should_run "$name" || return 0
  local store proj out err status=0 count ordered malformed
  if ! command -v gzip >/dev/null 2>&1; then
    pass "$name"
    return 0
  fi
  store="$tmp_root/large-store"
  proj="$(trace_project_dir "$store")"
  # 120 archived + 120 active events, disjoint timestamp bands so a correct
  # merge must order across both sources; two malformed rows exercise the
  # streaming skip path at a scale well above the other cases. Fixtures are
  # built in one awk pass, not per-event jq spawns (per-item-subprocess-class).
  large_events() {
    local band="$1" prefix="$2" n="$3"
    awk -v band="$band" -v prefix="$prefix" -v n="$n" 'BEGIN {
      for (i = 1; i <= n; i++) {
        printf "{\"schema_version\":1,\"id\":\"%s-%03d\",\"ts\":\"2026-06-06T%s:%02d:00Z\",\"kind\":\"run.completed\",\"subject_type\":\"run\",\"subject_id\":\"%s-%d\",\"actor\":\"pmctl\",\"payload\":{}}\n", prefix, i, band, i % 60, prefix, i
      }
    }'
  }
  large_events 01 evt-large-a 120 | gzip -c > "$proj/archive/events-202606a.jsonl.gz"
  {
    printf '%s\n' '{"id":'
    large_events 02 evt-large-b 120
    printf '%s\n' 'not json at all'
  } > "$proj/events.jsonl"
  out="$tmp_root/large.out"
  err="$tmp_root/large.err"
  run_trace "$store" "$out" "$err" --all --json || status=$?
  count="$(line_count "$out")"
  # timestamps must be non-decreasing across the merged stream
  ordered="$(jq -r '.ts' "$out" | LC_ALL=C sort -c 2>&1 && echo OK)"
  malformed="$(grep -c 'trace: skipped 2 malformed row(s)' "$err" || true)"
  if [[ "$status" -eq 0 && "$count" == "240" && "$ordered" == "OK" && "$malformed" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status count=$count ordered=$ordered malformed=$malformed err=$(<"$err")"
  fi
}

case_trace_empty_missing_store() {
  local name="pmctl trace tail: missing store exits 0 with empty stdout"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/missing-store"
  out="$tmp_root/missing.out"
  err="$tmp_root/missing.err"
  run_trace "$store" "$out" "$err" || status=$?
  if [[ "$status" -eq 0 && ! -s "$out" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_trace_unknown_flag_usage() {
  local name="pmctl trace tail: unknown flag exits 2 with usage"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/unknown-store"
  out="$tmp_root/unknown.out"
  err="$tmp_root/unknown.err"
  run_trace "$store" "$out" "$err" --bogus || status=$?
  if [[ "$status" -eq 2 && ! -s "$out" ]] &&
     grep -Fq 'pmctl trace tail: unknown flag: --bogus' "$err" &&
     grep -Fq 'usage: pmctl trace tail' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_trace_filter_kind
case_trace_filter_subject
case_trace_filter_id
case_trace_time_window_inclusive
case_trace_limit_default_and_all
case_trace_json_passthrough
case_trace_human_format
case_trace_equal_ts_append_order
case_trace_corrupt_row_tolerance
case_trace_active_archive_merge
case_trace_large_partition_streaming
case_trace_empty_missing_store
case_trace_unknown_flag_usage

th_summary
