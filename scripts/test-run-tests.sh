#!/usr/bin/env bash
# Regression tests for the pm-dispatch iteration-only affected test planner.
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s: %s\n' "$1" "$2"; }

make_fixture() {
  local name="$1" repo
  repo="$TMP_ROOT/$name"
  mkdir -p "$repo/scripts/lib" "$repo/core/schema"
  cp "$REPO_ROOT/scripts/run-tests.sh" "$repo/scripts/run-tests.sh"
  cp "$REPO_ROOT/scripts/run-all-tests.sh" "$repo/scripts/run-all-tests.sh"
  cp "$REPO_ROOT/scripts/lib/test-result.sh" "$repo/scripts/lib/test-result.sh"
  cp "$REPO_ROOT/scripts/lib/artifact-paths.sh" "$repo/scripts/lib/artifact-paths.sh"
  cp "$REPO_ROOT/core/schema/test-result.schema.json" "$repo/core/schema/test-result.schema.json"
  chmod +x "$repo/scripts/run-tests.sh"
  cat > "$repo/scripts/lib/test-suite-runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
suites=(lint-agents lint-scripts test-lint-frontmatter test-commands test-check-docs-freshness test-guards test-migrate test-install test-doctor test-pmctl-dispatch test-pmctl-context test-pmctl-memory test-pr-gate test-host-manifest test-host-write-codex test-host-write-parity test-core-schemas test-layer-boundaries test-pm-scripts test-run-tests)
for arg in "$@"; do
  if [[ "$arg" == --list ]]; then printf '%s\n' "${suites[@]}"; exit 0; fi
done
if [[ -n "${RUN_TESTS_MUTATE_PATH:-}" ]]; then
  printf 'mutated during test\n' >> "$RUN_TESTS_MUTATE_PATH"
fi
printf '%s\n' "$@" > "${RUN_TESTS_ARGS_LOG:?}"
exit "${RUN_TESTS_STUB_STATUS:-0}"
RUNNER
  chmod +x "$repo/scripts/lib/test-suite-runner.sh"
  git -C "$repo" init -q
  git -C "$repo" add .
  printf '%s\n' "$repo"
}

case_direct_library_mapping() {
  local name=direct-library-mapping repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path scripts/lib/pmctl-context.sh 2>&1) || status=$?
  if [[ "$status" -eq 0 ]] && grep -qx -- '--suite' "$args" && grep -qx 'lint-scripts' "$args" &&
     grep -qx 'test-pmctl-context' "$args" && [[ "$out" == *"contract=iteration-only"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

case_memory_config_mapping_has_no_gap() {
  local name=memory-config-mapping-has-no-gap repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path scripts/lib/pmctl-config.sh 2>&1) || status=$?
  if [[ "$status" -eq 0 ]] && grep -qx 'test-pmctl-dispatch' "$args" &&
     grep -qx 'test-pmctl-context' "$args" && grep -qx 'test-pmctl-memory' "$args" &&
     [[ "$out" != *"coverage gaps"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

case_docs_mapping_list_only() {
  local name=docs-mapping-list-only repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path docs/context-retrieval.md --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-check-docs-freshness"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out executed=$([[ -e "$args" ]] && echo yes || echo no)"
  fi
}

case_agent_mapping_uses_registered_frontmatter_suite() {
  local name=agent-mapping-uses-registered-frontmatter-suite repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path agents/project-pm.md --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"lint-agents"* && "$out" == *"test-lint-frontmatter"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out executed=$([[ -e "$args" ]] && echo yes || echo no)"
  fi
}

case_command_mapping_uses_registered_frontmatter_suite() {
  local name=command-mapping-uses-registered-frontmatter-suite repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path commands/ship.md --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-lint-frontmatter"* && "$out" == *"test-commands"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out executed=$([[ -e "$args" ]] && echo yes || echo no)"
  fi
}

case_skill_mapping_uses_registered_frontmatter_suite() {
  local name=skill-mapping-uses-registered-frontmatter-suite repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path skills/example/SKILL.md --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-lint-frontmatter"* && "$out" == *"test-commands"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out executed=$([[ -e "$args" ]] && echo yes || echo no)"
  fi
}

case_guard_family_maps_to_guard_suite() {
  local name=guard-family-maps-to-guard-suite repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path scripts/guard-inject-context.sh 2>&1) || status=$?
  if [[ "$status" -eq 0 ]] && grep -qx 'lint-scripts' "$args" && grep -qx 'test-guards' "$args" &&
     [[ "$out" != *"coverage gaps"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

case_prompt_context_timeout_contract_maps_all_consumers() {
  local name=prompt-context-timeout-contract-maps-all-consumers repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" \
    --path hosts/claude/lib/prompt-context-timeouts.sh 2>&1) || status=$?
  if [[ "$status" -eq 0 ]] && grep -qx 'lint-scripts' "$args" &&
     grep -qx 'test-guards' "$args" && grep -qx 'test-install' "$args" &&
     grep -qx 'test-doctor' "$args" && [[ "$out" != *"coverage gaps"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

case_evidence_contract_maps_to_runner_regression() {
  local name=evidence-contract-maps-to-runner-regression repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" \
    --path scripts/lib/test-result.sh --path core/schema/test-result.schema.json \
    --path core/schema/preflight-evidence.schema.json --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-run-tests"* && "$out" == *"test-pr-gate"* &&
        "$out" == *"test-core-schemas"* &&
        "$out" != *"coverage gaps"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_high_fanout_escalates_full() {
  local name=high-fanout-escalates-full repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path scripts/lib/portable.sh 2>&1) || status=$?
  if [[ "$status" -eq 0 && -z "$(tr -d '\n' < "$args")" && "$out" == *"escalating to full suite"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

case_repeated_high_fanout_escalation_succeeds() {
  local name=repeated-high-fanout-escalation-succeeds repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" \
    --path install.sh --path uninstall.sh 2>&1) || status=$?
  if [[ "$status" -eq 0 && -z "$(tr -d '\n' < "$args")" &&
        "$out" == *"escalating to full suite"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

case_unknown_path_fails_without_test_evidence() {
  local name=unknown-path-fails-without-test-evidence repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path package.json 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"coverage gaps"* && "$out" == *"no suites selected"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_selected_failure_propagates() {
  local name=selected-failure-propagates repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" RUN_TESTS_STUB_STATUS=1 "$repo/scripts/run-tests.sh" --path scripts/pr-gate.sh 2>&1) || status=$?
  if [[ "$status" -eq 1 && "$out" == *"selected suites"* && -s "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_explicit_all_delegates_without_selector() {
  local name=explicit-all-delegates repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --all --jobs 3 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"authoritative full suite"* &&
        $(wc -l < "$args") -eq 2 && $(sed -n '1p' "$args") == --jobs && $(sed -n '2p' "$args") == 3 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

case_full_result_verifies_same_tree() {
  local name=full-result-verifies-same-tree repo out status=0 args artifact
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --all --result-file "$artifact" 2>&1) || status=$?
  if [[ "$status" -ne 0 || ! -s "$artifact" ]] ||
     ! jq -e '.kind == "pm_test_result_v2" and .schema_version == 2 and .contract == "full" and
       .authoritative == true and .status == "pass" and (.suite_set | length > 0) and
       ((.suite_results | length) == (.suite_set | length))' "$artifact" >/dev/null; then
    fail "$name" "artifact missing/invalid status=$status out=$out"
    return
  fi
  status=0
  out=$("$repo/scripts/run-tests.sh" --verify-full "$artifact" 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"verified authoritative full PASS"* ]]; then
    pass "$name"
  else
    fail "$name" "verify status=$status out=$out"
  fi
}

case_full_result_rejects_changed_tree() {
  local name=full-result-rejects-changed-tree repo out status=0 args artifact
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --all --result-file "$artifact" >/dev/null 2>&1 || {
    fail "$name" "setup full run failed"; return;
  }
  printf '\npost-test source change\n' >> "$repo/scripts/run-all-tests.sh"
  out=$("$repo/scripts/run-tests.sh" --verify-full "$artifact" 2>&1) || status=$?
  if [[ "$status" -eq 1 && "$out" == *"tree fingerprint does not match"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_tree_change_during_run_marks_stale() {
  local name=tree-change-during-run-marks-stale repo out status=0 args artifact
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  out=$(RUN_TESTS_ARGS_LOG="$args" RUN_TESTS_MUTATE_PATH="$repo/scripts/run-all-tests.sh" \
    "$repo/scripts/run-tests.sh" --all --result-file "$artifact" 2>&1) || status=$?
  if [[ "$status" -eq 1 ]] && jq -e '.status == "stale" and .authoritative == false' "$artifact" >/dev/null 2>&1 &&
     [[ "$out" == *"source tree changed while tests ran"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out artifact=$(cat "$artifact" 2>/dev/null)"
  fi
}

case_iteration_result_cannot_verify_as_full() {
  local name=iteration-result-cannot-verify-as-full repo out status=0 args artifact
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/iteration.json"
  RUN_TESTS_ARGS_LOG="$args" "$repo/scripts/run-tests.sh" --path scripts/lib/pmctl-context.sh \
    --result-file "$artifact" >/dev/null 2>&1 || { fail "$name" "iteration run failed"; return; }
  out=$("$repo/scripts/run-tests.sh" --verify-full "$artifact" 2>&1) || status=$?
  if [[ "$status" -eq 1 && "$out" == *"not an authoritative full PASS"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_direct_library_mapping
case_memory_config_mapping_has_no_gap
case_docs_mapping_list_only
case_agent_mapping_uses_registered_frontmatter_suite
case_command_mapping_uses_registered_frontmatter_suite
case_skill_mapping_uses_registered_frontmatter_suite
case_guard_family_maps_to_guard_suite
case_prompt_context_timeout_contract_maps_all_consumers
case_evidence_contract_maps_to_runner_regression
case_high_fanout_escalates_full
case_repeated_high_fanout_escalation_succeeds
case_unknown_path_fails_without_test_evidence
case_selected_failure_propagates
case_explicit_all_delegates_without_selector
case_full_result_verifies_same_tree
case_full_result_rejects_changed_tree
case_tree_change_during_run_marks_stale
case_iteration_result_cannot_verify_as_full

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
