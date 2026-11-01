#!/usr/bin/env bash
# Regression tests for gate_reviewer_protocol_verify (runtime/lib/gate-result-verify.sh)
# at the library layer (CC-692).
#
# Ten of these defects used to be proven only by running a whole pr-gate.sh each
# (~10 s apiece in test-pr-gate.sh), although the verdict "this reviewer artifact
# is not a valid protocol document" is a pure function of the artifact, the
# selected reviewers, the scope digest and the scope manifest. They are asserted
# here against the function, with a positive control so a verifier that rejects
# everything cannot pass. test-pr-gate.sh keeps the wiring: an incomplete
# artifact aborts the gate before synthesis, a retry recovers or exhausts.
#
# The artifacts come from the same writer the gate suites use
# (pr_gate_fixture_write_reviewer_protocol), so the documents are the ones the
# gate suites feed the gate.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/gate-structural-verify.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/gate-structural-verify.sh"
# shellcheck source=runtime/lib/gate-result-verify.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/gate-result-verify.sh"
# shellcheck source=tests/lib/test-pr-gate-fixture.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-pr-gate-fixture.sh"

# _protocol_run <case-dir> <verdict> <selected> <mutation> -> sets PROTO_RC, PROTO_ERR
# Builds one artifact holding a reviewer_result_v1 block per selected reviewer
# (the mutation applies only to the reviewers it names in the fixture writer),
# a scope manifest whose reference index declares that artifact, and a brief
# carrying the two lines the writer reads.
_protocol_run() {
  local d="$1" verdict="$2" selected="$3" mutation="$4" r sha
  mkdir -p "$d"
  jq -n '{reference_index:{claim:"declared-review-reference-set",
    entries:[{path:".gate-results/artifact.md",line_count:50,
      sha256:("c" * 64)}]}}' > "$d/manifest.json"
  sha="$(_gate_result_sha256_file "$d/manifest.json")"
  printf 'artifact_sha256: %s\nartifact: %s/artifact.md\n' "$sha" "$d" > "$d/brief.md"
  : > "$d/artifact.md"
  for r in $selected; do
    pr_gate_fixture_write_reviewer_protocol \
      "$d/brief.md" "$d/artifact.md" "$r" "$verdict" "$mutation"
  done
  PROTO_RC=0
  PROTO_ERR="$(gate_reviewer_protocol_verify "$d/artifact.md" "$selected" "$sha" \
    "$d/manifest.json" 2>&1 >/dev/null)" || PROTO_RC=$?
}

# _protocol_case <name> <verdict> <selected> <mutation> <expected-rc> <needle>
# <needle> must appear in the diagnostic; "-" means the run must be silent.
_protocol_case() {
  local name="$1" verdict="$2" selected="$3" mutation="$4" want_rc="$5" needle="$6"
  should_run "$name" || return 0
  _protocol_run "$TMP_ROOT/${name//[^A-Za-z0-9]/_}" "$verdict" "$selected" "$mutation"
  if [[ "$PROTO_RC" != "$want_rc" ]]; then
    fail "$name" "rc=$PROTO_RC want $want_rc: $PROTO_ERR"
  elif [[ "$needle" == "-" && -n "$PROTO_ERR" ]]; then
    fail "$name" "unexpected diagnostic: $PROTO_ERR"
  elif [[ "$needle" != "-" && "$PROTO_ERR" != *"$needle"* ]]; then
    fail "$name" "diagnostic missing '$needle': $PROTO_ERR"
  else
    pass "$name"
  fi
}

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Behavior: a complete, correctly bound artifact is accepted without a word. This
# is the control: every rejection below is meaningful only because this passes.
_protocol_case "protocol verify: a complete artifact is accepted" \
  approve "critic qa-tester" none 0 -

# Behavior: each documented defect is rejected as INCOMPLETE with the diagnostic
# that names it, once each (a defect repeated across modes or reviewers is the
# same rejection).
_protocol_case "protocol verify: a missing declared surface is incomplete" \
  approve "critic qa-tester" missing-surface 1 "reviewer protocol INCOMPLETE"
_protocol_case "protocol verify: an unstable finding id is incomplete" \
  approve "critic qa-tester" invalid-id 1 "reviewer protocol INCOMPLETE"
_protocol_case "protocol verify: a blocker without a source reference is incomplete" \
  block "critic qa-tester" evidence-less-blocker 1 "reviewer protocol INCOMPLETE"
_protocol_case "protocol verify: a legacy pass verdict is named a verdict-contract error" \
  approve "critic qa-tester" qa-legacy-pass 1 "invalid verdict contract for qa-tester"
_protocol_case "protocol verify: a role-specific top-level field is rejected" \
  approve "critic qa-tester" critic-extra-top-level 1 \
  "invalid top-level or binding contract for critic"
_protocol_case "protocol verify: an abbreviated finding id is rejected" \
  approve "critic qa-tester risk-reviewer" risk-short-id 1 \
  "invalid finding contract for risk-reviewer"
_protocol_case "protocol verify: a blocker below high severity names the field and value" \
  block-soft "critic qa-tester architecture-reviewer" blocking-medium-severity 1 \
  "architecture-reviewer-F001 hard_gate_class=soft_block requires severity=critical|high (got medium)"
_protocol_case "protocol verify: a blocker from a pre-existing origin names the field and value" \
  block-soft "critic qa-tester architecture-reviewer" blocking-pre-existing-origin 1 \
  "architecture-reviewer-F001 hard_gate_class=soft_block requires origin=diff_caused|uncertain (got pre_existing)"
_protocol_case "protocol verify: an evidence path outside the declared set is rejected" \
  approve "critic qa-tester" out-of-scope-reference 1 \
  "invalid evidence reference contract for critic"
_protocol_case "protocol verify: an evidence line past the end of the file is rejected" \
  approve "critic qa-tester" out-of-range-line 1 \
  "invalid evidence reference contract for critic"

# Behavior: a terminal control sequence inside a finding id reaches the operator
# only JSON-escaped, never as a raw ESC byte.
case_diagnostic_never_carries_a_raw_escape_byte() {
  local name="protocol verify: a terminal escape in a finding id is printed escaped"
  should_run "$name" || return 0
  _protocol_run "$TMP_ROOT/escape" block-soft "critic qa-tester architecture-reviewer" \
    blocking-terminal-escape
  if [[ "$PROTO_RC" != 1 ]]; then
    fail "$name" "rc=$PROTO_RC want 1: $PROTO_ERR"
  elif [[ "$PROTO_ERR" != *'architecture-reviewer-F001\u001b[31m hard_gate_class=soft_block requires severity=critical|high (got medium)'* ]]; then
    fail "$name" "escaped diagnostic missing: $PROTO_ERR"
  elif [[ "$PROTO_ERR" == *$'\033'* ]]; then
    fail "$name" "raw ESC byte reached the diagnostic"
  else
    pass "$name"
  fi
}
case_diagnostic_never_carries_a_raw_escape_byte

th_summary
