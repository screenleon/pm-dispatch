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
# The Windows-hint cases set PM_DISPATCH_PLATFORM inside subshells on purpose.
# shellcheck disable=SC2030,SC2031
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

# Behavior: (CC-594) a content-digest mismatch on native Windows tells the user an
# artifact written before the jq line-ending fix fails the same way and the gate
# should be re-run; on Linux/macOS the message is unchanged (no hint).
# Steps: verify a manifest with a wrong digest with the platform forced to windows
# (PM_DISPATCH_PLATFORM, the repo's override) and to linux; compare the stderr.
case_digest_mismatch_hints_re_run_on_windows_only() {
  local name="gate_scope_manifest_verify: a digest mismatch hints at re-running the gate on Windows only"
  should_run "$name" || return 0
  local f win_err linux_err
  f="$tmp_root/digest-mismatch-hint.json"
  _gate_scope_manifest_valid_instance | jq -c '.content.digest = ("9" * 64)' > "$f"
  win_err="$( (export PM_DISPATCH_PLATFORM=windows; _verify_valid "$f") 2>&1 >/dev/null || true)"
  linux_err="$( (export PM_DISPATCH_PLATFORM=linux; _verify_valid "$f") 2>&1 >/dev/null || true)"
  if [[ "$win_err" == *"content digest mismatch"* && "$win_err" == *"re-run the gate"* ]]      && [[ "$linux_err" == *"content digest mismatch"* && "$linux_err" != *"re-run the gate"* ]]; then
    pass "$name"
  else
    fail "$name" "windows=[$win_err] linux=[$linux_err]"
  fi
}

# Behavior: (CC-594) a protected-attestation failure on Windows hints at re-running
# the gate only when the SUBJECT digest (the one computed over jq output) is what
# differs; a mismatch of another bound value (here the result sha) is not explained
# by the jq line-ending fix and must not be softened by the hint; on Linux there is
# never a hint.
# Steps: build a v3 assurance, a nonempty result and runs file, and attestations with
# (1) a wrong subject_sha256, (2) the right subject_sha256 but a wrong result_sha256;
# call gate_assurance_authorization_verify with the platform forced to windows and
# to linux and look for the hint on stderr.
case_attestation_mismatch_hint_is_limited_to_the_subject_digest() {
  local name="gate_assurance_authorization_verify: the Windows re-run hint appears only for a subject digest mismatch"
  should_run "$name" || return 0
  local d="$tmp_root/attestation-hint" subject_sha out_subject_win out_subject_linux out_other_win
  mkdir -p "$d"
  printf 'result
' > "$d/result.md"
  printf '{"kind":"gate_assurance_v3","subject":{"a":1},"bindings":{},"dispatch":{"outcomes":[]}}
' > "$d/assurance.json"
  printf '{"run":1}
' > "$d/runs.jsonl"
  subject_sha="$(jq -cS '.subject' "$d/assurance.json" | _gate_result_sha256_stream)"
  printf '{"kind":"gate_assurance_attestation_v2","schema_version":2,"subject_sha256":"%s"}
' "$(printf '0%.0s' $(seq 1 64))" > "$d/att-subject.json"
  printf '{"kind":"gate_assurance_attestation_v2","schema_version":2,"subject_sha256":"%s","result_sha256":"%s"}
' "$subject_sha" "$(printf '1%.0s' $(seq 1 64))" > "$d/att-other.json"
  out_subject_win="$( (export PM_DISPATCH_PLATFORM=windows; gate_assurance_authorization_verify "$d/result.md" "$d/assurance.json" "$d/att-subject.json" "$d/runs.jsonl") 2>&1 >/dev/null || true)"
  out_subject_linux="$( (export PM_DISPATCH_PLATFORM=linux; gate_assurance_authorization_verify "$d/result.md" "$d/assurance.json" "$d/att-subject.json" "$d/runs.jsonl") 2>&1 >/dev/null || true)"
  out_other_win="$( (export PM_DISPATCH_PLATFORM=windows; gate_assurance_authorization_verify "$d/result.md" "$d/assurance.json" "$d/att-other.json" "$d/runs.jsonl") 2>&1 >/dev/null || true)"
  if [[ "$out_subject_win" == *"protected attestation mismatch"* && "$out_subject_win" == *"re-run the gate"* ]]      && [[ "$out_subject_linux" == *"protected attestation mismatch"* && "$out_subject_linux" != *"re-run the gate"* ]]      && [[ "$out_other_win" == *"protected attestation mismatch"* && "$out_other_win" != *"re-run the gate"* ]]; then
    pass "$name"
  else
    fail "$name" "subject/windows=[$out_subject_win] subject/linux=[$out_subject_linux] other/windows=[$out_other_win]"
  fi
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
case_digest_mismatch_hints_re_run_on_windows_only
case_attestation_mismatch_hint_is_limited_to_the_subject_digest

th_summary
