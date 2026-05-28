#!/usr/bin/env bash
# Regression suite for scripts/lib/hook-framework.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init --format=indent-2sp-quiet "$@"

TEST_LOG_FILE="$tmp_root/hooks.log"

run_in_framework() {
  local stdin="$1"
  shift
  (
    # shellcheck source=scripts/lib/portable.sh
    . "$SCRIPT_DIR/lib/portable.sh"
    HOOK_NAME="test-hook-framework"
    LOG_FILE="$TEST_LOG_FILE"
    HK_BYPASS_ENV="CLAUDE_HOOK_TEST"
    HK_AGENT_TYPE="test-agent"
    HK_TOOL_NAME="TestTool"
    # shellcheck source=scripts/lib/hook-framework.sh
    . "$SCRIPT_DIR/lib/hook-framework.sh"
    "$@"
  ) <<<"$stdin"
}

fw_read_json() {
  hk_read_json
}

fw_read_json_populates_agent() {
  hk_read_json
  [[ "$HK_AGENT_TYPE" == "project-pm" ]]
}

fw_jq_agent_type() {
  hk_read_json
  hk_jq '.agent_type'
}

fw_deny() {
  HK_TARGET="/tmp/deny-target"
  hk_deny "blocked reason"
}

fw_allow() {
  HK_TARGET="/tmp/allow-target"
  hk_allow "allowed reason"
}

fw_bypass() {
  CLAUDE_HOOK_TEST=off
  HK_TARGET="/tmp/bypass-target"
  hk_check_bypass CLAUDE_HOOK_TEST
  exit 99
}

fw_validate_empty_path() {
  hk_validate_path ""
}

fw_validate_relative_path() {
  hk_validate_path "relative/path.md"
}

fw_validate_path_arg() {
  hk_validate_path "$1"
  printf '%s\n' "$HK_ABS_PATH"
}

fw_validate_path_realpath_failure() {
  realpath_m() {
    return 1
  }
  hk_validate_path "/tmp/path-that-realpath-cannot-resolve"
}

fw_require_jq_missing() {
  mkdir -p "$tmp_root/no-jq-bin"
  PATH="$tmp_root/no-jq-bin"
  hk_require_jq
}

fw_require_realpath_available() {
  hk_require_realpath
}

fw_require_realpath_missing() {
  PATH=""
  hk_require_realpath
}

test_read_json_malformed() {
  local name="hk_read_json: malformed JSON exits 2"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework 'not-json' fw_read_json 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"malformed JSON on stdin"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_read_json_populates_agent() {
  local name="hk_read_json: populates HK_AGENT_TYPE"
  should_run "$name" || return 0
  local status=0
  run_in_framework '{"agent_type":"project-pm","tool_name":"Edit","tool_input":{}}' \
    fw_read_json_populates_agent >/dev/null 2>&1 || status=$?
  assert_exit "$name" "$status" 0 && pass "$name"
}

test_jq_returns_agent_type() {
  local name="hk_jq: returns agent_type field"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{}}' \
    fw_jq_agent_type 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == "codex-executor" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status expected codex-executor, got: $out"
  fi
}

test_deny_audits_and_exits() {
  local name="hk_deny: exits 2 and audits deny"
  should_run "$name" || return 0
  : > "$TEST_LOG_FILE"
  local status=0
  run_in_framework '{}' fw_deny >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 2 ]] &&
    grep -Fq 'decision=deny' "$TEST_LOG_FILE" &&
    grep -Fq 'reason=blocked\ reason' "$TEST_LOG_FILE"; then
    pass "$name"
  else
    fail "$name" "status=$status log=$(cat "$TEST_LOG_FILE" 2>/dev/null)"
  fi
}

test_allow_audits_and_exits() {
  local name="hk_allow: exits 0 and audits allow"
  should_run "$name" || return 0
  : > "$TEST_LOG_FILE"
  local status=0
  run_in_framework '{}' fw_allow >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 ]] &&
    grep -Fq 'decision=allow' "$TEST_LOG_FILE" &&
    grep -Fq 'target=/tmp/allow-target' "$TEST_LOG_FILE"; then
    pass "$name"
  else
    fail "$name" "status=$status log=$(cat "$TEST_LOG_FILE" 2>/dev/null)"
  fi
}

test_bypass_allows() {
  local name="hk_check_bypass: env off allows before policy"
  should_run "$name" || return 0
  : > "$TEST_LOG_FILE"
  local status=0
  run_in_framework '{}' fw_bypass >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 ]] &&
    grep -Fq 'decision=bypass' "$TEST_LOG_FILE" &&
    grep -Fq 'CLAUDE_HOOK_TEST=off' "$TEST_LOG_FILE"; then
    pass "$name"
  else
    fail "$name" "status=$status log=$(cat "$TEST_LOG_FILE" 2>/dev/null)"
  fi
}

test_validate_empty_path() {
  local name="hk_validate_path: denies empty path"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' fw_validate_empty_path 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"tool_input.file_path empty"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_validate_relative_path() {
  local name="hk_validate_path: denies non-absolute path"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' fw_validate_relative_path 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"file_path must be absolute"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_validate_valid_absolute_path() {
  local name="hk_validate_path: valid absolute path"
  should_run "$name" || return 0
  local tmp out status=0
  tmp="$(mktemp "$tmp_root/valid-path.XXXXXX")"
  out="$(run_in_framework '{}' fw_validate_path_arg "$tmp" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && -n "$out" && "$out" == /* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status HK_ABS_PATH=$out"
  fi
}

test_validate_realpath_failure() {
  local name="hk_validate_path: realpath-like failure"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' fw_validate_path_realpath_failure 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"realpath failed on file_path"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_require_jq_missing() {
  local name="hk_require_jq: exits 2 when jq absent"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' fw_require_jq_missing 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"jq missing on PATH"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_require_realpath_available() {
  local name="hk_require_realpath: realpath present"
  should_run "$name" || return 0
  local status=0
  if command -v realpath >/dev/null 2>&1; then
    run_in_framework '{}' fw_require_realpath_available >/dev/null 2>&1 || status=$?
    assert_exit "$name" "$status" 0 && pass "$name"
  else
    pass "$name"
  fi
}

test_require_realpath_missing() {
  local name="hk_require_realpath: behavior when missing"
  should_run "$name" || return 0
  local out platform status=0
  case "${PM_DISPATCH_PLATFORM:-${OSTYPE:-}}" in
    windows|msys*|cygwin*|mingw*) platform="windows" ;;
    *) platform="non-windows" ;;
  esac
  out="$(run_in_framework '{}' fw_require_realpath_missing 2>&1)" || status=$?
  if [[ "$platform" == "windows" ]]; then
    assert_exit "$name" "$status" 0 && pass "$name"
  elif [[ "$status" -eq 2 && "$out" == *"realpath missing on PATH"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_read_json_malformed
test_read_json_populates_agent
test_jq_returns_agent_type
test_deny_audits_and_exits
test_allow_audits_and_exits
test_bypass_allows
test_validate_empty_path
test_validate_relative_path
test_validate_valid_absolute_path
test_validate_realpath_failure
test_require_jq_missing
test_require_realpath_available
test_require_realpath_missing

th_summary
