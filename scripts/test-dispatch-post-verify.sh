#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/dispatch-post-verify.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"
th_init "$@"

_DPV_PLATFORM="$(detect_platform)"
_dpv_skip_win() {
  local name="$1" reason="$2"
  [[ "$_DPV_PLATFORM" == "windows" ]] || return 1
  $LIST || printf 'SKIP: %s (%s)\n' "$name" "$reason"
  return 0
}

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

# CC-386: write a latest.jsonl trace (the JSONL event stream pmctl post-verify
# integrity-checks). content is written verbatim so a test can supply a complete
# stream, a truncated one, or an empty file.
write_latest_jsonl() {
  local work_dir="$1" content="$2"
  mkdir -p "$work_dir/.agent-trace"
  printf '%s\n' "$content" > "$work_dir/.agent-trace/latest.jsonl"
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

# CC-318: a structured `cmd:` self_verify check that exits 0 is reported as PASS.
# Steps:
# 1. Create a valid trace and a brief whose self_verify item is `- cmd: "<exit-0>"`.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 and output containing the PASS line.
case_selfverify_pass() {
  local name="selfverify-pass"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "test 1 = 1"
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" 'PASS: cmd: "test 1 = 1"' || return 0
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

# CC-318: a structured `cmd:` self_verify check that exits non-zero is reported as FAIL.
# Steps:
# 1. Create a valid trace and a brief whose self_verify item is `- cmd: "<exit-1>"`.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 1 and output containing the FAIL line with the exit code.
case_selfverify_fail() {
  local name="selfverify-fail"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "test 1 = 2"
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" 'FAIL (exit 1): cmd: "test 1 = 2"' || return 0
  pass "$name"
}

# CC-318: a `cmd:` value with spaces/`=` survives quote-stripping and executes whole.
# Steps:
# 1. Create a valid trace and a brief with a quoted `cmd:` containing spaces and `=`.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 — the entire quoted command runs, not just the first word.
case_selfverify_cmd_quoted_spaces() {
  local name="selfverify-cmd-quoted-spaces"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "VAR=1 test 1 = 1"
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" 'PASS: cmd: "VAR=1 test 1 = 1"' || return 0
  pass "$name"
}

# CC-318: a single-quoted `cmd:` value is unwrapped and executed.
# Steps:
# 1. Create a valid trace and a brief with a single-quoted passing `cmd:`.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 and a PASS line.
case_selfverify_cmd_single_quotes() {
  local name="selfverify-cmd-single-quotes"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: 'test 1 = 1'
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: cmd: 'test 1 = 1'" || return 0
  pass "$name"
}

# CC-318: an unquoted `cmd:` value is executed as-is.
# Steps:
# 1. Create a valid trace and a brief with an unquoted passing `cmd:`.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 and a PASS line.
case_selfverify_cmd_unquoted() {
  local name="selfverify-cmd-unquoted"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: test 1 = 1
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: cmd: test 1 = 1" || return 0
  pass "$name"
}

# CC-318: the documented structured form (`cmd:` + `expect:`) executes the cmd value.
# Steps:
# 1. Create a valid trace and a brief with a `- cmd: "..."` item plus an `expect:` line.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 — the cmd runs and the informational `expect:` line is ignored.
case_selfverify_structured_expect() {
  local name="selfverify-structured-expect"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "test 1 = 1"
    expect: "exits 0"
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" 'PASS: cmd: "test 1 = 1"' || return 0
  pass "$name"
}

# CC-318: a named-macro self_verify item is executor-evaluated, so post-verify SKIPs it.
# Steps:
# 1. Create a valid trace and a brief whose self_verify item is a prose macro.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 and a SKIP (executor-evaluated) line — not a FAIL.
case_selfverify_macro_skipped() {
  local name="selfverify-macro-skipped"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - git-status no-collateral-damage: only the audit file as new
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "SKIP (executor-evaluated): git-status no-collateral-damage" || return 0
  pass "$name"
}

# CC-318: a bare scalar (no `cmd:`) is treated as a semantic check and SKIPped,
# never blindly executed.
# Steps:
# 1. Create a valid trace and a brief whose self_verify item is a bare command string.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 and a SKIP line — the bare scalar is not run.
case_selfverify_bare_scalar_skipped() {
  local name="selfverify-bare-scalar-skipped"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - bash scripts/definitely-missing.sh
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "SKIP (executor-evaluated): bash scripts/definitely-missing.sh" || return 0
  pass "$name"
}

# CC-318: a brief whose self_verify items are all executor-evaluated passes overall.
# Steps:
# 1. Create a valid trace and a brief with only macro/prose self_verify items.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 0 (nothing machine-checkable failed) with OK and SKIP lines.
case_selfverify_all_skipped_ok() {
  local name="selfverify-all-skipped-ok"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cross-source: each row checked against >=2 authoritative sources
  - schema-match: every new entry matches the reference shape
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "SKIP (executor-evaluated): cross-source" || return 0
  assert_string_contains "$name" "$out" "OK" || return 0
  pass "$name"
}

# CC-318: a `cmd:` check runs in $WORK_DIR (relative paths resolve there).
# Steps:
# 1. Create a valid trace and place a marker file inside the work directory.
# 2. Write a brief whose `cmd:` item tests for that marker via a relative path.
# 3. Assert exit 0 — the command only passes if cwd is the work directory.
case_selfverify_runs_in_work_dir() {
  local name="selfverify-runs-in-work-dir"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  printf 'marker\n' > "$work_dir/marker.txt"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "test -f marker.txt"
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" 'PASS: cmd: "test -f marker.txt"' || return 0
  pass "$name"
}

# CC-318: a `cmd:` check that exceeds the timeout is reported as FAIL (timeout).
# Steps:
# 1. Create a valid trace and a brief whose `cmd:` item sleeps past the timeout.
# 2. Run dispatch-post-verify.sh with DISPATCH_SELF_VERIFY_TIMEOUT=1.
# 3. Assert exit 1 and output containing the timeout FAIL line.
case_selfverify_timeout() {
  local name="selfverify-timeout"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "sleep 10"
EOF

  export DISPATCH_SELF_VERIFY_TIMEOUT=1
  run_validator rc out "$work_dir" "$brief"
  unset DISPATCH_SELF_VERIFY_TIMEOUT

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" 'FAIL (timeout 1s): cmd: "sleep 10"' || return 0
  pass "$name"
}

# CC-318: when multiple `cmd:` checks run and one fails, overall result is FAIL.
# Steps:
# 1. Create a valid trace and a brief with one passing and one failing `cmd:` item.
# 2. Run dispatch-post-verify.sh with the work directory and brief file.
# 3. Assert exit 1, a PASS line for the good item, and a FAIL line for the bad one.
case_selfverify_multiple_one_fails() {
  local name="selfverify-multiple-one-fails"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "test 1 = 1"
  - cmd: "test 1 = 2"
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" 'PASS: cmd: "test 1 = 1"' || return 0
  assert_string_contains "$name" "$out" 'FAIL (exit 1): cmd: "test 1 = 2"' || return 0
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
  if _dpv_skip_win "$name" "ln -sfn has no real-symlink support on Windows MSYS"; then return 0; fi
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
  if _dpv_skip_win "$name" "ln -sfn has no real-symlink support on Windows MSYS"; then return 0; fi
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
  if _dpv_skip_win "$name" "ln -sfn has no real-symlink support on Windows MSYS"; then return 0; fi
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
  if _dpv_skip_win "$name" "ln -s has no real-symlink support on Windows MSYS"; then return 0; fi
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
  write_latest_last "$work_dir" "status: failed"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "true"
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
  write_latest_last "$work_dir" "status: partial"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "true"
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
  write_latest_last "$work_dir" "status: blocked"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "true"
EOF

  run_validator rc out "$work_dir" "$brief"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  assert_string_contains "$name" "$out" "executor reported non-success" || return 0
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

# --brief-file supplies the brief; its self_verify items are executed.
# Steps:
# 1. Create a work dir with a valid latest.last.
# 2. Write a brief and run dispatch-post-verify.sh passing it via --brief-file.
# 3. Assert exit 0 and output containing PASS.
case_flag_brief_file() {
  local name="flag-brief-file"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "true"
EOF

  run_validator rc out "$work_dir" --brief-file "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS" || return 0
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

# The exact /pm Bash-route invocation shape — --last, --stderr, and --brief-file
# together — resolves all paths and runs self_verify in one call.
# Steps:
# 1. Create a per-run last (status line), a per-run stderr, and a brief.
# 2. Run dispatch-post-verify.sh with --last, --stderr, and --brief-file together.
# 3. Assert exit 0, a PASS self_verify line, and the per-run stderr content surfaced.
case_flag_pm_invocation_shape() {
  local name="flag-pm-invocation-shape"
  should_run "$name" || return 0
  local work_dir last err brief out rc
  work_dir="$(make_work_dir "$name")"
  last="$(write_named_trace "$work_dir" "codex-99.last" "status: ok")"
  err="$(write_named_trace "$work_dir" "codex-99.stderr" "noise-from-stderr")"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "true"
EOF

  run_validator rc out "$work_dir" --last "$last" --stderr "$err" --brief-file "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS" || return 0
  assert_string_contains "$name" "$out" "noise-from-stderr" || return 0
  pass "$name"
}

# --base makes post-verify diff against the caller-selected integration base
# (not hard-coded origin/main), preserving /pm base-aware verification.
# Steps:
# 1. Create a work dir with a valid latest.last and a git repo whose base branch
#    predates a committed newfile.txt (so the worktree is clean vs HEAD).
# 2. Run dispatch-post-verify.sh with --base <branch>.
# 3. Assert exit 0, the (base: <branch>) label, AND that the diff stat lists
#    newfile.txt — base-dependent content that only appears when diffing against
#    the selected base, not HEAD (kills a label-prints-but-diffs-HEAD mutation).
case_flag_base_override() {
  local name="flag-base-override"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  git -C "$work_dir" init -q
  git -C "$work_dir" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
  git -C "$work_dir" branch basebranch
  : > "$work_dir/newfile.txt"
  git -C "$work_dir" add -A
  git -C "$work_dir" -c user.email=t@t -c user.name=t commit -q -m change

  run_validator rc out "$work_dir" --base basebranch

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "(base: basebranch...HEAD)" || return 0
  # Worktree == HEAD (clean), so newfile.txt only shows when diffing vs basebranch;
  # a mutation that diffs HEAD would print an empty stat and fail this assertion.
  assert_string_contains "$name" "$out" "newfile.txt" || return 0
  pass "$name"
}

# A flag-supplied --stderr whose file is missing is fail-closed (broken-footer /
# lost-artifact signal), unlike the optional positional latest.stderr path.
# Steps:
# 1. Create a work dir with a valid per-run last (so --last passes) and no stderr file.
# 2. Run dispatch-post-verify.sh with --last <ok> --stderr <nonexistent .agent-trace path>.
# 3. Assert exit 1 and output containing the supplied-stderr-not-found failure.
case_flag_stderr_override_missing_rejected() {
  local name="flag-stderr-override-missing-rejected"
  should_run "$name" || return 0
  local work_dir last out rc
  work_dir="$(make_work_dir "$name")"
  last="$(write_named_trace "$work_dir" "codex-99.last" "status: ok")"

  run_validator rc out "$work_dir" --last "$last" --stderr "$work_dir/.agent-trace/nope.stderr"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "supplied --stderr not found" || return 0
  pass "$name"
}

# The `--` end-of-options sentinel forces remaining args to positionals; work_dir
# and brief_file still resolve correctly after it.
# Steps:
# 1. Create a work dir with a valid latest.last, and a brief with a passing self_verify item.
# 2. Run dispatch-post-verify.sh with `--` before the positional work_dir and brief.
# 3. Assert exit 0 and a PASS self_verify line (both positionals resolved past the sentinel).
case_flag_double_dash_positional() {
  local name="flag-double-dash-positional"
  should_run "$name" || return 0
  local work_dir brief out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  brief="$tmpdir/$name.md"
  cat > "$brief" <<'EOF'
self_verify:
  - cmd: "true"
EOF

  run_validator rc out -- "$work_dir" "$brief"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS" || return 0
  pass "$name"
}

# Three-dot base diff excludes commits the integration branch advanced past the
# fork point, so an advanced base does not surface unrelated upstream changes as
# spurious diff evidence (regression guard for the `<base>...HEAD` semantics).
# Steps:
# 1. Build a git repo: C0; branch intbase@C0; commit dispatch.txt on HEAD (C1);
#    advance intbase with upstream.txt (C2); restore HEAD to the C1 branch.
# 2. Run dispatch-post-verify.sh with --base intbase.
# 3. Assert exit 0, the diff lists dispatch.txt, and does NOT list upstream.txt
#    (a two-dot `git diff <base>` would leak upstream.txt as a removal).
case_flag_base_advanced_excludes_upstream() {
  local name="flag-base-advanced-excludes-upstream"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  git -C "$work_dir" init -q
  git -C "$work_dir" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c0
  git -C "$work_dir" branch intbase
  : > "$work_dir/dispatch.txt"
  git -C "$work_dir" add -A
  git -C "$work_dir" -c user.email=t@t -c user.name=t commit -q -m c1
  git -C "$work_dir" -c advice.detachedHead=false checkout -q intbase
  : > "$work_dir/upstream.txt"
  git -C "$work_dir" add -A
  git -C "$work_dir" -c user.email=t@t -c user.name=t commit -q -m c2
  git -C "$work_dir" checkout -q -
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir" --base intbase

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "dispatch.txt" || return 0
  if [[ "$out" == *"upstream.txt"* ]]; then
    fail "$name" "advanced-base upstream change leaked into diff evidence: $out"
    return 0
  fi
  pass "$name"
}

# A --base ref that does not exist falls back to HEAD and labels the base as
# unavailable, instead of erroring out.
# Steps:
# 1. Create a work dir with a valid latest.last and a git repo with one commit (HEAD valid; no 'bogusbase' ref).
# 2. Run dispatch-post-verify.sh with --base bogusbase.
# 3. Assert exit 0 and output containing the HEAD-fallback label naming the unavailable base.
case_flag_base_fallback_unavailable() {
  local name="flag-base-fallback-unavailable"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  git -C "$work_dir" init -q
  git -C "$work_dir" -c user.email=t@t -c user.name=t commit -q --allow-empty -m only

  run_validator rc out "$work_dir" --base bogusbase

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "(base: HEAD — bogusbase unavailable)" || return 0
  pass "$name"
}

# CC-386: a present, structurally complete latest.jsonl passes the trace-integrity
# check (positional caller, default latest.jsonl path).
# Steps:
# 1. Create a valid latest.last plus a complete JSONL trace.
# 2. Run dispatch-post-verify.sh positionally.
# 3. Assert exit 0 and the trace-integrity PASS line.
case_trace_jsonl_valid_complete_passes() {
  local name="trace-jsonl-valid-complete-passes"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"turn.started"}
{"type":"turn.completed"}'

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: trace structurally complete" || return 0
  pass "$name"
}

# CC-386: the integrity check is adapter-agnostic. codex emits a multi-line JSONL
# event stream; claude (`claude -p --output-format json`) emits a single, NON-
# streamed JSON object. `jq empty` parses both, so a complete claude single-object
# trace passes the same structural check.
# Steps:
# 1. Create a valid latest.last plus a claude-shape single JSON object trace.
# 2. Run dispatch-post-verify.sh positionally.
# 3. Assert exit 0 and the trace-integrity PASS line.
case_trace_jsonl_claude_single_object_passes() {
  local name="trace-jsonl-claude-single-object-passes"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"result","subtype":"success","is_error":false,"result":"done"}'

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: trace structurally complete" || return 0
  pass "$name"
}

# CC-386: a truncated latest.jsonl (partial trailing JSON — the orphan/SIGKILL
# signature) fails even though latest.last is non-empty.
# Steps:
# 1. Create a valid latest.last plus a JSONL trace whose last record is truncated.
# 2. Run dispatch-post-verify.sh positionally.
# 3. Assert exit 1 and the truncation FAIL message.
case_trace_jsonl_truncated_fails() {
  local name="trace-jsonl-truncated-fails"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"turn.started"}
{"type":"turn.compl'

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "trace truncated" || return 0
  pass "$name"
}

# CC-386 (scope lock): a parseable trace with NO terminal completion event
# (no codex `turn.completed`, no claude `result`) PASSES structural integrity by
# design. CC-386 verifies STRUCTURE (>= 1 parsed JSON value); per-adapter SEMANTIC
# terminal-event validation is explicitly deferred to CC-389. This test locks that
# boundary so the descope is intentional and visible, not an accident.
# Steps:
# 1. Create a valid latest.last and a one-event trace with no terminal marker.
# 2. Run dispatch-post-verify.sh positionally.
# 3. Assert exit 0 and the structural PASS line.
case_trace_jsonl_non_terminal_passes_structurally() {
  local name="trace-jsonl-non-terminal-passes-structurally"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"turn.started"}'

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: trace structurally complete" || return 0
  pass "$name"
}

# CC-386 (gate fix): a non-empty but WHITESPACE-ONLY latest.jsonl must fail. `jq
# empty` alone would pass it (whitespace is valid jq input with zero values), a
# silent false-success; the value-count check requires >= 1 parsed JSON value.
# Steps:
# 1. Create a valid latest.last and a latest.jsonl containing only newlines.
# 2. Run dispatch-post-verify.sh positionally.
# 3. Assert exit 1 and the no-JSON-value FAIL message.
case_trace_jsonl_whitespace_only_fails() {
  local name="trace-jsonl-whitespace-only-fails"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  mkdir -p "$work_dir/.agent-trace"
  printf '\n\n' > "$work_dir/.agent-trace/latest.jsonl"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "no JSON value" || return 0
  pass "$name"
}

# CC-386: a present-but-empty latest.jsonl fails the integrity check.
# Steps:
# 1. Create a valid latest.last and an empty latest.jsonl.
# 2. Run dispatch-post-verify.sh positionally.
# 3. Assert exit 1 and the empty-trace FAIL message.
case_trace_jsonl_empty_fails() {
  local name="trace-jsonl-empty-fails"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  mkdir -p "$work_dir/.agent-trace"
  touch "$work_dir/.agent-trace/latest.jsonl"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "trace is empty" || return 0
  pass "$name"
}

# CC-386: an explicit --jsonl whose file is absent is fail-closed (mirrors the
# supplied --stderr contract; every real pmctl dispatch supplies --jsonl).
# Steps:
# 1. Create a valid latest.last but no per-run jsonl.
# 2. Run dispatch-post-verify.sh with --jsonl pointing at a missing file.
# 3. Assert exit 1 and the supplied-not-found FAIL message.
case_trace_jsonl_supplied_missing_fails() {
  local name="trace-jsonl-supplied-missing-fails"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir" --jsonl "$work_dir/.agent-trace/nope.jsonl"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "supplied --jsonl not found" || return 0
  pass "$name"
}

# CC-386: a positional caller with no latest.jsonl is tolerated (back-compat with
# legacy callers and trace-less fixtures); the .last contract still governs.
# Steps:
# 1. Create only a valid latest.last (no jsonl).
# 2. Run dispatch-post-verify.sh positionally.
# 3. Assert exit 0 and the integrity SKIP note.
case_trace_jsonl_default_absent_tolerated() {
  local name="trace-jsonl-default-absent-tolerated"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "SKIP: no latest.jsonl" || return 0
  pass "$name"
}

# CC-386: an explicit --jsonl resolving outside .agent-trace is rejected (the same
# containment guard latest.last gets).
# Steps:
# 1. Create a valid latest.last and a jsonl file outside the work dir.
# 2. Run dispatch-post-verify.sh with --jsonl pointing at the external file.
# 3. Assert exit 1 and the outside-.agent-trace rejection.
case_trace_jsonl_override_outside_rejected() {
  local name="trace-jsonl-override-outside-rejected"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  printf '{"type":"turn.completed"}\n' > "$tmpdir/$name.outside.jsonl"

  run_validator rc out "$work_dir" --jsonl "$tmpdir/$name.outside.jsonl"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "latest.jsonl path is outside .agent-trace" || return 0
  pass "$name"
}

# CC-386: a latest.jsonl symlink pointing outside .agent-trace is rejected.
# Steps:
# 1. Create a valid latest.last and an external jsonl, symlink latest.jsonl to it.
# 2. Run dispatch-post-verify.sh positionally.
# 3. Assert exit 1 and the outside-.agent-trace rejection.
case_trace_jsonl_symlink_outside_rejected() {
  local name="trace-jsonl-symlink-outside-rejected"
  should_run "$name" || return 0
  if _dpv_skip_win "$name" "ln -sfn has no real-symlink support on Windows MSYS"; then return 0; fi
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  mkdir -p "$work_dir/.agent-trace"
  printf '{"type":"turn.completed"}\n' > "$tmpdir/$name.external.jsonl"
  ln -sfn "$tmpdir/$name.external.jsonl" "$work_dir/.agent-trace/latest.jsonl"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "latest.jsonl path is outside .agent-trace" || return 0
  pass "$name"
}

# CC-386: an explicit per-run --jsonl inside .agent-trace passes (the footer route
# pmctl dispatch run uses, where latest.* is not written).
# Steps:
# 1. Create a valid latest.last and a per-run codex-77.jsonl inside .agent-trace.
# 2. Run dispatch-post-verify.sh with --jsonl pointing at the per-run file.
# 3. Assert exit 0 and the trace-integrity PASS line.
case_trace_jsonl_override_ok() {
  local name="trace-jsonl-override-ok"
  should_run "$name" || return 0
  local work_dir out rc jpath
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  jpath="$(write_named_trace "$work_dir" "codex-77.jsonl" '{"type":"turn.completed"}')"

  run_validator rc out "$work_dir" --jsonl "$jpath"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: trace structurally complete" || return 0
  pass "$name"
}

# With --terminal-event, a trace carrying the declared completion event
# (codex turn.completed) passes the semantic check on top of structural integrity.
# Steps:
# 1. Create a valid latest.last and a codex trace ending in turn.completed.
# 2. Run dispatch-post-verify.sh with --terminal-event turn.completed.
# 3. Assert exit 0 and the semantic PASS line.
case_terminal_event_present_passes() {
  local name="terminal-event-present-passes"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"turn.started"}
{"type":"turn.completed"}'

  run_validator rc out "$work_dir" --terminal-event turn.completed

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: trace semantically complete" || return 0
  pass "$name"
}

# The semantic check is adapter-agnostic by declared value. claude's
# `terminal_event` is `result`; a claude single-object trace carries .type=result.
# Steps:
# 1. Create a valid latest.last and a claude-shape single result object.
# 2. Run dispatch-post-verify.sh with --terminal-event result.
# 3. Assert exit 0 and the semantic PASS line.
case_terminal_event_claude_result_passes() {
  local name="terminal-event-claude-result-passes"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"result","subtype":"success","is_error":false,"result":"done"}'

  run_validator rc out "$work_dir" --terminal-event result

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: trace semantically complete" || return 0
  pass "$name"
}

# The keystone case: with --terminal-event, a structurally whole but NON-terminal
# trace (stops at turn.started, no completion event — the auth-rejected /
# silently-killed signature) FAILS the semantic check. This is what the prior
# structure-only verifier could not catch.
# Steps:
# 1. Create a valid latest.last and a one-event trace with no terminal marker.
# 2. Run dispatch-post-verify.sh with --terminal-event turn.completed.
# 3. Assert exit 1 and the missing-terminal-event FAIL message.
case_terminal_event_missing_fails() {
  local name="terminal-event-missing-fails"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"turn.started"}'

  run_validator rc out "$work_dir" --terminal-event turn.completed

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" 'no "turn.completed" terminal event' || return 0
  pass "$name"
}

# Back-compat — WITHOUT --terminal-event, the same non-terminal trace stays
# structure-only (no semantic check runs). Complements the structure-only lock
# case_trace_jsonl_non_terminal_passes_structurally; here we additionally assert
# the semantic line is absent, proving the flag gates the new behavior.
# Steps:
# 1. Create a valid latest.last and a non-terminal trace.
# 2. Run dispatch-post-verify.sh positionally (no --terminal-event).
# 3. Assert exit 0, structural PASS present, semantic line absent.
case_terminal_event_absent_flag_structure_only() {
  local name="terminal-event-absent-flag-structure-only"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"turn.started"}'

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "PASS: trace structurally complete" || return 0
  if [[ "$out" == *"semantically complete"* || "$out" == *"terminal event"* ]]; then
    fail "$name" "unexpected semantic terminal-event check ran without --terminal-event: $out"
    return 0
  fi
  pass "$name"
}

# A structurally broken trace short-circuits BEFORE the semantic check,
# so a truncated trace fails on structure and never false-reports a missing
# terminal event (constraint: semantic layered on top, structure FAIL wins).
# Steps:
# 1. Create a valid latest.last and a truncated trace.
# 2. Run dispatch-post-verify.sh with --terminal-event turn.completed.
# 3. Assert exit 1, the truncation FAIL message, and no terminal-event line.
case_terminal_event_structural_fail_short_circuits() {
  local name="terminal-event-structural-fail-short-circuits"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"
  write_latest_jsonl "$work_dir" '{"type":"turn.started"}
{"type":"turn.compl'

  run_validator rc out "$work_dir" --terminal-event turn.completed

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "trace truncated" || return 0
  if [[ "$out" == *"terminal event"* ]]; then
    fail "$name" "semantic check ran despite structural failure: $out"
    return 0
  fi
  pass "$name"
}

# Behavior: --trace-dir <abs> re-bases the latest.* lookup onto an out-of-repo
# trace dir, so verification reads the relocated trace and the work dir need not
# contain .agent-trace at all (the relocation seam, shared with the adapters).
# Steps: write latest.last into an external trace dir; run with --trace-dir; assert OK.
case_flag_trace_dir_rebases_latest() {
  local name="flag-trace-dir-rebases-latest"
  should_run "$name" || return 0
  local work_dir trace_dir out rc
  work_dir="$(make_work_dir "$name")"
  trace_dir="$tmpdir/$name-ext-trace"
  mkdir -p "$trace_dir"
  printf '%s\n' "status: ok" > "$trace_dir/latest.last"

  run_validator rc out "$work_dir" --trace-dir "$trace_dir"

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "OK" || return 0
  pass "$name"
}

# Behavior: PM_DISPATCH_TRACE_DIR env re-bases latest.* the same way (precedence
# below an explicit --trace-dir, covered by the state-paths unit tests).
case_env_trace_dir_rebases_latest() {
  local name="env-trace-dir-rebases-latest"
  should_run "$name" || return 0
  local work_dir trace_dir out rc
  work_dir="$(make_work_dir "$name")"
  trace_dir="$tmpdir/$name-ext-trace"
  mkdir -p "$trace_dir"
  printf '%s\n' "status: ok" > "$trace_dir/latest.last"

  set +e
  out="$(PM_DISPATCH_TRACE_DIR="$trace_dir" bash "$VALIDATOR" "$work_dir" 2>&1)"
  rc=$?
  set -e

  assert_eq "$name" "$rc" 0 || return 0
  assert_string_contains "$name" "$out" "OK" || return 0
  pass "$name"
}

# Behavior: a relative --trace-dir is rejected (exit 2) so the trace base never
# depends on cwd — parity with the adapter validation.
case_flag_trace_dir_relative_rejected() {
  local name="flag-trace-dir-relative-rejected"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir" --trace-dir "rel/trace"

  assert_eq "$name" "$rc" 2 || return 0
  pass "$name"
}

# --run-dir: a relative path is rejected (exit 2) before any guard runs.
# Steps:
# 1. Create a work dir with a valid latest.last.
# 2. Run dispatch-post-verify.sh with --run-dir relative/path.
# 3. Assert exit 2.
case_run_dir_relative_rejected() {
  local name="run-dir-relative-rejected"
  should_run "$name" || return 0
  local work_dir out rc
  work_dir="$(make_work_dir "$name")"
  write_latest_last "$work_dir" "status: ok"

  run_validator rc out "$work_dir" --run-dir "relative/run"

  assert_eq "$name" "$rc" 2 || return 0
  pass "$name"
}

# --run-dir: a .agent-trace symlink pointing into the run-dir subtree passes guard 1.
# Steps:
# 1. Create a run-dir outside work_dir; put the real trace dir inside it.
# 2. Symlink work_dir/.agent-trace → run-dir/trace with a valid latest.last inside.
# 3. Run dispatch-post-verify.sh with --run-dir <abs-run-dir>.
# 4. Assert exit 0.
case_run_dir_trace_inside_pass() {
  local name="run-dir-trace-inside-pass"
  should_run "$name" || return 0
  if _dpv_skip_win "$name" "ln -s has no real-symlink support on Windows MSYS"; then return 0; fi
  local work_dir run_dir out rc

  work_dir="$(make_work_dir "$name")"
  run_dir="$tmpdir/${name}-run"
  mkdir -p "$run_dir/trace"
  printf 'status: ok\n' > "$run_dir/trace/latest.last"
  ln -s "$run_dir/trace" "$work_dir/.agent-trace"

  run_validator rc out "$work_dir" --run-dir "$run_dir"

  assert_eq "$name" "$rc" 0 || return 0
  pass "$name"
}

# --run-dir: a .agent-trace symlink pointing outside the run-dir subtree is rejected.
# Steps:
# 1. Create a run-dir and a separate escape-dir outside it, both outside work_dir.
# 2. Symlink work_dir/.agent-trace → escape-dir with a valid latest.last inside.
# 3. Run dispatch-post-verify.sh with --run-dir <abs-run-dir>.
# 4. Assert exit 1 and output containing FAILED.
case_run_dir_trace_escape_rejected() {
  local name="run-dir-trace-escape-rejected"
  should_run "$name" || return 0
  if _dpv_skip_win "$name" "ln -s has no real-symlink support on Windows MSYS"; then return 0; fi
  local work_dir run_dir escape_dir out rc

  work_dir="$(make_work_dir "$name")"
  run_dir="$tmpdir/${name}-run"
  escape_dir="$tmpdir/${name}-escape"
  mkdir -p "$run_dir" "$escape_dir"
  printf 'status: ok\n' > "$escape_dir/latest.last"
  ln -s "$escape_dir" "$work_dir/.agent-trace"

  run_validator rc out "$work_dir" --run-dir "$run_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  pass "$name"
}

# --run-dir absent: old work-dir boundary is preserved (regression guard).
# Steps:
# 1. Create a trace dir outside work_dir; symlink work_dir/.agent-trace to it.
# 2. Run dispatch-post-verify.sh WITHOUT --run-dir.
# 3. Assert exit 1 (outside work-dir is still rejected when no --run-dir supplied).
case_run_dir_absent_fallback_work_dir() {
  local name="run-dir-absent-fallback-work-dir"
  should_run "$name" || return 0
  if _dpv_skip_win "$name" "ln -s has no real-symlink support on Windows MSYS"; then return 0; fi
  local work_dir outside_trace out rc

  work_dir="$(make_work_dir "$name")"
  outside_trace="$tmpdir/${name}-outside"
  mkdir -p "$outside_trace"
  printf 'status: ok\n' > "$outside_trace/latest.last"
  ln -s "$outside_trace" "$work_dir/.agent-trace"

  run_validator rc out "$work_dir"

  assert_eq "$name" "$rc" 1 || return 0
  assert_string_contains "$name" "$out" "FAILED" || return 0
  pass "$name"
}

case_valid_latest_last_exists
case_valid_no_brief_arg
case_flag_trace_dir_rebases_latest
case_env_trace_dir_rebases_latest
case_flag_trace_dir_relative_rejected
case_run_dir_relative_rejected
case_run_dir_trace_inside_pass
case_run_dir_trace_escape_rejected
case_run_dir_absent_fallback_work_dir
case_selfverify_pass
case_trace_jsonl_valid_complete_passes
case_trace_jsonl_claude_single_object_passes
case_trace_jsonl_truncated_fails
case_trace_jsonl_whitespace_only_fails
case_trace_jsonl_non_terminal_passes_structurally
case_trace_jsonl_empty_fails
case_trace_jsonl_supplied_missing_fails
case_trace_jsonl_default_absent_tolerated
case_trace_jsonl_override_outside_rejected
case_trace_jsonl_symlink_outside_rejected
case_trace_jsonl_override_ok
case_terminal_event_present_passes
case_terminal_event_claude_result_passes
case_terminal_event_missing_fails
case_terminal_event_absent_flag_structure_only
case_terminal_event_structural_fail_short_circuits
case_fail_no_trace_dir
case_fail_no_latest_last
case_fail_empty_latest_last
case_selfverify_fail
case_selfverify_cmd_quoted_spaces
case_selfverify_cmd_single_quotes
case_selfverify_cmd_unquoted
case_selfverify_structured_expect
case_selfverify_macro_skipped
case_selfverify_bare_scalar_skipped
case_selfverify_all_skipped_ok
case_selfverify_runs_in_work_dir
case_selfverify_timeout
case_selfverify_multiple_one_fails
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
case_flag_pm_invocation_shape
case_flag_base_override
case_flag_double_dash_positional
case_flag_base_fallback_unavailable
case_flag_base_advanced_excludes_upstream
case_flag_stderr_override_missing_rejected

th_summary
