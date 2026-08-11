#!/usr/bin/env bash
# Observational CC-521 live-model evaluator. It reports recall/variance but
# never turns model recall into a deterministic gate correctness decision.

set -euo pipefail

usage() {
  printf 'usage: %s --fixture FILE --result GATE.md [--result GATE.md ...] [--baseline REPORT.json] [--output REPORT.json]\n' "$0" >&2
}

fixture=""
baseline=""
output=""
results=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture) fixture="${2:-}"; shift 2 ;;
    --result) results+=("${2:-}"); shift 2 ;;
    --baseline) baseline="${2:-}"; shift 2 ;;
    --output) output="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

[[ -s "$fixture" && "${#results[@]}" -gt 0 ]] || { usage; exit 2; }
jq -e '.kind == "gate_test_gap_live_fixture_v1" and
  (.seeds | type == "array" and length > 1) and
  all(.seeds[]; (.id | type == "string" and length > 0) and
    (.signals | type == "array" and length > 0))' "$fixture" >/dev/null
if [[ -n "$baseline" ]]; then
  jq -e '.kind == "gate_test_gap_live_report_v1"' "$baseline" >/dev/null
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-test-gap-live-eval.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
runs_jsonl="$tmp_dir/runs.jsonl"

for result in "${results[@]}"; do
  [[ -s "$result" ]] || { printf 'missing result: %s\n' "$result" >&2; exit 2; }
  synthesis="$tmp_dir/$(basename "$result").synthesis.json"
  awk '
    $0 == "```synthesis_result_v1" { inside=1; next }
    inside && $0 == "```" { exit }
    inside { print }
  ' "$result" > "$synthesis"
  jq -e '.test_gap_matrix | type == "array"' "$synthesis" >/dev/null
  jq -nc --slurpfile fixture "$fixture" --slurpfile synthesis "$synthesis" \
    --arg artifact "$result" '
    ($synthesis[0].test_gap_matrix | map(
      [.affected_behavior,.contract,.scenario,.oracle,.failure_signal]
      | map(select(. != null)) | join(" ") | ascii_downcase
    ) | join(" ")) as $haystack |
    ($fixture[0].seeds | map(. + {
      detected:(any(.signals[]; . as $signal |
        ($haystack | contains($signal | ascii_downcase))))
    })) as $observations |
    {
      artifact:$artifact,
      detected_ids:[$observations[] | select(.detected) | .id],
      missed_ids:[$observations[] | select(.detected | not) | .id],
      recall:(([$observations[] | select(.detected)] | length) /
        ($observations | length))
    }' >> "$runs_jsonl"
done

report="$tmp_dir/report.json"
jq -sn --slurpfile fixture "$fixture" --slurpfile runs "$runs_jsonl" \
  --arg baseline "$baseline" '
  ($runs | map(.recall)) as $recalls |
  ($recalls | add / length) as $mean |
  {
    kind:"gate_test_gap_live_report_v1",
    schema_version:1,
    fixture_id:$fixture[0].fixture_id,
    correctness_gate:false,
    runs:$runs,
    summary:{
      run_count:($runs | length),
      mean_recall:$mean,
      min_recall:($recalls | min),
      max_recall:($recalls | max),
      variance:($recalls | map((. - $mean) * (. - $mean)) | add / length)
    }
  }' > "$report"

if [[ -n "$baseline" ]]; then
  jq --slurpfile baseline "$baseline" '
    . + {regression_observation:{
      baseline_mean_recall:$baseline[0].summary.mean_recall,
      delta:(.summary.mean_recall - $baseline[0].summary.mean_recall),
      observed:(.summary.mean_recall < $baseline[0].summary.mean_recall)
    }}' "$report" > "$tmp_dir/report-with-baseline.json"
  mv -- "$tmp_dir/report-with-baseline.json" "$report"
fi

if [[ -n "$output" ]]; then
  cp -- "$report" "$output"
else
  cat "$report"
fi
