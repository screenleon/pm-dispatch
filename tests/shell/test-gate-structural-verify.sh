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

case_first_error_unknown_schema_name_exits_2() {
  local name="gate_structural_schema_first_error: unknown schema name exits 2"
  should_run "$name" || return 0
  local tmpf rc=0
  tmpf="$tmp_root/whatever.json"
  _gate_scope_manifest_valid_instance > "$tmpf"
  gate_structural_schema_first_error no-such-schema "$tmpf" >/dev/null 2>/dev/null || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
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
case_verdict_approve_with_no_blocking_findings_passes
case_verdict_approve_with_hard_block_finding_rejected
case_verdict_advise_with_soft_block_finding_rejected
case_verdict_block_with_hard_block_finding_still_passes

th_summary
