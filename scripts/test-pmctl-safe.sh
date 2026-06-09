#!/usr/bin/env bash
# Regression tests for pmctl safe bash command.
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/test-harness.sh"
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

case_safe_bash_allowed_command_executes() {
  local name="pmctl safe bash: allowed command executes and exits 0"
  should_run "$name" || return 0
  # Behavior: safe bash actually runs the command body (not just returns 0) and
  #   exits 0 when the guard policy allows it.
  # Steps: invoke safe bash --role executor --runtime codex
  #   "git rev-parse --is-inside-work-tree" (codex allowlisted read-only git with
  #   deterministic stdout); assert exit 0 AND stdout == "true". Asserting the
  #   deterministic output -- not just the wrapper exit -- isolates the execution
  #   side effect: replacing the `bash -c "$cmd"` body with a no-op that returns 0
  #   would still exit 0 but produce empty stdout, failing this test.
  local out err status=0 output
  out="$tmp_root/safe-ok.out"
  err="$tmp_root/safe-ok.err"
  # git rev-parse is in the codex bash guard read-only allowlist; the test runs
  # from within the repo work tree so --is-inside-work-tree prints exactly "true".
  run_safe_cmd "$out" "$err" safe bash \
    --role executor --runtime codex "git rev-parse --is-inside-work-tree" && status=$? || status=$?
  output="$(<"$out")"
  if [[ "$status" -eq 0 && "$output" == "true" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 + stdout 'true', got status=$status out=$output err=$(<"$err")"
  fi
}

case_safe_bash_no_policy_exits_3() {
  local name="pmctl safe bash: no-policy role pre-bash exits exactly 3 (fail-closed) and does not execute"
  should_run "$name" || return 0
  # Behavior: when no guard policy is registered for the role/runtime/event, safe bash propagates
  #   the guard's fail-closed exit code 3 verbatim AND does not execute the command body. This is the
  #   exact-code contract assertion: 3 = cannot enforce, distinct from 2 = policy denied (see below).
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

case_safe_bash_policy_denied_exits_2() {
  local name="pmctl safe bash: policy-denied command exits exactly 2 (denied, distinct from no-policy 3) and does not execute"
  should_run "$name" || return 0
  # Behavior: when a policy IS registered but denies the command, safe bash propagates the guard's
  #   denial exit code 2 verbatim AND does not execute the command body. Together with the no-policy
  #   case above this pins the exit-code contract that distinguishes "denied" (2) from "cannot enforce" (3).
  # Steps: create a sentinel file; invoke safe bash --role executor --runtime codex "rm -f <sentinel>"
  #        (codex bash guard is registered but rm is not allowlisted → guard returns 2);
  #        assert exit 2 AND sentinel still exists (denied before exec).
  local out err status=0 sentinel
  out="$tmp_root/safe-deny.out"
  err="$tmp_root/safe-deny.err"
  sentinel="$tmp_root/safe-deny-sentinel.txt"
  printf 'sentinel\n' > "$sentinel"
  run_safe_cmd "$out" "$err" safe bash \
    --role executor --runtime codex "rm -f $sentinel" && status=$? || status=$?
  if [[ "$status" -eq 2 && -f "$sentinel" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 and sentinel intact, got status=$status sentinel_exists=$([[ -f $sentinel ]] && echo yes || echo no) err=$(<"$err")"
  fi
}

case_safe_bash_double_dash_separator() {
  local name="pmctl safe bash: -- separator passes remaining args as command"
  should_run "$name" || return 0
  # Behavior: safe bash accepts -- as an explicit separator; everything after it is treated as the command.
  # Steps: invoke safe bash --role executor --runtime codex -- "git status --short"; assert exit 0.
  local out err status=0
  out="$tmp_root/safe-dd.out"
  err="$tmp_root/safe-dd.err"
  run_safe_cmd "$out" "$err" safe bash \
    --role executor --runtime codex -- "git status --short" && status=$? || status=$?
  if [[ "$status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0, got $status err=$(<"$err")"
  fi
}

case_safe_bash_missing_role
case_safe_bash_missing_runtime
case_safe_bash_missing_command
case_safe_bash_unknown_flag
case_safe_bash_double_dash_separator
case_safe_bash_allowed_command_executes
case_safe_bash_no_policy_exits_3
case_safe_bash_policy_denied_exits_2

th_summary
