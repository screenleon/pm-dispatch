#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/dispatch-post-verify.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_eq() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  fail "$name" "assert_eq: actual=$actual expected=$expected"
  return 1
}

run_validator() {
  local rc_var="$1" out_var="$2"
  shift 2
  local output="" status=0

  set +e
  output="$(bash "$VALIDATOR" "$@" 2>&1)"
  status=$?
  set -e

  printf -v "$rc_var" '%s' "$status"
  printf -v "$out_var" '%s' "$output"
}

make_work_dir() {
  local name="$1"
  local work_dir="$tmpdir/$name"
  mkdir -p "$work_dir"
  printf '%s\n' "$work_dir"
}

write_latest_last() {
  local work_dir="$1" content="$2"
  mkdir -p "$work_dir/.agent-trace"
  printf '%s\n' "$content" > "$work_dir/.agent-trace/latest.last"
}

# A work directory with a non-empty latest.last passes post-dispatch verification.
# Steps:
# 1. Create a work directory with .agent-trace/latest.last containing status text.
# 2. Run dispatch-post-verify.sh with the work directory.
# 3. Assert exit 0 and output containing OK.
case_valid_latest_last_exists() {
  local name="valid-latest-last-exists"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "OK" || return 0
  pass "$name"
}

# Omitting brief_file keeps post-dispatch verification from running self_verify checks.
# Steps:
# 1. Create a work directory with .agent-trace/latest.last containing status text.
# 2. Run dispatch-post-verify.sh with only the work directory argument.
# 3. Assert exit 0 and no Self-verify checks header appears.
case_valid_no_brief_arg() {
  local name="valid-no-brief-arg"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  if [[ "$out" == *"=== Self-verify checks ==="* ]]; then
    fail "$name" "unexpected self_verify block in output: $out"
    return 0
  fi
  pass "$name"
}

# A self_verify command present in latest.last is reported as FOUND.
# Steps:
# 1. Create a trace whose latest.last includes the self_verify command and write a matching brief.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 and output containing the FOUND line.
case_valid_selfverify_found() {
  local name="valid-selfverify-found"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "bash scripts/run-all-tests.sh: pass"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "FOUND: bash scripts/run-all-tests.sh" || return 0
  pass "$name"
}

# A work directory without .agent-trace fails post-dispatch verification.
# Steps:
# 1. Create a work directory with no .agent-trace directory.
# 2. Run dispatch-post-verify.sh with the work directory.
# 3. Assert exit 1 and output containing FAILED.
case_fail_no_trace_dir() {
  local name="fail-no-trace-dir"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  pass "$name"
}

# A work directory with .agent-trace but no latest.last fails post-dispatch verification.
# Steps:
# 1. Create a work directory with an empty .agent-trace directory.
# 2. Run dispatch-post-verify.sh with the work directory.
# 3. Assert exit 1 and output containing FAILED.
case_fail_no_latest_last() {
  local name="fail-no-latest-last"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  mkdir -p "$work_dir/.agent-trace"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  pass "$name"
}

# An empty latest.last fails post-dispatch verification.
# Steps:
# 1. Create a work directory with .agent-trace/latest.last as an empty file.
# 2. Run dispatch-post-verify.sh with the work directory.
# 3. Assert exit 1 and output containing FAILED.
case_fail_empty_latest_last() {
  local name="fail-empty-latest-last"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  mkdir -p "$work_dir/.agent-trace"
  touch "$work_dir/.agent-trace/latest.last"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  pass "$name"
}

# A self_verify command missing from latest.last is reported as MISSING and fails.
# Steps:
# 1. Create a valid trace and a brief whose self_verify command is absent from latest.last.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 1 and output containing the MISSING line.
case_fail_selfverify_missing() {
  local name="fail-selfverify-missing"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/missing-cmd.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "MISSING: bash scripts/missing-cmd.sh" || return 0
  pass "$name"
}

# A self_verify command on only a failure-prefixed trace line is reported as MISSING.
# Steps:
# 1. Create a trace whose latest.last contains only a fail-prefixed self_verify command line.
# 2. Run dispatch-post-verify.sh with the work directory and matching brief file.
# 3. Assert exit 1 and output containing the MISSING line.
case_fail_selfverify_failed_prefix() {
  local name="fail-selfverify-failed-prefix"
  should_run "$name" || return 0
  local work_dir brief out rc

  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "fail: bash scripts/run-all-tests.sh exited 1"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "MISSING: bash scripts/run-all-tests.sh" || return 0
  pass "$name"
}

# A self_verify command on only a colon-fail trace line is reported as MISSING.
# Steps:
# 1. Create a trace whose latest.last contains the self_verify command as cmd: fail: reason.
# 2. Run dispatch-post-verify.sh with the work directory and matching brief file.
# 3. Assert exit 1 and output containing the MISSING line.
case_fail_selfverify_colon_fail() {
  local name="fail-selfverify-colon-fail"
  should_run "$name" || return 0
  local work_dir brief out rc

  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "bash scripts/run-all-tests.sh: fail: exited 1"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "MISSING: bash scripts/run-all-tests.sh" || return 0
  pass "$name"
}

# A self_verify command with a skipped status is reported as MISSING and fails.
# Steps:
# 1. Create a trace whose latest.last contains the self_verify command as cmd: skipped.
# 2. Run dispatch-post-verify.sh with the work directory and matching brief file.
# 3. Assert exit 1 and output containing the MISSING line.
case_fail_selfverify_skipped() {
  local name="fail-selfverify-skipped"
  should_run "$name" || return 0
  local work_dir brief out rc

  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "bash scripts/run-all-tests.sh: skipped"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "MISSING: bash scripts/run-all-tests.sh" || return 0
  pass "$name"
}

# A latest.last symlink pointing within .agent-trace passes path validation.
# Steps:
# 1. Create .agent-trace/codex-12345.last and a relative latest.last symlink to it.
# 2. Run dispatch-post-verify.sh with the work directory.
# 3. Assert exit 0 and output containing OK.
case_symlink_indir_valid() {
  local name="symlink-indir-valid"
  should_run "$name" || return 0
  local work_dir out rc

  work_dir="$(make_work_dir "$name")"
  mkdir -p "$work_dir/.agent-trace"
  printf 'status: ok\n' > "$work_dir/.agent-trace/codex-12345.last"
  ln -sfn codex-12345.last "$work_dir/.agent-trace/latest.last"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "OK" || return 0
  pass "$name"
}

# A latest.last symlink pointing outside .agent-trace is rejected.
# Steps:
# 1. Create an external trace file and an absolute latest.last symlink pointing to it.
# 2. Run dispatch-post-verify.sh with the work directory.
# 3. Assert exit 1 and output containing FAILED.
case_symlink_outofdir_rejected() {
  local name="symlink-outofdir-rejected"
  should_run "$name" || return 0
  local work_dir out rc

  work_dir="$(make_work_dir "$name")"
  mkdir -p "$work_dir/.agent-trace"
  printf 'external content\n' > "$tmpdir/external.last"
  ln -sfn "$tmpdir/external.last" "$work_dir/.agent-trace/latest.last"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  pass "$name"
}

# A latest.stderr symlink pointing outside .agent-trace is rejected.
# Steps:
# 1. Create a valid latest.last and an absolute latest.stderr symlink pointing outside .agent-trace.
# 2. Run dispatch-post-verify.sh with the work directory.
# 3. Assert exit 1 and output containing FAILED.
case_symlink_stderr_outofdir_rejected() {
  local name="symlink-stderr-outofdir-rejected"
  should_run "$name" || return 0
  local work_dir out rc

  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  printf 'external stderr\n' > "$tmpdir/external-stderr.txt"
  ln -sfn "$tmpdir/external-stderr.txt" "$work_dir/.agent-trace/latest.stderr"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  pass "$name"
}

# A non-empty latest.stderr is shown in post-dispatch verification output.
# Steps:
# 1. Create a valid latest.last and a non-empty latest.stderr file.
# 2. Run dispatch-post-verify.sh with the work directory.
# 3. Assert exit 0 and output containing the stderr header and warning text.
case_show_stderr() {
  local name="show-stderr"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  printf 'warning: something\n' > "$work_dir/.agent-trace/latest.stderr"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "Stderr (latest.stderr)" || return 0
  assert_string_contains "$name" "$out" "warning: something" || return 0
  pass "$name"
}

# Running dispatch-post-verify.sh without arguments exits with usage status 2.
# Steps:
# 1. Prepare no work directory or brief arguments.
# 2. Run dispatch-post-verify.sh with no arguments.
# 3. Assert exit 2.
case_usage_no_args() {
  local name="usage-no-args"
  should_run "$name" || return 0
  local out rc

  run_validator rc out

  assert_eq "$name" "$rc" 2 || return 0
  pass "$name"
}

# A missing brief_file argument path fails before trace verification succeeds.
# Steps:
# 1. Create a valid work directory with a non-empty latest.last.
# 2. Run dispatch-post-verify.sh with a nonexistent brief file path.
# 3. Assert exit 1.
case_brief_not_found() {
  local name="brief-not-found"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir" /nonexistent/brief.md

  assert_eq "$name" "$rc" 1 || return 0
  pass "$name"
}

case_valid_latest_last_exists
case_valid_no_brief_arg
case_valid_selfverify_found
case_fail_no_trace_dir
case_fail_no_latest_last
case_fail_empty_latest_last
case_fail_selfverify_missing
case_fail_selfverify_failed_prefix
case_fail_selfverify_colon_fail
case_fail_selfverify_skipped
case_symlink_indir_valid
case_symlink_outofdir_rejected
case_symlink_stderr_outofdir_rejected
case_show_stderr
case_usage_no_args
case_brief_not_found

th_summary
