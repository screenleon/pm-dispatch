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
# Resolver integration remains in test-pr-gate.sh. The focused cost case below
# uses the same input shape as pr-gate.sh's GATE_POLICY_INPUT producer, without
# dispatching reviewers, to measure unmatched-signal overhead directly.
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
# export needed; the read is inside the sourced _gate_assurance_policy_resolve, so
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

# --- _gate_assurance_policy_lookup (CC-600: no per-call subshell/cat/pipe) ---
# A gate resolves the policy ~100 times and every extra process costs ~40 ms on
# native Windows, so the lookup was reworked to read the table with one awk. The
# contract is unchanged: exactly one matching row, a non-empty value, and the
# same answer from the canonical file and from the bundled snapshot.

name="policy_lookup: the canonical file answers, and copy-mode answers from the bundled snapshot instead"
if should_run "$name"; then
  # A fixture whose express row differs from the bundled snapshot makes the
  # source of the answer observable (the real file and the snapshot are
  # byte-identical by design, so they cannot tell the two paths apart).
  d="$tmp_root/lookup-source"
  mkdir -p "$d"
  printf 'tier\tdefault_reviewers\tevidence_floor\nexpress\tfixture-only\treviewer-verdicts\n' \
    > "$d/gate-tiers.tsv"
  # The real answer is read from the shipped file, not hard-coded, so a
  # legitimate policy edit cannot break a test about *where* the answer comes from.
  expected="$(awk -F '\t' '$1 == "express" { print $2 }' "$REPO_ROOT/core/policy/gate-tiers.tsv")"
  real="$( _gate_assurance_policy_lookup tiers tier express default_reviewers 2>&1 )"; rc1=$?
  canonical="$( PR_GATE_POLICY_DIR="$d" \
    _gate_assurance_policy_lookup tiers tier express default_reviewers 2>&1 )"; rc2=$?
  snapshot="$( PR_GATE_POLICY_DIR="$d" PR_GATE_INSTALLED_COPY_ROOT=/nonexistent \
    _gate_assurance_policy_lookup tiers tier express default_reviewers 2>&1 )"; rc3=$?
  if [[ "$rc1" -eq 0 && "$rc2" -eq 0 && "$rc3" -eq 0 && -n "$expected" \
      && "$real" == "$expected" && "$canonical" == "fixture-only" \
      && "$snapshot" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "expected '$expected'; real rc=$rc1 '$real'; canonical rc=$rc2 '$canonical'; snapshot rc=$rc3 '$snapshot'"
  fi
fi

name="policy_lookup: an unreadable canonical table falls back to the bundled snapshot"
if should_run "$name"; then
  d="$tmp_root/lookup-empty-dir"
  mkdir -p "$d"
  expected="$(awk -F '\t' '$1 == "express" { print $2 }' "$REPO_ROOT/core/policy/gate-tiers.tsv")"
  out="$( PR_GATE_POLICY_DIR="$d" \
    _gate_assurance_policy_lookup tiers tier express default_reviewers 2>&1 )"; rc=$?
  if [[ "$rc" -eq 0 && -n "$expected" && "$out" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "expected '$expected'; rc=$rc '$out'"
  fi
fi

name="policy_lookup: an unknown table, key, column or argument count is rejected with rc 2"
if should_run "$name"; then
  _gate_assurance_policy_lookup nosuchtable tier express default_reviewers >/dev/null 2>&1; rc1=$?
  _gate_assurance_policy_lookup tiers tier nosuchtier default_reviewers >/dev/null 2>&1; rc2=$?
  _gate_assurance_policy_lookup tiers tier express nosuchcolumn >/dev/null 2>&1; rc3=$?
  _gate_assurance_policy_lookup tiers tier express >/dev/null 2>&1; rc4=$?
  if [[ "$rc1" -eq 2 && "$rc2" -eq 2 && "$rc3" -eq 2 && "$rc4" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "rc table=$rc1 key=$rc2 column=$rc3 arity=$rc4 (all must be 2)"
  fi
fi

name="policy_path: prints the canonical file, and returns 1 in copy mode and 2 for an unknown table"
if should_run "$name"; then
  out="$( _gate_assurance_policy_path tiers )"; rc1=$?
  copy="$( PR_GATE_INSTALLED_COPY_ROOT=/nonexistent _gate_assurance_policy_path tiers )"; rc2=$?
  _gate_assurance_policy_path nosuchtable >/dev/null 2>&1; rc3=$?
  if [[ "$rc1" -eq 0 && "$out" == "$REPO_ROOT/core/policy/gate-tiers.tsv" \
      && "$rc2" -eq 1 && -z "$copy" && "$rc3" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "canonical rc=$rc1 '$out'; copy rc=$rc2 '$copy'; unknown rc=$rc3"
  fi
fi

name="policy_lookup: a duplicated key row is rejected rather than answered"
if should_run "$name"; then
  d="$tmp_root/lookup-dupkey"
  mkdir -p "$d"
  cp "$REPO_ROOT/core/policy/gate-tiers.tsv" "$d/gate-tiers.tsv"
  printf 'express\tcritic\treviewer-verdicts\n' >> "$d/gate-tiers.tsv"
  out="$( PR_GATE_POLICY_DIR="$d" \
    _gate_assurance_policy_lookup tiers tier express default_reviewers 2>&1 )"; rc=$?
  want "$name" 2 "$rc" "" "$out"
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

case_resolver_unmatched_signal_cost() {
  # Behavior: unmatched classification rules add only the match-producing jq,
  # and do not change the resolved tier, reviewer set, or matched evidence.
  # Steps: resolve a fixture matching all three signal-source kinds, append
  # unmatched rules, and compare both output and actual process-count growth.
  local name="policy resolver: unmatched signals avoid extra jq probes"
  should_run "$name" || return 0
  local policy_dir input first second first_count second_count rc=0 index
  local shimdir="$tmp_root/policy-jq-shim" tally="$tmp_root/policy-jq.tally" real_jq
  policy_dir="$(_policy_dir resolver-cost)"
  input="$(jq -nc '{
    policy:"generic",policy_source:"repo",scope_fingerprint:("a" * 64),
    requested:{tier:"auto",mode:"default",pass_kind:"initial",reviewers:null},
    reviewer_vocabulary:["critic","qa-tester","architecture-reviewer","security-reviewer","risk-reviewer"],
    changed_paths:["runtime/auth/example.sh"],
    classifications:[{id:"bounded-runtime",matches:["runtime/auth/example.sh"]}],
    classification:{architecture_impact:"minor",line_changes:1,binary_or_unknown_count:0,layer_roots:["runtime"]},
    reviewer_override:null
  }')"
  real_jq="$(type -P jq)"
  mkdir -p "$shimdir"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf 'printf x >> %q\n' "$tally"
    printf 'exec %q "$@"\n' "$real_jq"
  } > "$shimdir/jq"
  chmod +x "$shimdir/jq"
  : > "$tally"
  first="$(PR_GATE_POLICY_DIR="$policy_dir" PATH="$shimdir:$PATH" _gate_policy_resolve "$input")" || rc=$?
  first_count="$(wc -c < "$tally")"
  for index in {1..8}; do
    printf 'unmatched-%s\tclassification\tdocs-only\tfull\trisk-reviewer\tparallel\n' "$index" \
      >> "$policy_dir/gate-policy-signals.tsv"
  done
  : > "$tally"
  second="$(PR_GATE_POLICY_DIR="$policy_dir" PATH="$shimdir:$PATH" _gate_policy_resolve "$input")" || rc=$?
  second_count="$(wc -c < "$tally")"
  if [[ "$rc" -ne 0 || "$first" != "$second" || $((second_count - first_count)) -ne 8 ]]; then
    fail "$name" "rc=$rc jq growth=$((second_count - first_count)); expected 8 and unchanged resolution"
    return
  fi
  if jq -e '
    .resolved == {tier:"standard",mode:"parallel",reviewers:["critic","qa-tester","architecture-reviewer","security-reviewer"]} and
    .enforcement.status == "pass" and
    [.matched_signals[].id] == ["consumer-policy","bounded-runtime","security-sensitive-path","brief-architecture-minor"] and
    [.matched_signals[].matches] == [["generic:initial"],["runtime/auth/example.sh"],["runtime/auth/example.sh"],["minor"]]
  ' <<< "$first" >/dev/null; then
    pass "$name"
  else
    fail "$name" "matched classification/path/brief evidence changed: $first"
  fi
}

case_resolver_unmatched_signal_cost
th_summary
