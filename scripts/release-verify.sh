#!/usr/bin/env bash
# release-verify.sh — pre-release verification orchestrator for pm-dispatch.
#
# Runs every SAFE, automated verification phase in one shot and prints a
# per-phase PASS/FAIL table plus a final GO / NO-GO verdict. Side-effect-free:
# it never installs into the real ~/.claude and never spends LLM tokens. The
# environment-mutating and credentialed-E2E checks (real dispatch, reviewer
# fan-out, real install + Claude Code hooks) are MANUAL and live in
# docs/RELEASE_CHECKLIST.md — this script prints a pointer to them at the end.
#
# Usage:
#   scripts/release-verify.sh [--no-suite] [--help]
#
#   --no-suite   Skip the full run-all-tests.sh aggregator (fast iteration only;
#                NEVER skip for an actual release sign-off).
#
# Exit status: 0 = GO (all phases passed), 1 = NO-GO (one or more failed),
#              2 = usage error.
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

RUN_SUITE=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-suite) RUN_SUITE=0; shift ;;
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'release-verify: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

# ── Result accumulation ──────────────────────────────────────────────────────
PHASE_NAMES=()
PHASE_RESULTS=()
PHASE_NOTES=()
FAILED=0

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
    record "sqlite3 FTS5" FAIL "sqlite3 lacks FTS5 — context query falls back to LIKE"
  fi
fi

# ── Phase 2: Full automated test suite ───────────────────────────────────────
section "Phase 2 — Automated test suite (run-all-tests.sh)"
if [[ "$RUN_SUITE" -eq 0 ]]; then
  record "run-all-tests" SKIP "--no-suite requested (NOT valid for release sign-off)"
else
  suite_log="$(mktemp)"
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
  rm -f "$suite_log"
fi

# ── Phase 3: Real-binary feature smoke ───────────────────────────────────────
# The unit suites use fixtures; this phase exercises the headline v0.5.0
# feature (pmctl context) against the REAL repo with the REAL sqlite3 binary,
# in a throwaway state root (no pollution).
section "Phase 3 — Real-binary feature smoke (pmctl context on this repo)"
if ! command -v sqlite3 >/dev/null 2>&1; then
  record "context smoke" SKIP "sqlite3 missing — cannot exercise context"
else
  smoke_state="$(mktemp -d)"
  smoke_err="$(mktemp)"
  (
    export PM_DISPATCH_STATE_ROOT="$smoke_state"
    set -e
    "$PMCTL" context index "$REPO_ROOT" >/dev/null 2>"$smoke_err"
    # Incremental re-index must skip (proves mtime-skip works on this platform).
    "$PMCTL" context index "$REPO_ROOT" 2>>"$smoke_err" | grep -qE '0 indexed, [0-9]+ skipped'
  )
  if [[ $? -eq 0 ]]; then
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
  rm -rf "$smoke_state" "$smoke_err"
fi

# ── Verdict ──────────────────────────────────────────────────────────────────
section "Verdict"
hr
printf '%-32s %s\n' "PHASE" "RESULT"
hr
for i in "${!PHASE_NAMES[@]}"; do
  printf '%-32s %s\n' "${PHASE_NAMES[$i]}" "${PHASE_RESULTS[$i]}"
done
hr
if [[ "$FAILED" -eq 0 ]]; then
  printf 'AUTOMATED VERDICT: GO  (%d checks, 0 failures)\n' "${#PHASE_NAMES[@]}"
else
  printf 'AUTOMATED VERDICT: NO-GO  (%d failures)\n' "$FAILED"
fi
cat <<'EOF'

NOTE: automated phases do NOT cover environment-mutating or credentialed steps.
Before tagging a release you MUST also complete the MANUAL steps in
docs/RELEASE_CHECKLIST.md (real install + doctor, real dispatch on each
executor, /pr-gate reviewer fan-out, Claude Code hook execution), on BOTH
Linux and Windows Git Bash.
EOF

[[ "$FAILED" -eq 0 ]] && exit 0 || exit 1
