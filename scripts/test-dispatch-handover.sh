#!/usr/bin/env bash
# Regression tests for codex_dispatch_handover_v1 extraction and validation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib/handover-validate.sh"

PASS=0
FAIL=0
FAILED_CASES=()

t_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
t_fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL+1)); FAILED_CASES+=("$1"); }

run_case() {
  local name=$1
  local fn=$2

  if "$fn"; then
    t_pass "$name"
  else
    t_fail "$name"
  fi
}

make_tmpdir() {
  mktemp -d -t dispatch-handover.XXXXXX
}

metadata_fixture() {
  local work_dir=${1:-$REPO_ROOT}
  local brief_file=${2:-/tmp/brief-pm-dispatch-test.md}

  cat <<EOF
handover_version: 1
dispatch_route: main_thread_bash_background
working_dir: $work_dir
brief_file: $brief_file
sandbox: workspace-write
approval: never
timeout: 1200
model: default
skip_git_check: false
fallback_allowed: true
EOF
}

write_valid_handover() {
  local out=$1
  local work_dir=$2
  local brief_file=$3

  cat > "$out" <<EOF
PM summary outside fence.

\`\`\`codex_dispatch_handover_v1
handover_version: 1
dispatch_route: main_thread_bash_background
working_dir: $work_dir
brief_file: $brief_file
sandbox: workspace-write
approval: never
timeout: 1200
model: default
skip_git_check: false
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
#   1. Attempt extraction from prose with no codex_dispatch_handover_v1 block.
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

# Behavior: Handover version 1 is accepted.
# Steps:
#   1. Validate handover_version value 1.
#   2. Assert validation succeeds.
handover_version_one_accepts_case() {
  handover_validate_handover_version 1 >/dev/null 2>&1
}

# Behavior: Handover version 2 is rejected.
# Steps:
#   1. Validate handover_version value 2.
#   2. Assert the reject audit names handover_version.
handover_version_two_rejects_case() {
  expect_reject handover_version handover_validate_handover_version 2
}

# Behavior: The main-thread Bash dispatch route is accepted.
# Steps:
#   1. Validate main_thread_bash_background.
#   2. Assert validation succeeds.
dispatch_route_bash_accepts_case() {
  handover_validate_dispatch_route main_thread_bash_background >/dev/null 2>&1
}

# Behavior: The codex executor fallback route is accepted.
# Steps:
#   1. Validate agent_codex_executor.
#   2. Assert validation succeeds.
dispatch_route_agent_accepts_case() {
  handover_validate_dispatch_route agent_codex_executor >/dev/null 2>&1
}

# Behavior: Unknown dispatch route values are rejected by the route allowlist.
# Steps:
#   1. Validate an unknown dispatch route.
#   2. Assert the reject audit names dispatch_route.
dispatch_route_unknown_value_rejects_case() {
  expect_reject dispatch_route handover_validate_dispatch_route mystery_route
}

# Behavior: workspace-write sandbox is accepted.
# Steps:
#   1. Validate sandbox workspace-write.
#   2. Assert validation succeeds.
sandbox_workspace_write_accepts_case() {
  handover_validate_sandbox workspace-write >/dev/null 2>&1
}

# Behavior: read-only sandbox is accepted.
# Steps:
#   1. Validate sandbox read-only.
#   2. Assert validation succeeds.
sandbox_read_only_accepts_case() {
  handover_validate_sandbox read-only >/dev/null 2>&1
}

# Behavior: danger-full-access sandbox is rejected by the bash route (use Agent(codex-executor) fallback).
# Steps:
#   1. Validate sandbox danger-full-access.
#   2. Assert the reject audit names sandbox.
sandbox_danger_full_access_rejects_case() {
  expect_reject_reason sandbox "not supported by bash route" handover_validate_sandbox danger-full-access
}

# Behavior: approval never is accepted.
# Steps:
#   1. Validate approval never.
#   2. Assert validation succeeds.
approval_never_accepts_case() {
  handover_validate_approval never >/dev/null 2>&1
}

# Behavior: approval on-failure is rejected by the bash route (use Agent(codex-executor) fallback).
# Steps:
#   1. Validate approval on-failure.
#   2. Assert the reject audit names approval.
approval_on_failure_rejects_case() {
  expect_reject_reason approval "not supported by bash route" handover_validate_approval on-failure
}

# Behavior: approval on-request is rejected by the bash route (use Agent(codex-executor) fallback).
# Steps:
#   1. Validate approval on-request.
#   2. Assert the reject audit names approval.
approval_on_request_rejects_case() {
  expect_reject_reason approval "not supported by bash route" handover_validate_approval on-request
}

# Behavior: skip_git_check false is accepted.
# Steps:
#   1. Validate skip_git_check false.
#   2. Assert validation succeeds.
skip_git_check_false_accepts_case() {
  handover_validate_skip_git_check false >/dev/null 2>&1
}

# Behavior: skip_git_check true is rejected by the bash route (use Agent(codex-executor) fallback).
# Steps:
#   1. Validate skip_git_check true.
#   2. Assert the reject audit names skip_git_check.
skip_git_check_true_rejects_case() {
  expect_reject_reason skip_git_check "not supported by bash route" handover_validate_skip_git_check true
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
#   1. Build metadata with sandbox danger-full-access.
#   2. Assert handover_validate_all_metadata rejects and names sandbox.
all_metadata_invalid_field_rejects_case() {
  expect_reject sandbox handover_validate_all_metadata "$(metadata_fixture "$REPO_ROOT" /tmp/brief-invalid-composite.md | sed 's/^sandbox: .*/sandbox: danger-full-access/')"
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
  input=$'before\n```codex_dispatch_handover_v1\nhandover_version: 1\n---\ngoal: x\n```\nafter'
  block="$(handover_extract_block "$input")" || return 1
  grep -q '^handover_version: 1$' <<<"$block" || return 1
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
  input=$'```codex_dispatch_handover_v1\nhandover_version: 1\n---\ngoal: x'
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
  ! handover_extract_metadata $'handover_version: 1\ngoal: x' >/dev/null 2>&1
}

# Behavior: Body extraction rejects blocks without a standalone separator.
# Steps:
#   1. Extract body from a block with no standalone --- line.
#   2. Assert extraction fails.
extract_body_missing_separator_rejects_case() {
  ! handover_extract_body $'handover_version: 1\ngoal: x' >/dev/null 2>&1
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
run_case "handover/version one accepts" handover_version_one_accepts_case
run_case "handover/version two rejects" handover_version_two_rejects_case
run_case "handover/dispatch route bash accepts" dispatch_route_bash_accepts_case
run_case "handover/dispatch route agent accepts" dispatch_route_agent_accepts_case
run_case "handover/dispatch route unknown rejects" dispatch_route_unknown_value_rejects_case
run_case "handover/sandbox workspace-write accepts" sandbox_workspace_write_accepts_case
run_case "handover/sandbox read-only accepts" sandbox_read_only_accepts_case
run_case "handover/sandbox danger-full-access rejects" sandbox_danger_full_access_rejects_case
run_case "handover/approval never accepts" approval_never_accepts_case
run_case "handover/approval on-failure rejects" approval_on_failure_rejects_case
run_case "handover/approval on-request rejects" approval_on_request_rejects_case
run_case "handover/skip_git_check false accepts" skip_git_check_false_accepts_case
run_case "handover/skip_git_check true rejects" skip_git_check_true_rejects_case
run_case "handover/timeout 1200 accepts" timeout_1200_accepts_case
run_case "handover/timeout below min rejects" timeout_below_minimum_rejects_case
run_case "handover/timeout above max rejects" timeout_above_maximum_rejects_case
run_case "handover/timeout non-integer rejects" timeout_non_integer_rejects_case
run_case "handover/brief_file tmp prefix md accepts" brief_file_tmp_prefix_md_accepts_case
run_case "handover/brief_file relative rejects" brief_file_relative_path_rejects_case
run_case "handover/brief_file outside tmp prefix rejects" brief_file_outside_tmp_prefix_rejects_case
run_case "handover/brief_file dotdot rejects" brief_file_dotdot_rejects_case
run_case "handover/brief_file suffix rejects" brief_file_suffix_rejects_case
run_case "brief_file_subdirectory_rejects_case" brief_file_subdirectory_rejects_case
run_case "brief_file_symlink_rejects_case" brief_file_symlink_rejects_case
run_case "handover/model default accepts" model_default_accepts_case
run_case "handover/model codex-spark accepts" model_codex_spark_accepts_case
run_case "handover/model bad shape rejects" model_bad_shape_rejects_case
run_case "handover/fallback_allowed true accepts" fallback_allowed_true_accepts_case
run_case "handover/fallback_allowed invalid rejects" fallback_allowed_invalid_rejects_case
run_case "handover/all metadata valid accepts" all_metadata_valid_accepts_case
run_case "handover/all metadata invalid field rejects" all_metadata_invalid_field_rejects_case
run_case "handover/required fields all present accepts" required_fields_all_present_accepts_case
run_case "handover/required fields missing dispatch_route rejects" required_fields_missing_dispatch_route_rejects_case
run_case "handover/working_dir match accepts" working_dir_match_accepts_case
run_case "handover/working_dir mismatch helper rejects" working_dir_match_mismatch_rejects_case
run_case "handover/extract block present echoes content" extract_block_present_echoes_content_case
run_case "handover/extract block missing rejects" extract_block_missing_rejects_case
run_case "extract_block_unterminated_fence_rejects_case" extract_block_unterminated_fence_rejects_case
run_case "extract_metadata_missing_separator_rejects_case" extract_metadata_missing_separator_rejects_case
run_case "extract_body_missing_separator_rejects_case" extract_body_missing_separator_rejects_case
run_case "handover/extract metadata body round-trips" extract_metadata_body_round_trips_case

echo "----"
echo "$PASS passed, $FAIL failed"
if [[ "$FAIL" -ne 0 ]]; then
  printf 'Failed cases:\n' >&2
  printf '  %s\n' "${FAILED_CASES[@]}" >&2
fi
[[ "$FAIL" -eq 0 ]]
