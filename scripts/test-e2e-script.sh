#!/usr/bin/env bash
# Tests for scripts/test-e2e.sh — CLI argument handling, exit-code contract,
# and Phase C skip semantics. Does not call LLM adapters.
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
E2E="$REPO_ROOT/scripts/test-e2e.sh"

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
  local out; out=$(bash "$E2E" --help 2>&1)
  assert_contains    "help-usage"         "Usage"             "$out"
}

test_help_no_code_leak() {
  local out; out=$(bash "$E2E" --help 2>&1)
  assert_not_contains "help-no-set-e"     "set -uo pipefail"  "$out"
  assert_not_contains "help-no-export"    "export LC_ALL"     "$out"
}

test_help_exits_0() {
  assert_exit "help-exits-0" 0 bash "$E2E" --help
}

test_help_short() {
  local out; out=$(bash "$E2E" -h 2>&1)
  assert_contains    "help-short-usage"   "Usage"             "$out"
}

# ── Unknown / malformed flags ─────────────────────────────────────────────────

test_unknown_flag() {
  local rc=0 out
  out=$(bash "$E2E" --bad-flag 2>&1) || rc=$?
  assert_contains "unknown-flag-msg" "unknown flag" "$out"
  [[ "$rc" -eq 2 ]] && pass "unknown-flag-exit2" || fail "unknown-flag-exit2" "exit $rc want 2"
}

test_adapter_missing_value() {
  local rc=0
  bash "$E2E" --adapter 2>/dev/null || rc=$?
  [[ "$rc" -eq 2 ]] && pass "adapter-missing-value" || fail "adapter-missing-value" "exit $rc want 2"
}

test_adapter_invalid() {
  local rc=0
  bash "$E2E" --adapter xyznotvalid 2>/dev/null || rc=$?
  [[ "$rc" -eq 2 ]] && pass "adapter-invalid" || fail "adapter-invalid" "exit $rc want 2"
}

# ── Exit-code contract ────────────────────────────────────────────────────────

test_usage_error_exits_2() {
  assert_exit "usage-error-exits-2" 2 bash "$E2E" --bad
}

# ── Missing prerequisite: adapter not on PATH → Phase A FAIL → exit 1 ────────
# Use a restricted PATH (no codex/claude) with a valid adapter name so Phase A
# fails with FAIL (not a usage error) and the script exits 1 (NO-GO).

test_missing_adapter_exits_1() {
  local rc=0 out
  out=$(PATH=/usr/bin:/bin bash "$E2E" --adapter codex 2>&1) || rc=$?
  [[ "$rc" -eq 1 ]] && pass "missing-adapter-exits-1" || fail "missing-adapter-exits-1" "exit $rc want 1"
  assert_contains "missing-adapter-no-go" "NO-GO" "$out"
}

# ── Phase C skip flag is accepted without error ───────────────────────────────
# --skip-gate is a valid flag; combining with restricted PATH still exits 1
# (Phase A failure) not 2 (parse error), confirming the flag is parsed OK.

test_skip_gate_flag_accepted() {
  local rc=0
  PATH=/usr/bin:/bin bash "$E2E" --adapter codex --skip-gate 2>/dev/null || rc=$?
  [[ "$rc" -eq 1 ]] && pass "skip-gate-flag-accepted" \
    || fail "skip-gate-flag-accepted" "exit $rc want 1 (parse error would be 2)"
}

# ── Phase C produces SKIP (not FAIL) when --skip-gate requested ───────────────
# Confirm --skip-gate does not trigger a usage error regardless of flag order.

test_skip_gate_not_usage_error() {
  local rc=0
  PATH=/usr/bin:/bin bash "$E2E" --skip-gate --adapter codex 2>/dev/null || rc=$?
  [[ "$rc" -ne 2 ]] && pass "skip-gate-not-usage-error" \
    || fail "skip-gate-not-usage-error" "--skip-gate caused a parse error (exit 2)"
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
test_missing_adapter_exits_1
test_skip_gate_flag_accepted
test_skip_gate_not_usage_error

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
