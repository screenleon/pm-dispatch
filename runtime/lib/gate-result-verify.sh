#!/usr/bin/env bash
# Shared gate-result integrity and assurance verification.
#
# pr_gate_result_v1 remains valid legacy structural evidence.  It proves only
# frontmatter/body verdict parity and is reported as assurance=unavailable.
# pr_gate_result_v2 points at a sibling assurance JSON envelope owned by the
# gate shell. Legacy gate_assurance_v1 remains readable but non-authorizing;
# gate_assurance_v2 adds result bindings and protected dispatch attestation.
# gate_assurance_v3 adds an immutable subject plus digest-bound evidence links.

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
          select(. == "pass" or . == "fail" or . == "timeout" or
            . == "stale" or . == "invalid")' "$artifact_path" 2>/dev/null
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
      if [[ ( "$linked_outcome" == pass && "$artifact_outcome" != pass ) \
          || ( "$linked_outcome" == fail && "$artifact_outcome" == pass ) ]]; then
        printf 'Error: gate assurance linked preflight evidence outcome mismatch: %s\n' \
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
    $assurance[0] as $a |
    (if $consumer == "embedded" then $a.policy.consumer_policy
     elif $consumer == "publish" then "maintainer"
     else $consumer end) as $required_policy |
    ([
      if $a.result.final != "GO" then "verdict_not_go" else empty end,
      if ($a | has("policy") | not) then "policy_resolution_unavailable" else empty end,
      if $a.policy.consumer_policy != $required_policy
        then "consumer_policy_mismatch" else empty end,
      if $a.policy.enforcement.status != "pass"
        then "policy_enforcement_failed" else empty end,
      if $a.coordinates.independence.evidence_status != "verified"
        then "review_independence_unverified" else empty end,
      if any($a.dispatch.outcomes[];
        .status != "passed" or .evidence_status != "verified" or .run_id == null)
        then "review_dispatch_evidence_incomplete" else empty end,
      if $authorization_status != "verified"
        then $authorization_reason else empty end,
      if $consumer == "publish" and $a.evidence.closure.status != "verified"
        then "closure_evidence_unavailable" else empty end
    ] | unique) as $reasons |
    {
      status:(if ($reasons | length) == 0 then "pass" else "fail" end),
      reason_codes:$reasons,
      consumer:$consumer,
      required_policy:$required_policy,
      embedded_policy:$a.policy.consumer_policy
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
        (.evidence.preflight.outcome | IN("pass","fail")) and
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
