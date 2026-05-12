#!/usr/bin/env bash
# test-patch-gitignore.sh — regression tests for patch-gitignore.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_SCRIPT="$SCRIPT_DIR/patch-gitignore.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); FAILED_CASES+=("$1"); printf 'FAIL: %s: %s\n' "$1" "$2"; }

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -Fq -- "$needle" "$file" 2>/dev/null; then
    fail "$name" "missing in $file: $needle"; return 1
  fi
}

assert_output_contains() {
  local name="$1" output="$2" needle="$3"
  if ! printf '%s\n' "$output" | grep -Fq -- "$needle"; then
    fail "$name" "missing output: $needle"; return 1
  fi
}

init_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
}

count_entry() {
  local file="$1" entry="$2"
  grep -xcF -- "$entry" "$file" 2>/dev/null || true
}

test_non_git_skips_silently() {
  local name="non-git-skips-silently"
  local dir="$TMP_ROOT/$name"
  local out="$TMP_ROOT/$name.out"
  local err="$TMP_ROOT/$name.err"
  mkdir -p "$dir"

  bash "$PATCH_SCRIPT" "$dir" ".agent-trace/" >"$out" 2>"$err"
  if [[ -s "$out" || -s "$err" ]]; then
    fail "$name" "expected no output for non-git project"
    return
  fi
  if [[ -f "$dir/.gitignore" ]]; then
    fail "$name" ".gitignore was created outside a git repo"
    return
  fi
  pass "$name"
}

test_adds_entries_and_is_idempotent() {
  local name="adds-entries-and-is-idempotent"
  local dir="$TMP_ROOT/$name"
  init_git_repo "$dir"

  bash "$PATCH_SCRIPT" "$dir" ".agent-trace/" ".codex-briefs/" ".gate-results/"
  assert_contains "$name" "$dir/.gitignore" "# Claude agent / codex output" || return
  assert_contains "$name" "$dir/.gitignore" ".agent-trace/" || return
  assert_contains "$name" "$dir/.gitignore" ".codex-briefs/" || return
  assert_contains "$name" "$dir/.gitignore" ".gate-results/" || return

  bash "$PATCH_SCRIPT" "$dir" ".agent-trace/" ".codex-briefs/" ".gate-results/"
  local entry count
  for entry in ".agent-trace/" ".codex-briefs/" ".gate-results/"; do
    count="$(count_entry "$dir/.gitignore" "$entry")"
    if [[ "$count" -ne 1 ]]; then
      fail "$name" "$entry appears $count times (expected 1)"
      return
    fi
  done
  pass "$name"
}

test_dry_run_writes_nothing() {
  local name="dry-run-writes-nothing"
  local dir="$TMP_ROOT/$name"
  local out
  init_git_repo "$dir"

  out="$(bash "$PATCH_SCRIPT" --dry-run "$dir" ".agent-trace/" ".gate-results/")"
  assert_output_contains "$name" "$out" "would add: .agent-trace/" || return
  assert_output_contains "$name" "$out" "would add: .gate-results/" || return
  if [[ -f "$dir/.gitignore" ]]; then
    fail "$name" ".gitignore was created during --dry-run"
    return
  fi
  pass "$name"
}

run_test() { "$@" || true; }

run_test test_non_git_skips_silently
run_test test_adds_entries_and_is_idempotent
run_test test_dry_run_writes_nothing

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
