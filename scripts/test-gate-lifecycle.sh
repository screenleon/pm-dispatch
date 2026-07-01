#!/usr/bin/env bash
# Regression tests for the gate lifecycle axis (CC-423): --lifecycle
# foreground|detached, scripts/gate-supervisor.sh's setsid/nohup detach, and
# `pmctl gate wait <gate_id>`'s nonce-authenticated sentinel resolution.
# Mirrors scripts/test-dispatch-lifecycle.sh's shape but is far shorter:
# scripts/pr-gate.sh is a trusted in-repo script (not an arbitrary untrusted
# executor/brief), so gate-supervisor.sh has no run-spec/guard/adapter-
# validation layer to test — only the detach + authenticated-sentinel pattern.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

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
  mkdir -p "$fixture/scripts/lib"
  cp "$REPO_ROOT/scripts/lib/pmctl-gate.sh" "$fixture/scripts/lib/pmctl-gate.sh"
  cp "$REPO_ROOT/scripts/gate-supervisor.sh" "$fixture/scripts/gate-supervisor.sh"
  chmod +x "$fixture/scripts/gate-supervisor.sh"
  for _lib in state-paths.sh portable.sh gate-result-verify.sh; do
    cp "$REPO_ROOT/scripts/lib/$_lib" "$fixture/scripts/lib/$_lib"
  done
}

# Install a fake pr-gate.sh that writes a structurally valid gate result under
# --run-dir and prints `result: <path>` (mirrors the real script's contract at
# scripts/pr-gate.sh:1493), then exits with the given code.
_mk_fake_gate() {
  local fixture="$1" code="$2" delay="${3:-0}"
  mkdir -p "$fixture/scripts"
  cat > "$fixture/scripts/pr-gate.sh" <<FAKEGATE
#!/usr/bin/env bash
sleep $delay
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
  chmod +x "$fixture/scripts/pr-gate.sh"
}

# Install a fake pr-gate.sh usage-error case: it exits 2 without a --run-dir
# or a result file at all (mirrors a real dispatch/argv failure path).
_mk_fake_gate_usage_error() {
  local fixture="$1"
  mkdir -p "$fixture/scripts"
  cat > "$fixture/scripts/pr-gate.sh" <<'FAKEGATE'
#!/usr/bin/env bash
printf 'Error: usage error\n' >&2
exit 2
FAKEGATE
  chmod +x "$fixture/scripts/pr-gate.sh"
}

_run_gate_wrapper() {
  local fixture="$1"; shift
  local wrapper="$1"; shift
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/scripts/lib/pmctl-gate.sh"
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
. "$fixture/scripts/lib/pmctl-gate.sh"
pmctl_gate_wait "$fixture" "\$@"
WRAPPER
  chmod +x "$wrapper"
}

# ---- 1: detached launch returns gate_id immediately, exit 0 ------------------
case_detached_launch_returns_gate_id() {
  local name="gate-lifecycle/detached launch returns gate_id immediately"
  should_run "$name" || return 0

  local fixture="$tmp_root/c1/fixture" work="$tmp_root/c1/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 0

  local run_wrapper="$tmp_root/c1/run"
  _run_gate_wrapper "$fixture" "$run_wrapper"

  local out code
  set +e; out="$("$run_wrapper" --cd "$work" --lifecycle detached 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
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

# ---- 6: gate wait times out (exit 124) when supervisor never completes -------
case_wait_times_out() {
  local name="gate-lifecycle/gate wait times out when supervisor never completes"
  should_run "$name" || return 0

  local fixture="$tmp_root/c6/fixture" work="$tmp_root/c6/work"
  mkdir -p "$work"
  _mk_fixture_repo "$fixture"
  _mk_fake_gate "$fixture" 0 5   # 5s delay, well past the 1s wait timeout below

  local run_wrapper="$tmp_root/c6/run" wait_wrapper="$tmp_root/c6/wait"
  _run_gate_wrapper "$fixture" "$run_wrapper"
  _wait_wrapper "$fixture" "$wait_wrapper"

  local gate_id
  gate_id="$("$run_wrapper" --cd "$work" --lifecycle detached)"

  local out code
  set +e; out="$("$wait_wrapper" "$gate_id" --cd "$work" --timeout 1 2>&1)"; code=$?; set -e

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
  cat > "$fixture/scripts/pr-gate.sh" <<'FAKEGATE'
#!/usr/bin/env bash
printf 'fake-gate-args: %s\n' "$*"
exit 0
FAKEGATE
  chmod +x "$fixture/scripts/pr-gate.sh"

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
  mkdir -p "$fixture/scripts/lib" "$work"
  cp "$REPO_ROOT/scripts/lib/pmctl-gate.sh" "$fixture/scripts/lib/pmctl-gate.sh"
  cp "$REPO_ROOT/scripts/gate-supervisor.sh" "$fixture/scripts/gate-supervisor.sh"
  chmod +x "$fixture/scripts/gate-supervisor.sh"
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

case_detached_launch_returns_gate_id
case_wait_resolves_go
case_wait_resolves_nogo
case_wait_resolves_failed
case_wait_indeterminate_on_consumed_sentinel
case_wait_times_out
case_foreground_unchanged
case_detached_requires_state_paths

th_summary
