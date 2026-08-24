#!/usr/bin/env bash
# Regression tests for gate_scope_manifest_verify (CC-533).
#
# CC-533 removed the handwritten only_keys/type/enum/pattern/const duplication
# (including several cross-field correlations -- subject_kind<->diff_kind,
# status<->truncation shape, per-status old_path/new_path/similarity shape --
# that core/schema/gate-scope-manifest.schema.json encodes via allOf/if/then,
# unlike gate-assurance.schema.json) from gate_scope_manifest_verify. What's
# left is either a same-document derivation this schema still cannot express
# (a set derived from OTHER array entries, e.g. changed_paths must equal the
# union of entries[].old_path/new_path) or a comparison against external
# context (the caller-supplied repository_key/commits/refs).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/gate-digest.sh
. "$REPO_ROOT/runtime/lib/gate-digest.sh"
# shellcheck source=runtime/lib/gate-structural-verify.sh
. "$REPO_ROOT/runtime/lib/gate-structural-verify.sh"
# shellcheck source=runtime/lib/gate-result-verify.sh
. "$REPO_ROOT/runtime/lib/gate-result-verify.sh"
# shellcheck source=tests/lib/gate-scope-manifest-fixtures.sh
. "$SCRIPT_DIR/../lib/gate-scope-manifest-fixtures.sh"

# Valid-instance external bindings, matching _gate_scope_manifest_valid_instance.
_VALID_REPOSITORY_KEY="$(printf 'a%.0s' $(seq 1 64))"
_VALID_BASE_COMMIT="$(printf 'b%.0s' $(seq 1 40))"
_VALID_HEAD_COMMIT="$(printf 'c%.0s' $(seq 1 40))"
_VALID_TREE_FINGERPRINT="$(printf 'd%.0s' $(seq 1 64))"
_VALID_SUBJECT_KIND="committed_head"
_VALID_BASE_REF="main"
_VALID_HEAD_REF="HEAD"

_verify_valid() {
  gate_scope_manifest_verify "$1" \
    "$_VALID_REPOSITORY_KEY" "$_VALID_BASE_COMMIT" "$_VALID_HEAD_COMMIT" \
    "$_VALID_TREE_FINGERPRINT" "$_VALID_SUBJECT_KIND" \
    "$_VALID_BASE_REF" "$_VALID_HEAD_REF"
}

# Builds a manifest file with a correct content.digest for whatever body the
# optional jq filter produces, so each negative case tampers exactly one field
# without also (accidentally) tripping the separate digest-mismatch check.
_mk_manifest() {
  local path="$1" filter="${2:-.}"
  local body
  body="$(_gate_scope_manifest_valid_instance | jq -c "$filter")"
  local digest
  digest="$(printf '%s' "$body" | jq -cS 'del(.content.digest)' | _gate_result_sha256_stream)"
  printf '%s' "$body" | jq -c --arg d "$digest" '.content.digest = $d' > "$path"
}

case_valid_instance_passes() {
  local name="gate_scope_manifest_verify: schema-valid, cross-field-consistent instance passes"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/valid.json"
  _mk_manifest "$f"
  _verify_valid "$f" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
}

case_missing_required_key_rejected() {
  local name="gate_scope_manifest_verify: missing required top-level key is rejected (structural)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/missing-key.json"
  _mk_manifest "$f" 'del(.provenance) | del(.flags)'
  _verify_valid "$f" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_invalid_enum_rejected() {
  local name="gate_scope_manifest_verify: invalid status enum is rejected (structural)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/bad-enum.json"
  _mk_manifest "$f" '.status = "bogus-status"'
  _verify_valid "$f" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_change_entry_status_shape_rejected() {
  local name="gate_scope_manifest_verify: renamed entry missing similarity is rejected (structural, schema allOf)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/entry-shape.json"
  _mk_manifest "$f" '.changes.entries[0].status = "renamed" | .changes.entries[0].old_path = "runtime/bin/example.sh"'
  _verify_valid "$f" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_repository_key_mismatch_rejected() {
  local name="gate_scope_manifest_verify: repository_key arg mismatch is rejected (external)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/repo-key-mismatch.json"
  _mk_manifest "$f"
  gate_scope_manifest_verify "$f" "$(printf 'z%.0s' $(seq 1 64))" \
    "$_VALID_BASE_COMMIT" "$_VALID_HEAD_COMMIT" "$_VALID_TREE_FINGERPRINT" \
    "$_VALID_SUBJECT_KIND" "$_VALID_BASE_REF" "$_VALID_HEAD_REF" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_base_ref_mismatch_rejected() {
  local name="gate_scope_manifest_verify: base_ref arg mismatch is rejected (external)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/base-ref-mismatch.json"
  _mk_manifest "$f"
  gate_scope_manifest_verify "$f" \
    "$_VALID_REPOSITORY_KEY" "$_VALID_BASE_COMMIT" "$_VALID_HEAD_COMMIT" \
    "$_VALID_TREE_FINGERPRINT" "$_VALID_SUBJECT_KIND" \
    "not-main" "$_VALID_HEAD_REF" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_changed_paths_derivation_mismatch_rejected() {
  local name="gate_scope_manifest_verify: changed_paths not matching entries[] is rejected (cross-field derivation)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/changed-paths-mismatch.json"
  _mk_manifest "$f" '.changes.changed_paths += ["some/other/file.sh"]'
  _verify_valid "$f" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_hunk_path_outside_changed_set_rejected() {
  local name="gate_scope_manifest_verify: diff hunk path outside changed_paths is rejected (cross-field, external-set membership)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/hunk-outside.json"
  _mk_manifest "$f" '.diff.hunks[0].path = "not/a/changed/path.sh"'
  _verify_valid "$f" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_truncation_omitted_occurred_mismatch_rejected() {
  local name="gate_scope_manifest_verify: omitted count > 0 without occurred=true is rejected (cross-field derivation)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/truncation-mismatch.json"
  _mk_manifest "$f" '.truncation.omitted.diff_hunks = 3'
  _verify_valid "$f" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_digest_mismatch_rejected() {
  local name="gate_scope_manifest_verify: content.digest not matching the actual body is rejected (external, pre-jq check)"
  should_run "$name" || return 0
  local f rc=0
  f="$tmp_root/digest-mismatch.json"
  _gate_scope_manifest_valid_instance | jq -c '.content.digest = ("9" * 64)' > "$f"
  _verify_valid "$f" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected rejection)"; fi
}

case_valid_instance_passes
case_missing_required_key_rejected
case_invalid_enum_rejected
case_change_entry_status_shape_rejected
case_repository_key_mismatch_rejected
case_base_ref_mismatch_rejected
case_changed_paths_derivation_mismatch_rejected
case_hunk_path_outside_changed_set_rejected
case_truncation_omitted_occurred_mismatch_rejected
case_digest_mismatch_rejected

th_summary
