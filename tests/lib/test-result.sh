#!/usr/bin/env bash
# State-bound test-result artifact helpers for tests/bin/run-tests.sh.

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
    tests/bin/run-all-tests.sh
    tests/bin/run-tests.sh
    tests/lib/test-suite-runner.sh
    tests/lib/test-result.sh
    core/schema/test-result.schema.json
  )
  for rel in "${files[@]}"; do
    [[ -f "$repo/$rel" ]] || { printf 'pm-test-result: runner contract file missing: %s\n' "$rel" >&2; return 2; }
    digest="$(pm_test_sha256_file "$repo/$rel")" || return 2
    printf '%s\t%s\n' "$rel" "$digest"
  done | pm_test_sha256_stream
}

pm_test_repo_identity() {
  local repo="$1" remote
  remote="$(git -C "$repo" config --get remote.origin.url 2>/dev/null || true)"
  printf '%s\n%s\n' "$repo" "$remote" | pm_test_sha256_stream
}

pm_test_write_result() {
  local file="$1" repo="$2" contract="$3" authoritative="$4" status="$5"
  local exit_code="$6" started="$7" finished="$8" before="$9" after="${10}"
  local contract_hash="${11}" selection_mode="${12}" changed_json="${13}"
  local suite_json="${14}" skips_json="${15}" suite_results_json="${16}" base_ref="${17}"
  local repo_identity head_commit base_commit aggregate_json
  local dir tmp
  repo_identity="$(pm_test_repo_identity "$repo")" || return 2
  head_commit="$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)"
  base_commit=""
  if [[ -n "$base_ref" ]]; then
    base_commit="$(git -C "$repo" rev-parse "${base_ref}^{commit}")" || return 2
  fi
  aggregate_json="$(jq -nc --arg status "$status" --argjson results "$suite_results_json" '
    {status:$status,selected:($results|length),
     passed:([$results[]|select(.status=="pass")]|length),
     failed:([$results[]|select(.status=="fail")]|length),
     timed_out:([$results[]|select(.status=="timeout")]|length),
     skipped:([$results[]|select(.status=="skip")]|length)}')" || return 2
  dir="$(dirname "$file")"
  mkdir -p "$dir" || return 2
  tmp="$(mktemp "$dir/.pm-test-result.XXXXXX")" || return 2
  jq -n \
    --arg kind pm_test_result_v2 \
    --argjson schema_version 2 \
    --arg repo_root "$repo" \
    --arg repo_identity "$repo_identity" \
    --arg base_ref "$base_ref" \
    --arg base_commit "$base_commit" \
    --arg head_commit "$head_commit" \
    --arg contract "$contract" \
    --argjson authoritative "$authoritative" \
    --arg status "$status" \
    --argjson exit_code "$exit_code" \
    --arg started_at "$started" \
    --arg finished_at "$finished" \
    --arg tree_fingerprint "$before" \
    --arg observed_tree_fingerprint_after "$after" \
    --arg runner_contract_hash "$contract_hash" \
    --arg selection_mode "$selection_mode" \
    --argjson changed_paths "$changed_json" \
    --argjson suite_set "$suite_json" \
    --argjson requested_skips "$skips_json" \
    --argjson suite_results "$suite_results_json" \
    --argjson aggregate "$aggregate_json" \
    '{kind:$kind,schema_version:$schema_version,repo_root:$repo_root,repo_identity:$repo_identity,
      base_ref:(if $base_ref=="" then null else $base_ref end),
      base_commit:(if $base_commit=="" then null else $base_commit end),
      head_commit:(if $head_commit=="" then null else $head_commit end),contract:$contract,
      authoritative:$authoritative,status:$status,exit_code:$exit_code,
      started_at:$started_at,finished_at:$finished_at,
      tree_fingerprint:$tree_fingerprint,
      observed_tree_fingerprint_after:$observed_tree_fingerprint_after,
      runner_contract_hash:$runner_contract_hash,selection_mode:$selection_mode,
      changed_paths:$changed_paths,suite_set:$suite_set,requested_skips:$requested_skips,
      suite_results:$suite_results,aggregate:$aggregate}' > "$tmp" || { rm -f "$tmp"; return 2; }
  chmod 0600 "$tmp" 2>/dev/null || true
  mv "$tmp" "$file"
  printf 'test result artifact: %s\n' "$file"
}

pm_test_run_and_record() {
  local repo="$1" contract="$2" result_file="$3" selection_mode="$4" changed_json="$5"
  local suite_json="$6" skips_json="$7" base_ref="$8"
  shift 8
  local before after contract_hash started finished rc=0 status authoritative=false
  local suite_results_file suite_results_json
  before="$(pm_test_tree_fingerprint "$repo")" || return 2
  contract_hash="$(pm_test_runner_contract_hash "$repo")" || return 2
  started="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  suite_results_file="$(mktemp "${TMPDIR:-/tmp}/pm-suite-results.XXXXXX")" || return 2
  set +e
  PM_TEST_SUITE_RESULTS_FILE="$suite_results_file" "$@"
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
  # The structured sink is part of the authoritative evidence contract. jq
  # exits successfully with no output for an empty input file, so test size
  # explicitly and fail closed instead of fabricating per-suite PASS records.
  local expected_result_names
  expected_result_names="$suite_json"
  if [[ ! -s "$suite_results_file" ]] ||
     ! suite_results_json="$(jq -ce --argjson expected "$expected_result_names" '
       if type == "array" and length > 0 and [.[].name] == $expected and
          all(.[]; (.status == "pass" or .status == "fail" or .status == "timeout" or .status == "skip") and
                   (.exit_code | type == "number") and
                   (.duration_seconds | type == "number" and . >= 0))
       then . else error("invalid or incomplete structured suite results") end
     ' "$suite_results_file" 2>/dev/null)"; then
    printf 'pm-test-result: suite runner did not emit a valid non-empty structured result sink\n' >&2
    rm -f "$suite_results_file"
    return 2
  fi
  rm -f "$suite_results_file"
  pm_test_write_result "$result_file" "$repo" "$contract" "$authoritative" "$status" \
    "$rc" "$started" "$finished" "$before" "$after" "$contract_hash" "$selection_mode" \
    "$changed_json" "$suite_json" "$skips_json" "$suite_results_json" "$base_ref" || return 2
  [[ "$status" == stale ]] && printf 'run-tests: source tree changed while tests ran; result is stale\n' >&2
  return "$rc"
}

pm_test_verify_full_result() {
  local repo="$1" file="$2" current_tree current_contract expected_suites
  [[ -s "$file" ]] || { printf 'run-tests: full result artifact missing or empty: %s\n' "$file" >&2; return 1; }
  jq -e '
    .kind == "pm_test_result_v2" and .schema_version == 2 and
    .contract == "full" and .authoritative == true and
    .status == "pass" and .exit_code == 0 and
    (.requested_skips == []) and
    (.suite_set | type == "array" and length > 0)
  ' "$file" >/dev/null 2>&1 || {
    printf 'run-tests: artifact is not an authoritative full PASS: %s\n' "$file" >&2
    return 1
  }
  # A retry-recovered suite (see run_suite_retry_once in test-suite-runner.sh)
  # failed at least once before passing; that is legitimate diagnostic signal
  # for an interactive/gate run, but this verifier backs the authoritative
  # release-readiness claim, where a suite that failed even once must not be
  # indistinguishable from one that passed cleanly on its first attempt. Any
  # retry-recovered suite makes the artifact non-authoritative here -- get a
  # clean rerun (PM_DISPATCH_TEST_SUITE_RETRY_ON_FAIL=0 catches this
  # deterministically) before it can back a release.
  if jq -e '.suite_results | any(.[]; .reason == "flaky, passed on retry")' \
      "$file" >/dev/null 2>&1; then
    printf 'run-tests: artifact contains a retry-recovered suite (failed once, passed on retry) -- not authoritative for release; rerun with PM_DISPATCH_TEST_SUITE_RETRY_ON_FAIL=0 for a clean result\n' >&2
    return 1
  fi
  current_tree="$(pm_test_tree_fingerprint "$repo")" || return 2
  current_contract="$(pm_test_runner_contract_hash "$repo")" || return 2
  expected_suites="$("$repo/tests/lib/test-suite-runner.sh" --list | jq -Rsc 'split("\n") | map(select(length > 0))')" || return 2
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
