#!/usr/bin/env bash
# Regression tests for append-only state-store rotation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/state-writer.sh
. "$REPO_ROOT/runtime/lib/state-writer.sh"

project_dir_for_store() {
  local store="$1"
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" _sw_project_dir
}

event_json() {
  local n="$1" sec suffix id run_id
  sec="$(printf '%02d' "$n")"
  suffix="$(printf '%06x' "$n")"
  id="evt-20260606T0000${sec}Z-${suffix}"
  run_id="run-20260606T0000${sec}Z-${suffix}"
  jq -cn \
    --arg id "$id" \
    --arg ts "2026-06-06T00:00:${sec}Z" \
    --arg run_id "$run_id" \
    '{schema_version:1,id:$id,ts:$ts,kind:"run.completed",subject_type:"run",subject_id:$run_id,actor:"pmctl",payload:{run_id:$run_id,state:"ok",from_state:"verifying",to_state:"ok"}}'
}

run_json() {
  local n="$1" sec suffix id
  sec="$(printf '%02d' "$n")"
  suffix="$(printf '%06x' "$n")"
  id="run-20260606T0000${sec}Z-${suffix}"
  jq -cn \
    --arg id "$id" \
    --arg created_ts "2026-06-06T00:00:${sec}Z" \
    '{schema_version:3,id:$id,task_id:"TASK-1",executor:"codex",state:"ok",working_dir:"/tmp/test",trace_path:"/tmp/test.jsonl",exit_code:0,created_ts:$created_ts}'
}

append_event_n() {
  local store="$1" n="$2" threshold="${3:-1}"
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" PM_DISPATCH_ROTATE_MAX_BYTES="$threshold" \
    events_append "$(event_json "$n")"
}

append_run_n() {
  local store="$1" n="$2" threshold="${3:-1}"
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" PM_DISPATCH_ROTATE_MAX_BYTES="$threshold" \
    runs_append "$(run_json "$n")"
}

ids_from_file() {
  local file="$1"
  jq -r '.id' "$file" 2>/dev/null | tr '\n' ' '
}

ids_from_gzip() {
  local file="$1"
  gzip -cd "$file" | jq -r '.id' | tr '\n' ' '
}

make_path_without_gzip() {
  local bin="$1" cmd src
  mkdir -p "$bin"
  for cmd in bash date git sha1sum shasum jq stat wc mkdir mv rm rmdir flock sleep cut tr grep sed sort head find cat dirname basename perl mktemp; do
    src="$(type -P "$cmd" 2>/dev/null || true)"
    [[ -n "$src" ]] || continue
    ln -sf "$src" "$bin/$cmd"
  done
  printf '%s\n' "$bin"
}

make_path_with_failing_gzip() {
  local bin="$1"
  make_path_without_gzip "$bin" >/dev/null
  cat > "$bin/gzip" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
  chmod +x "$bin/gzip"
  printf '%s\n' "$bin"
}

case_rotation_below_threshold() {
  # Behavior: appends that stay under the byte threshold never rotate.
  # Steps:
  #   1. Append two small events with a large (100000) threshold.
  #   2. Assert no archive segment exists and both rows remain in the active file.
  local name="state rotation: below byte threshold leaves active intact"
  should_run "$name" || return 0
  local store proj archives active_count
  store="$tmp_root/below"
  append_event_n "$store" 1 100000
  append_event_n "$store" 2 100000
  proj="$(project_dir_for_store "$store")"
  archives="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print 2>/dev/null)"
  active_count="$(wc -l < "$proj/events.jsonl" | tr -d ' ')"
  if [[ -z "$archives" && "$active_count" == "2" ]]; then
    pass "$name"
  else
    fail "$name" "archives=$archives active_count=$active_count"
  fi
}

case_rotation_byte_threshold_triggers() {
  # Behavior: crossing the byte threshold rotates the prior rows into segment 0001.
  # Steps:
  #   1. Append two events with a tiny (1-byte) threshold so the second triggers rotation.
  #   2. Assert events-*-0001.jsonl.gz holds row 1 and the active file holds row 2.
  local name="state rotation: byte threshold creates first event archive"
  should_run "$name" || return 0
  local store proj archive active_id archive_id
  store="$tmp_root/threshold"
  append_event_n "$store" 1 1
  append_event_n "$store" 2 1
  proj="$(project_dir_for_store "$store")"
  archive="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*-0001.jsonl.gz' -print -quit)"
  active_id="$(jq -r '.id' "$proj/events.jsonl")"
  archive_id="$(ids_from_gzip "$archive")"
  if [[ -f "$archive" && "$active_id" == "evt-20260606T000002Z-000002" &&
        "$archive_id" == "evt-20260606T000001Z-000001 " ]]; then
    pass "$name"
  else
    fail "$name" "archive=$archive active_id=$active_id archive_id=$archive_id"
  fi
}

case_rotation_monotonic_segments() {
  # Behavior: repeated rotations in one month allocate monotonic segment numbers.
  # Steps:
  #   1. Append three events with a tiny threshold so two rotations occur.
  #   2. Assert the archive holds -0001 and -0002 segments (no collision/overwrite).
  local name="state rotation: same-month segments are monotonic"
  should_run "$name" || return 0
  local store proj names
  store="$tmp_root/segments"
  append_event_n "$store" 1 1
  append_event_n "$store" 2 1
  append_event_n "$store" 3 1
  proj="$(project_dir_for_store "$store")"
  names="$(
    while IFS= read -r path; do
      basename "$path"
    done < <(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print) | sort | tr '\n' ' '
  )"
  if [[ "$names" =~ events-[0-9]{6}-0001\.jsonl\.gz\ events-[0-9]{6}-0002\.jsonl\.gz\  ]]; then
    pass "$name"
  else
    fail "$name" "names=$names"
  fi
}

case_rotation_gzip_integrity() {
  # Behavior: the gzipped segment preserves exactly the rotated rows, in order.
  # Steps:
  #   1. Append two events under a large threshold, then one with a tiny threshold to rotate.
  #   2. Gunzip segment 0001 and assert it contains rows 1 then 2 in order.
  local name="state rotation: gzip segment preserves rotated rows in order"
  should_run "$name" || return 0
  local store proj archive ids
  store="$tmp_root/integrity"
  append_event_n "$store" 1 100000
  append_event_n "$store" 2 100000
  append_event_n "$store" 3 1
  proj="$(project_dir_for_store "$store")"
  archive="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*-0001.jsonl.gz' -print -quit)"
  ids="$(ids_from_gzip "$archive")"
  if [[ "$ids" == "evt-20260606T000001Z-000001 evt-20260606T000002Z-000002 " ]]; then
    pass "$name"
  else
    fail "$name" "ids=$ids archive=$archive"
  fi
}

case_rotation_reader_integration() {
  # Behavior: pmctl trace tail merges archived segments with the active file.
  # Steps:
  #   1. Append two events with a tiny threshold so row 1 is archived and row 2 stays active.
  #   2. Run `pmctl trace tail --all --json` and assert both rows are returned in ts order.
  local name="state rotation: pmctl trace tail reads archive plus active"
  should_run "$name" || return 0
  local store out err status=0 ids
  store="$tmp_root/reader"
  append_event_n "$store" 1 1
  append_event_n "$store" 2 1
  out="$tmp_root/reader.out"
  err="$tmp_root/reader.err"
  (cd "$REPO_ROOT" && PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" trace tail --all --json > "$out" 2> "$err") || status=$?
  ids="$(jq -r '.id' "$out" | tr '\n' ' ')"
  if [[ "$status" -eq 0 && "$ids" == "evt-20260606T000001Z-000001 evt-20260606T000002Z-000002 " ]]; then
    pass "$name"
  else
    fail "$name" "status=$status ids=$ids err=$(<"$err")"
  fi
}

case_rotation_runs_independent() {
  # Behavior: runs.jsonl rotates on its own without rotating events.jsonl.
  # Steps:
  #   1. Append two runs with a tiny threshold so run 1 is archived.
  #   2. Assert a runs-*-0001 segment exists, no events segment exists, run 2 stays active.
  local name="state rotation: runs rotate independently"
  should_run "$name" || return 0
  local store proj run_archive event_archives active_id archive_id
  store="$tmp_root/runs"
  append_run_n "$store" 1 1
  append_run_n "$store" 2 1
  proj="$(project_dir_for_store "$store")"
  run_archive="$(find "$proj/archive" -maxdepth 1 -type f -name 'runs-*-0001.jsonl.gz' -print -quit)"
  event_archives="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print 2>/dev/null)"
  active_id="$(jq -r '.id' "$proj/runs.jsonl")"
  archive_id="$(ids_from_gzip "$run_archive")"
  if [[ -f "$run_archive" && -z "$event_archives" &&
        "$active_id" == "run-20260606T000002Z-000002" &&
        "$archive_id" == "run-20260606T000001Z-000001 " ]]; then
    pass "$name"
  else
    fail "$name" "run_archive=$run_archive event_archives=$event_archives active_id=$active_id archive_id=$archive_id"
  fi
}

case_rotation_crash_recovery() {
  # Behavior: a crash after staging but before publish is recovered on the next append.
  # Steps:
  #   1. Init store; place a destination-named .staging orphan (row 1) plus a stale .gz.tmp.
  #   2. Append row 2 (large threshold → no fresh rotation).
  #   3. Assert the stage is published to segment 0001 (row 1), the stale tmp and staging
  #      are gone, and the active file holds row 2.
  local name="state rotation: stale staged segment is recovered idempotently"
  should_run "$name" || return 0
  local store proj period archive ids active_ids tmp_left staging_left
  store="$tmp_root/recovery"
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" state_store_init
  proj="$(project_dir_for_store "$store")"
  period="$(date -u +%Y%m)"
  event_json 1 > "$proj/archive/events-${period}-0001.jsonl.gz.staging"
  printf 'partial\n' > "$proj/archive/events-${period}-9999.jsonl.gz.tmp"
  append_event_n "$store" 2 100000
  archive="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print -quit)"
  ids="$(ids_from_gzip "$archive")"
  active_ids="$(ids_from_file "$proj/events.jsonl")"
  tmp_left="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz.tmp' -print 2>/dev/null)"
  staging_left="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz.staging' -print 2>/dev/null)"
  if [[ -f "$archive" && -z "$tmp_left" && -z "$staging_left" &&
        "$ids" == "evt-20260606T000001Z-000001 " &&
        "$active_ids" == "evt-20260606T000002Z-000002 " ]]; then
    pass "$name"
  else
    fail "$name" "archive=$archive ids=$ids active_ids=$active_ids tmp_left=$tmp_left staging_left=$staging_left"
  fi
}

case_rotation_post_publish_no_duplicate() {
  # Behavior: a stage left behind AFTER its segment was already published is dropped,
  #   never re-archived, so no duplicate rows reach the reader (idempotent recovery).
  # Steps:
  #   1. Rotate for real so segment 0001 (row 1) is published and row 2 is active.
  #   2. Recreate the already-published segment's .staging with identical content
  #      (simulating a crash between publish and stage cleanup).
  #   3. Append row 3, then assert: still exactly one segment (no -0002 duplicate),
  #      no staging left, and `pmctl trace tail --all --json` emits no duplicate ids.
  local name="state rotation: post-publish stale stage does not duplicate rows"
  should_run "$name" || return 0
  local store proj period seg_count staging_left trace_ids uniq_ids out err status=0
  store="$tmp_root/postpublish"
  append_event_n "$store" 1 1
  append_event_n "$store" 2 1
  proj="$(project_dir_for_store "$store")"
  period="$(date -u +%Y%m)"
  gzip -cd "$proj/archive/events-${period}-0001.jsonl.gz" \
    > "$proj/archive/events-${period}-0001.jsonl.gz.staging"
  append_event_n "$store" 3 100000
  seg_count="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' | wc -l | tr -d ' ')"
  staging_left="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz.staging' -print 2>/dev/null)"
  out="$tmp_root/postpublish.out"
  err="$tmp_root/postpublish.err"
  (cd "$REPO_ROOT" && PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" trace tail --all --json > "$out" 2> "$err") || status=$?
  trace_ids="$(jq -r '.id' "$out" | sort)"
  uniq_ids="$(printf '%s\n' "$trace_ids" | sort -u)"
  if [[ "$status" -eq 0 && "$seg_count" == "1" && -z "$staging_left" &&
        "$trace_ids" == "$uniq_ids" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status seg_count=$seg_count staging_left=$staging_left trace_ids=$(printf '%s' "$trace_ids" | tr '\n' ',')"
  fi
}

case_rotation_recovery_failure_preserves_stage() {
  # Behavior: when a pre-existing stage cannot be published (gzip failing during
  #   recovery), rotation skips a fresh rotation, preserves the stage for retry,
  #   keeps the append succeeding, and never allocates a new segment.
  # Steps:
  #   1. Init store; place a destination-named .staging orphan (row 1).
  #   2. Append row 2 with a failing-gzip PATH and a tiny threshold.
  #   3. Assert: append rc 0; the .staging orphan is preserved; no published
  #      segment was created; the active file still holds row 2.
  local name="state rotation: recovery failure preserves stage and does not rotate"
  should_run "$name" || return 0
  local store proj period path home rc=0 staging_left seg_count active_ids
  store="$tmp_root/recovery-fail-store"
  home="$tmp_root/recovery-fail-home"
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" state_store_init
  proj="$(project_dir_for_store "$store")"
  period="$(date -u +%Y%m)"
  event_json 1 > "$proj/archive/events-${period}-0001.jsonl.gz.staging"
  path="$(make_path_with_failing_gzip "$tmp_root/recovery-fail-bin")"
  HOME="$home" PATH="$path" PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" PM_DISPATCH_ROTATE_MAX_BYTES=1 \
    events_append "$(event_json 2)" || rc=$?
  staging_left="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz.staging' -print 2>/dev/null)"
  seg_count="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' | wc -l | tr -d ' ')"
  active_ids="$(ids_from_file "$proj/events.jsonl")"
  if [[ "$rc" -eq 0 && -n "$staging_left" && "$seg_count" == "0" &&
        "$active_ids" == *"evt-20260606T000002Z-000002"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc staging_left=$staging_left seg_count=$seg_count active_ids=$active_ids"
  fi
}

case_rotation_gzip_unavailable() {
  # Behavior: a missing gzip binary degrades rotation loudly without failing the append.
  # Steps:
  #   1. Append row 1, then append row 2 with a gzip-less PATH and a tiny threshold.
  #   2. Assert: append rc 0; no archive segment; both rows remain in the active file;
  #      state-writer.err records the "gzip unavailable" degradation.
  local name="state rotation: missing gzip skips rotation without failing append"
  should_run "$name" || return 0
  local store proj path home rc=0 archives active_ids log
  store="$tmp_root/no-gzip-store"
  home="$tmp_root/no-gzip-home"
  append_event_n "$store" 1 1
  path="$(make_path_without_gzip "$tmp_root/no-gzip-bin")"
  HOME="$home" PATH="$path" PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" PM_DISPATCH_ROTATE_MAX_BYTES=1 \
    events_append "$(event_json 2)" || rc=$?
  proj="$(project_dir_for_store "$store")"
  archives="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print 2>/dev/null)"
  active_ids="$(ids_from_file "$proj/events.jsonl")"
  log="$(cat "$store/logs/state-writer.err" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 && -z "$archives" &&
        "$active_ids" == "evt-20260606T000001Z-000001 evt-20260606T000002Z-000002 " &&
        "$log" == *"gzip unavailable"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc archives=$archives active_ids=$active_ids log=$log"
  fi
}

case_rotation_gzip_failure_nonfatal() {
  # Behavior: a gzip that fails before publish does not fail the append or lose rows —
  #   the staged rows are restored to the active file (no orphan stage, no segment).
  # Steps:
  #   1. Append row 1, then append row 2 with a failing-gzip PATH and a tiny threshold.
  #   2. Assert: append rc 0; no archive segment; no leftover .staging; both rows in the
  #      active file; state-writer.err records the "gzip failed" degradation.
  local name="state rotation: gzip failure does not fail append or lose active rows"
  should_run "$name" || return 0
  local store proj path home rc=0 archives active_ids staging_left log
  store="$tmp_root/gzip-fail-store"
  home="$tmp_root/gzip-fail-home"
  append_event_n "$store" 1 1
  path="$(make_path_with_failing_gzip "$tmp_root/gzip-fail-bin")"
  HOME="$home" PATH="$path" PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" PM_DISPATCH_ROTATE_MAX_BYTES=1 \
    events_append "$(event_json 2)" || rc=$?
  proj="$(project_dir_for_store "$store")"
  archives="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print 2>/dev/null)"
  active_ids="$(ids_from_file "$proj/events.jsonl")"
  staging_left="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz.staging' -print 2>/dev/null)"
  log="$(cat "$store/logs/state-writer.err" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 && -z "$archives" && -z "$staging_left" &&
        "$active_ids" == "evt-20260606T000001Z-000001 evt-20260606T000002Z-000002 " &&
        "$log" == *"gzip failed"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc archives=$archives staging_left=$staging_left active_ids=$active_ids log=$log"
  fi
}

case_rotation_max_bytes_parsing() {
  # Behavior: _sw_rotate_max_bytes falls back to the 50 MB default for unset/empty/
  #   zero/non-numeric/negative input and passes through a valid positive integer.
  # Steps:
  #   1. Call _sw_rotate_max_bytes with each input form.
  #   2. Assert the fallbacks return 52428800 and the valid value passes through.
  local name="state rotation: PM_DISPATCH_ROTATE_MAX_BYTES default/zero/non-numeric fallback"
  should_run "$name" || return 0
  local def=52428800 out_unset out_empty out_zero out_alpha out_neg out_valid
  out_unset="$(unset PM_DISPATCH_ROTATE_MAX_BYTES; _sw_rotate_max_bytes)"
  out_empty="$(PM_DISPATCH_ROTATE_MAX_BYTES="" _sw_rotate_max_bytes)"
  out_zero="$(PM_DISPATCH_ROTATE_MAX_BYTES=0 _sw_rotate_max_bytes)"
  out_alpha="$(PM_DISPATCH_ROTATE_MAX_BYTES=abc _sw_rotate_max_bytes)"
  out_neg="$(PM_DISPATCH_ROTATE_MAX_BYTES=-5 _sw_rotate_max_bytes)"
  out_valid="$(PM_DISPATCH_ROTATE_MAX_BYTES=1048576 _sw_rotate_max_bytes)"
  if [[ "$out_unset" == "$def" && "$out_empty" == "$def" && "$out_zero" == "$def" &&
        "$out_alpha" == "$def" && "$out_neg" == "$def" && "$out_valid" == "1048576" ]]; then
    pass "$name"
  else
    fail "$name" "unset=$out_unset empty=$out_empty zero=$out_zero alpha=$out_alpha neg=$out_neg valid=$out_valid"
  fi
}

case_rotation_exact_threshold() {
  # Behavior: an active file whose size exactly equals the threshold rotates (>= boundary).
  # Steps:
  #   1. Append one row under a large threshold; measure its exact byte size.
  #   2. Append a second row with threshold == that size so the pre-append check sees
  #      size == threshold; assert segment 0001 was created (exact equality triggers).
  local name="state rotation: active size exactly at threshold triggers rotation"
  should_run "$name" || return 0
  local store proj size archive
  store="$tmp_root/exact"
  append_event_n "$store" 1 100000
  proj="$(project_dir_for_store "$store")"
  size="$(file_size_bytes "$proj/events.jsonl")"
  append_event_n "$store" 2 "$size"
  archive="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*-0001.jsonl.gz' -print -quit)"
  if [[ -f "$archive" && "$(ids_from_gzip "$archive")" == "evt-20260606T000001Z-000001 " ]]; then
    pass "$name"
  else
    fail "$name" "size=$size archive=$archive"
  fi
}

case_rotation_below_threshold
case_rotation_byte_threshold_triggers
case_rotation_monotonic_segments
case_rotation_gzip_integrity
case_rotation_reader_integration
case_rotation_runs_independent
case_rotation_crash_recovery
case_rotation_post_publish_no_duplicate
case_rotation_recovery_failure_preserves_stage
case_rotation_gzip_unavailable
case_rotation_gzip_failure_nonfatal
case_rotation_max_bytes_parsing
case_rotation_exact_threshold

th_summary
