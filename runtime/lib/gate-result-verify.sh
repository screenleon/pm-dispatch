#!/usr/bin/env bash
# Shared gate-result integrity and assurance verification.
#
# pr_gate_result_v1 remains valid legacy structural evidence.  It proves only
# frontmatter/body verdict parity and is reported as assurance=unavailable.
# pr_gate_result_v2 additionally points at a sibling gate_assurance_v1 JSON
# envelope owned by the gate shell; the verifier checks its structural and
# claim consistency.

# gate_result_verdict_verify <result_file> [expected_final] [route_label]
gate_result_verdict_verify() {
  local result_file=${1-} expected_final=${2-} route_label=${3-gate}
  local final_count frontmatter_final body_final

  [[ $# -ge 1 && $# -le 3 ]] || {
    printf 'gate-result-verify: gate_result_verdict_verify expects <result_file> [expected_final] [route_label]\n' >&2
    return 2
  }
  if [[ ! -s "$result_file" ]]; then
    printf 'Error: %s did not produce the result file: %s\n' "$route_label" "$result_file" >&2
    printf 'Gate aborted -- the executor session may have exited 0 without writing a verdict.\n' >&2
    return 1
  fi
  final_count=$(grep -cE '^Final: (GO|NO-GO)$' "$result_file" || true)
  if [[ "$final_count" -ne 1 ]]; then
    printf 'Error: gate result file must contain exactly one Final: GO/NO-GO line (found %d): %s\n' \
      "$final_count" "$result_file" >&2
    return 1
  fi
  frontmatter_final=$(awk 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } } s && $1 == "final:" { print $2; exit }' "$result_file")
  if [[ -z "$frontmatter_final" ]]; then
    printf 'Error: gate result YAML frontmatter missing required field: final: (%s)\n' "$result_file" >&2
    return 1
  fi
  body_final=$(grep -E '^Final: (GO|NO-GO)$' "$result_file" | awk '{print $2}')
  if [[ "$frontmatter_final" != "$body_final" ]]; then
    printf 'Error: frontmatter final: (%s) does not match body Final: (%s) in gate result: %s\n' \
      "$frontmatter_final" "$body_final" "$result_file" >&2
    return 1
  fi
  if [[ -n "$expected_final" && "$body_final" != "$expected_final" ]]; then
    printf 'Error: %s verdict (%s) contradicts shell-computed verdict (%s) -- gate result may have been manipulated: %s\n' \
      "$route_label" "$body_final" "$expected_final" "$result_file" >&2
    return 1
  fi
}

_gate_result_frontmatter_value() {
  local result_file="$1" key="$2"
  awk -v wanted="$key" '
    BEGIN{s=0}
    /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } }
    s && $1 == wanted ":" { print $2; exit }
  ' "$result_file"
}

# gate_assurance_verify <result_file> <assurance_file> <body_final>
gate_assurance_verify() {
  local result_file="$1" assurance_file="$2" body_final="$3"
  local markdown_tier markdown_mode
  command -v jq >/dev/null 2>&1 || {
    printf 'Error: gate assurance verification requires jq\n' >&2
    return 2
  }
  if [[ ! -s "$assurance_file" ]]; then
    printf 'Error: gate assurance sidecar missing or empty: %s\n' "$assurance_file" >&2
    return 1
  fi
  markdown_tier="$(_gate_result_frontmatter_value "$result_file" tier)"
  markdown_mode="$(_gate_result_frontmatter_value "$result_file" mode)"
  jq -e --arg final "$body_final" --arg markdown_tier "$markdown_tier" \
    --arg markdown_mode "$markdown_mode" '
    def strings_unique:
      type == "array" and all(.[]; type == "string" and length > 0) and
      (length == (unique | length));
    def same_set($a; $b): ($a | sort) == ($b | sort);
    .kind == "gate_assurance_v1" and .schema_version == 1 and
    .result.final == $final and
    .coordinates.tier.resolved == $markdown_tier and
    .coordinates.mode.resolved == $markdown_mode and
    .provenance.producer == "pr-gate.sh" and
    (.provenance.policy_source |
      IN("canonical","generated-snapshot","mixed")) and
    (.coordinates.tier.evidence_floor | type == "string" and length > 0) and
    (.coordinates.tier.requested == "auto" or
      (.coordinates.tier.requested == .coordinates.tier.resolved and
       (.coordinates.tier.requested | IN("express","standard","full")))) and
    (.coordinates.tier.resolved | IN("express","standard","full")) and
    (.coordinates.mode.requested | IN("default","sequential","parallel")) and
    (.coordinates.mode.resolved | IN("sequential","parallel")) and
    (.coordinates.mode.requested == "default" or
      .coordinates.mode.requested == .coordinates.mode.resolved) and
    ((.coordinates.mode.resolved == "sequential" and
       .coordinates.mode.topology == "combined-session" and
       .coordinates.mode.synthesis == "inline") or
     (.coordinates.mode.resolved == "parallel" and
       .coordinates.mode.topology == "per-reviewer-sessions" and
       .coordinates.mode.synthesis == "separate-session")) and
    (.coordinates.pass.requested | IN("initial","targeted")) and
    (.coordinates.pass.resolved | IN("initial","targeted")) and
    .coordinates.pass.requested == .coordinates.pass.resolved and
    ((.coordinates.pass.resolved == "initial" and
       .coordinates.pass.scope == "comprehensive" and
       .coordinates.pass.initial_result == null) or
     (.coordinates.pass.resolved == "targeted" and
       .coordinates.pass.scope == "remediation-delta" and
       (.coordinates.pass.initial_result | type == "string" and length > 0))) and
    (.coordinates.coverage.vocabulary | strings_unique) and
    (.coordinates.coverage.selected | strings_unique) and
    (.coordinates.coverage.skipped | strings_unique) and
    ((.coordinates.coverage.selected + .coordinates.coverage.skipped) | strings_unique) and
    same_set(.coordinates.coverage.selected + .coordinates.coverage.skipped;
      .coordinates.coverage.vocabulary) and
    (.coordinates.coverage.requested == null or
      ((.coordinates.coverage.requested | strings_unique) and
       same_set(.coordinates.coverage.requested;
         .coordinates.coverage.selected))) and
    (.dispatch.outcomes | type == "array") and
    (all(.dispatch.outcomes[];
      (.role | IN("combined","reviewer","synthesis","preflight")) and
      (if .role == "reviewer"
       then (.reviewer | type == "string" and length > 0)
       else .reviewer == null
       end) and
      (.status | IN("passed","failed","skipped")) and
      (.evidence_status | IN("verified","unavailable","unverified")) and
      (.run_id == null or
        (.run_id | type == "string" and test("^run-[A-Za-z0-9]+-[A-Za-z0-9]+$"))))) and
    (if .coordinates.mode.resolved == "parallel" and
        ([.dispatch.outcomes[] | select(.role == "preflight")] | length) == 0
     then
       ([.dispatch.outcomes[] | select(.role == "reviewer") | .reviewer] | sort) ==
         (.coordinates.coverage.selected | sort) and
       ([.dispatch.outcomes[] | select(.role == "synthesis")] | length) == 1
     elif .coordinates.mode.resolved == "sequential" and
          ([.dispatch.outcomes[] | select(.role == "preflight")] | length) == 0
     then
       ([.dispatch.outcomes[] | select(.role == "combined")] | length) == 1
     else
       ([.dispatch.outcomes[] | select(.role == "preflight" and .status == "failed")] | length) == 1
     end) and
    (.coordinates.independence.evidence_status |
      IN("verified","unavailable","unverified")) and
    .coordinates.independence.reviewer_topology ==
      .coordinates.mode.topology and
    (if .coordinates.independence.evidence_status == "verified"
     then
       .coordinates.independence.implementation_context_isolated == true and
       (all(.dispatch.outcomes[]; .evidence_status == "verified" and .run_id != null)) and
       ([.dispatch.outcomes[].run_id] | length == (unique | length)) and
       (if .coordinates.mode.resolved == "parallel"
        then .coordinates.independence.per_reviewer_independent == true
        else .coordinates.independence.per_reviewer_independent == false
        end)
     else
       .coordinates.independence.implementation_context_isolated != true and
       .coordinates.independence.per_reviewer_independent != true and
       (all(.dispatch.outcomes[]; .evidence_status != "verified"))
     end)
  ' "$assurance_file" >/dev/null || {
    printf 'Error: gate assurance sidecar failed structural/claim verification: %s\n' \
      "$assurance_file" >&2
    return 1
  }
}

# gate_result_verify <result_file> [expected_final] [route_label]
gate_result_verify() {
  local result_file=${1-} expected_final=${2-} route_label=${3-gate}
  local version pointer result_parent assurance_file body_final
  [[ $# -ge 1 && $# -le 3 ]] || {
    printf 'gate-result-verify: gate_result_verify expects <result_file> [expected_final] [route_label]\n' >&2
    return 2
  }
  gate_result_verdict_verify "$result_file" "$expected_final" "$route_label" || return $?
  version="$(_gate_result_frontmatter_value "$result_file" gate_result_version)"
  case "$version" in
    pr_gate_result_v1)
      GATE_RESULT_ASSURANCE=unavailable
      unset GATE_RESULT_ASSURANCE_FILE
      export GATE_RESULT_ASSURANCE
      return 0
      ;;
    pr_gate_result_v2)
      pointer="$(_gate_result_frontmatter_value "$result_file" gate_assurance)"
      if [[ -z "$pointer" || "$pointer" == */* || "$pointer" == "." || "$pointer" == ".." \
          || ! "$pointer" =~ ^[A-Za-z0-9._-]+\.json$ ]]; then
        printf 'Error: pr_gate_result_v2 requires a bounded sibling gate_assurance pointer: %s\n' \
          "$result_file" >&2
        return 1
      fi
      result_parent="$(cd "$(dirname "$result_file")" && pwd -P)" || return 1
      assurance_file="$result_parent/$pointer"
      body_final=$(grep -E '^Final: (GO|NO-GO)$' "$result_file" | awk '{print $2}')
      gate_assurance_verify "$result_file" "$assurance_file" "$body_final" || return $?
      GATE_RESULT_ASSURANCE=verified
      GATE_RESULT_ASSURANCE_FILE="$assurance_file"
      export GATE_RESULT_ASSURANCE GATE_RESULT_ASSURANCE_FILE
      ;;
    *)
      printf 'Error: unsupported or missing gate_result_version in gate result: %s\n' \
        "$result_file" >&2
      return 1
      ;;
  esac
}

export -f gate_result_verdict_verify gate_assurance_verify gate_result_verify
