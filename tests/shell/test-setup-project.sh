#!/usr/bin/env bash
# test-setup-project.sh — regression tests for setup-project.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETUP_SCRIPT="$REPO_ROOT/ops/setup/setup-project.sh"
EXPECTED_ENTRIES=(
  ".agent-trace/"
  ".gate-briefs/"
  ".gate-results/"
  ".agents/"
  ".pm-dispatch-state/"
)
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

init_git_repo() {
  local dir="$1"
  git -C "$dir" init -q
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file" 2>/dev/null; then
    fail "$name" "unexpected in $file: $needle"; return 1
  fi
}

assert_entry_once() {
  local name="$1" file="$2" entry="$3"
  local count
  count="$(grep -xcF -- "$entry" "$file" 2>/dev/null || true)"
  if [[ "$count" -ne 1 ]]; then
    fail "$name" "$entry appears $count times in $file (expected 1)"
    return 1
  fi
}

assert_expected_entries_once() {
  local name="$1" file="$2"
  local entry
  for entry in "${EXPECTED_ENTRIES[@]}"; do
    assert_entry_once "$name" "$file" "$entry" || return
  done
}

test_creates_gitignore_entries() {
  # Happy path: no .gitignore exists — both entries must be created.
  local name="creates-gitignore-entries"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  mkdir -p "$dir"
  init_git_repo "$dir"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_file_contains "$name" "$dir/.gitignore" ".agent-trace/" || return
  assert_file_contains "$name" "$dir/.gitignore" ".gate-briefs/" || return
  assert_file_contains "$name" "$dir/.gitignore" ".gate-results/" || return
  assert_file_contains "$name" "$dir/.gitignore" ".agents/" || return
  assert_expected_entries_once "$name" "$dir/.gitignore" || return
  pass "$name"
}

test_patches_existing_gitignore() {
  # Existing .gitignore — entries appended, prior content preserved.
  local name="patches-existing-gitignore"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  mkdir -p "$dir"
  init_git_repo "$dir"
  printf '*.log\n' > "$dir/.gitignore"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_file_contains "$name" "$dir/.gitignore" "*.log" || return
  assert_file_contains "$name" "$dir/.gitignore" ".agent-trace/" || return
  assert_file_contains "$name" "$dir/.gitignore" ".gate-briefs/" || return
  assert_file_contains "$name" "$dir/.gitignore" ".gate-results/" || return
  assert_file_contains "$name" "$dir/.gitignore" ".agents/" || return
  assert_expected_entries_once "$name" "$dir/.gitignore" || return
  pass "$name"
}

test_idempotent_gitignore() {
  # Running twice — no duplicate entries for any managed entry.
  local name="idempotent-gitignore"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  mkdir -p "$dir"
  init_git_repo "$dir"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_expected_entries_once "$name" "$dir/.gitignore" || return
  pass "$name"
}

test_dry_run_no_modifications() {
  # --dry-run must not create or modify any files.
  local name="dry-run-no-modifications"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  mkdir -p "$dir"
  init_git_repo "$dir"

  bash "$SETUP_SCRIPT" --dry-run "$dir" > /dev/null
  if [[ -f "$dir/.gitignore" ]]; then
    fail "$name" ".gitignore was created during --dry-run"
    return
  fi
  pass "$name"
}

test_no_dockerfiles_skips_dockerignore() {
  # No Dockerfiles in tree — .dockerignore must NOT be created.
  local name="no-dockerfiles-skips-dockerignore"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  mkdir -p "$dir"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  if [[ -f "$dir/.dockerignore" ]]; then
    fail "$name" ".dockerignore was created with no Dockerfiles present"
    return
  fi
  pass "$name"
}

test_patches_dockerignore_next_to_dockerfile() {
  # Dockerfile present in subdir — co-located .dockerignore patched, existing content kept.
  local name="patches-dockerignore-next-to-dockerfile"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  local svcdir="$dir/service"
  mkdir -p "$svcdir"
  touch "$svcdir/Dockerfile"
  printf 'node_modules/\n' > "$svcdir/.dockerignore"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_file_contains "$name" "$svcdir/.dockerignore" "node_modules/" || return
  assert_file_contains "$name" "$svcdir/.dockerignore" ".agent-trace/" || return
  assert_file_contains "$name" "$svcdir/.dockerignore" ".gate-briefs/" || return
  assert_file_contains "$name" "$svcdir/.dockerignore" ".gate-results/" || return
  assert_file_contains "$name" "$svcdir/.dockerignore" ".agents/" || return
  pass "$name"
}

test_already_present_entries() {
  # Entries already in .gitignore — output says "already present", no duplicates.
  local name="already-present-entries"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  mkdir -p "$dir"
  init_git_repo "$dir"
  printf '.agent-trace/\n.gate-briefs/\n' > "$dir/.gitignore"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_expected_entries_once "$name" "$dir/.gitignore" || return
  pass "$name"
}

test_partial_state_no_header_duplicate() {
  # One entry present, one absent — header must appear exactly once after patching.
  local name="partial-state-no-header-duplicate"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  mkdir -p "$dir"
  init_git_repo "$dir"
  printf '.agent-trace/\n' > "$dir/.gitignore"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_file_contains "$name" "$dir/.gitignore" ".gate-briefs/" || return
  local hdr_count
  hdr_count=$(grep -c "Claude agent" "$dir/.gitignore" || echo 0)
  if [[ "$hdr_count" -gt 1 ]]; then
    fail "$name" "header comment duplicated ($hdr_count times)"
    return
  fi
  pass "$name"
}

test_entry_list_parity() {
  local name="entry-list-parity"
  should_run "$name" || return 0
  local dir="$tmp_root/$name"
  mkdir -p "$dir"
  init_git_repo "$dir"
  touch "$dir/Dockerfile"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_expected_entries_once "$name" "$dir/.gitignore" || return
  assert_expected_entries_once "$name" "$dir/.dockerignore" || return
  pass "$name"
}

run_test() { "$@" || true; }

run_test test_creates_gitignore_entries
run_test test_patches_existing_gitignore
run_test test_idempotent_gitignore
run_test test_dry_run_no_modifications
run_test test_no_dockerfiles_skips_dockerignore
run_test test_patches_dockerignore_next_to_dockerfile
run_test test_already_present_entries
run_test test_partial_state_no_header_duplicate
run_test test_entry_list_parity

th_summary
