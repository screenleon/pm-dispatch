#!/usr/bin/env bash
# Shared gate-result integrity, subject freshness, and applicability verification.

_grv_yaml_field() {
  local file="$1" key="$2"
  awk -v key="$key" 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) exit } s && index($0,key ": ")==1 { sub("^[^:]+: ",""); print; exit }' "$file"
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
  local root="$1" manifest path quoted kind executable digest
  manifest="$(mktemp "${TMPDIR:-/tmp}/gate-subject.XXXXXX")" || return 2
  git -C "$root" ls-files -s -- \
    . ':(exclude).agent-trace/**' ':(exclude).gate-briefs/**' ':(exclude).gate-results/**' \
    >> "$manifest" || { rm -f "$manifest"; return 2; }
  git -C "$root" diff --binary HEAD -- \
    . ':(exclude).agent-trace/**' ':(exclude).gate-briefs/**' ':(exclude).gate-results/**' \
    >> "$manifest" || { rm -f "$manifest"; return 2; }
  while IFS= read -r -d '' path; do
    case "$path" in
      .agent-trace|.agent-trace/*|.gate-briefs|.gate-briefs/*|.gate-results|.gate-results/*) continue ;;
    esac
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
  expected_digest="$(_grv_yaml_field "$result_file" artifact_sha256)"
  if [[ -n "$expected_digest" ]]; then
    [[ "$expected_digest" =~ ^[a-f0-9]{64}$ ]] || { printf 'Error: malformed artifact_sha256 in gate result: %s\n' "$result_file" >&2; return 1; }
    current_digest="$(_grv_content_digest "$result_file")" || return 2
    [[ "$current_digest" == "$expected_digest" ]] || { printf 'Error: gate result content digest mismatch: %s\n' "$result_file" >&2; return 1; }
  fi
  return 0
}

# gate_result_attest <result_file> <repo_root> <base_ref> <head_ref> <subject_kind> <created_at>
gate_result_attest() {
  local file="$1" root="$2" base_ref="$3" head_ref="$4" subject_kind="$5" created_at="$6"
  local physical canonical common repo_key common_id remote_id base_commit head_commit tree finished tmp digest
  physical="$(cd "$root" && pwd)"; canonical="$(_grv_canonical_path "$root")" || return 1
  common="$(_grv_git_common_dir "$canonical")" || return 1
  repo_key="$(_grv_repository_key "$canonical")" || return 1
  common_id="$(_grv_common_dir_identity "$canonical")" || return 1
  remote_id="$(_grv_remote_identity "$canonical")" || return 1
  base_commit="$(git -C "$canonical" rev-parse "${base_ref}^{commit}")" || return 1
  head_commit="$(git -C "$canonical" rev-parse "${head_ref}^{commit}")" || return 1
  if [[ "$subject_kind" == fixed_ref ]]; then
    tree="$(_grv_ref_fingerprint "$canonical" "$head_ref")" || return 1
  else tree="$(_grv_tree_fingerprint "$canonical")" || return 1
  fi
  finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  tmp="${file}.attest-tmp"
  awk -v rk="$repo_key" -v ci="$common_id" -v ri="$remote_id" -v pr="$physical" -v cr="$canonical" \
    -v br="$base_ref" -v bc="$base_commit" -v hr="$head_ref" -v hc="$head_commit" -v tf="$tree" \
    -v sk="$subject_kind" -v ca="$created_at" -v fa="$finished" '
    /^---$/ { fence++; if (fence == 2) {
      print "gate_subject_version: 1"; print "repository_key: " rk; print "git_common_dir_identity: " ci
      print "remote_identity: " ri; print "observed_physical_root: " pr; print "observed_canonical_root: " cr
      print "base_ref: " br; print "base_commit: " bc; print "head_ref: " hr; print "head_commit: " hc
      print "tree_fingerprint: " tf; print "subject_kind: " sk; print "dirty_policy: " (sk == "working_tree" ? "allow" : "deny")
      print "created_at: " ca; print "finished_at: " fa; print "artifact_sha256: PENDING"
    }} { print }' "$file" > "$tmp" || return 1
  mv "$tmp" "$file"
  digest="$(_grv_content_digest "$file")" || return 1
  sed "s/^artifact_sha256: PENDING$/artifact_sha256: $digest/" "$file" > "$tmp" && mv "$tmp" "$file"
}

_grv_tier_rank() { case "$1" in express) echo 1;; standard) echo 2;; full) echo 3;; *) echo 0;; esac; }

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
            else current="$(_grv_tree_fingerprint "$root" 2>/dev/null || true)"
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
    pa=true; tier="$(_grv_yaml_field "$file" tier)"; mode="$(_grv_yaml_field "$file" mode)"
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

export -f gate_result_verify gate_result_attest gate_result_assess
