#!/usr/bin/env bash
# gate-protocol.sh — protocol-attempt recording and the single-retry outcome
# state machine shared by pr-gate.sh's sequential and synthesis authoring
# loops. Both loops used to open-code the same four-way decision
# (complete / stale / retryable-failure / exhausted); it now lives here so a
# change to that taxonomy is one edit, not two near-identical inline branches.
#
# Sourcing this file only defines functions. It does not run the protocol
# *verification* helpers (gate_reviewer_protocol_verify,
# gate_verify_synthesis_protocol, ...) — those stay in gate-result-verify.sh
# and remain the caller's job. This module only records the attempt and maps
# the caller's already-computed (complete, reason) pair to a control action.
#
# The parallel-reviewer batch-retry branch in pr-gate.sh keeps its own
# orchestration (per-reviewer re-dispatch, watchdog, fold-back of recovered
# reviewers), but its retryable-reason taxonomy lives here — see
# GATE_PROTOCOL_RETRYABLE_REASONS / gate_protocol_reason_retryable — so the
# question "which reviewer-protocol failures may be retried once" has a single
# home rather than an inline array in the orchestrator.
#
# Note the two retry taxonomies are intentionally distinct, not merged:
# gate_protocol_single_retry_outcome (sequential/synthesis) retries *any*
# non-stale reason once; the parallel branch retries only the transport-shaped
# and machine-contract reasons on the allowlist below.
#
# Required globals (set once during preflight, long before the first retry
# loop runs): SCOPE_MANIFEST_DIGEST, GATE_BINDING_SUBJECT_FINGERPRINT,
# PROTOCOL_RECOVERY_PATH.

# CC-521/CC-545: the reviewer-protocol failures the parallel-reviewer branch
# may retry exactly once with a corrective note. Everything not listed here —
# stale subject binding, analysis uncertainty — is either unrepairable by
# re-authoring or is valid review evidence synthesis must preserve, so it
# stops as INCOMPLETE without a retry.
GATE_PROTOCOL_RETRYABLE_REASONS=(
  "invalid evidence reference contract"
  "transport failure"
  "invalid JSON document"
  "reviewer protocol filter failed"
  "malformed reviewer result fence"
  "truncated reviewer result"
  "missing reviewer result"
  "invalid reviewer binding"
  "missing selected reviewer"
  "invalid top-level or binding contract"
  "invalid coverage contract"
  "invalid finding contract"
  "invalid test-gap matrix contract"
  "finding lacks actionable test-gap row"
  "invalid verdict contract"
)

# gate_protocol_reason_retryable <reason>
#   Exit 0 if <reason> is retryable, 1 otherwise. Matches the reason STEM: the
#   verifier appends ": <detail>" to several reasons so a reviewer learns which
#   row and constraint it broke, and exact equality would silently declassify
#   every such detailed reason as non-retryable — turning the most correctable
#   failures into immediate INCOMPLETE. The colon makes the prefix unambiguous,
#   so no unrelated reason can match by accident.
gate_protocol_reason_retryable() {
  local reason="$1" entry
  for entry in "${GATE_PROTOCOL_RETRYABLE_REASONS[@]}"; do
    [[ "$reason" == "$entry" || "$reason" == "$entry:"* ]] && return 0
  done
  return 1
}

# gate_protocol_attempt_record <role> <reviewer> <attempt> <outcome> <reason> <artifact>
#   Append one gate_protocol_attempt_v1 JSON line to $PROTOCOL_RECOVERY_PATH.
#   An empty <reviewer> is recorded as JSON null. Returns non-zero only if the
#   append itself fails.
gate_protocol_attempt_record() {
  local role="$1" reviewer="$2" attempt="$3" outcome="$4" reason="$5" artifact="$6"
  jq -nc \
    --arg role "$role" --arg reviewer "$reviewer" --argjson attempt "$attempt" \
    --arg outcome "$outcome" --arg reason "$reason" --arg artifact "$artifact" \
    --arg scope_sha "$SCOPE_MANIFEST_DIGEST" \
    --arg subject_fingerprint "$GATE_BINDING_SUBJECT_FINGERPRINT" '{
      kind:"gate_protocol_attempt_v1",schema_version:1,
      role:$role,
      reviewer:(if $reviewer == "" then null else $reviewer end),
      attempt:$attempt,outcome:$outcome,reason:$reason,artifact:$artifact,
      scope_manifest_sha256:$scope_sha,
      subject_fingerprint:$subject_fingerprint
    }' >> "$PROTOCOL_RECOVERY_PATH"
}

# gate_protocol_single_retry_outcome <role> <attempt> <complete> <reason> <artifact>
#   Records the attempt and prints exactly one control token on stdout:
#     break  — the round completed; caller should break its retry loop
#     retry  — attempt 1 failed on a recoverable reason; caller should loop
#     abort  — stale subject, or attempt 2 exhausted; caller should exit 1
#   Emits the role-parametrised "stale" / "exhausted" diagnostics on stderr
#   itself. Does NOT emit the "retrying once after ..." note — the caller owns
#   that (sequential prints it at the top of iteration 2; synthesis prints it
#   on the `retry` token).
#   Returns 2 if a gate_protocol_attempt_record append fails (caller: || exit 2).
gate_protocol_single_retry_outcome() {
  local role="$1" attempt="$2" complete="$3" reason="$4" artifact="$5"

  if [[ "$complete" == true ]]; then
    gate_protocol_attempt_record "$role" "" "$attempt" accepted ok "$artifact" || return 2
    printf 'break\n'
    return 0
  fi

  # A stale subject cannot be repaired by re-authoring: the evidence no longer
  # describes this tree, so retrying would only produce a second stale result.
  if [[ "$reason" == "stale subject binding" ]]; then
    gate_protocol_attempt_record "$role" "" "$attempt" stale "$reason" "$artifact" || return 2
    printf 'Error: %s subject is stale; refusing protocol retry\n' "$role" >&2
    printf 'abort\n'
    return 0
  fi

  if [[ "$attempt" -eq 1 ]]; then
    gate_protocol_attempt_record "$role" "" 1 retryable-failure "$reason" "$artifact" || return 2
    printf 'retry\n'
    return 0
  fi

  gate_protocol_attempt_record "$role" "" 2 exhausted "$reason" "$artifact" || return 2
  printf 'Error: %s recovery exhausted after %s\n' "$role" "$reason" >&2
  printf 'abort\n'
  return 0
}
