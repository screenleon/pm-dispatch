#!/usr/bin/env bash
# Regression tests for ops/diagnostics/run-tests-in-wsl.sh: argument handling and
# the platform refusal. Running real suites needs native Windows plus WSL2 and is
# exercised by hand (the helper is a developer aid, not a release gate).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/ops/diagnostics/run-tests-in-wsl.sh"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

should_run() {
  if $LIST; then ALL_CASES+=("$1"); return 1; fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

# run_helper <expected-exit> <output-substring> <name> <args...>
run_helper() {
  local expected="$1" needle="$2" name="$3"
  shift 3
  should_run "$name" || return 0
  local output status
  output="$(bash "$HELPER" "$@" 2>&1)"
  status=$?
  if [[ "$status" -eq "$expected" && "$output" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit $expected containing '$needle'; got exit $status: $output"
  fi
}

# Behavior: help text is printed on stdout-or-stderr with exit 0 and names the
# options a caller needs.
# Steps: run with --help; assert exit 0 and the usage line.
run_helper 0 "usage: run-tests-in-wsl.sh" "run-tests-in-wsl/help" --help

# Behavior: a call that names no suite (and is not --sync-only) is a usage error.
# Steps: run with no arguments; assert exit 2 and the usage line.
run_helper 2 "usage:" "run-tests-in-wsl/no-suite-is-usage-error"

# Behavior: unknown options and a malformed --timeout are usage errors, not
# silently ignored.
# Steps: run with --bogus, then with --timeout abc; assert exit 2 for each.
run_helper 2 "usage:" "run-tests-in-wsl/unknown-option" --bogus test-foo
run_helper 2 "usage:" "run-tests-in-wsl/non-numeric-timeout" --timeout abc test-foo
run_helper 2 "usage:" "run-tests-in-wsl/zero-timeout" --timeout 0 test-foo

# Behavior: outside native Windows Git Bash the helper refuses, because there
# the suites should simply be run directly.
# Steps: on a non-msys, non-cygwin platform run with a suite name; assert exit 2
#        and the platform message. Skipped on native Windows.
case "${OSTYPE:-}" in
  msys*|cygwin*)
    if should_run "run-tests-in-wsl/refuses-outside-native-windows"; then
      skip "run-tests-in-wsl/refuses-outside-native-windows" "only meaningful off native Windows"
    fi
    ;;
  *)
    run_helper 2 "native-Windows Git Bash" "run-tests-in-wsl/refuses-outside-native-windows" test-doctor
    ;;
esac

th_summary
