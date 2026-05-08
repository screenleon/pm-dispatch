#!/usr/bin/env bash
# test-setup-project.sh — regression tests for setup-project.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-project.sh"

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

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file" 2>/dev/null; then
    fail "$name" "unexpected in $file: $needle"; return 1
  fi
}

test_creates_gitignore_entries() {
  # Happy path: no .gitignore exists — both entries must be created.
  local name="creates-gitignore-entries"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_contains "$name" "$dir/.gitignore" ".agent-trace/" || return
  assert_contains "$name" "$dir/.gitignore" ".codex-briefs/" || return
  assert_contains "$name" "$dir/.gitignore" ".gate-results/" || return
  pass "$name"
}

test_patches_existing_gitignore() {
  # Existing .gitignore — entries appended, prior content preserved.
  local name="patches-existing-gitignore"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  printf '*.log\n' > "$dir/.gitignore"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_contains "$name" "$dir/.gitignore" "*.log" || return
  assert_contains "$name" "$dir/.gitignore" ".agent-trace/" || return
  assert_contains "$name" "$dir/.gitignore" ".codex-briefs/" || return
  assert_contains "$name" "$dir/.gitignore" ".gate-results/" || return
  pass "$name"
}

test_idempotent_gitignore() {
  # Running twice — no duplicate entries for any managed entry.
  local name="idempotent-gitignore"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  local count
  for entry in ".agent-trace/" ".codex-briefs/" ".gate-results/"; do
    count=$(grep -c "$entry" "$dir/.gitignore" || echo 0)
    if [[ "$count" -ne 1 ]]; then
      fail "$name" "$entry appears $count times (expected 1)"
      return
    fi
  done
  pass "$name"
}

test_dry_run_no_modifications() {
  # --dry-run must not create or modify any files.
  local name="dry-run-no-modifications"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"

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
  local dir="$TMP_ROOT/$name"
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
  local dir="$TMP_ROOT/$name"
  local svcdir="$dir/service"
  mkdir -p "$svcdir"
  touch "$svcdir/Dockerfile"
  printf 'node_modules/\n' > "$svcdir/.dockerignore"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_contains "$name" "$svcdir/.dockerignore" "node_modules/" || return
  assert_contains "$name" "$svcdir/.dockerignore" ".agent-trace/" || return
  assert_contains "$name" "$svcdir/.dockerignore" ".codex-briefs/" || return
  assert_contains "$name" "$svcdir/.dockerignore" ".gate-results/" || return
  pass "$name"
}

test_already_present_entries() {
  # Entries already in .gitignore — output says "already present", no duplicates.
  local name="already-present-entries"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  printf '.agent-trace/\n.codex-briefs/\n' > "$dir/.gitignore"

  local out
  out=$(bash "$SETUP_SCRIPT" "$dir" 2>&1)
  if ! printf '%s' "$out" | grep -q "already present"; then
    fail "$name" "expected 'already present' in output"
    return
  fi
  local count
  count=$(grep -c "\.agent-trace/" "$dir/.gitignore" || echo 0)
  if [[ "$count" -ne 1 ]]; then
    fail "$name" ".agent-trace/ appears $count times (expected 1)"
    return
  fi
  pass "$name"
}

test_partial_state_no_header_duplicate() {
  # One entry present, one absent — header must appear exactly once after patching.
  local name="partial-state-no-header-duplicate"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  printf '.agent-trace/\n' > "$dir/.gitignore"

  bash "$SETUP_SCRIPT" "$dir" > /dev/null
  assert_contains "$name" "$dir/.gitignore" ".codex-briefs/" || return
  local hdr_count
  hdr_count=$(grep -c "Claude agent" "$dir/.gitignore" || echo 0)
  if [[ "$hdr_count" -gt 1 ]]; then
    fail "$name" "header comment duplicated ($hdr_count times)"
    return
  fi
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

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
