#!/usr/bin/env bash
# Source-safe Gate assurance publication and attestation assembly.
#
# The entrypoint supplies the resolved subject, policy, scope, dispatch, and
# artifact globals; this module owns all assurance-path validation and machine
# sidecar/attestation publication behavior.

_gate_assurance_destination_check() {
  local path="$1" nlink
  if [[ -L "$path" ]]; then
    printf 'Error: gate assurance destination must not be a symlink: %s\n' "$path" >&2
    return 1
  fi
  if [[ -e "$path" ]]; then
    if [[ ! -f "$path" ]]; then
      printf 'Error: gate assurance destination must be a regular file: %s\n' "$path" >&2
      return 1
    fi
    if nlink="$(stat -c '%h' "$path" 2>/dev/null)"; then
      :
    elif nlink="$(stat -f '%l' "$path" 2>/dev/null)"; then
      :
    else
      printf 'Error: unable to inspect gate assurance destination link count: %s\n' \
        "$path" >&2
      return 1
    fi
    if [[ ! "$nlink" =~ ^[0-9]+$ || "$nlink" -ne 1 ]]; then
      printf 'Error: gate assurance destination must not be hardlinked: %s\n' \
        "$path" >&2
      return 1
    fi
  fi
}
gate_finalize_assurance() {
  local result_file="$1" assurance_file="$2"
  local final requested_json outcomes_json independence_status implementation_isolated
  local per_reviewer_independent expected_count capture_count assurance_tmp result_tmp
  local result_sha assurance_sha subject_sha attestation_tmp run_ids_json attestation_pointer
  local finished_at subject_finish subject_json preflight_json evidence_json
  local evidence_destination evidence_destination_sha evidence_tmp
  local scope_destination scope_destination_sha scope_tmp scope_json
  local closure_file closure_sha closure_tmp closure_json
  local -a capture_files=()

  final="$(grep -E '^Final: (GO|NO-GO|INCOMPLETE)$' "$result_file" | awk '{print $2}')"
  [[ -n "$final" ]] || {
    printf 'Error: cannot finalize gate assurance without a unique final verdict\n' >&2
    return 1
  }
  if [[ -n "$REVIEWERS_OVERRIDE" ]]; then
    requested_json="$(jq -nc --arg reviewers "$REVIEWERS" \
      '$reviewers | split(" ") | map(select(length > 0))')"
  else
    requested_json=null
  fi

  while IFS= read -r _capture_file; do
    capture_files+=("$_capture_file")
  done < <(find "$GATE_ASSURANCE_CAPTURE_DIR" -maxdepth 1 -type f -name '*.json' -print | LC_ALL=C sort)
  capture_count="${#capture_files[@]}"

  if [[ "$PREFLIGHT_STATUS" != pass && "$PREFLIGHT_STATUS" != skipped ]]; then
    if [[ "$PREFLIGHT_STATUS" == test-fail ]]; then
      outcomes_json='[{"role":"preflight","reviewer":null,"status":"failed","run_id":null,"evidence_status":"unavailable"}]'
    else
      outcomes_json='[{"role":"preflight","reviewer":null,"status":"incomplete","run_id":null,"evidence_status":"unavailable"}]'
    fi
    independence_status=unavailable
    implementation_isolated=null
    per_reviewer_independent=null
  elif [[ -n "$PMCTL_DISPATCH_LIB_DIR" \
      && -n "$ASSURANCE_ATTESTATION_FILE" \
      && -n "$GATE_ASSURANCE_RUNS_FILE" ]]; then
    if [[ "$SEQUENTIAL" == true ]]; then expected_count=1; else expected_count=$((NUM_REVIEWERS + 1)); fi
    if [[ "$capture_count" -ne "$expected_count" ]]; then
      printf 'Error: gate dispatch evidence incomplete (expected %d capture(s), found %d)\n' \
        "$expected_count" "$capture_count" >&2
      return 1
    fi
    outcomes_json="$(jq -s '.' "${capture_files[@]}")" || return 1
    independence_status=verified
    implementation_isolated=true
    if [[ "$SEQUENTIAL" == true ]]; then
      per_reviewer_independent=false
    else
      per_reviewer_independent=true
    fi
  else
    independence_status=unavailable
    implementation_isolated=null
    per_reviewer_independent=null
    if [[ "$SEQUENTIAL" == true ]]; then
      outcomes_json='[{"role":"combined","reviewer":null,"status":"passed","run_id":null,"evidence_status":"unavailable"}]'
    else
      outcomes_json="$(jq -nc --arg reviewers "$REVIEWERS" '
        ($reviewers | split(" ") | map(select(length > 0))) as $selected |
        ([$selected[] | {role:"reviewer",reviewer:.,status:"passed",run_id:null,
          evidence_status:"unavailable"}] +
         [{role:"synthesis",reviewer:null,status:"passed",run_id:null,
          evidence_status:"unavailable"}])')"
    fi
  fi
  attestation_pointer=""
  if [[ "$independence_status" == verified ]]; then
    attestation_pointer="$ASSURANCE_ATTESTATION_POINTER"
  fi
  finished_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
    || date +'%Y-%m-%dT%H:%M:%SZ')"
  subject_finish="$(
    gate_subject_snapshot "$WORK_DIR" "$BASE" "$HEAD_REF" "$GATE_SUBJECT_KIND" \
      "$GATE_SUBJECT_DIRTY_POLICY" "$finished_at"
  )" || {
    printf 'Error: unable to capture final gate subject\n' >&2
    return 1
  }
  subject_json="$(jq -nc \
    --argjson initial "$GATE_SUBJECT_INITIAL" \
    --argjson finish "$subject_finish" '{
      kind:"gate_subject_v1",
      schema_version:1,
      repository:$initial.repository,
      observed:$initial.observed,
      base:$initial.base,
      head:$initial.head,
      tree_fingerprint:$initial.tree_fingerprint,
      subject_kind:$initial.subject_kind,
      dirty_policy:$initial.dirty_policy,
      created_at:$initial.captured_at,
      finished_at:$finish.captured_at,
      observed_at_finish:{
        repository_key:$finish.repository.key,
        base_commit:$finish.base.commit,
        head_commit:$finish.head.commit,
        tree_fingerprint:$finish.tree_fingerprint
      }
    }')" || return 1
  if [[ "$PREFLIGHT_STATUS" == skipped ]]; then
    preflight_json='{"status":"not_run","outcome":null,"artifact":null,"sha256":null,"subject_fingerprint":null}'
  else
    evidence_destination="$(dirname "$assurance_file")/$(basename "$PREFLIGHT_EVIDENCE_PATH")"
    if [[ "$PREFLIGHT_EVIDENCE_PATH" != "$evidence_destination" ]]; then
      _gate_assurance_destination_check "$evidence_destination" || return 1
      if [[ -e "$evidence_destination" ]]; then
        evidence_destination_sha="$(
          _gate_result_sha256_file "$evidence_destination"
        )" || return $?
        if [[ "$evidence_destination_sha" != "$PREFLIGHT_EVIDENCE_DIGEST" ]]; then
          printf 'Error: linked preflight evidence destination already exists with different content: %s\n' \
            "$evidence_destination" >&2
          return 1
        fi
      else
        evidence_tmp="$(mktemp "${evidence_destination}.tmp.XXXXXX")" || return 1
        if ! cp -- "$PREFLIGHT_EVIDENCE_PATH" "$evidence_tmp" \
            || ! mv -- "$evidence_tmp" "$evidence_destination"; then
          rm -f -- "$evidence_tmp"
          return 1
        fi
      fi
      PREFLIGHT_EVIDENCE_PATH="$evidence_destination"
    fi
    preflight_json="$(jq -nc \
      --arg outcome "$PREFLIGHT_STATUS" \
      --arg artifact "$(basename "$PREFLIGHT_EVIDENCE_PATH")" \
      --arg sha256 "$PREFLIGHT_EVIDENCE_DIGEST" \
      --arg subject_fingerprint \
        "$(jq -r '.tree_fingerprint' <<<"$GATE_SUBJECT_INITIAL")" '{
        status:"linked",
        outcome:$outcome,
        artifact:$artifact,
        sha256:$sha256,
        subject_fingerprint:$subject_fingerprint
      }')" || return 1
  fi
  scope_destination="$(dirname "$assurance_file")/$(basename "$SCOPE_MANIFEST_PATH")"
  if [[ "$SCOPE_MANIFEST_PATH" != "$scope_destination" ]]; then
    _gate_assurance_destination_check "$scope_destination" || return 1
    if [[ -e "$scope_destination" ]]; then
      scope_destination_sha="$(
        _gate_result_sha256_file "$scope_destination"
      )" || return $?
      if [[ "$scope_destination_sha" != "$SCOPE_MANIFEST_DIGEST" ]]; then
        printf 'Error: linked scope manifest destination already exists with different content: %s\n' \
          "$scope_destination" >&2
        return 1
      fi
    else
      scope_tmp="$(mktemp "${scope_destination}.tmp.XXXXXX")" || return 1
      if ! cp -- "$SCOPE_MANIFEST_PATH" "$scope_tmp" \
          || ! mv -- "$scope_tmp" "$scope_destination"; then
        rm -f -- "$scope_tmp"
        return 1
      fi
    fi
    SCOPE_MANIFEST_PATH="$scope_destination"
  fi
  scope_json="$(jq -nc \
    --arg artifact "$(basename "$SCOPE_MANIFEST_PATH")" \
    --arg sha256 "$SCOPE_MANIFEST_DIGEST" \
    --arg subject_fingerprint \
      "$(jq -r '.tree_fingerprint' <<<"$GATE_SUBJECT_INITIAL")" '{
      status:"verified",
      artifact:$artifact,
      sha256:$sha256,
      subject_fingerprint:$subject_fingerprint
    }')" || return 1
  evidence_json="$(jq -nc --argjson preflight "$preflight_json" \
    --argjson scope "$scope_json" '{
    preflight:$preflight,
    scope_manifest:$scope,
    closure:{
      status:"unavailable",artifact:null,sha256:null,subject_fingerprint:null
    }
  }')" || return 1

  result_tmp="$(mktemp "${result_file}.assurance-tmp.XXXXXX")" || {
    printf 'Error: unable to create gate result temporary file beside: %s\n' \
      "$result_file" >&2
    return 1
  }
  local result_version=pr_gate_result_v2
  if [[ "$REVIEWER_PROTOCOL_COMPLETE" == true \
      && "$SYNTHESIS_PROTOCOL_COMPLETE" == true ]]; then
    result_version=pr_gate_result_v5
  elif [[ "$REVIEWER_PROTOCOL_COMPLETE" == true ]]; then
    result_version=pr_gate_result_v3
  fi
  awk -v pointer="$ASSURANCE_POINTER" -v result_version="$result_version" '
    /^---$/ {
      fence++
      print
      next
    }
    fence == 1 && /^gate_result_version:/ {
      print "gate_result_version: " result_version
      print "gate_assurance: " pointer
      next
    }
    fence == 1 && /^gate_assurance:/ { next }
    { print }
  ' "$result_file" > "$result_tmp" || {
    rm -f -- "$result_tmp"
    return 1
  }
  result_sha="$(_gate_result_sha256_file "$result_tmp")" || {
    rm -f -- "$result_tmp"
    return 1
  }

  assurance_tmp="$(mktemp "${assurance_file}.tmp.XXXXXX")" || {
    rm -f -- "$result_tmp"
    printf 'Error: unable to create gate assurance temporary file beside: %s\n' \
      "$assurance_file" >&2
    return 1
  }
  if ! jq -n \
    --arg final "$final" \
    --arg result_sha "$result_sha" \
    --arg repo_root "$WORK_DIR" --arg repo_identity "$GATE_SUBJECT_REPOSITORY_KEY" \
    --arg base_commit "$GATE_BINDING_BASE_COMMIT" \
    --arg head_commit "$GATE_BINDING_HEAD_COMMIT" \
    --arg subject_fingerprint "$GATE_BINDING_SUBJECT_FINGERPRINT" \
    --arg tier_requested "$TIER_REQUESTED" --arg tier_resolved "$TIER_RESOLVED" \
    --arg tier_selection_basis "$TIER_SELECTION_BASIS" \
    --arg evidence_floor "$TIER_EVIDENCE_FLOOR" \
    --arg mode_requested "$MODE_REQUESTED" --arg mode_resolved "$MODE_RESOLVED" \
    --arg topology "$MODE_TOPOLOGY" --arg synthesis "$MODE_SYNTHESIS" \
    --arg pass_requested "$PASS_KIND_REQUESTED" --arg pass_resolved "$PASS_KIND_RESOLVED" \
    --arg pass_scope "$PASS_SCOPE" --arg initial_result "$INITIAL_RESULT_RESOLVED" \
    --arg pass_syntax "$PASS_SYNTAX_SOURCE" --arg coverage_syntax "$COVERAGE_SYNTAX_SOURCE" \
    --arg selected "$REVIEWERS" --arg skipped "$SKIPPED_WORDS" \
    --arg coverage_selection_basis "$COVERAGE_SELECTION_BASIS" \
    --arg vocabulary "$ALL_REVIEWERS" \
    --arg reviewer_topology "$MODE_TOPOLOGY" \
    --arg independence_status "$independence_status" \
    --arg policy_source "$GATE_ASSURANCE_POLICY_SOURCE" \
    --arg attestation "$attestation_pointer" \
    --argjson requested "$requested_json" --argjson outcomes "$outcomes_json" \
    --argjson subject "$subject_json" --argjson evidence "$evidence_json" \
    --argjson policy_resolution "$GATE_POLICY_RESOLUTION" \
    --argjson implementation_isolated "$implementation_isolated" \
    --argjson per_reviewer_independent "$per_reviewer_independent" '
      {
        kind:"gate_assurance_v3",schema_version:3,
        result:{final:$final},
        bindings:{
          result_sha256:$result_sha,
          repo_root:$repo_root,
          repo_identity:$repo_identity,
          base_commit:$base_commit,
          head_commit:$head_commit,
          subject_fingerprint:$subject_fingerprint
        },
        subject:$subject,
        evidence:$evidence,
        coordinates:{
          tier:{requested:$tier_requested,resolved:$tier_resolved,
            evidence_floor:$evidence_floor,selection_basis:$tier_selection_basis},
          mode:{requested:$mode_requested,resolved:$mode_resolved,
            topology:$topology,synthesis:$synthesis},
          pass:{requested:$pass_requested,resolved:$pass_resolved,scope:$pass_scope,
            initial_result:(if $initial_result == "" then null else $initial_result end)},
          coverage:{
            requested:$requested,
            selected:($selected | split(" ") | map(select(length > 0))),
            skipped:($skipped | split(" ") | map(select(length > 0))),
            vocabulary:($vocabulary | split(" ") | map(select(length > 0))),
            selection_basis:$coverage_selection_basis
          },
          independence:{
            implementation_context_isolated:$implementation_isolated,
            reviewer_topology:$reviewer_topology,
            per_reviewer_independent:$per_reviewer_independent,
            evidence_status:$independence_status
          }
        },
        policy:$policy_resolution,
        dispatch:{outcomes:$outcomes},
        provenance:{
          producer:"pr-gate.sh",
          policy_source:$policy_source,
          attestation:(if $attestation == "" then null else $attestation end),
          coordinate_syntax:{pass:$pass_syntax,coverage:$coverage_syntax}
        }
      }' > "$assurance_tmp"; then
    rm -f -- "$assurance_tmp" "$result_tmp"
    return 1
  fi

  _gate_assurance_destination_check "$assurance_file" || {
    rm -f -- "$assurance_tmp" "$result_tmp"
    return 1
  }
  # Publish the sidecar before the v2 Markdown result that references it. A verifier
  # racing this boundary sees either the original self-contained v1 result or
  # the complete bound pair; a host failure cannot strand a v2/v3 result with
  # a permanently missing sidecar.
  mv -- "$assurance_tmp" "$assurance_file" || {
    rm -f -- "$assurance_tmp" "$result_tmp"
    return 1
  }
  mv -- "$result_tmp" "$result_file" || {
    rm -f -- "$result_tmp"
    return 1
  }
  gate_result_verify "$result_file" "" "machine assurance finalization" || return $?

  # Publish the first immutable remediation closure only after the final Gate
  # result and assurance sidecar exist. The closure links the final result
  # digest, so publishing it earlier would bind the pre-assurance staging
  # digest rather than the artifact consumers actually verify.
  closure_file="$(dirname "$assurance_file")/$(basename "$result_file" .md).remediation-closure.json"
  if ! gate_remediation_closure_publish \
      "$result_file" "$assurance_file" "$closure_file"; then
    printf 'Error: unable to publish remediation closure evidence: %s\n' \
      "$closure_file" >&2
    return 1
  fi
  closure_sha="$(_gate_result_sha256_file "$closure_file")" || return $?
  closure_json="$(jq -nc \
    --arg artifact "$(basename "$closure_file")" \
    --arg sha256 "$closure_sha" \
    --arg subject_fingerprint "$(jq -r '.subject.tree_fingerprint' "$assurance_file")" \
    '{status:"verified",artifact:$artifact,sha256:$sha256,subject_fingerprint:$subject_fingerprint}')" || return 1
  closure_tmp="$(mktemp "${assurance_file}.closure-tmp.XXXXXX")" || return 1
  if ! jq --argjson closure "$closure_json" '.evidence.closure = $closure' \
      "$assurance_file" > "$closure_tmp"; then
    rm -f -- "$closure_tmp"
    return 1
  fi
  mv -- "$closure_tmp" "$assurance_file" || {
    rm -f -- "$closure_tmp"
    return 1
  }
  gate_result_verify "$result_file" "" "remediation closure finalization" || return $?

  if [[ "$independence_status" == verified ]]; then
    assurance_sha="$(_gate_result_sha256_file "$assurance_file")" || return $?
    subject_sha="$(jq -cS '.subject' "$assurance_file" \
      | _gate_result_sha256_stream)" || return $?
    run_ids_json="$(jq -c '[.[].run_id]' <<<"$outcomes_json")" || return 1
    _gate_assurance_destination_check "$ASSURANCE_ATTESTATION_FILE" || return 1
    attestation_tmp="$(mktemp "${ASSURANCE_ATTESTATION_FILE}.tmp.XXXXXX")" || {
      printf 'Error: unable to create protected gate assurance attestation\n' >&2
      return 1
    }
    if ! jq -n \
      --arg result_sha "$result_sha" --arg assurance_sha "$assurance_sha" \
      --arg repo_root "$WORK_DIR" --arg repo_identity "$GATE_SUBJECT_REPOSITORY_KEY" \
      --arg base_commit "$GATE_BINDING_BASE_COMMIT" \
      --arg head_commit "$GATE_BINDING_HEAD_COMMIT" \
      --arg subject_fingerprint "$GATE_BINDING_SUBJECT_FINGERPRINT" \
      --arg repository_key "$GATE_SUBJECT_REPOSITORY_KEY" \
      --arg subject_sha "$subject_sha" \
      --argjson run_ids "$run_ids_json" '{
        kind:"gate_assurance_attestation_v2",
        schema_version:2,
        result_sha256:$result_sha,
        assurance_sha256:$assurance_sha,
        repo_root:$repo_root,
        repo_identity:$repo_identity,
        base_commit:$base_commit,
        head_commit:$head_commit,
        subject_fingerprint:$subject_fingerprint,
        repository_key:$repository_key,
        subject_sha256:$subject_sha,
        run_ids:$run_ids
      }' > "$attestation_tmp"; then
      rm -f -- "$attestation_tmp"
      return 1
    fi
    mv -- "$attestation_tmp" "$ASSURANCE_ATTESTATION_FILE" || {
      rm -f -- "$attestation_tmp"
      return 1
    }
    gate_assurance_authorization_verify "$result_file" "$assurance_file" \
      "$ASSURANCE_ATTESTATION_FILE" "$GATE_ASSURANCE_RUNS_FILE"
  fi
}
