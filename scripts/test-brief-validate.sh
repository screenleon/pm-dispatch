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

case_reject_file_not_found() {
  local name="reject-file-not-found"
  should_run "$name" || return 0

  assert_validation "$name" "$tmpdir/no-such-brief.md" 1 "REJECT"
}

case_reject_empty_brief() {
  local name="reject-empty-brief"
  should_run "$name" || return 0
  local brief="$tmpdir/empty.md"
  : > "$brief"

  assert_validation "$name" "$brief" 1 "REJECT: missing field 'schema_version'"
}

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

case_valid_read_only_brief
case_valid_write_with_self_verify
case_valid_new_with_self_verify
case_reject_missing_schema_version
case_reject_missing_working_dir
case_reject_missing_goal
case_reject_missing_files
case_reject_missing_acceptance
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

th_summary
