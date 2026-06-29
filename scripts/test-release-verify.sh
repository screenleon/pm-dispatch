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
  if [[ "$rc" -eq 2 ]]; then pass "unknown-flag-exit2"; else fail "unknown-flag-exit2" "exit $rc want 2"; fi
}

test_adapter_missing_value() {
  local rc=0
  bash "$RV" --adapter 2>/dev/null || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "adapter-missing-value"; else fail "adapter-missing-value" "exit $rc want 2"; fi
}

test_adapter_invalid() {
  local rc=0
  bash "$RV" --adapter xyznotvalid 2>/dev/null || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "adapter-invalid"; else fail "adapter-invalid" "exit $rc want 2"; fi
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
  if [[ -z "$last" && "$sz" -gt 0 ]]; then pass "help-ends-with-newline"
  else fail "help-ends-with-newline" "help output does not end with a newline"; fi
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
  if [[ "$rc" -eq 3 ]]; then pass "e2e-pass-exit3"
  else fail "e2e-pass-exit3" "exit $rc want 3 (PARTIAL GO)"; fi
}

test_e2e_delegation_fail() {
  local stub; stub=$(mktemp)
  printf '#!/usr/bin/env bash\nprintf "AUTOMATED VERDICT: NO-GO (stub)\\n"\nexit 1\n' > "$stub"
  chmod +x "$stub"
  local rc=0
  PM_RELEASE_VERIFY_E2E_SCRIPT="$stub" bash "$RV" --no-suite --e2e --adapter claude \
    >/dev/null 2>&1 || rc=$?
  rm -f "$stub"
  if [[ "$rc" -eq 1 ]]; then pass "e2e-fail-exit1"
  else fail "e2e-fail-exit1" "exit $rc want 1 (NO-GO)"; fi
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
  if [[ "$rc" -eq 3 ]]; then pass "e2e-req-skip-exit3"
  else fail "e2e-req-skip-exit3" "exit $rc want 3 (PARTIAL GO)"; fi
}

# ── No --e2e: Phase 4 recorded as required SKIP ───────────────────────────────

test_no_e2e_phase4_skip_recorded() {
  # When --e2e is omitted Phase 4 must be explicitly recorded as SKIP (required
  # phase skipped), making the verdict PARTIAL GO (exit 3) — not GO.
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "no-e2e-skip-line" "[SKIP] e2e dispatch+gate" "$out"
  assert_contains "no-e2e-partial"   "PARTIAL GO"               "$out"
  if [[ "$rc" -eq 3 ]]; then pass "no-e2e-exits-3"
  else fail "no-e2e-exits-3" "exit $rc want 3 (PARTIAL GO)"; fi
}

# ── Phase 3: repo-local db + external-repo smoke cases ────────────────────────
# Verifies that the new context behavior (db in .pm-dispatch/, external-repo-index
# smoke, and no-db graceful degradation) appears in Phase 3 output.

test_phase3_external_repo_cases() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3-external-repo-index"    "[PASS] external-repo-index"    "$out"
  assert_contains "phase3-external-repo-db-loc"   "external-repo-db-location"     "$out"
  assert_contains "phase3-external-repo-query"    "external-repo-query"           "$out"
  assert_contains "phase3-no-db-graceful"         "context-no-db-graceful"        "$out"
}

test_phase3_repo_local_db_smoke() {
  # The standard Phase 3 smoke (this repo) must PASS — proves repo-local db works.
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3-index-skip-query" "[PASS] context index+skip+query" "$out"
  assert_contains "phase3-pack"             "[PASS] context pack"             "$out"
  assert_contains "phase3-reuse-scan"       "[PASS] context reuse-scan"       "$out"
}

test_native_windows_refused() {
  # On native Windows (Git Bash) release-verify refuses with exit 2 and a "use
  # WSL2" message instead of running phases. Simulated via a fake `uname -s`
  # returning a MINGW string; fails if the refusal branch is removed.
  local bin out rc real_uname
  bin="$(mktemp -d)"
  real_uname="$(command -v uname)"
  cat > "$bin/uname" <<EOF
#!/bin/sh
[ "\$1" = "-s" ] && echo "MINGW64_NT-10.0-19045" || exec "$real_uname" "\$@"
EOF
  chmod +x "$bin/uname"
  out="$(PATH="$bin:$PATH" bash "$RV" 2>&1)"; rc=$?
  rm -rf "$bin"
  if [[ "$rc" -eq 2 ]]; then pass "native-windows-refused-exit2"; else fail "native-windows-refused-exit2" "exit $rc want 2"; fi
  assert_contains "native-windows-refused-msg" "not a release sign-off platform" "$out"
  # The refusal must happen BEFORE any phase runs — no phase banner, no phase
  # result lines may appear (guards against the refusal being moved below Phase 1,
  # which would reintroduce the platform false-failure noise).
  assert_not_contains "native-windows-refused-no-phase-banner" "=== Phase" "$out"
  assert_not_contains "native-windows-refused-no-pass-record" "[PASS]" "$out"
  assert_not_contains "native-windows-refused-no-fail-record" "[FAIL]" "$out"
}

# ── Phase 3b: v0.6.0 feature smoke regression ────────────────────────────────
# Verifies that Phase 3b records appear in --no-suite output and that the
# new guard + brief-validate smoke cases pass against the real pmctl binary.

test_phase3b_adapter_manifests() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3b-manifest-codex"    "[PASS] adapter-manifest-codex"    "$out"
  assert_contains "phase3b-manifest-claude"   "[PASS] adapter-manifest-claude"   "$out"
  assert_contains "phase3b-manifest-opencode" "[PASS] adapter-manifest-opencode" "$out"
}

test_phase3b_guard_check() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3b-guard-allow" "[PASS] guard-check-executor-allow" "$out"
  assert_contains "phase3b-guard-block" "[PASS] guard-check-executor-block" "$out"
}

test_phase3b_brief_validate() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3b-legacy-reject" "[PASS] brief-validate-legacy-reject"     "$out"
  assert_contains "phase3b-none-reject"   "[PASS] brief-validate-none-codex-reject" "$out"
  assert_contains "phase3b-valid-brief"   "[PASS] brief-validate-valid"             "$out"
}

# ── Phase 3c: v0.7.0 feature smoke ───────────────────────────────────────────
# Verifies that Phase 3c records appear in --no-suite output and that the
# memory-source, doctor, artifacts-list, and pre-release-audit smoke cases pass.

test_phase3c_memory_source() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3c-memory-source" "[PASS] context-memory-source" "$out"
}

test_phase3c_memory_doctor() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3c-memory-doctor" "[PASS] memory-doctor" "$out"
}

test_phase3c_artifacts_list() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3c-artifacts-list" "[PASS] artifacts-list" "$out"
}

test_phase3c_pre_release_audit() {
  local out rc=0
  out=$(bash "$RV" --no-suite 2>&1) || rc=$?
  assert_contains "phase3c-pre-release-audit" "[PASS] pre-release-audit" "$out"
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
test_phase3_external_repo_cases
test_phase3_repo_local_db_smoke
test_phase3b_adapter_manifests
test_phase3b_guard_check
test_phase3b_brief_validate
test_phase3c_memory_source
test_phase3c_memory_doctor
test_phase3c_artifacts_list
test_phase3c_pre_release_audit
test_native_windows_refused

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
