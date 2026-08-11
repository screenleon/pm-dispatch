#!/usr/bin/env bash
# Shared test fixtures for the pr-gate shell suites.

create_agents() {
  local home="$1"
  shift
  mkdir -p "$home/.claude/agents"
  local reviewer
  for reviewer in "$@"; do
    printf '# %s\n\nReviewer fixture.\n' "$reviewer" \
      > "$home/.claude/agents/$reviewer.md"
  done
}

pr_gate_fixture_write_reviewer_protocol() {
  local brief_file="$1" output_path="$2" reviewer="$3" verdict="$4"
  local mutation="${5:-${CODEX_GATE_STUB_PROTOCOL_MUTATION:-none}}"
  local scope_sha scope_path evidence_path hard_gate_class findings_json
  scope_sha="$(awk '$1 == "artifact_sha256:" { print $2; exit }' "$brief_file")"
  scope_path="$(awk '$1 == "artifact:" { print $2; exit }' "$brief_file")"
  evidence_path=".gate-results/$(basename "$scope_path")"
  hard_gate_class=none
  case "$verdict" in
    block-soft) hard_gate_class=soft_block ;;
    block) hard_gate_class=hard_block ;;
  esac
  findings_json='[]'
  if [[ "$hard_gate_class" != none ]]; then
    findings_json="$(jq -nc \
      --arg id "${reviewer}-F001" --arg reviewer "$reviewer" \
      --arg evidence_path "$evidence_path" \
      --arg hard_gate_class "$hard_gate_class" '[{
        id:$id,
        reviewer:$reviewer,
        severity:"high",
        hard_gate_class:$hard_gate_class,
        origin:"diff_caused",
        source:{path:$evidence_path,line:1,symbol:null},
        affected_behavior:"The changed behavior is blocked by the fixture finding.",
        why_it_matters:"The fixture models an actionable gate failure.",
        failure_mode:"The reviewed behavior fails when exercised.",
        minimum_fix_boundary:"Correct the changed behavior without expanding scope.",
        verification_expectation:"Run the focused regression for the changed behavior."
      }]')"
  fi
  if [[ "$mutation" == advisory-finding ]]; then
    findings_json="$(jq -nc \
      --arg id "${reviewer}-F001" --arg reviewer "$reviewer" \
      --arg evidence_path "$evidence_path" '[{
        id:$id,
        reviewer:$reviewer,
        severity:"low",
        hard_gate_class:"none",
        origin:"caution",
        source:{path:$evidence_path,line:1,symbol:null},
        affected_behavior:"The fixture preserves a lower-severity behavior note.",
        why_it_matters:"Synthesis must not discard advisory findings.",
        failure_mode:"The advisory disappears from remediation evidence.",
        minimum_fix_boundary:"Retain the original finding without increasing scope.",
        verification_expectation:"Run the focused advisory verification."
      }]')"
  fi
  if [[ "$mutation" == invalid-id ]]; then
    findings_json="$(jq -nc --arg reviewer "$reviewer" \
      --arg evidence_path "$evidence_path" '[{
      id:"invalid-id",
      reviewer:$reviewer,
      severity:"low",
      hard_gate_class:"none",
      origin:"caution",
      source:{path:$evidence_path,line:1,symbol:null},
      affected_behavior:"The fixture finding exercises stable-ID validation.",
      why_it_matters:"Unstable finding IDs cannot seed deterministic remediation.",
      failure_mode:"Downstream consumers cannot preserve finding identity.",
      minimum_fix_boundary:"Emit the reviewer-prefixed stable identifier.",
      verification_expectation:"Validate the corrected protocol artifact."
    }]')"
  fi
  jq -nc \
    --arg reviewer "$reviewer" \
    --arg scope_sha "$scope_sha" \
    --arg evidence_path "$evidence_path" \
    --arg verdict "$verdict" \
    --arg mutation "$mutation" \
    --argjson findings "$findings_json" '
    ["changed_files","paired_tests","sensitive_signals","public_interface",
      "schema","config","install","ci","release","migration",
      "bounded_expansion"] as $surfaces |
    {
      kind:"gate_reviewer_result_v1",
      schema_version:1,
      reviewer:$reviewer,
      scope_manifest_sha256:$scope_sha,
      coverage_claim:"declared-scope-checklist-not-review-completeness",
      coverage:($surfaces | map({
        surface:.,status:"examined",
        evidence_refs:[{path:$evidence_path,line:1,symbol:null}],
        reason:"Fixture examined this declared surface."
      })),
      findings:$findings,
      test_gaps:[(if ($findings | length) > 0 then {
        id:($reviewer + "-TG001"),
        reviewer:$reviewer,
        status:"gap",
        affected_behavior:$findings[0].affected_behavior,
        contract:"The changed behavior must fail under a focused regression mutation.",
        existing_evidence:[{path:$evidence_path,line:1,symbol:null}],
        coverage_dimensions:["negative","regression"],
        missing_layer:"integration",
        scenario:"Exercise the changed behavior under the recorded failure mode.",
        oracle:"The focused regression observes the expected contract outcome.",
        failure_signal:$findings[0].failure_mode,
        suggested_command:"bash tests/bin/run-tests.sh --path tests/shell/test-pr-gate.sh"
      } else {
        id:($reviewer + "-TG001"),
        reviewer:$reviewer,
        status:"no_gap",
        affected_behavior:"The fixture-reviewed behavior has sufficient regression evidence.",
        contract:"The declared behavior remains covered by the focused fixture.",
        existing_evidence:[{path:$evidence_path,line:1,symbol:null}],
        coverage_dimensions:["happy","boundary","negative","regression"],
        missing_layer:"none",
        scenario:null,
        oracle:null,
        failure_signal:null,
        suggested_command:null
      } end)],
      verdict:$verdict,
      rationale:"Fixture reviewer completed every declared coverage surface."
    }
    | if $mutation == "missing-surface" then .coverage = .coverage[:-1]
      elif $mutation == "evidence-less-blocker"
      then .findings[0].source = {path:"",line:null,symbol:null}
      elif $mutation == "out-of-scope-reference"
      then .coverage[0].evidence_refs[0].path = "not-declared-by-scope.md"
      elif $mutation == "out-of-range-line"
      then .coverage[0].evidence_refs[0].line = 999999
      elif $mutation == "qa-legacy-pass" and $reviewer == "qa-tester"
      then .verdict = "pass"
      elif $mutation == "critic-extra-top-level" and $reviewer == "critic"
      then .alignment = "Legacy role-specific field."
      elif $mutation == "risk-short-id" and $reviewer == "risk-reviewer"
      then .findings = [{
        id:"risk-F001",
        reviewer:"risk-reviewer",
        severity:"low",
        hard_gate_class:"none",
        origin:"caution",
        source:{path:$evidence_path,line:1},
        affected_behavior:"The fixture models an abbreviated finding ID.",
        why_it_matters:"Abbreviated IDs cannot preserve reviewer identity.",
        failure_mode:"Downstream remediation loses deterministic identity.",
        minimum_fix_boundary:"Use the complete reviewer role as the prefix.",
        verification_expectation:"Validate the corrected finding ID."
      }]
      elif $mutation == "blocking-medium-severity" and
        $reviewer == "architecture-reviewer"
      then .findings[0].severity = "medium"
      elif $mutation == "blocking-pre-existing-origin" and
        $reviewer == "architecture-reviewer"
      then .findings[0].origin = "pre_existing"
      elif $mutation == "blocking-terminal-escape" and
        $reviewer == "architecture-reviewer"
      then .findings[0].id = "architecture-reviewer-F001\u001b[31m"
        | .findings[0].severity = "medium"
      elif $mutation == "qa-rules-dir-missing" and $reviewer == "qa-tester"
      then .findings[0].affected_behavior =
        "QA_RULES_DIR (qa-testing-rules/AGENT.md) could not be read; Tier 1 rules unavailable."
        | .test_gaps[0].affected_behavior = .findings[0].affected_behavior
      elif $mutation == "missing-test-gap" then del(.test_gaps)
      elif $mutation == "malformed-test-gap"
      then .test_gaps[0].coverage_dimensions = []
      elif $mutation == "wrong-subject"
      then .scope_manifest_sha256 = ("b" * 64)
      elif $mutation == "test-gap"
      then .test_gaps[0] = {
        id:($reviewer + "-TG001"),
        reviewer:$reviewer,
        status:"gap",
        affected_behavior:"The retry behavior lacks a negative-path regression.",
        contract:"A failed first attempt is retried once and then fails closed.",
        existing_evidence:[{path:$evidence_path,line:1,symbol:null}],
        coverage_dimensions:["negative","regression"],
        missing_layer:"integration",
        scenario:"The first protocol artifact is malformed and the corrective attempt is valid.",
        oracle:"Only the failed reviewer is retried and synthesis receives the corrected row.",
        failure_signal:"The gate aborts early or retries an already-valid reviewer.",
        suggested_command:"bash tests/bin/run-tests.sh --path tests/shell/test-pr-gate.sh"
      }
      else .
      end
  ' | {
    printf '```reviewer_result_v1\n'
    cat
    printf '\n```\n'
  } >> "$output_path"
}

pr_gate_fixture_write_synthesis_protocol() {
  local brief_file="$1" output_path="$2"
  local document_source reviewer_documents synthesis_document
  reviewer_documents="$(mktemp "${TMPDIR:-/tmp}/gate-fixture-reviewers.XXXXXX")"
  synthesis_document="$(mktemp "${TMPDIR:-/tmp}/gate-fixture-synthesis.XXXXXX")"
  document_source="$output_path"
  if ! grep -q '^```reviewer_result_v1$' "$document_source"; then
    document_source="$brief_file"
  fi
  awk '
    $0 == "```reviewer_result_v1" { inside=1; next }
    inside && $0 == "```" { inside=0; print ""; next }
    inside { print }
  ' "$document_source" > "$reviewer_documents"
  jq -s '
    def rcg($number):
      "RCG-" +
      (if $number < 10 then "00"
       elif $number < 100 then "0"
       else ""
       end) + ($number | tostring);
    . as $reviewers |
    [$reviewers[].reviewer] as $selected |
    (["critic","qa-tester","architecture-reviewer",
      "security-reviewer","risk-reviewer"] - $selected) as $skipped |
    ([$reviewers[] as $reviewer |
      $reviewer.coverage[] |
      {
        reviewer:$reviewer.reviewer,
        surface,
        status,
        evidence_refs,
        reason
      }
    ]) as $coverage |
    ([$reviewers[].findings[]] | sort_by(.id)) as $findings |
    ([$reviewers[].test_gaps[]] | sort_by(.id)) as $test_gaps |
    ($findings | to_entries | map(
      .value + {
        root_cause_group_id:rcg(.key + 1),
        disposition:"pending"
      }
    )) as $union |
    {
      kind:"gate_synthesis_result_v1",
      schema_version:1,
      scope_manifest_sha256:$reviewers[0].scope_manifest_sha256,
      selected_reviewers:$selected,
      not_reviewed_dimensions:$skipped,
      coverage_matrix:$coverage,
      reviewer_finding_inventory:($findings | map({
        id,
        reviewer,
        severity,
        hard_gate_class,
        origin,
        verification_expectation
      })),
      findings_union:$union,
      root_cause_groups:($union | to_entries | map({
        id:.value.root_cause_group_id,
        summary:("Fixture root cause for " + .value.id),
        finding_ids:[.value.id]
      })),
      disagreements:[],
      uncertainties:{
        finding_ids:($findings |
          map(select(.origin == "uncertain") | .id)),
        coverage_cells:([$reviewers[] as $reviewer |
          $reviewer.coverage[] |
          select(.status == "uncertain") |
          {
            reviewer:$reviewer.reviewer,
            surface,
            reason
          }
        ])
      },
      cautions:($findings |
        map(select(.origin == "caution") | .id)),
      test_gap_matrix:$test_gaps,
      operational_cautions:[],
      user_cautions:[],
      verification_plan:{
        focused:($test_gaps |
          map(select(.status == "gap") | .suggested_command) | unique | sort),
        manual:[],
        full:["bash tests/bin/run-tests.sh"]
      },
      remediation_seed:{
        kind:"remediation_closure_v1",
        schema_version:1,
        state:"seed",
        scope_manifest_sha256:$reviewers[0].scope_manifest_sha256,
        entries:($union | map({
          finding_id:.id,
          reviewer,
          root_cause_group_id,
          disposition,
          verification_expectation
        }))
      }
    }
  ' "$reviewer_documents" > "$synthesis_document"
  if [[ -n "${CODEX_GATE_STUB_SYNTHESIS_PROTOCOL_MUTATION:-}" ]]; then
    local apply_mutation=true mutated_document
    if [[ -n "${CODEX_GATE_STUB_SYNTHESIS_PROTOCOL_MUTATION_ONLY_FIRST:-}" ]] \
        && grep -q '^correction_retry:' "$brief_file"; then
      apply_mutation=false
    fi
    if [[ "$apply_mutation" == true ]]; then
      mutated_document="$(mktemp "${TMPDIR:-/tmp}/gate-fixture-synthesis-mutated.XXXXXX")"
      case "$CODEX_GATE_STUB_SYNTHESIS_PROTOCOL_MUTATION" in
        drop-test-gap-row)
          jq '.test_gap_matrix = .test_gap_matrix[1:]' \
            "$synthesis_document" > "$mutated_document"
          mv -- "$mutated_document" "$synthesis_document"
          ;;
        malformed-json)
          printf '{"kind":\n' > "$synthesis_document"
          rm -f -- "$mutated_document"
          ;;
      esac
    fi
  fi
  {
    printf '\n```synthesis_result_v1\n'
    cat "$synthesis_document"
    printf '```\n\n'
    printf '## Must-Fix Order\nnone\n\n'
    printf '## Advisory and Cautions\nnone\n\n'
    printf '## Coverage Gaps and Uncertainties\nnone\n\n'
    printf '## Test Coverage to Add or Strengthen\nnone\n\n'
    printf '## Operational and User Cautions\nnone\n\n'
    printf '## Post-Fix Verification Plan\nfocused/manual/full\n\n'
    printf '## Recommended Verification\nnone\n'
  } >> "$output_path"
  rm -f -- "$reviewer_documents" "$synthesis_document"
}

pr_gate_fixture_profile_dispatch() {
  local executor="$1"
  shift
  local brief_file="" mode marker output_path reviewer_name selected_csv selected_reviewer
  case "$executor" in
    codex)
      mode="${CODEX_GATE_STUB_MODE:-success}"
      marker="${CODEX_GATE_STUB_CALLED_MARKER:-}"
      ;;
    claude)
      mode="${CLAUDE_GATE_STUB_MODE:-success}"
      marker="${CLAUDE_GATE_STUB_CALLED_MARKER:-}"
      ;;
    *)
      printf 'unknown profile fixture executor: %s\n' "$executor" >&2
      return 2
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --brief-file) brief_file="$2"; shift 2 ;;
      --cd | --timeout | --model | --isolation) shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -n "$marker" ]] && printf 'called\n' > "$marker"
  printf 'DISPATCH_STUB:%s\n' "$mode"
  [[ "$mode" != exit99 ]] || return 99
  [[ -n "$brief_file" ]] || return 0

  output_path=""
  if [[ -f "$brief_file" ]]; then
    output_path="$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}' || true)"
  fi
  [[ -n "$output_path" ]] || return 0
  mkdir -p "$(dirname "$output_path")"

  if [[ "$brief_file" == *-synthesis.md ]]; then
    printf -- '---\ngate_result_version: pr_gate_result_v1\nfinal: GO\ntier: standard\nmode: parallel\nmost_severe: advise\nreviewers:\n  critic: advise\nescalation:\n  recommended: false\n  reviewers: []\n  reason: []\n---\n\n# PR-Gate Result — stub tier\n**Date**: 2026-05-17\n**Reviewers**: stub\n**Not reviewed**: none\n\n## cross-check\nnone\n\n## Gate Conclusion\n**Overall verdict**: advise\n**Most severe individual verdict**: advise\nFinal: GO\n' > "$output_path"
    pr_gate_fixture_write_synthesis_protocol "$brief_file" "$output_path"
    return 0
  fi

  reviewer_name="$(awk '$1 == "Reviewer:" { print $2; exit }' "$brief_file")"
  if [[ -n "$reviewer_name" ]]; then
    printf '## %s -- advise\n\nstatus: advise\nfindings: []\nverdict: Stub output.\n' \
      "$reviewer_name" > "$output_path"
    pr_gate_fixture_write_reviewer_protocol \
      "$brief_file" "$output_path" "$reviewer_name" advise
    return 0
  fi

  printf -- '---\ngate_result_version: pr_gate_result_v1\nfinal: GO\ntier: standard\nmode: sequential\nmost_severe: advise\nreviewers:\n  critic: advise\nescalation:\n  recommended: false\n  reviewers: []\n  reason: []\n---\n\n## stub-reviewer — advise\nVerdict: advise. Stub output.\n' > "$output_path"
  selected_csv="$(awk '$1 == "coverage.selected:" { print $2; exit }' "$brief_file")"
  : "${selected_csv:=critic}"
  for selected_reviewer in ${selected_csv//,/ }; do
    printf '\n## %s -- advise\n' "$selected_reviewer" >> "$output_path"
    pr_gate_fixture_write_reviewer_protocol \
      "$brief_file" "$output_path" "$selected_reviewer" advise
  done
  pr_gate_fixture_write_synthesis_protocol "$brief_file" "$output_path"
  printf 'Final: GO\n' >> "$output_path"
}
