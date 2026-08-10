#!/usr/bin/env bash
# Shared gate-result integrity, subject freshness, and applicability verification.

_GRV_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -r "$_GRV_LIB_DIR/gate-assurance.sh" ]]; then
  # Optional sibling library, guarded above.
  # shellcheck source=runtime/lib/gate-assurance.sh
  # shellcheck disable=SC1091
  . "$_GRV_LIB_DIR/gate-assurance.sh"
fi

_grv_yaml_field() {
  local file="$1" key="$2"
  awk -v key="$key" 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) exit } s && index($0,key ": ")==1 { sub("^[^:]+: ",""); print; exit }' "$file"
}

_grv_yaml_nested_field() {
  local file="$1" parent="$2" key="$3"
  awk -v parent="$parent" -v key="$key" '
    /^---$/ { fence++; next }
    fence == 1 && $0 == parent ":" { in_parent=1; next }
    in_parent && /^[^ ]/ { exit }
    in_parent && index($0, "  " key ": ") == 1 {
      sub("^  " key ":[[:space:]]*", ""); print; exit
    }
  ' "$file"
}

_grv_sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  else printf 'gate-result-verify: sha256sum or shasum is required\n' >&2; return 2
  fi
}

_grv_sha256_file() { _grv_sha256_stream < "$1"; }

# The digest covers the complete artifact except its own digest field.
_grv_content_digest() { sed '/^artifact_sha256: /d' "$1" | _grv_sha256_stream; }

_grv_assurance_list() {
  local value="$1" item
  [[ "$value" == \[*\] ]] || return 1
  value="${value#[}"
  value="${value%]}"
  [[ -z "${value//[[:space:]]/}" ]] && return 0
  while IFS= read -r item || [[ -n "$item" ]]; do
    item="$(printf '%s' "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ "$item" =~ ^[a-z][a-z-]*$ ]] || return 1
    printf '%s\n' "$item"
  done < <(printf '%s' "$value" | tr ',' '\n')
}

_grv_assurance_has_token() {
  local tokens="${1//$'\n'/ }"
  [[ " $tokens " == *" $2 "* ]]
}

_grv_assurance_token_count() {
  awk -v token="$2" '$0 == token { count++ } END { print count + 0 }' <<<"$1"
}

_grv_validate_coverage_assurance() {
  local file="$1" tier="$2" reviewers_raw skipped_raw expected known reviewer selected="" skipped=""
  reviewers_raw="$(_grv_yaml_nested_field "$file" coverage_assurance reviewers)"
  skipped_raw="$(_grv_yaml_nested_field "$file" coverage_assurance skipped)"
  [[ -n "$reviewers_raw" && -n "$skipped_raw" ]] || {
    printf 'Error: assurance coverage declaration is incomplete\n' >&2
    return 1
  }
  selected="$(_grv_assurance_list "$reviewers_raw")" || {
    printf 'Error: assurance reviewers must be a bracketed reviewer list\n' >&2
    return 1
  }
  skipped="$(_grv_assurance_list "$skipped_raw")" || {
    printf 'Error: assurance skipped must be a bracketed reviewer list\n' >&2
    return 1
  }
  expected="$(gate_assurance_default_reviewers "$tier")" || return 1
  known="$(gate_assurance_mandatory_full_reviewers)" || return 1
  [[ -n "$selected" ]] || {
    printf 'Error: assurance coverage has no selected reviewers\n' >&2
    return 1
  }
  for reviewer in $selected $skipped; do
    _grv_assurance_has_token "$known" "$reviewer" || {
      printf 'Error: assurance coverage names unknown reviewer: %s\n' "$reviewer" >&2
      return 1
    }
  done
  for reviewer in $selected; do
    [[ "$(_grv_assurance_token_count "$selected" "$reviewer")" -eq 1 ]] || {
      printf 'Error: assurance coverage duplicates selected reviewer: %s\n' "$reviewer" >&2
      return 1
    }
    _grv_assurance_has_token "$skipped" "$reviewer" && {
      printf 'Error: assurance coverage overlaps selected/skipped reviewer: %s\n' "$reviewer" >&2
      return 1
    }
  done
  for reviewer in $skipped; do
    [[ "$(_grv_assurance_token_count "$skipped" "$reviewer")" -eq 1 ]] || {
      printf 'Error: assurance coverage duplicates skipped reviewer: %s\n' "$reviewer" >&2
      return 1
    }
  done
  if [[ "$tier" != targeted ]]; then
    for reviewer in $expected; do
      _grv_assurance_has_token "$selected" "$reviewer" || {
        printf 'Error: assurance coverage misses required %s reviewer: %s\n' "$tier" "$reviewer" >&2
        return 1
      }
    done
    [[ "$(wc -w <<<"$selected")" -eq "$(wc -w <<<"$expected")" ]] || {
      printf 'Error: assurance coverage has reviewers outside resolved %s tier\n' "$tier" >&2
      return 1
    }
  fi
  for reviewer in $known; do
    if _grv_assurance_has_token "$selected" "$reviewer"; then
      ! _grv_assurance_has_token "$skipped" "$reviewer" || return 1
    else
      _grv_assurance_has_token "$skipped" "$reviewer" || {
        printf 'Error: assurance coverage omits reviewer from selected/skipped partition: %s\n' "$reviewer" >&2
        return 1
      }
    fi
  done
}

_grv_parallel_evidence_hash() {
  local file="$1" reviewer="$2"
  awk -v reviewer="$reviewer" '
    /^---$/ { fence++; next }
    fence == 1 && $0 == "parallel_reviewer_evidence:" { in_evidence=1; next }
    in_evidence && /^[^ ]/ { exit }
    in_evidence && $0 == "  artifacts:" { in_artifacts=1; next }
    in_artifacts && /^  [^ ]/ { exit }
    in_artifacts && $0 ~ "^    " reviewer ": " {
      sub("^    " reviewer ":[[:space:]]*", ""); print; exit
    }
  ' "$file"
}

_grv_parallel_evidence_names() {
  awk '
    /^---$/ { fence++; next }
    fence == 1 && $0 == "parallel_reviewer_evidence:" { in_evidence=1; next }
    in_evidence && /^[^ ]/ { exit }
    in_evidence && $0 == "  artifacts:" { in_artifacts=1; next }
    in_artifacts && /^  [^ ]/ { exit }
    in_artifacts && /^    [a-z][a-z-]*:/ {
      name=$1; sub(/:$/, "", name); print name
    }
  ' "$1"
}

_grv_validate_parallel_evidence() {
  local file="$1" reviewers_raw selected run_id evidence_names reviewer digest artifact_dir artifact
  reviewers_raw="$(_grv_yaml_nested_field "$file" coverage_assurance reviewers)"
  selected="$(_grv_assurance_list "$reviewers_raw")" || return 1
  run_id="$(_grv_yaml_nested_field "$file" parallel_reviewer_evidence run_id)"
  [[ "$run_id" =~ ^[0-9]{8}-[0-9]{6}$ ]] || {
    printf 'Error: parallel assurance lacks a valid reviewer evidence run id\n' >&2
    return 1
  }
  evidence_names="$(_grv_parallel_evidence_names "$file")"
  for reviewer in $selected; do
    [[ "$(_grv_assurance_token_count "$evidence_names" "$reviewer")" -eq 1 ]] || {
      printf 'Error: parallel assurance lacks evidence for reviewer: %s\n' "$reviewer" >&2
      return 1
    }
    digest="$(_grv_parallel_evidence_hash "$file" "$reviewer")"
    [[ "$digest" =~ ^[a-f0-9]{64}$ ]] || {
      printf 'Error: parallel assurance has malformed evidence digest for reviewer: %s\n' "$reviewer" >&2
      return 1
    }
    artifact_dir="$(dirname "$file")"
    artifact="$artifact_dir/reviewer-${reviewer}-${run_id}.md"
    [[ -f "$artifact" ]] || {
      printf 'Error: parallel assurance reviewer artifact is missing: %s\n' "$artifact" >&2
      return 1
    }
    [[ "$(_grv_sha256_file "$artifact")" == "$digest" ]] || {
      printf 'Error: parallel assurance reviewer artifact digest mismatch: %s\n' "$artifact" >&2
      return 1
    }
  done
  for reviewer in $evidence_names; do
    _grv_assurance_has_token "$selected" "$reviewer" || {
      printf 'Error: parallel assurance has evidence for unselected reviewer: %s\n' "$reviewer" >&2
      return 1
    }
  done
}

_grv_validate_assurance() {
  local file="$1" version tier mode requested_tier requested_mode topology independent evidence legacy
  version="$(_grv_yaml_field "$file" assurance_contract_version)"
  [[ -z "$version" ]] && return 0
  [[ "$version" == 1 ]] || { printf 'Error: unsupported assurance_contract_version: %s\n' "$version" >&2; return 1; }
  tier="$(_grv_yaml_nested_field "$file" tier_assurance resolved)"
  mode="$(_grv_yaml_nested_field "$file" mode_assurance resolved)"
  requested_tier="$(_grv_yaml_nested_field "$file" tier_assurance requested)"
  requested_mode="$(_grv_yaml_nested_field "$file" mode_assurance requested)"
  topology="$(_grv_yaml_nested_field "$file" independence_assurance session_topology)"
  independent="$(_grv_yaml_nested_field "$file" independence_assurance per_reviewer_independent)"
  evidence="$(_grv_yaml_nested_field "$file" independence_assurance session_evidence)"
  if ! declare -F gate_assurance_valid_tier >/dev/null \
    || ! gate_assurance_valid_tier "$tier"; then
    printf 'Error: invalid resolved tier assurance: %s\n' "$tier" >&2
    return 1
  fi
  if ! declare -F gate_assurance_valid_mode >/dev/null \
    || ! gate_assurance_valid_mode "$mode"; then
    printf 'Error: invalid resolved mode assurance: %s\n' "$mode" >&2
    return 1
  fi
  [[ "$requested_tier" == auto || "$requested_tier" == targeted ]] \
    || gate_assurance_valid_tier "$requested_tier" \
    || { printf 'Error: invalid requested tier assurance: %s\n' "$requested_tier" >&2; return 1; }
  [[ "$requested_mode" == default ]] || gate_assurance_valid_mode "$requested_mode" \
    || { printf 'Error: invalid requested mode assurance: %s\n' "$requested_mode" >&2; return 1; }
  [[ "$topology" == "$(gate_assurance_mode_topology "$mode")" \
    && "$independent" == "$(gate_assurance_mode_independence "$mode")" ]] \
    || { printf 'Error: mode assurance contradicts topology/independence evidence\n' >&2; return 1; }
  [[ "$evidence" == "$(gate_assurance_mode_evidence "$mode")" ]] \
    || { printf 'Error: mode assurance lacks matching session evidence\n' >&2; return 1; }
  legacy="$(_grv_yaml_field "$file" tier)"; [[ -z "$legacy" || "$legacy" == "$tier" ]] \
    || { printf 'Error: legacy tier contradicts resolved tier assurance\n' >&2; return 1; }
  legacy="$(_grv_yaml_field "$file" mode)"; [[ -z "$legacy" || "$legacy" == "$mode" ]] \
    || { printf 'Error: legacy mode contradicts resolved mode assurance\n' >&2; return 1; }
  _grv_validate_coverage_assurance "$file" "$tier" || return 1
  [[ "$mode" != parallel ]] || _grv_validate_parallel_evidence "$file"
}

_grv_canonical_path() { (cd "$1" 2>/dev/null && pwd -P); }

_grv_git_common_dir() {
  local root="$1" common
  common="$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)" || return 1
  [[ "$common" == /* ]] || common="$root/$common"
  _grv_canonical_path "$common"
}

_grv_remote_identity() {
  local root="$1" remote
  remote="$(git -C "$root" config --get remote.origin.url 2>/dev/null || true)"
  [[ -n "$remote" ]] || { printf 'none'; return; }
  printf '%s' "$remote" | _grv_sha256_stream
}

# A stable clone identity: remote identity when present, otherwise the root commit.
# The common-dir identity is recorded separately so a copied clone cannot masquerade
# as the reviewed repository merely by having the same history.
_grv_repository_key() {
  local root="$1" remote root_commit
  remote="$(git -C "$root" config --get remote.origin.url 2>/dev/null || true)"
  root_commit="$(git -C "$root" rev-list --max-parents=0 HEAD 2>/dev/null | LC_ALL=C sort | head -1)" || return 1
  printf '%s\n%s\n' "$remote" "$root_commit" | _grv_sha256_stream
}

_grv_common_dir_identity() {
  local common
  common="$(_grv_git_common_dir "$1")" || return 1
  printf '%s' "$common" | _grv_sha256_stream
}

# Bind the index plus tracked working-tree delta and non-ignored untracked
# contents. `git diff --binary` carries modes and symlink targets without a
# process-per-tracked-file scan, keeping verification practical on real repos.
_grv_tree_fingerprint() {
  local root="$1" manifest path quoted kind executable digest excluded_path
  shift
  local -a excluded_paths=("$@")
  local -a pathspec=(. ':(exclude).agent-trace/**' ':(exclude).gate-briefs/**' ':(exclude).gate-results/**')
  for excluded_path in "${excluded_paths[@]}"; do
    [[ -z "$excluded_path" ]] || pathspec+=(":(exclude,literal)$excluded_path")
  done
  manifest="$(mktemp "${TMPDIR:-/tmp}/gate-subject.XXXXXX")" || return 2
  git -C "$root" ls-files -s -- "${pathspec[@]}" >> "$manifest" \
    || { rm -f "$manifest"; return 2; }
  git -C "$root" diff --binary HEAD -- "${pathspec[@]}" >> "$manifest" \
    || { rm -f "$manifest"; return 2; }
  while IFS= read -r -d '' path; do
    case "$path" in
      .agent-trace|.agent-trace/*|.gate-briefs|.gate-briefs/*|.gate-results|.gate-results/*) continue ;;
    esac
    for excluded_path in "${excluded_paths[@]}"; do
      [[ -z "$excluded_path" || "$path" != "$excluded_path" ]] || continue 2
    done
    quoted="$(printf '%q' "$path")"
    if [[ -L "$root/$path" ]]; then
      kind='symlink'; executable='false'
      digest="$(printf '%s' "$(readlink "$root/$path")" | _grv_sha256_stream)" || { rm -f "$manifest"; return 2; }
    elif [[ -f "$root/$path" ]]; then
      kind='file'
      if [[ -x "$root/$path" ]]; then executable='true'; else executable='false'; fi
      digest="$(_grv_sha256_file "$root/$path")" || { rm -f "$manifest"; return 2; }
    else kind='missing'; executable='false'; digest='-'
    fi
    printf '%s\t%s\t%s\t%s\n' "$quoted" "$kind" "$executable" "$digest" >> "$manifest"
  done < <(git -C "$root" ls-files --others --exclude-standard -z)
  _grv_sha256_file "$manifest"
  local rc=$?; rm -f "$manifest"; return "$rc"
}

_grv_ref_fingerprint() {
  git -C "$1" ls-tree -r --full-tree "$2" | _grv_sha256_stream
}

# gate_result_verify <result_file> [expected_final] [route_label]
# Backward-compatible structural verification. Attested results additionally have
# their content digest checked, so copying is safe while mutation fails closed.
gate_result_verify() {
  local result_file=${1-} expected_final=${2-} route_label=${3-gate}
  local final_count frontmatter_final body_final expected_digest current_digest
  [[ $# -ge 1 && $# -le 3 ]] || { printf 'gate-result-verify: gate_result_verify expects <result_file> [expected_final] [route_label]\n' >&2; return 2; }
  if [[ ! -s "$result_file" ]]; then
    printf 'Error: %s did not produce the result file: %s\n' "$route_label" "$result_file" >&2
    printf 'Gate aborted -- the executor session may have exited 0 without writing a verdict.\n' >&2; return 1
  fi
  final_count=$(grep -cE '^Final: (GO|NO-GO)$' "$result_file" || true)
  [[ "$final_count" -eq 1 ]] || { printf 'Error: gate result file must contain exactly one Final: GO/NO-GO line (found %d): %s\n' "$final_count" "$result_file" >&2; return 1; }
  frontmatter_final="$(_grv_yaml_field "$result_file" final)"
  [[ -n "$frontmatter_final" ]] || { printf 'Error: gate result YAML frontmatter missing required field: final: (%s)\n' "$result_file" >&2; return 1; }
  body_final=$(grep -E '^Final: (GO|NO-GO)$' "$result_file" | awk '{print $2}')
  [[ "$frontmatter_final" == "$body_final" ]] || { printf 'Error: frontmatter final: (%s) does not match body Final: (%s) in gate result: %s\n' "$frontmatter_final" "$body_final" "$result_file" >&2; return 1; }
  [[ -z "$expected_final" || "$body_final" == "$expected_final" ]] || { printf 'Error: %s verdict (%s) contradicts shell-computed verdict (%s) -- gate result may have been manipulated: %s\n' "$route_label" "$body_final" "$expected_final" "$result_file" >&2; return 1; }
  _grv_validate_assurance "$result_file" || return 1
  expected_digest="$(_grv_yaml_field "$result_file" artifact_sha256)"
  if [[ -n "$expected_digest" ]]; then
    [[ "$expected_digest" =~ ^[a-f0-9]{64}$ ]] || { printf 'Error: malformed artifact_sha256 in gate result: %s\n' "$result_file" >&2; return 1; }
    current_digest="$(_grv_content_digest "$result_file")" || return 2
    [[ "$current_digest" == "$expected_digest" ]] || { printf 'Error: gate result content digest mismatch: %s\n' "$result_file" >&2; return 1; }
  fi
  return 0
}

# gate_result_attest <result_file> <repo_root> <base_ref> <head_ref> <subject_kind> <created_at>
#   [tier_requested tier_resolved mode_requested mode_resolved reviewers skipped
#    parallel_run_id parallel_reviewer_hashes]
gate_result_attest() {
  local file="$1" root="$2" base_ref="$3" head_ref="$4" subject_kind="$5" created_at="$6"
  local tier_requested="${7-}" tier_resolved="${8-}" mode_requested="${9-}" mode_resolved="${10-}"
  local coverage_reviewers="${11-}" coverage_skipped="${12-}" parallel_run_id="${13-}" parallel_hashes="${14-}"
  local topology="" independent="" session_evidence="" reviewer pair digest evidence_count=0
  local physical canonical common repo_key common_id remote_id base_commit head_commit tree finished tmp digest artifact_repo_path=""
  local -a artifact_exclusions=()
  physical="$(cd "$root" && pwd)"; canonical="$(_grv_canonical_path "$root")" || return 1
  common="$(_grv_git_common_dir "$canonical")" || return 1
  repo_key="$(_grv_repository_key "$canonical")" || return 1
  common_id="$(_grv_common_dir_identity "$canonical")" || return 1
  remote_id="$(_grv_remote_identity "$canonical")" || return 1
  base_commit="$(git -C "$canonical" rev-parse "${base_ref}^{commit}")" || return 1
  head_commit="$(git -C "$canonical" rev-parse "${head_ref}^{commit}")" || return 1
  case "$file" in "$canonical"/*) artifact_repo_path="${file#"$canonical"/}" ;; esac
  [[ -z "$artifact_repo_path" ]] || artifact_exclusions+=("$artifact_repo_path")
  if [[ "$subject_kind" == fixed_ref ]]; then
    tree="$(_grv_ref_fingerprint "$canonical" "$head_ref")" || return 1
  fi
  finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  if [[ -n "$tier_resolved" ]]; then
    if ! declare -F gate_assurance_valid_tier >/dev/null \
      || ! gate_assurance_valid_tier "$tier_resolved"; then
      return 1
    fi
    if ! declare -F gate_assurance_valid_mode >/dev/null \
      || ! gate_assurance_valid_mode "$mode_resolved"; then
      return 1
    fi
    topology="$(gate_assurance_mode_topology "$mode_resolved")" || return 1
    independent="$(gate_assurance_mode_independence "$mode_resolved")" || return 1
    session_evidence="$(gate_assurance_mode_evidence "$mode_resolved")" || return 1
    if [[ "$mode_resolved" == parallel ]]; then
      [[ "$parallel_run_id" =~ ^[0-9]{8}-[0-9]{6}$ ]] || return 1
      for reviewer in ${coverage_reviewers//,/ }; do
        digest=""
        for pair in $parallel_hashes; do
          [[ "${pair%%:*}" == "$reviewer" ]] && digest="${pair#*:}"
        done
        [[ "$digest" =~ ^[a-f0-9]{64}$ ]] || return 1
        evidence_count=$((evidence_count + 1))
        if [[ -n "$artifact_repo_path" ]]; then
          artifact_exclusions+=("$(dirname "$artifact_repo_path")/reviewer-${reviewer}-${parallel_run_id}.md")
        fi
      done
      [[ "$evidence_count" -eq "$(wc -w <<<"$parallel_hashes")" ]] || return 1
    fi
  fi
  if [[ "$subject_kind" != fixed_ref ]]; then
    tree="$(_grv_tree_fingerprint "$canonical" "${artifact_exclusions[@]}")" || return 1
  fi
  tmp="${file}.attest-tmp"
  awk -v rk="$repo_key" -v ci="$common_id" -v ri="$remote_id" -v pr="$physical" -v cr="$canonical" \
    -v br="$base_ref" -v bc="$base_commit" -v hr="$head_ref" -v hc="$head_commit" -v tf="$tree" \
    -v sk="$subject_kind" -v ca="$created_at" -v fa="$finished" -v arp="$artifact_repo_path" \
    -v trq="$tier_requested" -v trs="$tier_resolved" -v mrq="$mode_requested" -v mrs="$mode_resolved" \
    -v cov="$coverage_reviewers" -v skip="$coverage_skipped" -v topology="$topology" -v independent="$independent" \
    -v session_evidence="$session_evidence" -v parallel_run_id="$parallel_run_id" -v parallel_hashes="$parallel_hashes" '
    /^---$/ { fence++; if (fence == 2) {
      print "gate_subject_version: 1"; print "repository_key: " rk; print "git_common_dir_identity: " ci
      print "remote_identity: " ri; print "observed_physical_root: " pr; print "observed_canonical_root: " cr
      print "base_ref: " br; print "base_commit: " bc; print "head_ref: " hr; print "head_commit: " hc
      print "tree_fingerprint: " tf; print "subject_kind: " sk; print "dirty_policy: " (sk == "working_tree" ? "allow" : "deny")
      print "artifact_repo_path: " (arp == "" ? "none" : arp)
      print "created_at: " ca; print "finished_at: " fa; print "artifact_sha256: PENDING"
      if (trs != "") {
        print "assurance_contract_version: 1"
        print "tier_assurance:"; print "  requested: " trq; print "  resolved: " trs
        print "mode_assurance:"; print "  requested: " mrq; print "  resolved: " mrs
        print "coverage_assurance:"; print "  reviewers: [" cov "]"; print "  skipped: [" skip "]"
        print "independence_assurance:"; print "  implementation_context_isolated: true"
        print "  session_topology: " topology; print "  per_reviewer_independent: " independent
        print "  session_evidence: " session_evidence
        if (mrs == "parallel") {
          print "parallel_reviewer_evidence:"; print "  run_id: " parallel_run_id; print "  artifacts:"
          count=split(parallel_hashes, entries, " ")
          for (i = 1; i <= count; i++) {
            split(entries[i], pair, ":")
            print "    " pair[1] ": " pair[2]
          }
        }
      }
    }} { print }' "$file" > "$tmp" || return 1
  mv "$tmp" "$file"
  digest="$(_grv_content_digest "$file")" || return 1
  sed "s/^artifact_sha256: PENDING$/artifact_sha256: $digest/" "$file" > "$tmp" && mv "$tmp" "$file"
}

_grv_tier_rank() {
  if declare -F gate_assurance_tier_rank >/dev/null; then gate_assurance_tier_rank "$1"
  else case "$1" in express) echo 1;; standard) echo 2;; full) echo 3;; *) echo 0;; esac
  fi
}

_grv_tree_is_dirty() {
  ! git -C "$1" diff --quiet --ignore-submodules -- 2>/dev/null \
    || ! git -C "$1" diff --cached --quiet --ignore-submodules -- 2>/dev/null \
    || [[ -n "$(git -C "$1" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]]
}

# gate_result_assess <file> [repo_root] [required_tier] [required_mode]
# Emits one JSON object and returns 0 only when every requested axis passes.
gate_result_assess() {
  local file="$1" root="${2-}" required_tier="${3-}" required_mode="${4-}"
  local av=true sc=null pa=null ar='' sr='' pr='' expected current field expected_value actual tier mode dirty_policy
  local reviewer run_id artifact_repo_path
  local -a artifact_exclusions=()
  if ! command -v jq >/dev/null 2>&1; then
    printf 'gate-result-verify: jq is required for structured gate assessment\n' >&2
    return 2
  fi
  if ! gate_result_verify "$file" >/dev/null 2>&1; then av=false; ar=artifact_invalid; fi
  if [[ "$av" == true && -n "$root" ]]; then
    sc=true
    if [[ -z "$(_grv_yaml_field "$file" gate_subject_version)" ]]; then sc=false; sr=subject_missing
    else
      for field in repository_key git_common_dir_identity head_commit tree_fingerprint; do
        expected="$(_grv_yaml_field "$file" "$field")"
        case "$field" in
          repository_key) current="$(_grv_repository_key "$root" 2>/dev/null || true)";;
          git_common_dir_identity) current="$(_grv_common_dir_identity "$root" 2>/dev/null || true)";;
          head_commit)
            actual="$(_grv_yaml_field "$file" subject_kind)"
            if [[ "$actual" == fixed_ref ]]; then
              expected_value="$(_grv_yaml_field "$file" head_ref)"
              current="$(git -C "$root" rev-parse "${expected_value}^{commit}" 2>/dev/null || true)"
            else current="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
            fi
            ;;
          tree_fingerprint)
            actual="$(_grv_yaml_field "$file" subject_kind)"
            if [[ "$actual" == fixed_ref ]]; then
              expected_value="$(_grv_yaml_field "$file" head_ref)"
              current="$(_grv_ref_fingerprint "$root" "$expected_value" 2>/dev/null || true)"
            else
              artifact_repo_path="$(_grv_yaml_field "$file" artifact_repo_path)"
              [[ "$artifact_repo_path" != none ]] || artifact_repo_path=""
              artifact_exclusions=()
              [[ -z "$artifact_repo_path" ]] || artifact_exclusions+=("$artifact_repo_path")
              if [[ "$(_grv_yaml_nested_field "$file" mode_assurance resolved)" == parallel && -n "$artifact_repo_path" ]]; then
                run_id="$(_grv_yaml_nested_field "$file" parallel_reviewer_evidence run_id)"
                for reviewer in $(_grv_assurance_list "$(_grv_yaml_nested_field "$file" coverage_assurance reviewers)" 2>/dev/null || true); do
                  artifact_exclusions+=("$(dirname "$artifact_repo_path")/reviewer-${reviewer}-${run_id}.md")
                done
              fi
              current="$(_grv_tree_fingerprint "$root" "${artifact_exclusions[@]}" 2>/dev/null || true)"
            fi
            ;;
        esac
        if [[ -z "$expected" || "$expected" != "$current" ]]; then sc=false; sr="${sr:+$sr,}${field}_mismatch"; fi
      done
      expected="$(_grv_yaml_field "$file" base_commit)"; actual="$(_grv_yaml_field "$file" base_ref)"
      current="$(git -C "$root" rev-parse "${actual}^{commit}" 2>/dev/null || true)"
      [[ -n "$expected" && "$expected" == "$current" ]] || { sc=false; sr="${sr:+$sr,}base_commit_mismatch"; }
      actual="$(_grv_yaml_field "$file" subject_kind)"
      dirty_policy="$(_grv_yaml_field "$file" dirty_policy)"
      case "$actual:$dirty_policy" in
        working_tree:allow|committed_head:deny|fixed_ref:deny) : ;;
        *) sc=false; sr="${sr:+$sr,}dirty_policy_mismatch" ;;
      esac
      if [[ "$actual" == committed_head && "$dirty_policy" == deny ]] && _grv_tree_is_dirty "$root"; then
        sc=false; sr="${sr:+$sr,}dirty_policy_violation"
      fi
    fi
  elif [[ "$av" == true ]]; then
    sr=subject_not_checked
  fi
  if [[ "$av" == true && ( -n "$required_tier" || -n "$required_mode" ) ]]; then
    pa=true
    if [[ -n "$(_grv_yaml_field "$file" assurance_contract_version)" ]]; then
      tier="$(_grv_yaml_nested_field "$file" tier_assurance resolved)"
      mode="$(_grv_yaml_nested_field "$file" mode_assurance resolved)"
    else
      tier="$(_grv_yaml_field "$file" tier)"; mode="$(_grv_yaml_field "$file" mode)"
    fi
    if [[ -n "$required_tier" ]]; then
      if [[ "$tier" == targeted && "$required_tier" != targeted ]]; then
        pa=false; pr=targeted_requires_initial_coverage
      elif [[ "$required_tier" == targeted && "$tier" != targeted ]]; then
        pa=false; pr=targeted_tier_required
      elif [[ "$tier" != targeted && $(_grv_tier_rank "$tier") -eq 0 ]]; then
        pa=false; pr=tier_unknown
      elif [[ "$tier" != targeted && $(_grv_tier_rank "$tier") -lt $(_grv_tier_rank "$required_tier") ]]; then
        pa=false; pr=tier_insufficient
      fi
    fi
    if [[ -n "$required_mode" && "$mode" != "$required_mode" ]]; then pa=false; pr="${pr:+$pr,}mode_mismatch"; fi
  fi
  jq -nc --argjson av "$av" --argjson sc "$sc" --argjson pa "$pa" --arg ar "$ar" --arg sr "$sr" --arg pr "$pr" \
    '{artifact_valid:$av,subject_current:$sc,policy_applicable:$pa,reasons:{artifact:(if ($ar|length)>0 then $ar else null end),subject:(if ($sr|length)>0 then ($sr|split(",")) else [] end),policy:(if ($pr|length)>0 then ($pr|split(",")) else [] end)}}'
  [[ "$av" == true && "$sc" == true && "$pa" != false ]]
}

# Exported public functions can outlive their private dependencies when a Bash
# child inherits BASH_FUNC_* entries without sourcing this library. Consumers
# use this readiness predicate before trusting an inherited public function.
gate_result_library_ready() {
  local fn
  for fn in gate_result_verify gate_result_attest gate_result_assess \
    _grv_yaml_field _grv_yaml_nested_field _grv_validate_assurance \
    _grv_content_digest _grv_tree_is_dirty _grv_repository_key; do
    declare -F "$fn" >/dev/null 2>&1 || return 1
  done
  return 0
}

export -f gate_result_verify gate_result_attest gate_result_assess gate_result_library_ready
