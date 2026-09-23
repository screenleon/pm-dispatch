#!/usr/bin/env bash
# Regression coverage for producer-owned parent-operation records.
# shellcheck disable=SC2154 # tmp_root is initialized by test-harness.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=tests/lib/test-harness.sh disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/portable.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/portable.sh"
# shellcheck source=runtime/lib/pmctl-operation.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/pmctl-operation.sh"
# shellcheck source=runtime/lib/pmctl-dispatch.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/pmctl-dispatch.sh"

make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
}

# issue #593: MSYS2/Git Bash does not ship setsid. Three cases in this file
# use it to get a real, independently-signalable process group (needed to
# test producer-liveness/kill semantics; a plain background job cannot be
# targeted the same way). Without a guard, `setsid` failing with "command
# not found" doesn't just fail the case that calls it directly -- two other
# cases background a `setsid bash -c 'read ... < fifo'` reader and later
# write to that FIFO expecting the (never-started) reader to unblock them;
# with no reader, the write blocks forever, a real deadlock, not merely a
# failure. Skip the process-group-dependent cases cleanly instead.
_require_setsid() {
  local name="$1"
  command -v setsid >/dev/null 2>&1 && return 0
  skip "$name" "setsid not available on this platform (issue #593); this case needs a real, killable process group"
  return 1
}

# Operation reconciliation needs the PID that will actually remain alive for
# identity verification.  Do not use `setsid` here: it may fork when invoked
# by a process-group leader, leaving $! as a short-lived wrapper PID.
start_live_test_producer() {
  sleep 30 &
  TEST_PRODUCER_PID=$!
}

stop_live_test_producer() {
  local producer="$1" signal="${2:-TERM}"
  kill -s "$signal" -- "$producer" 2>/dev/null || true
  wait "$producer" 2>/dev/null || true
}

case_writer_loader_repairs_partial_inherited_functions() {
  local name="operation lock: partial inherited writer functions reload before producer registration"
  should_run "$name" || return 0
  _require_setsid "$name" || return 0
  local work="$tmp_root/partial-writer-work" store="$tmp_root/partial-writer-state"
  local op out rc=0 state record
  make_repo "$work"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer \
    "$REPO_ROOT" gate "$op" "$work"
  _pmctl_operation_load_writer "$REPO_ROOT"
  out="$(
    export -f operation_create
    export -n -f operation_upsert operation_child_append 2>/dev/null || true
    # shellcheck disable=SC2016 # variables are expanded by the spawned bash.
    PM_DISPATCH_STATE_ROOT="$store" setsid bash -c '
      set -euo pipefail
      . "$1/runtime/lib/pmctl-operation.sh"
      pmctl_operation_register_producer "$1" gate "$2" "$3" "$BASHPID"
      declare -F operation_create operation_upsert operation_child_append
    ' _ "$REPO_ROOT" "$op" "$work"
  )" || rc=$?
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c \
    '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' \
    _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$op.json"
  if [[ "$rc" -eq 0 && "$out" == *"operation_create"* \
    && "$out" == *"operation_upsert"* && "$out" == *"operation_child_append"* \
    && "$(jq -r .producer.status "$record")" == running ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out record=$(jq -c . "$record" 2>/dev/null || true)"
  fi
}

# Regression: operation op-20260922T151921Z-2faf65 lost its Windows children.
# Behavior: Windows drive-letter children use the same trusted terminal claims
# as POSIX children; failed children must never become parent success.
# Steps: attach a real native path, publish a failed supervisor terminal claim,
# reconcile twice, and check the durable failed state and idempotent timestamp.
case_reconcile_windows_child_terminal_claim() {
  local name="operation reconcile: Windows child failure converges idempotently"
  should_run "$name" || return 0
  if [[ "$(detect_platform)" != windows ]]; then
    skip "$name" "requires a real native Windows drive-letter path"
    return
  fi
  local work="$tmp_root/windows-reconcile-work" store="$tmp_root/windows-reconcile-state"
  local op child run_id="run-20260923T000000Z-abcdef" out rc=0 state before after
  make_repo "$work"
  work="$(cd "$work" && pwd -P)"
  child="$(cygpath -m "$work")"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$child"
  PM_DISPATCH_STATE_ROOT="$store" _pmctl_dispatch_try_terminal_claim "$child" "$run_id" failed supervisor
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd "$work")" || rc=$?
  state="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$work" _sw_project_dir)"
  before="$(cat "$state/operations/$op.json")"
  [[ "$rc" -eq 0 && "$out" == *"children: 1  unresolved: 0"* && "$(jq -r .state <<<"$before")" == failed ]] || {
    fail "$name" "rc=$rc out=$out record=$before"
    return
  }
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd "$work" > "$tmp_root/reconcile-again.out" || rc=$?
  after="$(cat "$state/operations/$op.json")"
  [[ "$rc" -eq 0 && "$before" == "$after" ]] || { fail "$name" "second reconciliation changed terminal record"; return; }
  pass "$name"
}

case_reconcile_uses_trusted_terminal_claims() {
  local name="operation reconcile: all trusted child claims converge parent to completed"
  should_run "$name" || return 0
  local work="$tmp_root/work" store="$tmp_root/state" op run_id out state
  make_repo "$work"; run_id="run-20260724T000000Z-abcdef"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" ship codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$store" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" ship "$op" --cd "$work")"
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  if [[ "$out" == *"state: completed"* ]] && [[ "$(jq -r .state "${state%/}/operations/$op.json")" == completed ]]; then
    pass "$name"
  else
    fail "$name" "out=$out"
  fi
}

case_reconcile_defers_while_producer_is_running() {
  local name="operation reconcile: running producer blocks premature child convergence"
  should_run "$name" || return 0
  local work="$tmp_root/producer-active-work" store="$tmp_root/producer-active-state"
  local op run_id producer out rc=0 state
  make_repo "$work"; run_id="run-20260724T000002Z-fedcba"
  start_live_test_producer; producer="$TEST_PRODUCER_PID"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_register_producer "$REPO_ROOT" gate "$op" "$work" "$producer"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$store" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd "$work" 2>&1)" || rc=$?
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  stop_live_test_producer "$producer"
  if [[ "$rc" -ne 0 && "$out" == *"producer-active"* \
    && "$(jq -r .state "${state%/}/operations/$op.json")" == running ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out state=$(jq -r .state "${state%/}/operations/$op.json" 2>/dev/null || true)"
  fi
}

# Behavior: reconciliation must convert a dead registered producer into a
# diagnosable terminal state once its trusted child claim is complete.
# Steps:
#   1. Register a producer and attach a successful child terminal claim.
#   2. Kill the producer before reconciliation runs.
#   3. Assert reconciliation completes and records producer.status=stopped.
case_reconcile_recovers_dead_registered_producer() {
  local name="operation reconcile: dead registered producer becomes diagnosable terminal"
  should_run "$name" || return 0
  local work="$tmp_root/dead-producer-work" store="$tmp_root/dead-producer-state"
  local op run_id producer out rc=0 state record
  make_repo "$work"; run_id="run-20260724T000003Z-deadbe"
  start_live_test_producer; producer="$TEST_PRODUCER_PID"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_register_producer "$REPO_ROOT" gate "$op" "$work" "$producer"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$store" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  stop_live_test_producer "$producer" KILL
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd "$work" 2>&1)" || rc=$?
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$op.json"
  if [[ "$rc" -eq 0 && "$out" == *"state: completed"* \
      && "$(jq -r .state "$record")" == completed \
      && "$(jq -r .producer.status "$record")" == stopped ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out record=$(jq -c . "$record" 2>/dev/null || true)"
  fi
}

# Behavior: producer identity conversion failure must fail closed as
# indeterminate rather than leaving the parent operation running forever.
# Steps:
#   1. Register a producer and attach a successful child terminal claim.
#   2. Force identity conversion to fail during reconciliation.
#   3. Assert reconciliation returns nonzero and persists state=indeterminate.
case_reconcile_rejects_malformed_producer_identity() {
  local name="operation reconcile: producer identity conversion failure becomes indeterminate"
  should_run "$name" || return 0
  local work="$tmp_root/malformed-producer-work" store="$tmp_root/malformed-producer-state"
  local op run_id producer out rc=0 state record
  make_repo "$work"; run_id="run-20260724T000004Z-badc0d"
  start_live_test_producer; producer="$TEST_PRODUCER_PID"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_register_producer "$REPO_ROOT" gate "$op" "$work" "$producer"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$store" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$op.json"
  stop_live_test_producer "$producer" KILL
  out="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '
    set -euo pipefail
    . "$1/runtime/lib/pmctl-operation.sh"
    _pmctl_operation_identity_file_from_json() { return 1; }
    PM_DISPATCH_STATE_ROOT="$3" pmctl_operation_reconcile "$1" gate "$2" --cd "$4"
  ' _ "$REPO_ROOT" "$op" "$store" "$work" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"state: indeterminate"* \
      && "$(jq -r .state "$record")" == indeterminate ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out record=$(jq -c . "$record" 2>/dev/null || true)"
  fi
}

case_create_collision_never_overwrites_record() {
  local name="operation create: ID collision never overwrites an existing parent record"
  should_run "$name" || return 0
  local work="$tmp_root/create-collision-work" store="$tmp_root/create-collision-state" first second_out rc=0 state record stamp_def hex_def
  make_repo "$work"
  stamp_def="$(declare -f _pmctl_operation_stamp)"
  hex_def="$(declare -f _pmctl_operation_hex6)"
  _pmctl_operation_stamp() { printf "20260724T000030Z"; }
  _pmctl_operation_hex6() { printf "abcdef"; }
  first="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  second_out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" ship claude 2>&1)" || rc=$?
  eval "$stamp_def"
  eval "$hex_def"
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$first.json"
  if [[ "$rc" -ne 0 && "$second_out" == *"could not reserve a unique operation ID"* ]] \
     && [[ "$(jq -r .kind "$record")" == gate ]] \
     && [[ "$(jq -r .executor "$record")" == codex ]] \
     && [[ "$(jq -r .state "$record")" == running ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc first=$first second=$second_out record=$(jq -c . "$record" 2>/dev/null || true)"
  fi
}

case_reconcile_rejects_foreign_operation() {
  local name="operation reconcile: foreign project target is refused"
  should_run "$name" || return 0
  local first="$tmp_root/first" second="$tmp_root/second" store="$tmp_root/state" op rc=0
  make_repo "$first"; make_repo "$second"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$first" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd "$second" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "expected 2 got $rc"; fi
}

case_reconcile_never_infers_success_without_claim() {
  local name="operation reconcile: missing child terminal evidence is indeterminate"
  should_run "$name" || return 0
  local work="$tmp_root/no-claim" store="$tmp_root/no-claim-state" op run_id out rc=0
  make_repo "$work"; run_id="run-20260724T000001Z-fedcba"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd "$work" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"state: indeterminate"* ]]; then pass "$name"; else fail "$name" "rc=$rc out=$out"; fi
}

case_cancel_targets_only_recorded_children() {
  local name="operation cancel: invokes dispatch cancel only for recorded children"
  should_run "$name" || return 0
  local work="$tmp_root/cancel-work" store="$tmp_root/cancel-state" op first second calls out
  make_repo "$work"; first="run-20260724T000010Z-aaaaaa"; second="run-20260724T000011Z-bbbbbb"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" ship codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$first" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$second" "$work"
  calls="$tmp_root/cancel-calls"
  out="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '
    . "$1/runtime/lib/portable.sh"
    . "$1/runtime/lib/pmctl-operation.sh"
    calls="$3"
    pmctl_dispatch_cancel() { printf "%s\n" "$2" >> "$calls"; return 1; }
    pmctl_operation_cancel "$1" ship "$2" --cd "$4"
  ' _ "$REPO_ROOT" "$op" "$calls" "$work")"
  if [[ "$(sort "$calls" | tr "\n" " ")" == "$first $second " ]] && [[ "$out" == *"state: cancelled"* ]]; then
    pass "$name"
  else
    fail "$name" "calls=$(cat "$calls" 2>/dev/null || true) out=$out"
  fi
}

case_cancel_rejects_foreign_operation() {
  local name="operation cancel: foreign project target is rejected before child cancellation"
  should_run "$name" || return 0
  local first="$tmp_root/cancel-first" second="$tmp_root/cancel-second" store="$tmp_root/cancel-foreign-state" op rc=0
  make_repo "$first"; make_repo "$second"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$first" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_cancel "$REPO_ROOT" gate "$op" --cd "$second" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "expected 2 got $rc"; fi
}

case_cancel_intent_blocks_reconcile_and_late_attachment() {
  local name="operation cancel: cancellation intent blocks reconcile overwrite and late attachment"
  should_run "$name" || return 0
  local work="$tmp_root/cancel-intent-work" store="$tmp_root/cancel-intent-state" op first late state out rc=0
  make_repo "$work"; first="run-20260724T000020Z-aaaaaa"; late="run-20260724T000021Z-bbbbbb"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" ship codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$first" "$work"
  # The child-cancel stub deliberately calls reconcile while cancel is in
  # progress.  Reconcile must defer instead of terminalizing the parent.
  out="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '
    . "$1/runtime/lib/portable.sh"
    . "$1/runtime/lib/pmctl-operation.sh"
    pmctl_dispatch_cancel() {
      pmctl_operation_reconcile "$1" ship "$2" --cd "$3" >/dev/null 2>&1 || true
      return 0
    }
    pmctl_operation_cancel "$1" ship "$2" --cd "$3"
  ' _ "$REPO_ROOT" "$op" "$work" 2>&1)" || rc=$?
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$late" "$work" >/dev/null 2>&1 || true
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  if [[ "$rc" -eq 0 && "$out" == *"state: cancelled"* ]] \
     && [[ "$(jq -r .state "${state%/}/operations/$op.json")" == cancelled ]] \
     && [[ "$(wc -l < "${state%/}/operations/$op/children.jsonl")" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out state=$(jq -r .state "${state%/}/operations/$op.json" 2>/dev/null || true)"
  fi
}

case_childless_producer_failure_is_terminal() {
  local name="operation producer: childless preflight failure is terminal"
  should_run "$name" || return 0
  local work="$tmp_root/childless-work" store="$tmp_root/childless-state" op state
  make_repo "$work"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_fail_if_childless "$REPO_ROOT" gate "$op" "$work"
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  if [[ "$(jq -r .state "${state%/}/operations/$op.json")" == failed ]]; then
    pass "$name"
  else
    fail "$name" "state=$(jq -r .state "${state%/}/operations/$op.json" 2>/dev/null || true)"
  fi
}

case_concurrent_attach_preserves_complete_child_records() {
  local name="operation attach: concurrent children are appended as two complete records"
  should_run "$name" || return 0
  local work="$tmp_root/concurrent-attach-work" store="$tmp_root/concurrent-attach-state" op first second state p1 p2
  make_repo "$work"; first="run-20260724T000040Z-aaaaaa"; second="run-20260724T000041Z-bbbbbb"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  (PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$first" "$work") & p1=$!
  (PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$second" "$work") & p2=$!
  wait "$p1"; wait "$p2"
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  if [[ "$(jq -s 'length == 2 and ([.[].run_id] | sort) == ["'"$first"'","'"$second"'"]' "${state%/}/operations/$op/children.jsonl")" == true ]]; then
    pass "$name"
  else
    fail "$name" "children=$(cat "${state%/}/operations/$op/children.jsonl" 2>/dev/null || true)"
  fi
}

case_cancel_deduplicates_repeated_child_records() {
  local name="operation cancel: repeated child record is cancelled once"
  should_run "$name" || return 0
  local work="$tmp_root/dedupe-work" store="$tmp_root/dedupe-state" op run_id calls out
  make_repo "$work"; run_id="run-20260724T000050Z-aaaaaa"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" ship codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  calls="$tmp_root/dedupe-calls"
  out="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '
    . "$1/runtime/lib/portable.sh"
    . "$1/runtime/lib/pmctl-operation.sh"
    calls="$3"
    pmctl_dispatch_cancel() { printf "%s\\n" "$2" >> "$calls"; return 0; }
    pmctl_operation_cancel "$1" ship "$2" --cd "$4"
  ' _ "$REPO_ROOT" "$op" "$calls" "$work")"
  if [[ "$(wc -l < "$calls")" -eq 1 && "$(cat "$calls")" == "$run_id" && "$out" == *"state: cancelled"* ]]; then
    pass "$name"
  else
    fail "$name" "calls=$(cat "$calls" 2>/dev/null || true) out=$out"
  fi
}

case_cancel_refuses_reused_producer_identity() {
  local name="operation cancel: producer identity mismatch is indeterminate and never signalled"
  should_run "$name" || return 0
  _require_setsid "$name" || return 0
  local work="$tmp_root/producer-mismatch-work" store="$tmp_root/producer-mismatch-state"
  local op producer release record state tampered out rc=0 reconcile_rc=0 fail_rc=0
  make_repo "$work"
  release="$tmp_root/producer-mismatch-release"
  mkfifo "$release"
  # shellcheck disable=SC2016 # $1 belongs to the spawned bash.
  setsid bash -c 'IFS= read -r _ < "$1"' _ "$release" &
  producer=$!
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_register_producer "$REPO_ROOT" gate "$op" "$work" "$producer"
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$op.json"
  tampered="$(jq -c '.producer.identity.starttime="1"' "$record")"
  ( cd "$work" && PM_DISPATCH_STATE_ROOT="$store" operation_upsert "$op" "$tampered" )
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_cancel "$REPO_ROOT" gate "$op" --cd "$work" --grace 0 2>&1)" || rc=$?
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd "$work" >/dev/null 2>&1 || reconcile_rc=$?
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_fail_if_childless "$REPO_ROOT" gate "$op" "$work" >/dev/null 2>&1 || fail_rc=$?
  if [[ "$rc" -ne 0 && "$(jq -r .state "$record")" == indeterminate ]] \
     && kill -0 "$producer" 2>/dev/null \
     && [[ "$reconcile_rc" -ne 0 && "$fail_rc" -ne 0 ]] \
     && [[ "$out" == *"identity mismatch"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc reconcile=$reconcile_rc fail_if_childless=$fail_rc producer=$producer state=$(jq -r .state "$record" 2>/dev/null || true) out=$out"
  fi
  kill -TERM -- "-$producer" 2>/dev/null || true
  wait "$producer" 2>/dev/null || true
}

case_cancel_accepts_producer_that_exited_before_signal() {
  local name="operation cancel: an already-exited registered producer can terminalize cancelled"
  should_run "$name" || return 0
  _require_setsid "$name" || return 0
  local work="$tmp_root/producer-gone-work" store="$tmp_root/producer-gone-state"
  local op producer release record state out
  make_repo "$work"
  release="$tmp_root/producer-gone-release"
  mkfifo "$release"
  # shellcheck disable=SC2016 # $1 belongs to the spawned bash.
  setsid bash -c 'IFS= read -r _ < "$1"' _ "$release" &
  producer=$!
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_register_producer "$REPO_ROOT" gate "$op" "$work" "$producer"
  printf 'release\n' > "$release"
  wait "$producer"
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_cancel "$REPO_ROOT" gate "$op" --cd "$work" --grace 0)"
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$op.json"
  if [[ "$(jq -r .state "$record")" == cancelled ]] \
     && [[ "$(jq -r .producer.status "$record")" == stopped ]] \
     && [[ "$out" == *"producer_failures: 0"* ]]; then
    pass "$name"
  else
    fail "$name" "state=$(jq -c . "$record" 2>/dev/null || true) out=$out"
  fi
}

case_repeated_cancel_preserves_cancelled_terminal() {
  local name="operation cancel: repeated cancel preserves the first cancelled terminal"
  should_run "$name" || return 0
  local work="$tmp_root/repeated-cancel-work" store="$tmp_root/repeated-cancel-state"
  local op first second rc=0 state record
  make_repo "$work"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  first="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_cancel "$REPO_ROOT" gate "$op" --cd "$work")"
  second="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_cancel "$REPO_ROOT" gate "$op" --cd "$work" 2>&1)" || rc=$?
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$op.json"
  if [[ "$rc" -eq 1 && "$(jq -r .state "$record")" == cancelled ]] \
     && [[ "$first" == *"state: cancelled"* ]] \
     && [[ "$second" == *"already terminal"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc first=$first second=$second state=$(jq -r .state "$record" 2>/dev/null || true)"
  fi
}

# Verifies that reserving producer ownership survives the native-Windows
# replace boundary when MSYS mv cannot overwrite the existing operation file.
# Behavior: the writer falls back to PowerShell File.Replace without exposing
# a missing or partial operation record.
# Steps: create an operation normally, force mv to fail under the Windows
# platform override, provide path/PowerShell stubs, then assert pending state.
_install_replace_cygpath_stub() {
  local target="$1" real_cygpath
  real_cygpath="$(command -v cygpath || true)"
  # Keep replacement paths usable by the Bash PowerShell stub, but preserve
  # real -m canonicalization for operation ownership checks on native Windows.
  # shellcheck disable=SC2016 # Arguments expand when the stub runs.
  printf '#!/usr/bin/env bash\nif [[ "$1" == "-w" ]]; then\n  shift\n  [[ "${1:-}" == "--" ]] && shift\n  printf "%%s\\n" "$1"\n  exit 0\nfi\n' > "$target"
  if [[ -n "$real_cygpath" ]]; then
    # shellcheck disable=SC2016 # Forward the generated stub's arguments.
    printf 'exec %q "$@"\n' "$real_cygpath" >> "$target"
  else
    printf 'exit 1\n' >> "$target"
  fi
}

case_expect_producer_windows_replace_fallback() {
  local name="operation producer reservation: native Windows replace fallback preserves the record"
  should_run "$name" || return 0
  local work="$tmp_root/windows replace work" store="$tmp_root/windows replace state"
  local stubs="$tmp_root/windows-replace-stubs" sink="$tmp_root/windows-replace-called"
  local op state record real_mv replace_args replace_src replace_dest
  local replace_src_dir replace_dest_normal replace_before replace_after rc=0
  make_repo "$work"
  _pmctl_operation_load_writer "$REPO_ROOT"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  state="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$work" _sw_project_dir)"
  record="${state%/}/operations/$op.json"
  real_mv="$(command -v mv)"
  mkdir -p "$stubs"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$stubs/mv"
  _install_replace_cygpath_stub "$stubs/cygpath"
  cat > "$stubs/powershell.exe" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# issue #592: state_store_init's Windows ACL guard now also shells to
# powershell.exe (a DIFFERENT -Command script, matched here by its own
# env var) on every state write, including the operation-record write this
# case exercises. Answer that invocation shape distinctly from the
# replace-file fallback below, which this case is actually testing --
# report the store root safe so the test reaches its real subject.
if [[ -n "${PM_DISPATCH_ACL_PATH:-}" ]]; then
  printf 'SAFE\n'
  exit 0
fi
# This is the observable replacement boundary: a fallback that unlinks or
# partially rewrites the destination before invoking ReplaceFile must fail the
# regression instead of being hidden by the final-state assertion.
[[ -f "$PM_DISPATCH_REPLACE_SOURCE" && -f "$PM_DISPATCH_REPLACE_DESTINATION" ]]
jq -e 'type == "object" and .id != null and .state != null' \
  "$PM_DISPATCH_REPLACE_SOURCE" "$PM_DISPATCH_REPLACE_DESTINATION" >/dev/null
before="$(jq -c . "$PM_DISPATCH_REPLACE_DESTINATION")"
"$CC587_REAL_MV" -f -- "$PM_DISPATCH_REPLACE_SOURCE" "$PM_DISPATCH_REPLACE_DESTINATION"
[[ ! -e "$PM_DISPATCH_REPLACE_SOURCE" && -f "$PM_DISPATCH_REPLACE_DESTINATION" ]]
jq -e 'type == "object" and .id != null and .state != null' \
  "$PM_DISPATCH_REPLACE_DESTINATION" >/dev/null
after="$(jq -c . "$PM_DISPATCH_REPLACE_DESTINATION")"
printf '%s\n%s\n%s\n%s\n%s\n' "$*" "$PM_DISPATCH_REPLACE_SOURCE" \
  "$PM_DISPATCH_REPLACE_DESTINATION" "$before" "$after" > "$CC587_REPLACE_SINK"
EOF
  chmod +x "$stubs/mv" "$stubs/cygpath" "$stubs/powershell.exe"
  PATH="$stubs:$PATH" PM_DISPATCH_PLATFORM=windows PM_DISPATCH_STATE_ROOT="$store" \
    CC587_REAL_MV="$real_mv" CC587_REPLACE_SINK="$sink" \
    pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work" || rc=$?
  replace_args="$(sed -n '1p' "$sink" 2>/dev/null || true)"
  replace_src="$(sed -n '2p' "$sink" 2>/dev/null || true)"
  replace_dest="$(sed -n '3p' "$sink" 2>/dev/null || true)"
  replace_before="$(sed -n '4p' "$sink" 2>/dev/null || true)"
  replace_after="$(sed -n '5p' "$sink" 2>/dev/null || true)"
  replace_src_dir="$(realpath_m "${replace_src%/*}" 2>/dev/null || true)"
  replace_dest_normal="$(realpath_m "$replace_dest" 2>/dev/null || true)"
  # shellcheck disable=SC2016 # The assertion requires literal PowerShell $env references.
  if [[ "$rc" -eq 0 && -f "$sink" && -f "$record" \
      && "$replace_args" == *'[System.IO.File]::Replace($env:PM_DISPATCH_REPLACE_SOURCE, $env:PM_DISPATCH_REPLACE_DESTINATION, $null)'* \
      && "$replace_args" != *"$record"* && "${replace_src##*/}" == .tmp-* \
      && "$replace_src_dir" == "${record%/*}" && "$replace_dest_normal" == "$record" \
      && "$(jq -r '.producer // ""' <<< "$replace_before")" == "" \
      && "$(jq -r '.producer.status // ""' <<< "$replace_after")" == pending \
      && "$(jq -r '.producer.status // ""' "$record")" == pending ]] \
      && ! find "${record%/*}" -maxdepth 1 -name '.tmp-*' -print -quit | grep -q .; then
    pass "$name"
  else
    fail "$name" "rc=$rc record=$(jq -c . "$record" 2>/dev/null || true) fallback=$([[ -f "$sink" ]] && printf called || printf missing) args=$replace_args src=$replace_src dest=$replace_dest before=$replace_before after=$replace_after temps=$(find "${record%/*}" -maxdepth 1 -name '.tmp-*' -print 2>/dev/null | tr '\n' '|')"
  fi
}

# Behavior: a failed native-Windows replacement preserves the existing valid
# operation projection, reports failure, and removes its temporary projection.
# Steps: force both the primary mv and PowerShell fallback to fail, then compare
# the record byte-for-byte and validate it through the writer's schema boundary.
case_expect_producer_windows_replace_failure_preserves_record() {
  local name="operation producer reservation: failed Windows replace preserves record and cleans temp"
  should_run "$name" || return 0
  local work="$tmp_root/windows replace failure work"
  local store="$tmp_root/windows replace failure state"
  local stubs="$tmp_root/windows-replace-failure-stubs"
  local sink="$tmp_root/windows-replace-failure-called"
  local op state record before after rc=0 schema_rc=0
  make_repo "$work"
  _pmctl_operation_load_writer "$REPO_ROOT"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  state="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$work" _sw_project_dir)"
  record="${state%/}/operations/$op.json"
  before="$(cat "$record")"
  mkdir -p "$stubs"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$stubs/mv"
  _install_replace_cygpath_stub "$stubs/cygpath"
  cat > "$stubs/powershell.exe" <<'EOF'
#!/usr/bin/env bash
# issue #592: answer the store-root ACL-check invocation (a different
# -Command script, matched by its own env var) distinctly from the
# replace-file fallback below, which this case is actually testing --
# report the store root safe so the induced replace failure below is what
# actually fails the call, not an unrelated store-root rejection.
if [[ -n "${PM_DISPATCH_ACL_PATH:-}" ]]; then
  printf 'SAFE\n'
  exit 0
fi
printf 'called\n' > "$CC587_REPLACE_FAILURE_SINK"
exit 23
EOF
  chmod +x "$stubs/mv" "$stubs/cygpath" "$stubs/powershell.exe"
  PATH="$stubs:$PATH" PM_DISPATCH_PLATFORM=windows PM_DISPATCH_STATE_ROOT="$store" \
    CC587_REPLACE_FAILURE_SINK="$sink" \
    pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work" \
    >/dev/null 2>&1 || rc=$?
  after="$(cat "$record" 2>/dev/null || true)"
  _sw_validate_compacted_json_line operation "$after" >/dev/null 2>&1 || schema_rc=$?
  if [[ "$rc" -ne 0 && "$schema_rc" -eq 0 && -f "$sink" \
      && "$after" == "$before" && "$(jq -r '.producer // ""' "$record")" == "" ]] \
      && ! find "${record%/*}" -maxdepth 1 -name '.tmp-*' -print -quit | grep -q .; then
    pass "$name"
  else
    fail "$name" "rc=$rc schema_rc=$schema_rc fallback=$([[ -f "$sink" ]] && printf called || printf missing) before=$before after=$after temps=$(find "${record%/*}" -maxdepth 1 -name '.tmp-*' -print 2>/dev/null | tr '\n' '|')"
  fi
}

# Behavior: a record's stored working_dir and a caller's --cd can be two valid
# but differently spelled forms of the same native-Windows path (POSIX
# /c/Users/... vs drive-letter C:/Users/...); ownership validation must accept
# that equivalence instead of rejecting the record as foreign (CC-587).
# Steps: hand-write a record whose working_dir is drive-letter form, stub
# cygpath to perform the same /x -> X: fold `_portable_canonical_path` relies
# on, then validate against an equivalent POSIX spelling and a genuinely
# different directory.
case_validate_record_canonicalizes_windows_path_spelling() {
  local name="operation record validation: equivalent Windows path spellings are the same owner"
  should_run "$name" || return 0
  local stubs="$tmp_root/windows-spelling-stubs"
  local record="$tmp_root/windows-spelling-record.json"
  local rc=0 other_rc=0
  mkdir -p "$stubs"
  cat > "$stubs/cygpath" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "-m" && "$2" == "--" ]] || exit 1
path="$3"
if [[ "$path" =~ ^/([A-Za-z])(/.*)?$ ]]; then
  printf '%s:%s\n' "${BASH_REMATCH[1]^^}" "${BASH_REMATCH[2]:-/}"
else
  printf '%s\n' "$path"
fi
EOF
  chmod +x "$stubs/cygpath"
  jq -n '{schema_version:1,id:"op-windows-spelling-test",kind:"gate",
    working_dir:"C:/Users/First Last/repo",state:"running",
    created_ts:"2026-01-01T00:00:00Z",terminal_ts:null,producer:null,
    cancellation:null}' > "$record"
  (
    # shellcheck disable=SC2030,SC2031  # deliberately subshell-local; only this call needs the stubbed cygpath.
    PATH="$stubs:$PATH"
    _pmctl_operation_validate_record "$record" gate "/c/Users/First Last/repo"
  ) || rc=$?
  (
    # shellcheck disable=SC2030,SC2031  # deliberately subshell-local; only this call needs the stubbed cygpath.
    PATH="$stubs:$PATH"
    _pmctl_operation_validate_record "$record" gate "/c/Users/Someone/other"
  ) || other_rc=$?
  if [[ "$rc" -eq 0 && "$other_rc" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "equivalent-spelling-rc=$rc different-path-rc=$other_rc"
  fi
}

# Behavior: _pmctl_operation_is_absolute_dir accepts both POSIX and Windows
# drive-letter absolute forms. pmctl_operation_create's and
# pmctl_operation_attach_child's own absolute-path guards used a POSIX-only
# `== /*` test that rejected every call on native Windows, where
# pmctl-dispatch.sh's --cd handling canonicalizes the path to drive-letter
# form (e.g. c:/Users/...) before this library ever sees it -- rejecting it
# before _pmctl_operation_validate_record even runs, with a silent exit 2
# (CC-587). This is the actual root cause behind the 100% native-Windows gate
# failure; the earlier record-ownership canonicalization fix alone was
# insufficient because this guard rejected the call first.
case_absolute_dir_accepts_windows_drive_letter_form() {
  local name="operation absolute-path guard: accepts Windows drive-letter form"
  should_run "$name" || return 0
  local rc=0
  if _pmctl_operation_is_absolute_dir '/posix/style/path' \
      && _pmctl_operation_is_absolute_dir 'C:/Users/First Last/repo' \
      && _pmctl_operation_is_absolute_dir 'c:/users/first' \
      && ! _pmctl_operation_is_absolute_dir 'relative/path' \
      && ! _pmctl_operation_is_absolute_dir 'C:no-slash-after-colon'; then
    pass "$name"
  else
    fail "$name" "one or more absolute-dir classifications were wrong"
  fi
}

# Behavior: pmctl_operation_attach_child itself (not just the predicate in
# isolation) accepts a Windows drive-letter-form child_dir end-to-end.
# Steps: create a real parent operation on a POSIX work dir, then attach a
# child using a synthetic drive-letter-spelled child_dir; the guard must let
# it through and the appended child record must preserve that exact spelling
# (attach_child does not canonicalize its stored value).
case_attach_child_accepts_windows_drive_letter_child_dir() {
  local name="operation attach: accepts a Windows drive-letter child_dir"
  should_run "$name" || return 0
  local work="$tmp_root/win-child-dir-work" store="$tmp_root/win-child-dir-state"
  local op run_id="run-20260917T000000Z-abcdef" rc=0 state record children
  make_repo "$work"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child \
    "$REPO_ROOT" "$work" "$op" "$run_id" 'C:/Users/First Last/child-repo' || rc=$?
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$op/children.jsonl"
  children="$(cat "$record" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 \
      && "$(jq -r '.working_dir' <<<"$children")" == 'C:/Users/First Last/child-repo' ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc children=$children"
  fi
}

case_unknown_operation_is_diagnosed_not_silent() {
  local name="operation cancel/reconcile: unknown id reports why instead of exiting silently"
  should_run "$name" || return 0
  local work="$tmp_root/unknown-work" store="$tmp_root/unknown-state" unknown out rc verb
  make_repo "$work"; unknown="op-20260724T085509Z-62e179"
  for verb in cancel reconcile; do
    rc=0
    out="$(PM_DISPATCH_STATE_ROOT="$store" "pmctl_operation_$verb" "$REPO_ROOT" gate "$unknown" --cd "$work" 2>&1)" || rc=$?
    if [[ "$rc" -ne 2 ]]; then fail "$name" "$verb expected rc 2 got $rc"; return 0; fi
    # An id copied from a PR body or another host is the common operator error;
    # the failure must name it rather than exit non-zero with no output.
    if [[ "$out" != *"no operation $unknown recorded"* || "$out" != *"machine-local"* ]]; then
      fail "$name" "$verb produced no actionable diagnostic: out=$out"; return 0
    fi
  done
  pass "$name"
}

case_reconcile_usage_on_malformed_invocation() {
  local name="operation reconcile: malformed invocation prints usage"
  should_run "$name" || return 0
  local work="$tmp_root/usage-work" store="$tmp_root/usage-state" out rc=0
  make_repo "$work"
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate --bogus --cd "$work" 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 && "$out" == *"usage: pmctl <gate|ship|task> reconcile"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out"
  fi
}

case_relative_cd_resolves_to_the_same_operation() {
  local name="operation reconcile: relative --cd resolves the recorded operation"
  should_run "$name" || return 0
  local work="$tmp_root/relative-work" store="$tmp_root/relative-state" op out rc=0
  make_repo "$work"
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  # `--cd .` must reach the same record as the absolute path; path
  # normalisation of "." previously aborted under `set -u`.
  out="$(cd "$work" && PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd . 2>&1)" || rc=$?
  if [[ "$out" == *"operation: $op"* && "$out" != *"no operation"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out"
  fi
}

case_writer_loader_repairs_partial_inherited_functions
case_reconcile_windows_child_terminal_claim
case_reconcile_uses_trusted_terminal_claims
case_reconcile_defers_while_producer_is_running
case_reconcile_recovers_dead_registered_producer
case_reconcile_rejects_malformed_producer_identity
case_create_collision_never_overwrites_record
case_unknown_operation_is_diagnosed_not_silent
case_reconcile_usage_on_malformed_invocation
case_relative_cd_resolves_to_the_same_operation
case_reconcile_rejects_foreign_operation
case_reconcile_never_infers_success_without_claim
case_cancel_targets_only_recorded_children
case_cancel_rejects_foreign_operation
case_cancel_intent_blocks_reconcile_and_late_attachment
case_childless_producer_failure_is_terminal
case_concurrent_attach_preserves_complete_child_records
case_cancel_deduplicates_repeated_child_records
case_cancel_refuses_reused_producer_identity
case_cancel_accepts_producer_that_exited_before_signal
case_repeated_cancel_preserves_cancelled_terminal
case_expect_producer_windows_replace_fallback
case_expect_producer_windows_replace_failure_preserves_record
case_validate_record_canonicalizes_windows_path_spelling
case_absolute_dir_accepts_windows_drive_letter_form
case_attach_child_accepts_windows_drive_letter_child_dir
th_summary
