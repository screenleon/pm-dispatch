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

case_validate_sources_rejects_bad_tier_and_mode_rows() {
  # Behavior: a signal row naming an unknown tier or mode is rejected even when
  # earlier rows already named valid ones. CC-605 remembers the tiers/modes that
  # passed, so the memo must not leak between the two tables (a valid MODE is not
  # a valid TIER) nor match by prefix (`stand` is not `standard`).
  # Steps: append one bad row to the real signals table in each fixture -- tier
  # `parallel` (a valid mode), mode `standard` (a valid tier), tier `stand` (a
  # prefix of a valid tier) -- and assert rc 2 with the matching message.
  local name="validate_sources: an unknown tier or mode row is rejected (even a valid value of the other table)"
  should_run "$name" || return 0
  local d out rc bad="" spec
  for spec in \
    'bad-tier-mode|parallel|sequential|signal bad-tier-mode has invalid minimum tier: parallel' \
    'bad-mode-tier|standard|standard|signal bad-mode-tier has invalid recommended mode: standard' \
    'bad-tier-prefix|stand|sequential|signal bad-tier-prefix has invalid minimum tier: stand'; do
    IFS='|' read -r sig tier mode want <<<"$spec"
    d="$(_policy_dir "sources-$sig")"
    printf '%s\tpath-regex\tnever-match-this-fixture\t%s\tnone\t%s\n' "$sig" "$tier" "$mode" \
      >> "$d/gate-policy-signals.tsv"
    out="$( PR_GATE_POLICY_DIR="$d" _gate_policy_validate_sources "$VOCAB" 2>&1 )"; rc=$?
    if [[ "$rc" -ne 2 || "$out" != *"$want"* ]]; then
      bad+=" [$sig rc=$rc '$out']"
    fi
  done
  if [[ -z "$bad" ]]; then
    pass "$name"
  else
    fail "$name" "not rejected as expected:$bad"
  fi
}

# _resolver_fixture <name>: a policy dir whose signals table is exactly the two
# rows the resolver cases below depend on, so they do not track the real table.
_resolver_fixture() {
  local d
  d="$(_policy_dir "$1")"
  printf '%s\n' \
    $'signal\tmatch_source\tpattern\tminimum_tier\trequired_reviewers\trecommended_mode' \
    $'bounded-runtime\tclassification\tbounded-runtime\tstandard\tarchitecture-reviewer\tparallel' \
    $'auth-path\tpath-regex\t(^|/)auth(/|$)\tstandard\tsecurity-reviewer\tparallel' \
    > "$d/gate-policy-signals.tsv"
  printf '%s' "$d"
}

# _resolver_input: a well-formed resolver input (prints one compact JSON line).
_resolver_input() {
  jq -nc '{
    policy:"generic",policy_source:"repo",scope_fingerprint:("a" * 64),
    requested:{tier:"auto",mode:"default",pass_kind:"initial",reviewers:null},
    reviewer_vocabulary:["critic","qa-tester","architecture-reviewer","security-reviewer","risk-reviewer"],
    changed_paths:["runtime/lib/x.sh"],
    classifications:[{id:"bounded-runtime",matches:["runtime/lib/x.sh"]}],
    classification:{architecture_impact:"none",line_changes:1,binary_or_unknown_count:0,layer_roots:["runtime"]},
    reviewer_override:null
  }'
}

case_resolver_fails_closed_on_malformed_classifications() {
  # Behavior: the resolver reads its input once (CC-605) but still fails closed
  # where per-signal jq reads used to: a classification list it cannot iterate,
  # or a matching entry whose `.matches` it cannot, is rc 2; the same defect on
  # an id no signal names is harmless.
  # Steps: resolve one well-formed input, then variants with a null
  # `.classifications`, a used id with null matches, and an unused id with null
  # matches; assert rc 0 / 2 / 2 / 0 and an unchanged resolution for the last.
  local name="policy resolver: malformed classification input fails closed only where it is used"
  should_run "$name" || return 0
  local input ok out null_list used_bad unused_bad d rc_ok=0 rc_null=0 rc_used=0 rc_unused=0
  d="$(_resolver_fixture resolver-malformed)"
  input="$(_resolver_input)"
  null_list="$(jq -c '.classifications = null' <<<"$input")"
  used_bad="$(jq -c '.classifications = [{id:"bounded-runtime"}]' <<<"$input")"
  unused_bad="$(jq -c '.classifications += [{id:"id-no-signal-names"}]' <<<"$input")"
  ok="$(PR_GATE_POLICY_DIR="$d" _gate_policy_resolve "$input" 2>/dev/null)" || rc_ok=$?
  PR_GATE_POLICY_DIR="$d" _gate_policy_resolve "$null_list" >/dev/null 2>&1 || rc_null=$?
  PR_GATE_POLICY_DIR="$d" _gate_policy_resolve "$used_bad" >/dev/null 2>&1 || rc_used=$?
  out="$(PR_GATE_POLICY_DIR="$d" _gate_policy_resolve "$unused_bad" 2>/dev/null)" || rc_unused=$?
  if [[ "$rc_ok" -eq 0 && "$rc_null" -eq 2 && "$rc_used" -eq 2 && "$rc_unused" -eq 0 \
      && "$(jq -cS . <<<"$out")" == "$(jq -cS . <<<"$ok")" ]]; then
    pass "$name"
  else
    fail "$name" "rc ok=$rc_ok null-list=$rc_null used-bad=$rc_used unused-bad=$rc_unused (want 0/2/2/0) or resolution differs"
  fi
}

case_resolver_rejects_unreadable_input_without_aborting() {
  # Behavior: input the resolver cannot read safely -- a string holding a NUL
  # (which would shift the record layout its single jq run hands to bash), or a
  # `changed_paths` that is not an array (which would read as "no paths" and drop
  # every path-based reviewer requirement) -- is rc 2, never data used as
  # arithmetic, never an abort of a `set -u` caller such as pr-gate.sh.
  # Steps: NUL in a scalar, a NUL-shifted record whose next field looks like a
  # command substitution, a string `changed_paths`, and a missing one; run each
  # in a `set -u` subshell and assert rc 2, no marker output, no shell abort.
  local name="policy resolver: unreadable input (NUL, non-array changed_paths) is rc 2 under set -u"
  should_run "$name" || return 0
  local d input variant out rc bad="" label
  d="$(_resolver_fixture resolver-unreadable)"
  input="$(_resolver_input)"
  for label in nul-policy nul-shift-inject string-paths missing-paths; do
    case "$label" in
      nul-policy) variant="$(jq -c '.policy = "generic\u0000"' <<<"$input")" ;;
      nul-shift-inject) variant="$(jq -c '.policy = "generic\u0000\u0000\u0000" | .policy_source = "a[$(echo INJECTED-MARKER >&2)]"' <<<"$input")" ;;
      string-paths) variant="$(jq -c '.changed_paths = "runtime/lib/x.sh"' <<<"$input")" ;;
      missing-paths) variant="$(jq -c 'del(.changed_paths)' <<<"$input")" ;;
    esac
    out="$( ( set -u; PR_GATE_POLICY_DIR="$d" _gate_policy_resolve "$variant" ) 2>&1 )"; rc=$?
    if [[ "$rc" -ne 2 || "$out" == *INJECTED-MARKER* || "$out" == *"unbound variable"* ]]; then
      bad+=" [$label rc=$rc '$out']"
    fi
  done
  if [[ -z "$bad" ]]; then
    pass "$name"
  else
    fail "$name" "not rejected cleanly:$bad"
  fi
}

case_resolver_path_lines_keep_grep_semantics() {
  # Behavior: changed paths are matched line by line, case-insensitively, exactly
  # as `jq -r | grep -iE` did: an upper-case path matches, and a path with an
  # embedded newline or tab, or an empty path, never fakes a match.
  # Steps: resolve an input whose paths are one upper-case auth path plus
  # `a\nb`, `t\tc` and "" against the pinned two-row fixture; assert rc 0, the
  # path signal matched exactly the upper-case path, and its reviewer was added.
  local name="policy resolver: changed paths keep line-by-line case-insensitive grep semantics"
  should_run "$name" || return 0
  local d input out rc=0
  d="$(_resolver_fixture resolver-paths)"
  input="$(_resolver_input | jq -c '.changed_paths = ["runtime/AUTH/Example.sh","a\nb","t\tc",""]')"
  out="$(PR_GATE_POLICY_DIR="$d" _gate_policy_resolve "$input" 2>/dev/null)" || rc=$?
  if [[ "$rc" -eq 0 ]] && jq -e '
      ([.matched_signals[] | select(.id == "auth-path") | .matches] == [["runtime/AUTH/Example.sh"]]) and
      (.resolved.reviewers | index("security-reviewer") != null)
    ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out"
  fi
}

case_resolver_keeps_a_matches_list_over_the_windows_command_line() {
  # Behavior: a signal whose matched paths exceed the ~32 KB Windows command line
  # is resolved like a small one (#621). The list used to be passed to jq with
  # --argjson, sharing the command line with the program text.
  # Steps: resolve an input with 2000 long auth paths (about 150 KB matched);
  # assert rc 0, every path is kept, and the reviewer is still added.
  local name="policy resolver: a matches list over the command-line limit is kept whole"
  should_run "$name" || return 0
  local d input out rc=0
  d="$(_resolver_fixture resolver-large-matches)"
  input="$(_resolver_input | jq -c '.changed_paths = [range(0;2000) | "runtime/auth/" + ("d" * 60) + "/" + (tostring) + ".sh"]')"
  out="$(PR_GATE_POLICY_DIR="$d" _gate_policy_resolve "$input" 2>/dev/null)" || rc=$?
  # The expected list goes in through a file: this assertion has the same size
  # limit as the code under test.
  printf '%s\n' "$input" > "$d/input.json"
  if [[ "$rc" -eq 0 ]] && jq -e --slurpfile input "$d/input.json" '
      ([.matched_signals[] | select(.id == "auth-path") | .matches | sort] == [$input[0].changed_paths | sort]) and
      (.resolved.reviewers | index("security-reviewer") != null)
    ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "rc=$rc matched=$(jq -c '[.matched_signals[]? | {id, n: (.matches | length)}]' <<<"$out" 2>/dev/null)"
  fi
}

case_resolver_unmatched_signal_cost() {
  # Behavior: unmatched classification rules add no jq process at all (the
  # resolver reads its input once, CC-605), and do not change the resolved tier,
  # reviewer set, or matched evidence.
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
  if [[ "$rc" -ne 0 || "$first" != "$second" || $((second_count - first_count)) -ne 0 ]]; then
    fail "$name" "rc=$rc jq growth=$((second_count - first_count)); expected 0 and unchanged resolution"
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

case_header_marks_generated_matches_head_grep() {
  # Behavior: the generated-file header check answers exactly as the
  # `head -n 8 | grep -iE` pipeline it replaced, without starting a process.
  # Steps: write files that differ in case, line position, trailing newline,
  # line endings, a marker split over two lines, a binary body and no content;
  # assert each answer against the old pipeline's.
  local name="policy: generated-header check matches head|grep -iE"
  should_run "$name" || return 0
  local d f exp got bad=""
  d="$tmp_root/header-generated"; mkdir -p "$d"
  printf 'x\nDO NOT EDIT - Generated by foo\n' > "$d/upper"
  printf '1\n2\n3\n4\n5\n6\n7\n8\ndo not edit generated\n' > "$d/line9"
  printf '1\n2\n3\n4\n5\n6\n7\ngenerated, do not edit\n' > "$d/line8"
  printf 'This file is GENERATED, please do not edit' > "$d/no-newline"
  printf 'a\r\ngenerated; do not edit\r\n' > "$d/crlf"
  printf 'do not edit\ngenerated\n' > "$d/split"
  printf 'plain text\n' > "$d/plain"
  printf '\0\0do not edit generated\0\n' > "$d/binary"
  : > "$d/empty"
  for f in "$d"/*; do
    exp=1; head -n 8 "$f" 2>/dev/null | grep -qiE 'do not edit.*generated|generated.*do not edit' && exp=0
    got=1; _gate_policy_header_marks_generated "$f" && got=0
    [[ "$exp" == "$got" ]] || bad+=" ${f##*/}(old=$exp new=$got)"
  done
  if [[ -z "$bad" ]]; then
    pass "$name"
  else
    fail "$name" "mismatch:$bad"
  fi
}

# The awk programs the table lookups used before they read the table in bash.
_oracle_awk_lookup() { # <file> <key-column> <key> <value-column>
  awk -F '\t' -v key_name="$2" -v wanted="$3" -v value_name="$4" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    !header_seen {
      header_seen=1; header_width=NF
      for (i=1; i<=NF; i++) {
        sub(/\r$/, "", $i)
        if ($i == key_name) key_index=i
        if ($i == value_name) value_index=i
      }
      if (!key_index || !value_index) { malformed=1; exit }
      next
    }
    {
      sub(/\r$/, "", $NF)
      if (NF != header_width) { malformed=1; exit }
      if ($(key_index) == wanted) { matches++; result=$(value_index) }
    }
    END {
      if (malformed || !header_seen || matches != 1 || result == "") exit 2
      print result
    }' < "$1"
}
_oracle_awk_values() { # <file> <key-column>
  awk -F '\t' -v key_name="$2" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    !header_seen {
      header_seen=1; header_width=NF
      for (i=1; i<=NF; i++) { sub(/\r$/, "", $i); if ($i == key_name) key_index=i }
      if (!key_index) { malformed=1; exit }
      next
    }
    {
      sub(/\r$/, "", $NF)
      value=$(key_index)
      if (NF != header_width || value == "" || seen[value]++) { malformed=1; exit }
      values[++count]=value
    }
    END {
      if (malformed || !header_seen || count == 0) exit 2
      for (i=1; i<=count; i++) print values[i]
    }' < "$1"
}

case_table_reads_answer_as_the_awk_programs_did() {
  # Behavior: a policy table lookup and an enum listing give the answer, and the
  # exit status, the awk programs they replaced gave, for well-formed and for
  # every malformed shape (the gate fails closed on those), and a table rewritten
  # between two calls in one shell is read again, not served from a stale parse.
  # Steps: write tables that differ in comments, line endings, duplicate keys,
  # short rows, empty cells, a missing column and a bad row after the match;
  # compare both answers with the old programs'; rewrite one table and ask again.
  local name="policy: table lookups answer as the awk programs did"
  should_run "$name" || return 0
  local d="$tmp_root/table-reads" saved_dir="$PR_GATE_POLICY_DIR" t f q bad="" exp got exp_rc got_rc
  mkdir -p "$d"
  t="$d/gate-tiers.tsv"
  local -a tables=(
    $'tier\tdefault_reviewers\tevidence_floor\nexpress\tcritic\tfloor-a\nfull\tcritic,qa-tester\tfloor-b'
    $'# note\n\ntier\tdefault_reviewers\tevidence_floor\n  # inner\nexpress\tcritic\tfloor-a\n\nfull\tx\tfloor-b\n'
    $'tier\tdefault_reviewers\tevidence_floor\r\nexpress\tcritic\tfloor-a\r\nfull\tx\tfloor-b\r\n'
    $'tier\tdefault_reviewers\tevidence_floor\nexpress\tcritic\tfloor-a\nexpress\tcritic\tfloor-b'
    $'tier\tdefault_reviewers\tevidence_floor\nexpress\tcritic'
    $'tier\tdefault_reviewers\tevidence_floor\nexpress\tcritic\t\nfull\tx\tfloor-b'
    $'tier\tdefault_reviewers\tevidence_floor\nexpress\tcritic\tfloor-a\t'
    $'tier\tdefault_reviewers\nexpress\tcritic'
    $'tier\tdefault_reviewers\tevidence_floor\nexpress\tcritic\tfloor-a\nfull\tbroken'
    $'tier\tdefault_reviewers\tevidence_floor\tevidence_floor\nexpress\tcritic\tfloor-a\tfloor-z'
    $'tier\tdefault_reviewers\tevidence_floor'
    $'# only a comment\n'
    ''
  )
  PR_GATE_POLICY_DIR="$d"
  for f in "${tables[@]}"; do
    printf '%s' "$f" > "$t"
    for q in "tier express evidence_floor" "tier full default_reviewers" "tier absent evidence_floor" \
             "tier express nosuchcolumn" "nosuchcolumn express evidence_floor" \
             "default_reviewers critic tier"; do
      # shellcheck disable=SC2086
      set -- $q
      exp="$(_oracle_awk_lookup "$t" "$1" "$2" "$3")"; exp_rc=$?
      got="$(_gate_assurance_policy_lookup tiers "$1" "$2" "$3")"; got_rc=$?
      [[ "$exp_rc/$exp" == "$got_rc/$got" ]] \
        || bad+=" lookup[$q](old=$exp_rc/$exp new=$got_rc/$got)"
    done
    for q in tier default_reviewers evidence_floor nosuchcolumn; do
      exp="$(_oracle_awk_values "$t" "$q")"; exp_rc=$?
      got="$(_gate_assurance_policy_values tiers "$q")"; got_rc=$?
      [[ "$exp_rc/$exp" == "$got_rc/$got" ]] \
        || bad+=" values[$q](old=$exp_rc/$exp new=$got_rc/$got)"
    done
  done
  printf 'tier\tdefault_reviewers\tevidence_floor\nexpress\tcritic\tfirst\n' > "$t"
  # Same shell, no command substitution: the parse cache lives in this process.
  _gate_assurance_policy_lookup tiers tier express evidence_floor > "$d/first.out"
  printf 'tier\tdefault_reviewers\tevidence_floor\nexpress\tcritic\tsecond\n' > "$t"
  _gate_assurance_policy_lookup tiers tier express evidence_floor > "$d/second.out"
  got="$(<"$d/first.out")/$(<"$d/second.out")"
  [[ "$got" == "first/second" ]] || bad+=" rewritten-table(got $got)"
  # Installed copy-mode has no table file: the bundled snapshot answers the same.
  PR_GATE_POLICY_DIR="$saved_dir"
  exp="$(_oracle_awk_lookup "$saved_dir/gate-tiers.tsv" tier full default_reviewers)"
  got="$(PR_GATE_INSTALLED_COPY_ROOT=/nonexistent _gate_assurance_policy_lookup tiers tier full default_reviewers)"
  [[ -n "$exp" && "$exp" == "$got" ]] || bad+=" snapshot(old=$exp new=$got)"
  # Alternating the two sources in one shell answers from each source in turn.
  printf 'tier\tdefault_reviewers\tevidence_floor\nfull\tcritic\tf\n' > "$t"
  PR_GATE_POLICY_DIR="$d"
  _gate_assurance_policy_lookup tiers tier full default_reviewers > "$d/a.out"
  PR_GATE_INSTALLED_COPY_ROOT=/nonexistent _gate_assurance_policy_lookup tiers tier full default_reviewers > "$d/b.out"
  PR_GATE_INSTALLED_COPY_ROOT=/nonexistent _gate_assurance_policy_lookup tiers tier full default_reviewers > "$d/c.out"
  _gate_assurance_policy_lookup tiers tier full default_reviewers > "$d/d.out"
  PR_GATE_POLICY_DIR="$saved_dir"
  [[ "$(<"$d/a.out")/$(<"$d/b.out")/$(<"$d/c.out")/$(<"$d/d.out")" == "critic/$exp/$exp/critic" ]] \
    || bad+=" alternating-sources"
  if [[ -z "$bad" ]]; then
    pass "$name"
  else
    fail "$name" "mismatch:$bad"
  fi
}

case_json_array_helpers_answer_as_jq_did() {
  # Behavior: turning a word list or a newline list into a JSON array gives the
  # bytes the jq programs gave, for plain input (no process needed) and for every
  # input that needs escaping or re-encoding (still jq's).
  # Steps: feed both implementations words and lines that differ in blank runs,
  # tabs, embedded newlines, quotes, backslashes, CRLF, non-ASCII, a byte that is
  # not UTF-8, glob characters and a leading dash; compare the output.
  local name="policy: JSON array helpers answer as the jq programs did"
  should_run "$name" || return 0
  local w l exp got bad=""
  local -a words=( "" "   " "critic" "critic qa-tester" "  a   b  " $'a\tb' $'a\nb c' 'a"b' 'a\b'
    $'a b\r' "é x" $'bad\xff byte' 'x[y]* ?' '-n -e' "a/b.sh c d" )
  local -a lines=( "" $'\n' $'a\n' $'a\nb\n' $'a\n\nb' $'  \n' 'a"b' 'a\b' $'a\tb' $'a\r\nb'
    "é/ü.sh" $'bad\xff.sh' 'no/newline' 'dir with space/f.txt' '*.sh' '-n' $'a\n-e\nb' )
  for w in "${words[@]}"; do
    exp="$(jq -nc --arg words "$w" '$words | split(" ") | map(select(length > 0))')"
    got="$(_gate_policy_words_json "$w")"
    [[ "$exp" == "$got" ]] || bad+=" words[$(printf '%q' "$w")](old=$exp new=$got)"
  done
  for l in "${lines[@]}"; do
    exp="$(printf '%s\n' "$l" | jq -Rsc 'split("\n") | map(select(length > 0))')"
    got="$(printf '%s\n' "$l" | _gate_policy_lines_json)"
    [[ "$exp" == "$got" ]] || bad+=" lines[$(printf '%q' "$l")](old=$exp new=$got)"
  done
  if [[ -z "$bad" ]]; then
    pass "$name"
  else
    fail "$name" "mismatch:$bad"
  fi
}

case_validate_sources_rejects_bad_tier_and_mode_rows
case_table_reads_answer_as_the_awk_programs_did
case_json_array_helpers_answer_as_jq_did
case_header_marks_generated_matches_head_grep
case_resolver_fails_closed_on_malformed_classifications
case_resolver_rejects_unreadable_input_without_aborting
case_resolver_path_lines_keep_grep_semantics
case_resolver_keeps_a_matches_list_over_the_windows_command_line
case_resolver_unmatched_signal_cost
th_summary
