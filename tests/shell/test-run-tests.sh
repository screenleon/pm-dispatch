#!/usr/bin/env bash
# Regression tests for the pm-dispatch iteration-only affected test planner.
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# This suite launches fixture copies of the iteration runner; see
# tests/lib/test-env-isolation.sh for why the cleared set is inventory-driven.
# shellcheck source=tests/lib/test-env-isolation.sh
# shellcheck disable=SC1091 # CI runs shellcheck without -x; the source= hint above names the file.
. "$REPO_ROOT/tests/lib/test-env-isolation.sh"
test_env_scrub_fixture_inputs "$REPO_ROOT"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s: %s\n' "$1" "$2"; }

make_fixture() {
  local name="$1" repo
  repo="$TMP_ROOT/$name"
  mkdir -p "$repo/scripts/lib" "$repo/runtime/lib" "$repo/tests/bin" "$repo/tests/lib" \
    "$repo/core/schema" "$repo/core/state" "$repo/core/policy"
  cp "$REPO_ROOT/tests/bin/run-tests.sh" "$repo/tests/bin/run-tests.sh"
  cp "$REPO_ROOT/tests/bin/run-all-tests.sh" "$repo/tests/bin/run-all-tests.sh"
  cp "$SCRIPT_DIR/../lib/test-result.sh" "$repo/tests/lib/test-result.sh"
  cp "$REPO_ROOT/runtime/lib/artifact-paths.sh" "$repo/runtime/lib/artifact-paths.sh"
  cp "$REPO_ROOT/core/schema/test-result.schema.json" "$repo/core/schema/test-result.schema.json"
  cp "$REPO_ROOT/core/policy/gate-tiers.tsv" "$repo/core/policy/gate-tiers.tsv"
  cp "$REPO_ROOT/core/policy/gate-modes.tsv" "$repo/core/policy/gate-modes.tsv"
  cp "$REPO_ROOT/core/policy/gate-pass-kinds.tsv" "$repo/core/policy/gate-pass-kinds.tsv"
  cp "$REPO_ROOT/core/policy/gate-policy-consumers.tsv" "$repo/core/policy/gate-policy-consumers.tsv"
  cp "$REPO_ROOT/core/policy/gate-policy-signals.tsv" "$repo/core/policy/gate-policy-signals.tsv"
  chmod +x "$repo/tests/bin/run-tests.sh"
  cat > "$repo/tests/lib/test-suite-runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
suites=(lint-agents lint-scripts lint-script-domain-inventory lint-portable-repo-paths test-lint-shellcheck test-script-domain-inventory test-lint-portable-repo-paths test-lint-frontmatter test-commands test-check-docs-freshness test-guards test-migrate test-portable test-install test-uninstall test-doctor test-hook-profile-parity test-pmctl-dispatch test-pmctl-context test-pmctl-memory test-pmctl-gate test-pmctl-adapter-generate test-executor-router test-runner-kind test-release-verify test-dispatch-lifecycle test-runtime-lib-coverage test-e2e-script test-pr-gate-shard-1 test-pr-gate-shard-2 test-pr-gate-shard-3 test-pr-gate-shard-4 test-pr-gate-profile test-gate-protocol test-gate-options test-pmctl-operation test-host-manifest test-host-write-codex test-codex-dispatch-continuation test-host-write-parity test-core-schemas test-layer-boundaries test-pm-scripts test-run-tests test-setup-project test-state-store test-state-layout-parity test-check-planning-status-consistency test-lint-permanent-test-admissions test-schema-task-mirrors-backlog test-pmctl-backlog test-archive-closed-backlog)
for arg in "$@"; do
  if [[ "$arg" == --list ]]; then printf '%s\n' "${suites[@]}"; exit 0; fi
done
if [[ -n "${RUN_TESTS_MUTATE_PATH:-}" ]]; then
  printf 'mutated during test\n' >> "$RUN_TESTS_MUTATE_PATH"
fi
printf '%s\n' "$@" > "${RUN_TESTS_ARGS_LOG:?}"
rc="${RUN_TESTS_STUB_STATUS:-0}"
if [[ -n "${PM_TEST_SUITE_RESULTS_FILE:-}" && "${RUN_TESTS_SKIP_SINK:-0}" != "1" ]]; then
  selected=()
  args=("$@")
  i=0
  while (( i < ${#args[@]} )); do
    if [[ "${args[$i]}" == "--suite" && $((i + 1)) -lt ${#args[@]} ]]; then
      selected+=("${args[$((i + 1))]}")
      i=$((i + 2))
    else
      i=$((i + 1))
    fi
  done
  (( ${#selected[@]} > 0 )) || selected=("${suites[@]}")
  names_json="$(printf '%s\n' "${selected[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')"
  if [[ "${RUN_TESTS_INVALID_SINK:-0}" == "1" ]]; then
    printf '%s\n' '[{"name":"wrong-suite","status":"bogus","exit_code":0,"duration_seconds":"fast"}]' > "$PM_TEST_SUITE_RESULTS_FILE"
  else
    jq -n --argjson names "$names_json" --argjson rc "$rc" \
      --argjson case_skips "${RUN_TESTS_CASE_SKIPS:-0}" '
      [$names[] | {name:.,status:(if $rc == 0 then "pass" else "fail" end),exit_code:$rc,duration_seconds:0}]
      | (if $case_skips > 0 then .[0].case_skips = $case_skips else . end)
    ' > "$PM_TEST_SUITE_RESULTS_FILE"
  fi
fi
exit "$rc"
RUNNER
  chmod +x "$repo/tests/lib/test-suite-runner.sh"
  git -C "$repo" init -q
  git -C "$repo" add .
  printf '%s\n' "$repo"
}

case_direct_library_mapping() {
  local name=direct-library-mapping repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path runtime/lib/pmctl-context.sh 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path runtime/lib/pmctl-config.sh 2>&1) || status=$?
  if [[ "$status" -eq 0 ]] && grep -qx 'test-pmctl-dispatch' "$args" &&
     grep -qx 'test-pmctl-context' "$args" && grep -qx 'test-pmctl-memory' "$args" &&
     [[ "$out" != *"coverage gaps"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

# Behavior: --path runtime/lib/retrieval-terms.sh selects the three suites
# declared in map_path plus the generic *.sh lint-scripts entry.
# Steps: run the isolated planner against that path and assert the args log.
case_retrieval_terms_mapping_selects_declared_suites() {
  local name=retrieval-terms-mapping-selects-declared-suites repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/lib/retrieval-terms.sh 2>&1) || status=$?
  if [[ "$status" -eq 0 ]] && grep -qx -- '--suite' "$args" &&
     grep -qx 'lint-scripts' "$args" &&
     grep -qx 'test-runtime-lib-coverage' "$args" &&
     grep -qx 'test-guards' "$args" &&
     grep -qx 'test-pmctl-context' "$args" &&
     [[ "$out" == *"contract=iteration-only"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out args=$(cat "$args" 2>/dev/null)"
  fi
}

# Behavior: every repository-owned ShellCheck version or installation contract
# selects canonical lint plus the relevant toolchain and release regressions.
# Steps: Arrange an isolated runner fixture; Act by listing each toolchain path
# independently; Assert the pin selects lint plus both regression boundaries,
# tool assets add inventory, and bootstrap also selects layer-boundary coverage.
case_shellcheck_toolchain_mapping_is_complete() {
  local name=shellcheck-toolchain-mapping-is-complete repo path out status expected
  local diagnostics
  name=shellcheck-toolchain-mapping-is-complete
  repo="$(make_fixture "$name")"
  diagnostics="$TMP_ROOT/$name.diagnostics"
  for path in .shellcheck-version tools/lint/shellcheck-assets.tsv \
    tools/lint/bootstrap-shellcheck.sh; do
    status=0
    out="$(RUN_TESTS_ARGS_LOG="$TMP_ROOT/$name.args" \
      "$repo/tests/bin/run-tests.sh" --path "$path" --list 2>"$diagnostics")" || status=$?
    case "$path" in
      .shellcheck-version)
        expected=$'lint-scripts\ntest-lint-shellcheck\ntest-release-verify' ;;
      *.sh)
        expected=$'lint-script-domain-inventory\nlint-scripts\ntest-layer-boundaries\ntest-lint-shellcheck\ntest-release-verify' ;;
      *)
        expected=$'lint-script-domain-inventory\nlint-scripts\ntest-lint-shellcheck' ;;
    esac
    if [[ "$status" -ne 0 || "$(printf '%s\n' "$out" | LC_ALL=C sort)" != "$expected" \
        || "$(<"$diagnostics")" == *"coverage gaps"* ]]; then
      fail "$name" "path=$path status=$status expected=$expected out=$out diagnostics=$(<"$diagnostics")"
      return
    fi
  done
  pass "$name"
}

# Behavior: A changed adapter-manifest library selects every registered direct
# consumer suite without executing any suite during list mode.
# Steps:
#   1. Arrange a runner fixture with argument and diagnostic capture files.
#   2. Act by listing suites selected for runtime/lib/adapter-manifest.sh.
#   3. Assert the exact 23-suite set, zero execution, successful status, and no coverage-gap diagnostic.
case_adapter_manifest_mapping_covers_consumers() {
  local name=adapter-manifest-mapping-covers-consumers repo out status=0 args diagnostics
  local actual expected
  args="$TMP_ROOT/$name.args"
  diagnostics="$TMP_ROOT/$name.diagnostics"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/lib/adapter-manifest.sh --list 2>"$diagnostics") || status=$?
  actual="$(printf '%s\n' "$out" | LC_ALL=C sort)"
  expected="$(printf '%s\n' \
    lint-scripts \
    lint-script-domain-inventory \
    lint-portable-repo-paths \
    test-dispatch-lifecycle \
    test-doctor \
    test-e2e-script \
    test-executor-router \
    test-guards \
    test-hook-profile-parity \
    test-install \
    test-layer-boundaries \
    test-lint-portable-repo-paths \
    test-pmctl-adapter-generate \
    test-pmctl-dispatch \
    test-pr-gate-profile \
    test-pr-gate-shard-1 \
    test-pr-gate-shard-2 \
    test-pr-gate-shard-3 \
    test-pr-gate-shard-4 \
    test-release-verify \
    test-runner-kind \
    test-runtime-lib-coverage \
    test-uninstall | LC_ALL=C sort)"
  if [[ "$status" -eq 0 && "$actual" == "$expected" \
      && $(wc -l <<< "$out") -eq 23 \
      && ! -s "$args" \
      && "$(<"$diagnostics")" != *"coverage gaps"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status expected=$expected actual=$actual diagnostics=$(<"$diagnostics") executed=$([[ -s "$args" ]] && echo yes || echo no)"
  fi
}

# Behavior: A changed install-receipt library selects its complete registered
# consumer set without executing any suite during list mode.
# Steps:
#   1. Arrange a runner fixture with argument and diagnostic capture files.
#   2. Act by listing suites selected for runtime/lib/install-receipt.sh.
#   3. Assert the exact nine-suite set, zero execution, successful status, and no coverage-gap diagnostic.
case_install_receipt_mapping_covers_consumers() {
  local name=install-receipt-mapping-covers-consumers repo out status=0 args diagnostics
  local actual expected
  args="$TMP_ROOT/$name.args"
  diagnostics="$TMP_ROOT/$name.diagnostics"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/lib/install-receipt.sh --list 2>"$diagnostics") || status=$?
  actual="$(printf '%s\n' "$out" | LC_ALL=C sort)"
  expected="$(printf '%s\n' \
    lint-portable-repo-paths \
    lint-script-domain-inventory \
    lint-scripts \
    test-doctor \
    test-install \
    test-layer-boundaries \
    test-lint-portable-repo-paths \
    test-portable \
    test-uninstall | LC_ALL=C sort)"
  if [[ "$status" -eq 0 && "$actual" == "$expected" \
      && $(wc -l <<< "$out") -eq 9 \
      && ! -s "$args" \
      && "$(<"$diagnostics")" != *"coverage gaps"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status expected=$expected actual=$actual diagnostics=$(<"$diagnostics") executed=$([[ -s "$args" ]] && echo yes || echo no)"
  fi
}

# Behavior: A changed executor-router library selects router consumers and all
# four deployed PR Gate shards without executing suites during list mode.
# Steps:
#   1. Arrange a runner fixture with argument and diagnostic capture files.
#   2. Act by listing suites selected for runtime/lib/executor-router.sh.
#   3. Assert the exact 12-suite set, zero execution, successful status, and no coverage-gap diagnostic.
case_executor_router_mapping_covers_gate_deployments() {
  local name=executor-router-mapping-covers-gate-deployments repo out status=0 args diagnostics
  local actual expected
  args="$TMP_ROOT/$name.args"
  diagnostics="$TMP_ROOT/$name.diagnostics"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/lib/executor-router.sh --list 2>"$diagnostics") || status=$?
  actual="$(printf '%s\n' "$out" | LC_ALL=C sort)"
  expected="$(printf '%s\n' \
    lint-portable-repo-paths \
    lint-script-domain-inventory \
    lint-scripts \
    test-executor-router \
    test-install \
    test-layer-boundaries \
    test-lint-portable-repo-paths \
    test-pr-gate-profile \
    test-pr-gate-shard-1 \
    test-pr-gate-shard-2 \
    test-pr-gate-shard-3 \
    test-pr-gate-shard-4 | LC_ALL=C sort)"
  if [[ "$status" -eq 0 && "$actual" == "$expected" \
      && $(wc -l <<< "$out") -eq 12 \
      && ! -s "$args" \
      && "$(<"$diagnostics")" != *"coverage gaps"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status expected=$expected actual=$actual diagnostics=$(<"$diagnostics") executed=$([[ -s "$args" ]] && echo yes || echo no)"
  fi
}

case_state_writer_mapping_runs_operation_parity() {
  local name=state-writer-mapping-runs-operation-parity repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/lib/state-writer.sh --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-state-store"* &&
        "$out" == *"test-state-layout-parity"* && "$out" == *"test-pmctl-operation"* &&
        "$out" != *"coverage gaps"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out executed=$([[ -e "$args" ]] && echo yes || echo no)"
  fi
}

case_state_layout_mapping_runs_parity() {
  local name=state-layout-mapping-runs-parity repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path core/state/layout.yaml --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-state-store"* &&
        "$out" == *"test-state-layout-parity"* && "$out" != *"coverage gaps"* &&
        ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out executed=$([[ -e "$args" ]] && echo yes || echo no)"
  fi
}

case_docs_mapping_list_only() {
  local name=docs-mapping-list-only repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path docs/context-retrieval.md --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-check-docs-freshness"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out executed=$([[ -e "$args" ]] && echo yes || echo no)"
  fi
}

# Behavior: a change to any planning document (BACKLOG.md / MILESTONES.md), and a
# change to the checker script itself, each select test-check-planning-status-consistency
# exactly once. Steps: list the plan for each path and assert the selection.
case_planning_docs_map_to_status_consistency_suite() {
  local name=planning-docs-map-to-status-consistency-suite repo status out p n
  repo="$(make_fixture "$name")"
  for p in BACKLOG.md MILESTONES.md tools/lint/check-planning-status-consistency.sh; do
    status=0
    out="$(RUN_TESTS_ARGS_LOG="$TMP_ROOT/$name.args" \
      "$repo/tests/bin/run-tests.sh" --path "$p" --list 2>&1)" || status=$?
    if [[ "$status" -ne 0 ]]; then
      fail "$name" "planner exited $status for --path $p: $out"; return
    fi
    n=$(printf '%s\n' "$out" | grep -cx 'test-check-planning-status-consistency')
    if [[ "$n" != "1" ]]; then
      fail "$name" "--path $p listed test-check-planning-status-consistency $n times (want 1): $out"
      return
    fi
  done
  pass "$name"
}

# Behavior: a change to the permanent-test admission linter, and to its own
# regression suite, each select test-lint-permanent-test-admissions exactly once
# via the generic tools/ + tests/shell/ mapping (no dedicated map_path arm).
# Steps: list the plan for each path and assert the selection with no gap.
case_admission_lint_paths_map_to_meta_suite() {
  local name=admission-lint-paths-map-to-meta-suite repo status out p n
  repo="$(make_fixture "$name")"
  for p in tools/lint/lint-permanent-test-admissions.sh \
           tests/shell/test-lint-permanent-test-admissions.sh; do
    status=0
    out="$(RUN_TESTS_ARGS_LOG="$TMP_ROOT/$name.args" \
      "$repo/tests/bin/run-tests.sh" --path "$p" --list 2>&1)" || status=$?
    if [[ "$status" -ne 0 ]]; then
      fail "$name" "planner exited $status for --path $p: $out"; return
    fi
    n=$(printf '%s\n' "$out" | grep -cx 'test-lint-permanent-test-admissions')
    if [[ "$n" != "1" ]]; then
      fail "$name" "--path $p listed test-lint-permanent-test-admissions $n times (want 1): $out"
      return
    fi
    if [[ "$out" == *"coverage gaps"* ]]; then
      fail "$name" "--path $p reported a coverage gap: $out"; return
    fi
  done
  pass "$name"
}

case_operational_docs_map_to_stale_reference_lint() {
  local name=operational-docs-map-to-stale-reference-lint repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path README.md --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"lint-script-domain-inventory"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out executed=$([[ -e "$args" ]] && echo yes || echo no)"
  fi
}

case_gitignore_maps_to_setup_project() {
  local name=gitignore-maps-to-setup-project repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path .gitignore --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-setup-project"* \
      && "$out" != *"coverage gaps"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_agent_mapping_uses_registered_frontmatter_suite() {
  local name=agent-mapping-uses-registered-frontmatter-suite repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path agents/project-pm.md --list 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path commands/ship.md --list 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path skills/example/SKILL.md --list 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path hosts/claude/hooks/inject-context.sh 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path tests/lib/test-result.sh --path core/schema/test-result.schema.json \
    --path core/schema/preflight-evidence.schema.json --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-run-tests"* && "$out" == *"test-pr-gate"* &&
        "$out" == *"test-core-schemas"* &&
        "$out" != *"coverage gaps"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_gate_assurance_policy_maps_gate_consumers() {
  local name=gate-assurance-policy-maps-gate-consumers repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path core/policy/gate-tiers.tsv --path core/policy/gate-modes.tsv \
    --path core/policy/gate-pass-kinds.tsv \
    --path core/policy/gate-policy-consumers.tsv \
    --path core/policy/gate-policy-signals.tsv --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-pr-gate"* &&
        "$out" == *"test-pr-gate-profile"* && "$out" == *"test-core-schemas"* &&
        "$out" == *"test-layer-boundaries"* && "$out" != *"coverage gaps"* &&
        ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_gate_assurance_contract_maps_runtime_verifiers() {
  local name=gate-assurance-contract-maps-runtime-verifiers repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path core/schema/gate-assurance.schema.json \
    --path core/schema/gate-policy-override.schema.json \
    --path core/schema/gate-publish-assessment.schema.json \
    --path runtime/lib/gate-result-verify.sh --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-core-schemas"* &&
        "$out" == *"test-pr-gate"* && "$out" == *"test-pmctl-gate"* &&
        "$out" == *"test-layer-boundaries"* && "$out" != *"coverage gaps"* &&
        ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_pr_gate_protocol_contract_maps_profile_and_verifiers() {
  local name=pr-gate-protocol-contract-maps-profile-and-verifiers
  local repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/bin/pr-gate.sh \
    --path runtime/lib/gate-result-verify.sh \
    --path core/schema/gate-reviewer-result.schema.json \
    --path tests/lib/test-pr-gate-fixture.sh --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-core-schemas"* &&
        "$out" == *"test-pr-gate"* && "$out" == *"test-pr-gate-profile"* &&
        "$out" == *"test-pmctl-gate"* && "$out" == *"test-layer-boundaries"* &&
        "$out" != *"coverage gaps"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_gate_protocol_lib_maps_its_suite_and_shards() {
  local name=gate-protocol-lib-maps-its-suite-and-shards repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/lib/gate-protocol.sh --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-gate-protocol"* &&
        "$out" == *"test-pr-gate-shard-1"* && "$out" == *"test-pr-gate-profile"* &&
        "$out" != *"coverage gaps"* && ! -e "$args" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: runtime/lib/gate-options.sh selects its own unit suite (plus the
# pr-gate shards, since pr-gate.sh sources it); a pr-gate.sh change also pulls
# in test-gate-options, since pr-gate.sh now calls its comparators.
case_gate_options_lib_maps_its_suite() {
  local name=gate-options-lib-maps-its-suite repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/lib/gate-options.sh --list 2>&1) || status=$?
  if [[ "$status" -ne 0 || "$out" != *"test-gate-options"* \
        || "$out" != *"test-pr-gate-shard-1"* || "$out" == *"coverage gaps"* ]]; then
    fail "$name" "gate-options.sh path: status=$status out=$out"; return
  fi
  status=0
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path runtime/bin/pr-gate.sh --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-gate-options"* && "$out" != *"coverage gaps"* ]]; then
    pass "$name"
  else
    fail "$name" "pr-gate.sh path: status=$status out=$out"
  fi
}

case_gate_synthesis_schema_maps_protocol_verifiers() {
  local name=gate-synthesis-schema-maps-protocol-verifiers
  local repo out status=0 args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
    --path core/schema/gate-synthesis-result.schema.json --list 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"test-core-schemas"* &&
        "$out" == *"test-pr-gate"* && "$out" == *"test-pmctl-gate"* &&
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path runtime/lib/portable.sh 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" \
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path package.json 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" RUN_TESTS_STUB_STATUS=1 "$repo/tests/bin/run-tests.sh" --path runtime/bin/pr-gate.sh 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --all --jobs 3 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --all --result-file "$artifact" 2>&1) || status=$?
  if [[ "$status" -ne 0 || ! -s "$artifact" ]] ||
     ! jq -e '.kind == "pm_test_result_v2" and .schema_version == 2 and .contract == "full" and
       .authoritative == true and .status == "pass" and (.suite_set | length > 0) and
       ((.suite_results | length) == (.suite_set | length))' "$artifact" >/dev/null; then
    fail "$name" "artifact missing/invalid status=$status out=$out"
    return
  fi
  status=0
  out=$("$repo/tests/bin/run-tests.sh" --verify-full "$artifact" 2>&1) || status=$?
  if [[ "$status" -eq 0 && "$out" == *"verified authoritative full PASS"* ]]; then
    pass "$name"
  else
    fail "$name" "verify status=$status out=$out"
  fi
}

case_full_result_case_skips_is_not_authoritative() {
  # A --all run where any suite reported case-level skips must produce a
  # full-with-skips, non-authoritative artifact, and --verify-full must reject
  # it -- the same direction as a requested suite skip.
  local name=full-result-case-skips-not-authoritative repo out status=0 artifact args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  out=$(RUN_TESTS_ARGS_LOG="$args" RUN_TESTS_CASE_SKIPS=3 "$repo/tests/bin/run-tests.sh" --all --result-file "$artifact" 2>&1) || status=$?
  if [[ "$status" -ne 0 || ! -s "$artifact" ]] ||
     ! jq -e '
       .contract == "full-with-skips" and .authoritative == false and
       .aggregate.case_skipped == 3 and
       ([.suite_results[] | (.case_skips // 0)] | add) == 3
     ' "$artifact" >/dev/null; then
    fail "$name" "artifact wrong: status=$status out=$out artifact=$(cat "$artifact" 2>/dev/null | jq -c '{contract,authoritative,cs:.aggregate.case_skipped}' 2>/dev/null)"
    return
  fi
  status=0
  out=$("$repo/tests/bin/run-tests.sh" --verify-full "$artifact" 2>&1) || status=$?
  if [[ "$status" -ne 0 && "$out" == *"not an authoritative full PASS"* ]]; then
    pass "$name"
  else
    fail "$name" "verify should have rejected the case-skip artifact: status=$status out=$out"
  fi
}

case_full_result_rejects_fractional_case_skips() {
  # A structured sink whose case_skips is a non-integer must be rejected before
  # any artifact is emitted -- never coerced to zero, which would let a bad
  # sink produce an authoritative PASS despite a positive reported skip count.
  local name=full-result-rejects-fractional-case-skips repo out status=0 artifact args
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  out=$(RUN_TESTS_ARGS_LOG="$args" RUN_TESTS_CASE_SKIPS=0.5 "$repo/tests/bin/run-tests.sh" --all --result-file "$artifact" 2>&1) || status=$?
  if [[ "$status" -ne 0 && ! -s "$artifact" ]] \
    && { [[ "$out" == *"non-integer case_skips"* ]] || [[ "$out" == *"invalid or incomplete structured suite results"* ]] || [[ "$out" == *"did not emit a valid"* ]]; }; then
    pass "$name"
  else
    fail "$name" "status=$status artifact_exists=$([[ -s "$artifact" ]] && echo yes || echo no) out=$out"
  fi
}

case_verify_full_rejects_collect_all() {
  local name=verify-full-rejects-collect-all repo out status=0 artifact
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  out=$("$repo/tests/bin/run-tests.sh" --verify-full "$artifact" --collect-all 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"cannot be combined with planning or execution flags"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_full_result_rejects_changed_tree() {
  local name=full-result-rejects-changed-tree repo out status=0 args artifact
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --all --result-file "$artifact" >/dev/null 2>&1 || {
    fail "$name" "setup full run failed"; return;
  }
  printf '\npost-test source change\n' >> "$repo/tests/bin/run-all-tests.sh"
  out=$("$repo/tests/bin/run-tests.sh" --verify-full "$artifact" 2>&1) || status=$?
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
  out=$(RUN_TESTS_ARGS_LOG="$args" RUN_TESTS_MUTATE_PATH="$repo/tests/bin/run-all-tests.sh" \
    "$repo/tests/bin/run-tests.sh" --all --result-file "$artifact" 2>&1) || status=$?
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
  RUN_TESTS_ARGS_LOG="$args" "$repo/tests/bin/run-tests.sh" --path runtime/lib/pmctl-context.sh \
    --result-file "$artifact" >/dev/null 2>&1 || { fail "$name" "iteration run failed"; return; }
  out=$("$repo/tests/bin/run-tests.sh" --verify-full "$artifact" 2>&1) || status=$?
  if [[ "$status" -eq 1 && "$out" == *"not an authoritative full PASS"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_empty_structured_sink_fails_closed() {
  local name=empty-structured-sink-fails-closed repo out status=0 args artifact
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  out=$(RUN_TESTS_ARGS_LOG="$args" RUN_TESTS_SKIP_SINK=1 \
    "$repo/tests/bin/run-tests.sh" --all --result-file "$artifact" 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"did not emit a valid non-empty structured result sink"* \
      && ! -e "$artifact" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out artifact=$(cat "$artifact" 2>/dev/null)"
  fi
}

case_invalid_structured_sink_fails_closed() {
  local name=invalid-structured-sink-fails-closed repo out status=0 args artifact
  args="$TMP_ROOT/$name.args"
  repo="$(make_fixture "$name")"
  artifact="$repo/.pm-dispatch/test-results/full.json"
  out=$(RUN_TESTS_ARGS_LOG="$args" RUN_TESTS_INVALID_SINK=1 \
    "$repo/tests/bin/run-tests.sh" --all --result-file "$artifact" 2>&1) || status=$?
  if [[ "$status" -eq 2 && "$out" == *"did not emit a valid non-empty structured result sink"* \
      && ! -e "$artifact" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out artifact=$(cat "$artifact" 2>/dev/null)"
  fi
}

case_direct_library_mapping
case_memory_config_mapping_has_no_gap
case_retrieval_terms_mapping_selects_declared_suites
case_shellcheck_toolchain_mapping_is_complete
case_adapter_manifest_mapping_covers_consumers
case_install_receipt_mapping_covers_consumers
case_executor_router_mapping_covers_gate_deployments
case_state_writer_mapping_runs_operation_parity
case_state_layout_mapping_runs_parity
case_docs_mapping_list_only
case_planning_docs_map_to_status_consistency_suite
case_admission_lint_paths_map_to_meta_suite
case_operational_docs_map_to_stale_reference_lint
case_gitignore_maps_to_setup_project
case_agent_mapping_uses_registered_frontmatter_suite
case_command_mapping_uses_registered_frontmatter_suite
case_skill_mapping_uses_registered_frontmatter_suite
case_guard_family_maps_to_guard_suite
case_prompt_context_timeout_contract_maps_all_consumers
case_evidence_contract_maps_to_runner_regression
case_gate_assurance_policy_maps_gate_consumers
case_gate_assurance_contract_maps_runtime_verifiers
case_pr_gate_protocol_contract_maps_profile_and_verifiers
case_gate_protocol_lib_maps_its_suite_and_shards
case_gate_options_lib_maps_its_suite
case_gate_synthesis_schema_maps_protocol_verifiers
case_high_fanout_escalates_full
case_repeated_high_fanout_escalation_succeeds
case_unknown_path_fails_without_test_evidence
case_selected_failure_propagates
case_explicit_all_delegates_without_selector
case_full_result_verifies_same_tree
case_full_result_case_skips_is_not_authoritative
case_full_result_rejects_fractional_case_skips
case_verify_full_rejects_collect_all
case_full_result_rejects_changed_tree
case_tree_change_during_run_marks_stale
case_iteration_result_cannot_verify_as_full
case_empty_structured_sink_fails_closed
case_invalid_structured_sink_fails_closed

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
