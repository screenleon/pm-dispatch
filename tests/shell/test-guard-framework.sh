#!/usr/bin/env bash
# Regression suite for runtime/lib/guard-framework.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init --format=indent-2sp-quiet "$@"

TEST_LOG_FILE="$tmp_root/hooks.log"

run_in_framework() {
  local stdin="$1"
  shift
  (
    # shellcheck source=runtime/lib/portable.sh
    . "$REPO_ROOT/runtime/lib/portable.sh"
    GUARD_NAME="test-guard-framework"
    LOG_FILE="$TEST_LOG_FILE"
    G_BYPASS_ENV="PM_GUARD_TEST"
    G_AGENT_TYPE="test-agent"
    G_TOOL_NAME="TestTool"
    # shellcheck source=runtime/lib/guard-framework.sh
    . "$REPO_ROOT/runtime/lib/guard-framework.sh"
    "$@"
  ) <<<"$stdin"
}

fw_read_json() {
  g_read_json
}

fw_read_json_populates_agent() {
  g_read_json
  [[ "$G_AGENT_TYPE" == "project-pm" ]]
}

fw_read_json_populates_tool_name() {
  g_read_json
  [[ "$G_TOOL_NAME" == "Bash" ]]
}

fw_read_json_populates_tool_input() {
  g_read_json
  [[ "$G_TOOL_INPUT" == '{"command":"ls"}' ]]
}

fw_read_json_defaults_tool_input() {
  g_read_json
  [[ "$G_TOOL_INPUT" == "{}" ]]
}

fw_jq_agent_type() {
  g_read_json
  g_jq '.agent_type'
}

fw_deny() {
  G_TARGET="/tmp/deny-target"
  g_deny "blocked reason"
}

fw_allow() {
  G_TARGET="/tmp/allow-target"
  g_allow "allowed reason"
}

fw_bypass() {
  PM_GUARD_TEST=off
  G_TARGET="/tmp/bypass-target"
  g_check_bypass PM_GUARD_TEST
  exit 99
}

fw_validate_empty_path() {
  g_validate_path ""
}

fw_validate_relative_path() {
  g_validate_path "relative/path.md"
}

fw_validate_path_arg() {
  g_validate_path "$1"
  printf '%s\n' "$G_ABS_PATH"
}

fw_validate_path_realpath_failure() {
  realpath_m() {
    return 1
  }
  g_validate_path "/tmp/path-that-realpath-cannot-resolve"
}

fw_require_jq_missing() {
  mkdir -p "$tmp_root/no-jq-bin"
  PATH="$tmp_root/no-jq-bin"
  g_require_jq
}

fw_require_realpath_available() {
  g_require_realpath
}

fw_require_realpath_missing() {
  PATH=""
  g_require_realpath
}

# Behavior: g_read_json rejects malformed JSON with a deny-style exit.
# Steps: call g_read_json with invalid input, assert exit code and stderr.
test_read_json_malformed() {
  local name="g_read_json: malformed JSON exits 2"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework 'not-json' fw_read_json 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"malformed JSON on stdin"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: g_read_json populates G_AGENT_TYPE from JSON agent_type field.
# Steps: call g_read_json with agent_type project-pm, assert G_AGENT_TYPE equals project-pm.
test_read_json_populates_agent() {
  local name="g_read_json: populates G_AGENT_TYPE"
  should_run "$name" || return 0
  local status=0
  run_in_framework '{"agent_type":"project-pm","tool_name":"Edit","tool_input":{}}' \
    fw_read_json_populates_agent >/dev/null 2>&1 || status=$?
  assert_exit "$name" "$status" 0 && pass "$name"
}

# Behavior: g_jq reads fields from the JSON captured by g_read_json.
# Steps: call g_read_json then g_jq .agent_type, assert stdout is the agent type.
test_jq_returns_agent_type() {
  local name="g_jq: returns agent_type field"
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

# Behavior: g_read_json populates G_TOOL_NAME from JSON tool_name field.
# Steps: call g_read_json with tool_name Bash, assert G_TOOL_NAME equals Bash.
test_read_json_populates_tool_name() {
  local name="g_read_json: populates G_TOOL_NAME"
  should_run "$name" || return 0
  local status=0
  run_in_framework '{"agent_type":"codex","tool_name":"Bash","tool_input":{"command":"ls"}}' \
    fw_read_json_populates_tool_name >/dev/null 2>&1 || status=$?
  assert_exit "$name" "$status" 0 && pass "$name"
}

# Behavior: g_read_json populates G_TOOL_INPUT with a compact JSON object when tool_input is present.
# Steps: call g_read_json with tool_input, assert G_TOOL_INPUT equals the parsed object.
test_read_json_populates_tool_input() {
  local name="g_read_json: populates G_TOOL_INPUT from JSON"
  should_run "$name" || return 0
  local status=0
  run_in_framework '{"agent_type":"codex","tool_name":"Bash","tool_input":{"command":"ls"}}' \
    fw_read_json_populates_tool_input >/dev/null 2>&1 || status=$?
  assert_exit "$name" "$status" 0 && pass "$name"
}

# Behavior: g_read_json defaults G_TOOL_INPUT to an empty JSON object when tool_input is absent.
# Steps: call g_read_json without tool_input, assert G_TOOL_INPUT equals {}.
test_read_json_defaults_tool_input() {
  local name="g_read_json: G_TOOL_INPUT defaults to {}"
  should_run "$name" || return 0
  local status=0
  run_in_framework '{"agent_type":"codex","tool_name":"Bash"}' \
    fw_read_json_defaults_tool_input >/dev/null 2>&1 || status=$?
  assert_exit "$name" "$status" 0 && pass "$name"
}

# Behavior: g_deny audits a deny decision and exits with the hook-deny status.
# Steps: call g_deny through the framework, assert exit code and audit fields.
test_deny_audits_and_exits() {
  local name="g_deny: exits 2 and audits deny"
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

# Behavior: g_allow audits an allow decision and exits successfully.
# Steps: call g_allow through the framework, assert exit code and audit fields.
test_allow_audits_and_exits() {
  local name="g_allow: exits 0 and audits allow"
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

# Behavior: g_check_bypass allows execution when the configured bypass env var is off.
# Steps: set bypass env to off, call g_check_bypass, assert bypass audit and zero exit.
test_bypass_allows() {
  local name="g_check_bypass: env off allows before policy"
  should_run "$name" || return 0
  : > "$TEST_LOG_FILE"
  local status=0
  run_in_framework '{}' fw_bypass >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 ]] &&
    grep -Fq 'decision=bypass' "$TEST_LOG_FILE" &&
    grep -Fq 'PM_GUARD_TEST=off' "$TEST_LOG_FILE"; then
    pass "$name"
  else
    fail "$name" "status=$status log=$(cat "$TEST_LOG_FILE" 2>/dev/null)"
  fi
}

# Behavior: g_validate_path denies an empty path input.
# Steps: call g_validate_path with an empty string, assert deny exit and message.
test_validate_empty_path() {
  local name="g_validate_path: denies empty path"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' fw_validate_empty_path 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"tool_input.file_path empty"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: g_validate_path denies relative path input.
# Steps: call g_validate_path with a relative path, assert deny exit and message.
test_validate_relative_path() {
  local name="g_validate_path: denies non-absolute path"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' fw_validate_relative_path 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"file_path must be absolute"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: g_validate_path accepts an existing absolute path and stores the resolved path.
# Steps: create a temp file, call g_validate_path, assert successful exit and absolute output.
test_validate_valid_absolute_path() {
  local name="g_validate_path: valid absolute path"
  should_run "$name" || return 0
  local tmp out status=0
  tmp="$(mktemp "$tmp_root/valid-path.XXXXXX")"
  out="$(run_in_framework '{}' fw_validate_path_arg "$tmp" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && -n "$out" && "$out" == /* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status G_ABS_PATH=$out"
  fi
}

# Behavior: g_validate_path denies when realpath resolution fails.
# Steps: stub realpath_m to fail, call g_validate_path, assert deny exit and message.
test_validate_realpath_failure() {
  local name="g_validate_path: realpath-like failure"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' fw_validate_path_realpath_failure 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"realpath failed on file_path"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: g_require_jq exits with deny status when jq is absent from PATH.
# Steps: clear PATH to a temp bin, call g_require_jq, assert exit code and message.
test_require_jq_missing() {
  local name="g_require_jq: exits 2 when jq absent"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' fw_require_jq_missing 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"jq missing on PATH"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: g_require_realpath returns successfully when realpath is available.
# Steps: when realpath exists on PATH, call g_require_realpath and assert zero exit.
test_require_realpath_available() {
  local name="g_require_realpath: realpath present"
  should_run "$name" || return 0
  local status=0
  if command -v realpath >/dev/null 2>&1; then
    run_in_framework '{}' fw_require_realpath_available >/dev/null 2>&1 || status=$?
    assert_exit "$name" "$status" 0 && pass "$name"
  else
    pass "$name"
  fi
}

# Behavior: g_require_realpath denies on non-Windows platforms when realpath is absent.
# Steps: clear PATH, call g_require_realpath, assert platform-specific exit behavior.
test_require_realpath_missing() {
  local name="g_require_realpath: behavior when missing"
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

# Behavior: g_to_posix_path is a no-op for non-drive-letter (POSIX) paths.
# Steps: call with an absolute POSIX path on the default platform; assert it is
# echoed unchanged with exit 0.
test_to_posix_noop() {
  local name="g_to_posix_path: POSIX path no-op"
  should_run "$name" || return 0
  local out status=0
  out="$(run_in_framework '{}' g_to_posix_path '/tmp/x/y')" || status=$?
  if [[ "$status" -eq 0 && "$out" == "/tmp/x/y" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: a Windows drive-letter path is converted to POSIX mount form via
# cygpath. Steps: force windows + a stub cygpath that maps C:/... -> /...;
# assert the converted path and exit 0.
test_to_posix_windows_convert() {
  local name="g_to_posix_path: Windows drive-letter -> POSIX via cygpath"
  should_run "$name" || return 0
  local stub out status=0
  stub="$(mktemp -d)"
  printf '#!/usr/bin/env bash\np="${!#}"; printf '\''%%s'\'' "/${p#?:/}"\n' > "$stub/cygpath"
  chmod +x "$stub/cygpath"
  out="$(PM_DISPATCH_PLATFORM=windows PATH="$stub:$PATH" run_in_framework '{}' g_to_posix_path 'C:/Users/foo')" || status=$?
  rm -rf "$stub"
  if [[ "$status" -eq 0 && "$out" == "/Users/foo" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: a drive-letter path with cygpath unavailable fails closed (return 2).
# Steps: force windows; rely on cygpath being absent (skip if the host has it).
test_to_posix_cygpath_unavailable() {
  local name="g_to_posix_path: drive-letter + no cygpath -> rc 2"
  should_run "$name" || return 0
  if command -v cygpath >/dev/null 2>&1; then
    $LIST || printf '  SKIP  %s (host has cygpath)\n' "$name"
    return 0
  fi
  local status=0
  PM_DISPATCH_PLATFORM=windows run_in_framework '{}' g_to_posix_path 'C:/x' >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status (expected 2)"
  fi
}

# Behavior: a drive-letter path where cygpath fails/produces empty output fails
# closed (return 3). Steps: force windows + a stub cygpath that exits nonzero.
test_to_posix_cygpath_fail() {
  local name="g_to_posix_path: drive-letter + cygpath fail -> rc 3"
  should_run "$name" || return 0
  local stub status=0
  stub="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$stub/cygpath"
  chmod +x "$stub/cygpath"
  PM_DISPATCH_PLATFORM=windows PATH="$stub:$PATH" run_in_framework '{}' g_to_posix_path 'C:/x' >/dev/null 2>&1 || status=$?
  rm -rf "$stub"
  if [[ "$status" -eq 3 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status (expected 3)"
  fi
}

test_to_posix_noop
test_to_posix_windows_convert
test_to_posix_cygpath_unavailable
test_to_posix_cygpath_fail
test_read_json_malformed
test_read_json_populates_agent
test_jq_returns_agent_type
test_read_json_populates_tool_name
test_read_json_populates_tool_input
test_read_json_defaults_tool_input
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
