#!/usr/bin/env bash
# Tests for ops/release/release-verify.sh — CLI argument handling and exit-code contract.
# Does not call LLM adapters; all cases resolve deterministically.
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RV="$REPO_ROOT/ops/release/release-verify.sh"
# shellcheck source=runtime/lib/adapter-enum.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/adapter-enum.sh"

# Every `bash "$RV"` invocation below exercises Phase 3, which by default
# indexes/queries/packs against REPO_ROOT — the developer's live
# .pm-dispatch/ctx/context.db. Point Phase 3 at a throwaway copy of this
# repo's CURRENT WORKING TREE instead: same real file mix the smoke is meant
# to exercise, but its own isolated DB, so this suite never mutates the live
# one (and can safely run in parallel with test-pmctl-context, which asserts
# that DB is untouched). This must snapshot on-disk content, not `git archive
# HEAD` — HEAD is the last commit, so an archive-based fixture would silently
# validate against stale, already-committed code instead of uncommitted
# changes under test (the failure mode test_phase3_default_target_is_own_repo_root
# below exists to catch: the fixture's own copy of release-verify.sh must be
# the one actually being changed).
CONTEXT_FIXTURE_REPO="$(mktemp -d)"
git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard \
  | tar -C "$REPO_ROOT" --null -T - -cf - \
  | tar -xf - -C "$CONTEXT_FIXTURE_REPO"
export PM_RELEASE_VERIFY_CONTEXT_REPO="$CONTEXT_FIXTURE_REPO"
trap 'rm -rf "$CONTEXT_FIXTURE_REPO"' EXIT

# The developer's live repo context DB — the file the redirect above exists to
# keep untouched. test_context_smoke_targets_fixture_repo proves the redirect
# worked from evidence this suite owns: the fixture DB. A fingerprint of the live
# DB cannot distinguish this suite's writes from any other process's, and the
# auto-context hook writes it on every prompt.
LIVE_DB="$REPO_ROOT/.pm-dispatch/ctx/context.db"

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

# ── Shared cache for the repeated `bash "$RV" --no-suite` invocation ──────────
# A dozen test functions below all assert against the same bare `--no-suite`
# output (Phase 1 + real-repo Phase 3/3b/3c smoke). Running it once and caching
# the result means that real work happens exactly once per test-release-verify.sh
# run instead of once per assertion group. Only this exact invocation shape is
# cached — the --e2e stub variants further down use distinct stubs/flags and stay
# independent processes.
RV_NO_SUITE_DONE=0
RV_NO_SUITE_OUT=""
RV_NO_SUITE_RC=0

rv_no_suite_once() {
  if [[ "$RV_NO_SUITE_DONE" -eq 0 ]]; then
    RV_NO_SUITE_RC=0
    RV_NO_SUITE_OUT=$(bash "$RV" --no-suite 2>&1) || RV_NO_SUITE_RC=$?
    RV_NO_SUITE_DONE=1
  fi
}

# ── --help / -h ───────────────────────────────────────────────────────────────

test_help_contains_usage() {
  local out; out=$(bash "$RV" --help 2>&1)
  assert_contains    "help-usage"         "Usage"             "$out"
  assert_contains    "help-e2e-keeps-full" "never replaces or skips the full suite" "$out"
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

test_release_suite_verifies_state_bound_artifact() {
  # Release sign-off must freshly run the full suite (with every flag
  # declared in _release_phase2_suite_flags -- currently --result-file and
  # --collect-all; a structural precheck failure must still surface every
  # suite's PASS/FAIL instead of short-circuiting and hiding the rest of
  # this report) and verify its tree-bound artifact before any later
  # smoke/e2e phase can produce GO. Asserted against the flags array
  # declaration and its actual use in the invocation, not a hand-grepped
  # copy of the invocation line -- a future flag addition/removal only
  # needs updating that one array, and this test tracks it automatically.
  local name="release-suite-verifies-state-bound-artifact"
  # shellcheck disable=SC2016  # Literal grep patterns, not meant to expand.
  if grep -q '_release_phase2_suite_flags=(--result-file "\$suite_result" --collect-all)' "$RV" \
    && grep -q 'run-all-tests.sh".*"\${_release_phase2_suite_flags\[@\]}"' "$RV" \
    && grep -q 'run-tests.sh.*--verify-full' "$RV"; then
    pass "$name"
  else
    fail "$name" "release Phase 2 does not run+verify the full test artifact with its declared flags"
  fi
}

test_release_phase1_runs_evidence_inventory_lints() {
  # Phase 1 must turn a failed inventory linter into a release NO-GO, not just
  # contain a static call-site string. Intercept only the surface linter while
  # delegating every other bash invocation to the real interpreter.
  local name="release-phase1-runs-evidence-inventory-lints" shim_dir out status=0
  shim_dir="$(mktemp -d)"
  printf '%s\n' '#!/bin/bash' \
    "if [[ \"\${1:-}\" == */tools/lint/lint-surface-coverage.sh ]]; then exit 17; fi" \
    'exec /bin/bash "$@"' > "$shim_dir/bash"
  # Keep the behavioral check out of the live context-DB path: Phase 1 still
  # executes normally, while later sqlite-dependent smoke records a fast
  # non-GO contributor instead of opening the shared repo database.
  printf '%s\n' '#!/bin/bash' 'exit 1' > "$shim_dir/sqlite3"
  chmod +x "$shim_dir/bash" "$shim_dir/sqlite3"
  out="$(PATH="$shim_dir:$PATH" bash "$RV" --no-suite 2>&1)" || status=$?
  rm -rf "$shim_dir"
  if [[ "$status" -eq 1 && "$out" == *'[FAIL] surface coverage'* && "$out" == *'AUTOMATED VERDICT: NO-GO'* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: release authorization rejects an ambient ShellCheck whose version
# differs from the repository pin even when the executable exists on PATH.
# Steps: Arrange a 0.10.0 ShellCheck and failing SQLite shim; Act by running
# no-suite release verification; Assert the version mismatch makes the verdict NO-GO.
test_release_phase1_rejects_shellcheck_version_drift() {
  local name="release-phase1-rejects-shellcheck-version-drift" shim_dir out status=0
  shim_dir="$(mktemp -d)"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "ShellCheck\nversion: 0.10.0\n"' > "$shim_dir/shellcheck"
  # Keep the behavioral check away from the context DB after Phase 1 records
  # the mismatch; the SQLite smoke remains a deterministic NO-GO contributor.
  printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$shim_dir/sqlite3"
  chmod +x "$shim_dir/shellcheck" "$shim_dir/sqlite3"
  out="$(PATH="$shim_dir:$PATH" bash "$RV" --no-suite 2>&1)" || status=$?
  rm -rf "$shim_dir"
  if [[ "$status" -eq 1 && "$out" == *'[FAIL] shellcheck'* \
      && "$out" == *'expected 0.11.0, got 0.10.0'* \
      && "$out" == *'AUTOMATED VERDICT: NO-GO'* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_release_e2e_keeps_full_and_excludes_affected_phase() {
  # The fixed release entry point is release-verify.sh --e2e. It must keep the
  # default fresh full suite, add E2E after that suite, and never grow an
  # affected-selection phase (affected feedback belongs to development/PR).
  local name="release-e2e-keeps-full-and-excludes-affected-phase"
  local full_line e2e_line
  full_line="$(grep -n '^# ── Phase 2: Full automated test suite' "$RV" | head -1 | cut -d: -f1)"
  e2e_line="$(grep -n '^# ── Phase 4:' "$RV" | head -1 | cut -d: -f1)"
  if grep -q '^RUN_SUITE=1$' "$RV" \
    && grep -q -- '--e2e)      RUN_E2E=1; shift ;;' "$RV" \
    && [[ "$full_line" =~ ^[0-9]+$ && "$e2e_line" =~ ^[0-9]+$ ]] \
    && (( full_line < e2e_line )) \
    && ! grep -Eq 'run-tests\.sh[^[:cntrl:]]*--(base|path)|run-tests\.sh[^[:cntrl:]]*contract=iteration|run-tests\.sh[^[:cntrl:]]*affected' "$RV"; then
    pass "$name"
  else
    fail "$name" "--e2e no longer means fresh full first + E2E, or an affected phase leaked into release"
  fi
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

test_opencode_adapter_is_accepted() {
  local stub rc=0
  stub=$(mktemp)
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub"
  chmod +x "$stub"
  PM_RELEASE_VERIFY_E2E_SCRIPT="$stub" bash "$RV" --no-suite --e2e --adapter opencode >/dev/null 2>&1 || rc=$?
  rm -f "$stub"
  if [[ "$rc" -eq 3 ]]; then pass "opencode-adapter-accepted"; else fail "opencode-adapter-accepted" "exit $rc want 3 (accepted adapter with --no-suite)"; fi
}

test_adapter_enum_rejects_invalid_and_symlinked_manifest() {
  local root manifest
  root=$(mktemp -d); mkdir -p "$root/adapters/demo"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$root/adapters/demo/worker.sh"
  chmod +x "$root/adapters/demo/worker.sh"
  manifest="$root/adapters/demo/adapter.yaml"
  printf '%s\n' 'schema_version: 1' 'adapter_name: demo' \
    'runner_kind: cli-subprocess' 'dispatch_entrypoint: ./worker.sh' > "$manifest"
  if ! pm_adapter_is_valid "$root" 'Bad_Name' && ! pm_adapter_is_valid "$root" '-demo'; then pass "adapter-enum-invalid-names-rejected"; else fail "adapter-enum-invalid-names-rejected"; fi
  rm -f "$manifest"; ln -s /dev/null "$manifest"
  if ! pm_adapter_is_valid "$root" demo; then pass "adapter-enum-symlink-manifest-rejected"; else fail "adapter-enum-symlink-manifest-rejected"; fi
  rm -rf "$root"
}

test_adapter_enum_expected_values() {
  local root values
  root=$(mktemp -d); mkdir -p "$root/adapters/zeta" "$root/adapters/alpha" "$root/adapters/broken"
  for adapter in zeta alpha; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$root/adapters/$adapter/worker.sh"
    chmod +x "$root/adapters/$adapter/worker.sh"
    printf '%s\n' 'schema_version: 1' "adapter_name: $adapter" \
      'runner_kind: cli-subprocess' 'dispatch_entrypoint: ./worker.sh' \
      > "$root/adapters/$adapter/adapter.yaml"
  done
  printf '%s\n' 'schema_version: 1' 'adapter_name: broken' \
    'runner_kind: cli-subprocess' 'dispatch_entrypoint: ./missing.sh' \
    > "$root/adapters/broken/adapter.yaml"
  values="$(pm_adapter_expected_values "$root")"; rm -rf "$root"
  if [[ "$values" == 'auto|alpha|zeta' ]]; then pass "adapter-enum-expected-values"; else fail "adapter-enum-expected-values" "values=$values"; fi
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
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "no-suite-partial-verdict"   "PARTIAL GO"                     "$out"
  assert_contains "no-suite-skip-reason"       "NOT valid for release sign-off" "$out"
}

test_no_suite_exits_3() {
  # PARTIAL GO is exit 3: distinct from 0=full GO, 1=NO-GO, 2=usage error.
  rv_no_suite_once
  local rc="$RV_NO_SUITE_RC"
  if [[ "$rc" -eq 3 ]]; then pass "no-suite-exits-3"; else fail "no-suite-exits-3" "exit $rc want 3"; fi
}

# ── Phase 4 delegation via PM_RELEASE_VERIFY_E2E_SCRIPT stub ──────────────────
# Each test stubs the e2e script to return a specific exit code; Phase 4 handling
# is tested without spending LLM tokens. Phase 1+3 still run for real.

test_e2e_delegation_pass() {
  local stub state; stub=$(mktemp); state=$(mktemp -d)
  printf '#!/usr/bin/env bash\nprintf "AUTOMATED VERDICT: GO (stub)\\n"\nexit 0\n' > "$stub"
  chmod +x "$stub"
  local out rc=0
  out=$(PM_DISPATCH_STATE_ROOT="$state" PM_RELEASE_VERIFY_E2E_SCRIPT="$stub" bash "$RV" --no-suite --e2e --adapter claude 2>&1) || rc=$?
  rm -f "$stub"; rm -rf "$state"
  # --no-suite increments REQUIRED_SKIPPED → PARTIAL GO (exit 3) even with GO from stub
  assert_not_contains "e2e-pass-no-fail" "[FAIL]" "$out"
  if [[ "$rc" -eq 3 ]]; then pass "e2e-pass-exit3"
  else fail "e2e-pass-exit3" "exit $rc want 3 (PARTIAL GO)"; fi
}

test_e2e_delegation_fail() {
  local stub state; stub=$(mktemp); state=$(mktemp -d)
  printf '#!/usr/bin/env bash\nprintf "AUTOMATED VERDICT: NO-GO (stub)\\n"\nexit 1\n' > "$stub"
  chmod +x "$stub"
  local rc=0
  PM_DISPATCH_STATE_ROOT="$state" PM_RELEASE_VERIFY_E2E_SCRIPT="$stub" bash "$RV" --no-suite --e2e --adapter claude \
    >/dev/null 2>&1 || rc=$?
  rm -f "$stub"; rm -rf "$state"
  if [[ "$rc" -eq 1 ]]; then pass "e2e-fail-exit1"
  else fail "e2e-fail-exit1" "exit $rc want 1 (NO-GO)"; fi
}

test_e2e_delegation_required_skip() {
  # test-e2e.sh exit 4 = PARTIAL GO (Phase C SKIP) → release-verify records SKIP
  local stub state; stub=$(mktemp); state=$(mktemp -d)
  printf '#!/usr/bin/env bash\nprintf "AUTOMATED VERDICT: PARTIAL GO (stub)\\n"\nexit 4\n' > "$stub"
  chmod +x "$stub"
  local out rc=0
  out=$(PM_DISPATCH_STATE_ROOT="$state" PM_RELEASE_VERIFY_E2E_SCRIPT="$stub" bash "$RV" --no-suite --e2e --adapter claude 2>&1) || rc=$?
  rm -f "$stub"; rm -rf "$state"
  assert_contains "e2e-req-skip-text" "SKIP" "$out"
  if [[ "$rc" -eq 3 ]]; then pass "e2e-req-skip-exit3"
  else fail "e2e-req-skip-exit3" "exit $rc want 3 (PARTIAL GO)"; fi
}

# ── No --e2e: Phase 4 recorded as required SKIP ───────────────────────────────

test_no_e2e_phase4_skip_recorded() {
  # When --e2e is omitted Phase 4 must be explicitly recorded as SKIP (required
  # phase skipped), making the verdict PARTIAL GO (exit 3) — not GO.
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "no-e2e-skip-line" "[SKIP] e2e dispatch+gate" "$out"
  assert_contains "no-e2e-partial"   "PARTIAL GO"               "$out"
  if [[ "$rc" -eq 3 ]]; then pass "no-e2e-exits-3"
  else fail "no-e2e-exits-3" "exit $rc want 3 (PARTIAL GO)"; fi
}

# ── Phase 3: repo-local db + external-repo smoke cases ────────────────────────
# Verifies that the new context behavior (db in .pm-dispatch/, external-repo-index
# smoke, and no-db graceful degradation) appears in Phase 3 output.

test_phase3_external_repo_cases() {
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3-external-repo-index"    "[PASS] external-repo-index"    "$out"
  assert_contains "phase3-external-repo-db-loc"   "external-repo-db-location"     "$out"
  assert_contains "phase3-external-repo-query"    "external-repo-query"           "$out"
  assert_contains "phase3-no-db-graceful"         "context-no-db-graceful"        "$out"
}

test_phase3_repo_local_db_smoke() {
  # The standard Phase 3 smoke (this repo) must PASS — proves repo-local db works.
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3-index-skip-query" "[PASS] context index+skip+query" "$out"
  assert_contains "phase3-pack"             "[PASS] context pack"             "$out"
  assert_contains "phase3-reuse-scan"       "[PASS] context reuse-scan"       "$out"
}

# ── Phase 3: production-default branch (PM_RELEASE_VERIFY_CONTEXT_REPO unset) ─
# Every other case in this file runs the real ops/release/release-verify.sh
# with the override exported (see top of file), so none of them exercise the
# `${PM_RELEASE_VERIFY_CONTEXT_REPO:-$REPO_ROOT}` fallback branch that a real
# release sign-off actually relies on. Prove that branch here by running the
# FIXTURE's own copy of release-verify.sh (CONTEXT_FIXTURE_REPO is a full
# working-tree copy, so it carries its own ops/release/release-verify.sh,
# cli/pmctl, and runtime/lib/) with the override unset. That script resolves
# its own REPO_ROOT from its own path, so the default branch targets the
# fixture's tree — never the real developer repo — while still proving the
# fallback actually fires.

test_phase3_default_target_is_own_repo_root() {
  local fixture_rv="$CONTEXT_FIXTURE_REPO/ops/release/release-verify.sh"
  local out
  out=$(env -u PM_RELEASE_VERIFY_CONTEXT_REPO bash "$fixture_rv" --no-suite 2>&1) || true
  assert_contains "phase3-default-branch-index-pass" "[PASS] context index+skip+query" "$out"
  if [[ -f "$CONTEXT_FIXTURE_REPO/.pm-dispatch/ctx/context.db" ]]; then
    pass "phase3-default-branch-targets-own-repo-root"
  else
    fail "phase3-default-branch-targets-own-repo-root" "no context.db created under the fixture's own repo root — default branch did not fire"
  fi
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
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3b-manifest-codex"    "[PASS] adapter-manifest-codex"    "$out"
  assert_contains "phase3b-manifest-claude"   "[PASS] adapter-manifest-claude"   "$out"
  assert_contains "phase3b-manifest-opencode" "[PASS] adapter-manifest-opencode" "$out"
}

test_phase3b_guard_check() {
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3b-guard-allow" "[PASS] guard-check-executor-allow" "$out"
  assert_contains "phase3b-guard-block" "[PASS] guard-check-executor-block" "$out"
}

test_phase3b_brief_validate() {
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3b-legacy-reject" "[PASS] brief-validate-legacy-reject"     "$out"
  assert_contains "phase3b-none-reject"   "[PASS] brief-validate-none-codex-reject" "$out"
  assert_contains "phase3b-valid-brief"   "[PASS] brief-validate-valid"             "$out"
}

# ── Phase 3c: v0.7.0 feature smoke ───────────────────────────────────────────
# Verifies that Phase 3c records appear in --no-suite output and that the
# memory-source, doctor, artifacts-list, and pre-release-audit smoke cases pass.

test_phase3c_memory_source() {
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3c-memory-source" "[PASS] context-memory-source" "$out"
}

test_phase3c_memory_doctor() {
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3c-memory-doctor" "[PASS] memory-doctor" "$out"
}

test_phase3c_artifacts_list() {
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3c-artifacts-list" "[PASS] artifacts-list" "$out"
}

test_phase3c_pre_release_audit() {
  rv_no_suite_once
  local out="$RV_NO_SUITE_OUT" rc="$RV_NO_SUITE_RC"
  assert_contains "phase3c-pre-release-audit" "[PASS] pre-release-audit" "$out"
}

# ── Live-db isolation guard ─────────────────────────────────────────────────
# Every RV invocation above targets CONTEXT_FIXTURE_REPO, never REPO_ROOT
# directly. Run this last so it observes the cumulative effect of the whole
# suite, not just one call.

test_context_smoke_targets_fixture_repo() {
  local name="context-smoke-targets-fixture-repo"
  # Phase 3 indexes CONTEXT_SMOKE_REPO. If the redirect failed, that work landed
  # in REPO_ROOT and the fixture DB was never built — so the fixture's own DB is
  # positive, self-owned evidence that the redirect held. Reading the live DB
  # instead would report on every process on this machine, not on this suite.
  if [[ "$CONTEXT_FIXTURE_REPO" == "$REPO_ROOT" ]]; then
    fail "$name" "fixture repo is REPO_ROOT — the redirect is not isolating anything"
    return
  fi
  if [[ ! -s "$CONTEXT_FIXTURE_REPO/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "Phase 3 built no DB under the fixture repo ($CONTEXT_FIXTURE_REPO) — the smoke target was not redirected away from $LIVE_DB"
    return
  fi
  pass "$name"
}

# ── Run ───────────────────────────────────────────────────────────────────────

test_help_contains_usage
test_help_no_code_leak
test_help_exits_0
test_help_short
test_release_suite_verifies_state_bound_artifact
test_release_phase1_runs_evidence_inventory_lints
test_release_phase1_rejects_shellcheck_version_drift
test_release_e2e_keeps_full_and_excludes_affected_phase
test_unknown_flag
test_adapter_missing_value
test_adapter_invalid
test_opencode_adapter_is_accepted
test_adapter_enum_rejects_invalid_and_symlinked_manifest
test_adapter_enum_expected_values
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
test_phase3_default_target_is_own_repo_root
test_phase3b_adapter_manifests
test_phase3b_guard_check
test_phase3b_brief_validate
test_phase3c_memory_source
test_phase3c_memory_doctor
test_phase3c_artifacts_list
test_phase3c_pre_release_audit
test_native_windows_refused
test_context_smoke_targets_fixture_repo

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
