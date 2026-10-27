#!/usr/bin/env bash
# Regression tests for pmctl time and the pm_timing_phase marker (CC-689, issue #742).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"
TIMING_LIB="$REPO_ROOT/runtime/lib/timing.sh"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# run_time <out> <err> <args...>: pmctl time with the given arguments; returns its status.
run_time() {
  local out="$1" err="$2" status=0
  shift 2
  "$PMCTL" time "$@" > "$out" 2> "$err" || status=$?
  return "$status"
}

case_time_json_shape_and_warm_stats() {
  local name="pmctl time: --runs 3 --json reports cold, warm p50/p95/max and no failures"
  should_run "$name" || return 0
  local out="$tmp_root/shape.out" err="$tmp_root/shape.err" status=0
  run_time "$out" "$err" --runs 3 --json -- true || status=$?
  if [[ "$status" -eq 0 ]] \
    && jq -e '.kind == "pmctl_time_v1" and .runs == 3 and .failed_runs == 0
      and (.cold_ms | type == "number") and .warm.runs == 2
      and (.warm.p50_ms <= .warm.p95_ms) and (.warm.p95_ms <= .warm.max_ms)
      and (.phases | length == 0)' "$out" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_time_single_run_has_no_warm() {
  local name="pmctl time: a single run reports cold only"
  should_run "$name" || return 0
  local out="$tmp_root/single.out" err="$tmp_root/single.err" status=0
  run_time "$out" "$err" --json -- true || status=$?
  if [[ "$status" -eq 0 ]] && jq -e '.runs == 1 and (has("warm") | not)' "$out" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_time_failing_command_exits_1() {
  local name="pmctl time: a failing command is counted and the exit status is 1"
  should_run "$name" || return 0
  local out="$tmp_root/fail.out" err="$tmp_root/fail.err" status=0
  run_time "$out" "$err" --runs 2 --json -- bash -c 'exit 3' || status=$?
  if [[ "$status" -eq 1 ]] && jq -e '.failed_runs == 2' "$out" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_time_phases_are_measured() {
  local name="pmctl time: pm_timing_phase markers become per-phase milliseconds"
  should_run "$name" || return 0
  local out="$tmp_root/phase.out" err="$tmp_root/phase.err" status=0
  run_time "$out" "$err" --runs 2 --json -- \
    bash -c '. "$1"; pm_timing_phase first; sleep 0.3; pm_timing_phase second; sleep 0.1' _ "$TIMING_LIB" || status=$?
  if [[ "$status" -eq 0 ]] \
    && jq -e '[.phases[].phase] == ["first","second"]
      and (.phases[0].median_ms >= 250) and (.phases[0].median_ms < 5000)
      and (.phases[1].median_ms >= 50) and (.phases[1].cold_ms != null)
      and (.phases[0].runs == 2)' "$out" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_time_marker_is_silent_and_inert_without_env() {
  local name="pm_timing_phase: prints nothing, with timing on or off, and writes only when asked"
  should_run "$name" || return 0
  local file="$tmp_root/marker.jsonl" off on status=0
  rm -f "$file"
  off="$(env -u PM_DISPATCH_TIMING_FILE bash -c '. "$1"; pm_timing_phase a; echo rc=$?' _ "$TIMING_LIB" 2>&1)" || status=$?
  on="$(PM_DISPATCH_TIMING_FILE="$file" bash -c '. "$1"; pm_timing_phase a; pm_timing_phase "Bad Name"; echo rc=$?' _ "$TIMING_LIB" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$off" == "rc=0" && "$on" == "rc=0" && "$(grep -c . "$file")" -eq 1 ]] \
    && grep -q '^{"phase":"a","t":[0-9.]*}$' "$file"; then
    pass "$name"
  else
    fail "$name" "status=$status off=$off on=$on file=$(cat "$file" 2>/dev/null)"
  fi
}

case_time_marker_survives_unwritable_file() {
  local name="pm_timing_phase: an unwritable timing file never fails the caller"
  should_run "$name" || return 0
  local got status=0
  got="$(PM_DISPATCH_TIMING_FILE="$tmp_root/no-such-dir/x.jsonl" bash -c 'set -e; . "$1"; pm_timing_phase a; echo ok' _ "$TIMING_LIB" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$got" == "ok" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status got=$got"
  fi
}

case_time_malformed_timing_lines_are_skipped() {
  local name="pmctl time: malformed lines in the timing file are skipped, not fatal"
  should_run "$name" || return 0
  local out="$tmp_root/junk.out" err="$tmp_root/junk.err" status=0
  run_time "$out" "$err" --json -- \
    bash -c 'printf "not json\n{\"phase\":\"ok\",\"t\":1.5}\n{\"phase\":\"bad\",\"t\":\"x\"}\n" >> "$PM_DISPATCH_TIMING_FILE"' || status=$?
  if [[ "$status" -eq 0 ]] && jq -e '[.phases[].phase] == ["ok"]' "$out" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_time_report_has_no_command_text_or_output() {
  local name="pmctl time: the report never carries the command's arguments or output"
  should_run "$name" || return 0
  local out="$tmp_root/priv.out" err="$tmp_root/priv.err" status=0
  run_time "$out" "$err" --runs 2 -- bash -c 'echo SECRET_OUTPUT_TOKEN; echo SECRET_STDERR_TOKEN >&2' SECRET_ARG_TOKEN || status=$?
  if [[ "$status" -eq 0 ]] && ! grep -q 'SECRET_' "$out" "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_time_show_output_passes_output_through() {
  local name="pmctl time: --show-output lets the command's own output through"
  should_run "$name" || return 0
  local out="$tmp_root/show.out" err="$tmp_root/show.err" status=0
  run_time "$out" "$err" --show-output -- echo VISIBLE_TOKEN || status=$?
  if [[ "$status" -eq 0 ]] && grep -q 'VISIBLE_TOKEN' "$out"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_time_pmctl_word_runs_this_checkout() {
  local name="pmctl time: a leading 'pmctl' runs this checkout, with no pmctl on PATH"
  should_run "$name" || return 0
  local out="$tmp_root/self.out" err="$tmp_root/self.err" status=0
  run_time "$out" "$err" --json -- pmctl commands --json || status=$?
  if [[ "$status" -eq 0 ]] && jq -e '.failed_runs == 0' "$out" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_time_baseline_reports_process_cost() {
  local name="pmctl time: --baseline adds the process and subshell start cost"
  should_run "$name" || return 0
  local out="$tmp_root/base.out" err="$tmp_root/base.err" status=0
  run_time "$out" "$err" --json --baseline -- true || status=$?
  if [[ "$status" -eq 0 ]] && jq -e '.baseline.subshell_ms | type == "number"' "$out" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_time_usage_errors_exit_2() {
  local name="pmctl time: a missing command, a bad --runs and an unknown option exit 2"
  should_run "$name" || return 0
  local out="$tmp_root/use.out" err="$tmp_root/use.err" bad="" args status
  for args in "--runs 3" "--" "--runs 0 -- true" "--runs 1001 -- true" "--runs x -- true" "--bogus -- true"; do
    status=0
    # shellcheck disable=SC2086  # the words are split on purpose.
    run_time "$out" "$err" $args || status=$?
    [[ "$status" -eq 2 ]] || bad="$bad [$args -> $status]"
  done
  if [[ -z "$bad" ]]; then
    pass "$name"
  else
    fail "$name" "unexpected statuses:$bad"
  fi
}

case_time_json_shape_and_warm_stats
case_time_single_run_has_no_warm
case_time_failing_command_exits_1
case_time_phases_are_measured
case_time_marker_is_silent_and_inert_without_env
case_time_marker_survives_unwritable_file
case_time_malformed_timing_lines_are_skipped
case_time_report_has_no_command_text_or_output
case_time_show_output_passes_output_through
case_time_pmctl_word_runs_this_checkout
case_time_baseline_reports_process_cost
case_time_usage_errors_exit_2

th_summary
