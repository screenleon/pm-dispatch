#!/usr/bin/env bash
# Unit tests for scripts/lib/portable.sh

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"

# --filter <pattern>  run only cases whose name contains <pattern>
# --list              print all case names and exit
FILTER=""
LIST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      FILTER="${2:-}"
      shift 2
      ;;
    --list)
      LIST=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

ALL_CASES=()
should_run() {
  if $LIST; then
    ALL_CASES+=("$1")
    return 1
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

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

case_realpath_m_existing_abs() {
  local name="portable-realpath-m-existing-absolute-file"
  should_run "$name" || return 0
  local root="$tmp_root/realpath"
  local file="$root/existing/file.txt"
  mkdir -p "$root/existing"
  printf 'ok\n' > "$file"

  if [[ "$(realpath_m "$file")" == "$file" ]]; then
    pass "$name"
  else
    fail "$name" "unexpected path"
  fi
}

case_realpath_m_parent_dots() {
  local name="portable-realpath-m-abspath-with-dots"
  should_run "$name" || return 0
  local root="$tmp_root/dots"
  mkdir -p "$root/a"
  printf 'ok\n' > "$root/a/b.txt"
  local raw="$root/a/../a/b.txt"
  local got
  got="$(realpath_m "$raw")"
  if [[ "$got" == "$root/a/b.txt" ]]; then
    pass "$name"
  else
    fail "$name" "got $got"
  fi
}

case_realpath_m_nonexistent_leaf() {
  local name="portable-realpath-m-nonexistent-leaf"
  should_run "$name" || return 0
  local root="$tmp_root/nonexistent"
  mkdir -p "$root/parent"
  local got expected
  expected="$root/parent/new-file.txt"
  got="$(realpath_m "$expected")"
  if [[ "$got" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "got $got, expected $expected"
  fi
}

case_realpath_m_empty_fails() {
  local name="portable-realpath-m-empty-string"
  should_run "$name" || return 0
  if ! realpath_m "" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "empty input should fail"
  fi
}

case_safe_tmpdir() {
  local name="portable-safe-tmpdir-writable"
  should_run "$name" || return 0
  local dir
  dir="$(safe_tmpdir)"
  if [[ -n "$dir" && -d "$dir" && -w "$dir" ]]; then
    pass "$name"
  else
    fail "$name" "not writable/empty: $dir"
  fi
}

case_mkdir_lock_contention() {
  local name="portable-mkdir-lock-contention-timeout"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-contention"
  # FIFO/named-pipe handshake — pure event synchronization. The holder
  # subshell writes to the FIFO AFTER acquiring the lock; the foreground
  # blocks on `read` until that write happens. No `sleep` involved in the
  # readiness wait, so the test is independent of scheduler latency on
  # any platform (addresses CC-104g gate r1 critic+qa advise).
  local fifo="$tmp_root/lock-contention.ready"
  if ! mkfifo "$fifo" 2>/dev/null; then
    printf 'SKIP: %s (mkfifo unavailable on this platform)\n' "$name"
    return
  fi

  (
    if mkdir_lock "$lock" 2; then
      echo ok > "$fifo"
    else
      echo fail > "$fifo"
      exit 1
    fi
    sleep 1.2
    rmdir "$lock"
  ) &
  local holder_pid=$!

  local signal=""
  if ! IFS= read -r signal < "$fifo"; then
    kill "$holder_pid" 2>/dev/null || true
    rm -f "$fifo"
    fail "$name" "FIFO read failed waiting for holder readiness"
    return
  fi
  rm -f "$fifo"
  if [[ "$signal" != "ok" ]]; then
    kill "$holder_pid" 2>/dev/null || true
    fail "$name" "holder subshell failed to acquire lock (signal=$signal)"
    return
  fi

  if mkdir_lock "$lock" 1; then
    rmdir "$lock"
    kill "$holder_pid" 2>/dev/null || true
    fail "$name" "second lock attempt unexpectedly succeeded"
    return
  fi

  wait "$holder_pid" || true
  pass "$name"
}

case_mkdir_lock_release() {
  local name="portable-mkdir-lock-release"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-release"

  if ! mkdir_lock "$lock" 2; then
    fail "$name" "initial lock acquire failed"
    return
  fi
  rmdir "$lock"

  if mkdir_lock "$lock" 2; then
    rmdir "$lock"
    pass "$name"
  else
    fail "$name" "second lock acquire after release failed"
  fi
}

case_detect_platform_override_windows() {
  local name="portable-detect-platform-override-windows"
  should_run "$name" || return 0
  local got old_value old_set

  if [[ -n "${PM_DISPATCH_PLATFORM+x}" ]]; then
    old_set=1
    old_value="$PM_DISPATCH_PLATFORM"
  else
    old_set=0
  fi

  PM_DISPATCH_PLATFORM=windows
  got="$(detect_platform)"

  if [[ "$old_set" -eq 1 ]]; then
    PM_DISPATCH_PLATFORM="$old_value"
  else
    unset PM_DISPATCH_PLATFORM
  fi

  if [[ "$got" == "windows" ]]; then
    pass "$name"
  else
    fail "$name" "got $got"
  fi
}

case_detect_platform_host_native() {
  # Previously this test asserted `got == linux` regardless of host
  # platform, which made it a guaranteed FAIL on macOS and Windows. The
  # assertion is reframed: detect_platform must return SOME valid value
  # AND that value must agree with a direct OSTYPE/uname check.
  local name="portable-detect-platform-host-native"
  should_run "$name" || return 0
  local got
  local old_ostype
  local old_platform
  local old_set=0
  if [[ -n "${PM_DISPATCH_PLATFORM+x}" ]]; then
    old_set=1
    old_platform="$PM_DISPATCH_PLATFORM"
  fi
  if [[ -n "${OSTYPE+x}" ]]; then
    old_ostype="$OSTYPE"
  else
    old_ostype=""
  fi

  unset PM_DISPATCH_PLATFORM
  got="$(detect_platform)"

  if [[ "$old_set" -eq 1 ]]; then
    PM_DISPATCH_PLATFORM="$old_platform"
  fi
  if [[ -n "$old_ostype" ]]; then
    OSTYPE="$old_ostype"
  else
    unset OSTYPE
  fi

  # Derive the expected value independently using the same priority order
  # the shim uses (OSTYPE prefix, then uname fallback).
  local expected
  case "${OSTYPE:-}" in
    linux-gnu*) expected=linux ;;
    darwin*)    expected=macos ;;
    msys*|cygwin*|mingw*) expected=windows ;;
    *)
      case "$(uname -s 2>/dev/null)" in
        Linux*)  expected=linux ;;
        Darwin*) expected=macos ;;
        MINGW*|MSYS*|CYGWIN*) expected=windows ;;
        *) expected=unknown ;;
      esac
      ;;
  esac

  if [[ "$got" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "got '$got', expected '$expected' (OSTYPE=${OSTYPE:-unset}, uname=$(uname -s 2>/dev/null || echo unknown))"
  fi
}

case_detect_platform_ostype_msys() {
  local name="portable-detect-platform-ostype-msys"
  should_run "$name" || return 0
  local got old_platform old_set old_ostype
  if [[ -n "${PM_DISPATCH_PLATFORM+x}" ]]; then
    old_set=1
    old_platform="$PM_DISPATCH_PLATFORM"
  else
    old_set=0
  fi
  if [[ -n "${OSTYPE+x}" ]]; then
    old_ostype="$OSTYPE"
  else
    old_ostype=""
  fi

  unset PM_DISPATCH_PLATFORM
  OSTYPE=msys
  got="$(detect_platform)"

  if [[ "$old_set" -eq 1 ]]; then
    PM_DISPATCH_PLATFORM="$old_platform"
  fi
  if [[ -n "$old_ostype" ]]; then
    OSTYPE="$old_ostype"
  else
    unset OSTYPE
  fi

  if [[ "$got" == "windows" ]]; then
    pass "$name"
  else
    fail "$name" "got $got"
  fi
}

case_realpath_m_symlink_resolves() {
  local name="portable-realpath-m-symlink-resolves"
  should_run "$name" || return 0
  local root="$tmp_root/sym"
  mkdir -p "$root/target"
  printf 'ok\n' > "$root/target/file.txt"
  ln -s "$root/target" "$root/link"
  # Skip when ln -s did not actually create a symlink (Git Bash on Windows
  # without `MSYS=winsymlinks:nativestrict` + Developer Mode falls back to
  # copying the directory). The shim's symlink semantics are still tested
  # natively on Linux/macOS/WSL CI; on Windows the precondition fails.
  if [[ ! -L "$root/link" ]]; then
    printf 'SKIP: %s (ln -s did not create a symlink on this platform)\n' "$name"
    return
  fi
  local got
  got="$(realpath_m "$root/link/file.txt")"
  if [[ "$got" == "$root/target/file.txt" ]]; then
    pass "$name"
  else
    fail "$name" "got $got"
  fi
}

case_realpath_m_windows_mode_normalizes() {
  # Forces the pure-bash code path by simulating windows platform.
  local name="portable-realpath-m-windows-mode-collapses-dots"
  should_run "$name" || return 0
  local root="$tmp_root/winmode"
  mkdir -p "$root/a/b"
  printf 'ok\n' > "$root/a/b/file.txt"
  local raw="$root/a/./b/../b/file.txt"
  local got
  got="$(PM_DISPATCH_PLATFORM=windows realpath_m "$raw")"
  if [[ "$got" == "$root/a/b/file.txt" ]]; then
    pass "$name"
  else
    fail "$name" "got $got"
  fi
}

case_realpath_m_windows_mode_relative_path() {
  # Relative input under windows simulation should resolve against PWD.
  local name="portable-realpath-m-windows-mode-relative-uses-pwd"
  should_run "$name" || return 0
  local root="$tmp_root/winrel"
  mkdir -p "$root/sub"
  printf 'ok\n' > "$root/sub/f.txt"
  local got
  got="$(cd "$root" && PM_DISPATCH_PLATFORM=windows realpath_m "sub/f.txt")"
  if [[ "$got" == "$root/sub/f.txt" ]]; then
    pass "$name"
  else
    fail "$name" "got $got"
  fi
}

case_file_size_bytes_returns_size() {
  local name="portable-file-size-bytes-returns-size"
  should_run "$name" || return 0
  local root="$tmp_root/fsize"
  mkdir -p "$root"
  local f="$root/probe.bin"
  printf 'hello\n' > "$f"   # 6 bytes
  local got
  got="$(file_size_bytes "$f")"
  if [[ "$got" == "6" ]]; then
    pass "$name"
  else
    fail "$name" "expected 6 got '$got'"
  fi
}

case_file_size_bytes_missing_file() {
  local name="portable-file-size-bytes-missing-file-returns-nonzero"
  should_run "$name" || return 0
  local f="$tmp_root/does-not-exist-$$.bin"
  if file_size_bytes "$f" >/dev/null 2>&1; then
    fail "$name" "expected non-zero exit for missing file"
  else
    pass "$name"
  fi
}

case_link_or_copy_symlink_success() {
  local name="link-or-copy-symlink-success"
  should_run "$name" || return 0

  local old_home="$HOME"
  local root="$tmp_root/link-or-copy-symlink-success"
  local src="$root/src.txt"
  local dst="$root/dst.txt"
  local manifest_home="$tmp_root/link-or-copy-symlink-success-home"
  local manifest
  local src_abs dst_abs
  local code
  local out
  local out_file
  local old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  local old_bogus="${FAKE_SYMLINK_BOGUS-0}"

  rm -rf "$tmp_root/link-or-copy-symlink-success-home"
  HOME="$manifest_home"
  mkdir -p "$HOME/.claude/.pm-dispatch"
  mkdir -p "$root"
  printf 'ok\n' > "$src"

  set +e
  out_file="$root/link-or-copy.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code=$?
  set -e
  out="$(cat "$out_file")"

  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  FAKE_SYMLINK_BOGUS="$old_bogus"
  manifest="$manifest_home/.claude/.pm-dispatch/install-manifest.json"
  HOME="$old_home"

  if [[ "$code" -ne 0 ]]; then
    fail "$name" "rc=$code (want 0)"
    return
  fi
  if ! [[ -L "$dst" ]]; then
    fail "$name" "$dst is not a symlink"
    return
  fi
  manifest_flush "$manifest" "$REPO_ROOT" >/dev/null
  if ! grep -q '\"src\"' "$manifest" >/dev/null 2>&1; then
    fail "$name" "manifest has no entries"
    return
  fi
  src_abs="$(realpath_m "$src")"
  dst_abs="$(cd "$(dirname "$dst")" && pwd -P)/$(basename "$dst")"
  if ! grep -Fq "\"src\":\"$src_abs\"" "$manifest"; then
    fail "$name" "manifest missing src entry $src_abs"
    return
  fi
  if ! grep -Fq "\"dst\":\"$dst_abs\"" "$manifest"; then
    fail "$name" "manifest missing dst entry $dst_abs"
    return
  fi
  if ! grep -Fq '"mode":"symlink"' "$manifest"; then
    fail "$name" "manifest entry mode is not symlink"
    return
  fi
  if grep -q '"sha256"' "$manifest"; then
    fail "$name" "symlink-mode entry contains sha256"
    return
  fi
  if grep -q '"fallback_reason"' "$manifest"; then
    fail "$name" "symlink-mode entry contains fallback_reason"
    return
  fi
  pass "$name"
}

case_link_or_copy_post_check_reject() {
  local name="link-or-copy-post-check-reject"
  should_run "$name" || return 0

  local old_home="$HOME"
  local root="$tmp_root/link-or-copy-post-check-reject"
  local src="$root/src.txt"
  local dst="$root/dst.txt"
  local manifest_home="$tmp_root/link-or-copy-post-check-reject-home"
  local manifest
  local src_abs dst_abs
  local code
  local out
  local out_file
  local old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  local old_bogus="${FAKE_SYMLINK_BOGUS-0}"

  rm -rf "$tmp_root/link-or-copy-post-check-reject-home"
  HOME="$manifest_home"
  mkdir -p "$HOME/.claude/.pm-dispatch"
  mkdir -p "$root"
  printf 'ok\n' > "$src"
  FAKE_SYMLINK_BOGUS=1

  set +e
  out_file="$root/link-or-copy.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code=$?
  set -e
  out="$(cat "$out_file")"

  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  FAKE_SYMLINK_BOGUS="$old_bogus"
  manifest="$manifest_home/.claude/.pm-dispatch/install-manifest.json"
  HOME="$old_home"

  if [[ "$code" -ne 1 ]]; then
    fail "$name" "rc=$code (want 1)"
    return
  fi
  if [[ -L "$dst" ]]; then
    fail "$name" "$dst is still a symlink"
    return
  fi
  if ! grep -q 'symlink post-check failed' <<< "$out"; then
    fail "$name" "no post-check fallback warning"
    return
  fi

  manifest_flush "$manifest" "$REPO_ROOT" >/dev/null
  if ! grep -Fq '"mode":"copy"' "$manifest"; then
    fail "$name" "manifest entry mode is not copy"
    return
  fi
  if ! grep -Fq '"sha256":"' "$manifest" || ! grep -Eq '\"sha256\":\"[0-9a-f]{64}\"' "$manifest"; then
    fail "$name" "manifest copy entry missing valid sha256"
    return
  fi
  if ! grep -Fq '"fallback_reason":"symlink post-check failed"' "$manifest"; then
    fail "$name" "manifest copy entry fallback_reason incorrect"
    return
  fi
  if ! [[ -f "$dst" ]]; then
    fail "$name" "$dst not copied"
    return
  fi
  src_abs="$(realpath_m "$src")"
  dst_abs="$(cd "$(dirname "$dst")" && pwd -P)/$(basename "$dst")"
  if ! grep -Fq "\"src\":\"$src_abs\"" "$manifest" || ! grep -Fq "\"dst\":\"$dst_abs\"" "$manifest"; then
    fail "$name" "manifest copy entry lacks src/dst"
    return
  fi
  pass "$name"
}

case_link_or_copy_copy_fallback() {
  local name="link-or-copy-copy-fallback"
  should_run "$name" || return 0

  local old_home="$HOME"
  local root="$tmp_root/link-or-copy-copy-fallback"
  local src="$root/src.txt"
  local dst="$root/dst.txt"
  local manifest_home="$tmp_root/link-or-copy-copy-fallback-home"
  local manifest
  local src_abs dst_abs
  local code
  local out
  local out_file
  local old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  local old_bogus="${FAKE_SYMLINK_BOGUS-0}"

  rm -rf "$tmp_root/link-or-copy-copy-fallback-home"
  HOME="$manifest_home"
  mkdir -p "$HOME/.claude/.pm-dispatch"
  mkdir -p "$root"
  printf 'ok\n' > "$src"
  FAKE_SYMLINK_UNSUPPORTED=1

  set +e
  out_file="$root/link-or-copy.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code=$?
  set -e
  out="$(cat "$out_file")"

  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  FAKE_SYMLINK_BOGUS="$old_bogus"
  manifest="$manifest_home/.claude/.pm-dispatch/install-manifest.json"
  HOME="$old_home"

  if [[ "$code" -ne 1 ]]; then
    fail "$name" "rc=$code (want 1)"
    return
  fi
  if [[ -L "$dst" ]]; then
    fail "$name" "$dst is still a symlink"
    return
  fi
  if ! grep -q 'symlink unsupported on host' <<< "$out"; then
    fail "$name" "no unsupported fallback warning"
    return
  fi

  manifest_flush "$manifest" "$REPO_ROOT" >/dev/null
  if ! grep -Fq '"mode":"copy"' "$manifest"; then
    fail "$name" "manifest entry mode is not copy"
    return
  fi
  if ! grep -Fq '"sha256":"' "$manifest" || ! grep -Eq '\"sha256\":\"[0-9a-f]{64}\"' "$manifest"; then
    fail "$name" "manifest copy entry missing valid sha256"
    return
  fi
  if ! grep -Fq '"fallback_reason":"symlink unsupported on host"' "$manifest"; then
    fail "$name" "manifest copy entry fallback_reason incorrect"
    return
  fi
  if ! [[ -f "$dst" ]]; then
    fail "$name" "$dst not copied"
    return
  fi
  src_abs="$(realpath_m "$src")"
  dst_abs="$(cd "$(dirname "$dst")" && pwd -P)/$(basename "$dst")"
  if ! grep -Fq "\"src\":\"$src_abs\"" "$manifest" || ! grep -Fq "\"dst\":\"$dst_abs\"" "$manifest"; then
    fail "$name" "manifest copy entry lacks src/dst"
    return
  fi
  pass "$name"
}

case_realpath_m_existing_abs
case_realpath_m_parent_dots
case_realpath_m_nonexistent_leaf
case_realpath_m_empty_fails
case_realpath_m_symlink_resolves
case_realpath_m_windows_mode_normalizes
case_realpath_m_windows_mode_relative_path
case_safe_tmpdir
case_mkdir_lock_contention
case_mkdir_lock_release
case_detect_platform_override_windows
case_detect_platform_host_native
case_detect_platform_ostype_msys
case_file_size_bytes_returns_size
case_file_size_bytes_missing_file
case_link_or_copy_symlink_success
case_link_or_copy_post_check_reject
case_link_or_copy_copy_fallback

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
