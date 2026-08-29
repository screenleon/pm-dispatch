#!/usr/bin/env bash
# Regression tests for runtime/lib/gate-policy.sh -- the reviewer-list validators
# and the policy-source integrity check.
#
# These assertions used to run as end-to-end cases in test-pr-gate.sh, each
# spawning a real pr-gate.sh (~8s). The functions here are pure `return 2`
# validators that take plain string args (or read the policy tables from
# $PR_GATE_POLICY_DIR), so they belong at ~0.12s/case. No production change:
# gate-policy.sh is only sourced and called.
#
# gate-policy.sh's risk/policy *resolver* (_gate_policy_resolve) is deliberately
# NOT covered here -- its input is a large hand-built JSON contract and moving
# those cases safely needs a captured golden input; they stay end-to-end for now.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/gate-policy.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/gate-policy.sh"

VOCAB="critic qa-tester architecture-reviewer security-reviewer risk-reviewer"

# _gate_policy_validate_sources reads its tables from this (same shell -- no
# export needed; the read is inside the sourced _gate_assurance_policy_path, so
# ShellCheck flags every assignment as unused -- see shellcheck-ignores.tsv).
# Default to the real tables; the fixture cases point it at a tmp copy.
PR_GATE_POLICY_DIR="$REPO_ROOT/core/policy"

# want <name> <expected-rc> <actual-rc> [needle] [output]
# The validators call `return`, not `exit`, but a stray future `exit` would
# still be contained; each assertion runs the call in a ( … ) subshell.
want() {
  local name="$1" exp="$2" got="$3" needle="${4:-}" body="${5:-}"
  if [[ "$got" -ne "$exp" ]]; then
    fail "$name" "expected rc $exp, got $got${body:+ :: $body}"
    return
  fi
  if [[ -n "$needle" && "$body" != *"$needle"* ]]; then
    fail "$name" "missing '$needle' in: $body"
    return
  fi
  pass "$name"
}

# Build a $PR_GATE_POLICY_DIR fixture: the real consumers table (unchanged, so
# its shape check passes first) plus a signals table the caller may mutate.
# Prints the dir path.
_policy_dir() {
  # shellcheck disable=SC2154  # tmp_root is initialized by th_init.
  local d="$tmp_root/$1"
  mkdir -p "$d"
  cp "$REPO_ROOT/core/policy/gate-policy-consumers.tsv" "$d/gate-policy-consumers.tsv"
  cp "$REPO_ROOT/core/policy/gate-policy-signals.tsv" "$d/gate-policy-signals.tsv"
  printf '%s' "$d"
}

# --- _gate_policy_normalize_reviewer_list (migrated: empty / duplicate) -----

name="normalize_reviewer_list: a valid CSV normalizes to a space list"
if should_run "$name"; then
  out="$( ( _gate_policy_normalize_reviewer_list "qa-tester,critic" "$VOCAB" "--reviewers" ) 2>/dev/null )"; rc=$?
  want "$name" 0 "$rc"
  [[ "$out" == "qa-tester critic" ]] || fail "$name (order preserved)" "got '$out'"
fi

name="normalize_reviewer_list: an empty / bare-comma list is rejected"
if should_run "$name"; then
  for raw in "" "," "critic," ",critic" "a,,b" "   "; do
    out="$( ( _gate_policy_normalize_reviewer_list "$raw" "$VOCAB" "--reviewers" ) 2>&1 )"; rc=$?
    if [[ "$rc" -ne 2 || "$out" != *"--reviewers requires a non-empty comma-separated reviewer list"* ]]; then
      fail "$name" "raw='$raw' rc=$rc out=$out"; break
    fi
  done
  [[ "$rc" -eq 2 ]] && pass "$name"
fi

name="normalize_reviewer_list: a duplicate reviewer is rejected, naming it"
if should_run "$name"; then
  out="$( ( _gate_policy_normalize_reviewer_list "critic,critic" "$VOCAB" "--reviewers" ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "--reviewers contains duplicate reviewer: critic" "$out"
fi

name="normalize_reviewer_list: a reviewer outside the vocabulary is rejected"
if should_run "$name"; then
  out="$( ( _gate_policy_normalize_reviewer_list "critic,nobody" "$VOCAB" "--reviewers" ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "--reviewers contains unknown reviewer nobody" "$out"
fi

# --- _gate_policy_validate_reviewer_csv (net-new: sibling validator) --------

name="validate_reviewer_csv: the literal 'none' is accepted"
if should_run "$name"; then
  ( _gate_policy_validate_reviewer_csv "none" "$VOCAB" "signals row X" ) 2>/dev/null; rc=$?
  want "$name" 0 "$rc"
fi

name="validate_reviewer_csv: a repeated reviewer is rejected"
if should_run "$name"; then
  out="$( ( _gate_policy_validate_reviewer_csv "critic,critic" "$VOCAB" "signals row X" ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "gate policy signals row X repeats reviewer critic" "$out"
fi

name="validate_reviewer_csv: an unknown reviewer is rejected"
if should_run "$name"; then
  out="$( ( _gate_policy_validate_reviewer_csv "critic,nobody" "$VOCAB" "signals row X" ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "names unknown reviewer nobody" "$out"
fi

name="validate_reviewer_csv: a malformed list is rejected"
if should_run "$name"; then
  out="$( ( _gate_policy_validate_reviewer_csv ",critic" "$VOCAB" "signals row X" ) 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "has an invalid reviewer list" "$out"
fi

# --- _gate_policy_validate_sources (migrated: dormant / duplicate signal) ---

name="validate_sources: the real core/policy tables pass"
if should_run "$name"; then
  out="$( _gate_policy_validate_sources "$VOCAB" 2>&1 )"; rc=$?
  want "$name" 0 "$rc" "" "$out"
fi

name="validate_sources: a signal naming a reviewer outside the vocabulary is rejected"
if should_run "$name"; then
  d="$(_policy_dir sources-dormant)"
  printf 'dormant-signal\tpath-regex\tnever-match-this-fixture\tstandard\tunknown-reviewer\tparallel\n' \
    >> "$d/gate-policy-signals.tsv"
  PR_GATE_POLICY_DIR="$d"
  out="$( _gate_policy_validate_sources "$VOCAB" 2>&1 )"; rc=$?
  PR_GATE_POLICY_DIR="$REPO_ROOT/core/policy"
  want "$name" 2 "$rc" "signal dormant-signal names unknown reviewer unknown-reviewer" "$out"
fi

name="validate_sources: a duplicate signal id is rejected"
if should_run "$name"; then
  d="$(_policy_dir sources-dupid)"
  # docs-only already exists in the real table; a second row with the same id
  # breaks the closed unique-inventory contract.
  printf 'docs-only\tpath-regex\tnever-match-this-fixture\texpress\tnone\tsequential\n' \
    >> "$d/gate-policy-signals.tsv"
  PR_GATE_POLICY_DIR="$d"
  out="$( _gate_policy_validate_sources "$VOCAB" 2>&1 )"; rc=$?
  PR_GATE_POLICY_DIR="$REPO_ROOT/core/policy"
  want "$name" 2 "$rc" "invalid gate policy signals source" "$out"
fi

name="validate_sources: it requires exactly one non-empty vocabulary argument"
if should_run "$name"; then
  _gate_policy_validate_sources        2>/dev/null; rc0=$?
  _gate_policy_validate_sources ""     2>/dev/null; rc1=$?
  _gate_policy_validate_sources a b    2>/dev/null; rc2=$?
  if [[ "$rc0" -eq 2 && "$rc1" -eq 2 && "$rc2" -eq 2 ]]; then pass "$name"; else fail "$name" "rc0=$rc0 rc1=$rc1 rc2=$rc2"; fi
fi

th_summary
