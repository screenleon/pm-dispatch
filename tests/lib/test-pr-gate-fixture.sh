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
      else .
      end
  ' | {
    printf '```reviewer_result_v1\n'
    cat
    printf '\n```\n'
  } >> "$output_path"
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
  printf 'Final: GO\n' >> "$output_path"
}
