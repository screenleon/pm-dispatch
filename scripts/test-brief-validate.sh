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
trap 'rm -rf "$tmpdir"' EXIT

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

assert_validation_with_retrieval_mode() {
  local name="$1" mode="$2" brief="$3" expected_rc="$4" expected_output="$5"
  local output="" rc=0

  set +e
  output="$(BRIEF_VALIDATE_RETRIEVAL="$mode" bash "$VALIDATOR" "$brief" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq "$expected_rc" && "$output" == *"$expected_output"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=$expected_rc output~'$expected_output'; got rc=$rc output='$output'"
  fi
}

assert_validation_no_warn() {
  local name="$1" brief="$2"
  local output="" rc=0

  set +e
  output="$(bash "$VALIDATOR" "$brief" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 && "$output" == *"VALID"* && "$output" != *"WARN"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=0 with VALID and no WARN; got rc=$rc output='$output'"
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
  - cmd: "bash scripts/test-brief-validate.sh"
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
  - cmd: "bash scripts/brief-validate.sh --help"
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

# A brief with architecture_impact:major and an empty conceptual_map: header is rejected.
# Steps:
# 1. Write a brief with architecture_impact: major and a bare "conceptual_map:" header with no value.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: architecture_impact:major requires 'conceptual_map'".
case_reject_arch_major_empty_map_header() {
  local name="reject-arch-major-empty-map-header"
  should_run "$name" || return 0
  local brief="$tmpdir/arch-major-empty-map-header.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Introduce cross-layer module with empty map.
files:
  - write: core/state/store.sh
architecture_impact: major
conceptual_map:
acceptance:
  - core/state/store.sh exists
self_verify:
  - cmd: "test -f core/state/store.sh"
EOF

  assert_validation "$name" "$brief" 1 "REJECT: architecture_impact:major requires 'conceptual_map'"
}

# A brief with architecture_impact:major and a block-scalar conceptual_map with no indented content is rejected.
# Steps:
# 1. Write a brief with architecture_impact: major and "conceptual_map: |" with no following indented lines.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: architecture_impact:major requires 'conceptual_map'".
case_reject_arch_major_empty_block_scalar() {
  local name="reject-arch-major-empty-block-scalar"
  should_run "$name" || return 0
  local brief="$tmpdir/arch-major-empty-block-scalar.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Introduce cross-layer module with block-scalar placeholder.
files:
  - write: core/state/store.sh
architecture_impact: major
conceptual_map: |
acceptance:
  - core/state/store.sh exists
self_verify:
  - cmd: "test -f core/state/store.sh"
EOF

  assert_validation "$name" "$brief" 1 "REJECT: architecture_impact:major requires 'conceptual_map'"
}

# A brief with architecture_impact:minor but no conceptual_map emits a WARN but still passes.
# Steps:
# 1. Write a brief with architecture_impact: minor and no conceptual_map field.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 0 (VALID) and output containing "WARN".
case_warn_architecture_impact_minor_no_map() {
  local name="warn-architecture-impact-minor-no-map"
  should_run "$name" || return 0
  local brief="$tmpdir/arch-minor-no-map.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Add a new validation rule to brief-validate.sh.
files:
  - write: scripts/brief-validate.sh
architecture_impact: minor
acceptance:
  - brief-validate.sh rejects invalid architecture_impact enum values
self_verify:
  - cmd: "grep -q 'architecture_impact' scripts/brief-validate.sh"
EOF

  local output="" rc=0
  set +e
  output="$(bash "$VALIDATOR" "$brief" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq 0 && "$output" == *"VALID"* && "$output" == *"WARN"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=0 with VALID+WARN; got rc=$rc output='$output'"
  fi
}

# A brief with architecture_impact set to a valid value passes.
# Steps:
# 1. Write a brief with architecture_impact: minor and a conceptual_map.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 0 and output "VALID".
case_valid_architecture_impact_minor() {
  local name="valid-architecture-impact-minor"
  should_run "$name" || return 0
  local brief="$tmpdir/arch-impact-minor.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Add a new optional field to the brief schema.
files:
  - write: docs/dispatch-brief.md
architecture_impact: minor
conceptual_map: |
  dispatch-brief.md gains two optional fields; brief-validate.sh gains enum check
  no layer boundary change; optional field only
acceptance:
  - dispatch-brief.md contains new field documentation
self_verify:
  - cmd: "grep -q 'architecture_impact' docs/dispatch-brief.md"
EOF

  assert_validation "$name" "$brief" 0 "VALID"
}

# A brief with architecture_impact:major and conceptual_map passes.
# Steps:
# 1. Write a brief with architecture_impact: major and a conceptual_map field.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 0 and output "VALID".
case_valid_architecture_impact_major_with_map() {
  local name="valid-architecture-impact-major-with-map"
  should_run "$name" || return 0
  local brief="$tmpdir/arch-impact-major-with-map.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Introduce new cross-layer state module.
files:
  - write: core/state/store.sh
architecture_impact: major
conceptual_map: |
  cli/ -> scripts/ -> core/state/ (new module)
  no reverse dependency from core/ to scripts/ or cli/
acceptance:
  - core/state/store.sh exists and passes shellcheck
self_verify:
  - cmd: "bash -c 'shellcheck core/state/store.sh'"
EOF

  assert_validation "$name" "$brief" 0 "VALID"
}

# A brief with architecture_impact:major but no conceptual_map is rejected.
# Steps:
# 1. Write a brief with architecture_impact: major and no conceptual_map field.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: architecture_impact:major requires 'conceptual_map'".
case_reject_arch_major_no_map() {
  local name="reject-arch-major-no-map"
  should_run "$name" || return 0
  local brief="$tmpdir/arch-major-no-map.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Introduce new cross-layer module without a map.
files:
  - write: core/state/store.sh
architecture_impact: major
acceptance:
  - core/state/store.sh exists
self_verify:
  - cmd: "test -f core/state/store.sh"
EOF

  assert_validation "$name" "$brief" 1 "REJECT: architecture_impact:major requires 'conceptual_map'"
}

# A brief with an invalid architecture_impact value is rejected.
# Steps:
# 1. Write a brief with architecture_impact set to an unlisted value.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: invalid field 'architecture_impact'".
case_reject_invalid_architecture_impact() {
  local name="reject-invalid-architecture-impact"
  should_run "$name" || return 0
  local brief="$tmpdir/invalid-arch-impact.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Reject invalid architecture_impact value.
files:
  - read: README.md
architecture_impact: huge
acceptance:
  - architecture_impact must be none|minor|major
EOF

  assert_validation "$name" "$brief" 1 "REJECT: invalid field 'architecture_impact'"
}

# A file-writing brief whose self_verify has no cmd: entry is rejected.
# Steps:
# 1. Write a brief with a write: file entry and a self_verify block containing only executor-evaluated macros.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 1 and output containing "REJECT: file-writing brief self_verify has no 'cmd:' entry".
case_reject_write_self_verify_no_cmd() {
  local name="reject-write-self-verify-no-cmd"
  should_run "$name" || return 0
  local brief="$tmpdir/write-no-cmd-self-verify.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update a file with only executor-evaluated self_verify.
files:
  - write: docs/dispatch-brief.md
acceptance:
  - file updated
self_verify:
  - git-status no-collateral-damage
EOF

  assert_validation "$name" "$brief" 1 "REJECT: file-writing brief self_verify has no 'cmd:' entry"
}

# A brief with a vague acceptance phrase emits a WARN but still passes.
# Steps:
# 1. Write a valid write brief whose acceptance contains "works as expected".
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 0 (VALID) and output containing "WARN".
case_warn_vague_acceptance() {
  local name="warn-vague-acceptance"
  should_run "$name" || return 0
  local brief="$tmpdir/vague-acceptance.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Test vague acceptance detection.
files:
  - write: docs/dispatch-brief.md
acceptance:
  - works as expected
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  local output="" rc=0
  set +e
  output="$(bash "$VALIDATOR" "$brief" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq 0 && "$output" == *"VALID"* && "$output" == *"WARN"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=0 with VALID+WARN; got rc=$rc output='$output'"
  fi
}

# A brief with behavioral_units >= 3 but no qa_checklist emits a WARN but still passes.
# Steps:
# 1. Write a valid write brief with behavioral_units: 3 and no qa_checklist section.
# 2. Run brief-validate.sh against the brief.
# 3. Assert exit 0 (VALID) and output containing "WARN".
case_warn_behavioral_units_no_qa_checklist() {
  local name="warn-behavioral-units-no-qa-checklist"
  should_run "$name" || return 0
  local brief="$tmpdir/behavioral-units-no-qa.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Add three behavioral units without a qa_checklist.
files:
  - write: scripts/new-feature.sh
behavioral_units: 3
acceptance:
  - new-feature.sh exists and is executable
self_verify:
  - cmd: "test -x scripts/new-feature.sh"
EOF

  local output="" rc=0
  set +e
  output="$(bash "$VALIDATOR" "$brief" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq 0 && "$output" == *"VALID"* && "$output" == *"WARN"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=0 with VALID+WARN; got rc=$rc output='$output'"
  fi
}

# A file-writing brief without retrieval evidence warns by default but still passes.
case_warn_retrieval_evidence_default() {
  local name="warn-retrieval-evidence-default"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-default-warn.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs without retrieval evidence.
files:
  - write: docs/dispatch-brief.md
acceptance:
  - dispatch docs are updated
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  local output="" rc=0
  set +e
  output="$(bash "$VALIDATOR" "$brief" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq 0 && "$output" == *"WARN"* && "$output" == *"VALID"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=0 with WARN+VALID; got rc=$rc output='$output'"
  fi
}

# Fail mode rejects a file-writing brief without retrieval evidence.
case_reject_retrieval_evidence_fail_mode() {
  local name="reject-retrieval-evidence-fail-mode"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-fail.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs without retrieval evidence.
files:
  - write: docs/dispatch-brief.md
acceptance:
  - dispatch docs are updated
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  assert_validation_with_retrieval_mode "$name" "fail" "$brief" 1 "REJECT: file-writing brief lacks retrieval evidence"
}

# A non-empty context block satisfies retrieval evidence.
case_valid_retrieval_evidence_context() {
  local name="valid-retrieval-evidence-context"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-context.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs with cited context.
files:
  - write: docs/dispatch-brief.md
context: |
  docs/context-retrieval.md:1 explains retrieval ordering.
acceptance:
  - dispatch docs are updated
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  assert_validation_no_warn "$name" "$brief"
}

# auto_pack:true satisfies retrieval evidence.
case_valid_retrieval_evidence_auto_pack() {
  local name="valid-retrieval-evidence-auto-pack"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-auto-pack.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs with dispatch-time packing.
auto_pack: true
files:
  - write: docs/dispatch-brief.md
acceptance:
  - dispatch docs are updated
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  assert_validation_no_warn "$name" "$brief"
}

# A non-empty retrieval_skip_reason satisfies retrieval evidence.
case_valid_retrieval_evidence_skip_reason() {
  local name="valid-retrieval-evidence-skip-reason"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-skip-reason.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs with a justified retrieval skip.
retrieval_skip_reason: exact text replacement with no source lookup needed
files:
  - write: docs/dispatch-brief.md
acceptance:
  - dispatch docs are updated
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  assert_validation_no_warn "$name" "$brief"
}

# Read-only briefs are exempt from retrieval evidence.
case_valid_retrieval_trivial_read_only_exempt() {
  local name="valid-retrieval-trivial-read-only-exempt"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-read-only.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Inspect dispatch docs without retrieval evidence.
files:
  - read: docs/dispatch-brief.md
acceptance:
  - read-only brief validates without retrieval evidence
EOF

  assert_validation_no_warn "$name" "$brief"
}

# An unsupported BRIEF_VALIDATE_RETRIEVAL value is rejected before the evidence
# check (so even an evidence-bearing brief is rejected).
case_reject_invalid_retrieval_mode() {
  local name="reject-invalid-retrieval-mode"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-invalid-mode.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs with cited context.
files:
  - write: docs/dispatch-brief.md
context: |
  docs/context-retrieval.md:1 explains retrieval ordering.
acceptance:
  - dispatch docs are updated
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  assert_validation_with_retrieval_mode "$name" "bogus" "$brief" 1 "REJECT: invalid BRIEF_VALIDATE_RETRIEVAL"
}

# An empty block-scalar retrieval_skip_reason ("|" with no body) is NOT evidence:
# fail mode must still reject. Guards the empty-skip-reason bypass.
case_reject_retrieval_empty_skip_reason_block_scalar() {
  local name="reject-retrieval-empty-skip-reason-block-scalar"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-empty-skip-block.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs with an empty skip reason.
retrieval_skip_reason: |
files:
  - write: docs/dispatch-brief.md
acceptance:
  - dispatch docs are updated
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  assert_validation_with_retrieval_mode "$name" "fail" "$brief" 1 "REJECT: file-writing brief lacks retrieval evidence"
}

# A bare empty retrieval_skip_reason (key with no value, no body) is NOT evidence:
# fail mode must still reject.
case_reject_retrieval_empty_skip_reason_bare() {
  local name="reject-retrieval-empty-skip-reason-bare"
  should_run "$name" || return 0
  local brief="$tmpdir/retrieval-empty-skip-bare.md"
  write_brief "$brief" <<EOF
schema_version: 1
working_dir: $REPO_ROOT
goal: Update dispatch docs with an empty skip reason.
retrieval_skip_reason:
files:
  - write: docs/dispatch-brief.md
acceptance:
  - dispatch docs are updated
self_verify:
  - cmd: "test -f docs/dispatch-brief.md"
EOF

  assert_validation_with_retrieval_mode "$name" "fail" "$brief" 1 "REJECT: file-writing brief lacks retrieval evidence"
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
case_reject_arch_major_empty_map_header
case_reject_arch_major_empty_block_scalar
case_warn_architecture_impact_minor_no_map
case_valid_architecture_impact_minor
case_valid_architecture_impact_major_with_map
case_reject_arch_major_no_map
case_reject_invalid_architecture_impact
case_reject_write_self_verify_no_cmd
case_warn_vague_acceptance
case_warn_behavioral_units_no_qa_checklist
case_warn_retrieval_evidence_default
case_reject_retrieval_evidence_fail_mode
case_valid_retrieval_evidence_context
case_valid_retrieval_evidence_auto_pack
case_valid_retrieval_evidence_skip_reason
case_valid_retrieval_trivial_read_only_exempt
case_reject_invalid_retrieval_mode
case_reject_retrieval_empty_skip_reason_block_scalar
case_reject_retrieval_empty_skip_reason_bare

th_summary
