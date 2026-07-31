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

case_writer_loader_repairs_partial_inherited_functions() {
  local name="operation lock: partial inherited writer functions reload before producer registration"
  should_run "$name" || return 0
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
  setsid sleep 30 & producer=$!
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_register_producer "$REPO_ROOT" gate "$op" "$work" "$producer"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$store" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  out="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_reconcile "$REPO_ROOT" gate "$op" --cd "$work" 2>&1)" || rc=$?
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  kill -TERM -- "-$producer" 2>/dev/null || true; wait "$producer" 2>/dev/null || true
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
  setsid sleep 30 & producer=$!
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_register_producer "$REPO_ROOT" gate "$op" "$work" "$producer"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$store" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  kill -KILL -- "$producer" 2>/dev/null || true
  wait "$producer" 2>/dev/null || true
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
  setsid sleep 30 & producer=$!
  op="$(PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_expect_producer "$REPO_ROOT" gate "$op" "$work"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_register_producer "$REPO_ROOT" gate "$op" "$work" "$producer"
  PM_DISPATCH_STATE_ROOT="$store" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$store" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  state="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '. "$1/runtime/lib/state-writer.sh"; cd "$2"; _sw_project_dir' _ "$REPO_ROOT" "$work")"
  record="${state%/}/operations/$op.json"
  kill -KILL -- "$producer" 2>/dev/null || true
  wait "$producer" 2>/dev/null || true
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
th_summary
