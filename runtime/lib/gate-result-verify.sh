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
#
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

_gate_reviewer_protocol_document_verify() {
  local document="$1" expected_reviewer="$2" expected_scope_sha="$3"
  local reference_index_json="${4:-null}"
  local surfaces_json validation
  GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR=""
  surfaces_json="$(_gate_reviewer_protocol_surfaces | jq -Rsc '
    split("\n") | map(select(length > 0))
  ')" || return 2
  validation="$(jq -r \
    --arg reviewer "$expected_reviewer" \
    --arg scope_sha "$expected_scope_sha" \
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
    def envelope_contract:
      exact_keys(["kind","schema_version","reviewer","scope_manifest_sha256",
        "coverage_claim","coverage","findings","verdict","rationale"]) and
      .kind == "gate_reviewer_result_v1" and .schema_version == 1 and
      .reviewer == $reviewer and .scope_manifest_sha256 == $scope_sha and
      .coverage_claim == "declared-scope-checklist-not-review-completeness";
    def coverage_contract:
      .coverage | type == "array" and length == ($surfaces | length) and
        all(.[]; coverage_entry) and
        ([.[].surface] | sort) == ($surfaces | sort);
    def finding_contract:
      .findings | type == "array" and all(.[]; finding) and
        ([.[].id] | length) == ([.[].id] | unique | length);
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
      all(.findings[].source; bound_evidence_ref);
    if (envelope_contract | not)
    then "invalid top-level or binding contract"
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
    elif $references != null and (evidence_reference_contract | not)
    then "invalid evidence reference contract"
    elif (verdict_contract | not)
    then "invalid verdict contract"
    else "ok"
    end
  ' "$document" 2>/dev/null)" || {
    GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR="invalid JSON document"
    return 1
  }
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
  local tmp_dir line block="" in_block=false count=0 reviewer expected document
  local seen=" " reference_index_json=null
  [[ $# -ge 3 && $# -le 4 && -s "$artifact" && -n "$selected" \
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
      in_block=false
      block=""
      continue
    fi
    if [[ "$in_block" == true ]]; then
      block="${block}${block:+$'\n'}${line}"
    fi
  done < "$artifact"
  if [[ "$in_block" == true ]]; then
    printf 'Error: reviewer protocol INCOMPLETE: unclosed result block in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  if [[ "$count" -eq 0 ]]; then
    printf 'Error: reviewer protocol INCOMPLETE: no reviewer_result_v1 block in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  for document in "$tmp_dir"/*.json; do
    reviewer="$(jq -r '.reviewer // empty' "$document" 2>/dev/null)" || reviewer=""
    if [[ -z "$reviewer" || " $selected " != *" $reviewer "* \
        || "$seen" == *" $reviewer "* ]]; then
      printf 'Error: reviewer protocol INCOMPLETE: unexpected or duplicate reviewer %s in %s\n' \
        "${reviewer:-<missing>}" "$artifact" >&2
      rm -rf -- "$tmp_dir"
      return 1
    fi
    if ! _gate_reviewer_protocol_document_verify \
        "$document" "$reviewer" "$scope_sha" "$reference_index_json"; then
      printf 'Error: reviewer protocol INCOMPLETE: %s for %s in %s\n' \
        "${GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR:-invalid reviewer document}" \
        "$reviewer" "$artifact" >&2
      rm -rf -- "$tmp_dir"
      return 1
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

# gate_synthesis_protocol_verify <artifact> <selected-reviewers>
#                                <skipped-reviewers> <scope-sha256>
#
# Validates the synthesis-owned JSON shape and then derives the authoritative
# finding inventory, coverage matrix, uncertainties, cautions, and remediation
# entries from the original reviewer_result_v1 documents. Root-cause grouping
# and disagreement prose remain synthesis judgments, but every referenced ID
# must belong to that immutable inventory and every finding must be grouped
# exactly once.
gate_synthesis_protocol_verify() {
  local artifact=${1-} selected=${2-} skipped=${3-} scope_sha=${4-}
  local tmp_dir synthesis_documents reviewer_documents synthesis_count validation
  local heading heading_count
  [[ $# -eq 4 && -s "$artifact" && -n "$selected" \
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
    printf 'Error: synthesis protocol INCOMPLETE: malformed synthesis_result_v1 fence in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  synthesis_count="$(jq -s 'length' "$synthesis_documents" 2>/dev/null)" || {
    printf 'Error: synthesis protocol INCOMPLETE: invalid synthesis JSON in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  }
  if [[ "$synthesis_count" -ne 1 ]]; then
    printf 'Error: synthesis protocol INCOMPLETE: expected one synthesis_result_v1 block, found %d in %s\n' \
      "$synthesis_count" "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi
  if ! _gate_reviewer_protocol_documents "$artifact" \
      > "$reviewer_documents" \
      || ! jq -s -e 'length > 0' "$reviewer_documents" >/dev/null 2>&1; then
    printf 'Error: synthesis protocol INCOMPLETE: reviewer documents unavailable in %s\n' \
      "$artifact" >&2
    rm -rf -- "$tmp_dir"
    return 1
  fi

  validation="$(
    jq -nr \
      --arg selected "$selected" --arg skipped "$skipped" \
      --arg scope_sha "$scope_sha" \
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
      if
        ($s | only_keys([
          "kind","schema_version","scope_manifest_sha256",
          "selected_reviewers","not_reviewed_dimensions","coverage_matrix",
          "reviewer_finding_inventory","findings_union","root_cause_groups",
          "disagreements","uncertainties","cautions","remediation_seed"
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
        ($s.root_cause_groups | type) != "array" or
        ($s.disagreements | type) != "array" or
        ($s.cautions | type) != "array" or
        ($s.remediation_seed | type) != "object"
      then "invalid top-level contract"
      elif
        $s.scope_manifest_sha256 != $scope_sha or
        $s.selected_reviewers != $selected_reviewers or
        $s.not_reviewed_dimensions != $skipped_reviewers
      then "selected/not-reviewed dimensions mismatch"
      elif
        (all($s.coverage_matrix[]; coverage_cell) | not)
      then "invalid coverage matrix"
      elif
        ($s.coverage_matrix | sort_by(.reviewer,.surface)) != $expected_coverage
      then "coverage matrix parity mismatch"
      elif
        (all($s.reviewer_finding_inventory[]; finding_inventory) | not) or
        (all($s.findings_union[]; finding_union) | not)
      then "invalid finding inventory or union"
      elif
        (($s.reviewer_finding_inventory | map(.id)) |
          length != (unique | length)) or
        (($s.findings_union | map(.id)) |
          length != (unique | length))
      then "duplicate finding ID collision"
      elif
        ($s.reviewer_finding_inventory | sort_by(.id)) != $expected_inventory
      then "reviewer finding inventory parity mismatch"
      elif
        ($s.findings_union |
          map(del(.root_cause_group_id,.disposition)) | sort_by(.id)) !=
          $expected_union
      then "findings union parity mismatch"
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
      then "root-cause grouping parity mismatch"
      elif
        (all($s.disagreements[]; disagreement) | not) or
        (($s.disagreements | map(.id)) |
          length != (unique | length)) or
        ([$s.disagreements[].finding_ids[] as $finding_id |
          ($expected_ids | index($finding_id)) != null
        ] | all | not)
      then "invalid disagreement references"
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
      then "malformed uncertainties contract or parity mismatch"
      elif
        (all($s.cautions[]; finding_id) | not) or
        ($s.cautions | sort) != $expected_cautions
      then "caution parity mismatch"
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
      then "remediation seed parity mismatch"
      else "ok"
      end
    '
  )" || validation="invalid synthesis JSON document"
  if [[ "$validation" != ok ]]; then
    printf 'Error: synthesis protocol INCOMPLETE: %s in %s\n' \
      "$validation" "$artifact" >&2
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
  rm -rf -- "$tmp_dir"
}

_gate_result_sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    printf 'Error: no sha256sum or shasum found -- cannot identify gate subject\n' >&2
    return 2
  fi
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

_gate_subject_tree_fingerprint() {
  local repo_root="$1" subject_kind="$2" head_commit="$3"
  local manifest path quoted kind executable digest
  local entry metadata mode object target
  manifest="$(mktemp "${TMPDIR:-/tmp}/gate-subject-tree.XXXXXX")" || return 2
  case "$subject_kind" in
    fixed_ref)
      while IFS= read -r -d '' entry; do
        metadata="${entry%%$'\t'*}"
        path="${entry#*$'\t'}"
        mode="${metadata%% *}"
        object="${metadata##* }"
        quoted="$(printf '%q' "$path")"
        case "$mode" in
          120000)
            kind=symlink
            executable=false
            target="$(git -C "$repo_root" cat-file blob "$object" 2>/dev/null)" || {
              rm -f -- "$manifest"
              return 2
            }
            digest="$(printf '%s' "$target" | _gate_result_sha256_stream)" || {
              rm -f -- "$manifest"
              return 2
            }
            ;;
          100644|100755)
            kind="file"
            [[ "$mode" == 100755 ]] && executable=true || executable=false
            digest="$(git -C "$repo_root" cat-file blob "$object" 2>/dev/null \
              | _gate_result_sha256_stream)" || {
              rm -f -- "$manifest"
              return 2
            }
            ;;
          *)
            # Keep gitlinks and other non-file entries visible without
            # claiming local file content, matching the workspace manifest.
            kind=missing
            executable=false
            digest=-
            ;;
        esac
        printf '%s\t%s\t%s\t%s\n' "$quoted" "$kind" "$executable" "$digest" \
          >> "$manifest"
      done < <(git -C "$repo_root" ls-tree -r -z --full-tree "$head_commit" 2>/dev/null)
      ;;
    committed_head|working_tree)
      while IFS= read -r -d '' path; do
        case "$path" in
          .agent-trace|.agent-trace/*|.gate-briefs|.gate-briefs/*|.gate-results|.gate-results/*)
            continue
            ;;
        esac
        quoted="$(printf '%q' "$path")"
        if [[ -L "$repo_root/$path" ]]; then
          kind=symlink
          executable=false
          digest="$(printf '%s' "$(readlink "$repo_root/$path")" \
            | _gate_result_sha256_stream)" || {
            rm -f -- "$manifest"
            return 2
          }
        elif [[ -f "$repo_root/$path" ]]; then
          kind="file"
          [[ -x "$repo_root/$path" ]] && executable=true || executable=false
          digest="$(_gate_result_sha256_file "$repo_root/$path")" || {
            rm -f -- "$manifest"
            return 2
          }
        else
          kind=missing
          executable=false
          digest=-
        fi
        printf '%s\t%s\t%s\t%s\n' "$quoted" "$kind" "$executable" "$digest" \
          >> "$manifest"
      done < <(git -C "$repo_root" ls-files --cached --others --exclude-standard -z)
      ;;
    *)
      printf 'Error: unsupported gate subject kind: %s\n' "$subject_kind" >&2
      rm -f -- "$manifest"
      return 2
      ;;
  esac
  LC_ALL=C sort "$manifest" | _gate_result_sha256_stream
  local rc=$?
  rm -f -- "$manifest"
  return "$rc"
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
  expected_digest="$(jq -r '.content.digest // empty' "$manifest_file" 2>/dev/null)"
  actual_digest="$(jq -cS 'del(.content.digest)' "$manifest_file" 2>/dev/null \
    | _gate_result_sha256_stream)" || return $?
  if [[ ! "$expected_digest" =~ ^[a-f0-9]{64}$ \
      || "$actual_digest" != "$expected_digest" ]]; then
    printf 'Error: gate scope manifest content digest mismatch: %s\n' \
      "$manifest_file" >&2
    return 1
  fi
  jq -e \
    --arg repository_key "$repository_key" \
    --arg base_commit "$base_commit" \
    --arg head_commit "$head_commit" \
    --arg tree_fingerprint "$tree_fingerprint" \
    --arg subject_kind "$subject_kind" \
    --arg base_ref "$base_ref" \
    --arg head_ref "$head_ref" '
    def only_keys($allowed):
      (keys | sort) == ($allowed | sort);
    def strings_unique:
      type == "array" and all(.[]; type == "string" and length > 0) and
      length == (unique | length);
    def safe_path:
      type == "string" and length > 0 and
      (startswith("/") | not) and
      ((split("/") | index("..")) == null);
    def paths_unique:
      strings_unique and all(.[]; safe_path);
    def exact_set($other):
      (sort) == ($other | sort);
    def scope_counts:
      only_keys(["diff_hunks","expansion_source_paths",
        "symbols_per_source","matches_per_query",
        "contract_consumers_per_source","expansion_entries"]) and
      all(.[]; type == "number" and . >= 0 and floor == .);
    def scope_flag($changed):
      only_keys(["matched","paths"]) and
      (.matched | type == "boolean") and
      (.paths | paths_unique) and
      (.matched == ((.paths | length) > 0)) and
      all(.paths[]; . as $path | ($changed | index($path)) != null);

      ((keys - ["reference_index"]) | sort) ==
        (["kind","schema_version","status","subject","selection",
          "changes","diff","paired_tests","sensitive_signals","flags",
          "expansion","truncation","content"] | sort) and
    .kind == "gate_scope_manifest_v1" and .schema_version == 1 and
    (.status | IN("complete","accepted_truncation","incomplete")) and
    (.subject |
      only_keys(["repository_key","base_commit","head_commit",
        "tree_fingerprint","subject_kind"]) and
      .repository_key == $repository_key and
      .base_commit == $base_commit and
      .head_commit == $head_commit and
      .tree_fingerprint == $tree_fingerprint and
      .subject_kind == $subject_kind and
      (.repository_key | test("^[a-f0-9]{64}$")) and
      (.base_commit | test("^[a-f0-9]{40}$")) and
      (.head_commit | test("^[a-f0-9]{40}$")) and
      (.tree_fingerprint | test("^[a-f0-9]{64}$")) and
      (.subject_kind | IN("committed_head","working_tree","fixed_ref"))) and
    (.selection |
      only_keys(["diff_kind","base_ref","head_ref","include_untracked"]) and
      (.diff_kind | IN("committed","working-tree","allow-dirty","fixed-head")) and
      .base_ref == $base_ref and
      .head_ref == $head_ref and
      (.include_untracked | type == "boolean")) and
    ((.subject.subject_kind == "committed_head" and
        .selection.diff_kind == "committed") or
     (.subject.subject_kind == "working_tree" and
        (.selection.diff_kind == "working-tree" or
          .selection.diff_kind == "allow-dirty")) or
     (.subject.subject_kind == "fixed_ref" and
        .selection.diff_kind == "fixed-head")) and
    (.selection.include_untracked ==
      (.subject.subject_kind == "working_tree")) and
    (.changes |
      only_keys(["entries","changed_paths","renamed_paths","untracked_paths"]) and
      (.entries | type == "array" and length > 0) and
      all(.entries[];
        only_keys(["status","old_path","new_path","similarity"]) and
        (.status | IN("added","modified","deleted","renamed","copied",
          "type_changed","unmerged","untracked","unknown")) and
        (.old_path == null or (.old_path | safe_path)) and
        (.new_path == null or (.new_path | safe_path)) and
        (if (.status | IN("renamed","copied"))
         then
           (.old_path | safe_path) and (.new_path | safe_path) and
           (.similarity | type == "number" and . >= 0 and . <= 100 and floor == .)
         elif .status == "deleted"
         then (.old_path | safe_path) and .new_path == null and .similarity == null
         else .old_path == null and (.new_path | safe_path) and .similarity == null
         end)) and
      (.changed_paths | paths_unique) and
      (. as $changes |
        ([.entries[] | .old_path,.new_path | select(. != null)] | unique) |
        exact_set($changes.changed_paths)) and
      (.renamed_paths | type == "array" and
        all(.[];
          only_keys(["from","to","similarity"]) and
          (.from | safe_path) and (.to | safe_path) and
          (.similarity | type == "number" and . >= 0 and . <= 100 and floor == .))) and
      (. as $changes |
        ([.entries[] | select(.status == "renamed") |
          {from:.old_path,to:.new_path,similarity:(.similarity // 0)}] | sort) ==
        ($changes.renamed_paths | sort)) and
      (.untracked_paths | paths_unique) and
      (. as $changes |
        ([.entries[] | select(.status == "untracked") | .new_path] | unique) |
        exact_set($changes.untracked_paths))) and
    (.changes.changed_paths as $changed |
      (.diff |
        only_keys(["hunks","binary_or_special_paths"]) and
        (.hunks | type == "array" and
          all(.[];
            only_keys(["path","source","old_start","old_lines",
              "new_start","new_lines","header"]) and
            (.path | safe_path) and
            (.source | IN("tracked","untracked")) and
            all([.old_start,.old_lines,.new_start,.new_lines][];
              type == "number" and . >= 0 and floor == .) and
            (.header | type == "string" and length > 0) and
            (.path as $path | ($changed | index($path)) != null))) and
        (.binary_or_special_paths | paths_unique) and
        all(.binary_or_special_paths[];
          . as $path | ($changed | index($path)) != null)) and
      (.paired_tests | type == "array" and
        all(.[];
          only_keys(["source_path","test_path","reason"]) and
          (.source_path | safe_path) and (.test_path | safe_path) and
          .reason == "language-convention" and
          (.source_path as $path | ($changed | index($path)) != null))) and
      (.sensitive_signals | type == "array" and
        ([.[].id] | strings_unique) and
        all(.[];
          only_keys(["id","source","matches","minimum_tier",
            "required_reviewers","recommended_mode"]) and
          (.id | type == "string" and length > 0) and
          .source == "path-regex" and
          (.matches | strings_unique) and
          all(.matches[]; . as $path | ($changed | index($path)) != null) and
          (.minimum_tier | IN("express","standard","full")) and
          (.required_reviewers | strings_unique) and
          (.recommended_mode | IN("sequential","parallel")))) and
      (.flags as $flags |
        ($flags |
          only_keys(["public_interface","schema","config","install","ci",
            "release","migration"])) and
        ($flags.public_interface | scope_flag($changed)) and
        ($flags.schema | scope_flag($changed)) and
        ($flags.config | scope_flag($changed)) and
        ($flags.install | scope_flag($changed)) and
        ($flags.ci | scope_flag($changed)) and
        ($flags.release | scope_flag($changed)) and
        ($flags.migration | scope_flag($changed)))) and
      (.expansion |
        only_keys(["claim","entries","included_paths"]) and
        .claim == "bounded-hints-not-complete-call-graph" and
      (.entries | type == "array" and
        all(.[];
          only_keys(["path","reason","source","evidence","limit"]) and
          (.path | safe_path) and
          (.reason | IN("same-stem-peer","call-site-hint",
            "shared-helper-consumer")) and
          (.source | type == "string" and length > 0) and
          (.evidence | IN("peer-convention","symbol-reference","path-reference")) and
          (.limit |
            only_keys(["kind","maximum"]) and
            (.kind | IN("per-source","per-symbol","global")) and
            (.maximum | type == "number" and . >= 1 and floor == .)))) and
        (.included_paths | paths_unique) and
        (. as $expansion |
          ([.entries[].path] | unique | exact_set($expansion.included_paths)))) and
      (. as $manifest |
        ([$manifest.changes.changed_paths[]] +
         [$manifest.paired_tests[] | .source_path,.test_path] +
         [$manifest.sensitive_signals[] | .matches[]] +
         [$manifest.flags[] | .paths[]] +
         [$manifest.expansion.included_paths[]] | unique) as $allowed |
        ($manifest.reference_index == null or
          ($manifest.reference_index |
            only_keys(["claim","entries"]) and
            .claim == "declared-review-reference-set" and
            (.entries | type == "array" and length > 0) and
            ([.entries[].path] | strings_unique) and
            all(.entries[];
              only_keys(["path","snapshot","line_count","sha256"]) and
              (.path | safe_path) and
              (.path as $path | ($allowed | index($path)) != null) and
              (.snapshot | IN("subject","base")) and
              (.line_count | type == "number" and . >= 0 and floor == .) and
              (.sha256 | test("^[a-f0-9]{64}$")))))) and
      (. as $manifest | .truncation |
      only_keys(["occurred","budgets","omitted","reasons","acceptance"]) and
      (.occurred | type == "boolean") and
      (.budgets | scope_counts and all(.[]; . >= 1)) and
      (.omitted | scope_counts) and
      (.reasons | strings_unique) and
      all(.reasons[];
        IN("diff-hunk-budget","expansion-source-budget","symbol-budget",
          "search-match-budget","contract-consumer-budget",
          "expansion-entry-budget")) and
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
      (.acceptance |
        only_keys(["required","accepted","source"]) and
        (.required | type == "boolean") and
        (.accepted | type == "boolean") and
        (.source == null or .source == "--accept-scope-truncation")) and
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
       end)) and
    ((.status == "complete" and .truncation.occurred == false) or
     (.status == "accepted_truncation" and
       .truncation.occurred == true and
       .truncation.acceptance.accepted == true) or
     (.status == "incomplete" and
       .truncation.occurred == true and
       .truncation.acceptance.accepted == false)) and
    (.content |
      only_keys(["digest_algorithm","digest"]) and
      .digest_algorithm == "sha256-canonical-json-without-content-digest" and
      (.digest | test("^[a-f0-9]{64}$")))
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
gate_policy_applicability_assess() {
  local assurance_file="$1" consumer="$2" authorization_status="$3"
  local authorization_reason="${4:-dispatch_authorization_unavailable}"
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
    --arg authorization_reason "$authorization_reason" '
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
      if $consumer == "publish" and $a.coordinates.pass.resolved != "initial"
        then "publish_initial_review_required" else empty end
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
    only_keys(["kind","schema_version","result","bindings","subject","evidence",
      "coordinates","policy","dispatch","provenance"]) and
    (.result | only_keys(["final"])) and
    (.bindings | only_keys(["result_sha256","repo_root","repo_identity",
      "base_commit","head_commit","subject_fingerprint"])) and
    (if .kind == "gate_assurance_v3" then
      (.subject |
        only_keys(["kind","schema_version","repository","observed","base","head",
          "tree_fingerprint","subject_kind","dirty_policy","created_at",
          "finished_at","observed_at_finish"])) and
      .subject.kind == "gate_subject_v1" and .subject.schema_version == 1 and
      (.subject.repository |
        only_keys(["key","git_common_dir_identity","remote_identity"])) and
      (.subject.repository.key | test("^[a-f0-9]{64}$")) and
      (.subject.repository.git_common_dir_identity | test("^[a-f0-9]{64}$")) and
      (.subject.repository.remote_identity == null or
        (.subject.repository.remote_identity | test("^[a-f0-9]{64}$"))) and
      (.subject.observed | only_keys(["root","git_common_dir"])) and
      (.subject.observed.root | type == "string" and startswith("/")) and
      (.subject.observed.git_common_dir | type == "string" and startswith("/")) and
      (.subject.base | only_keys(["ref","commit"])) and
      (.subject.base.ref | type == "string" and length > 0) and
      (.subject.base.commit | test("^[a-f0-9]{40}$")) and
      (.subject.head | only_keys(["ref","commit"])) and
      (.subject.head.ref | type == "string" and length > 0) and
      (.subject.head.commit | test("^[a-f0-9]{40}$")) and
      (.subject.tree_fingerprint | test("^[a-f0-9]{64}$")) and
      (.subject.subject_kind | IN("committed_head","working_tree","fixed_ref")) and
      (.subject.dirty_policy |
        IN("require_clean","include_working_tree","ignore_working_tree")) and
      ((.subject.subject_kind == "committed_head" and
          .subject.dirty_policy == "require_clean") or
       (.subject.subject_kind == "working_tree" and
          .subject.dirty_policy == "include_working_tree") or
       (.subject.subject_kind == "fixed_ref" and
          .subject.dirty_policy == "ignore_working_tree")) and
      (.subject.created_at |
        test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")) and
      (.subject.finished_at |
        test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")) and
      (.subject.observed_at_finish |
        only_keys(["repository_key","base_commit","head_commit",
          "tree_fingerprint"])) and
      (.subject.observed_at_finish.repository_key | test("^[a-f0-9]{64}$")) and
      (.subject.observed_at_finish.base_commit | test("^[a-f0-9]{40}$")) and
      (.subject.observed_at_finish.head_commit | test("^[a-f0-9]{40}$")) and
      (.subject.observed_at_finish.tree_fingerprint | test("^[a-f0-9]{64}$")) and
      (.evidence | only_keys(["preflight","scope_manifest","closure"])) and
      (.evidence.preflight |
        only_keys(["status","outcome","artifact","sha256",
          "subject_fingerprint"])) and
      (.evidence.preflight.status | IN("not_run","linked")) and
      (if .evidence.preflight.status == "linked" then
          (.evidence.preflight.outcome |
            IN("pass","fail","test-fail","timeout","environment-error","stale",
              "invalid-evidence","unclassified-nonzero")) and
        (.evidence.preflight.artifact |
          type == "string" and
          test("^preflight-evidence-[0-9]{8}-[0-9]{6}\\.json$")) and
        (.evidence.preflight.sha256 | test("^[a-f0-9]{64}$")) and
        (.evidence.preflight.subject_fingerprint | test("^[a-f0-9]{64}$"))
       else
        .evidence.preflight.outcome == null and
        .evidence.preflight.artifact == null and
        .evidence.preflight.sha256 == null and
        .evidence.preflight.subject_fingerprint == null
       end) and
      (all([.evidence.scope_manifest,.evidence.closure][];
        only_keys(["status","artifact","sha256","subject_fingerprint"]) and
        (.status | IN("unavailable","verified")) and
        (if .status == "verified" then
          (.artifact |
            type == "string" and length > 0 and (contains("/") | not)) and
          (.sha256 | test("^[a-f0-9]{64}$")) and
          (.subject_fingerprint | test("^[a-f0-9]{64}$"))
         else
          .artifact == null and .sha256 == null and .subject_fingerprint == null
         end))) and
      .bindings.repo_root == .subject.observed.root and
      .bindings.repo_identity == .subject.repository.key and
      .bindings.base_commit == .subject.base.commit and
      .bindings.head_commit == .subject.head.commit and
      .bindings.subject_fingerprint == .subject.tree_fingerprint and
      .subject.created_at <= .subject.finished_at
     else
      (has("subject") | not) and (has("evidence") | not)
     end) and
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
    ((.kind == "gate_assurance_v2" and .schema_version == 2) or
      (.kind == "gate_assurance_v3" and .schema_version == 3)) and
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
      (.status | IN("passed","failed","incomplete","skipped")) and
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
       (.dispatch.outcomes[0].status == "failed" or
        .dispatch.outcomes[0].status == "incomplete")
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
  if [[ "$assurance_kind" == gate_assurance_v3 ]]; then
    _gate_assurance_linked_evidence_verify "$assurance_file" || return $?
  fi
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
  local assurance_kind protocol_final
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
    pr_gate_result_v2 | pr_gate_result_v3 | pr_gate_result_v4)
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
          || "$version" == pr_gate_result_v4 ]]; then
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
            "$scope_manifest" || return $?
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
        if [[ "$version" == pr_gate_result_v4 ]]; then
          gate_synthesis_protocol_verify \
            "$result_file" "$selected_reviewers" "$skipped_reviewers" \
            "$scope_sha" || return $?
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
