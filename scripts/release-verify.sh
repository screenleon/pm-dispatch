#!/usr/bin/env bash
# release-verify.sh — pre-release verification orchestrator for pm-dispatch.
#
# Runs every automated verification phase in one shot and prints a per-phase
# PASS/FAIL table plus a final GO / NO-GO verdict.
#
# Usage:
#   scripts/release-verify.sh [--no-suite] [--e2e] [--adapter claude|codex|auto] [--help]
#
#   --no-suite        Skip run-all-tests.sh (fast iteration only; NEVER skip
#                     for an actual release sign-off).
#   --e2e             Also run Phase 4: real dispatch + pr-gate via
#                     test-e2e.sh. Spends LLM tokens. Required for release.
#   --adapter <a>     Executor for --e2e (default: auto — codex if on PATH,
#                     else claude).
#
# Exit status: 0 = GO (all phases passed), 1 = NO-GO (one or more failed),
#              2 = usage error, 3 = PARTIAL GO (required phases skipped, no failures).
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# Temp files — declared upfront so the EXIT trap can always clean them safely.
suite_log=""
smoke_state=""
smoke_err=""
e2e_log=""
cleanup() {
  rm -f "$suite_log" "$smoke_err" "$e2e_log" 2>/dev/null || true
  if [[ -n "$smoke_state" ]]; then rm -rf "$smoke_state" 2>/dev/null || true; fi
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
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'release-verify: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

case "$E2E_ADAPTER" in
  claude|codex|auto) ;;
  *) printf 'release-verify: --adapter must be claude|codex|auto (got: %s)\n' "$E2E_ADAPTER" >&2; exit 2 ;;
esac

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
  if bash "$SCRIPT_DIR/run-all-tests.sh" >"$suite_log" 2>&1; then
    record "run-all-tests" PASS "$(tail -1 "$suite_log")"
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
# feature (pmctl context) against the REAL repo with the REAL sqlite3 binary,
# in a throwaway state root (no pollution).
section "Phase 3 — Real-binary feature smoke (pmctl context on this repo)"
if [[ ! -x "$PMCTL" ]]; then
  record "context smoke" SKIP "pmctl not found or not executable: $PMCTL"
elif ! command -v sqlite3 >/dev/null 2>&1; then
  record "context smoke" SKIP "sqlite3 missing — cannot exercise context"
else
  smoke_state="$(mktemp -d)"  # registered in cleanup trap above
  smoke_err="$(mktemp)"       # registered in cleanup trap above
  if (
    export PM_DISPATCH_STATE_ROOT="$smoke_state"
    set -eo pipefail
    "$PMCTL" context index "$REPO_ROOT" >/dev/null 2>"$smoke_err"
    # Incremental re-index must skip (proves mtime-skip works on this platform).
    "$PMCTL" context index "$REPO_ROOT" 2>>"$smoke_err" | grep -qE '0 indexed, [0-9]+ skipped'
  ); then
    # A query for a known repo symbol should return at least one clean ref.
    q="$(PM_DISPATCH_STATE_ROOT="$smoke_state" "$PMCTL" context query "$REPO_ROOT" pmctl_context_index 2>/dev/null || true)"
    if printf '%s' "$q" | grep -q 'ref: ' && ! printf '%s' "$q" | grep -q $'\r'; then
      record "context index+skip+query" PASS "index, incremental skip, and clean-ref query all OK"
    else
      record "context index+skip+query" FAIL "query returned no clean ref (got: $(printf '%s' "$q" | head -1))"
    fi
    # pack + reuse-scan are the v0.5.0 index consumers.
    if PM_DISPATCH_STATE_ROOT="$smoke_state" "$PMCTL" context pack "$REPO_ROOT" --task-id REL-SMOKE --query dispatch >/dev/null 2>&1; then
      record "context pack" PASS "context-pack assembled"
    else
      record "context pack" FAIL "pmctl context pack failed"
    fi
    if PM_DISPATCH_STATE_ROOT="$smoke_state" "$PMCTL" context reuse-scan "$REPO_ROOT" "dispatch a brief to an executor" >/dev/null 2>&1; then
      record "context reuse-scan" PASS "reuse-scan emitted candidates"
    else
      record "context reuse-scan" FAIL "pmctl context reuse-scan failed"
    fi
  else
    record "context index+skip+query" FAIL "index/skip failed: $(tail -1 "$smoke_err")"
  fi
  rm -rf "$smoke_state"; smoke_state=""
  rm -f "$smoke_err"; smoke_err=""
fi

# ── Phase 4: Real E2E (optional — requires --e2e) ────────────────────────────
if [[ "$RUN_E2E" -eq 1 ]]; then
  section "Phase 4 — Real E2E (pmctl dispatch + pr-gate)"
  e2e_script="${PM_RELEASE_VERIFY_E2E_SCRIPT:-$SCRIPT_DIR/test-e2e.sh}"
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
