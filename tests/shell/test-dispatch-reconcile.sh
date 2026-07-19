#!/usr/bin/env bash
# Regression tests for pmctl dispatch reconcile (CC-499).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=tests/lib/dispatch-decoy-helpers.sh
. "$SCRIPT_DIR/../lib/dispatch-decoy-helpers.sh"
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
export PM_DISPATCH_STATE_ROOT="$tmp_root/reconcile-state"

_TEST_XDG_RUNTIME_DIR="$tmp_root/xdg-runtime"
mkdir -p "$_TEST_XDG_RUNTIME_DIR" && chmod 700 "$_TEST_XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR="$_TEST_XDG_RUNTIME_DIR"

# Job control off: killed decoys must not become interactive job failures.
set +m 2>/dev/null || true

_isolated_decoy() { dispatch_test_isolated_decoy; }
_kill_pid_quiet() { dispatch_test_kill_pid_quiet "$1"; }
_run_trace_dir() { dispatch_test_run_trace_dir "$1" "$2"; }

_BRIEFS=()
_mk_runspec_fixture() {
  local work="$1" run_id="$2" art_dir="$3"
  local bf="/tmp/brief-$run_id.md"
  printf 'goal: reconcile fixture\n' >"$bf"
  _BRIEFS+=("$bf")
  cat >"$art_dir/$run_id.runspec" <<EOF
schema_version=2
run_id=$run_id
adapter=codex
work_dir=$work
cd_arg=$work
brief_file=$bf
model=
created_ts=2026-07-19T00:00:00Z
print_cmd=0
initial_state_written=1
native_b64:
EOF
}

# shellcheck disable=SC2317
_cleanup() { rm -f "${_BRIEFS[@]}" 2>/dev/null || true; }
trap _cleanup EXIT

# ── reconcile: dead-leader identity + no terminal → orphaned, converges ─────
# Behavior: identity present, process provably gone, no terminal claim yet →
#          reconcile claims failed (never invents ok/partial).
# Steps: craft identity (dead pid) + runspec → reconcile → assert claim
#        final_state=failed claimer=reconcile.
case_dispatch_reconcile_orphaned_converges() {
  local name="lifecycle/dispatch reconcile converges orphaned run to failed"
  should_run "$name" || return 0
  local work run_id art_dir out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0001"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"
  printf 'pid=999999\npgid=999999\nstarttime=1\ncomm=bash\nisolated=1\nboot_id=%s\n' \
    "$(detached_launch_current_boot_id)" >"$art_dir/$run_id.supervisor.identity"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] \
    && grep -q 'status: orphaned' <<<"$out" \
    && [[ -f "$claim" ]] && grep -q '^final_state=failed$' "$claim" \
    && grep -q '^claimer=reconcile$' "$claim" \
    && [[ ! -f "$art_dir/$run_id.supervisor.identity" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim=$(tr '\n' '|' <"$claim" 2>/dev/null)"
  fi
  rm -rf "$work"
}

# ── reconcile: --dry-run reports but never writes ───────────────────────────
# Behavior: --dry-run prints the same classification but leaves no terminal
#          claim and leaves the identity/runspec fixtures untouched.
case_dispatch_reconcile_dry_run_no_write() {
  local name="lifecycle/dispatch reconcile --dry-run does not converge"
  should_run "$name" || return 0
  local work run_id art_dir out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0002"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"
  printf 'pid=999999\npgid=999999\nstarttime=1\ncomm=bash\nisolated=1\nboot_id=%s\n' \
    "$(detached_launch_current_boot_id)" >"$art_dir/$run_id.supervisor.identity"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" --dry-run 2>&1)"
  code=$?
  set -e
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: orphaned' <<<"$out" \
    && [[ ! -f "$claim" ]] \
    && [[ -f "$art_dir/$run_id.supervisor.identity" ]] \
    && [[ -f "$art_dir/$run_id.runspec" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim_present=$( [[ -f "$claim" ]] && echo yes || echo no)"
  fi
  rm -rf "$work"
}

# ── reconcile: no identity AND no pid file → indeterminate, never converges ─
# Behavior: only a runspec exists (identity/pid never written) → zero
#          liveness signal in either direction; the supervisor could still
#          be alive with lost/never-written artifacts. Reconcile must report
#          indeterminate and NEVER auto-claim failed here (gate critic
#          finding: a false "failed" claim could overwrite a still-live job).
case_dispatch_reconcile_runspec_only_indeterminate() {
  local name="lifecycle/dispatch reconcile reports indeterminate for runspec-only, never converges"
  should_run "$name" || return 0
  local work run_id art_dir out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0003"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: indeterminate' <<<"$out" \
    && grep -q 'cannot prove process absence' <<<"$out" \
    && [[ ! -f "$claim" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim_present=$( [[ -f "$claim" ]] && echo yes || echo no)"
  fi
  rm -rf "$work"
}

# ── reconcile: pid_file recorded but confirmed dead → still converges ──────
# Behavior: a bare .supervisor.pid (no identity file) whose pid is confirmed
#          not running IS provable absence for that specific pid (a negative
#          kill -0 has no PID-reuse ambiguity) — reconcile still converges
#          this to failed, unlike the identity-and-pid-free case above.
case_dispatch_reconcile_dead_pid_file_converges() {
  local name="lifecycle/dispatch reconcile converges dead pid-file-only run"
  should_run "$name" || return 0
  local work run_id art_dir out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0014"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"
  printf '999999\n' >"$art_dir/$run_id.supervisor.pid"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: process-gone-without-evidence' <<<"$out" \
    && [[ -f "$claim" ]] && grep -q '^final_state=failed$' "$claim"; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim=$(tr '\n' '|' <"$claim" 2>/dev/null)"
  fi
  rm -rf "$work"
}

# ── reconcile: malformed pid_file content is indeterminate, never converges ─
# Behavior: a .supervisor.pid whose content is not a bare integer (empty,
#          garbage, non-numeric) carries no liveness signal at all — unlike
#          a confirmed-dead numeric pid, this must NOT be treated as proof
#          of absence. Reconcile reports indeterminate and writes no claim
#          (gate critic + qa-tester finding, CC-499).
case_dispatch_reconcile_malformed_pid_file_indeterminate() {
  local name="lifecycle/dispatch reconcile treats malformed pid_file as indeterminate"
  should_run "$name" || return 0
  local work run_id art_dir out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0015"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"
  printf 'not-a-pid\n' >"$art_dir/$run_id.supervisor.pid"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: indeterminate' <<<"$out" \
    && grep -q 'cannot prove process absence' <<<"$out" \
    && [[ ! -f "$claim" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim_present=$( [[ -f "$claim" ]] && echo yes || echo no)"
  fi
  rm -rf "$work"
}

# ── reconcile: identity mismatch (possible PID reuse) refuses to converge ──
# Behavior: a live process exists at the recorded pid but pgid/starttime
#          mismatch (simulated PID reuse) → reconcile reports indeterminate
#          and never writes a terminal claim.
case_dispatch_reconcile_pid_reuse_refuses() {
  local name="lifecycle/dispatch reconcile refuses to converge on PID-reuse mismatch"
  should_run "$name" || return 0
  local work run_id art_dir decoy out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0004"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"

  decoy="$(_isolated_decoy)" || {
    fail "$name" "setsid decoy unavailable"
    rm -rf "$work"
    return
  }
  detached_launch_capture_identity "$decoy" "1" >"$art_dir/$run_id.supervisor.identity" 2>/dev/null
  sed -i 's/^starttime=.*/starttime=1/' "$art_dir/$run_id.supervisor.identity" \
    || sed -i '' 's/^starttime=.*/starttime=1/' "$art_dir/$run_id.supervisor.identity"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  _kill_pid_quiet "$decoy"
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: indeterminate' <<<"$out" \
    && grep -q 'PID reuse' <<<"$out" \
    && [[ ! -f "$claim" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim_present=$( [[ -f "$claim" ]] && echo yes || echo no)"
  fi
  rm -rf "$work"
}

# ── reconcile: live matching identity is in-flight, untouched ──────────────
# Behavior: identity matches a live process → reconcile reports in-flight and
#          never writes a terminal claim (mirrors dispatch status).
case_dispatch_reconcile_in_flight_untouched() {
  local name="lifecycle/dispatch reconcile leaves in-flight run untouched"
  should_run "$name" || return 0
  local work run_id art_dir decoy out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0005"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"

  decoy="$(_isolated_decoy)" || {
    fail "$name" "setsid decoy unavailable"
    rm -rf "$work"
    return
  }
  detached_launch_capture_identity "$decoy" "1" >"$art_dir/$run_id.supervisor.identity" 2>/dev/null
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  _kill_pid_quiet "$decoy"
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: in-flight' <<<"$out" && [[ ! -f "$claim" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim_present=$( [[ -f "$claim" ]] && echo yes || echo no)"
  fi
  rm -rf "$work"
}

# ── reconcile: live pid_file with no identity file is in-flight, untouched ─
# Behavior: pre-CC-495-style fixtures (only a raw .supervisor.pid, no
#          .supervisor.identity) with a live process must classify as
#          in-flight/unknown-identity and never converge — mirrors dispatch
#          status's "process_alive: unknown-identity" branch.
case_dispatch_reconcile_pid_file_only_in_flight() {
  local name="lifecycle/dispatch reconcile leaves pid-file-only live run untouched"
  should_run "$name" || return 0
  local work run_id art_dir decoy out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0013"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"

  decoy="$(_isolated_decoy)" || {
    fail "$name" "setsid decoy unavailable"
    rm -rf "$work"
    return
  }
  printf '%s\n' "$decoy" >"$art_dir/$run_id.supervisor.pid"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  _kill_pid_quiet "$decoy"
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: in-flight  process_alive: unknown-identity' <<<"$out" \
    && [[ ! -f "$claim" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim_present=$( [[ -f "$claim" ]] && echo yes || echo no)"
  fi
  rm -rf "$work"
}

# ── reconcile: existing terminal claim is never overwritten ────────────────
# Behavior: a pre-existing cancelled claim is reported as terminal-authenticated
#          and left byte-for-byte unmodified.
case_dispatch_reconcile_already_terminal_not_overwritten() {
  local name="lifecycle/dispatch reconcile does not overwrite existing terminal claim"
  should_run "$name" || return 0
  local work run_id art_dir out code claim before after
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0006"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"
  claim="$art_dir/$run_id.terminal"
  printf 'final_state=cancelled\nclaimer=cancel\nts=2026-07-19T00:00:00Z\n' >"$claim"
  before="$(cat "$claim")"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  after="$(cat "$claim")"

  if [[ "$code" -eq 0 ]] && grep -q 'status: terminal-authenticated' <<<"$out" \
    && grep -q 'final_state: cancelled' <<<"$out" \
    && [[ "$before" == "$after" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') changed=$( [[ "$before" == "$after" ]] && echo no || echo yes)"
  fi
  rm -rf "$work"
}

# ── reconcile: unknown run_id (no trusted evidence) fails closed ───────────
# Behavior: a syntactically valid but never-dispatched run_id yields exit 2
#          and no fabricated classification.
case_dispatch_reconcile_unknown_run() {
  local name="lifecycle/dispatch reconcile fails closed for unknown run_id"
  should_run "$name" || return 0
  local work code
  work="$(mktemp -d)"; git init -q "$work"

  set +e
  "$PMCTL" dispatch reconcile "run-20260719T000000Z-rc0007" --cd "$work" >/dev/null 2>&1
  code=$?
  set -e

  if [[ "$code" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code (expected 2)"
  fi
  rm -rf "$work"
}

# ── reconcile: --all scans every run under the work dir ────────────────────
# Behavior: --all converges the orphaned run and leaves the in-flight run
#          alone, in a single pass.
case_dispatch_reconcile_all_scans_multiple_runs() {
  local name="lifecycle/dispatch reconcile --all converges orphaned, spares in-flight"
  should_run "$name" || return 0
  local work run_a run_b art_a art_b decoy out code
  work="$(mktemp -d)"; git init -q "$work"
  run_a="run-20260719T000000Z-rc0008"
  run_b="run-20260719T000000Z-rc0009"
  art_a="$(_run_trace_dir "$work" "$run_a")"
  art_b="$(_run_trace_dir "$work" "$run_b")"
  mkdir -p "$art_a" "$art_b"

  printf 'pid=999999\npgid=999999\nstarttime=1\ncomm=bash\nisolated=1\nboot_id=%s\n' \
    "$(detached_launch_current_boot_id)" >"$art_a/$run_a.supervisor.identity"
  _mk_runspec_fixture "$work" "$run_a" "$art_a"

  decoy="$(_isolated_decoy)" || {
    fail "$name" "setsid decoy unavailable"
    rm -rf "$work"
    return
  }
  detached_launch_capture_identity "$decoy" "1" >"$art_b/$run_b.supervisor.identity" 2>/dev/null
  _mk_runspec_fixture "$work" "$run_b" "$art_b"

  set +e
  out="$("$PMCTL" dispatch reconcile --all --cd "$work" 2>&1)"
  code=$?
  set -e
  _kill_pid_quiet "$decoy"

  if [[ "$code" -eq 0 ]] \
    && [[ -f "$art_a/$run_a.terminal" ]] && grep -q '^final_state=failed$' "$art_a/$run_a.terminal" \
    && [[ ! -f "$art_b/$run_b.terminal" ]] \
    && grep -q "$run_b" <<<"$out" && grep -q 'in-flight' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

# ── reconcile: boot_id mismatch short-circuits to gone, no starttime replay ─
# Behavior: recorded boot_id differs from the current one → identity is
#          treated as provably gone even though pid/pgid/starttime happen to
#          match a live decoy (post-reboot coincidental collision simulated).
case_dispatch_reconcile_reboot_short_circuits() {
  local name="lifecycle/dispatch reconcile treats boot_id mismatch as gone (reboot)"
  should_run "$name" || return 0
  local work run_id art_dir decoy out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0010"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"

  decoy="$(_isolated_decoy)" || {
    fail "$name" "setsid decoy unavailable"
    rm -rf "$work"
    return
  }
  # Real pid/pgid/starttime match (coincidental collision simulation), but
  # boot_id is forged to a different value — must short-circuit to gone.
  detached_launch_capture_identity "$decoy" "1" >"$art_dir/$run_id.supervisor.identity" 2>/dev/null
  sed -i 's/^boot_id=.*/boot_id=00000000-0000-0000-0000-000000000000/' "$art_dir/$run_id.supervisor.identity" \
    || sed -i '' 's/^boot_id=.*/boot_id=00000000-0000-0000-0000-000000000000/' "$art_dir/$run_id.supervisor.identity"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  _kill_pid_quiet "$decoy"
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: orphaned' <<<"$out" \
    && [[ -f "$claim" ]] && grep -q '^final_state=failed$' "$claim"; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim=$(tr '\n' '|' <"$claim" 2>/dev/null)"
  fi
  rm -rf "$work"
}

# ── reconcile: CLI validation — missing --cd ────────────────────────────────
# Behavior: --cd is required; missing it exits 2 without touching state.
case_dispatch_reconcile_cli_missing_cd() {
  local name="lifecycle/dispatch reconcile CLI requires --cd"
  should_run "$name" || return 0
  local code
  set +e
  "$PMCTL" dispatch reconcile "run-20260719T000000Z-rccli1" >/dev/null 2>&1
  code=$?
  set -e
  if [[ "$code" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code (expected 2)"
  fi
}

# ── reconcile: CLI validation — run_id and --all are mutually exclusive ─────
case_dispatch_reconcile_cli_run_id_and_all_exclusive() {
  local name="lifecycle/dispatch reconcile CLI rejects run_id with --all"
  should_run "$name" || return 0
  local work code
  work="$(mktemp -d)"; git init -q "$work"
  set +e
  "$PMCTL" dispatch reconcile "run-20260719T000000Z-rccli2" --all --cd "$work" >/dev/null 2>&1
  code=$?
  set -e
  if [[ "$code" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code (expected 2)"
  fi
  rm -rf "$work"
}

# ── reconcile: CLI validation — run_id required unless --all ───────────────
case_dispatch_reconcile_cli_run_id_required() {
  local name="lifecycle/dispatch reconcile CLI requires run_id unless --all"
  should_run "$name" || return 0
  local work code
  work="$(mktemp -d)"; git init -q "$work"
  set +e
  "$PMCTL" dispatch reconcile --cd "$work" >/dev/null 2>&1
  code=$?
  set -e
  if [[ "$code" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code (expected 2)"
  fi
  rm -rf "$work"
}

# ── reconcile: CLI validation — malformed run_id rejected ──────────────────
case_dispatch_reconcile_cli_malformed_run_id() {
  local name="lifecycle/dispatch reconcile CLI rejects malformed run_id"
  should_run "$name" || return 0
  local work code
  work="$(mktemp -d)"; git init -q "$work"
  set +e
  "$PMCTL" dispatch reconcile "not-a-run-id" --cd "$work" >/dev/null 2>&1
  code=$?
  set -e
  if [[ "$code" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code (expected 2)"
  fi
  rm -rf "$work"
}

# ── reconcile: CLI validation — unknown flag rejected ───────────────────────
case_dispatch_reconcile_cli_unknown_flag() {
  local name="lifecycle/dispatch reconcile CLI rejects unknown flag"
  should_run "$name" || return 0
  local work code
  work="$(mktemp -d)"; git init -q "$work"
  set +e
  "$PMCTL" dispatch reconcile "run-20260719T000000Z-rccli3" --cd "$work" --bogus >/dev/null 2>&1
  code=$?
  set -e
  if [[ "$code" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code (expected 2)"
  fi
  rm -rf "$work"
}

# ── reconcile: CAS lost-race is reported, never overwritten ────────────────
# Behavior: if a terminal claim appears between _pmctl_dispatch_reconcile_one's
#          classification and the converge step's own CAS attempt (concurrent
#          cancel/supervisor write), converge must report the winner and must
#          NOT touch the existing claim. Exercised by calling the converge
#          step directly against a pre-existing claim (same shape a real race
#          would leave behind), since single-process tests cannot induce a
#          true timing race.
case_dispatch_reconcile_cas_lost_race_not_overwritten() {
  local name="lifecycle/dispatch reconcile converge reports CAS lost-race, does not overwrite"
  should_run "$name" || return 0
  local work run_id art_dir claim before after out
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0011"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"
  claim="$art_dir/$run_id.terminal"
  # Simulate: a competing writer (e.g. natural complete) already won the CAS
  # by the time converge is invoked.
  printf 'final_state=ok\nclaimer=supervisor\nts=2026-07-19T00:00:00Z\n' >"$claim"
  before="$(cat "$claim")"

  out="$(_pmctl_dispatch_reconcile_converge "$REPO_ROOT" "$work" "$run_id" 2>&1)"
  after="$(cat "$claim")"

  if grep -q 'status: terminal-authenticated' <<<"$out" \
    && grep -q 'final_state: ok' <<<"$out" \
    && grep -q 'reconcile lost race, not overwritten' <<<"$out" \
    && [[ "$before" == "$after" ]]; then
    pass "$name"
  else
    fail "$name" "out=$(printf '%s' "$out" | tr '\n' '|') changed=$( [[ "$before" == "$after" ]] && echo no || echo yes)"
  fi
  rm -rf "$work"
}

# ── reconcile: legacy identity file without boot_id still classifies ───────
# Behavior: identity files written before CC-499 (no boot_id= line) must
#          still classify correctly — both the live-match (in-flight) and
#          dead-leader (orphaned) paths — since detached_launch_load_identity_file
#          leaves DL_ID_BOOT_ID empty and verify_identity's reboot short-circuit
#          only applies when both sides have a boot_id (backward compat).
case_dispatch_reconcile_legacy_identity_no_boot_id() {
  local name="lifecycle/dispatch reconcile classifies legacy identity without boot_id"
  should_run "$name" || return 0
  local work run_id art_dir decoy out code claim
  work="$(mktemp -d)"; git init -q "$work"
  run_id="run-20260719T000000Z-rc0012"
  art_dir="$(_run_trace_dir "$work" "$run_id")"
  mkdir -p "$art_dir"

  decoy="$(_isolated_decoy)" || {
    fail "$name" "setsid decoy unavailable"
    rm -rf "$work"
    return
  }
  # Legacy shape: real identity fields, but no boot_id= line at all
  # (pre-CC-499 identity file) — strip it rather than fabricate starttime.
  detached_launch_capture_identity "$decoy" "1" 2>/dev/null \
    | grep -v '^boot_id=' >"$art_dir/$run_id.supervisor.identity"
  _mk_runspec_fixture "$work" "$run_id" "$art_dir"

  set +e
  out="$("$PMCTL" dispatch reconcile "$run_id" --cd "$work" 2>&1)"
  code=$?
  set -e
  _kill_pid_quiet "$decoy"
  claim="$art_dir/$run_id.terminal"

  if [[ "$code" -eq 0 ]] && grep -q 'status: in-flight' <<<"$out" && [[ ! -f "$claim" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | tr '\n' '|') claim_present=$( [[ -f "$claim" ]] && echo yes || echo no)"
  fi
  rm -rf "$work"
}

_safe_case() {
  local fn="${1:?}"
  if ! declare -F "$fn" >/dev/null 2>&1; then
    fail "missing case function: $fn" "not defined"
    return 0
  fi
  set +e
  "$fn"
  set -e
  return 0
}

_safe_case case_dispatch_reconcile_orphaned_converges
_safe_case case_dispatch_reconcile_dry_run_no_write
_safe_case case_dispatch_reconcile_runspec_only_indeterminate
_safe_case case_dispatch_reconcile_dead_pid_file_converges
_safe_case case_dispatch_reconcile_malformed_pid_file_indeterminate
_safe_case case_dispatch_reconcile_pid_reuse_refuses
_safe_case case_dispatch_reconcile_in_flight_untouched
_safe_case case_dispatch_reconcile_pid_file_only_in_flight
_safe_case case_dispatch_reconcile_already_terminal_not_overwritten
_safe_case case_dispatch_reconcile_unknown_run
_safe_case case_dispatch_reconcile_all_scans_multiple_runs
_safe_case case_dispatch_reconcile_reboot_short_circuits
_safe_case case_dispatch_reconcile_cli_missing_cd
_safe_case case_dispatch_reconcile_cli_run_id_and_all_exclusive
_safe_case case_dispatch_reconcile_cli_run_id_required
_safe_case case_dispatch_reconcile_cli_malformed_run_id
_safe_case case_dispatch_reconcile_cli_unknown_flag
_safe_case case_dispatch_reconcile_cas_lost_race_not_overwritten
_safe_case case_dispatch_reconcile_legacy_identity_no_boot_id
th_summary
