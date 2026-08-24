#!/usr/bin/env bash
# Shared gate_reviewer_result_v1 JSON fixture builder, used by both
# test-core-schemas.sh (schema-shape validation) and
# test-gate-structural-verify.sh (gate_structural_schema_verify/
# gate_structural_schema_first_error behavior against this schema). One
# canonical "what does a valid reviewer result look like" definition, per the
# same reuse lesson as CC-533's other shared *-fixtures.sh files: two
# independently hand-rolled copies silently drift out of sync with
# core/schema/gate-reviewer-result.schema.json without anyone noticing.

_gate_reviewer_result_valid_instance() {
  jq -n '
    ["changed_files","paired_tests","sensitive_signals","public_interface",
      "schema","config","install","ci","release","migration",
      "bounded_expansion"] as $surfaces |
    {
      kind:"gate_reviewer_result_v1",
      schema_version:1,
      reviewer:"critic",
      scope_manifest_sha256:("a" * 64),
      coverage_claim:"declared-scope-checklist-not-review-completeness",
      coverage:($surfaces | map({
        surface:.,
        status:"examined",
        evidence_refs:[{path:"runtime/bin/example.sh",line:42,symbol:null}],
        reason:"The reviewer examined this declared surface."
      })),
      findings:[{
        id:"critic-F001",
        reviewer:"critic",
        severity:"high",
        hard_gate_class:"soft_block",
        origin:"diff_caused",
        source:{path:"runtime/bin/example.sh",line:42,symbol:null},
        affected_behavior:"The changed command can emit an incomplete result.",
        why_it_matters:"Consumers could accept evidence that was not reviewed.",
        failure_mode:"The incomplete artifact reaches a publish decision.",
        minimum_fix_boundary:"Reject the malformed reviewer result before synthesis.",
        verification_expectation:"Run the malformed-protocol fixture."
      }],
      test_gaps:[{
        id:"critic-TG001",
        reviewer:"critic",
        status:"gap",
        affected_behavior:"Malformed reviewer output lacks negative-path coverage.",
        contract:"Malformed output fails closed and is retried once.",
        existing_evidence:[{path:"runtime/bin/example.sh",line:42,symbol:null}],
        coverage_dimensions:["negative","regression"],
        missing_layer:"integration",
        scenario:"The first reviewer result is malformed and the second is valid.",
        oracle:"Only the failed reviewer is retried.",
        failure_signal:"A valid reviewer is dispatched again.",
        suggested_command:"bash tests/bin/run-tests.sh --path tests/shell/test-pr-gate.sh"
      }],
      verdict:"block-soft",
      rationale:"Every declared surface was completed after recording the blocker."
    }
  '
}
