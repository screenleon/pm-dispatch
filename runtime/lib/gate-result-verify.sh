#!/usr/bin/env bash
# Shared gate-result integrity and assurance verification.
#
# pr_gate_result_v1 remains valid legacy structural evidence.  It proves only
# frontmatter/body verdict parity and is reported as assurance=unavailable.
# pr_gate_result_v2 points at a sibling assurance JSON envelope owned by the
# gate shell. Legacy gate_assurance_v1 remains readable but non-authorizing;
# gate_assurance_v2 adds subject/result bindings and protected attestation.

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

# The core JSON Schema owns portable envelope shape. This runtime predicate owns
# cross-artifact and semantic claim consistency that JSON Schema cannot establish
# from the Markdown result. The standalone fallback is an exact generated-style
# copy guarded by test_inline_fallback_matches_lib.
#
# gate_assurance_verify <result_file> <assurance_file> <body_final>
gate_assurance_verify() {
  local result_file="$1" assurance_file="$2" body_final="$3"
  local markdown_tier markdown_mode result_sha assurance_kind
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
  assurance_kind="$(jq -r '.kind // empty' "$assurance_file" 2>/dev/null)"
  if [[ "$assurance_kind" == gate_assurance_v1 ]]; then
    jq -e --arg final "$body_final" --arg markdown_tier "$markdown_tier" \
      --arg markdown_mode "$markdown_mode" '
        .kind == "gate_assurance_v1" and .schema_version == 1 and
        .result.final == $final and
        .coordinates.tier.resolved == $markdown_tier and
        .coordinates.mode.resolved == $markdown_mode
      ' "$assurance_file" >/dev/null || {
      printf 'Error: legacy gate assurance sidecar failed claim verification: %s\n' \
        "$assurance_file" >&2
      return 1
    }
    GATE_ASSURANCE_BOUND=false
    export GATE_ASSURANCE_BOUND
    return 0
  fi
  result_sha="$(_gate_result_sha256_file "$result_file")" || return $?
  jq -e --arg final "$body_final" --arg result_sha "$result_sha" \
    --arg markdown_tier "$markdown_tier" \
    --arg markdown_mode "$markdown_mode" '
    def only_keys($allowed):
      type == "object" and ((keys_unsorted - $allowed) | length) == 0;
    def strings_unique:
      type == "array" and all(.[]; type == "string" and length > 0) and
      (length == (unique | length));
    def same_set($a; $b): ($a | sort) == ($b | sort);
    only_keys(["kind","schema_version","result","bindings","coordinates",
      "policy","dispatch","provenance"]) and
    (.result | only_keys(["final"])) and
    (.bindings | only_keys(["result_sha256","repo_root","repo_identity",
      "base_commit","head_commit","subject_fingerprint"])) and
    (.coordinates | only_keys(["tier","mode","pass","coverage","independence"])) and
    (.coordinates.tier | only_keys(["requested","resolved","evidence_floor"])) and
    (.coordinates.mode | only_keys(["requested","resolved","topology","synthesis"])) and
    (.coordinates.pass | only_keys(["requested","resolved","scope","initial_result"])) and
    (.coordinates.coverage |
      only_keys(["requested","selected","skipped","vocabulary"])) and
    (.coordinates.independence |
      only_keys(["implementation_context_isolated","reviewer_topology",
        "per_reviewer_independent","evidence_status"])) and
    (if has("policy") then
      (.policy |
        only_keys(["kind","schema_version","consumer_policy","policy_source",
          "scope_fingerprint","request","classification","resolution",
          "matched_signals","resolved","enforcement","override",
          "reviewer_override"])) and
      (.policy.request |
        only_keys(["tier","mode","pass_kind","reviewers"])) and
      (.policy.classification |
        only_keys(["architecture_impact","line_changes",
          "binary_or_unknown_count","layer_roots"])) and
      (.policy.resolution |
        only_keys(["minimum_tier","required_reviewers","recommended_mode",
          "mode_selection_source","mode_recommendation_overridden",
          "downgrade_requested","downgrade_allowed"])) and
      (.policy.resolved | only_keys(["tier","mode","reviewers"])) and
      (.policy.enforcement | only_keys(["status","violations"])) and
      (.policy.override |
        only_keys(["status","source","sha256","reason","approver"])) and
      (.policy.reviewer_override |
        only_keys(["status","source","sha256"])) and
      .policy.kind == "gate_policy_resolution_v1" and
      .policy.schema_version == 1 and
      (.policy.consumer_policy | IN("generic","maintainer")) and
      .policy.policy_source == .provenance.policy_source and
      (.policy.scope_fingerprint | test("^[a-f0-9]{64}$")) and
      .policy.request.tier == .coordinates.tier.requested and
      .policy.request.mode == .coordinates.mode.requested and
      .policy.request.pass_kind == .coordinates.pass.resolved and
      ((.policy.request.reviewers == null and
        .coordinates.coverage.requested == null) or
       (same_set(.policy.request.reviewers;
         .coordinates.coverage.requested))) and
      (.policy.classification.architecture_impact |
        IN("unknown","none","minor","major")) and
      (.policy.classification.line_changes |
        type == "number" and . >= 0 and floor == .) and
      (.policy.classification.binary_or_unknown_count |
        type == "number" and . >= 0 and floor == .) and
      (.policy.classification.layer_roots | strings_unique) and
      (.policy.resolution.minimum_tier |
        IN("express","standard","full")) and
      (.policy.resolution.required_reviewers | strings_unique) and
      (.policy as $policy |
        all($policy.resolution.required_reviewers[];
          . as $reviewer |
          ($policy.resolved.reviewers | index($reviewer)) != null or
          $policy.resolution.downgrade_allowed)) and
      (.policy.resolution.recommended_mode |
        IN("sequential","parallel")) and
      (.policy.resolution.mode_selection_source | IN("user","policy")) and
      (.policy.resolution.mode_recommendation_overridden | type == "boolean") and
      (if .policy.request.mode == "default"
       then
         .policy.resolution.mode_selection_source == "policy" and
         .policy.resolved.mode == .policy.resolution.recommended_mode and
         .policy.resolution.mode_recommendation_overridden == false
       else
         .policy.resolution.mode_selection_source == "user" and
         .policy.resolved.mode == .policy.request.mode and
         .policy.resolution.mode_recommendation_overridden ==
           (.policy.request.mode != .policy.resolution.recommended_mode)
       end) and
      (.policy.resolution.downgrade_requested | type == "boolean") and
      (.policy.resolution.downgrade_allowed | type == "boolean") and
      (.policy.matched_signals | type == "array" and length > 0) and
      ([.policy.matched_signals[].id] | strings_unique) and
      (all(.policy.matched_signals[];
        only_keys(["id","source","matches","minimum_tier",
          "required_reviewers","recommended_mode"]) and
        (.id | type == "string" and length > 0) and
        (.source |
          IN("consumer-policy","classification","path-regex","brief-value")) and
        (.matches | strings_unique and length > 0) and
        (.minimum_tier | IN("express","standard","full")) and
        (.required_reviewers | strings_unique) and
        (.recommended_mode | IN("sequential","parallel")))) and
      .policy.resolved.tier == .coordinates.tier.resolved and
      .policy.resolved.mode == .coordinates.mode.resolved and
      same_set(.policy.resolved.reviewers;
        .coordinates.coverage.selected) and
      .policy.enforcement.status == "pass" and
      (.policy.enforcement.violations | type == "array") and
      (all(.policy.enforcement.violations[];
        only_keys(["coordinate","requested","required"]) and
        (.coordinate | IN("tier","coverage")))) and
      (.policy.override.status |
        IN("not_provided","not_needed","applied","scope_mismatch",
          "allowance_mismatch")) and
      (if .policy.resolution.downgrade_requested
       then
         .policy.resolution.downgrade_allowed == true and
         .policy.override.status == "applied" and
         (.policy.override.source |
           type == "string" and startswith("/")) and
         (.policy.override.sha256 | test("^[a-f0-9]{64}$")) and
         (.policy.override.reason | type == "string" and length > 0) and
         (.policy.override.approver |
           only_keys(["kind","identity","approval_ref"])) and
         .policy.override.approver.kind == "user" and
         (.policy.override.approver.identity |
           type == "string" and length > 0) and
         (.policy.override.approver.approval_ref |
           type == "string" and length > 0)
       else
         .policy.resolution.downgrade_allowed == false and
         (.policy.override.status |
           IN("not_provided","not_needed"))
       end) and
      (.policy.reviewer_override.status |
        IN("not_provided","provided")) and
      (if .policy.reviewer_override.status == "provided"
       then
         (.policy.reviewer_override.source |
           type == "string" and startswith("/")) and
         (.policy.reviewer_override.sha256 | test("^[a-f0-9]{64}$"))
       else
         .policy.reviewer_override.source == null and
         .policy.reviewer_override.sha256 == null
       end)
    else true end) and
    (.dispatch | only_keys(["outcomes"])) and
    (all(.dispatch.outcomes[];
      only_keys(["role","reviewer","status","run_id","evidence_status"]))) and
    (.provenance | only_keys(["producer","policy_source","attestation"])) and
    .kind == "gate_assurance_v2" and .schema_version == 2 and
    .result.final == $final and
    .bindings.result_sha256 == $result_sha and
    (.bindings.repo_root | type == "string" and startswith("/")) and
    (.bindings.repo_identity | test("^[a-f0-9]{64}$")) and
    (.bindings.base_commit | test("^[a-f0-9]{40}$")) and
    (.bindings.head_commit | test("^[a-f0-9]{40}$")) and
    (.bindings.subject_fingerprint | test("^[a-f0-9]{64}$")) and
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
       (.dispatch.outcomes | length) ==
         ((.coordinates.coverage.selected | length) + 1) and
       (all(.dispatch.outcomes[];
         (.role == "reviewer" or .role == "synthesis"))) and
       ([.dispatch.outcomes[] | select(.role == "reviewer") | .reviewer] | sort) ==
         (.coordinates.coverage.selected | sort) and
       ([.dispatch.outcomes[] | select(.role == "synthesis")] | length) == 1
     elif .coordinates.mode.resolved == "sequential" and
          ([.dispatch.outcomes[] | select(.role == "preflight")] | length) == 0
     then
       (.dispatch.outcomes | length) == 1 and
       .dispatch.outcomes[0].role == "combined"
     else
       (.dispatch.outcomes | length) == 1 and
       .dispatch.outcomes[0].role == "preflight" and
       .dispatch.outcomes[0].status == "failed"
     end) and
    (.coordinates.independence.evidence_status |
      IN("verified","unavailable","unverified")) and
    (if .coordinates.independence.evidence_status == "verified"
     then (.provenance.attestation |
       type == "string" and
       test("^gate-assurance-[0-9]{8}-[0-9]{6}\\.attestation\\.json$"))
     else .provenance.attestation == null
     end) and
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
  GATE_ASSURANCE_BOUND=true
  export GATE_ASSURANCE_BOUND
}

_gate_result_sha256_file() {
  local file="$1" digest=""
  if command -v sha256sum >/dev/null 2>&1 \
      && digest="$(sha256sum -- "$file" 2>/dev/null | awk '{print $1}')" \
      && [[ -n "$digest" ]]; then
    printf '%s\n' "$digest"
    return 0
  fi
  if command -v shasum >/dev/null 2>&1 \
      && digest="$(shasum -a 256 -- "$file" 2>/dev/null | awk '{print $1}')" \
      && [[ -n "$digest" ]]; then
    printf '%s\n' "$digest"
    return 0
  fi
  printf 'Error: no sha256sum or shasum found -- cannot verify gate assurance binding\n' >&2
  return 2
}

# gate_assurance_authorization_verify <result> <assurance> <attestation> <runs.jsonl>
# Validates the protected producer attestation and resolves every claimed run ID
# to the latest canonical terminal record for the same gate run and repository.
gate_assurance_authorization_verify() {
  local result_file="$1" assurance_file="$2" attestation_file="$3" runs_file="$4"
  local result_sha assurance_sha run_root
  [[ -s "$attestation_file" && -s "$runs_file" ]] || {
    printf 'Error: verified gate assurance requires protected attestation and canonical run records\n' >&2
    return 1
  }
  result_sha="$(_gate_result_sha256_file "$result_file")" || return $?
  assurance_sha="$(_gate_result_sha256_file "$assurance_file")" || return $?
  run_root="$(cd "$(dirname "$attestation_file")" && pwd -P)" || return 1
  jq -e --arg result_sha "$result_sha" --arg assurance_sha "$assurance_sha" \
    --slurpfile assurance "$assurance_file" '
      $assurance[0] as $a |
      .kind == "gate_assurance_attestation_v1" and .schema_version == 1 and
      .result_sha256 == $result_sha and .assurance_sha256 == $assurance_sha and
      .repo_root == $a.bindings.repo_root and
      .repo_identity == $a.bindings.repo_identity and
      .base_commit == $a.bindings.base_commit and
      .head_commit == $a.bindings.head_commit and
      .subject_fingerprint == $a.bindings.subject_fingerprint and
      ([.run_ids[]] | sort) ==
        ([$a.dispatch.outcomes[].run_id] | sort)
    ' "$attestation_file" >/dev/null || {
    printf 'Error: gate assurance protected attestation mismatch: %s\n' \
      "$attestation_file" >&2
    return 1
  }
  jq -s -e --slurpfile assurance "$assurance_file" \
    --arg run_root "$run_root" '
      $assurance[0] as $a |
      . as $records |
      all($a.dispatch.outcomes[].run_id;
        . as $id |
        ([$records[] | select(.id == $id)] | last) as $record |
        $record != null and $record.state == "ok" and $record.exit_code == 0 and
        $record.working_dir == $a.bindings.repo_root and
        ($record.trace_path | type == "string" and
          startswith($run_root + "/.agent-trace/")))
    ' "$runs_file" >/dev/null || {
    printf 'Error: gate assurance dispatch evidence does not match canonical run records\n' >&2
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
      if [[ "${GATE_ASSURANCE_BOUND:-false}" == true ]]; then
        GATE_RESULT_ASSURANCE=verified
      else
        GATE_RESULT_ASSURANCE=unavailable
      fi
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

# These functions are a sourced-library API, not a `bash -c` API. Exporting
# only the public entry points leaks an incomplete closure into descendants:
# gate_result_verify also needs private helpers such as
# _gate_result_frontmatter_value. A nested pmctl could then mistake the
# inherited entry point for a fully loaded verifier and reject valid results.
