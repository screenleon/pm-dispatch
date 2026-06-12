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

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
