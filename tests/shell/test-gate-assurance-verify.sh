#!/usr/bin/env bash
# Regression tests for gate_assurance_verify (CC-533).
#
# CC-533 removed the handwritten only_keys/type/enum/pattern/const duplication
# from gate_assurance_verify's current (v2/v3) branch, since
# core/schema/gate-assurance.schema.json + gate_structural_schema_verify
# already prove all of that. What's left is same-document cross-field
# consistency (plain JSON Schema cannot express "field A must equal field B")
# and comparisons against context outside the assurance document itself
# (the result markdown's frontmatter/body, a freshly computed file digest).
#
# These tests are the differential safety net for that removal: every
# violation type the deleted lines used to catch must still be caught --
# either by gate_structural_schema_verify (for the truly structural ones) or
# by the trimmed handwritten check (for the cross-field/external ones).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/gate-digest.sh
. "$REPO_ROOT/runtime/lib/gate-digest.sh"
# shellcheck source=runtime/lib/identifier-policy.sh
. "$REPO_ROOT/runtime/lib/identifier-policy.sh"
# shellcheck source=runtime/lib/gate-structural-verify.sh
. "$REPO_ROOT/runtime/lib/gate-structural-verify.sh"
# shellcheck source=runtime/lib/gate-result-verify.sh
. "$REPO_ROOT/runtime/lib/gate-result-verify.sh"
# _gate_assurance_v3_valid_instance / _gate_assurance_valid_instance: the same
# canonical fixture test-core-schemas.sh uses for schema-shape validation.
# Reused here (not re-hand-rolled) so there is exactly one "what does a valid
# assurance document look like" definition to keep in sync with the schema.
# shellcheck source=tests/lib/gate-assurance-fixtures.sh
. "$SCRIPT_DIR/../lib/gate-assurance-fixtures.sh"

_write_result_md() {
  local path="$1" tier="${2:-standard}" mode="${3:-sequential}" final="${4:-GO}"
  cat > "$path" <<EOF
---
tier: $tier
mode: $mode
---
Final: $final
EOF
}

# Builds a result.md + matching v3 assurance.json pair. $2 (optional) is a jq
# filter applied to the canonical valid v3 fixture before result_sha256 is
# patched in, so each negative case tampers exactly one field.
#
# The shared fixture's evidence.preflight is "linked" to an artifact file
# that gate_assurance_verify's _gate_assurance_linked_evidence_verify checks
# actually exists on disk (with a matching sha256) -- irrelevant to what
# these tests exercise, so it's downgraded to "not_run" here to avoid every
# case needing a real preflight-evidence fixture file.
_mk_valid_pair() {
  local dir="$1" filter="${2:-.}"
  local result="$dir/result.md" assurance
  assurance="$result.assurance.json"
  mkdir -p "$dir"
  _write_result_md "$result"
  local sha
  sha="$(_gate_result_sha256_file "$result")"
  _gate_assurance_v3_valid_instance \
    | jq -c '.evidence.preflight = {status:"not_run",outcome:null,artifact:null,sha256:null,subject_fingerprint:null}' \
    | jq -c "$filter" \
    | jq -c --arg sha "$sha" '.bindings.result_sha256 = $sha' > "$assurance"
  printf '%s\t%s\n' "$result" "$assurance"
}

_read_pair() {
  IFS=$'\t' read -r RESULT ASSURANCE <<< "$1"
}

case_valid_v3_passes() {
  local name="gate_assurance_verify: schema-valid, cross-field-consistent v3 document passes"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/valid-v3")"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
}

case_valid_v2_passes() {
  local name="gate_assurance_verify: v2 (no subject/evidence) document passes"
  should_run "$name" || return 0
  local dir="$tmp_root/valid-v2" result assurance rc=0
  mkdir -p "$dir"
  result="$dir/result.md"
  assurance="$result.assurance.json"
  _write_result_md "$result"
  local sha
  sha="$(_gate_result_sha256_file "$result")"
  _gate_assurance_valid_instance | jq -c --arg sha "$sha" '.bindings.result_sha256 = $sha' > "$assurance"
  gate_assurance_verify "$result" "$assurance" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
}

case_v1_legacy_passes() {
  local name="gate_assurance_verify: legacy v1 claim-only document passes via extracted helper"
  should_run "$name" || return 0
  local dir="$tmp_root/valid-v1" result assurance rc=0
  mkdir -p "$dir"
  result="$dir/result.md"
  assurance="$result.assurance.json"
  _write_result_md "$result"
  jq -n '{kind:"gate_assurance_v1",schema_version:1,result:{final:"GO"},
    coordinates:{tier:{resolved:"standard"},mode:{resolved:"sequential"}}}' \
    > "$assurance"
  gate_assurance_verify "$result" "$assurance" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 && "${GATE_ASSURANCE_BOUND:-}" == false ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc GATE_ASSURANCE_BOUND=${GATE_ASSURANCE_BOUND:-unset}"
  fi
}

case_v1_legacy_claim_mismatch_rejected() {
  local name="gate_assurance_verify: legacy v1 with wrong Final is rejected"
  should_run "$name" || return 0
  local dir="$tmp_root/v1-mismatch" result assurance rc=0
  mkdir -p "$dir"
  result="$dir/result.md"
  assurance="$result.assurance.json"
  _write_result_md "$result"
  jq -n '{kind:"gate_assurance_v1",schema_version:1,result:{final:"NO-GO"},
    coordinates:{tier:{resolved:"standard"},mode:{resolved:"sequential"}}}' \
    > "$assurance"
  gate_assurance_verify "$result" "$assurance" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

# --- Structural violations: now caught by gate_structural_schema_verify,
# not the trimmed handwritten block. Proves removing the duplicate only_keys/
# enum/pattern checks did not weaken structural coverage. ---

case_missing_required_key_rejected() {
  local name="gate_assurance_verify: missing required top-level key is rejected (structural)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/missing-key" 'del(.provenance)')"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_additional_property_rejected() {
  local name="gate_assurance_verify: additional top-level property is rejected (structural)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/extra-key" '. + {unexpected_field: true}')"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_invalid_enum_rejected() {
  local name="gate_assurance_verify: invalid enum value is rejected (structural)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/bad-enum" '.coordinates.tier.resolved = "bogus-tier"')"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_invalid_pattern_rejected() {
  local name="gate_assurance_verify: malformed sha-shaped field is rejected (structural)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/bad-pattern" '.bindings.repo_identity = "not-a-sha256"')"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_subject_kind_dirty_policy_mismatch_rejected() {
  # Altitude review caught this as a residual duplication the first CC-533
  # pass missed: gate-assurance.schema.json's gateSubject definition already
  # encodes subject_kind<->dirty_policy via allOf/if/then, so this is
  # structural (gate_structural_schema_verify), not a surviving cross-field
  # handwritten check -- confirmed empirically before removing the duplicate.
  local name="gate_assurance_verify: subject_kind/dirty_policy mismatch is rejected (structural, schema allOf)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/dirty-policy-mismatch" '.subject.dirty_policy = "include_working_tree"')"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

# --- Cross-field / external violations: caught by the surviving handwritten
# checks, since plain JSON Schema cannot express these. Proves the trim kept
# what it must keep. ---

case_bindings_subject_repo_root_mismatch_rejected() {
  local name="gate_assurance_verify: bindings.repo_root != subject.observed.root is rejected (cross-field)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/repo-root-mismatch" \
    '.subject.observed.root = "/tmp/different-repo" | .subject.observed.git_common_dir = "/tmp/different-repo/.git"')"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_result_sha_mismatch_rejected() {
  local name="gate_assurance_verify: bindings.result_sha256 not matching the actual result file is rejected (external)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/sha-mismatch")"
  jq -c '.bindings.result_sha256 = ("9" * 64)' "$ASSURANCE" > "$ASSURANCE.tmp" && mv "$ASSURANCE.tmp" "$ASSURANCE"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_tier_mismatch_with_markdown_rejected() {
  local name="gate_assurance_verify: coordinates.tier.resolved not matching markdown frontmatter tier is rejected (external)"
  should_run "$name" || return 0
  local dir="$tmp_root/tier-mismatch" result assurance rc=0
  mkdir -p "$dir"
  result="$dir/result.md"
  assurance="$result.assurance.json"
  _write_result_md "$result" full sequential
  local sha
  sha="$(_gate_result_sha256_file "$result")"
  _gate_assurance_v3_valid_instance \
    | jq -c '.evidence.preflight = {status:"not_run",outcome:null,artifact:null,sha256:null,subject_fingerprint:null}' \
    | jq -c --arg sha "$sha" '.bindings.result_sha256 = $sha' > "$assurance"
  gate_assurance_verify "$result" "$assurance" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection, tier full vs standard)"; fi
}

case_dispatch_outcomes_shape_mismatch_rejected() {
  local name="gate_assurance_verify: sequential mode with 2 dispatch outcomes is rejected (data-dependent shape)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/outcomes-shape" \
    '.dispatch.outcomes += [{role:"combined",reviewer:null,status:"passed",run_id:null,evidence_status:"unavailable"}]')"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_reviewer_role_correlation_rejected() {
  local name="gate_assurance_verify: role=reviewer with null reviewer is rejected (cross-field)"
  should_run "$name" || return 0
  local RESULT ASSURANCE rc=0
  _read_pair "$(_mk_valid_pair "$tmp_root/reviewer-role" '.dispatch.outcomes[0].role = "reviewer"')"
  gate_assurance_verify "$RESULT" "$ASSURANCE" GO >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_valid_v3_passes
case_valid_v2_passes
case_v1_legacy_passes
case_v1_legacy_claim_mismatch_rejected
case_missing_required_key_rejected
case_additional_property_rejected
case_invalid_enum_rejected
case_invalid_pattern_rejected
case_subject_kind_dirty_policy_mismatch_rejected
case_bindings_subject_repo_root_mismatch_rejected
case_result_sha_mismatch_rejected
case_tier_mismatch_with_markdown_rejected
case_dispatch_outcomes_shape_mismatch_rejected
case_reviewer_role_correlation_rejected

th_summary
