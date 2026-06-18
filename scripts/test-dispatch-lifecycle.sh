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
  local record_while_blocked
  record_while_blocked="$(_record_for_run "$work" "$run_id")"

  # Unblock adapter (O_RDWR open prevents blocking if adapter already exited).
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true

  set +e
  wait_out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch wait "$run_id" --cd "$work" --timeout 10 2>&1)"; wait_code=$?
  set -e
  record="$(_record_for_run "$work" "$run_id")"

  if [[ "$code" -eq 0 ]] \
    && [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]] \
    && [[ -z "$record_while_blocked" ]] \
    && [[ "$wait_code" -eq 0 ]] \
    && grep -q "state: ok  exit: 0" <<<"$wait_out" \
    && [[ -n "$record" ]] && grep -q '^final_state: "ok"$' "$record" \
    && [[ -n "$runspec" ]] && grep -q '^schema_version=2$' "$runspec" \
    && grep -q '^adapter=codex$' "$runspec" \
    && grep -q '^cd_arg=' "$runspec" \
    && { _snap="$(grep '^brief_file=' "$runspec" | cut -d= -f2-)"; \
         [[ "$_snap" =~ ^/tmp/brief-run-[A-Za-z0-9]+-[A-Za-z0-9]+\.md$ ]] \
         && diff "$brief" "$_snap" >/dev/null 2>&1; } \
    && grep -q '^native_b64:$' "$runspec" \
    && [[ -s "$pid_file" ]] \
    && [[ -s "$log_file" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code wait=$wait_code run_id=${run_id:-missing} blocked_record=${record_while_blocked:-absent} record=${record:-missing} runspec=${runspec:-missing} err=$(tail -3 "$err" | tr '\n' '|') wait=$(tail -3 <<<"$wait_out" | tr '\n' '|')"
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
    fail "$name" "code=$code runspec=${_first_runspec "$work":-absent} record=${_first_record "$work":-absent} out=$(tail -2 <<<"$out" | tr '\n' '|')"
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

# ── detached + auto-pack is rejected (deferred combination) ───────────────────
case_detached_autopack_rejected() {
  local name="lifecycle/detached + auto-pack rejected"
  should_run "$name" || return 0
  local work brief code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  set +e
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached --auto-pack 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] \
    && grep -qi 'does not yet support auto-pack' <<<"$err" \
    && [[ -z "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code runspec=$(_first_runspec "$work") err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
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

case_detached_is_default
case_foreground_explicit_no_runspec
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
case_detached_autopack_rejected
case_supervisor_preflight_failure
case_supervisor_tail_failure_writes_fallback_record
th_summary
