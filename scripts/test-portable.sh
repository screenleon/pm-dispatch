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

_slw_write_basic() {
  printf 'serialize ok\n' > "$1"
}

_slw_return_42() {
  return 42
}

_slw_write_fallback() {
  printf 'fallback ok\n' > "$1"
}

# Behavior: serialize_with_lock runs the wrapped function and applies its file side-effects.
# Steps: 1. Call serialize_with_lock with a helper that writes to a temp file; 2. Assert rc=0; 3. Assert temp file contains the expected string.
case_serialize_with_lock_basic() {
  local name="portable-serialize-with-lock-runs-fn"
  should_run "$name" || return 0
  local out="$tmp_root/slw-basic.out"

  if ! serialize_with_lock "$tmp_root/slw-basic" _slw_write_basic "$out"; then
    fail "$name" "serialize_with_lock returned non-zero"
    return
  fi
  if [[ "$(cat "$out" 2>/dev/null)" == "serialize ok" ]]; then
    pass "$name"
  else
    fail "$name" "helper output mismatch"
  fi
}

# Behavior: serialize_with_lock propagates the wrapped function's non-zero exit code on both flock and mkdir-fallback paths.
# Steps: 1. Call serialize_with_lock with a helper returning 42 (flock path); 2. Repeat with FAKE_FLOCK_MISSING=1 (mkdir path); 3. Assert both results equal 42.
case_serialize_with_lock_propagates_rc() {
  local name="portable-serialize-with-lock-propagates-rc"
  should_run "$name" || return 0
  local rc_default rc_fallback old_fake old_set

  if [[ -n "${FAKE_FLOCK_MISSING+x}" ]]; then
    old_set=1
    old_fake="$FAKE_FLOCK_MISSING"
  else
    old_set=0
  fi

  set +e
  serialize_with_lock "$tmp_root/slw-rc-default" _slw_return_42
  rc_default=$?
  FAKE_FLOCK_MISSING=1 serialize_with_lock "$tmp_root/slw-rc-fallback" _slw_return_42
  rc_fallback=$?
  set -e

  if [[ "$old_set" -eq 1 ]]; then
    FAKE_FLOCK_MISSING="$old_fake"
  else
    unset FAKE_FLOCK_MISSING
  fi

  if [[ -d "${tmp_root}/slw-rc-fallback.lockdir" ]]; then
    fail "$name" "mkdir fallback lockdir not removed after non-zero fn exit"
    return
  fi

  if [[ "$rc_default" -eq 42 && "$rc_fallback" -eq 42 ]]; then
    pass "$name"
  else
    fail "$name" "expected rc 42 in both paths, got default=$rc_default fallback=$rc_fallback"
  fi
}

# Behavior: When FAKE_FLOCK_MISSING=1, serialize_with_lock uses the mkdir-fallback path and cleans up the lockdir on success.
# Steps: 1. Set FAKE_FLOCK_MISSING=1 and call serialize_with_lock with a file-writing helper; 2. Assert rc=0 and file content correct; 3. Assert lockdir is removed after the call.
case_serialize_with_lock_fallback() {
  local name="portable-serialize-with-lock-mkdir-fallback"
  should_run "$name" || return 0
  local out="$tmp_root/slw-fallback.out"
  local old_fake old_set

  if [[ -n "${FAKE_FLOCK_MISSING+x}" ]]; then
    old_set=1
    old_fake="$FAKE_FLOCK_MISSING"
  else
    old_set=0
  fi

  FAKE_FLOCK_MISSING=1
  if ! serialize_with_lock "$tmp_root/slw-fallback" _slw_write_fallback "$out"; then
    if [[ "$old_set" -eq 1 ]]; then
      FAKE_FLOCK_MISSING="$old_fake"
    else
      unset FAKE_FLOCK_MISSING
    fi
    fail "$name" "serialize_with_lock fallback returned non-zero"
    return
  fi

  if [[ "$old_set" -eq 1 ]]; then
    FAKE_FLOCK_MISSING="$old_fake"
  else
    unset FAKE_FLOCK_MISSING
  fi

  if [[ "$(cat "$out" 2>/dev/null)" != "fallback ok" ]]; then
    fail "$name" "helper output mismatch"
    return
  fi
  if [[ -e "$tmp_root/slw-fallback.lockdir" ]]; then
    fail "$name" "fallback lockdir was not cleaned up"
    return
  fi
  pass "$name"
}

# Behavior: serialize_with_lock returns non-zero when the lock parent directory does not exist.
# Steps:
#   1. Choose a lockbase whose parent directory does not exist.
#   2. Call serialize_with_lock with a no-op helper; assert rc != 0 and helper was not called.
#   3. Repeat with FAKE_FLOCK_MISSING=1 (mkdir fallback path).
case_serialize_with_lock_missing_parent() {
  local name="portable-serialize-with-lock-missing-parent"
  should_run "$name" || return 0
  local absent_lockbase="$tmp_root/nonexistent-dir/slw-lock"
  local fn_called_file="$tmp_root/slw-parent-fn-called"

  _slw_parent_probe() { touch "$fn_called_file"; }

  # Test flock path
  local rc=0
  serialize_with_lock "$absent_lockbase" _slw_parent_probe || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    fail "$name" "expected non-zero rc when parent dir absent (flock path), got 0"
    return
  fi
  if [[ -f "$fn_called_file" ]]; then
    fail "$name" "helper fn was called despite missing lock parent (flock path)"
    return
  fi

  # Test mkdir fallback path
  local old_fake old_set
  if [[ -n "${FAKE_FLOCK_MISSING+x}" ]]; then old_set=1; old_fake="$FAKE_FLOCK_MISSING"; else old_set=0; fi
  FAKE_FLOCK_MISSING=1
  rc=0
  serialize_with_lock "$absent_lockbase" _slw_parent_probe || rc=$?
  if [[ "$old_set" -eq 1 ]]; then FAKE_FLOCK_MISSING="$old_fake"; else unset FAKE_FLOCK_MISSING; fi

  if [[ "$rc" -eq 0 ]]; then
    fail "$name" "expected non-zero rc when parent dir absent (mkdir fallback), got 0"
    return
  fi
  if [[ -f "$fn_called_file" ]]; then
    fail "$name" "helper fn was called despite missing lock parent (mkdir fallback)"
    return
  fi

  pass "$name"
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

case_link_or_copy_dst_is_real_dir() {
  local name="link-or-copy-dst-is-real-dir"
  should_run "$name" || return 0
  # Behavior: link_or_copy returns 2 (CONFLICT) when dst is a pre-existing unmanaged real directory.
  # Steps: mkdir dst; call link_or_copy; assert rc=2, CONFLICT message, dst unchanged.

  local root="$tmp_root/link-or-copy-dst-is-real-dir"
  local src="$root/src.txt"
  local dst="$root/dst"
  local code
  local out
  local out_file

  mkdir -p "$dst"
  printf 'ok\n' > "$src"

  set +e
  out_file="$root/link-or-copy.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code=$?
  set -e
  out="$(cat "$out_file")"

  if [[ "$code" -ne 2 ]]; then
    fail "$name" "rc=$code (want 2)"
    return
  fi
  if ! grep -q 'CONFLICT' <<< "$out" || ! grep -q 'real directory' <<< "$out"; then
    fail "$name" "missing real-directory conflict message"
    return
  fi
  if ! [[ -d "$dst" && ! -L "$dst" ]]; then
    fail "$name" "$dst was replaced"
    return
  fi
  if [[ -e "$dst/$(basename "$src")" ]]; then
    fail "$name" "created entry inside real-directory dst"
    return
  fi
  pass "$name"
}

case_link_or_copy_copy_fallback_dir_idempotent() {
  local name="link-or-copy-copy-fallback-dir-idempotent"
  should_run "$name" || return 0
  # Behavior: second link_or_copy call for a manifest-managed copied directory returns 0 (ok).
  # Steps: first call with FAKE_SYMLINK_UNSUPPORTED=1 installs dir (rc=1); second call sees
  #        manifest entry, matches SHA, and returns 0 without CONFLICT.

  local old_home="$HOME"
  local root="$tmp_root/$name"
  local src_dir="$root/src_dir"
  local dst_dir="$root/dst_dir"
  local manifest_home="$tmp_root/$name-home"
  local manifest
  local code1 code2 out1 out2 out_file

  rm -rf "$manifest_home"
  HOME="$manifest_home"
  mkdir -p "$HOME/.claude/.pm-dispatch"
  mkdir -p "$src_dir"
  printf 'hello\n' > "$src_dir/file.txt"

  local old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  FAKE_SYMLINK_UNSUPPORTED=1

  # First install: copy fallback creates dst_dir (rc=1)
  set +e
  out_file="$root/first.out"
  link_or_copy "$src_dir" "$dst_dir" > "$out_file" 2>&1
  code1=$?
  set -e
  out1="$(cat "$out_file")"

  manifest="$manifest_home/.claude/.pm-dispatch/install-manifest.json"
  manifest_flush "$manifest" "$REPO_ROOT" >/dev/null
  _PORTABLE_MANIFEST_PREV_INITIALIZED=0

  # Second install: idempotent re-run (rc=0, "ok")
  set +e
  out_file="$root/second.out"
  link_or_copy "$src_dir" "$dst_dir" > "$out_file" 2>&1
  code2=$?
  set -e
  out2="$(cat "$out_file")"

  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  HOME="$old_home"

  if [[ "$code1" -ne 1 ]]; then
    fail "$name" "first install rc=$code1 (want 1)"
    return
  fi
  if [[ "$code2" -ne 0 ]]; then
    fail "$name" "second install rc=$code2 (want 0 — idempotent); out=$out2"
    return
  fi
  if [[ "$out2" != *"ok"* ]]; then
    fail "$name" "second install did not print 'ok'; out=$out2"
    return
  fi
  if ! [[ -d "$dst_dir" && ! -L "$dst_dir" ]]; then
    fail "$name" "dst_dir is not a real directory after idempotent re-run"
    return
  fi
  if ! [[ -f "$dst_dir/file.txt" ]]; then
    fail "$name" "dst_dir/file.txt missing after re-run"
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
case_serialize_with_lock_basic
case_serialize_with_lock_propagates_rc
case_serialize_with_lock_fallback
case_serialize_with_lock_missing_parent
case_detect_platform_override_windows
case_detect_platform_host_native
case_detect_platform_ostype_msys
case_file_size_bytes_returns_size
case_file_size_bytes_missing_file
case_link_or_copy_copy_refresh_stale() {
  local name="link-or-copy-copy-refresh-stale"
  should_run "$name" || return 0
  # Behavior: when src content changes after a copy-mode install, re-running link_or_copy
  #           detects dst_sha==prev_sha (dst unchanged) but src_sha!=dst_sha, then re-copies.
  # Steps:
  #   1. First install: FAKE_SYMLINK_UNSUPPORTED=1, src="v1" → dst copied, manifest records sha("v1")
  #   2. Modify src to "v2"
  #   3. Re-run link_or_copy → rc=1 (refresh), "refresh" in output, dst contains "v2"

  local old_home="$HOME"
  local old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  local root="$tmp_root/$name"
  local manifest_home="$tmp_root/$name-home"
  local src="$root/src.txt"
  local dst="$root/dst.txt"
  local manifest="$manifest_home/.claude/.pm-dispatch/install-manifest.json"
  local code1 code2 out2 out_file

  rm -rf "$root" "$manifest_home"
  mkdir -p "$root" "$manifest_home/.claude/.pm-dispatch"
  printf 'version one\n' > "$src"
  HOME="$manifest_home"
  FAKE_SYMLINK_UNSUPPORTED=1

  set +e
  out_file="$root/first.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code1=$?
  set -e

  manifest_flush "$manifest" "$REPO_ROOT" >/dev/null
  _PORTABLE_MANIFEST_PREV_INITIALIZED=0

  printf 'version two\n' > "$src"

  set +e
  out_file="$root/second.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code2=$?
  set -e
  out2="$(cat "$out_file")"

  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  HOME="$old_home"

  if [[ "$code1" -ne 1 ]]; then
    fail "$name" "first install rc=$code1 (want 1)"; return
  fi
  if [[ "$code2" -ne 1 ]]; then
    fail "$name" "refresh rc=$code2 (want 1); out=$out2"; return
  fi
  if [[ "$out2" != *"refresh"* ]]; then
    fail "$name" "output missing 'refresh'; out=$out2"; return
  fi
  local dst_content
  dst_content="$(cat "$dst")"
  if [[ "$dst_content" != "version two" ]]; then
    fail "$name" "dst has stale content: $dst_content"; return
  fi
  pass "$name"
}

case_link_or_copy_copy_no_refresh_when_up_to_date() {
  local name="link-or-copy-copy-no-refresh-when-up-to-date"
  should_run "$name" || return 0
  # Behavior: when src has not changed since copy-mode install, re-run returns 0 (ok).
  # Steps:
  #   1. First install: FAKE_SYMLINK_UNSUPPORTED=1 → dst copied
  #   2. Re-run without changing src → src_sha==dst_sha → rc=0, "ok"

  local old_home="$HOME"
  local old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  local root="$tmp_root/$name"
  local manifest_home="$tmp_root/$name-home"
  local src="$root/src.txt"
  local dst="$root/dst.txt"
  local manifest="$manifest_home/.claude/.pm-dispatch/install-manifest.json"
  local code1 code2 out2 out_file

  rm -rf "$root" "$manifest_home"
  mkdir -p "$root" "$manifest_home/.claude/.pm-dispatch"
  printf 'no change\n' > "$src"
  HOME="$manifest_home"
  FAKE_SYMLINK_UNSUPPORTED=1

  set +e
  out_file="$root/first.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code1=$?
  set -e

  manifest_flush "$manifest" "$REPO_ROOT" >/dev/null
  _PORTABLE_MANIFEST_PREV_INITIALIZED=0

  set +e
  out_file="$root/second.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code2=$?
  set -e
  out2="$(cat "$out_file")"

  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  HOME="$old_home"

  if [[ "$code1" -ne 1 ]]; then
    fail "$name" "first install rc=$code1 (want 1)"; return
  fi
  if [[ "$code2" -ne 0 ]]; then
    fail "$name" "re-run rc=$code2 (want 0 — up to date); out=$out2"; return
  fi
  if [[ "$out2" != *"ok"* ]]; then
    fail "$name" "expected 'ok' in output; out=$out2"; return
  fi
  pass "$name"
}

case_link_or_copy_copy_refresh_user_modified_conflict() {
  local name="link-or-copy-copy-refresh-user-modified-conflict"
  should_run "$name" || return 0
  # Behavior: when user modifies the installed copy (dst_sha != prev_sha), re-run returns 2 (CONFLICT).
  # Steps:
  #   1. First install: FAKE_SYMLINK_UNSUPPORTED=1 → dst copied, manifest records sha
  #   2. User overwrites dst with different content
  #   3. Re-run → dst_sha != prev_sha AND dst_sha != src_sha → rc=2, CONFLICT message

  local old_home="$HOME"
  local old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  local root="$tmp_root/$name"
  local manifest_home="$tmp_root/$name-home"
  local src="$root/src.txt"
  local dst="$root/dst.txt"
  local manifest="$manifest_home/.claude/.pm-dispatch/install-manifest.json"
  local code1 code2 out2 out_file

  rm -rf "$root" "$manifest_home"
  mkdir -p "$root" "$manifest_home/.claude/.pm-dispatch"
  printf 'original\n' > "$src"
  HOME="$manifest_home"
  FAKE_SYMLINK_UNSUPPORTED=1

  set +e
  out_file="$root/first.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code1=$?
  set -e

  manifest_flush "$manifest" "$REPO_ROOT" >/dev/null
  _PORTABLE_MANIFEST_PREV_INITIALIZED=0

  printf 'user modified\n' > "$dst"

  set +e
  out_file="$root/second.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code2=$?
  set -e
  out2="$(cat "$out_file")"

  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  HOME="$old_home"

  if [[ "$code1" -ne 1 ]]; then
    fail "$name" "first install rc=$code1 (want 1)"; return
  fi
  if [[ "$code2" -ne 2 ]]; then
    fail "$name" "re-run rc=$code2 (want 2 — CONFLICT); out=$out2"; return
  fi
  if [[ "$out2" != *"CONFLICT"* ]]; then
    fail "$name" "expected CONFLICT in output; out=$out2"; return
  fi
  pass "$name"
}

case_link_or_copy_symlink_success
case_link_or_copy_post_check_reject
case_link_or_copy_copy_fallback
case_link_or_copy_dst_is_real_dir
case_link_or_copy_copy_fallback_dir_idempotent
case_link_or_copy_copy_refresh_stale
case_link_or_copy_copy_no_refresh_when_up_to_date
case_link_or_copy_copy_refresh_user_modified_conflict

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
