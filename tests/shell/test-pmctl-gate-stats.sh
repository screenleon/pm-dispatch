#!/usr/bin/env bash
# Regression tests for `pmctl gate stats` — read-only operational-cost
# aggregation over PR-gate artifacts already on disk.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/state-paths.sh
. "$REPO_ROOT/runtime/lib/state-paths.sh"

gs_project_dir() {
  local store="$1" proj_dir
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$REPO_ROOT" _sw_project_dir)"
  proj_dir="${proj_dir%/}"
  mkdir -p "$proj_dir/runs"
  printf '%s\n' "$proj_dir"
}

# gs_make_gate_run <proj_dir> <run_id> <final> <tier> <mode> <reviewers-csv> \
#                  [created_at] [finished_at] [base_commit] [findings-json] [protocol-lines] [malformed]
# reviewers-csv: "critic=approve,qa-tester=block"
# findings-json: a reviewer_result_v1 findings array literal, or "" for none
# protocol-lines: "accepted|ok;retryable-failure|invalid reviewer protocol" or ""
# malformed: "1" appends one extra reviewer_result_v1 block whose body is not
#            valid JSON (to exercise the degraded-data contract)
gs_make_gate_run() {
  local proj_dir="$1" run_id="$2" final="$3" tier="$4" mode="$5" reviewers="$6"
  local created="${7:-}" finished="${8:-}" base="${9:-}" findings="${10:-}" protocol="${11:-}"
  local malformed="${12:-}"
  local dir="$proj_dir/runs/$run_id/.gate-results"
  mkdir -p "$dir"
  local ts="${run_id#gate-}"; ts="${ts%%-*}"
  local md="$dir/gate-$ts.md"

  {
    printf -- '---\n'
    printf 'gate_result_version: pr_gate_result_v5\n'
    [[ -n "$final" ]] && printf 'final: %s\n' "$final"
    [[ -n "$tier" ]] && printf 'tier: %s\n' "$tier"
    [[ -n "$mode" ]] && printf 'mode: %s\n' "$mode"
    printf 'most_severe: approve\n'
    printf 'reviewers:\n'
    local pair k v
    IFS=',' read -ra _pairs <<< "$reviewers"
    for pair in "${_pairs[@]}"; do
      k="${pair%%=*}"; v="${pair#*=}"
      printf '  %s: %s\n' "$k" "$v"
    done
    printf 'escalation:\n'
    printf '  recommended: false\n'
    printf -- '---\n'
    printf '\n# PR-Gate Result\n\n'
    if [[ -n "$findings" ]]; then
      for pair in "${_pairs[@]}"; do
        k="${pair%%=*}"
        printf '## %s\n```reviewer_result_v1\n' "$k"
        jq -cn --arg r "$k" --argjson f "$findings" '{kind:"gate_reviewer_result_v1",reviewer:$r,verdict:"block",findings:$f}'
        printf '```\n\n'
      done
    fi
    if [[ "$malformed" == 1 ]]; then
      # \140 is an octal backtick -- keeps a code-fence literal out of the
      # source so shellcheck does not read it as a command substitution.
      local fence
      fence="$(printf '\140\140\140')"
      printf '## broken\n%sreviewer_result_v1\n{ this is not json\n%s\n\n' "$fence" "$fence"
    fi
  } > "$md"

  # assurance sidecar
  local assurance="$md.assurance.json"
  jq -n \
    --arg created "$created" --arg finished "$finished" --arg base "$base" \
    '{
      subject: {
        repository: {key: "fixturekey"},
        base: (if $base == "" then {} else {commit: $base} end),
        created_at: (if $created == "" then null else $created end),
        finished_at: (if $finished == "" then null else $finished end)
      },
      policy: {classification: {line_changes: 42}}
    }' > "$assurance"

  if [[ -n "$protocol" ]]; then
    local plog="$dir/gate-protocol-attempts-$ts.jsonl" pl pout pr
    : > "$plog"
    IFS=';' read -ra _pl <<< "$protocol"
    for pl in "${_pl[@]}"; do
      pout="${pl%%|*}"; pr="${pl#*|}"
      jq -cn --arg o "$pout" --arg r "$pr" '{kind:"gate_protocol_attempt_v1",outcome:$o,reason:$r}' >> "$plog"
    done
  fi
}

gs_run() {
  local store="$1" out="$2" err="$3"; shift 3
  local status=0
  ( cd "$REPO_ROOT" && PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" gate stats "$@" ) > "$out" 2> "$err" || status=$?
  return "$status"
}

# --------------------------------------------------------------------------

case_json_envelope_shape() {
  local name="pmctl gate stats: --json envelope carries every documented section"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/shape-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000000-aaaaaa GO full sequential "critic=approve,qa-tester=pass" \
    2026-08-10T00:00:00Z 2026-08-10T00:10:00Z c0ffee00 "" "accepted|ok"
  out="$tmp_root/shape.out"; err="$tmp_root/shape.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && jq -e '
      ._meta.schema_version == 1
      and (._meta.derivability | has("wall_time") and has("rounds_to_go") and has("tokens"))
      and (._meta.derivability.tokens | test("deferred"))
      and has("totals") and has("by_verdict") and has("by_tier") and has("by_mode")
      and has("by_reviewer") and has("protocol_failures") and has("wall_time")
      and has("round_clusters")
    ' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_verdict_and_tier_counts() {
  local name="pmctl gate stats: by_verdict and by_tier count complete gates"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/verdict-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000001-a1 GO    full     sequential "critic=approve" 2026-08-10T00:00:00Z 2026-08-10T00:05:00Z b1
  gs_make_gate_run "$proj" gate-20260810-000002-a2 NO-GO full     sequential "critic=block"   2026-08-10T00:10:00Z 2026-08-10T00:20:00Z b1
  gs_make_gate_run "$proj" gate-20260810-000003-a3 GO    standard parallel   "critic=approve" 2026-08-10T00:30:00Z 2026-08-10T00:34:00Z b2
  out="$tmp_root/verdict.out"; err="$tmp_root/verdict.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.by_verdict.GO' "$out")" == 2 ]] \
    && [[ "$(jq -r '.by_verdict."NO-GO"' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_tier.full' "$out")" == 2 ]] \
    && [[ "$(jq -r '.by_tier.standard' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_mode.sequential' "$out")" == 2 ]] \
    && [[ "$(jq -r '.by_mode.parallel' "$out")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_incomplete_source_not_dropped() {
  local name="pmctl gate stats: a result with no final: is incomplete_source, not a verdict"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/incomplete-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000010-ok GO full sequential "critic=approve" 2026-08-10T00:00:00Z 2026-08-10T00:05:00Z z1
  # no final: at all
  gs_make_gate_run "$proj" gate-20260810-000011-bad "" full sequential "critic=approve" 2026-08-10T01:00:00Z 2026-08-10T01:05:00Z z1
  out="$tmp_root/incomplete.out"; err="$tmp_root/incomplete.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.totals.gates' "$out")" == 2 ]] \
    && [[ "$(jq -r '.totals.incomplete_source' "$out")" == 1 ]] \
    && [[ "$(jq -r '.totals.complete' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_verdict | to_entries | map(.value) | add' "$out")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_dual_scan_dedup() {
  local name="pmctl gate stats: frozen + live rows both counted, a run in both counted once"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/dual-store"
  proj="$(gs_project_dir "$store")"
  # live-only run
  gs_make_gate_run "$proj" gate-20260810-000100-live GO full sequential "critic=approve" 2026-08-10T00:00:00Z 2026-08-10T00:06:00Z d1
  # run present in both the summary and as a live dir -> must not double count
  gs_make_gate_run "$proj" gate-20260810-000101-both NO-GO full sequential "critic=block" 2026-08-10T01:00:00Z 2026-08-10T01:12:00Z d1
  # frozen-only run (summary row, no live dir)
  {
    jq -cn '{run_id:"gate-20260809-120000-frozen",kind:"gate",status:"complete",duration_seconds:300,
             gate:{final:"GO",tier:"standard",most_severe:"approve",
                   reviewers:{critic:"approve"},findings_by_severity:"unavailable"}}'
    jq -cn '{run_id:"gate-20260810-000101-both",kind:"gate",status:"complete",duration_seconds:720,
             gate:{final:"NO-GO",tier:"full",most_severe:"block",
                   reviewers:{critic:"block"},findings_by_severity:"unavailable"}}'
  } > "$proj/runs-summary.jsonl"
  out="$tmp_root/dual.out"; err="$tmp_root/dual.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.totals.gates' "$out")" == 3 ]] \
    && [[ "$(jq -r '._meta.scan.frozen' "$out")" == 2 ]] \
    && [[ "$(jq -r '._meta.scan.live' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_verdict.GO' "$out")" == 2 ]] \
    && [[ "$(jq -r '.by_verdict."NO-GO"' "$out")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_corrupt_frozen_summary_flags_incomplete() {
  local name="pmctl gate stats: a malformed runs-summary.jsonl line is counted, flagged incomplete, and does not drop later rows"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/corruptfrozen-store"
  proj="$(gs_project_dir "$store")"
  # valid gate row, then a malformed line, then another valid gate row.
  {
    jq -cn '{run_id:"gate-20260809-100000-a",kind:"gate",status:"complete",duration_seconds:100,
             gate:{final:"GO",tier:"full",most_severe:"approve",reviewers:{critic:"approve"},findings_by_severity:"unavailable"}}'
    printf '{ this line is not valid json\n'
    jq -cn '{run_id:"gate-20260809-110000-b",kind:"gate",status:"complete",duration_seconds:200,
             gate:{final:"NO-GO",tier:"full",most_severe:"block",reviewers:{critic:"block"},findings_by_severity:"unavailable"}}'
  } > "$proj/runs-summary.jsonl"
  out="$tmp_root/corruptfrozen.out"; err="$tmp_root/corruptfrozen.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '._meta.scan.frozen_summary' "$out")" == "incomplete" ]] \
    && [[ "$(jq -r '._meta.scan.frozen_parse_errors' "$out")" == 1 ]] \
    && [[ "$(jq -r '._meta.scan.frozen' "$out")" == 2 ]] \
    && [[ "$(jq -r '.by_verdict.GO // 0' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_verdict."NO-GO" // 0' "$out")" == 1 ]] \
    && grep -q 'incomplete' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status meta=$(jq -c '._meta.scan' "$out") err=$(<"$err")"
  fi
}

case_unparseable_live_artifact_is_counted_not_dropped() {
  local name="pmctl gate stats: a live gate run with an unreadable result artifact is counted as a parse error and flagged"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/liveerr-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000800-ok  GO full sequential "critic=approve" 2026-08-10T00:00:00Z 2026-08-10T00:05:00Z le1
  gs_make_gate_run "$proj" gate-20260810-000801-bad GO full sequential "critic=approve" 2026-08-10T01:00:00Z 2026-08-10T01:05:00Z le2
  # make the second run's result artifact unreadable -> jq --rawfile fails
  chmod 000 "$proj/runs/gate-20260810-000801-bad/.gate-results/"*.md
  out="$tmp_root/liveerr.out"; err="$tmp_root/liveerr.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  chmod 644 "$proj/runs/gate-20260810-000801-bad/.gate-results/"*.md 2>/dev/null || true
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '._meta.scan.live' "$out")" == 1 ]] \
    && [[ "$(jq -r '._meta.scan.live_scan' "$out")" == "incomplete" ]] \
    && [[ "$(jq -r '._meta.scan.live_parse_errors' "$out")" == 1 ]] \
    && grep -q 'incomplete' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status meta=$(jq -c '._meta.scan' "$out") err=$(<"$err")"
  fi
}

case_non_iso_assurance_timestamps_keep_the_row() {
  local name="pmctl gate stats: a non-ISO assurance created_at drops only the duration, the run still counts"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/badts-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000900-bt NO-GO full sequential "critic=block" \
    "not-a-timestamp" "also-not" bt1
  out="$tmp_root/badts.out"; err="$tmp_root/badts.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '._meta.scan.live' "$out")" == 1 ]] \
    && [[ "$(jq -r '._meta.scan.live_scan' "$out")" == "ok" ]] \
    && [[ "$(jq -r '.by_verdict."NO-GO"' "$out")" == 1 ]] \
    && [[ "$(jq -r '.wall_time.count' "$out")" == 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status meta=$(jq -c '._meta.scan' "$out") wt=$(jq -c '.wall_time' "$out") err=$(<"$err")"
  fi
}

case_frozen_summary_ok_when_clean() {
  local name="pmctl gate stats: frozen_summary is ok and error count 0 for a clean runs-summary.jsonl"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/cleanfrozen-store"
  proj="$(gs_project_dir "$store")"
  jq -cn '{run_id:"gate-20260809-100000-c",kind:"gate",status:"complete",duration_seconds:100,
           gate:{final:"GO",tier:"full",reviewers:{critic:"approve"},findings_by_severity:"unavailable"}}' \
    > "$proj/runs-summary.jsonl"
  out="$tmp_root/cleanfrozen.out"; err="$tmp_root/cleanfrozen.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '._meta.scan.frozen_summary' "$out")" == "ok" ]] \
    && [[ "$(jq -r '._meta.scan.frozen_parse_errors' "$out")" == 0 ]] \
    && [[ ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status meta=$(jq -c '._meta.scan' "$out") err=$(<"$err")"
  fi
}

case_round_clusters_heuristic() {
  local name="pmctl gate stats: round_clusters group by base commit, count to first GO, carry caveat"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/round-store"
  proj="$(gs_project_dir "$store")"
  # base AAA: NO-GO, NO-GO, GO  -> 3 rounds, reached
  gs_make_gate_run "$proj" gate-20260810-000200-r1 NO-GO full sequential "critic=block"   2026-08-10T00:00:00Z 2026-08-10T00:10:00Z AAA
  gs_make_gate_run "$proj" gate-20260810-000201-r2 NO-GO full sequential "critic=block"   2026-08-10T01:00:00Z 2026-08-10T01:10:00Z AAA
  gs_make_gate_run "$proj" gate-20260810-000202-r3 GO    full sequential "critic=approve" 2026-08-10T02:00:00Z 2026-08-10T02:08:00Z AAA
  # base BBB: NO-GO only -> 1 round, not reached
  gs_make_gate_run "$proj" gate-20260810-000203-r4 NO-GO full sequential "critic=block"   2026-08-10T03:00:00Z 2026-08-10T03:10:00Z BBB
  out="$tmp_root/round.out"; err="$tmp_root/round.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  local aaa bbb
  aaa="$(jq -c '.round_clusters[] | select(.base_commit == "AAA")' "$out")"
  bbb="$(jq -c '.round_clusters[] | select(.base_commit == "BBB")' "$out")"
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.rounds' <<<"$aaa")" == 3 ]] \
    && [[ "$(jq -r '.reached_go' <<<"$aaa")" == true ]] \
    && [[ "$(jq -r '.clustering' <<<"$aaa")" == "heuristic-base-commit" ]] \
    && [[ "$(jq -r '.rounds' <<<"$bbb")" == 1 ]] \
    && [[ "$(jq -r '.reached_go' <<<"$bbb")" == false ]] \
    && [[ "$(jq -r '._meta.derivability.rounds_to_go' "$out")" == "heuristic-base-commit" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status aaa=$aaa bbb=$bbb err=$(<"$err")"
  fi
}

case_wall_time_from_assurance_and_mtime() {
  local name="pmctl gate stats: wall time uses assurance endpoints, falls back to mtime span"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/wall-store"
  proj="$(gs_project_dir "$store")"
  # assurance endpoints present -> exactly 600s
  gs_make_gate_run "$proj" gate-20260810-000300-w1 GO full sequential "critic=approve" 2026-08-10T00:00:00Z 2026-08-10T00:10:00Z w1
  # no assurance timestamps -> mtime span fallback (touch files 120s apart)
  gs_make_gate_run "$proj" gate-20260810-000301-w2 GO full sequential "critic=approve" "" "" w2
  local d2="$proj/runs/gate-20260810-000301-w2/.gate-results"
  touch -d '2026-08-10T05:00:00' "$d2"/*.md
  touch -d '2026-08-10T05:02:00' "$d2"/*.assurance.json
  out="$tmp_root/wall.out"; err="$tmp_root/wall.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.wall_time.count' "$out")" == 2 ]] \
    && [[ "$(jq -r '.wall_time.max_seconds' "$out")" == 600 ]] \
    && [[ "$(jq -r '.wall_time.total_seconds' "$out")" == 720 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_by_reviewer_merges_verdicts_and_findings() {
  local name="pmctl gate stats: by_reviewer merges verdict tallies with finding counts by severity"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/rev-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000400-v1 NO-GO full sequential "qa-tester=block,critic=advise" \
    2026-08-10T00:00:00Z 2026-08-10T00:10:00Z rv \
    '[{"id":"qa-F1","severity":"high"},{"id":"qa-F2","severity":"high"},{"id":"qa-F3","severity":"low"}]'
  gs_make_gate_run "$proj" gate-20260810-000401-v2 GO full sequential "qa-tester=pass,critic=approve" \
    2026-08-10T01:00:00Z 2026-08-10T01:05:00Z rv2
  out="$tmp_root/rev.out"; err="$tmp_root/rev.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.by_reviewer."qa-tester".verdicts.block' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_reviewer."qa-tester".verdicts.pass' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_reviewer."qa-tester".findings.high' "$out")" == 2 ]] \
    && [[ "$(jq -r '.by_reviewer."qa-tester".findings.low' "$out")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_malformed_reviewer_block_forces_unavailable() {
  local name="pmctl gate stats: a mixed valid/malformed reviewer block set degrades to unavailable, not partial counts"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/malformed-store"
  proj="$(gs_project_dir "$store")"
  # One valid reviewer block with real findings, plus one malformed block.
  gs_make_gate_run "$proj" gate-20260810-000450-mf NO-GO full sequential "qa-tester=block" \
    2026-08-10T00:00:00Z 2026-08-10T00:10:00Z mf \
    '[{"id":"qa-F1","severity":"high"},{"id":"qa-F2","severity":"high"}]' "" 1
  # A clean run so by_reviewer is otherwise populated.
  gs_make_gate_run "$proj" gate-20260810-000451-ok GO full sequential "qa-tester=pass" \
    2026-08-10T01:00:00Z 2026-08-10T01:05:00Z ok2
  out="$tmp_root/malformed.out"; err="$tmp_root/malformed.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  # The malformed run must contribute NO finding counts (degraded to
  # unavailable), so qa-tester.findings stays absent/empty despite the valid
  # block in the same artifact naming two high findings.
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.totals.gates' "$out")" == 2 ]] \
    && [[ "$(jq -r '.by_reviewer."qa-tester".findings // {} | length' "$out")" == 0 ]] \
    && [[ "$(jq -r '.by_reviewer."qa-tester".verdicts.block' "$out")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status by_reviewer=$(jq -c '.by_reviewer' "$out") err=$(<"$err")"
  fi
}

case_protocol_failures_tally() {
  local name="pmctl gate stats: protocol_failures tallies outcomes and retryable reasons"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/proto-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000500-p1 GO full sequential "critic=approve" \
    2026-08-10T00:00:00Z 2026-08-10T00:06:00Z p1 "" \
    "retryable-failure|invalid reviewer protocol;retryable-failure|invalid reviewer protocol;accepted|ok"
  gs_make_gate_run "$proj" gate-20260810-000501-p2 GO full sequential "critic=approve" \
    2026-08-10T01:00:00Z 2026-08-10T01:06:00Z p2 "" \
    "retryable-failure|coverage matrix parity mismatch;accepted|ok"
  out="$tmp_root/proto.out"; err="$tmp_root/proto.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.protocol_failures.accepted' "$out")" == 2 ]] \
    && [[ "$(jq -r '.protocol_failures."retryable-failure"' "$out")" == 3 ]] \
    && [[ "$(jq -r '.protocol_failures.reasons."invalid reviewer protocol"' "$out")" == 2 ]] \
    && [[ "$(jq -r '.protocol_failures.reasons."coverage matrix parity mismatch"' "$out")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_since_filters_by_run_id_date_for_frozen() {
  local name="pmctl gate stats: --since excludes older rows, using run-id date when created_at absent"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/since-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260701-000000-old GO full sequential "critic=approve" 2026-07-01T00:00:00Z 2026-07-01T00:05:00Z s1
  gs_make_gate_run "$proj" gate-20260815-000000-new GO full sequential "critic=approve" 2026-08-15T00:00:00Z 2026-08-15T00:05:00Z s2
  # frozen rows: no created_at, so the run-id date is the cutoff key
  {
    jq -cn '{run_id:"gate-20260705-000000-fold",kind:"gate",status:"complete",duration_seconds:200,
             gate:{final:"GO",tier:"full",reviewers:{critic:"approve"},findings_by_severity:"unavailable"}}'
    jq -cn '{run_id:"gate-20260820-000000-fnew",kind:"gate",status:"complete",duration_seconds:200,
             gate:{final:"NO-GO",tier:"full",reviewers:{critic:"block"},findings_by_severity:"unavailable"}}'
  } > "$proj/runs-summary.jsonl"
  out="$tmp_root/since.out"; err="$tmp_root/since.err"
  gs_run "$store" "$out" "$err" --since 2026-08-01 --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.totals.gates' "$out")" == 2 ]] \
    && [[ "$(jq -r '._meta.since' "$out")" == "2026-08-01" ]] \
    && [[ "$(jq -r '._meta.since_cutoff' "$out")" == "day granularity" ]] \
    && [[ "$(jq -r '.by_verdict.GO' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_verdict."NO-GO"' "$out")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_since_time_aware_for_live_rows() {
  local name="pmctl gate stats: a Z-suffixed --since excludes an earlier same-UTC-day live run"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/sincetime-store"
  proj="$(gs_project_dir "$store")"
  # Two live runs on the SAME day, on opposite sides of a 12:00Z cutoff.
  gs_make_gate_run "$proj" gate-20260810-000000-early GO full sequential "critic=approve" \
    2026-08-10T09:00:00Z 2026-08-10T09:05:00Z tt1
  gs_make_gate_run "$proj" gate-20260810-000001-late  NO-GO full sequential "critic=block" \
    2026-08-10T15:00:00Z 2026-08-10T15:10:00Z tt2
  # A frozen row on the same day with no created_at -> kept at day granularity
  # (a sub-day bound cannot place it, so it must not be silently dropped).
  jq -cn '{run_id:"gate-20260810-000002-frozen",kind:"gate",status:"complete",duration_seconds:100,
           gate:{final:"GO",tier:"full",reviewers:{critic:"approve"},findings_by_severity:"unavailable"}}' \
    > "$proj/runs-summary.jsonl"
  out="$tmp_root/sincetime.out"; err="$tmp_root/sincetime.err"
  gs_run "$store" "$out" "$err" --since 2026-08-10T12:00:00Z --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '._meta.scan.live' "$out")" == 1 ]] \
    && [[ "$(jq -r '._meta.scan.frozen' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_verdict."NO-GO" // 0' "$out")" == 1 ]] \
    && [[ "$(jq -r '.by_verdict.GO // 0' "$out")" == 1 ]] \
    && [[ "$(jq -r '._meta.since_cutoff' "$out")" == *"time-aware"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_text_and_json_agree() {
  local name="pmctl gate stats: text output reports the same counts as --json"
  should_run "$name" || return 0
  local store proj tout terr jout jerr status=0
  store="$tmp_root/agree-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000600-t1 GO    full     sequential "critic=approve" 2026-08-10T00:00:00Z 2026-08-10T00:05:00Z t1
  gs_make_gate_run "$proj" gate-20260810-000601-t2 NO-GO standard parallel   "critic=block"   2026-08-10T01:00:00Z 2026-08-10T01:10:00Z t2
  tout="$tmp_root/agree.tout"; terr="$tmp_root/agree.terr"
  jout="$tmp_root/agree.jout"; jerr="$tmp_root/agree.jerr"
  gs_run "$store" "$tout" "$terr" || status=$?
  gs_run "$store" "$jout" "$jerr" --json || status=$?
  local jgo jnogo
  jgo="$(jq -r '.by_verdict.GO' "$jout")"
  jnogo="$(jq -r '.by_verdict."NO-GO"' "$jout")"
  if [[ "$status" -eq 0 ]] \
    && grep -q "GO $jgo" "$tout" \
    && grep -q "NO-GO $jnogo" "$tout" \
    && grep -q 'rounds to GO  (heuristic' "$tout"; then
    pass "$name"
  else
    fail "$name" "status=$status jgo=$jgo jnogo=$jnogo text=$(<"$tout") err=$(<"$jerr")"
  fi
}

case_read_only_no_state_writes() {
  local name="pmctl gate stats: does not mutate the state store and calls no writer"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/ro-store"
  proj="$(gs_project_dir "$store")"
  gs_make_gate_run "$proj" gate-20260810-000700-ro GO full sequential "critic=approve" 2026-08-10T00:00:00Z 2026-08-10T00:05:00Z ro
  printf 'sentinel\n' > "$proj/events.jsonl"
  local before after
  before="$(find "$proj" -type f -printf '%T@ %p\n' | sort)"
  out="$tmp_root/ro.out"; err="$tmp_root/ro.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  after="$(find "$proj" -type f -printf '%T@ %p\n' | sort)"
  # Grep for writer *calls*, with comments stripped so the "read-only: never
  # calls events_append" header does not count as a violation.
  local writer_calls
  writer_calls="$(sed 's/#.*//' "$REPO_ROOT/runtime/lib/pmctl-gate-stats.sh" \
    | grep -Enq '(^|[^_a-zA-Z])(events_append|sw_events_append|state_writer_[a-z_]*write)[[:space:]]' && echo hit || true)"
  if [[ "$status" -eq 0 ]] \
    && [[ "$before" == "$after" ]] \
    && [[ -z "$writer_calls" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status writer_calls=$writer_calls changed=$(diff <(printf '%s' "$before") <(printf '%s' "$after"))"
  fi
}

case_empty_partition_is_zeroed_report() {
  local name="pmctl gate stats: a partition with no gate runs yields a well-formed zero report"
  should_run "$name" || return 0
  local store proj out err status=0
  store="$tmp_root/empty-store"
  proj="$(gs_project_dir "$store")"
  out="$tmp_root/empty.out"; err="$tmp_root/empty.err"
  gs_run "$store" "$out" "$err" --json || status=$?
  if [[ "$status" -eq 0 ]] \
    && [[ "$(jq -r '.totals.gates' "$out")" == 0 ]] \
    && [[ "$(jq -r '.round_clusters | length' "$out")" == 0 ]] \
    && [[ "$(jq -r '.wall_time.count' "$out")" == 0 ]] \
    && [[ "$(jq -r '.wall_time.mean_seconds' "$out")" == "null" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_invalid_since_exits_2() {
  local name="pmctl gate stats: --since with a non-ISO value exits 2 with a usage error"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/badsince-store"
  gs_project_dir "$store" >/dev/null
  out="$tmp_root/badsince.out"; err="$tmp_root/badsince.err"
  gs_run "$store" "$out" "$err" --since yesterday || status=$?
  if [[ "$status" -eq 2 ]] && grep -q 'YYYY-MM-DD' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_since_calendar_impossible_exits_2() {
  local name="pmctl gate stats: --since with a calendar-impossible date exits 2"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/badcal-store"
  gs_project_dir "$store" >/dev/null
  out="$tmp_root/badcal.out"; err="$tmp_root/badcal.err"
  gs_run "$store" "$out" "$err" --since 2026-02-30 || status=$?
  if [[ "$status" -eq 2 ]] && grep -q 'calendar' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_unknown_flag_exits_2() {
  local name="pmctl gate stats: an unknown flag exits 2 with usage"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/badflag-store"
  gs_project_dir "$store" >/dev/null
  out="$tmp_root/badflag.out"; err="$tmp_root/badflag.err"
  gs_run "$store" "$out" "$err" --bogus || status=$?
  if [[ "$status" -eq 2 ]] && grep -q 'unknown argument' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_cd_requires_value_and_existing_dir() {
  local name="pmctl gate stats: --cd rejects a missing value and a non-existent dir"
  should_run "$name" || return 0
  local store out err s1=0 s2=0
  store="$tmp_root/cd-store"
  gs_project_dir "$store" >/dev/null
  out="$tmp_root/cd.out"; err="$tmp_root/cd.err"
  gs_run "$store" "$out" "$err" --cd || s1=$?
  gs_run "$store" "$out" "$err" --cd /no/such/dir/here || s2=$?
  if [[ "$s1" -eq 2 && "$s2" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "s1=$s1 s2=$s2 err=$(<"$err")"
  fi
}

case_help_exits_zero() {
  local name="pmctl gate stats: help exits 0 and describes the command"
  should_run "$name" || return 0
  local store out err status=0
  store="$tmp_root/help-store"
  out="$tmp_root/help.out"; err="$tmp_root/help.err"
  # `gate stats -h` is intercepted by the shared command-catalog help path
  # (prints to stdout); `pmctl help gate stats` is the same path.
  gs_run "$store" "$out" "$err" -h || status=$?
  if [[ "$status" -eq 0 ]] && grep -q 'pmctl gate stats' "$out"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_json_envelope_shape
case_verdict_and_tier_counts
case_incomplete_source_not_dropped
case_dual_scan_dedup
case_corrupt_frozen_summary_flags_incomplete
case_unparseable_live_artifact_is_counted_not_dropped
case_non_iso_assurance_timestamps_keep_the_row
case_frozen_summary_ok_when_clean
case_round_clusters_heuristic
case_wall_time_from_assurance_and_mtime
case_by_reviewer_merges_verdicts_and_findings
case_malformed_reviewer_block_forces_unavailable
case_protocol_failures_tally
case_since_filters_by_run_id_date_for_frozen
case_since_time_aware_for_live_rows
case_text_and_json_agree
case_read_only_no_state_writes
case_empty_partition_is_zeroed_report
case_invalid_since_exits_2
case_since_calendar_impossible_exits_2
case_unknown_flag_exits_2
case_cd_requires_value_and_existing_dir
case_help_exits_zero

th_summary
