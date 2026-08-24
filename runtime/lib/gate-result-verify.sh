#!/usr/bin/env bash
# Shared gate-result integrity and assurance verification.
#
# pr_gate_result_v1 remains valid legacy structural evidence.  It proves only
# frontmatter/body verdict parity and is reported as assurance=unavailable.
# pr_gate_result_v2 points at a sibling assurance JSON envelope owned by the
# gate shell. pr_gate_result_v3 additionally requires one schema-complete
# reviewer protocol block per selected reviewer. Legacy gate_assurance_v1
# remains readable but non-authorizing;
# gate_assurance_v2 adds result bindings and protected dispatch attestation.
# gate_assurance_v3 adds an immutable subject plus digest-bound evidence links.

# pr_gate_result_v4 additionally requires one synthesis parity document whose
# inventory and remediation seed are mechanically reconciled with the original
# reviewer protocol documents.
# pr_gate_result_v5 adds strict test-gap parity, caution, and verification-plan
# contracts while preserving v3/v4 readability.
if ! declare -F gate_digest_stream >/dev/null 2>&1; then
  _gate_result_verify_dir="${BASH_SOURCE[0]%/*}"
  _gate_digest_module="$_gate_result_verify_dir/gate-digest.sh"
  if [[ ! -r "$_gate_digest_module" ]]; then
    printf 'gate-result-verify: digest module unavailable: %s\n' \
      "$_gate_digest_module" >&2
    return 2
  fi
  # shellcheck source=runtime/lib/gate-digest.sh
  # shellcheck disable=SC1091  # dependency path is resolved beside this module
  . "$_gate_digest_module"
  unset _gate_result_verify_dir _gate_digest_module
fi
if ! declare -F _gate_subject_tree_fingerprint >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-subject.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-subject.sh"
fi
#
# gate_result_verdict_verify <result_file> [expected_final] [route_label]
if ! declare -F pm_identifier_run_ere_pattern >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/identifier-policy.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/identifier-policy.sh"
fi
if ! declare -F gate_structural_schema_verify >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-structural-verify.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-structural-verify.sh"
fi
if ! declare -F gate_remediation_closure_verify >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-closure.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-closure.sh"
fi

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
  final_count=$(grep -cE '^Final: (GO|NO-GO|INCOMPLETE)$' "$result_file" || true)
  if [[ "$final_count" -ne 1 ]]; then
    printf 'Error: gate result file must contain exactly one Final: GO/NO-GO/INCOMPLETE line (found %d): %s\n' \
      "$final_count" "$result_file" >&2
    return 1
  fi
  frontmatter_final=$(awk 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } } s && $1 == "final:" { print $2; exit }' "$result_file")
  if [[ -z "$frontmatter_final" ]]; then
    printf 'Error: gate result YAML frontmatter missing required field: final: (%s)\n' "$result_file" >&2
    return 1
  fi
  body_final=$(grep -E '^Final: (GO|NO-GO|INCOMPLETE)$' "$result_file" | awk '{print $2}')
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

_gate_reviewer_protocol_surfaces() {
  printf '%s\n' \
    changed_files \
    paired_tests \
    sensitive_signals \
    public_interface \
    schema \
    config \
    install \
    ci \
    release \
    migration \
    bounded_expansion
}

_gate_reviewer_protocol_reference_index_json() {
  local manifest_file="$1" expected_sha="$2"
  local actual_sha manifest_ref line_count
  if [[ ! -f "$manifest_file" || -L "$manifest_file" ]]; then
    printf 'Error: reviewer protocol reference manifest is missing or unsafe: %s\n' \
      "$manifest_file" >&2
    return 1
  fi
  actual_sha="$(_gate_result_sha256_file "$manifest_file")" || return $?
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    printf 'Error: reviewer protocol reference manifest digest mismatch: %s\n' \
      "$manifest_file" >&2
    return 1
  fi
  manifest_ref=".gate-results/$(basename "$manifest_file")"
  line_count="$(awk 'END { print NR+0 }' "$manifest_file")"
  jq -c \
    --arg manifest_ref "$manifest_ref" \
    --arg manifest_sha "$actual_sha" \
    --argjson manifest_lines "$line_count" '
    if .reference_index.claim != "declared-review-reference-set" or
       (.reference_index.entries | type) != "array" or
       (.reference_index.entries | length) == 0
    then error("missing reviewer reference index: claim=" +
      (.reference_index.claim // "<missing>") + " entries=" +
      ((.reference_index.entries // []) | length | tostring))
    else
      ([.reference_index.entries[] | {
        path:.path,
        line_count:.line_count,
        sha256:.sha256
      }] + [{
        path:$manifest_ref,
        line_count:$manifest_lines,
        sha256:$manifest_sha
      }] | unique_by(.path) | sort_by(.path))
    end
  ' "$manifest_file" || {
    printf 'Error: reviewer protocol reference manifest has no valid index: %s\n' \
      "$manifest_file" >&2
    return 1
  }
}

# Fill empty test-gap existing_evidence from a finding with the same
# affected_behavior. That is a copy from an already-declared source, not a
# new citation. Do not invent contract/status/scenario values.
#
# Returns 0 on success (changed or already complete) and 2 on I/O failure.
# The caller persists a semantic change into the reviewer markdown so later
# synthesis restore copies the healed row rather than the empty one.
_gate_reviewer_heal_empty_existing_evidence() {
  local document=${1-} healed
  [[ $# -eq 1 && -s "$document" ]] || return 2
  healed="$(mktemp "${TMPDIR:-/tmp}/gate-reviewer-healed.XXXXXX")" || return 2
  if ! jq '
      . as $doc |
      if (.test_gaps | type) != "array" then .
      else
        .test_gaps |= map(
          . as $row |
          if (($row.existing_evidence | type) != "array" or
              ($row.existing_evidence | length) == 0) and
             (($row.affected_behavior | type) == "string")
          then
            ([($doc.findings // [])[]
              | select(.affected_behavior == $row.affected_behavior)
              | .source
              | select(type == "object")] | .[0]) as $src |
            if $src == null then $row
            else $row + {existing_evidence: [$src]}
            end
          else $row
          end)
      end
    ' "$document" > "$healed"; then
    rm -f -- "$healed"
    return 0
  fi
  if jq -n -e --slurpfile before "$document" --slurpfile after "$healed" \
      '$before[0] == $after[0]' >/dev/null 2>&1; then
    rm -f -- "$healed"
    return 0
  fi
  mv -- "$healed" "$document"
}

# Replace the Nth reviewer_result_v1 JSON body in <artifact> with <json_file>.
# Opening/closing fences stay in place. Fails closed if that fence pair cannot
# be located. Occurrence is 1-based in document order.
_gate_reviewer_replace_json_block() {
  local artifact=${1-} json_file=${2-} occurrence=${3-}
  local rewritten start_line end_line
  [[ $# -eq 3 && -s "$artifact" && -s "$json_file" \
      && "$occurrence" =~ ^[1-9][0-9]*$ ]] || return 2
  start_line="$(awk -v n="$occurrence" '
    $0 == "```reviewer_result_v1" { c++; if (c == n) { print NR; exit } }
  ' "$artifact")"
  end_line="$(awk -v start="$start_line" \
    'NR > start && $0 == "```" { print NR; exit }' "$artifact")"
  [[ "$start_line" =~ ^[1-9][0-9]*$ && "$end_line" =~ ^[1-9][0-9]*$ ]] || return 2
  [[ "$end_line" -gt "$start_line" ]] || return 2
  rewritten="$(mktemp "${TMPDIR:-/tmp}/gate-reviewer-rewritten.XXXXXX")" || return 2
  {
    sed -n "1,${start_line}p" "$artifact"
    cat "$json_file"
    sed -n "${end_line},\$p" "$artifact"
  } > "$rewritten" || {
    rm -f -- "$rewritten"
    return 2
  }
  mv -- "$rewritten" "$artifact"
}

_gate_reviewer_protocol_document_verify() {
  local document="$1" expected_reviewer="$2" expected_scope_sha="$3"
  local reference_index_json="${4:-null}"
  local require_test_gaps="${5:-false}"
  local surfaces_json validation parse_err jq_rc
  GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR=""
  surfaces_json="$(_gate_reviewer_protocol_surfaces | jq -Rsc '
    split("\n") | map(select(length > 0))
  ')" || return 2
  parse_err="$(mktemp "${TMPDIR:-/tmp}/gate-reviewer-json-parse.XXXXXX")" \
    || return 2
  if ! jq -e 'type == "object"' "$document" >/dev/null 2>"$parse_err"; then
    GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="invalid JSON document"
    if [[ -s "$parse_err" ]]; then
      GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="invalid JSON document: $(
        tr -cd 'A-Za-z0-9._: -' < "$parse_err" | tr -s '[:space:]' ' ' | head -c 160
      )"
    fi
    rm -f -- "$parse_err"
    return 1
  fi
  rm -f -- "$parse_err"
  if ! _gate_reviewer_heal_empty_existing_evidence "$document"; then
    return 2
  fi
  validation="$(jq -r \
    --arg reviewer "$expected_reviewer" \
    --arg scope_sha "$expected_scope_sha" \
    --argjson require_test_gaps "$require_test_gaps" \
    --argjson surfaces "$surfaces_json" \
    --argjson references "$reference_index_json" '
    def only_keys($allowed):
      type == "object" and ((keys_unsorted - $allowed) | length) == 0;
    def exact_keys($required):
      type == "object" and ((keys_unsorted | sort) == ($required | sort));
    def nonempty: type == "string" and length > 0;
    def relative_path:
      nonempty and (startswith("/") | not) and
      (test("(^|/)\\.\\.(/|$)") | not);
    def evidence_ref:
      only_keys(["path","line","symbol"]) and
      (.path | relative_path) and
      (.line == null or (.line | type == "number" and . >= 1 and floor == .)) and
      (.symbol == null or (.symbol | nonempty)) and
      (.line != null or .symbol != null);
    def coverage_entry:
      only_keys(["surface","status","evidence_refs","reason"]) and
      (.surface | IN($surfaces[])) and
      (.status | IN("examined","not_applicable","uncertain")) and
      (.reason | nonempty) and
      (.evidence_refs | type == "array" and all(.[]; evidence_ref)) and
      (if .status == "examined"
       then (.evidence_refs | length) > 0
       else true
       end);
    def finding:
      only_keys(["id","reviewer","severity","hard_gate_class","origin","source",
        "affected_behavior","why_it_matters","failure_mode",
        "minimum_fix_boundary","verification_expectation"]) and
      .reviewer == $reviewer and
      (.id | test("^" + $reviewer + "-F[0-9]{3}$")) and
      (.severity | IN("critical","high","medium","low")) and
      (.hard_gate_class | IN("none","soft_block","hard_block")) and
      (.origin | IN("diff_caused","pre_existing","uncertain","caution")) and
      (.source | evidence_ref) and
      (.affected_behavior | nonempty) and
      (.why_it_matters | nonempty) and
      (.failure_mode | nonempty) and
      (.minimum_fix_boundary | nonempty) and
      (.verification_expectation | nonempty) and
      (if .hard_gate_class == "none"
       then true
       else (.severity | IN("critical","high")) and
         (.origin | IN("diff_caused","uncertain"))
       end) and
      (if (.origin | IN("pre_existing","caution"))
       then .hard_gate_class == "none"
       else true
       end);
    def test_gap:
      only_keys(["id","reviewer","status","affected_behavior","contract",
        "existing_evidence","coverage_dimensions","missing_layer","scenario",
        "oracle","failure_signal","suggested_command"]) and
      .reviewer == $reviewer and
      (.id | test("^" + $reviewer + "-TG[0-9]{3}$")) and
      (.status | IN("gap","no_gap")) and
      (.affected_behavior | nonempty) and (.contract | nonempty) and
      (.existing_evidence | type == "array" and length > 0 and
        all(.[]; evidence_ref)) and
      (.coverage_dimensions | type == "array" and length > 0 and
        length == (unique | length) and
        all(.[]; IN("happy","boundary","negative","regression",
          "concurrency","security","migration","rollback"))) and
      (if .status == "gap"
       then (.missing_layer | IN("unit","integration","contract","e2e",
          "manual","operational")) and
         (.scenario | nonempty) and (.oracle | nonempty) and
         (.failure_signal | nonempty) and (.suggested_command | nonempty)
       else .missing_layer == "none" and .scenario == null and
         .oracle == null and .failure_signal == null and
         .suggested_command == null
       end);
    def envelope_contract:
      only_keys(["kind","schema_version","reviewer","scope_manifest_sha256",
        "coverage_claim","coverage","findings","test_gaps","verdict","rationale"]) and
      ((keys_unsorted | length) == 9 or
        (has("test_gaps") and (keys_unsorted | length) == 10)) and
      .kind == "gate_reviewer_result_v1" and .schema_version == 1 and
      .reviewer == $reviewer and
      .coverage_claim == "declared-scope-checklist-not-review-completeness";
    def coverage_contract:
      .coverage | type == "array" and length == ($surfaces | length) and
        all(.[]; coverage_entry) and
        ([.[].surface] | sort) == ($surfaces | sort);
    def finding_contract:
      .findings | type == "array" and all(.[]; finding) and
        ([.[].id] | length) == ([.[].id] | unique | length);
    def test_gap_contract:
      if has("test_gaps")
      then .test_gaps | type == "array" and length > 0 and
        all(.[]; test_gap) and
        ([.[].id] | length) == ([.[].id] | unique | length)
      else ($require_test_gaps | not)
      end;
    def finding_test_gap_contract:
      if has("test_gaps")
      then . as $document |
        [$document.findings[] | . as $finding |
          any($document.test_gaps[];
            .status == "gap" and
            .affected_behavior == $finding.affected_behavior)] | all
      else ($require_test_gaps | not)
      end;
    def unpaired_finding_ids:
      . as $document |
      if (($document.findings | type) != "array") or
         (($document.test_gaps | type) != "array")
      then []
      else
        [$document.findings[] | . as $finding |
          select([$document.test_gaps[] |
            select(.status == "gap" and
              .affected_behavior == $finding.affected_behavior)] |
            length == 0) | .id]
      end;
    def findings_array:
      if (.findings | type) == "array" then .findings else [] end;
    def blocking_severity_violation:
      [findings_array[] |
        select(
          (.hard_gate_class | IN("soft_block","hard_block")) and
          ((.severity | IN("critical","high")) | not)
        )
      ] | first;
    def blocking_origin_violation:
      [findings_array[] |
        select(
          (.hard_gate_class | IN("soft_block","hard_block")) and
          ((.origin | IN("diff_caused","uncertain")) | not)
        )
      ] | first;
    def display:
      if . == null
      then "<missing>"
      else (tostring | tojson | .[1:-1])
      end;
    # Name the exact test-gap row and constraint that failed, the way
    # blocking_severity_violation already does for findings. A reviewer told
    # only "invalid test-gap matrix contract" cannot tell which of ~10
    # constraints it broke, so its one retry tends to reproduce the same class
    # of error — repeatedly seen as a value borrowed from a SIBLING enum
    # (`missing_layer`/`contract` values placed in `coverage_dimensions`).
    # Reporting the field, the offending value, and the permitted set turns a
    # wasted retry into a correctable one.
    def test_gap_dimension_vocabulary:
      ["happy","boundary","negative","regression",
       "concurrency","security","migration","rollback"];
    def test_gap_layer_vocabulary:
      ["unit","integration","contract","e2e","manual","operational"];
    def test_gaps_array:
      if (.test_gaps | type) == "array" then .test_gaps else [] end;
    def test_gap_violation:
      [test_gaps_array[] | select(test_gap | not) |
        . as $row |
        (   if ($row.reviewer != $reviewer)
            then "reviewer=" + ($row.reviewer | display) +
                 " must equal " + $reviewer
            elif (($row.id | type) != "string" or
                  ($row.id | test("^" + $reviewer + "-TG[0-9]{3}$") | not))
            then "id=" + ($row.id | display) +
                 " must match " + $reviewer + "-TG###"
            elif (($row.status | IN("gap","no_gap")) | not)
            then "status=" + ($row.status | display) +
                 " must be one of: gap, no_gap"
            elif (($row.contract | type) != "string" or
                  ($row.contract | length) == 0)
            then "contract=" + ($row.contract | display) +
                 " must be a non-empty string"
            elif (($row.coverage_dimensions | type) != "array" or
                  ($row.coverage_dimensions | length) == 0)
            then "coverage_dimensions must be a non-empty array"
            elif ([$row.coverage_dimensions[] |
                   select(IN(test_gap_dimension_vocabulary[]) | not)] |
                  length) > 0
            then ([$row.coverage_dimensions[] |
                   select(IN(test_gap_dimension_vocabulary[]) | not)] |
                  join(", ")) as $bad |
                 "coverage_dimensions contains " + $bad +
                 " — permitted values are: " +
                 (test_gap_dimension_vocabulary | join(", ")) +
                 " (note: unit/integration/contract/e2e/manual/operational are" +
                 " missing_layer values, not coverage_dimensions)"
            elif (($row.coverage_dimensions | length) !=
                  ($row.coverage_dimensions | unique | length))
            then "coverage_dimensions must not repeat a value"
            elif ($row.status == "gap" and
                  (($row.missing_layer | IN(test_gap_layer_vocabulary[])) | not))
            then "missing_layer=" + ($row.missing_layer | display) +
                 " must be one of: " + (test_gap_layer_vocabulary | join(", "))
            elif ($row.status == "no_gap" and $row.missing_layer != "none")
            then "missing_layer=" + ($row.missing_layer | display) +
                 " must be \"none\" when status=no_gap"
            elif ($row.status == "no_gap" and
                  [$row.scenario, $row.oracle, $row.failure_signal,
                   $row.suggested_command] != [null, null, null, null])
            then "scenario/oracle/failure_signal/suggested_command must all be" +
                 " null when status=no_gap"
            elif ($row.status == "gap" and
                  [$row.scenario, $row.oracle, $row.failure_signal,
                   $row.suggested_command] | any(. == null or . == ""))
            then "scenario, oracle, failure_signal, and suggested_command are" +
                 " all required when status=gap"
            elif (($row.existing_evidence | type) != "array" or
                  ($row.existing_evidence | length) == 0)
            then "existing_evidence must be a non-empty array"
            else "row does not satisfy the test-gap contract"
            end) as $reason |
        {id: $row.id, reason: $reason}
      ] | first;
    def verdict_contract:
      (.verdict | IN("approve","advise","block-soft","block")) and
        (.rationale | nonempty) and
      (if .verdict == "block-soft"
       then any(.findings[]; .hard_gate_class == "soft_block")
       elif .verdict == "block"
       then any(.findings[]; .hard_gate_class == "hard_block")
       else all(.findings[]; .hard_gate_class == "none")
       end);
    def bound_evidence_ref:
      .path as $path |
      ($references | map(select(.path == $path)) | first) as $entry |
      $entry != null and
      (if .line != null then .line <= $entry.line_count else true end);
    def evidence_reference_contract:
      all(.coverage[].evidence_refs[]; bound_evidence_ref) and
      all(.findings[].source; bound_evidence_ref) and
      all((.test_gaps // [])[].existing_evidence[]; bound_evidence_ref);
    try (
    if (envelope_contract | not)
    then "invalid top-level or binding contract"
    elif .scope_manifest_sha256 != $scope_sha
    then "stale subject binding"
    elif (coverage_contract | not)
    then "invalid coverage contract"
    elif (blocking_severity_violation != null)
    then (blocking_severity_violation as $invalid |
      "invalid finding contract: " + ($invalid.id | display) +
      " hard_gate_class=" + ($invalid.hard_gate_class | display) +
      " requires severity=critical|high (got " +
      ($invalid.severity | display) + ")")
    elif (blocking_origin_violation != null)
    then (blocking_origin_violation as $invalid |
      "invalid finding contract: " + ($invalid.id | display) +
      " hard_gate_class=" + ($invalid.hard_gate_class | display) +
      " requires origin=diff_caused|uncertain (got " +
      ($invalid.origin | display) + ")")
    elif (finding_contract | not)
    then "invalid finding contract"
    elif (test_gap_contract | not)
    then (test_gap_violation as $invalid |
      if $invalid == null
      then "invalid test-gap matrix contract"
      else "invalid test-gap matrix contract: " + ($invalid.id | display) +
        ": " + $invalid.reason
      end)
    elif (finding_test_gap_contract | not)
    then "finding lacks actionable test-gap row" +
      (if (unpaired_finding_ids | length) == 0
       then ""
       else ": " + (unpaired_finding_ids | join(", "))
       end)
    elif $references != null and (evidence_reference_contract | not)
    then "invalid evidence reference contract"
    elif (verdict_contract | not)
    then "invalid verdict contract"
    else "ok"
    end
    ) catch (
      "reviewer protocol filter failed: " +
      ((. | tostring)
        | gsub("[^A-Za-z0-9._: -]"; "?")
        | if length > 160 then .[0:160] + "~" else . end)
    )
  ' "$document" 2>/dev/null)"
  jq_rc=$?
  if [[ "$jq_rc" -ne 0 ]]; then
    GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="reviewer protocol filter failed"
    return 1
  fi
  if [[ "$validation" != ok ]]; then
    GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="$validation"
    return 1
  fi
}

_gate_reviewer_protocol_documents() {
  local artifact="$1"
  awk '
    $0 == "```reviewer_result_v1" {
      if (inside) exit 2
      inside=1
      next
    }
    inside && $0 == "```" {
      inside=0
      print ""
      next
    }
    inside { print }
    END { if (inside) exit 2 }
  ' "$artifact"
}

_gate_reviewer_protocol_verdict_extract() {
  local artifact="$1" reviewer="$2" verdicts count
  verdicts="$(
    _gate_reviewer_protocol_documents "$artifact" |
      jq -r --arg reviewer "$reviewer" \
        'select(.reviewer == $reviewer) | .verdict // empty'
  )" || return 1
  count="$(printf '%s\n' "$verdicts" | awk 'NF { count++ } END { print count+0 }')"
  [[ "$count" -eq 1 ]] || return 1
  printf '%s\n' "$verdicts"
}

_gate_reviewer_protocol_final_extract() {
  local artifact="$1"
  _gate_reviewer_protocol_documents "$artifact" |
    jq -sr '
      map(.verdict) as $verdicts |
      if ($verdicts | any(. == "block" or . == "block-soft"))
      then "NO-GO"
      else "GO"
      end
    '
}

# gate_reviewer_protocol_verify <artifact> <selected-reviewers> <scope-sha256>
#                               [scope-manifest]
#
# Extract every exact reviewer_result_v1 fenced JSON block and verify that the
# selected reviewer set is represented once, with the complete declared-surface
# checklist and actionable finding fields. When the linked scope manifest has a
# reference index, every evidence path and line is bound to that immutable set.
# The optional fourth argument preserves readability for legacy v3 artifacts
# produced before reference indexes existed.
gate_reviewer_protocol_verify() {
  local artifact=${1-} selected=${2-} scope_sha=${3-} scope_manifest=${4-}
  local require_test_gaps=${5-false}
  local tmp_dir line block="" in_block=false count=0 reviewer expected document
  local seen=" " reference_index_json=null extracted i
  GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR=""
  [[ $# -ge 3 && $# -le 5 && -s "$artifact" && -n "$selected" \
      && "$scope_sha" =~ ^[a-f0-9]{64}$ ]] || {
    printf 'Error: reviewer protocol INCOMPLETE: invalid verifier inputs\n' >&2
    return 2
  }
  if [[ -n "$scope_manifest" ]]; then
    reference_index_json="$(
      _gate_reviewer_protocol_reference_index_json \
        "$scope_manifest" "$scope_sha"
    )" || return $?
  fi
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-reviewer-protocol.XXXXXX")" \
    || return 2
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == '```reviewer_result_v1' ]]; then
      if [[ "$in_block" == true ]]; then
        GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="malformed reviewer result fence"
        printf 'Error: reviewer protocol INCOMPLETE: nested result block in %s\n' \
          "$artifact" >&2
        rm -rf -- "$tmp_dir"
        return 1
      fi
      in_block=true
      block=""
      continue
    fi
    if [[ "$in_block" == true && "$line" == '```' ]]; then
      count=$((count + 1))
      printf '%s\n' "$block" > "$tmp_dir/$count.json"
      cp -- "$tmp_dir/$count.json" "$tmp_dir/${count}.extracted" || {
        rm -rf -- "$tmp_dir"
        return 2
      }
      in_block=false
      block=""
      continue
    fi
    if [[ "$in_block" == true ]]; then
      block="${block}${block:+$'\n'}${line}"
    fi
  done < "$artifact"
  if [[ "$in_block" == true ]]; then
    GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="truncated reviewer result"
    printf 'Error: reviewer protocol INCOMPLETE: unclosed result block in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  if [[ "$count" -eq 0 ]]; then
    GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="missing reviewer result"
    printf 'Error: reviewer protocol INCOMPLETE: no reviewer_result_v1 block in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  for ((i = 1; i <= count; i++)); do
    document="$tmp_dir/$i.json"
    reviewer="$(jq -r '.reviewer // empty' "$document" 2>/dev/null)" || {
      GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="invalid JSON document"
      printf 'Error: reviewer protocol INCOMPLETE: invalid JSON document in %s\n' \
        "$artifact" >&2
      rm -rf -- "$tmp_dir"
      return 1
    }
    if [[ -z "$reviewer" || " $selected " != *" $reviewer "* \
        || "$seen" == *" $reviewer "* ]]; then
      GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="invalid reviewer binding"
      printf 'Error: reviewer protocol INCOMPLETE: unexpected or duplicate reviewer %s in %s\n' \
        "${reviewer:-<missing>}" "$artifact" >&2
      rm -rf -- "$tmp_dir"
      return 1
    fi
    if ! _gate_reviewer_protocol_document_verify \
        "$document" "$reviewer" "$scope_sha" "$reference_index_json" \
        "$require_test_gaps"; then
      printf 'Error: reviewer protocol INCOMPLETE: %s for %s in %s\n' \
        "${GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR:-invalid reviewer document}" \
        "$reviewer" "$artifact" >&2
      rm -rf -- "$tmp_dir"
      return 1
    fi
    if ! gate_structural_schema_verify gate-reviewer-result "$document" \
        "reviewer protocol ($reviewer)"; then
      GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="schema structural contract failed"
      rm -rf -- "$tmp_dir"
      return 1
    fi
    # Persist a semantic heal into the on-disk markdown. Synthesis restore
    # copies test_gaps from that markdown, not from this tmp file.
    extracted="$tmp_dir/${i}.extracted"
    if ! jq -n -e --slurpfile before "$extracted" --slurpfile after "$document" \
        '$before[0] == $after[0]' >/dev/null 2>&1; then
      if ! _gate_reviewer_replace_json_block "$artifact" "$document" "$i"; then
        GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="failed to persist healed reviewer document"
        printf 'Error: reviewer protocol INCOMPLETE: failed to persist healed reviewer document for %s in %s\n' \
          "$reviewer" "$artifact" >&2
        rm -rf -- "$tmp_dir"
        return 2
      fi
    fi
    # CC-541: detect (from the already-parsed structured document, not a
    # later markdown re-scan) a qa-tester block/block-soft finding whose
    # own text cites the rules source as missing, while this orchestrator
    # separately host-confirmed QA_RULES_DIR exists and is readable. Sets
    # a script-global flag consumed once near the end of the run to print
    # a distinguishing diagnostic -- informational only, never alters this
    # function's verdict/return value.
    if [[ "$reviewer" == "qa-tester" && -n "${PM_DISPATCH_QA_RULES_DIR_HOST_CONFIRMED:-}" ]] && \
       jq -e '(.verdict == "block" or .verdict == "block-soft") and
         ((.findings // []) | any((.affected_behavior // "") + " " + (.why_it_matters // "")
           | test("QA_RULES_DIR|qa-testing-rules|AGENT\\.md"; "i")))' \
         "$document" >/dev/null 2>&1; then
      # shellcheck disable=SC2034  # consumed by pr-gate.sh after this function returns.
      PM_DISPATCH_QA_RULES_DIR_REVIEWER_GAP_DETECTED=1
    fi
    seen="${seen}${reviewer} "
  done
  for expected in $selected; do
    if [[ "$seen" != *" $expected "* ]]; then
      GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="missing selected reviewer"
      printf 'Error: reviewer protocol INCOMPLETE: missing selected reviewer %s in %s\n' \
        "$expected" "$artifact" >&2
      rm -rf -- "$tmp_dir"
      return 1
    fi
  done
  rm -rf -- "$tmp_dir"
}

_gate_synthesis_protocol_documents() {
  local artifact="$1"
  awk '
    $0 == "```synthesis_result_v1" {
      if (inside) exit 2
      inside=1
      next
    }
    inside && $0 == "```" {
      inside=0
      print ""
      next
    }
    inside { print }
    END { if (inside) exit 2 }
  ' "$artifact"
}

# Replace the single synthesis_result_v1 JSON body in <artifact> with <json_file>.
# The opening/closing fences stay in place so human sections after the block
# are preserved. Fails closed if the fence pair cannot be located.
_gate_synthesis_replace_json_block() {
  local artifact=${1-} json_file=${2-} rewritten start_line end_line
  [[ $# -eq 2 && -s "$artifact" && -s "$json_file" ]] || return 2
  start_line="$(awk '$0 == "```synthesis_result_v1" { print NR; exit }' "$artifact")"
  end_line="$(awk -v start="$start_line" \
    'NR > start && $0 == "```" { print NR; exit }' "$artifact")"
  [[ "$start_line" =~ ^[1-9][0-9]*$ && "$end_line" =~ ^[1-9][0-9]*$ ]] || return 2
  [[ "$end_line" -gt "$start_line" ]] || return 2
  rewritten="$(mktemp "${TMPDIR:-/tmp}/gate-synthesis-rewritten.XXXXXX")" || return 2
  {
    sed -n "1,${start_line}p" "$artifact"
    cat "$json_file"
    sed -n "${end_line},\$p" "$artifact"
  } > "$rewritten" || {
    rm -f -- "$rewritten"
    return 2
  }
  mv -- "$rewritten" "$artifact"
}

# True when <artifact> frontmatter points at a sibling assurance sidecar whose
# provenance.attestation is a non-empty filename. Used to refuse restore after
# publication. A missing sidecar or a null pointer is treated as in-flight.
_gate_synthesis_artifact_has_protected_attestation() {
  local artifact=${1-} pointer sidecar attestation
  [[ $# -eq 1 && -s "$artifact" ]] || return 1
  pointer="$(awk '
    /^---$/ {
      if (fence == 0) { fence=1; next }
      if (fence == 1) exit
    }
    fence == 1 && $1 == "gate_assurance:" { print $2; exit }
  ' "$artifact")"
  [[ -n "$pointer" ]] || return 1
  # Refuse path-shaped pointers the same way verify does: they are not a
  # same-directory sidecar name and must not be followed for a rewrite.
  if [[ "$pointer" == */* || "$pointer" == .* ]]; then
    return 0
  fi
  sidecar="$(dirname -- "$artifact")/$pointer"
  [[ -s "$sidecar" ]] || return 1
  attestation="$(jq -r '.provenance.attestation // empty' "$sidecar" 2>/dev/null)" \
    || return 1
  [[ -n "$attestation" ]]
}

# One-line stderr diagnostic of which copy-fields restore changed. Silent on
# no-op. Values are neutralized so they cannot break a later YAML brief.
_gate_synthesis_restore_copy_fields_log() {
  local before=${1-} after=${2-} summary
  [[ $# -eq 2 && -s "$before" && -s "$after" ]] || return 0
  summary="$(jq -n -r --slurpfile before "$before" --slurpfile after "$after" '
    def one_line:
      tostring
      | gsub("[^A-Za-z0-9._:,=+-]"; "?")
      | if length > 240 then .[0:240] + "~" else . end;
    ($before[0] // {}) as $b | ($after[0] // {}) as $a |
    [
      "coverage_matrix","reviewer_finding_inventory","test_gap_matrix",
      "findings_union","cautions","uncertainties","selected_reviewers",
      "not_reviewed_dimensions","verification_plan"
    ]
    | map(select($b[.] != $a[.]))
    | if length == 0 then "copied fields" else join(",") end
    | one_line
  ' 2>/dev/null)" || summary="copied fields"
  printf 'gate synthesis restore: updated %s\n' "$summary" >&2
}

# Overwrite synthesis fields that are mechanical copies of reviewer_result_v1
# documents. Typography/paraphrase in those fields is not a synthesis judgment
# and must not consume the single correction retry. Grouping, disagreement,
# confirmation, and subject-binding fields stay with synthesis.
#
# Call this on the live gate-run artifact BEFORE first protocol verify and
# attestation. Do not call it from later `pmctl gate verify`: rewriting a
# published result would invalidate the protected attestation digest.
#
# Returns 0 when restore is applied or safely skipped (invalid JSON is left
# for the verifier). Returns 2 on I/O failure or when the artifact already
# carries a protected attestation pointer -- rewriting a published result
# would invalidate that digest. Callers on verify/publish paths must not
# invoke this function.
gate_synthesis_restore_copy_fields() {
  local artifact=${1-} selected=${2-} skipped=${3-}
  local tmp_dir synthesis_documents reviewer_documents synthesis_document
  [[ $# -eq 3 && -s "$artifact" && -n "$selected" ]] || return 2
  if _gate_synthesis_artifact_has_protected_attestation "$artifact"; then
    printf 'Error: synthesis copy-field restore refused on attested artifact: %s\n' \
      "$artifact" >&2
    return 2
  fi
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-synthesis-restore.XXXXXX")" \
    || return 2
  synthesis_documents="$tmp_dir/synthesis.jsonl"
  reviewer_documents="$tmp_dir/reviewers.jsonl"
  synthesis_document="$tmp_dir/synthesis.json"
  if ! _gate_synthesis_protocol_documents "$artifact" \
      > "$synthesis_documents" \
      || ! jq -s -e 'length == 1' "$synthesis_documents" >/dev/null 2>&1; then
    rm -rf -- "$tmp_dir"
    return 0
  fi
  jq -s '.[0]' "$synthesis_documents" > "$synthesis_document" || {
    rm -rf -- "$tmp_dir"
    return 0
  }
  if ! _gate_reviewer_protocol_documents "$artifact" \
      > "$reviewer_documents" \
      || ! jq -s -e 'length > 0' "$reviewer_documents" >/dev/null 2>&1; then
    rm -rf -- "$tmp_dir"
    return 0
  fi
  _gate_synthesis_restore_copy_fields_into \
    "$artifact" "$synthesis_document" "$reviewer_documents" \
    "$selected" "$skipped"
  local rc=$?
  rm -rf -- "$tmp_dir"
  return "$rc"
}

_gate_synthesis_restore_copy_fields_into() {
  local artifact=${1-} synthesis_document=${2-} reviewer_documents=${3-}
  local selected=${4-} skipped=${5-} healed
  [[ $# -eq 5 && -s "$artifact" && -s "$synthesis_document" \
      && -s "$reviewer_documents" ]] || return 2
  jq -e 'type == "object"' "$synthesis_document" >/dev/null 2>&1 || return 0
  healed="$(mktemp "${TMPDIR:-/tmp}/gate-synthesis-healed.XXXXXX")" || return 2
  if ! jq --arg selected "$selected" --arg skipped "$skipped" \
      --slurpfile reviewers "$reviewer_documents" '
      def nonempty_words($raw):
        $raw | split(" ") | map(select(length > 0));
      def findings:
        [$reviewers[] | (.findings // [])[]];
      def finding_by_id($id):
        findings | map(select(.id == $id)) | .[0];
      def coverage_cells:
        [$reviewers[] as $rev |
          ($rev.coverage // [])[] |
          {
            reviewer:$rev.reviewer,
            surface,
            status,
            evidence_refs,
            reason
          }]
        | sort_by(.reviewer, .surface);
      def inventory:
        findings
        | sort_by(.id)
        | map({
            id,
            reviewer,
            severity,
            hard_gate_class,
            origin,
            verification_expectation
          });
      # Keep in sync with _gate_reviewer_heal_empty_existing_evidence: empty
      # existing_evidence is filled from a same-behavior finding source so
      # restore does not copy a still-empty row if persist was skipped.
      def heal_test_gaps($findings):
        map(
          . as $row |
          if (($row.existing_evidence | type) != "array" or
              ($row.existing_evidence | length) == 0) and
             (($row.affected_behavior | type) == "string")
          then
            ([($findings // [])[]
              | select(.affected_behavior == $row.affected_behavior)
              | .source
              | select(type == "object")] | .[0]) as $src |
            if $src == null then $row
            else $row + {existing_evidence: [$src]}
            end
          else $row
          end
        );
      def gaps:
        [$reviewers[] | . as $rev |
          ((($rev.test_gaps // []) | heal_test_gaps($rev.findings))[])]
        | sort_by(.id);
      def uncertain_ids:
        findings | map(select(.origin == "uncertain") | .id) | sort;
      def uncertain_cells:
        [$reviewers[] as $rev |
          ($rev.coverage // [])[] |
          select(.status == "uncertain") |
          {reviewer:$rev.reviewer, surface, reason}]
        | sort_by(.reviewer, .surface);
      def caution_ids:
        findings | map(select(.origin == "caution") | .id);
      .coverage_matrix = coverage_cells
      | .reviewer_finding_inventory = inventory
      | .cautions = caution_ids
      | .selected_reviewers = nonempty_words($selected)
      | .not_reviewed_dimensions = nonempty_words($skipped)
      | if (gaps | length) > 0 then
          .test_gap_matrix = gaps
          | if (.verification_plan | type) == "object" then
              .verification_plan.focused =
                (gaps | map(select(.status == "gap") | .suggested_command)
                  | unique | sort)
            else .
            end
        else .
        end
      | if (.findings_union | type) == "array" then
          .findings_union |= map(
            . as $union |
            finding_by_id($union.id) as $src |
            if $src == null then $union
            else {
              id:$src.id,
              reviewer:$src.reviewer,
              severity:$src.severity,
              hard_gate_class:$src.hard_gate_class,
              origin:$src.origin,
              source:$src.source,
              affected_behavior:$src.affected_behavior,
              why_it_matters:$src.why_it_matters,
              failure_mode:$src.failure_mode,
              minimum_fix_boundary:$src.minimum_fix_boundary,
              verification_expectation:$src.verification_expectation,
              root_cause_group_id:$union.root_cause_group_id,
              disposition:"pending"
            }
            end)
        else .
        end
      | if (.uncertainties | type) == "array" then .
        else
          .uncertainties = {
            finding_ids:uncertain_ids,
            coverage_cells:uncertain_cells
          }
        end
      | if ((.remediation_seed | type) == "object") and
            ((.remediation_seed.entries | type) == "array") then
          .remediation_seed.entries |= map(
            finding_by_id(.finding_id) as $src |
            if $src == null then .
            else {
              finding_id:$src.id,
              reviewer:$src.reviewer,
              root_cause_group_id,
              disposition:"pending",
              verification_expectation:$src.verification_expectation
            }
            end)
        else .
        end
    ' "$synthesis_document" > "$healed"; then
    rm -f -- "$healed"
    return 0
  fi
  if jq -n -e --slurpfile before "$synthesis_document" --slurpfile after "$healed" \
      '$before[0] == $after[0]' >/dev/null 2>&1; then
    rm -f -- "$healed"
    return 0
  fi
  _gate_synthesis_restore_copy_fields_log "$synthesis_document" "$healed"
  if ! _gate_synthesis_replace_json_block "$artifact" "$healed"; then
    rm -f -- "$healed"
    return 2
  fi
  mv -- "$healed" "$synthesis_document"
}

# gate_synthesis_protocol_verify <artifact> <selected-reviewers>
#                                <skipped-reviewers> <scope-sha256>
#                                [require-test-gaps] [initial-finding-ids-json]
#
# Validates the synthesis-owned JSON shape against the original
# reviewer_result_v1 documents. Copied coverage/inventory fields should already
# have been restored by gate_synthesis_restore_copy_fields on the live gate
# path. Root-cause grouping and disagreement prose remain synthesis judgments,
# but every referenced ID must belong to that immutable inventory and every
# finding must be grouped exactly once.
gate_synthesis_protocol_verify() {
  local artifact=${1-} selected=${2-} skipped=${3-} scope_sha=${4-}
  local require_test_gaps=${5-false}
  local initial_finding_ids=${6-null}
  local tmp_dir synthesis_documents synthesis_document reviewer_documents synthesis_count validation
  local heading heading_count
  GATE_SYNTHESIS_PROTOCOL_ERROR=""
  [[ $# -ge 4 && $# -le 6 && -s "$artifact" && -n "$selected" \
      && "$scope_sha" =~ ^[a-f0-9]{64}$ ]] || {
    printf 'Error: synthesis protocol INCOMPLETE: invalid verifier inputs\n' >&2
    return 2
  }
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-synthesis-protocol.XXXXXX")" \
    || return 2
  synthesis_documents="$tmp_dir/synthesis.jsonl"
  reviewer_documents="$tmp_dir/reviewers.jsonl"
  if ! _gate_synthesis_protocol_documents "$artifact" \
      > "$synthesis_documents"; then
    GATE_SYNTHESIS_PROTOCOL_ERROR="malformed synthesis result fence"
    printf 'Error: synthesis protocol INCOMPLETE: malformed synthesis_result_v1 fence in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  synthesis_count="$(jq -s 'length' "$synthesis_documents" 2>/dev/null)" || {
    GATE_SYNTHESIS_PROTOCOL_ERROR="invalid synthesis JSON"
    printf 'Error: synthesis protocol INCOMPLETE: invalid synthesis JSON in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  }
  if [[ "$initial_finding_ids" != null ]] && ! jq -e \
      'type == "array" and length == (unique | length) and
       all(.[]; type == "string" and test("^(critic|qa-tester|architecture-reviewer|security-reviewer|risk-reviewer)-F[0-9]{3,}$"))' \
      <<<"$initial_finding_ids" >/dev/null 2>&1; then
    GATE_SYNTHESIS_PROTOCOL_ERROR="invalid initial finding ID set"
    printf 'Error: synthesis protocol INCOMPLETE: invalid initial finding ID set\n' >&2
    return 1
  fi
  if [[ "$synthesis_count" -ne 1 ]]; then
    GATE_SYNTHESIS_PROTOCOL_ERROR="missing or duplicate synthesis result"
    printf 'Error: synthesis protocol INCOMPLETE: expected one synthesis_result_v1 block, found %d in %s\n' \
      "$synthesis_count" "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  synthesis_document="$tmp_dir/synthesis.json"
  jq -s '.[0]' "$synthesis_documents" > "$synthesis_document" || {
    GATE_SYNTHESIS_PROTOCOL_ERROR="invalid synthesis JSON"
    rm -rf -- "$tmp_dir"
    return 1
  }
  if ! _gate_reviewer_protocol_documents "$artifact" \
      > "$reviewer_documents" \
      || ! jq -s -e 'length > 0' "$reviewer_documents" >/dev/null 2>&1; then
    GATE_SYNTHESIS_PROTOCOL_ERROR="reviewer documents unavailable"
    printf 'Error: synthesis protocol INCOMPLETE: reviewer documents unavailable in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi

  validation="$(
    jq -nr \
      --arg selected "$selected" --arg skipped "$skipped" \
      --arg scope_sha "$scope_sha" \
      --argjson require_test_gaps "$require_test_gaps" \
      --argjson initial_finding_ids "$initial_finding_ids" \
      --slurpfile synthesis "$synthesis_documents" \
      --slurpfile reviewers "$reviewer_documents" '
      def only_keys($allowed):
        type == "object" and ((keys_unsorted - $allowed) | length) == 0;
      def nonempty: type == "string" and length > 0;
      def reviewer:
        IN("critic","qa-tester","architecture-reviewer",
          "security-reviewer","risk-reviewer");
      def surface:
        IN("changed_files","paired_tests","sensitive_signals",
          "public_interface","schema","config","install","ci","release",
          "migration","bounded_expansion");
      def finding_id:
        type == "string" and
        test("^(critic|qa-tester|architecture-reviewer|security-reviewer|risk-reviewer)-F[0-9]{3,}$");
      def reference:
        only_keys(["path","line","symbol"]) and
        (.path | nonempty) and
        ((.line | type == "number" and . >= 1 and floor == .) or
         (.symbol | nonempty));
      def coverage_cell:
        only_keys(["reviewer","surface","status","evidence_refs","reason"]) and
        (.reviewer | reviewer) and (.surface | surface) and
        (.status | IN("examined","not_applicable","uncertain")) and
        (.evidence_refs | type == "array" and all(.[]; reference)) and
        (.reason | nonempty);
      def finding_inventory:
        only_keys(["id","reviewer","severity","hard_gate_class","origin",
          "verification_expectation"]) and
        (.id | finding_id) and (.reviewer | reviewer) and
        (.severity | IN("critical","high","medium","low")) and
        (.hard_gate_class | IN("none","soft_block","hard_block")) and
        (.origin | IN("diff_caused","pre_existing","uncertain","caution")) and
        (.verification_expectation | nonempty);
      def finding_union:
        only_keys(["id","reviewer","severity","hard_gate_class","origin",
          "source","affected_behavior","why_it_matters","failure_mode",
          "minimum_fix_boundary","verification_expectation",
          "root_cause_group_id","disposition"]) and
        (.id | finding_id) and (.reviewer | reviewer) and
        (.severity | IN("critical","high","medium","low")) and
        (.hard_gate_class | IN("none","soft_block","hard_block")) and
        (.origin | IN("diff_caused","pre_existing","uncertain","caution")) and
        (.source | reference) and
        (.affected_behavior | nonempty) and (.why_it_matters | nonempty) and
        (.failure_mode | nonempty) and (.minimum_fix_boundary | nonempty) and
        (.verification_expectation | nonempty) and
        (.root_cause_group_id |
          type == "string" and test("^RCG-[0-9]{3,}$")) and
        .disposition == "pending";
      def root_group:
        only_keys(["id","summary","finding_ids"]) and
        (.id | type == "string" and test("^RCG-[0-9]{3,}$")) and
        (.summary | nonempty) and
        (.finding_ids | type == "array" and length > 0 and
          length == (unique | length) and all(.[]; finding_id));
      # Every id quoted in a diagnostic comes from the REJECTED artifact, and a
      # rejected artifact is precisely where malformed values live: the
      # disagreement branch selects entries that FAILED the shape contract, so
      # their .id may be any JSON value, including a string with newlines. The
      # reason is then carried across a trust boundary into the next agent
      # brief, so reduce each quoted value to a bounded, single-line,
      # punctuation-free token before it can be embedded. Never echo an
      # artifact field verbatim.
      def safe_token:
        (if type == "string" then . else tojson end)
        | gsub("[^A-Za-z0-9._:-]"; "?")
        | if length > 64 then .[0:64] + "~" else . end;
      def safe_join($ids): ($ids | map(safe_token) | join(","));
      # A parity reason names WHICH ids differ, and separates "wrong id set"
      # from "right ids, wrong field values" -- two defects with different
      # fixes. Synthesis gets exactly one correction retry; a reason it cannot
      # act on spends that retry reproducing the same output. Single-line by
      # contract: the reason is embedded in the retry brief YAML block.
      def id_delta($want; $got; $same_set_hint):
        (($want - $got) | unique) as $missing |
        (($got - $want) | unique) as $unexpected |
        if ($missing | length) == 0 and ($unexpected | length) == 0
        then ": id sets match, so a field value differs -- " + $same_set_hint
        else ": missing=[" + safe_join($missing) +
             "] unexpected=[" + safe_join($unexpected) + "]"
        end;
      def coverage_index($rows):
        [$rows[] | {key:(.reviewer + ":" + .surface), value:.}] | from_entries;
      def first_coverage_field_diff($want; $got):
        coverage_index($want) as $w |
        coverage_index($got) as $g |
        ([
          ($w | keys_unsorted[]) as $k |
          select(($g | has($k)) and $w[$k] != $g[$k]) |
          $k + (
            if $w[$k].status != $g[$k].status then ".status"
            elif $w[$k].evidence_refs != $g[$k].evidence_refs then ".evidence_refs"
            else ".reason"
            end
          )
        ] | .[0]) // "unknown field";
      # Same rationale as disagreement_defect below: naming the array a shape
      # check failed in is not enough when the entry contract bundles several
      # independent rules -- report the first violated rule with the observed
      # value so the sole correction retry knows which field to fix.
      def coverage_cell_defect:
        if (type != "object")
        then "entry is " + (type) + ", expected an object"
        elif (only_keys(["reviewer","surface","status","evidence_refs","reason"]) | not)
        then "keys are [" + safe_join((keys_unsorted // [])) +
          "], expected exactly reviewer/surface/status/evidence_refs/reason"
        elif ((.reviewer | reviewer) | not)
        then "reviewer=" + (.reviewer | safe_token) + " is not a known reviewer"
        elif ((.surface | surface) | not)
        then "surface=" + (.surface | safe_token) + " is not a known surface"
        elif ((.status | IN("examined","not_applicable","uncertain")) | not)
        then "status=" + (.status | safe_token) +
          " is not one of examined/not_applicable/uncertain"
        elif (((.evidence_refs | type) != "array") or
              ((.evidence_refs | all(.[]; reference)) | not))
        then "evidence_refs is not an array of valid references"
        else "reason is empty"
        end;
      def finding_inventory_defect:
        if (type != "object")
        then "entry is " + (type) + ", expected an object"
        elif (only_keys(["id","reviewer","severity","hard_gate_class","origin",
              "verification_expectation"]) | not)
        then "keys are [" + safe_join((keys_unsorted // [])) +
          "], expected exactly id/reviewer/severity/hard_gate_class/origin/verification_expectation"
        elif ((.id | finding_id) | not)
        then "id=" + (.id | safe_token) + " does not match a known finding id shape"
        elif ((.reviewer | reviewer) | not)
        then "reviewer=" + (.reviewer | safe_token) + " is not a known reviewer"
        elif ((.severity | IN("critical","high","medium","low")) | not)
        then "severity=" + (.severity | safe_token) +
          " is not one of critical/high/medium/low"
        elif ((.hard_gate_class | IN("none","soft_block","hard_block")) | not)
        then "hard_gate_class=" + (.hard_gate_class | safe_token) +
          " is not one of none/soft_block/hard_block"
        elif ((.origin | IN("diff_caused","pre_existing","uncertain","caution")) | not)
        then "origin=" + (.origin | safe_token) +
          " is not one of diff_caused/pre_existing/uncertain/caution"
        else "verification_expectation is empty"
        end;
      def finding_union_defect:
        if (type != "object")
        then "entry is " + (type) + ", expected an object"
        elif (only_keys(["id","reviewer","severity","hard_gate_class","origin",
              "source","affected_behavior","why_it_matters","failure_mode",
              "minimum_fix_boundary","verification_expectation",
              "root_cause_group_id","disposition"]) | not)
        then "keys are [" + safe_join((keys_unsorted // [])) +
          "], expected exactly id/reviewer/severity/hard_gate_class/origin/source/" +
          "affected_behavior/why_it_matters/failure_mode/minimum_fix_boundary/" +
          "verification_expectation/root_cause_group_id/disposition"
        elif ((.id | finding_id) | not)
        then "id=" + (.id | safe_token) + " does not match a known finding id shape"
        elif ((.reviewer | reviewer) | not)
        then "reviewer=" + (.reviewer | safe_token) + " is not a known reviewer"
        elif ((.severity | IN("critical","high","medium","low")) | not)
        then "severity=" + (.severity | safe_token) +
          " is not one of critical/high/medium/low"
        elif ((.hard_gate_class | IN("none","soft_block","hard_block")) | not)
        then "hard_gate_class=" + (.hard_gate_class | safe_token) +
          " is not one of none/soft_block/hard_block"
        elif ((.origin | IN("diff_caused","pre_existing","uncertain","caution")) | not)
        then "origin=" + (.origin | safe_token) +
          " is not one of diff_caused/pre_existing/uncertain/caution"
        elif ((.source | reference) | not)
        then "source is not a valid reference"
        elif ((.affected_behavior | nonempty) | not)
        then "affected_behavior is empty"
        elif ((.why_it_matters | nonempty) | not)
        then "why_it_matters is empty"
        elif ((.failure_mode | nonempty) | not)
        then "failure_mode is empty"
        elif ((.minimum_fix_boundary | nonempty) | not)
        then "minimum_fix_boundary is empty"
        elif ((.verification_expectation | nonempty) | not)
        then "verification_expectation is empty"
        elif ((.root_cause_group_id | type == "string" and test("^RCG-[0-9]{3,}$")) | not)
        then "root_cause_group_id=" + (.root_cause_group_id | safe_token) +
          " does not match ^RCG-[0-9]{3,}$"
        else "disposition=" + (.disposition | safe_token) + ", expected pending"
        end;
      # Naming the offending entry is not enough: the entry contract bundles six
      # independent rules, so "it fails the contract" still leaves the sole
      # correction retry guessing which one. Report the first violated rule with
      # the observed value. `finding_ids` length is the rule most often tripped
      # innocently -- a single reviewer raising a lone objection naturally writes
      # one id -- so it says why two are required rather than restating the bound.
      def disagreement_defect:
        if (type != "object")
        then "entry is " + (type) + ", expected an object"
        elif (only_keys(["id","summary","finding_ids"]) | not)
        then "keys are [" + safe_join((keys_unsorted // [])) +
             "], expected exactly id/summary/finding_ids"
        elif (((.id | type) != "string") or ((.id | test("^D-[0-9]{3,}$")) | not))
        then "id=" + (.id | safe_token) + " does not match ^D-[0-9]{3,}$"
        elif ((.summary | nonempty) | not)
        then "summary is empty"
        elif ((.finding_ids | type) != "array")
        then "finding_ids is " + (.finding_ids | type) + ", expected an array"
        elif ((.finding_ids | length) < 2)
        then "finding_ids has " + (.finding_ids | length | tostring) +
             " id(s); a disagreement records two or more findings in conflict, so a lone objection is a finding, not a disagreement"
        elif ((.finding_ids | length) != (.finding_ids | unique | length))
        then "finding_ids repeats an id"
        else "finding_ids contains a value that is not a known finding id: [" +
             safe_join([.finding_ids[] | select(finding_id | not)]) + "]"
        end;
      def disagreement:
        only_keys(["id","summary","finding_ids"]) and
        (.id | type == "string" and test("^D-[0-9]{3,}$")) and
        (.summary | nonempty) and
        (.finding_ids | type == "array" and length >= 2 and
          length == (unique | length) and all(.[]; finding_id));
      def uncertain_cell:
        only_keys(["reviewer","surface","reason"]) and
        (.reviewer | reviewer) and (.surface | surface) and
        (.reason | nonempty);
      def seed_entry:
        only_keys(["finding_id","reviewer","root_cause_group_id",
          "disposition","verification_expectation"]) and
        (.finding_id | finding_id) and (.reviewer | reviewer) and
        (.root_cause_group_id |
          type == "string" and test("^RCG-[0-9]{3,}$")) and
        .disposition == "pending" and
        (.verification_expectation | nonempty);
      def test_gap:
        only_keys(["id","reviewer","status","affected_behavior","contract",
          "existing_evidence","coverage_dimensions","missing_layer","scenario",
          "oracle","failure_signal","suggested_command"]) and
        (.id | type == "string" and
          test("^(critic|qa-tester|architecture-reviewer|security-reviewer|risk-reviewer)-TG[0-9]{3}$")) and
        (.reviewer | reviewer) and (.status | IN("gap","no_gap")) and
        (.affected_behavior | nonempty) and (.contract | nonempty) and
        (.existing_evidence | type == "array" and length > 0 and
          all(.[]; reference)) and
        (.coverage_dimensions | type == "array" and length > 0 and
          length == (unique | length) and
          all(.[]; IN("happy","boundary","negative","regression",
            "concurrency","security","migration","rollback"))) and
        (if .status == "gap"
         then (.missing_layer | IN("unit","integration","contract","e2e",
            "manual","operational")) and
           (.scenario | nonempty) and (.oracle | nonempty) and
           (.failure_signal | nonempty) and (.suggested_command | nonempty)
         else .missing_layer == "none" and .scenario == null and
           .oracle == null and .failure_signal == null and
           .suggested_command == null
         end);
      def string_array:
        type == "array" and length == (unique | length) and all(.[]; nonempty);
      ($selected | split(" ") | map(select(length > 0))) as $selected_reviewers |
      ($skipped | split(" ") | map(select(length > 0))) as $skipped_reviewers |
      $synthesis[0] as $s |
      ([$reviewers[] as $review |
        $review.coverage[] |
        {
          reviewer:$review.reviewer,
          surface:.surface,
          status:.status,
          evidence_refs:.evidence_refs,
          reason:.reason
        }
      ] | sort_by(.reviewer,.surface)) as $expected_coverage |
      ([$reviewers[] | .findings[]] | sort_by(.id)) as $expected_findings |
      ($expected_findings | map({
        id,reviewer,severity,hard_gate_class,origin,verification_expectation
      })) as $expected_inventory |
      ($expected_findings | map({
        id,reviewer,severity,hard_gate_class,origin,source,affected_behavior,
        why_it_matters,failure_mode,minimum_fix_boundary,
        verification_expectation
      })) as $expected_union |
      ($expected_findings |
        map(select(.origin == "uncertain") | .id) | sort) as $expected_uncertain_ids |
      ([$reviewers[] as $review |
        $review.coverage[] |
        select(.status == "uncertain") |
        {reviewer:$review.reviewer,surface:.surface,reason:.reason}
      ] | sort_by(.reviewer,.surface)) as $expected_uncertain_coverage |
      ($expected_findings |
        map(select(.origin == "caution") | .id) | sort) as $expected_cautions |
      ($expected_findings | map(.id) | sort) as $expected_ids |
      ([$reviewers[] | (.test_gaps // [])[]] | sort_by(.id)) as $expected_test_gaps |
      ($expected_test_gaps | map(select(.status == "gap") | .suggested_command) |
        unique | sort) as $expected_focused |
      if
        ($s | only_keys([
          "kind","schema_version","scope_manifest_sha256",
          "selected_reviewers","not_reviewed_dimensions","coverage_matrix",
          "reviewer_finding_inventory","findings_union","remediation_confirmations",
          "root_cause_groups",
          "disagreements","uncertainties","cautions","test_gap_matrix",
          "operational_cautions","user_cautions","verification_plan",
          "remediation_seed"
        ]) | not) or
        $s.kind != "gate_synthesis_result_v1" or
        $s.schema_version != 1 or
        ($s.scope_manifest_sha256 |
          type != "string" or test("^[a-f0-9]{64}$") | not) or
        ($s.selected_reviewers | type) != "array" or
        ($s.not_reviewed_dimensions | type) != "array" or
        ($s.coverage_matrix | type) != "array" or
        ($s.reviewer_finding_inventory | type) != "array" or
        ($s.findings_union | type) != "array" or
        ($s.remediation_confirmations | type) != "array" or
        ($s.root_cause_groups | type) != "array" or
        ($s.disagreements | type) != "array" or
        ($s.cautions | type) != "array" or
        ($s.remediation_seed | type) != "object" or
        (if $require_test_gaps
         then ($s | has("test_gap_matrix") and has("operational_cautions") and
           has("user_cautions") and has("verification_plan")) | not
         else false
         end)
      then "invalid top-level contract"
      elif $s.scope_manifest_sha256 != $scope_sha
      then "stale subject binding"
      elif
        $s.selected_reviewers != $selected_reviewers or
        $s.not_reviewed_dimensions != $skipped_reviewers
      then "selected/not-reviewed dimensions mismatch" +
        (if $s.selected_reviewers != $selected_reviewers
         then " (selected_reviewers)" +
           id_delta($selected_reviewers; $s.selected_reviewers;
             "selected_reviewers must copy the resolved list verbatim")
         else " (not_reviewed_dimensions)" +
           id_delta($skipped_reviewers; $s.not_reviewed_dimensions;
             "not_reviewed_dimensions must copy the skipped list verbatim")
         end)
      elif
        (all($s.coverage_matrix[]; coverage_cell) | not)
      then "invalid coverage matrix: " +
        ([$s.coverage_matrix[] | select(coverage_cell | not) |
            "entry " + ((.reviewer? // "no-reviewer") | safe_token) + "/" +
              ((.surface? // "no-surface") | safe_token) + ": " +
              coverage_cell_defect]
          | join("; "))
      elif
        ($s.coverage_matrix | sort_by(.reviewer,.surface)) != $expected_coverage
      then "coverage matrix parity mismatch" +
        id_delta(($expected_coverage | map(.reviewer + ":" + .surface));
                 ($s.coverage_matrix | map(.reviewer + ":" + .surface));
                 "first drifted cell: " +
                   first_coverage_field_diff($expected_coverage; $s.coverage_matrix))
      elif
        (all($s.reviewer_finding_inventory[]; finding_inventory) | not) or
        (all($s.findings_union[]; finding_union) | not)
      then "invalid finding inventory or union: " +
        (([$s.reviewer_finding_inventory[] | select(finding_inventory | not) |
             "inventory entry " + ((.id? // "no-id") | safe_token) + ": " +
               finding_inventory_defect] +
          [$s.findings_union[] | select(finding_union | not) |
             "union entry " + ((.id? // "no-id") | safe_token) + ": " +
               finding_union_defect])
         | join("; "))
      elif
        (($s.reviewer_finding_inventory | map(.id)) |
          length != (unique | length)) or
        (($s.findings_union | map(.id)) |
          length != (unique | length))
      then "duplicate finding ID collision: " +
        (([if (($s.reviewer_finding_inventory | map(.id)) |
                length != (unique | length))
           then "inventory duplicate id: [" +
             safe_join(($s.reviewer_finding_inventory | map(.id) |
               group_by(.) | map(select(length > 1) | .[0]))) + "]"
           else empty
           end] +
          [if (($s.findings_union | map(.id)) |
                length != (unique | length))
           then "union duplicate id: [" +
             safe_join(($s.findings_union | map(.id) |
               group_by(.) | map(select(length > 1) | .[0]))) + "]"
           else empty
           end])
         | join("; "))
      elif
        (all($s.remediation_confirmations[];
          (type == "object" and
           (keys_unsorted - ["finding_id","status","summary","evidence_refs"] | length) == 0 and
           (.finding_id | finding_id) and .status == "confirmed" and
           (.summary | nonempty) and
           (.evidence_refs | type == "array" and length > 0 and all(.[]; reference)))) | not)
      then "invalid remediation confirmation"
      elif
        (($s.remediation_confirmations | map(.finding_id)) |
          length != (unique | length))
      then "duplicate remediation confirmation ID"
      elif $initial_finding_ids != null and
        (($s.remediation_confirmations | map(.finding_id) | sort) !=
          ($initial_finding_ids | sort))
      then "remediation confirmation set mismatch"
      elif
        ($s.reviewer_finding_inventory | sort_by(.id)) != $expected_inventory
      then "reviewer finding inventory parity mismatch" +
        id_delta(($expected_inventory | map(.id));
                 ($s.reviewer_finding_inventory | map(.id));
                 "every inventory entry must copy each reviewer finding field verbatim")
      elif
        ($s.findings_union |
          map(del(.root_cause_group_id,.disposition)) | sort_by(.id)) !=
          $expected_union
      then "findings union parity mismatch" +
        id_delta(($expected_union | map(.id));
                 ($s.findings_union | map(.id));
                 "every union entry must copy each reviewer finding field verbatim and add only root_cause_group_id and disposition")
      elif
        (all($s.root_cause_groups[]; root_group) | not) or
        (($s.root_cause_groups | map(.id)) |
          length != (unique | length)) or
        ([$s.root_cause_groups[].finding_ids[]] | sort) != $expected_ids or
        (([$s.root_cause_groups[].finding_ids[]] | length) !=
          ([$s.root_cause_groups[].finding_ids[]] | unique | length)) or
        ([$s.findings_union[] as $finding |
          any($s.root_cause_groups[];
            .id == $finding.root_cause_group_id and
            ((.finding_ids | index($finding.id)) != null))
        ] | all | not)
      then "root-cause grouping parity mismatch" +
        ([$s.root_cause_groups[].finding_ids[]] as $grouped |
         if (($s.root_cause_groups | map(.id)) | length != (unique | length))
         then ": duplicate root-cause group id: [" +
           safe_join(($s.root_cause_groups | map(.id) | group_by(.) |
             map(select(length > 1) | .[0]))) + "]"
         elif (($grouped | length) != ($grouped | unique | length))
         then ": a finding is grouped more than once: [" +
           safe_join(($grouped | group_by(.) | map(select(length > 1) | .[0]))) + "]"
         elif (($grouped | sort) != $expected_ids)
         then id_delta($expected_ids; ($grouped | unique);
                "every reviewer finding must appear in exactly one group")
         else ": findings whose root_cause_group_id names no group holding them: [" +
           safe_join([$s.findings_union[] | . as $f |
             select(any($s.root_cause_groups[];
               .id == $f.root_cause_group_id and
               ((.finding_ids | index($f.id)) != null)) | not) | .id]) + "]"
         end)
      elif
        (all($s.disagreements[]; disagreement) | not) or
        (($s.disagreements | map(.id)) |
          length != (unique | length)) or
        ([$s.disagreements[].finding_ids[] as $finding_id |
          ($expected_ids | index($finding_id)) != null
        ] | all | not)
      then "invalid disagreement references: " +
        (if (all($s.disagreements[]; disagreement) | not)
         then ([$s.disagreements[] | select(disagreement | not) |
             "entry " + ((.id? // "no-id") | safe_token) + ": " + disagreement_defect]
           | join("; "))
         elif (($s.disagreements | map(.id)) | length != (unique | length))
         then "duplicate disagreement id: [" +
           safe_join(($s.disagreements | map(.id) | group_by(.) | map(select(length > 1) | .[0]))) +
           "]"
         else "finding_ids cite ids that are not in the reviewer findings: [" +
           safe_join((([$s.disagreements[].finding_ids[]] | unique) - $expected_ids)) +
           "]"
         end)
      elif
        ($s.uncertainties | type) != "object" or
        ($s.uncertainties |
          only_keys(["finding_ids","coverage_cells"]) | not) or
        ($s.uncertainties.finding_ids | type) != "array" or
        ($s.uncertainties.coverage_cells | type) != "array" or
        (all($s.uncertainties.finding_ids[]; finding_id) | not) or
        (all($s.uncertainties.coverage_cells[]; uncertain_cell) | not) or
        ($s.uncertainties.finding_ids | sort) != $expected_uncertain_ids or
        ($s.uncertainties.coverage_cells |
          sort_by(.reviewer,.surface)) != $expected_uncertain_coverage
      then "malformed uncertainties contract or parity mismatch" +
        (if ($s.uncertainties | type) != "object"
         then ": uncertainties is " + ($s.uncertainties | type) + ", expected an object"
         elif ($s.uncertainties | only_keys(["finding_ids","coverage_cells"]) | not)
         then ": keys are [" + safe_join(($s.uncertainties | keys_unsorted)) +
           "], expected exactly finding_ids/coverage_cells"
         elif ($s.uncertainties.finding_ids | type) != "array"
         then ": finding_ids is " + ($s.uncertainties.finding_ids | type) + ", expected an array"
         elif ($s.uncertainties.coverage_cells | type) != "array"
         then ": coverage_cells is " + ($s.uncertainties.coverage_cells | type) + ", expected an array"
         elif (all($s.uncertainties.finding_ids[]; finding_id) | not)
         then ": finding_ids holds a value that is not a finding id"
         elif (all($s.uncertainties.coverage_cells[]; uncertain_cell) | not)
         then ": a coverage_cells entry does not match the uncertain-cell shape"
         elif ($s.uncertainties.finding_ids | sort) != $expected_uncertain_ids
         then " (finding_ids)" +
           id_delta($expected_uncertain_ids; $s.uncertainties.finding_ids;
             "copy every uncertain finding id the reviewers declared")
         else " (coverage_cells)" +
           id_delta(($expected_uncertain_coverage | map(.reviewer + ":" + .surface));
                    ($s.uncertainties.coverage_cells | map(.reviewer + ":" + .surface));
                    "copy the reviewer/surface pair of each uncertain cell verbatim")
         end)
      elif
        (all($s.cautions[]; finding_id) | not) or
        ($s.cautions | sort) != $expected_cautions
      then "caution parity mismatch" +
        (if (all($s.cautions[]; finding_id) | not)
         then ": cautions holds a value that is not a finding id"
         else id_delta($expected_cautions; $s.cautions;
                "copy every reviewer caution finding id verbatim")
         end)
      elif
        (($s.test_gap_matrix // []) | type) != "array" or
        (all(($s.test_gap_matrix // [])[]; test_gap) | not) or
        (($s.test_gap_matrix // []) | sort_by(.id)) != $expected_test_gaps
      then "test-gap matrix parity mismatch" +
        (if (($s.test_gap_matrix // []) | type) != "array"
         then ": test_gap_matrix is " + (($s.test_gap_matrix // []) | type) +
           ", expected an array"
         elif (all(($s.test_gap_matrix // [])[]; test_gap) | not)
         then ": a row does not match the test-gap row shape"
         else id_delta(($expected_test_gaps | map(.id));
                (($s.test_gap_matrix // []) | map(.id));
                "copy every reviewer test_gaps row verbatim, field by field")
         end)
      elif $require_test_gaps and
        ((($s.operational_cautions // null) | string_array | not) or
         (($s.user_cautions // null) | string_array | not) or
         (($s.verification_plan // null) | type) != "object" or
         (($s.verification_plan | only_keys(["focused","manual","full"])) | not) or
         (($s.verification_plan.focused | string_array) | not) or
         (($s.verification_plan.manual | string_array) | not) or
         (($s.verification_plan.full | string_array) | not) or
         ($s.verification_plan.full | length) == 0)
      then "invalid cautions or verification plan"
      elif $require_test_gaps and
        (($s.verification_plan.focused | sort) != $expected_focused)
      then "focused verification parity mismatch" +
        id_delta($expected_focused; $s.verification_plan.focused;
          "copy every reviewer focused verification entry verbatim")
      elif
        ($s.remediation_seed |
          only_keys(["kind","schema_version","state",
            "scope_manifest_sha256","entries"]) | not) or
        $s.remediation_seed.kind != "remediation_closure_v1" or
        $s.remediation_seed.schema_version != 1 or
        $s.remediation_seed.state != "seed" or
        $s.remediation_seed.scope_manifest_sha256 != $scope_sha or
        ($s.remediation_seed.entries | type) != "array" or
        (all($s.remediation_seed.entries[]; seed_entry) | not)
      then "malformed remediation seed"
      elif
        ($s.remediation_seed.entries | sort_by(.finding_id)) !=
          ($s.findings_union | map({
            finding_id:.id,
            reviewer,
            root_cause_group_id,
            disposition,
            verification_expectation
          }) | sort_by(.finding_id))
      then "remediation seed parity mismatch" +
        id_delta(($s.findings_union | map(.id));
                 ($s.remediation_seed.entries | map(.finding_id));
                 "each seed entry copies reviewer/root_cause_group_id/disposition/verification_expectation from its union finding")
      else "ok"
      end
    '
  )" || validation="invalid synthesis JSON document"
  if [[ "$validation" != ok ]]; then
    GATE_SYNTHESIS_PROTOCOL_ERROR="$validation"
    printf 'Error: synthesis protocol INCOMPLETE: %s in %s\n' \
      "$validation" "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  if ! gate_structural_schema_verify gate-synthesis-result "$synthesis_document" \
      "synthesis protocol"; then
    GATE_SYNTHESIS_PROTOCOL_ERROR="schema structural contract failed"
    rm -rf -- "$tmp_dir"
    return 1
  fi

  for heading in \
    '## Must-Fix Order' \
    '## Advisory and Cautions' \
    '## Coverage Gaps and Uncertainties' \
    '## Recommended Verification'
  do
    heading_count="$(grep -Fxc -- "$heading" "$artifact" || true)"
    if [[ "$heading_count" -ne 1 ]]; then
      printf 'Error: synthesis protocol INCOMPLETE: required human section %s appears %d time(s) in %s\n' \
        "$heading" "$heading_count" "$artifact" >&2
      rm -rf -- "$tmp_dir"
      return 1
    fi
  done
  if [[ "$require_test_gaps" == true ]]; then
    for heading in \
      '## Test Coverage to Add or Strengthen' \
      '## Operational and User Cautions' \
      '## Post-Fix Verification Plan'
    do
      heading_count="$(grep -Fxc -- "$heading" "$artifact" || true)"
      if [[ "$heading_count" -ne 1 ]]; then
        # shellcheck disable=SC2034 # consumed by pr-gate.sh recovery classification.
        GATE_SYNTHESIS_PROTOCOL_ERROR="missing required CC-521 human section"
        printf 'Error: synthesis protocol INCOMPLETE: required human section %s appears %d time(s) in %s\n' \
          "$heading" "$heading_count" "$artifact" >&2
        rm -rf -- "$tmp_dir"
        return 1
      fi
    done
  fi
  rm -rf -- "$tmp_dir"
}

_gate_result_sha256_stream() {
  gate_digest_stream
}

_gate_subject_common_dir() {
  local repo_root="$1" common_dir common_parent
  common_dir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null)" || {
    printf 'Error: gate subject is not a Git worktree: %s\n' "$repo_root" >&2
    return 2
  }
  if [[ "$common_dir" != /* ]]; then
    common_dir="$repo_root/$common_dir"
  fi
  common_parent="$(cd "$(dirname "$common_dir")" 2>/dev/null && pwd -P)" || return 2
  common_dir="$common_parent/$(basename "$common_dir")"
  [[ -d "$common_dir" ]] || {
    printf 'Error: gate subject Git common directory is unavailable: %s\n' "$common_dir" >&2
    return 2
  }
  printf '%s\n' "$common_dir"
}

# gate_subject_snapshot <repo> <base-ref> <head-ref> <subject-kind>
#                       <dirty-policy> <captured-at>
# Prints one immutable-subject observation. Repository identity is stable across
# linked worktrees because it is rooted in Git's common directory; the observed
# worktree path remains provenance only.
gate_subject_snapshot() {
  local repo_root="$1" base_ref="$2" head_ref="$3" subject_kind="$4"
  local dirty_policy="$5" captured_at="$6"
  local observed_root common_dir common_identity remote remote_identity repository_key
  local base_commit head_commit tree_fingerprint fingerprint_kind
  observed_root="$(cd "$repo_root" 2>/dev/null && pwd -P)" || return 2
  common_dir="$(_gate_subject_common_dir "$observed_root")" || return $?
  common_identity="$(printf '%s' "$common_dir" | _gate_result_sha256_stream)" || return $?
  remote="$(git -C "$observed_root" config --get remote.origin.url 2>/dev/null || true)"
  remote_identity=""
  if [[ -n "$remote" ]]; then
    remote_identity="$(printf '%s' "$remote" | _gate_result_sha256_stream)" || return $?
  fi
  repository_key="$(
    printf 'common:%s\nremote:%s\n' "$common_identity" "${remote_identity:-absent}" \
      | _gate_result_sha256_stream
  )" || return $?
  base_commit="$(git -C "$observed_root" rev-parse "${base_ref}^{commit}" 2>/dev/null)" \
    || return 2
  head_commit="$(git -C "$observed_root" rev-parse "${head_ref}^{commit}" 2>/dev/null)" \
    || return 2
  fingerprint_kind="$subject_kind"
  if [[ "$subject_kind" == committed_head ]] \
      && { ! git -C "$observed_root" diff --quiet HEAD 2>/dev/null \
        || [[ -n "$(git -C "$observed_root" ls-files --others --exclude-standard)" ]]; }; then
    fingerprint_kind=working_tree
  fi
  tree_fingerprint="$(
    _gate_subject_tree_fingerprint "$observed_root" "$fingerprint_kind" "$head_commit"
  )" || return $?

  jq -nc \
    --arg repository_key "$repository_key" \
    --arg common_identity "$common_identity" \
    --arg remote_identity "$remote_identity" \
    --arg observed_root "$observed_root" \
    --arg common_dir "$common_dir" \
    --arg base_ref "$base_ref" --arg base_commit "$base_commit" \
    --arg head_ref "$head_ref" --arg head_commit "$head_commit" \
    --arg tree_fingerprint "$tree_fingerprint" \
    --arg subject_kind "$subject_kind" --arg dirty_policy "$dirty_policy" \
    --arg captured_at "$captured_at" '{
      repository:{
        key:$repository_key,
        git_common_dir_identity:$common_identity,
        remote_identity:(if $remote_identity == "" then null else $remote_identity end)
      },
      observed:{
        root:$observed_root,
        git_common_dir:$common_dir
      },
      base:{ref:$base_ref,commit:$base_commit},
      head:{ref:$head_ref,commit:$head_commit},
      tree_fingerprint:$tree_fingerprint,
      subject_kind:$subject_kind,
      dirty_policy:$dirty_policy,
      captured_at:$captured_at
    }'
}

# gate_subject_assess <assurance-file> <current-repo>
# Always prints a structured axis object. An older assurance envelope remains a
# valid historical artifact but cannot claim current-subject evidence.
gate_subject_assess() {
  local assurance_file="$1" repo_root="$2"
  local kind current current_at
  kind="$(jq -r '.kind // empty' "$assurance_file" 2>/dev/null)"
  if [[ "$kind" != gate_assurance_v3 ]]; then
    jq -nc '{
      status:"unavailable",
      reason_codes:["immutable_subject_unavailable"]
    }'
    return 0
  fi
  current_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
    || date +'%Y-%m-%dT%H:%M:%SZ')"
  current="$(
    gate_subject_snapshot "$repo_root" \
      "$(jq -r '.subject.base.ref' "$assurance_file")" \
      "$(jq -r '.subject.head.ref' "$assurance_file")" \
      "$(jq -r '.subject.subject_kind' "$assurance_file")" \
      "$(jq -r '.subject.dirty_policy' "$assurance_file")" \
      "$current_at"
  )" || {
    jq -nc '{
      status:"unavailable",
      reason_codes:["current_subject_unresolvable"]
    }'
    return 0
  }
  jq -nc --slurpfile assurance "$assurance_file" --argjson current "$current" '
    $assurance[0] as $a |
    ([
      if $a.subject.repository.key != $a.subject.observed_at_finish.repository_key
        then "producer_repository_drift" else empty end,
      if $a.subject.base.commit != $a.subject.observed_at_finish.base_commit
        then "producer_base_drift" else empty end,
      if $a.subject.head.commit != $a.subject.observed_at_finish.head_commit
        then "producer_head_drift" else empty end,
      if $a.subject.tree_fingerprint != $a.subject.observed_at_finish.tree_fingerprint
        then "producer_tree_drift" else empty end,
      if $a.subject.repository.key != $current.repository.key
        then "repository_mismatch" else empty end,
      if $a.subject.base.commit != $current.base.commit
        then "base_advanced" else empty end,
      if $a.subject.head.commit != $current.head.commit
        then "head_moved" else empty end,
      if $a.subject.tree_fingerprint != $current.tree_fingerprint
        then "tree_drift" else empty end
    ] | unique) as $reasons |
    {
      status:(if ($reasons | length) == 0 then "pass" else "fail" end),
      reason_codes:$reasons,
      current:{
        repository_key:$current.repository.key,
        base_commit:$current.base.commit,
        head_commit:$current.head.commit,
        tree_fingerprint:$current.tree_fingerprint,
        observed_root:$current.observed.root
      }
    }'
}

# gate_scope_manifest_verify <manifest> <repository-key> <base-commit>
#                            <head-commit> <tree-fingerprint> <subject-kind>
#                            <base-ref> <head-ref>
#
# JSON Schema owns the portable development contract. This jq predicate is the
# copy-mode runtime mirror: it verifies closed shapes, cross-field parity,
# truncation truthfulness, immutable-subject binding, and the self-addressed
# canonical content digest without requiring a jsonschema executable.
gate_scope_manifest_verify() {
  local manifest_file="$1" repository_key="$2" base_commit="$3"
  local head_commit="$4" tree_fingerprint="$5" subject_kind="$6"
  local base_ref="$7" head_ref="$8"
  local expected_digest actual_digest
  [[ -s "$manifest_file" ]] || {
    printf 'Error: gate scope manifest is missing or empty: %s\n' \
      "$manifest_file" >&2
    return 1
  }
  if ! gate_structural_schema_verify gate-scope-manifest "$manifest_file" \
      "gate scope manifest"; then
    printf 'Error: gate scope manifest failed structural/claim verification: %s\n' \
      "$manifest_file" >&2
    return 1
  fi
  expected_digest="$(jq -r '.content.digest // empty' "$manifest_file" 2>/dev/null)"
  actual_digest="$(jq -cS 'del(.content.digest)' "$manifest_file" 2>/dev/null \
    | _gate_result_sha256_stream)" || return $?
  if [[ ! "$expected_digest" =~ ^[a-f0-9]{64}$ \
      || "$actual_digest" != "$expected_digest" ]]; then
    printf 'Error: gate scope manifest content digest mismatch: %s\n' \
      "$manifest_file" >&2
    return 1
  fi
  # CC-533 Req 2: single-field shape checks (only_keys/type/enum/pattern/const)
  # already declared in core/schema/gate-scope-manifest.schema.json — including
  # several cross-field correlations this schema encodes via allOf/if/then that
  # gate-assurance.schema.json does NOT (subject_kind<->diff_kind,
  # status<->truncation shape, per-status old_path/new_path/similarity shape) —
  # are NOT repeated here; gate_structural_schema_verify above already proved
  # them. What remains is either a same-document cross-field derivation this
  # schema's plain JSON Schema still cannot express (a set derived from OTHER
  # array entries, e.g. changed_paths must equal the union of entries[].old_path/
  # new_path) or a comparison against external context (the caller-supplied
  # repository_key/commits/refs).
  jq -e \
    --arg repository_key "$repository_key" \
    --arg base_commit "$base_commit" \
    --arg head_commit "$head_commit" \
    --arg tree_fingerprint "$tree_fingerprint" \
    --arg subject_kind "$subject_kind" \
    --arg base_ref "$base_ref" \
    --arg head_ref "$head_ref" '
    def exact_set($other):
      (sort) == ($other | sort);
    def scope_flag($changed):
      all(.paths[]; . as $path | ($changed | index($path)) != null) and
      (.matched == ((.paths | length) > 0));
    (.subject.repository_key == $repository_key) and
    (.subject.base_commit == $base_commit) and
    (.subject.head_commit == $head_commit) and
    (.subject.tree_fingerprint == $tree_fingerprint) and
    (.subject.subject_kind == $subject_kind) and
    (.selection.base_ref == $base_ref) and
    (.selection.head_ref == $head_ref) and
    (.changes | . as $changes |
      (([.entries[] | .old_path,.new_path | select(. != null)] | unique) |
        exact_set($changes.changed_paths)) and
      (([.entries[] | select(.status == "renamed") |
          {from:.old_path,to:.new_path,similarity:(.similarity // 0)}] | sort) ==
        ($changes.renamed_paths | sort)) and
      (([.entries[] | select(.status == "untracked") | .new_path] | unique) |
        exact_set($changes.untracked_paths))) and
    (.changes.changed_paths as $changed |
      (.diff |
        all(.hunks[]; .path as $path | ($changed | index($path)) != null) and
        all(.binary_or_special_paths[];
          . as $path | ($changed | index($path)) != null)) and
      all(.paired_tests[];
        .source_path as $path | ($changed | index($path)) != null) and
      ([.sensitive_signals[].id] | length == (unique | length)) and
      all(.sensitive_signals[].matches[];
        . as $path | ($changed | index($path)) != null) and
      (.flags as $flags |
        ($flags.public_interface | scope_flag($changed)) and
        ($flags.schema | scope_flag($changed)) and
        ($flags.config | scope_flag($changed)) and
        ($flags.install | scope_flag($changed)) and
        ($flags.ci | scope_flag($changed)) and
        ($flags.release | scope_flag($changed)) and
        ($flags.migration | scope_flag($changed)))) and
      (.expansion | . as $expansion |
        ([.entries[].path] | unique | exact_set($expansion.included_paths))) and
      (. as $manifest |
        ([$manifest.changes.changed_paths[]] +
         [$manifest.paired_tests[] | .source_path,.test_path] +
         [$manifest.sensitive_signals[] | .matches[]] +
         [$manifest.flags[] | .paths[]] +
         [$manifest.expansion.included_paths[]] | unique) as $allowed |
        ($manifest.reference_index == null or
          ($manifest.reference_index |
            ([.entries[].path] | length == (unique | length)) and
            all(.entries[];
              .path as $path | ($allowed | index($path)) != null)))) and
      (. as $manifest | .truncation |
      all(.budgets[]; . >= 1) and
      (.omitted as $o |
        .occurred == ([$o[]] | any(. > 0)) and
        (.reasons | exact_set([
          if $o.diff_hunks > 0 then "diff-hunk-budget" else empty end,
          if $o.expansion_source_paths > 0
            then "expansion-source-budget" else empty end,
          if $o.symbols_per_source > 0 then "symbol-budget" else empty end,
          if $o.matches_per_query > 0
            then "search-match-budget" else empty end,
          if $o.contract_consumers_per_source > 0
            then "contract-consumer-budget" else empty end,
          if $o.expansion_entries > 0
            then "expansion-entry-budget" else empty end
        ]))) and
      (($manifest.diff.hunks | length) <= .budgets.diff_hunks) and
      (($manifest.expansion.entries | length) <= .budgets.expansion_entries) and
      (if .occurred
       then
         .acceptance.required == true and
         (if .acceptance.accepted
          then .acceptance.source == "--accept-scope-truncation"
          else .acceptance.source == null
          end)
       else
         .acceptance == {required:false,accepted:false,source:null} and
         (.reasons | length) == 0
       end))
  ' "$manifest_file" >/dev/null || {
    printf 'Error: gate scope manifest failed structural/claim verification: %s\n' \
      "$manifest_file" >&2
    return 1
  }
}

_gate_assurance_linked_evidence_verify() {
  local assurance_file="$1" assurance_dir label artifact expected_sha
  local linked_subject subject_fingerprint artifact_path actual_sha
  local artifact_subject artifact_outcome linked_outcome
  assurance_dir="$(cd "$(dirname "$assurance_file")" 2>/dev/null && pwd -P)" \
    || return 1
  subject_fingerprint="$(jq -r '.subject.tree_fingerprint' "$assurance_file")"
  while IFS=$'\t' read -r label artifact expected_sha linked_subject; do
    [[ -n "$label" ]] || continue
    artifact_path="$assurance_dir/$artifact"
    if [[ ! -f "$artifact_path" || -L "$artifact_path" ]]; then
      printf 'Error: gate assurance linked %s evidence is missing or unsafe: %s\n' \
        "$label" "$artifact_path" >&2
      return 1
    fi
    actual_sha="$(_gate_result_sha256_file "$artifact_path")" || return $?
    if [[ "$actual_sha" != "$expected_sha" ]]; then
      printf 'Error: gate assurance linked %s evidence digest mismatch: %s\n' \
        "$label" "$artifact_path" >&2
      return 1
    fi
    if [[ "$linked_subject" != "$subject_fingerprint" ]]; then
      printf 'Error: gate assurance linked %s evidence subject mismatch: %s\n' \
        "$label" "$artifact_path" >&2
      return 1
    fi
    if [[ "$label" == preflight ]]; then
      if ! artifact_subject="$(
        jq -er '.subject.fingerprint_before |
          select(type == "string" and test("^[a-f0-9]{64}$"))' \
          "$artifact_path" 2>/dev/null
      )" || ! artifact_outcome="$(
        jq -er '.status |
            select(. == "pass" or . == "fail" or . == "test-fail" or . == "timeout" or
              . == "environment-error" or . == "stale" or
              . == "invalid-evidence" or . == "unclassified-nonzero")' "$artifact_path" 2>/dev/null
      )"; then
        printf 'Error: gate assurance linked preflight evidence claim is malformed: %s\n' \
          "$artifact_path" >&2
        return 1
      fi
      linked_outcome="$(jq -r '.evidence.preflight.outcome' "$assurance_file")"
        if [[ "$artifact_subject" != "$linked_subject" ]]; then
          printf 'Error: gate assurance linked preflight evidence subject claim mismatch: %s\n' \
            "$artifact_path" >&2
          return 1
        fi
        if ! jq -e '
          ((has("outcome") | not) and (.status | IN("pass","fail"))) or
          (.outcome | type == "object" and
            (.execution | IN("pass","nonzero","timeout")) and
            (.test_verdict | IN("pass","fail","not_available","inconclusive")) and
            (.evidence_richness | IN("opaque","structured","invalid")) and
            (.authorization | IN("eligible","non_authorizing"))) and
          ((.status == "pass" and .outcome.execution == "pass" and
            .outcome.test_verdict == "pass" and
            .outcome.authorization == "eligible") or
           (.status == "test-fail" and .outcome.test_verdict == "fail" and
            .outcome.evidence_richness == "structured" and
            .outcome.authorization == "non_authorizing") or
           ((.status | IN("timeout","environment-error","stale",
             "invalid-evidence","unclassified-nonzero")) and
            .outcome.test_verdict != "fail" and
            .outcome.authorization == "non_authorizing"))
        ' "$artifact_path" >/dev/null 2>&1; then
          printf 'Error: gate assurance linked preflight evidence outcome contract is malformed: %s\n' \
            "$artifact_path" >&2
          return 1
        fi
        if [[ "$linked_outcome" != "$artifact_outcome" ]]; then
        printf 'Error: gate assurance linked preflight evidence outcome mismatch: %s\n' \
          "$artifact_path" >&2
        return 1
      fi
    elif [[ "$label" == scope_manifest ]]; then
      if ! gate_scope_manifest_verify "$artifact_path" \
          "$(jq -r '.subject.repository.key' "$assurance_file")" \
          "$(jq -r '.subject.base.commit' "$assurance_file")" \
          "$(jq -r '.subject.head.commit' "$assurance_file")" \
          "$linked_subject" \
          "$(jq -r '.subject.subject_kind' "$assurance_file")" \
          "$(jq -r '.subject.base.ref' "$assurance_file")" \
          "$(jq -r '.subject.head.ref' "$assurance_file")"; then
        return 1
      fi
      if ! jq -e --slurpfile scope "$artifact_path" '
          ([.policy.matched_signals[] |
            select(.source == "path-regex")] | sort_by(.id)) ==
          ($scope[0].sensitive_signals | sort_by(.id))
        ' "$assurance_file" >/dev/null; then
        printf 'Error: gate scope manifest sensitive signals do not match resolved policy: %s\n' \
          "$artifact_path" >&2
        return 1
      fi
      if [[ "$(jq -r '.status' "$artifact_path")" == incomplete ]]; then
        printf 'Error: incomplete gate scope manifest cannot authorize a gate result: %s\n' \
          "$artifact_path" >&2
        return 1
      fi
    elif [[ "$label" == closure ]]; then
      if ! gate_remediation_closure_verify "$artifact_path" \
          "$linked_subject" \
          "$(jq -r '.evidence.scope_manifest.sha256 // empty' "$assurance_file")"; then
        return 1
      fi
    fi
  done < <(
    jq -r '
      [
        (if .evidence.preflight.status == "linked" then
          ["preflight",.evidence.preflight.artifact,
            .evidence.preflight.sha256,.evidence.preflight.subject_fingerprint]
         else empty end),
        (if .evidence.scope_manifest.status == "verified" then
          ["scope_manifest",.evidence.scope_manifest.artifact,
            .evidence.scope_manifest.sha256,
            .evidence.scope_manifest.subject_fingerprint]
         else empty end),
        (if .evidence.closure.status == "verified" then
          ["closure",.evidence.closure.artifact,
            .evidence.closure.sha256,.evidence.closure.subject_fingerprint]
         else empty end)
      ][] | @tsv
    ' "$assurance_file"
  )
}

# gate_policy_applicability_assess <assurance-file>
#                                  <embedded|generic|maintainer|publish>
#                                  <verified|unavailable|invalid>
#                                  [authorization-reason]
#                                  [closure-authorized]
gate_policy_applicability_assess() {
  local assurance_file="$1" consumer="$2" authorization_status="$3"
  local authorization_reason="${4:-dispatch_authorization_unavailable}"
  local closure_authorized="${5:-unavailable}"
  case "$consumer" in
    embedded|generic|maintainer|publish) ;;
    *)
      jq -nc '{
        status:"fail",
        reason_codes:["consumer_policy_unknown"]
      }'
      return 0
      ;;
  esac
  local kind
  kind="$(jq -r '.kind // empty' "$assurance_file" 2>/dev/null)"
  if [[ "$kind" != gate_assurance_v3 ]]; then
    jq -nc '{
      status:"unavailable",
      reason_codes:["consumer_applicability_unavailable"]
    }'
    return 0
  fi
  jq -nc --slurpfile assurance "$assurance_file" \
    --arg consumer "$consumer" \
    --arg authorization_status "$authorization_status" \
    --arg authorization_reason "$authorization_reason" \
    --arg closure_authorized "$closure_authorized" '
    def policy_rank:
      if . == "generic" then 1
      elif . == "maintainer" then 2
      else 0
      end;
    $assurance[0] as $a |
    (if $consumer == "embedded" then $a.policy.consumer_policy
     elif $consumer == "maintainer" then "maintainer"
     else "generic" end) as $required_policy |
    (if $consumer == "publish" then "maintainer"
     else $required_policy end) as $preferred_policy |
    ($a.policy.consumer_policy | policy_rank) as $embedded_rank |
    ($required_policy | policy_rank) as $required_rank |
    ($preferred_policy | policy_rank) as $preferred_rank |
    ([
      if $a.result.final != "GO" then "verdict_not_go" else empty end,
      if ($a | has("policy") | not) then "policy_resolution_unavailable" else empty end,
      if $embedded_rank < $required_rank
        then "consumer_policy_below_minimum" else empty end,
      if $a.policy.enforcement.status != "pass"
        then "policy_enforcement_failed" else empty end,
      if $a.coordinates.independence.evidence_status != "verified"
        then "review_independence_unverified" else empty end,
      if any($a.dispatch.outcomes[];
        .status != "passed" or .evidence_status != "verified" or .run_id == null)
        then "review_dispatch_evidence_incomplete" else empty end,
      if $a.evidence.scope_manifest.status != "verified"
        then "scope_manifest_unavailable" else empty end,
      if $authorization_status != "verified"
        then $authorization_reason else empty end,
      if ($consumer == "maintainer" or $consumer == "publish") and
         ($a.coordinates.pass.resolved != "initial" or
          $a.coordinates.pass.scope != "comprehensive")
        and $closure_authorized != "verified"
        then "comprehensive_review_required" else empty end
    ] | unique) as $reasons |
    {
      status:(if ($reasons | length) == 0 then "pass" else "fail" end),
      reason_codes:$reasons,
      consumer:$consumer,
      required_policy:$required_policy,
      preferred_policy:$preferred_policy,
      embedded_policy:$a.policy.consumer_policy,
      policy_satisfaction:
        (if $embedded_rank >= $preferred_rank then "preferred" else "baseline" end)
    }'
}

# The core JSON Schema owns portable envelope shape. This runtime predicate owns
# cross-artifact and semantic claim consistency that JSON Schema cannot establish
# from the Markdown result. The standalone fallback is an exact generated-style
# copy guarded by test_inline_fallback_matches_lib.
#
# gate_assurance_verify <result_file> <assurance_file> <body_final>
# CC-533 Req 3: legacy gate_assurance_v1 claim verification, isolated from the
# current (v2/v3) verifier below. v1 predates the schema-derived structural
# validator entirely (no gate-assurance.schema.json coverage), so this stays
# a small self-contained handwritten check rather than a version branch
# threaded through the current verifier's logic.
_gate_assurance_verify_legacy_v1() {
  local assurance_file="$1" body_final="$2" markdown_tier="$3" markdown_mode="$4"
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
}

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
    _gate_assurance_verify_legacy_v1 \
      "$assurance_file" "$body_final" "$markdown_tier" "$markdown_mode" || return $?
    GATE_ASSURANCE_BOUND=false
    export GATE_ASSURANCE_BOUND
    return 0
  fi
  if ! gate_structural_schema_verify gate-assurance "$assurance_file" \
      "gate assurance"; then
    printf 'Error: gate assurance failed structural/claim verification: %s\n' \
      "$assurance_file" >&2
    return 1
  fi
  result_sha="$(_gate_result_sha256_file "$result_file")" || return $?
  # CC-533 Req 2: single-field shape checks (only_keys/type/enum/pattern/const)
  # already declared in core/schema/gate-assurance.schema.json are NOT
  # repeated here — gate_structural_schema_verify above already proved them.
  # Everything remaining below is either a same-document cross-field
  # consistency rule (plain JSON Schema has no `$data`-style "field A must
  # equal field B" construct, so these cannot be schema-derived) or a
  # comparison against something outside this document (the result markdown's
  # frontmatter/body, a freshly computed file digest, or the shared
  # identifier-policy run-id pattern). Do not add a check here that a schema
  # property/pattern/enum/const addition could express instead.
  jq -e --arg final "$body_final" --arg result_sha "$result_sha" \
    --arg markdown_tier "$markdown_tier" \
    --arg markdown_mode "$markdown_mode" \
    --arg run_id_pattern "$(pm_identifier_run_ere_pattern)" '
    def strings_unique:
      type == "array" and all(.[]; type == "string" and length > 0) and
      (length == (unique | length));
    def same_set($a; $b): ($a | sort) == ($b | sort);
    (if .kind == "gate_assurance_v3" then
      # subject_kind<->dirty_policy correlation is schema-covered (gateSubject
      # allOf/if/then in core/schema/gate-assurance.schema.json) -- confirmed
      # by the CC-533 altitude review that caught this residual duplication
      # missed in the first pass; not repeated here.
      .bindings.repo_root == .subject.observed.root and
      .bindings.repo_identity == .subject.repository.key and
      .bindings.base_commit == .subject.base.commit and
      .bindings.head_commit == .subject.head.commit and
      .bindings.subject_fingerprint == .subject.tree_fingerprint and
      .subject.created_at <= .subject.finished_at
     else true end) and
    (if has("policy") then
      .policy.policy_source == .provenance.policy_source and
      .policy.request.tier == .coordinates.tier.requested and
      .policy.request.mode == .coordinates.mode.requested and
      .policy.request.pass_kind == .coordinates.pass.resolved and
      ((.policy.request.reviewers == null and
        .coordinates.coverage.requested == null) or
       (same_set(.policy.request.reviewers;
         .coordinates.coverage.requested))) and
      (.policy.classification.layer_roots | strings_unique) and
      (.policy.resolution.required_reviewers | strings_unique) and
      (.policy as $policy |
        all($policy.resolution.required_reviewers[];
          . as $reviewer |
          ($policy.resolved.reviewers | index($reviewer)) != null or
            $policy.resolution.downgrade_allowed)) and
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
      ([.policy.matched_signals[].id] | strings_unique) and
      (all(.policy.matched_signals[];
        (.matches | strings_unique) and
        (.required_reviewers | strings_unique))) and
      .policy.resolved.tier == .coordinates.tier.resolved and
      .policy.resolved.mode == .coordinates.mode.resolved and
      same_set(.policy.resolved.reviewers;
        .coordinates.coverage.selected) and
      (all(.policy.enforcement.violations[];
        (.coordinate | IN("tier","coverage")))) and
      (if .policy.resolution.downgrade_requested
       then
         .policy.resolution.downgrade_allowed == true and
         .policy.override.status == "applied" and
         (.policy.override.source |
           type == "string" and startswith("/")) and
         (.policy.override.reason | type == "string" and length > 0) and
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
      (if .policy.reviewer_override.status == "provided"
       then
         (.policy.reviewer_override.source |
           type == "string" and startswith("/"))
       else
         .policy.reviewer_override.source == null and
         .policy.reviewer_override.sha256 == null
       end)
    else true end) and
    .result.final == $final and
    .bindings.result_sha256 == $result_sha and
    .coordinates.tier.resolved == $markdown_tier and
    .coordinates.mode.resolved == $markdown_mode and
    (if .kind == "gate_assurance_v3" then
       # Historical v3 artifacts predate selection_basis. They remain readable
       # only when both additions are absent; a partial claim is always invalid.
       (if ((.coordinates.tier | has("selection_basis")) and
            (.coordinates.coverage | has("selection_basis"))) then
          (.coordinates.tier.selection_basis ==
            (if .coordinates.tier.requested == "auto" then "policy" else "explicit" end)) and
          (.coordinates.coverage.selection_basis ==
            (if .coordinates.coverage.requested == null then "policy-default"
             elif .provenance.coordinate_syntax.coverage? != null
             then .provenance.coordinate_syntax.coverage
             else .coordinates.coverage.selection_basis end))
        else
          ((.coordinates.tier | has("selection_basis")) | not) and
          ((.coordinates.coverage | has("selection_basis")) | not)
        end)
     else
       ((.coordinates.tier | has("selection_basis")) | not) and
       ((.coordinates.coverage | has("selection_basis")) | not)
     end) and
    (.coordinates.tier.requested == "auto" or
      .coordinates.tier.requested == .coordinates.tier.resolved) and
    (.coordinates.mode.requested == "default" or
      .coordinates.mode.requested == .coordinates.mode.resolved) and
    ((.coordinates.mode.resolved == "sequential" and
       .coordinates.mode.topology == "combined-session" and
       .coordinates.mode.synthesis == "inline") or
     (.coordinates.mode.resolved == "parallel" and
       .coordinates.mode.topology == "per-reviewer-sessions" and
       .coordinates.mode.synthesis == "separate-session")) and
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
    (all(.dispatch.outcomes[];
      (if .role == "reviewer"
       then (.reviewer | type == "string" and length > 0)
       else .reviewer == null
       end) and
      (.run_id == null or
        (.run_id | type == "string" and test($run_id_pattern))))) and
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
       (.dispatch.outcomes[0].status == "failed" or
        .dispatch.outcomes[0].status == "incomplete")
     end) and
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
  if [[ "$assurance_kind" == gate_assurance_v3 ]]; then
    _gate_assurance_linked_evidence_verify "$assurance_file" || return $?
  fi
  GATE_ASSURANCE_BOUND=true
  export GATE_ASSURANCE_BOUND
}

_gate_result_sha256_file() {
  gate_digest_file "$1"
}

# gate_assurance_authorization_verify <result> <assurance> <attestation> <runs.jsonl>
# Validates the protected producer attestation and resolves every claimed run ID
# to the latest canonical terminal record for the same gate run and repository.
gate_assurance_authorization_verify() {
  local result_file="$1" assurance_file="$2" attestation_file="$3" runs_file="$4"
  local result_sha assurance_sha subject_sha="" run_root assurance_kind
  [[ -s "$attestation_file" && -s "$runs_file" ]] || {
    printf 'Error: verified gate assurance requires protected attestation and canonical run records\n' >&2
    return 1
  }
  result_sha="$(_gate_result_sha256_file "$result_file")" || return $?
  assurance_sha="$(_gate_result_sha256_file "$assurance_file")" || return $?
  assurance_kind="$(jq -r '.kind // empty' "$assurance_file" 2>/dev/null)"
  if [[ "$assurance_kind" == gate_assurance_v3 ]]; then
    subject_sha="$(jq -cS '.subject' "$assurance_file" \
      | _gate_result_sha256_stream)" || return $?
  fi
  run_root="$(cd "$(dirname "$attestation_file")" && pwd -P)" || return 1
  jq -e --arg result_sha "$result_sha" --arg assurance_sha "$assurance_sha" \
    --arg subject_sha "$subject_sha" \
    --slurpfile assurance "$assurance_file" '
      $assurance[0] as $a |
      ((($a.kind == "gate_assurance_v2") and
        .kind == "gate_assurance_attestation_v1" and .schema_version == 1) or
       (($a.kind == "gate_assurance_v3") and
        .kind == "gate_assurance_attestation_v2" and .schema_version == 2)) and
      .result_sha256 == $result_sha and .assurance_sha256 == $assurance_sha and
      .repo_root == $a.bindings.repo_root and
      .repo_identity == $a.bindings.repo_identity and
      .base_commit == $a.bindings.base_commit and
      .head_commit == $a.bindings.head_commit and
      .subject_fingerprint == $a.bindings.subject_fingerprint and
      (if $a.kind == "gate_assurance_v3" then
        .repository_key == $a.subject.repository.key and
        .subject_sha256 == $subject_sha
       else
        has("repository_key") == false and has("subject_sha256") == false
       end) and
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
  local selected_reviewers skipped_reviewers scope_sha scope_artifact scope_manifest
  local assurance_kind protocol_final require_test_gaps=false
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
    pr_gate_result_v2 | pr_gate_result_v3 | pr_gate_result_v4 | pr_gate_result_v5)
      pointer="$(_gate_result_frontmatter_value "$result_file" gate_assurance)"
      if [[ -z "$pointer" || "$pointer" == */* || "$pointer" == "." || "$pointer" == ".." \
          || ! "$pointer" =~ ^[A-Za-z0-9._-]+\.json$ ]]; then
        printf 'Error: %s requires a bounded sibling gate_assurance pointer: %s\n' \
          "$version" "$result_file" >&2
        return 1
      fi
      result_parent="$(cd "$(dirname "$result_file")" && pwd -P)" || return 1
      assurance_file="$result_parent/$pointer"
      body_final=$(grep -E '^Final: (GO|NO-GO|INCOMPLETE)$' "$result_file" | awk '{print $2}')
      gate_assurance_verify "$result_file" "$assurance_file" "$body_final" || return $?
      if [[ "$version" == pr_gate_result_v3 \
          || "$version" == pr_gate_result_v4 \
          || "$version" == pr_gate_result_v5 ]]; then
        assurance_kind="$(jq -r '.kind // empty' "$assurance_file" 2>/dev/null)"
        selected_reviewers="$(jq -r \
          '.coordinates.coverage.selected // [] | join(" ")' \
          "$assurance_file" 2>/dev/null)"
        skipped_reviewers="$(jq -r \
          '.coordinates.coverage.skipped // [] | join(" ")' \
          "$assurance_file" 2>/dev/null)"
        scope_sha="$(jq -r \
          '.evidence.scope_manifest.sha256 // empty' \
          "$assurance_file" 2>/dev/null)"
        scope_artifact="$(jq -r \
          '.evidence.scope_manifest.artifact // empty' \
          "$assurance_file" 2>/dev/null)"
        scope_manifest="$result_parent/$scope_artifact"
        [[ "$version" == pr_gate_result_v5 ]] && require_test_gaps=true
        if [[ "$assurance_kind" != gate_assurance_v3 \
            || -z "$selected_reviewers" \
            || ! "$scope_sha" =~ ^[a-f0-9]{64}$ ]]; then
          printf 'Error: %s requires verified selected-reviewer scope evidence: %s\n' \
            "$version" "$assurance_file" >&2
          return 1
        fi
        if jq -e '.reference_index != null' "$scope_manifest" >/dev/null 2>&1; then
          gate_reviewer_protocol_verify \
            "$result_file" "$selected_reviewers" "$scope_sha" \
            "$scope_manifest" "$require_test_gaps" \
            || return $?
        else
          gate_reviewer_protocol_verify \
            "$result_file" "$selected_reviewers" "$scope_sha" || return $?
        fi
        protocol_final="$(
          _gate_reviewer_protocol_final_extract "$result_file"
        )" || return 1
        if [[ "$protocol_final" != "$body_final" ]]; then
          printf 'Error: reviewer protocol verdict (%s) contradicts gate Final: (%s): %s\n' \
            "$protocol_final" "$body_final" "$result_file" >&2
          return 1
        fi
        if [[ "$version" == pr_gate_result_v4 \
            || "$version" == pr_gate_result_v5 ]]; then
          gate_synthesis_protocol_verify \
            "$result_file" "$selected_reviewers" "$skipped_reviewers" \
            "$scope_sha" "$require_test_gaps" \
            || return $?
        fi
      fi
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
