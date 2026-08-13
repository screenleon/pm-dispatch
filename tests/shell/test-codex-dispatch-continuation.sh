#!/usr/bin/env bash
# Regression suite for the Codex host detached-dispatch waiter.
# shellcheck disable=SC1091,SC2154

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "test-codex-dispatch-continuation" "$@"

make_pmctl_stub() {
  local path="$1" exit_code="$2"
  mkdir -p "$(dirname "$path")"
  printf '#!/usr/bin/env bash\nprintf "stub wait: %%s\\n" "$*"\nexit %s\n' "$exit_code" > "$path"
  chmod +x "$path"
}

run_waiter() {
  local stub="$1" run_id="$2" work="$3" timeout="$4"
  PM_DISPATCH_CODEX_PMCTL_BIN="$stub" bash "$REPO_ROOT/hosts/codex/bin/wait-dispatch.sh" \
    --repo-root "$REPO_ROOT" --run-id "$run_id" --cd "$work" --timeout "$timeout"
}

run_waiter_path() {
  local waiter="$1" stub="$2" run_id="$3" work="$4" timeout="$5"
  PM_DISPATCH_CODEX_PMCTL_BIN="$stub" bash "$waiter" \
    --repo-root "$REPO_ROOT" --run-id "$run_id" --cd "$work" --timeout "$timeout"
}

make_proxy_stub() {
  local path="$1" capture="$2" mode="$3"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
#!/usr/bin/env bash
cat > "$capture"
case "$mode" in
  ok) printf '%s\\n' '{"id":1,"result":{}}' '{"id":2,"result":{"turn":{}}}' ;;
  error) printf '%s\\n' '{"id":2,"error":{"message":"thread unavailable"}}' ;;
  *) exit 9 ;;
esac
EOF
  chmod +x "$path"
}

run_continuation() {
  local pmctl_stub="$1" proxy_stub="$2" run_id="$3" work="$4" thread_id="$5"
  PM_DISPATCH_CODEX_PMCTL_BIN="$pmctl_stub" PM_DISPATCH_CODEX_APP_SERVER_PROXY_BIN="$proxy_stub" \
    bash "$REPO_ROOT/hosts/codex/bin/continue-dispatch.sh" \
      --repo-root "$REPO_ROOT" --run-id "$run_id" --cd "$work" --thread-id "$thread_id" \
      --app-server-socket /tmp/codex-app-server.sock
}

test_waiter_completed_envelope_preserves_success() {
  # Behavior: a successful authenticated wait emits the completed continuation envelope.
  # Steps: 1. stub pmctl with exit 0; 2. invoke the waiter; 3. assert its exit code and envelope state.
  local name="waiter-completed-envelope-preserves-success"
  should_run "$name" || return 0
  local stub="$tmp_root/complete/pmctl" work="$tmp_root/complete/work" out rc=0
  mkdir -p "$work"; make_pmctl_stub "$stub" 0
  out="$(run_waiter "$stub" run-20260812T000000Z-complete "$work" 5)" || rc=$?
  if [[ "$rc" -eq 0 && "$out" == *'state: completed'* && "$out" == *'wait_exit_code: 0'* ]]; then
    pass "$name"
  else
    fail "$name" "expected completed envelope with rc 0, got rc=$rc out=$out"
  fi
}

test_waiter_indeterminate_recommends_foreground_fallback() {
  # Behavior: an indeterminate wait tells the host to use foreground only for a new attempt.
  # Steps: 1. stub pmctl with exit 3; 2. invoke the waiter; 3. assert the fail-closed fallback text.
  local name="waiter-indeterminate-recommends-foreground-fallback"
  should_run "$name" || return 0
  local stub="$tmp_root/indeterminate/pmctl" work="$tmp_root/indeterminate/work" out rc=0
  mkdir -p "$work"; make_pmctl_stub "$stub" 3
  out="$(run_waiter "$stub" run-20260812T000000Z-indeterminate "$work" 5)" || rc=$?
  if [[ "$rc" -eq 3 && "$out" == *'state: indeterminate'* && "$out" == *'use foreground lifecycle for a new attempt'* ]]; then
    pass "$name"
  else
    fail "$name" "expected indeterminate fallback with rc 3, got rc=$rc out=$out"
  fi
}

test_waiter_timeout_does_not_recommend_redispatch() {
  # Behavior: a timed-out wait preserves exit 124 and prohibits an automatic re-dispatch.
  # Steps: 1. stub pmctl with exit 124; 2. invoke the waiter; 3. assert the retry-same-wait guidance.
  local name="waiter-timeout-does-not-recommend-redispatch"
  should_run "$name" || return 0
  local stub="$tmp_root/timeout/pmctl" work="$tmp_root/timeout/work" out rc=0
  mkdir -p "$work"; make_pmctl_stub "$stub" 124
  out="$(run_waiter "$stub" run-20260812T000000Z-timeout "$work" 5)" || rc=$?
  if [[ "$rc" -eq 124 && "$out" == *'state: timed_out'* && "$out" == *'do not re-dispatch'* ]]; then
    pass "$name"
  else
    fail "$name" "expected timeout retry guidance with rc 124, got rc=$rc out=$out"
  fi
}

test_waiter_rejects_invalid_run_id() {
  # Behavior: a malformed run ID is rejected before pmctl is invoked.
  # Steps: 1. create a valid pmctl stub and work dir; 2. invoke with invalid ID; 3. assert exit 2.
  local name="waiter-rejects-invalid-run-id"
  should_run "$name" || return 0
  local stub="$tmp_root/invalid/pmctl" work="$tmp_root/invalid/work" rc=0
  mkdir -p "$work"; make_pmctl_stub "$stub" 0
  run_waiter "$stub" invalid "$work" 5 >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected rc 2, got $rc"
  fi
}

test_waiter_rejects_loose_run_id_before_pmctl() {
  # Behavior: a formerly accepted loose run ID is rejected before pmctl is invoked.
  # Steps: 1. create a successful pmctl stub that records invocation; 2. invoke with run-legacy;
  # 3. assert exit 2, the validation diagnostic, and no stub invocation.
  local name="waiter-rejects-loose-run-id-before-pmctl"
  should_run "$name" || return 0
  local stub="$tmp_root/loose/pmctl" work="$tmp_root/loose/work" err="$tmp_root/loose.err" invoked="$tmp_root/loose.invoked" rc=0
  mkdir -p "$work"
  cat > "$stub" <<EOF
#!/usr/bin/env bash
printf '%s\n' invoked > "$invoked"
exit 0
EOF
  chmod +x "$stub"
  run_waiter "$stub" run-legacy "$work" 5 >/dev/null 2>"$err" || rc=$?
  if [[ "$rc" -eq 2 && "$(<"$err")" == *'invalid --run-id: run-legacy'* && ! -e "$invoked" ]]; then
    pass "$name"
  else
    fail "$name" "expected rc 2, invalid-ID diagnostic, and no pmctl invocation, got rc=$rc err=$(<"$err")"
  fi
}

test_symlinked_waiter_uses_receipt_owned_runtime_policy() {
  # Behavior: a symlinked installed waiter canonicalizes itself before importing runtime policy.
  # Steps: 1. create a link with no runtime sibling; 2. invoke it with a valid ID and pmctl stub;
  # 3. assert the normal wait envelope proves the receipt-owned library was loaded.
  local name="symlinked-waiter-uses-receipt-owned-runtime-policy"
  should_run "$name" || return 0
  local link="$tmp_root/symlinked/wait-dispatch.sh" stub="$tmp_root/symlinked/pmctl" work="$tmp_root/symlinked/work" out rc=0
  mkdir -p "$(dirname "$link")" "$work"; make_pmctl_stub "$stub" 0
  ln -s "$REPO_ROOT/hosts/codex/bin/wait-dispatch.sh" "$link"
  out="$(run_waiter_path "$link" "$stub" run-20260812T000000Z-symlink "$work" 5)" || rc=$?
  if [[ "$rc" -eq 0 && "$out" == *'state: completed'* ]]; then
    pass "$name"
  else
    fail "$name" "expected symlinked waiter to reach pmctl, got rc=$rc out=$out"
  fi
}

test_waiter_rejects_non_checkout_repo_root() {
  # Behavior: a repo root without executable cli/pmctl is rejected before waiting.
  # Steps: 1. create an absolute non-checkout directory; 2. invoke the waiter; 3. assert exit 2 and stderr.
  local name="waiter-rejects-non-checkout-repo-root"
  should_run "$name" || return 0
  local fake_root="$tmp_root/not-checkout" work="$tmp_root/not-checkout-work" err="$tmp_root/not-checkout.err" rc=0
  mkdir -p "$fake_root" "$work"
  bash "$REPO_ROOT/hosts/codex/bin/wait-dispatch.sh" \
    --repo-root "$fake_root" --run-id run-20260812T000000Z-invalidroot --cd "$work" >/dev/null 2>"$err" || rc=$?
  if [[ "$rc" -eq 2 && -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "expected validation rc 2 with stderr, got rc=$rc"
  fi
}

test_waiter_rejects_invalid_work_dir() {
  # Behavior: a non-absolute or missing work directory is rejected before pmctl is invoked.
  # Steps: 1. create a pmctl stub; 2. invoke with a relative work dir; 3. assert exit 2 and stderr.
  local name="waiter-rejects-invalid-work-dir"
  should_run "$name" || return 0
  local stub="$tmp_root/invalid-work/pmctl" err="$tmp_root/invalid-work.err" rc=0
  make_pmctl_stub "$stub" 0
  PM_DISPATCH_CODEX_PMCTL_BIN="$stub" bash "$REPO_ROOT/hosts/codex/bin/wait-dispatch.sh" \
    --repo-root "$REPO_ROOT" --run-id run-20260812T000000Z-invalidwork --cd relative >/dev/null 2>"$err" || rc=$?
  if [[ "$rc" -eq 2 && -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "expected validation rc 2 with stderr, got rc=$rc"
  fi
}

test_waiter_rejects_invalid_timeout() {
  # Behavior: zero or non-numeric timeout input is rejected before pmctl is invoked.
  # Steps: 1. create a pmctl stub and work dir; 2. invoke with timeout zero; 3. assert exit 2 and stderr.
  local name="waiter-rejects-invalid-timeout"
  should_run "$name" || return 0
  local stub="$tmp_root/invalid-timeout/pmctl" work="$tmp_root/invalid-timeout/work" err="$tmp_root/invalid-timeout.err" rc=0
  mkdir -p "$work"; make_pmctl_stub "$stub" 0
  PM_DISPATCH_CODEX_PMCTL_BIN="$stub" bash "$REPO_ROOT/hosts/codex/bin/wait-dispatch.sh" \
    --repo-root "$REPO_ROOT" --run-id run-20260812T000000Z-invalidtimeout --cd "$work" --timeout 0 >/dev/null 2>"$err" || rc=$?
  if [[ "$rc" -eq 2 && -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "expected validation rc 2 with stderr, got rc=$rc"
  fi
}

test_waiter_failed_envelope_preserves_failure() {
  # Behavior: a failed adapter wait emits failed guidance without converting its exit code.
  # Steps: 1. stub pmctl with exit 1; 2. invoke the waiter; 3. assert failed state and exit 1.
  local name="waiter-failed-envelope-preserves-failure"
  should_run "$name" || return 0
  local stub="$tmp_root/failed/pmctl" work="$tmp_root/failed/work" out rc=0
  mkdir -p "$work"; make_pmctl_stub "$stub" 1
  out="$(run_waiter "$stub" run-20260812T000000Z-failed "$work" 5)" || rc=$?
  if [[ "$rc" -eq 1 && "$out" == *'state: failed'* && "$out" == *'supervisor stderr'* ]]; then
    pass "$name"
  else
    fail "$name" "expected failed envelope with rc 1, got rc=$rc out=$out"
  fi
}

test_waiter_cancelled_envelope_preserves_cancellation() {
  # Behavior: a cancelled wait emits terminal-cancellation guidance and preserves exit 130.
  # Steps: 1. stub pmctl with exit 130; 2. invoke the waiter; 3. assert cancelled state and exit 130.
  local name="waiter-cancelled-envelope-preserves-cancellation"
  should_run "$name" || return 0
  local stub="$tmp_root/cancelled/pmctl" work="$tmp_root/cancelled/work" out rc=0
  mkdir -p "$work"; make_pmctl_stub "$stub" 130
  out="$(run_waiter "$stub" run-20260812T000000Z-cancelled "$work" 5)" || rc=$?
  if [[ "$rc" -eq 130 && "$out" == *'state: cancelled'* && "$out" == *'terminally cancelled'* ]]; then
    pass "$name"
  else
    fail "$name" "expected cancelled envelope with rc 130, got rc=$rc out=$out"
  fi
}

test_waiter_unknown_exit_uses_failed_guidance() {
  # Behavior: an unrecognised wait exit code falls back to failed guidance without changing that code.
  # Steps: 1. stub pmctl with exit 5; 2. invoke the waiter; 3. assert failed state and exit 5.
  local name="waiter-unknown-exit-uses-failed-guidance"
  should_run "$name" || return 0
  local stub="$tmp_root/unknown/pmctl" work="$tmp_root/unknown/work" out rc=0
  mkdir -p "$work"; make_pmctl_stub "$stub" 5
  out="$(run_waiter "$stub" run-20260812T000000Z-unknown "$work" 5)" || rc=$?
  if [[ "$rc" -eq 5 && "$out" == *'state: failed'* && "$out" == *'supervisor stderr'* ]]; then
    pass "$name"
  else
    fail "$name" "expected failed fallback with rc 5, got rc=$rc out=$out"
  fi
}

test_background_supervisor_injects_verified_continuation_turn() {
  # Behavior: a background supervisor relays the waiter envelope through App Server turn/start.
  # Steps: 1. stub successful pmctl and App Server proxy; 2. run supervisor; 3. assert protocol and verified envelope input.
  local name="background-supervisor-injects-verified-continuation-turn"
  should_run "$name" || return 0
  local pmctl_stub="$tmp_root/bridge/pmctl" proxy_stub="$tmp_root/bridge/codex" capture="$tmp_root/bridge/request.jsonl" work="$tmp_root/bridge/work" out rc=0
  mkdir -p "$work"; make_pmctl_stub "$pmctl_stub" 0; make_proxy_stub "$proxy_stub" "$capture" ok
  out="$(run_continuation "$pmctl_stub" "$proxy_stub" run-20260812T000000Z-bridge "$work" thread-123)" || rc=$?
  if [[ "$rc" -eq 0 && "$out" == *'continuation delivered to Codex thread thread-123'* ]] \
    && grep -Fq '"method":"initialize"' "$capture" \
    && grep -Fq '"method":"turn/start"' "$capture" \
    && grep -Fq '"threadId":"thread-123"' "$capture" \
    && grep -Fq 'state: completed' "$capture"; then
    pass "$name"
  else
    fail "$name" "expected successful continuation delivery, got rc=$rc out=$out"
  fi
}

test_background_supervisor_fails_loudly_when_callback_rejected() {
  # Behavior: App Server rejection does not masquerade as a completed automatic continuation.
  # Steps: 1. stub successful pmctl and rejecting proxy; 2. run supervisor; 3. assert exit 4 and foreground guidance.
  local name="background-supervisor-fails-loudly-when-callback-rejected"
  should_run "$name" || return 0
  local pmctl_stub="$tmp_root/bridge-error/pmctl" proxy_stub="$tmp_root/bridge-error/codex" capture="$tmp_root/bridge-error/request.jsonl" work="$tmp_root/bridge-error/work" err="$tmp_root/bridge-error/err" rc=0
  mkdir -p "$work"; make_pmctl_stub "$pmctl_stub" 0; make_proxy_stub "$proxy_stub" "$capture" error
  run_continuation "$pmctl_stub" "$proxy_stub" run-20260812T000000Z-bridgeerror "$work" thread-456 >/dev/null 2>"$err" || rc=$?
  if [[ "$rc" -eq 4 && "$(<"$err")" == *'foreground continuation is required'* ]]; then
    pass "$name"
  else
    fail "$name" "expected callback failure rc 4 with foreground guidance, got rc=$rc"
  fi
}

test_background_supervisor_rejects_invalid_thread_id() {
  # Behavior: malformed thread IDs are rejected before the waiter or App Server runs.
  # Steps: 1. create valid stubs; 2. pass a whitespace thread id; 3. assert exit 2.
  local name="background-supervisor-rejects-invalid-thread-id"
  should_run "$name" || return 0
  local pmctl_stub="$tmp_root/invalid-thread/pmctl" proxy_stub="$tmp_root/invalid-thread/codex" capture="$tmp_root/invalid-thread/request.jsonl" work="$tmp_root/invalid-thread/work" rc=0
  mkdir -p "$work"; make_pmctl_stub "$pmctl_stub" 0; make_proxy_stub "$proxy_stub" "$capture" ok
  PM_DISPATCH_CODEX_PMCTL_BIN="$pmctl_stub" PM_DISPATCH_CODEX_APP_SERVER_PROXY_BIN="$proxy_stub" \
    bash "$REPO_ROOT/hosts/codex/bin/continue-dispatch.sh" --repo-root "$REPO_ROOT" --run-id run-20260812T000000Z-invalidthread --cd "$work" --thread-id 'bad thread' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 && ! -e "$capture" ]]; then
    pass "$name"
  else
    fail "$name" "expected invalid thread id rc 2 without proxy call, got rc=$rc"
  fi
}

test_waiter_completed_envelope_preserves_success
test_waiter_indeterminate_recommends_foreground_fallback
test_waiter_timeout_does_not_recommend_redispatch
test_waiter_rejects_invalid_run_id
test_waiter_rejects_loose_run_id_before_pmctl
test_symlinked_waiter_uses_receipt_owned_runtime_policy
test_waiter_rejects_non_checkout_repo_root
test_waiter_rejects_invalid_work_dir
test_waiter_rejects_invalid_timeout
test_waiter_failed_envelope_preserves_failure
test_waiter_cancelled_envelope_preserves_cancellation
test_waiter_unknown_exit_uses_failed_guidance
test_background_supervisor_injects_verified_continuation_turn
test_background_supervisor_fails_loudly_when_callback_rejected
test_background_supervisor_rejects_invalid_thread_id
th_summary
