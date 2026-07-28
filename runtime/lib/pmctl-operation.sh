#!/usr/bin/env bash
# Durable parent-operation control plane shared by dispatch-capable producers.

_PMCTL_OPERATION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(type -t _portable_canonical_path 2>/dev/null)" != function ]]; then
  # shellcheck source=runtime/lib/portable.sh
  # shellcheck disable=SC1091 # sourced by repository-relative runtime path
  . "$_PMCTL_OPERATION_LIB_DIR/portable.sh"
fi

_pmctl_operation_stamp() { date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ; }
_pmctl_operation_hex6() { od -An -N3 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' | cut -c1-6; }
_pmctl_operation_ts() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ; }

_pmctl_operation_load_writer() {
  local repo_root lib
  repo_root="$1"
  lib="$repo_root/runtime/lib/state-writer.sh"
  [[ "$(type -t operation_create 2>/dev/null)" == function ]] && return 0
  [[ -r "$lib" ]] || return 1
  # shellcheck source=/dev/null # repo-root-relative runtime library
  . "$lib"
  [[ "$(type -t operation_create 2>/dev/null)" == function ]]
}

_pmctl_operation_load_detached_launch() {
  local repo_root="$1" lib
  [[ "$(type -t detached_launch_capture_identity 2>/dev/null)" == function \
    && "$(type -t detached_launch_verify_identity 2>/dev/null)" == function \
    && "$(type -t detached_launch_kill_process_group 2>/dev/null)" == function ]] \
    && return 0
  lib="$repo_root/runtime/lib/detached-launch.sh"
  [[ -r "$lib" ]] || return 1
  # shellcheck source=/dev/null # repo-root-relative runtime library
  . "$lib"
  [[ "$(type -t detached_launch_capture_identity 2>/dev/null)" == function \
    && "$(type -t detached_launch_verify_identity 2>/dev/null)" == function \
    && "$(type -t detached_launch_kill_process_group 2>/dev/null)" == function ]]
}

# _pmctl_operation_ensure_loaded <repo-root>
# Callers that already loaded this library use one common readiness check before
# creating or reconciling a parent operation.  Keeping the dependency check
# here prevents producer-specific lazy-load behavior from drifting apart.
_pmctl_operation_ensure_loaded() {
  local repo_root="$1"
  _pmctl_operation_load_writer "$repo_root" || return 1
  declare -F pmctl_operation_create >/dev/null 2>&1 \
    && declare -F pmctl_operation_attach_child >/dev/null 2>&1 \
    && declare -F pmctl_operation_expect_producer >/dev/null 2>&1 \
    && declare -F pmctl_operation_register_producer >/dev/null 2>&1 \
    && declare -F pmctl_operation_reconcile >/dev/null 2>&1
}

_pmctl_operation_dir() {
  local repo_root="$1" work_dir="$2" operation_id="$3" project_dir
  _pmctl_operation_load_writer "$repo_root" || return 1
  project_dir="$(cd "$work_dir" && _SW_REPO_ROOT="$work_dir" _sw_project_dir)" || return 1
  [[ -n "$project_dir" ]] || return 1
  printf '%s/operations/%s\n' "${project_dir%/}" "$operation_id"
}

# pmctl_operation_create <repo-root> <work-dir> <gate|ship|task> [executor]
pmctl_operation_create() {
  local repo_root="$1" work_dir="$2" kind="$3" executor="${4:-}" id ts json attempt rc
  [[ "$kind" =~ ^(gate|ship|task)$ && "$work_dir" == /* && -d "$work_dir" ]] || return 2
  _pmctl_operation_load_writer "$repo_root" || return 2
  # Timestamp-plus-random IDs make collisions extraordinarily unlikely, but
  # creation must still be non-destructive if one does occur.
  for ((attempt = 0; attempt < 16; attempt += 1)); do
    id="op-$(_pmctl_operation_stamp)-$(_pmctl_operation_hex6)"; ts="$(_pmctl_operation_ts)"
    json="$(jq -cn --arg id "$id" --arg kind "$kind" --arg dir "$work_dir" --arg executor "$executor" --arg ts "$ts" \
      '{schema_version:1,id:$id,kind:$kind,working_dir:$dir,executor:(if $executor == "" then null else $executor end),state:"running",created_ts:$ts,terminal_ts:null,producer:null,cancellation:null}')" || return 1
    ( cd "$work_dir" && operation_create "$id" "$json" ) && { printf '%s\n' "$id"; return 0; }
    rc=$?
    [[ "$rc" -eq 3 ]] || return "$rc"
  done
  printf 'operation create: could not reserve a unique operation ID after 16 attempts\n' >&2
  return 1
}

# pmctl_operation_attach_child <repo-root> <parent-work-dir> <op-id> <run-id> <child-work-dir>
_pmctl_operation_attach_child_inner() {
  local repo_root="$1" parent_dir="$2" op_id="$3" run_id="$4" child_dir="$5" ts json record
  record="$(_pmctl_operation_record_path "$repo_root" "$parent_dir" "$op_id")" || return 2
  _pmctl_operation_validate_record "$record" "$(jq -r '.kind // ""' "$record")" "$parent_dir" || return $?
  # A cancellation request owns the operation before it starts cancelling
  # children.  Refuse late attachment so that cancel cannot miss a child
  # appended after its child-list snapshot.
  [[ "$PMCTL_OPERATION_RECORD_STATE" == running ]] || return 3
  ts="$(_pmctl_operation_ts)"
  json="$(jq -cn --arg run_id "$run_id" --arg work_dir "$child_dir" --arg ts "$ts" '{run_id:$run_id,working_dir:$work_dir,attached_ts:$ts}')" || return 1
  ( cd "$parent_dir" && operation_child_append "$op_id" "$json" )
}

pmctl_operation_attach_child() {
  local repo_root="$1" parent_dir="$2" op_id="$3" run_id="$4" child_dir="$5" op_dir
  [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ && "$child_dir" == /* ]] || return 2
  _pmctl_operation_load_writer "$repo_root" || return 2
  op_dir="$(_pmctl_operation_dir "$repo_root" "$parent_dir" "$op_id")" || return 2
  [[ -f "${op_dir%/*}/${op_id}.json" ]] || return 2
  _pmctl_operation_with_record_lock "$repo_root" "$parent_dir" "$op_id" \
    _pmctl_operation_attach_child_inner "$repo_root" "$parent_dir" "$op_id" "$run_id" "$child_dir"
}

_pmctl_operation_usage() {
  printf 'usage: pmctl <gate|ship|task> cancel <operation-id> --cd <work_dir> [--grace <seconds>]\n' >&2
}

_pmctl_operation_reconcile_usage() {
  printf 'usage: pmctl <gate|ship|task> reconcile <operation-id> --cd <work_dir>\n' >&2
}

# Operation records live in the machine-local state store, so an id copied from
# a PR body, a chat log, or another host resolves to nothing here.  Say so
# explicitly instead of exiting non-zero in silence.
_pmctl_operation_unknown_msg() {
  local kind="$1" verb="$2" operation_id="$3" work_dir="$4"
  printf 'pmctl %s %s: no operation %s recorded for %s\n' "$kind" "$verb" "$operation_id" "$work_dir" >&2
  printf 'pmctl %s %s: operation ids are machine-local; one created on another host or repo is not resolvable here\n' \
    "$kind" "$verb" >&2
}

# Records store the absolute working_dir enforced by pmctl_operation_create, and
# ownership is decided by comparing against it.  Resolve caller-supplied --cd the
# same way so a relative path is not misreported as a foreign operation.
_pmctl_operation_resolve_cd() {
  local raw="$1" abs
  abs="$(cd "$raw" 2>/dev/null && pwd -P)" || return 1
  _portable_canonical_path "$abs"
}

_pmctl_operation_record_path() {
  local repo_root="$1" work_dir="$2" operation_id="$3" op_dir
  op_dir="$(_pmctl_operation_dir "$repo_root" "$work_dir" "$operation_id")" || return 1
  printf '%s/%s.json\n' "${op_dir%/*}" "$operation_id"
}

_pmctl_operation_record_lock_base() {
  local repo_root="$1" work_dir="$2" operation_id="$3" op_dir
  op_dir="$(_pmctl_operation_dir "$repo_root" "$work_dir" "$operation_id")" || return 1
  # The record lives at operations/<id>.json; operations/<id>/ is reserved
  # for children.jsonl and is not created until the first child attaches.
  printf '%s/%s.record\n' "${op_dir%/*}" "$operation_id"
}

_pmctl_operation_validate_record() {
  local record="$1" expected_kind="$2" work_dir="$3" json kind owner
  # 5 distinguishes "no such operation" from 2 "exists but foreign/malformed",
  # so callers can name the operator's actual mistake.
  [[ -f "$record" ]] || return 5
  json="$(jq -c . "$record")" || return 2
  kind="$(jq -r '.kind // ""' <<<"$json")"
  owner="$(jq -r '.working_dir // ""' <<<"$json")"
  [[ "$kind" == "$expected_kind" && "$owner" == "$work_dir" ]] || return 2
  PMCTL_OPERATION_RECORD_JSON="$json"
  PMCTL_OPERATION_RECORD_STATE="$(jq -r '.state // ""' <<<"$json")"
}

# Run all parent record read-modify-write transitions under one operation-local
# lock. Child append uses a separate lock so launch/cancel never observes a
# half-written JSONL line, while terminal ownership remains single-writer.
_pmctl_operation_with_record_lock() {
  local repo_root="$1" work_dir="$2" operation_id="$3"; shift 3
  local lock_base record
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  [[ -f "$record" ]] || return 5
  lock_base="$(_pmctl_operation_record_lock_base "$repo_root" "$work_dir" "$operation_id")" || return 2
  serialize_with_lock "$lock_base" "$@"
}

_pmctl_operation_mark_cancelling_inner() {
  local repo_root="$1" expected_kind="$2" work_dir="$3" operation_id="$4" record ts updated
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return $?
  case "$PMCTL_OPERATION_RECORD_STATE" in
    completed|failed|cancelled) return 3 ;;
    cancelling) return 4 ;;
    running|indeterminate) : ;;
    *) return 2 ;;
  esac
  ts="$(_pmctl_operation_ts)"
  updated="$(jq -c --arg ts "$ts" \
    '.state="cancelling"
      | .cancellation={requested_ts:$ts,actor:"pmctl",producer_failures:null,child_failures:null}' \
    <<<"$PMCTL_OPERATION_RECORD_JSON")" || return 2
  ( cd "$work_dir" && operation_upsert "$operation_id" "$updated" )
}

_pmctl_operation_finish_cancel_inner() {
  local repo_root="$1" expected_kind="$2" work_dir="$3" operation_id="$4"
  local producer_failures="$5" child_failures="$6" record ts next updated
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return $?
  [[ "$PMCTL_OPERATION_RECORD_STATE" == cancelling ]] || return 3
  ts="$(_pmctl_operation_ts)"; next="cancelled"
  [[ "$producer_failures" -eq 0 && "$child_failures" -eq 0 ]] || next="indeterminate"
  updated="$(jq -c --arg state "$next" --arg ts "$ts" \
    --argjson producer_failures "$producer_failures" --argjson child_failures "$child_failures" \
    '.state=$state | .terminal_ts=$ts
      | .cancellation.producer_failures=$producer_failures
      | .cancellation.child_failures=$child_failures' \
    <<<"$PMCTL_OPERATION_RECORD_JSON")" || return 2
  ( cd "$work_dir" && operation_upsert "$operation_id" "$updated" )
}

_pmctl_operation_identity_json() {
  local repo_root="$1" pid="$2" snapshot line key value
  local id_pid="" state="" pgid="" starttime="" comm="" isolated="" boot_id=""
  _pmctl_operation_load_detached_launch "$repo_root" || return 2
  snapshot="$(detached_launch_capture_identity "$pid" 2>/dev/null)" || return 2
  while IFS= read -r line || [[ -n "$line" ]]; do
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      pid) id_pid="$value" ;;
      state) state="$value" ;;
      pgid) pgid="$value" ;;
      starttime) starttime="$value" ;;
      comm) comm="$value" ;;
      isolated) isolated="$value" ;;
      boot_id) boot_id="$value" ;;
    esac
  done <<<"$snapshot"
  [[ "$id_pid" == "$pid" && "$pid" =~ ^[1-9][0-9]*$ \
    && "$pgid" =~ ^[1-9][0-9]*$ && "$starttime" =~ ^[0-9]+$ \
    && "$isolated" =~ ^[01]$ ]] || return 2
  jq -cn --argjson pid "$pid" --arg state "$state" --argjson pgid "$pgid" \
    --arg starttime "$starttime" --arg comm "$comm" --arg isolated "$isolated" \
    --arg boot_id "$boot_id" \
    '{pid:$pid,state:$state,pgid:$pgid,starttime:$starttime,comm:$comm,
      isolated:($isolated == "1"),boot_id:$boot_id}'
}

_pmctl_operation_expect_producer_inner() {
  local repo_root="$1" expected_kind="$2" work_dir="$3" operation_id="$4"
  local record ts updated
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return $?
  [[ "$PMCTL_OPERATION_RECORD_STATE" == running ]] || return 3
  [[ "$(jq -r '.producer == null' <<<"$PMCTL_OPERATION_RECORD_JSON")" == true ]] || return 3
  ts="$(_pmctl_operation_ts)"
  updated="$(jq -c --arg ts "$ts" \
    '.producer={status:"pending",phase:"gate",identity:null,
      expected_ts:$ts,registered_ts:null,stopped_ts:null}' \
    <<<"$PMCTL_OPERATION_RECORD_JSON")" || return 2
  ( cd "$work_dir" && operation_upsert "$operation_id" "$updated" )
}

# Declare that this operation will launch one producer process.  Gate calls
# this before exposing the operation id, so cancel can never mistake the small
# launch/registration window for a genuinely childless operation.
pmctl_operation_expect_producer() {
  local repo_root="$1" expected_kind="$2" operation_id="$3" work_dir="$4"
  _pmctl_operation_load_writer "$repo_root" || return 2
  _pmctl_operation_with_record_lock "$repo_root" "$work_dir" "$operation_id" \
    _pmctl_operation_expect_producer_inner "$repo_root" "$expected_kind" "$work_dir" "$operation_id"
}

_pmctl_operation_register_producer_inner() {
  local repo_root="$1" expected_kind="$2" work_dir="$3" operation_id="$4" identity="$5"
  local record ts status next_status updated rc=0
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return $?
  status="$(jq -r '.producer.status // ""' <<<"$PMCTL_OPERATION_RECORD_JSON")"
  [[ "$status" == pending ]] || return 3
  case "$PMCTL_OPERATION_RECORD_STATE" in
    running) next_status=running ;;
    cancelling) next_status=stopping; rc=130 ;;
    cancelled) next_status=stopped; rc=130 ;;
    *) return 3 ;;
  esac
  ts="$(_pmctl_operation_ts)"
  updated="$(jq -c --arg status "$next_status" --arg ts "$ts" --argjson identity "$identity" \
    '.producer.status=$status | .producer.identity=$identity
      | .producer.registered_ts=$ts
      | if $status == "stopped" then .producer.stopped_ts=$ts else . end' \
    <<<"$PMCTL_OPERATION_RECORD_JSON")" || return 2
  ( cd "$work_dir" && operation_upsert "$operation_id" "$updated" ) || return 2
  return "$rc"
}

# Register only the calling producer's kernel identity.  The public cancel
# command never accepts a PID; this producer-side API captures /proc evidence
# before persisting it in the trusted operation record.
pmctl_operation_register_producer() {
  local repo_root="$1" expected_kind="$2" operation_id="$3" work_dir="$4" producer_pid="$5"
  local identity rc=0
  identity="$(_pmctl_operation_identity_json "$repo_root" "$producer_pid")" || return 2
  _pmctl_operation_with_record_lock "$repo_root" "$work_dir" "$operation_id" \
    _pmctl_operation_register_producer_inner "$repo_root" "$expected_kind" "$work_dir" \
      "$operation_id" "$identity" || rc=$?
  return "$rc"
}

_pmctl_operation_mark_producer_stopped_inner() {
  local repo_root="$1" expected_kind="$2" work_dir="$3" operation_id="$4"
  local record ts updated
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return $?
  [[ "$PMCTL_OPERATION_RECORD_STATE" == cancelling ]] || return 3
  [[ "$(jq -r '.producer.status // ""' <<<"$PMCTL_OPERATION_RECORD_JSON")" =~ ^(running|stopping|stopped)$ ]] \
    || return 3
  ts="$(_pmctl_operation_ts)"
  updated="$(jq -c --arg ts "$ts" \
    '.producer.status="stopped" | .producer.stopped_ts=$ts' \
    <<<"$PMCTL_OPERATION_RECORD_JSON")" || return 2
  ( cd "$work_dir" && operation_upsert "$operation_id" "$updated" )
}

_pmctl_operation_identity_file_from_json() {
  local identity="$1" destination="$2"
  jq -er '
    (.pid | tostring) as $pid
    | (.pgid | tostring) as $pgid
    | (.starttime | tostring) as $starttime
    | (.isolated | if . then "1" else "0" end) as $isolated
    | "pid=\($pid)\nstate=\(.state)\npgid=\($pgid)\nstarttime=\($starttime)\ncomm=\(.comm)\nisolated=\($isolated)\nboot_id=\(.boot_id)\n"
  ' <<<"$identity" >"$destination"
}

_pmctl_operation_stop_producer() {
  local repo_root="$1" expected_kind="$2" work_dir="$3" operation_id="$4" grace="$5"
  local record deadline status identity identity_file pid pgid isolated verify_rc
  _pmctl_operation_load_detached_launch "$repo_root" || return 1
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 1
  deadline=$((SECONDS + grace + 1))
  while true; do
    _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return 1
    status="$(jq -r '.producer.status // "none"' <<<"$PMCTL_OPERATION_RECORD_JSON")"
    case "$status" in
      none|stopped) return 0 ;;
      pending)
        if (( SECONDS >= deadline )); then
          printf 'pmctl %s cancel: producer registration did not settle for %s; refusing cancelled terminal state\n' \
            "$expected_kind" "$operation_id" >&2
          return 1
        fi
        sleep 0.05
        continue
        ;;
      running|stopping) : ;;
      *)
        printf 'pmctl %s cancel: invalid producer status %s for %s\n' \
          "$expected_kind" "$status" "$operation_id" >&2
        return 1
        ;;
    esac
    identity="$(jq -c '.producer.identity // null' <<<"$PMCTL_OPERATION_RECORD_JSON")"
    [[ "$identity" != null ]] || {
      if (( SECONDS >= deadline )); then return 1; fi
      sleep 0.05
      continue
    }
    identity_file="$(mktemp /tmp/pm-operation-producer-XXXXXX.identity)" || return 1
    if ! _pmctl_operation_identity_file_from_json "$identity" "$identity_file" \
      || ! detached_launch_load_identity_file "$identity_file"; then
      rm -f "$identity_file"
      printf 'pmctl %s cancel: invalid trusted producer identity for %s\n' \
        "$expected_kind" "$operation_id" >&2
      return 1
    fi
    pid="$DL_ID_PID"; pgid="$DL_ID_PGID"; isolated="$DL_ID_ISOLATED"
    verify_rc=0
    detached_launch_verify_identity "$pid" "$identity_file" || verify_rc=$?
    case "$verify_rc" in
      0)
        if [[ "$isolated" != 1 || "$pid" != "$pgid" ]]; then
          rm -f "$identity_file"
          printf 'pmctl %s cancel: producer %s is not an isolated process-group leader; refusing signal\n' \
            "$expected_kind" "$operation_id" >&2
          return 1
        fi
        if ! detached_launch_kill_process_group "$pgid" "$grace"; then
          rm -f "$identity_file"
          printf 'pmctl %s cancel: producer process group %s for %s remains live; refusing cancelled terminal state\n' \
            "$expected_kind" "$pgid" "$operation_id" >&2
          return 1
        fi
        ;;
      1) : ;;
      2)
        rm -f "$identity_file"
        printf 'pmctl %s cancel: producer identity mismatch for %s (pid=%s); refusing signal\n' \
          "$expected_kind" "$operation_id" "$pid" >&2
        return 1
        ;;
      *) rm -f "$identity_file"; return 1 ;;
    esac
    rm -f "$identity_file"
    _pmctl_operation_with_record_lock "$repo_root" "$work_dir" "$operation_id" \
      _pmctl_operation_mark_producer_stopped_inner "$repo_root" "$expected_kind" \
        "$work_dir" "$operation_id" || return 1
    return 0
  done
}

# Returns 0 only when cancellation owns the operation terminal transition.
pmctl_operation_cancellation_requested() {
  local repo_root="$1" expected_kind="$2" operation_id="$3" work_dir="$4" record state
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return 2
  state="$PMCTL_OPERATION_RECORD_STATE"
  PMCTL_OPERATION_CANCELLATION_STATE="$state"
  [[ "$state" == cancelling || "$state" == cancelled \
    || ( "$state" == indeterminate \
      && "$(jq -r '.cancellation != null' <<<"$PMCTL_OPERATION_RECORD_JSON")" == true ) ]]
}

_pmctl_operation_reconcile_inner() {
  local repo_root="$1" expected_kind="$2" work_dir="$3" operation_id="$4"
  local record op_dir line run_id child_dir missing=0 failed=0 cancelled=0 children=0 next ts updated
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return $?
  case "$PMCTL_OPERATION_RECORD_STATE" in
    completed|failed|cancelled)
      printf 'operation: %s  state: %s  already-terminal: true\n' "$operation_id" "$PMCTL_OPERATION_RECORD_STATE"
      return 0
      ;;
    cancelling)
      printf 'operation: %s  state: cancelling  reconciliation: deferred\n' "$operation_id"
      return 1
      ;;
    indeterminate)
      if [[ "$(jq -r '.cancellation != null' <<<"$PMCTL_OPERATION_RECORD_JSON")" == true ]]; then
        printf 'operation: %s  state: indeterminate  cancellation: unresolved\n' "$operation_id"
        return 1
      fi
      ;;
  esac
  op_dir="$(_pmctl_operation_dir "$repo_root" "$work_dir" "$operation_id")" || return 2
  if [[ -f "$op_dir/children.jsonl" ]]; then
    while IFS= read -r line; do
      run_id="$(jq -r '.run_id // ""' <<<"$line")"; child_dir="$(jq -r '.working_dir // ""' <<<"$line")"
      [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ && "$child_dir" == /* ]] || { missing=$((missing + 1)); continue; }
      children=$((children + 1))
      if ! _pmctl_dispatch_read_terminal_claim "$child_dir" "$run_id"; then missing=$((missing + 1)); continue; fi
      case "$PMCTL_TERMINAL_STATE" in failed|partial) failed=$((failed + 1)) ;; cancelled) cancelled=$((cancelled + 1)) ;; ok) : ;; *) missing=$((missing + 1)) ;; esac
    done < "$op_dir/children.jsonl"
  fi
  [[ "$children" -gt 0 ]] || missing=1
  if [[ "$missing" -gt 0 ]]; then next="indeterminate"; elif [[ "$cancelled" -gt 0 ]]; then next="cancelled"; elif [[ "$failed" -gt 0 ]]; then next="failed"; else next="completed"; fi
  ts="$(_pmctl_operation_ts)"
  updated="$(jq -c --arg state "$next" --arg ts "$ts" \
    '.state=$state | .terminal_ts=$ts
      | if .producer != null then
          .producer.status="stopped" | .producer.stopped_ts=$ts
        else . end' <<<"$PMCTL_OPERATION_RECORD_JSON")" || return 2
  ( cd "$work_dir" && operation_upsert "$operation_id" "$updated" ) || return 2
  printf 'operation: %s  state: %s  children: %s  unresolved: %s\n' "$operation_id" "$next" "$children" "$missing"
  [[ "$next" != indeterminate ]]
}

_pmctl_operation_fail_if_childless_inner() {
  local repo_root="$1" expected_kind="$2" work_dir="$3" operation_id="$4" record op_dir ts updated
  record="$(_pmctl_operation_record_path "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_validate_record "$record" "$expected_kind" "$work_dir" || return $?
  [[ "$PMCTL_OPERATION_RECORD_STATE" == running || "$PMCTL_OPERATION_RECORD_STATE" == indeterminate ]] || return 3
  if [[ "$PMCTL_OPERATION_RECORD_STATE" == indeterminate \
    && "$(jq -r '.cancellation != null' <<<"$PMCTL_OPERATION_RECORD_JSON")" == true ]]; then
    return 3
  fi
  op_dir="$(_pmctl_operation_dir "$repo_root" "$work_dir" "$operation_id")" || return 2
  [[ ! -s "$op_dir/children.jsonl" ]] || return 1
  ts="$(_pmctl_operation_ts)"
  updated="$(jq -c --arg ts "$ts" \
    '.state="failed" | .terminal_ts=$ts
      | if .producer != null then
          .producer.status="stopped" | .producer.stopped_ts=$ts
        else . end' <<<"$PMCTL_OPERATION_RECORD_JSON")" || return 2
  ( cd "$work_dir" && operation_upsert "$operation_id" "$updated" )
}

# Mark a producer as failed only when it never launched a child.  This is the
# producer-side completion path for pre-flight failures; once a child exists,
# only trusted dispatch terminal claims may decide the parent state.
pmctl_operation_fail_if_childless() {
  local repo_root="$1" expected_kind="$2" operation_id="$3" work_dir="$4"
  _pmctl_operation_load_writer "$repo_root" || return 2
  _pmctl_operation_with_record_lock "$repo_root" "$work_dir" "$operation_id" \
    _pmctl_operation_fail_if_childless_inner "$repo_root" "$expected_kind" "$work_dir" "$operation_id"
}

# pmctl_operation_cancel <repo-root> <expected-kind> <operation-id> --cd <dir>
# Cancellation is ownership-based: only children recorded below this operation
# are considered, and each child is cancelled through the existing trusted
# dispatch primitive (never by accepting a PID from the caller).
pmctl_operation_cancel() {
  local repo_root="$1" expected_kind="$2"; shift 2
  local operation_id="" work_dir="" grace=5
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd) [[ $# -ge 2 ]] || { _pmctl_operation_usage; return 2; }; work_dir="$(_pmctl_operation_resolve_cd "$2")" || { _pmctl_operation_usage; return 2; }; shift 2 ;;
      --grace) [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || { _pmctl_operation_usage; return 2; }; grace="$2"; shift 2 ;;
      --*) _pmctl_operation_usage; return 2 ;;
      *) [[ -z "$operation_id" ]] || { _pmctl_operation_usage; return 2; }; operation_id="$1"; shift ;;
    esac
  done
  [[ "$operation_id" =~ ^op-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$ && -n "$work_dir" && -d "$work_dir" ]] || { _pmctl_operation_usage; return 2; }
  _pmctl_operation_load_writer "$repo_root" || return 2
  local op_dir mark_rc=0
  op_dir="$(_pmctl_operation_dir "$repo_root" "$work_dir" "$operation_id")" || return 2
  _pmctl_operation_with_record_lock "$repo_root" "$work_dir" "$operation_id" \
    _pmctl_operation_mark_cancelling_inner "$repo_root" "$expected_kind" "$work_dir" "$operation_id" || mark_rc=$?
  case "$mark_rc" in
    0) : ;;
    3) printf 'pmctl %s cancel: operation %s already terminal\n' "$expected_kind" "$operation_id"; return 1 ;;
    4) printf 'pmctl %s cancel: operation %s cancellation already in progress\n' "$expected_kind" "$operation_id"; return 1 ;;
    5) _pmctl_operation_unknown_msg "$expected_kind" cancel "$operation_id" "$work_dir"; return 2 ;;
    *) printf 'pmctl %s cancel: foreign or invalid operation target refused\n' "$expected_kind" >&2; return 2 ;;
  esac

  local producer_failures=0
  _pmctl_operation_stop_producer "$repo_root" "$expected_kind" "$work_dir" \
    "$operation_id" "$grace" || producer_failures=1

  local line run_id child_dir rc child_failures=0 seen=" "
  if [[ -f "$op_dir/children.jsonl" ]]; then
    while IFS= read -r line; do
      run_id="$(jq -r '.run_id // ""' <<<"$line" 2>/dev/null || true)"; child_dir="$(jq -r '.working_dir // ""' <<<"$line" 2>/dev/null || true)"
      [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ && "$child_dir" == /* && "$seen" != *" $run_id "* ]] || continue
      seen+="$run_id "
      rc=0; pmctl_dispatch_cancel "$repo_root" "$run_id" --cd "$child_dir" --grace "$grace" || rc=$?
      # A child already terminal is a valid cancel race outcome; unknown or
      # identity failures keep the parent non-successful and diagnosable.
      [[ "$rc" -eq 0 || "$rc" -eq 1 ]] || child_failures=$((child_failures + 1))
    done < "$op_dir/children.jsonl"
  fi
  _pmctl_operation_with_record_lock "$repo_root" "$work_dir" "$operation_id" \
    _pmctl_operation_finish_cancel_inner "$repo_root" "$expected_kind" "$work_dir" \
      "$operation_id" "$producer_failures" "$child_failures" || return $?
  local next_state="cancelled"
  [[ "$producer_failures" -eq 0 && "$child_failures" -eq 0 ]] || next_state="indeterminate"
  printf 'operation: %s  state: %s  producer_failures: %s  child_failures: %s\n' \
    "$operation_id" "$next_state" "$producer_failures" "$child_failures"
  [[ "$producer_failures" -eq 0 && "$child_failures" -eq 0 ]]
}

# pmctl_operation_reconcile <repo-root> <expected-kind> <operation-id> --cd <dir>
# Never infers completion from workspace records.  The only success evidence is
# every recorded child having the dispatch layer's trusted terminal claim.
pmctl_operation_reconcile() {
  local repo_root="$1" expected_kind="$2"; shift 2
  local operation_id="" work_dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd) [[ $# -ge 2 ]] || { _pmctl_operation_reconcile_usage; return 2; }; work_dir="$(_pmctl_operation_resolve_cd "$2")" || { _pmctl_operation_reconcile_usage; return 2; }; shift 2 ;;
      --*) _pmctl_operation_reconcile_usage; return 2 ;;
      *) [[ -z "$operation_id" ]] || { _pmctl_operation_reconcile_usage; return 2; }; operation_id="$1"; shift ;;
    esac
  done
  [[ "$operation_id" =~ ^op-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$ && -n "$work_dir" && -d "$work_dir" ]] || { _pmctl_operation_reconcile_usage; return 2; }
  _pmctl_operation_load_writer "$repo_root" || return 2
  local rc=0
  _pmctl_operation_with_record_lock "$repo_root" "$work_dir" "$operation_id" \
    _pmctl_operation_reconcile_inner "$repo_root" "$expected_kind" "$work_dir" "$operation_id" || rc=$?
  case "$rc" in
    5) _pmctl_operation_unknown_msg "$expected_kind" reconcile "$operation_id" "$work_dir"; return 2 ;;
    2) printf 'pmctl %s reconcile: foreign or invalid operation target refused\n' "$expected_kind" >&2; return 2 ;;
  esac
  return "$rc"
}

unset _PMCTL_OPERATION_LIB_DIR
