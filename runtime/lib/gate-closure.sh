#!/usr/bin/env bash
# Runtime verification for the immutable remediation_closure_v1 artifact.
#
# The schema owns the portable shape. This module owns the copy-mode claims
# that depend on the linked Gate subject, scope manifest, and finding ledger.

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

_gate_closure_destination_check() {
  local path="$1" nlink
  [[ -L "$path" ]] && {
    printf 'gate-closure: destination must not be a symlink: %s\n' "$path" >&2
    return 1
  }
  [[ -e "$path" ]] || return 0
  [[ -f "$path" ]] || {
    printf 'gate-closure: destination must be a regular file: %s\n' "$path" >&2
    return 1
  }
  if nlink="$(stat -c '%h' "$path" 2>/dev/null)"; then
    :
  elif nlink="$(stat -f '%l' "$path" 2>/dev/null)"; then
    :
  else
    printf 'gate-closure: unable to inspect destination link count: %s\n' "$path" >&2
    return 1
  fi
  [[ "$nlink" =~ ^[0-9]+$ && "$nlink" -eq 1 ]] || {
    printf 'gate-closure: destination must not be hardlinked: %s\n' "$path" >&2
    return 1
  }
}

_gate_closure_synthesis_json() {
  local result_file="$1" output="$2"
  awk '
    /^```synthesis_result_v1[[:space:]]*$/ { in_block=1; next }
    in_block && /^```[[:space:]]*$/ { exit }
    in_block { print }
  ' "$result_file" > "$output"
  [[ -s "$output" ]] && jq -e '.kind == "gate_synthesis_result_v1"' "$output" >/dev/null 2>&1
}

_gate_closure_subject_json() {
  local assurance_file="$1"
  jq -c '
    .subject |
    {
      repository_key:(.repository_key // .repository.key),
      base_commit:(.base_commit // .base.commit),
      head_commit:(.head_commit // .head.commit),
      tree_fingerprint,
      subject_kind
    }
  ' "$assurance_file"
}

# gate_remediation_closure_publish <result> <assurance> <closure> [full-result] [ticket-ref]
#
# Gate calls this without a full result and therefore publishes a
# non-authorizing closure. Ship calls it with the authoritative full-suite
# artifact and publishes a new immutable closure that can authorize release.
# Both producers use this one builder so their evidence shape cannot drift.
gate_remediation_closure_publish() {
  local result_file="${1:-}" assurance_file="${2:-}" closure_file="${3:-}"
  local full_result="${4:-}" ticket_ref="${5:-}"
  local result_parent scope_artifact scope_file scope_sha subject_json subject_fp
  local final primary_result primary_assurance primary_subject primary_verdict
  local primary_artifact primary_sha synthesis_tmp initial_synthesis_tmp findings_json reviewers_json
  local targeted_confirmation_ids_json required_targeted_ids missing_targeted_ids
  local changed_files_json closure_tmp full_status full_tree full_artifact full_sha
  local test_evidence_json targeted_status targeted_reviewers
  local result_sha
  local allow_existing_retry=false

  [[ $# -ge 3 && $# -le 5 ]] || {
    printf 'gate-closure: publish expects <result> <assurance> <closure> [full-result] [ticket-ref]\n' >&2
    return 2
  }
  [[ $# -eq 5 && -n "$ticket_ref" ]] && allow_existing_retry=true
  [[ -s "$result_file" && -s "$assurance_file" ]] || {
    printf 'gate-closure: result and assurance artifacts are required\n' >&2
    return 1
  }
  result_parent="$(cd "$(dirname "$result_file")" && pwd -P)" || return 1
  scope_artifact="$(jq -r '.evidence.scope_manifest.artifact // empty' "$assurance_file")"
  scope_sha="$(jq -r '.evidence.scope_manifest.sha256 // empty' "$assurance_file")"
  scope_file="$result_parent/$scope_artifact"
  subject_json="$(_gate_closure_subject_json "$assurance_file")" || return 1
  subject_fp="$(jq -r '.tree_fingerprint' <<<"$subject_json")"
  [[ "$scope_sha" =~ ^[a-f0-9]{64}$ && "$subject_fp" =~ ^[a-f0-9]{64}$ ]] || {
    printf 'gate-closure: assurance lacks verified scope and subject evidence\n' >&2
    return 1
  }
  [[ -s "$scope_file" ]] || {
    printf 'gate-closure: scope manifest is missing beside assurance: %s\n' "$scope_file" >&2
    return 1
  }

  final="$(grep -m1 -E '^Final: (GO|NO-GO|INCOMPLETE)$' "$result_file" | awk '{print $2}')"
  [[ "$final" == GO || "$final" == NO-GO || "$final" == INCOMPLETE ]] || {
    printf 'gate-closure: result must have a terminal GO, NO-GO, or INCOMPLETE verdict to publish closure evidence\n' >&2
    return 1
  }

  primary_result="$result_file"
  # A targeted pass may reference a legacy v1 result without an immutable
  # subject sidecar. In that case the current verified Gate result is the
  # honest primary evidence; targeted coordinates remain recorded below.
  if [[ "$(jq -r '.coordinates.pass.resolved // empty' "$assurance_file")" == targeted \
      && "$final" != INCOMPLETE ]]; then
    local initial_input initial_candidate
    initial_input="$(jq -r '.coordinates.pass.initial_result // empty' "$assurance_file")"
    if [[ -n "$initial_input" ]]; then
      initial_candidate="$initial_input"
      [[ "$initial_candidate" == /* ]] || initial_candidate="$result_parent/$initial_candidate"
      if [[ -s "$initial_candidate" && -s "${initial_candidate}.assurance.json" ]] \
        && jq -e '.subject.tree_fingerprint != null' "${initial_candidate}.assurance.json" >/dev/null 2>&1; then
        primary_result="$initial_candidate"
      fi
    fi
  fi
  primary_artifact="$(basename "$primary_result")"
  primary_sha="$(gate_digest_file "$primary_result")" || return 1
  result_sha="$(gate_digest_file "$result_file")" || return 1
  primary_verdict="$(grep -m1 -E '^Final: (GO|NO-GO|INCOMPLETE)$' "$primary_result" | awk '{print $2}')"
  primary_subject="$subject_json"
  primary_assurance="${primary_result}.assurance.json"
  if [[ "$primary_result" != "$result_file" && -s "$primary_assurance" ]]; then
    primary_subject="$(_gate_closure_subject_json "$primary_assurance")" || return 1
  fi

  synthesis_tmp="$(mktemp "${TMPDIR:-/tmp}/gate-closure-synthesis.XXXXXX.json")" || return 1
  initial_synthesis_tmp=""
  findings_json='[]'
  targeted_confirmation_ids_json='[]'
  reviewers_json='[]'
  if _gate_closure_synthesis_json "$result_file" "$synthesis_tmp"; then
    targeted_confirmation_ids_json="$(jq -c '[.remediation_confirmations[]?.finding_id] | unique' "$synthesis_tmp")" || {
      rm -f "$synthesis_tmp"; return 1;
    }
    findings_json="$(jq -c '.findings_union // []' "$synthesis_tmp")" || {
      rm -f "$synthesis_tmp"; return 1;
    }
    reviewers_json="$(jq -c '.selected_reviewers // []' "$synthesis_tmp")" || {
      rm -f "$synthesis_tmp"; return 1;
    }
  fi

  # A targeted pass is delta evidence, not a replacement for the initial
  # comprehensive ledger. When the initial result has an immutable sidecar,
  # carry its complete finding inventory into the closure and require the
  # targeted GO to explicitly confirm every initial diff-caused/uncertain
  # finding. Confirmation is a separate delta ledger: a successful targeted
  # review should have no current blocking findings left to union into the
  # result. Requiring the old finding IDs in findings_union made a clean GO
  # impossible because retaining a blocker would itself contradict GO.
  if [[ "$primary_result" != "$result_file" ]]; then
    initial_synthesis_tmp="$(mktemp "${TMPDIR:-/tmp}/gate-closure-initial-synthesis.XXXXXX.json")" || {
      rm -f "$synthesis_tmp"; return 1;
    }
    if _gate_closure_synthesis_json "$primary_result" "$initial_synthesis_tmp"; then
      findings_json="$(jq -c '.findings_union // []' "$initial_synthesis_tmp")" || {
        rm -f "$synthesis_tmp" "$initial_synthesis_tmp"; return 1;
      }
      if [[ "$final" == GO && "$(jq -r '.coordinates.pass.resolved // empty' "$assurance_file")" == targeted ]]; then
        required_targeted_ids="$(jq -c '[.[] | select(.origin == "diff_caused" or .origin == "uncertain") | .id] | unique' <<<"$findings_json")" || {
          rm -f "$synthesis_tmp" "$initial_synthesis_tmp"; return 1;
        }
        missing_targeted_ids="$(jq -cn --argjson required "$required_targeted_ids" --argjson observed "${targeted_confirmation_ids_json:-[]}" '
          ($observed | unique) as $observed_ids |
          ($required - $observed_ids)')" || {
          rm -f "$synthesis_tmp" "$initial_synthesis_tmp"; return 1;
        }
        if [[ "$missing_targeted_ids" != "[]" ]]; then
          printf 'gate-closure: targeted pass does not explicitly confirm initial blocking findings: %s\n' \
            "$missing_targeted_ids" >&2
          rm -f "$synthesis_tmp" "$initial_synthesis_tmp"
          return 1
        fi
      fi
    elif [[ "$final" == GO && "$(jq -r '.coordinates.pass.resolved // empty' "$assurance_file")" == targeted ]]; then
      printf 'gate-closure: targeted pass lacks the initial comprehensive finding ledger\n' >&2
      rm -f "$synthesis_tmp" "$initial_synthesis_tmp"
      return 1
    fi
  fi

  changed_files_json="$(jq -c --argjson findings "$findings_json" '
    ([.changes.changed_paths[], .changes.renamed_paths[]?.from,
      .changes.renamed_paths[]?.to, .changes.untracked_paths[],
      .diff.binary_or_special_paths[]]) |
      map(select(type == "string" and length > 0)) | unique | sort
  ' "$scope_file")" || {
    rm -f "$synthesis_tmp" "$initial_synthesis_tmp"; return 1;
  }

  full_status=not_run
  full_artifact=null
  full_sha=""
  if [[ -n "$full_result" ]]; then
    full_tree="$(jq -r '.tree_fingerprint // empty' "$full_result" 2>/dev/null)"
    if ! jq -e '
      .kind == "pm_test_result_v2" and .contract == "full" and
      .authoritative == true and .status == "pass" and
      .aggregate.status == "pass" and .exit_code == 0
    ' "$full_result" >/dev/null 2>&1 || [[ "$full_tree" != "$subject_fp" ]]; then
      printf 'gate-closure: supplied full-suite evidence is not an authoritative pass for the Gate subject\n' >&2
      rm -f "$synthesis_tmp" "$initial_synthesis_tmp"
      return 1
    fi
    full_status=pass
    full_artifact="$(basename "$full_result")"
    full_sha="$(gate_digest_file "$full_result")" || { rm -f "$synthesis_tmp" "$initial_synthesis_tmp"; return 1; }
  fi

  targeted_status=not_required
  targeted_reviewers='[]'
  if [[ "$(jq -r '.coordinates.pass.resolved // empty' "$assurance_file")" == targeted \
      && "$final" != INCOMPLETE ]]; then
    targeted_status=pass
    targeted_reviewers="$reviewers_json"
  fi

  # These are producer-owned facts: Gate verification is the focused check;
  # ship adds the authoritative full suite. They are never inferred from prose.
  test_evidence_json="$(jq -nc \
    --arg subject "$subject_fp" --arg result_artifact "$(basename "$result_file")" \
    --arg result_sha "$(gate_digest_file "$result_file")" \
    --arg full_artifact "$full_artifact" --arg full_sha "$full_sha" \
    --arg full_status "$full_status" --arg gate_status \
      "$(if [[ "$final" == INCOMPLETE ]]; then printf not_run; else printf pass; fi)" '[
      {id:"gate-review",kind:"focused",command:"pmctl gate verify <gate-result>",
       status:$gate_status,subject_fingerprint:$subject,artifact:$result_artifact,
       artifact_sha256:$result_sha},
      (if $full_status == "pass" then
        {id:"full-suite",kind:"full",command:"bash tests/bin/run-all-tests.sh",
         status:"pass",subject_fingerprint:$subject,artifact:$full_artifact,
         artifact_sha256:$full_sha}
       else empty end)
    ]')" || { rm -f "$synthesis_tmp"; return 1; }

  closure_tmp="$(mktemp "${closure_file}.tmp.XXXXXX")" || {
    rm -f "$synthesis_tmp"; return 1;
  }
  if ! jq -n \
    --arg scope_sha "$scope_sha" --argjson primary_subject "$primary_subject" \
    --arg primary_artifact "$primary_artifact" --arg primary_sha "$primary_sha" \
    --arg primary_fp "$(jq -r '.tree_fingerprint' <<<"$primary_subject")" \
    --arg primary_verdict "$primary_verdict" --argjson final_subject "$subject_json" \
    --argjson findings "$findings_json" --argjson changed_files "$changed_files_json" \
    --argjson tests "$test_evidence_json" --arg targeted_status "$targeted_status" \
    --argjson targeted_confirmation_ids "$targeted_confirmation_ids_json" \
    --argjson targeted_reviewers "$targeted_reviewers" --arg final "$final" \
    --arg result_artifact "$(basename "$result_file")" --arg result_sha "$result_sha" \
    --arg full_status "$full_status" --arg ticket_ref "$ticket_ref" '
    ($findings | map(
      . as $f |
      (if $f.origin == "uncertain" then
        (if $final == "GO" and $targeted_status == "pass" and
            (($targeted_confirmation_ids | index($f.id)) != null) then
          {disposition:"closed",classification:"targeted_confirmation",verification_status:"pass"}
         else
          {disposition:"split",classification:"stop_split",verification_status:"split"}
         end)
       elif $f.origin == "pre_existing" then
        {disposition:"tracked",classification:"stop_split",verification_status:"not_required"}
       elif $f.origin == "caution" then
        {disposition:"closed",classification:"local",verification_status:"not_required"}
       elif $final == "GO" then
        {disposition:"closed",
         classification:(if $targeted_status == "pass" then "targeted_confirmation" else "local" end),
         verification_status:"pass"}
       else
        {disposition:"split",classification:"stop_split",verification_status:"split"}
       end) as $claim |
      {finding_id:$f.id,origin:$f.origin,disposition:$claim.disposition,
       classification:$claim.classification,
       changed_paths:(if ($changed_files | index($f.source.path)) != null then
         [$f.source.path]
       elif ($changed_files | length) > 0 then
         [$changed_files[0]]
       else [] end),
       evidence_refs:[$f.source],
       affected_test_ids:(if $full_status == "pass" then ["gate-review","full-suite"] else ["gate-review"] end),
       verification_status:$claim.verification_status}
       + (if $f.origin == "pre_existing" then
           {ticket_ref:(if $ticket_ref == "" then null else $ticket_ref end)}
          else {} end)
    )) as $mapped_findings |
    (if $final != "GO" and ($mapped_findings | length) == 0 and
        ($changed_files | length) > 0 then
      [{finding_id:"critic-F999",origin:"uncertain",disposition:"split",
        classification:"stop_split",changed_paths:[$changed_files[0]],
        evidence_refs:[{path:$changed_files[0],line:1,symbol:null}],
        affected_test_ids:["gate-review"],verification_status:"split"}]
     else $mapped_findings end) as $closure_findings |
    ([$closure_findings[] | select(.disposition != "closed")] | length) as $unresolved |
    ([$closure_findings[] | select(.disposition != "closed" and
      (.origin == "diff_caused" or .origin == "uncertain"))] | length) as $blocking |
    ($unresolved - $blocking) as $advisory |
    (if $unresolved == 0 then "closed" else "split" end) as $state |
    {
      kind:"remediation_closure_v1",schema_version:1,state:$state,
      scope_manifest_sha256:$scope_sha,
      primary:{gate_result:{artifact:$primary_artifact,sha256:$primary_sha,
        subject_fingerprint:$primary_fp},verdict:$primary_verdict,status:"verified",
        subject:$primary_subject},
      final_subject:$final_subject,findings:$closure_findings,
      changed_files:$changed_files,affected_tests:$tests,
      targeted_confirmation:{status:$targeted_status,reviewers:$targeted_reviewers,
        finding_ids:(if $targeted_status == "pass" then $targeted_confirmation_ids else [] end),
        delta_only:true,evidence:(if $targeted_status == "pass" then
          {artifact:$result_artifact,sha256:$result_sha,
           subject_fingerprint:$final_subject.tree_fingerprint}
        else null end)},
      unresolved_counts:{total:$unresolved,blocking:$blocking,advisory:$advisory},
      final_assessment:{remediation_status:$state,
        affected_tests_status:(if $final == "GO" then "pass" else "incomplete" end),
        full_suite_status:$full_status,subject_fingerprint:$final_subject.tree_fingerprint,
        publish_authorized:($state == "closed" and $final == "GO" and
          $full_status == "pass" and $unresolved == 0)}
    }
  ' > "$closure_tmp"; then
    rm -f "$closure_tmp" "$synthesis_tmp" "$initial_synthesis_tmp"
    return 1
  fi
  rm -f "$synthesis_tmp" "$initial_synthesis_tmp"
  if [[ -e "$closure_file" || -L "$closure_file" ]]; then
    # A retry after a pushed branch's transient PR failure may rebuild the
    # same deterministic closure path. Reuse is allowed only for an exact,
    # already-valid immutable artifact; a changed or redirected destination
    # remains fail-closed and is never overwritten.
    if [[ "$allow_existing_retry" == true \
        && -f "$closure_file" && ! -L "$closure_file" ]] \
        && cmp -s "$closure_tmp" "$closure_file" \
        && gate_remediation_closure_verify "$closure_file" "$subject_fp" "$scope_sha"; then
      rm -f "$closure_tmp" "$initial_synthesis_tmp"
      printf 'gate-closure: reusing unchanged closure destination: %s\n' "$closure_file" >&2
      printf '%s\n' "$closure_file"
      return 0
    fi
    _gate_closure_destination_check "$closure_file" || { rm -f "$closure_tmp" "$initial_synthesis_tmp"; return 1; }
    printf 'gate-closure: closure destination already exists and differs: %s\n' "$closure_file" >&2
    rm -f "$closure_tmp" "$initial_synthesis_tmp"
    return 1
  fi
  _gate_closure_destination_check "$closure_file" || { rm -f "$closure_tmp" "$initial_synthesis_tmp"; return 1; }
  # Link-then-unlink is an atomic no-replace publish on the same filesystem:
  # unlike `mv`, it cannot overwrite a closure that appeared after the
  # destination check. The temporary file is created beside the destination,
  # so the link is guaranteed to stay on one filesystem.
  if ! ln -- "$closure_tmp" "$closure_file"; then
    printf 'gate-closure: destination already exists or cannot be published: %s\n' \
      "$closure_file" >&2
    rm -f "$closure_tmp" "$initial_synthesis_tmp"
    return 1
  fi
  rm -f "$closure_tmp" "$initial_synthesis_tmp"
  if ! gate_remediation_closure_verify "$closure_file" "$subject_fp" "$scope_sha"; then
    printf 'gate-closure: published artifact failed its own verification: %s\n' "$closure_file" >&2
    return 1
  fi
  printf '%s\n' "$closure_file"
}

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
    def only_keys($allowed):
      type == "object" and ((keys_unsorted - $allowed) | length) == 0;
    def strings_unique:
      type == "array" and all(.[]; type == "string" and length > 0) and
      length == (unique | length);
    def safe_paths:
      strings_unique and all(.[];
        (startswith("/") | not) and ((split("/") | index("..")) == null));
    def finding_ids:
      [.findings[].finding_id];
    def test_ids:
      [.affected_tests[].id];

    . as $root |
    ($root.findings | any(.[]; .classification == "targeted_confirmation")) as $has_targeted |
    ($root.targeted_confirmation.finding_ids // []) as $targeted_ids |
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
      ($finding.evidence_refs | length > 0) and
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
        (($finding.disposition == "closed" and
          $finding.classification == "targeted_confirmation" and
          $finding.verification_status == "pass") or
         ($root.state == "split" and $finding.disposition == "split" and
          $finding.classification == "stop_split" and
          $finding.verification_status == "split"))
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
    ($targeted_ids | type == "array" and length == (unique | length) and
      all(.[]; type == "string")) and
    (if $has_targeted then
      ($targeted_ids | sort) == ([.findings[] | select(.classification == "targeted_confirmation") | .finding_id] | sort)
     else ($targeted_ids | length == 0) end) and
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
