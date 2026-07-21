#!/usr/bin/env bash
# Tests for tests/shell/test-e2e.sh — CLI argument handling, exit-code contract,
# and Phase C skip semantics. Does not call LLM adapters.
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
E2E="$REPO_ROOT/tests/shell/test-e2e.sh"

PASSED=0; FAILED=0

pass() { printf 'PASS: %s\n' "$1"; PASSED=$((PASSED+1)); }
fail() { printf 'FAIL: %s: %s\n' "$1" "${2:-}"; FAILED=$((FAILED+1)); }

assert_exit() {  # assert_exit <name> <want> <cmd…>
  local name="$1" want="$2"; shift 2
  local rc=0; "$@" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq "$want" ]]; then pass "$name"; else fail "$name" "exit $rc want $want"; fi
}

assert_contains() {
  local name="$1" needle="$2" hay="$3"
  if [[ "$hay" == *"$needle"* ]]; then pass "$name"; else fail "$name" "expected: $needle"; fi
}

assert_not_contains() {
  local name="$1" needle="$2" hay="$3"
  if [[ "$hay" != *"$needle"* ]]; then pass "$name"; else fail "$name" "must not contain: $needle"; fi
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
  if [[ "$rc" -eq 2 ]]; then pass "unknown-flag-exit2"; else fail "unknown-flag-exit2" "exit $rc want 2"; fi
}

test_adapter_missing_value() {
  local rc=0
  bash "$E2E" --adapter 2>/dev/null || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "adapter-missing-value"; else fail "adapter-missing-value" "exit $rc want 2"; fi
}

test_adapter_invalid() {
  local rc=0
  bash "$E2E" --adapter xyznotvalid 2>/dev/null || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "adapter-invalid"; else fail "adapter-invalid" "exit $rc want 2"; fi
}

test_opencode_adapter_is_accepted() {
  local rc=0
  PATH=/usr/bin:/bin bash "$E2E" --adapter opencode 2>/dev/null || rc=$?
  if [[ "$rc" -eq 4 ]]; then pass "opencode-adapter-accepted"; else fail "opencode-adapter-accepted" "exit $rc want 4 (parse error would be 2)"; fi
}

# ── Exit-code contract ────────────────────────────────────────────────────────

test_usage_error_exits_2() {
  assert_exit "usage-error-exits-2" 2 bash "$E2E" --bad
}

# ── Missing prerequisite: adapter not on PATH → Phase A SKIP → exit 4 ───────
# Use a restricted PATH (no codex/claude) with a valid adapter name so Phase A
# records SKIP (not FAIL) and the script exits 4 (PARTIAL GO) — E2E requires a
# live adapter, so the gate gracefully skips rather than hard-failing.

test_missing_adapter_exits_4() {
  local rc=0 out
  out=$(PATH=/usr/bin:/bin bash "$E2E" --adapter codex 2>&1) || rc=$?
  if [[ "$rc" -eq 4 ]]; then pass "missing-adapter-exits-4"; else fail "missing-adapter-exits-4" "exit $rc want 4"; fi
  assert_contains "missing-adapter-partial-go" "PARTIAL GO" "$out"
}

# ── Phase C skip flag is accepted without error ───────────────────────────────
# --skip-gate is a valid flag; combining with restricted PATH still exits 4
# (Phase A skip) not 2 (parse error), confirming the flag is parsed OK.

test_skip_gate_flag_accepted() {
  local rc=0
  PATH=/usr/bin:/bin bash "$E2E" --adapter codex --skip-gate 2>/dev/null || rc=$?
  if [[ "$rc" -eq 4 ]]; then pass "skip-gate-flag-accepted"
  else fail "skip-gate-flag-accepted" "exit $rc want 4 (parse error would be 2)"; fi
}

# ── Phase C produces SKIP (not FAIL) when --skip-gate requested ───────────────
# Confirm --skip-gate does not trigger a usage error regardless of flag order.

test_skip_gate_not_usage_error() {
  local rc=0
  PATH=/usr/bin:/bin bash "$E2E" --skip-gate --adapter codex 2>/dev/null || rc=$?
  if [[ "$rc" -ne 2 ]]; then pass "skip-gate-not-usage-error"
  else fail "skip-gate-not-usage-error" "--skip-gate caused a parse error (exit 2)"; fi
}

# ── Phase C skip actually reaches Phase C via pmctl/adapter stubs ─────────────
# Phases A+B run with stubs (no tokens). --skip-gate causes Phase C to record
# SKIP → REQUIRED_SKIPPED=1 → exit 4 (PARTIAL GO).

make_e2e_stubs() {
  local stubdir="$1"
  printf '#!/usr/bin/env bash\necho "stub-codex 0.0.0"\nexit 0\n' \
    > "$stubdir/codex"
  chmod +x "$stubdir/codex"
  cat > "$stubdir/pmctl" <<'PMCTL_STUB'
#!/usr/bin/env bash
cd_arg=""
while [[ $# -gt 0 ]]; do
  case "$1" in --cd) cd_arg="$2"; shift 2 ;; *) shift ;; esac
done
if [[ -n "$cd_arg" ]]; then
  mkdir -p "$cd_arg/.agent-trace"
  printf 'stub dispatch\n'    > "$cd_arg/.agent-trace/latest.last"
  printf '{"type":"stub"}\n' > "$cd_arg/.agent-trace/latest.jsonl"
fi
exit 0
PMCTL_STUB
  chmod +x "$stubdir/pmctl"
}

test_skip_gate_reaches_phase_c_skip() {
  local stubdir; stubdir=$(mktemp -d)
  make_e2e_stubs "$stubdir"

  local out rc=0
  out=$(PATH="$stubdir:/usr/bin:/bin" PM_E2E_PMCTL="$stubdir/pmctl" \
    bash "$E2E" --adapter codex --skip-gate 2>&1) || rc=$?
  rm -rf "$stubdir"

  if [[ "$rc" -eq 4 ]]; then pass "skip-gate-reaches-phase-c-exit4"
  else fail "skip-gate-reaches-phase-c-exit4" "exit $rc want 4 (PARTIAL GO)"; fi
  assert_contains     "skip-gate-records-skip" "SKIP"   "$out"
  assert_not_contains "skip-gate-no-fail"      "[FAIL]" "$out"
}

# ── Stub-based E2E does not create .pm-dispatch/ in working dirs ───────────────
# Regression: context db is repo-local; dispatch stub must not trigger context
# index as a side effect, leaving no .pm-dispatch/ artifact in the smoke workdir.

test_stub_e2e_no_pm_dispatch_artifact() {
  local stubdir; stubdir=$(mktemp -d)
  make_e2e_stubs "$stubdir"
  # Redirect mktemp calls inside the E2E run to a controlled subdir so the
  # artifact scan is scoped to this test's workspace only (avoids false positives
  # from concurrent agent or test runs that may create .pm-dispatch dirs in /tmp).
  local workdir="$stubdir/e2e-work"
  mkdir -p "$workdir"

  local out rc=0
  out=$(TMPDIR="$workdir" PATH="$stubdir:/usr/bin:/bin" PM_E2E_PMCTL="$stubdir/pmctl" \
    bash "$E2E" --adapter codex --skip-gate 2>&1) || rc=$?
  local artifacts
  artifacts="$(find "$workdir" -maxdepth 4 -name '.pm-dispatch' 2>/dev/null | head -5 || true)"
  rm -rf "$stubdir"

  if [[ -z "$artifacts" ]]; then pass "stub-e2e-no-pm-dispatch-artifact"
  else fail "stub-e2e-no-pm-dispatch-artifact" ".pm-dispatch created at: $artifacts"; fi
}

# Phase C runs `pmctl gate run`, whose context refresh may create
# `.pm-dispatch/ctx/context.db`. The synthetic repo must commit the canonical
# ignore before its base commit or pr-gate will reject the harness-created
# `.gitignore` change as a dirty tree.
test_phase_c_commits_context_ignore() {
  local body
  body="$(<"$E2E")"
  assert_contains "phase-c-writes-context-ignore" \
    "printf '.pm-dispatch/\\n' > \"\$synthetic_base/.gitignore\"" "$body"
  assert_contains "phase-c-commits-context-ignore" \
    'add calc.sh .gitignore' "$body"
}

# ── Run ───────────────────────────────────────────────────────────────────────

test_help_contains_usage
test_help_no_code_leak
test_help_exits_0
test_help_short
test_unknown_flag
test_adapter_missing_value
test_adapter_invalid
test_opencode_adapter_is_accepted
test_usage_error_exits_2
test_missing_adapter_exits_4
test_skip_gate_flag_accepted
test_skip_gate_not_usage_error
test_skip_gate_reaches_phase_c_skip
test_stub_e2e_no_pm_dispatch_artifact
test_phase_c_commits_context_ignore

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
