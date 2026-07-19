#!/usr/bin/env bash
# Regression tests for pmctl dispatch cancel / status (CC-495).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=runtime/lib/runner-kind.sh
. "$REPO_ROOT/runtime/lib/runner-kind.sh"
# shellcheck source=runtime/lib/executor-router.sh
. "$REPO_ROOT/runtime/lib/executor-router.sh"
# shellcheck source=runtime/lib/pmctl-guard.sh
. "$REPO_ROOT/runtime/lib/pmctl-guard.sh"
# shellcheck source=runtime/lib/pmctl-dispatch.sh
. "$REPO_ROOT/runtime/lib/pmctl-dispatch.sh"
# shellcheck source=runtime/lib/detached-launch.sh
. "$REPO_ROOT/runtime/lib/detached-launch.sh"
# shellcheck source=runtime/lib/state-paths.sh
. "$REPO_ROOT/runtime/lib/state-paths.sh"
th_init "$@"
export PM_DISPATCH_STATE_ROOT="$tmp_root/cancel-state"

_TEST_XDG_RUNTIME_DIR="$tmp_root/xdg-runtime"
mkdir -p "$_TEST_XDG_RUNTIME_DIR" && chmod 700 "$_TEST_XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR="$_TEST_XDG_RUNTIME_DIR"
export PM_DISPATCH_WAIT_POLL_INTERVAL="${PM_DISPATCH_WAIT_POLL_INTERVAL:-0.1}"
_WAIT_OK="${PM_DISPATCH_TEST_WAIT_TIMEOUT:-30}"

_BRIEFS=()
_mk_brief() {
  local work="$1" bf
  bf="/tmp/brief-cancel-$$-${#_BRIEFS[@]}.md"
  cat > "$bf" <<EOF
schema_version: 1
working_dir: $work
goal: exercise dispatch cancel
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

# shellcheck disable=SC2317
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

_run_trace_dir() { ( cd "$1" 2>/dev/null && printf '%s/.agent-trace\n' "$(sw_project_run_dir "$2")" ); }
_record_for_run() {
  if [[ -f "$1/.dispatch-results/$2.md" ]]; then
    printf '%s/.dispatch-results/%s.md\n' "$1" "$2"
  fi
}

# ── cancel: in-flight process group terminalized + wait exit 130 ────────────
# Behavior: cancel of a live detached run kills the isolated process group,
#          writes cancelled claim/record/sentinel, and wait returns exit 130.
# Steps: launch blocking detached run → cancel --grace 2 → wait → assert
#        cancelled claim/record and process gone.
case_dispatch_cancel_in_flight() {
  local name="lifecycle/dispatch cancel in-flight run terminates group and wait exits 130"
  should_run "$name" || return 0
  local work brief bindir run_id code cancel_code wait_code wait_out record
  local started_fifo release_fifo _started_dummy art_dir id_file claim_file pid
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -ne 0 || ! "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]]; then
    fail "$name" "dispatch failed code=$code run_id=${run_id:-empty}"
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "adapter did not start"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  # Identity is written before dispatch returns the run_id (no sleep poll).
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  id_file="$art_dir/$run_id.supervisor.identity"
  claim_file="$art_dir/$run_id.terminal"
  if [[ ! -f "$id_file" ]]; then
    fail "$name" "identity missing after dispatch returned (expected written before run_id)"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi
  pid="$(grep -m1 '^pid=' "$id_file" 2>/dev/null | cut -d= -f2-)" || pid=""

  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch cancel "$run_id" --cd "$work" --grace 2 >/dev/null 2>&1
  cancel_code=$?
  wait_out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout "$_WAIT_OK" 2>&1)"
  wait_code=$?
  set -e
  record="$(_record_for_run "$work" "$run_id")"

  # Release FIFO in case cancel did not kill (cleanup); ignore errors.
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  local proc_gone=1
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    proc_gone=0
  fi
  # After successful cancel, identity file is removed; check via claim + wait.
  if [[ "$cancel_code" -eq 0 && "$wait_code" -eq 130 ]] \
    && grep -q 'state: cancelled' <<<"$wait_out" \
    && [[ -n "$record" ]] && grep -q '^final_state: "cancelled"$' "$record" \
    && [[ -f "$claim_file" ]] && grep -q '^final_state=cancelled$' "$claim_file" \
    && [[ "$proc_gone" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_code wait=$wait_code proc_gone=$proc_gone claim=$(cat "$claim_file" 2>/dev/null | tr '\n' '|') wait_out=$(printf '%s' "$wait_out" | tr '\n' '|') record=$(grep final_state "$record" 2>/dev/null | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# ── cancel: already-terminal ok is not overwritten ──────────────────────────
# Behavior: cancel after natural ok completion exits 1 and leaves final_state=ok.
# Steps: detached run → wait (ok) → cancel → assert claim/record still ok.
case_dispatch_cancel_already_terminal() {
  local name="lifecycle/dispatch cancel does not overwrite existing ok terminal"
  should_run "$name" || return 0
  local work brief bindir run_id cancel_code wait_code record
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout "$_WAIT_OK" >/dev/null 2>&1
  wait_code=$?
  # Second wait consumes key; re-seed is not needed — cancel must still refuse
  # overwrite based on the durable terminal claim file.
  PATH="$bindir:$PATH" "$PMCTL" dispatch cancel "$run_id" --cd "$work" >/dev/null 2>&1
  cancel_code=$?
  set -e
  record="$(_record_for_run "$work" "$run_id")"
  local claim_file
  claim_file="$(_run_trace_dir "$work" "$run_id")/$run_id.terminal"

  if [[ "$wait_code" -eq 0 && "$cancel_code" -eq 1 ]] \
    && [[ -n "$record" ]] && grep -q '^final_state: "ok"$' "$record" \
    && [[ -f "$claim_file" ]] && grep -q '^final_state=ok$' "$claim_file"; then
    pass "$name"
  else
    fail "$name" "wait=$wait_code cancel=$cancel_code claim=$(cat "$claim_file" 2>/dev/null | tr '\n' '|') record=$(grep final_state "$record" 2>/dev/null | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ── cancel: identity mismatch fail-closed (no signal) ───────────────────────
# Behavior: forged starttime against a live decoy pid causes cancel exit 2
#          without killing the decoy.
# Steps: blocking detached run → rewrite identity to decoy sleep → cancel →
#        assert decoy still alive and cancel_rc=2.
case_dispatch_cancel_identity_mismatch() {
  local name="lifecycle/dispatch cancel identity mismatch refuses signal"
  should_run "$name" || return 0
  local work brief bindir run_id cancel_code started_fifo release_fifo _started_dummy
  local art_dir id_file sleep_pid
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"
  set -e
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "adapter did not start"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  # Identity is written before dispatch returns (no sleep poll).
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  id_file="$art_dir/$run_id.supervisor.identity"
  if [[ ! -f "$id_file" ]]; then
    fail "$name" "identity missing after dispatch returned"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  # Forge a different starttime while keeping a live decoy pid so verify fails
  # closed (PID reuse / identity mismatch) and cancel must not claim success
  # by killing the wrong process.
  tail -f /dev/null &
  sleep_pid=$!
  printf 'pid=%s\npgid=%s\nstarttime=1\ncomm=sleep\nisolated=1\n' "$sleep_pid" "$sleep_pid" >"$id_file"

  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch cancel "$run_id" --cd "$work" --grace 1 >/dev/null 2>&1
  cancel_code=$?
  set -e

  local decoy_alive=0
  if kill -0 "$sleep_pid" 2>/dev/null; then
    decoy_alive=1
  fi
  kill "$sleep_pid" 2>/dev/null || true
  wait "$sleep_pid" 2>/dev/null || true
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout "$_WAIT_OK" >/dev/null 2>&1 || true

  if [[ "$cancel_code" -eq 2 && "$decoy_alive" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_code decoy_alive=$decoy_alive (expected cancel=2 and decoy still alive)"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# ── cancel: workspace-forged pid is not authority ───────────────────────────
# Behavior: a workspace .agent-trace/*.supervisor.pid is ignored; cancel uses
#          the trusted run-dir identity and leaves the workspace decoy alive.
# Steps: blocking run → forge workspace pid to decoy → cancel → assert
#        cancel_rc=0 and decoy still alive.
case_dispatch_cancel_ignores_workspace_pid() {
  local name="lifecycle/dispatch cancel ignores workspace-forged supervisor.pid"
  should_run "$name" || return 0
  local work brief bindir run_id cancel_code started_fifo release_fifo _started_dummy
  local decoy_pid
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"
  set -e
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "adapter did not start"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  tail -f /dev/null &
  decoy_pid=$!
  mkdir -p "$work/.agent-trace"
  printf '%s\n' "$decoy_pid" >"$work/.agent-trace/$run_id.supervisor.pid"

  set +e
  # Real cancel uses trusted art_dir identity, not workspace pid. Should succeed
  # against the real supervisor and leave the decoy untouched until we kill it.
  PATH="$bindir:$PATH" "$PMCTL" dispatch cancel "$run_id" --cd "$work" --grace 2 >/dev/null 2>&1
  cancel_code=$?
  set -e

  local decoy_alive=0
  if kill -0 "$decoy_pid" 2>/dev/null; then
    decoy_alive=1
  fi
  kill "$decoy_pid" 2>/dev/null || true
  wait "$decoy_pid" 2>/dev/null || true
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  if [[ "$cancel_code" -eq 0 && "$decoy_alive" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_code decoy_alive=$decoy_alive"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# ── cancel: explicit --trace-dir is not cancel authority ────────────────────
# Behavior: even when --trace-dir points at a workspace-writable path that
#          contains a forged identity, cancel uses the state-derived trusted
#          dir and leaves a decoy process (forged target) alive.
# Steps: blocking run with --trace-dir=$work/evil-trace → forge identity in
#        evil-trace → cancel → assert success against real supervisor and
#        decoy still alive.
case_dispatch_cancel_ignores_explicit_trace_dir() {
  local name="lifecycle/dispatch cancel ignores explicit --trace-dir for authority"
  should_run "$name" || return 0
  local work brief bindir run_id started_fifo release_fifo _started_dummy
  local evil_trace decoy_pid trusted_id
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"
  evil_trace="$work/evil-trace"
  mkdir -p "$evil_trace"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached --trace-dir "$evil_trace" 2>/dev/null)"
  set -e
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "adapter did not start"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  trusted_id="$(_run_trace_dir "$work" "$run_id")/$run_id.supervisor.identity"
  if [[ ! -f "$trusted_id" ]]; then
    fail "$name" "trusted identity missing under state run dir"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  tail -f /dev/null &
  decoy_pid=$!
  # Forge authority-looking files under the explicit trace-dir (must be ignored).
  printf 'pid=%s\npgid=%s\nstarttime=1\ncomm=sleep\nisolated=1\n' "$decoy_pid" "$decoy_pid" \
    >"$evil_trace/$run_id.supervisor.identity"
  printf '%s\n' "$decoy_pid" >"$evil_trace/$run_id.supervisor.pid"

  local cancel_code decoy_alive=0
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch cancel "$run_id" --cd "$work" --grace 2 >/dev/null 2>&1
  cancel_code=$?
  set -e
  if kill -0 "$decoy_pid" 2>/dev/null; then
    decoy_alive=1
  fi
  kill "$decoy_pid" 2>/dev/null || true
  wait "$decoy_pid" 2>/dev/null || true
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  local claim
  claim="$(_run_trace_dir "$work" "$run_id")/$run_id.terminal"
  if [[ "$cancel_code" -eq 0 && "$decoy_alive" -eq 1 ]] \
    && [[ -f "$claim" ]] && grep -q '^final_state=cancelled$' "$claim" \
    && [[ ! -f "$evil_trace/$run_id.terminal" ]]; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_code decoy_alive=$decoy_alive claim=$(cat "$claim" 2>/dev/null | tr '\n' '|') evil_term=$(ls "$evil_trace" 2>/dev/null | tr '\n' ' ')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# ── status: lists in-flight runs ────────────────────────────────────────────
# Behavior: dispatch status reports in-flight while adapter is blocked.
# Steps: blocking detached run → status → assert "status: in-flight" for run_id.
case_dispatch_status_lists_in_flight() {
  local name="lifecycle/dispatch status lists in-flight run"
  should_run "$name" || return 0
  local work brief bindir run_id started_fifo release_fifo _started_dummy status_out
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"
  set -e
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "adapter did not start"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  set +e
  status_out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch status --cd "$work" 2>&1)"
  set -e
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout "$_WAIT_OK" >/dev/null 2>&1 || true

  if grep -q "run: $run_id  status: in-flight" <<<"$status_out"; then
    pass "$name"
  else
    fail "$name" "status=$(printf '%s' "$status_out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# ── status: lists terminal runs after completion ────────────────────────────
# Behavior: after wait resolves ok, status reports terminal final_state=ok.
# Steps: quick detached run → wait → status → assert terminal ok line.
case_dispatch_status_lists_terminal() {
  local name="lifecycle/dispatch status lists terminal run after ok"
  should_run "$name" || return 0
  local work brief bindir run_id status_out
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout "$_WAIT_OK" >/dev/null 2>&1
  status_out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch status --cd "$work" 2>&1)"
  set -e

  if grep -q "run: $run_id  status: terminal  final_state: ok" <<<"$status_out"; then
    pass "$name"
  else
    fail "$name" "status=$(printf '%s' "$status_out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ── cancel: record write failure still leaves wait-resolvable cancel ────────
# Behavior: if .dispatch-results cannot be written, cancel still publishes the
#          authenticated cancelled sentinel and claim; wait returns 130;
#          cancel command exits 2 for incomplete durable evidence.
# Steps: blocking run → poison .dispatch-results as a file → cancel → wait.
case_dispatch_cancel_record_write_failure() {
  local name="lifecycle/dispatch cancel incomplete record still wait-resolvable"
  should_run "$name" || return 0
  local work brief bindir run_id started_fifo release_fifo _started_dummy
  local cancel_code wait_code claim
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  _install_fake_codex_blocking "$bindir" 0 "$started_fifo" "$release_fifo"

  set +e
  run_id="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>/dev/null)"
  set -e
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "adapter did not start"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
    return
  fi

  # Poison workspace record path so hard record write fails.
  rm -rf "$work/.dispatch-results"
  printf 'not-a-dir\n' >"$work/.dispatch-results"

  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch cancel "$run_id" --cd "$work" --grace 2 >/dev/null 2>&1
  cancel_code=$?
  PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout "$_WAIT_OK" >/dev/null 2>&1
  wait_code=$?
  set -e
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  claim="$(_run_trace_dir "$work" "$run_id")/$run_id.terminal"
  if [[ "$cancel_code" -eq 2 && "$wait_code" -eq 130 ]] \
    && [[ -f "$claim" ]] && grep -q '^final_state=cancelled$' "$claim"; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_code wait=$wait_code claim=$(cat "$claim" 2>/dev/null | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$started_fifo" "$release_fifo"
}

# ── cancel: dead leader PID but live isolated PGID is still killed ──────────
# Behavior: when identity PID is gone but recorded isolated PGID still has
#          members, cancel kills the group before claiming cancelled.
# Steps: handcraft trusted identity (dead pid + live setsid group) + runspec +
#        key/nonce → cancel → assert group dead and cancelled claim.
case_dispatch_cancel_orphaned_process_group() {
  local name="lifecycle/dispatch cancel kills orphaned process group after leader exit"
  should_run "$name" || return 0
  command -v setsid >/dev/null 2>&1 || { pass "$name (SKIP: no setsid)"; return 0; }

  local work run_id art_dir id_file runspec key_file nonce leader child pgid
  local cancel_code claim group_gone=1 starttime
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-c49501"
  export _SW_REPO_ROOT="$work"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"

  # Isolated group: leader + long-lived child; then kill only the leader.
  setsid bash -c 'tail -f /dev/null & exec -a pm-sup-dead sleep 3600' >/dev/null 2>&1 & disown 2>/dev/null || true
  leader=$!
  # Capture identity while leader is alive.
  local _i
  for _i in 1 2 3 4 5 6 7 8 9 10; do
    [[ -r "/proc/$leader/stat" ]] && break
  done
  if ! detached_launch_capture_identity "$leader" "1" >"$art_dir/$run_id.supervisor.identity" 2>/dev/null; then
    kill -KILL "$leader" 2>/dev/null || true
    fail "$name" "failed to capture identity for leader=$leader"
    rm -rf "$work"
    return
  fi
  pgid="$(grep -m1 '^pgid=' "$art_dir/$run_id.supervisor.identity" | cut -d= -f2-)"
  # Kill leader only; child (tail) should remain in the process group.
  kill -KILL "$leader" 2>/dev/null || true

  # Minimal runspec so cancel accepts dispatch evidence.
  cat >"$art_dir/$run_id.runspec" <<EOF
schema_version=2
run_id=$run_id
adapter=codex
work_dir=$work
cd_arg=$work
brief_file=/tmp/brief-$run_id.md
model=
created_ts=2026-07-19T00:00:00Z
print_cmd=0
initial_state_written=1
native_b64:
EOF
  printf 'goal: cancel orphan fixture\n' >"/tmp/brief-$run_id.md"

  # Sentinel key so cancel can publish wait-resolvable cancelled outcome.
  key_file="$(_pmctl_sentinel_key_file "$run_id")"
  mkdir -p "$(dirname "$key_file")"
  chmod 700 "$(dirname "$key_file")" 2>/dev/null || true
  nonce="$(detached_launch_generate_nonce)"
  printf '%s' "$nonce" >"$key_file"

  set +e
  pmctl_dispatch_cancel "$REPO_ROOT" "$run_id" --cd "$work" --grace 2 >/dev/null 2>&1
  cancel_code=$?
  set -e

  claim="$art_dir/$run_id.terminal"
  if [[ -n "$pgid" ]] && kill -0 -- "-$pgid" 2>/dev/null; then
    group_gone=0
  fi
  # Cleanup any survivors.
  [[ -n "$pgid" ]] && kill -KILL -- "-$pgid" 2>/dev/null || true
  rm -f "/tmp/brief-$run_id.md" "$key_file" \
    "$(detached_launch_sentinel_path "pm-supervisor" "$run_id" "$nonce")" 2>/dev/null || true

  if [[ "$cancel_code" -eq 0 && "$group_gone" -eq 1 ]] \
    && [[ -f "$claim" ]] && grep -q '^final_state=cancelled$' "$claim"; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_code group_gone=$group_gone claim=$(cat "$claim" 2>/dev/null | tr '\n' '|') pgid=$pgid leader=$leader"
  fi
  unset _SW_REPO_ROOT
  rm -rf "$work"
}

# ── cancel: non-isolated live process refuses group kill ────────────────────
# Behavior: identity with isolated=0 and a live PID causes cancel to exit 2
#          without signaling the process or writing a cancelled claim.
# Steps: craft trusted identity (isolated=0) + runspec for a live decoy →
#        cancel → assert exit 2, decoy alive, no terminal claim.
case_dispatch_cancel_non_isolated_refuses_kill() {
  local name="lifecycle/dispatch cancel refuses non-isolated live process group"
  should_run "$name" || return 0
  local work run_id art_dir decoy cancel_code claim decoy_alive=0
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-c49502"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"

  tail -f /dev/null &
  decoy=$!
  disown "$decoy" 2>/dev/null || true
  # Force isolated=0 even if pid==pgid; cancel must refuse live non-isolated kill.
  printf 'pid=%s\npgid=%s\nstarttime=1\ncomm=tail\nisolated=0\n' "$decoy" "$decoy" \
    >"$art_dir/$run_id.supervisor.identity"
  # Use real starttime so verify matches, then force isolated=0.
  if detached_launch_capture_identity "$decoy" "0" >"$art_dir/$run_id.supervisor.identity" 2>/dev/null; then
    :
  else
    kill "$decoy" 2>/dev/null || true
    fail "$name" "could not capture identity for decoy"
    rm -rf "$work"
    return
  fi

  cat >"$art_dir/$run_id.runspec" <<EOF
schema_version=2
run_id=$run_id
adapter=codex
work_dir=$work
cd_arg=$work
brief_file=/tmp/brief-$run_id.md
model=
created_ts=2026-07-19T00:00:00Z
print_cmd=0
initial_state_written=1
native_b64:
EOF
  printf 'goal: non-isolated cancel fixture\n' >"/tmp/brief-$run_id.md"
  local key_file nonce
  key_file="$(_pmctl_sentinel_key_file "$run_id")"
  mkdir -p "$(dirname "$key_file")"
  chmod 700 "$(dirname "$key_file")" 2>/dev/null || true
  nonce="$(detached_launch_generate_nonce)"
  printf '%s' "$nonce" >"$key_file"

  set +e
  pmctl_dispatch_cancel "$REPO_ROOT" "$run_id" --cd "$work" --grace 1 >/dev/null 2>&1
  cancel_code=$?
  set -e
  if kill -0 "$decoy" 2>/dev/null; then
    decoy_alive=1
  fi
  kill "$decoy" 2>/dev/null || true
  wait "$decoy" 2>/dev/null || true
  claim="$art_dir/$run_id.terminal"
  rm -f "/tmp/brief-$run_id.md" "$key_file" 2>/dev/null || true

  if [[ "$cancel_code" -eq 2 && "$decoy_alive" -eq 1 && ! -f "$claim" ]]; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_code decoy_alive=$decoy_alive claim=$( [[ -f "$claim" ]] && echo present || echo absent )"
  fi
  rm -rf "$work"
}

case_dispatch_cancel_in_flight
case_dispatch_cancel_already_terminal
case_dispatch_cancel_identity_mismatch
case_dispatch_cancel_ignores_workspace_pid
case_dispatch_cancel_ignores_explicit_trace_dir
case_dispatch_cancel_record_write_failure
case_dispatch_cancel_orphaned_process_group
case_dispatch_cancel_non_isolated_refuses_kill
case_dispatch_status_lists_in_flight
case_dispatch_status_lists_terminal
th_summary
