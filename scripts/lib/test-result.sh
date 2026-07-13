#!/usr/bin/env bash
# State-bound test-result artifact helpers for scripts/run-tests.sh.

pm_test_sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    printf 'pm-test-result: sha256sum or shasum is required\n' >&2
    return 2
  fi
}

pm_test_sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$file" | awk '{print $1}'
  else
    printf 'pm-test-result: sha256sum or shasum is required\n' >&2
    return 2
  fi
}

pm_test_path_is_runtime_artifact() {
  local path="$1" leaf
  case "$path" in
    .pm-dispatch|.pm-dispatch/*) return 0 ;;
  esac
  for leaf in "${PM_ARTIFACT_LEAVES[@]:-}"; do
    [[ "$path" == "$leaf" || "$path" == "$leaf/"* ]] && return 0
  done
  return 1
}

# Fingerprints the actual files under test: tracked working-tree content plus
# untracked, non-ignored content. Runtime artifacts are excluded. The manifest
# includes path, kind, executable bit, and content/link-target digest.
pm_test_tree_fingerprint() {
  local repo="$1" manifest path quoted kind executable digest
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    printf 'pm-test-result: not a git worktree: %s\n' "$repo" >&2
    return 2
  }
  manifest="$(mktemp "${TMPDIR:-/tmp}/pm-test-tree.XXXXXX")" || return 2
  while IFS= read -r -d '' path; do
    pm_test_path_is_runtime_artifact "$path" && continue
    quoted="$(printf '%q' "$path")"
    if [[ -L "$repo/$path" ]]; then
      kind=symlink
      executable=false
      digest="$(printf '%s' "$(readlink "$repo/$path")" | pm_test_sha256_stream)" || { rm -f "$manifest"; return 2; }
    elif [[ -f "$repo/$path" ]]; then
      kind='file'
      [[ -x "$repo/$path" ]] && executable=true || executable=false
      digest="$(pm_test_sha256_file "$repo/$path")" || { rm -f "$manifest"; return 2; }
    elif [[ -e "$repo/$path" ]]; then
      kind=other
      executable=false
      digest="$(git -C "$repo" ls-files -s -- "$path" | pm_test_sha256_stream)" || { rm -f "$manifest"; return 2; }
    else
      kind=missing
      executable=false
      digest=-
    fi
    printf '%s\t%s\t%s\t%s\n' "$quoted" "$kind" "$executable" "$digest" >> "$manifest"
  done < <(git -C "$repo" ls-files --cached --others --exclude-standard -z)
  LC_ALL=C sort "$manifest" | pm_test_sha256_stream
  local rc=$?
  rm -f "$manifest"
  return "$rc"
}

pm_test_runner_contract_hash() {
  local repo="$1" rel digest
  local files=(
    scripts/run-all-tests.sh
    scripts/run-tests.sh
    scripts/lib/test-suite-runner.sh
    scripts/lib/test-result.sh
    core/schema/test-result.schema.json
  )
  for rel in "${files[@]}"; do
    [[ -f "$repo/$rel" ]] || { printf 'pm-test-result: runner contract file missing: %s\n' "$rel" >&2; return 2; }
    digest="$(pm_test_sha256_file "$repo/$rel")" || return 2
    printf '%s\t%s\n' "$rel" "$digest"
  done | pm_test_sha256_stream
}

pm_test_write_result() {
  local file="$1" repo="$2" contract="$3" authoritative="$4" status="$5"
  local exit_code="$6" started="$7" finished="$8" before="$9" after="${10}"
  local contract_hash="${11}" suite_json="${12}" skips_json="${13}"
  local dir tmp
  dir="$(dirname "$file")"
  mkdir -p "$dir" || return 2
  tmp="$(mktemp "$dir/.pm-test-result.XXXXXX")" || return 2
  jq -n \
    --arg kind pm_test_result_v1 \
    --argjson schema_version 1 \
    --arg repo_root "$repo" \
    --arg contract "$contract" \
    --argjson authoritative "$authoritative" \
    --arg status "$status" \
    --argjson exit_code "$exit_code" \
    --arg started_at "$started" \
    --arg finished_at "$finished" \
    --arg tree_fingerprint "$before" \
    --arg observed_tree_fingerprint_after "$after" \
    --arg runner_contract_hash "$contract_hash" \
    --argjson suite_set "$suite_json" \
    --argjson requested_skips "$skips_json" \
    '{kind:$kind,schema_version:$schema_version,repo_root:$repo_root,contract:$contract,
      authoritative:$authoritative,status:$status,exit_code:$exit_code,
      started_at:$started_at,finished_at:$finished_at,
      tree_fingerprint:$tree_fingerprint,
      observed_tree_fingerprint_after:$observed_tree_fingerprint_after,
      runner_contract_hash:$runner_contract_hash,
      suite_set:$suite_set,requested_skips:$requested_skips}' > "$tmp" || { rm -f "$tmp"; return 2; }
  chmod 0600 "$tmp" 2>/dev/null || true
  mv "$tmp" "$file"
  printf 'test result artifact: %s\n' "$file"
}

pm_test_run_and_record() {
  local repo="$1" contract="$2" result_file="$3" suite_json="$4" skips_json="$5"
  shift 5
  local before after contract_hash started finished rc=0 status authoritative=false
  before="$(pm_test_tree_fingerprint "$repo")" || return 2
  contract_hash="$(pm_test_runner_contract_hash "$repo")" || return 2
  started="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  set +e
  "$@"
  rc=$?
  set -e
  finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  after="$(pm_test_tree_fingerprint "$repo")" || return 2
  if [[ "$before" != "$after" ]]; then
    status=stale
    [[ "$rc" -eq 0 ]] && rc=1
  elif [[ "$rc" -eq 0 ]]; then
    status=pass
  else
    status=fail
  fi
  if [[ "$contract" == full && "$status" == pass && "$skips_json" == '[]' ]]; then
    authoritative=true
  fi
  pm_test_write_result "$result_file" "$repo" "$contract" "$authoritative" "$status" \
    "$rc" "$started" "$finished" "$before" "$after" "$contract_hash" "$suite_json" "$skips_json" || return 2
  [[ "$status" == stale ]] && printf 'run-tests: source tree changed while tests ran; result is stale\n' >&2
  return "$rc"
}

pm_test_verify_full_result() {
  local repo="$1" file="$2" current_tree current_contract expected_suites
  [[ -s "$file" ]] || { printf 'run-tests: full result artifact missing or empty: %s\n' "$file" >&2; return 1; }
  jq -e '
    .kind == "pm_test_result_v1" and .schema_version == 1 and
    .contract == "full" and .authoritative == true and
    .status == "pass" and .exit_code == 0 and
    (.requested_skips == []) and
    (.suite_set | type == "array" and length > 0)
  ' "$file" >/dev/null 2>&1 || {
    printf 'run-tests: artifact is not an authoritative full PASS: %s\n' "$file" >&2
    return 1
  }
  current_tree="$(pm_test_tree_fingerprint "$repo")" || return 2
  current_contract="$(pm_test_runner_contract_hash "$repo")" || return 2
  expected_suites="$("$repo/scripts/lib/test-suite-runner.sh" --list | jq -Rsc 'split("\n") | map(select(length > 0))')" || return 2
  [[ "$(jq -r '.tree_fingerprint' "$file")" == "$current_tree" ]] || {
    printf 'run-tests: full result tree fingerprint does not match current source tree\n' >&2; return 1;
  }
  [[ "$(jq -r '.observed_tree_fingerprint_after' "$file")" == "$current_tree" ]] || {
    printf 'run-tests: full result was not stable across its test run\n' >&2; return 1;
  }
  [[ "$(jq -r '.runner_contract_hash' "$file")" == "$current_contract" ]] || {
    printf 'run-tests: full result runner contract hash is stale\n' >&2; return 1;
  }
  jq -e --argjson expected "$expected_suites" '.suite_set == $expected' "$file" >/dev/null 2>&1 || {
    printf 'run-tests: full result suite registry does not match current runner\n' >&2; return 1;
  }
  printf 'run-tests: verified authoritative full PASS for tree %s\n' "$current_tree"
}
