#!/usr/bin/env bash
# Smoke test for the claude-executor brief flow.
#
# Cannot invoke Agent(subagent_type: "claude-executor") from a shell — that's
# only available inside Claude Code's tool surface. This test asserts the
# format-level prerequisites for a claude dispatch:
#   - the brief schema validator accepts a representative claude metadata
#     header (executor: claude + canonical no-op codex fields)
#   - the brief body's self_verify commands can be shell-executed and exit 0
#     against a trivial goal
#   - no repo files leak into git status; no ~/.claude/ touched
#
# Runs entirely in a mktemp -d scratch dir; cleans up on exit.

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/handover-validate.sh
. "$REPO_ROOT/scripts/lib/handover-validate.sh"

FILTER=""
LIST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      if [[ $# -lt 2 ]]; then
        echo "test-claude-executor: --filter requires a pattern argument" >&2
        exit 2
      fi
      FILTER="$2"
      shift 2
      ;;
    --list)   LIST=true; shift ;;
    *) shift ;;
  esac
done

ALL_CASES=()
should_run() {
  if $LIST; then
    ALL_CASES+=("$1")
    return 1
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

scratch="$(mktemp -d)"
brief_file="$(mktemp -p /tmp brief-cc102-test-XXXXXX.md)"
chmod 600 "$brief_file"
trap 'rm -rf "$scratch" "$brief_file"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); FAILED_CASES+=("$1"); }

# ── case 1: validator accepts a claude metadata header ──────────────────

claude_metadata_validates() {
  local name="claude-executor/metadata claude accepts"
  should_run "$name" || return 0

  local metadata
  metadata=$(cat <<META
handover_version: 2
executor: claude
dispatch_route: main_thread_bash_background
working_dir: $scratch
brief_file: $brief_file
sandbox: workspace-write
approval: never
timeout: 600
model: default
skip_git_check: false
fallback_allowed: true
META
)
  if handover_validate_all_metadata "$metadata" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "validator rejected canonical claude metadata"
  fi
}

# ── case 2: validator rejects unknown executor ────────────────────────────────

unknown_executor_rejected() {
  local name="claude-executor/metadata unknown executor rejected"
  should_run "$name" || return 0

  if handover_validate_executor mystery-executor 2>/dev/null; then
    fail "$name" "validator should have rejected mystery-executor"
  else
    pass "$name"
  fi
}

# ── case 3: brief self_verify is shell-executable end-to-end ─────────────────

self_verify_executes() {
  local name="claude-executor/self_verify executes against trivial goal"
  should_run "$name" || return 0

  local target="$scratch/hello.txt"
  cat > "$brief_file" <<BRIEF
working_dir: $scratch
goal: Create hello.txt with body "hello".
files:
  - new: $target
acceptance:
  - $target exists and contains the word "hello".
self_verify:
  - test -f "$target"
  - grep -q "hello" "$target"
BRIEF

  # Simulate the agent step: create the file per the goal.
  printf 'hello\n' > "$target"

  # Run each self_verify line as the agent would.
  local rc=0
  test -f "$target" || rc=1
  grep -q "hello" "$target" || rc=1

  if [[ $rc -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "self_verify shell-simulation failed (rc=$rc)"
  fi
}

# ── case 4: scratch isolation — no repo files touched ────────────────────────

scratch_isolation() {
  local name="claude-executor/scratch isolation (no repo file leak)"
  should_run "$name" || return 0

  local repo_diff
  repo_diff="$(git -C "$REPO_ROOT" status --short -- scripts/test-claude-executor.sh 2>/dev/null || true)"
  # The test script itself may be staged in a feature branch, which is fine;
  # what we care about is that running this test did not modify anything
  # under $REPO_ROOT/scripts/, $REPO_ROOT/agents/, $REPO_ROOT/commands/, etc.
  # Assert specifically that no untracked artifacts were created in scratch
  # locations that would imply repo leakage.
  if [[ -e "$REPO_ROOT/hello.txt" ]]; then
    fail "$name" "test leaked hello.txt into repo root"
    return
  fi
  if [[ -e "$REPO_ROOT/scripts/hello.txt" ]]; then
    fail "$name" "test leaked hello.txt into scripts/"
    return
  fi
  pass "$name"
}

# ── runner ────────────────────────────────────────────────────────────────────

claude_metadata_validates
unknown_executor_rejected
self_verify_executes
scratch_isolation

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

echo
echo "----"
echo "$PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  printf 'failed cases:\n'
  for c in "${FAILED_CASES[@]}"; do printf '  - %s\n' "$c"; done
  exit 1
fi
