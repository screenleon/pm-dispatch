#!/usr/bin/env bash
# Read-side verification for remediation_closure_v1.
# This module deliberately contains no closure publication or destination writes.

if ! declare -F gate_structural_schema_verify >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-structural-verify.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-structural-verify.sh"
fi

# gate_remediation_closure_verify <artifact> <subject-fingerprint> <scope-sha>
gate_remediation_closure_verify() {
  local artifact="${1:-}" expected_subject="${2:-}" expected_scope="${3:-}"
  [[ $# -eq 3 && -s "$artifact" ]] || {
    printf 'gate-closure: expected <artifact> <subject-fingerprint> <scope-sha>\n' >&2
    return 2
  }
  [[ "$expected_subject" =~ ^[a-f0-9]{64}$ && "$expected_scope" =~ ^[a-f0-9]{64}$ ]] || {
    printf 'gate-closure: expected valid subject and scope fingerprints\n' >&2
    return 2
  }
  gate_structural_schema_verify gate-remediation-closure "$artifact" \
    'remediation closure' || return 1

  if ! jq -e \
      --arg expected_subject "$expected_subject" \
      --arg expected_scope "$expected_scope" '
    def strings_unique:
      type == "array" and all(.[]; type == "string" and length > 0) and
      length == (unique | length);
    def safe_paths:
      strings_unique and all(.[ ];
        (startswith("/") | not) and ((split("/") | index("..")) == null));
    def test_ids:
      [.affected_tests[].id];

    . as $root |
    ($root.findings | any(.[]; .classification == "targeted_confirmation")) as $has_targeted |
    .scope_manifest_sha256 == $expected_scope and
    .final_subject.tree_fingerprint == $expected_subject and
    .final_assessment.subject_fingerprint == $expected_subject and
    .primary.status == "verified" and
    .primary.subject.tree_fingerprint == .primary.gate_result.subject_fingerprint and
    (.findings | map(.finding_id) | unique | length) == (.findings | length) and
    (test_ids | unique | length) == (.affected_tests | length) and
    (.changed_files | safe_paths) and
    (all($root.findings[];
      . as $finding |
      ($finding.changed_paths | safe_paths) and
      all($finding.changed_paths[];
        . as $path | ($root.changed_files | index($path)) != null) and
      ($finding.evidence_refs | length > 0 and
        all(.[ ];
          ((.line | type == "number" and floor == . and . >= 1) or
           (.symbol | type == "string" and length > 0)))) and
      ($finding.affected_test_ids | length > 0) and
      all($finding.affected_test_ids[];
        . as $test_id | ($root.affected_tests | map(.id) | index($test_id)) != null) and
      (if $finding.origin == "diff_caused" then
        (($finding.disposition == "closed" and
          ($finding.classification | IN("local","targeted_confirmation")) and
          $finding.verification_status == "pass") or
         ($root.state == "split" and $finding.disposition == "split" and
          $finding.classification == "stop_split" and
          $finding.verification_status == "split"))
       elif $finding.origin == "pre_existing" then
       $finding.disposition == "tracked" and
       $finding.classification == "stop_split" and
       $finding.verification_status == "not_required" and
        ($finding.ticket_ref == null or ($finding.ticket_ref | type == "string"))
       elif $finding.origin == "uncertain" then
        $finding.disposition == "split" and
        $finding.classification == "stop_split" and
        $finding.verification_status == "split"
       else
        ($finding.disposition | IN("closed","tracked")) and
        ($finding.classification | IN("local","targeted_confirmation")) and
        ($finding.verification_status | IN("pass","not_required"))
       end))) and
    ([.findings[] | select(.disposition != "closed")] | length) ==
      .unresolved_counts.total and
    (.unresolved_counts.blocking + .unresolved_counts.advisory) ==
      .unresolved_counts.total and
    all(.affected_tests[]; .subject_fingerprint == $expected_subject) and
    (.state == .final_assessment.remediation_status) and
    ((.unresolved_counts.total == 0) == (.state == "closed")) and
    (if $has_targeted then .targeted_confirmation.status == "pass" else true end) and
    (.targeted_confirmation.delta_only == true) and
    (.targeted_confirmation.status != "incomplete") and
    (.targeted_confirmation.evidence == null or
      .targeted_confirmation.evidence.subject_fingerprint == $expected_subject) and
    (.state == "split" or
      (all(.affected_tests[]; .status == "pass") and
       .final_assessment.affected_tests_status == "pass")) and
    (.final_assessment.publish_authorized == false or
      (.state == "closed" and
       .unresolved_counts.total == 0 and
       .final_assessment.affected_tests_status == "pass" and
       .final_assessment.full_suite_status == "pass" and
       .targeted_confirmation.status != "incomplete"))
  ' "$artifact" >/dev/null 2>&1; then
    printf 'Error: remediation closure failed deterministic claim verification: %s\n' \
      "$artifact" >&2
    return 1
  fi
}
