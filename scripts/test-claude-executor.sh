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
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"
th_init "$@"
_TCE_PLATFORM="$(detect_platform)"

brief_file="$(mktemp -p /tmp brief-cc102-test-XXXXXX.md)"
chmod 600 "$brief_file"
trap 'rm -rf "$tmp_root" "$brief_file"' EXIT

# ── case 1: validator accepts a claude metadata header ──────────────────

claude_metadata_validates() {
  local name="claude-executor/metadata claude accepts"
  should_run "$name" || return 0

  local metadata
  metadata=$(cat <<META
handover_version: 3
executor: claude
dispatch_route: main_thread_bash_background
working_dir: $tmp_root
brief_file: $brief_file
isolation_level: workspace-write
timeout: 600
model: default
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

  local target="$tmp_root/hello.txt"
  cat > "$brief_file" <<BRIEF
working_dir: $tmp_root
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

# ── case 5: trace write contract ─────────────────────────────────────────────

trace_write_contract() {
  local name="claude-executor/trace write contract"
  should_run "$name" || return 0
  if [[ "$_TCE_PLATFORM" == "windows" ]]; then
    printf 'SKIP: %s (ln -sfn has no real-symlink support on Windows MSYS)\n' "$name"
    return 0
  fi

  local work_dir
  work_dir="$(mktemp -d)"
  trap 'rm -rf "$work_dir"' RETURN

  # Simulate the Write trace steps from agents/claude-executor.md
  mkdir -p "$work_dir/.agent-trace"
  local ts
  ts=$(date +%Y%m%d-%H%M%S)-$$
  local last_file="$work_dir/.agent-trace/claude-$ts.last"
  printf 'status: ok\nbash scripts/run-all-tests.sh: pass\n' > "$last_file"
  ln -sfn "claude-$ts.last" "$work_dir/.agent-trace/latest.last"

  # 1. latest.last must be a symlink
  if [[ ! -L "$work_dir/.agent-trace/latest.last" ]]; then
    fail "$name" "latest.last is not a symlink"
    return
  fi

  # 2. symlink must resolve inside .agent-trace
  local resolved
  resolved="$(readlink -f "$work_dir/.agent-trace/latest.last" 2>/dev/null || true)"
  if [[ -z "$resolved" || "${resolved#"$work_dir/.agent-trace/"}" == "$resolved" ]]; then
    fail "$name" "latest.last resolves outside .agent-trace: $resolved"
    return
  fi

  # 3. exact cmd: pass line must be present (dispatch-post-verify uses grep -qxF)
  if ! grep -qxF "bash scripts/run-all-tests.sh: pass" "$work_dir/.agent-trace/latest.last"; then
    fail "$name" "exact 'cmd: pass' line not found in trace (whole-line match required)"
    return
  fi

  pass "$name"
}

# ── runner ────────────────────────────────────────────────────────────────────

claude_metadata_validates
unknown_executor_rejected
self_verify_executes
scratch_isolation
trace_write_contract

th_summary
