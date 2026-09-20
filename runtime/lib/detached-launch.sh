#!/usr/bin/env bash
# detached-launch.sh — shared setsid/nohup + nonce-authenticated sentinel
# primitives (CC-434, spike CC-433 angle a1/a3).
#
# Extracted from the byte-identical portions of runtime/bin/gate-supervisor.sh /
# runtime/lib/pmctl-gate.sh and runtime/bin/dispatch-supervisor.sh /
# runtime/lib/pmctl-dispatch.sh. Owns ONLY the detach/sentinel mechanics that
# are provably identical across both callers:
#   - nonce generation, per-user key-dir management
#   - setsid/nohup process launch
#   - sentinel write (opaque key=value passthrough) / poll-for-existence
#
# Deliberately does NOT own:
#   - REPO_ROOT self-resolution (circular: the caller must resolve its own
#     root BEFORE it can source this file — see docs/spikes/CC-433.md angle a3)
#   - sentinel CONTENT semantics (which keys, how to parse/verify them) — that
#     stays with each caller (gate_result_verify vs dispatch_record)
#   - any dispatch-only security preflight (adapter/route/guard/brief checks)
#     — those never applied to the gate side and must not be introduced here
#
# Sourced by both runtime/bin/gate-supervisor.sh / runtime/bin/dispatch-supervisor.sh
# (after each resolves its own REPO_ROOT) and runtime/lib/pmctl-gate.sh /
# runtime/lib/pmctl-dispatch.sh. Do NOT set -euo pipefail here (callers carry
# their own flags).

_DL_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$_DL_SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && _DL_SCRIPT_DIR=.
# detect_platform (portable.sh) drives every Windows branch below (issue
# #606). Guarded source, same pattern state-writer.sh uses: this file may be
# sourced before or after portable.sh depending on the caller.
if ! declare -F detect_platform >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  . "$_DL_SCRIPT_DIR/portable.sh" 2>/dev/null || true
fi

# --- Windows-native process-group isolation (issue #606) ------------------
#
# Native Windows Git Bash has neither setsid nor /proc, so the POSIX
# functions below (detached_launch_under_setsid, _capture_identity,
# _verify_identity, _kill_process_group) each grow a `detect_platform ==
# windows` branch that delegates to runtime/lib/windows/detached-launch-job.ps1
# -- a Windows Job Object (JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE) based
# replacement for setsid+pgid isolation. See that script's own header for
# the full empirical findings (verified on a real Windows 11 host,
# 2026-09-20) this design is built on; the short version: a named Job Object
# does not survive its creator's handle closing, so the PowerShell launcher
# this repo spawns stays alive for the whole run and IS the unit later
# terminated to tear the tree down -- its own (translated) Windows pid is
# recorded as both pid= and pgid= in the identity file, with isolated=1
# unconditionally (Job Objects have no missing-setsid-style degraded mode).
#
# POSIX code paths below are UNCHANGED -- every Windows branch is additive,
# gated on detect_platform, and never alters what happens on Linux/macOS.

_dl_win_ps1_path() {
  printf '%s/windows/detached-launch-job.ps1' "$_DL_SCRIPT_DIR"
}

_dl_win_available() {
  command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1
}

# Real Windows pid of the CURRENT bash process. MSYS's own $$ (and $!, for a
# backgrounded native Windows exe) is an internal fake pid that no Win32 API
# recognizes -- confirmed by direct test: `tasklist /FI "PID eq $$"` finds
# nothing, while `ps -p $$`'s WINPID column holds the real value Get-Process/
# TerminateProcess/etc. actually operate on. This function is that
# translation, needed anywhere a bash-side pid must cross into a PowerShell
# call.
_dl_win_winpid_of() {
  local bash_view_pid="${1:?bash_view_pid required}"
  ps -p "$bash_view_pid" 2>/dev/null | awk 'NR==2{print $4}'
}

# The pid a script should use to identify ITSELF for later cancel/verify --
# i.e. what a caller like gate-supervisor.sh's _write_ready should pass to
# detached_launch_capture_identity when capturing its own identity to
# publish, instead of assuming plain $$ always means "my own pid" the way
# it does on POSIX.
#
# On POSIX this is exactly $$: the supervisor process launched under setsid
# IS the group leader that cancel later signals, so its own pid is already
# the correct value. On Windows it is NOT $$ -- MSYS's $$ is an internal
# fake pid no Win32 API recognizes, and in any case the unit a later kill
# actually targets is the PowerShell Job Object launcher (see this file's
# Windows section header), not the bash.exe supervisor process running this
# code. detached_launch_windows_launch's PowerShell side exports
# PM_WINJOB_WRAPPER_PID (its own real pid) into the launched process's
# environment specifically so this function can hand it back here; a script
# not running under that launcher (or on POSIX) falls back to $$.
detached_launch_self_pid() {
  if [[ "$(detect_platform)" == windows && -n "${PM_WINJOB_WRAPPER_PID:-}" ]]; then
    printf '%s\n' "$PM_WINJOB_WRAPPER_PID"
  else
    printf '%s\n' "$$"
  fi
}

# Windows-native launch: creates a Job Object, starts
# `<bash.exe> <script_path> [args...]` as its sole member, and blocks inside
# a detached PowerShell process for the run's whole lifetime (see the
# module header above). Callers should reach this through
# detached_launch_under_setsid's platform branch, not directly, except
# runtime/bin/pr-gate.sh's operation-owned preflight path (CC-606), which
# needs to launch a raw command line rather than a script file and so calls
# this with a small synthetic wrapper script -- see that call site.
#
# Sets DETACHED_LAUNCH_ISOLATED=1 on success (Windows has no isolated=0
# case). Writes the PowerShell launcher's own (translated) Windows pid to
# <pid_file> -- NOT the inner bash.exe child's pid; that pid is the unit a
# later kill must target, per the module header above.
detached_launch_windows_launch() {
  local script_path="${1:?script_path required}" log_file="${2:?log_file required}" pid_file="${3-}"
  shift 3
  [[ "${1:-}" == "--" ]] && shift

  export DETACHED_LAUNCH_ISOLATED=0
  _dl_win_available || return 1
  local ps1 ps1_win bash_exe_win log_win child_pid_file child_pid_win argv_b64
  ps1="$(_dl_win_ps1_path)"
  [[ -r "$ps1" ]] || return 1
  ps1_win="$(cygpath -w -- "$ps1")" || return 1
  bash_exe_win="$(cygpath -w -- "$(command -v bash)")" || return 1

  mkdir -p "$(dirname "$log_file")" || return 1
  log_win="$(cygpath -w -- "$log_file")" || return 1
  [[ -n "$pid_file" ]] && { mkdir -p "$(dirname "$pid_file")" || return 1; }
  # The launched bash.exe's own pid is informational only (never a kill
  # target -- see module header); give it a throwaway sibling path when the
  # caller did not ask for a real pid_file so -ChildPidFile always has
  # somewhere writable to go.
  child_pid_file="$(mktemp "${TMPDIR:-/tmp}/pm-winjob-childpid.XXXXXX" 2>/dev/null)" || child_pid_file="${pid_file:-$log_file}.winjob-child-pid"
  child_pid_win="$(cygpath -w -- "$child_pid_file")" || return 1

  argv_b64="$(printf '%s\0' "$script_path" "$@" | base64 -w0 2>/dev/null)" || return 1

  powershell.exe -NoProfile -NonInteractive -File "$ps1_win" \
    -Action Launch -BashExe "$bash_exe_win" -ChildPidFile "$child_pid_win" \
    -LogFile "$log_win" -TargetArgsB64 "$argv_b64" \
    </dev/null >/dev/null 2>&1 &
  local bash_view_pid="$!"
  disown "$bash_view_pid" 2>/dev/null || true
  rm -f "$child_pid_file" 2>/dev/null || true

  # `ps` can race the fork()/exec() of a just-backgrounded process; retry
  # briefly rather than fail on the first miss.
  local win_pid="" _attempt
  for _attempt in 1 2 3 4 5 6 7 8; do
    win_pid="$(_dl_win_winpid_of "$bash_view_pid")"
    [[ "$win_pid" =~ ^[0-9]+$ ]] && break
    win_pid=""
    sleep 0.1
  done
  [[ -n "$win_pid" ]] || return 1

  if [[ -n "$pid_file" ]]; then
    printf '%s\n' "$win_pid" > "$pid_file" || return 1
  fi
  export DETACHED_LAUNCH_ISOLATED=1
  return 0
}

# Platform-neutral "is this launched unit still alive" probe. Used by
# pmctl-dispatch.sh's cancel path as the decision point for whether a kill
# attempt is even needed (detached_launch_kill_process_group is itself
# idempotent either way, but callers like cancel's "leader gone, pgid still
# reported live" branch need to know NOW, not just "did a kill succeed").
# POSIX: signal-0 the process group. Windows: pgid IS the launcher's own
# (translated) Windows pid (see module header); probe it directly.
detached_launch_target_alive() {
  local pgid="${1:?pgid required}"
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] || return 1
  if [[ "$(detect_platform)" == windows ]]; then
    detached_launch_pid_alive "$pgid"
    return $?
  fi
  kill -0 -- "-$pgid" 2>/dev/null
}

# Plain single-pid liveness probe (not a process-group check). Several
# pmctl-dispatch.sh call sites use a bare `kill -0 "$pid"` for this on POSIX
# (status reporting, and the reconcile path's "recorded pid confirmed not
# running" convergence decision) -- confirmed by direct test that this is
# NOT just a style difference on Windows: MSYS `kill -0 <real-windows-pid>`
# reports "No such process" for an arbitrary live Windows process outside
# this bash session's own process tree (verified against a `ping -t`
# process independently confirmed alive via `tasklist`), so on Windows it
# is a silent false negative, not merely unsupported. Any caller checking a
# pid recorded by detached_launch_windows_launch (a real Windows pid, not
# an MSYS-internal one) must route through this function instead of a raw
# `kill -0`.
detached_launch_pid_alive() {
  local pid="${1:?pid required}"
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
  if [[ "$(detect_platform)" == windows ]]; then
    _dl_win_available || return 1
    local ps1_win
    ps1_win="$(cygpath -w -- "$(_dl_win_ps1_path)")" || return 1
    powershell.exe -NoProfile -NonInteractive -File "$ps1_win" \
      -Action Identity -TargetPid "$pid" >/dev/null 2>&1
    return $?
  fi
  kill -0 "$pid" 2>/dev/null
}

# --- end Windows-native process-group isolation ----------------------------

# Generate a 32-char nonce suitable for sentinel-path unguessability.
# /dev/urandom first, $RANDOM concatenation fallback if urandom is
# unavailable/empty/short. Deliberately does not rely on the pipeline's exit
# status: `tr | head -c 32` reliably exits non-zero under `set -o pipefail`
# (head closes its read end after 32 bytes, SIGPIPE-ing tr) even though the
# captured output is fully valid, which would otherwise silently discard a
# perfectly good high-entropy nonce for the much weaker $RANDOM fallback on
# every call from a caller with pipefail set (all current callers have it).
# Judge success by the captured length instead.
detached_launch_generate_nonce() {
  local nonce
  nonce="$( { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32; } 2>/dev/null)" || true
  [[ "${#nonce}" -ge 32 ]] || nonce="${RANDOM}${RANDOM}${RANDOM}"
  printf '%s' "$nonce"
}

# Per-user private key-file path for a given namespace (e.g. "pm-dispatch",
# "pm-gate-dispatch") and id. Prefers XDG_RUNTIME_DIR (tmpfs, already
# per-user/per-session) and falls back to a uid-suffixed /tmp dir.
detached_launch_key_file() {
  local namespace="${1:?namespace required}" id="${2:?id required}" uid key_dir
  uid="$(id -u 2>/dev/null)" || uid="0"
  if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR}" ]]; then
    key_dir="${XDG_RUNTIME_DIR}/${namespace}"
  else
    key_dir="/tmp/${namespace}-${uid}"
  fi
  printf '%s/%s' "$key_dir" "$id"
}

# mkdir -p + chmod 700 + owner-uid verification on a key dir. `mkdir -m 700
# -p` is insufficient: -m only applies to the deepest *new* dir, and a
# pre-existing dir keeps its prior mode/owner — a pre-seeded permissive or
# foreign-owned dir could expose nonce files. Fails closed; distinguishes
# failure stages via return code so callers can print a stage-specific
# message (create/secure/ownership), matching pre-extraction behavior:
#   returns 0 — key_dir exists, mode 700, owned by current uid
#   returns 1 — mkdir failed
#   returns 2 — chmod failed (not owner of a pre-existing dir?)
#   returns 3 — owned by a different uid
detached_launch_secure_key_dir() {
  local key_dir="${1:?key_dir required}"
  mkdir -p "$key_dir" 2>/dev/null || return 1
  chmod 700 "$key_dir" 2>/dev/null || return 2
  local owner
  owner="$(stat -c '%u' "$key_dir" 2>/dev/null || stat -f '%u' "$key_dir" 2>/dev/null || true)"
  if [[ -n "$owner" && "$owner" != "$(id -u)" ]]; then
    return 3
  fi
  return 0
}

# Write a nonce to <key_file>. Caller must have called
# detached_launch_secure_key_dir on dirname(key_file) first.
detached_launch_write_key_file() {
  local key_file="${1:?key_file required}" nonce="${2:?nonce required}"
  printf '%s' "$nonce" > "$key_file" 2>/dev/null
}

# Deterministic sentinel path for a given /tmp prefix ("pm-supervisor" for
# dispatch, "pm-gate" for gate), id, and nonce pair. Both the launcher
# (writes) and the waiter (polls) derive this independently — the path is
# never stored in a workspace-readable location.
detached_launch_sentinel_path() {
  local prefix="${1:?prefix required}" id="${2:?id required}" nonce="${3:?nonce required}"
  printf '/tmp/%s-sentinel-%s-%s' "$prefix" "$id" "$nonce"
}

# Gate lifecycle sentinels are control-plane evidence, not workspace artifacts.
# Keep them beside the mode-700 per-user nonce key rather than in shared /tmp:
# tmpwatch and another successful waiter must not turn an already terminal gate
# into an unverifiable one.  The namespace is also part of the path so the gate
# and dispatch lifecycles remain disjoint.
detached_launch_private_sentinel_path() {
  local namespace="${1:?namespace required}" prefix="${2:?prefix required}"
  local id="${3:?id required}" nonce="${4:?nonce required}" key_file key_dir
  key_file="$(detached_launch_key_file "$namespace" "$id")" || return 1
  key_dir="$(dirname -- "$key_file")" || return 1
  printf '%s/.%s-sentinel-%s-%s' "$key_dir" "$prefix" "$id" "$nonce"
}

# Launch <script_path> [args...] detached via setsid+nohup (falling back to
# nohup+disown when setsid is unavailable). stdout+stderr go to <log_file>;
# if <pid_file> is non-empty, the backgrounded PID is recorded there.
# Env vars assigned on the call itself (e.g. `NONCE="$x" detached_launch_under_setsid ...`)
# propagate to the launched process for the lifetime of this function call,
# same as any other simple-command prefix assignment in bash.
#
# When setsid is used, the child is a new session/process-group leader and is
# safe for process-group cancel. Without setsid the child shares the caller's
# process group — cancel must refuse group kill (see identity `isolated=`).
# Sets DETACHED_LAUNCH_ISOLATED=1|0 for the caller to record in identity.
#
# Usage: detached_launch_under_setsid <script_path> <log_file> <pid_file> [--] <args...>
# Returns 0 once the process is launched and (if requested) the PID is
# persisted; does not wait for the process to complete.
detached_launch_under_setsid() {
  local script_path="${1:?script_path required}" log_file="${2:?log_file required}" pid_file="${3-}"
  shift 3
  [[ "${1:-}" == "--" ]] && shift

  mkdir -p "$(dirname "$log_file")" || return 1
  [[ -n "$pid_file" ]] && { mkdir -p "$(dirname "$pid_file")" || return 1; }

  if [[ "$(detect_platform)" == windows ]]; then
    detached_launch_windows_launch "$script_path" "$log_file" "$pid_file" "$@"
    return $?
  fi

  local pid
  # Exported so callers (pmctl-dispatch) can record isolated= in identity files.
  export DETACHED_LAUNCH_ISOLATED=0
  if command -v setsid >/dev/null 2>&1; then
    setsid nohup bash "$script_path" "$@" </dev/null >"$log_file" 2>&1 &
    pid=$!
    export DETACHED_LAUNCH_ISOLATED=1
  else
    nohup bash "$script_path" "$@" </dev/null >"$log_file" 2>&1 &
    pid=$!
    disown "$pid" 2>/dev/null || true
    export DETACHED_LAUNCH_ISOLATED=0
  fi

  if [[ -n "$pid_file" ]]; then
    printf '%s\n' "$pid" > "$pid_file" || return 1
  fi
  return 0
}

# Write an opaque key=value sentinel file. Content semantics (which keys, in
# what order) are entirely the caller's decision — this function does not
# interpret the pairs, just serializes them one per line.
#
# Publication is atomic: pairs are written to a same-directory temp file, then
# renamed onto <sentinel_path>. Waiters that poll for path existence therefore
# never observe a partial multi-line sentinel (and must not delete a half-written
# file that has not yet been renamed into place).
#
# Usage: detached_launch_write_sentinel <sentinel_path> "final_state=GO" "exit_code=0" ["result_file=/path"]...
detached_launch_write_sentinel() {
  local sentinel_path="${1:?sentinel_path required}"
  shift
  local pair dir base tmp
  dir="$(dirname -- "$sentinel_path")"
  base="$(basename -- "$sentinel_path")"
  mkdir -p "$dir" 2>/dev/null || true
  tmp="$(mktemp "$dir/.${base}.tmp.XXXXXX" 2>/dev/null)" || return 1
  {
    for pair in "$@"; do
      printf '%s\n' "$pair"
    done
  } >"$tmp" 2>/dev/null || { rm -f "$tmp" 2>/dev/null || true; return 1; }
  # Atomic on same filesystem: destination appears only after full content is written.
  mv -f "$tmp" "$sentinel_path" 2>/dev/null || { rm -f "$tmp" 2>/dev/null || true; return 1; }
  return 0
}

# Poll for a sentinel file's existence. Pure poll, no parse, no cleanup: the
# caller reads/removes the file itself once this returns 0. Does NOT handle
# the "key file absent" (indeterminate/exit 3) case — that check happens
# before this function is ever called, against the per-user key file, not
# the sentinel itself (see pmctl_gate_wait / pmctl_dispatch_wait).
#   returns 0   — sentinel appeared within timeout
#   returns 124 — timed out waiting
detached_launch_wait_for_sentinel() {
  local sentinel_path="${1:?sentinel_path required}" timeout="${2:?timeout required}"
  local poll_interval="${3:-2}"
  local start elapsed
  start="$SECONDS"
  while true; do
    [[ -f "$sentinel_path" ]] && return 0
    elapsed=$((SECONDS - start))
    (( elapsed >= timeout )) && return 124
    sleep "$poll_interval"
  done
}

# Current boot identifier, when the kernel exposes one. Used to detect a
# reboot between identity capture and re-verification: starttime (below) is
# boot-relative ticks and resets after reboot, so a post-reboot process could
# coincidentally collide on pid+pgid+starttime. Empty (not an error) when
# unavailable, e.g. non-Linux — callers treat empty as "no reboot signal".
detached_launch_current_boot_id() {
  local f="/proc/sys/kernel/random/boot_id"
  [[ -r "$f" ]] || return 0
  cat "$f" 2>/dev/null || true
}

# Capture a stable process identity for cancel-time re-verification.
# Linux /proc is authoritative; without it this returns 1 (fail-closed for
# identity-dependent kill). Emits key=value lines:
#   pid=  state=  pgid=  starttime=  comm=  isolated=  boot_id=
# starttime is the kernel field from /proc/<pid>/stat (boot-relative ticks),
# which is stable across PID reuse of the same numeric pid within one boot;
# boot_id disambiguates across a reboot (see detached_launch_current_boot_id).
# isolated=1 means the process was launched under setsid (own process group);
# isolated=0 means cancel must refuse process-group kill (shared group).
# Optional second arg overrides isolated (defaults to 1 when pid==pgid else 0).
detached_launch_capture_identity() {
  local pid="${1:?pid required}" isolated_override="${2-}"
  local stat_file rest pgrp starttime state comm_field comm isolated boot_id
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1

  if [[ "$(detect_platform)" == windows ]]; then
    # isolated_override is not applicable here: Windows Job Object launches
    # are always isolated=1 (see module header), so the PowerShell Identity
    # action hardcodes it rather than accepting an override the way the
    # /proc-based path below does for its setsid-missing fallback case.
    _dl_win_available || return 1
    local ps1_win out
    ps1_win="$(cygpath -w -- "$(_dl_win_ps1_path)")" || return 1
    out="$(powershell.exe -NoProfile -NonInteractive -File "$ps1_win" \
      -Action Identity -TargetPid "$pid" 2>/dev/null)" || return 1
    [[ -n "$out" ]] || return 1
    printf '%s\n' "$out" | tr -d '\r'
    return 0
  fi

  stat_file="/proc/$pid/stat"
  [[ -r "$stat_file" ]] || return 1
  # comm may contain spaces/parentheses; fields after the final ')' are fixed.
  rest="$(cat "$stat_file" 2>/dev/null)" || return 1
  comm_field="${rest#*(}"
  comm_field="${comm_field%)*}"
  rest="${rest##*)}"
  # shellcheck disable=SC2086  # intentional field split of /proc stat tail
  set -- $rest
  # After comm: state ppid pgrp session ... starttime is positional $20.
  state="${1:-}"
  pgrp="${3:-}"
  starttime="${20:-}"
  [[ -n "$state" && -n "$pgrp" && -n "$starttime" ]] || return 1
  comm="$(tr -d '\n' <"/proc/$pid/comm" 2>/dev/null || printf '%s' "$comm_field")"
  if [[ -n "$isolated_override" ]]; then
    isolated="$isolated_override"
  elif [[ "$pid" == "$pgrp" ]]; then
    # Session/process-group leaders created by setsid have pid == pgid.
    isolated=1
  else
    isolated=0
  fi
  boot_id="$(detached_launch_current_boot_id)" || boot_id=""
  printf 'pid=%s\nstate=%s\npgid=%s\nstarttime=%s\ncomm=%s\nisolated=%s\nboot_id=%s\n' \
    "$pid" "$state" "$pgrp" "$starttime" "$comm" "$isolated" "$boot_id"
}

# Publish a captured identity record to <path>.
#
# Only the identified process itself can produce an authoritative record: a
# launcher can observe a child that setsid has not yet moved into its own
# process group, so the pgid it reads is the launcher's own and is stale the
# moment setsid takes effect. A process calling this on itself after setsid
# has no such window.
#
# The record is the multi-line output of detached_launch_capture_identity; it
# is split back into key=value pairs and installed through the same atomic
# temp-then-rename publication detached_launch_write_sentinel uses, so a
# concurrent reader never loads a partially written identity.
detached_launch_publish_identity_record() {
  local path="${1:?identity path required}" record="${2:?identity record required}"
  local -a pairs=()
  mapfile -t pairs <<<"$record"
  (( ${#pairs[@]} > 0 )) || return 1
  detached_launch_write_sentinel "$path" "${pairs[@]}"
}

# Load identity file written by detached_launch_capture_identity (key=value).
# Sets DL_ID_PID DL_ID_PGID DL_ID_STARTTIME DL_ID_COMM DL_ID_ISOLATED DL_ID_BOOT_ID.
# Returns 1 if incomplete.
detached_launch_load_identity_file() {
  local path="${1:?identity path required}" line key val
  DL_ID_PID=""; DL_ID_PGID=""; DL_ID_STARTTIME=""; DL_ID_COMM=""; DL_ID_ISOLATED=""; DL_ID_BOOT_ID=""
  [[ -f "$path" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip a trailing CR: identity files written via jq's `>` file
    # redirection on native Windows come out CRLF-terminated (confirmed by
    # direct test -- this jq build emits \r\n even for a plain `\n` in the
    # format string), which would otherwise make every value compare unequal
    # to its non-CR-suffixed counterpart and make detached_launch_verify_
    # identity report a false mismatch on every Windows producer-identity
    # round-trip. Harmless no-op for files that never had a CR (the normal
    # detached_launch_write_sentinel-authored ones, and all of POSIX).
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      pid) DL_ID_PID="$val" ;;
      pgid) DL_ID_PGID="$val" ;;
      starttime) DL_ID_STARTTIME="$val" ;;
      comm) DL_ID_COMM="$val" ;;
      isolated) DL_ID_ISOLATED="$val" ;;
      boot_id) DL_ID_BOOT_ID="$val" ;;
    esac
  done <"$path"
  [[ -n "$DL_ID_PID" && -n "$DL_ID_PGID" && -n "$DL_ID_STARTTIME" ]] || return 1
  # Legacy identity files without isolated=: treat as isolated only when pid==pgid.
  if [[ -z "$DL_ID_ISOLATED" ]]; then
    if [[ "$DL_ID_PID" == "$DL_ID_PGID" ]]; then
      DL_ID_ISOLATED=1
    else
      DL_ID_ISOLATED=0
    fi
  fi
  return 0
}

# Re-verify that <pid> still matches a captured identity.
#   0 — process alive and identity matches (safe to signal)
#   1 — process gone (not an error for cancel terminalization; do not signal)
#   2 — identity mismatch / PID reuse (fail-closed; never signal)
detached_launch_verify_identity() {
  local pid="${1:?pid required}" identity_file="${2:?identity file required}"
  local snap cur_pgid cur_start cur_comm cur_boot_id cur_state
  if ! detached_launch_load_identity_file "$identity_file"; then
    return 2
  fi
  [[ "$pid" == "$DL_ID_PID" ]] || return 2

  if [[ "$(detect_platform)" == windows ]]; then
    _dl_win_available || return 2
    local ps1_win rc=0
    ps1_win="$(cygpath -w -- "$(_dl_win_ps1_path)")" || return 2
    local -a extra_args=()
    [[ -n "${DL_ID_BOOT_ID:-}" ]] && extra_args=(-ExpectBootId "$DL_ID_BOOT_ID")
    powershell.exe -NoProfile -NonInteractive -File "$ps1_win" -Action Verify \
      -TargetPid "$pid" -ExpectStarttime "$DL_ID_STARTTIME" -ExpectComm "$DL_ID_COMM" \
      "${extra_args[@]}" >/dev/null 2>&1
    rc=$?
    # The PowerShell action's own exit codes (0/1/2) already match this
    # function's contract exactly; a launch failure (missing powershell.exe/
    # cygpath, or any other non-0/1/2 exit) is not "identity confirmed gone"
    # and must fail closed as a mismatch, not fall through as if it were 1.
    case "$rc" in
      0|1|2) return "$rc" ;;
      *) return 2 ;;
    esac
  fi

  # Reboot detection: starttime is boot-relative and resets after reboot, so a
  # post-reboot process could coincidentally collide on pid+pgid+starttime.
  # When both boot ids are known and differ, the original process cannot
  # possibly still be alive — report gone without attempting the (unreliable
  # post-reboot) starttime comparison below. Legacy identity files without
  # boot_id= (empty DL_ID_BOOT_ID) fall through to the existing comparison.
  if [[ -n "${DL_ID_BOOT_ID:-}" ]]; then
    cur_boot_id="$(detached_launch_current_boot_id)" || cur_boot_id=""
    if [[ -n "$cur_boot_id" && "$cur_boot_id" != "$DL_ID_BOOT_ID" ]]; then
      return 1
    fi
  fi
  if [[ ! -r "/proc/$pid/stat" ]]; then
    return 1
  fi
  # Single /proc snapshot so fields cannot mix across a mid-read transition.
  snap="$(detached_launch_capture_identity "$pid" 2>/dev/null)" || return 1
  # `kill -0` and /proc both still report a zombie. The state is parsed from
  # the same safe snapshot capture above, whose parser handles a `comm` field
  # containing spaces or parentheses.
  cur_state="$(printf '%s\n' "$snap" | grep -m1 '^state=' | cut -d= -f2-)" || true
  [[ "$cur_state" != "Z" && "$cur_state" != "X" ]] || return 1
  cur_pgid="$(printf '%s\n' "$snap" | grep -m1 '^pgid=' | cut -d= -f2-)" || true
  cur_start="$(printf '%s\n' "$snap" | grep -m1 '^starttime=' | cut -d= -f2-)" || true
  cur_comm="$(printf '%s\n' "$snap" | grep -m1 '^comm=' | cut -d= -f2-)" || true
  if [[ -z "$cur_pgid" || -z "$cur_start" ]]; then
    return 1
  fi
  if [[ "$cur_pgid" != "$DL_ID_PGID" || "$cur_start" != "$DL_ID_STARTTIME" ]]; then
    return 2
  fi
  if [[ -n "$DL_ID_COMM" && -n "$cur_comm" && "$cur_comm" != "$DL_ID_COMM" ]]; then
    return 2
  fi
  return 0
}

# Signal an entire process group: SIGTERM, wait up to grace seconds, then
# SIGKILL if any member remains. pgid must be positive; never signals pgid 0/-1.
# Refuses to signal:
#   - the caller's own process group
#   - any process group that contains this process or an ancestor (would kill
#     the invoking shell/automation runner)
#   0 — group gone after TERM or KILL
#   1 — invalid pgid / refused unsafe group / group still alive after KILL
detached_launch_kill_process_group() {
  local pgid="${1:?pgid required}" grace="${2:-5}"
  local self_pgid probe p_pgid
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] || return 1

  if [[ "$(detect_platform)" == windows ]]; then
    # pgid IS the PowerShell launcher's own (translated) Windows pid here
    # (see module header) -- terminating it is what closes the job handle
    # and, via KILL_ON_JOB_CLOSE, atomically tears down the whole tree.
    # Windows has no SIGTERM-equivalent soft-kill for an arbitrary console
    # process tree, so there is no separate TERM phase to attempt first;
    # -Action Kill itself is the hard kill, with -GraceSeconds bounding how
    # long it polls afterward to confirm the tree actually went away.
    _dl_win_available || return 1
    local ps1_win own_bash_pid own_win_pid
    ps1_win="$(cygpath -w -- "$(_dl_win_ps1_path)")" || return 1
    own_bash_pid="$$"
    own_win_pid="$(_dl_win_winpid_of "$own_bash_pid")"
    # Fail closed if we cannot determine our own Windows pid: without it we
    # cannot prove the target is not the invoking shell/automation runner
    # (the direct analogue of the POSIX self_pgid check just below).
    [[ "$own_win_pid" =~ ^[0-9]+$ ]] || return 1
    powershell.exe -NoProfile -NonInteractive -File "$ps1_win" -Action Kill \
      -TargetPid "$pgid" -CallerWinPid "$own_win_pid" -GraceSeconds "$grace" \
      >/dev/null 2>&1
    return $?
  fi

  # Fail closed if we cannot determine our own process group: without it we
  # cannot prove the target is not the invoking shell/automation runner.
  self_pgid="$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')" || self_pgid=""
  if [[ -z "$self_pgid" || ! "$self_pgid" =~ ^[1-9][0-9]*$ ]]; then
    return 1
  fi
  if [[ "$pgid" == "$self_pgid" ]]; then
    return 1
  fi
  # Walk ancestors: if any share the target pgid, refuse (shared runner group).
  # If /proc/ps becomes unreadable mid-walk, fail closed rather than signal.
  probe="$$"
  while [[ "$probe" =~ ^[1-9][0-9]*$ && "$probe" -gt 1 ]]; do
    p_pgid="$(ps -o pgid= -p "$probe" 2>/dev/null | tr -d ' ')" || return 1
    if [[ -z "$p_pgid" ]]; then
      return 1
    fi
    if [[ "$p_pgid" == "$pgid" ]]; then
      return 1
    fi
    probe="$(ps -o ppid= -p "$probe" 2>/dev/null | tr -d ' ')" || return 1
  done
  # Negative pid = process group. Prefer kill, fall back quietly if already gone.
  # Poll interval is fractional so short --grace values (tests) do not wait full
  # seconds per tick; wall-clock budget remains `grace` seconds.
  local poll="0.2"
  kill -TERM -- "-$pgid" 2>/dev/null || true
  local start=$SECONDS
  while (( SECONDS - start < grace )); do
    if ! kill -0 -- "-$pgid" 2>/dev/null; then
      return 0
    fi
    sleep "$poll"
  done
  if kill -0 -- "-$pgid" 2>/dev/null; then
    kill -KILL -- "-$pgid" 2>/dev/null || true
    sleep 0.2
  fi
  if kill -0 -- "-$pgid" 2>/dev/null; then
    return 1
  fi
  return 0
}
