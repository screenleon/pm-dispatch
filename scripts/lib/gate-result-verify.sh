#!/usr/bin/env bash
# Shared gate-result integrity verification.
#
# A gate result file (pr_gate_result_v1) is only trustworthy when it is
# structurally complete: a non-empty file carrying exactly one parseable
# `Final: GO|NO-GO` verdict whose value agrees with the YAML frontmatter
# `final:` field. The single-session route, the parallel synthesis route, and
# `pmctl gate verify` all enforce the SAME contract, so the checks live here
# once instead of being re-encoded per call site.
#
# This is the authority the gate uses to turn "the executor exited 0" into
# "the executor actually produced a verdict" -- the seam that catches a session
# that exits clean without writing the result (the 0-byte result failure mode).
#
# pr-gate.sh carries an inline copy of gate_result_verify as a fallback for
# copy-mode (running pr-gate.sh standalone without scripts/lib/ co-located); the
# two MUST stay in sync. The copy-mode regression test exercises the fallback.

# gate_result_verify <result_file> [expected_final] [route_label]
# Returns 0 when <result_file> is a structurally valid gate result. On the first
# failed check it prints a specific diagnostic to stderr and returns 1:
#   - file exists and is non-empty
#   - exactly one `^Final: (GO|NO-GO)$` line (plain text, no markdown emphasis)
#   - YAML frontmatter carries a `final:` field
#   - frontmatter `final:` equals the body `Final:` value
#   - when [expected_final] is non-empty, the body `Final:` must equal it (the
#     parallel route passes the shell-computed verdict so a synthesis that
#     contradicts it is rejected as manipulated/corrupt)
# [route_label] (default "gate") is woven into the not-produced / contradiction
# diagnostics so each call site reports in its own vocabulary.
gate_result_verify() {
  local result_file=${1-} expected_final=${2-} route_label=${3-gate}
  local final_count frontmatter_final body_final

  [[ $# -ge 1 && $# -le 3 ]] || {
    printf 'gate-result-verify: gate_result_verify expects <result_file> [expected_final] [route_label]\n' >&2
    return 2
  }

  if [[ ! -s "$result_file" ]]; then
    printf 'Error: %s did not produce the result file: %s\n' "$route_label" "$result_file" >&2
    printf 'Gate aborted -- the executor session may have exited 0 without writing a verdict.\n' >&2
    return 1
  fi

  final_count=$(grep -cE '^Final: (GO|NO-GO)$' "$result_file" || true)
  if [[ "$final_count" -ne 1 ]]; then
    printf 'Error: gate result file must contain exactly one Final: GO/NO-GO line (found %d): %s\n' \
      "$final_count" "$result_file" >&2
    return 1
  fi

  frontmatter_final=$(awk 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } } s && $1 == "final:" { print $2; exit }' "$result_file")
  if [[ -z "$frontmatter_final" ]]; then
    printf 'Error: gate result YAML frontmatter missing required field: final: (%s)\n' "$result_file" >&2
    return 1
  fi

  body_final=$(grep -E '^Final: (GO|NO-GO)$' "$result_file" | awk '{print $2}')
  if [[ "$frontmatter_final" != "$body_final" ]]; then
    printf 'Error: frontmatter final: (%s) does not match body Final: (%s) in gate result: %s\n' \
      "$frontmatter_final" "$body_final" "$result_file" >&2
    return 1
  fi

  if [[ -n "$expected_final" && "$body_final" != "$expected_final" ]]; then
    printf 'Error: %s verdict (%s) contradicts shell-computed verdict (%s) -- gate result may have been manipulated: %s\n' \
      "$route_label" "$body_final" "$expected_final" "$result_file" >&2
    return 1
  fi

  return 0
}

export -f gate_result_verify
