#!/usr/bin/env bash
# Regression tests for runtime/lib/gate-structural-verify.sh and its
# gate-structural-validator.jq interpreter (CC-533 continuation).
#
# Covers the generic-interpreter enhancements added to make
# gate_structural_schema_first_error a viable single-authority replacement
# for a handwritten verifier's own "X is not one of A/B/C" diagnostic
# messages: issue objects now carry the observed value, and the new
# gate_structural_schema_first_error helper formats the first violation as a
# single line (used by reviewer-result/synthesis-result once those are
# migrated). Also covers the new gate-reviewer-result.schema.json rule
# (verdict approve/advise forbids a blocking finding) added in the same
# slice. This is not a live runtime bug fix -- gate-result-verify.sh's
# handwritten verdict_contract already enforces the rule today -- it closes
# a schema self-sufficiency gap the later reviewer-result rewrite needs
# before it can drop that handwritten check in favor of
# gate_structural_schema_first_error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/gate-structural-verify.sh
. "$REPO_ROOT/runtime/lib/gate-structural-verify.sh"
# shellcheck source=tests/lib/gate-scope-manifest-fixtures.sh
. "$SCRIPT_DIR/../lib/gate-scope-manifest-fixtures.sh"
# shellcheck source=tests/lib/gate-reviewer-result-fixtures.sh
. "$SCRIPT_DIR/../lib/gate-reviewer-result-fixtures.sh"

case_verify_valid_instance_passes() {
  local name="gate_structural_schema_verify: valid instance passes with no stderr"
  should_run "$name" || return 0
  local tmpf out err rc=0
  tmpf="$tmp_root/valid.json"
  _gate_scope_manifest_valid_instance > "$tmpf"
  out="$tmp_root/valid.out"
  err="$tmp_root/valid.err"
  gate_structural_schema_verify gate-scope-manifest "$tmpf" "test" > "$out" 2> "$err" || rc=$?
  if [[ "$rc" -eq 0 && ! -s "$err" ]]; then pass "$name"; else fail "$name" "rc=$rc err=$(<"$err")"; fi
}

case_verify_invalid_instance_reports_path_and_message() {
  local name="gate_structural_schema_verify: invalid instance reports path and message on stderr"
  should_run "$name" || return 0
  local tmpf out err rc=0
  tmpf="$tmp_root/invalid.json"
  _gate_scope_manifest_valid_instance | jq -c '.status = "bogus"' > "$tmpf"
  out="$tmp_root/invalid.out"
  err="$tmp_root/invalid.err"
  gate_structural_schema_verify gate-scope-manifest "$tmpf" "test" > "$out" 2> "$err" || rc=$?
  if [[ "$rc" -eq 1 ]] && grep -Fq '$.status' "$err" && grep -Fq 'outside enum' "$err"; then
    pass "$name"
  else
    fail "$name" "rc=$rc err=$(<"$err")"
  fi
}

case_first_error_valid_instance_no_output() {
  local name="gate_structural_schema_first_error: valid instance exits 0 with no output"
  should_run "$name" || return 0
  local tmpf out rc=0
  tmpf="$tmp_root/valid2.json"
  _gate_scope_manifest_valid_instance > "$tmpf"
  out="$tmp_root/valid2.out"
  gate_structural_schema_first_error gate-scope-manifest "$tmpf" > "$out" 2>/dev/null || rc=$?
  if [[ "$rc" -eq 0 && ! -s "$out" ]]; then pass "$name"; else fail "$name" "rc=$rc out=$(<"$out")"; fi
}

case_first_error_includes_path_message_and_value() {
  local name="gate_structural_schema_first_error: invalid enum includes path, message, and observed value"
  should_run "$name" || return 0
  local tmpf out rc=0
  tmpf="$tmp_root/bad-enum.json"
  _gate_scope_manifest_valid_instance | jq -c '.status = "bogus-status"' > "$tmpf"
  out="$tmp_root/bad-enum.out"
  gate_structural_schema_first_error gate-scope-manifest "$tmpf" > "$out" 2>/dev/null || rc=$?
  if [[ "$rc" -eq 1 ]] \
     && grep -Fq '$.status' "$out" \
     && grep -Fq 'outside enum' "$out" \
     && grep -Fq 'bogus-status' "$out"; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$(<"$out")"
  fi
}

case_first_error_missing_required_omits_value_suffix() {
  local name="gate_structural_schema_first_error: missing required property has no (got: ...) suffix"
  should_run "$name" || return 0
  local tmpf out rc=0
  tmpf="$tmp_root/missing-key.json"
  _gate_scope_manifest_valid_instance | jq -c 'del(.content)' > "$tmpf"
  out="$tmp_root/missing-key.out"
  gate_structural_schema_first_error gate-scope-manifest "$tmpf" > "$out" 2>/dev/null || rc=$?
  if [[ "$rc" -eq 1 ]] \
     && grep -Fq 'required property is missing' "$out" \
     && ! grep -Fq '(got:' "$out"; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$(<"$out")"
  fi
}

# assert_execution_failure <case-name> <rc> <stdout-file> <stderr-file> [needle...]
#
# Every entry point owes callers the same classification when validation could
# not run: a non-zero status, a diagnostic, and -- the part that is easy to
# lose -- no trace of a *validation verdict*. An execution failure reported as
# "this instance violates the schema" blames a caller's valid input, and one
# reported as a clean pass hides the failure entirely.
#
# This is a helper rather than five hand-copied assertion blocks because the
# hand-copied version already drifted once: the JSON-wrapper case checked only
# the status and was caught in review. Naming the contract makes leaving a
# clause out structurally impossible instead of a thing to remember.
assert_execution_failure() {
  local name="$1" rc="$2" out="$3" err="$4"
  shift 4
  local needle
  if [[ "$rc" -eq 0 ]]; then
    fail "$name" "expected a non-zero status, got 0 :: err=$(<"$err")"
    return 1
  fi
  if [[ -s "$out" ]]; then
    fail "$name" "execution failure wrote stdout a caller could read as a verdict: $(<"$out")"
    return 1
  fi
  for needle in 'failed schema-derived structural validation' 'invalid schema node'; do
    if grep -Fq "$needle" "$err"; then
      fail "$name" "execution failure was reported as a validation verdict ($needle) :: $(<"$err")"
      return 1
    fi
  done
  for needle in "$@"; do
    if ! grep -Fq "$needle" "$err"; then
      fail "$name" "expected diagnostic '$needle', got: $(<"$err")"
      return 1
    fi
  done
  pass "$name"
}

case_first_error_unknown_schema_name_exits_2() {
  local name="gate_structural_schema_first_error: unknown schema name exits 2"
  should_run "$name" || return 0
  local tmpf out err rc=0
  tmpf="$tmp_root/whatever.json"
  out="$tmp_root/unknown-first.out"
  err="$tmp_root/unknown-first.err"
  _gate_scope_manifest_valid_instance > "$tmpf"
  gate_structural_schema_first_error no-such-schema "$tmpf" >"$out" 2>"$err" || rc=$?
  # 2 is "could not execute"; 1 would claim a violation was found and printed.
  [[ "$rc" -eq 2 ]] || { fail "$name" "expected rc=2, got $rc"; return; }
  assert_execution_failure "$name" "$rc" "$out" "$err" 'unknown schema: no-such-schema'
}

case_verify_unknown_schema_name_is_execution_failure() {
  local name="gate_structural_schema_verify: unknown schema name is an execution failure"
  should_run "$name" || return 0
  local tmpf out err rc=0
  tmpf="$tmp_root/unknown-verify.json"
  out="$tmp_root/unknown-verify.out"
  err="$tmp_root/unknown-verify.err"
  _gate_scope_manifest_valid_instance > "$tmpf"
  gate_structural_schema_verify no-such-schema "$tmpf" >"$out" 2>"$err" || rc=$?
  assert_execution_failure "$name" "$rc" "$out" "$err" \
    'unknown schema: no-such-schema' 'could not execute'
}

case_verify_json_unknown_schema_name_is_execution_failure() {
  local name="gate_structural_schema_verify_json: unknown schema name is an execution failure"
  should_run "$name" || return 0
  local out err rc=0
  out="$tmp_root/unknown-json.out"
  err="$tmp_root/unknown-json.err"
  gate_structural_schema_verify_json no-such-schema '{"a":1}' >"$out" 2>"$err" || rc=$?
  assert_execution_failure "$name" "$rc" "$out" "$err" \
    'unknown schema: no-such-schema' 'could not execute'
}

case_unreadable_instance_is_execution_failure_not_a_verdict() {
  local name="gate_structural_schema_verify: a jq failure other than unknown-schema is an execution failure"
  should_run "$name" || return 0
  local tmpf out err rc=0
  tmpf="$tmp_root/malformed-instance.json"
  out="$tmp_root/malformed.out"
  err="$tmp_root/malformed.err"
  # Non-empty so the argument guard passes, but not parseable, so jq fails with
  # a status that is not the interpreter's unknown-schema signal. That branch
  # must land in the same classification as every other execution failure.
  printf '{oops\n' > "$tmpf"
  gate_structural_schema_verify gate-scope-manifest "$tmpf" >"$out" 2>"$err" || rc=$?
  assert_execution_failure "$name" "$rc" "$out" "$err" 'could not execute'
  grep -Fq 'unknown schema' "$err" \
    && fail "$name" "a malformed instance was misreported as an unknown schema"
  return 0
}

case_malformed_instance_first_error_reports_execution_failure() {
  local name="gate_structural_schema_first_error: a jq failure other than unknown-schema exits 2"
  should_run "$name" || return 0
  local tmpf out err rc=0
  tmpf="$tmp_root/malformed-first.json"
  out="$tmp_root/malformed-first.out"
  err="$tmp_root/malformed-first.err"
  printf '{oops\n' > "$tmpf"
  gate_structural_schema_first_error gate-scope-manifest "$tmpf" >"$out" 2>"$err" || rc=$?
  [[ "$rc" -eq 2 ]] || { fail "$name" "expected rc=2, got $rc"; return; }
  assert_execution_failure "$name" "$rc" "$out" "$err"
}

case_schema_validation_spawns_one_jq_per_call() {
  local name="schema validation spawns exactly one jq per validation"
  should_run "$name" || return 0
  local shimdir tally tmpf real_jq count rc=0
  real_jq="$(type -P jq)"
  shimdir="$tmp_root/jqcount-shim"
  tally="$tmp_root/jqcount.tally"
  mkdir -p "$shimdir"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf 'printf x >> %q\n' "$tally"
    printf 'exec %q "$@"\n' "$real_jq"
  } > "$shimdir/jq"
  chmod +x "$shimdir/jq"
  tmpf="$tmp_root/onepass.json"
  _gate_scope_manifest_valid_instance > "$tmpf"
  : > "$tally"
  # Five validations of a valid instance: the issue-printing jq only runs when
  # there are issues, so a clean run should be one process each. This locks the
  # CC-579 collapse -- a reinstated `has($name)` probe, or any other per-call
  # helper process, doubles the count while the output stays identical.
  local remaining=5
  while (( remaining-- > 0 )); do
    PATH="$shimdir:$PATH" gate_structural_schema_verify gate-scope-manifest "$tmpf" \
      >/dev/null 2>&1 || rc=$?
  done
  count="$(wc -c < "$tally" | tr -d ' ')"
  if [[ "$rc" -eq 0 && "$count" -eq 5 ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc expected 5 jq invocations, got $count"
  fi
}

# --- gate-reviewer-result.schema.json: verdict/findings correlation ---
# Built on the SHARED canonical fixture (not a second hand-rolled instance)
# via targeted jq overrides, mirroring how test-core-schemas.sh's other
# reviewer-result cases already vary one field at a time off the same base.

case_verdict_approve_with_no_blocking_findings_passes() {
  local name="gate-reviewer-result schema: verdict=approve with no findings passes"
  should_run "$name" || return 0
  local tmpf rc=0
  tmpf="$tmp_root/approve-clean.json"
  _gate_reviewer_result_valid_instance \
    | jq -c '.verdict = "approve" | .findings = []' > "$tmpf"
  gate_structural_schema_verify gate-reviewer-result "$tmpf" "test" >/dev/null 2>/dev/null || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
}

case_verdict_approve_with_hard_block_finding_rejected() {
  # NOT a live regression fix: runtime/lib/gate-result-verify.sh's
  # verdict_contract already enforces this today via its else-branch
  # (`all(.findings[]; .hard_gate_class == "none")` for approve/advise). This
  # schema addition makes the SCHEMA self-sufficient for the same rule, which
  # the later reviewer-result rewrite needs before it can delete the
  # handwritten check and rely on gate_structural_schema_first_error instead.
  local name="gate-reviewer-result schema: verdict=approve with a hard_block finding is rejected"
  should_run "$name" || return 0
  local tmpf rc=0
  tmpf="$tmp_root/approve-hard-block.json"
  _gate_reviewer_result_valid_instance \
    | jq -c '.verdict = "approve" | .findings[0].hard_gate_class = "hard_block"' > "$tmpf"
  gate_structural_schema_verify gate-reviewer-result "$tmpf" "test" >/dev/null 2>/dev/null || rc=$?
  if [[ "$rc" -eq 1 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_verdict_advise_with_soft_block_finding_rejected() {
  local name="gate-reviewer-result schema: verdict=advise with a soft_block finding is rejected"
  should_run "$name" || return 0
  local tmpf rc=0
  tmpf="$tmp_root/advise-soft-block.json"
  _gate_reviewer_result_valid_instance | jq -c '.verdict = "advise"' > "$tmpf"
  gate_structural_schema_verify gate-reviewer-result "$tmpf" "test" >/dev/null 2>/dev/null || rc=$?
  if [[ "$rc" -eq 1 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_verdict_block_with_hard_block_finding_still_passes() {
  local name="gate-reviewer-result schema: verdict=block with a hard_block finding still passes (no regression)"
  should_run "$name" || return 0
  local tmpf rc=0
  tmpf="$tmp_root/block-hard-block.json"
  _gate_reviewer_result_valid_instance \
    | jq -c '.verdict = "block" | .findings[0].hard_gate_class = "hard_block"' > "$tmpf"
  gate_structural_schema_verify gate-reviewer-result "$tmpf" "test" >/dev/null 2>/dev/null || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
}

case_verify_valid_instance_passes
case_verify_invalid_instance_reports_path_and_message
case_first_error_valid_instance_no_output
case_first_error_includes_path_message_and_value
case_first_error_missing_required_omits_value_suffix
case_first_error_unknown_schema_name_exits_2
case_verify_unknown_schema_name_is_execution_failure
case_verify_json_unknown_schema_name_is_execution_failure
case_unreadable_instance_is_execution_failure_not_a_verdict
case_malformed_instance_first_error_reports_execution_failure
case_schema_validation_spawns_one_jq_per_call
case_verdict_approve_with_no_blocking_findings_passes
case_verdict_approve_with_hard_block_finding_rejected
case_verdict_advise_with_soft_block_finding_rejected
case_verdict_block_with_hard_block_finding_still_passes

th_summary
