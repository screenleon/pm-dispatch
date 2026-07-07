#!/usr/bin/env bash
# Regression suite for guard-pm-write.sh,
# guard-executor-write.sh, and guard-reviewer-write.sh.
# Note: guard-reviewer-write.sh is the policy-backing script for
# `pmctl guard check --role reviewer`; it is NOT a PreToolUse hook.
# Its pmctl integration is covered by test-pmctl-guard.sh.
#
# Runs each hook script with a stdin payload that simulates the PreToolUse JSON
# Claude Code emits, asserts the exit code, optionally checks for a substring in
# stderr, and (on selected cases) asserts a substring in the audit log.
#
# Audit log is redirected to a per-run temp dir via $PM_GUARD_LOG_DIR — the
# live ~/.claude/logs/hooks.log is NOT polluted by this suite.
#
# Usage:
#   scripts/test-guards.sh           # silent unless failures
#   VERBOSE=1 scripts/test-guards.sh # print every case

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMHOOK="$SCRIPT_DIR/guard-pm-write.sh"
RWHOOK="$SCRIPT_DIR/guard-reviewer-write.sh"
EXWHOOK="$SCRIPT_DIR/guard-executor-write.sh"
STOP_HOOK="$SCRIPT_DIR/guard-log-claude-usage.sh"
RL_HOOK="$SCRIPT_DIR/guard-save-rate-limits.sh"
MEM_HOOK="$SCRIPT_DIR/guard-inject-memory.sh"
CTX_HOOK="$SCRIPT_DIR/guard-inject-context.sh"
SESSION_HOOK="$SCRIPT_DIR/guard-session-summary.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init --format=indent-2sp-quiet "$@"

# Sandbox audit logs.
export PM_GUARD_LOG_DIR="$(mktemp -d)"
TEST_LOG_FILE="$PM_GUARD_LOG_DIR/hooks.log"
trap 'rm -rf "$PM_GUARD_LOG_DIR" "${DISPATCH_TEST_BRIEF:-}" "${DISPATCH_TEST_BIN:-}" "${tmp_root:-}"' EXIT

# Pin the codex-executor read roots to known values so path tests are
# deterministic regardless of caller environment.
export PM_GUARD_CODEX_READ_ROOTS="$HOME/github:/tmp"

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
  actual_exit=$(printf '%s' "$json" | env "$envspec" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$hook" >/dev/null 2>&1; echo $?)
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
  tmp_home="$(mktemp -d "$PM_GUARD_LOG_DIR/stop-home.XXXXXX")"
  mkdir -p "$tmp_home/.claude/scripts"
  ln -s "$SCRIPT_DIR/log-usage.sh" "$tmp_home/.claude/scripts/log-usage.sh"
  printf '%s\n' "$tmp_home"
}

mem_path="$HOME/.claude/projects/test-project/memory/foo.md"
code_path="$REPO_ROOT/agents/project-pm.md"

# =============================================================================
# pm-write-guard
# =============================================================================

$LIST || echo "== guard-pm-write =="

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

run_case_env "pm: bypass via PM_GUARD_PM_WRITE=off" 0 "PM_GUARD_PM_WRITE=off" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

run_case_env "pm: bypass=Off (case mismatch) does NOT bypass" 2 "PM_GUARD_PM_WRITE=Off" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

run_case_env "pm: bypass=empty does NOT bypass" 2 "PM_GUARD_PM_WRITE=" "$PMHOOK" \
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
$LIST || printf '%s' "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$mem_path\"}}" | env PM_GUARD_PM_WRITE=off PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$PMHOOK" >/dev/null 2>&1
assert_log "pm: audit log contains bypass line with agent_type" "decision=bypass"
assert_log "pm: bypass line records project-pm (not '?')" "agent=project-pm"

# --- Rule A: /tmp/<slug>/*.md (PM task-slug brief pattern) ---
run_case "pm: Write /tmp/slug-abc/brief.md → allow (Rule A)" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/slug-abc/brief.md"}}'

run_case "pm: Write /tmp/task-xyz/output.md → allow (Rule A)" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/task-xyz/output.md"}}'

run_case "pm: Edit /tmp/task-abc123/notes.md → allow (Rule A)" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Edit","tool_input":{"file_path":"/tmp/task-abc123/notes.md"}}'

run_case "pm: Write /tmp/My-task/brief.md → deny (uppercase start, Rule A)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/My-task/brief.md"}}' \
  "outside memory directory"

run_case "pm: Write /tmp/slug/sub/deep.md → deny (nested subdir, Rule A)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/slug/sub/deep.md"}}' \
  "outside memory directory"

run_case "pm: Write /tmp/slug-abc/file.txt → deny (not .md, Rule A)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/slug-abc/file.txt"}}' \
  "outside memory directory"

# --- Rule B: docs/spikes PM-authored files ---
run_case "pm: Write docs/spikes/CC-258-pm-write.md → allow (Rule B, CC-NNN*)" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/spikes/CC-258-pm-write.md\"}}"

run_case "pm: Write docs/spikes/pm-guard-scope.md → allow (Rule B, *-scope)" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/spikes/pm-guard-scope.md\"}}"

run_case "pm: Write docs/spikes/pm-guard-rfc.md → allow (Rule B, *-rfc)" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/spikes/pm-guard-rfc.md\"}}"

run_case "pm: Write docs/spikes/notes.md → deny (no pattern match, Rule B)" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/spikes/notes.md\"}}" \
  "outside memory directory"

run_case "pm: Write docs/DECISIONS.md → deny (not spikes/, Rule B)" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/DECISIONS.md\"}}" \
  "outside memory directory"

run_case "pm: Write /tmp/rogue/docs/spikes/CC-999-evil.md → deny (Rule B in /tmp zone)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/rogue/docs/spikes/CC-999-evil.md"}}' \
  "outside memory directory"

# Cross-repo Rule B: PM dispatched to work on another repo — spike files there
# should be allowed.  Use a sibling directory next to REPO_ROOT so the path is
# outside /tmp/ and does not rely on the file existing.
run_case "pm: Write cross-repo docs/spikes/CC-999-cross-repo.md → allow (Rule B, any repo)" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/../other-project/docs/spikes/CC-999-cross-repo.md\"}}"

run_case "pm: Write cross-repo docs/spikes/analysis-scope.md → allow (Rule B, *-scope, any repo)" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/../other-project/docs/spikes/analysis-scope.md\"}}"

run_case "pm: Write cross-repo docs/spikes/notes.md → deny (no pattern match, cross-repo)" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/../other-project/docs/spikes/notes.md\"}}" \
  "outside memory directory"

# Rule A traversal: the lexical normalizer must collapse /tmp/<slug>/../ before
# the pattern check so that the traversal cannot escape the two-segment limit.
run_case "pm: Write /tmp/brief-abc/../secret.md → deny (Rule A traversal)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-abc/../secret.md"}}' \
  "outside memory directory"

# --- Rule C: symlinked memory dir (lexical path dual-normalization) ---
# Use a fake HOME under the sandboxed log dir so tests are isolated from the
# live ~/.claude/projects tree.
_pm_sym_fake_home="$(mktemp -d "$PM_GUARD_LOG_DIR/fake-home.XXXXXX")"
_pm_sym_real="$(mktemp -d "$PM_GUARD_LOG_DIR/sym-real.XXXXXX")"
mkdir -p "$_pm_sym_fake_home/.claude/projects/test-proj"
ln -sfn "$_pm_sym_real" "$_pm_sym_fake_home/.claude/projects/test-proj/memory" 2>/dev/null || true
if [[ -L "$_pm_sym_fake_home/.claude/projects/test-proj/memory" ]]; then
  run_case_env "pm: Write symlinked memory dir → allow (Rule C)" 0 \
    "HOME=$_pm_sym_fake_home" "$PMHOOK" \
    "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_pm_sym_fake_home/.claude/projects/test-proj/memory/foo.md\"}}"
  run_case "pm: Write symlinked memory/../../../etc/passwd → deny (Rule C traversal)" 2 "$PMHOOK" \
    "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_pm_sym_fake_home/.claude/projects/test-proj/memory/../../../etc/passwd\"}}" \
    "outside memory directory"

  # File symlink escape: memory dir is legitimate, but the file itself is a
  # symlink pointing outside — Rule C must deny this.
  _pm_file_sym_target="$(mktemp "$PM_GUARD_LOG_DIR/outside-XXXXXX")"
  _pm_file_sym_link="$_pm_sym_real/escape.md"
  ln -sfn "$_pm_file_sym_target" "$_pm_file_sym_link" 2>/dev/null || true
  if [[ -L "$_pm_file_sym_link" ]]; then
    run_case_env "pm: Write file symlink inside memory pointing outside → deny (Rule C escape)" 2 \
      "HOME=$_pm_sym_fake_home" "$PMHOOK" \
      "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_pm_sym_fake_home/.claude/projects/test-proj/memory/escape.md\"}}"
  else
    $LIST || printf '  SKIP  pm: file-symlink escape test (symlink creation unsupported)\n'
  fi
  rm -f "$_pm_file_sym_target" "$_pm_file_sym_link"
  unset _pm_file_sym_target _pm_file_sym_link

  # Nested directory symlink escape: a subdirectory inside memory is itself a
  # symlink pointing outside the memory target — must also deny.
  _pm_nest_outside="$(mktemp -d "$PM_GUARD_LOG_DIR/nest-outside-XXXXXX")"
  _pm_nest_linkdir="$_pm_sym_real/linkdir"
  ln -sfn "$_pm_nest_outside" "$_pm_nest_linkdir" 2>/dev/null || true
  if [[ -L "$_pm_nest_linkdir" ]]; then
    run_case_env "pm: Write nested dir symlink inside memory pointing outside → deny (Rule C)" 2 \
      "HOME=$_pm_sym_fake_home" "$PMHOOK" \
      "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_pm_sym_fake_home/.claude/projects/test-proj/memory/linkdir/escape.md\"}}"
  else
    $LIST || printf '  SKIP  pm: nested dir symlink escape test (symlink creation unsupported)\n'
  fi
  rm -rf "$_pm_nest_outside" "$_pm_nest_linkdir"
  unset _pm_nest_outside _pm_nest_linkdir

  # Cross-rule Rule A escape: memory dir symlinks into /tmp/<slug>/ so that
  # abs_path matches Rule A's /tmp/[a-z][^/]*/[^/]+\.md pattern.  The
  # dual-check must deny because lex_path is not under /tmp/<slug>/.
  _pm_cross_ruleA_dir="$(mktemp -d /tmp/brief-escXXXXXX)"
  _pm_cross_ruleA_home="$(mktemp -d "$PM_GUARD_LOG_DIR/fake-home-ruleA.XXXXXX")"
  mkdir -p "$_pm_cross_ruleA_home/.claude/projects/test-proj"
  ln -sfn "$_pm_cross_ruleA_dir" "$_pm_cross_ruleA_home/.claude/projects/test-proj/memory" 2>/dev/null || true
  if [[ -L "$_pm_cross_ruleA_home/.claude/projects/test-proj/memory" ]]; then
    run_case_env "pm: memory symlink into /tmp/<slug>/ → deny (cross-rule Rule A escape)" 2 \
      "HOME=$_pm_cross_ruleA_home" "$PMHOOK" \
      "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_pm_cross_ruleA_home/.claude/projects/test-proj/memory/escape.md\"}}" \
      "outside memory directory"
  else
    $LIST || printf '  SKIP  pm: cross-rule Rule A escape test (symlink creation unsupported)\n'
  fi
  rm -rf "$_pm_cross_ruleA_dir" "$_pm_cross_ruleA_home"
  unset _pm_cross_ruleA_dir _pm_cross_ruleA_home

  # Cross-rule Rule B escape: memory dir symlinks into docs/spikes/ so that
  # abs_path matches Rule B's docs/spikes/CC-*.md pattern.  The dual-check
  # must deny because lex_path is not under docs/spikes/.
  _pm_cross_ruleB_home="$(mktemp -d "$PM_GUARD_LOG_DIR/fake-home-ruleB.XXXXXX")"
  mkdir -p "$_pm_cross_ruleB_home/.claude/projects/test-proj"
  ln -sfn "$REPO_ROOT/docs/spikes" "$_pm_cross_ruleB_home/.claude/projects/test-proj/memory" 2>/dev/null || true
  if [[ -L "$_pm_cross_ruleB_home/.claude/projects/test-proj/memory" ]]; then
    run_case_env "pm: memory symlink into docs/spikes/ → deny (cross-rule Rule B escape)" 2 \
      "HOME=$_pm_cross_ruleB_home" "$PMHOOK" \
      "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_pm_cross_ruleB_home/.claude/projects/test-proj/memory/CC-99999-test.md\"}}" \
      "outside memory directory"
  else
    $LIST || printf '  SKIP  pm: cross-rule Rule B escape test (symlink creation unsupported)\n'
  fi
  rm -rf "$_pm_cross_ruleB_home"
  unset _pm_cross_ruleB_home
else
  $LIST || printf '  SKIP  pm: symlink tests (symlink creation unsupported)\n'
fi
rm -rf "$_pm_sym_fake_home" "$_pm_sym_real"
unset _pm_sym_fake_home _pm_sym_real

# --- realpath_m_lex bash fallback ---
# Shadow the system realpath with a stub that always fails so the bash-native
# normalization branch is exercised on all platforms.
_lex_fake_bin="$(mktemp -d "$PM_GUARD_LOG_DIR/fake-bin.XXXXXX")"
printf '#!/bin/bash\nexit 1\n' > "$_lex_fake_bin/realpath"
chmod +x "$_lex_fake_bin/realpath"

if should_run "pm: realpath_m_lex fallback collapses .."; then
  _lex_got="$(PATH="$_lex_fake_bin:$PATH" bash -c \
    ". '$SCRIPT_DIR/lib/portable.sh' && realpath_m_lex '/foo/bar/../baz'" 2>/dev/null)"
  if [[ "$_lex_got" == "/foo/baz" ]]; then
    pass "pm: realpath_m_lex fallback collapses .."
  else
    fail "pm: realpath_m_lex fallback collapses .." "expected /foo/baz, got '$_lex_got'"
  fi
fi

if should_run "pm: realpath_m_lex fallback strips ."; then
  _lex_got2="$(PATH="$_lex_fake_bin:$PATH" bash -c \
    ". '$SCRIPT_DIR/lib/portable.sh' && realpath_m_lex '/a/./b/c'" 2>/dev/null)"
  if [[ "$_lex_got2" == "/a/b/c" ]]; then
    pass "pm: realpath_m_lex fallback strips ."
  else
    fail "pm: realpath_m_lex fallback strips ." "expected /a/b/c, got '$_lex_got2'"
  fi
fi

rm -rf "$_lex_fake_bin"
unset _lex_fake_bin

# =============================================================================
# codex-write-guard
# =============================================================================

echo
$LIST || echo "== guard-executor-write (codex, cli-only) =="
# codex write_guard_mode=cli-only (CC-375/CC-385a): live hook no-ops; enforcement
# only via PM_GUARD_CHECK_CLI=1 (set by pmctl guard check).
#
# REGRESSION LOCK — the surviving hook-mode (write_guard_mode=hook) branch:
# codex routes its brief through pmctl (no subagent self-writes a brief), so its
# manifest overrides to cli-only and the live PreToolUse branch no-ops below. No
# SHIPPED adapter is hook-mode today, so no integration case here drives the live
# enforce path — but it is NOT dead code. It survives for the no-CLI self-writing
# fallback class (a runtime whose executor subagent authors its own brief via the
# host Write tool). The hook's `write_guard_mode != "hook"` live-no-op condition
# must therefore stay; its complement (hook-mode → live-enforce) is unit-locked by
# test-runner-kind.sh ("default/cli/guardmode" → hook). Do not simplify the branch
# away on the assumption that "every executor is cli-only".
truncate_log

# --- happy path: Write/Edit to /tmp/brief-*.md ---
run_case "exw: Write /tmp/brief-task.md → allow" 0 "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-task.md"}}'

run_case "exw: Write /tmp/brief-seed-postal-fix.md → allow" 0 "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-seed-postal-fix.md"}}'

run_case "exw: Edit /tmp/brief-task.md → allow" 0 "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Edit","tool_input":{"file_path":"/tmp/brief-task.md"}}'

# --- LIVE context (no PM_GUARD_CHECK_CLI): cli-only mode no-ops all codex writes ---
run_case "exw: codex-executor LIVE Write source file → no-op (cli-only)" 0 "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/backend/seeds/100_demo_content.sql"}}'

run_case "exw: codex-executor LIVE Write /etc/passwd → no-op (cli-only)" 0 "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'

# --- CLI enforcement (PM_GUARD_CHECK_CLI=1): policy applies ---
run_case_env "exw: Write source file → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/backend/seeds/100_demo_content.sql"}}'

run_case_env "exw: Edit source file → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Edit","tool_input":{"file_path":"/home/example/github/pm-dispatch/agents/codex-executor.md"}}'

run_case_env "exw: Write /tmp/other.md (not brief-prefixed) → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/other.md"}}'

run_case_env "exw: Write /tmp/brief-task.txt (not .md) → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-task.txt"}}'

run_case_env "exw: Write /tmp/brief- (no suffix) → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-"}}'

run_case_env "exw: Write /etc/passwd → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'

# --- traversal: /tmp/brief-../../../etc/passwd.md normalizes outside /tmp ---
run_case_env "exw: Write path traversal via brief prefix → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-/../etc/shadow.md"}}'

# --- no-op for other agents ---
run_case "exw: project-pm Write anywhere → no-op (pm guard handles it)" 0 "$EXWHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/whatever.md"}}'

run_case "exw: critic Write anywhere → no-op" 0 "$EXWHOOK" \
  '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}'

run_case "exw: main thread (no agent_type) Write → no-op" 0 "$EXWHOOK" \
  '{"tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}'

run_case "exw: codex-executor Bash → no-op (matcher would not fire it)" 0 "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"ls /tmp"}}'

# --- edge cases ---
run_case_env "exw: empty file_path → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":""}}'

run_case_env "exw: relative file_path → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"brief-task.md"}}'

run_case "exw: malformed JSON → deny" 2 "$EXWHOOK" \
  'not-json'

# --- symlink attack: /tmp/brief-*.md exists as a symlink to a protected path ---
_exw_symlink_target="$(mktemp)"
_exw_symlink_brief="$(mktemp -u /tmp/brief-XXXXXX.md)"
ln -s "$_exw_symlink_target" "$_exw_symlink_brief" 2>/dev/null || true
# Platforms without real symlink support (e.g. Git-Bash/MSYS without Developer
# Mode) silently copy on `ln -s`, so the symlink-attack vector cannot be staged
# here. Skip rather than false-fail — the guard's [[ -L ]] check is unchanged.
if [[ -L "$_exw_symlink_brief" ]]; then
  run_case_env "exw: Write to existing symlink /tmp/brief-*.md → deny" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
    "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_exw_symlink_brief\"}}"
else
  $LIST || printf '  SKIP  exw: Write to existing symlink /tmp/brief-*.md → deny (no real symlink support)\n'
fi
rm -f "$_exw_symlink_brief" "$_exw_symlink_target"
unset _exw_symlink_target _exw_symlink_brief

# --- bypass ---
run_case_env "exw: bypass via PM_GUARD_CODEX_WRITE=off" 0 "PM_GUARD_CODEX_WRITE=off" "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}'

# --- audit-log content assertions (CLI-driven; enforcement only under PM_GUARD_CHECK_CLI) ---
$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-task.md"}}' | env PM_GUARD_CHECK_CLI=1 PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$EXWHOOK" >/dev/null 2>&1
assert_log "exw: audit log contains allow line" "decision=allow"
assert_log "exw: allow line records agent=codex-executor" "agent=codex-executor"
assert_log "exw: allow line records tool=Write" "tool=Write"

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}' | env PM_GUARD_CHECK_CLI=1 PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$EXWHOOK" >/dev/null 2>&1
assert_log "exw: audit log contains deny line" "decision=deny"
assert_log "exw: deny line records agent=codex-executor" "agent=codex-executor"

$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/home/example/github/ExampleApp/foo.go"}}' | env PM_GUARD_CHECK_CLI=1 PM_GUARD_CODEX_WRITE=off PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$EXWHOOK" >/dev/null 2>&1
assert_log "exw: audit log contains bypass line" "decision=bypass"
assert_log "exw: bypass line records agent=codex-executor" "agent=codex-executor"

# =============================================================================
# executor-write-guard — runtime asymmetry (CC-374): live-hook vs cli-only
# =============================================================================
# write_guard_mode is read from each runtime's adapter manifest:
#   codex  = cli-subprocess → cli-only → no-op when fired LIVE (independent subprocess;
#                                         PM session hooks don't govern codex writes),
#                                         enforced only via PM_GUARD_CHECK_CLI
#   claude = cli-subprocess → cli-only → no-op when fired LIVE (canonical headless
#                              (override)  `claude --print` subprocess consumes a
#                                         pmctl-landed brief; no self-write via a
#                                         live host Write), enforced only when
#                                         driven by pmctl guard check
#                                         (PM_GUARD_CHECK_CLI set).

echo
$LIST || echo "== guard-executor-write (runtime asymmetry) =="
truncate_log

# codex (write_guard_mode=cli-only as of CC-375/CC-385a) is also no-op in the
# LIVE context — same as claude; enforcement only via PM_GUARD_CHECK_CLI.
run_case "exw: codex-executor LIVE Write /etc/passwd → no-op (cli-only)" 0 "$EXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'

# Unregistered runtime: fail-closed (deny) under the CLI, no-op when fired live so
# a live hook never blocks an agent whose runtime it cannot resolve.
run_case_env "exw: unregistered runtime CLI → deny (fail-closed)" 2 "PM_GUARD_CHECK_CLI=1" "$EXWHOOK" \
  '{"agent_type":"bogus-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-x.md"}}'
run_case "exw: unregistered runtime LIVE → no-op" 0 "$EXWHOOK" \
  '{"agent_type":"bogus-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-x.md"}}'

# =============================================================================
# reviewer-write-guard
# =============================================================================

echo
$LIST || echo "== guard-reviewer-write =="
truncate_log

_gate_dir="$(mktemp -d)/repo/.gate-results"
mkdir -p "$_gate_dir"
_gate_repo="$(dirname "$_gate_dir")"

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

# parent is repo root, not .gate-results → deny (basename != ".gate-results")
run_case "rw: critic Write file not inside .gate-results/ → deny" 2 "$RWHOOK" \
  "{\"agent_type\":\"critic\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_gate_repo/gate-result.md\"}}"

# path traversal: resolves to parent of .gate-results → deny
run_case "rw: critic Write path traversal → deny" 2 "$RWHOOK" \
  "{\"agent_type\":\"critic\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_gate_dir/../evil.md\"}}"

# --- synthetic identity (pmctl guard check --role reviewer codex route) ---
run_case "rw: reviewer (pmctl synthetic) Write to .gate-results/ → allow" 0 "$RWHOOK" \
  "{\"agent_type\":\"reviewer\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_gate_dir/pmctl-output.md\"}}"

run_case "rw: reviewer (pmctl synthetic) Write outside .gate-results/ → deny" 2 "$RWHOOK" \
  '{"agent_type":"reviewer","tool_name":"Write","tool_input":{"file_path":"/tmp/evil.md"}}'

# CC-319: any directory named .gate-results is allowed — pr-gate works on any
# project without coupling to the pm-dispatch install path.
_rw_cross_gate="$(mktemp -d)/.gate-results"
mkdir -p "$_rw_cross_gate"
run_case "rw: reviewer Write to any project's .gate-results → allow (CC-319)" 0 "$RWHOOK" \
  "{\"agent_type\":\"reviewer\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_rw_cross_gate/output.md\"}}"
rm -rf "$(dirname "$_rw_cross_gate")"
unset _rw_cross_gate

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
ln -s "$_rw_symlink_target" "$_rw_symlink_out" 2>/dev/null || true
# See cxw symlink case: skip where real symlinks are unavailable (MSYS copies).
if [[ -L "$_rw_symlink_out" ]]; then
  run_case "rw: Write to existing symlink in .gate-results/ → deny" 2 "$RWHOOK" \
    "{\"agent_type\":\"critic\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_rw_symlink_out\"}}"
else
  $LIST || printf '  SKIP  rw: Write to existing symlink in .gate-results/ → deny (no real symlink support)\n'
fi
rm -f "$_rw_symlink_out" "$_rw_symlink_target"
unset _rw_symlink_target _rw_symlink_out

# --- bypass ---
run_case_env "rw: bypass via PM_GUARD_REVIEWER_WRITE=off" 0 "PM_GUARD_REVIEWER_WRITE=off" "$RWHOOK" \
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
$LIST || printf '%s' '{"agent_type":"critic","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}' | env PM_GUARD_REVIEWER_WRITE=off PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$RWHOOK" >/dev/null 2>&1
assert_log "rw: audit log contains bypass line" "decision=bypass"
assert_log "rw: bypass line records agent=critic" "agent=critic"

# --- read-only audit log must not leak a redirection error ---
# Regression: when $LOG_FILE (e.g. a sandboxed read-only ~/.claude/logs/hooks.log)
# cannot be opened for append, g_audit must stay silent and the allow/deny
# decision must be unaffected. A bare `printf >> "$LOG_FILE" 2>/dev/null` leaks
# the open-failure ("Permission denied") because bash reports a redirection-open
# error before the inner 2>/dev/null applies; the brace-group wrap silences it.
rw_readonly_log_no_leak() {
  local name="rw: read-only audit log → allow exits 0 with no stderr leak"
  should_run "$name" || return 0
  local stderr_file actual_exit actual_stderr
  stderr_file="$(mktemp)"
  chmod 0444 "$TEST_LOG_FILE"
  printf '%s' "{\"agent_type\":\"critic\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_gate_dir/output.md\"}}" \
    | "$RWHOOK" >/dev/null 2>"$stderr_file"
  actual_exit=$?
  chmod 0644 "$TEST_LOG_FILE"
  actual_stderr="$(cat "$stderr_file")"; rm -f "$stderr_file"
  if [[ "$actual_exit" == "0" && -z "$actual_stderr" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '        exit=%s stderr=%q' "$actual_exit" "${actual_stderr:0:200}")"
  fi
}
rw_readonly_log_no_leak

rm -rf "$_gate_dir" "$(dirname "$_gate_dir")"
unset _gate_dir

# =============================================================================
# guard-log-claude-usage
# =============================================================================

echo
$LIST || echo "== guard-log-claude-usage =="
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
  printf '%s' "$payload" | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >"$out" 2>"$err"
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
  printf '%s' '{"session_id":"s1"}' | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
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
  printf '%s' '{"transcript_path":"/nonexistent/path","session_id":"s1"}' | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
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
  printf '%s' 'not json' | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
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
  printf '%s' "$payload" | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
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
  printf '%s' "$payload" | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
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
  printf '%s' "$payload" | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  # Second invocation (same session + transcript)
  printf '%s' "$payload" | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
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
  printf '%s' "$payload" | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
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
  printf '%s' "$payload" | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
  printf '%s' "$payload" | HOME="$home" PM_GUARD_LOG_DIR="$PM_GUARD_LOG_DIR" "$STOP_HOOK" >/dev/null 2>&1
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
# guard-save-rate-limits
# =============================================================================

echo
$LIST || echo "== guard-save-rate-limits =="

run_rl_hook() {
  local json="$1" config_dir="$2"
  printf '%s' "$json" | CLAUDE_CONFIG_DIR="$config_dir" "$RL_HOOK" 2>/dev/null
}

_set_mtime_secs_ago() {
  local file="$1" secs="$2"
  if command -v perl >/dev/null 2>&1; then
    perl -e 'utime(time()-$ARGV[0], time()-$ARGV[0], $ARGV[1])' "$secs" "$file"
  else
    printf 'SKIP: _set_mtime_secs_ago requires perl\n' >&2
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
  # Verifies that the EXIT trap in guard-save-rate-limits.sh removes the
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
# guard-inject-memory
# =============================================================================

echo
$LIST || echo "== guard-inject-memory =="

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
  #   1. Create a sandbox project MEMORY.md with two "- " index lines (no card files)
  #   2. Run the hook with a UserPromptSubmit payload whose cwd matches the project
  #   3. Assert stdout contains delimiters, preamble lines, both index entries, no omission notice
  local name="inject-hook/happy-path" dir cwd payload output status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  write_inject_memory "$dir" "$cwd" $'# title\n- alpha\n  - nested ignored\n- beta\nnot index\n'
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" \
      && "$output" == ===\ auto-memory:\ MEMORY.md\ index\ ===$'\n'* \
      && "$output" == *$'\n'===\ end\ auto-memory\ === \
      && "$output" == *"Memory dir:"* \
      && "$output" == *"/mem-search"* \
      && "$output" == *"- alpha"* \
      && "$output" == *"- beta"* \
      && "$output" != *"entries omitted"* ]]; then
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
  #   3. Assert stdout contains the parent project index line
  local name="inject-hook/parent-fallback" dir parent child payload output status
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  parent="$dir/repo"
  child="$parent/packages/app"
  mkdir -p "$child"
  write_inject_memory "$dir" "$parent" $'# memory\n- parent index\n'
  payload="{\"cwd\":\"$child\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" \
      && "$output" == ===\ auto-memory:\ MEMORY.md\ index\ ===$'\n'* \
      && "$output" == *$'\n'===\ end\ auto-memory\ === \
      && "$output" == *"- parent index"* ]]; then
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
  # Verifies that when MEMORY.md has 60 index entries (no card files), the hook
  # injects exactly MAX_INJECT_ENTRIES=20 entries and appends an omission notice.
  # Steps:
  #   1. Create a matching project MEMORY.md with 60 plain index lines (no card files)
  #   2. Run the hook with a valid cwd payload and capture stdout
  #   3. Assert first 20 entries appear, entry 021 does NOT appear,
  #      omission notice "(40 entries omitted" appears, no old "memory-compress" warning
  local name="inject-hook/threshold-shows-directive" dir cwd payload output status omission_line
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
  omission_line="$(printf '%s\n' "$output" | grep 'entries omitted' || true)"
  if [[ "$status" == "0" \
      && "$output" == ===\ auto-memory:\ MEMORY.md\ index\ ===$'\n'* \
      && "$output" == *$'\n'===\ end\ auto-memory\ === \
      && "$output" == *"memory index line 001"* \
      && "$output" == *"memory index line 020"* \
      && "$output" != *"memory index line 021"* \
      && -n "$omission_line" \
      && "$omission_line" == *"40 entries omitted"* \
      && "$output" != *"memory-compress"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s omission=%q output_tail=%q\n' "$name" "$status" "$omission_line" "${output: -80}"
  fi
  rm -rf "$dir"
}

inject_hook_threshold_below_emits_no_directive() {
  # Verifies that 15 index entries (under budget of 20) injects all entries with no omission notice.
  # Steps:
  #   1. Create a matching project MEMORY.md with 15 plain index lines (no card files)
  #   2. Run the hook and capture stdout
  #   3. Assert all 15 entries present and no omission notice
  local name="inject-hook/under-budget-15-no-omission" dir cwd payload output status i
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  {
    printf '# title\n'
    for i in $(seq 1 15); do
      printf -- '- memory index line %03d\n' "$i"
    done
  } > "$dir/memory15.md"
  write_inject_memory "$dir" "$cwd" "$(cat "$dir/memory15.md")"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" \
      && "$output" == *"memory index line 001"* \
      && "$output" == *"memory index line 015"* \
      && "$output" != *"entries omitted"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output_tail=%q\n' "$name" "$status" "${output: -120}"
  fi
  rm -rf "$dir"
}

inject_hook_threshold_at_boundary_emits_directive() {
  # Verifies budget boundary: exactly 20 entries → all injected, no omission notice;
  # exactly 21 entries → 20 injected + omission notice of 1.
  # Steps:
  #   1. 20 plain entries → assert all 20 present, no omission
  #   2. 21 plain entries → assert 20 present, entry 021 missing, omission notice "(1 entries omitted"
  local name="inject-hook/budget-boundary-20-21-emits-omission" dir cwd payload output status i
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"

  # Part 1: exactly 20 entries — no omission
  {
    printf '# title\n'
    for i in $(seq 1 20); do printf -- '- memory index line %03d\n' "$i"; done
  } > "$dir/memory20.md"
  write_inject_memory "$dir" "$cwd" "$(cat "$dir/memory20.md")"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if ! [[ "$status" == "0" \
      && "$output" == *"memory index line 020"* \
      && "$output" != *"entries omitted"* ]]; then
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (20-entry part) — exit=%s output_tail=%q\n' "$name" "$status" "${output: -80}"
    rm -rf "$dir"
    return
  fi

  # Part 2: exactly 21 entries — 1 omitted
  {
    printf '# title\n'
    for i in $(seq 1 21); do printf -- '- memory index line %03d\n' "$i"; done
  } > "$dir/memory21.md"
  write_inject_memory "$dir" "$cwd" "$(cat "$dir/memory21.md")"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" \
      && "$output" == *"memory index line 020"* \
      && "$output" != *"memory index line 021"* \
      && "$output" == *"1 entries omitted"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (21-entry part) — exit=%s output_tail=%q\n' "$name" "$status" "${output: -80}"
  fi
  rm -rf "$dir"
}

inject_hook_default_home_fallback() {
  # Verifies that when CLAUDE_CONFIG_DIR is unset, the hook falls back to $HOME/.claude.
  # Steps:
  #   1. Create a temp dir used as a sandboxed HOME; write MEMORY.md under
  #      <tmp_home>/.claude/projects/<encoded>/memory/ with a uniquely-named fake cwd
  #   2. Run guard-inject-memory.sh with HOME overridden to the temp dir and
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

inject_hook_always_priority_bypasses_budget() {
  # Verifies that a card with priority: always injects even when the entry budget is full.
  # Steps:
  #   1. Create MEMORY.md with 22 plain entries (no card files = tier2) and 1 entry
  #      whose card file has priority: always (tier1)
  #   2. Run the hook (budget = 20 total)
  #   3. Assert the always-priority entry appears, total injected = 20, 3 omitted
  local name="inject-hook/always-priority-bypasses-budget" dir cwd mem payload output status omission_line
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"

  {
    printf '# test\n'
    for i in $(seq 1 22); do
      printf -- '- [card%03d](card%03d.md) — normal card %d\n' "$i" "$i" "$i"
    done
    printf -- '- [always-card](always-card.md) — must always inject\n'
  } > "$mem/MEMORY.md"

  printf -- '---\npriority: always\nstatus: inactive\n---\nAlways content\n' > "$mem/always-card.md"

  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  omission_line="$(printf '%s\n' "$output" | grep 'entries omitted' || true)"
  if [[ "$status" == "0" \
      && "$output" == *"always-card"* \
      && -n "$omission_line" \
      && "$omission_line" == *"3 entries omitted"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s omission=%q output_tail=%q\n' "$name" "$status" "$omission_line" "${output: -120}"
  fi
  rm -rf "$dir"
}

inject_hook_prompt_aware_scoring() {
  # Verifies that tier2 cards with topics matching prompt keywords rank above others.
  # Steps:
  #   1. Create MEMORY.md with 2 entries in order: card-b (no match) then card-a (match)
  #      Both have status: inactive and priority: normal (tier2)
  #   2. Run the hook with a prompt containing a keyword matching card-a's topics
  #   3. Assert card-a appears before card-b in output (higher score wins over insertion order)
  local name="inject-hook/prompt-aware-scoring" dir cwd mem payload output status pos_a pos_b
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"

  printf '# test\n- [card-b](card-b.md) — general card\n- [card-a](card-a.md) — specialized card\n' > "$mem/MEMORY.md"

  printf -- '---\npriority: normal\nstatus: inactive\ntopics:\n  - unrelated\n---\nCard B\n' > "$mem/card-b.md"
  printf -- '---\npriority: normal\nstatus: inactive\ntopics:\n  - retrieval\n  - memory\n---\nCard A\n' > "$mem/card-a.md"

  payload="{\"cwd\":\"$cwd\",\"prompt\":\"check the retrieval system\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  # Find line positions of each entry
  pos_a=$(printf '%s\n' "$output" | grep -n 'card-a' | cut -d: -f1 | head -1 || printf '0')
  pos_b=$(printf '%s\n' "$output" | grep -n 'card-b' | cut -d: -f1 | head -1 || printf '0')
  if [[ "$status" == "0" \
      && -n "$pos_a" && -n "$pos_b" \
      && "$pos_a" -lt "$pos_b" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s pos_a=%s pos_b=%s output=%q\n' "$name" "$status" "$pos_a" "$pos_b" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_byte_cap_truncates_before_entry_cap() {
  # Verifies the MAX_INJECT_BYTES budget truncates tier2 entries even when the
  # entry count is well under MAX_INJECT_ENTRIES=20. Without a byte cap, all 10
  # entries would inject (10 < 20); with it, ~400-byte lines exhaust 3000 bytes
  # first, so the tail is omitted.
  # Steps:
  #   1. Create MEMORY.md with 10 plain entries (no card files = tier2), each ~400 bytes
  #   2. Run the hook (entry budget = 20, so entry-cap cannot fire with only 10)
  #   3. Assert entry 001 present, entry 010 absent, and an omission notice appears
  #      — proving the byte cap (not the entry cap) did the truncation
  local name="inject-hook/byte-cap-truncates-before-entry-cap" dir cwd payload output status omission_line pad
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  pad="$(printf 'x%.0s' $(seq 1 380))"
  {
    printf '# title\n'
    for i in $(seq 1 10); do
      printf -- '- entry %03d %s\n' "$i" "$pad"
    done
  } > "$dir/long-lines-memory.md"
  write_inject_memory "$dir" "$cwd" "$(cat "$dir/long-lines-memory.md")"
  payload="{\"cwd\":\"$cwd\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  omission_line="$(printf '%s\n' "$output" | grep 'entries omitted' || true)"
  if [[ "$status" == "0" \
      && "$output" == *"entry 001"* \
      && "$output" != *"entry 010"* \
      && -n "$omission_line" \
      && "$omission_line" == *"entries omitted"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s omission=%q output_tail=%q\n' "$name" "$status" "$omission_line" "${output: -80}"
  fi
  rm -rf "$dir"
}

inject_hook_status_active_no_longer_pins() {
  # CC-427 core fix: status: active must NOT force tier1 (always-inject). With
  # 25 normal cards all status: active, the budget (20) must still truncate,
  # emitting 20 entries + a "5 entries omitted" notice. Pre-CC-427 these would
  # all land in tier1 and bypass the budget (the "33 cards, zero omission" bug).
  local name="inject-hook/status-active-no-longer-pins" dir cwd mem payload output status omission_line injected
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  {
    printf '# test\n'
    for i in $(seq 1 25); do
      printf -- '---\npriority: normal\nstatus: active\n---\nCard %d\n' "$i" > "$mem/c$i.md"
      printf -- '- [c%d](c%d.md) — active card %d\n' "$i" "$i" "$i"
    done
  } > "$mem/MEMORY.md"
  payload="{\"cwd\":\"$cwd\",\"prompt\":\"zzz\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  injected="$(printf '%s\n' "$output" | grep -c '^- \[' || true)"
  omission_line="$(printf '%s\n' "$output" | grep 'entries omitted' || true)"
  if [[ "$status" == "0" \
      && "$injected" == "20" \
      && "$omission_line" == *"5 entries omitted"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s injected=%s omission=%q\n' "$name" "$status" "$injected" "$omission_line"
  fi
  rm -rf "$dir"
}

inject_hook_keyword_hit_records_access() {
  # A keyword-hit normal card records one access in the usage sidecar (counted
  # before budget truncation). Pinned tier1 cards are not counted.
  local name="inject-hook/keyword-hit-records-access" dir cwd mem payload status sidecar row
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  printf '# test\n- [a](a.md) — retrieval card\n- [b](b.md) — other card\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\ntopics:\n  - retrieval\n---\nA\n' > "$mem/a.md"
  printf -- '---\npriority: normal\ntopics:\n  - unrelated\n---\nB\n' > "$mem/b.md"
  payload="{\"cwd\":\"$cwd\",\"prompt\":\"check the retrieval system\"}"
  printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" >/dev/null 2>&1
  status=$?
  sidecar="$mem/.pm-dispatch/inject-usage.tsv"
  row="$(grep '^a\.md' "$sidecar" 2>/dev/null || true)"
  if [[ "$status" == "0" \
      && "$row" == a.md$'\t'1$'\t'* \
      && -z "$(grep '^b\.md' "$sidecar" 2>/dev/null || true)" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s row=%q sidecar=%q\n' "$name" "$status" "$row" "$(cat "$sidecar" 2>/dev/null)"
  fi
  rm -rf "$dir"
}

inject_hook_frecency_ranks_accessed_above_cold() {
  # With NO keyword hit this run, a card that accrued usage (frecency > 0) ranks
  # above a never-accessed card, replacing the old fixed index order.
  local name="inject-hook/frecency-ranks-accessed-above-cold" dir cwd mem status pos_a pos_b
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  # Order in index: b (cold) before a (will be warmed).
  printf '# test\n- [b](b.md) — beta\n- [a](a.md) — alpha\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\ntopics:\n  - alpha\n---\nA\n' > "$mem/a.md"
  printf -- '---\npriority: normal\ntopics:\n  - beta\n---\nB\n' > "$mem/b.md"
  # Warm a.md with a keyword-hit run.
  printf '{"cwd":"%s","prompt":"alpha alpha"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" >/dev/null 2>&1
  # Now a neutral prompt: no keyword hits → ranking driven by frecency.
  output=$(printf '{"cwd":"%s","prompt":"zzz"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  pos_a=$(printf '%s\n' "$output" | grep -n '\[a\]' | cut -d: -f1 | head -1 || printf '0')
  pos_b=$(printf '%s\n' "$output" | grep -n '\[b\]' | cut -d: -f1 | head -1 || printf '0')
  if [[ "$status" == "0" && -n "$pos_a" && -n "$pos_b" && "$pos_a" -lt "$pos_b" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s pos_a=%s pos_b=%s output=%q\n' "$name" "$status" "$pos_a" "$pos_b" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_keyword_tier_dominates_frecency() {
  # A card the current prompt's keywords hit outranks a high-frecency card that
  # the prompt does NOT hit (layered: keyword tier first, frecency within tier).
  local name="inject-hook/keyword-tier-dominates-frecency" dir cwd mem status pos_a pos_b i
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  printf '# test\n- [a](a.md) — alpha card\n- [b](b.md) — beta card\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\ntopics:\n  - alpha\n---\nA\n' > "$mem/a.md"
  printf -- '---\npriority: normal\ntopics:\n  - beta\n---\nB\n' > "$mem/b.md"
  # Warm b.md heavily so it has high frecency.
  for i in 1 2 3 4 5; do
    printf '{"cwd":"%s","prompt":"beta beta"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" >/dev/null 2>&1
  done
  # Prompt hits a (keyword) but not b; a must outrank high-frecency b.
  output=$(printf '{"cwd":"%s","prompt":"alpha please"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  pos_a=$(printf '%s\n' "$output" | grep -n '\[a\]' | cut -d: -f1 | head -1 || printf '0')
  pos_b=$(printf '%s\n' "$output" | grep -n '\[b\]' | cut -d: -f1 | head -1 || printf '0')
  if [[ "$status" == "0" && -n "$pos_a" && -n "$pos_b" && "$pos_a" -lt "$pos_b" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s pos_a=%s pos_b=%s output=%q\n' "$name" "$status" "$pos_a" "$pos_b" "$output"
  fi
  rm -rf "$dir"
}

memory_usage_commit_decay_halves() {
  # Unit: reaching the decay threshold halves every access_count and resets the
  # global event counter to 0.
  local name="memory-usage/commit-decay-halves" out acc te
  should_run "$name" || return 0
  out="$(
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/lib/memory.sh"
    sc="$(mktemp -d)/u.tsv"
    # 4 hits on a.md at threshold 4 → access_count 4, then >>1 = 2; total_events 0.
    memory_usage_commit "$sc" 4 100 a.md a.md a.md a.md
    cat "$sc"
  )"
  acc="$(printf '%s\n' "$out" | awk -F'\t' '$1=="a.md"{print $2}')"
  te="$(printf '%s\n' "$out" | awk -F= '/^# total_events=/{print $2}')"
  if [[ "$acc" == "2" && "$te" == "0" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — acc=%q total_events=%q out=%q\n' "$name" "$acc" "$te" "$out"
  fi
}

memory_usage_commit_concurrent_no_lost_updates() {
  # Concurrency (mutation-grade): N simultaneous keyword-hit writers to the same
  # sidecar, each serialized through serialize_with_lock, must not lose any
  # increment — final access_count must equal exactly N. Removing the lock from
  # the hook's persistence path turns the read-modify-write into a race that
  # drops updates, so this test fails (the mutation is caught). Uses a private
  # temp dir (no shared /tmp scanning) so the result is isolation-stable.
  local name="memory-usage/concurrent-no-lost-updates" got n=25
  should_run "$name" || return 0
  got="$(
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/lib/memory.sh"
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/lib/portable.sh"
    d="$(mktemp -d)"
    sc="$d/.pm-dispatch/inject-usage.tsv"
    mkdir -p "$(dirname "$sc")"
    local i
    for ((i = 0; i < n; i++)); do
      # threshold high so decay never fires; one a.md hit per writer.
      serialize_with_lock "$sc" memory_usage_commit "$sc" 1000000 100 a.md &
    done
    wait
    awk -F'\t' '$1=="a.md"{print $2}' "$sc"
    rm -rf "$d"
  )"
  if [[ "$got" == "$n" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — final access_count=%q want=%q\n' "$name" "$got" "$n"
  fi
}

memory_age_bucket_mapping() {
  # Unit: age bucket boundaries map to 100/70/50/30/10.
  local name="memory-usage/age-bucket-mapping" got want ok=1
  should_run "$name" || return 0
  got="$(
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/lib/memory.sh"
    # today=100; last at diffs 0,4,5,14,31,90,91 and a future stamp (-3 diff).
    for pair in 100:100 96:100 95:70 86:70 69:50 10:30 9:10 103:100; do
      last="${pair%%:*}"
      printf '%s ' "$(memory_age_bucket 100 "$last")"
    done
  )"
  want="100 100 70 70 50 30 10 100 "
  [[ "$got" == "$want" ]] && ok=1 || ok=0
  if [[ "$ok" == "1" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — got=%q want=%q\n' "$name" "$got" "$want"
  fi
}

inject_hook_sidecar_write_failure_is_best_effort() {
  # Error path: when the usage sidecar cannot be written (here .pm-dispatch is a
  # regular file, so the dir/lock cannot be created), the hook must still exit 0
  # and emit the memory index — telemetry persistence is strictly best-effort.
  local name="inject-hook/sidecar-write-failure-best-effort" dir cwd mem status output
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  printf '# test\n- [a](a.md) — retrieval card\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\ntopics:\n  - retrieval\n---\nA\n' > "$mem/a.md"
  # Occupy the .pm-dispatch path with a regular file so sidecar dir/lock creation fails.
  printf 'blocker' > "$mem/.pm-dispatch"
  output=$(printf '{"cwd":"%s","prompt":"retrieval system"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" \
      && "$output" == *"- [a](a.md)"* \
      && "$output" == *"=== end auto-memory ==="* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_malformed_sidecar_degrades_to_zero() {
  # Negative input: malformed existing sidecar rows (non-numeric counters /
  # timestamps and a non-numeric total_events header) must degrade to zero
  # without aborting. The hook still exits 0, emits the index, and a fresh
  # keyword-hit access rewrites a well-formed row (a.md access_count=1) with a
  # numeric total_events header.
  local name="inject-hook/malformed-sidecar-degrades-to-zero" dir cwd mem status output sidecar row te
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  printf '# test\n- [a](a.md) — retrieval card\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\ntopics:\n  - retrieval\n---\nA\n' > "$mem/a.md"
  mkdir -p "$mem/.pm-dispatch"
  sidecar="$mem/.pm-dispatch/inject-usage.tsv"
  printf '# total_events=abc\na.md\tnotanum\txyz\n' > "$sidecar"
  output=$(printf '{"cwd":"%s","prompt":"retrieval system"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  row="$(grep '^a\.md' "$sidecar" 2>/dev/null || true)"
  te="$(awk -F= '/^# total_events=/{print $2}' "$sidecar" 2>/dev/null || true)"
  if [[ "$status" == "0" \
      && "$output" == *"- [a](a.md)"* \
      && "$row" == a.md$'\t'1$'\t'* \
      && "$te" =~ ^[0-9]+$ ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s row=%q te=%q output=%q\n' "$name" "$status" "$row" "$te" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_stale_card_demoted_below_active() {
  # Verifies that a status:stale card with high frecency ranks after a status:active
  # card with zero frecency — lifecycle validity gates before usage.
  # Steps:
  #   1. Create MEMORY.md with stale.md (status:stale, warmable) and active.md (status:active)
  #   2. Warm stale.md with 5 keyword-hit runs to accrue high frecency
  #   3. Run with neutral prompt (no keyword hits)
  #   4. Assert active.md appears before stale.md in output
  local name="inject-hook/stale-card-demoted-below-active" dir cwd mem status pos_stale pos_active i
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  printf '# test\n- [stale](stale.md) — retrieval stale card\n- [active](active.md) — other card\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\nstatus: stale\ntopics:\n  - retrieval\n---\nStale\n' > "$mem/stale.md"
  printf -- '---\npriority: normal\nstatus: active\ntopics:\n  - unrelated\n---\nActive\n' > "$mem/active.md"
  # Warm stale.md with repeated keyword hits so it has high frecency.
  for i in $(seq 1 5); do
    printf '{"cwd":"%s","prompt":"retrieval system"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" >/dev/null 2>&1
  done
  # Neutral prompt: no keyword hits → ranking should be frecency/lifecycle only.
  output=$(printf '{"cwd":"%s","prompt":"zzz"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  pos_stale=$(printf '%s\n' "$output" | grep -n '\[stale\]' | cut -d: -f1 | head -1 || printf '0')
  pos_active=$(printf '%s\n' "$output" | grep -n '\[active\]' | cut -d: -f1 | head -1 || printf '0')
  if [[ "$status" == "0" ]] && (( pos_active > 0 && pos_stale > 0 && pos_active < pos_stale )); then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s pos_active=%s pos_stale=%s output=%q\n' "$name" "$status" "$pos_active" "$pos_stale" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_superseded_card_demoted_below_active() {
  # Verifies that a status:superseded card with high frecency ranks after a
  # status:active card with zero frecency — superseded is a terminal lifecycle state.
  # Steps:
  #   1. Create MEMORY.md with sup.md (status:superseded, warmable) and active.md (status:active)
  #   2. Warm sup.md with 5 keyword-hit runs to accrue high frecency
  #   3. Run with neutral prompt (no keyword hits)
  #   4. Assert active.md appears before sup.md in output
  local name="inject-hook/superseded-card-demoted-below-active" dir cwd mem status pos_sup pos_active i
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  printf '# test\n- [sup](sup.md) — retrieval superseded card\n- [active](active.md) — other card\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\nstatus: superseded\ntopics:\n  - retrieval\n---\nSuperseded\n' > "$mem/sup.md"
  printf -- '---\npriority: normal\nstatus: active\ntopics:\n  - unrelated\n---\nActive\n' > "$mem/active.md"
  # Warm sup.md with repeated keyword hits.
  for i in $(seq 1 5); do
    printf '{"cwd":"%s","prompt":"retrieval system"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" >/dev/null 2>&1
  done
  output=$(printf '{"cwd":"%s","prompt":"zzz"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  pos_sup=$(printf '%s\n' "$output" | grep -n '\[sup\]' | cut -d: -f1 | head -1 || printf '0')
  pos_active=$(printf '%s\n' "$output" | grep -n '\[active\]' | cut -d: -f1 | head -1 || printf '0')
  if [[ "$status" == "0" ]] && (( pos_active > 0 && pos_sup > 0 && pos_active < pos_sup )); then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s pos_active=%s pos_sup=%s output=%q\n' "$name" "$status" "$pos_active" "$pos_sup" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_missing_status_treated_as_active() {
  # Verifies that a card with no status field in frontmatter is not degraded —
  # it ranks normally by frecency as if status:active (defensive default).
  # Steps:
  #   1. Create MEMORY.md with warm.md (no status field, warmable) listed after cold.md (status:active)
  #   2. Warm warm.md with 5 keyword-hit runs to accrue frecency
  #   3. Run with neutral prompt (no keyword hits)
  #   4. Assert warm.md (frecency > 0) appears before cold.md (frecency = 0)
  local name="inject-hook/missing-status-treated-as-active" dir cwd mem status pos_warm pos_cold i
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  # cold.md listed first in index; warm.md has no status field (just priority).
  printf '# test\n- [cold](cold.md) — beta card\n- [warm](warm.md) — retrieval card\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\nstatus: active\ntopics:\n  - beta\n---\nCold\n' > "$mem/cold.md"
  printf -- '---\npriority: normal\ntopics:\n  - retrieval\n---\nWarm\n' > "$mem/warm.md"
  # Warm warm.md with keyword hits.
  for i in $(seq 1 5); do
    printf '{"cwd":"%s","prompt":"retrieval system"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" >/dev/null 2>&1
  done
  output=$(printf '{"cwd":"%s","prompt":"zzz"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  pos_warm=$(printf '%s\n' "$output" | grep -n '\[warm\]' | cut -d: -f1 | head -1 || printf '0')
  pos_cold=$(printf '%s\n' "$output" | grep -n '\[cold\]' | cut -d: -f1 | head -1 || printf '0')
  # warm.md (no status, high frecency) must rank above cold.md (active, cold).
  if [[ "$status" == "0" ]] && (( pos_warm > 0 && pos_cold > 0 && pos_warm < pos_cold )); then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s pos_warm=%s pos_cold=%s output=%q\n' "$name" "$status" "$pos_warm" "$pos_cold" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_archived_card_treated_as_active() {
  # Verifies that a status:archived card is NOT degraded — it ranks normally by
  # frecency, same as status:active (archived is a historical record, not stale context).
  # Steps:
  #   1. Create MEMORY.md with arch.md (status:archived, warmable) listed after cold.md (status:active)
  #   2. Warm arch.md with 5 keyword-hit runs to accrue frecency
  #   3. Run with neutral prompt (no keyword hits)
  #   4. Assert arch.md (frecency > 0) appears before cold.md (frecency = 0, no degradation)
  local name="inject-hook/archived-card-treated-as-active" dir cwd mem status pos_arch pos_cold i
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  # cold.md listed first; arch.md (archived, warmed) should rank above it via frecency.
  printf '# test\n- [cold](cold.md) — beta card\n- [arch](arch.md) — retrieval card\n' > "$mem/MEMORY.md"
  printf -- '---\npriority: normal\nstatus: active\ntopics:\n  - beta\n---\nCold\n' > "$mem/cold.md"
  printf -- '---\npriority: normal\nstatus: archived\ntopics:\n  - retrieval\n---\nArch\n' > "$mem/arch.md"
  for i in $(seq 1 5); do
    printf '{"cwd":"%s","prompt":"retrieval system"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" >/dev/null 2>&1
  done
  output=$(printf '{"cwd":"%s","prompt":"zzz"}' "$cwd" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  pos_arch=$(printf '%s\n' "$output" | grep -n '\[arch\]' | cut -d: -f1 | head -1 || printf '0')
  pos_cold=$(printf '%s\n' "$output" | grep -n '\[cold\]' | cut -d: -f1 | head -1 || printf '0')
  if [[ "$status" == "0" ]] && (( pos_arch > 0 && pos_cold > 0 && pos_arch < pos_cold )); then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s pos_arch=%s pos_cold=%s output=%q\n' "$name" "$status" "$pos_arch" "$pos_cold" "$output"
  fi
  rm -rf "$dir"
}

inject_hook_priority_always_bypasses_lifecycle_gate() {
  # Verifies that a priority:always card is NOT demoted by the lifecycle gate
  # even when its status is stale or superseded — tier1 is orthogonal to status.
  # Steps:
  #   1. Create MEMORY.md with always-stale.md (priority:always, status:stale) and
  #      active.md (priority:normal, status:active, budget-filling cards)
  #   2. Fill budget with 20 normal cards so any tier1 bypass is visible
  #   3. Run the hook
  #   4. Assert always-stale.md appears in output (tier1 — not demoted or budget-cut)
  local name="inject-hook/priority-always-bypasses-lifecycle-gate" dir cwd mem payload output status i
  should_run "$name" || return 0
  dir="$(mktemp -d)"
  cwd="$dir/workspace"
  mkdir -p "$cwd"
  encoded="$(inject_encoded_path "$cwd")"
  mem="$dir/projects/$encoded/memory"
  mkdir -p "$mem"
  {
    printf '# test\n'
    # 20 normal active cards to fill the tier2 budget
    for i in $(seq 1 20); do
      printf -- '---\npriority: normal\nstatus: active\n---\nCard %d\n' "$i" > "$mem/c$i.md"
      printf -- '- [c%d](c%d.md) — normal active card %d\n' "$i" "$i" "$i"
    done
    printf -- '- [always-stale](always-stale.md) — must inject despite stale status\n'
  } > "$mem/MEMORY.md"
  printf -- '---\npriority: always\nstatus: stale\n---\nAlways stale content\n' > "$mem/always-stale.md"
  payload="{\"cwd\":\"$cwd\",\"prompt\":\"zzz\"}"
  output=$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$dir" "$MEM_HOOK" 2>/dev/null)
  status=$?
  if [[ "$status" == "0" && "$output" == *"always-stale"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q\n' "$name" "$status" "${output: -200}"
  fi
  rm -rf "$dir"
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
inject_hook_always_priority_bypasses_budget
inject_hook_prompt_aware_scoring
inject_hook_byte_cap_truncates_before_entry_cap
inject_hook_default_home_fallback
inject_hook_status_active_no_longer_pins
inject_hook_keyword_hit_records_access
inject_hook_frecency_ranks_accessed_above_cold
inject_hook_keyword_tier_dominates_frecency
inject_hook_sidecar_write_failure_is_best_effort
inject_hook_malformed_sidecar_degrades_to_zero
inject_hook_stale_card_demoted_below_active
inject_hook_superseded_card_demoted_below_active
inject_hook_missing_status_treated_as_active
inject_hook_archived_card_treated_as_active
inject_hook_priority_always_bypasses_lifecycle_gate
memory_usage_commit_decay_halves
memory_usage_commit_concurrent_no_lost_updates
memory_age_bucket_mapping

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
# guard-inject-context
# =============================================================================

echo
$LIST || echo "== guard-inject-context =="

PMCTL_CLI="$REPO_ROOT/cli/pmctl"

# Stand up an indexed git fixture repo with one knowledge doc, isolated from the
# live install: context DB is repo-local, telemetry goes to the given state root.
# Returns non-zero (with a printed reason) if the index build did not produce a
# DB — a silent setup failure here would otherwise surface as a confusing
# empty-output assertion failure in the case itself.
ctx_inject_make_repo() {
  local repo="$1" state_root="$2" idx_err
  idx_err="$(mktemp)"
  mkdir -p "$repo/docs"
  git -C "$repo" init -q
  printf '# Notes\n\n## Gate verdict\n\nctxinjectterm knowledge body.\n' > "$repo/docs/notes.md"
  PM_DISPATCH_STATE_ROOT="$state_root" bash "$PMCTL_CLI" context index "$repo" >/dev/null 2>"$idx_err"
  if [[ ! -f "$repo/.pm-dispatch/ctx/context.db" ]]; then
    printf '  SETUP-FAIL ctx_inject_make_repo: no context.db after index: %s\n' "$(<"$idx_err")"
    rm -f "$idx_err"
    return 1
  fi
  rm -f "$idx_err"
}

ctx_inject_case() {
  # Shared assertion runner: feeds a payload to the ctx hook and checks
  # exit 0 plus expected/forbidden output substrings.
  # Args: name payload expect_mode ("hit" = auto-context block present,
  #       "silent" = empty stdout) [extra env assignments via _CTX_CASE_ENV array]
  # A generous scan timeout is set for every case: the production default (10s)
  # can be exceeded on a CPU-saturated machine (run-all-tests --jobs N), and a
  # timed-out scan degrades to silence — which would flip "hit" cases red for
  # load reasons, not correctness ones.
  local name="$1" payload="$2" expect="$3" state_root="$4"
  local output status hook_err
  hook_err="$(mktemp)"
  output=$(printf '%s' "$payload" \
    | env PM_DISPATCH_STATE_ROOT="$state_root" \
      PM_DISPATCH_PROMPT_CONTEXT_TIMEOUT=120 \
      "${_CTX_CASE_ENV[@]+"${_CTX_CASE_ENV[@]}"}" \
      "$CTX_HOOK" 2>"$hook_err")
  status=$?
  local ok=0
  if [[ "$expect" == "hit" ]]; then
    [[ "$status" == "0" \
      && "$output" == ===\ auto-context:*$'\n'* \
      && "$output" == *"knowledge_hits:"* \
      && "$output" == *"docs/notes.md"* \
      && "$output" == *$'\n'===\ end\ auto-context\ === ]] && ok=1
  else
    [[ "$status" == "0" && -z "$output" ]] && ok=1
  fi
  if [[ "$ok" == "1" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — exit=%s output=%q stderr=%q\n' "$name" "$status" "$output" "$(<"$hook_err")"
  fi
  rm -f "$hook_err"
}

ctx_inject_hook_happy_path() {
  # Verifies knowledge hits are injected as an auto-context block when the cwd
  # is inside an indexed git repo and the prompt matches a knowledge doc.
  # Steps:
  #   1. Create a git fixture repo with docs/notes.md and build its index
  #   2. Run the hook with a payload whose prompt contains the matching term
  #   3. Assert exit 0, auto-context delimiters, knowledge_hits with the doc ref
  local name="ctx-inject-hook/happy-path"
  should_run "$name" || return 0
  command -v sqlite3 >/dev/null 2>&1 || { PASS=$((PASS+1)); return 0; }
  local dir repo state_root
  dir="$(mktemp -d)"; repo="$dir/repo"; state_root="$dir/state"
  if ! ctx_inject_make_repo "$repo" "$state_root"; then
    FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); rm -rf "$dir"; return 0
  fi
  local _CTX_CASE_ENV=()
  ctx_inject_case "$name" "{\"cwd\":\"$repo\",\"prompt\":\"tell me about ctxinjectterm behavior\"}" hit "$state_root"
  rm -rf "$dir"
}

ctx_inject_hook_subdir_resolves_toplevel() {
  # Verifies the hook resolves the git toplevel from a nested cwd — the scan
  # target is the repo root, not the subdirectory.
  # Steps:
  #   1. Create an indexed git fixture repo with a nested subdir
  #   2. Run the hook with cwd set to the subdir and a matching prompt
  #   3. Assert the knowledge hit from the repo root is injected
  local name="ctx-inject-hook/subdir-resolves-toplevel"
  should_run "$name" || return 0
  command -v sqlite3 >/dev/null 2>&1 || { PASS=$((PASS+1)); return 0; }
  local dir repo state_root
  dir="$(mktemp -d)"; repo="$dir/repo"; state_root="$dir/state"
  if ! ctx_inject_make_repo "$repo" "$state_root"; then
    FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); rm -rf "$dir"; return 0
  fi
  mkdir -p "$repo/packages/app"
  local _CTX_CASE_ENV=()
  ctx_inject_case "$name" "{\"cwd\":\"$repo/packages/app\",\"prompt\":\"tell me about ctxinjectterm behavior\"}" hit "$state_root"
  rm -rf "$dir"
}

ctx_inject_hook_non_git_cwd_silent() {
  # Verifies a cwd outside any git worktree exits 0 with empty stdout.
  # Steps:
  #   1. Create a plain (non-git) directory
  #   2. Run the hook with a valid payload pointing at it
  #   3. Assert exit 0 and empty stdout
  local name="ctx-inject-hook/non-git-cwd-silent"
  should_run "$name" || return 0
  local dir
  dir="$(mktemp -d)"
  local _CTX_CASE_ENV=()
  ctx_inject_case "$name" "{\"cwd\":\"$dir\",\"prompt\":\"tell me about ctxinjectterm behavior\"}" silent "$dir/state"
  rm -rf "$dir"
}

ctx_inject_hook_no_db_silent() {
  # Verifies a git repo with no context index stays silent — the hook must not
  # trigger a first full index build on the prompt path (AUTOBUILD=0).
  # Steps:
  #   1. Create a git fixture repo WITHOUT building an index
  #   2. Run the hook with a matching prompt
  #   3. Assert exit 0, empty stdout, and no context.db created
  local name="ctx-inject-hook/no-db-silent"
  should_run "$name" || return 0
  local dir repo
  dir="$(mktemp -d)"; repo="$dir/repo"
  mkdir -p "$repo/docs"
  git -C "$repo" init -q
  printf '## Gate verdict\n\nctxinjectterm knowledge body.\n' > "$repo/docs/notes.md"
  local _CTX_CASE_ENV=()
  ctx_inject_case "$name" "{\"cwd\":\"$repo\",\"prompt\":\"tell me about ctxinjectterm behavior\"}" silent "$dir/state"
  if [[ -e "$repo/.pm-dispatch/ctx/context.db" ]]; then
    FAIL=$((FAIL+1)); FAILED_CASES+=("$name/no-autobuild")
    printf '  FAIL  %s — hook auto-built context.db on the prompt path\n' "$name"
  fi
  rm -rf "$dir"
}

ctx_inject_hook_no_hits_silent() {
  # Verifies an indexed repo with a non-matching prompt stays silent.
  # Steps:
  #   1. Create an indexed git fixture repo
  #   2. Run the hook with a prompt matching nothing in the index
  #   3. Assert exit 0 and empty stdout
  local name="ctx-inject-hook/no-hits-silent"
  should_run "$name" || return 0
  command -v sqlite3 >/dev/null 2>&1 || { PASS=$((PASS+1)); return 0; }
  local dir repo state_root
  dir="$(mktemp -d)"; repo="$dir/repo"; state_root="$dir/state"
  if ! ctx_inject_make_repo "$repo" "$state_root"; then
    FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); rm -rf "$dir"; return 0
  fi
  local _CTX_CASE_ENV=()
  ctx_inject_case "$name" "{\"cwd\":\"$repo\",\"prompt\":\"zzzznomatch yyyynomatch xxxxnomatch\"}" silent "$state_root"
  rm -rf "$dir"
}

ctx_inject_hook_short_prompt_silent() {
  # Verifies trivially short prompts (< 12 chars) skip the scan entirely.
  # Steps:
  #   1. Create an indexed git fixture repo
  #   2. Run the hook with a short prompt
  #   3. Assert exit 0 and empty stdout
  local name="ctx-inject-hook/short-prompt-silent"
  should_run "$name" || return 0
  command -v sqlite3 >/dev/null 2>&1 || { PASS=$((PASS+1)); return 0; }
  local dir repo state_root
  dir="$(mktemp -d)"; repo="$dir/repo"; state_root="$dir/state"
  if ! ctx_inject_make_repo "$repo" "$state_root"; then
    FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); rm -rf "$dir"; return 0
  fi
  local _CTX_CASE_ENV=()
  ctx_inject_case "$name" "{\"cwd\":\"$repo\",\"prompt\":\"hi there\"}" silent "$state_root"
  rm -rf "$dir"
}

ctx_inject_hook_kill_switch() {
  # Verifies PM_DISPATCH_DISABLE_PROMPT_CONTEXT=1 disables the scan even when
  # a hit would otherwise be injected.
  # Steps:
  #   1. Create an indexed git fixture repo with a matching prompt setup
  #   2. Run the hook with the kill-switch env set
  #   3. Assert exit 0 and empty stdout
  local name="ctx-inject-hook/kill-switch"
  should_run "$name" || return 0
  command -v sqlite3 >/dev/null 2>&1 || { PASS=$((PASS+1)); return 0; }
  local dir repo state_root
  dir="$(mktemp -d)"; repo="$dir/repo"; state_root="$dir/state"
  if ! ctx_inject_make_repo "$repo" "$state_root"; then
    FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); rm -rf "$dir"; return 0
  fi
  local _CTX_CASE_ENV=(PM_DISPATCH_DISABLE_PROMPT_CONTEXT=1)
  ctx_inject_case "$name" "{\"cwd\":\"$repo\",\"prompt\":\"tell me about ctxinjectterm behavior\"}" silent "$state_root"
  rm -rf "$dir"
}

ctx_inject_hook_malformed_payload() {
  # Verifies malformed JSON stdin never crashes or blocks the prompt.
  # Steps:
  #   1. Run the hook with non-JSON stdin
  #   2. Assert exit 0 and empty stdout
  local name="ctx-inject-hook/malformed-payload"
  should_run "$name" || return 0
  local dir output status
  dir="$(mktemp -d)"
  output=$(printf '%s' 'not-json{{{' | PM_DISPATCH_STATE_ROOT="$dir/state" "$CTX_HOOK" 2>/dev/null)
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

ctx_inject_hook_empty_stdin() {
  # Verifies empty stdin exits 0 without stdout.
  # Steps:
  #   1. Run the hook with empty stdin
  #   2. Assert exit 0 and empty stdout
  local name="ctx-inject-hook/empty-stdin"
  should_run "$name" || return 0
  local dir output status
  dir="$(mktemp -d)"
  output=$(printf '' | PM_DISPATCH_STATE_ROOT="$dir/state" "$CTX_HOOK" 2>/dev/null)
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

ctx_inject_hook_happy_path
ctx_inject_hook_subdir_resolves_toplevel
ctx_inject_hook_non_git_cwd_silent
ctx_inject_hook_no_db_silent
ctx_inject_hook_no_hits_silent
ctx_inject_hook_short_prompt_silent
ctx_inject_hook_kill_switch
ctx_inject_hook_malformed_payload
ctx_inject_hook_empty_stdin

# =============================================================================
# guard-session-summary
# =============================================================================

echo
$LIST || echo "== guard-session-summary =="

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
  #   1. Invoke test-guards.sh --filter with a pattern matching exactly one known case
  #   2. Assert the output reports exactly "1 passed, 0 failed"
  local name="meta/filter-runs-only-matching"
  should_run "$name" || return 0
  local out
  out=$(bash "$SCRIPT_DIR/test-guards.sh" --filter "pm: Edit memory file" 2>&1)
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
  #   1. Invoke test-guards.sh --list
  #   2. Assert exit status is 0
  #   3. Assert the printed line count exceeds 140 (confirming the full registry)
  local name="meta/list-exits-zero-with-count"
  should_run "$name" || return 0
  local out count status
  out=$(bash "$SCRIPT_DIR/test-guards.sh" --list 2>&1)
  status=$?
  count=$(printf '%s\n' "$out" | wc -l)
  if [[ "$status" == "0" && "$count" -gt 140 ]]; then
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
  #   1. Invoke test-guards.sh --filter with a pattern known to match nothing
  #   2. Assert exit status is nonzero
  #   3. Assert stderr/stdout contains "no tests matched"
  local name="meta/filter-no-match-exits-nonzero"
  should_run "$name" || return 0
  local out status
  out=$(bash "$SCRIPT_DIR/test-guards.sh" --filter "__no_such_case_xyz__" 2>&1) && status=$? || status=$?
  if [[ "$status" -ne 0 && "$out" == *"no tests matched"* ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s — status=%s out=%q\n' "$name" "$status" "$out"
  fi
}

meta_filter_runs_only_matching
meta_list_exits_zero_with_count
meta_filter_no_match_exits_nonzero

# =============================================================================
# summary
# =============================================================================
th_summary
