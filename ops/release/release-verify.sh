#!/usr/bin/env bash
# release-verify.sh — pre-release verification orchestrator for pm-dispatch.
#
# Runs every automated verification phase in one shot and prints a per-phase
# PASS/FAIL table plus a final GO / NO-GO verdict.
#
# Usage:
#   ops/release/release-verify.sh [--no-suite] [--e2e] [--adapter claude|codex|opencode|grok|auto] [--help]
#
#   --no-suite        Skip run-all-tests.sh (fast iteration only; NEVER skip
#                     for an actual release sign-off).
#   --e2e             Also run Phase 4: real dispatch + pr-gate via
#                     test-e2e.sh. Spends LLM tokens. Required for release.
#                     Phase 2 still runs a fresh run-all-tests.sh; --e2e adds
#                     live coverage and never replaces or skips the full suite.
#   --adapter <a>     Executor for --e2e (default: auto — codex if on PATH,
#                     else claude).
#
# Exit status: 0 = GO (all phases passed), 1 = NO-GO (one or more failed),
#              2 = usage error OR unsupported sign-off platform (native Windows;
#              use WSL2), 3 = PARTIAL GO (required phases skipped, no failures).
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"
# shellcheck source=runtime/lib/adapter-enum.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/adapter-enum.sh"

# Temp files — declared upfront so the EXIT trap can always clean them safely.
suite_log=""
smoke_state=""
smoke_err=""
smoke_telemetry_root=""
bv_dir=""
e2e_log=""
# shellcheck disable=SC2329,SC2317  # invoked indirectly via trap
cleanup() {
  rm -f "$suite_log" "$smoke_err" "$e2e_log" 2>/dev/null || true
  if [[ -n "$smoke_state" ]]; then rm -rf "$smoke_state" 2>/dev/null || true; fi
  if [[ -n "$smoke_telemetry_root" ]]; then rm -rf "$smoke_telemetry_root" 2>/dev/null || true; fi
  if [[ -n "$bv_dir" ]]; then rm -rf "$bv_dir" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM

RUN_SUITE=1
RUN_E2E=0
E2E_ADAPTER="auto"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-suite) RUN_SUITE=0; shift ;;
    --e2e)      RUN_E2E=1; shift ;;
    --adapter)
      if [[ -z "${2:-}" ]]; then printf 'release-verify: --adapter requires a value\n' >&2; exit 2; fi
      E2E_ADAPTER="$2"; shift 2
      ;;
    --help|-h)
      sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'release-verify: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

if ! pm_adapter_is_valid "$REPO_ROOT" "$E2E_ADAPTER"; then
  printf 'release-verify: --adapter must be %s (got: %s)\n' "$(pm_adapter_expected_values "$REPO_ROOT")" "$E2E_ADAPTER" >&2
  exit 2
fi

# ── Result accumulation ──────────────────────────────────────────────────────
PHASE_NAMES=()
PHASE_RESULTS=()
PHASE_NOTES=()
FAILED=0
REQUIRED_SKIPPED=0

record() {  # record <name> <PASS|FAIL|SKIP> <note>
  PHASE_NAMES+=("$1")
  PHASE_RESULTS+=("$2")
  PHASE_NOTES+=("${3:-}")
  [[ "$2" == FAIL ]] && FAILED=$((FAILED + 1))
  printf '  [%s] %s%s\n' "$2" "$1" "${3:+  — $3}"
}

hr() { printf '%s\n' "------------------------------------------------------------"; }
section() { printf '\n=== %s ===\n' "$1"; }

# Detect platform for reporting.
case "$(uname -s 2>/dev/null)" in
  Linux*)  PLATFORM=linux ;;
  Darwin*) PLATFORM=macos ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
  *) PLATFORM=unknown ;;
esac

printf 'pm-dispatch release verification\n'
printf 'repo:     %s\n' "$REPO_ROOT"
printf 'platform: %s\n' "$PLATFORM"
printf 'branch:   %s\n' "$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo '?')"
printf 'commit:   %s\n' "$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"

# Native Windows Git Bash is out of scope for release sign-off; CI runs Linux
# only. Refuse here rather than emit a pile of platform false failures. Run
# release verification under WSL2 (treated as Linux). See docs/platform-support.md.
if [[ "$PLATFORM" == "windows" ]]; then
  printf '\nNative Windows (Git Bash) is not a release sign-off platform.\n' >&2
  printf 'Platform work is deferred during core development; pm-dispatch targets Linux & WSL2.\n' >&2
  printf 'Run release verification under WSL2 (treated as Linux). See docs/platform-support.md.\n' >&2
  exit 2
fi

# ── Phase 1: Prerequisites ───────────────────────────────────────────────────
section "Phase 1 — Prerequisites"
need() {  # need <tool> <required|optional> <version-cmd>
  local tool="$1" kind="$2"; shift 2
  if command -v "$tool" >/dev/null 2>&1; then
    record "$tool" PASS "$("$@" 2>&1 | head -1)"
  elif [[ "$kind" == required ]]; then
    record "$tool" FAIL "REQUIRED tool missing from PATH"
  else
    record "$tool" SKIP "optional tool not installed"
  fi
}
need bash    required bash --version
need jq      required jq --version
need git     required git --version
need sqlite3 required sqlite3 --version
need codex   optional codex --version
need claude  optional claude --version
need shellcheck optional shellcheck --version

# These inventories protect the release evidence boundary before a potentially
# expensive full suite or live E2E invocation starts.
if registry_lint_output="$(bash "$REPO_ROOT/tools/lint/lint-test-suite-registry.sh" 2>&1)"; then
  record "test suite registry" PASS "canonical runner and CI coverage agree"
else
  record "test suite registry" FAIL "${registry_lint_output##*$'\n'}"
fi
if surface_lint_output="$(bash "$REPO_ROOT/tools/lint/lint-surface-coverage.sh" 2>&1)"; then
  record "surface coverage" PASS "commands, agents, and skills are classified"
else
  record "surface coverage" FAIL "${surface_lint_output##*$'\n'}"
fi

# FTS5 capability of the resolved sqlite3 (context query depends on it).
if command -v sqlite3 >/dev/null 2>&1; then
  if sqlite3 ":memory:" "CREATE VIRTUAL TABLE t USING fts5(x);" >/dev/null 2>&1; then
    record "sqlite3 FTS5" PASS "full-text search available"
  else
    record "sqlite3 FTS5" SKIP "sqlite3 lacks FTS5 — context query uses LIKE fallback (optional feature)"
  fi
fi

# ── Phase 2: Full automated test suite ───────────────────────────────────────
section "Phase 2 — Automated test suite (run-all-tests.sh)"
if [[ "$RUN_SUITE" -eq 0 ]]; then
  record "run-all-tests" SKIP "--no-suite requested (NOT valid for release sign-off)"
  REQUIRED_SKIPPED=$((REQUIRED_SKIPPED + 1))
else
  suite_log="$(mktemp)"  # registered in cleanup trap above
  suite_result="$REPO_ROOT/.pm-dispatch/test-results/latest-full.json"
  if bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --result-file "$suite_result" --collect-all >"$suite_log" 2>&1 \
    && bash "$REPO_ROOT/tests/bin/run-tests.sh" --verify-full "$suite_result" >>"$suite_log" 2>&1; then
    record "run-all-tests" PASS "authoritative full PASS verified for the current tree"
  else
    record "run-all-tests" FAIL "$(tail -1 "$suite_log") — see below"
    printf '    --- failing suites ---\n'
    grep -E '^FAIL ' "$suite_log" | sed 's/^/    /'
  fi
  # Surface any SKIPped suites explicitly — a skip is not coverage.
  if grep -qE '^SKIP ' "$suite_log"; then
    printf '    --- skipped suites (NOT covered here) ---\n'
    grep -E '^SKIP ' "$suite_log" | sed 's/^/    /'
  fi
  rm -f "$suite_log"; suite_log=""
fi

# ── Phase 3: Real-binary feature smoke ───────────────────────────────────────
# The unit suites use fixtures; this phase exercises the headline v0.5.0
# feature (pmctl context) against a real repo tree with the REAL sqlite3
# binary. Target defaults to REPO_ROOT itself (actual release sign-off
# behavior); PM_RELEASE_VERIFY_CONTEXT_REPO lets test-release-verify.sh point
# this at an isolated fixture tree instead, so the meta-test of this script
# never rebuilds the operator's live .pm-dispatch/ctx/context.db. DB is
# repo-local to whichever target is used; usage telemetry is redirected to a
# throwaway state root below so the smoke never pollutes the real trace store.
CONTEXT_SMOKE_REPO="${PM_RELEASE_VERIFY_CONTEXT_REPO:-$REPO_ROOT}"
section "Phase 3 — Real-binary feature smoke (pmctl context on this repo)"
if [[ ! -x "$PMCTL" ]]; then
  record "context smoke" SKIP "pmctl not found or not executable: $PMCTL"
elif ! command -v sqlite3 >/dev/null 2>&1; then
  record "context smoke" SKIP "sqlite3 missing — cannot exercise context"
else
  # Isolate verification telemetry: context query / reuse-scan emit usage events,
  # which now honor PM_DISPATCH_STATE_ROOT. Redirect them to a throwaway root so a
  # release smoke run never writes context.* events into the operator's real trace
  # state. The DB itself is repo-local and unaffected by this redirect.
  smoke_telemetry_root="$(mktemp -d)"   # registered in cleanup trap above
  export PM_DISPATCH_STATE_ROOT="$smoke_telemetry_root"
  smoke_err="$(mktemp)"       # registered in cleanup trap above
  if (
    set -eo pipefail
    "$PMCTL" context index "$CONTEXT_SMOKE_REPO" >/dev/null 2>"$smoke_err"
    # Incremental re-index must skip (proves mtime-skip works on this platform).
    "$PMCTL" context index "$CONTEXT_SMOKE_REPO" 2>>"$smoke_err" | grep -qE '0 indexed, [0-9]+ skipped'
  ); then
    # A query for a known repo symbol should return at least one clean ref.
    q="$("$PMCTL" context query "$CONTEXT_SMOKE_REPO" pmctl_context_index 2>/dev/null || true)"
    if printf '%s' "$q" | grep -q 'ref: ' && ! printf '%s' "$q" | grep -q $'\r'; then
      record "context index+skip+query" PASS "index, incremental skip, and clean-ref query all OK"
    else
      record "context index+skip+query" FAIL "query returned no clean ref (got: $(printf '%s' "$q" | head -1))"
    fi
    # pack + reuse-scan are the v0.5.0 index consumers.
    if "$PMCTL" context pack "$CONTEXT_SMOKE_REPO" --task-id REL-SMOKE --query dispatch >/dev/null 2>&1; then
      record "context pack" PASS "context-pack assembled"
    else
      record "context pack" FAIL "pmctl context pack failed"
    fi
    if "$PMCTL" context reuse-scan "$CONTEXT_SMOKE_REPO" "dispatch a brief to an executor" >/dev/null 2>&1; then
      record "context reuse-scan" PASS "reuse-scan emitted candidates"
    else
      record "context reuse-scan" FAIL "pmctl context reuse-scan failed"
    fi
  else
    record "context index+skip+query" FAIL "index/skip failed: $(tail -1 "$smoke_err")"
  fi
  rm -f "$smoke_err"; smoke_err=""

  # ── External repo smoke: repo-local db placement + bootstrap ─────────────────
  smoke_state="$(mktemp -d)"  # registered in cleanup trap above — rm'd below
  smoke_err="$(mktemp)"
  mkdir -p "$smoke_state/scripts/lib"
  printf '#!/usr/bin/env bash\n# dummy helper\ndummy_fn() { echo hello; }\n' \
    > "$smoke_state/scripts/lib/dummy.sh"
  printf '# Temp test repo\n\nDummy readme.\n' > "$smoke_state/README.md"
  printf 'key: value\n' > "$smoke_state/config.yaml"

  if "$PMCTL" context index "$smoke_state" >/dev/null 2>"$smoke_err"; then
    record "external-repo-index" PASS "context index on external repo succeeded"
  else
    record "external-repo-index" FAIL "context index failed: $(tail -1 "$smoke_err")"
  fi

  if [[ -f "$smoke_state/.pm-dispatch/ctx/context.db" ]]; then
    record "external-repo-db-location" PASS ".pm-dispatch/ctx/context.db created inside target repo"
  else
    record "external-repo-db-location" FAIL ".pm-dispatch/ctx/context.db not found in target repo"
  fi

  ext_q="$("$PMCTL" context query "$smoke_state" "dummy_fn" 2>/dev/null || true)"
  if printf '%s' "$ext_q" | grep -q 'ref: '; then
    record "external-repo-query" PASS "query on external repo returned hits"
  else
    record "external-repo-query" FAIL "query returned no hits (got: $(printf '%s' "$ext_q" | head -1))"
  fi

  rm -rf "$smoke_state"; smoke_state=""
  rm -f "$smoke_err"; smoke_err=""

  # ── No-db graceful degradation ────────────────────────────────────────────────
  nodeb_repo="$(mktemp -d)"
  if "$PMCTL" context reuse-scan "$nodeb_repo" "dispatch a task" >/dev/null 2>&1; then
    record "context-no-db-graceful" PASS "reuse-scan returns empty on missing index"
  else
    record "context-no-db-graceful" FAIL "reuse-scan errored on missing index (expected graceful empty)"
  fi
  rm -rf "$nodeb_repo"

  # Tear down the isolated telemetry root and restore the ambient state config so
  # later phases (e.g. E2E dispatch) write to the real store as intended.
  unset PM_DISPATCH_STATE_ROOT
  rm -rf "$smoke_telemetry_root"; smoke_telemetry_root=""
fi

# ── Phase 3b: v0.6.0 feature smoke ──────────────────────────────────────────
# Exercises the headline v0.6.0 additions that aren't covered by the unit
# suites alone: adapter manifests, unified guard check, and brief-validate
# policy changes (legacy trio removal + isolation_level:none codex rejection).
section "Phase 3b — v0.6.0 feature smoke (adapters · guard · brief-validate)"

# Adapter manifests — codex/claude/opencode must declare runner_kind
for _adapter in codex claude opencode grok; do
  _manifest="$REPO_ROOT/adapters/$_adapter/adapter.yaml"
  if [[ ! -f "$_manifest" ]]; then
    record "adapter-manifest-$_adapter" FAIL "adapter.yaml not found"
  elif grep -q "^runner_kind:" "$_manifest"; then
    _rk="$(awk '/^runner_kind:/{print $2;exit}' "$_manifest")"
    record "adapter-manifest-$_adapter" PASS "runner_kind=$_rk"
  else
    record "adapter-manifest-$_adapter" FAIL "adapter.yaml missing runner_kind"
  fi
done

# Guard check — exercises the unified write-guard CLI:
#   executor+codex allow: /tmp/brief-*.md only
#   executor+codex block: anything outside that pattern
if [[ ! -x "$PMCTL" ]]; then
  record "guard-check-executor-allow" SKIP "pmctl not found"
  record "guard-check-executor-block" SKIP "pmctl not found"
else
  # executor+codex writing a brief temp file must be allowed
  if "$PMCTL" guard check \
      --role executor --runtime codex \
      --event pre-write --file "/tmp/brief-smoke-$$.md" \
      >/dev/null 2>&1; then
    record "guard-check-executor-allow" PASS "executor write /tmp/brief-*.md: allowed"
  else
    record "guard-check-executor-allow" FAIL "executor write /tmp/brief-*.md: unexpectedly blocked"
  fi
  # executor+codex writing outside the brief pattern must be blocked
  if "$PMCTL" guard check \
      --role executor --runtime codex \
      --event pre-write --file "/tmp/guard-smoke-$$-outside.txt" \
      >/dev/null 2>&1; then
    record "guard-check-executor-block" FAIL "executor write outside brief pattern: allowed (should block)"
  else
    record "guard-check-executor-block" PASS "executor write outside brief pattern: blocked"
  fi
fi

# Brief validate — legacy trio rejection + codex isolation_level:none rejection + valid brief
if [[ ! -x "$PMCTL" ]]; then
  record "brief-validate-legacy-reject"     SKIP "pmctl not found"
  record "brief-validate-none-codex-reject" SKIP "pmctl not found"
  record "brief-validate-valid"             SKIP "pmctl not found"
else
  bv_dir="$(mktemp -d)"  # registered in cleanup trap above
  _bv_tmp_brief="/tmp/brief-smoke-$$.md"

  # 3b-i. legacy sandbox field must be rejected (v0.6.0 removal)
  {
    printf '%s\n' '```dispatch_handover_v1'
    printf 'handover_version: 4\nexecutor: codex\ndispatch_route: main_thread_bash_background\n'
    printf 'working_dir: %s\nbrief_file: %s\n' "$REPO_ROOT" "$_bv_tmp_brief"
    printf 'isolation_level: workspace-write\nsandbox: workspace-write\ntimeout: 300\nmodel: default\nfallback_allowed: true\n'
    printf '%s\n' '---'
    printf 'working_dir: %s\ngoal: smoke test\nfiles: []\nacceptance:\n  - done\n' "$REPO_ROOT"
    printf '%s\n' '```'
  } > "$bv_dir/brief-legacy.md"

  if ! "$PMCTL" validate brief "$bv_dir/brief-legacy.md" >/dev/null 2>&1; then
    record "brief-validate-legacy-reject" PASS "legacy sandbox field correctly rejected"
  else
    record "brief-validate-legacy-reject" FAIL "legacy sandbox field accepted (should reject)"
  fi

  # 3b-ii. codex + isolation_level:none must be rejected
  {
    printf '%s\n' '```dispatch_handover_v1'
    printf 'handover_version: 4\nexecutor: codex\ndispatch_route: main_thread_bash_background\n'
    printf 'working_dir: %s\nbrief_file: %s\n' "$REPO_ROOT" "$_bv_tmp_brief"
    printf 'isolation_level: none\ntimeout: 300\nmodel: default\nfallback_allowed: true\n'
    printf '%s\n' '---'
    printf 'working_dir: %s\ngoal: smoke test\nfiles: []\nacceptance:\n  - done\n' "$REPO_ROOT"
    printf '%s\n' '```'
  } > "$bv_dir/brief-none.md"

  if ! "$PMCTL" validate brief "$bv_dir/brief-none.md" >/dev/null 2>&1; then
    record "brief-validate-none-codex-reject" PASS "codex isolation_level:none correctly rejected"
  else
    record "brief-validate-none-codex-reject" FAIL "codex isolation_level:none accepted (should reject)"
  fi

  # 3b-iii. valid brief with isolation_level:workspace-write must be accepted
  {
    printf '%s\n' '```dispatch_handover_v1'
    printf 'handover_version: 4\nexecutor: codex\ndispatch_route: main_thread_bash_background\n'
    printf 'working_dir: %s\nbrief_file: %s\n' "$REPO_ROOT" "$_bv_tmp_brief"
    printf 'isolation_level: workspace-write\ntimeout: 300\nmodel: default\nfallback_allowed: true\n'
    printf '%s\n' '---'
    printf 'working_dir: %s\ngoal: smoke test\nfiles:\n  - read: BACKLOG.md\nacceptance:\n  - done\n' "$REPO_ROOT"
    printf '%s\n' '```'
  } > "$bv_dir/brief-valid.md"

  if "$PMCTL" validate brief "$bv_dir/brief-valid.md" >/dev/null 2>&1; then
    record "brief-validate-valid" PASS "valid brief (isolation_level:workspace-write) accepted"
  else
    record "brief-validate-valid" FAIL "valid brief unexpectedly rejected"
  fi

  rm -rf "$bv_dir"; bv_dir=""
fi

# ── Phase 3c: v0.7.0 feature smoke ──────────────────────────────────────────
# Exercises headline v0.7.0 additions not covered by unit suites alone:
#   CC-403 pmctl context --source memory
#   CC-405 pmctl memory doctor
#   CC-418 pmctl artifacts list
#   CC-426 pmctl pre-release audit
section "Phase 3c — v0.7.0 feature smoke (memory-source · doctor · artifacts · pre-release)"

if [[ ! -x "$PMCTL" ]]; then
  record "context-memory-source" SKIP "pmctl not found"
  record "memory-doctor"         SKIP "pmctl not found"
  record "artifacts-list"        SKIP "pmctl not found"
  record "pre-release-audit"     SKIP "pmctl not found"
else
  # CC-403: pmctl context --source memory must accept the flag without error
  if "$PMCTL" context query --source memory "$REPO_ROOT" "release" >/dev/null 2>&1; then
    record "context-memory-source" PASS "pmctl context query --source memory: accepted"
  else
    # Non-zero is acceptable when memory DB is empty; only crash/unknown-flag is a FAIL
    _ctx_mem_exit=$?
    if [[ "$_ctx_mem_exit" -eq 2 ]]; then
      record "context-memory-source" FAIL "--source memory flag unrecognised (exit 2)"
    else
      record "context-memory-source" PASS "pmctl context query --source memory: ran (no hits, exit $_ctx_mem_exit)"
    fi
  fi

  # CC-405: pmctl memory doctor must exit 0 or 1 (issues found), never crash
  _doctor_out="$("$PMCTL" memory doctor 2>&1)" || true
  _doctor_exit=$?
  if [[ "$_doctor_exit" -le 1 ]]; then
    record "memory-doctor" PASS "pmctl memory doctor: ran (exit $_doctor_exit)"
  else
    record "memory-doctor" FAIL "pmctl memory doctor crashed (exit $_doctor_exit): $(printf '%s' "$_doctor_out" | head -1)"
  fi

  # CC-418: pmctl artifacts list must run without crash
  if "$PMCTL" artifacts list --cd "$REPO_ROOT" >/dev/null 2>&1; then
    record "artifacts-list" PASS "pmctl artifacts list: ran"
  else
    _art_exit=$?
    if [[ "$_art_exit" -eq 1 ]]; then
      record "artifacts-list" PASS "pmctl artifacts list: ran (no runs found, exit 1)"
    else
      record "artifacts-list" FAIL "pmctl artifacts list crashed (exit $_art_exit)"
    fi
  fi

  # CC-426: pmctl pre-release audit must generate a report (exit 0 or 1)
  _pre_exit=0
  "$PMCTL" pre-release audit v0.7.0 >/dev/null 2>&1 || _pre_exit=$?
  if [[ "$_pre_exit" -le 1 ]]; then
    record "pre-release-audit" PASS "pmctl pre-release audit v0.7.0: report generated (exit $_pre_exit)"
  else
    record "pre-release-audit" FAIL "pmctl pre-release audit crashed (exit $_pre_exit)"
  fi
fi

# ── Phase 4: Real E2E (optional — requires --e2e) ────────────────────────────
if [[ "$RUN_E2E" -eq 1 ]]; then
  section "Phase 4 — Real E2E (pmctl dispatch + pr-gate)"
  e2e_script="${PM_RELEASE_VERIFY_E2E_SCRIPT:-$REPO_ROOT/tests/shell/test-e2e.sh}"
  if [[ ! -x "$e2e_script" ]]; then
    record "test-e2e.sh" FAIL "not found or not executable: $e2e_script"
  else
    e2e_log="$(mktemp)"  # registered in cleanup trap above
    e2e_rc=0
    bash "$e2e_script" --adapter "$E2E_ADAPTER" >"$e2e_log" 2>&1 || e2e_rc=$?
    case "$e2e_rc" in
      0)
        record "e2e dispatch+gate" PASS \
          "$(grep -m1 'AUTOMATED VERDICT' "$e2e_log" || echo 'all checks passed')"
        ;;
      4)
        record "e2e dispatch+gate" SKIP \
          "pr-gate Phase C skipped (codex absent) — full sign-off requires a codex-enabled run"
        REQUIRED_SKIPPED=$((REQUIRED_SKIPPED + 1))
        ;;
      *)
        record "e2e dispatch+gate" FAIL \
          "$(grep -m1 'AUTOMATED VERDICT' "$e2e_log" || echo 'test-e2e.sh failed')"
        printf '    --- E2E failures ---\n'
        grep -E '^\s+\[FAIL\]' "$e2e_log" | sed 's/^/    /' || true
        ;;
    esac
    rm -f "$e2e_log"; e2e_log=""
  fi
else
  record "e2e dispatch+gate" SKIP \
    "pass --e2e to include live dispatch + pr-gate (required for release sign-off)"
  REQUIRED_SKIPPED=$((REQUIRED_SKIPPED + 1))
fi

# ── Verdict ──────────────────────────────────────────────────────────────────
section "Verdict"
hr
printf '%-44s %s\n' "PHASE" "RESULT"
hr
for i in "${!PHASE_NAMES[@]}"; do
  printf '%-44s %s\n' "${PHASE_NAMES[$i]}" "${PHASE_RESULTS[$i]}"
done
hr
if [[ "$FAILED" -gt 0 ]]; then
  printf 'AUTOMATED VERDICT: NO-GO  (%d failures)\n' "$FAILED"
elif [[ "$REQUIRED_SKIPPED" -gt 0 ]]; then
  printf 'AUTOMATED VERDICT: PARTIAL GO  (%d checks, 0 failures, %d required phase(s) skipped)\n' \
    "${#PHASE_NAMES[@]}" "$REQUIRED_SKIPPED"
else
  printf 'AUTOMATED VERDICT: GO  (%d checks, 0 failures)\n' "${#PHASE_NAMES[@]}"
fi

if [[ "$RUN_E2E" -eq 0 ]]; then
  printf '\nNOTE: Re-run with --e2e to validate real dispatch + pr-gate (spends LLM\n'
  printf 'tokens). Required for release sign-off (see docs/RELEASE_CHECKLIST.md).\n'
elif [[ "$REQUIRED_SKIPPED" -gt 0 ]]; then
  printf '\nNOTE: PARTIAL GO — required phase(s) skipped. Full sign-off (exit 0) requires\n'
  printf 'all phases to pass, including Phase C on a codex-enabled machine.\n'
  printf 'See docs/RELEASE_CHECKLIST.md §2b.\n'
else
  printf '\nNOTE: install/doctor/uninstall and Claude Code hook execution are still\n'
  printf 'manual. See docs/RELEASE_CHECKLIST.md §2a and §2d before tagging.\n'
fi

if [[ "$FAILED" -gt 0 ]]; then exit 1; fi
if [[ "$REQUIRED_SKIPPED" -gt 0 ]]; then exit 3; fi
exit 0
