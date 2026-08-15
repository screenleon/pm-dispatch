#!/usr/bin/env bash
# Unit tests for runtime/lib/portable.sh

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=runtime/lib/portable.sh
. "$REPO_ROOT/runtime/lib/portable.sh"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

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
  # Two-FIFO handshake — fully event-driven, no sleep on either side.
  # lock-contention.ready:   holder → foreground: lock acquired
  # lock-contention.release: foreground → holder: ok to unlock
  local fifo_ready="$tmp_root/lock-contention.ready"
  local fifo_release="$tmp_root/lock-contention.release"
  if ! mkfifo "$fifo_ready" 2>/dev/null || ! mkfifo "$fifo_release" 2>/dev/null; then
    printf 'SKIP: %s (mkfifo unavailable on this platform)\n' "$name"
    rm -f "$fifo_ready" "$fifo_release"
    return
  fi

  (
    if mkdir_lock "$lock" 2; then
      echo ok > "$fifo_ready"
      IFS= read -r _ < "$fifo_release" || true
      mkdir_unlock "$lock"
    else
      echo fail > "$fifo_ready"
      exit 1
    fi
  ) &
  local holder_pid=$!

  local signal=""
  if ! IFS= read -r signal < "$fifo_ready"; then
    kill "$holder_pid" 2>/dev/null || true
    rm -f "$fifo_ready" "$fifo_release"
    fail "$name" "FIFO read failed waiting for holder readiness"
    return
  fi
  rm -f "$fifo_ready"
  if [[ "$signal" != "ok" ]]; then
    kill "$holder_pid" 2>/dev/null || true
    rm -f "$fifo_release"
    fail "$name" "holder subshell failed to acquire lock (signal=$signal)"
    return
  fi

  if mkdir_lock "$lock" 1; then
    mkdir_unlock "$lock"
    printf '%s\n' done > "$fifo_release"
    rm -f "$fifo_release"
    wait "$holder_pid" || true
    fail "$name" "second lock attempt unexpectedly succeeded"
    return
  fi

  echo done > "$fifo_release"
  rm -f "$fifo_release"
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
  mkdir_unlock "$lock"

  if mkdir_lock "$lock" 2; then
    mkdir_unlock "$lock"
    pass "$name"
  else
    fail "$name" "second lock acquire after release failed"
  fi
}

case_mkdir_unlock_expected_owner_preserves_successor() {
  local name="portable-mkdir-unlock-expected-owner-preserves-successor"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-owner-fence" first_owner second_owner

  mkdir_lock "$lock" 2 || { fail "$name" "first acquire failed"; return; }
  first_owner="$(_portable_lock_read_owner "$lock")"
  mkdir_unlock "$lock" "$first_owner"
  mkdir_lock "$lock" 2 || { fail "$name" "second acquire failed"; return; }
  second_owner="$(_portable_lock_read_owner "$lock")"

  mkdir_unlock "$lock" "$first_owner"
  if [[ -d "$lock" && "$(_portable_lock_read_owner "$lock" 2>/dev/null || true)" == "$second_owner" ]]; then
    mkdir_unlock "$lock" "$second_owner"
    pass "$name"
  else
    fail "$name" "a delayed old-owner unlock removed or changed the successor"
  fi
}

case_mkdir_lock_owner_election_is_noclobber() {
  local name="portable-mkdir-lock-owner-election-is-noclobber"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-owner-election" first_owner second_owner second_status=0
  mkdir "$lock"
  _portable_lock_write_owner "$lock" || { fail "$name" "first owner claim failed"; return; }
  first_owner="$(_portable_lock_read_owner "$lock")"
  _portable_lock_write_owner "$lock" || second_status=$?
  second_owner="$(_portable_lock_read_owner "$lock")"
  rm -f "$lock/owner"
  rmdir "$lock"
  if [[ "$second_status" -ne 0 && "$second_owner" == "$first_owner" ]]; then
    pass "$name"
  else
    fail "$name" "second_status=$second_status first=$first_owner second=$second_owner"
  fi
}

case_mkdir_lock_writes_owner_metadata() {
  local name="portable-mkdir-lock-writes-owner-metadata"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-owner" owner pid host epoch nonce extra

  if ! mkdir_lock "$lock" 2; then
    fail "$name" "lock acquire failed"
    return
  fi
  owner="$(cat "$lock/owner" 2>/dev/null || true)"
  read -r pid host epoch nonce extra <<< "$owner"
  mkdir_unlock "$lock"

  if [[ "$pid" =~ ^[0-9]+$ && -n "$host" && "$epoch" =~ ^[0-9]+$ \
    && -n "$nonce" && -z "${extra:-}" ]]; then
    pass "$name"
  else
    fail "$name" "owner metadata malformed: ${owner:-empty}"
  fi
}

case_mkdir_lock_owner_is_background_holder() {
  local name="portable-mkdir-lock-owner-is-background-holder"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-background-owner"
  local ready="$tmp_root/lock-background-owner.ready"
  local release="$tmp_root/lock-background-owner.release"
  local holder_pid owner_pid host epoch nonce extra child rc=0
  mkfifo "$ready" "$release"

  (
    if ! mkdir_lock "$lock" 2; then
      printf 'acquire-failed\n' > "$ready"
      exit 1
    fi
    read -r owner_pid host epoch nonce extra < "$lock/owner"
    printf '%s %s %s %s %s\n' "$BASHPID" "$owner_pid" "$host" "$epoch" "$nonce" > "$ready"
    IFS= read -r _ < "$release" || true
    mkdir_unlock "$lock"
  ) &
  child=$!

  if ! read -r holder_pid owner_pid host epoch nonce extra < "$ready"; then
    rc=1
  fi
  printf 'release\n' > "$release" || rc=1
  wait "$child" || rc=1

  if [[ "$rc" -eq 0 && "$holder_pid" =~ ^[0-9]+$ && "$holder_pid" == "$owner_pid" \
        && -n "$host" && "$epoch" =~ ^[0-9]+$ && -n "$nonce" && -z "${extra:-}" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc holder=${holder_pid:-missing} owner=${owner_pid:-missing} metadata=${host:-missing}/${epoch:-missing}/${nonce:-missing}/${extra:-unexpected}"
  fi
}

case_mkdir_lock_reclaims_dead_same_host_owner() {
  local name="portable-mkdir-lock-reclaims-dead-same-host-owner"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-dead-owner" host now owner
  mkdir "$lock"
  host="$(_portable_lock_host)"
  now="$(_portable_lock_now)"
  printf '99999999 %s %s\n' "$host" "$now" > "$lock/owner"

  if ! mkdir_lock "$lock" 2; then
    fail "$name" "lock acquire did not reclaim dead owner"
    return
  fi
  owner="$(cat "$lock/owner" 2>/dev/null || true)"
  mkdir_unlock "$lock"
  if [[ "$owner" =~ ^[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]+[0-9]+[[:space:]]+[^[:space:]]+$ ]]; then
    pass "$name"
  else
    fail "$name" "new owner metadata missing after reclaim"
  fi
}

case_mkdir_lock_reclaims_age_ceiling_owner() {
  local name="portable-mkdir-lock-reclaims-owner-past-age-ceiling"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-old-owner" old_epoch
  mkdir "$lock"
  old_epoch="$(( $(_portable_lock_now) - 10 ))"
  printf '1 remote-host %s\n' "$old_epoch" > "$lock/owner"

  if PM_DISPATCH_LOCK_STALE_SECS=1 mkdir_lock "$lock" 2; then
    mkdir_unlock "$lock"
    pass "$name"
  else
    fail "$name" "lock acquire did not reclaim old owner"
  fi
}

case_mkdir_lock_does_not_steal_live_lock() {
  local name="portable-mkdir-lock-does-not-steal-live-lock"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-live-owner" rc=0
  if ! mkdir_lock "$lock" 2; then
    fail "$name" "initial lock acquire failed"
    return
  fi

  PM_DISPATCH_LOCK_STALE_SECS=999 mkdir_lock "$lock" 1 >/dev/null 2>&1 || rc=$?
  mkdir_unlock "$lock"
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "contended live lock was acquired"
  fi
}

case_mkdir_lock_live_owner_old_age_not_stolen() {
  # Behavior: a live, same-host owner is never reclaimed even when its lock age
  #   exceeds PM_DISPATCH_LOCK_STALE_SECS — liveness, not age, decides on-host.
  # Steps: 1. Pre-create the lockdir owned by our live pid with a far-past epoch;
  #   2. Attempt mkdir_lock with a 1s stale ceiling and short timeout;
  #   3. Assert acquisition fails (the live lock was not stolen by age).
  local name="portable-mkdir-lock-live-owner-old-age-not-stolen"
  should_run "$name" || return 0
  local lock="$tmp_root/lock-live-old" rc=0 host old_epoch
  mkdir "$lock" || { fail "$name" "setup mkdir failed"; return; }
  host="$(_portable_lock_host)"
  old_epoch="$(( $(_portable_lock_now) - 100000 ))"
  printf '%s %s %s\n' "$$" "$host" "$old_epoch" > "$lock/owner"

  PM_DISPATCH_LOCK_STALE_SECS=1 mkdir_lock "$lock" 1 >/dev/null 2>&1 || rc=$?
  mkdir_unlock "$lock"
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "live same-host owner with old age was stolen"
  fi
}

_slw_term_self() {
  kill -TERM "$BASHPID"
  sleep 2
}

case_serialize_with_lock_fallback_signal_cleanup() {
  # Behavior: the mkdir-fallback path releases its lockdir from the wrapped command's EXIT trap.
  # Steps: 1. Force the mkdir fallback; 2. Run a helper that terminates its subshell; 3. Assert rc is non-zero and the lockdir is gone.
  local name="portable-serialize-with-lock-mkdir-fallback-signal-cleanup"
  should_run "$name" || return 0
  local lockbase="$tmp_root/slw-signal" rc=0

  FAKE_FLOCK_MISSING=1 serialize_with_lock "$lockbase" _slw_term_self >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 && ! -e "$lockbase.lockdir" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc lockdir_exists=$([[ -e "$lockbase.lockdir" ]] && printf yes || printf no)"
  fi
}

case_mkdir_lock_unc_warning_nonfatal() {
  local name="portable-mkdir-lock-unc-looking-path-warns-nonfatal"
  should_run "$name" || return 0
  local lock="//${tmp_root#/}/lock-unc" rc=0 stderr_out
  unset _PORTABLE_LOCK_PREFLIGHT_WARNED

  stderr_out="$(mkdir_lock "$lock" 2 2>&1 >/dev/null)" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    mkdir_unlock "$lock"
  fi
  if [[ "$rc" -eq 0 && "$stderr_out" == *"warning: lock path may be on a network filesystem"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
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

_slw_report_owner_and_body() {
  local lockdir="$1" out_file="$2" owner_pid host epoch nonce extra
  read -r owner_pid host epoch nonce extra < "$lockdir/owner"
  printf '%s %s %s %s %s\n' "$BASHPID" "$owner_pid" "$host" "$epoch" "$nonce" > "$out_file"
}

_slw_hold_lock() {
  local ready_fifo="$1" release_fifo="$2"
  printf 'ready\n' > "$ready_fifo"
  IFS= read -r < "$release_fifo"
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

# Behavior: a contended flock reports its lock path and configured timeout instead of failing silently.
# Steps: signal when the holder acquires the lock; acquire it with a shorter timeout; release the holder; assert exit 1 and a diagnostic.
case_serialize_with_lock_contention_diagnostic() {
  local name="portable-serialize-with-lock-contention-diagnostic"
  should_run "$name" || return 0
  local lockbase="$tmp_root/slw-contention" err="$tmp_root/slw-contention.err" rc=0 holder
  local ready_fifo="$tmp_root/slw-contention-ready" release_fifo="$tmp_root/slw-contention-release"
  mkfifo "$ready_fifo" "$release_fifo"
  serialize_with_lock "$lockbase" _slw_hold_lock "$ready_fifo" "$release_fifo" >/dev/null 2>&1 &
  holder=$!
  IFS= read -r < "$ready_fifo"
  PM_DISPATCH_LOCK_TIMEOUT_SECS=1 serialize_with_lock "$lockbase" _slw_write_basic "$tmp_root/should-not-write" \
    >/dev/null 2>"$err" || rc=$?
  printf 'release\n' > "$release_fifo"
  wait "$holder" || true
  if [[ "$rc" -eq 1 && "$(<"$err")" == *"timed out after 1s acquiring $lockbase.lock"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=$(<"$err")"
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

case_serialize_with_lock_fallback_owner_is_body() {
  local name="portable-serialize-with-lock-mkdir-owner-is-critical-body"
  should_run "$name" || return 0
  local lockbase="$tmp_root/slw-owner-body" out_file="$tmp_root/slw-owner-body.out"
  local body_pid owner_pid host epoch nonce extra
  FAKE_FLOCK_MISSING=1 serialize_with_lock "$lockbase" \
    _slw_report_owner_and_body "$lockbase.lockdir" "$out_file" \
    || { fail "$name" "fallback call failed"; return; }
  read -r body_pid owner_pid host epoch nonce extra < "$out_file"
  if [[ "$body_pid" =~ ^[0-9]+$ && "$body_pid" == "$owner_pid" \
    && -n "$host" && "$epoch" =~ ^[0-9]+$ && -n "$nonce" \
    && -z "${extra:-}" && ! -e "$lockbase.lockdir" ]]; then
    pass "$name"
  else
    fail "$name" "body=${body_pid:-missing} owner=${owner_pid:-missing} metadata=${host:-missing}/${epoch:-missing}/${nonce:-missing}/${extra:-unexpected}"
  fi
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

case_codex_available_true_when_stub_present() {
  local name="portable-codex-available-true-when-stub-present"
  should_run "$name" || return 0
  local old_path="$PATH"
  local stub_dir="$tmp_root/codex-stub-available"
  mkdir -p "$stub_dir"
  printf '#!/usr/bin/env sh\nprintf "codex-stub\\n"\n' > "$stub_dir/codex"
  chmod +x "$stub_dir/codex"

  PATH="$stub_dir:$old_path"
  if codex_available; then
    pass "$name"
  else
    fail "$name" "expected codex_available success when codex stub is on PATH"
  fi
  PATH="$old_path"
}

case_codex_available_false_without_stub() {
  local name="portable-codex-available-false-without-stub"
  should_run "$name" || return 0
  local old_path="$PATH"
  local no_codex_path="$tmp_root/empty-path"
  mkdir -p "$no_codex_path"

  PATH="$no_codex_path"
  if codex_available; then
    fail "$name" "expected codex_available failure when codex is absent from PATH"
  else
    pass "$name"
  fi
  PATH="$old_path"
}

case_detect_executor_profile_full_when_stub_present() {
  local name="portable-detect-executor-profile-full-when-stub-present"
  should_run "$name" || return 0
  local old_path="$PATH"
  local stub_dir="$tmp_root/detect-profile-stub"
  local got
  mkdir -p "$stub_dir"
  printf '#!/usr/bin/env sh\nprintf "codex-stub\\n"\n' > "$stub_dir/codex"
  chmod +x "$stub_dir/codex"

  PATH="$stub_dir:$old_path"
  got="$(detect_executor_profile)"
  PATH="$old_path"
  if [[ "$got" == "full" ]]; then
    pass "$name"
  else
    fail "$name" "expected profile 'full' got '$got'"
  fi
}

case_detect_executor_profile_minimal_without_stub() {
  local name="portable-detect-executor-profile-minimal-without-stub"
  should_run "$name" || return 0
  local old_path="$PATH"
  local no_codex_path="$tmp_root/empty-path-profile"
  local got
  mkdir -p "$no_codex_path"

  PATH="$no_codex_path"
  got="$(detect_executor_profile)"
  PATH="$old_path"
  if [[ "$got" == "minimal" ]]; then
    pass "$name"
  else
    fail "$name" "expected profile 'minimal' got '$got'"
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

# Behavior: link_or_copy rejects missing and special-file sources in dry-run and
# real modes without creating a destination or recording receipt state.
# Steps: Arrange a missing path and FIFO; Act by invoking both modes; Assert exit
# 3, no destination or symlink, and an empty pending manifest.
case_link_or_copy_missing_source_fails_closed() {
  local name="link-or-copy-missing-source-fails-closed"
  should_run "$name" || return 0
  local root="$tmp_root/$name" missing="$tmp_root/$name/missing.txt"
  local dry_dst="$tmp_root/$name/dry-dst.txt" real_dst="$tmp_root/$name/real-dst.txt"
  local special="$tmp_root/$name/source.fifo" out_file="$tmp_root/$name/out" rc dry_before
  mkdir -p "$root"
  dry_before="${DRY_RUN-0}"

  _PORTABLE_MANIFEST_RECORDS=()
  set +e
  DRY_RUN=1 link_or_copy "$missing" "$dry_dst" > "$out_file" 2>&1
  rc=$?
  set -e
  if [[ "$rc" -ne 3 || -e "$dry_dst" || -L "$dry_dst" \
      || "${#_PORTABLE_MANIFEST_RECORDS[@]}" -ne 0 ]]; then
    DRY_RUN="$dry_before"
    fail "$name" "dry-run missing source was not rejected cleanly (rc=$rc)"
    return
  fi

  set +e
  DRY_RUN=0 link_or_copy "$missing" "$real_dst" > "$out_file" 2>&1
  rc=$?
  set -e
  if [[ "$rc" -ne 3 || -e "$real_dst" || -L "$real_dst" \
      || "${#_PORTABLE_MANIFEST_RECORDS[@]}" -ne 0 ]]; then
    DRY_RUN="$dry_before"
    fail "$name" "real-run missing source created state (rc=$rc)"
    return
  fi

  if mkfifo "$special" 2>/dev/null; then
    set +e
    link_or_copy "$special" "$real_dst" > "$out_file" 2>&1
    rc=$?
    set -e
    if [[ "$rc" -ne 3 || -e "$real_dst" || -L "$real_dst" \
        || "${#_PORTABLE_MANIFEST_RECORDS[@]}" -ne 0 ]]; then
      DRY_RUN="$dry_before"
      fail "$name" "special-file source was not rejected (rc=$rc)"
      return
    fi
  fi

  DRY_RUN="$dry_before"
  pass "$name"
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
  if grep -q '"digest_scheme"' "$manifest"; then
    fail "$name" "symlink-mode entry contains digest_scheme"
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
  if ! grep -Fq '"digest_scheme":"file-v1"' "$manifest"; then
    fail "$name" "manifest copy entry missing file-v1 digest scheme"
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
  if ! grep -Fq '"digest_scheme":"file-v1"' "$manifest"; then
    fail "$name" "manifest copy entry missing file-v1 digest scheme"
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
case_mkdir_unlock_expected_owner_preserves_successor
case_mkdir_lock_owner_election_is_noclobber
case_mkdir_lock_writes_owner_metadata
case_mkdir_lock_owner_is_background_holder
case_mkdir_lock_reclaims_dead_same_host_owner
case_mkdir_lock_reclaims_age_ceiling_owner
case_mkdir_lock_does_not_steal_live_lock
case_mkdir_lock_live_owner_old_age_not_stolen
case_serialize_with_lock_basic
case_serialize_with_lock_propagates_rc
case_serialize_with_lock_contention_diagnostic
case_serialize_with_lock_fallback
case_serialize_with_lock_fallback_owner_is_body
case_serialize_with_lock_fallback_signal_cleanup
case_serialize_with_lock_missing_parent
case_mkdir_lock_unc_warning_nonfatal
case_detect_platform_override_windows
case_detect_platform_host_native
case_detect_platform_ostype_msys
case_codex_available_true_when_stub_present
case_codex_available_false_without_stub
case_detect_executor_profile_full_when_stub_present
case_detect_executor_profile_minimal_without_stub
case_file_size_bytes_returns_size
case_file_size_bytes_missing_file
case_link_or_copy_missing_source_fails_closed
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

case_link_or_copy_copy_refresh_dry_run() {
  local name="link-or-copy-copy-refresh-dry-run"
  should_run "$name" || return 0
  # Behavior: DRY_RUN=1 on a stale-copy path returns 0, prints "would refresh",
  #           and leaves dst unchanged.
  # Steps:
  #   1. First install (FAKE_SYMLINK_UNSUPPORTED=1) → dst copied with "v1"
  #   2. Modify src to "v2"
  #   3. Re-run with DRY_RUN=1 → rc=0, "would refresh" in output, dst still "v1"

  local old_home="$HOME"
  local old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  local old_dryrun="${DRY_RUN-0}"
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
  DRY_RUN=1

  set +e
  out_file="$root/second.out"
  link_or_copy "$src" "$dst" > "$out_file" 2>&1
  code2=$?
  set -e
  out2="$(cat "$out_file")"

  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  DRY_RUN="$old_dryrun"
  HOME="$old_home"

  if [[ "$code1" -ne 1 ]]; then
    fail "$name" "first install rc=$code1 (want 1)"; return
  fi
  if [[ "$code2" -ne 0 ]]; then
    fail "$name" "dry-run refresh rc=$code2 (want 0); out=$out2"; return
  fi
  if [[ "$out2" != *"would refresh"* ]]; then
    fail "$name" "output missing 'would refresh'; out=$out2"; return
  fi
  local dst_content
  dst_content="$(cat "$dst")"
  if [[ "$dst_content" != "version one" ]]; then
    fail "$name" "dry-run must not modify dst; got: $dst_content"; return
  fi
  pass "$name"
}

# Behavior: the receipt writer and canonical reader preserve special path bytes
# and let the exact recorded copy destination refresh.
# Steps: Arrange quoted, backslash, and newline-bearing paths in a receipt; Act by
# reloading and refreshing; Assert new bytes and exact source/destination values.
case_link_or_copy_receipt_json_round_trip() {
  local name="link-or-copy-receipt-json-special-path-round-trip"
  should_run "$name" || return 0
  local root="$tmp_root/$name" manifest="$tmp_root/$name/receipt.json"
  local src="$tmp_root/$name/"$'source "quoted" \\ path\nfile.txt'
  local dst="$tmp_root/$name/"$'dest "quoted" \\ path\nfile.txt'
  local out="$tmp_root/$name/out" old_sha rc old_unsupported
  mkdir -p "$root"
  printf 'old\n' > "$src"
  printf 'old\n' > "$dst"
  old_sha="$(_portable_sha256_path "$dst")"
  _PORTABLE_MANIFEST_RECORDS=()
  manifest_record "$src" "$dst" copy "$old_sha" "special path fixture" || {
    fail "$name" "could not serialize special-character receipt entry"; return; }
  manifest_flush "$manifest" "$REPO_ROOT" >/dev/null || {
    fail "$name" "could not flush special-character receipt"; return; }
  printf 'new\n' > "$src"

  PM_DISPATCH_MANIFEST_PATH="$manifest"
  _PORTABLE_MANIFEST_PREV_INITIALIZED=0
  _PORTABLE_MANIFEST_PREV_LOAD_STATUS=0
  _PORTABLE_MANIFEST_PREV_PATH=""
  _PORTABLE_MANIFEST_RECORDS=()
  old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  set +e
  FAKE_SYMLINK_UNSUPPORTED=1 link_or_copy "$src" "$dst" > "$out" 2>&1
  rc=$?
  set -e
  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  unset PM_DISPATCH_MANIFEST_PATH

  if [[ "$rc" -ne 1 || "$(<"$dst")" != new ]]; then
    fail "$name" "special-character receipt did not authorize its exact refresh (rc=$rc out=$(<"$out"))"
    return
  fi
  if [[ "${_PORTABLE_MANIFEST_PREV_SRCS[0]-}" != "$src" \
      || "${_PORTABLE_MANIFEST_PREV_DSTS[0]-}" != "$dst" ]]; then
    fail "$name" "canonical reader did not preserve the exact source/destination bytes"
    return
  fi
  pass "$name"
}

# Behavior: the canonical receipt reader fails closed with an actionable error
# when jq is unavailable.
# Steps: Arrange an isolated PATH without jq; Act by reading a receipt; Assert
# exit 2 and the jq-required diagnostic.
case_receipt_reader_requires_jq() {
  local name="install-receipt-reader-requires-jq"
  should_run "$name" || return 0
  local root="$tmp_root/$name" receipt="$tmp_root/$name/receipt.json" out rc
  mkdir -p "$root/empty-path"
  printf '{"entries":[]}\n' > "$receipt"
  set +e
  out="$(PATH="$root/empty-path" /bin/bash -c '
    . "$1"
    pm_dispatch_receipt_load_entries "$2"
  ' _ "$REPO_ROOT/runtime/lib/install-receipt.sh" "$receipt" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 2 || "$out" != *"jq is required"* ]]; then
    fail "$name" "missing jq did not fail closed with an actionable diagnostic (rc=$rc out=$out)"
    return
  fi
  pass "$name"
}

# Behavior: a well-formed receipt with string fields loads on jq 1.6, where
# contains(NUL) is true for every string and must not be used as the NUL check.
# Steps: load a normal symlink entry; assert rc 0 and the recorded src.
case_receipt_reader_accepts_plain_string_fields() {
  local name="install-receipt-reader-accepts-plain-string-fields"
  should_run "$name" || return 0
  local receipt="$tmp_root/$name/receipt.json" out rc
  mkdir -p "$tmp_root/$name"
  printf '%s\n' '{"manifest_version":1,"entries":[{"src":"/tmp/src","dst":"/tmp/dst","mode":"symlink"}]}' > "$receipt"
  set +e
  out="$(bash -c '
    . "$1"
    pm_dispatch_receipt_load "$2" || exit $?
    printf "%s\n" "${PM_DISPATCH_RECEIPT_ENTRY_SRCS[0]}"
  ' _ "$REPO_ROOT/runtime/lib/install-receipt.sh" "$receipt" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 || "$out" != "/tmp/src" ]]; then
    fail "$name" "plain string receipt failed (rc=$rc out=$out)"
    return
  fi
  pass "$name"
}

# Behavior: a JSON unicode NUL in a required string field is rejected with a
# NUL-specific diagnostic, not the generic "must be a string" type error.
# Steps: write a receipt whose src decodes to an embedded NUL; load it;
# assert exit 2, empty src array, and stderr names NUL.
case_receipt_reader_rejects_embedded_nul() {
  local name="install-receipt-reader-rejects-embedded-nul"
  should_run "$name" || return 0
  local receipt="$tmp_root/$name/receipt.json" out rc
  mkdir -p "$tmp_root/$name"
  jq -n '{manifest_version:1,entries:[{src:("pre\u0000post"),dst:"/tmp/dst",mode:"symlink"}]}' \
    > "$receipt"
  set +e
  out="$(bash -c '
    . "$1"
    pm_dispatch_receipt_load "$2" || exit $?
    printf "loaded:%s\n" "${PM_DISPATCH_RECEIPT_ENTRY_SRCS[0]-}"
  ' _ "$REPO_ROOT/runtime/lib/install-receipt.sh" "$receipt" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -eq 2 && "$out" == *"must not contain a NUL"* \
      && "$out" != *"loaded:"* && "$out" != *"must be a string"* ]]; then
    pass "$name"
  else
    fail "$name" "NUL src was not rejected with a NUL diagnostic (rc=$rc out=$out)"
  fi
}

# Behavior: an unsupported receipt schema cannot authorize or record a copy
# refresh and leaves the installed destination unchanged.
# Steps: Arrange a version-99 receipt with a changed source; Act via link_or_copy;
# Assert exit 3, old destination bytes, no records, and unsupported status.
case_receipt_unknown_version_denies_refresh() {
  local name="install-receipt-unknown-version-denies-refresh"
  should_run "$name" || return 0
  local root="$tmp_root/$name" src dst receipt out old_sha rc old_unsupported
  root="$tmp_root/$name"
  src="$root/src.txt"
  dst="$root/dst.txt"
  receipt="$root/receipt.json"
  out="$root/out"
  mkdir -p "$root"
  printf 'old\n' > "$src"
  printf 'old\n' > "$dst"
  old_sha="$(_portable_sha256_path "$dst")"
  jq -n --arg src "$src" --arg dst "$dst" --arg sha "$old_sha" '{
      manifest_version: 99,
      entries: [{src: $src, dst: $dst, mode: "copy", sha256: $sha,
        digest_scheme: "file-v1", fallback_reason: "unknown schema"}]
    }' > "$receipt"
  printf 'new\n' > "$src"

  PM_DISPATCH_MANIFEST_PATH="$receipt"
  _PORTABLE_MANIFEST_PREV_INITIALIZED=0
  _PORTABLE_MANIFEST_PREV_LOAD_STATUS=0
  _PORTABLE_MANIFEST_PREV_PATH=""
  _PORTABLE_MANIFEST_RECORDS=()
  old_unsupported="${FAKE_SYMLINK_UNSUPPORTED-0}"
  set +e
  FAKE_SYMLINK_UNSUPPORTED=1 link_or_copy "$src" "$dst" > "$out" 2>&1
  rc=$?
  set -e
  FAKE_SYMLINK_UNSUPPORTED="$old_unsupported"
  unset PM_DISPATCH_MANIFEST_PATH

  if [[ "$rc" -ne 3 || "$(<"$dst")" != old \
      || "${#_PORTABLE_MANIFEST_RECORDS[@]}" -ne 0 \
      || "$PM_DISPATCH_RECEIPT_MANIFEST_VERSION_STATUS" != unsupported ]]; then
    fail "$name" "unknown receipt schema authorized or recorded refresh state (rc=$rc)"
    return
  fi
  pass "$name"
}

case_portable_sha1_shasum_fallback() {
  local name="portable-sha1: shasum fallback produces 40-char hex digest"
  should_run "$name" || return 0

  # Build a fake bin directory that contains shasum (but not sha1sum).
  # FAKE_SHA1SUM_MISSING=1 prevents portable.sh from using the real sha1sum
  # even if it exists on PATH, so the shasum branch is exercised.
  local fake_bin
  fake_bin="$(mktemp -d)"
  # shasum shim that delegates to openssl so stdin is actually hashed.
  # FAKE_SHA1SUM_MISSING=1 blocks the direct sha1sum branch; this shim proves
  # the shasum branch passes stdin through rather than returning a fixed digest.
  # shasum shim: ignore -a 1 args (shasum-specific) and delegate stdin to openssl.
  printf '#!/bin/sh\nopenssl dgst -sha1 < /dev/stdin | awk '"'"'{print $NF}'"'"'\n' > "$fake_bin/shasum"
  chmod +x "$fake_bin/shasum"

  local result
  result="$(
    FAKE_SHA1SUM_MISSING=1 PATH="$fake_bin:$PATH" \
      bash -c ". '${REPO_ROOT}/runtime/lib/portable.sh'
               printf 'test-input\n' | _portable_sha1" 2>/dev/null
  )" || true
  rm -rf "$fake_bin"

  # SHA-1("test-input\n") = 19877dd23a7175600bf62729888d5cea95ccb85a.
  # An input-independent fake would return a different constant; wrong routing would
  # return the sha1sum-branch hash for a different input or empty.
  if [[ "$result" == "19877dd23a7175600bf62729888d5cea95ccb85a" ]]; then
    pass "$name"
  else
    fail "$name" "expected 19877dd23a7175600bf62729888d5cea95ccb85a, got '${result:-empty}'"
  fi
}

case_portable_sha1_both_missing() {
  local name="portable-sha1: both tools missing exits non-zero and warns"
  should_run "$name" || return 0

  local stderr_file rc
  stderr_file="$(mktemp)"
  FAKE_SHA1_MISSING=1 bash -c "
    . '${REPO_ROOT}/runtime/lib/portable.sh'
    printf 'test\n' | _portable_sha1
  " >/dev/null 2>"$stderr_file" && rc=0 || rc=$?
  local stderr_out
  stderr_out="$(cat "$stderr_file")"
  rm -f "$stderr_file"

  if [[ "$rc" -ne 0 ]] && [[ "$stderr_out" == *"neither sha1sum nor shasum"* ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero rc and warning; got rc=${rc} stderr='${stderr_out:-empty}'"
  fi
}

# Behavior: directory digests are creation/glob-order independent while changes
# to file content, executable mode, or empty-directory membership change the hash.
# Steps: Arrange equivalent trees in different orders; Act by hashing then
# mutating each logical attribute; Assert equality first and divergence after each change.
case_portable_directory_digest_is_canonical() {
  local name="portable-directory-digest-canonical-logical-tree"
  should_run "$name" || return 0
  local root="$tmp_root/$name" first second
  first="$root/first"
  second="$root/second"
  local newline_name=$'line\nbreak.txt' first_sha second_sha mutated_sha

  # Create the same logical tree in deliberately different filesystem orders.
  mkdir -p "$first/z-empty" "$first/a dir/nested"
  printf 'hidden\n' > "$first/.hidden"
  printf 'payload\n' > "$first/a dir/nested/$newline_name"
  printf '#!/bin/sh\nexit 0\n' > "$first/tool.sh"
  chmod +x "$first/tool.sh"

  mkdir -p "$second/a dir/nested" "$second/z-empty"
  printf '#!/bin/sh\nexit 0\n' > "$second/tool.sh"
  chmod +x "$second/tool.sh"
  printf 'payload\n' > "$second/a dir/nested/$newline_name"
  printf 'hidden\n' > "$second/.hidden"

  if ln -s 'a dir/nested' "$first/link" 2>/dev/null \
      && ln -s 'a dir/nested' "$second/link" 2>/dev/null \
      && [[ -L "$first/link" && -L "$second/link" ]]; then
    :
  else
    rm -f "$first/link" "$second/link"
  fi

  # Bash 5.3 lets callers override glob order with GLOBSORT; digesting must
  # neutralize it just like GLOBIGNORE and remain creation-order independent.
  first_sha="$(GLOBSORT=nosort _portable_sha256_path "$first")" || {
    fail "$name" "first tree digest failed"; return; }
  second_sha="$(GLOBSORT=nosort _portable_sha256_path "$second")" || {
    fail "$name" "second tree digest failed"; return; }
  if [[ "$first_sha" != "$second_sha" ]]; then
    fail "$name" "equivalent trees hashed differently"
    return
  fi

  printf 'changed\n' > "$second/a dir/nested/$newline_name"
  mutated_sha="$(_portable_sha256_path "$second")"
  if [[ "$mutated_sha" == "$first_sha" ]]; then
    fail "$name" "file-content mutation did not change digest"
    return
  fi
  printf 'payload\n' > "$second/a dir/nested/$newline_name"
  chmod -x "$second/tool.sh"
  mutated_sha="$(_portable_sha256_path "$second")"
  if [[ "$mutated_sha" == "$first_sha" ]]; then
    fail "$name" "executable-bit mutation did not change digest"
    return
  fi
  chmod +x "$second/tool.sh"
  mkdir "$second/new-empty"
  mutated_sha="$(_portable_sha256_path "$second")"
  if [[ "$mutated_sha" == "$first_sha" ]]; then
    fail "$name" "empty-directory mutation did not change digest"
    return
  fi

  pass "$name"
}

# Behavior: a verified tar-v0 directory receipt refreshes and migrates to the
# logical-tree digest, while mismatched or unverifiable legacy state is preserved.
# Steps: Arrange matching, mismatched, and unverifiable legacy receipts; Act by
# refreshing each; Assert migration for the match and preserved conflicts otherwise.
case_portable_legacy_directory_receipt_migration() {
  local name="portable-legacy-directory-receipt-migration"
  should_run "$name" || return 0
  local root="$tmp_root/$name" src dst manifest legacy_sha out out_file rc
  mkdir -p "$root"

  # An exact tar-v0 match proves the legacy copy untouched, so a changed source
  # may refresh it and the pending receipt migrates to logical-tree-v1.
  src="$root/hit-src"; dst="$root/hit-dst"; manifest="$root/hit.json"
  mkdir -p "$src" "$dst"
  printf 'old\n' > "$src/value"; cp -a "$src/." "$dst/"
  legacy_sha="$(_portable_sha256_tar_v0 "$dst")" || {
    fail "$name" "could not create legacy tar-v0 fixture"; return; }
  printf '{"manifest_version":1,"entries":[{"src":"%s","dst":"%s","mode":"copy","sha256":"%s","fallback_reason":"legacy"}]}\n' \
    "$(_portable_json_escape "$src")" "$(_portable_json_escape "$dst")" "$legacy_sha" > "$manifest"
  printf 'upstream\n' > "$src/value"
  PM_DISPATCH_MANIFEST_PATH="$manifest"
  _PORTABLE_MANIFEST_PREV_INITIALIZED=0
  _PORTABLE_MANIFEST_PREV_SRCS=(); _PORTABLE_MANIFEST_PREV_DSTS=()
  _PORTABLE_MANIFEST_PREV_MODES=(); _PORTABLE_MANIFEST_PREV_SHA256S=()
  _PORTABLE_MANIFEST_PREV_DIGEST_SCHEMES=(); _PORTABLE_MANIFEST_RECORDS=()
  out_file="$root/hit.out"
  set +e
  FAKE_SYMLINK_UNSUPPORTED=1 link_or_copy "$src" "$dst" > "$out_file" 2>&1; rc=$?
  set -e
  out="$(<"$out_file")"
  if [[ "$rc" -ne 1 || "$(<"$dst/value")" != upstream \
      || "${_PORTABLE_MANIFEST_RECORDS[*]}" != *'"digest_scheme":"logical-tree-v1"'* ]]; then
    fail "$name" "legacy verified refresh did not migrate rc=$rc out=$out"
    return
  fi

  # A mismatched legacy digest is ambiguous and must preserve local bytes.
  src="$root/mismatch-src"; dst="$root/mismatch-dst"; manifest="$root/mismatch.json"
  mkdir -p "$src" "$dst"
  printf 'old\n' > "$src/value"; cp -a "$src/." "$dst/"
  legacy_sha="$(_portable_sha256_tar_v0 "$dst")"
  printf '{"manifest_version":1,"entries":[{"src":"%s","dst":"%s","mode":"copy","sha256":"%s","fallback_reason":"legacy"}]}\n' \
    "$(_portable_json_escape "$src")" "$(_portable_json_escape "$dst")" "$legacy_sha" > "$manifest"
  printf 'upstream\n' > "$src/value"; printf 'user-change\n' > "$dst/value"
  PM_DISPATCH_MANIFEST_PATH="$manifest"
  _PORTABLE_MANIFEST_PREV_INITIALIZED=0
  _PORTABLE_MANIFEST_PREV_SRCS=(); _PORTABLE_MANIFEST_PREV_DSTS=()
  _PORTABLE_MANIFEST_PREV_MODES=(); _PORTABLE_MANIFEST_PREV_SHA256S=()
  _PORTABLE_MANIFEST_PREV_DIGEST_SCHEMES=(); _PORTABLE_MANIFEST_RECORDS=()
  out_file="$root/mismatch.out"
  set +e
  FAKE_SYMLINK_UNSUPPORTED=1 link_or_copy "$src" "$dst" > "$out_file" 2>&1; rc=$?
  set -e
  out="$(<"$out_file")"
  if [[ "$rc" -ne 2 || "$(<"$dst/value")" != user-change || "$out" != *CONFLICT* ]]; then
    fail "$name" "legacy mismatch did not fail closed rc=$rc out=$out"
    return
  fi

  # Missing tar evidence is the same fail-closed case; it is never permission
  # to overwrite a legacy directory receipt.
  src="$root/no-tar-src"; dst="$root/no-tar-dst"; manifest="$root/no-tar.json"
  mkdir -p "$src" "$dst"
  printf 'old\n' > "$src/value"; cp -a "$src/." "$dst/"
  legacy_sha="$(_portable_sha256_tar_v0 "$dst")"
  printf '{"manifest_version":1,"entries":[{"src":"%s","dst":"%s","mode":"copy","sha256":"%s","fallback_reason":"legacy"}]}\n' \
    "$(_portable_json_escape "$src")" "$(_portable_json_escape "$dst")" "$legacy_sha" > "$manifest"
  printf 'upstream\n' > "$src/value"
  set +e
  out="$({
    PM_DISPATCH_MANIFEST_PATH="$manifest"
    _PORTABLE_MANIFEST_PREV_INITIALIZED=0
    _PORTABLE_MANIFEST_PREV_SRCS=(); _PORTABLE_MANIFEST_PREV_DSTS=()
    _PORTABLE_MANIFEST_PREV_MODES=(); _PORTABLE_MANIFEST_PREV_SHA256S=()
    _PORTABLE_MANIFEST_PREV_DIGEST_SCHEMES=(); _PORTABLE_MANIFEST_RECORDS=()
    # shellcheck disable=SC2317,SC2329  # link_or_copy invokes this test override indirectly.
    _portable_sha256_tar_v0() { return 1; }
    FAKE_SYMLINK_UNSUPPORTED=1 link_or_copy "$src" "$dst"
  } 2>&1)"; rc=$?
  set -e
  if [[ "$rc" -ne 2 || "$(<"$dst/value")" != old || "$out" != *CONFLICT* ]]; then
    fail "$name" "missing legacy verifier did not preserve copy rc=$rc out=$out"
    return
  fi

  unset PM_DISPATCH_MANIFEST_PATH
  pass "$name"
}

# Writes a cygpath shim mimicking `cygpath -m` (POSIX /c/x and drive forms ->
# mixed C:/x) into $1, so the MSYS-only branch of _portable_canonical_path can be
# exercised on a POSIX host. `command -v cygpath` resolves at call time, so a
# PATH prefix on the calling line is enough to activate it.
_write_fake_cygpath() {
  cat > "$1/cygpath" <<'CYG'
#!/usr/bin/env bash
p="${@: -1}"
case "$p" in
  /[A-Za-z]/*) printf '%s:/%s\n' "${p:1:1}" "${p:3}" ;;
  [A-Za-z]:/*) printf '%s\n' "$p" ;;
  *)           printf '%s\n' "$p" ;;
esac
CYG
  chmod +x "$1/cygpath"
}

case_portable_canonical_path() {
  local name="portable-canonical-path: POSIX no-op, drive-case fold, cygpath dialect collapse"
  should_run "$name" || return 0

  local posix dotseg drivecase stub c_slash drive_up drive_lo
  # cygpath is absent on this host, so a POSIX absolute path is returned unchanged
  # and dot segments collapse via _portable_normalize_path only.
  posix="$(_portable_canonical_path "/home/user/repo")"
  dotseg="$(_portable_canonical_path "/srv/app/./sub/../sub2")"
  # A bare drive letter is lowercased even without cygpath (case-insensitive on Windows).
  drivecase="$(_portable_canonical_path "C:/Users/First Last/repo")"

  # With a cygpath stub, the three Windows spellings of one location collapse.
  stub="$(mktemp -d)"
  _write_fake_cygpath "$stub"
  c_slash="$(PATH="$stub:$PATH" _portable_canonical_path "/c/Users/x")"
  drive_up="$(PATH="$stub:$PATH" _portable_canonical_path "C:/Users/x")"
  drive_lo="$(PATH="$stub:$PATH" _portable_canonical_path "c:/Users/x")"
  rm -rf "$stub"

  if [[ "$posix" == "/home/user/repo" \
        && "$dotseg" == "/srv/app/sub2" \
        && "$drivecase" == "c:/Users/First Last/repo" \
        && "$c_slash" == "c:/Users/x" \
        && "$drive_up" == "c:/Users/x" \
        && "$drive_lo" == "c:/Users/x" ]]; then
    pass "$name"
  else
    fail "$name" "posix=$posix dotseg=$dotseg drivecase=$drivecase c_slash=$c_slash drive_up=$drive_up drive_lo=$drive_lo"
  fi
}

# Behavior: importing a runtime library leaves the caller's execution context
# untouched.  Steps: source portable.sh under several strict-mode combinations
# and verify flags, cwd, traps, and the watched directory are unchanged.
case_portable_source_is_side_effect_free() {
  local name="portable/source-is-side-effect-free" watched
  should_run "$name" || return 0
  watched="$tmp_root/source-contract"
  mkdir -p "$watched"
  printf 'sentinel\n' > "$watched/sentinel"

  local mode
  for mode in none errexit nounset pipefail all; do
    if ! bash -c '
      mode="$1"; lib="$2"; watched="$3"
      case "$mode" in none) ;; errexit) set -e ;; nounset) set -u ;; pipefail) set -o pipefail ;; all) set -euo pipefail ;; esac
      trap "printf trapped >&2" USR1
      before_flags="$-"; before_pipefail="$(set -o | awk '\''$1 == "pipefail" { print $2 }'\'')"; before_cwd="$PWD"; before_trap="$(trap -p USR1)"; before_files="$(find "$watched" -mindepth 1 -printf "%P\\n" | sort)"
      . "$lib"
      after_pipefail="$(set -o | awk '\''$1 == "pipefail" { print $2 }'\'')"; after_trap="$(trap -p USR1)"; after_files="$(find "$watched" -mindepth 1 -printf "%P\\n" | sort)"
      [[ "$before_flags" == "$-" && "$before_pipefail" == "$after_pipefail" && "$before_cwd" == "$PWD" && "$before_trap" == "$after_trap" && "$before_files" == "$after_files" ]]
    ' _ "$mode" "$REPO_ROOT/runtime/lib/portable.sh" "$watched"; then
      fail "$name" "source contract failed under $mode"
      return
    fi
  done
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
case_link_or_copy_copy_refresh_dry_run
case_link_or_copy_receipt_json_round_trip
case_receipt_reader_requires_jq
case_receipt_reader_accepts_plain_string_fields
case_receipt_reader_rejects_embedded_nul
case_receipt_unknown_version_denies_refresh
case_portable_sha1_shasum_fallback
case_portable_sha1_both_missing
case_portable_directory_digest_is_canonical
case_portable_legacy_directory_receipt_migration
case_portable_canonical_path
case_portable_source_is_side_effect_free

th_summary
