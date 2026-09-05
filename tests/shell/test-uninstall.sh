#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UNINSTALL="$REPO_ROOT/uninstall.sh"

# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/portable.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/install-receipt.sh"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

run_case() {
  local name="$1" fn="$2"
  should_run "$name" || return 0
  "$fn"
}

# Whether this platform can create real symlinks. MSYS/Git-Bash without Developer
# Mode silently copies on `ln -s`, so symlink-mode fixtures (and the symlink
# removal / symlink-parent-traversal code paths they exercise) cannot be
# represented; such tests are skipped there. Probed once.
_TU_CAN_SYMLINK=0
printf 'x' > "$tmp_root/.symlink-probe-target"
# Probe with a real regular-file target: MSYS special-cases /dev/null into a
# real symlink even when ordinary `ln -s` silently copies, so /dev/null would
# misreport support.
if ln -s "$tmp_root/.symlink-probe-target" "$tmp_root/.symlink-probe" 2>/dev/null \
   && [[ -L "$tmp_root/.symlink-probe" ]]; then
  _TU_CAN_SYMLINK=1
fi
rm -f "$tmp_root/.symlink-probe" "$tmp_root/.symlink-probe-target" 2>/dev/null || true

# Usage at the top of a symlink-fixture test: `_tu_needs_symlink "$name" || return 0`
_tu_needs_symlink() {
  local name="$1"
  [[ "$_TU_CAN_SYMLINK" == "1" ]] && return 0
  $LIST || printf 'SKIP: %s (no real symlink support on this platform)\n' "$name"
  return 1
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
  local src="$1" dst="$2" sha="$3" digest_scheme
  digest_scheme="$(_portable_digest_scheme_for_path "$src")" || return 1
  printf '{"src":"%s","dst":"%s","mode":"copy","sha256":"%s","digest_scheme":"%s","fallback_reason":"test"}' \
    "$(manifest_escape "$src")" "$(manifest_escape "$dst")" "$sha" "$digest_scheme"
}

legacy_copy_entry() {
  local src="$1" dst="$2" sha="$3"
  printf '{"src":"%s","dst":"%s","mode":"copy","sha256":"%s","fallback_reason":"legacy"}' \
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

# Verifies that uninstall exits 0 and reports "no manifest found" when no
# install-manifest.json is present under $HOME/.claude/.pm-dispatch/.
#
# Steps:
#   1. Create a fake HOME with no .claude/.pm-dispatch directory.
#   2. Run uninstall.sh with that HOME.
#   3. Assert exit 0 and output contains "no manifest found".
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

# Verifies that a symlink whose target matches the manifest src is removed.
#
# Steps:
#   1. Create a source file and a symlink inside $HOME/.claude pointing to it.
#   2. Write a manifest entry for that symlink.
#   3. Run uninstall.sh and assert the symlink is gone.
test_symlink_removed() {
  local name="TC-02 symlink-removed"
  _tu_needs_symlink "$name" || return 0
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

# Verifies that a symlink pointing to a target other than the manifest src is
# skipped and left on disk.
#
# Steps:
#   1. Create a foreign symlink (points to a different file than the manifest src).
#   2. Write a manifest entry with the correct src but the foreign symlink as dst.
#   3. Run uninstall.sh and assert the symlink still exists.
test_symlink_foreign() {
  local name="TC-03 symlink-foreign"
  _tu_needs_symlink "$name" || return 0
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

# Verifies that a copy-mode file whose sha256 matches the manifest record is removed.
#
# Steps:
#   1. Copy a source file into $HOME/.claude; record its sha256 in the manifest.
#   2. Run uninstall.sh.
#   3. Assert the copied file no longer exists.
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

# Verifies that a copy-mode file whose sha256 differs from the manifest record is
# skipped and output reports "modified since install".
#
# Steps:
#   1. Create a dst file with different content from the manifest sha256.
#   2. Run uninstall.sh.
#   3. Assert dst still exists and output contains "modified since install".
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

# Verifies that --dry-run prints "would remove" and makes no filesystem changes.
#
# Steps:
#   1. Create a symlink inside $HOME/.claude with a matching manifest entry.
#   2. Run uninstall.sh --dry-run.
#   3. Assert the symlink still exists and output contains "would remove".
test_dry_run() {
  local name="TC-06 dry-run"
  _tu_needs_symlink "$name" || return 0
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

# Verifies that an empty managed directory (e.g. agents/) is removed with rmdir
# after its last symlink entry is uninstalled.
#
# Steps:
#   1. Create a symlink inside $HOME/.claude/agents/ with a matching manifest entry.
#   2. Run uninstall.sh; the symlink is removed, leaving agents/ empty.
#   3. Assert $HOME/.claude/agents/ no longer exists.
test_empty_dir_removed() {
  local name="TC-07 empty-dir-removed"
  _tu_needs_symlink "$name" || return 0
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

# Verifies that uninstall-guards.sh is invoked and removes pm-dispatch hook entries
# from $HOME/.claude/settings.json.
#
# Steps:
#   1. Write settings.json containing a pm-dispatch hook entry.
#   2. Run uninstall.sh.
#   3. Assert output contains "==> hooks" and "uninstall-guards: wrote"; assert
#      guard-pm-write.sh is no longer referenced in settings.json.
test_hooks_called() {
  local name="TC-08 hooks-called"
  _tu_needs_symlink "$name" || return 0
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
          {"type": "command", "command": "$REPO_ROOT/runtime/hooks/guard-pm-write.sh"}
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
  assert_contains "$name" "$out" "uninstall-guards: wrote" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  pass "$name"
}

# Verifies that a copy-mode directory whose sha256 matches the manifest record is
# removed recursively with rm -rf.
#
# Steps:
#   1. Copy a source directory tree into $HOME/.claude; record the directory sha256.
#   2. Write a manifest entry for the directory.
#   3. Run uninstall.sh and assert the directory tree no longer exists.
test_copy_dir_sha_match() {
  local name="TC-09 copy-dir-sha-match"
  local home="$tmp_root/home-copy-dir-sha-match"
  local src_dir="$tmp_root/copy-dir-sha-match-src"
  local dst_dir="$home/.claude/pm-copy-dir"
  local out="$tmp_root/copy-dir-sha-match.out"
  local sha
  mkdir -p "$home/.claude" "$src_dir"
  printf 'content' > "$src_dir/subfile.txt"
  cp -a "$src_dir" "$dst_dir"
  sha="$(_portable_sha256_path "$src_dir")"
  write_manifest "$home" "$(copy_entry "$src_dir" "$dst_dir" "$sha")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ -d "$dst_dir" ]]; then
    fail "$name" "$dst_dir should have been removed"
    return
  fi
  pass "$name"
}

# Behavior: uninstall removes an untouched legacy copy directory when its stored
# tar-v0 digest matches the destination tree.
# Steps: Arrange identical trees and a matching legacy receipt; Act by
# uninstalling; Assert success and recursive removal of the destination.
test_legacy_copy_dir_tar_sha_match() {
  local name="TC-09b legacy-copy-dir-tar-sha-match"
  local home="$tmp_root/home-legacy-copy-dir-tar-sha-match"
  local src_dir="$tmp_root/legacy-copy-dir-tar-sha-match-src"
  local dst_dir="$home/.claude/legacy-copy-dir"
  local out="$tmp_root/legacy-copy-dir-tar-sha-match.out" sha
  mkdir -p "$home/.claude" "$src_dir"
  printf 'legacy\n' > "$src_dir/subfile.txt"
  cp -a "$src_dir" "$dst_dir"
  sha="$(_portable_sha256_tar_v0 "$dst_dir")" || {
    fail "$name" "could not create legacy tar-v0 fixture"; return; }
  write_manifest "$home" "$(legacy_copy_entry "$src_dir" "$dst_dir" "$sha")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ -d "$dst_dir" ]]; then
    fail "$name" "$dst_dir should have been removed after legacy verification"
    return
  fi
  pass "$name"
}

# Verifies that a copy-mode directory whose sha256 differs from the manifest record
# is skipped and output reports "modified since install".
#
# Steps:
#   1. Create a dst directory whose contents produce a hash different from the manifest.
#   2. Run uninstall.sh.
#   3. Assert the directory still exists and output contains "modified since install".
test_copy_dir_sha_mismatch() {
  local name="TC-10 copy-dir-sha-mismatch"
  local home="$tmp_root/home-copy-dir-sha-mismatch"
  local src_dir="$tmp_root/copy-dir-sha-mismatch-src"
  local dst_dir="$home/.claude/pm-copy-dir2"
  local out="$tmp_root/copy-dir-sha-mismatch.out"
  mkdir -p "$src_dir" "$dst_dir"
  printf 'modified' > "$dst_dir/extra.txt"
  write_manifest "$home" "$(copy_entry "$src_dir" "$dst_dir" "deadbeef0000")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ ! -d "$dst_dir" ]]; then
    fail "$name" "$dst_dir should not have been removed"
    return
  fi
  assert_contains "$name" "$out" "modified since install" || return
  pass "$name"
}

# Verifies that --dry-run with a copy-mode entry prints "would remove" and does
# not delete the file.
#
# Steps:
#   1. Copy a file into $HOME/.claude; record its sha256 in the manifest.
#   2. Run uninstall.sh --dry-run.
#   3. Assert the file still exists and output contains "would remove".
test_dry_run_copy() {
  local name="TC-11 dry-run-copy"
  local home="$tmp_root/home-dry-run-copy"
  local src="$tmp_root/dry-run-copy-src"
  local dst="$home/.claude/agents/file11.md"
  local out="$tmp_root/dry-run-copy.out"
  local sha
  mkdir -p "$(dirname "$dst")"
  printf 'hello' > "$src"
  cp "$src" "$dst"
  sha="$(_portable_sha256_path "$dst")"
  write_manifest "$home" "$(copy_entry "$src" "$dst" "$sha")"

  if ! run_uninstall "$home" "$out" --dry-run; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ ! -f "$dst" ]]; then
    fail "$name" "$dst should remain in dry-run"
    return
  fi
  assert_contains "$name" "$out" "would remove" || return
  pass "$name"
}

# Verifies that an unrecognised CLI flag causes uninstall.sh to exit 2 with an
# error message containing "unknown flag".
#
# Steps:
#   1. Run uninstall.sh --bogus-flag and capture exit code and output.
#   2. Assert exit code is 2.
#   3. Assert output contains "unknown flag".
test_unknown_flag() {
  local name="TC-12 unknown-flag"
  local home="$tmp_root/home-unknown-flag"
  local out="$tmp_root/unknown-flag.out"
  local rc
  mkdir -p "$home/.claude"

  if run_uninstall "$home" "$out" --bogus-flag; then
    rc=0
  else
    rc=$?
  fi

  if [[ "$rc" -ne 2 ]]; then
    fail "$name" "expected exit 2, got $rc"
    return
  fi
  assert_contains "$name" "$out" "unknown flag" || return
  pass "$name"
}

# Verifies that manifest entries with an unknown mode or an empty dst are skipped
# and reported rather than causing a crash or silent deletion.
#
# Steps:
#   1. Write a manifest with one entry using mode "badmode" and one with an empty dst.
#   2. Run uninstall.sh.
#   3. Assert output contains "unknown mode" and "invalid manifest entry".
test_manifest_edge_branches() {
  local name="TC-13 manifest-edge-branches"
  _tu_needs_symlink "$name" || return 0
  local home="$tmp_root/home-manifest-edge-branches"
  local src="$tmp_root/manifest-edge-src"
  local copy_dst="$home/.claude/scripts/already-gone.sh"
  local unknown_dst="$home/.claude/scripts/unknown-mode.sh"
  local relative_dst="$home/.claude/agents/relative.md"
  local relative_target="../source/relative.md"
  local out="$tmp_root/manifest-edge-branches.out"
  mkdir -p "$(dirname "$copy_dst")" "$(dirname "$relative_dst")" "$home/.claude/source"
  printf 'agent\n' > "$src"
  cp "$src" "$home/.claude/source/relative.md"
  ln -s "$relative_target" "$relative_dst"
  write_manifest "$home" \
    "{\"src\":\"/x\",\"dst\":\"$(manifest_escape "$unknown_dst")\",\"mode\":\"badmode\"}" \
    '{"src":"/a","dst":"","mode":"symlink"}' \
    "$(copy_entry "$src" "$copy_dst" "$(_portable_sha256_path "$src")")" \
    "$(symlink_entry "$home/.claude/source/relative.md" "$relative_dst")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  assert_contains "$name" "$out" "unknown mode" || return
  assert_contains "$name" "$out" "invalid manifest entry" || return
  assert_contains "$name" "$out" "already gone" || return
  if [[ -e "$relative_dst" || -L "$relative_dst" ]]; then
    fail "$name" "relative symlink target should have been removed"
    return
  fi
  pass "$name"
}

# Verifies that when an entry is skipped for safety (foreign symlink), the manifest
# is preserved on disk and a rerun produces a consistent result.
#
# Steps:
#   1. Create a foreign symlink and write a manifest entry for it.
#   2. Run uninstall.sh; assert manifest still exists (safety_skipped > 0).
#   3. Rerun uninstall.sh; assert output still contains "not our symlink".
test_skip_preserves_manifest() {
  local name="TC-14 skip-preserves-manifest"
  _tu_needs_symlink "$name" || return 0
  local home="$tmp_root/home-skip-preserves-manifest"
  local src="$tmp_root/skip-preserves-manifest-src"
  local dst="$home/.claude/agents/foreign14.md"
  local out="$tmp_root/skip-preserves-manifest.out"
  local out2="$tmp_root/skip-preserves-manifest-rerun.out"
  local manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  mkdir -p "$(dirname "$dst")"
  printf 'original' > "$src"
  ln -s "/some/other/path" "$dst"
  write_manifest "$home" "$(symlink_entry "$src" "$dst")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ ! -f "$manifest" ]]; then
    fail "$name" "manifest was deleted despite skipped entries"
    return
  fi

  if ! run_uninstall "$home" "$out2"; then
    fail "$name" "second uninstall exited non-zero"
    return
  fi
  if [[ ! -f "$manifest" ]]; then
    fail "$name" "manifest deleted on second run"
    return
  fi
  assert_contains "$name" "$out2" "not our symlink" || return
  pass "$name"
}

# Verifies that when a copy-mode entry is skipped due to sha mismatch, the manifest
# is preserved on disk for manual resolution and rerun.
#
# Steps:
#   1. Create a dst file with different content than the manifest sha256.
#   2. Run uninstall.sh.
#   3. Assert manifest still exists.
test_skip_copy_preserves_manifest() {
  local name="TC-15 skip-copy-preserves-manifest"
  local home="$tmp_root/home-skip-copy-preserves-manifest"
  local src="$tmp_root/skip-copy-preserves-manifest-src"
  local dst="$home/.claude/agents/modified15.md"
  local out="$tmp_root/skip-copy-preserves-manifest.out"
  local manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  mkdir -p "$(dirname "$dst")"
  printf 'original' > "$src"
  printf 'different content' > "$dst"
  write_manifest "$home" "$(copy_entry "$src" "$dst" "deadbeef")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ ! -f "$manifest" ]]; then
    fail "$name" "manifest was deleted despite skipped modified copy"
    return
  fi
  pass "$name"
}

# Verifies that a symlink-mode manifest entry whose dst resolves outside
# $HOME/.claude is rejected and the target file is left untouched.
#
# Steps:
#   1. Write a manifest entry whose dst is an absolute path outside $HOME/.claude.
#   2. Run uninstall.sh.
#   3. Assert the outside file still exists.
test_out_of_root_dst_rejected() {
  local name="TC-16 out-of-root-dst-rejected"
  local home="$tmp_root/home-out-of-root-dst-rejected"
  local outside_file="$tmp_root/outside16.txt"
  local manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  local out="$tmp_root/out-of-root-dst-rejected.out"
  mkdir -p "$home/.claude" "$(dirname "$manifest")"
  printf 'do not delete' > "$outside_file"
  printf '{\n  "entries": [\n    {"src":"/fake/src","dst":"%s","mode":"symlink"}\n  ]\n}\n' \
    "$(manifest_escape "$outside_file")" > "$manifest"

  run_uninstall "$home" "$out" || true
  if [[ ! -f "$outside_file" ]]; then
    fail "$name" "file outside managed root was deleted"
    return
  fi
  assert_contains "$name" "$out" "dst outside managed root" || return
  pass "$name"
}

# Verifies that a copy-mode manifest entry whose dst resolves outside
# $HOME/.claude is rejected and the target directory is left untouched.
#
# Steps:
#   1. Write a manifest entry whose dst is a directory outside $HOME/.claude.
#   2. Run uninstall.sh.
#   3. Assert the outside directory still exists.
test_out_of_root_copy_rejected() {
  local name="TC-17 out-of-root-copy-rejected"
  local home="$tmp_root/home-out-of-root-copy-rejected"
  local outside_dir="$tmp_root/outside17dir"
  local manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  local out="$tmp_root/out-of-root-copy-rejected.out"
  local sha
  mkdir -p "$home/.claude" "$outside_dir" "$(dirname "$manifest")"
  printf 'keep me' > "$outside_dir/file.txt"
  sha="$(_portable_sha256_path "$outside_dir")"
  printf '{\n  "entries": [\n    {"src":"/fake/src","dst":"%s","mode":"copy","sha256":"%s","fallback_reason":"test"}\n  ]\n}\n' \
    "$(manifest_escape "$outside_dir")" "$sha" > "$manifest"

  run_uninstall "$home" "$out" || true
  if [[ ! -d "$outside_dir" ]]; then
    fail "$name" "directory outside managed root was deleted"
    return
  fi
  assert_contains "$name" "$out" "dst outside managed root" || return
  pass "$name"
}

# Verifies that a dst containing ".." components that resolve outside $HOME/.claude
# is rejected by the managed-root guard and the target file is left untouched.
#
# Steps:
#   1. Create a file in $HOME (parent of .claude) and write a manifest entry whose
#      dst is $HOME/.claude/../<filename> (lexically inside .claude, resolves outside).
#   2. Run uninstall.sh.
#   3. Assert the outside file still exists.
test_dot_dot_traversal_rejected() {
  local name="TC-18 dot-dot-traversal-rejected"
  local home="$tmp_root/home-dot-dot-traversal-rejected"
  local outside_target="$home/should-not-be-deleted.txt"
  local dotdot_dst="$home/.claude/../should-not-be-deleted.txt"
  local manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  local out="$tmp_root/dot-dot-traversal-rejected.out"
  mkdir -p "$home/.claude/.pm-dispatch"
  printf 'do not delete' > "$outside_target"
  printf '{\n  "entries": [\n    {"src":"/fake","dst":"%s","mode":"symlink"}\n  ]\n}\n' \
    "$(manifest_escape "$dotdot_dst")" > "$manifest"

  run_uninstall "$home" "$out" || true
  if [[ ! -f "$outside_target" ]]; then
    fail "$name" "dot-dot dst deleted file outside .claude/"
    return
  fi
  pass "$name"
}

# Verifies that when uninstall-guards.sh exits non-zero, the script exits non-zero
# before deleting the manifest, leaving it available for a recovery rerun; and that
# after the hook dependency is fixed a second run successfully cleans up.
#
# Steps:
#   1. Set up a mock repo with a failing uninstall-guards.sh (always exit 1).
#   2. Run mock uninstall.sh; assert non-zero exit and manifest preserved.
#   3. Fix mock hooks to exit 0; rerun; assert manifest is deleted (clean state).
test_hooks_failure_preserves_manifest() {
  local name="TC-19 hooks-failure-preserves-manifest"
  _tu_needs_symlink "$name" || return 0
  local fake_home="$tmp_root/home19"
  local mock_repo="$tmp_root/mock-repo19"
  local src19 dst19 manifest19 rc
  mkdir -p "$fake_home/.claude/agents" "$fake_home/.claude/.pm-dispatch"
  mkdir -p "$mock_repo/scripts/lib" "$mock_repo/runtime/lib" \
    "$mock_repo/hosts/claude/bin" "$mock_repo/hosts/claude/lib"

  cp "$REPO_ROOT/uninstall.sh" "$mock_repo/uninstall.sh"
  cp "$REPO_ROOT/runtime/lib/portable.sh" "$mock_repo/runtime/lib/portable.sh"
  cp "$REPO_ROOT/runtime/lib/install-receipt.sh" "$mock_repo/runtime/lib/install-receipt.sh"
  cp "$REPO_ROOT/runtime/lib/host-manifest.sh" "$mock_repo/runtime/lib/host-manifest.sh"
  cp "$REPO_ROOT/runtime/lib/host-resolver.sh" "$mock_repo/runtime/lib/host-resolver.sh"
  cp "$REPO_ROOT/runtime/lib/host-write.sh" "$mock_repo/runtime/lib/host-write.sh"
  cp "$REPO_ROOT/hosts/claude/lib/path-resolver.sh" "$mock_repo/hosts/claude/lib/path-resolver.sh"
  printf 'install_module: hosts/claude/bin/install-guards.sh\nuninstall_module: hosts/claude/bin/uninstall-guards.sh\n' \
    > "$mock_repo/hosts/claude/host.yaml"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$mock_repo/hosts/claude/bin/install-guards.sh"

  printf '#!/usr/bin/env bash\nexit 1\n' > "$mock_repo/hosts/claude/bin/uninstall-guards.sh"
  chmod +x "$mock_repo/hosts/claude/bin/install-guards.sh" "$mock_repo/hosts/claude/bin/uninstall-guards.sh"

  src19="$tmp_root/src19.md"
  printf 'hello' > "$src19"
  dst19="$fake_home/.claude/agents/link19.md"
  ln -s "$src19" "$dst19"
  manifest19="$fake_home/.claude/.pm-dispatch/install-manifest.json"
  printf '{\n  "entries": [\n    {"src":"%s","dst":"%s","mode":"symlink"}\n  ]\n}\n' \
    "$src19" "$dst19" > "$manifest19"

  rc=0
  HOME="$fake_home" bash "$mock_repo/uninstall.sh" > /dev/null 2>&1 || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when hooks fail, got 0"
  elif [[ ! -f "$manifest19" ]]; then
    fail "$name" "manifest deleted despite hooks failure - state is unrecoverable"
  else
    # First run correct: hooks failed, manifest preserved.
    # Now fix the mock hooks and rerun — recovery should succeed.
    printf '#!/usr/bin/env bash\nexit 0\n' > "$mock_repo/hosts/claude/bin/uninstall-guards.sh"
    HOME="$fake_home" bash "$mock_repo/uninstall.sh" > /dev/null 2>&1 || true
    # Entries are "already gone" (removed in first run) → safety_skipped=0 → manifest deleted
    if [[ -f "$manifest19" ]]; then
      fail "$name" "manifest not cleaned up after recovery rerun"
    else
      pass "$name"
    fi
  fi
}

# Verifies that canonical jq parsing accepts pretty-printed (multi-line) JSON
# entries instead of depending on one physical line per entry.
#
# Steps:
#   1. Write a manifest whose entry fields each occupy a separate line.
#   2. Run uninstall.sh.
#   3. Assert its already-gone entry is processed and the manifest converges.
# Behavior: canonical receipt parsing accepts a pretty-printed entry spread over
# multiple lines and processes it normally.
# Steps: Arrange a multiline already-gone symlink entry; Act by uninstalling;
# Assert the entry is visited and the converged manifest is removed.
test_multi_line_manifest_parsed() {
  local name="TC-20 multi-line-manifest-parsed"
  local fake_home="$tmp_root/home20"
  local manifest20 out20
  mkdir -p "$fake_home/.claude/.pm-dispatch"
  manifest20="$fake_home/.claude/.pm-dispatch/install-manifest.json"
  printf '{\n  "entries": [\n    {\n      "src": "/fake/src",\n      "dst": "%s/.claude/agents/f.md",\n      "mode": "symlink"\n    }\n  ]\n}\n' \
    "$fake_home" > "$manifest20"

  out20="$(HOME="$fake_home" bash "$UNINSTALL" 2>&1 || true)"
  if [[ -f "$manifest20" ]]; then
    fail "$name" "valid pretty-printed receipt was not processed: $out20"
    return
  fi
  if [[ "$out20" != *"already gone"* ]]; then
    fail "$name" "pretty-printed entry was not visited: $out20"
    return
  fi
  pass "$name"
}

# Behavior: uninstall preserves JSON-decoded path bytes and removes the exact
# owned copy destination containing quotes, backslashes, and a newline.
# Steps: Arrange special-character paths and a matching receipt; Act by
# uninstalling; Assert success and absence of the exact destination.
test_receipt_special_path_round_trip() {
  local name="TC-20b receipt-special-path-round-trip"
  local home="$tmp_root/home-special-path" root="$tmp_root/special-path-source"
  local src="$tmp_root/special-path-source/"$'source "quoted" \\ path\nfile.txt'
  local dst="$tmp_root/home-special-path/.claude/agents/"$'dest "quoted" \\ path\nfile.txt'
  local out="$tmp_root/special-path.out" sha
  mkdir -p "$home/.claude/agents" "$root"
  printf 'owned\n' > "$src"
  printf 'owned\n' > "$dst"
  sha="$(_portable_sha256_path "$dst")"
  write_manifest "$home" "$(copy_entry "$src" "$dst" "$sha")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall rejected a valid escaped receipt: $(<"$out")"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    fail "$name" "exact special-character destination was not removed"
    return
  fi
  pass "$name"
}

# Behavior: a malformed product receipt stops uninstall before it removes an
# owned pmctl symlink or discards the unreadable receipt.
# Steps: Arrange invalid JSON plus a managed pmctl link; Act by uninstalling;
# Assert exit 2, both artifacts preserved, and the cannot-safely-read diagnostic.
test_malformed_receipt_fails_before_mutation() {
  local name="TC-20c malformed-receipt-fails-before-mutation"
  _tu_needs_symlink "$name" || return 0
  local home="$tmp_root/home-malformed-receipt" manifest out pmctl rc=0
  manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  pmctl="$home/.local/bin/pmctl"
  out="$tmp_root/malformed-receipt.out"
  mkdir -p "${manifest%/*}" "${pmctl%/*}"
  printf '{"entries":[{"src":"broken"\n' > "$manifest"
  ln -s "$REPO_ROOT/cli/pmctl" "$pmctl"

  run_uninstall "$home" "$out" || rc=$?
  if [[ "$rc" -ne 2 || ! -L "$pmctl" || ! -f "$manifest" ]]; then
    fail "$name" "malformed receipt did not preserve pre-existing state (rc=$rc)"
    return
  fi
  assert_contains "$name" "$out" "cannot safely read" || return
  pass "$name"
}

# Behavior: the canonical selected-host reader preserves ordered host values from
# pretty-printed JSON.
# Steps: Arrange a multiline codex/claude host array; Act by loading it; Assert
# success and the exact ordered selected-host result.
test_selected_hosts_pretty_json() {
  local name="TC-20d selected-hosts-pretty-json"
  local receipt="$tmp_root/selected-hosts-pretty.json"
  printf '{\n  "selected_hosts": [\n    "codex",\n    "claude"\n  ],\n  "entries": []\n}\n' > "$receipt"
  if ! pm_dispatch_receipt_load_selected_hosts "$receipt"; then
    fail "$name" "canonical selected_hosts reader rejected pretty JSON"
    return
  fi
  if [[ "${PM_DISPATCH_RECEIPT_SELECTED_HOSTS[*]}" != "codex claude" ]]; then
    fail "$name" "unexpected selected hosts: ${PM_DISPATCH_RECEIPT_SELECTED_HOSTS[*]}"
    return
  fi
  pass "$name"
}

# Behavior: duplicate receipt destinations are rejected before uninstall mutates
# managed state.
# Steps: Arrange two sources for one destination beside managed state; Act by
# uninstalling; Assert exit 2, preserved state, and a duplicate diagnostic.
test_duplicate_receipt_destination_fails_closed() {
  local name="TC-20e duplicate-receipt-destination-fails-closed"
  _tu_needs_symlink "$name" || return 0
  local home="$tmp_root/home-duplicate-receipt" manifest out pmctl rc=0 dst
  manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  pmctl="$home/.local/bin/pmctl"
  dst="$home/.claude/agents/duplicate.md"
  out="$tmp_root/duplicate-receipt.out"
  mkdir -p "${manifest%/*}" "${pmctl%/*}"
  jq -n --arg dst "$dst" '{entries: [
      {src: "/first", dst: $dst, mode: "symlink"},
      {src: "/second", dst: $dst, mode: "symlink"}
    ]}' > "$manifest"
  ln -s "$REPO_ROOT/cli/pmctl" "$pmctl"

  run_uninstall "$home" "$out" || rc=$?
  if [[ "$rc" -ne 2 || ! -L "$pmctl" || ! -f "$manifest" ]]; then
    fail "$name" "duplicate destination did not preserve pre-existing state (rc=$rc)"
    return
  fi
  assert_contains "$name" "$out" "duplicate destination" || return
  pass "$name"
}

# Behavior: receipt validation rejects a decoded NUL in a path without exposing
# any partially loaded destination entries, and names NUL on stderr.
# Steps: Arrange a receipt containing an escaped NUL; Act by validating it;
# Assert exit 2, empty destination array, and a NUL-specific diagnostic.
test_nul_receipt_field_fails_closed() {
  local name="TC-20f nul-receipt-field-fails-closed"
  local receipt="$tmp_root/nul-receipt-field.json" err rc=0
  err="$tmp_root/nul-receipt-field.err"
  printf '{"manifest_version":1,"entries":[{"src":"/safe","dst":"/bad\\u0000path","mode":"symlink"}]}\n' \
    > "$receipt"
  pm_dispatch_receipt_validate "$receipt" >/dev/null 2>"$err" || rc=$?
  if [[ "$rc" -ne 2 || "${#PM_DISPATCH_RECEIPT_ENTRY_DSTS[@]}" -ne 0 ]] \
      || ! grep -q 'must not contain a NUL' "$err"; then
    fail "$name" "NUL-bearing receipt field was accepted or diagnostic missing (rc=$rc err=$(cat "$err"))"
    return
  fi
  pass "$name"
}

# Behavior: an explicit Codex uninstall validates a malformed product receipt
# before changing Codex hook state.
# Steps: Arrange invalid entry structure and managed hooks; Act via explicit
# Codex uninstall; Assert exit 2, retained receipt, unchanged hooks, and an error.
test_explicit_codex_malformed_receipt_precedes_host_mutation() {
  local name="TC-20g explicit-codex-malformed-receipt-precedes-host-mutation"
  local home="$tmp_root/home-explicit-codex-malformed"
  local codex_home="$tmp_root/codex-explicit-malformed" receipt hooks before out rc=0
  receipt="$home/.pm-dispatch/install-manifest.json"
  hooks="$codex_home/hooks.json"
  before="$tmp_root/explicit-codex-malformed.before"
  out="$tmp_root/explicit-codex-malformed.out"
  mkdir -p "${receipt%/*}" "$codex_home"
  printf '{"manifest_version":1,"selected_hosts":["codex"],"entries":"invalid"}\n' > "$receipt"
  printf '{"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"%s/hosts/codex/hooks/command-guard.sh"}]}]}}\n' \
    "$REPO_ROOT" > "$hooks"
  cp "$hooks" "$before"

  HOME="$home" CODEX_HOME="$codex_home" bash "$UNINSTALL" --host codex > "$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 2 || ! -f "$receipt" ]] || ! cmp -s "$before" "$hooks"; then
    fail "$name" "host state changed before malformed explicit receipt rejection (rc=$rc)"
    return
  fi
  assert_contains "$name" "$out" "cannot safely read product receipt" || return
  pass "$name"
}

# Behavior: an explicit Codex uninstall rejects an unsupported receipt schema
# before changing Codex hook state.
# Steps: Arrange a version-99 receipt and managed hooks; Act via explicit Codex
# uninstall; Assert exit 2, retained receipt, unchanged hooks, and an error.
test_explicit_codex_unknown_version_precedes_host_mutation() {
  local name="TC-20h explicit-codex-unknown-version-precedes-host-mutation"
  local home="$tmp_root/home-explicit-codex-version"
  local codex_home="$tmp_root/codex-explicit-version" receipt hooks before out rc=0
  receipt="$home/.pm-dispatch/install-manifest.json"
  hooks="$codex_home/hooks.json"
  before="$tmp_root/explicit-codex-version.before"
  out="$tmp_root/explicit-codex-version.out"
  mkdir -p "${receipt%/*}" "$codex_home"
  printf '{"manifest_version":99,"selected_hosts":["codex"],"entries":[]}\n' > "$receipt"
  printf '{"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"%s/hosts/codex/hooks/command-guard.sh"}]}]}}\n' \
    "$REPO_ROOT" > "$hooks"
  cp "$hooks" "$before"

  HOME="$home" CODEX_HOME="$codex_home" bash "$UNINSTALL" --host codex > "$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 2 || ! -f "$receipt" ]] || ! cmp -s "$before" "$hooks"; then
    fail "$name" "unknown schema changed host state before rejection (rc=$rc)"
    return
  fi
  assert_contains "$name" "$out" "cannot safely read product receipt" || return
  pass "$name"
}

# Verifies that a copy-mode dst that lexically starts with $HOME/.claude but
# whose realpath resolves outside the managed root (via a symlinked parent
# directory) is rejected and the outside file is left untouched.
#
# Steps:
#   1. Create a symlink inside $HOME/.claude pointing to an outside directory.
#   2. Write a manifest copy-mode entry for a path through the symlinked parent.
#   3. Run uninstall.sh and assert the outside file still exists.
test_symlink_parent_traversal_rejected() {
  local name="TC-21 symlink-parent-traversal-rejected"
  _tu_needs_symlink "$name" || return 0
  local fake_home="$tmp_root/home21"
  local outside_dir outside_file dst21 sha21 manifest21
  mkdir -p "$fake_home/.claude/agents" "$fake_home/.claude/.pm-dispatch"

  # Create an "outside" file that a symlinked parent directory would target
  outside_dir="$tmp_root/outside21"
  mkdir -p "$outside_dir"
  outside_file="$outside_dir/precious.md"
  printf 'do not delete' > "$outside_file"

  # Create a symlink inside .claude pointing to outside_dir
  ln -s "$outside_dir" "$fake_home/.claude/linkdir"

  # The dst lexically appears inside .claude (starts with $fake_home/.claude)
  # but physically resolves to $outside_dir/precious.md (outside the managed root)
  dst21="$fake_home/.claude/linkdir/precious.md"

  # Compute sha256 of the actual file so it would pass the hash check
  sha21="$(sha256sum "$outside_file" 2>/dev/null | awk '{print $1}')"
  [[ -z "$sha21" ]] && sha21="$(shasum -a 256 "$outside_file" 2>/dev/null | awk '{print $1}')"

  manifest21="$fake_home/.claude/.pm-dispatch/install-manifest.json"
  printf '{\n  "entries": [\n    {"src":"/fake","dst":"%s","mode":"copy","sha256":"%s","fallback_reason":"test"}\n  ]\n}\n' \
    "$dst21" "$sha21" > "$manifest21"

  HOME="$fake_home" bash "$UNINSTALL" > /dev/null 2>&1 || true

  if [[ ! -f "$outside_file" ]]; then
    fail "$name" "file outside managed root deleted via symlinked parent dir"
  else
    pass "$name"
  fi
}

# Verifies that symlinked-parent traversal is blocked even when realpath is
# unavailable, by failing closed (return 1 from is_under_managed_root) when the
# path exists on disk but cannot be physically resolved.
#
# Steps:
#   1. Inject a fake realpath binary (always exits 1) earlier on PATH.
#   2. Write a copy-mode manifest entry through a symlinked parent directory.
#   3. Run uninstall.sh via a mock repo and assert the outside file is not deleted.
test_symlink_parent_no_realpath_rejected() {
  local name="TC-22 symlink-parent-no-realpath-rejected"
  _tu_needs_symlink "$name" || return 0
  local fake_home="$tmp_root/home22"
  local mock_repo="$tmp_root/mock-repo22"
  local outside_dir outside_file dst22 sha22 manifest22
  mkdir -p "$fake_home/.claude/agents" "$fake_home/.claude/.pm-dispatch"
  mkdir -p "$mock_repo/scripts/lib" "$mock_repo/runtime/lib" \
    "$mock_repo/hosts/claude/lib" "$mock_repo/bin"

  # Set up a mock repo with a real uninstall.sh, portable helpers, and working hooks.
  cp "$REPO_ROOT/uninstall.sh" "$mock_repo/uninstall.sh"
  cp "$REPO_ROOT/runtime/lib/portable.sh" "$mock_repo/runtime/lib/portable.sh"
  cp "$REPO_ROOT/runtime/lib/install-receipt.sh" "$mock_repo/runtime/lib/install-receipt.sh"
  cp "$REPO_ROOT/hosts/claude/lib/path-resolver.sh" "$mock_repo/hosts/claude/lib/path-resolver.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$mock_repo/scripts/uninstall-guards.sh"
  chmod +x "$mock_repo/scripts/uninstall-guards.sh"

  # Inject a fake realpath that always exits 1 with no output.
  printf '#!/usr/bin/env bash\nexit 1\n' > "$mock_repo/bin/realpath"
  chmod +x "$mock_repo/bin/realpath"

  outside_dir="$tmp_root/outside22"
  mkdir -p "$outside_dir"
  outside_file="$outside_dir/precious22.md"
  printf 'do not delete' > "$outside_file"
  ln -s "$outside_dir" "$fake_home/.claude/linkdir22"

  dst22="$fake_home/.claude/linkdir22/precious22.md"
  sha22="$(sha256sum "$outside_file" 2>/dev/null | awk '{print $1}')"
  [[ -z "$sha22" ]] && sha22="$(shasum -a 256 "$outside_file" 2>/dev/null | awk '{print $1}')"

  manifest22="$fake_home/.claude/.pm-dispatch/install-manifest.json"
  printf '{\n  "entries": [\n    {"src":"/fake","dst":"%s","mode":"copy","sha256":"%s","fallback_reason":"test"}\n  ]\n}\n' \
    "$dst22" "$sha22" > "$manifest22"

  HOME="$fake_home" PATH="$mock_repo/bin:$PATH" bash "$mock_repo/uninstall.sh" > /dev/null 2>&1 || true

  if [[ ! -f "$outside_file" ]]; then
    fail "$name" "file deleted outside managed root when realpath unavailable (fail-open)"
  else
    pass "$name"
  fi
}

# Verifies that when $HOME/.claude is itself a symlink, uninstall.sh correctly
# resolves the managed root via realpath and can still remove entries that live
# inside the resolved directory.
#
# Steps:
#   1. Create a real directory outside fake HOME; make $HOME/.claude a symlink to it.
#   2. Write a symlink manifest entry pointing inside the symlinked .claude.
#   3. Run uninstall.sh and assert the symlink is removed (managed-root resolved OK).
test_claude_home_symlink() {
  local name="TC-23 claude-home-symlink"
  _tu_needs_symlink "$name" || return 0
  local fake_home="$tmp_root/home23"
  local real_claude="$tmp_root/real_claude_home23"
  local src23 manifest23

  # real_claude is the actual directory; $fake_home/.claude is a symlink to it
  mkdir -p "$real_claude/.pm-dispatch" "$real_claude/agents"
  mkdir -p "$fake_home"
  ln -s "$real_claude" "$fake_home/.claude"

  src23="$tmp_root/src23.md"
  printf 'hello' > "$src23"
  ln -s "$src23" "$real_claude/agents/tc23.md"

  manifest23="$real_claude/.pm-dispatch/install-manifest.json"
  printf '{"entries":[{"src":"%s","dst":"%s/.claude/agents/tc23.md","mode":"symlink"}]}\n' \
    "$src23" "$fake_home" > "$manifest23"

  HOME="$fake_home" bash "$UNINSTALL" > /dev/null 2>&1 || true

  if [[ -L "$real_claude/agents/tc23.md" ]]; then
    fail "$name" "symlink not removed when ~/.claude is itself a symlink"
  else
    pass "$name"
  fi
}

test_pmctl_symlink_removed() {
  # Verifies uninstall removes ~/.local/bin/pmctl when it is our symlink.
  #
  # Steps:
  #   1. Create ~/.local/bin/pmctl -> <repo>/cli/pmctl.
  #   2. Run uninstall.
  #   3. Assert the symlink is gone and output contains "remove <dest>".
  local name="TC-24 pmctl-symlink-removed"
  _tu_needs_symlink "$name" || return 0
  local home="$tmp_root/home-pmctl-removed"
  local dest="$home/.local/bin/pmctl"
  local out="$tmp_root/pmctl-removed.out"
  mkdir -p "$(dirname "$dest")"
  ln -s "$REPO_ROOT/cli/pmctl" "$dest"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    fail "$name" "$dest should have been removed"
    return
  fi
  assert_contains "$name" "$out" "remove $dest" || return
  pass "$name"
}

test_pmctl_manifest_duplicate_converges() {
  # The installer records ~/.local/bin/pmctl in the manifest even though
  # uninstall_pmctl_cli removes it before the manifest loop. That duplicate
  # already-gone entry must not count as an out-of-root safety skip or preserve
  # the manifest forever.
  #
  # Steps:
  #   1. Create the owned pmctl symlink and a matching manifest entry.
  #   2. Run uninstall; the dedicated phase removes the symlink first.
  #   3. Assert the manifest loop accepts already-gone and removes the manifest.
  local name="TC-24b pmctl-manifest-duplicate-converges"
  _tu_needs_symlink "$name" || return 0
  local home="$tmp_root/home-pmctl-manifest-duplicate"
  local dest="$home/.local/bin/pmctl"
  local out="$tmp_root/pmctl-manifest-duplicate.out"
  local manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  mkdir -p "$(dirname "$dest")"
  ln -s "$REPO_ROOT/cli/pmctl" "$dest"
  write_manifest "$home" "$(symlink_entry "$REPO_ROOT/cli/pmctl" "$dest")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    fail "$name" "$dest should have been removed"
    return
  fi
  if [[ -e "$manifest" ]]; then
    fail "$name" "manifest should be removed after duplicate entry is already gone"
    return
  fi
  assert_contains "$name" "$out" "skip $dest (already gone)" || return
  assert_not_contains "$name" "$out" "manual attention" || return
  pass "$name"
}

test_pmctl_foreign_symlink_preserved() {
  # Verifies uninstall preserves a ~/.local/bin/pmctl symlink that points
  # somewhere other than this checkout's cli/pmctl (ownership check).
  #
  # Steps:
  #   1. Create ~/.local/bin/pmctl -> an unrelated (foreign) target.
  #   2. Run uninstall.
  #   3. Assert the symlink survives and output contains "not our symlink".
  local name="TC-25 pmctl-foreign-symlink-preserved"
  _tu_needs_symlink "$name" || return 0
  local home="$tmp_root/home-pmctl-foreign"
  local foreign="$tmp_root/foreign-pmctl"
  local dest="$home/.local/bin/pmctl"
  local out="$tmp_root/pmctl-foreign.out"
  mkdir -p "$(dirname "$dest")"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$foreign"
  ln -s "$foreign" "$dest"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ ! -L "$dest" ]]; then
    fail "$name" "$dest should not have been removed"
    return
  fi
  assert_contains "$name" "$out" "not our symlink" || return
  pass "$name"
}

test_pmctl_real_file_preserved() {
  # Verifies uninstall preserves a ~/.local/bin/pmctl that is a real file
  # (not a symlink) — only our symlink is ever removed.
  #
  # Steps:
  #   1. Create ~/.local/bin/pmctl as a plain file.
  #   2. Run uninstall.
  #   3. Assert the file survives and output contains "not a symlink".
  local name="TC-26 pmctl-real-file-preserved"
  local home="$tmp_root/home-pmctl-real-file"
  local dest="$home/.local/bin/pmctl"
  local out="$tmp_root/pmctl-real-file.out"
  mkdir -p "$(dirname "$dest")"
  printf 'foreign pmctl\n' > "$dest"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero"
    return
  fi
  if [[ ! -f "$dest" ]]; then
    fail "$name" "$dest should not have been removed"
    return
  fi
  # The foreign file is preserved on every platform. On Windows uninstall skips
  # the pmctl CLI entirely (it is never installed there), so the reason differs.
  if [[ "$(detect_platform)" == "windows" ]]; then
    assert_contains "$name" "$out" "not installed on Windows" || return
  else
    assert_contains "$name" "$out" "not a symlink" || return
  fi
  pass "$name"
}

test_prune_feedback() {
  # Verifies that uninstall prints "pruned <dir>" when an empty managed directory
  # is successfully removed by the post-manifest pruning loop.
  #
  # Steps:
  #   1. Install a copy-mode file into share/; compute SHA so manifest matches.
  #   2. Run uninstall.sh; the copy is removed, share/ becomes empty.
  #   3. Assert output contains "pruned" and share/ directory is gone.
  local name="TC-27 prune-feedback"
  local home="$tmp_root/home-prune-feedback"
  local src="$tmp_root/codex-model-aliases.tsv"
  local dst="$home/.claude/share/codex-model-aliases.tsv"
  local out="$tmp_root/prune-feedback.out"
  printf 'alias\tmodel\n' > "$src"
  local sha
  sha="$(sha256sum "$src" | cut -d' ' -f1)"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  write_manifest "$home" "$(copy_entry "$src" "$dst" "$sha")"

  if ! run_uninstall "$home" "$out"; then
    fail "$name" "uninstall exited non-zero: $(cat "$out")"
    return
  fi
  if ! grep -q "pruned" "$out"; then
    fail "$name" "expected 'pruned' in output but got: $(cat "$out")"
    return
  fi
  if [[ -d "$home/.claude/share" ]]; then
    fail "$name" "$home/.claude/share should have been pruned"
    return
  fi
  pass "$name"
}

# Verifies that a manifest entry whose dst equals CLAUDE_HOME itself is rejected
# by the managed-root guard and the directory is left untouched.
#
# Steps:
#   1. Write a manifest entry with dst = $HOME/.claude (the managed root itself).
#   2. Run uninstall.sh.
#   3. Assert the directory still exists and the guard error was reported.
test_claude_home_dst_rejected() {
  local name="TC-28 claude-home-dst-rejected"
  local home="$tmp_root/home-claude-home-dst-rejected"
  local claude_home="$home/.claude"
  local manifest="$claude_home/.pm-dispatch/install-manifest.json"
  local out="$tmp_root/claude-home-dst-rejected.out"
  mkdir -p "$claude_home" "$(dirname "$manifest")"
  # dst points to $HOME/.claude itself — must be rejected
  printf '{\n  "entries": [\n    {"src":"/fake/src","dst":"%s","mode":"symlink"}\n  ]\n}\n' \
    "$(manifest_escape "$claude_home")" > "$manifest"

  run_uninstall "$home" "$out" || true
  if [[ ! -d "$claude_home" ]]; then
    fail "$name" "CLAUDE_HOME itself was deleted — blast-radius guard bypassed"
    return
  fi
  assert_contains "$name" "$out" "dst outside managed root" || return
  pass "$name"
}

# A partial checkout without the manifest dispatcher cannot safely discover
# Claude or optional-host uninstall modules. Uninstall remains best-effort but
# must warn and leave existing Claude settings byte-identical.
test_missing_host_write_library_warns_and_preserves_hooks() {
  local name="TC-29 missing-host-write-library-warns-and-preserves-hooks"
  local home="$tmp_root/home-missing-host-write" mock_repo="$tmp_root/mock-repo-missing-host-write"
  local out="$tmp_root/missing-host-write.out" before="$tmp_root/missing-host-write.before" rc=0
  mkdir -p "$home/.claude" "$mock_repo/scripts/lib" "$mock_repo/runtime/lib" \
    "$mock_repo/hosts/claude/lib"
  cp "$REPO_ROOT/uninstall.sh" "$mock_repo/uninstall.sh"
  cp "$REPO_ROOT/runtime/lib/portable.sh" "$mock_repo/runtime/lib/portable.sh"
  cp "$REPO_ROOT/hosts/claude/lib/path-resolver.sh" "$mock_repo/hosts/claude/lib/path-resolver.sh"
  printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/checkout/runtime/hooks/guard-session-summary.sh --host claude"}]}]},"foreign":{"keep":true}}\n' \
    > "$home/.claude/settings.json"
  cp "$home/.claude/settings.json" "$before"

  HOME="$home" bash "$mock_repo/uninstall.sh" >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "expected best-effort exit 0, got $rc: $(<"$out")"
    return
  fi
  assert_contains "$name" "$out" "host write libraries unavailable; Claude and optional-host hooks will not be removed" || return
  if ! cmp -s "$before" "$home/.claude/settings.json"; then
    fail "$name" "settings.json changed despite unavailable host-write libraries"
    return
  fi
  pass "$name"
}

# Behavior: Codex uninstall always removes every scratch file after a successful
# one-sided update, including the temporary file for the unchanged target.
# Steps: Seed both Codex targets, independently change hooks and instructions,
# then run the host uninstaller with a fresh TMPDIR and assert it is empty.
test_codex_uninstall_success_cleans_unchanged_target_scratch() {
  local name="codex-uninstall-success-cleans-unchanged-target-scratch"
  local codex_home="$tmp_root/$name-codex" prep_tmp="$tmp_root/$name-prep-tmp"
  local scratch="$tmp_root/$name-scratch" rc=0
  mkdir -p "$prep_tmp" "$scratch"

  TMPDIR="$prep_tmp" CODEX_HOME="$codex_home" \
    bash "$REPO_ROOT/hosts/codex/bin/install.sh" --repo-root "$REPO_ROOT" >/dev/null || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "precondition install exited $rc"
    return
  fi

  printf '\n' > "$codex_home/AGENTS.md"
  TMPDIR="$scratch" CODEX_HOME="$codex_home" \
    bash "$REPO_ROOT/hosts/codex/bin/uninstall.sh" --repo-root "$REPO_ROOT" >/dev/null || rc=$?
  if [[ "$rc" -ne 0 || -n "$(compgen -G "$scratch/tmp.*")" ]]; then
    fail "$name" "hooks-only uninstall left scratch files (rc=$rc)"
    return
  fi

  TMPDIR="$prep_tmp" CODEX_HOME="$codex_home" \
    bash "$REPO_ROOT/hosts/codex/bin/install.sh" --repo-root "$REPO_ROOT" >/dev/null || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "second precondition install exited $rc"
    return
  fi
  printf '{}\n' > "$codex_home/hooks.json"
  TMPDIR="$scratch" CODEX_HOME="$codex_home" \
    bash "$REPO_ROOT/hosts/codex/bin/uninstall.sh" --repo-root "$REPO_ROOT" >/dev/null || rc=$?
  if [[ "$rc" -ne 0 || -n "$(compgen -G "$scratch/tmp.*")" ]]; then
    fail "$name" "instructions-only uninstall left scratch files (rc=$rc)"
    return
  fi
  pass "$name"
}

run_case "TC-01 no-manifest" test_no_manifest
run_case "TC-02 symlink-removed" test_symlink_removed
run_case "TC-03 symlink-foreign" test_symlink_foreign
run_case "TC-04 copy-sha-match" test_copy_sha_match
run_case "TC-05 copy-sha-mismatch" test_copy_sha_mismatch
run_case "TC-06 dry-run" test_dry_run
run_case "TC-07 empty-dir-removed" test_empty_dir_removed
run_case "TC-08 hooks-called" test_hooks_called
run_case "TC-09 copy-dir-sha-match" test_copy_dir_sha_match
run_case "TC-09b legacy-copy-dir-tar-sha-match" test_legacy_copy_dir_tar_sha_match
run_case "TC-10 copy-dir-sha-mismatch" test_copy_dir_sha_mismatch
run_case "TC-11 dry-run-copy" test_dry_run_copy
run_case "TC-12 unknown-flag" test_unknown_flag
run_case "TC-13 manifest-edge-branches" test_manifest_edge_branches
run_case "TC-14 skip-preserves-manifest" test_skip_preserves_manifest
run_case "TC-15 skip-copy-preserves-manifest" test_skip_copy_preserves_manifest
run_case "TC-16 out-of-root-dst-rejected" test_out_of_root_dst_rejected
run_case "TC-17 out-of-root-copy-rejected" test_out_of_root_copy_rejected
run_case "TC-18 dot-dot-traversal-rejected" test_dot_dot_traversal_rejected
run_case "TC-19 hooks-failure-preserves-manifest" test_hooks_failure_preserves_manifest
run_case "TC-20 multi-line-manifest-parsed" test_multi_line_manifest_parsed
run_case "TC-20b receipt-special-path-round-trip" test_receipt_special_path_round_trip
run_case "TC-20c malformed-receipt-fails-before-mutation" test_malformed_receipt_fails_before_mutation
run_case "TC-20d selected-hosts-pretty-json" test_selected_hosts_pretty_json
run_case "TC-20e duplicate-receipt-destination-fails-closed" test_duplicate_receipt_destination_fails_closed
run_case "TC-20f nul-receipt-field-fails-closed" test_nul_receipt_field_fails_closed
run_case "TC-20g explicit-codex-malformed-receipt-precedes-host-mutation" test_explicit_codex_malformed_receipt_precedes_host_mutation
run_case "TC-20h explicit-codex-unknown-version-precedes-host-mutation" test_explicit_codex_unknown_version_precedes_host_mutation
run_case "TC-21 symlink-parent-traversal-rejected" test_symlink_parent_traversal_rejected
run_case "TC-22 symlink-parent-no-realpath-rejected" test_symlink_parent_no_realpath_rejected
run_case "TC-23 claude-home-symlink" test_claude_home_symlink
run_case "TC-24 pmctl-symlink-removed" test_pmctl_symlink_removed
run_case "TC-24b pmctl-manifest-duplicate-converges" test_pmctl_manifest_duplicate_converges
run_case "TC-25 pmctl-foreign-symlink-preserved" test_pmctl_foreign_symlink_preserved
run_case "TC-26 pmctl-real-file-preserved" test_pmctl_real_file_preserved
run_case "TC-27 prune-feedback" test_prune_feedback
run_case "TC-28 claude-home-dst-rejected" test_claude_home_dst_rejected
run_case "TC-29 missing-host-write-library-warns-and-preserves-hooks" test_missing_host_write_library_warns_and_preserves_hooks
run_case "TC-30 codex-uninstall-success-cleans-unchanged-target-scratch" test_codex_uninstall_success_cleans_unchanged_target_scratch

th_summary
