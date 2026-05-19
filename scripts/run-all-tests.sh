#!/usr/bin/env bash
# Standalone test aggregator - run all pm-dispatch test suites.
# Usage: scripts/run-all-tests.sh [--skip <name>] [--list]
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SUITE_NAMES=(
  lint-agents
  lint-scripts
  test-hooks
  test-migrate
  test-install
  test-usage-weekly
  test-usage-tracker
  test-pm-scripts
  test-codex-dispatch
  test-pr-gate
  test-setup-project
  test-patch-gitignore
)

declare -A SUITE_PATHS=(
  [lint-agents]="scripts/lint-agents.sh"
  [lint-scripts]="scripts/lint-scripts.sh"
  [test-hooks]="scripts/test-hooks.sh"
  [test-migrate]="scripts/test-migrate-routing-log.sh"
  [test-install]="scripts/test-install.sh"
  [test-usage-weekly]="scripts/test-usage-weekly.sh"
  [test-usage-tracker]="scripts/test-usage-tracker.sh"
  [test-pm-scripts]="pm/scripts/test/run-tests.sh"
  [test-codex-dispatch]="scripts/test-codex-dispatch.sh"
  [test-pr-gate]="scripts/test-pr-gate.sh"
  [test-setup-project]="scripts/test-setup-project.sh"
  [test-patch-gitignore]="scripts/test-patch-gitignore.sh"
)

declare -A SKIP_REQUESTED=()
LIST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip)
      [[ $# -ge 2 ]] || { echo "run-all-tests: --skip requires a suite name" >&2; exit 2; }
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
    printf 'SKIP %s (not found)\n' "$name"
    skipped=$((skipped + 1))
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
  fi
done

printf '%s passed, %s failed, %s skipped\n' "$passed" "$failed" "$skipped"
if [[ "$failed" -gt 0 ]]; then
  exit 1
fi
