#!/usr/bin/env bash
# Regression tests for pmctl run-stats (CC-358).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/state-writer.sh
. "$REPO_ROOT/runtime/lib/state-writer.sh"

run_stats_project_dir() {
  local store="$1" proj_dir
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" _sw_project_dir)"
  mkdir -p "$proj_dir"
  printf '%s\n' "$proj_dir"
}

run_event_json() {
  local id="$1" ts="$2" kind="$3" run_id="$4" adapter="$5" state="$6" note="${7:-}" \
    exit_code="${8:-0}" fallback="${9:-}"
  jq -cn \
    --arg id "$id" --arg ts "$ts" --arg kind "$kind" --arg run_id "$run_id" \
    --arg adapter "$adapter" --arg state "$state" --arg note "$note" \
    --argjson exit_code "$exit_code" --arg fallback "$fallback" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,subject_type:"run",subject_id:$run_id,actor:"pmctl",
      payload:({run_id:$run_id,state:$state,from_state:"",to_state:$state,exit_code:$exit_code,adapter:$adapter}
        + (if $note == "" then {} else {note:$note} end)
        + (if $fallback == "true" then {fallback_used:true} else {} end))}'
}

run_stats() {
  local store="$1" out="$2" err="$3"
  shift 3
  local status=0
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" run-stats "$@" > "$out" 2> "$err" || status=$?
  return "$status"
}

case_run_stats_basic_aggregation() {
  local name="pmctl run-stats: aggregates ok/failed/cancelled per adapter"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/basic-store"
  proj="$(run_stats_project_dir "$store")"
  {
    run_event_json evt-1 2026-08-10T00:00:00Z run.pending run-A codex pending
    run_event_json evt-2 2026-08-10T00:01:00Z run.completed run-A codex ok
    run_event_json evt-3 2026-08-10T00:02:00Z run.pending run-B codex pending
    run_event_json evt-4 2026-08-10T00:03:00Z run.failed run-B codex failed "" 1
    run_event_json evt-5 2026-08-10T00:04:00Z run.pending run-C codex pending
    run_event_json evt-6 2026-08-10T00:05:00Z run.cancelled run-C codex cancelled cancelled
  } > "$proj/events.jsonl"
  out="$tmp_root/basic.out"
  err="$tmp_root/basic.err"
  run_stats "$store" "$out" "$err" --since 2026-08-01 --json || status=$?
  local codex
  codex="$(jq -c '.adapters.codex' "$out" 2>/dev/null)"
  if [[ "$status" -eq 0 ]] && \
     [[ "$(jq -r '.adapters.codex.total' "$out")" == "3" ]] && \
     [[ "$(jq -r '.adapters.codex.ok' "$out")" == "1" ]] && \
     [[ "$(jq -r '.adapters.codex.failed' "$out")" == "1" ]] && \
     [[ "$(jq -r '.adapters.codex.cancelled' "$out")" == "1" ]] && \
     [[ "$(jq -r '.adapters.codex.nonzero_exit' "$out")" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status codex=$codex err=$(<"$err")"
  fi
}

case_run_stats_missing_terminal() {
  local name="pmctl run-stats: run with no terminal event counts as missing_terminal"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/missing-store"
  proj="$(run_stats_project_dir "$store")"
  {
    run_event_json evt-1 2026-08-10T00:00:00Z run.pending run-A codex pending
    run_event_json evt-2 2026-08-10T00:01:00Z run.dispatched run-A codex dispatched
    run_event_json evt-3 2026-08-10T00:02:00Z run.verifying run-A codex verifying
  } > "$proj/events.jsonl"
  out="$tmp_root/missing.out"
  err="$tmp_root/missing.err"
  run_stats "$store" "$out" "$err" --since 2026-08-01 --json || status=$?
  if [[ "$status" -eq 0 ]] && \
     [[ "$(jq -r '.adapters.codex.total' "$out")" == "1" ]] && \
     [[ "$(jq -r '.adapters.codex.missing_terminal' "$out")" == "1" ]] && \
     [[ "$(jq -r '.adapters.codex.ok' "$out")" == "0" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_post_verify_fail_note() {
  local name="pmctl run-stats: completed event with note=partial counts as post_verify_fail, not ok"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/partial-store"
  proj="$(run_stats_project_dir "$store")"
  {
    run_event_json evt-1 2026-08-10T00:00:00Z run.pending run-A opencode pending
    run_event_json evt-2 2026-08-10T00:01:00Z run.completed run-A opencode ok partial
  } > "$proj/events.jsonl"
  out="$tmp_root/partial.out"
  err="$tmp_root/partial.err"
  run_stats "$store" "$out" "$err" --since 2026-08-01 --json || status=$?
  if [[ "$status" -eq 0 ]] && \
     [[ "$(jq -r '.adapters.opencode.post_verify_fail' "$out")" == "1" ]] && \
     [[ "$(jq -r '.adapters.opencode.ok' "$out")" == "0" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_fallback_used() {
  local name="pmctl run-stats: fallback_used payload flag is counted per run"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/fallback-store"
  proj="$(run_stats_project_dir "$store")"
  {
    run_event_json evt-1 2026-08-10T00:00:00Z run.pending run-A opencode pending
    run_event_json evt-2 2026-08-10T00:01:00Z run.completed run-A opencode ok "" 0 true
    run_event_json evt-3 2026-08-10T00:02:00Z run.pending run-B opencode pending
    run_event_json evt-4 2026-08-10T00:03:00Z run.completed run-B opencode ok
  } > "$proj/events.jsonl"
  out="$tmp_root/fallback.out"
  err="$tmp_root/fallback.err"
  run_stats "$store" "$out" "$err" --since 2026-08-01 --json || status=$?
  if [[ "$status" -eq 0 ]] && \
     [[ "$(jq -r '.adapters.opencode.fallback_used' "$out")" == "1" ]] && \
     [[ "$(jq -r '.adapters.opencode.total' "$out")" == "2" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_since_filters_out_older_events() {
  local name="pmctl run-stats: --since excludes events before the cutoff"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/since-store"
  proj="$(run_stats_project_dir "$store")"
  {
    run_event_json evt-1 2026-07-01T00:00:00Z run.pending run-OLD claude pending
    run_event_json evt-2 2026-07-01T00:01:00Z run.completed run-OLD claude ok
  } > "$proj/events.jsonl"
  out="$tmp_root/since.out"
  err="$tmp_root/since.err"
  run_stats "$store" "$out" "$err" --since 2026-08-01 --json || status=$?
  if [[ "$status" -eq 0 ]] && [[ "$(jq -r '.adapters | has("claude")' "$out")" == "false" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_by_adapter_matches_default() {
  local name="pmctl run-stats: --by-adapter produces the same breakdown as the default"
  should_run "$name" || return 0
  local store proj out_default out_flag err status=0
  store="$tmp_root/by-adapter-store"
  proj="$(run_stats_project_dir "$store")"
  {
    run_event_json evt-1 2026-08-10T00:00:00Z run.pending run-A codex pending
    run_event_json evt-2 2026-08-10T00:01:00Z run.completed run-A codex ok
  } > "$proj/events.jsonl"
  out_default="$tmp_root/by-adapter-default.out"
  out_flag="$tmp_root/by-adapter-flag.out"
  err="$tmp_root/by-adapter.err"
  run_stats "$store" "$out_default" "$err" --since 2026-08-01 --json || status=$?
  run_stats "$store" "$out_flag" "$err" --since 2026-08-01 --by-adapter --json || status=$?
  if [[ "$status" -eq 0 ]] && diff -q "$out_default" "$out_flag" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status default=$(<"$out_default") flag=$(<"$out_flag")"
  fi
}

case_run_stats_empty_store_no_error() {
  local name="pmctl run-stats: empty/missing events.jsonl exits 0 with no error"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/empty-store"
  out="$tmp_root/empty.out"
  err="$tmp_root/empty.err"
  run_stats "$store" "$out" "$err" --since 2026-08-01 --json || status=$?
  if [[ "$status" -eq 0 ]] && \
     [[ "$(jq -c '.adapters' "$out" 2>/dev/null)" == "{}" ]] && \
     [[ "$(jq -r '._meta.archive_scanned' "$out" 2>/dev/null)" == "true" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_unknown_flag_usage() {
  local name="pmctl run-stats: unknown flag exits 2 with usage"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/unknown-store"
  out="$tmp_root/unknown.out"
  err="$tmp_root/unknown.err"
  run_stats "$store" "$out" "$err" --bogus || status=$?
  if [[ "$status" -eq 2 && ! -s "$out" ]] &&
     grep -Fq 'pmctl run-stats: unknown argument: --bogus' "$err" &&
     grep -Fq 'usage: pmctl run-stats' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_since_missing_value() {
  local name="pmctl run-stats: --since with no value exits 2, no report output"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/since-missing-store"
  out="$tmp_root/since-missing.out"
  err="$tmp_root/since-missing.err"
  run_stats "$store" "$out" "$err" --since || status=$?
  if [[ "$status" -eq 2 && ! -s "$out" ]] &&
     grep -Fq 'pmctl run-stats: --since requires a value' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_since_timezone_less_datetime_rejected() {
  # qa-tester-F001: a timezone-less T<time> value must be rejected, not
  # silently accepted as if it were the Z-suffixed (UTC) form the documented
  # contract and event ts values both require -- otherwise it would compare
  # against Z-suffixed event timestamps as if they shared a timezone.
  local name="pmctl run-stats: --since with T<time> but no trailing Z is rejected"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/since-no-z-store"
  out="$tmp_root/since-no-z.out"
  err="$tmp_root/since-no-z.err"
  run_stats "$store" "$out" "$err" --since "2026-08-01T00:00:00" --json || status=$?
  if [[ "$status" -eq 2 && ! -s "$out" ]] &&
     grep -Fq 'pmctl run-stats: --since must be YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_since_malformed_value_rejected() {
  local name="pmctl run-stats: malformed --since exits 2, explanatory error, no report output"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/since-malformed-store"
  out="$tmp_root/since-malformed.out"
  err="$tmp_root/since-malformed.err"
  run_stats "$store" "$out" "$err" --since yesterday --json || status=$?
  if [[ "$status" -eq 2 && ! -s "$out" ]] &&
     grep -Fq 'pmctl run-stats: --since must be YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_since_calendar_impossible_value_rejected() {
  # critic-F001: shape-only validation (regex) accepts calendar-impossible
  # values like a day-of-month of 99; date -u -d must catch what the regex
  # cannot, so an impossible cutoff never produces a misleadingly successful
  # report.
  local name="pmctl run-stats: calendar-impossible --since (shape-valid but nonexistent date) is rejected"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/since-impossible-store"
  out="$tmp_root/since-impossible.out"
  err="$tmp_root/since-impossible.err"
  run_stats "$store" "$out" "$err" --since "2026-13-99" --json || status=$?
  if [[ "$status" -eq 2 && ! -s "$out" ]] &&
     grep -Fq 'pmctl run-stats: --since is not a valid calendar date/time' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_json_meta_reports_archive_inclusive_scan() {
  # architecture-reviewer-F001: run-stats is archive-inclusive by default
  # (mirrors pmctl_trace_tail's read_archives=1), so the normal case is
  # archive_scanned=true with a note confirming archives were included -- not
  # a permanent limitation notice.
  local name="pmctl run-stats: --json output reports archive-inclusive scan in _meta by default"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/meta-store"
  proj="$(run_stats_project_dir "$store")"
  : > "$proj/events.jsonl"
  out="$tmp_root/meta.out"
  err="$tmp_root/meta.err"
  run_stats "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] &&
     [[ "$(jq -r '._meta.archive_scanned' "$out" 2>/dev/null)" == "true" ]] &&
     [[ "$(jq -r '._meta.note' "$out" 2>/dev/null)" == *"archive"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_human_output_reports_archive_inclusive_scan() {
  local name="pmctl run-stats: human-readable output reports archive-inclusive scan"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/meta-human-store"
  proj="$(run_stats_project_dir "$store")"
  : > "$proj/events.jsonl"
  out="$tmp_root/meta-human.out"
  err="$tmp_root/meta-human.err"
  run_stats "$store" "$out" "$err" || status=$?
  if [[ "$status" -eq 0 ]] && grep -Fq 'archive' "$out"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_run_stats_scans_rotated_archive() {
  # architecture-reviewer-F001 (fix, not just documentation): a run whose
  # only event lives in a rotated archive/events-*.jsonl.gz must still be
  # counted -- proves --since windows spanning rotation don't undercount.
  local name="pmctl run-stats: rotated archive/events-*.jsonl.gz is scanned and counted"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/archive-store"
  proj="$(run_stats_project_dir "$store")"
  mkdir -p "$proj/archive"
  {
    run_event_json evt-1 2026-06-01T00:00:00Z run.pending run-ARCHIVED codex pending
    run_event_json evt-2 2026-06-01T00:01:00Z run.completed run-ARCHIVED codex ok
  } | gzip -c > "$proj/archive/events-20260601.jsonl.gz"
  : > "$proj/events.jsonl"
  out="$tmp_root/archive.out"
  err="$tmp_root/archive.err"
  run_stats "$store" "$out" "$err" --since 2026-01-01 --json || status=$?
  if [[ "$status" -eq 0 ]] &&
     [[ "$(jq -r '.adapters.codex.total' "$out" 2>/dev/null)" == "1" ]] &&
     [[ "$(jq -r '.adapters.codex.ok' "$out" 2>/dev/null)" == "1" ]] &&
     [[ "$(jq -r '._meta.archive_scanned' "$out" 2>/dev/null)" == "true" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

# Behavior: run-stats scans events.jsonl in a single jq pass -- jq is invoked
# a fixed number of times for a whole partition, not once per event -- so a
# future return to per-event jq spawning is caught even though the aggregate
# report stays byte-identical.
# Steps: shim a counting `jq` wrapper onto PATH (it tallies invocations then
# exec's the real jq), run `run-stats --json` once over a 20-run partition and
# once over a 200-run partition, and assert the invocation tally is identical
# for both (O(1) in event count), non-zero, and that both reports aggregate
# the expected total. A per-event implementation would make the 200-run tally
# ~10x the 20-run one.
case_run_stats_single_jq_pass() {
  local name="pmctl run-stats: jq invocation count is O(1) in event count"
  should_run "$name" || return 0
  local store proj shimdir real_jq tally small large status=0
  real_jq="$(type -P jq)"
  store="$tmp_root/jqcount-store"
  proj="$(run_stats_project_dir "$store")"
  shimdir="$tmp_root/rs-jqcount-shim"
  tally="$tmp_root/rs-jqcount.tally"
  mkdir -p "$shimdir"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf 'printf x >> %q\n' "$tally"
    printf 'exec %q "$@"\n' "$real_jq"
  } > "$shimdir/jq"
  chmod +x "$shimdir/jq"

  gen_runs() {
    awk -v n="$1" 'BEGIN {
      for (i = 1; i <= n; i++) {
        printf "{\"schema_version\":1,\"id\":\"e%06d\",\"ts\":\"2026-06-06T00:%02d:00Z\",\"kind\":\"run.completed\",\"subject_type\":\"run\",\"subject_id\":\"R%d\",\"actor\":\"pmctl\",\"payload\":{\"run_id\":\"R%d\",\"adapter\":\"codex\",\"exit_code\":0}}\n", i, i % 60, i, i
      }
    }'
  }

  gen_runs 20 > "$proj/events.jsonl"
  : > "$tally"
  PATH="$shimdir:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" run-stats --json \
    > "$tmp_root/rs-jqcount-small.out" 2>/dev/null || status=$?
  small="$(wc -c < "$tally" | tr -d ' ')"

  gen_runs 200 > "$proj/events.jsonl"
  : > "$tally"
  PATH="$shimdir:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" run-stats --json \
    > "$tmp_root/rs-jqcount-large.out" 2>/dev/null || status=$?
  large="$(wc -c < "$tally" | tr -d ' ')"

  if [[ "$status" -eq 0 && "$small" -gt 0 && "$small" == "$large" &&
        "$(jq -r '.adapters.codex.total' "$tmp_root/rs-jqcount-large.out")" == "200" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status small=$small large=$large total=$(jq -r '.adapters.codex.total' "$tmp_root/rs-jqcount-large.out" 2>/dev/null)"
  fi
}

# Behavior: the streaming scan produces a byte-identical normalized JSON
# report to the pre-refactor per-line implementation across a heterogeneous
# partition -- valid terminal rows, a post-verify "partial", a nonzero exit,
# a cancelled run, a run with only a non-terminal event, a fallback_used
# run, a run older than --since, two malformed lines, a non-run event, and a
# run whose only event is in a rotated archive, spanning three adapters.
# Steps: build that fixture, run `run-stats --since 2026-06-01 --json`, and
# assert `jq -S` of the output equals the golden JSON captured from the
# origin/main implementation (CC-364 method: freeze the prior behavior as a
# fixture rather than re-run two implementations).
case_run_stats_streaming_matches_reference() {
  local name="pmctl run-stats: streaming report matches the pre-refactor golden"
  should_run "$name" || return 0
  local store proj out err status=0 expected got
  store="$tmp_root/golden-store"
  proj="$(run_stats_project_dir "$store")"
  mkdir -p "$proj/archive"
  run_event_json arc1 2026-06-06T00:01:00Z run.completed R-ARC codex ok \
    | gzip -c > "$proj/archive/events-202606.jsonl.gz"
  {
    run_event_json a1 2026-06-06T00:05:00Z run.completed R-OK      codex    ok
    run_event_json a2 2026-06-06T00:06:00Z run.completed R-PARTIAL codex    ok partial
    run_event_json a3 2026-06-06T00:07:00Z run.failed    R-FAIL    codex    failed "" 3
    run_event_json a4 2026-06-06T00:08:00Z run.cancelled R-CANC    opencode cancelled
    run_event_json a5 2026-06-06T00:09:00Z run.pending   R-MISSING opencode pending
    run_event_json a6 2026-06-06T00:10:00Z run.completed R-FB      grok     ok "" 0 true
    run_event_json a7 2026-05-01T00:00:00Z run.completed R-OLD     codex    ok
    printf '%s\n' '{"id":"broken",'
    printf '%s\n' 'totally not json'
    run_event_json g1 2026-06-06T00:11:00Z gate.completed G-1      codex    ok
  } > "$proj/events.jsonl"

  expected="$(jq -S . <<'GOLDEN'
{
  "_meta": { "schema_version": 1, "archive_scanned": true,
    "note": "active events.jsonl plus 1 rotated archive(s) were scanned" },
  "adapters": {
    "codex":    { "total": 4, "ok": 2, "failed": 1, "cancelled": 0, "post_verify_fail": 1, "nonzero_exit": 1, "missing_terminal": 0, "fallback_used": 0 },
    "opencode": { "total": 2, "ok": 0, "failed": 0, "cancelled": 1, "post_verify_fail": 0, "nonzero_exit": 0, "missing_terminal": 1, "fallback_used": 0 },
    "grok":     { "total": 1, "ok": 1, "failed": 0, "cancelled": 0, "post_verify_fail": 0, "nonzero_exit": 0, "missing_terminal": 0, "fallback_used": 1 }
  }
}
GOLDEN
)"

  out="$tmp_root/golden.out"
  err="$tmp_root/golden.err"
  run_stats "$store" "$out" "$err" --since 2026-06-01 --json || status=$?
  got="$(jq -S . "$out" 2>/dev/null)"
  if [[ "$status" -eq 0 && "$got" == "$expected" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err") diff=$(diff <(printf '%s\n' "$expected") <(printf '%s\n' "$got"))"
  fi
}

case_run_stats_basic_aggregation
case_run_stats_single_jq_pass
case_run_stats_streaming_matches_reference
case_run_stats_missing_terminal
case_run_stats_post_verify_fail_note
case_run_stats_fallback_used
case_run_stats_since_filters_out_older_events
case_run_stats_by_adapter_matches_default
case_run_stats_since_missing_value
case_run_stats_since_malformed_value_rejected
case_run_stats_since_timezone_less_datetime_rejected
case_run_stats_since_calendar_impossible_value_rejected
case_run_stats_json_meta_reports_archive_inclusive_scan
case_run_stats_human_output_reports_archive_inclusive_scan
case_run_stats_scans_rotated_archive
case_run_stats_empty_store_no_error
case_run_stats_unknown_flag_usage

th_summary
