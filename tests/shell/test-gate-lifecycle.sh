#!/usr/bin/env bash
# Regression tests for the gate lifecycle axis (CC-423): --lifecycle
# foreground|detached, runtime/bin/gate-supervisor.sh's setsid/nohup detach, and
# `pmctl gate wait <gate_id>`'s nonce-authenticated sentinel resolution.
# Mirrors tests/shell/test-dispatch-lifecycle.sh's shape but is far shorter:
# runtime/bin/pr-gate.sh is a trusted in-repo script (not an arbitrary untrusted
# executor/brief), so gate-supervisor.sh has no run-spec/guard/adapter-
# validation layer to test — only the detach + authenticated-sentinel pattern.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/detached-launch.sh
. "$REPO_ROOT/runtime/lib/detached-launch.sh"

export PM_DISPATCH_STATE_ROOT="$tmp_root/gate-lifecycle-state"

# Isolate the sentinel key dir the same way test-dispatch-lifecycle.sh does
# for dispatch: point XDG_RUNTIME_DIR at a temp dir we own so the detached
# path is runnable everywhere (CI / sandboxed pr-gate codex included).
_TEST_XDG_RUNTIME_DIR="$tmp_root/xdg-runtime"
mkdir -p "$_TEST_XDG_RUNTIME_DIR" && chmod 700 "$_TEST_XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR="$_TEST_XDG_RUNTIME_DIR"

# The fake pr-gate.sh below exits immediately, so a 2s poll is pure dead time.
export PM_GATE_WAIT_POLL_INTERVAL="${PM_GATE_WAIT_POLL_INTERVAL:-0.1}"
_WAIT_OK="${PM_GATE_TEST_WAIT_TIMEOUT:-30}"

# Build a fixture repo root with the real pmctl-gate.sh + gate-supervisor.sh
# + their dependencies (state-paths.sh/portable.sh for sw_project_run_dir,
# gate-result-verify.sh for the post-wait structural check) so
# --lifecycle detached exercises the actual code, not a stand-in.
_mk_fixture_repo() {
  local fixture="$1"
  mkdir -p "$fixture/runtime/lib" "$fixture/runtime/bin"
  cp "$REPO_ROOT/runtime/lib/pmctl-gate.sh" "$fixture/runtime/lib/pmctl-gate.sh"
  cp "$REPO_ROOT/runtime/bin/gate-supervisor.sh" "$fixture/runtime/bin/gate-supervisor.sh"
  chmod +x "$fixture/runtime/bin/gate-supervisor.sh"
  for _lib in state-paths.sh portable.sh gate-result-verify.sh detached-launch.sh; do
    cp "$REPO_ROOT/runtime/lib/$_lib" "$fixture/runtime/lib/$_lib"
  done
}

# Install a fake pr-gate.sh that signals $started_fifo then blocks reading
# $release_fifo indefinitely -- a deterministic "never completes" fixture for
# the wait-timeout case, with no sleep-based synchronization (QA red line:
# tests/shell/test-dispatch-lifecycle.sh's _install_fake_codex_blocking uses the
# same FIFO handshake). O_RDWR opens on both FIFOs so writer/reader never
# block on each other regardless of open order.
_mk_fake_gate_blocking() {
  local fixture="$1" started_fifo="$2" release_fifo="$3"
  mkdir -p "$fixture/runtime/bin"
  cat > "$fixture/runtime/bin/pr-gate.sh" <<FAKEGATE
#!/usr/bin/env bash
exec 7<>"$started_fifo" 2>/dev/null || true
printf 'started\n' >&7 2>/dev/null || true
if [[ -p "$release_fifo" ]]; then
  read -r _dummy < "$release_fifo" 2>/dev/null || true
fi
exec 7>&- 2>/dev/null || true
exit 0
FAKEGATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"
}

# Install a fake pr-gate.sh that writes a structurally valid gate result under
# --run-dir and prints `result: <path>` (mirrors the real script's contract at
# runtime/bin/pr-gate.sh:1493), then exits with the given code.
_mk_fake_gate() {
  local fixture="$1" code="$2"
  mkdir -p "$fixture/runtime/bin"
  cat > "$fixture/runtime/bin/pr-gate.sh" <<FAKEGATE
#!/usr/bin/env bash
rd=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --run-dir) rd="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -n "\$rd" ]]; then
  mkdir -p "\$rd"
  cat > "\$rd/result.md" <<RESULT
---
gate_result_version: pr_gate_result_v1
final: $([[ $code -eq 0 ]] && printf GO || printf NO-GO)
tier: express
mode: sequential
most_severe: approve
---

# PR-Gate Result

## Gate Conclusion
Final: $([[ $code -eq 0 ]] && printf GO || printf NO-GO)
RESULT
  printf 'result: %s\n' "\$rd/result.md"
fi
exit $code
FAKEGATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"
}

# Install a fake pr-gate.sh that exits 0 (GO) but never writes a result file
# or prints a `result: <path>` line -- the pathological case the pr-gate
# result-integrity fix (CC-423 risk-reviewer finding) exists to catch: a
# sentinel that reports GO/NO-GO with no verifiable result behind it.
_mk_fake_gate_no_result() {
  local fixture="$1" code="${2:-0}"
  mkdir -p "$fixture/runtime/bin"
  cat > "$fixture/runtime/bin/pr-gate.sh" <<FAKEGATE
#!/usr/bin/env bash
exit $code
FAKEGATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"
}

# Install a fake pr-gate.sh that exits 0 (GO) and prints a \`result:\` line,
# but the file it points at is structurally invalid (no Final: line) -- the
# gate_result_verify rejection path, distinct from the missing-result path
# above.
_mk_fake_gate_corrupt_result() {
  local fixture="$1"
  mkdir -p "$fixture/runtime/bin"
  cat > "$fixture/runtime/bin/pr-gate.sh" <<'FAKEGATE'
#!/usr/bin/env bash
rd=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) rd="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$rd"
printf 'not a valid gate result\n' > "$rd/result.md"
printf 'result: %s\n' "$rd/result.md"
exit 0
FAKEGATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"
}

# Install a fake pr-gate.sh usage-error case: it exits 2 without a --run-dir
# or a result file at all (mirrors a real dispatch/argv failure path).
_mk_fake_gate_usage_error() {
  local fixture="$1"
  mkdir -p "$fixture/runtime/bin"
  cat > "$fixture/runtime/bin/pr-gate.sh" <<'FAKEGATE'
#!/usr/bin/env bash
printf 'Error: usage error\n' >&2
exit 2
FAKEGATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"
}

_run_gate_wrapper() {
  local fixture="$1"; shift
  local wrapper="$1"; shift
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$wrapper"
}

_wait_wrapper() {
  local fixture="$1"; shift
  local wrapper="$1"; shift
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
pmctl_gate_wait "$fixture" "\$@"
WRAPPER
  chmod +x "$wrapper"
}

# ---- 1: detached launch returns gate_id immediately, exit 0 ------------------
case_detached_launch_returns_gate_id() {
  local name="gate-lifecycle/detached launch returns gate_id only after supervisor readiness"
  should_run "$name" || return 0

  local fixture="$tmp_root/c1/fixture" work="$tmp_root/c1/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 0

  local run_wrapper="$tmp_root/c1/run"
  _run_gate_wrapper "$fixture" "$run_wrapper"

  local out code err_file="$tmp_root/c1/run.err"
  set +e; out="$("$run_wrapper" --cd "$work" --lifecycle detached 2>"$err_file")"; code=$?; set -e

  # stdout stays a single bare gate_id (command-substitution contract); the
  # ready-to-paste `pmctl gate wait <id> --cd <path>` hint lands on stderr.
  local err_out; err_out="$(cat "$err_file" 2>/dev/null)"
  if [[ "$code" -eq 0 ]] \
     && [[ "$out" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]] \
     && [[ "$err_out" == *"pmctl gate wait $out --cd"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out err=$err_out"
  fi
}

# ---- 1b: early supervisor death fails the launch, not a later wait -----------
case_detached_launch_fails_loud_on_early_supervisor_death() {
  local name="gate-lifecycle/detached launch fails loud when supervisor dies before readiness"
  should_run "$name" || return 0

  local fixture="$tmp_root/c1b/fixture" work="$tmp_root/c1b/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 0
  # Die before the real supervisor reaches its readiness publication point.
  sed -i 's/_write_ready || _die "failed to publish supervisor readiness evidence"/exit 97/' "$fixture/runtime/bin/gate-supervisor.sh"

  local run_wrapper="$tmp_root/c1b/run"
  _run_gate_wrapper "$fixture" "$run_wrapper"

  local out code
  set +e; out="$("$run_wrapper" --cd "$work" --lifecycle detached 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 2 ]] && [[ "$out" == *"exited before readiness"* ]] && [[ "$out" == *"--lifecycle foreground"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 1c: mismatched readiness identity is rejected before returning gate ID --
case_detached_launch_rejects_invalid_ready_identity() {
  local name="gate-lifecycle/detached launch rejects mismatched readiness identity"
  should_run "$name" || return 0
  local fixture="$tmp_root/c1c/fixture" work="$tmp_root/c1c/work"
  mkdir -p "$work"; _mk_fixture_repo "$fixture"; _mk_fake_gate "$fixture" 0
  # shellcheck disable=SC2016  # sed must match literal supervisor variables.
  sed -i 's/"pid=$_pid"/"pid=999999"/' "$fixture/runtime/bin/gate-supervisor.sh"
  local run_wrapper="$tmp_root/c1c/run" out code
  _run_gate_wrapper "$fixture" "$run_wrapper"
  set +e; out="$("$run_wrapper" --cd "$work" --lifecycle detached 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 2 ]] && [[ "$out" == *"invalid supervisor readiness evidence"* ]]; then pass "$name"; else fail "$name" "code=$code out=$out"; fi
}

# ---- 1d: invalid readiness timeout is rejected before supervisor polling -----
case_detached_launch_rejects_invalid_ready_timeout() {
  local name="gate-lifecycle/detached launch rejects invalid readiness timeout"
  should_run "$name" || return 0
  local fixture="$tmp_root/c1d/fixture" work="$tmp_root/c1d/work"
  mkdir -p "$work"; _mk_fixture_repo "$fixture"; _mk_fake_gate "$fixture" 0
  local run_wrapper="$tmp_root/c1d/run" out code
  _run_gate_wrapper "$fixture" "$run_wrapper"
  set +e; out="$(PM_GATE_READY_TIMEOUT=invalid "$run_wrapper" --cd "$work" --lifecycle detached 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 2 ]] && [[ "$out" == *"invalid PM_GATE_READY_TIMEOUT"* ]]; then pass "$name"; else fail "$name" "code=$code out=$out"; fi
}

case_detached_launch_accepts_terminal_evidence_after_capture_race() {
  local name="gate-lifecycle/detached launch accepts ready terminal evidence after initial identity capture race"
  should_run "$name" || return 0
  local fixture="$tmp_root/c1e/fixture" work="$tmp_root/c1e/work"
  mkdir -p "$work"; _mk_fixture_repo "$fixture"; _mk_fake_gate "$fixture" 0
  local run_wrapper="$tmp_root/c1e/run" out code
  # Override only the launcher's in-process capture. The detached supervisor
  # starts a separate shell and sources the unmodified fixture library, so it
  # still emits genuine ready and terminal sentinels.
  cat > "$run_wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
detached_launch_capture_identity() { return 1; }
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$run_wrapper"
  set +e; out="$("$run_wrapper" --cd "$work" --lifecycle detached 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 0 && "$out" == *"pmctl gate wait gate-"* && "$out" == *$'\ngate-'* ]]; then pass "$name"; else fail "$name" "code=$code out=$out"; fi
}

# ---- 1f: identity can die between capture and ready observation -------------
case_detached_launch_accepts_terminal_evidence_after_liveness_race() {
  local name="gate-lifecycle/detached launch accepts terminal evidence after captured identity dies"
  should_run "$name" || return 0
  local fixture="$tmp_root/c1f/fixture" work="$tmp_root/c1f/work" release="$tmp_root/c1f/release"
  mkdir -p "$work"; _mk_fixture_repo "$fixture"; _mk_fake_gate "$fixture" 0
  # Hold the child after it has started, then release it from the parent's
  # forced-dead liveness check. This deterministically exercises the window
  # where identity capture succeeded but ready + terminal arrive just after
  # the parent first observes that identity as dead.
  # shellcheck disable=SC2016  # sed must preserve the supervisor's env expansion.
  sed -i 's/_write_ready || _die "failed to publish supervisor readiness evidence"/while [[ ! -f "${PM_TEST_READY_RELEASE:-}" ]]; do sleep 0.01; done\n_write_ready || _die "failed to publish supervisor readiness evidence"/' "$fixture/runtime/bin/gate-supervisor.sh"

  local run_wrapper="$tmp_root/c1f/run" out code
  cat > "$run_wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
. "$fixture/runtime/lib/detached-launch.sh"
detached_launch_verify_identity() { : > "$release"; return 1; }
export PM_TEST_READY_RELEASE="$release"
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$run_wrapper"
  set +e; out="$("$run_wrapper" --cd "$work" --lifecycle detached 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 0 && "$out" == *"pmctl gate wait gate-"* && "$out" == *$'\ngate-'* ]]; then pass "$name"; else fail "$name" "code=$code out=$out"; fi
}

# ---- 2: gate wait resolves GO (exit 0) after supervisor completes ------------
case_wait_resolves_go() {
  local name="gate-lifecycle/gate wait resolves GO after supervisor completes"
  should_run "$name" || return 0

  local fixture="$tmp_root/c2/fixture" work="$tmp_root/c2/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 0

  local run_wrapper="$tmp_root/c2/run" wait_wrapper="$tmp_root/c2/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"

  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout "$_WAIT_OK" 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"state: GO"* ]] && [[ "$out" == *"result: "* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# A parent gate used to export gate_result_verify without its private helper
# closure. The nested wait saw the inherited public function, skipped its own
# library load, and rejected a valid result. The selected pmctl repository must
# replace any inherited same-name function with its complete verifier library.
case_wait_reloads_verifier_over_incomplete_export() {
  local name="gate-lifecycle/gate wait reloads verifier over incomplete inherited function"
  should_run "$name" || return 0

  local fixture="$tmp_root/c2b/fixture" work="$tmp_root/c2b/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 0

  local run_wrapper="$tmp_root/c2b/run" wait_wrapper="$tmp_root/c2b/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id out code
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"
  set +e
  out="$(
    # shellcheck disable=SC2317 # exported fixture is invoked by the child shell
    gate_result_verify() { _incomplete_inherited_gate_verifier "$@"; }
    export -f gate_result_verify
    "$wait_wrapper" "$gate_id" --cd "$work" --timeout "$_WAIT_OK" 2>&1
  )"
  code=$?
  set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"state: GO"* ]] \
      && [[ "$out" == *"Final: GO"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 3: gate wait resolves NO-GO (exit 1) -------------------------------------
case_wait_resolves_nogo() {
  local name="gate-lifecycle/gate wait resolves NO-GO"
  should_run "$name" || return 0

  local fixture="$tmp_root/c3/fixture" work="$tmp_root/c3/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 1

  local run_wrapper="$tmp_root/c3/run" wait_wrapper="$tmp_root/c3/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"

  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout "$_WAIT_OK" 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 1 ]] && [[ "$out" == *"state: NO-GO"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 4: gate wait resolves failed (exit 2, usage error) ----------------------
case_wait_resolves_failed() {
  local name="gate-lifecycle/gate wait resolves failed on usage error"
  should_run "$name" || return 0

  local fixture="$tmp_root/c4/fixture" work="$tmp_root/c4/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate_usage_error "$fixture"

  local run_wrapper="$tmp_root/c4/run" wait_wrapper="$tmp_root/c4/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"

  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout "$_WAIT_OK" 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 2 ]] && [[ "$out" == *"state: failed"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 5: gate wait on nonexistent/consumed gate_id returns 3 (indeterminate) --
case_wait_indeterminate_on_consumed_sentinel() {
  local name="gate-lifecycle/gate wait returns 3 for consumed/unknown gate_id"
  should_run "$name" || return 0

  local fixture="$tmp_root/c5/fixture" work="$tmp_root/c5/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 0

  local run_wrapper="$tmp_root/c5/run" wait_wrapper="$tmp_root/c5/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"

  # First wait consumes the sentinel + key file (one-shot).
  "$wait_wrapper" "$gate_id" --cd "$work" --timeout "$_WAIT_OK" >/dev/null 2>&1 || true

  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout 2 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 3 ]] && [[ "$out" == *"indeterminate"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 5b: a key without readiness is a failed launch, not a real timeout ------
case_wait_indeterminate_when_no_readiness_evidence() {
  local name="gate-lifecycle/gate wait classifies no readiness evidence as indeterminate"
  should_run "$name" || return 0

  local fixture="$tmp_root/c5b/fixture" work="$tmp_root/c5b/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  local wait_wrapper="$tmp_root/c5b/wait"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id="gate-20260722-000000-deadbe" nonce="test-no-readiness-nonce"
  mkdir -p "$XDG_RUNTIME_DIR/pm-gate-dispatch"
  printf '%s' "$nonce" > "$XDG_RUNTIME_DIR/pm-gate-dispatch/$gate_id"

  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout 1 2>&1)"; code=$?; set -e
  rm -f "$XDG_RUNTIME_DIR/pm-gate-dispatch/$gate_id"
  if [[ "$code" -eq 3 ]] && [[ "$out" == *"never reached supervisor readiness"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_wait_indeterminate_when_ready_supervisor_died() {
  local name="gate-lifecycle/gate wait classifies a dead ready supervisor as indeterminate"
  should_run "$name" || return 0
  local fixture="$tmp_root/c5c/fixture" work="$tmp_root/c5c/work"
  mkdir -p "$work"; _mk_fixture_repo "$fixture"
  local wait_wrapper="$tmp_root/c5c/wait" gate_id="gate-20260722-000000-deadbf" nonce="test-dead-ready-nonce"
  _wait_wrapper "$fixture" "$wait_wrapper"
  mkdir -p "$XDG_RUNTIME_DIR/pm-gate-dispatch"
  printf '%s' "$nonce" > "$XDG_RUNTIME_DIR/pm-gate-dispatch/$gate_id"
  local run_dir
  run_dir="$(PM_DISPATCH_STATE_ROOT="$PM_DISPATCH_STATE_ROOT" bash -c '. "$1/runtime/lib/state-paths.sh"; cd "$2"; sw_project_run_dir "$3"' _ "$fixture" "$work" "$gate_id")"
  mkdir -p "$run_dir"
  printf 'pid=999999\nstate=Z\npgid=999999\nstarttime=1\ncomm=bash\nisolated=1\nboot_id=\n' > "$run_dir/supervisor.identity"
  detached_launch_write_sentinel "$(detached_launch_sentinel_path "pm-gate-ready" "$gate_id" "$nonce")" "state=ready" "pid=999999" "starttime=1"
  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout 1 2>&1)"; code=$?; set -e
  rm -f "$XDG_RUNTIME_DIR/pm-gate-dispatch/$gate_id"
  if [[ "$code" -eq 3 ]] && [[ "$out" == *"died without terminal evidence"* ]]; then pass "$name"; else fail "$name" "code=$code out=$out"; fi
}

# ---- 6: gate wait times out (exit 124) when supervisor never completes -------
case_wait_times_out() {
  # No sleep-based synchronization (QA red line): the fake gate signals
  # $started_fifo the instant it launches, so the test blocks on a bounded
  # `read -t` of that FIFO to know the supervisor is genuinely running before
  # asserting the wait times out -- not a fixed sleep racing the poll loop.
  local name="gate-lifecycle/gate wait times out when supervisor never completes"
  should_run "$name" || return 0

  local fixture="$tmp_root/c6/fixture" work="$tmp_root/c6/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"

  local started_fifo release_fifo
  started_fifo="$(mktemp -u)"; release_fifo="$(mktemp -u)"
  mkfifo "$started_fifo" "$release_fifo"
  _mk_fake_gate_blocking "$fixture" "$started_fifo" "$release_fifo"

  local run_wrapper="$tmp_root/c6/run" wait_wrapper="$tmp_root/c6/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"

  local _started_dummy
  if ! read -r -t 10 _started_dummy < "$started_fifo"; then
    fail "$name" "fake pr-gate.sh never signaled started_fifo within 10s"
    { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
    rm -f "$started_fifo" "$release_fifo"
    return
  fi

  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout 1 2>&1)"; code=$?; set -e

  # Release the blocked fake gate so its process doesn't leak past this case,
  # then clean up the FIFOs.
  { exec 9<>"$release_fifo" && printf 'go\n' >&9 && exec 9>&-; } 2>/dev/null || true
  rm -f "$started_fifo" "$release_fifo"

  if [[ "$code" -eq 124 ]] && [[ "$out" == *"timed out"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 7: --lifecycle foreground behavior unchanged (backward-compat) ----------
case_foreground_unchanged() {
  local name="gate-lifecycle/--lifecycle foreground behaves like today"
  should_run "$name" || return 0

  local fixture="$tmp_root/c7/fixture" work="$tmp_root/c7/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  # Echo-args fake, distinguishable from the result-writing fake above: proves
  # the foreground exec path still invokes pr-gate.sh synchronously in-band
  # (no gate_id, no detach) exactly as it did before this ticket.
  cat > "$fixture/runtime/bin/pr-gate.sh" <<'FAKEGATE'
#!/usr/bin/env bash
printf 'fake-gate-args: %s\n' "$*"
exit 0
FAKEGATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"

  local run_wrapper="$tmp_root/c7/run"
  _run_gate_wrapper "$fixture" "$run_wrapper"

  local out code
  set +e; out="$("$run_wrapper" --cd "$work" --lifecycle foreground --tier express 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"fake-gate-args:"* ]] && [[ "$out" == *"--tier express"* ]] && [[ "$out" != gate-* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 8: detached rejects when sw_project_run_dir is unavailable --------------
case_detached_requires_state_paths() {
  local name="gate-lifecycle/--lifecycle detached hard-fails without state-paths.sh"
  should_run "$name" || return 0

  local fixture="$tmp_root/c8/fixture" work="$tmp_root/c8/work"
  mkdir -p "$fixture/runtime/lib" "$fixture/runtime/bin" "$work"
  cp "$REPO_ROOT/runtime/lib/pmctl-gate.sh" "$fixture/runtime/lib/pmctl-gate.sh"
  cp "$REPO_ROOT/runtime/bin/gate-supervisor.sh" "$fixture/runtime/bin/gate-supervisor.sh"
  chmod +x "$fixture/runtime/bin/gate-supervisor.sh"
  # Deliberately omit state-paths.sh/portable.sh.
  _mk_fake_gate "$fixture" 0

  local run_wrapper="$tmp_root/c8/run"
  _run_gate_wrapper "$fixture" "$run_wrapper"

  local out code
  set +e; out="$("$run_wrapper" --cd "$work" --lifecycle detached 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 2 ]] && [[ "$out" == *"sw_project_run_dir unavailable"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 9: verdict-like exits without a result are infrastructure failures ------
case_wait_fails_on_missing_result() {
  # CC-423 pr-gate finding (risk-reviewer, high): a wait must not report
  # GO/NO-GO when the supervisor did not observe the verified `result:`
  # handoff. Both an apparent GO (0) and NO-GO (1) are execution failures in
  # that state and must be normalized to failed/2 at the producer boundary.
  local name="gate-lifecycle/gate wait treats verdict exits without result as failed"
  should_run "$name" || return 0

  local gate_rc fixture work run_wrapper wait_wrapper gate_id out code
  for gate_rc in 0 1; do
    fixture="$tmp_root/c9-$gate_rc/fixture"
    work="$tmp_root/c9-$gate_rc/work"
    mkdir -p "$work"
    _mk_fixture_repo "$fixture"
    _mk_fake_gate_no_result "$fixture" "$gate_rc"

    run_wrapper="$tmp_root/c9-$gate_rc/run"
    wait_wrapper="$tmp_root/c9-$gate_rc/wait"
    _run_gate_wrapper "$fixture" "$run_wrapper"
    _wait_wrapper "$fixture" "$wait_wrapper"

    gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"
    set +e
    out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout "$_WAIT_OK" 2>&1)"
    code=$?
    set -e
    if [[ "$code" -ne 2 || "$out" != *"state: failed  exit: 2"* \
        || "$out" == *"state: GO"* || "$out" == *"state: NO-GO"* ]]; then
      fail "$name" "gate_rc=$gate_rc code=$code out=$out"
      return
    fi
  done
  pass "$name"
}

# ---- 10: GO sentinel with a structurally invalid result fails the wait -------
case_wait_fails_on_corrupt_result() {
  # CC-423 pr-gate finding (qa-tester, high): distinct from the missing-result
  # case above -- here a result file exists but gate_result_verify rejects it
  # (no Final: line), and the wait must still fail rather than trust it.
  local name="gate-lifecycle/gate wait fails when result fails gate_result_verify"
  should_run "$name" || return 0

  local fixture="$tmp_root/c10/fixture" work="$tmp_root/c10/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate_corrupt_result "$fixture"

  local run_wrapper="$tmp_root/c10/run" wait_wrapper="$tmp_root/c10/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"

  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout "$_WAIT_OK" 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 2 ]] && [[ "$out" == *"gate_result_verify rejected"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 10b: gate wait rejects a --cd whose partition doesn't own the result ----
case_wait_fails_on_cd_partition_mismatch() {
  # CC-423 pr-gate finding (architecture-reviewer, medium): --cd previously
  # played no role in completion lookup, making it structurally misleading as
  # a "required" flag. It now must recompute the SAME gate_run_dir the
  # detached launcher derived (via sw_project_run_dir keyed off --cd) and
  # reject a sentinel result that falls outside it.
  local name="gate-lifecycle/gate wait fails when --cd partition does not own the result"
  should_run "$name" || return 0

  local fixture="$tmp_root/c10b/fixture" work="$tmp_root/c10b/work" other_work="$tmp_root/c10b/other-work"
  mkdir -p "$work" "$other_work"
  # sw_project_run_dir partitions by git top-level; a plain non-repo dir
  # falls back to a shared "global" bucket, which would make work and
  # other_work collide into the SAME partition and defeat this test. `git
  # init` alone is enough for `rev-parse --show-toplevel` to resolve (no
  # commit needed), so give each its own throwaway repo root.
  git init -q "$work"
  git init -q "$other_work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 0

  local run_wrapper="$tmp_root/c10b/run" wait_wrapper="$tmp_root/c10b/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"

  # Wait under a DIFFERENT --cd than the one the gate was launched under --
  # sw_project_run_dir partitions by cwd hash, so this recomputes a different
  # expected run dir than the one the sentinel's result actually lives under.
  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$other_work" --timeout "$_WAIT_OK" 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 2 ]] && [[ "$out" == *"does not fall under the run dir"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 11: gate wait usage-error contract (invalid timeout / gate_id / --cd) ---
case_wait_usage_errors() {
  # CC-423 pr-gate finding (qa-tester, medium): the wait input-validation
  # branches (invalid --timeout, invalid gate_id, bare --cd) had no direct
  # coverage in this suite.
  local name="gate-lifecycle/gate wait rejects malformed usage (exit 2)"
  should_run "$name" || return 0

  local fixture="$tmp_root/c11/fixture" work="$tmp_root/c11/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"

  local wait_wrapper="$tmp_root/c11/wait"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local out code

  set +e; out="$("$wait_wrapper" gate-20260101-000000-abcdef --cd "$work" --timeout notanumber 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$out" != *"invalid --timeout"* ]]; then
    fail "$name" "invalid --timeout: code=$code out=$out"
    return
  fi

  set +e; out="$("$wait_wrapper" not-a-valid-gate-id --cd "$work" 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$out" != *"invalid gate_id"* ]]; then
    fail "$name" "invalid gate_id: code=$code out=$out"
    return
  fi

  # --cd is now optional (defaults to the caller's CWD git toplevel / $PWD),
  # so a bare `--cd` with no value is the remaining usage error on that flag.
  set +e; out="$("$wait_wrapper" gate-20260101-000000-abcdef --cd 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$out" != *"missing value for --cd"* ]]; then
    fail "$name" "bare --cd without value: code=$code out=$out"
    return
  fi

  pass "$name"
}

case_detached_launch_returns_gate_id
case_detached_launch_fails_loud_on_early_supervisor_death
case_detached_launch_rejects_invalid_ready_identity
case_detached_launch_rejects_invalid_ready_timeout
case_detached_launch_accepts_terminal_evidence_after_capture_race
case_detached_launch_accepts_terminal_evidence_after_liveness_race
case_wait_resolves_go
case_wait_reloads_verifier_over_incomplete_export
case_wait_resolves_nogo
case_wait_resolves_failed
case_wait_indeterminate_on_consumed_sentinel
case_wait_indeterminate_when_no_readiness_evidence
case_wait_indeterminate_when_ready_supervisor_died
case_wait_times_out
case_foreground_unchanged
case_detached_requires_state_paths
case_wait_fails_on_missing_result
case_wait_fails_on_corrupt_result
case_wait_fails_on_cd_partition_mismatch
case_wait_usage_errors

th_summary
