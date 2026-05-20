#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UNINSTALL="$REPO_ROOT/uninstall.sh"

# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/portable.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

pass() {
  printf 'PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -Fq -- "$needle" "$file"; then
    fail "$name" "missing output: $needle"
    return 1
  fi
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$name" "unexpected output: $needle"
    return 1
  fi
}

manifest_escape() {
  _portable_json_escape "$1"
}

write_manifest() {
  local home="$1"
  shift
  local manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  local count="$#"
  local i=0
  mkdir -p "${manifest%/*}"
  {
    printf '{\n'
    printf '  "manifest_version": 1,\n'
    printf '  "installed_at": "2026-05-20T00:00:00Z",\n'
    printf '  "pm_dispatch_version": "test",\n'
    printf '  "entries": [\n'
    for entry in "$@"; do
      i=$((i + 1))
      if [[ "$i" -lt "$count" ]]; then
        printf '    %s,\n' "$entry"
      else
        printf '    %s\n' "$entry"
      fi
    done
    printf '  ]\n'
    printf '}\n'
  } > "$manifest"
}

symlink_entry() {
  local src="$1" dst="$2"
  printf '{"src":"%s","dst":"%s","mode":"symlink"}' "$(manifest_escape "$src")" "$(manifest_escape "$dst")"
}

copy_entry() {
  local src="$1" dst="$2" sha="$3"
  printf '{"src":"%s","dst":"%s","mode":"copy","sha256":"%s","fallback_reason":"test"}' \
    "$(manifest_escape "$src")" "$(manifest_escape "$dst")" "$sha"
}

run_uninstall() {
  local home="$1" out="$2"
  shift 2
  set +e
  HOME="$home" bash "$UNINSTALL" "$@" >"$out" 2>&1
  local rc=$?
  set -e
  return "$rc"
}

test_no_manifest() {
  local name="TC-01 no-manifest"
  local home="$tmp_root/home-no-manifest"
  local out="$tmp_root/no-manifest.out"
  mkdir -p "$home"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  assert_contains "$name" "$out" "no manifest found" || return
  pass "$name"
}

test_symlink_removed() {
  local name="TC-02 symlink-removed"
  local home="$tmp_root/home-symlink-removed"
  local src="$tmp_root/symlink-removed-src"
  local dst="$home/.claude/agents/example.md"
  local out="$tmp_root/symlink-removed.out"
  mkdir -p "$(dirname "$dst")"
  printf 'agent\n' > "$src"
  ln -s "$src" "$dst"
  write_manifest "$home" "$(symlink_entry "$src" "$dst")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    fail "$name" "$dst should have been removed"
    return
  fi
  pass "$name"
}

test_symlink_foreign() {
  local name="TC-03 symlink-foreign"
  local home="$tmp_root/home-symlink-foreign"
  local src="$tmp_root/symlink-foreign-src"
  local foreign="$tmp_root/symlink-foreign-target"
  local dst="$home/.claude/agents/example.md"
  local out="$tmp_root/symlink-foreign.out"
  mkdir -p "$(dirname "$dst")"
  printf 'agent\n' > "$src"
  printf 'foreign\n' > "$foreign"
  ln -s "$foreign" "$dst"
  write_manifest "$home" "$(symlink_entry "$src" "$dst")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ ! -L "$dst" ]]; then
    fail "$name" "$dst should not have been removed"
    return
  fi
  assert_contains "$name" "$out" "not our symlink" || return
  pass "$name"
}

test_copy_sha_match() {
  local name="TC-04 copy-sha-match"
  local home="$tmp_root/home-copy-sha-match"
  local src="$tmp_root/copy-sha-match-src"
  local dst="$home/.claude/scripts/example.sh"
  local out="$tmp_root/copy-sha-match.out"
  local sha
  mkdir -p "$(dirname "$dst")"
  printf 'script\n' > "$src"
  cp "$src" "$dst"
  sha="$(_portable_sha256_path "$src")"
  write_manifest "$home" "$(copy_entry "$src" "$dst" "$sha")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ -e "$dst" ]]; then
    fail "$name" "$dst should have been removed"
    return
  fi
  pass "$name"
}

test_copy_sha_mismatch() {
  local name="TC-05 copy-sha-mismatch"
  local home="$tmp_root/home-copy-sha-mismatch"
  local src="$tmp_root/copy-sha-mismatch-src"
  local dst="$home/.claude/scripts/example.sh"
  local out="$tmp_root/copy-sha-mismatch.out"
  local sha
  mkdir -p "$(dirname "$dst")"
  printf 'script\n' > "$src"
  printf 'modified\n' > "$dst"
  sha="$(_portable_sha256_path "$src")"
  write_manifest "$home" "$(copy_entry "$src" "$dst" "$sha")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ ! -f "$dst" ]]; then
    fail "$name" "$dst should not have been removed"
    return
  fi
  assert_contains "$name" "$out" "modified since install" || return
  pass "$name"
}

test_dry_run() {
  local name="TC-06 dry-run"
  local home="$tmp_root/home-dry-run"
  local src="$tmp_root/dry-run-src"
  local dst="$home/.claude/agents/example.md"
  local out="$tmp_root/dry-run.out"
  mkdir -p "$(dirname "$dst")"
  printf 'agent\n' > "$src"
  ln -s "$src" "$dst"
  write_manifest "$home" "$(symlink_entry "$src" "$dst")"

  if ! run_uninstall "$home" "$out" --dry-run; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  assert_contains "$name" "$out" "would remove" || return
  if [[ ! -L "$dst" ]]; then
    fail "$name" "$dst should remain in dry-run"
    return
  fi
  pass "$name"
}

test_empty_dir_removed() {
  local name="TC-07 empty-dir-removed"
  local home="$tmp_root/home-empty-dir-removed"
  local src="$tmp_root/empty-dir-src"
  local dst="$home/.claude/agents/example.md"
  local out="$tmp_root/empty-dir-removed.out"
  mkdir -p "$(dirname "$dst")"
  printf 'agent\n' > "$src"
  ln -s "$src" "$dst"
  write_manifest "$home" "$(symlink_entry "$src" "$dst")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ -d "$home/.claude/agents" ]]; then
    fail "$name" "$home/.claude/agents should have been removed"
    return
  fi
  pass "$name"
}

test_hooks_called() {
  local name="TC-08 hooks-called"
  if ! command -v jq >/dev/null 2>&1; then
    printf 'SKIP: %s (jq not found)\n' "$name"
    return
  fi

  local home="$tmp_root/home-hooks-called"
  local src="$tmp_root/hooks-called-src"
  local dst="$home/.claude/scripts/example.sh"
  local out="$tmp_root/hooks-called.out"
  mkdir -p "$(dirname "$dst")"
  printf 'script\n' > "$src"
  ln -s "$src" "$dst"
  write_manifest "$home" "$(symlink_entry "$src" "$dst")"
  cat > "$home/.claude/settings.json" <<JSON
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {"type": "command", "command": "$REPO_ROOT/scripts/hook-pm-write-guard.sh"}
        ]
      }
    ]
  }
}
JSON

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  assert_contains "$name" "$out" "==> hooks" || return
  assert_contains "$name" "$out" "uninstall-hooks: wrote" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  pass "$name"
}

test_no_manifest
test_symlink_removed
test_symlink_foreign
test_copy_sha_match
test_copy_sha_mismatch
test_dry_run
test_empty_dir_removed
test_hooks_called

if [[ "$FAIL" -gt 0 ]]; then
  printf '%s passed, %s failed\n' "$PASS" "$FAIL"
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}"
  exit 1
fi

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
