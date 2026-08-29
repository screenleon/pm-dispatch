#!/usr/bin/env bash
# Regression tests for runtime/lib/gate-options.sh — the source-safe Gate CLI
# option parser and its two pure cross-option comparators.
#
# These assertions used to run as end-to-end cases in test-pr-gate.sh, each
# spawning a real pr-gate.sh (~8s). They test option-shape rejections that
# gate-options.sh owns outright, so they belong here at ~0.12s/case. The two
# comparators (gate_options_require_initial_result,
# gate_options_reviewer_coverage_agrees) were extracted from pr-gate.sh's
# linear flow in the same change; pr-gate.sh still computes their inputs (they
# need the policy tables) and calls them at the same point.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/gate-options.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/gate-options.sh"

# want <name> <expected-rc> <actual-rc> [needle] [output]
# gate_options_* helpers call `exit`, so every assertion runs them in a ( … )
# subshell and passes the subshell's exit code here.
want() {
  local name="$1" exp="$2" got="$3" needle="${4:-}" body="${5:-}"
  if [[ "$got" -ne "$exp" ]]; then
    fail "$name" "expected exit $exp, got $got${body:+ :: $body}"
    return
  fi
  if [[ -n "$needle" && "$body" != *"$needle"* ]]; then
    fail "$name" "missing '$needle' in: $body"
    return
  fi
  pass "$name"
}

# --- gate_options_parse: rejections migrated from test-pr-gate.sh -------------

name="gate_options_parse: --policy bogus is rejected"
if should_run "$name"; then
  out="$( ( gate_options_init; gate_options_parse --policy bogus ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Error: --policy must be generic or maintainer (got: bogus)" "$out"
fi

name="gate_options_parse: --pass initial + --targeted is a pass-option conflict"
if should_run "$name"; then
  out="$( ( gate_options_init; gate_options_parse --pass initial --targeted critic ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "conflicting gate pass options: --pass requested initial, but --targeted requested targeted" "$out"
fi

# --- gate_options_parse: representative net-new rejection classes ------------

name="gate_options_parse: an unknown flag is rejected with the accepted-list"
if should_run "$name"; then
  out="$( ( gate_options_init; gate_options_parse --frobnicate ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Unknown arg: --frobnicate" "$out"
  [[ "$out" == *"Accepted: --cd"* ]] || fail "$name (accepted-list)" "no accepted-list line in: $out"
fi

name="gate_options_parse: --reviewers given twice is rejected"
if should_run "$name"; then
  out="$( ( gate_options_init; gate_options_parse --reviewers critic --reviewers qa-tester ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Error: --reviewers may only be provided once" "$out"
fi

name="gate_options_parse: --parallel + --sequential is a mode conflict"
if should_run "$name"; then
  out="$( ( gate_options_init; gate_options_parse --parallel --sequential ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "conflicting gate mode options: --parallel requested parallel, but --sequential requested sequential" "$out"
fi

# --- gate_options_parse: accepted inputs -----------------------------------

name="gate_options_parse: --policy generic is accepted"
if should_run "$name"; then
  ( gate_options_init; gate_options_parse --policy generic ) 2>/dev/null; rc=$?
  want "$name" 0 "$rc"
fi

name="gate_options_parse: --effort high is accepted, an unknown effort is not"
if should_run "$name"; then
  ( gate_options_init; gate_options_parse --effort high ) 2>/dev/null; rc=$?
  want "$name" 0 "$rc"
  out="$( ( gate_options_init; gate_options_parse --effort wild ) 2>&1 )"; rc2=$?
  want "$name/reject" 2 "$rc2" "Error: --effort must be one of: low medium high (got: wild)" "$out"
fi

# --- gate_options_require_workdir ----------------------------------------------

name="gate_options_require_workdir: an unset --cd is rejected"
if should_run "$name"; then
  out="$( ( gate_options_init; gate_options_require_workdir ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Error: --cd <dir> is required" "$out"
fi

name="gate_options_require_workdir: a relative --run-dir is rejected"
if should_run "$name"; then
  # WORK_DIR / GATE_RUN_DIR_OVERRIDE are read inside gate_options_require_workdir
  # (sourced), which ShellCheck cannot see through.
  # shellcheck disable=SC2154,SC2034  # tmp_root from th_init; the two are consumed by the sourced helper.
  out="$( ( gate_options_init; WORK_DIR="$tmp_root"; GATE_RUN_DIR_OVERRIDE="rel/dir"; gate_options_require_workdir ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Error: --run-dir must be an absolute path: rel/dir" "$out"
fi

# --- gate_options_require_initial_result (extracted from pr-gate.sh) --------

name="require_initial_result: requires=true + no --initial-result is rejected"
if should_run "$name"; then
  out="$( ( gate_options_require_initial_result true "" targeted ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Error: --pass targeted requires --initial-result <path>" "$out"
fi

name="require_initial_result: requires=true + --initial-result present is ok"
if should_run "$name"; then
  ( gate_options_require_initial_result true /some/initial.md targeted ) 2>/dev/null; rc=$?
  want "$name" 0 "$rc"
fi

name="require_initial_result: requires=false + --initial-result present is rejected"
if should_run "$name"; then
  out="$( ( gate_options_require_initial_result false /some/initial.md initial ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Error: --initial-result is only valid with --pass targeted" "$out"
fi

name="require_initial_result: requires=false + no --initial-result is ok"
if should_run "$name"; then
  ( gate_options_require_initial_result false "" initial ) 2>/dev/null; rc=$?
  want "$name" 0 "$rc"
fi

name="require_initial_result: a non-boolean policy value is a policy-integrity error"
if should_run "$name"; then
  out="$( ( gate_options_require_initial_result maybe /x targeted ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Error: invalid requires_initial_result value for pass kind targeted: maybe" "$out"
fi

# --- gate_options_reviewer_coverage_agrees (extracted from pr-gate.sh) -----

name="reviewer_coverage_agrees: same set, different order, agrees"
if should_run "$name"; then
  ( gate_options_reviewer_coverage_agrees "critic qa-tester" "qa-tester critic" ) 2>/dev/null; rc=$?
  want "$name" 0 "$rc"
fi

name="reviewer_coverage_agrees: an identical single reviewer agrees"
if should_run "$name"; then
  ( gate_options_reviewer_coverage_agrees "critic" "critic" ) 2>/dev/null; rc=$?
  want "$name" 0 "$rc"
fi

name="reviewer_coverage_agrees: disjoint sets are rejected"
if should_run "$name"; then
  out="$( ( gate_options_reviewer_coverage_agrees "critic" "qa-tester" ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "Error: --reviewers and --targeted request different reviewer coverage" "$out"
fi

name="reviewer_coverage_agrees: a strict subset is rejected"
if should_run "$name"; then
  out="$( ( gate_options_reviewer_coverage_agrees "critic qa-tester" "critic" ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "different reviewer coverage" "$out"
fi

th_summary
