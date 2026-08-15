#!/usr/bin/env bash
# Shared verification for the final, publication-authorizing assessment.
#
# Gate verification answers whether a Gate artifact is valid/current/applicable.
# This module answers the narrower publish question: whether that verified Gate,
# its remediation closure, and the authoritative full suite all describe the
# same final tree and authorize publication. Ship's human and machine outputs
# must consume this assessment instead of recomputing any of those facts.

if ! declare -F gate_structural_schema_verify >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-structural-verify.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-structural-verify.sh"
fi
if ! declare -F gate_digest_file >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-digest.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-digest.sh"
fi
if ! declare -F gate_remediation_closure_verify >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-closure.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-closure.sh"
fi
if ! declare -F gate_policy_applicability_assess >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-result-verify.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-result-verify.sh"
fi

# gate_publish_assessment_build <output> <gate-verification-json>
#                              <closure> <full-result> <ticket-id>
gate_publish_assessment_build() {
  local output="${1:-}" gate_report_file="${2:-}" closure_file="${3:-}"
  local full_result="${4:-}" ticket_id="${5:-}"
  local assurance_file subject_fp scope_sha policy_axis route targeted_status
  local gate_result full_sha gate_sha closure_sha assurance_sha policy_status
  local assessment_tmp

  [[ $# -eq 5 && -n "$output" && -s "$gate_report_file" && -s "$closure_file" \
    && -s "$full_result" && -n "$ticket_id" ]] || {
    printf 'gate-publish: expected <output> <gate-verification-json> <closure> <full-result> <ticket-id>\n' >&2
    return 2
  }
  gate_structural_schema_verify gate-verification "$gate_report_file" \
    'gate publish input assessment' || return 1

  if ! jq -e '
      .verdict == "GO" and
      .axes.artifact_valid.status == "pass" and
      .axes.subject_current.status == "pass" and
      (.axes.subject_current.current.tree_fingerprint | type == "string") and
      (.assurance.file | type == "string" and startswith("/"))
    ' "$gate_report_file" >/dev/null 2>&1; then
    printf 'gate-publish: Gate assessment is not a current, valid GO\n' >&2
    return 1
  fi

  assurance_file="$(jq -r '.assurance.file' "$gate_report_file")"
  subject_fp="$(jq -r '.axes.subject_current.current.tree_fingerprint' "$gate_report_file")"
  scope_sha="$(jq -r '.evidence.scope_manifest.sha256 // empty' "$assurance_file" 2>/dev/null || true)"
  [[ -s "$assurance_file" && "$scope_sha" =~ ^[a-f0-9]{64}$ ]] || {
    printf 'gate-publish: Gate assurance lacks a verified scope manifest\n' >&2
    return 1
  }

  gate_remediation_closure_verify "$closure_file" "$subject_fp" "$scope_sha" || {
    printf 'gate-publish: remediation closure is not valid for the current Gate subject\n' >&2
    return 1
  }
  if ! jq -e --arg subject "$subject_fp" '
      .kind == "remediation_closure_v1" and .state == "closed" and
      .final_assessment.publish_authorized == true and
      .final_assessment.subject_fingerprint == $subject and
      .final_subject.tree_fingerprint == $subject and
      (.targeted_confirmation.status | IN("pass", "not_required"))
    ' "$closure_file" >/dev/null 2>&1; then
    printf 'gate-publish: closure does not authorize this final tree\n' >&2
    return 1
  fi

  if ! jq -e --arg subject "$subject_fp" '
      .kind == "pm_test_result_v2" and .contract == "full" and
      .authoritative == true and .status == "pass" and
      .aggregate.status == "pass" and .exit_code == 0 and
      .tree_fingerprint == $subject
    ' "$full_result" >/dev/null 2>&1; then
    printf 'gate-publish: full-suite evidence is not an authoritative pass for the Gate subject\n' >&2
    return 1
  fi

  # The policy resolver remains the only owner of baseline/preferred meaning.
  # A verified closure is the explicit authorization route for targeted
  # confirmation; it does not change the generic/maintainer policy ordering.
  policy_axis="$(gate_policy_applicability_assess "$assurance_file" publish \
    verified "" verified)" || return 1
  policy_status="$(jq -r '.status // empty' <<<"$policy_axis")"
  [[ "$policy_status" == pass ]] || {
    printf 'gate-publish: publish policy is not applicable: %s\n' \
      "$(jq -c '.reason_codes // []' <<<"$policy_axis")" >&2
    return 1
  }

  gate_result="$(jq -r '.result_file' "$gate_report_file")"
  gate_sha="$(gate_digest_file "$gate_result")" || return 1
  assurance_sha="$(gate_digest_file "$assurance_file")" || return 1
  closure_sha="$(gate_digest_file "$closure_file")" || return 1
  full_sha="$(gate_digest_file "$full_result")" || return 1
  targeted_status="$(jq -r '.targeted_confirmation.status' "$closure_file")"
  if [[ "$targeted_status" == pass ]]; then
    route=primary_review_closure
  else
    route=final_tree_review
  fi

  assessment_tmp="$(mktemp "${output}.tmp.XXXXXX")" || return 1
  if ! jq -n \
      --slurpfile gate "$gate_report_file" \
      --arg ticket "$ticket_id" \
      --argjson policy "$policy_axis" \
      --arg route "$route" \
      --arg subject "$subject_fp" \
      --arg gate_sha "$gate_sha" \
      --arg assurance_sha "$assurance_sha" \
      --arg closure "$closure_file" \
      --arg closure_sha "$closure_sha" \
      --arg full "$full_result" \
      --arg full_sha "$full_sha" \
      --arg targeted "$targeted_status" '
      $gate[0] as $g |
      ($g.axes.subject_current.current |
        {repository_key,base_commit,head_commit,tree_fingerprint}) as $subject_obj |
      {
        kind:"gate_publish_assessment_v1",schema_version:1,ticket:$ticket,
        subject:$subject_obj,
        authorization:{status:"authorized",route:$route,reason_codes:[]},
        policy:{embedded_policy:$policy.embedded_policy,
          required_policy:$policy.required_policy,
          preferred_policy:$policy.preferred_policy,
          policy_satisfaction:$policy.policy_satisfaction},
        gate:{result_file:$g.result_file,assurance_file:$g.assurance.file,
          verdict:$g.verdict,subject_fingerprint:$subject,
          artifact_sha256:$gate_sha,assurance_sha256:$assurance_sha},
        closure:{artifact:$closure,sha256:$closure_sha,state:"closed",
          subject_fingerprint:$subject,targeted_confirmation:$targeted},
        full_suite:{artifact:$full,sha256:$full_sha,status:"pass",
          subject_fingerprint:$subject}
      }
    ' > "$assessment_tmp"; then
    rm -f -- "$assessment_tmp"
    return 1
  fi
  gate_structural_schema_verify gate-publish-assessment "$assessment_tmp" \
    'publish assessment' || { rm -f -- "$assessment_tmp"; return 1; }
  if [[ -e "$output" || -L "$output" ]]; then
    # A retry after a successful push but transient PR-creation failure may
    # target the same subject and deterministic assessment path. Reuse is
    # safe only when the existing immutable artifact is byte-for-byte the
    # newly built assessment; any changed or symlinked destination remains a
    # fail-closed refusal and is never overwritten.
    if [[ -f "$output" && ! -L "$output" ]] && cmp -s "$assessment_tmp" "$output"; then
      rm -f -- "$assessment_tmp"
      printf 'gate-publish: reusing unchanged assessment destination: %s\n' "$output" >&2
      printf '%s\n' "$output"
      return 0
    fi
    printf 'gate-publish: assessment destination already exists and differs: %s\n' "$output" >&2
    rm -f -- "$assessment_tmp"
    return 1
  fi
  ln -- "$assessment_tmp" "$output" 2>/dev/null || {
    printf 'gate-publish: unable to publish assessment: %s\n' "$output" >&2
    rm -f -- "$assessment_tmp"
    return 1
  }
  rm -f -- "$assessment_tmp"
  printf '%s\n' "$output"
}

# gate_publish_assessment_verify <assessment>
gate_publish_assessment_verify() {
  local assessment="${1:-}" label path expected actual
  [[ $# -eq 1 && -s "$assessment" ]] || return 2
  gate_structural_schema_verify gate-publish-assessment "$assessment" \
    'publish assessment' || return 1
  jq -e '
    .authorization.status == "authorized" and
    .gate.verdict == "GO" and
    .closure.state == "closed" and
    .full_suite.status == "pass" and
    .subject.tree_fingerprint == .gate.subject_fingerprint and
    .subject.tree_fingerprint == .closure.subject_fingerprint and
    .subject.tree_fingerprint == .full_suite.subject_fingerprint
  ' "$assessment" >/dev/null 2>&1 || return 1

  # The assessment is consumed immediately before an irreversible push.  Its
  # recorded source digests are therefore re-computed at the consumption
  # boundary, rather than treated as historical claims.  This closes the
  # window in which a valid assessment could outlive a mutated Gate, closure,
  # or full-suite artifact.
  for label in gate assurance closure full_suite; do
    case "$label" in
      gate)
        path="$(jq -r '.gate.result_file // empty' "$assessment")"
        expected="$(jq -r '.gate.artifact_sha256 // empty' "$assessment")"
        ;;
      assurance)
        path="$(jq -r '.gate.assurance_file // empty' "$assessment")"
        expected="$(jq -r '.gate.assurance_sha256 // empty' "$assessment")"
        ;;
      closure)
        path="$(jq -r '.closure.artifact // empty' "$assessment")"
        expected="$(jq -r '.closure.sha256 // empty' "$assessment")"
        ;;
      full_suite)
        path="$(jq -r '.full_suite.artifact // empty' "$assessment")"
        expected="$(jq -r '.full_suite.sha256 // empty' "$assessment")"
        ;;
    esac
    if [[ -z "$path" || ! -f "$path" || -L "$path" ]]; then
      printf 'gate-publish: %s source artifact is missing or not a regular file: %s\n' \
        "$label" "$path" >&2
      return 1
    fi
    actual="$(gate_digest_file "$path")" || return 1
    if [[ "$actual" != "$expected" ]]; then
      printf 'gate-publish: %s source digest changed after assessment build: %s\n' \
        "$label" "$path" >&2
      return 1
    fi
  done
}
