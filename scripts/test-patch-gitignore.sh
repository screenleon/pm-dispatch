#!/usr/bin/env bash
# test-patch-gitignore.sh — regression tests for patch-gitignore.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_SCRIPT="$SCRIPT_DIR/patch-gitignore.sh"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

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
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  local out="$tmp_root/$name.out"
  local err="$tmp_root/$name.err"
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
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  init_git_repo "$dir"

  bash "$PATCH_SCRIPT" "$dir" ".agent-trace/" ".codex-briefs/" ".gate-results/"
  assert_file_contains "$name" "$dir/.gitignore" "# Claude agent / codex output" || return
  assert_file_contains "$name" "$dir/.gitignore" ".agent-trace/" || return
  assert_file_contains "$name" "$dir/.gitignore" ".codex-briefs/" || return
  assert_file_contains "$name" "$dir/.gitignore" ".gate-results/" || return

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
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  local out
  init_git_repo "$dir"

  out="$(bash "$PATCH_SCRIPT" --dry-run "$dir" ".agent-trace/" ".gate-results/")"
  assert_string_contains "$name" "$out" "would add: .agent-trace/" || return
  assert_string_contains "$name" "$out" "would add: .gate-results/" || return
  if [[ -f "$dir/.gitignore" ]]; then
    fail "$name" ".gitignore was created during --dry-run"
    return
  fi
  pass "$name"
}

test_rejects_symlink_gitignore() {
  local name="rejects-symlink-gitignore"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  local target="$tmp_root/$name-elsewhere-target"
  local out="$tmp_root/$name.out"
  local err="$tmp_root/$name.err"
  init_git_repo "$dir"
  printf 'pre-existing\n' > "$target"
  ln -s "$target" "$dir/.gitignore"

  set +e
  bash "$PATCH_SCRIPT" "$dir" ".agent-trace/" >"$out" 2>"$err"
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  if ! grep -qi 'symlink' "$err"; then
    fail "$name" "stderr did not mention symlink"
    return
  fi
  if [[ "$(cat "$target")" != "pre-existing" ]]; then
    fail "$name" "symlink target was modified"
    return
  fi
  if [[ ! -L "$dir/.gitignore" ]]; then
    fail "$name" ".gitignore symlink was replaced"
    return
  fi
  pass "$name"
}

test_rejects_symlink_dry_run() {
  local name="rejects-symlink-dry-run"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  local target="$tmp_root/$name-elsewhere-target"
  local out="$tmp_root/$name.out"
  local err="$tmp_root/$name.err"
  init_git_repo "$dir"
  printf 'pre-existing\n' > "$target"
  ln -s "$target" "$dir/.gitignore"

  set +e
  bash "$PATCH_SCRIPT" --dry-run "$dir" ".agent-trace/" >"$out" 2>"$err"
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  if ! grep -qi 'symlink' "$err"; then
    fail "$name" "stderr did not mention symlink"
    return
  fi
  if grep -Fq 'would add' "$out" "$err"; then
    fail "$name" "dry-run printed would-add output for symlink"
    return
  fi
  if [[ "$(cat "$target")" != "pre-existing" ]]; then
    fail "$name" "symlink target was modified"
    return
  fi
  if [[ ! -L "$dir/.gitignore" ]]; then
    fail "$name" ".gitignore symlink was replaced"
    return
  fi
  pass "$name"
}

run_test() { "$@" || true; }

run_test test_non_git_skips_silently
run_test test_adds_entries_and_is_idempotent
run_test test_dry_run_writes_nothing
run_test test_rejects_symlink_gitignore
run_test test_rejects_symlink_dry_run

th_summary
