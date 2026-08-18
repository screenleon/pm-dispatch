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

if ! declare -F gate_remediation_closure_verify >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-closure-verify.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-closure-verify.sh"
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

# Closure publication must never traverse a symlinked ancestor.  The leaf
# check above is intentionally separate because an existing leaf can be
# inspected without following it; the parent check protects the write path
# used by mktemp(1) and ln(1).  realpath -m -s normalizes lexically and does
# not resolve symlinks, so every existing component can then be checked
# without losing the original path boundary.
_gate_closure_destination_parent_check() {
  local path="$1" parent normalized prefix component
  local -a components=() normalized_parts=()

  parent="${path%/*}"
  [[ "$parent" != "$path" ]] || parent=.
  if [[ "$parent" != /* ]]; then
    parent="$(pwd -P)/$parent" || return 1
  fi
  if command -v realpath >/dev/null 2>&1; then
    normalized="$(realpath -m -s -- "$parent" 2>/dev/null)" || normalized=""
  else
    normalized=""
  fi
  if [[ -z "$normalized" ]]; then
    # Keep the guard usable in restricted PATHs (the Gate test fixtures and
    # some deployed runners intentionally omit external path utilities).
    local segment
    IFS='/' read -r -a components <<< "${parent#/}"
    for segment in "${components[@]}"; do
      case "$segment" in
        ''|.) ;;
        ..)
          if ((${#normalized_parts[@]} > 0)); then
            unset 'normalized_parts[-1]'
          fi
          ;;
        *) normalized_parts+=("$segment") ;;
      esac
    done
    normalized=/
    for segment in "${normalized_parts[@]}"; do
      [[ "$normalized" == / ]] || normalized+="/"
      normalized+="$segment"
    done
  fi
  [[ -d "$normalized" ]] || {
    printf 'gate-closure: destination parent is unavailable: %s\n' "$normalized" >&2
    return 1
  }

  IFS='/' read -r -a components <<< "${normalized#/}"
  prefix=/
  for component in "${components[@]}"; do
    [[ -n "$component" ]] || continue
    prefix="${prefix%/}/$component"
    [[ -L "$prefix" ]] && {
      printf 'gate-closure: destination parent must not traverse a symlink: %s\n' "$prefix" >&2
      return 1
    }
    [[ -d "$prefix" ]] || {
      printf 'gate-closure: destination parent component is not a directory: %s\n' "$prefix" >&2
      return 1
    }
  done
}

# Pin the validated parent as the process working directory before any
# temporary-file or no-replace publication operation. A directory cwd keeps
# referring to the original inode even if a concurrent process renames the
# pathname and replaces it with a symlink after validation.
_gate_closure_destination_parent_pin() {
  local path="$1" parent normalized actual segment
  local -a components=() normalized_parts=()
  parent="${path%/*}"
  [[ "$parent" != "$path" ]] || parent=.
  if [[ "$parent" != /* ]]; then
    parent="$(pwd -P)/$parent" || return 1
  fi
  if command -v realpath >/dev/null 2>&1; then
    normalized="$(realpath -m -s -- "$parent" 2>/dev/null)" || normalized=""
  else
    normalized=""
  fi
  if [[ -z "$normalized" ]]; then
    IFS='/' read -r -a components <<< "${parent#/}"
    for segment in "${components[@]}"; do
      case "$segment" in
        ''|.) ;;
        ..)
          if ((${#normalized_parts[@]} > 0)); then
            unset 'normalized_parts[-1]'
          fi
          ;;
        *) normalized_parts+=("$segment") ;;
      esac
    done
    normalized=/
    for segment in "${normalized_parts[@]}"; do
      [[ "$normalized" == / ]] || normalized+="/"
      normalized+="$segment"
    done
  fi
  cd -P -- "$parent" || {
    printf 'gate-closure: unable to pin destination parent: %s\n' "$parent" >&2
    return 1
  }
  actual="$(pwd -P)" || return 1
  [[ "$actual" == "$normalized" ]] || {
    printf 'gate-closure: destination parent changed or traverses a symlink: %s\n' "$path" >&2
    return 1
  }
  IFS='/' read -r -a components <<< "${actual#/}"
  parent=/
  for segment in "${components[@]}"; do
    [[ -n "$segment" ]] || continue
    parent="${parent%/}/$segment"
    [[ -L "$parent" ]] && {
      printf 'gate-closure: pinned destination parent contains a symlink: %s\n' "$parent" >&2
      return 1
    }
    [[ -d "$parent" ]] || return 1
  done
  GATE_CLOSURE_PINNED_LEAF="${path##*/}"
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
gate_remediation_closure_publish() (
  local result_file="${1:-}" assurance_file="${2:-}" closure_file="${3:-}"
  local full_result="${4:-}" ticket_ref="${5:-}"
  local result_parent scope_artifact scope_file scope_sha subject_json subject_fp
  local final primary_result primary_subject primary_verdict
  local primary_artifact primary_sha synthesis_tmp primary_synthesis_tmp
  local findings_json primary_findings_json reviewers_json
  local changed_files_json closure_tmp full_status full_tree full_artifact full_sha
  local test_evidence_json targeted_status targeted_reviewers
  local result_sha closure_output

  [[ $# -ge 3 && $# -le 5 ]] || {
    printf 'gate-closure: publish expects <result> <assurance> <closure> [full-result] [ticket-ref]\n' >&2
    return 2
  }
  [[ -s "$result_file" && -s "$assurance_file" ]] || {
    printf 'gate-closure: result and assurance artifacts are required\n' >&2
    return 1
  }
  closure_output="$closure_file"
  result_file="$(cd "$(dirname "$result_file")" && pwd -P)/$(basename "$result_file")" || return 1
  assurance_file="$(cd "$(dirname "$assurance_file")" && pwd -P)/$(basename "$assurance_file")" || return 1
  if [[ -n "$full_result" ]]; then
    full_result="$(cd "$(dirname "$full_result")" && pwd -P)/$(basename "$full_result")" || return 1
  fi
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
  # Targeted publication is allowed to select only the immutable v3 baseline
  # accepted at argv validation. Falling back to the current result would
  # make a failed or legacy initial run look like authorization evidence.
  if [[ "$(jq -r '.coordinates.pass.resolved // empty' "$assurance_file")" == targeted \
      && "$final" != INCOMPLETE ]]; then
    local initial_input initial_candidate initial_sha expected_initial_sha
    local initial_assurance_sha expected_initial_assurance_sha
    initial_input="$(jq -r '.coordinates.pass.initial_result // empty' "$assurance_file")"
    [[ -n "$initial_input" ]] || {
      printf 'gate-closure: targeted publication requires an immutable v3 initial result\n' >&2
      return 1
    }
    initial_candidate="$initial_input"
    [[ "$initial_candidate" == /* ]] || initial_candidate="$result_parent/$initial_candidate"
    [[ -s "$initial_candidate" && -s "${initial_candidate}.assurance.json" ]] || {
      printf 'gate-closure: targeted initial result or assurance sidecar is unavailable: %s\n' \
        "$initial_candidate" >&2
      return 1
    }
    expected_initial_sha="$(jq -r '.coordinates.pass.initial_result_sha256 // empty' \
      "$assurance_file")"
    [[ "$expected_initial_sha" =~ ^[a-f0-9]{64}$ ]] || {
      printf 'gate-closure: targeted assurance lacks the accepted initial-result digest: %s\n' \
        "$initial_candidate" >&2
      return 1
    }
    initial_sha="$(gate_digest_file "$initial_candidate")" || return 1
    [[ "$initial_sha" == "$expected_initial_sha" ]] || {
      printf 'gate-closure: targeted initial result changed after acceptance: %s\n' \
        "$initial_candidate" >&2
      return 1
    }
    expected_initial_assurance_sha="$(jq -r \
      '.coordinates.pass.initial_assurance_sha256 // empty' "$assurance_file")"
    [[ "$expected_initial_assurance_sha" =~ ^[a-f0-9]{64}$ ]] || {
      printf 'gate-closure: targeted assurance lacks the accepted initial-sidecar digest: %s\n' \
        "$initial_candidate" >&2
      return 1
    }
    initial_assurance_sha="$(gate_digest_file "${initial_candidate}.assurance.json")" || return 1
    [[ "$initial_assurance_sha" == "$expected_initial_assurance_sha" ]] || {
      printf 'gate-closure: targeted initial assurance sidecar changed after acceptance: %s\n' \
        "${initial_candidate}.assurance.json" >&2
      return 1
    }
    if ! jq -e \
        '.kind == "gate_assurance_v3" and .schema_version == 3 and
         (.subject.tree_fingerprint | type == "string" and
          test("^[a-f0-9]{64}$"))' \
        "${initial_candidate}.assurance.json" >/dev/null 2>&1; then
      printf 'gate-closure: targeted initial result must carry a subject-bound v3 assurance sidecar: %s\n' \
        "$initial_candidate" >&2
      return 1
    fi
    primary_result="$initial_candidate"
  fi
  primary_artifact="$(basename "$primary_result")"
  primary_sha="$(gate_digest_file "$primary_result")" || return 1
  result_sha="$(gate_digest_file "$result_file")" || return 1
  primary_verdict="$(grep -m1 -E '^Final: (GO|NO-GO|INCOMPLETE)$' "$primary_result" | awk '{print $2}')"
  primary_subject="$subject_json"
  if [[ "$primary_result" != "$result_file" ]]; then
    primary_subject="$(_gate_closure_subject_json "${primary_result}.assurance.json")" || return 1
  fi

  synthesis_tmp="$(mktemp "${TMPDIR:-/tmp}/gate-closure-synthesis.XXXXXX.json")" || return 1
  findings_json='[]'
  primary_findings_json='[]'
  reviewers_json='[]'
  if _gate_closure_synthesis_json "$result_file" "$synthesis_tmp"; then
    findings_json="$(jq -c '.findings_union // []' "$synthesis_tmp")" || {
      rm -f "$synthesis_tmp"; return 1;
    }
    reviewers_json="$(jq -c '.selected_reviewers // []' "$synthesis_tmp")" || {
      rm -f "$synthesis_tmp"; return 1;
    }
  fi
  # A targeted pass confirms the primary review; it does not replace its
  # finding ledger. Preserve every primary finding in the closure and let the
  # current targeted synthesis override an identically named entry when it
  # supplies a refreshed source or disposition.
  if [[ "$primary_result" != "$result_file" ]]; then
    primary_synthesis_tmp="$(mktemp "${TMPDIR:-/tmp}/gate-closure-primary-synthesis.XXXXXX.json")" || {
      rm -f "$synthesis_tmp"; return 1;
    }
    if _gate_closure_synthesis_json "$primary_result" "$primary_synthesis_tmp"; then
      primary_findings_json="$(jq -c '.findings_union // []' "$primary_synthesis_tmp")" || {
        rm -f "$synthesis_tmp" "$primary_synthesis_tmp"; return 1;
      }
    fi
    rm -f "$primary_synthesis_tmp"
    findings_json="$(jq -cn --argjson primary "$primary_findings_json" \
      --argjson current "$findings_json" \
      '($primary + $current) | group_by(.id) | map(.[-1])')" || {
      rm -f "$synthesis_tmp"; return 1;
    }
  fi

  changed_files_json="$(jq -c --argjson findings "$findings_json" '
    ([.changes.changed_paths[], .changes.renamed_paths[]?.from,
      .changes.renamed_paths[]?.to, .changes.untracked_paths[],
      .diff.binary_or_special_paths[]]) |
      map(select(type == "string" and length > 0)) | unique | sort
  ' "$scope_file")" || {
    rm -f "$synthesis_tmp"; return 1;
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
      rm -f "$synthesis_tmp"
      return 1
    fi
    full_status=pass
    full_artifact="$(basename "$full_result")"
    full_sha="$(gate_digest_file "$full_result")" || { rm -f "$synthesis_tmp"; return 1; }
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

  # Validate the parent before creating any temporary file. Otherwise
  # mktemp(1) would itself follow a symlinked ancestor and briefly write
  # outside the trusted artifact directory before the later leaf checks run.
  _gate_closure_destination_parent_pin "$closure_file" || {
    rm -f "$synthesis_tmp"
    return 1
  }
  closure_file="./$GATE_CLOSURE_PINNED_LEAF"
  # Test-only seam used by the deterministic directory-swap regression. The
  # subsequent writes are relative to the pinned directory cwd.
  if declare -F gate_closure_test_after_parent_pin >/dev/null 2>&1; then
    gate_closure_test_after_parent_pin || {
      rm -f "$synthesis_tmp"
      return 1
    }
  fi
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
    --argjson targeted_reviewers "$targeted_reviewers" --arg final "$final" \
    --arg result_artifact "$(basename "$result_file")" --arg result_sha "$result_sha" \
    --arg full_status "$full_status" --arg ticket_ref "$ticket_ref" '
    ($findings | map(
      . as $f |
      (if $f.origin == "uncertain" then
        {disposition:"split",classification:"stop_split",verification_status:"split"}
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
      # A reviewer source is evidence, not proof that the cited file changed.
      # Never manufacture attribution from the first manifest path. When a
      # diff-caused finding has no changed-path source, keep the closure
      # non-authorizing and split it until synthesis supplies a truthful
      # changed-path relationship.
      {finding_id:$f.id,origin:$f.origin,
       disposition:(if ($f.origin == "diff_caused" and
                        ($changed_files | index($f.source.path)) == null)
                    then "split" else $claim.disposition end),
       classification:(if ($f.origin == "diff_caused" and
                           ($changed_files | index($f.source.path)) == null)
                       then "stop_split" else $claim.classification end),
       changed_paths:(if ($changed_files | index($f.source.path)) != null then
         [$f.source.path] else [] end),
       evidence_refs:[$f.source],
       affected_test_ids:(if $full_status == "pass" then ["gate-review","full-suite"] else ["gate-review"] end),
       verification_status:(if ($f.origin == "diff_caused" and
                                ($changed_files | index($f.source.path)) == null)
                            then "split" else $claim.verification_status end)}
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
    rm -f "$closure_tmp" "$synthesis_tmp"
    return 1
  fi
  rm -f "$synthesis_tmp"
  _gate_closure_destination_check "$closure_file" || { rm -f "$closure_tmp"; return 1; }
  # Finalization is retryable across the narrow crash window between
  # publishing the closure and linking its digest into the assurance sidecar.
  # The closure is deterministic for the same inputs, so an already-published
  # byte-identical artifact is safe to reuse. A different artifact remains a
  # hard immutability violation and is never overwritten.
  if [[ -e "$closure_file" ]]; then
    if cmp -s "$closure_tmp" "$closure_file"; then
      rm -f "$closure_tmp"
      if ! gate_remediation_closure_verify "$closure_file" "$subject_fp" "$scope_sha"; then
        printf 'gate-closure: existing identical artifact failed verification: %s\n' \
          "$closure_file" >&2
        return 1
      fi
      printf '%s\n' "$closure_output"
      return 0
    fi
    printf 'gate-closure: immutable destination contains different content: %s\n' \
      "$closure_file" >&2
    rm -f "$closure_tmp"
    return 1
  fi
  # Link-then-unlink is an atomic no-replace publish on the same filesystem:
  # unlike `mv`, it cannot overwrite a closure that appeared after the
  # destination check. The temporary file is created beside the destination,
  # so the link is guaranteed to stay on one filesystem.
  if ! ln -- "$closure_tmp" "$closure_file"; then
    # A concurrent finalizer may have won the no-replace race. Reuse its
    # artifact only when it is byte-identical; otherwise retain the immutable
    # destination failure.
    if [[ -e "$closure_file" ]] && cmp -s "$closure_tmp" "$closure_file"; then
      rm -f "$closure_tmp"
      if ! gate_remediation_closure_verify "$closure_file" "$subject_fp" "$scope_sha"; then
        printf 'gate-closure: concurrent identical artifact failed verification: %s\n' \
          "$closure_file" >&2
        return 1
      fi
      printf '%s\n' "$closure_output"
      return 0
    fi
    printf 'gate-closure: destination already exists or cannot be published: %s\n' \
      "$closure_file" >&2
    rm -f "$closure_tmp"
    return 1
  fi
  rm -f "$closure_tmp"
  if ! gate_remediation_closure_verify "$closure_file" "$subject_fp" "$scope_sha"; then
    printf 'gate-closure: published artifact failed its own verification: %s\n' "$closure_file" >&2
    return 1
  fi
  printf '%s\n' "$closure_output"
)

# gate_remediation_closure_bind_assurance <result> <assurance> <closure>
#
# Targeted Gate runs need their non-authorizing closure linked before a ship
# publish consumer can verify the result. Keep this binding beside the shared
# publisher, while leaving generic assurance finalization independent of the
# ship-owned closure contract.
gate_remediation_closure_bind_assurance() (
  local result_file="$1" assurance_file="$2" closure_file="$3"
  local closure_sha closure_json assurance_tmp assurance_leaf subject_fp scope_sha
  [[ -s "$result_file" && -s "$assurance_file" && -s "$closure_file" ]] || {
    printf 'gate-closure: cannot bind a missing targeted closure or assurance\n' >&2
    return 1
  }
  _gate_closure_destination_parent_pin "$assurance_file" || return 1
  assurance_leaf="$GATE_CLOSURE_PINNED_LEAF"
  subject_fp="$(jq -r '.subject.tree_fingerprint // empty' "$assurance_leaf")" || return 1
  scope_sha="$(jq -r '.evidence.scope_manifest.sha256 // empty' "$assurance_leaf")" || return 1
  [[ "$subject_fp" =~ ^[a-f0-9]{64}$ && "$scope_sha" =~ ^[a-f0-9]{64}$ ]] || {
    printf 'gate-closure: assurance lacks a valid subject or scope for closure binding\n' >&2
    return 1
  }
  closure_sha="$(gate_digest_file "$closure_file")" || return 1
  if ! gate_remediation_closure_verify "$closure_file" "$subject_fp" "$scope_sha"; then
    printf 'gate-closure: supplied closure failed verification before assurance binding: %s\n' \
      "$closure_file" >&2
    return 1
  fi
  if declare -F gate_closure_test_after_assurance_parent_pin >/dev/null 2>&1; then
    gate_closure_test_after_assurance_parent_pin || return 1
  fi
  _gate_closure_destination_check "$assurance_leaf" || return 1
  closure_json="$(jq -nc \
    --arg artifact "$(basename "$closure_file")" \
    --arg sha256 "$closure_sha" \
    --arg subject_fingerprint "$subject_fp" \
    '{status:"verified",artifact:$artifact,sha256:$sha256,subject_fingerprint:$subject_fingerprint}')" || return 1
  assurance_tmp="$(mktemp "${assurance_leaf}.closure-tmp.XXXXXX")" || return 1
  if ! jq --argjson closure "$closure_json" '.evidence.closure = $closure' \
      "$assurance_leaf" > "$assurance_tmp"; then
    rm -f -- "$assurance_tmp"
    return 1
  fi
  _gate_closure_destination_check "$assurance_leaf" || {
    rm -f -- "$assurance_tmp"
    return 1
  }
  if ! mv -- "$assurance_tmp" "$assurance_leaf"; then
    rm -f -- "$assurance_tmp"
    return 1
  fi
)
