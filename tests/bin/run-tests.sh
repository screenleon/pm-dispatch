#!/usr/bin/env bash
# Fast, repo-specific iteration runner for pm-dispatch.
#
# This runner selects direct regression suites for changed paths. It is suitable
# for an explicit `pr-gate.sh --test-cmd`, but it is NOT a full-suite or release
# sign-off. Run tests/bin/run-all-tests.sh separately for final validation.
#
# Usage:
#   tests/bin/run-tests.sh [--base <ref>] [--path <repo-relative-path>]...
#                        [--result-file <path>] [--list] [--jobs N] [--suite-timeout N]
#   tests/bin/run-tests.sh --all [--skip <suite>] [--collect-all] [--list] [--jobs N] [--suite-timeout N]
#   tests/bin/run-tests.sh --verify-full <result-file>
#
# --collect-all (only valid with --all) disables the suite runner's Phase 0
# fail-fast short-circuit, so every suite runs regardless of a structural
# precheck failure -- used when full diagnostic evidence across all phases is
# needed (e.g. release sign-off).
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SUITE_RUNNER="$SCRIPT_DIR/../lib/test-suite-runner.sh"
TEST_RESULT_LIB="$SCRIPT_DIR/../lib/test-result.sh"

BASE_REF=""
LIST_ONLY=0
RUN_ALL=0
COLLECT_ALL=0
JOBS=""
SUITE_TIMEOUT=""
RESULT_FILE="${PM_DISPATCH_PREFLIGHT_TEST_RESULT:-}"
VERIFY_FULL_FILE=""
declare -a EXPLICIT_PATHS=()
declare -a FULL_SKIPS=()

usage() {
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'run-tests: --base requires a git ref\n' >&2; exit 2; }
      BASE_REF="$2"; shift 2 ;;
    --path)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'run-tests: --path requires a repo-relative path\n' >&2; exit 2; }
      EXPLICIT_PATHS+=("$2"); shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --all) RUN_ALL=1; shift ;;
    --collect-all) COLLECT_ALL=1; shift ;;
    --result-file)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'run-tests: --result-file requires a path\n' >&2; exit 2; }
      RESULT_FILE="$2"; shift 2 ;;
    --verify-full)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'run-tests: --verify-full requires a result artifact path\n' >&2; exit 2; }
      VERIFY_FULL_FILE="$2"; shift 2 ;;
    --skip)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'run-tests: --skip requires a non-empty suite name\n' >&2; exit 2; }
      FULL_SKIPS+=("$2"); shift 2 ;;
    --jobs|-j)
      [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*$ ]] || { printf 'run-tests: --jobs requires a positive integer\n' >&2; exit 2; }
      JOBS="$2"; shift 2 ;;
    --suite-timeout)
      [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*$ ]] || { printf 'run-tests: --suite-timeout requires a positive integer\n' >&2; exit 2; }
      SUITE_TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'run-tests: unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -x "$SUITE_RUNNER" ]] || { printf 'run-tests: suite executor is missing or not executable: %s\n' "$SUITE_RUNNER" >&2; exit 2; }
[[ -f "$TEST_RESULT_LIB" ]] || { printf 'run-tests: test result library is missing: %s\n' "$TEST_RESULT_LIB" >&2; exit 2; }
# shellcheck source=tests/lib/test-result.sh disable=SC1091
. "$TEST_RESULT_LIB"
# shellcheck source=runtime/lib/artifact-paths.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/artifact-paths.sh"

if [[ -n "$VERIFY_FULL_FILE" ]]; then
  [[ "$RUN_ALL" -eq 0 && "$LIST_ONLY" -eq 0 && "${#EXPLICIT_PATHS[@]}" -eq 0 && -z "$BASE_REF" && "${#FULL_SKIPS[@]}" -eq 0 && -z "$RESULT_FILE" && "$COLLECT_ALL" -eq 0 ]] || {
    printf 'run-tests: --verify-full cannot be combined with planning or execution flags\n' >&2
    exit 2
  }
  pm_test_verify_full_result "$REPO_ROOT" "$VERIFY_FULL_FILE"
  exit $?
fi

runner_args=()
[[ -n "$JOBS" ]] && runner_args+=(--jobs "$JOBS")
[[ -n "$SUITE_TIMEOUT" ]] && runner_args+=(--suite-timeout "$SUITE_TIMEOUT")
[[ "$COLLECT_ALL" -eq 1 ]] && runner_args+=(--collect-all)
if [[ "$RUN_ALL" -eq 1 ]]; then
  [[ "$LIST_ONLY" -eq 1 ]] && runner_args+=(--list)
  for suite in "${FULL_SKIPS[@]}"; do runner_args+=(--skip "$suite"); done
  if [[ "$LIST_ONLY" -eq 0 ]]; then
    if [[ "${#FULL_SKIPS[@]}" -eq 0 ]]; then
      printf 'run-tests: escalating to authoritative full suite (--all requested)\n' >&2
    else
      printf 'run-tests: running full registry with explicit skips (non-authoritative evidence)\n' >&2
    fi
  fi
  if [[ "$LIST_ONLY" -eq 1 ]]; then exec "$SUITE_RUNNER" "${runner_args[@]}"; fi
  full_suite_json="$("$SUITE_RUNNER" --list | jq -Rsc 'split("\n") | map(select(length > 0))')"
  skip_json="$(printf '%s\n' "${FULL_SKIPS[@]+"${FULL_SKIPS[@]}"}" | jq -Rsc 'split("\n") | map(select(length > 0))')"
  if [[ "${#FULL_SKIPS[@]}" -gt 0 ]]; then
    result_contract=full-with-skips
    [[ -n "$RESULT_FILE" ]] || RESULT_FILE="$REPO_ROOT/.pm-dispatch/test-results/latest-partial.json"
  else
    result_contract=full
    [[ -n "$RESULT_FILE" ]] || RESULT_FILE="$REPO_ROOT/.pm-dispatch/test-results/latest-full.json"
  fi
  pm_test_run_and_record "$REPO_ROOT" "$result_contract" "$RESULT_FILE" all '[]' \
    "$full_suite_json" "$skip_json" "" \
    "$SUITE_RUNNER" "${runner_args[@]}"
  exit $?
fi
if [[ "$COLLECT_ALL" -eq 1 ]]; then
  printf 'run-tests: --collect-all is only valid with --all\n' >&2
  exit 2
fi
if [[ "${#FULL_SKIPS[@]}" -gt 0 ]]; then
  printf 'run-tests: --skip is only valid with --all\n' >&2
  exit 2
fi

declare -A REGISTERED=()
while IFS= read -r suite; do
  [[ -n "$suite" ]] && REGISTERED["$suite"]=1
done < <("$SUITE_RUNNER" --list)

declare -A CHANGED=()
add_changed() {
  local path="$1"
  path="${path#./}"
  [[ -n "$path" ]] && CHANGED["$path"]=1
}

if [[ "${#EXPLICIT_PATHS[@]}" -gt 0 ]]; then
  for path in "${EXPLICIT_PATHS[@]}"; do add_changed "$path"; done
else
  cd "$REPO_ROOT"
  if [[ -n "$BASE_REF" ]]; then
    git rev-parse --verify "${BASE_REF}^{commit}" >/dev/null 2>&1 || {
      printf 'run-tests: base ref does not resolve to a commit: %s\n' "$BASE_REF" >&2
      exit 2
    }
    while IFS= read -r -d '' path; do add_changed "$path"; done < <(git diff --name-only -z --diff-filter=ACMR "${BASE_REF}...HEAD")
  fi
  while IFS= read -r -d '' path; do add_changed "$path"; done < <(git diff --name-only -z --diff-filter=ACMR HEAD)
  while IFS= read -r -d '' path; do add_changed "$path"; done < <(git ls-files --others --exclude-standard -z)
fi

if [[ "${#CHANGED[@]}" -eq 0 ]]; then
  printf 'run-tests: no changed paths detected; use --base <ref>, --path <path>, or --all\n' >&2
  exit 2
fi

declare -A SELECTED=()
declare -A COVERAGE_GAPS=()
ESCALATE_FULL=0
ESCALATE_REASON=""

add_suite() {
  local suite="$1"
  [[ -n "${REGISTERED[$suite]:-}" ]] && SELECTED["$suite"]=1
}

add_pr_gate_shards() {
  add_suite test-pr-gate-shard-1
  add_suite test-pr-gate-shard-2
  add_suite test-pr-gate-shard-3
  add_suite test-pr-gate-shard-4
}

mark_full() {
  ESCALATE_FULL=1
  if [[ -z "$ESCALATE_REASON" ]]; then
    ESCALATE_REASON="$1"
  fi
  return 0
}

map_path() {
  local path="$1" stem="" behavioral=0

  case "$path" in
    tests/bin/run-all-tests.sh|tests/lib/test-suite-runner.sh|tests/lib/test-harness.sh|runtime/lib/portable.sh|install.sh|uninstall.sh)
      mark_full "high-fanout runner/install substrate changed: $path"
      return ;;
  esac

  [[ "$path" == *.sh ]] && add_suite lint-scripts

  case "$path" in
    tests/shell/test-pr-gate.sh|tests/shell/test-pr-gate-shard-*.sh)
      add_pr_gate_shards; behavioral=1 ;;
    tests/shell/test-*.sh)
      stem="${path#tests/shell/}"
      stem="${stem%.sh}"
      case "$stem" in
        test-migrate-routing-log) stem=test-migrate ;;
        test-migrate-routing-to-events) stem=test-migrate-to-events ;;
      esac
      if [[ -n "${REGISTERED[$stem]:-}" ]]; then add_suite "$stem"; behavioral=1; fi ;;
    runtime/lib/*.sh|runtime/bin/*.sh|runtime/hooks/*.sh|ops/*/*.sh|tools/*/*.sh)
      stem="$(basename "$path" .sh)"
      if [[ -n "${REGISTERED[test-$stem]:-}" ]]; then add_suite "test-$stem"; behavioral=1; fi ;;
  esac

  case "$path" in
    .gitignore)
      add_suite test-setup-project; behavioral=1 ;;
    .shellcheck-version|tools/lint/bootstrap-shellcheck.sh)
      add_suite lint-scripts; add_suite test-lint-shellcheck
      add_suite test-release-verify; behavioral=1 ;;
    tools/lint/lint-shellcheck.sh|tools/lint/shellcheck-assets.tsv|tools/lint/shellcheck-domains.tsv|tools/lint/shellcheck-ignores.tsv|tests/shell/test-lint-shellcheck.sh)
      add_suite lint-scripts; add_suite test-lint-shellcheck; behavioral=1 ;;
    tools/lint/lint-script-domain-inventory.sh|tests/shell/test-script-domain-inventory.sh|docs/architecture/script-domain-ownership.md|docs/architecture/script-domain-inventory.tsv|docs/architecture/script-domain-reference-allowlist.tsv|docs/architecture/script-variable-inventory.tsv|docs/architecture/script-variable-consumers.tsv)
      add_suite lint-script-domain-inventory; add_suite test-script-domain-inventory; behavioral=1 ;;
    tools/lint/lint-portable-repo-paths.sh|tests/shell/test-lint-portable-repo-paths.sh|runtime/lib/repo-layout.sh)
      add_suite lint-portable-repo-paths; add_suite test-lint-portable-repo-paths; behavioral=1 ;;
    tools/lint/lint-pmctl-commands.sh|tests/shell/test-pmctl-discovery.sh|cli/commands.tsv|runtime/lib/pmctl-command-catalog.sh)
      add_suite lint-pmctl-commands; add_suite test-pmctl-discovery; behavioral=1 ;;
    tests/bin/run-tests.sh)
      add_suite test-run-tests; behavioral=1 ;;
    tests/lib/test-result.sh|core/schema/test-result.schema.json)
      add_suite test-run-tests; behavioral=1 ;;
    tests/lib/test-pmctl-fixture.sh)
      add_suite test-pmctl-adapter-generate; add_suite test-pmctl-artifacts
      add_suite test-pmctl-gate; add_suite test-pmctl-discovery; behavioral=1 ;;
    runtime/lib/state-writer.sh)
      add_suite test-state-store; add_suite test-state-layout-parity
      add_suite test-pmctl-operation; behavioral=1 ;;
    core/state/layout.yaml)
      add_suite test-state-store; add_suite test-state-layout-parity; behavioral=1 ;;
    runtime/lib/state-paths.sh)
      add_suite test-state-paths; add_suite test-state-store-rotation; behavioral=1 ;;
    runtime/lib/pmctl-policy.sh)
      add_suite test-pmctl-adapter-generate; add_pr_gate_shards
      add_suite test-dispatch-handover; add_suite test-handover-validate
      add_suite test-pmctl-task; behavioral=1 ;;
    core/schema/preflight-evidence.schema.json)
      add_pr_gate_shards; behavioral=1 ;;
    core/schema/gate-assurance.schema.json|core/schema/gate-policy-override.schema.json|core/schema/gate-publish-assessment.schema.json|core/schema/gate-reviewer-result.schema.json|core/schema/gate-scope-manifest.schema.json|core/schema/gate-synthesis-result.schema.json|core/schema/gate-verification.schema.json)
      add_suite test-core-schemas; add_pr_gate_shards
      add_suite test-pmctl-gate; behavioral=1 ;;
    runtime/bin/pr-gate.sh)
      add_pr_gate_shards; add_suite test-pr-gate-profile; behavioral=1 ;;
    runtime/lib/gate-assurance.sh|runtime/lib/gate-digest.sh|runtime/lib/gate-layout.sh|runtime/lib/gate-policy.sh|runtime/lib/gate-options.sh|runtime/lib/gate-reviewer-contract.sh|runtime/lib/gate-scope.sh|runtime/lib/gate-subject.sh)
      add_pr_gate_shards; add_suite test-pr-gate-profile; behavioral=1 ;;
    runtime/bin/dispatch-supervisor.sh)
      add_suite test-dispatch-lifecycle; behavioral=1 ;;
    runtime/lib/gate-result-verify.sh)
      add_pr_gate_shards; add_suite test-pr-gate-profile
      add_suite test-pmctl-gate; behavioral=1 ;;
    runtime/lib/gate-publish.sh|runtime/lib/pmctl-ship.sh)
      add_suite test-pmctl-ship; add_suite test-core-schemas
      add_suite test-pmctl-gate; behavioral=1 ;;
    tests/lib/test-pr-gate-fixture.sh)
      add_pr_gate_shards; add_suite test-pr-gate-profile; behavioral=1 ;;
    tools/eval/gate-test-gap-live-eval.sh|tests/fixtures/gate-live-eval/*)
      add_pr_gate_shards; behavioral=1 ;;
    core/policy/gate-tiers.tsv|core/policy/gate-modes.tsv|core/policy/gate-pass-kinds.tsv|core/policy/gate-policy-consumers.tsv|core/policy/gate-policy-signals.tsv)
      add_pr_gate_shards; add_suite test-pr-gate-profile; behavioral=1 ;;
    runtime/lib/pmctl-config.sh)
      add_suite test-pmctl-dispatch; add_suite test-pmctl-memory; add_suite test-pmctl-context; behavioral=1 ;;
    runtime/lib/adapter-manifest.sh)
      add_suite test-executor-router; add_suite test-pmctl-dispatch
      add_suite test-runner-kind; add_suite test-e2e-script
      add_suite test-pmctl-adapter-generate; add_suite test-release-verify
      add_suite test-install; add_suite test-doctor
      add_suite test-dispatch-lifecycle; add_suite test-pr-gate-profile
      add_suite test-guards; add_suite test-uninstall; add_suite test-hook-profile-parity
      add_pr_gate_shards; add_suite test-runtime-lib-coverage; behavioral=1 ;;
    runtime/lib/executor-router.sh)
      add_suite test-executor-router; add_suite test-install
      add_pr_gate_shards; add_suite test-pr-gate-profile; behavioral=1 ;;
    runtime/lib/adapter-enum.sh)
      add_suite test-release-verify; add_suite test-e2e-script; behavioral=1 ;;
    runtime/lib/allowlist.sh)
      add_suite test-install; add_suite test-uninstall; add_suite test-doctor; behavioral=1 ;;
    runtime/lib/install-receipt.sh)
      add_suite test-portable; add_suite test-install
      add_suite test-uninstall; add_suite test-doctor; behavioral=1 ;;
    runtime/lib/memory.sh|runtime/lib/memory-dir.sh)
      add_suite test-pmctl-memory; add_suite test-pmctl-context; add_suite test-migrate; add_suite test-guards; behavioral=1 ;;
    runtime/lib/prompt-context.sh)
      add_suite test-guards; behavioral=1 ;;
    runtime/lib/retrieval-terms.sh)
      add_suite test-runtime-lib-coverage; add_suite test-guards
      add_suite test-pmctl-context; behavioral=1 ;;
    runtime/lib/guard-log.sh)
      add_suite test-guards; behavioral=1 ;;
    runtime/lib/pmctl-memory-config.sh)
      add_suite test-pmctl-memory; behavioral=1 ;;
    hosts/claude/lib/prompt-context-timeouts.sh|hosts/claude/hooks/inject-context.sh)
      add_suite test-guards; add_suite test-install; add_suite test-doctor; behavioral=1 ;;
    scripts/install-guards-codex.sh|scripts/uninstall-guards-codex.sh|scripts/hook-codex-command-guard.sh|hosts/codex/bin/install.sh|hosts/codex/bin/uninstall.sh|hosts/codex/bin/wait-dispatch.sh|hosts/codex/bin/continue-dispatch.sh|hosts/codex/lib/doctor.sh|hosts/codex/lib/memory-contract.sh|hosts/codex/hooks/command-guard.sh|hosts/codex/host.yaml)
      add_suite test-host-write-codex; add_suite test-codex-dispatch-continuation; add_suite test-host-write-parity; add_suite test-doctor; add_suite test-host-resolver; behavioral=1 ;;
    scripts/install-host-opencode.sh|scripts/uninstall-host-opencode.sh|hosts/opencode/bin/install.sh|hosts/opencode/bin/uninstall.sh|hosts/opencode/lib/doctor.sh|hosts/opencode/host.yaml)
      add_suite test-host-write-opencode; add_suite test-host-write-parity; add_suite test-doctor; add_suite test-host-resolver; behavioral=1 ;;
    runtime/lib/host-write.sh)
      add_suite test-host-write-codex; add_suite test-host-write-opencode; add_suite test-host-write-parity; behavioral=1 ;;
    runtime/lib/host-resolver.sh|runtime/lib/host-doctor-primitives.sh)
      add_suite test-host-resolver; add_suite test-host-manifest; add_suite test-doctor
      add_suite test-host-write-codex; add_suite test-host-write-opencode
      add_suite test-host-write-parity; behavioral=1 ;;
    runtime/lib/host-manifest.sh)
      add_suite test-host-resolver; add_suite test-host-manifest; add_suite test-host-write-codex
      add_suite test-host-write-opencode; add_suite test-host-write-parity; add_suite test-doctor; behavioral=1 ;;
    scripts/install-guards.sh|scripts/uninstall-guards.sh|hosts/claude/bin/install-guards.sh|hosts/claude/bin/uninstall-guards.sh|hosts/claude/lib/doctor.sh|hosts/claude/host.yaml)
      add_suite test-install; add_suite test-uninstall; add_suite test-doctor
      add_suite test-hook-profile-parity; add_suite test-host-write-parity; behavioral=1 ;;
    scripts/guard-log-claude-usage.sh|scripts/guard-save-rate-limits.sh|hosts/claude/hooks/log-usage.sh|hosts/claude/hooks/save-rate-limits.sh)
      add_suite test-install; add_suite test-doctor; add_suite test-guards; behavioral=1 ;;
    tools/lint/lint-scripts.sh)
      add_suite lint-scripts; add_suite test-run-tests; behavioral=1 ;;
  esac

  case "$path" in
    install.sh|uninstall.sh|cli/pmctl|scripts/*.sh|scripts/**/*.sh|runtime/*.sh|runtime/**/*.sh|hosts/*.sh|hosts/**/*.sh|adapters/*.sh|adapters/**/*.sh|ops/*.sh|ops/**/*.sh|tools/*.sh|tools/**/*.sh)
      add_suite test-layer-boundaries; behavioral=1 ;;
  esac

  case "$path" in
    CONTRIBUTING.md|README.md|agents/*.md|commands/*.md|skills/*|scripts/*|scripts/**/*|runtime/*|runtime/**/*|pm/*|pm/**/*|docs/*.md)
      add_suite lint-portable-repo-paths; add_suite test-lint-portable-repo-paths; behavioral=1 ;;
  esac

  case "$path" in
    README.md|core/README.md|BACKLOG.md|MILESTONES.md|docs/*.md|docs/architecture/*.md|.github/*|.github/**/*|install.sh|uninstall.sh|cli/*|runtime/*|runtime/**/*|hosts/*|hosts/**/*|ops/*|ops/**/*|tools/*|tools/**/*)
      add_suite lint-script-domain-inventory; behavioral=1 ;;
  esac

  case "$path" in
    runtime/hooks/guard-*.sh)
      add_suite test-guards; behavioral=1 ;;
    cli/pmctl)
      for suite in "${!REGISTERED[@]}"; do [[ "$suite" == test-pmctl-* ]] && add_suite "$suite"; done
      add_suite lint-pmctl-commands
      behavioral=1 ;;
    agents/*.md)
      add_suite lint-agents; add_suite test-lint-frontmatter; behavioral=1 ;;
    commands/*.md)
      add_suite test-lint-frontmatter; add_suite test-commands; behavioral=1 ;;
    skills/*)
      add_suite test-lint-frontmatter; add_suite test-commands; behavioral=1 ;;
    adapters/claude/*)
      add_suite test-claude-dispatch; add_suite test-executor-router; add_suite test-runner-kind; behavioral=1 ;;
    adapters/codex/*)
      add_suite test-codex-dispatch; add_suite test-executor-router; add_suite test-runner-kind; behavioral=1 ;;
    adapters/opencode/*)
      add_suite test-opencode-dispatch; add_suite test-executor-router; add_suite test-runner-kind; behavioral=1 ;;
    adapters/grok/*)
      add_suite test-grok-dispatch; add_suite test-executor-router; add_suite test-runner-kind; behavioral=1 ;;
    adapters/*)
      add_suite test-executor-router; add_suite test-runner-kind; behavioral=1 ;;
    hosts/claude/*)
      add_suite test-host-manifest; add_suite test-host-write-parity; behavioral=1 ;;
    hosts/codex/*)
      add_suite test-host-manifest; add_suite test-host-write-codex; add_suite test-codex-dispatch-continuation; add_suite test-host-write-parity; behavioral=1 ;;
    hosts/opencode/*)
      add_suite test-host-manifest; add_suite test-host-write-opencode; add_suite test-host-write-parity; behavioral=1 ;;
    hosts/grok/*)
      add_suite test-host-manifest; add_suite test-host-write-parity; behavioral=1 ;;
    core/*)
      add_suite test-core-schemas; add_suite test-layer-boundaries; behavioral=1 ;;
    pm/*)
      add_suite test-pm-scripts; behavioral=1 ;;
    BACKLOG.md|BACKLOG-ARCHIVE.md|MILESTONES.md)
      add_suite test-schema-task-mirrors-backlog; add_suite test-pmctl-backlog; add_suite test-archive-closed-backlog; behavioral=1 ;;
    README.md|CHANGELOG.md|docs/*)
      add_suite test-check-docs-freshness; behavioral=1 ;;
    .github/*)
      add_suite lint-scripts; add_suite test-lint-shellcheck; behavioral=1 ;;
  esac

  [[ "$behavioral" -eq 1 ]] || COVERAGE_GAPS["$path"]=1
}

while IFS= read -r path; do map_path "$path"; done < <(printf '%s\n' "${!CHANGED[@]}" | LC_ALL=C sort)
changed_paths_json="$(printf '%s\n' "${!CHANGED[@]}" | LC_ALL=C sort | jq -Rsc 'split("\n") | map(select(length > 0))')"

printf 'run-tests: contract=iteration-only coverage=direct-impact (not final sign-off)\n' >&2
printf 'run-tests: changed paths: %s\n' "${#CHANGED[@]}" >&2

if [[ "$ESCALATE_FULL" -eq 1 ]]; then
  printf 'run-tests: affected selection is unsafe; escalating to full suite: %s\n' "$ESCALATE_REASON" >&2
  if [[ "$LIST_ONLY" -eq 1 ]]; then
    "$SUITE_RUNNER" --list
    exit 0
  fi
  if [[ -n "$RESULT_FILE" ]]; then
    escalated_suite_json="$("$SUITE_RUNNER" --list | jq -Rsc 'split("\n") | map(select(length > 0))')"
    pm_test_run_and_record "$REPO_ROOT" iteration "$RESULT_FILE" escalated-full \
      "$changed_paths_json" "$escalated_suite_json" '[]' "$BASE_REF" \
      "$SUITE_RUNNER" "${runner_args[@]}"
    exit $?
  fi
  exec "$SUITE_RUNNER" "${runner_args[@]}"
fi

if [[ "${#COVERAGE_GAPS[@]}" -gt 0 ]]; then
  printf 'run-tests: coverage gaps (no direct behavioral mapping):\n' >&2
  printf '  %s\n' "${!COVERAGE_GAPS[@]}" | LC_ALL=C sort >&2
fi

if [[ "${#SELECTED[@]}" -eq 0 ]]; then
  printf 'run-tests: no suites selected; this iteration result cannot be used as test evidence\n' >&2
  exit 2
fi

mapfile -t ORDERED_SUITES < <(
  "$SUITE_RUNNER" --list | while IFS= read -r suite; do
    [[ -n "${SELECTED[$suite]:-}" ]] && printf '%s\n' "$suite"
  done
)

printf 'run-tests: selected suites (%s): %s\n' "${#ORDERED_SUITES[@]}" "${ORDERED_SUITES[*]}" >&2
printf 'run-tests: final sign-off still requires a separate tests/bin/run-all-tests.sh PASS\n' >&2

if [[ "$LIST_ONLY" -eq 1 ]]; then
  printf '%s\n' "${ORDERED_SUITES[@]}"
  exit 0
fi

for suite in "${ORDERED_SUITES[@]}"; do runner_args+=(--suite "$suite"); done
if [[ -n "$RESULT_FILE" ]]; then
  iteration_suite_json="$(printf '%s\n' "${ORDERED_SUITES[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')"
  selection_mode=working-tree
  [[ -n "$BASE_REF" ]] && selection_mode=base-diff
  [[ "${#EXPLICIT_PATHS[@]}" -gt 0 ]] && selection_mode=explicit-paths
  pm_test_run_and_record "$REPO_ROOT" iteration "$RESULT_FILE" "$selection_mode" \
    "$changed_paths_json" "$iteration_suite_json" '[]' "$BASE_REF" \
    "$SUITE_RUNNER" "${runner_args[@]}"
  exit $?
fi
exec "$SUITE_RUNNER" "${runner_args[@]}"
