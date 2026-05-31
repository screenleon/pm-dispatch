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

# Write a per-run (non-latest.*) trace file and echo its absolute path — used to
# exercise the --last/--stderr override flags the /pm footer route relies on.
write_named_trace() {
  local work_dir="$1" fname="$2" content="$3"
  mkdir -p "$work_dir/.agent-trace"
  printf '%s\n' "$content" > "$work_dir/.agent-trace/$fname"
  printf '%s\n' "$work_dir/.agent-trace/$fname"
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

# A symlinked .agent-trace directory whose target is outside the work dir is rejected.
# Steps:
# 1. Create a real trace dir outside the work_dir.
# 2. Create work_dir/.agent-trace as a symlink pointing outside.
# 3. Run dispatch-post-verify.sh.
# 4. Assert exit 1.
case_fail_trace_dir_is_symlink() {
  local name="fail-trace-dir-is-symlink"
  should_run "$name" || return 0
  local work_dir out rc outside_trace

  work_dir="$(make_work_dir "$name")"
  outside_trace="$tmpdir/${name}-outside-trace"
  mkdir -p "$outside_trace"
  printf 'status: ok\n' > "$outside_trace/latest.last"
  ln -s "$outside_trace" "$work_dir/.agent-trace"

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

# A failed executor status fails even when self_verify passes.
# Steps:
# 1. Create a trace whose latest.last contains status: failed and a passing self_verify line.
# 2. Run dispatch-post-verify.sh with the work directory and matching brief file.
# 3. Assert exit 1 and output containing the executor status failure.
case_fail_executor_status_failed() {
  local name="fail-executor-status-failed"
  should_run "$name" || return 0
  local work_dir brief out rc

  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: failed
bash scripts/run-all-tests.sh: pass"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  assert_string_contains "$name" "$out" "executor reported non-success" || return 0
  pass "$name"
}

# A partial executor status fails even when self_verify passes.
# Steps:
# 1. Create a trace whose latest.last contains status: partial and a passing self_verify line.
# 2. Run dispatch-post-verify.sh with the work directory and matching brief file.
# 3. Assert exit 1 and output containing the executor status failure.
case_fail_executor_status_partial() {
  local name="fail-executor-status-partial"
  should_run "$name" || return 0
  local work_dir brief out rc

  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: partial
bash scripts/run-all-tests.sh: pass"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  assert_string_contains "$name" "$out" "executor reported non-success" || return 0
  pass "$name"
}

# A blocked executor status fails even when self_verify passes.
# Steps:
# 1. Create a trace whose latest.last contains status: blocked and a passing self_verify line.
# 2. Run dispatch-post-verify.sh with the work directory and matching brief file.
# 3. Assert exit 1 and output containing the executor status failure.
case_fail_executor_status_blocked() {
  local name="fail-executor-status-blocked"
  should_run "$name" || return 0
  local work_dir brief out rc

  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: blocked
bash scripts/run-all-tests.sh: pass"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  assert_string_contains "$name" "$out" "executor reported non-success" || return 0
  pass "$name"
}

# A latest.last containing a misleading substring is not accepted as a self_verify pass.
# Steps:
# 1. Create a trace whose latest.last contains a line that embeds "<cmd>: pass" as a substring.
# 2. Run dispatch-post-verify.sh with a brief requiring that command.
# 3. Assert exit 1 and output containing "MISSING".
case_fail_selfverify_substring_pass() {
  local name="fail-selfverify-substring-pass"
  should_run "$name" || return 0
  local work_dir brief out rc

  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "MISSING: bash scripts/run-all-tests.sh: pass not found"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "MISSING" || return 0
  pass "$name"
}

# --last overrides latest.last: verification reads the per-run file even when
# no latest.last symlink exists (the /pm footer route never writes latest.*).
# Steps:
# 1. Create a work dir with a per-run codex-99.last (status: ok) and no latest.last.
# 2. Run dispatch-post-verify.sh with --last pointing at the per-run file.
# 3. Assert exit 0 and output containing OK.
case_flag_last_override_ok() {
  local name="flag-last-override-ok"
  should_run "$name" || return 0
  local work_dir last out rc
  work_dir="$(make_work_dir "$name")"
  last="$(write_named_trace "$work_dir" "codex-99.last" "status: ok")"

  run_validator rc out "$work_dir" --last "$last"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "OK" || return 0
  pass "$name"
}

# A --last path resolving outside the run's .agent-trace is rejected, same as a
# latest.last symlink escape — race-safety guard must cover flag-supplied paths.
# Steps:
# 1. Create a work dir with .agent-trace and an external .last file outside it.
# 2. Run dispatch-post-verify.sh with --last pointing at the external file.
# 3. Assert exit 1 and output containing "outside .agent-trace".
case_flag_last_override_outside_rejected() {
  local name="flag-last-override-outside-rejected"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  mkdir -p "$work_dir/.agent-trace"
  printf 'status: ok\n' > "$tmpdir/$name.outside.last"

  run_validator rc out "$work_dir" --last "$tmpdir/$name.outside.last"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "outside .agent-trace" || return 0
  pass "$name"
}

# A nonexistent --last path hits the same not-found stop as a missing latest.last.
# Steps:
# 1. Create a work dir with an empty .agent-trace (no last file).
# 2. Run dispatch-post-verify.sh with --last pointing at a nonexistent path inside it.
# 3. Assert exit 1 and output containing "not found".
case_flag_last_override_missing() {
  local name="flag-last-override-missing"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  mkdir -p "$work_dir/.agent-trace"

  run_validator rc out "$work_dir" --last "$work_dir/.agent-trace/nope.last"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "not found" || return 0
  pass "$name"
}

# --stderr overrides latest.stderr: the per-run stderr content is surfaced.
# Steps:
# 1. Create a work dir with a valid latest.last and a per-run codex-99.stderr.
# 2. Run dispatch-post-verify.sh with --stderr pointing at the per-run stderr.
# 3. Assert exit 0 and output containing the per-run stderr content.
case_flag_stderr_override_shown() {
  local name="flag-stderr-override-shown"
  should_run "$name" || return 0
  local work_dir err out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  err="$(write_named_trace "$work_dir" "codex-99.stderr" "boom-from-override")"

  run_validator rc out "$work_dir" --stderr "$err"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "boom-from-override" || return 0
  pass "$name"
}

# A --stderr path resolving outside .agent-trace is rejected when it exists.
# Steps:
# 1. Create a work dir with a valid latest.last and an external stderr file outside .agent-trace.
# 2. Run dispatch-post-verify.sh with --stderr pointing at the external file.
# 3. Assert exit 1 and output containing "outside .agent-trace".
case_flag_stderr_override_outside_rejected() {
  local name="flag-stderr-override-outside-rejected"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  printf 'external stderr\n' > "$tmpdir/$name.outside.stderr"

  run_validator rc out "$work_dir" --stderr "$tmpdir/$name.outside.stderr"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "outside .agent-trace" || return 0
  pass "$name"
}

# --last given without --stderr falls back to latest.stderr (absent → tolerated).
# Steps:
# 1. Create a work dir with a per-run codex-99.last (status: ok) and no stderr file.
# 2. Run dispatch-post-verify.sh with only --last (no --stderr).
# 3. Assert exit 0 and that no Stderr block appears (absent stderr is tolerated).
case_flag_last_only_stderr_fallback() {
  local name="flag-last-only-stderr-fallback"
  should_run "$name" || return 0
  local work_dir last out rc
  work_dir="$(make_work_dir "$name")"
  last="$(write_named_trace "$work_dir" "codex-99.last" "status: ok")"

  run_validator rc out "$work_dir" --last "$last"

  assert_eq "$name" "$rc" 0 || return 0
  if [[ "$out" == *"=== Stderr"* ]]; then
    fail "$name" "unexpected stderr block with no stderr present: $out"
    return 0
  fi
  pass "$name"
}

# --brief-file supplies the brief; self_verify runs against the resolved last.
# Steps:
# 1. Create a work dir whose latest.last contains a passing self_verify line.
# 2. Write a brief and run dispatch-post-verify.sh passing it via --brief-file.
# 3. Assert exit 0 and output containing FOUND.
case_flag_brief_file() {
  local name="flag-brief-file"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "bash scripts/run-all-tests.sh: pass"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/run-all-tests.sh
EOF

  run_validator rc out "$work_dir" --brief-file "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "FOUND" || return 0
  pass "$name"
}

# --brief-file plus a second positional is ambiguous and rejected with usage (2).
# Steps:
# 1. Create a work dir with a valid latest.last and a brief file.
# 2. Run dispatch-post-verify.sh with both a positional brief and --brief-file.
# 3. Assert exit 2 (usage rejection).
case_flag_brief_file_and_positional_ambiguous() {
  local name="flag-brief-file-and-positional-ambiguous"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  printf 'self_verify:\n  - true\n' > "$brief"

  run_validator rc out "$work_dir" "$brief" --brief-file "$brief"

  assert_eq "$name" "$rc" 2 || return 0
  pass "$name"
}

# An unknown flag is rejected with usage (2).
# Steps:
# 1. Create a work dir with a valid latest.last.
# 2. Run dispatch-post-verify.sh with an unrecognized flag.
# 3. Assert exit 2 (usage rejection).
case_flag_unknown_rejected() {
  local name="flag-unknown-rejected"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir" --bogus

  assert_eq "$name" "$rc" 2 || return 0
  pass "$name"
}

# A value-taking flag at end-of-args (no value) is rejected with usage (2).
# Steps:
# 1. Create a work dir with a valid latest.last.
# 2. Run dispatch-post-verify.sh with --last as the final token (no value).
# 3. Assert exit 2 and output containing the missing-value error.
case_flag_missing_value_rejected() {
  local name="flag-missing-value-rejected"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir" --last

  assert_eq "$name" "$rc" 2 || return 0
  assert_string_contains "$name" "$out" "--last requires a value" || return 0
  pass "$name"
}

# A value-taking flag immediately followed by another flag is rejected (the next
# flag is not silently consumed as the value).
# Steps:
# 1. Create a work dir with a valid latest.last and a per-run stderr file.
# 2. Run dispatch-post-verify.sh with --last --stderr <path> (no value for --last).
# 3. Assert exit 2 and output containing the missing-value error for --last.
case_flag_value_is_flag_rejected() {
  local name="flag-value-is-flag-rejected"
  should_run "$name" || return 0
  local work_dir err out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  err="$(write_named_trace "$work_dir" "codex-99.stderr" "noise")"

  run_validator rc out "$work_dir" --last --stderr "$err"

  assert_eq "$name" "$rc" 2 || return 0
  assert_string_contains "$name" "$out" "--last requires a value" || return 0
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
case_fail_trace_dir_is_symlink
case_show_stderr
case_usage_no_args
case_brief_not_found
case_fail_executor_status_failed
case_fail_executor_status_partial
case_fail_executor_status_blocked
case_fail_selfverify_substring_pass
case_flag_last_override_ok
case_flag_last_override_outside_rejected
case_flag_last_override_missing
case_flag_stderr_override_shown
case_flag_stderr_override_outside_rejected
case_flag_last_only_stderr_fallback
case_flag_brief_file
case_flag_brief_file_and_positional_ambiguous
case_flag_unknown_rejected
case_flag_missing_value_rejected
case_flag_value_is_flag_rejected

th_summary
