#!/usr/bin/env bash
# Regression tests for runtime/lib/gate-protocol.sh — the protocol-attempt
# record writer and the sequential/synthesis single-retry outcome state
# machine extracted from pr-gate.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/gate-protocol.sh
. "$REPO_ROOT/runtime/lib/gate-protocol.sh"

# The lib reads these globals the same way pr-gate.sh sets them once during
# preflight.
SCOPE_MANIFEST_DIGEST="deadbeefdigest"
GATE_BINDING_SUBJECT_FINGERPRINT="cafef00dfingerprint"

gp_reset() {
  PROTOCOL_RECOVERY_PATH="$tmp_root/$1.jsonl"
  : > "$PROTOCOL_RECOVERY_PATH"
}

# ---------------------------------------------------------------------------
# gate_protocol_attempt_record
# ---------------------------------------------------------------------------

case_record_emits_full_v1_line() {
  local name="gate_protocol_attempt_record: appends a complete gate_protocol_attempt_v1 line"
  should_run "$name" || return 0
  gp_reset record-full
  gate_protocol_attempt_record sequential "" 1 retryable-failure "invalid reviewer protocol" /w/out.md
  local line; line="$(cat "$PROTOCOL_RECOVERY_PATH")"
  if [[ "$(jq -r '.kind' <<<"$line")" == gate_protocol_attempt_v1 ]] \
    && [[ "$(jq -r '.schema_version' <<<"$line")" == 1 ]] \
    && [[ "$(jq -r '.role' <<<"$line")" == sequential ]] \
    && [[ "$(jq -r '.reviewer' <<<"$line")" == null ]] \
    && [[ "$(jq -r '.attempt' <<<"$line")" == 1 ]] \
    && [[ "$(jq -r '.outcome' <<<"$line")" == retryable-failure ]] \
    && [[ "$(jq -r '.reason' <<<"$line")" == "invalid reviewer protocol" ]] \
    && [[ "$(jq -r '.artifact' <<<"$line")" == /w/out.md ]] \
    && [[ "$(jq -r '.scope_manifest_sha256' <<<"$line")" == deadbeefdigest ]] \
    && [[ "$(jq -r '.subject_fingerprint' <<<"$line")" == cafef00dfingerprint ]]; then
    pass "$name"
  else
    fail "$name" "line=$line"
  fi
}

case_record_named_reviewer_is_string_empty_is_null() {
  local name="gate_protocol_attempt_record: empty reviewer -> null, named reviewer -> string"
  should_run "$name" || return 0
  gp_reset record-reviewer
  gate_protocol_attempt_record reviewer "qa-tester" 2 exhausted "transport failure" /w/qa.md
  gate_protocol_attempt_record synthesis "" 1 accepted ok /w/syn.md
  if [[ "$(jq -rs '.[0].reviewer' "$PROTOCOL_RECOVERY_PATH")" == "qa-tester" ]] \
    && [[ "$(jq -rs '.[1].reviewer' "$PROTOCOL_RECOVERY_PATH")" == null ]] \
    && [[ "$(wc -l < "$PROTOCOL_RECOVERY_PATH")" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "$(cat "$PROTOCOL_RECOVERY_PATH")"
  fi
}

case_record_append_not_overwrite() {
  local name="gate_protocol_attempt_record: successive calls append"
  should_run "$name" || return 0
  gp_reset record-append
  gate_protocol_attempt_record sequential "" 1 retryable-failure a /w/1.md
  gate_protocol_attempt_record sequential "" 2 exhausted b /w/2.md
  if [[ "$(wc -l < "$PROTOCOL_RECOVERY_PATH")" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "$(cat "$PROTOCOL_RECOVERY_PATH")"
  fi
}

case_record_unwritable_path_returns_nonzero() {
  local name="gate_protocol_attempt_record: an unwritable recovery path returns non-zero"
  should_run "$name" || return 0
  PROTOCOL_RECOVERY_PATH="$tmp_root/no-such-dir/attempts.jsonl"
  local rc=0
  gate_protocol_attempt_record sequential "" 1 retryable-failure x /w/x.md 2>/dev/null || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
}

# ---------------------------------------------------------------------------
# gate_protocol_single_retry_outcome
# ---------------------------------------------------------------------------

case_outcome_complete_prints_break_records_accepted() {
  local name="gate_protocol_single_retry_outcome: complete=true -> break token + accepted record"
  should_run "$name" || return 0
  gp_reset outcome-break
  local tok rc=0
  tok="$(gate_protocol_single_retry_outcome sequential 1 true "" /w/out.md)" || rc=$?
  if [[ "$rc" -eq 0 && "$tok" == break ]] \
    && [[ "$(jq -r '.outcome' "$PROTOCOL_RECOVERY_PATH")" == accepted ]] \
    && [[ "$(jq -r '.reason' "$PROTOCOL_RECOVERY_PATH")" == ok ]] \
    && [[ "$(jq -r '.attempt' "$PROTOCOL_RECOVERY_PATH")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc tok=$tok rec=$(cat "$PROTOCOL_RECOVERY_PATH")"
  fi
}

case_outcome_stale_attempt1_aborts() {
  local name="gate_protocol_single_retry_outcome: stale subject at attempt 1 -> abort + stale record + stderr"
  should_run "$name" || return 0
  gp_reset outcome-stale1
  local tok err rc=0
  err="$tmp_root/stale1.err"
  tok="$(gate_protocol_single_retry_outcome sequential 1 false "stale subject binding" /w/out.md 2>"$err")" || rc=$?
  if [[ "$rc" -eq 0 && "$tok" == abort ]] \
    && [[ "$(jq -r '.outcome' "$PROTOCOL_RECOVERY_PATH")" == stale ]] \
    && grep -q 'sequential subject is stale; refusing protocol retry' "$err"; then
    pass "$name"
  else
    fail "$name" "rc=$rc tok=$tok err=$(<"$err") rec=$(cat "$PROTOCOL_RECOVERY_PATH")"
  fi
}

case_outcome_stale_attempt2_also_aborts() {
  local name="gate_protocol_single_retry_outcome: stale subject at attempt 2 -> abort (never retry)"
  should_run "$name" || return 0
  gp_reset outcome-stale2
  local tok rc=0
  tok="$(gate_protocol_single_retry_outcome synthesis 2 false "stale subject binding" /w/out.md 2>/dev/null)" || rc=$?
  if [[ "$rc" -eq 0 && "$tok" == abort ]] \
    && [[ "$(jq -r '.outcome' "$PROTOCOL_RECOVERY_PATH")" == stale ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc tok=$tok rec=$(cat "$PROTOCOL_RECOVERY_PATH")"
  fi
}

case_outcome_attempt1_retryable_prints_retry() {
  local name="gate_protocol_single_retry_outcome: attempt 1, non-stale failure -> retry token + retryable-failure record"
  should_run "$name" || return 0
  gp_reset outcome-retry
  local tok rc=0
  tok="$(gate_protocol_single_retry_outcome sequential 1 false "invalid reviewer protocol" /w/out.md)" || rc=$?
  if [[ "$rc" -eq 0 && "$tok" == retry ]] \
    && [[ "$(jq -r '.outcome' "$PROTOCOL_RECOVERY_PATH")" == retryable-failure ]] \
    && [[ "$(jq -r '.reason' "$PROTOCOL_RECOVERY_PATH")" == "invalid reviewer protocol" ]] \
    && [[ "$(jq -r '.attempt' "$PROTOCOL_RECOVERY_PATH")" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc tok=$tok rec=$(cat "$PROTOCOL_RECOVERY_PATH")"
  fi
}

case_outcome_attempt2_exhausted_aborts() {
  local name="gate_protocol_single_retry_outcome: attempt 2, non-stale failure -> abort + exhausted record + stderr"
  should_run "$name" || return 0
  gp_reset outcome-exhausted
  local tok err rc=0
  err="$tmp_root/exhausted.err"
  tok="$(gate_protocol_single_retry_outcome synthesis 2 false "synthesis parity failure" /w/out.md 2>"$err")" || rc=$?
  if [[ "$rc" -eq 0 && "$tok" == abort ]] \
    && [[ "$(jq -r '.outcome' "$PROTOCOL_RECOVERY_PATH")" == exhausted ]] \
    && [[ "$(jq -r '.attempt' "$PROTOCOL_RECOVERY_PATH")" == 2 ]] \
    && grep -q 'synthesis recovery exhausted after synthesis parity failure' "$err"; then
    pass "$name"
  else
    fail "$name" "rc=$rc tok=$tok err=$(<"$err") rec=$(cat "$PROTOCOL_RECOVERY_PATH")"
  fi
}

case_outcome_record_write_failure_returns_2_no_token() {
  local name="gate_protocol_single_retry_outcome: a failed record append returns 2 and prints no control token"
  should_run "$name" || return 0
  PROTOCOL_RECOVERY_PATH="$tmp_root/no-such-dir/attempts.jsonl"
  local tok rc=0
  tok="$(gate_protocol_single_retry_outcome sequential 1 true "" /w/out.md 2>/dev/null)" || rc=$?
  if [[ "$rc" -eq 2 && -z "$tok" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc tok=$tok"
  fi
}

case_outcome_role_is_parametrised() {
  local name="gate_protocol_single_retry_outcome: role appears in both the record and the stderr diagnostic"
  should_run "$name" || return 0
  gp_reset outcome-role
  local err="$tmp_root/role.err"
  gate_protocol_single_retry_outcome synthesis 2 false "boom" /w/out.md 2>"$err" >/dev/null || true
  if [[ "$(jq -r '.role' "$PROTOCOL_RECOVERY_PATH")" == synthesis ]] \
    && grep -q 'synthesis recovery exhausted' "$err" \
    && ! grep -q 'sequential' "$err"; then
    pass "$name"
  else
    fail "$name" "err=$(<"$err") rec=$(cat "$PROTOCOL_RECOVERY_PATH")"
  fi
}

case_outcome_matches_legacy_pr_gate_records() {
  local name="gate_protocol_single_retry_outcome: emitted records match the pre-refactor pr-gate.sh sequence"
  should_run "$name" || return 0
  # attempt 1 non-stale failure then attempt 2 exhausted -> exactly the two
  # records the old inline sequential branch wrote.
  gp_reset outcome-legacy
  gate_protocol_single_retry_outcome sequential 1 false "invalid reviewer protocol" /w/out.md >/dev/null
  gate_protocol_single_retry_outcome sequential 2 false "invalid reviewer protocol" /w/out.md 2>/dev/null >/dev/null
  local got
  got="$(jq -rs 'map([.role,.attempt,.outcome,.reason]|join("|"))|join(" ; ")' "$PROTOCOL_RECOVERY_PATH")"
  if [[ "$got" == "sequential|1|retryable-failure|invalid reviewer protocol ; sequential|2|exhausted|invalid reviewer protocol" ]]; then
    pass "$name"
  else
    fail "$name" "got=$got"
  fi
}

case_record_emits_full_v1_line
case_record_named_reviewer_is_string_empty_is_null
case_record_append_not_overwrite
case_record_unwritable_path_returns_nonzero
case_outcome_complete_prints_break_records_accepted
case_outcome_stale_attempt1_aborts
case_outcome_stale_attempt2_also_aborts
case_outcome_attempt1_retryable_prints_retry
case_outcome_attempt2_exhausted_aborts
case_outcome_record_write_failure_returns_2_no_token
case_outcome_role_is_parametrised
case_outcome_matches_legacy_pr_gate_records

th_summary
