#!/usr/bin/env bash
# test-e2e.sh — real-adapter E2E verification for pm-dispatch.
#
# Exercises the ACTUAL dispatch and pr-gate paths against live adapters.
# Spends LLM tokens. Never run in offline CI — call from release-verify.sh
# --e2e or directly before tagging a release.
#
# Validates the OUTPUT CONTRACT (files exist, non-empty, verdict present), NOT
# the LLM content (which is non-deterministic).
#
# Usage:
#   scripts/test-e2e.sh [--adapter claude|codex|auto] [--skip-gate] [--help]
#
#   --adapter <a>  Executor to use. auto (default): codex if on PATH, else claude.
#   --skip-gate    Skip Phase C (pr-gate); useful when no diff vs main exists.
#
# Exit status: 0 = GO (all phases passed), 1 = NO-GO (one or more failed),
#              2 = usage error.
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

ADAPTER="auto"
SKIP_GATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --adapter)
      if [[ -z "${2:-}" ]]; then printf 'test-e2e: --adapter requires a value\n' >&2; exit 2; fi
      ADAPTER="$2"; shift 2
      ;;
    --skip-gate) SKIP_GATE=1; shift ;;
    --help|-h)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'test-e2e: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

case "$ADAPTER" in
  claude|codex|auto) ;;
  *) printf 'test-e2e: --adapter must be claude|codex|auto (got: %s)\n' "$ADAPTER" >&2; exit 2 ;;
esac

# ── Result accumulation (same pattern as release-verify.sh) ──────────────────
PHASE_NAMES=()
PHASE_RESULTS=()
FAILED=0

record() {  # record <name> <PASS|FAIL|SKIP> [note]
  PHASE_NAMES+=("$1")
  PHASE_RESULTS+=("$2")
  [[ "$2" == FAIL ]] && FAILED=$((FAILED + 1))
  printf '  [%s] %s%s\n' "$2" "$1" "${3:+  — $3}"
}
section() { printf '\n=== %s ===\n' "$1"; }
hr()      { printf '%s\n' "------------------------------------------------------------"; }

# ── Temp file cleanup ─────────────────────────────────────────────────────────
brief_file=""
smoke_dir=""
synthetic_base=""
synthetic_remote=""
gate_result=""
e2e_log=""
cleanup() {
  rm -f "$brief_file" "$e2e_log" 2>/dev/null || true
  if [[ -n "$smoke_dir"        ]]; then rm -rf "$smoke_dir"        2>/dev/null || true; fi
  if [[ -n "$synthetic_base"   ]]; then rm -rf "$synthetic_base"   2>/dev/null || true; fi
  if [[ -n "$synthetic_remote" ]]; then rm -rf "$synthetic_remote" 2>/dev/null || true; fi
  if [[ -n "$gate_result"      ]]; then rm -f  "$gate_result"      2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM

# ── Phase A — Prerequisites ───────────────────────────────────────────────────
section "Phase A — Prerequisites"

if [[ "$ADAPTER" == "auto" ]]; then
  if command -v codex >/dev/null 2>&1; then ADAPTER=codex; else ADAPTER=claude; fi
fi

printf 'adapter:  %s\n' "$ADAPTER"
printf 'repo:     %s\n' "$REPO_ROOT"

if ! command -v "$ADAPTER" >/dev/null 2>&1; then
  record "$ADAPTER on PATH" FAIL "not found — install and authenticate $ADAPTER before running E2E"
  section "Verdict"; hr
  printf 'AUTOMATED VERDICT: NO-GO  (missing prerequisite)\n'
  exit 1
fi
record "$ADAPTER on PATH" PASS "$("$ADAPTER" --version 2>&1 | head -1)"

if [[ ! -x "$PMCTL" ]]; then
  record "pmctl" FAIL "not found or not executable: $PMCTL"
  section "Verdict"; hr
  printf 'AUTOMATED VERDICT: NO-GO  (missing prerequisite)\n'
  exit 1
fi
record "pmctl" PASS "ok"

# ── Phase B — Minimal dispatch (output contract) ──────────────────────────────
section "Phase B — Real dispatch (output-contract validation)"

smoke_dir="$(mktemp -d)"
printf 'E2E-SMOKE-INPUT\n' > "$smoke_dir/smoke-input.txt"

# Guard requires /tmp/brief-*.md (hook-claude-write-guard.sh pattern check).
brief_file="/tmp/brief-e2e-smoke-$$.md"
cat > "$brief_file" <<EOF
schema_version: 1
working_dir: $smoke_dir
goal: Read smoke-input.txt and print its first line verbatim to stdout.
files:
  - read: smoke-input.txt
acceptance:
  - printed output includes the exact string "E2E-SMOKE-INPUT"
EOF

e2e_log="$(mktemp)"
dispatch_rc=0
"$PMCTL" dispatch run \
  --adapter "$ADAPTER" \
  --cd "$smoke_dir" \
  --brief-file "$brief_file" \
  >"$e2e_log" 2>&1 || dispatch_rc=$?

if [[ "$dispatch_rc" -eq 0 ]]; then
  record "dispatch exits 0" PASS ""
else
  record "dispatch exits 0" FAIL "exit $dispatch_rc — $(tail -3 "$e2e_log" | tr '\n' ' ')"
fi
rm -f "$e2e_log"; e2e_log=""

trace_dir="$smoke_dir/.agent-trace"

if [[ -f "$trace_dir/latest.last" && -s "$trace_dir/latest.last" ]]; then
  record "latest.last non-empty" PASS ""
else
  record "latest.last non-empty" FAIL "missing or 0-byte: $trace_dir/latest.last"
fi

if [[ -f "$trace_dir/latest.jsonl" && -s "$trace_dir/latest.jsonl" ]]; then
  record "latest.jsonl non-empty" PASS ""
else
  record "latest.jsonl non-empty" FAIL "missing or 0-byte: $trace_dir/latest.jsonl"
fi

# ── Phase C — pr-gate mechanism check (synthetic target) ─────────────────────
# Validates that pr-gate.sh + codex can execute end-to-end and write a non-empty
# result, regardless of the current branch state. Runs against a tiny synthetic
# git repo (local bare remote + feature branch with a one-function diff) so the
# check is always runnable, even on main after a release tag.
#
# IMPORTANT: --executor claude is handover-only (reviewers run outside the
# script in a CC session). Phase C always uses codex; skipped if codex is not
# on PATH.
section "Phase C — pr-gate mechanism check (synthetic target)"

if [[ "$SKIP_GATE" -eq 1 ]]; then
  record "pr-gate smoke (codex)" SKIP "--skip-gate requested"
elif ! command -v codex >/dev/null 2>&1; then
  record "pr-gate smoke (codex)" SKIP \
    "codex not on PATH — claude executor is handover-only (no self-contained run)"
else
  synthetic_remote="$(mktemp -d)"
  synthetic_base="$(mktemp -d)"
  _gate_ok=1

  # Bare local remote — git push/fetch work without any network connection.
  git -C "$synthetic_remote" init --bare -b main >/dev/null 2>&1 || _gate_ok=0

  if [[ "$_gate_ok" -eq 1 ]]; then
    git -C "$synthetic_base" init -b main          >/dev/null 2>&1 || _gate_ok=0
    git -C "$synthetic_base" config user.email "e2e@test.local"    || _gate_ok=0
    git -C "$synthetic_base" config user.name  "E2E Test"          || _gate_ok=0
    git -C "$synthetic_base" remote add origin "$synthetic_remote" || _gate_ok=0
  fi

  if [[ "$_gate_ok" -eq 1 ]]; then
    # Base commit on main.
    cat > "$synthetic_base/calc.sh" <<'SCRIPT'
#!/usr/bin/env bash
add() { echo $(( $1 + $2 )); }
add 1 2
SCRIPT
    git -C "$synthetic_base" add calc.sh                >/dev/null 2>&1 || _gate_ok=0
    git -C "$synthetic_base" commit -m "add calc script" >/dev/null 2>&1 || _gate_ok=0
    git -C "$synthetic_base" push origin main            >/dev/null 2>&1 || _gate_ok=0
  fi

  if [[ "$_gate_ok" -eq 1 ]]; then
    # Feature branch — this one-function diff is what pr-gate reviews.
    git -C "$synthetic_base" checkout -b feature/add-multiply >/dev/null 2>&1 || _gate_ok=0
    cat >> "$synthetic_base/calc.sh" <<'SCRIPT'
multiply() { echo $(( $1 * $2 )); }
multiply 3 4
SCRIPT
    git -C "$synthetic_base" add calc.sh                       >/dev/null 2>&1 || _gate_ok=0
    git -C "$synthetic_base" commit -m "add multiply function"  >/dev/null 2>&1 || _gate_ok=0
  fi

  if [[ "$_gate_ok" -eq 0 ]]; then
    record "pr-gate smoke (codex)" FAIL "failed to initialise synthetic git repo"
  else
    # Output must be an absolute path ending in .gate-results/<file>
    # (reviewer-write-guard policy).
    gate_result="$REPO_ROOT/.gate-results/gate-e2e-smoke-$$.md"
    e2e_log="$(mktemp)"
    gate_rc=0
    "$PMCTL" gate run \
      --cd "$synthetic_base" \
      --executor codex \
      --tier express \
      --base main \
      --output "$gate_result" \
      >"$e2e_log" 2>&1 || gate_rc=$?

    # gate_rc 0 = GO, 1 = NO-GO: both are valid structural outcomes.
    # gate_rc 2+ = usage/fatal error: that is a failure.
    if [[ "$gate_rc" -le 1 ]]; then
      if [[ -s "$gate_result" ]]; then
        verdict="GO"; [[ "$gate_rc" -eq 1 ]] && verdict="NO-GO"
        record "pr-gate smoke (codex)" PASS "gate verdict: $verdict (synthetic diff)"
      else
        record "pr-gate smoke (codex)" FAIL \
          "0-byte result file at $gate_result — check for silent write failure"
      fi
    else
      record "pr-gate smoke (codex)" FAIL \
        "pr-gate.sh exited $gate_rc — $(tail -2 "$e2e_log" | tr '\n' ' ')"
    fi
    rm -f "$e2e_log"; e2e_log=""
  fi
fi

# ── Verdict ───────────────────────────────────────────────────────────────────
section "Verdict"
hr
printf '%-44s %s\n' "PHASE" "RESULT"
hr
for i in "${!PHASE_NAMES[@]}"; do
  printf '%-44s %s\n' "${PHASE_NAMES[$i]}" "${PHASE_RESULTS[$i]}"
done
hr
if [[ "$FAILED" -eq 0 ]]; then
  printf 'AUTOMATED VERDICT: GO  (%d checks, 0 failures)\n' "${#PHASE_NAMES[@]}"
else
  printf 'AUTOMATED VERDICT: NO-GO  (%d failures)\n' "$FAILED"
fi

[[ "$FAILED" -eq 0 ]] && exit 0 || exit 1
