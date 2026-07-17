#!/usr/bin/env bash
# Regression tests for pmctl safe bash command.
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

run_safe_cmd() {
  local _out="$1" _err="$2"
  shift 2
  "$PMCTL" "$@" > "$_out" 2> "$_err"
}

case_safe_bash_missing_role() {
  local name="pmctl safe bash: exits 2 when --role is missing"
  should_run "$name" || return 0
  # Behavior: safe bash without --role exits with a usage error before attempting any guard check or command.
  # Steps: invoke safe bash --runtime codex "echo hi" omitting --role; assert exit 2.
  local out err status=0
  out="$tmp_root/safe-mr.out"
  err="$tmp_root/safe-mr.err"
  run_safe_cmd "$out" "$err" safe bash --runtime codex "echo hi" && status=$? || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status err=$(<"$err")"
  fi
}

case_safe_bash_missing_runtime() {
  local name="pmctl safe bash: exits 2 when --runtime is missing"
  should_run "$name" || return 0
  # Behavior: safe bash without --runtime exits with a usage error before attempting any guard check or command.
  # Steps: invoke safe bash --role executor "echo hi" omitting --runtime; assert exit 2.
  local out err status=0
  out="$tmp_root/safe-mrt.out"
  err="$tmp_root/safe-mrt.err"
  run_safe_cmd "$out" "$err" safe bash --role executor "echo hi" && status=$? || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status err=$(<"$err")"
  fi
}

case_safe_bash_missing_command() {
  local name="pmctl safe bash: exits 2 when command is missing"
  should_run "$name" || return 0
  # Behavior: safe bash with --role and --runtime but no command exits with a usage error.
  # Steps: invoke safe bash --role executor --runtime codex with no command argument; assert exit 2.
  local out err status=0
  out="$tmp_root/safe-mc.out"
  err="$tmp_root/safe-mc.err"
  run_safe_cmd "$out" "$err" safe bash --role executor --runtime codex && status=$? || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status err=$(<"$err")"
  fi
}

case_safe_bash_unknown_flag() {
  local name="pmctl safe bash: exits 2 for unknown flag"
  should_run "$name" || return 0
  # Behavior: safe bash rejects unrecognised flags with a usage error.
  # Steps: invoke safe bash with --frobnicate; assert exit 2.
  local out err status=0
  out="$tmp_root/safe-uf.out"
  err="$tmp_root/safe-uf.err"
  run_safe_cmd "$out" "$err" safe bash --role executor --runtime codex --frobnicate "echo hi" \
    && status=$? || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status err=$(<"$err")"
  fi
}

case_safe_bash_executor_prebash_fail_closed() {
  local name="pmctl safe bash: executor pre-bash fail-closed exit 3 (no policy after codex-executor retirement) and does not execute"
  should_run "$name" || return 0
  # Behavior: the codex-executor subagent and its bash guard were retired, so no executor runtime
  #   registers a pre-bash policy. safe bash --role executor must fail closed (exit 3) and NOT run the
  #   command body. (Before retirement this path drove the codex bash guard and could exit 0.)
  # Steps: create a sentinel; invoke safe bash --role executor --runtime codex "rm -f <sentinel>";
  #   assert exit 3 AND sentinel still exists (never executed).
  local out err status=0 sentinel
  out="$tmp_root/safe-exec-nopolicy.out"
  err="$tmp_root/safe-exec-nopolicy.err"
  sentinel="$tmp_root/safe-exec-sentinel.txt"
  printf 'sentinel\n' > "$sentinel"
  run_safe_cmd "$out" "$err" safe bash \
    --role executor --runtime codex "rm -f $sentinel" && status=$? || status=$?
  if [[ "$status" -eq 3 && -f "$sentinel" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 3 and sentinel intact, got status=$status sentinel_exists=$([[ -f $sentinel ]] && echo yes || echo no) err=$(<"$err")"
  fi
}

case_safe_bash_no_policy_exits_3() {
  local name="pmctl safe bash: no-policy role pre-bash exits exactly 3 (fail-closed) and does not execute"
  should_run "$name" || return 0
  # Behavior: when no guard policy is registered for the role/runtime/event, safe bash propagates
  #   the guard's fail-closed exit code 3 verbatim AND does not execute the command body. This is the
  #   exact-code contract assertion: 3 = cannot enforce, distinct from 2 = policy denied (the pre-write
  #   path still produces 2; see test-pmctl-guard.sh).
  # Steps: create a sentinel file; invoke safe bash --role pm --runtime claude "rm -f <sentinel>"
  #        (pm/pre-bash has no policy → guard returns 3); assert exit 3 AND sentinel still exists.
  local out err status=0 sentinel
  out="$tmp_root/safe-nopolicy.out"
  err="$tmp_root/safe-nopolicy.err"
  sentinel="$tmp_root/safe-nopolicy-sentinel.txt"
  printf 'sentinel\n' > "$sentinel"
  run_safe_cmd "$out" "$err" safe bash \
    --role pm --runtime claude "rm -f $sentinel" && status=$? || status=$?
  if [[ "$status" -eq 3 && -f "$sentinel" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 3 and sentinel intact, got status=$status sentinel_exists=$([[ -f $sentinel ]] && echo yes || echo no) err=$(<"$err")"
  fi
}

case_safe_bash_double_dash_separator() {
  local name="pmctl safe bash: -- separator passes remaining args as command"
  should_run "$name" || return 0
  # Behavior: safe bash accepts -- as an explicit separator; everything after it is treated as the command.
  # Steps: invoke safe bash --role executor --runtime codex -- "git status --short". The command parses
  #   (so the guard runs and fail-closes at exit 3, NOT exit 2 for "missing command") — proving -- was
  #   honored and the remaining args were captured as the command body.
  local out err status=0
  out="$tmp_root/safe-dd.out"
  err="$tmp_root/safe-dd.err"
  run_safe_cmd "$out" "$err" safe bash \
    --role executor --runtime codex -- "git status --short" && status=$? || status=$?
  if [[ "$status" -eq 3 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 3 (parsed + fail-closed), got $status err=$(<"$err")"
  fi
}

case_safe_bash_missing_role
case_safe_bash_missing_runtime
case_safe_bash_missing_command
case_safe_bash_unknown_flag
case_safe_bash_double_dash_separator
case_safe_bash_executor_prebash_fail_closed
case_safe_bash_no_policy_exits_3

th_summary
