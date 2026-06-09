#!/usr/bin/env bash
# Regression tests for pmctl validate brief subcommand (CC-341).
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# Write a valid brief file with a dispatch_handover_v1 block.
write_valid_brief() {
  local path="$1"
  cat > "$path" <<EOF
Some preamble text.

\`\`\`dispatch_handover_v1
handover_version: 2
executor: codex
dispatch_route: main_thread_bash_background
working_dir: $REPO_ROOT
brief_file: /tmp/brief-pmctl-validate-test.md
sandbox: workspace-write
approval: never
timeout: 600
model: default
skip_git_check: false
fallback_allowed: true
---
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

case_validate_brief_accepts_valid
case_validate_brief_missing_file
case_validate_brief_missing_arg
case_validate_brief_no_block
case_validate_brief_invalid_executor
case_validate_brief_unknown_flag
case_validate_brief_double_dash_separator

th_summary
