#!/usr/bin/env bash
# Regression tests for pmctl validate brief subcommand (CC-341).
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Write a valid brief file with a dispatch_handover_v1 block.
# The body working_dir defaults to the metadata working_dir ($REPO_ROOT) so the
# brief is consistent; pass a second argument to force a body/metadata mismatch.
write_valid_brief() {
  local path="$1"
  local body_wd="${2:-$REPO_ROOT}"
  cat > "$path" <<EOF
Some preamble text.

\`\`\`dispatch_handover_v1
handover_version: 3
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-pmctl-validate-test.md
isolation_level: workspace-write
timeout: 600
model: default
fallback_allowed: true
---
working_dir: $body_wd
goal: test goal
EOF
  printf '```\n' >> "$path"
}

case_validate_brief_accepts_valid() {
  local name="pmctl validate brief: accepts a valid brief and exits 0"
  should_run "$name" || return 0
  # Behavior: validate brief exits 0 and prints "ok: <file>" when the brief contains a valid dispatch_handover_v1 block.
  # Steps: write a well-formed brief file; invoke validate brief; assert exit 0 and "ok:" prefix in stdout.
  local brief out err status=0
  brief="$tmp_root/valid-brief.md"
  out="$tmp_root/vb-ok.out"
  err="$tmp_root/vb-ok.err"
  write_valid_brief "$brief"
  "$PMCTL" validate brief "$brief" > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 0 ]] && grep -q "^ok:" "$out"; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with 'ok:' line, got $status out=$(<"$out") err=$(<"$err")"
  fi
}

case_validate_brief_missing_file() {
  local name="pmctl validate brief: exits 2 when file not found"
  should_run "$name" || return 0
  # Behavior: validate brief exits 2 with an error message when the specified file does not exist.
  # Steps: invoke validate brief with a path to a non-existent file; assert exit 2.
  local out err status=0
  out="$tmp_root/vb-nf.out"
  err="$tmp_root/vb-nf.err"
  "$PMCTL" validate brief "/tmp/nonexistent-brief-pmctl-validate-$$$.md" > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status err=$(<"$err")"
  fi
}

case_validate_brief_missing_arg() {
  local name="pmctl validate brief: exits 2 when no file argument given"
  should_run "$name" || return 0
  # Behavior: validate brief exits 2 with a usage error when no file argument is supplied.
  # Steps: invoke validate brief with no arguments; assert exit 2.
  local out err status=0
  out="$tmp_root/vb-na.out"
  err="$tmp_root/vb-na.err"
  "$PMCTL" validate brief > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status err=$(<"$err")"
  fi
}

case_validate_brief_no_block() {
  local name="pmctl validate brief: exits 1 when no dispatch_handover_v1 block"
  should_run "$name" || return 0
  # Behavior: validate brief exits 1 when the file does not contain a dispatch_handover_v1 fenced block.
  # Steps: write a plain text file with no fenced block; invoke validate brief; assert exit 1.
  local brief out err status=0
  brief="$tmp_root/no-block.md"
  out="$tmp_root/vb-nb.out"
  err="$tmp_root/vb-nb.err"
  printf 'Just a plain file with no fenced block.\n' > "$brief"
  "$PMCTL" validate brief "$brief" > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1, got $status err=$(<"$err")"
  fi
}

case_validate_brief_invalid_executor() {
  local name="pmctl validate brief: exits 1 for invalid executor field"
  should_run "$name" || return 0
  # Behavior: validate brief exits 1 when a required metadata field has an invalid value.
  # Steps: write a valid brief then replace executor:codex with executor:gemini; invoke validate brief; assert exit 1.
  local brief out err status=0
  brief="$tmp_root/bad-executor.md"
  out="$tmp_root/vb-be.out"
  err="$tmp_root/vb-be.err"
  write_valid_brief "$brief"
  # Replace executor: codex with something invalid
  sed -i 's/^executor: codex$/executor: gemini/' "$brief"
  "$PMCTL" validate brief "$brief" > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1, got $status err=$(<"$err")"
  fi
}

case_validate_brief_unknown_flag() {
  local name="pmctl validate brief: exits 2 for unknown flag"
  should_run "$name" || return 0
  # Behavior: validate brief rejects unrecognised flags with a usage error.
  # Steps: invoke validate brief --frobnicate /tmp/x.md; assert exit 2.
  local out err status=0
  out="$tmp_root/vb-uf.out"
  err="$tmp_root/vb-uf.err"
  "$PMCTL" validate brief --frobnicate /tmp/x.md > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $status err=$(<"$err")"
  fi
}

case_validate_brief_double_dash_separator() {
  local name="pmctl validate brief: -- separator works as file path prefix"
  should_run "$name" || return 0
  # Behavior: validate brief accepts -- as an explicit separator; the next argument is treated as the file path.
  # Steps: write a valid brief; invoke validate brief -- <file>; assert exit 0 and "ok:" in stdout.
  local brief out err status=0
  brief="$tmp_root/dd-brief.md"
  out="$tmp_root/vb-dd.out"
  err="$tmp_root/vb-dd.err"
  write_valid_brief "$brief"
  "$PMCTL" validate brief -- "$brief" > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 0 ]] && grep -q "^ok:" "$out"; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with 'ok:' line, got $status out=$(<"$out") err=$(<"$err")"
  fi
}

case_validate_brief_double_dash_extra_arg() {
  local name="pmctl validate brief: -- separator with an extra argument exits 2"
  should_run "$name" || return 0
  # Behavior: after `-- <file>` consumes the file path, any leftover argument is rejected with a
  #   usage error (exit 2) — matching the positional path, which already rejects a second argument.
  #   Guards against the separator branch silently ignoring trailing args.
  # Steps: write a valid brief; invoke validate brief -- <file> extra-arg; assert exit 2 and
  #   "unexpected argument" in stderr.
  local brief out err status=0
  brief="$tmp_root/dd-extra-brief.md"
  out="$tmp_root/vb-dd-extra.out"
  err="$tmp_root/vb-dd-extra.err"
  write_valid_brief "$brief"
  "$PMCTL" validate brief -- "$brief" extra-arg > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"unexpected argument"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 with 'unexpected argument', got $status out=$(<"$out") err=$(<"$err")"
  fi
}

case_validate_brief_body_working_dir_mismatch() {
  local name="pmctl validate brief: exits 1 when body working_dir differs from metadata working_dir"
  should_run "$name" || return 0
  # Behavior: the documented handover route requires body/metadata working_dir consistency
  #   (docs/dispatch-brief.md). A brief whose metadata working_dir is $REPO_ROOT but whose body
  #   says /tmp passes metadata validation yet must be rejected (exit 1) for the mismatch.
  # Steps: write a brief with body working_dir forced to /tmp; invoke validate brief; assert exit 1
  #   and "working_dir does not match" in stderr.
  local brief out err status=0
  brief="$tmp_root/wd-mismatch.md"
  out="$tmp_root/vb-wdm.out"
  err="$tmp_root/vb-wdm.err"
  write_valid_brief "$brief" /tmp
  "$PMCTL" validate brief "$brief" > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 1 && "$(<"$err")" == *"working_dir does not match"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 with working_dir mismatch, got $status out=$(<"$out") err=$(<"$err")"
  fi
}

case_validate_brief_body_missing_working_dir() {
  local name="pmctl validate brief: exits 1 when body has no working_dir"
  should_run "$name" || return 0
  # Behavior: a brief whose body omits working_dir entirely cannot satisfy the body-consistency
  #   check and must be rejected (exit 1) rather than green-lit on metadata alone.
  # Steps: write a valid brief then strip the body working_dir line (the one after the --- separator);
  #   invoke validate brief; assert exit 1 and "working_dir does not match" in stderr.
  local brief out err status=0
  brief="$tmp_root/wd-missing.md"
  out="$tmp_root/vb-wdmiss.out"
  err="$tmp_root/vb-wdmiss.err"
  write_valid_brief "$brief"
  # Delete the body working_dir line: the second working_dir occurrence (after ---).
  awk '/^working_dir: / { c++; if (c == 2) next } { print }' "$brief" > "$brief.tmp" && mv "$brief.tmp" "$brief"
  "$PMCTL" validate brief "$brief" > "$out" 2> "$err" && status=$? || status=$?
  if [[ "$status" -eq 1 && "$(<"$err")" == *"working_dir does not match"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 with working_dir mismatch, got $status out=$(<"$out") err=$(<"$err")"
  fi
}

case_validate_brief_accepts_valid
case_validate_brief_missing_file
case_validate_brief_missing_arg
case_validate_brief_no_block
case_validate_brief_invalid_executor
case_validate_brief_unknown_flag
case_validate_brief_double_dash_separator
case_validate_brief_double_dash_extra_arg
case_validate_brief_body_working_dir_mismatch
case_validate_brief_body_missing_working_dir

th_summary
