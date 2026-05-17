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
  (
    mkdir_lock "$lock" 2 || exit 1
    sleep 1.2
    rmdir "$lock"
  ) &
  local holder_pid=$!
  sleep 0.1

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

case_detect_platform_host_linux() {
  local name="portable-detect-platform-host-linux"
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

  if [[ "$got" == "linux" ]]; then
    pass "$name"
  else
    fail "$name" "got $got"
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

case_realpath_m_existing_abs
case_realpath_m_parent_dots
case_realpath_m_nonexistent_leaf
case_realpath_m_empty_fails
case_safe_tmpdir
case_mkdir_lock_contention
case_mkdir_lock_release
case_detect_platform_override_windows
case_detect_platform_host_linux
case_detect_platform_ostype_msys

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
