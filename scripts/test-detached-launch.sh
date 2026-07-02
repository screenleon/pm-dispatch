#!/usr/bin/env bash
# Regression tests for scripts/lib/detached-launch.sh (CC-434).
#
# Covers the shared nonce/key-dir/sentinel primitives, plus a drift guard: the
# REPO_ROOT symlink-resolution block is intentionally NOT extracted into this
# lib (circular dependency — see docs/spikes/CC-433.md angle a3), so it is
# duplicated verbatim between scripts/gate-supervisor.sh and
# scripts/dispatch-supervisor.sh inside BEGIN/END resolve-root markers. This
# suite extracts and diffs the two marked blocks so a future edit to one that
# forgets the other fails loudly instead of silently drifting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/detached-launch.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# shellcheck source=scripts/lib/detached-launch.sh
. "$LIB"

_extract_marked_block() {
  local file="$1"
  sed -n '/# BEGIN resolve-root/,/# END resolve-root/p' "$file"
}

# ---- 1: resolve-root inline blocks stay byte-identical across supervisors ----
case_resolve_root_blocks_identical() {
  local name="detached-launch/gate + dispatch supervisor resolve-root blocks match"
  should_run "$name" || return 0

  local gate_block dispatch_block
  gate_block="$(_extract_marked_block "$REPO_ROOT/scripts/gate-supervisor.sh")"
  dispatch_block="$(_extract_marked_block "$REPO_ROOT/scripts/dispatch-supervisor.sh")"

  if [[ -z "$gate_block" ]]; then
    fail "$name" "no BEGIN/END resolve-root block found in gate-supervisor.sh"
    return
  fi
  if [[ -z "$dispatch_block" ]]; then
    fail "$name" "no BEGIN/END resolve-root block found in dispatch-supervisor.sh"
    return
  fi

  if [[ "$gate_block" == "$dispatch_block" ]]; then
    pass "$name"
  else
    fail "$name" "resolve-root blocks diverged between gate-supervisor.sh and dispatch-supervisor.sh:
--- gate ---
$gate_block
--- dispatch ---
$dispatch_block"
  fi
}

# ---- 2: generate_nonce produces non-empty alnum output ----------------------
case_generate_nonce_nonempty() {
  local name="detached-launch/generate_nonce produces non-empty output"
  should_run "$name" || return 0

  local nonce
  nonce="$(detached_launch_generate_nonce)"
  if [[ -n "$nonce" ]] && [[ "$nonce" =~ ^[A-Za-z0-9]+$ ]]; then
    pass "$name"
  else
    fail "$name" "nonce=$nonce"
  fi
}

# ---- 3: generate_nonce is not deterministic across calls --------------------
case_generate_nonce_varies() {
  local name="detached-launch/generate_nonce varies across calls"
  should_run "$name" || return 0

  local n1 n2
  n1="$(detached_launch_generate_nonce)"
  n2="$(detached_launch_generate_nonce)"
  if [[ "$n1" != "$n2" ]]; then
    pass "$name"
  else
    fail "$name" "two consecutive nonces were identical: $n1"
  fi
}

# ---- 4: key_file honours XDG_RUNTIME_DIR when set ----------------------------
case_key_file_xdg_runtime_dir() {
  local name="detached-launch/key_file uses XDG_RUNTIME_DIR when set"
  should_run "$name" || return 0

  local xdg="$tmp_root/xdg1"
  mkdir -p "$xdg"
  local out
  out="$(XDG_RUNTIME_DIR="$xdg" detached_launch_key_file "pm-test-ns" "some-id")"
  if [[ "$out" == "$xdg/pm-test-ns/some-id" ]]; then
    pass "$name"
  else
    fail "$name" "out=$out"
  fi
}

# ---- 5: key_file falls back to /tmp when XDG_RUNTIME_DIR is unset/missing ---
case_key_file_tmp_fallback() {
  local name="detached-launch/key_file falls back to /tmp when XDG_RUNTIME_DIR absent"
  should_run "$name" || return 0

  local out uid
  uid="$(id -u)"
  out="$(unset XDG_RUNTIME_DIR; detached_launch_key_file "pm-test-ns" "some-id")"
  if [[ "$out" == "/tmp/pm-test-ns-${uid}/some-id" ]]; then
    pass "$name"
  else
    fail "$name" "out=$out"
  fi
}

# ---- 6: secure_key_dir creates a mode-700 dir owned by current user ----------
case_secure_key_dir_creates_700() {
  local name="detached-launch/secure_key_dir creates mode-700 dir"
  should_run "$name" || return 0

  local dir="$tmp_root/keydir1/nested"
  if detached_launch_secure_key_dir "$dir"; then
    local mode
    mode="$(stat -c '%a' "$dir" 2>/dev/null || stat -f '%A' "$dir" 2>/dev/null)"
    if [[ "$mode" == "700" ]]; then
      pass "$name"
    else
      fail "$name" "mode=$mode"
    fi
  else
    fail "$name" "secure_key_dir returned non-zero"
  fi
}

# ---- 7: secure_key_dir returns 1 when mkdir -p fails (portable: parent is a file) --
case_secure_key_dir_mkdir_failure() {
  local name="detached-launch/secure_key_dir returns 1 when mkdir -p fails"
  should_run "$name" || return 0

  local notadir="$tmp_root/notadir7"
  : > "$notadir"
  local rc=0
  detached_launch_secure_key_dir "$notadir/sub" || rc=$?
  if [[ "$rc" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc (expected 1 for mkdir failure under a non-directory parent)"
  fi
}

# ---- 8: write_key_file + read back round-trips the nonce --------------------
case_write_key_file_roundtrip() {
  local name="detached-launch/write_key_file round-trips nonce"
  should_run "$name" || return 0

  local dir="$tmp_root/keydir2" file
  detached_launch_secure_key_dir "$dir"
  file="$dir/some-id"
  detached_launch_write_key_file "$file" "abc123"
  local got
  got="$(cat "$file" 2>/dev/null)"
  if [[ "$got" == "abc123" ]]; then
    pass "$name"
  else
    fail "$name" "got=$got"
  fi
}

# ---- 9: sentinel_path is deterministic given the same inputs ----------------
case_sentinel_path_deterministic() {
  local name="detached-launch/sentinel_path deterministic"
  should_run "$name" || return 0

  local p1 p2
  p1="$(detached_launch_sentinel_path "pm-gate" "gate-1" "nonceX")"
  p2="$(detached_launch_sentinel_path "pm-gate" "gate-1" "nonceX")"
  if [[ "$p1" == "$p2" ]] && [[ "$p1" == "/tmp/pm-gate-sentinel-gate-1-nonceX" ]]; then
    pass "$name"
  else
    fail "$name" "p1=$p1 p2=$p2"
  fi
}

# ---- 10: write_sentinel + wait_for_sentinel round-trip on immediate write ---
case_wait_for_sentinel_success() {
  local name="detached-launch/wait_for_sentinel returns 0 once file exists"
  should_run "$name" || return 0

  local sentinel="$tmp_root/sentinel1"
  detached_launch_write_sentinel "$sentinel" "final_state=ok" "exit_code=0"

  if detached_launch_wait_for_sentinel "$sentinel" 5 1; then
    local state
    state="$(grep -m1 '^final_state=' "$sentinel" | cut -d= -f2-)"
    if [[ "$state" == "ok" ]]; then
      pass "$name"
    else
      fail "$name" "state=$state"
    fi
  else
    fail "$name" "wait_for_sentinel timed out on a pre-existing file"
  fi
}

# ---- 11: wait_for_sentinel returns 124 on timeout ----------------------------
case_wait_for_sentinel_timeout() {
  local name="detached-launch/wait_for_sentinel returns 124 on timeout"
  should_run "$name" || return 0

  local sentinel="$tmp_root/sentinel-never-appears"
  local rc=0
  detached_launch_wait_for_sentinel "$sentinel" 1 1 || rc=$?
  if [[ "$rc" -eq 124 ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc"
  fi
}

# ---- 12: under_setsid launches a script and records its pid -----------------
case_under_setsid_launches_and_records_pid() {
  local name="detached-launch/under_setsid launches script and writes pid_file"
  should_run "$name" || return 0

  local script="$tmp_root/probe.sh" log="$tmp_root/probe.log" pidfile="$tmp_root/probe.pid"
  local done_fifo="$tmp_root/probe.done.fifo"
  mkfifo "$done_fifo"
  cat > "$script" <<SCRIPT
#!/usr/bin/env bash
printf 'ran\n'
exec 7<>"$done_fifo" 2>/dev/null || true
printf 'done\n' >&7
SCRIPT
  chmod +x "$script"

  detached_launch_under_setsid "$script" "$log" "$pidfile"

  local signaled=0 _dummy
  if read -r -t 5 _dummy < "$done_fifo"; then
    signaled=1
  fi

  if [[ "$signaled" -eq 1 ]] && [[ -s "$pidfile" ]] && grep -q 'ran' "$log"; then
    pass "$name"
  else
    fail "$name" "signaled=$signaled pidfile_content=$(cat "$pidfile" 2>/dev/null) log=$(cat "$log" 2>/dev/null)"
  fi
}

# ---- 13: under_setsid with empty pid_file does not write a pid file ---------
case_under_setsid_empty_pid_file_skipped() {
  local name="detached-launch/under_setsid with empty pid_file arg writes nothing"
  should_run "$name" || return 0

  local script="$tmp_root/probe2.sh" log="$tmp_root/probe2.log"
  local done_fifo="$tmp_root/probe2.done.fifo"
  mkfifo "$done_fifo"
  cat > "$script" <<SCRIPT
#!/usr/bin/env bash
exec 7<>"$done_fifo" 2>/dev/null || true
printf 'done\n' >&7
SCRIPT
  chmod +x "$script"

  detached_launch_under_setsid "$script" "$log" ""

  local signaled=0 _dummy
  if read -r -t 5 _dummy < "$done_fifo"; then
    signaled=1
  fi

  if [[ "$signaled" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "script never signaled completion"
  fi
}

case_resolve_root_blocks_identical
case_generate_nonce_nonempty
case_generate_nonce_varies
case_key_file_xdg_runtime_dir
case_key_file_tmp_fallback
case_secure_key_dir_creates_700
case_secure_key_dir_mkdir_failure
case_write_key_file_roundtrip
case_sentinel_path_deterministic
case_wait_for_sentinel_success
case_wait_for_sentinel_timeout
case_under_setsid_launches_and_records_pid
case_under_setsid_empty_pid_file_skipped

th_summary
