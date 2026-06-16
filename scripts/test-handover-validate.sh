#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-handover-validate" "$@"

# shellcheck source=scripts/lib/handover-validate.sh
. "$SCRIPT_DIR/lib/handover-validate.sh"

metadata_fixture() {
  local work_dir=${1:-$REPO_ROOT}
  local brief_file=${2:-/tmp/brief-handover-validate-test.md}

  cat <<EOF
handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $work_dir
brief_file: $brief_file
isolation_level: workspace-write
timeout: 1200
model: default
fallback_allowed: true
EOF
}

if should_run "handover_extract_block: extracts dispatch fenced block"; then
  input=$'before\n```dispatch_handover_v1\nhandover_version: 3\n---\ngoal: ok\n```\nafter'
  block="$(handover_extract_block "$input")"
  if [[ "$block" == $'handover_version: 3\n---\ngoal: ok' ]]; then
    pass "handover_extract_block: extracts dispatch fenced block"
  else
    fail "handover_extract_block: extracts dispatch fenced block" "unexpected block: $block"
  fi
fi

if should_run "handover_extract_fenced_block: extracts pr-gate handover fence"; then
  input=$'```pr-gate-handover_v1\n- role: reviewer\n  output_file: /tmp/result.md\n```\n'
  block="$(handover_extract_fenced_block pr-gate-handover_v1 "$input")"
  if [[ "$block" == $'- role: reviewer\n  output_file: /tmp/result.md' ]]; then
    pass "handover_extract_fenced_block: extracts pr-gate handover fence"
  else
    fail "handover_extract_fenced_block: extracts pr-gate handover fence" "unexpected block: $block"
  fi
fi

if should_run "handover_extract_block: rejects unterminated fence"; then
  input=$'```dispatch_handover_v1\nhandover_version: 3\n'
  if ! handover_extract_block "$input" >/dev/null 2>&1; then
    pass "handover_extract_block: rejects unterminated fence"
  else
    fail "handover_extract_block: rejects unterminated fence" "unterminated block should fail"
  fi
fi

if should_run "handover_get_field: returns exact field value"; then
  metadata="$(metadata_fixture)"
  value="$(handover_get_field "$metadata" working_dir)"
  [[ "$value" == "$REPO_ROOT" ]] && pass "handover_get_field: returns exact field value" || fail "handover_get_field: returns exact field value" "got: $value"
fi

if should_run "handover_get_field: rejects missing field"; then
  metadata="$(metadata_fixture)"
  if ! handover_get_field "$metadata" missing_field >/dev/null 2>&1; then
    pass "handover_get_field: rejects missing field"
  else
    fail "handover_get_field: rejects missing field" "missing field should fail"
  fi
fi

if should_run "handover_validate_all_metadata: accepts valid metadata"; then
  metadata="$(metadata_fixture "$REPO_ROOT" /tmp/brief-handover-validate-good.md)"
  if handover_validate_all_metadata "$metadata" >/dev/null 2>&1; then
    pass "handover_validate_all_metadata: accepts valid metadata"
  else
    fail "handover_validate_all_metadata: accepts valid metadata" "valid metadata rejected"
  fi
fi

if should_run "handover_validate_all_metadata: rejects invalid executor"; then
  metadata="$(metadata_fixture "$REPO_ROOT" /tmp/brief-handover-validate-bad.md | sed 's/^executor: codex$/executor: gemini/')"
  if ! handover_validate_all_metadata "$metadata" >/dev/null 2>&1; then
    pass "handover_validate_all_metadata: rejects invalid executor"
  else
    fail "handover_validate_all_metadata: rejects invalid executor" "invalid executor should fail"
  fi
fi

if should_run "handover_safe_argv: round trips internal spaces"; then
  safe_value="/tmp/normal path"
  safe_argv="$(handover_safe_argv working_dir "$safe_value")"
  round_trip="$(bash -c "printf '%s' $safe_argv")"
  if [[ "$round_trip" == "$safe_value" && "$safe_argv" == "/tmp/normal\\ path" ]]; then
    pass "handover_safe_argv: round trips internal spaces"
  else
    fail "handover_safe_argv: round trips internal spaces" "safe_argv=$safe_argv round_trip=$round_trip"
  fi
fi

if should_run "handover_safe_argv: rejects shell metacharacters"; then
  if ! handover_safe_argv working_dir '/tmp/bad;path' >/dev/null 2>&1; then
    pass "handover_safe_argv: rejects shell metacharacters"
  else
    fail "handover_safe_argv: rejects shell metacharacters" "metacharacter should fail"
  fi
fi

th_summary
