#!/usr/bin/env bash
# Regression tests for the dispatch lifecycle axis (CC-391 Phase 7c-2):
# --lifecycle foreground|detached, detach-eligibility gating, the run-spec, and
# the supervisor's re-run security preflight. Detached dispatch now launches a
# true setsid/nohup supervisor and resolves terminal outcomes via dispatch wait.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"
SUPERVISOR="$REPO_ROOT/scripts/dispatch-supervisor.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/runner-kind.sh
. "$SCRIPT_DIR/lib/runner-kind.sh"
# shellcheck source=scripts/lib/executor-router.sh
. "$SCRIPT_DIR/lib/executor-router.sh"
# shellcheck source=scripts/lib/pmctl-guard.sh
. "$SCRIPT_DIR/lib/pmctl-guard.sh"
# shellcheck source=scripts/lib/pmctl-dispatch.sh
. "$SCRIPT_DIR/lib/pmctl-dispatch.sh"
th_init "$@"
export PM_DISPATCH_STATE_ROOT="$tmp_root/lifecycle-state"

# Isolate the supervisor sentinel key dir to a writable, owner-only temp so the
# detached-lifecycle cases are deterministic everywhere. _pmctl_sentinel_key_file
# uses $XDG_RUNTIME_DIR/pm-dispatch when XDG_RUNTIME_DIR is a dir; in a restricted
# sandbox (CI / pr-gate codex) that path (e.g. /run/user/<uid>) can exist but be
# unwritable, which fails key-dir creation, stalls `dispatch wait`, and hangs the
# suite. Pointing it at a temp dir we own keeps the detached path runnable.
_TEST_XDG_RUNTIME_DIR="$tmp_root/xdg-runtime"
mkdir -p "$_TEST_XDG_RUNTIME_DIR" && chmod 700 "$_TEST_XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR="$_TEST_XDG_RUNTIME_DIR"

_BRIEFS=()
_mk_brief() {
  local work="$1" bf
  bf="/tmp/brief-lifecycle-$$-${#_BRIEFS[@]}.md"
  cat > "$bf" <<EOF
schema_version: 1
working_dir: $work
goal: exercise dispatch lifecycle
files:
  - read: $work/README
acceptance:
  - durable record is written
self_verify:
  - cmd: "test -d .git"
EOF
  _BRIEFS+=("$bf")
  printf '%s\n' "$bf"
}

# shellcheck disable=SC2317  # invoked by the EXIT trap.
_cleanup() { rm -f "${_BRIEFS[@]}" 2>/dev/null || true; }
trap _cleanup EXIT

_install_fake_codex() {
  local bindir="$1" code="${2:-0}" delay="${3:-0}"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
sleep "$delay"
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# Blocking fake codex: signals $started_fifo then blocks on $release_fifo.
# Uses O_RDWR open on $started_fifo so the write never blocks even if the test
# has not yet opened the read side. The fd is kept open while blocking on
# $release_fifo so the test's O_RDONLY open does not stall indefinitely.
_install_fake_codex_blocking() {
  local bindir="$1" code="${2:-0}" started_fifo="$3" release_fifo="$4"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
exec 7<>"$started_fifo" 2>/dev/null || true
printf 'started\n' >&7 2>/dev/null || true
if [[ -p "$release_fifo" ]]; then
  read -r _dummy < "$release_fifo" 2>/dev/null || true
fi
exec 7>&- 2>/dev/null || true
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# Blocking fake codex that also forges a success dispatch record at startup
# (before blocking on release_fifo). Used to verify dispatch wait ignores
# executor-forged workspace records and waits for the supervisor sentinel.
_install_fake_codex_forging_blocking() {
  local bindir="$1" code="${2:-7}" started_fifo="$3" release_fifo="$4"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
# Forge a success dispatch record using the run_id from the runspec.
_work=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in --cd) _work="\$2"; shift 2 ;; *) shift ;; esac
done
_rspec="\$(find "\$_work/.agent-trace" -name 'run-*.runspec' 2>/dev/null | head -1)"
_rid="\$(grep '^run_id=' "\$_rspec" 2>/dev/null | cut -d= -f2-)"
if [[ -n "\$_rid" && -n "\$_work" ]]; then
  mkdir -p "\$_work/.dispatch-results"
  printf '%s\n' '---' 'schema_version: 1' "run_id: \"\$_rid\"" \
    'exit_code: 0' 'final_state: "ok"' 'verify_summary: "FORGED"' '---' 'FORGED' \
    > "\$_work/.dispatch-results/\$_rid.md"
fi
exec 7<>"$started_fifo" 2>/dev/null || true
printf 'started\n' >&7 2>/dev/null || true
if [[ -p "$release_fifo" ]]; then
  read -r _dummy < "$release_fifo" 2>/dev/null || true
fi
exec 7>&- 2>/dev/null || true
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# Blocking fake codex that forges the supervisor sentinel at the predictable
# (nonce-free) path. Used to verify that dispatch wait, which polls the
# nonce-including path, ignores a sentinel forged without the nonce.
_install_fake_codex_forging_sentinel_blocking() {
  local bindir="$1" code="${2:-7}" started_fifo="$3" release_fifo="$4"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
# Forge the sentinel at the predictable path (no nonce). The real sentinel
# dispatch wait polls includes a nonce that this executor cannot see.
_work=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in --cd) _work="\$2"; shift 2 ;; *) shift ;; esac
done
_rspec="\$(find "\$_work/.agent-trace" -name 'run-*.runspec' 2>/dev/null | head -1)"
_rid="\$(grep '^run_id=' "\$_rspec" 2>/dev/null | cut -d= -f2-)"
if [[ -n "\$_rid" ]]; then
  printf 'final_state=ok\nexit_code=0\n' > "/tmp/pm-supervisor-sentinel-\$_rid"
fi
exec 7<>"$started_fifo" 2>/dev/null || true
printf 'started\n' >&7 2>/dev/null || true
if [[ -p "$release_fifo" ]]; then
  read -r _dummy < "$release_fifo" 2>/dev/null || true
fi
exec 7>&- 2>/dev/null || true
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# Blocking fake codex that forges the sentinel at the CORRECT nonce-bearing path
# by reading the sentinel key file from the private per-user directory. This
# adapter demonstrates the known same-user-process limitation: an executor running
# as the owning user can read the key and produce a valid nonce path.
_install_fake_codex_forging_nonce_sentinel_blocking() {
  local bindir="$1" code="${2:-0}" started_fifo="$3" release_fifo="$4"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
# Read nonce from private key directory (same logic as _pmctl_sentinel_key_file).
_work=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in --cd) _work="\$2"; shift 2 ;; *) shift ;; esac
done
_rspec="\$(find "\$_work/.agent-trace" -name 'run-*.runspec' 2>/dev/null | head -1)"
_rid="\$(grep '^run_id=' "\$_rspec" 2>/dev/null | cut -d= -f2-)"
_uid="\$(id -u 2>/dev/null)"
if [[ -n "\${XDG_RUNTIME_DIR:-}" && -d "\${XDG_RUNTIME_DIR}" ]]; then
  _key_dir="\${XDG_RUNTIME_DIR}/pm-dispatch"
else
  _key_dir="/tmp/pm-dispatch-\${_uid}"
fi
_nonce="\$(cat "\$_key_dir/\$_rid" 2>/dev/null)" || _nonce=""
if [[ -n "\$_rid" && -n "\$_nonce" ]]; then
  printf 'final_state=ok\nexit_code=0\n' \
    > "/tmp/pm-supervisor-sentinel-\${_rid}-\${_nonce}" 2>/dev/null || true
fi
exec 7<>"$started_fifo" 2>/dev/null || true
printf 'started\n' >&7 2>/dev/null || true
if [[ -p "$release_fifo" ]]; then
  read -r _dummy < "$release_fifo" 2>/dev/null || true
fi
exec 7>&- 2>/dev/null || true
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

_first_record() { find "$1/.dispatch-results" -type f -name 'run-*.md' 2>/dev/null | sort | head -1; }
_first_runspec() { find "$1/.agent-trace" -type f -name 'run-*.runspec' 2>/dev/null | sort | head -1; }
_record_for_run() {
  if [[ -f "$1/.dispatch-results/$2.md" ]]; then
    printf '%s/.dispatch-results/%s.md\n' "$1" "$2"
  fi
}

# ── detached is the default (no --lifecycle flag → detached) ────────────────
case_detached_is_default() {
  local name="lifecycle/detached is the default when --lifecycle is omitted"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 >/dev/null 2>&1; wait_code=$?
  set -e
  if [[ "$code" -eq 0 ]] \
    && [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]] \
    && [[ -n "$(_first_runspec "$work")" ]] \
    && [[ "$wait_code" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code run_id=${run_id:-missing} runspec=$(_first_runspec "$work") wait=$wait_code"
  fi
  rm -rf "$work" "$bindir"
}

# ── explicit --lifecycle foreground writes no run-spec ───────────────────────
case_foreground_explicit_no_runspec() {
  local name="lifecycle/--lifecycle foreground writes no run-spec"
  should_run "$name" || return 0
  local work brief bindir out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle foreground 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] \
    && grep -q '^OK$' <<<"$out" \
    && [[ -n "$(_first_record "$work")" ]] \
    && [[ -z "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code runspec=$(_first_runspec "$work") tail=$(tail -3 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ── default lifecycle: end-to-end run_id capture → wait → ok record ─────────
# Regression for the primary caller pattern after the default flip to detached:
# bare dispatch (no --lifecycle flag) must return a run_id, dispatch wait must
# resolve, and the terminal dispatch record must reach state "ok".
case_default_detach_terminal_record_is_ok() {
  local name="lifecycle/default (no --lifecycle): run_id capture → wait → ok record"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code record
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -ne 0 || ! "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]]; then
    fail "$name" "dispatch run failed or returned no run_id: code=$code run_id=${run_id:-empty}"
    rm -rf "$work" "$bindir"; return
  fi
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 15 >/dev/null 2>&1; wait_code=$?
  set -e
  record="$(_record_for_run "$work" "$run_id")"
  if [[ "$wait_code" -eq 0 && -n "$record" ]] \
    && grep -q '^final_state: "ok"$' "$record" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "wait=$wait_code record=${record:-absent} state=$(grep 'final_state' "$record" 2>/dev/null | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ── detached launches supervisor and returns run_id immediately ──────────────
# Deterministic proof: dispatch returns while the adapter is still blocked on
# release_fifo. After reading from started_fifo (FIFO-based — no sleep) we
# know: dispatch already returned AND adapter is live but not yet finished
# (so no record). Releasing the FIFO then lets dispatch wait resolve normally.
case_detached_true_detach() {
  local name="lifecycle/detached launches supervisor and returns run_id"
  should_run "$name" || return 0
  local work brief bindir err code record runspec pid_file log_file wait_out wait_code
  local run_id started_fifo release_fifo _started_dummy
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"
  err="$(mktemp)"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>"$err")"; code=$?
  set -e

  runspec="$(_first_runspec "$work")"
  pid_file="$work/.agent-trace/$run_id.supervisor.pid"
  log_file="$work/.agent-trace/$run_id.supervisor.log"

  # Block until adapter signals it started via FIFO — no sleep. Adapter opens
  # started_fifo O_RDWR (non-blocking) then writes "started" before blocking on
  # release_fifo, keeping the write-side fd open so our O_RDONLY read unblocks.
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "adapter did not start within 10s; err=$(tail -3 "$err" | tr '\n' '|')"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$err" "$started_fifo" "$release_fifo"
    return
  fi

  # At this point: dispatch has returned (run_id in hand) AND adapter is still
  # blocked on release_fifo (record cannot exist yet). Deterministic proof.
  local record_while_blocked snap_ok=0
  record_while_blocked="$(_record_for_run "$work" "$run_id")"

  # Verify runspec fields and snapshot content while adapter is still blocked
  # (snapshot exists during adapter execution; supervisor cleans it up on exit).
  if [[ -n "$runspec" ]] && grep -q '^schema_version=2$' "$runspec" \
    && grep -q '^adapter=codex$' "$runspec" && grep -q '^cd_arg=' "$runspec" \
    && grep -q '^native_b64:$' "$runspec"; then
    local _snap
    _snap="$(grep '^brief_file=' "$runspec" | cut -d= -f2-)"
    if [[ "$_snap" =~ ^/tmp/brief-run-[A-Za-z0-9]+-[A-Za-z0-9]+\.md$ ]] \
      && diff "$brief" "$_snap" >/dev/null 2>&1; then
      snap_ok=1
    fi
  fi

  # Unblock adapter (O_RDWR open prevents blocking if adapter already exited).
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  set +e
  wait_out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 2>&1)"; wait_code=$?
  set -e
  record="$(_record_for_run "$work" "$run_id")"

  if [[ "$code" -eq 0 ]] \
    && [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]] \
    && [[ -z "$record_while_blocked" ]] \
    && [[ "$snap_ok" -eq 1 ]] \
    && [[ "$wait_code" -eq 0 ]] \
    && grep -q "state: ok  exit: 0" <<<"$wait_out" \
    && [[ -n "$record" ]] && grep -q '^final_state: "ok"$' "$record" \
    && [[ -s "$pid_file" ]] \
    && [[ -s "$log_file" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code wait=$wait_code run_id=${run_id:-missing} blocked_record=${record_while_blocked:-absent} snap_ok=$snap_ok record=${record:-missing} runspec=${runspec:-missing} err=$(tail -3 "$err" | tr '\n' '|') wait=$(tail -3 <<<"$wait_out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$err" "$started_fifo" "$release_fifo"
}

# ── adapter failure under detached is reported by dispatch wait ──────────────
case_dispatch_wait_failure_propagates() {
  local name="lifecycle/dispatch wait propagates detached adapter failure"
  should_run "$name" || return 0
  local work brief bindir code run_id wait_code record
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 7
  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"; code=$?
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 >/dev/null 2>&1; wait_code=$?
  set -e
  record="$(_record_for_run "$work" "$run_id")"
  if [[ "$code" -eq 0 && "$wait_code" -eq 7 ]] \
    && [[ -n "$record" ]] && grep -q '^final_state: "failed"$' "$record"; then
    pass "$name"
  else
    fail "$name" "code=$code wait=$wait_code record=${record:-missing}"
  fi
  rm -rf "$work" "$bindir"
}

case_dispatch_wait_timeout() {
  local name="lifecycle/dispatch wait timeout exits 124"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code err started_fifo release_fifo
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  # Blocking adapter: dispatch wait --timeout 1 times out while adapter is
  # still blocked; no wall-clock sleep needed.
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"
  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"; code=$?
  err="$(PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 1 2>&1 >/dev/null)"; wait_code=$?
  set -e
  # Release adapter (O_RDWR open prevents blocking if adapter already exited).
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
  if [[ "$code" -eq 0 && "$wait_code" -eq 124 ]] && grep -qi 'timed out' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code wait=$wait_code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  # Wait for the detached supervisor to finish before cleanup so that
  # rm -rf does not race with the supervisor still writing to .agent-trace.
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 >/dev/null 2>&1 || true
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

case_dispatch_wait_not_found() {
  local name="lifecycle/dispatch wait invalid run_id exits 2"
  should_run "$name" || return 0
  local work code err
  work="$(mktemp -d)"; git init -q "$work"
  set +e
  err="$("$PMCTL" dispatch wait unknown-run-id --cd "$work" 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'invalid run_id' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

case_dispatch_wait_requires_cd() {
  local name="lifecycle/dispatch wait requires --cd"
  should_run "$name" || return 0
  local code err
  set +e
  err="$("$PMCTL" dispatch wait run-20260618T000000Z-abcdef 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi -- '--cd' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
}

# ── invalid --lifecycle value is rejected ────────────────────────────────────
case_invalid_lifecycle_value() {
  local name="lifecycle/invalid --lifecycle value rejected"
  should_run "$name" || return 0
  local work brief code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  set +e
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle bogus 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'invalid --lifecycle' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

# ── detached + --print-cmd is incompatible ───────────────────────────────────
case_detached_print_cmd_incompatible() {
  local name="lifecycle/detached + --print-cmd rejected"
  should_run "$name" || return 0
  local work brief code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  set +e
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached --print-cmd 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'incompatible with --print-cmd' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

# ── detached rejects an ineligible adapter BEFORE launching the executor ──────
case_detached_ineligible_rejected() {
  local name="lifecycle/detached ineligible adapter rejected pre-launch"
  should_run "$name" || return 0
  local work brief bindir code out
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  # Simulate a host-native (non-detachable) adapter via override; codex is a real
  # cli-subprocess adapter, so the override is the only way to exercise the gate.
  pmctl_dispatch_detach_eligible() { printf 'fake: not detach-eligible\n' >&2; return 1; }
  set +e
  out="$(PATH="$bindir:$PATH" pmctl_dispatch_run "$REPO_ROOT" --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>&1)"; code=$?
  set -e
  unset -f pmctl_dispatch_detach_eligible
  # shellcheck source=scripts/lib/pmctl-dispatch.sh
  . "$SCRIPT_DIR/lib/pmctl-dispatch.sh"
  if [[ "$code" -eq 2 ]] \
    && [[ -z "$(_first_record "$work")" ]] \
    && [[ -z "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code record=$(_first_record "$work") runspec=$(_first_runspec "$work")"
  fi
  rm -rf "$work" "$bindir"
}

# ── detach-eligibility gate derives from runner_kind (unit) ──────────────────
case_detach_eligible_unit() {
  local name="lifecycle/detach-eligibility derives from runner_kind"
  should_run "$name" || return 0
  local root code_cli code_host code_missing code_unknown
  root="$(mktemp -d)"
  mkdir -p "$root/adapters/acli" "$root/adapters/ahost" "$root/adapters/anone" "$root/adapters/abad"
  printf 'runner_kind: cli-subprocess\n' > "$root/adapters/acli/adapter.yaml"
  printf 'runner_kind: host-native\n'    > "$root/adapters/ahost/adapter.yaml"
  printf 'name: anone\n'                 > "$root/adapters/anone/adapter.yaml"
  printf 'runner_kind: nonsense\n'       > "$root/adapters/abad/adapter.yaml"
  set +e
  pmctl_dispatch_detach_eligible "$root" acli  >/dev/null 2>&1; code_cli=$?
  pmctl_dispatch_detach_eligible "$root" ahost >/dev/null 2>&1; code_host=$?
  pmctl_dispatch_detach_eligible "$root" anone >/dev/null 2>&1; code_missing=$?
  pmctl_dispatch_detach_eligible "$root" abad  >/dev/null 2>&1; code_unknown=$?
  set -e
  if [[ "$code_cli" -eq 0 && "$code_host" -eq 1 && "$code_missing" -eq 2 && "$code_unknown" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "cli=$code_cli host=$code_host missing=$code_missing unknown=$code_unknown"
  fi
  rm -rf "$root"
}

# ── config dispatch.lifecycle = detached activates detached ──────────────────
case_config_lifecycle_detached() {
  local name="lifecycle/config dispatch.lifecycle=detached activates detached"
  should_run "$name" || return 0
  local work brief bindir cfg code run_id wait_code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  cfg="$(mktemp)"; printf 'dispatch.lifecycle = detached\n' > "$cfg"
  set +e
  run_id="$(PM_DISPATCH_CONFIG_FILE="$cfg" PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 >/dev/null 2>&1; wait_code=$?
  set -e
  if [[ "$code" -eq 0 && "$wait_code" -eq 0 ]] && [[ -n "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code wait=$wait_code runspec=$(_first_runspec "$work")"
  fi
  rm -rf "$work" "$bindir"; rm -f "$cfg"
}

# ── config dispatch.lifecycle = foreground opts back to foreground ────────────
case_config_lifecycle_foreground() {
  local name="lifecycle/config dispatch.lifecycle=foreground restores foreground with no --lifecycle flag"
  should_run "$name" || return 0
  local work brief bindir cfg code out
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  cfg="$(mktemp)"; printf 'dispatch.lifecycle = foreground\n' > "$cfg"
  set +e
  out="$(PM_DISPATCH_CONFIG_FILE="$cfg" PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  # foreground: exits with adapter exit code, no run-spec written, dispatch record present
  if [[ "$code" -eq 0 ]] \
    && grep -q '^OK$' <<<"$out" \
    && [[ -z "$(_first_runspec "$work")" ]] \
    && [[ -n "$(_first_record "$work")" ]]; then
    pass "$name"
  else
    local _rs _rc
    _rs="$(_first_runspec "$work")"; _rc="$(_first_record "$work")"
    fail "$name" "code=$code runspec=${_rs:-absent} record=${_rc:-absent} out=$(tail -2 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$cfg"
}

# ── parent brief snapshot survives caller cleanup of temp brief ───────────────
case_detached_brief_snapshot_survives_cleanup() {
  local name="lifecycle/detached: supervisor snapshot survives caller cleanup of temp brief"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"; code=$?
  set -e
  # Simulate caller cleanup: remove the original temp brief immediately.
  rm -f "$brief"
  # The supervisor must still complete from its durable snapshot.
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 >/dev/null 2>&1; wait_code=$?
  set -e
  if [[ "$code" -eq 0 && "$wait_code" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code wait=$wait_code (brief removed after dispatch returned)"
  fi
  rm -rf "$work" "$bindir"
}

# ── config --lifecycle flag beats config default ─────────────────────────────
case_flag_beats_config() {
  local name="lifecycle/--lifecycle foreground overrides config detached"
  should_run "$name" || return 0
  local work brief bindir cfg code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  cfg="$(mktemp)"; printf 'dispatch.lifecycle = detached\n' > "$cfg"
  set +e
  PM_DISPATCH_CONFIG_FILE="$cfg" PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle foreground >/dev/null 2>&1; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && [[ -z "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code runspec=$(_first_runspec "$work")"
  fi
  rm -rf "$work" "$bindir"; rm -f "$cfg"
}

# ── supervisor is not a bypass: a tampered run-spec is re-validated ───────────
# Writes a schema-v2 run-spec. Extra base64-encoded native args may be appended.
_write_runspec() {
  local path="$1" adapter="$2" work="$3" brief="$4"; shift 4
  {
    printf 'schema_version=2\n'
    printf 'run_id=run-20260617T000000Z-aaaaaa\n'
    printf 'adapter=%s\n' "$adapter"
    printf 'work_dir=%s\n' "$work"
    printf 'cd_arg=%s\n' "$work"
    printf 'brief_file=%s\n' "$brief"
    printf 'model=\n'
    printf 'created_ts=2026-06-17T00:00:00Z\n'
    printf 'print_cmd=0\n'
    printf 'native_b64:\n'
    local a
    for a in "$@"; do
      printf '%s\n' "$(printf '%s' "$a" | base64 | tr -d '\n')"
    done
  } > "$path"
}

case_supervisor_rejects_unroutable() {
  local name="supervisor/run-spec with non-routable adapter rejected"
  should_run "$name" || return 0
  local work brief spec code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/tamper.runspec"; mkdir -p "$work/.agent-trace"
  _write_runspec "$spec" "definitelynotanadapter" "$work" "$brief"
  set +e
  err="$(bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  # The adapter is refused by the shared security preflight (file-existence check
  # fires before the route check; either refusal is correct) and no executor runs.
  if [[ "$code" -eq 2 ]] \
    && grep -qiE 'unknown adapter|not a routable executor' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

case_supervisor_rejects_traversal_name() {
  local name="supervisor/run-spec with path-traversal adapter name rejected"
  should_run "$name" || return 0
  local work brief spec code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/tamper.runspec"; mkdir -p "$work/.agent-trace"
  _write_runspec "$spec" "../../etc" "$work" "$brief"
  set +e
  err="$(bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'invalid adapter name' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

case_supervisor_missing_spec() {
  local name="supervisor/missing run-spec rejected"
  should_run "$name" || return 0
  local code err
  set +e
  err="$(bash "$SUPERVISOR" --run-spec /no/such/runspec 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'run-spec not found' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
}

# ── supervisor rejects a malformed brief BEFORE launching the executor ────────
case_supervisor_rejects_malformed_brief() {
  local name="supervisor/run-spec with malformed brief rejected before launch"
  should_run "$name" || return 0
  local work bad bindir spec code err
  work="$(mktemp -d)"; git init -q "$work"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  # A guard-allowed /tmp/brief-*.md path that fails brief-validate (missing
  # required schema fields). pmctl dispatch run would reject it; so must the
  # supervisor, before any executor runs.
  bad="/tmp/brief-lifecycle-malformed-$$.md"; printf 'not: a valid brief\n' > "$bad"
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  _write_runspec "$spec" "codex" "$work" "$bad"
  set +e
  err="$(PATH="$bindir:$PATH" bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  local record
  record="$(_first_record "$work")"
  if [[ "$code" -eq 2 ]] \
    && grep -qiE 'brief failed validation|brief validation failed' <<<"$err" \
    && [[ -n "$record" ]] && grep -q '^final_state: "failed"$' "$record"; then
    pass "$name"
  else
    fail "$name" "code=$code record=${record:-missing} err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$bad"
}


# ── supervisor rejects native args that smuggle in --brief-file ──────────────
case_supervisor_rejects_native_brief_smuggle() {
  local name="supervisor/run-spec native args carrying --brief-file rejected"
  should_run "$name" || return 0
  local work brief evil bindir spec code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  evil="/tmp/brief-lifecycle-evil-$$.md"; cp "$brief" "$evil"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  # The trusted scalars name $brief, but native args try to override the brief the
  # adapter receives with $evil — the supervisor must refuse the split.
  _write_runspec "$spec" "codex" "$work" "$brief" "--brief-file" "$evil"
  set +e
  err="$(PATH="$bindir:$PATH" bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] \
    && grep -qi 'native args must not contain --brief-file' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$evil"
}

# Emit a schema-v2 run-spec with per-field control. An empty value omits that
# line entirely (to exercise missing-field validation). Args after `--` are raw
# native passthrough args, base64-encoded into the native_b64 section.
_emit_runspec() {
  local file="$1" schema="$2" rid="$3" adapter="$4" work="$5" cd="$6" brief="$7" pc="$8"; shift 8
  [[ "${1:-}" == "--" ]] && shift
  {
    [[ -n "$schema" ]] && printf 'schema_version=%s\n' "$schema"
    [[ -n "$rid" ]] && printf 'run_id=%s\n' "$rid"
    [[ -n "$adapter" ]] && printf 'adapter=%s\n' "$adapter"
    [[ -n "$work" ]] && printf 'work_dir=%s\n' "$work"
    [[ -n "$cd" ]] && printf 'cd_arg=%s\n' "$cd"
    [[ -n "$brief" ]] && printf 'brief_file=%s\n' "$brief"
    printf 'model=\n'
    printf 'created_ts=2026-06-17T00:00:00Z\n'
    [[ -n "$pc" ]] && printf 'print_cmd=%s\n' "$pc"
    printf 'native_b64:\n'
    local a
    for a in "$@"; do printf '%s\n' "$(printf '%s' "$a" | base64 | tr -d '\n')"; done
  } > "$file"
}

# Drive the supervisor with a crafted spec; assert exit 2, a message match, and
# that no executor record was produced (the spec was rejected before launch).
_expect_supervisor_reject() {
  local name="$1" work="$2" spec="$3" pattern="$4"
  local code err
  set +e
  err="$(bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qiE "$pattern" <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
}

_RID_OK="run-20260617T000000Z-aaaaaa"

case_supervisor_rejects_malformed_base64() {
  local name="supervisor/run-spec with malformed base64 native arg rejected"
  should_run "$name" || return 0
  local work brief spec
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  {
    printf 'schema_version=2\nrun_id=%s\nadapter=codex\nwork_dir=%s\ncd_arg=%s\nbrief_file=%s\nmodel=\ncreated_ts=2026-06-17T00:00:00Z\nprint_cmd=0\nnative_b64:\n' "$_RID_OK" "$work" "$work" "$brief"
    printf '@@@not-valid-base64@@@\n'
  } > "$spec"
  _expect_supervisor_reject "$name" "$work" "$spec" 'malformed base64'
  rm -rf "$work"
}

case_supervisor_rejects_bad_schema() {
  local name="supervisor/run-spec with unsupported schema_version rejected"
  should_run "$name" || return 0
  local work brief spec
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  _emit_runspec "$spec" 99 "$_RID_OK" codex "$work" "$work" "$brief" 0
  _expect_supervisor_reject "$name" "$work" "$spec" 'unsupported run-spec schema_version'
  rm -rf "$work"
}

case_supervisor_rejects_bad_runid() {
  local name="supervisor/run-spec with invalid run_id rejected"
  should_run "$name" || return 0
  local work brief spec
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  _emit_runspec "$spec" 2 "not-a-valid-runid" codex "$work" "$work" "$brief" 0
  _expect_supervisor_reject "$name" "$work" "$spec" 'invalid run_id'
  rm -rf "$work"
}

case_supervisor_rejects_missing_scalar() {
  local name="supervisor/run-spec missing brief_file scalar rejected"
  should_run "$name" || return 0
  local work spec
  work="$(mktemp -d)"; git init -q "$work"
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  # brief_file omitted (empty arg) -> missing-scalar validation fires.
  _emit_runspec "$spec" 2 "$_RID_OK" codex "$work" "$work" "" 0
  _expect_supervisor_reject "$name" "$work" "$spec" 'missing brief_file'
  rm -rf "$work"
}

case_supervisor_rejects_bad_printcmd() {
  local name="supervisor/run-spec with invalid print_cmd rejected"
  should_run "$name" || return 0
  local work brief spec
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  _emit_runspec "$spec" 2 "$_RID_OK" codex "$work" "$work" "$brief" 9
  _expect_supervisor_reject "$name" "$work" "$spec" 'invalid print_cmd'
  rm -rf "$work"
}

case_supervisor_rejects_cd_smuggle() {
  local name="supervisor/run-spec native args carrying --cd rejected"
  should_run "$name" || return 0
  local work brief spec
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  _emit_runspec "$spec" 2 "$_RID_OK" codex "$work" "$work" "$brief" 0 -- --cd /tmp
  _expect_supervisor_reject "$name" "$work" "$spec" 'native args must not contain --cd'
  rm -rf "$work"
}

# ── detached + auto-pack: the run-spec brief IS the augmented snapshot ─────────
# CC-402: detached + auto-pack is no longer rejected. When auto-pack finds hits it
# augments the brief with an auto_context: block; under detached, that augmented
# brief is snapshotted to the guardable /tmp path and recorded as the run-spec's
# trusted brief_file, so the supervisor validates == guards == executes one brief.
case_detached_autopack_snapshot_is_augmented() {
  local name="lifecycle/detached + auto-pack snapshots the augmented brief"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code runspec snap native_brief
  work="$(mktemp -d)"; git init -q "$work"
  # Seed indexable content so reuse-scan returns hits for the brief goal below.
  mkdir -p "$work/src"
  cat > "$work/src/alpha.sh" <<'SRC'
#!/usr/bin/env bash
alpha_beta_dispatch_helper() {
  printf 'alpha beta dispatch lifecycle helper\n'
}
SRC
  "$PMCTL" context index "$work" >/dev/null 2>/dev/null
  # Read-only brief (exempt from the retrieval gate) with a goal that matches the
  # seeded content, so the only behaviour under test is the augmented snapshot.
  brief="/tmp/brief-lifecycle-autopack-$$.md"
  _BRIEFS+=("$brief")
  cat > "$brief" <<EOF
schema_version: 1
working_dir: $work
goal: exercise the pmctl dispatch orchestrator shared flow
files:
  - read: $work/src/alpha.sh
acceptance:
  - dispatch exits 0
EOF
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached --auto-pack 2>/dev/null)"; code=$?
  set -e
  runspec="$(_first_runspec "$work")"
  snap=""; native_brief="present"
  if [[ -n "$runspec" ]]; then
    snap="$(grep '^brief_file=' "$runspec" | cut -d= -f2-)"
    # Trusted-scalar contract: --brief-file must NOT appear in the native passthrough.
    grep -q '^--brief-file$' "$runspec" || native_brief="absent"
  fi
  if [[ "$code" -eq 0 ]] \
    && [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]] \
    && [[ -n "$runspec" ]] \
    && [[ "$snap" == "/tmp/brief-${run_id}.md" ]] \
    && [[ -f "$snap" ]] \
    && grep -q '^auto_context:' "$snap" \
    && [[ "$native_brief" == "absent" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code run_id=${run_id:-missing} runspec=${runspec:-missing} snap=${snap:-missing} native_brief=$native_brief autoctx=$(grep -c '^auto_context:' "${snap:-/dev/null}" 2>/dev/null || echo 0)"
  fi
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 >/dev/null 2>&1 || true
  rm -rf "$work" "$bindir"
}

# ── supervisor preflight failure is observable through dispatch wait ──────────
# When the supervisor fails before execute_tail (e.g. brief not found), it now
# writes a failed dispatch record so dispatch wait resolves quickly instead of
# blocking until timeout.
case_supervisor_preflight_failure() {
  local name="lifecycle/supervisor preflight failure is observable through dispatch wait"
  should_run "$name" || return 0
  local work spec run_id bindir supervisor_code wait_out wait_code record
  work="$(mktemp -d)"; git init -q "$work"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  run_id="run-20260618T000000Z-pftest"
  mkdir -p "$work/.agent-trace"
  spec="$work/.agent-trace/$run_id.runspec"
  {
    printf 'schema_version=2\n'
    printf 'run_id=%s\n' "$run_id"
    printf 'adapter=codex\n'
    printf 'work_dir=%s\n' "$work"
    printf 'cd_arg=%s\n' "$work"
    printf 'brief_file=/tmp/brief-no-such-file-%s.md\n' "$$"
    printf 'model=\n'
    printf 'created_ts=2026-06-18T00:00:00Z\n'
    printf 'print_cmd=0\n'
    printf 'initial_state_written=0\n'
    printf 'native_b64:\n'
  } > "$spec"
  set +e
  PATH="$bindir:$PATH" bash "$SUPERVISOR" --run-spec "$spec" 2>/dev/null; supervisor_code=$?
  set -e
  record="$(_record_for_run "$work" "$run_id")"
  set +e
  wait_out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 5 2>&1)"; wait_code=$?
  set -e
  if [[ "$supervisor_code" -ne 0 ]] \
    && [[ -n "$record" ]] && grep -q '^final_state: "failed"$' "$record" \
    && [[ "$wait_code" -ne 0 && "$wait_code" -ne 124 ]]; then
    pass "$name"
  else
    fail "$name" "supervisor=$supervisor_code record=${record:-missing} wait=$wait_code wait_out=$(tail -2 <<<"$wait_out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ── supervisor execute_tail failure writes fallback dispatch record ────────────
# When execute_tail fails before writing the terminal dispatch record (e.g. an
# FSM state-store transition write failure), the supervisor writes a best-effort
# failed record so dispatch wait resolves quickly instead of timing out.
case_supervisor_tail_failure_writes_fallback_record() {
  local name="lifecycle/supervisor execute_tail failure writes fallback dispatch record"
  should_run "$name" || return 0
  local work brief spec bindir supervisor_code wait_out wait_code record run_id bad_state_root
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  run_id="run-20260618T000000Z-tailfail"
  mkdir -p "$work/.agent-trace"
  spec="$work/.agent-trace/$run_id.runspec"
  {
    printf 'schema_version=2\n'
    printf 'run_id=%s\n' "$run_id"
    printf 'adapter=codex\n'
    printf 'work_dir=%s\n' "$work"
    printf 'cd_arg=%s\n' "$work"
    printf 'brief_file=%s\n' "$brief"
    printf 'model=\n'
    printf 'created_ts=2026-06-18T00:00:00Z\n'
    printf 'print_cmd=0\n'
    printf 'initial_state_written=0\n'
    printf 'native_b64:\n'
  } > "$spec"
  # Point state root to a non-writable dir so FSM transition writes fail and
  # execute_tail exits non-zero before writing any dispatch record.
  bad_state_root="$(mktemp -d)"
  chmod 000 "$bad_state_root"
  set +e
  PM_DISPATCH_STATE_ROOT="$bad_state_root" PATH="$bindir:$PATH" \
    bash "$SUPERVISOR" --run-spec "$spec" 2>/dev/null; supervisor_code=$?
  set -e
  chmod 755 "$bad_state_root"
  record="$(_record_for_run "$work" "$run_id")"
  set +e
  wait_out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 5 2>&1)"; wait_code=$?
  set -e
  if [[ "$supervisor_code" -ne 0 ]] \
    && [[ -n "$record" ]] && grep -q '^final_state: "failed"$' "$record" \
    && [[ "$wait_code" -ne 0 && "$wait_code" -ne 124 ]]; then
    pass "$name"
  else
    fail "$name" "supervisor=$supervisor_code record=${record:-missing} wait=$wait_code wait_out=$(tail -2 <<<"$wait_out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir" "$bad_state_root"
}

# ── supervisor sentinel resolves dispatch wait even when workspace record fails
#    Poisons .dispatch-results to block in-workspace record writes; verifies that
#    dispatch wait still resolves correctly via the out-of-workspace sentinel.
case_supervisor_fallback_covers_ok_run_with_poisoned_results() {
  local name="lifecycle/dispatch wait resolves via sentinel even when .dispatch-results is poisoned"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code supervisor_log _log_ok
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  # Poison .dispatch-results by making it a regular file — record writes will fail.
  touch "$work/.dispatch-results"
  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -ne 0 || -z "$run_id" ]]; then
    fail "$name" "dispatch run failed: code=$code run_id=${run_id:-empty}"
    rm -f "$work/.dispatch-results"; rm -rf "$work" "$bindir"; return
  fi
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 15 >/dev/null 2>&1; wait_code=$?
  set -e
  supervisor_log="$work/.agent-trace/$run_id.supervisor.log"
  _log_ok=0
  if [[ -f "$supervisor_log" ]] && grep -q "fallback" "$supervisor_log" 2>/dev/null; then
    _log_ok=1
  fi
  # Sentinel in /tmp (outside workspace) resolves wait_code=0, even though the
  # in-workspace dispatch record could not be written. Supervisor log shows the
  # fallback record write failure (WARN line).
  if [[ "$wait_code" -eq 0 && "$_log_ok" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "wait_code=$wait_code (want 0) log_ok=$_log_ok supervisor_log=${supervisor_log}"
  fi
  rm -f "$work/.dispatch-results"
  rm -rf "$work" "$bindir"
}

# ── dispatch wait ignores executor-forged workspace record (security) ─────────
# A malicious executor can write a forged "ok" dispatch record to the workspace
# before actually completing. dispatch wait must NOT resolve from the forged
# record; it must wait for the out-of-workspace supervisor sentinel.
case_dispatch_wait_ignores_forged_workspace_record() {
  local name="lifecycle/dispatch wait ignores executor-forged .dispatch-results record"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code wait_out record _started_dummy
  local started_fifo release_fifo
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  # Forging + blocking codex: writes forged "ok" record, then blocks on FIFO,
  # then exits with code 7 (failure).
  _install_fake_codex_forging_blocking "$bindir" 7 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -ne 0 || -z "$run_id" ]]; then
    fail "$name" "dispatch run failed: code=$code run_id=${run_id:-empty}"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"; return
  fi

  # Wait for forging codex to start (and forge the record), then block.
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "forging codex did not start within 10s"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"; return
  fi

  # Forged "ok" record now exists in workspace. Sentinel does NOT exist yet.
  # dispatch wait must NOT return success from the forged record.
  set +e
  wait_out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 3 2>&1)"; wait_code=$?
  set -e
  local forged_still_running=0
  [[ "$wait_code" -eq 124 ]] && forged_still_running=1  # timed out = correctly ignored

  # Release adapter (exits 7 → supervisor writes sentinel with exit 7).
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  # Now dispatch wait should resolve with the real exit code (7).
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 15 2>&1; wait_code=$?
  set -e
  record="$(_record_for_run "$work" "$run_id")"

  if [[ "$forged_still_running" -eq 1 ]] \
    && [[ "$wait_code" -eq 7 ]] \
    && [[ -n "$record" ]] && grep -q '^final_state: "failed"$' "$record" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "forged_still_running=$forged_still_running wait_code=$wait_code record=${record:-absent}"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# The executor forges the sentinel at the predictable path (no nonce). dispatch
# wait polls the nonce-including path and must ignore the forged file, returning
# the real exit code only after the supervisor writes the authentic sentinel.
case_dispatch_wait_ignores_forged_sentinel() {
  local name="lifecycle/dispatch wait ignores executor-forged sentinel (wrong path, no nonce)"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code forged_path _started_dummy
  local started_fifo release_fifo
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  # Forging sentinel codex: writes forged "ok" sentinel at predictable path
  # (no nonce), then blocks on FIFO, then exits with code 7 (failure).
  _install_fake_codex_forging_sentinel_blocking "$bindir" 7 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -ne 0 || -z "$run_id" ]]; then
    fail "$name" "dispatch run failed: code=$code run_id=${run_id:-empty}"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"; return
  fi

  # Wait for forging codex to start (and forge the sentinel at wrong path).
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "forging codex did not start within 10s"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"; return
  fi

  # Forged sentinel at wrong path exists; real (nonce-including) sentinel does not.
  # dispatch wait must NOT resolve from the forged file.
  forged_path="/tmp/pm-supervisor-sentinel-$run_id"
  local forged_exists=0
  [[ -f "$forged_path" ]] && forged_exists=1

  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 3 >/dev/null 2>&1
  wait_code=$?
  set -e
  local forged_ignored=0
  [[ "$wait_code" -eq 124 ]] && forged_ignored=1  # timed out = correctly ignored

  # Release adapter (exits 7 → supervisor writes real sentinel).
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  # Now dispatch wait should resolve with the real exit code (7).
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 15 >/dev/null 2>&1
  wait_code=$?
  set -e

  rm -f "$forged_path" 2>/dev/null || true
  if [[ "$forged_exists" -eq 1 && "$forged_ignored" -eq 1 && "$wait_code" -eq 7 ]]; then
    pass "$name"
  else
    fail "$name" "forged_exists=$forged_exists forged_ignored=$forged_ignored wait_code=$wait_code"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# Trust model (CC-399 override): the executor runs under the same uid as the
# supervisor, so it CAN read the mode-700 key directory and write the correct
# nonce-bearing sentinel. This is by design — the executor is trusted (the
# operator's own login-authenticated agent), and the supervisor itself is also a
# same-user process. This test asserts that a same-user process holding the right
# nonce resolves the wait (the intended mechanism), distinct from a wrong-path
# forgery which is rejected (see case_dispatch_wait_ignores_forged_sentinel).
case_dispatch_wait_same_user_nonce_forgery_documented() {
  local name="lifecycle/same-user process with valid nonce resolves wait (trusted-executor model, CC-399 override)"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code _started_dummy
  local started_fifo release_fifo
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  # Adapter reads key to get nonce, forges sentinel at correct path, then blocks.
  _install_fake_codex_forging_nonce_sentinel_blocking "$bindir" 7 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -ne 0 || -z "$run_id" ]]; then
    fail "$name" "dispatch run failed: code=$code run_id=${run_id:-empty}"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"; return
  fi

  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "forging codex did not start within 10s"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"; return
  fi

  # Same-user process wrote a valid nonce sentinel; dispatch wait resolves it.
  # By the trusted-executor model, a same-user process can read the key directory.
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 3 >/dev/null 2>&1
  wait_code=$?
  set -e
  local nonce_resolved=0
  [[ "$wait_code" -eq 0 ]] && nonce_resolved=1  # resolved from the valid nonce sentinel

  # Release adapter. The test assertion (nonce_resolved) was determined before
  # this point; supervisor completing asynchronously is not load-bearing here.
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  if [[ "$nonce_resolved" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "expected valid nonce sentinel to resolve wait (wait_code=$wait_code want 0)"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# An executor removes the sentinel key file and forges a success workspace record
# before exiting. With the key absent there is no authenticated completion signal,
# so dispatch wait MUST return indeterminate (exit 3) and refuse to treat the
# executor-writable workspace record as authoritative success. Asserts the closed
# boundary: a forged workspace record can never make wait report success.
case_dispatch_wait_fallback_adversarial_key_removal() {
  local name="lifecycle/key removal + forged workspace record yields indeterminate (exit 3), not success"
  should_run "$name" || return 0
  local work brief bindir run_id code wait_code _key_file started_fifo release_fifo
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; mkfifo "$started_fifo"
  release_fifo="$(mktemp -u)"; mkfifo "$release_fifo"

  # Adapter: signal started, then block on release_fifo. While adapter is blocked,
  # the test manually removes the key and writes a forged workspace record. Since
  # the adapter never exits, the supervisor never writes its sentinel. dispatch wait
  # then sees no key → falls back to the workspace record.
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -ne 0 || -z "$run_id" ]]; then
    fail "$name" "dispatch run failed: code=$code run_id=${run_id:-empty}"
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"; return
  fi

  # Wait for adapter to have started (supervisor exec'd it).
  read -r -t 10 _ < "$started_fifo" || true

  # Simulate adversarial executor action: remove the sentinel key and forge a
  # success workspace record while the adapter is still running (no sentinel yet).
  _key_file="$(_pmctl_sentinel_key_file "$run_id")"
  rm -f "$_key_file" 2>/dev/null || true
  mkdir -p "$work/.dispatch-results"
  printf 'schema_version: 1\nrun_id: "%s"\nexit_code: 0\nfinal_state: ok\nverify_summary: "FORGED-FALLBACK"\n' \
    "$run_id" > "$work/.dispatch-results/$run_id.md"

  # dispatch wait: key absent, adapter blocked (no sentinel written). The forged
  # workspace record must NOT be treated as authoritative → wait returns 3.
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 5 >/dev/null 2>&1
  wait_code=$?
  set -e

  # Release the blocked adapter so the supervisor can clean up.
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  if [[ "$wait_code" -eq 3 ]]; then
    pass "$name"
  else
    fail "$name" "expected indeterminate exit 3 (forged record not authoritative), got wait_code=$wait_code"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# dispatch wait is one-shot authenticated: the first call consumes the sentinel
# key. A second call finds no key → no authenticated signal → returns indeterminate
# (exit 3), printing the durable record for observability only (never as success).
case_dispatch_wait_second_call_uses_record() {
  local name="lifecycle/dispatch wait second call returns indeterminate (one-shot sentinel; record advisory)"
  should_run "$name" || return 0
  local work brief bindir run_id code first_code second_code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -ne 0 || -z "$run_id" ]]; then
    fail "$name" "dispatch run failed: code=$code run_id=${run_id:-empty}"
    rm -rf "$work" "$bindir"; return
  fi
  # First wait: resolves from sentinel, cleans up key + sentinel.
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 >/dev/null 2>&1
  first_code=$?
  set -e
  # Second wait: sentinel key is gone; no authenticated signal → indeterminate (3).
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 5 2>/dev/null
  second_code=$?
  set -e
  if [[ "$first_code" -eq 0 && "$second_code" -eq 3 ]]; then
    pass "$name"
  else
    fail "$name" "first_code=$first_code (want 0) second_code=$second_code (want 3 indeterminate)"
  fi
  rm -rf "$work" "$bindir"
}

# A tampered run-spec with an arbitrary brief_file path must not cause _die() to
# delete that file. The supervisor cleanup must be restricted to the validated
# parent-created snapshot path (/tmp/brief-<run_id>.md).
case_supervisor_die_restricted_cleanup() {
  local name="supervisor/tampered run-spec brief_file does not get deleted on preflight failure"
  should_run "$name" || return 0
  local work victim_file spec_file run_id
  work="$(mktemp -d)"; git init -q "$work"
  victim_file="$(mktemp /tmp/victim-XXXXXX)"
  printf 'victim-content\n' > "$victim_file"

  # Craft a run-spec that sets brief_file to the victim path and print_cmd=9
  # (invalid) so the supervisor triggers _die() after parsing spec_brief_file.
  run_id="run-20260101T000000Z-deadbeef"
  spec_file="$(mktemp /tmp/runspec-XXXXXX)"
  printf 'schema_version=2\nrun_id=%s\nadapter=codex\nwork_dir=%s\ncd_arg=%s\n' \
    "$run_id" "$work" "$work" > "$spec_file"
  printf 'brief_file=%s\nmodel=default\ncreated_ts=2026-01-01T00:00:00Z\n' \
    "$victim_file" >> "$spec_file"
  printf 'print_cmd=9\ninitial_state_written=0\nnative_b64:\n' >> "$spec_file"

  local supervisor_log
  supervisor_log="$(mktemp)"
  set +e
  bash "$REPO_ROOT/scripts/dispatch-supervisor.sh" --run-spec "$spec_file" \
    >"$supervisor_log" 2>&1
  set -e

  if [[ -f "$victim_file" ]]; then
    pass "$name"
  else
    fail "$name" "victim file was deleted by supervisor _die() — tampered brief_file cleanup not restricted"
  fi
  rm -f "$victim_file" "$spec_file" "$supervisor_log" 2>/dev/null || true
  rm -rf "$work"
}

case_detached_is_default
case_foreground_explicit_no_runspec
case_default_detach_terminal_record_is_ok
case_detached_true_detach
case_dispatch_wait_failure_propagates
case_dispatch_wait_timeout
case_dispatch_wait_not_found
case_dispatch_wait_requires_cd
case_invalid_lifecycle_value
case_detached_print_cmd_incompatible
case_detached_ineligible_rejected
case_detach_eligible_unit
case_config_lifecycle_detached
case_config_lifecycle_foreground
case_detached_brief_snapshot_survives_cleanup
case_flag_beats_config
case_supervisor_rejects_unroutable
case_supervisor_rejects_traversal_name
case_supervisor_missing_spec
case_supervisor_rejects_malformed_brief
case_supervisor_rejects_native_brief_smuggle
case_supervisor_rejects_malformed_base64
case_supervisor_rejects_bad_schema
case_supervisor_rejects_bad_runid
case_supervisor_rejects_missing_scalar
case_supervisor_rejects_bad_printcmd
case_supervisor_rejects_cd_smuggle
case_detached_autopack_snapshot_is_augmented
case_supervisor_preflight_failure
case_supervisor_tail_failure_writes_fallback_record
case_supervisor_fallback_covers_ok_run_with_poisoned_results
case_dispatch_wait_ignores_forged_workspace_record
case_dispatch_wait_ignores_forged_sentinel
case_dispatch_wait_same_user_nonce_forgery_documented
case_dispatch_wait_fallback_adversarial_key_removal
case_dispatch_wait_second_call_uses_record
case_supervisor_die_restricted_cleanup
th_summary
