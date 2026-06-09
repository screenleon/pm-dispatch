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
  # Behavior: safe bash runs the command and exits 0 when the guard policy allows it.
  # Steps: invoke safe bash --role executor --runtime codex "git status --short" (codex allowlisted read-only git); assert exit 0.
  local out err status=0
  out="$tmp_root/safe-ok.out"
  err="$tmp_root/safe-ok.err"
  # git status is in the codex bash guard allowlist (read-only git operation).
  run_safe_cmd "$out" "$err" safe bash \
    --role executor --runtime codex "git status --short" && status=$? || status=$?
  if [[ "$status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0, got $status err=$(<"$err")"
  fi
}

case_safe_bash_denied_role_exits_nonzero() {
  local name="pmctl safe bash: pm role pre-bash is denied (no policy registered)"
  should_run "$name" || return 0
  # Behavior: safe bash exits non-zero AND does not execute the command body when the guard denies the request.
  # Steps: create a sentinel file; invoke safe bash --role pm --runtime claude "rm -f <sentinel>";
  #        assert non-zero exit AND sentinel still exists (guard denied before exec).
  local out err status=0 sentinel
  out="$tmp_root/safe-deny.out"
  err="$tmp_root/safe-deny.err"
  sentinel="$tmp_root/safe-deny-sentinel.txt"
  printf 'sentinel\n' > "$sentinel"
  # pm/pre-bash has no policy → fail-closed deny (guard exits 3, safe bash exits 1).
  run_safe_cmd "$out" "$err" safe bash \
    --role pm --runtime claude "rm -f $sentinel" && status=$? || status=$?
  if [[ "$status" -ne 0 && -f "$sentinel" ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit and sentinel intact, got status=$status sentinel_exists=$([[ -f $sentinel ]] && echo yes || echo no)"
  fi
}

case_safe_bash_missing_role
case_safe_bash_missing_runtime
case_safe_bash_missing_command
case_safe_bash_unknown_flag
case_safe_bash_allowed_command_executes
case_safe_bash_denied_role_exits_nonzero

th_summary
