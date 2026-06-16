#!/usr/bin/env bash
# Standalone test aggregator - run all pm-dispatch test suites.
# Usage: scripts/run-all-tests.sh [--skip <name>] [--list]
# Requires a complete developer checkout: registered suites that are missing or
# non-executable fail loudly (exit 1). Use --skip <name> to opt out of a specific suite.
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SUITE_NAMES=(
  lint-agents
  lint-scripts
  test-hooks
  test-hook-framework
  test-migrate
  test-migrate-to-events
  test-install
  test-uninstall
  test-usage-weekly
  test-usage-tracker
  test-pm-scripts
  test-codex-dispatch
  test-pmctl-dispatch
  test-claude-dispatch
  test-opencode-dispatch
  test-layer-boundaries
  test-executor-router
  test-runner-kind
  test-pmctl-adapter-generate
  test-pr-gate
  test-setup-project
  test-patch-gitignore
  test-portable
  test-doctor
  test-lint-frontmatter
  test-test-harness
  test-commands
  test-commands-runner
  test-dispatch-handover
  test-handover-validate
  test-dispatch-post-verify
  test-check-docs-freshness
  test-skill-refine
  test-pr-gate-profile
  test-claude-executor
  test-run-all-tests
  test-lint-model-aliases
  test-core-schemas
  test-pm-prep-snapshot
  test-schema-task-mirrors-backlog
  test-state-store
  test-state-layout-parity
  test-state-store-rotation
  test-pmctl-trace
  test-pmctl-task
  test-pmctl-decision
  test-pmctl-gate
  test-pmctl-safe
  test-pmctl-validate
  test-brief-validate
  test-archive-closed-backlog
  test-pmctl-context
  test-pmctl-backlog
  test-pmctl-guard
  test-release-verify
  test-e2e-script
)

declare -A SUITE_PATHS=(
  [lint-agents]="scripts/lint-agents.sh"
  [lint-scripts]="scripts/lint-scripts.sh"
  [test-hooks]="scripts/test-hooks.sh"
  [test-hook-framework]="scripts/test-hook-framework.sh"
  [test-migrate]="scripts/test-migrate-routing-log.sh"
  [test-migrate-to-events]="scripts/test-migrate-routing-to-events.sh"
  [test-install]="scripts/test-install.sh"
  [test-uninstall]="scripts/test-uninstall.sh"
  [test-usage-weekly]="scripts/test-usage-weekly.sh"
  [test-usage-tracker]="scripts/test-usage-tracker.sh"
  [test-pm-scripts]="pm/scripts/test/run-tests.sh"
  [test-codex-dispatch]="scripts/test-codex-dispatch.sh"
  [test-pmctl-dispatch]="scripts/test-pmctl-dispatch.sh"
  [test-claude-dispatch]="scripts/test-claude-dispatch.sh"
  [test-opencode-dispatch]="scripts/test-opencode-dispatch.sh"
  [test-layer-boundaries]="scripts/test-layer-boundaries.sh"
  [test-executor-router]="scripts/test-executor-router.sh"
  [test-runner-kind]="scripts/test-runner-kind.sh"
  [test-pmctl-adapter-generate]="scripts/test-pmctl-adapter-generate.sh"
  [test-pr-gate]="scripts/test-pr-gate.sh"
  [test-setup-project]="scripts/test-setup-project.sh"
  [test-patch-gitignore]="scripts/test-patch-gitignore.sh"
  [test-portable]="scripts/test-portable.sh"
  [test-doctor]="scripts/test-doctor.sh"
  [test-lint-frontmatter]="scripts/test-lint-frontmatter.sh"
  [test-test-harness]="scripts/test-test-harness.sh"
  [test-commands]="scripts/test-commands.sh"
  [test-commands-runner]="scripts/test-commands-runner.sh"
  [test-dispatch-handover]="scripts/test-dispatch-handover.sh"
  [test-handover-validate]="scripts/test-handover-validate.sh"
  [test-dispatch-post-verify]="scripts/test-dispatch-post-verify.sh"
  [test-check-docs-freshness]="scripts/test-check-docs-freshness.sh"
  [test-skill-refine]="scripts/test-skill-refine.sh"
  [test-pr-gate-profile]="scripts/test-pr-gate-profile.sh"
  [test-claude-executor]="scripts/test-claude-executor.sh"
  [test-run-all-tests]="scripts/test-run-all-tests.sh"
  [test-lint-model-aliases]="scripts/test-lint-model-aliases.sh"
  [test-core-schemas]="scripts/test-core-schemas.sh"
  [test-pm-prep-snapshot]="scripts/test-pm-prep-snapshot.sh"
  [test-schema-task-mirrors-backlog]="scripts/test-schema-task-mirrors-backlog.sh"
  [test-state-store]="scripts/test-state-store.sh"
  [test-state-layout-parity]="scripts/test-state-layout-parity.sh"
  [test-state-store-rotation]="scripts/test-state-store-rotation.sh"
  [test-pmctl-trace]="scripts/test-pmctl-trace.sh"
  [test-pmctl-task]="scripts/test-pmctl-task.sh"
  [test-pmctl-decision]="scripts/test-pmctl-decision.sh"
  [test-pmctl-gate]="scripts/test-pmctl-gate.sh"
  [test-pmctl-safe]="scripts/test-pmctl-safe.sh"
  [test-pmctl-validate]="scripts/test-pmctl-validate.sh"
  [test-brief-validate]="scripts/test-brief-validate.sh"
  [test-archive-closed-backlog]="scripts/test-archive-closed-backlog.sh"
  [test-pmctl-context]="scripts/test-pmctl-context.sh"
  [test-pmctl-backlog]="scripts/test-pmctl-backlog.sh"
  [test-pmctl-guard]="scripts/test-pmctl-guard.sh"
  [test-release-verify]="scripts/test-release-verify.sh"
  [test-e2e-script]="scripts/test-e2e-script.sh"
)

declare -A SKIP_REQUESTED=()
LIST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip)
      if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
        printf 'usage: %s [--skip <suite-name>] [--list]\n' "$0" >&2
        printf 'error: --skip requires a non-empty suite name (got: %q)\n' "${2:-}" >&2
        exit 2
      fi
      SKIP_REQUESTED["$2"]=1
      shift 2
      ;;
    --list)
      LIST=1
      shift
      ;;
    *)
      echo "run-all-tests: unknown flag $1" >&2
      exit 2
      ;;
  esac
done

if [[ "$LIST" -eq 1 ]]; then
  printf '%s\n' "${SUITE_NAMES[@]}"
  exit 0
fi

passed=0
failed=0
skipped=0
FAILED_SUITE_NAMES=()

run_suite() {
  local name="$1"
  local script="$REPO_ROOT/${SUITE_PATHS[$name]}"

  case "$name" in
    test-hooks)
      HOME="${CLAUDE_CONFIG_TEST_PREFLIGHT_HOME:-$HOME}" "$script"
      ;;
    test-install)
      CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 bash "$script"
      ;;
    test-pm-scripts)
      bash "$script"
      ;;
    *)
      "$script"
      ;;
  esac
}

for name in "${SUITE_NAMES[@]}"; do
  if [[ -n "${SKIP_REQUESTED[$name]:-}" ]]; then
    printf 'SKIP %s (requested)\n' "$name"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$name" == "test-codex-dispatch" ]] &&
    [[ "${CODEX_SKIP_IF_MISSING:-1}" != "0" ]] &&
    ! command -v codex >/dev/null 2>&1; then
    printf 'SKIP %s (codex not on PATH)\n' "$name"
    skipped=$((skipped + 1))
    continue
  fi

  script="$REPO_ROOT/${SUITE_PATHS[$name]}"
  if [[ ! -x "$script" ]]; then
    printf 'FAIL %s (not found or not executable)\n' "$name"
    failed=$((failed + 1))
    FAILED_SUITE_NAMES+=("$name")
    continue
  fi

  set +e
  run_suite "$name"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    printf 'PASS %s\n' "$name"
    passed=$((passed + 1))
  else
    printf 'FAIL %s\n' "$name"
    failed=$((failed + 1))
    FAILED_SUITE_NAMES+=("$name")
  fi
done

printf '%s passed, %s failed, %s skipped\n' "$passed" "$failed" "$skipped"
if [[ "${#FAILED_SUITE_NAMES[@]}" -gt 0 ]]; then
  printf 'failed suites:'
  printf ' %s' "${FAILED_SUITE_NAMES[@]}"
  printf '\n'
  exit 1
fi
