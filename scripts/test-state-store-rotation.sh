#!/usr/bin/env bash
# Regression tests for append-only state-store rotation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# shellcheck source=scripts/lib/state-writer.sh
. "$SCRIPT_DIR/lib/state-writer.sh"

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
    '{schema_version:1,id:$id,task_id:"CC-316",executor:"codex",state:"ok",working_dir:"/tmp/test",trace_path:"/tmp/test.jsonl",exit_code:0,created_ts:$created_ts}'
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
  local name="state rotation: stale rotating file is recovered idempotently"
  should_run "$name" || return 0
  local store proj archive ids active_ids tmp_left
  store="$tmp_root/recovery"
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" state_store_init
  proj="$(project_dir_for_store "$store")"
  event_json 1 > "$proj/events.jsonl.rotating"
  printf 'partial\n' > "$proj/archive/events-202606-9999.jsonl.gz.tmp"
  append_event_n "$store" 2 100000
  archive="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print -quit)"
  ids="$(ids_from_gzip "$archive")"
  active_ids="$(ids_from_file "$proj/events.jsonl")"
  tmp_left="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz.tmp' -print 2>/dev/null)"
  append_event_n "$store" 3 100000
  if [[ -f "$archive" && ! -f "$proj/events.jsonl.rotating" && -z "$tmp_left" &&
        "$ids" == "evt-20260606T000001Z-000001 " &&
        "$active_ids" == "evt-20260606T000002Z-000002 " ]]; then
    pass "$name"
  else
    fail "$name" "archive=$archive ids=$ids active_ids=$active_ids tmp_left=$tmp_left rotating=$(ls "$proj"/*.rotating 2>/dev/null || true)"
  fi
}

case_rotation_gzip_unavailable() {
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
  log="$(cat "$home/.claude/logs/state-writer.err" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 && -z "$archives" &&
        "$active_ids" == "evt-20260606T000001Z-000001 evt-20260606T000002Z-000002 " &&
        "$log" == *"gzip unavailable"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc archives=$archives active_ids=$active_ids log=$log"
  fi
}

case_rotation_gzip_failure_nonfatal() {
  local name="state rotation: gzip failure does not fail append or lose active rows"
  should_run "$name" || return 0
  local store proj path home rc=0 archives active_ids rotating log
  store="$tmp_root/gzip-fail-store"
  home="$tmp_root/gzip-fail-home"
  append_event_n "$store" 1 1
  path="$(make_path_with_failing_gzip "$tmp_root/gzip-fail-bin")"
  HOME="$home" PATH="$path" PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" PM_DISPATCH_ROTATE_MAX_BYTES=1 \
    events_append "$(event_json 2)" || rc=$?
  proj="$(project_dir_for_store "$store")"
  archives="$(find "$proj/archive" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print 2>/dev/null)"
  active_ids="$(ids_from_file "$proj/events.jsonl")"
  rotating="$(find "$proj" -maxdepth 1 -type f -name 'events.jsonl.rotating' -print 2>/dev/null)"
  log="$(cat "$home/.claude/logs/state-writer.err" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 && -z "$archives" && -z "$rotating" &&
        "$active_ids" == "evt-20260606T000001Z-000001 evt-20260606T000002Z-000002 " &&
        "$log" == *"gzip failed"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc archives=$archives rotating=$rotating active_ids=$active_ids log=$log"
  fi
}

case_rotation_below_threshold
case_rotation_byte_threshold_triggers
case_rotation_monotonic_segments
case_rotation_gzip_integrity
case_rotation_reader_integration
case_rotation_runs_independent
case_rotation_crash_recovery
case_rotation_gzip_unavailable
case_rotation_gzip_failure_nonfatal

th_summary
