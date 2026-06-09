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

case_validate_brief_accepts_valid
case_validate_brief_missing_file
case_validate_brief_missing_arg
case_validate_brief_no_block
case_validate_brief_invalid_executor
case_validate_brief_unknown_flag

th_summary
