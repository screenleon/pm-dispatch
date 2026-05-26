#!/usr/bin/env bash
# Regression tests for scripts/brief-validate.sh.

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/brief-validate.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir" "$tmp_root"' EXIT

write_brief() {
  local path="$1"
  cat > "$path"
}

assert_validation() {
  local name="$1" brief="$2" expected_rc="$3" expected_output="$4"
  local output="" rc=0

  set +e
  output="$(bash "$VALIDATOR" "$brief" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq "$expected_rc" && "$output" == *"$expected_output"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=$expected_rc output~'$expected_output'; got rc=$rc output='$output'"
  fi
}

# A read-only brief with only read: entries validates as VALID without requiring self_verify.
# Steps:
# 1. Write a brief with schema_version, working_dir, goal, acceptance, and only read: file entries.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 0 and output "VALID".
case_valid_read_only_brief() {
  local name="valid-read-only-brief"
  should_run "$name" || return 0
  local brief="$tmpdir/read-only.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Inspect dispatch docs.
files:
  - read: docs/dispatch-brief.md
  - read: scripts/test-portable.sh
acceptance:
  - validator accepts read-only briefs
EOF

  assert_validation "$name" "$brief" 0 "VALID"
}

# A write brief with self_verify validates as VALID.
# Steps:
# 1. Write a brief with a write: file entry and a self_verify command.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 0 and output "VALID".
case_valid_write_with_self_verify() {
  local name="valid-write-with-self-verify"
  should_run "$name" || return 0
  local brief="$tmpdir/write.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs.
files:
  - write: docs/dispatch-brief.md
acceptance:
  - dispatch docs updated
self_verify:
  - bash scripts/test-brief-validate.sh
EOF

  assert_validation "$name" "$brief" 0 "VALID"
}

# A new-file brief with self_verify validates as VALID.
# Steps:
# 1. Write a brief with a new: file entry and a self_verify command.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 0 and output "VALID".
case_valid_new_with_self_verify() {
  local name="valid-new-with-self-verify"
  should_run "$name" || return 0
  local brief="$tmpdir/new.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Add a validator.
files:
  - new: scripts/brief-validate.sh
acceptance:
  - validator added
self_verify:
  - bash scripts/brief-validate.sh --help
EOF

  assert_validation "$name" "$brief" 0 "VALID"
}

# A brief missing the schema_version field is rejected.
# Steps:
# 1. Write a brief without a schema_version line.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'schema_version'".
case_reject_missing_schema_version() {
  local name="reject-missing-schema-version"
  should_run "$name" || return 0
  local brief="$tmpdir/missing-schema.md"
  write_brief "$brief" <<EOF
working_dir: $REPO_ROOT
goal: Missing schema.
files:
  - read: README.md
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'schema_version'"
}

# A brief missing the working_dir field is rejected.
# Steps:
# 1. Write a brief without a working_dir line.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'working_dir'".
case_reject_missing_working_dir() {
  local name="reject-missing-working-dir"
  should_run "$name" || return 0
  local brief="$tmpdir/missing-working-dir.md"
  write_brief "$brief" <<'EOF'
schema_version: 1
goal: Missing working dir.
files:
  - read: README.md
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'working_dir'"
}

# A brief missing the goal field is rejected.
# Steps:
# 1. Write a brief without a goal line.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'goal'".
case_reject_missing_goal() {
  local name="reject-missing-goal"
  should_run "$name" || return 0
  local brief="$tmpdir/missing-goal.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
files:
  - read: README.md
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'goal'"
}

# A brief missing the files section is rejected.
# Steps:
# 1. Write a brief without a files section.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'files'".
case_reject_missing_files() {
  local name="reject-missing-files"
  should_run "$name" || return 0
  local brief="$tmpdir/missing-files.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Missing files.
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'files'"
}

# A brief with an empty files section is rejected.
# Steps:
# 1. Write a brief with a files header and no file entries.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'files'".
case_reject_empty_files_section() {
  local name="reject-empty-files-section"
  should_run "$name" || return 0
  local brief="$tmpdir/empty-files-section.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Empty files section.
files:
acceptance:
  - files section must contain entries
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'files'"
}

# A brief missing the acceptance section is rejected.
# Steps:
# 1. Write a brief without an acceptance section.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'acceptance'".
case_reject_missing_acceptance() {
  local name="reject-missing-acceptance"
  should_run "$name" || return 0
  local brief="$tmpdir/missing-acceptance.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update docs without acceptance.
files:
  - write: docs/dispatch-brief.md
self_verify:
  - bash scripts/test-brief-validate.sh
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'acceptance'"
}

# A brief with an empty acceptance section is rejected.
# Steps:
# 1. Write a brief with an acceptance header and no acceptance entries.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'acceptance'".
case_reject_empty_acceptance_section() {
  local name="reject-empty-acceptance-section"
  should_run "$name" || return 0
  local brief="$tmpdir/empty-acceptance-section.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Empty acceptance section.
files:
  - read: README.md
acceptance:
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'acceptance'"
}

# A write brief without self_verify is rejected.
# Steps:
# 1. Write a brief with a write: file entry and no self_verify section.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'self_verify'".
case_reject_write_no_self_verify() {
  local name="reject-write-no-self-verify"
  should_run "$name" || return 0
  local brief="$tmpdir/write-no-self-verify.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update docs without verification.
files:
  - write: docs/dispatch-brief.md
acceptance:
  - write entries require self verification
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'self_verify'"
}

# A new-file brief without self_verify is rejected.
# Steps:
# 1. Write a brief with a new: file entry and no self_verify section.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'self_verify'".
case_reject_new_no_self_verify() {
  local name="reject-new-no-self-verify"
  should_run "$name" || return 0
  local brief="$tmpdir/new-no-self-verify.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Add a file without verification.
files:
  - new: scripts/new-tool.sh
acceptance:
  - new entries require self verification
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'self_verify'"
}

# An edit brief without self_verify is rejected.
# Steps:
# 1. Write a brief with an edit: file entry and no self_verify section.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'self_verify'".
case_reject_edit_no_self_verify() {
  local name="reject-edit-no-self-verify"
  should_run "$name" || return 0
  local brief="$tmpdir/edit-no-self-verify.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Edit a file without verification.
files:
  - edit: docs/dispatch-brief.md
acceptance:
  - edit entries require self verification
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'self_verify'"
}

# An untagged writing brief without self_verify is rejected.
# Steps:
# 1. Write a brief with an untagged file entry and no self_verify section.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'self_verify'".
case_reject_untagged_no_self_verify() {
  local name="reject-untagged-no-self-verify"
  should_run "$name" || return 0
  local brief="$tmpdir/untagged-no-self-verify.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Touch a file without verification.
files:
  - docs/dispatch-brief.md
acceptance:
  - untagged entries require self verification
EOF

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'self_verify'"
}

# A brief with an absolute working_dir that does not exist is rejected.
# Steps:
# 1. Write a brief whose working_dir is an absolute missing path.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: working_dir not found".
case_reject_working_dir_not_found() {
  local name="reject-working-dir-not-found"
  should_run "$name" || return 0
  local brief="$tmpdir/missing-workdir.md"
  write_brief "$brief" <<'EOF'
schema_version: 1
working_dir: /tmp/this-does-not-exist-xyz
goal: Missing working dir path.
files:
  - read: README.md
acceptance:
  - working dir must exist
EOF

  assert_validation "$name" "$brief" 1 "REJECT: working_dir not found"
}

# A missing brief file is rejected.
# Steps:
# 1. Choose a brief path that does not exist.
# 2. Run brief-validate.sh against the missing path.
# 3. Assert exit 1 and output containing "REJECT".
case_reject_file_not_found() {
  local name="reject-file-not-found"
  should_run "$name" || return 0

  assert_validation "$name" "$tmpdir/no-such-brief.md" 1 "REJECT"
}

# An empty brief file is rejected for missing schema_version.
# Steps:
# 1. Create an empty brief file.
# 2. Run brief-validate.sh against the empty brief.
# 3. Assert exit 1 and output containing "REJECT: missing field 'schema_version'".
case_reject_empty_brief() {
  local name="reject-empty-brief"
  should_run "$name" || return 0
  local brief="$tmpdir/empty.md"
  : > "$brief"

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'schema_version'"
}

# The help flag exits successfully and prints usage.
# Steps:
# 1. Prepare the validator command with the --help flag.
# 2. Run brief-validate.sh with --help.
# 3. Assert exit 0 and output containing "usage".
case_help_exits_zero() {
  local name="help-exits-zero"
  should_run "$name" || return 0
  local output="" rc=0
  set +e
  output="$(bash "$VALIDATOR" --help 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq 0 && "$output" == *"usage"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=0 output~'usage'; got rc=$rc output='$output'"
  fi
}

# Running the validator without arguments exits with usage.
# Steps:
# 1. Prepare the validator command without positional arguments.
# 2. Run brief-validate.sh with no arguments.
# 3. Assert exit 2 and output containing "usage".
case_no_args_exits_usage() {
  local name="no-args-exits-usage"
  should_run "$name" || return 0
  local output="" rc=0
  set +e
  output="$(bash "$VALIDATOR" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq 2 && "$output" == *"usage"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=2 output~'usage'; got rc=$rc output='$output'"
  fi
}

# Running the validator with extra arguments exits with usage.
# Steps:
# 1. Prepare the validator command with two positional arguments.
# 2. Run brief-validate.sh with the extra arguments.
# 3. Assert exit 2 and output containing "usage".
case_extra_args_exits_usage() {
  local name="extra-args-exits-usage"
  should_run "$name" || return 0
  local output="" rc=0
  set +e
  output="$(bash "$VALIDATOR" a b 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq 2 && "$output" == *"usage"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=2 output~'usage'; got rc=$rc output='$output'"
  fi
}

# A brief with schema_version other than 1 is rejected.
# Steps:
# 1. Write a complete brief with schema_version set to 2.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: invalid field 'schema_version': expected 1".
case_reject_invalid_schema_version() {
  local name="reject-invalid-schema-version"
  should_run "$name" || return 0
  local brief="$tmpdir/invalid-schema-version.md"
  write_brief "$brief" <<EOF
schema_version: 2
working_dir: $REPO_ROOT
goal: Reject unsupported schema version.
files:
  - read: README.md
acceptance:
  - schema version must be exactly 1
EOF

  assert_validation "$name" "$brief" 1 "REJECT: invalid field 'schema_version': expected 1"
}

# A brief with a relative working_dir is rejected before disk existence checks.
# Steps:
# 1. Write a complete brief with working_dir set to a relative path.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: working_dir must be an absolute path".
case_reject_relative_working_dir() {
  local name="reject-relative-working-dir"
  should_run "$name" || return 0
  local brief="$tmpdir/relative-working-dir.md"
  write_brief "$brief" <<'EOF'
schema_version: 1
working_dir: .
goal: Reject relative working dir path.
files:
  - read: README.md
acceptance:
  - working_dir must be absolute
EOF

  assert_validation "$name" "$brief" 1 "REJECT: working_dir must be an absolute path"
}

case_valid_read_only_brief
case_valid_write_with_self_verify
case_valid_new_with_self_verify
case_reject_missing_schema_version
case_reject_missing_working_dir
case_reject_missing_goal
case_reject_missing_files
case_reject_empty_files_section
case_reject_missing_acceptance
case_reject_empty_acceptance_section
case_reject_write_no_self_verify
case_reject_new_no_self_verify
case_reject_edit_no_self_verify
case_reject_untagged_no_self_verify
case_reject_working_dir_not_found
case_reject_file_not_found
case_reject_empty_brief
case_help_exits_zero
case_no_args_exits_usage
case_extra_args_exits_usage
case_reject_invalid_schema_version
case_reject_relative_working_dir

th_summary
