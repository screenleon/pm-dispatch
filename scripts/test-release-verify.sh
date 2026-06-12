#!/usr/bin/env bash
# Tests for scripts/release-verify.sh — CLI argument handling and exit-code contract.
# Does not call LLM adapters; all cases resolve deterministically.
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RV="$REPO_ROOT/scripts/release-verify.sh"

PASSED=0; FAILED=0

pass() { printf 'PASS: %s\n' "$1"; PASSED=$((PASSED+1)); }
fail() { printf 'FAIL: %s: %s\n' "$1" "${2:-}"; FAILED=$((FAILED+1)); }

assert_exit() {  # assert_exit <name> <want> <cmd…>
  local name="$1" want="$2"; shift 2
  local rc=0; "$@" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq "$want" ]] && pass "$name" || fail "$name" "exit $rc want $want"
}

assert_contains() {
  local name="$1" needle="$2" hay="$3"
  [[ "$hay" == *"$needle"* ]] && pass "$name" || fail "$name" "expected: $needle"
}

assert_not_contains() {
  local name="$1" needle="$2" hay="$3"
  [[ "$hay" != *"$needle"* ]] && pass "$name" || fail "$name" "must not contain: $needle"
}

# ── --help / -h ───────────────────────────────────────────────────────────────

test_help_contains_usage() {
  local out; out=$(bash "$RV" --help 2>&1)
  assert_contains    "help-usage"         "Usage"             "$out"
}

test_help_no_code_leak() {
  local out; out=$(bash "$RV" --help 2>&1)
  assert_not_contains "help-no-set-e"     "set -uo pipefail"  "$out"
  assert_not_contains "help-no-export"    "export LC_ALL"     "$out"
}

test_help_exits_0() {
  assert_exit "help-exits-0" 0 bash "$RV" --help
}

test_help_short() {
  local out; out=$(bash "$RV" -h 2>&1)
  assert_contains    "help-short-usage"   "Usage"             "$out"
}

# ── Unknown / malformed flags ─────────────────────────────────────────────────

test_unknown_flag() {
  local rc=0 out
  out=$(bash "$RV" --not-a-real-flag 2>&1) || rc=$?
  assert_contains "unknown-flag-msg" "unknown flag" "$out"
  [[ "$rc" -eq 2 ]] && pass "unknown-flag-exit2" || fail "unknown-flag-exit2" "exit $rc want 2"
}

test_adapter_missing_value() {
  local rc=0
  bash "$RV" --adapter 2>/dev/null || rc=$?
  [[ "$rc" -eq 2 ]] && pass "adapter-missing-value" || fail "adapter-missing-value" "exit $rc want 2"
}

test_adapter_invalid() {
  local rc=0
  bash "$RV" --adapter xyznotvalid 2>/dev/null || rc=$?
  [[ "$rc" -eq 2 ]] && pass "adapter-invalid" || fail "adapter-invalid" "exit $rc want 2"
}

# ── Exit-code contract ────────────────────────────────────────────────────────

test_usage_error_exits_2() {
  assert_exit "usage-error-exits-2" 2 bash "$RV" --bad
}

# ── Help text ends with a newline (output-ends-with-newline contract) ─────────

test_help_ends_with_newline() {
  local tmpf; tmpf=$(mktemp)
  bash "$RV" --help >"$tmpf" 2>&1
  local last; last=$(tail -c 1 "$tmpf")
  # $() strips trailing \n; empty $last on a non-empty file means last byte was \n
  local sz; sz=$(wc -c < "$tmpf")
  rm -f "$tmpf"
  [[ -z "$last" && "$sz" -gt 0 ]] \
    && pass "help-ends-with-newline" \
    || fail "help-ends-with-newline" "help output does not end with a newline"
}

# ── Verdict contract: --no-suite produces PARTIAL GO (exit 3) ─────────────────
# These tests invoke real Phase 1 + Phase 3; they assume bash/jq/git/sqlite3/pmctl
# pass in the current environment (same assumption as release-verify --no-suite).

test_no_suite_partial_verdict() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "no-suite-partial-verdict"   "PARTIAL GO"                     "$out"
  assert_contains "no-suite-skip-reason"       "NOT valid for release sign-off" "$out"
}

test_no_suite_exits_3() {
  # PARTIAL GO is exit 3: distinct from 0=full GO, 1=NO-GO, 2=usage error.
  assert_exit "no-suite-exits-3" 3 bash "$RV" --no-suite
}

# ── Phase 4 delegation via PM_RELEASE_VERIFY_E2E_SCRIPT stub ──────────────────
# Each test stubs the e2e script to return a specific exit code; Phase 4 handling
# is tested without spending LLM tokens. Phase 1+3 still run for real.

test_e2e_delegation_pass() {
  local stub; stub=$(mktemp)
  printf '#!/usr/bin/env bash\nprintf "AUTOMATED VERDICT: GO (stub)\\n"\nexit 0\n' > "$stub"
  chmod +x "$stub"
  local out rc=0
  out=$(PM_RELEASE_VERIFY_E2E_SCRIPT="$stub" bash "$RV" --no-suite --e2e --adapter claude 2>&1) || rc=$?
  rm -f "$stub"
  # --no-suite increments REQUIRED_SKIPPED → PARTIAL GO (exit 3) even with GO from stub
  assert_not_contains "e2e-pass-no-fail" "[FAIL]" "$out"
  [[ "$rc" -eq 3 ]] && pass "e2e-pass-exit3" \
    || fail "e2e-pass-exit3" "exit $rc want 3 (PARTIAL GO)"
}

test_e2e_delegation_fail() {
  local stub; stub=$(mktemp)
  printf '#!/usr/bin/env bash\nprintf "AUTOMATED VERDICT: NO-GO (stub)\\n"\nexit 1\n' > "$stub"
  chmod +x "$stub"
  local rc=0
  PM_RELEASE_VERIFY_E2E_SCRIPT="$stub" bash "$RV" --no-suite --e2e --adapter claude \
    >/dev/null 2>&1 || rc=$?
  rm -f "$stub"
  [[ "$rc" -eq 1 ]] && pass "e2e-fail-exit1" \
    || fail "e2e-fail-exit1" "exit $rc want 1 (NO-GO)"
}

test_e2e_delegation_required_skip() {
  # test-e2e.sh exit 4 = PARTIAL GO (Phase C SKIP) → release-verify records SKIP
  local stub; stub=$(mktemp)
  printf '#!/usr/bin/env bash\nprintf "AUTOMATED VERDICT: PARTIAL GO (stub)\\n"\nexit 4\n' > "$stub"
  chmod +x "$stub"
  local out rc=0
  out=$(PM_RELEASE_VERIFY_E2E_SCRIPT="$stub" bash "$RV" --no-suite --e2e --adapter claude 2>&1) || rc=$?
  rm -f "$stub"
  assert_contains "e2e-req-skip-text" "SKIP" "$out"
  [[ "$rc" -eq 3 ]] && pass "e2e-req-skip-exit3" \
    || fail "e2e-req-skip-exit3" "exit $rc want 3 (PARTIAL GO)"
}

# ── No --e2e: Phase 4 recorded as required SKIP ───────────────────────────────

test_no_e2e_phase4_skip_recorded() {
  # When --e2e is omitted Phase 4 must be explicitly recorded as SKIP (required
  # phase skipped), making the verdict PARTIAL GO (exit 3) — not GO.
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "no-e2e-skip-line" "[SKIP] e2e dispatch+gate" "$out"
  assert_contains "no-e2e-partial"   "PARTIAL GO"               "$out"
  [[ "$rc" -eq 3 ]] && pass "no-e2e-exits-3" \
    || fail "no-e2e-exits-3" "exit $rc want 3 (PARTIAL GO)"
}

# ── Run ───────────────────────────────────────────────────────────────────────

test_help_contains_usage
test_help_no_code_leak
test_help_exits_0
test_help_short
test_unknown_flag
test_adapter_missing_value
test_adapter_invalid
test_usage_error_exits_2
test_help_ends_with_newline
test_no_suite_partial_verdict
test_no_suite_exits_3
test_e2e_delegation_pass
test_e2e_delegation_fail
test_e2e_delegation_required_skip
test_no_e2e_phase4_skip_recorded

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
