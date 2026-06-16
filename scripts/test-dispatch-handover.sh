#!/usr/bin/env bash
# Regression tests for dispatch_handover_v1 extraction and validation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib/handover-validate.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$REPO_ROOT/scripts/lib/test-harness.sh"
th_init "$@"

run_case() {
  local name="$1"
  local fn="$2"
  should_run "$name" || return 0

  if "$fn"; then
    pass "$name"
  else
    fail "$name"
  fi
}

make_tmpdir() {
  mktemp -d -t dispatch-handover.XXXXXX
}

metadata_fixture() {
  local work_dir=${1:-$REPO_ROOT}
  local brief_file=${2:-/tmp/brief-pm-dispatch-test.md}

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

write_valid_handover() {
  local out=$1
  local work_dir=$2
  local brief_file=$3

  cat > "$out" <<EOF
PM summary outside fence.

\`\`\`dispatch_handover_v1
handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $work_dir
brief_file: $brief_file
isolation_level: workspace-write
timeout: 1200
model: default
fallback_allowed: true
---
working_dir: $work_dir
goal: Confirm handover extraction.
files:
  - read: README.md
acceptance:
  - Handover extracts cleanly.
\`\`\`
EOF
}

extract_handover() {
  local input_file=$1
  local meta_out=$2
  local body_out=$3
  local input
  local block

  : > "$meta_out"
  : > "$body_out"
  input="$(cat "$input_file")"
  block="$(handover_extract_block "$input")" || return 1
  handover_extract_metadata "$block" > "$meta_out" || return 1
  handover_extract_body "$block" > "$body_out"
}

meta_value() {
  local field=$1
  local meta_file=$2

  handover_get_field "$(cat "$meta_file")" "$field"
}

body_working_dir() {
  local body_file=$1

  awk -F': ' '$1 == "working_dir" { print substr($0, length("working_dir") + 3); exit }' "$body_file"
}

validate_contract() {
  local meta_file=$1
  local body_file=$2
  local metadata
  local meta_wd
  local body_wd

  metadata="$(cat "$meta_file")"
  handover_validate_all_metadata "$metadata" || return 1
  meta_wd="$(handover_get_field "$metadata" working_dir)" || return 1
  body_wd="$(body_working_dir "$body_file")"
  handover_validate_working_dir_match "$meta_wd" "$body_wd"
}

parse_footer() {
  local stdout_file=$1
  local out_file=$2

  awk '
    /^trace:[[:space:]]+/ { sub(/^trace:[[:space:]]+/, "trace="); print; next }
    /^last:[[:space:]]+/ { sub(/^last:[[:space:]]+/, "last="); print; next }
    /^stderr:[[:space:]]+/ { sub(/^stderr:[[:space:]]+/, "stderr="); print; next }
    /^exit:[[:space:]]+/ { sub(/^exit:[[:space:]]+/, "exit="); print; next }
  ' "$stdout_file" > "$out_file"
}

expect_reject() {
  local field=$1
  shift
  local output

  if output="$("$@" 2>&1 >/dev/null)"; then
    return 1
  fi
  grep -q "handover-validate: reject $field:" <<<"$output"
}

expect_reject_reason() {
  local field=$1
  local reason=$2
  shift 2
  local output

  if output="$("$@" 2>&1 >/dev/null)"; then
    return 1
  fi
  grep -q "handover-validate: reject $field:" <<<"$output" || return 1
  grep -q "$reason" <<<"$output"
}

expect_code_token() {
  local want_code=$1
  local want_token=$2
  shift 2
  local output
  local rc

  set +e
  output="$("$@" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [[ "$rc" -eq "$want_code" ]] || return 1
  grep -q "$want_token" <<<"$output"
}

expect_code_without_token() {
  local want_code=$1
  local want_token=$2
  shift 2
  local output
  local rc

  set +e
  output="$("$@" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [[ "$rc" -eq "$want_code" ]] || return 1
  ! grep -q "$want_token" <<<"$output"
}

# Behavior: A valid handover block extracts metadata and body and passes the shared contract validators.
# Steps:
#   1. Write a valid fenced handover block to a temp file and extract it through the lib helpers.
#   2. Assert metadata, body, and shared contract validation all succeed.
valid_handover_extracts_metadata_and_body_case() {
  local tmp input meta body ok=1
  tmp="$(make_tmpdir)"
  input="$tmp/input.md"
  meta="$tmp/meta.txt"
  body="$tmp/body.md"
  write_valid_handover "$input" "$REPO_ROOT" "/tmp/brief-pm-dispatch-test-1.md"
  extract_handover "$input" "$meta" "$body" || ok=0
  [[ "$(meta_value working_dir "$meta")" == "$REPO_ROOT" ]] || ok=0
  [[ "$(meta_value brief_file "$meta")" == "/tmp/brief-pm-dispatch-test-1.md" ]] || ok=0
  grep -q '^goal: Confirm handover extraction\.$' "$body" || ok=0
  validate_contract "$meta" "$body" >/dev/null 2>&1 || ok=0
  rm -rf "$tmp"
  [[ "$ok" -eq 1 ]]
}

# Behavior: Metadata and body working_dir disagreement is rejected by the shared match validator.
# Steps:
#   1. Write a valid handover and mutate only the body working_dir.
#   2. Assert shared contract validation rejects the mismatch.
working_dir_mismatch_rejects_case() {
  local tmp input meta body ok=1
  tmp="$(make_tmpdir)"
  input="$tmp/input.md"
  meta="$tmp/meta.txt"
  body="$tmp/body.md"
  write_valid_handover "$input" "$REPO_ROOT" "/tmp/brief-pm-dispatch-test-2.md"
  sed -i '0,/^working_dir: /! s|^working_dir: .*|working_dir: /tmp/other|' "$input"
  extract_handover "$input" "$meta" "$body" || ok=0
  validate_contract "$meta" "$body" >/dev/null 2>&1 && ok=0
  rm -rf "$tmp"
  [[ "$ok" -eq 1 ]]
}

# Behavior: Shell metacharacters in working_dir are rejected.
# Steps:
#   1. Validate representative working_dir values containing shell metacharacters.
#   2. Assert every value is rejected by the metadata value guard.
working_dir_shell_metacharacters_reject_case() {
  local bad

  for bad in "/tmp/x'bad" "/tmp/x;bad" '/tmp/x$bad'; do
    handover_validate_metadata_value working_dir "$bad" >/dev/null 2>&1 && return 1
  done
  return 0
}

# Behavior: Relative working_dir values are rejected.
# Steps:
#   1. Validate a working_dir without a leading slash.
#   2. Assert the reject audit says the path must be absolute.
working_dir_not_absolute_rejects_case() {
  expect_reject_reason working_dir "must be an absolute path" handover_validate_working_dir foo/bar
}

# Behavior: Overlong working_dir values are rejected.
# Steps:
#   1. Validate an absolute working_dir longer than 4096 bytes.
#   2. Assert the reject audit says the path is too long.
working_dir_too_long_rejects_case() {
  local long_path
  long_path="/tmp/$(printf 'a%.0s' {1..4097})"
  expect_reject_reason working_dir "longer than 4096" handover_validate_working_dir "$long_path"
}

# Behavior: working_dir values containing dot-dot path segments are rejected.
# Steps:
#   1. Validate an absolute working_dir containing /../.
#   2. Assert the reject audit says dot-dot path segments are not allowed.
working_dir_dotdot_rejects_case() {
  expect_reject_reason working_dir "dot-dot path segment" handover_validate_working_dir /tmp/foo/../bar
}

# Behavior: Nonexistent working_dir values are rejected.
# Steps:
#   1. Validate an absolute path that does not exist.
#   2. Assert the reject audit says the directory does not exist.
working_dir_nonexistent_rejects_case() {
  local missing="/tmp/this-path-does-not-exist-handover-test-$$"
  rm -rf "$missing"
  expect_reject_reason working_dir "directory does not exist" handover_validate_working_dir "$missing"
}

# Behavior: Shell metacharacters in brief_file are rejected.
# Steps:
#   1. Validate a brief_file containing a command separator.
#   2. Assert the generic metadata value guard rejects it.
brief_file_shell_metacharacter_rejects_case() {
  ! handover_validate_metadata_value brief_file '/tmp/brief-pm-dispatch-test;touch-pwned.md' >/dev/null 2>&1
}

# Behavior: Unknown dispatch routes are rejected.
# Steps:
#   1. Mutate a valid handover to use an unknown dispatch_route.
#   2. Assert shared contract validation rejects it.
unknown_dispatch_route_rejects_case() {
  local tmp input meta body ok=1
  tmp="$(make_tmpdir)"
  input="$tmp/input.md"
  meta="$tmp/meta.txt"
  body="$tmp/body.md"
  write_valid_handover "$input" "$REPO_ROOT" "/tmp/brief-pm-dispatch-test-5.md"
  sed -i 's/^dispatch_route: .*/dispatch_route: mystery_route/' "$input"
  extract_handover "$input" "$meta" "$body" || ok=0
  validate_contract "$meta" "$body" >/dev/null 2>&1 && ok=0
  rm -rf "$tmp"
  [[ "$ok" -eq 1 ]]
}

# Behavior: Missing handover fences fail extraction without writing metadata or body content.
# Steps:
#   1. Attempt extraction from prose with no dispatch_handover_v1 block.
#   2. Assert extraction fails and output files remain empty.
missing_block_rejects_with_empty_extraction_case() {
  local tmp input meta body ok=1
  tmp="$(make_tmpdir)"
  input="$tmp/input.md"
  meta="$tmp/meta.txt"
  body="$tmp/body.md"
  printf 'ordinary PM summary with no fenced handover\n' > "$input"
  extract_handover "$input" "$meta" "$body" >/dev/null 2>&1 && ok=0
  [[ ! -s "$meta" && ! -s "$body" ]] || ok=0
  rm -rf "$tmp"
  [[ "$ok" -eq 1 ]]
}

# Behavior: Safe argv quoting round-trips an internal space.
# Steps:
#   1. Quote a working_dir value with an internal space.
#   2. Assert bash receives the original value and the emitted argv fragment escapes the space.
safe_argv_round_trips_internal_space_case() {
  local safe_value safe_argv round_trip
  safe_value="/tmp/normal path"
  safe_argv="$(handover_safe_argv working_dir "$safe_value")"
  round_trip="$(bash -c "printf '%s' $safe_argv")"
  [[ "$round_trip" == "$safe_value" && "$safe_argv" == "/tmp/normal\\ path" ]]
}

# Behavior: Dispatch footer parsing extracts trace, last, stderr, and exit fields.
# Steps:
#   1. Write a representative codex-dispatch stdout footer fixture.
#   2. Assert parser output contains all normalized footer fields.
footer_parse_extracts_paths_and_exit_case() {
  local tmp stdout parsed ok=1
  tmp="$(make_tmpdir)"
  stdout="$tmp/stdout.txt"
  parsed="$tmp/footer.env"
  cat > "$stdout" <<EOF
[2026-05-15T00:00:00+00:00] codex-dispatch finished
---
trace:  /repo/.agent-trace/codex-20260515-000000-123.jsonl
last:   /repo/.agent-trace/codex-20260515-000000-123.last
stderr: /repo/.agent-trace/codex-20260515-000000-123.stderr
exit:   0
---
EOF
  parse_footer "$stdout" "$parsed"
  grep -qx 'trace=/repo/.agent-trace/codex-20260515-000000-123.jsonl' "$parsed" || ok=0
  grep -qx 'last=/repo/.agent-trace/codex-20260515-000000-123.last' "$parsed" || ok=0
  grep -qx 'stderr=/repo/.agent-trace/codex-20260515-000000-123.stderr' "$parsed" || ok=0
  grep -qx 'exit=0' "$parsed" || ok=0
  rm -rf "$tmp"
  [[ "$ok" -eq 1 ]]
}

# Behavior: Leading whitespace in metadata values is rejected.
# Steps:
#   1. Validate a value with leading whitespace.
#   2. Assert the reject audit names the field.
metadata_value_leading_whitespace_rejects_case() {
  expect_reject working_dir handover_validate_metadata_value working_dir " $REPO_ROOT"
}

# Behavior: Trailing whitespace in metadata values is rejected.
# Steps:
#   1. Validate a value with trailing whitespace.
#   2. Assert the reject audit names the field.
metadata_value_trailing_whitespace_rejects_case() {
  expect_reject working_dir handover_validate_metadata_value working_dir "$REPO_ROOT "
}

# Behavior: Carriage returns in metadata values are rejected.
# Steps:
#   1. Validate a value containing CR.
#   2. Assert the reject audit names the field.
metadata_value_cr_injection_rejects_case() {
  expect_reject working_dir handover_validate_metadata_value working_dir $'/tmp/a\rb'
}

# Behavior: Line feeds in metadata values are rejected.
# Steps:
#   1. Validate a value containing LF.
#   2. Assert the reject audit names the field.
metadata_value_lf_injection_rejects_case() {
  expect_reject working_dir handover_validate_metadata_value working_dir $'/tmp/a\nb'
}

# Behavior: Every shell metacharacter in metadata values is rejected.
# Steps:
#   1. Validate one otherwise safe value for each denylisted shell metacharacter.
#   2. Assert every rejection names the field and reports a shell metacharacter.
metadata_value_full_denylist_rejects_case() {
  local labels=(double_quote backtick ampersand pipe less_than greater_than open_paren close_paren open_brace close_brace backslash)
  local chars=('"' '`' '&' '|' '<' '>' '(' ')' '{' '}' '\')
  local i value ok=1

  for i in "${!chars[@]}"; do
    value="/tmp/x${chars[$i]}y"
    expect_reject_reason test "shell metacharacter" handover_validate_metadata_value test "$value" || {
      printf 'metadata denylist char was not rejected: %s\n' "${labels[$i]}" >&2
      ok=0
    }
  done

  [[ "$ok" -eq 1 ]]
}

# Behavior: Wrong arity when calling metadata validation is rejected.
# Steps:
#   1. Call handover_validate_metadata_value with one argument.
#   2. Assert the reject audit names the supplied field.
metadata_value_wrong_arity_rejects_case() {
  expect_reject working_dir handover_validate_metadata_value working_dir
}

# Behavior: Handover version 1 is rejected.
# Steps:
#   1. Validate handover_version value 1.
#   2. Assert the reject audit names handover_version and carries the generic invalid token.
handover_version_one_rejects_case() {
  local want_code=1
  local want_token=E-HANDOVER-INVALID
  expect_code_token "$want_code" "$want_token" handover_validate_handover_version 1
}

# Behavior: Handover version 3 is accepted.
# Steps:
#   1. Validate handover_version value 3.
#   2. Assert validation succeeds.
handover_version_three_accepts_case() {
  local want_code=0
  local want_token=E-HANDOVER-INVALID
  expect_code_without_token "$want_code" "$want_token" handover_validate_handover_version 3
}

# Behavior: Executor metadata is required.
# Steps:
#   1. Remove executor from a metadata fixture.
#   2. Assert required-field validation rejects it with the generic invalid token.
executor_missing_rejects_case() {
  local want_code=1
  local want_token=E-HANDOVER-INVALID
  expect_code_token "$want_code" "$want_token" handover_validate_required_fields "$(metadata_fixture | sed '/^executor: /d')"
}

# Behavior: Unknown executor values are rejected by the closed enum.
# Steps:
#   1. Validate executor mystery-executor (intentionally not in the enum).
#   2. Assert the reject audit carries the generic invalid token.
executor_unknown_rejects_case() {
  local want_code=1
  local want_token=E-HANDOVER-INVALID
  expect_code_token "$want_code" "$want_token" handover_validate_executor mystery-executor
}

# Behavior: Executor codex is accepted.
# Steps:
#   1. Validate executor codex.
#   2. Assert validation succeeds.
executor_codex_accepts_case() {
  local want_code=0
  local want_token=E-HANDOVER-INVALID
  expect_code_without_token "$want_code" "$want_token" handover_validate_executor codex
}

# Behavior: Executor claude is accepted (CC-102).
# Steps:
#   1. Validate executor claude.
#   2. Assert validation succeeds.
executor_claude_accepts_case() {
  local want_code=0
  local want_token=E-HANDOVER-INVALID
  expect_code_without_token "$want_code" "$want_token" handover_validate_executor claude
}

# Behavior: Executor opencode is accepted.
# Steps:
#   1. Validate executor opencode.
#   2. Assert validation succeeds.
executor_opencode_accepts_case() {
  local want_code=0
  local want_token=E-HANDOVER-INVALID
  expect_code_without_token "$want_code" "$want_token" handover_validate_executor opencode
}

# Behavior: The main-thread Bash dispatch route is accepted.
# Steps:
#   1. Validate main_thread_bash_background.
#   2. Assert validation succeeds.
dispatch_route_bash_accepts_case() {
  handover_validate_dispatch_route main_thread_bash_background >/dev/null 2>&1
}

# Behavior: The executor fallback route is accepted.
# Steps:
#   1. Validate agent_executor.
#   2. Assert validation succeeds.
dispatch_route_agent_accepts_case() {
  handover_validate_dispatch_route agent_executor >/dev/null 2>&1
}

# Behavior: Unknown dispatch route values are rejected by the route allowlist.
# Steps:
#   1. Validate an unknown dispatch route.
#   2. Assert the reject audit names dispatch_route.
dispatch_route_unknown_value_rejects_case() {
  expect_reject dispatch_route handover_validate_dispatch_route mystery_route
}

# Behavior: isolation_level workspace-write is accepted.
# Steps:
#   1. Validate isolation_level workspace-write.
#   2. Assert validation succeeds.
isolation_level_workspace_write_accepts_case() {
  handover_validate_isolation_level workspace-write >/dev/null 2>&1
}

# Behavior: isolation_level sandboxed is accepted.
# Steps:
#   1. Validate isolation_level sandboxed.
#   2. Assert validation succeeds.
isolation_level_sandboxed_accepts_case() {
  handover_validate_isolation_level sandboxed >/dev/null 2>&1
}

# Behavior: isolation_level workspace-network is accepted.
# Steps:
#   1. Validate isolation_level workspace-network.
#   2. Assert validation succeeds.
isolation_level_workspace_network_accepts_case() {
  handover_validate_isolation_level workspace-network >/dev/null 2>&1
}

# Behavior: isolation_level none is accepted.
# Steps:
#   1. Validate isolation_level none.
#   2. Assert validation succeeds.
isolation_level_none_accepts_case() {
  handover_validate_isolation_level none >/dev/null 2>&1
}

# Behavior: isolation_level read-only is accepted.
# Steps:
#   1. Validate isolation_level read-only.
#   2. Assert validation succeeds.
isolation_level_read_only_accepts_case() {
  handover_validate_isolation_level read-only >/dev/null 2>&1
}

# Behavior: Unknown isolation_level value is rejected.
# Steps:
#   1. Validate isolation_level full-access (not in enum).
#   2. Assert the reject audit names isolation_level.
isolation_level_unknown_rejects_case() {
  expect_reject_reason isolation_level "unknown isolation_level value" handover_validate_isolation_level full-access
}

# Behavior: Full metadata validation rejects an invalid isolation_level value.
# Steps:
#   1. Build a complete metadata block with isolation_level set to an unknown value.
#   2. Assert handover_validate_all_metadata rejects and the audit names isolation_level.
all_metadata_invalid_isolation_level_rejects_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-invalid-isolation.md
isolation_level: full-access
timeout: 1200
model: default
fallback_allowed: true"
  expect_reject isolation_level handover_validate_all_metadata "$block"
}

# Behavior: isolation_level none is rejected on main_thread_bash_background route.
# Steps:
#   1. Build metadata with isolation_level none and dispatch_route main_thread_bash_background.
#   2. Assert handover_validate_all_metadata rejects — none maps to danger-full-access which
#      is not supported on the Bash route; the Agent fallback route must be used instead.
all_metadata_isolation_none_bash_route_rejects_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-none-bash.md
isolation_level: none
timeout: 1200
model: default
fallback_allowed: true"
  expect_reject isolation_level handover_validate_all_metadata "$block"
}

# Behavior: opencode handover with isolation_level:none on main_thread_bash_background is accepted.
# Steps:
#   1. Build metadata with executor:opencode, isolation_level:none, dispatch_route:main_thread_bash_background.
#   2. Assert handover_validate_all_metadata succeeds (opencode cli-subprocess is exempt from
#      the codex-specific danger-full-access bash-route block).
all_metadata_opencode_isolation_none_bash_route_accepts_case() {
  local block
  block="handover_version: 3
executor: opencode
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-opencode-none.md
isolation_level: none
timeout: 1200
model: default
fallback_allowed: true"
  handover_validate_all_metadata "$block" >/dev/null 2>&1
}

# Behavior: Handover block with isolation_level and no sandbox/approval/skip_git_check passes full validation.
# Steps:
#   1. Build a metadata block with isolation_level workspace-write, no sandbox/approval/skip_git_check.
#   2. Assert handover_validate_all_metadata succeeds.
all_metadata_with_isolation_level_accepts_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-isolation-test.md
isolation_level: workspace-write
timeout: 1200
model: default
fallback_allowed: true"
  handover_validate_all_metadata "$block" >/dev/null 2>&1
}

# Behavior: Handover block with isolation_level but no sandbox still passes required_fields check.
# Steps:
#   1. Build metadata with isolation_level present, sandbox/approval/skip_git_check absent.
#   2. Assert handover_validate_required_fields succeeds.
required_fields_with_isolation_level_accepts_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-isolation-req-test.md
isolation_level: workspace-write
timeout: 1200
model: default
fallback_allowed: true"
  handover_validate_required_fields "$block" >/dev/null 2>&1
}

# Behavior: Handover block with no isolation_level and no sandbox fails required_fields check.
# Steps:
#   1. Build metadata without isolation_level and without sandbox/approval/skip_git_check.
#   2. Assert handover_validate_required_fields rejects.
required_fields_missing_both_isolation_and_sandbox_rejects_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-missing-isolation.md
timeout: 1200
model: default
fallback_allowed: true"
  ! handover_validate_required_fields "$block" >/dev/null 2>&1
}

# Behavior: Handover block carrying the removed legacy sandbox field is rejected (v0.6.0 CC-335).
# Steps:
#   1. Build metadata with isolation_level plus the removed legacy sandbox field.
#   2. Assert handover_validate_all_metadata rejects naming the removed sandbox field.
all_metadata_mixed_isolation_and_sandbox_rejects_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-mixed-sandbox.md
isolation_level: workspace-write
sandbox: workspace-write
timeout: 1200
model: default
fallback_allowed: true"
  expect_reject_reason sandbox "legacy field removed in v0.6.0" handover_validate_all_metadata "$block"
}

# Behavior: Handover block carrying the removed legacy approval field is rejected (v0.6.0 CC-335).
# Steps:
#   1. Build metadata with isolation_level plus the removed legacy approval field.
#   2. Assert handover_validate_all_metadata rejects naming the removed approval field.
all_metadata_mixed_isolation_and_approval_rejects_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-mixed-approval.md
isolation_level: workspace-write
approval: never
timeout: 1200
model: default
fallback_allowed: true"
  expect_reject_reason approval "legacy field removed in v0.6.0" handover_validate_all_metadata "$block"
}

# Behavior: Handover block carrying the removed legacy skip_git_check field is rejected (v0.6.0 CC-335).
# Steps:
#   1. Build metadata with isolation_level plus the removed legacy skip_git_check field.
#   2. Assert handover_validate_all_metadata rejects naming the removed skip_git_check field.
all_metadata_mixed_isolation_and_skip_git_check_rejects_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-mixed-skip.md
isolation_level: workspace-write
skip_git_check: false
timeout: 1200
model: default
fallback_allowed: true"
  expect_reject_reason skip_git_check "legacy field removed in v0.6.0" handover_validate_all_metadata "$block"
}

# Behavior: A legacy-only (pre-M3) brief with the trio and NO isolation_level is
# rejected with the migration message, not a generic missing-isolation_level error.
# Steps:
#   1. Build metadata with sandbox/approval/skip_git_check and no isolation_level.
#   2. Assert handover_validate_all_metadata rejects naming a removed legacy field
#      with the v0.6.0 migration message.
all_metadata_legacy_only_rejects_with_migration_message_case() {
  local block
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-legacy-only.md
sandbox: workspace-write
approval: never
skip_git_check: false
timeout: 1200
model: default
fallback_allowed: true"
  expect_reject_reason sandbox "legacy field removed in v0.6.0" handover_validate_all_metadata "$block"
}

# Behavior: A present-but-empty legacy key (`sandbox: ` with an empty value) is
# rejected by field-key presence, not only on a non-empty value.
# Steps:
#   1. Build metadata with isolation_level plus an empty `sandbox: ` key. The
#      empty value is produced via ${_empty} so the source line carries no
#      trailing whitespace while the runtime line is `sandbox: ` (colon-space).
#   2. Assert handover_validate_required_fields rejects naming sandbox.
required_fields_empty_legacy_key_rejects_case() {
  local block _empty=""
  block="handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-empty-legacy.md
isolation_level: workspace-write
sandbox: ${_empty}
timeout: 1200
model: default
fallback_allowed: true"
  expect_reject_reason sandbox "legacy field removed in v0.6.0" handover_validate_required_fields "$block"
}

# Behavior: Timeout 1200 is accepted.
# Steps:
#   1. Validate timeout 1200.
#   2. Assert validation succeeds.
timeout_1200_accepts_case() {
  handover_validate_timeout 1200 >/dev/null 2>&1
}

# Behavior: Timeout below the minimum is rejected.
# Steps:
#   1. Validate timeout 29.
#   2. Assert the reject audit names timeout.
timeout_below_minimum_rejects_case() {
  expect_reject timeout handover_validate_timeout 29
}

# Behavior: Timeout above the maximum is rejected.
# Steps:
#   1. Validate timeout 3601.
#   2. Assert the reject audit names timeout.
timeout_above_maximum_rejects_case() {
  expect_reject timeout handover_validate_timeout 3601
}

# Behavior: Non-integer timeout is rejected.
# Steps:
#   1. Validate timeout abc.
#   2. Assert the reject audit names timeout.
timeout_non_integer_rejects_case() {
  expect_reject timeout handover_validate_timeout abc
}

# Behavior: A /tmp/brief-*.md path is accepted.
# Steps:
#   1. Validate /tmp/brief-x.md.
#   2. Assert validation succeeds.
brief_file_tmp_prefix_md_accepts_case() {
  handover_validate_brief_file /tmp/brief-x.md >/dev/null 2>&1
}

# Behavior: A Windows MSYS-style brief_file path under $TEMP is accepted.
# Steps:
#   1. Export TEMP to a synthetic Git Bash style path.
#   2. Validate a brief path under that prefix.
#   3. Assert validation succeeds.
brief_file_windows_msys_temp_accepts_case() {
  TEMP=/c/Users/test/AppData/Local/Temp \
    handover_validate_brief_file /c/Users/test/AppData/Local/Temp/brief-x.md >/dev/null 2>&1
}

# Behavior: A brief_file outside $TEMP (or /tmp) is still rejected even
# when TEMP is set elsewhere — security-relevant under Windows.
# Steps:
#   1. Export TEMP to a tmp-like path.
#   2. Validate a brief at a path NOT under TEMP nor /tmp.
#   3. Assert the reject audit names brief_file with the legacy-style
#      "must be /brief-*.md under" message (or subdirectory if path nests).
brief_file_windows_outside_temp_rejects_case() {
  local want_code=1
  local want_token=E-HANDOVER-INVALID
  TEMP=/c/Users/test/AppData/Local/Temp \
    expect_code_token "$want_code" "$want_token" \
      handover_validate_brief_file /c/Users/test/Documents/brief-x.md
}

# Behavior: Relative brief_file paths are rejected.
# Steps:
#   1. Validate a relative brief_file path.
#   2. Assert the reject audit names brief_file.
brief_file_relative_path_rejects_case() {
  expect_reject brief_file handover_validate_brief_file brief-x.md
}

# Behavior: brief_file paths outside /tmp/brief- are rejected.
# Steps:
#   1. Validate /etc/passwd.
#   2. Assert the reject audit names brief_file.
brief_file_outside_tmp_prefix_rejects_case() {
  expect_reject brief_file handover_validate_brief_file /etc/passwd
}

# Behavior: brief_file paths containing dot-dot segments are rejected.
# Steps:
#   1. Validate a /tmp/brief- path containing ..
#   2. Assert the reject audit names brief_file.
brief_file_dotdot_rejects_case() {
  expect_reject brief_file handover_validate_brief_file /tmp/brief-../x.md
}

# Behavior: brief_file paths without .md suffix are rejected.
# Steps:
#   1. Validate a /tmp/brief- path ending in .txt.
#   2. Assert the reject audit names brief_file.
brief_file_suffix_rejects_case() {
  expect_reject brief_file handover_validate_brief_file /tmp/brief-x.txt
}

# Behavior: brief_file paths below subdirectories are rejected.
# Steps:
#   1. Validate a /tmp/brief-* path containing an additional slash.
#   2. Assert the reject audit says subdirectories are not allowed.
brief_file_subdirectory_rejects_case() {
  expect_reject_reason brief_file "subdirectories are not allowed" handover_validate_brief_file /tmp/brief-x/y.md
}

# Behavior: brief_file symlink paths are rejected.
# Steps:
#   1. Create a temporary /tmp/brief-*.md symlink.
#   2. Assert the reject audit says symlink paths are not allowed, then clean up.
brief_file_symlink_rejects_case() (
  local tmp target link ok=1
  tmp="$(mktemp -d -t dispatch-handover-brief-symlink.XXXXXX)"
  trap 'rm -rf "$tmp"; rm -f "$link"' EXIT
  target="$tmp/target.md"
  link="/tmp/brief-$(basename "$tmp").md"

  printf 'temporary brief target\n' > "$target"
  ln -s "$target" "$link"
  expect_reject_reason brief_file "symlink path is not allowed" handover_validate_brief_file "$link" || ok=0
  [[ "$ok" -eq 1 ]]
)

# Behavior: default model is accepted.
# Steps:
#   1. Validate model default.
#   2. Assert validation succeeds.
model_default_accepts_case() {
  handover_validate_model default >/dev/null 2>&1
}

# Behavior: Codex-shaped model names are accepted.
# Steps:
#   1. Validate model codex-spark.
#   2. Assert validation succeeds.
model_codex_spark_accepts_case() {
  handover_validate_model codex-spark >/dev/null 2>&1
}

# Behavior: dotted wire/model ids (gpt-5.5, gpt-5.4) are accepted — every value in
# share/model-aliases.tsv must be a valid handover model: value (CC-292).
# Steps:
#   1. Validate model gpt-5.5 and gpt-5.4.
#   2. Assert both succeed.
model_dotted_wire_ids_accept_case() {
  handover_validate_model gpt-5.5 >/dev/null 2>&1 \
    && handover_validate_model gpt-5.4 >/dev/null 2>&1 \
    && handover_validate_model default >/dev/null 2>&1
}

# Behavior: opencode slash-form wire IDs are accepted.
# Steps:
#   1. Validate opencode/big-pickle and openrouter/custom/model.
#   2. Assert both succeed.
model_opencode_wire_id_accepts_case() {
  handover_validate_model opencode/big-pickle >/dev/null 2>&1 \
    && handover_validate_model openrouter/custom/model >/dev/null 2>&1
}

# Behavior: Bad model name shapes are rejected.
# Steps:
#   1. Validate a model with uppercase and punctuation.
#   2. Assert the reject audit names model.
model_bad_shape_rejects_case() {
  expect_reject model handover_validate_model Codex_Spark!
}

# Behavior: fallback_allowed true is accepted.
# Steps:
#   1. Validate fallback_allowed true.
#   2. Assert validation succeeds.
fallback_allowed_true_accepts_case() {
  handover_validate_fallback_allowed true >/dev/null 2>&1
}

# Behavior: Invalid fallback_allowed values are rejected.
# Steps:
#   1. Validate fallback_allowed maybe.
#   2. Assert the reject audit names fallback_allowed.
fallback_allowed_invalid_rejects_case() {
  expect_reject fallback_allowed handover_validate_fallback_allowed maybe
}

# Behavior: Composite valid metadata passes all field validators.
# Steps:
#   1. Build a complete metadata fixture.
#   2. Assert handover_validate_all_metadata accepts it.
all_metadata_valid_accepts_case() {
  handover_validate_all_metadata "$(metadata_fixture "$REPO_ROOT" /tmp/brief-valid-composite.md)" >/dev/null 2>&1
}

# Behavior: Composite metadata with one invalid field returns that field's reject reason.
# Steps:
#   1. Build metadata with an unknown isolation_level value.
#   2. Assert handover_validate_all_metadata rejects and names isolation_level.
all_metadata_invalid_field_rejects_case() {
  expect_reject isolation_level handover_validate_all_metadata "$(metadata_fixture "$REPO_ROOT" /tmp/brief-invalid-composite.md | sed 's/^isolation_level: .*/isolation_level: bogus-level/')"
}

# Behavior: Required-field validation accepts complete metadata.
# Steps:
#   1. Build a complete metadata fixture.
#   2. Assert handover_validate_required_fields succeeds.
required_fields_all_present_accepts_case() {
  handover_validate_required_fields "$(metadata_fixture)" >/dev/null 2>&1
}

# Behavior: Required-field validation rejects missing dispatch_route.
# Steps:
#   1. Remove dispatch_route from a metadata fixture.
#   2. Assert the reject audit names dispatch_route.
required_fields_missing_dispatch_route_rejects_case() {
  expect_reject dispatch_route handover_validate_required_fields "$(metadata_fixture | sed '/^dispatch_route: /d')"
}

# Behavior: Matching metadata and body working_dir values are accepted.
# Steps:
#   1. Pass equal working_dir strings to the shared match validator.
#   2. Assert validation succeeds.
working_dir_match_accepts_case() {
  handover_validate_working_dir_match "$REPO_ROOT" "$REPO_ROOT" >/dev/null 2>&1
}

# Behavior: Mismatched metadata and body working_dir values are rejected.
# Steps:
#   1. Pass different working_dir strings to the shared match validator.
#   2. Assert the reject audit names working_dir.
working_dir_match_mismatch_rejects_case() {
  expect_reject working_dir handover_validate_working_dir_match "$REPO_ROOT" /tmp/other
}

# Behavior: Present handover blocks extract only fenced block content.
# Steps:
#   1. Extract a block from content with prose before and after the fence.
#   2. Assert the block includes metadata and excludes surrounding prose.
extract_block_present_echoes_content_case() {
  local input block
  input=$'before\n```dispatch_handover_v1\nhandover_version: 3\n---\ngoal: x\n```\nafter'
  block="$(handover_extract_block "$input")" || return 1
  grep -q '^handover_version: 3$' <<<"$block" || return 1
  grep -q '^goal: x$' <<<"$block" || return 1
  ! grep -q '^before$' <<<"$block" && ! grep -q '^after$' <<<"$block"
}

# Behavior: Missing handover blocks are rejected by the shared extractor.
# Steps:
#   1. Extract from content without a handover fence.
#   2. Assert extraction fails.
extract_block_missing_rejects_case() {
  ! handover_extract_block 'no fenced block here' >/dev/null 2>&1
}

# Behavior: Unterminated handover blocks are rejected by the shared extractor.
# Steps:
#   1. Extract from content with an opening handover fence and no closing fence.
#   2. Assert extraction fails with an audit message mentioning unterminated.
extract_block_unterminated_fence_rejects_case() {
  local input output
  input=$'```dispatch_handover_v1\nhandover_version: 3\n---\ngoal: x'
  if output="$(printf '%s\n' "$input" | handover_extract_block 2>&1 >/dev/null)"; then
    return 1
  fi
  grep -q "handover-validate: reject handover_block:" <<<"$output" || return 1
  grep -q "unterminated" <<<"$output"
}

# Behavior: Metadata extraction rejects blocks without a standalone separator.
# Steps:
#   1. Extract metadata from a block with no standalone --- line.
#   2. Assert extraction fails.
extract_metadata_missing_separator_rejects_case() {
  ! handover_extract_metadata $'handover_version: 3\ngoal: x' >/dev/null 2>&1
}

# Behavior: Body extraction rejects blocks without a standalone separator.
# Steps:
#   1. Extract body from a block with no standalone --- line.
#   2. Assert extraction fails.
extract_body_missing_separator_rejects_case() {
  ! handover_extract_body $'handover_version: 3\ngoal: x' >/dev/null 2>&1
}

# Behavior: Metadata and body extraction can round-trip a block around the separator.
# Steps:
#   1. Split a block into metadata and body with the shared extractors.
#   2. Assert reconstructing with --- matches the original block.
extract_metadata_body_round_trips_case() {
  local block metadata body reconstructed
  block="$(metadata_fixture "$REPO_ROOT" /tmp/brief-round-trip.md)"$'\n---\nworking_dir: '"$REPO_ROOT"$'\ngoal: Round trip.'
  metadata="$(handover_extract_metadata "$block")" || return 1
  body="$(handover_extract_body "$block")" || return 1
  reconstructed="$metadata"$'\n---\n'"$body"
  [[ "$reconstructed" == "$block" ]]
}

run_case "handover/valid block extracts metadata and body" valid_handover_extracts_metadata_and_body_case
run_case "handover/working_dir mismatch rejects" working_dir_mismatch_rejects_case
run_case "handover/working_dir shell metacharacters reject" working_dir_shell_metacharacters_reject_case
run_case "working_dir_not_absolute_rejects_case" working_dir_not_absolute_rejects_case
run_case "working_dir_too_long_rejects_case" working_dir_too_long_rejects_case
run_case "working_dir_dotdot_rejects_case" working_dir_dotdot_rejects_case
run_case "working_dir_nonexistent_rejects_case" working_dir_nonexistent_rejects_case
run_case "handover/brief_file shell metacharacter rejects" brief_file_shell_metacharacter_rejects_case
run_case "handover/unknown dispatch_route rejects" unknown_dispatch_route_rejects_case
run_case "handover/missing block yields empty extraction" missing_block_rejects_with_empty_extraction_case
run_case "handover/safe argv quoting round-trips" safe_argv_round_trips_internal_space_case
run_case "handover/footer parse extracts trace last stderr exit" footer_parse_extracts_paths_and_exit_case
run_case "handover/metadata leading whitespace rejects" metadata_value_leading_whitespace_rejects_case
run_case "handover/metadata trailing whitespace rejects" metadata_value_trailing_whitespace_rejects_case
run_case "handover/metadata CR injection rejects" metadata_value_cr_injection_rejects_case
run_case "handover/metadata LF injection rejects" metadata_value_lf_injection_rejects_case
run_case "handover/metadata full denylist rejects" metadata_value_full_denylist_rejects_case
run_case "handover/metadata wrong arity rejects" metadata_value_wrong_arity_rejects_case
run_case "handover/version one rejects" handover_version_one_rejects_case
run_case "handover/version three accepts" handover_version_three_accepts_case
run_case "handover/executor missing rejects" executor_missing_rejects_case
run_case "handover/executor unknown rejects" executor_unknown_rejects_case
run_case "handover/executor codex accepts" executor_codex_accepts_case
run_case "handover/executor claude accepts" executor_claude_accepts_case
run_case "handover/executor opencode accepts" executor_opencode_accepts_case
run_case "handover/dispatch route bash accepts" dispatch_route_bash_accepts_case
run_case "handover/dispatch route agent accepts" dispatch_route_agent_accepts_case
run_case "handover/dispatch route unknown rejects" dispatch_route_unknown_value_rejects_case
run_case "handover/timeout 1200 accepts" timeout_1200_accepts_case
run_case "handover/timeout below min rejects" timeout_below_minimum_rejects_case
run_case "handover/timeout above max rejects" timeout_above_maximum_rejects_case
run_case "handover/timeout non-integer rejects" timeout_non_integer_rejects_case
run_case "handover/brief_file tmp prefix md accepts" brief_file_tmp_prefix_md_accepts_case
run_case "handover/brief_file windows msys temp accepts" brief_file_windows_msys_temp_accepts_case
run_case "handover/brief_file windows outside temp rejects" brief_file_windows_outside_temp_rejects_case
run_case "handover/brief_file relative rejects" brief_file_relative_path_rejects_case
run_case "handover/brief_file outside tmp prefix rejects" brief_file_outside_tmp_prefix_rejects_case
run_case "handover/brief_file dotdot rejects" brief_file_dotdot_rejects_case
run_case "handover/brief_file suffix rejects" brief_file_suffix_rejects_case
run_case "brief_file_subdirectory_rejects_case" brief_file_subdirectory_rejects_case
run_case "brief_file_symlink_rejects_case" brief_file_symlink_rejects_case
run_case "handover/model default accepts" model_default_accepts_case
run_case "handover/model codex-spark accepts" model_codex_spark_accepts_case
run_case "handover/model dotted wire ids accept" model_dotted_wire_ids_accept_case
run_case "handover/model opencode slash wire id accepts" model_opencode_wire_id_accepts_case
run_case "handover/model bad shape rejects" model_bad_shape_rejects_case
run_case "handover/fallback_allowed true accepts" fallback_allowed_true_accepts_case
run_case "handover/fallback_allowed invalid rejects" fallback_allowed_invalid_rejects_case
run_case "handover/all metadata valid accepts" all_metadata_valid_accepts_case
run_case "handover/all metadata invalid field rejects" all_metadata_invalid_field_rejects_case
run_case "handover/required fields all present accepts" required_fields_all_present_accepts_case
run_case "handover/required fields missing dispatch_route rejects" required_fields_missing_dispatch_route_rejects_case
run_case "handover/isolation_level workspace-write accepts" isolation_level_workspace_write_accepts_case
run_case "handover/isolation_level sandboxed accepts" isolation_level_sandboxed_accepts_case
run_case "handover/isolation_level workspace-network accepts" isolation_level_workspace_network_accepts_case
run_case "handover/isolation_level none accepts" isolation_level_none_accepts_case
run_case "handover/isolation_level read-only accepts" isolation_level_read_only_accepts_case
run_case "handover/isolation_level unknown rejects" isolation_level_unknown_rejects_case
run_case "handover/all metadata invalid isolation_level rejects" all_metadata_invalid_isolation_level_rejects_case
run_case "handover/all metadata isolation none bash route rejects" all_metadata_isolation_none_bash_route_rejects_case
run_case "handover/all metadata opencode isolation none bash route accepts" all_metadata_opencode_isolation_none_bash_route_accepts_case
run_case "handover/all metadata with isolation_level accepts" all_metadata_with_isolation_level_accepts_case
run_case "handover/required fields with isolation_level accepts" required_fields_with_isolation_level_accepts_case
run_case "handover/required fields missing both isolation and sandbox rejects" required_fields_missing_both_isolation_and_sandbox_rejects_case
run_case "handover/all metadata mixed isolation and sandbox rejects" all_metadata_mixed_isolation_and_sandbox_rejects_case
run_case "handover/all metadata mixed isolation and approval rejects" all_metadata_mixed_isolation_and_approval_rejects_case
run_case "handover/all metadata mixed isolation and skip_git_check rejects" all_metadata_mixed_isolation_and_skip_git_check_rejects_case
run_case "handover/all metadata legacy-only rejects with migration message" all_metadata_legacy_only_rejects_with_migration_message_case
run_case "handover/required fields empty legacy key rejects" required_fields_empty_legacy_key_rejects_case
run_case "handover/working_dir match accepts" working_dir_match_accepts_case
run_case "handover/working_dir mismatch helper rejects" working_dir_match_mismatch_rejects_case
run_case "handover/extract block present echoes content" extract_block_present_echoes_content_case
run_case "handover/extract block missing rejects" extract_block_missing_rejects_case
run_case "extract_block_unterminated_fence_rejects_case" extract_block_unterminated_fence_rejects_case
run_case "extract_metadata_missing_separator_rejects_case" extract_metadata_missing_separator_rejects_case
run_case "extract_body_missing_separator_rejects_case" extract_body_missing_separator_rejects_case
run_case "handover/extract metadata body round-trips" extract_metadata_body_round_trips_case

th_summary
