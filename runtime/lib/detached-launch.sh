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

# Launch <script_path> [args...] detached via setsid+nohup (falling back to
# nohup+disown when setsid is unavailable). stdout+stderr go to <log_file>;
# if <pid_file> is non-empty, the backgrounded PID is recorded there.
# Env vars assigned on the call itself (e.g. `NONCE="$x" detached_launch_under_setsid ...`)
# propagate to the launched process for the lifetime of this function call,
# same as any other simple-command prefix assignment in bash.
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

  local pid
  if command -v setsid >/dev/null 2>&1; then
    setsid nohup bash "$script_path" "$@" </dev/null >"$log_file" 2>&1 &
    pid=$!
  else
    nohup bash "$script_path" "$@" </dev/null >"$log_file" 2>&1 &
    pid=$!
    disown "$pid" 2>/dev/null || true
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
# Usage: detached_launch_write_sentinel <sentinel_path> "final_state=GO" "exit_code=0" ["result_file=/path"]...
detached_launch_write_sentinel() {
  local sentinel_path="${1:?sentinel_path required}"
  shift
  local pair
  {
    for pair in "$@"; do
      printf '%s\n' "$pair"
    done
  } > "$sentinel_path" 2>/dev/null || true
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

# Capture a stable process identity for cancel-time re-verification.
# Linux /proc is authoritative; without it this returns 1 (fail-closed for
# identity-dependent kill). Emits key=value lines:
#   pid=  pgid=  starttime=  comm=
# starttime is the kernel field from /proc/<pid>/stat (boot-relative ticks),
# which is stable across PID reuse of the same numeric pid.
detached_launch_capture_identity() {
  local pid="${1:?pid required}"
  local stat_file rest state ppid pgrp session tty_nr tpgid flags
  local minflt cminflt majflt cmajflt utime stime cutime cstime priority nice
  local num_threads itrealvalue starttime comm_field comm
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  stat_file="/proc/$pid/stat"
  [[ -r "$stat_file" ]] || return 1
  # comm may contain spaces/parentheses; fields after the final ')' are fixed.
  rest="$(cat "$stat_file" 2>/dev/null)" || return 1
  comm_field="${rest#*(}"
  comm_field="${comm_field%)*}"
  rest="${rest##*)}"
  # shellcheck disable=SC2086  # intentional field split of /proc stat tail
  set -- $rest
  # After comm: state ppid pgrp session tty_nr tpgid flags ... starttime is $20
  state="${1:-}"; ppid="${2:-}"; pgrp="${3:-}"
  starttime="${20:-}"
  [[ -n "$pgrp" && -n "$starttime" ]] || return 1
  comm="$(tr -d '\n' <"/proc/$pid/comm" 2>/dev/null || printf '%s' "$comm_field")"
  printf 'pid=%s\npgid=%s\nstarttime=%s\ncomm=%s\n' "$pid" "$pgrp" "$starttime" "$comm"
}

# Load identity file written by detached_launch_capture_identity (key=value).
# Sets DL_ID_PID DL_ID_PGID DL_ID_STARTTIME DL_ID_COMM. Returns 1 if incomplete.
detached_launch_load_identity_file() {
  local path="${1:?identity path required}" line key val
  DL_ID_PID=""; DL_ID_PGID=""; DL_ID_STARTTIME=""; DL_ID_COMM=""
  [[ -f "$path" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      pid) DL_ID_PID="$val" ;;
      pgid) DL_ID_PGID="$val" ;;
      starttime) DL_ID_STARTTIME="$val" ;;
      comm) DL_ID_COMM="$val" ;;
    esac
  done <"$path"
  [[ -n "$DL_ID_PID" && -n "$DL_ID_PGID" && -n "$DL_ID_STARTTIME" ]] || return 1
  return 0
}

# Re-verify that <pid> still matches a captured identity.
#   0 — process alive and identity matches (safe to signal)
#   1 — process gone (not an error for cancel terminalization; do not signal)
#   2 — identity mismatch / PID reuse (fail-closed; never signal)
detached_launch_verify_identity() {
  local pid="${1:?pid required}" identity_file="${2:?identity file required}"
  local cur_pgid cur_start cur_comm
  if ! detached_launch_load_identity_file "$identity_file"; then
    return 2
  fi
  [[ "$pid" == "$DL_ID_PID" ]] || return 2
  if [[ ! -r "/proc/$pid/stat" ]]; then
    return 1
  fi
  cur_pgid="$(detached_launch_capture_identity "$pid" 2>/dev/null | grep -m1 '^pgid=' | cut -d= -f2-)" || true
  cur_start="$(detached_launch_capture_identity "$pid" 2>/dev/null | grep -m1 '^starttime=' | cut -d= -f2-)" || true
  cur_comm="$(detached_launch_capture_identity "$pid" 2>/dev/null | grep -m1 '^comm=' | cut -d= -f2-)" || true
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
#   0 — group gone after TERM or KILL
#   1 — invalid pgid / signal delivery failure that left the group alive
detached_launch_kill_process_group() {
  local pgid="${1:?pgid required}" grace="${2:-5}"
  local waited=0
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] || return 1
  # Negative pid = process group. Prefer kill, fall back quietly if already gone.
  kill -TERM -- "-$pgid" 2>/dev/null || true
  while (( waited < grace )); do
    if ! kill -0 -- "-$pgid" 2>/dev/null; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
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
