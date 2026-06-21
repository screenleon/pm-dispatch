#!/usr/bin/env bash

# Executor-agnostic dispatch orchestrator.
#
# `pmctl dispatch run --adapter <name> --cd <dir> --brief-file <path>` OWNS the
# shared dispatch flow and composes the M2-extracted pieces; the adapter under
# `adapters/<name>/dispatch.sh` stays thin (executor invocation + the
# `.agent-trace/latest.last` output-contract glue only).
#
# Flow (each step is executor-agnostic except step 5):
#   1. validate adapter name (strict identifier) + resolve by convention
#   2. route + allowlist             executor-router: MANDATORY, fail-closed
#   3. brief-validate                scripts/brief-validate.sh
#  3a. optional auto-pack             context reuse-scan + pointer-only brief copy
#   4. guard                         pmctl guard check (shared policy, MANDATORY)
#   5. invoke adapter subprocess     the ONLY executor-specific step
#   6. read output contract          .agent-trace/latest.last (read-only)
#   7. post-verify                   scripts/dispatch-post-verify.sh
#
# The validate+guard invariant covers every dispatch that reaches an executor:
# an adapter that resolves AND routes is always brief-validated and guarded
# before invocation. Pre-flight rejections (invalid name, unknown adapter,
# non-routable executor) fail fast BEFORE brief work — intentionally, since there
# is no executor to guard for and no point validating a brief for a dispatch that
# cannot run.
#
# Policy invariants (every dispatch through pmctl is validated AND guarded —
# there is no bypass door):
#   - `--brief-file` is REQUIRED; the inline `-- <brief>` form is rejected, so no
#     execution can skip brief-validate + guard. (The adapter still accepts inline
#     form for direct smoke checks, but the policy surface — pmctl — does not.)
#   - `--adapter` MUST be a bare identifier `^[a-z][a-z0-9_-]*$`; it is never a
#     path, so a crafted value cannot traverse out of `adapters/` to execute an
#     arbitrary `dispatch.sh`.
#   - Routing is the allowlist: the executor MUST resolve to a registered route.
#     If the routing registry (executor-router) or the guard (pmctl-guard) is not
#     available, the dispatch is REFUSED — the allowlist/guard is never skipped.
#   - The ONLY data read back from an adapter is the output contract
#     (latest.last + exit code) — never the executor-internal trace format.
#   - No executor-specific invocation tokens live here; the only executor identity
#     used is the adapter NAME string (path resolution + `guard check --role
#     executor --runtime <adapter>`).
#
# Exit-code contract:
#   0  — adapter succeeded and post-verify passed (or was skipped on dry-run)
#   2  — usage error, invalid/unknown/non-routable adapter, brief rejected,
#        guard denied, or a required dependency (router/guard) unavailable
#   1  — post-verify failed after a successful adapter run
#   *  — any other non-zero adapter exit is propagated verbatim

# Source the shared config loader so pmctl_dispatch_run can resolve config
# defaults and export them to adapter subprocesses.
if ! declare -F pm_config_load >/dev/null 2>&1; then
  _pmctl_dispatch_lib_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck disable=SC1091  # dynamic path; pmctl-config.sh scanned separately
  . "$_pmctl_dispatch_lib_dir/pmctl-config.sh" 2>/dev/null || true
  unset _pmctl_dispatch_lib_dir
fi

# Source portable.sh so --cd canonicalization (_portable_canonical_path) works
# even when this lib is loaded standalone (e.g. unit tests); no-op in the full
# pmctl runtime where portable.sh is already loaded.
if ! declare -F _portable_canonical_path >/dev/null 2>&1; then
  _pmctl_dispatch_lib_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck disable=SC1091  # dynamic path; portable.sh scanned separately
  . "$_pmctl_dispatch_lib_dir/portable.sh" 2>/dev/null || true
  unset _pmctl_dispatch_lib_dir
fi

if ! declare -F dispatch_record_write >/dev/null 2>&1; then
  _pmctl_dispatch_lib_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck disable=SC1091  # dynamic path; dispatch-record.sh scanned separately
  . "$_pmctl_dispatch_lib_dir/dispatch-record.sh" 2>/dev/null || true
  unset _pmctl_dispatch_lib_dir
fi

pmctl_dispatch_extract_model() {
  local model=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)
        if [[ $# -ge 2 ]]; then
          model="$2"
          shift 2
        else
          shift
        fi
        ;;
      *)
        shift
        ;;
    esac
  done
  # Fall back to config default so Run rows record the effective model, not "".
  # Adapter built-in defaults (below PM_CFG_DEFAULT_MODEL) are not captured here;
  # that would require the adapter to expose its resolved model via the footer.
  if [[ -z "$model" && -n "${PM_CFG_DEFAULT_MODEL:-}" ]]; then
    model="$PM_CFG_DEFAULT_MODEL"
  fi
  printf '%s\n' "$model"
}

pmctl_dispatch_utc_ts() {
  date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ
}

pmctl_dispatch_stamp() {
  date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ
}

pmctl_dispatch_hex6() {
  local hex
  hex="$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  printf '%s\n' "${hex:0:6}"
}

pmctl_dispatch_ensure_state_writer() {
  local repo_root="${1:-}"
  if declare -F sw_build_run_json >/dev/null 2>&1 \
    && declare -F runs_append >/dev/null 2>&1 \
    && declare -F events_append >/dev/null 2>&1; then
    return 0
  fi
  # shellcheck disable=SC1091  # dynamic repo root path.
  . "$repo_root/scripts/lib/state-writer.sh"
}

pmctl_dispatch_write_event() {
  local repo_root="${1:-}" work_dir="${2:-}" kind="${3:-}" run_id="${4:-}"
  local state="${5:-}" exit_code="${6:-0}" adapter="${7:-}" note="${8:-}"
  local operation_id="${9:-}"
  local from_state="${10:-}"
  local ts evt_id event_json rc=0

  pmctl_dispatch_ensure_state_writer "$repo_root" || return $?
  [[ "$exit_code" =~ ^-?[0-9]+$ ]] || return 1
  ts="$(pmctl_dispatch_utc_ts)"
  evt_id="evt-$(pmctl_dispatch_stamp)-$(pmctl_dispatch_hex6)"
  event_json="$(jq -cn \
    --arg id "$evt_id" \
    --arg ts "$ts" \
    --arg kind "$kind" \
    --arg subject_id "$run_id" \
    --arg actor "pmctl" \
    --arg run_id "$run_id" \
    --arg state "$state" \
    --arg from_state "$from_state" \
    --arg adapter "$adapter" \
    --arg note "$note" \
    --arg operation_id "$operation_id" \
    --argjson exit_code "$exit_code" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,subject_type:"run",subject_id:$subject_id,actor:$actor,payload:({run_id:$run_id,state:$state,from_state:$from_state,to_state:$state,exit_code:$exit_code,adapter:$adapter} + (if $note == "" then {} else {note:$note} end))} + (if $operation_id == "" then {} else {operation_id:$operation_id} end)'
  )" || return $?
  _SW_REPO_ROOT="$work_dir" events_append "$event_json" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    printf 'pmctl dispatch run: failed to append %s event for %s\n' "$kind" "$run_id" >&2
    return "$rc"
  fi
  return 0
}

pmctl_dispatch_write_run() {
  local repo_root="${1:-}" adapter="${2:-}" state="${3:-}" exit_code="${4:-1}" model="${5:-}"
  local brief_file="${6:-}" work_dir="${7:-}" trace_path="${8:-}" run_id="${9:-}"
  local created_ts="${10:-}"
  local operation_id="${11:-}"
  local run_json rc=0

  pmctl_dispatch_ensure_state_writer "$repo_root" || return $?
  if ! run_json="$(_SW_RUN_ID_OVERRIDE="$run_id" _SW_CREATED_TS_OVERRIDE="$created_ts" \
    sw_build_run_json "$adapter" "$exit_code" "$state" "$model" "$brief_file" "$work_dir" "$trace_path" "" "$operation_id")"; then
    printf 'pmctl dispatch run: failed to build Run state for %s\n' "$run_id" >&2
    return 1
  fi
  _SW_REPO_ROOT="$work_dir" runs_append "$run_json" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    printf 'pmctl dispatch run: failed to append Run state for %s\n' "$run_id" >&2
    return "$rc"
  fi
  return 0
}

pmctl_dispatch_write_transition() {
  local repo_root="${1:-}" work_dir="${2:-}" adapter="${3:-}" run_id="${4:-}"
  local state="${5:-}" exit_code="${6:-0}" model="${7:-}" brief_file="${8:-}"
  local trace_path="${9:-}" created_ts="${10:-}"
  local from_state="${11:-}"
  local event_kind note="" op_id

  pmctl_dispatch_ensure_state_writer "$repo_root" || return $?
  case "$state" in
    pending) event_kind="run.pending" ;;
    dispatched) event_kind="run.dispatched" ;;
    verifying) event_kind="run.verifying" ;;
    ok) event_kind="run.completed" ;;
    partial)
      event_kind="run.completed"
      note="partial"
      ;;
    failed) event_kind="run.failed" ;;
    *)
      printf 'pmctl dispatch run: invalid Run transition state %q\n' "$state" >&2
      return 1
      ;;
  esac
  if ! run_transition_valid "$from_state" "$state"; then
    printf 'pmctl dispatch run: invalid transition %s->%s\n' "$from_state" "$state" >&2
    return 1
  fi
  op_id="op-$(pmctl_dispatch_stamp)-$(pmctl_dispatch_hex6)"

  pmctl_dispatch_write_run "$repo_root" "$adapter" "$state" "$exit_code" "$model" \
    "$brief_file" "$work_dir" "$trace_path" "$run_id" "$created_ts" "$op_id" || return $?
  pmctl_dispatch_write_event "$repo_root" "$work_dir" "$event_kind" "$run_id" \
    "$state" "$exit_code" "$adapter" "$note" "$op_id" "$from_state" || return $?
}

pmctl_dispatch_write_record_soft() {
  local run_id="${1:-}" adapter="${2:-}" model="${3:-}" brief_file="${4:-}" work_dir="${5:-}"
  local exit_code="${6:-}" final_state="${7:-}" verify_summary="${8:-}"
  local last_path="${9:-}" trace_path="${10:-}" stderr_path="${11:-}"
  local created_ts="${12:-}" finished_ts="${13:-}"
  local task_id=""

  if declare -F sw_extract_task_id >/dev/null 2>&1; then
    task_id="$(sw_extract_task_id "$brief_file" "" 2>/dev/null || true)"
    [[ "$task_id" == "UNKN-0" ]] && task_id=""
  fi

  if ! declare -F dispatch_record_write >/dev/null 2>&1; then
    printf 'pmctl dispatch run: failed to write dispatch record for %s (writer unavailable)\n' "$run_id" >&2
    return 0
  fi
  if ! dispatch_record_write "$run_id" "$task_id" "$adapter" "$model" "$brief_file" \
    "$work_dir" "$exit_code" "$final_state" "$verify_summary" "$last_path" \
    "$trace_path" "$stderr_path" "$created_ts" "$finished_ts"; then
    printf 'pmctl dispatch run: failed to write dispatch record for %s\n' "$run_id" >&2
  fi
  return 0
}

pmctl_dispatch_extract_goal() {
  local brief="$1"
  awk '
    function trim(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    function clean(s) {
      sub(/^[[:space:]]*-[[:space:]]*/, "", s)
      gsub(/[|>]/, " ", s)
      s = trim(s)
      if ((s ~ /^".*"$/) || (s ~ /^'\''.*'\''$/)) {
        s = substr(s, 2, length(s) - 2)
      }
      return trim(s)
    }
    /^goal:[[:space:]]*/ {
      line = $0
      sub(/^goal:[[:space:]]*/, "", line)
      line = trim(line)
      if (line ~ /^([|>][+-]?)?$/) {
        in_goal = 1
        next
      }
      print clean(line)
      found = 1
      exit
    }
    in_goal {
      if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/) {
        exit
      }
      line = clean($0)
      if (line != "") {
        out = (out == "" ? line : out " " line)
      }
    }
    END {
      if (!found && in_goal && out != "") {
        print out
      }
    }
  ' "$brief"
}

pmctl_dispatch_reuse_yaml_to_auto_context() {
  local yaml="$1"
  awk '
    function emit() {
      if (ref != "" && count < 5) {
        if (conf == "") {
          conf = "0"
        }
        gsub(/\\/, "\\\\", why)
        gsub(/"/, "\\\"", why)
        printf "  - ref: %s\n", ref
        printf "    why_relevant: \"%s\"\n", why
        printf "    confidence: %s\n", conf
        count += 1
      }
      ref = ""; why = ""; conf = ""
    }
    /^  hits:/ { in_hits = 1; next }
    in_hits && /^    - ref:[[:space:]]*/ {
      emit()
      ref = $0
      sub(/^    - ref:[[:space:]]*/, "", ref)
      next
    }
    in_hits && /^      why_relevant:[[:space:]]*/ {
      why = $0
      sub(/^      why_relevant:[[:space:]]*/, "", why)
      if (why ~ /^'\''.*'\''$/) {
        why = substr(why, 2, length(why) - 2)
        gsub(/'\'''\''/, "'\''", why)
      }
      next
    }
    in_hits && /^      confidence:[[:space:]]*/ {
      conf = $0
      sub(/^      confidence:[[:space:]]*/, "", conf)
      next
    }
    END { emit() }
  ' "$yaml"
}

pmctl_dispatch_emit_auto_packed_event() {
  local repo_root="${1:-}" run_id="${2:-}" hits="${3:-0}" pack="${4:-}" source_brief="${5:-}"
  local ts evt_id event_json append_err append_status=0

  pmctl_dispatch_ensure_state_writer "$repo_root" || {
    printf 'pmctl dispatch run: warning: context.auto_packed telemetry not recorded (state-writer unavailable)\n' >&2
    return 0
  }
  [[ "$hits" =~ ^[0-9]+$ ]] || hits=0
  ts="$(pmctl_dispatch_utc_ts)"
  evt_id="evt-$(pmctl_dispatch_stamp)-$(pmctl_dispatch_hex6)"
  if [[ "$evt_id" == "evt--" || "$evt_id" == *"-" ]]; then
    printf 'pmctl dispatch run: warning: context.auto_packed telemetry not recorded (could not generate event id)\n' >&2
    return 0
  fi
  if ! event_json="$(jq -cn \
    --arg id "$evt_id" \
    --arg ts "$ts" \
    --arg kind "context.auto_packed" \
    --arg run_id "$run_id" \
    --arg pack "$pack" \
    --arg source_brief "$source_brief" \
    --argjson hits "$hits" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,
      subject_type:"context",subject_id:$run_id,actor:"pmctl",
      payload:{run_id:$run_id,hits:$hits,pack:$pack,source_brief:$source_brief}}' 2>/dev/null)"; then
    printf 'pmctl dispatch run: warning: context.auto_packed telemetry not recorded (jq failed)\n' >&2
    return 0
  fi
  append_err="$(_SW_REPO_ROOT="$repo_root" events_append "$event_json" 2>&1)" || append_status=$?
  if [[ "$append_status" -ne 0 ]]; then
    printf 'pmctl dispatch run: warning: context.auto_packed telemetry not recorded: %s\n' "${append_err:-events_append failed}" >&2
  fi
  return 0
}

pmctl_dispatch_auto_pack() {
  local repo_root="${1:-}" work_dir="${2:-}" brief_file="${3:-}" run_id="${4:-}"
  local goal reuse_yaml reuse_err block_file block_hits pack_dir pack_path validate_msg validate_status=0

  if ! declare -F pmctl_context_reuse_scan >/dev/null 2>&1; then
    # shellcheck disable=SC1091  # dynamic repo root path.
    . "$repo_root/scripts/lib/pmctl-context.sh" 2>/dev/null || true
  fi
  if ! declare -F pmctl_context_reuse_scan >/dev/null 2>&1; then
    printf 'pmctl dispatch run: warning: auto-pack skipped: pmctl context reuse-scan unavailable\n' >&2
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  fi

  if ! goal="$(pmctl_dispatch_extract_goal "$brief_file" 2>/dev/null)" || [[ -z "$goal" ]]; then
    printf 'pmctl dispatch run: warning: auto-pack skipped: could not extract goal from %s\n' "$brief_file" >&2
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  fi

  reuse_err="$(mktemp)" || {
    printf 'pmctl dispatch run: warning: auto-pack skipped: mktemp failed\n' >&2
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  }
  if ! reuse_yaml="$(pmctl_context_reuse_scan "$work_dir" "$goal" 2>"$reuse_err")"; then
    printf 'pmctl dispatch run: warning: auto-pack skipped: reuse-scan failed: %s\n' "$(tr '\n' ' ' < "$reuse_err")" >&2
    rm -f "$reuse_err"
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  fi
  if [[ -s "$reuse_err" ]]; then
    printf '%s' "$(cat "$reuse_err")" >&2
    [[ "$(tail -c 1 "$reuse_err" 2>/dev/null || true)" == $'\n' ]] || printf '\n' >&2
  fi
  rm -f "$reuse_err"

  block_file="$(mktemp)" || {
    printf 'pmctl dispatch run: warning: auto-pack skipped: mktemp failed\n' >&2
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  }
  printf '%s\n' "$reuse_yaml" | pmctl_dispatch_reuse_yaml_to_auto_context /dev/stdin > "$block_file" || true
  block_hits="$(grep -c '^  - ref:' "$block_file" 2>/dev/null || true)"
  [[ "$block_hits" =~ ^[0-9]+$ ]] || block_hits=0
  if [[ "$block_hits" -eq 0 ]]; then
    rm -f "$block_file"
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  fi

  pack_dir="$work_dir/.pm-dispatch/ctx/packs"
  pack_path="$pack_dir/$run_id.md"
  if ! mkdir -p "$pack_dir"; then
    printf 'pmctl dispatch run: warning: auto-pack skipped: cannot create %s\n' "$pack_dir" >&2
    rm -f "$block_file"
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  fi
  if ! {
    cat "$brief_file"
    printf '\n\nauto_context:\n'
    printf '  # appended by pmctl dispatch run (auto-pack); pointers only - read on demand\n'
    cat "$block_file"
  } > "$pack_path"; then
    printf 'pmctl dispatch run: warning: auto-pack skipped: cannot write %s\n' "$pack_path" >&2
    rm -f "$block_file"
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  fi
  rm -f "$block_file"

  validate_msg="$(bash "$repo_root/scripts/brief-validate.sh" "$pack_path" 2>&1)" || validate_status=$?
  if [[ "$validate_status" -ne 0 ]]; then
    printf 'pmctl dispatch run: warning: auto-pack skipped: augmented brief failed validation: %s\n%s\n' "$pack_path" "$validate_msg" >&2
    rm -f "$pack_path"
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  fi
  if [[ -n "$validate_msg" && "$validate_msg" != "VALID" ]]; then
    printf '%s\n' "$validate_msg" >&2
  fi

  PMCTL_DISPATCH_AUTO_PACK_PATH="$pack_path"
  pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" "$block_hits" "$pack_path" "$brief_file"
  return 0
}

pmctl_dispatch_execute_tail() {
  local repo_root="${1:-}" work_dir="${2:-}" adapter="${3:-}" adapter_path="${4:-}"
  local _dispatch_run_id="${5:-}" _dispatch_model="${6:-}" brief_file="${7:-}"
  local _dispatch_created_ts="${8:-}" print_cmd="${9:-}"
  shift 9 || true
  local -a _forward=("$@")

  local _initial_state_written="${PMCTL_DISPATCH_INITIAL_STATE_WRITTEN:-0}"
  if [[ "$print_cmd" -eq 0 && "$_initial_state_written" != "1" ]]; then
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "pending" 0 "$_dispatch_model" "$brief_file" "" "$_dispatch_created_ts" "" || return $?
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "dispatched" 0 "$_dispatch_model" "$brief_file" "" "$_dispatch_created_ts" "pending" || return $?
  fi

  # Invoke the adapter subprocess and capture its stdout footer so per-run
  # artifact paths can be extracted for post-verify without relying on latest.*
  # symlinks. The footer is durable-local so a later recovery path can re-read
  # the adapter-declared paths after the adapter has exited.
  local exit_code=0 _footer_dir="" _footer_path=""
  local -a _pst=(0 0)
  _footer_dir="$work_dir/.agent-trace"
  _footer_path="$_footer_dir/$_dispatch_run_id.footer"
  mkdir -p "$_footer_dir" || { printf 'pmctl dispatch run: mkdir failed: %s\n' "$_footer_dir" >&2; return 2; }
  # Capture PIPESTATUS before any subsequent command clobbers it.  The { } group
  # is the LHS of ||, so set -e is suppressed for a non-zero pipeline exit.
  { bash "$adapter_path" "${_forward[@]}" | tee "$_footer_path"; _pst=("${PIPESTATUS[@]}"); } || true
  exit_code="${_pst[0]}"
  if [[ "${_pst[1]:-0}" -ne 0 ]]; then
    printf 'pmctl dispatch run: footer capture failed: %s\n' "$_footer_path" >&2
    return 2
  fi

  # Parse per-run paths from the adapter stdout footer ("last:   <path>",
  # "stderr: <path>"). Empty strings make post-verify fall back to latest.*.
  # "model:  <value>" overrides the pmctl-extracted model with the adapter's
  # effective model.
  local _run_last="" _run_trace="" _run_stderr="" _run_model=""
  _run_last="$(grep -m1 '^last:' "$_footer_path" | sed 's/^last:[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)" || true
  _run_trace="$(grep -m1 '^trace:' "$_footer_path" | sed 's/^trace:[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)" || true
  _run_stderr="$(grep -m1 '^stderr:' "$_footer_path" | sed 's/^stderr:[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)" || true
  _run_model="$(grep -m1 '^model:' "$_footer_path" | sed 's/^model:[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)" || true
  [[ -n "$_run_model" ]] && _dispatch_model="$_run_model"

  # Dry-run (--print-cmd): the adapter printed its command and wrote no trace;
  # there is no output contract to read and nothing to post-verify.
  if [[ "$print_cmd" -eq 1 ]]; then
    return "$exit_code"
  fi

  pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
    "verifying" "$exit_code" "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "dispatched" || return $?

  # A failed adapter run short-circuits: propagate its exit verbatim. The
  # adapter already wrote forensic trace/stderr for post-mortem.
  if [[ "$exit_code" -ne 0 ]]; then
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "failed" "$exit_code" "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "verifying" || return $?
    pmctl_dispatch_write_record_soft "$_dispatch_run_id" "$adapter" "$_dispatch_model" "$brief_file" \
      "$work_dir" "$exit_code" "failed" "adapter exited before post-verify (exit $exit_code)" \
      "${_run_last:-}" "${_run_trace:-}" "${_run_stderr:-}" "$_dispatch_created_ts" "$(pmctl_dispatch_utc_ts)"
    return "$exit_code"
  fi

  # Post-verify (shared): pass explicit per-run paths parsed from the footer, so
  # post-verify does not depend on shared latest.* symlinks. Falls back to
  # latest.* defaults when footer parsing found nothing.
  # Read the adapter's declared semantic terminal_event from its manifest and
  # thread it to post-verify, which asserts the trace carries at least one such
  # event (semantic completion, layered on the structural integrity check). Read
  # via the canonical manifest-field helper; sourced defensively so a missing lib
  # or absent field leaves the value empty and post-verify stays structure-only
  # (back-compat) rather than aborting dispatch.
  local _terminal_event="" _adapter_manifest="$repo_root/adapters/$adapter/adapter.yaml"
  if [[ -f "$_adapter_manifest" ]]; then
    if ! declare -F runner_kind_manifest_field >/dev/null 2>&1; then
      # shellcheck disable=SC1091  # dynamic repo root path.
      . "$repo_root/scripts/lib/runner-kind.sh" 2>/dev/null || true
    fi
    if declare -F runner_kind_manifest_field >/dev/null 2>&1; then
      _terminal_event="$(runner_kind_manifest_field "$_adapter_manifest" terminal_event 2>/dev/null || true)"
    fi
  fi

  local -a _pv_args=("$work_dir" "$brief_file")
  [[ -n "$_run_last" ]] && _pv_args+=(--last "$_run_last")
  [[ -n "$_run_trace" ]] && _pv_args+=(--jsonl "$_run_trace")
  [[ -n "$_run_stderr" ]] && _pv_args+=(--stderr "$_run_stderr")
  [[ -n "$_terminal_event" ]] && _pv_args+=(--terminal-event "$_terminal_event")
  local _pv_out="" _pv_rc=0
  if _pv_out="$(bash "$repo_root/scripts/dispatch-post-verify.sh" "${_pv_args[@]}")"; then
    _pv_rc=0
  else
    _pv_rc=$?
  fi
  printf '%s\n' "$_pv_out"
  if [[ "$_pv_rc" -ne 0 ]]; then
    printf 'pmctl dispatch run: post-verify failed\n' >&2
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "failed" 1 "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "verifying" || return $?
    pmctl_dispatch_write_record_soft "$_dispatch_run_id" "$adapter" "$_dispatch_model" "$brief_file" \
      "$work_dir" 1 "failed" "$_pv_out" "${_run_last:-}" "${_run_trace:-}" "${_run_stderr:-}" \
      "$_dispatch_created_ts" "$(pmctl_dispatch_utc_ts)"
    return 1
  fi

  pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
    "ok" "$exit_code" "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "verifying" || return $?
  pmctl_dispatch_write_record_soft "$_dispatch_run_id" "$adapter" "$_dispatch_model" "$brief_file" \
    "$work_dir" "$exit_code" "ok" "$_pv_out" "${_run_last:-}" "${_run_trace:-}" "${_run_stderr:-}" \
    "$_dispatch_created_ts" "$(pmctl_dispatch_utc_ts)"

  return "$exit_code"
}

# Resolve + security-gate an adapter by NAME: validate the bare identifier,
# resolve adapters/<name>/dispatch.sh, reject symlink/containment escapes, and
# enforce the route allowlist. Echoes the validated adapter_path on stdout; the
# route log line and all errors go to stderr; returns 2 on any failure.
#
# This is the shared security preflight used by BOTH pmctl_dispatch_run and the
# detached supervisor (scripts/dispatch-supervisor.sh), so a supervisor handed a
# tampered run-spec can never reach an executor that `pmctl dispatch run` would
# have refused. The identifier regex is duplicated in pmctl_dispatch_run's early
# input-validation block by design: each entry point is an independent gate.
pmctl_dispatch_resolve_adapter() {
  local repo_root="${1:-}" adapter="${2:-}"

  if ! [[ "$adapter" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    printf 'pmctl dispatch run: invalid adapter name %q (must be a bare lowercase identifier: a letter, then letters/digits/hyphen/underscore — no path separators)\n' "$adapter" >&2
    return 2
  fi

  local adapter_path="$repo_root/adapters/$adapter/dispatch.sh"
  if [[ ! -f "$adapter_path" ]]; then
    printf 'pmctl dispatch run: unknown adapter %q (no %s). An adapter must provide adapters/<name>/dispatch.sh; run pmctl adapter generate to scaffold it.\n' "$adapter" "$adapter_path" >&2
    return 2
  fi
  if [[ -L "$adapter_path" ]]; then
    printf 'pmctl dispatch run: adapter dispatch script must not be a symlink: %s\n' "$adapter_path" >&2
    return 2
  fi
  local _adapters_base _adapter_dir_real
  if ! _adapters_base="$(cd -P -- "$repo_root/adapters" 2>/dev/null && pwd -P)"; then
    printf 'pmctl dispatch run: adapters directory not found under %s\n' "$repo_root" >&2
    return 2
  fi
  if ! _adapter_dir_real="$(cd -P -- "$(dirname "$adapter_path")" 2>/dev/null && pwd -P)"; then
    printf 'pmctl dispatch run: cannot resolve adapter directory for %q\n' "$adapter" >&2
    return 2
  fi
  case "$_adapter_dir_real" in
    "$_adapters_base"/?*) : ;;
    *)
      printf 'pmctl dispatch run: adapter path escapes the adapters/ boundary: %s\n' "$_adapter_dir_real" >&2
      return 2
      ;;
  esac

  if ! declare -F dispatch_route_for >/dev/null; then
    printf 'pmctl dispatch run: routing registry unavailable (executor-router not sourced) — refusing to dispatch without allowlist enforcement\n' >&2
    return 2
  fi
  local route
  if ! route="$(dispatch_route_for "$adapter" 2>/dev/null)"; then
    printf 'pmctl dispatch run: %q is not a routable executor (not in the dispatch allowlist)\n' "$adapter" >&2
    return 2
  fi
  printf 'pmctl dispatch run: adapter=%s route=%s\n' "$adapter" "$route" >&2

  printf '%s\n' "$adapter_path"
}

# Shared brief-validate step: runs scripts/brief-validate.sh on the brief the
# adapter will consume, echoing any non-fatal validator notes to stderr. Used by
# BOTH pmctl_dispatch_run and the detached supervisor so every executor launch —
# foreground or detached — is fronted by the same brief schema check (a detached
# supervisor must not be able to launch an executor on a brief that
# `pmctl dispatch run` would reject). Returns 2 on validation failure.
pmctl_dispatch_validate_brief() {
  local repo_root="${1:-}" brief_file="${2:-}"
  local brief_result=0 brief_msg
  brief_msg="$(bash "$repo_root/scripts/brief-validate.sh" "$brief_file" 2>&1)" || brief_result=$?
  if [[ "$brief_result" -ne 0 ]]; then
    printf 'pmctl dispatch run: brief failed validation: %s\n%s\n' "$brief_file" "$brief_msg" >&2
    return 2
  fi
  if [[ -n "$brief_msg" && "$brief_msg" != "VALID" ]]; then
    printf '%s\n' "$brief_msg" >&2
  fi
  return 0
}

# Decide whether an adapter may run under a detached supervisor. Eligibility is
# DERIVED from the adapter's declared runner_kind, never a
# manifest lifecycle field: cli-subprocess executors are Model B subprocesses
# pmctl can reparent under a supervisor; host-native executors ARE the host and
# cannot be. Returns 0 (eligible), 1 (ineligible), 2 (cannot determine — fail
# closed). Prints a diagnostic on stderr for the non-eligible cases.
pmctl_dispatch_detach_eligible() {
  local repo_root="${1:-}" adapter="${2:-}"
  local manifest="$repo_root/adapters/$adapter/adapter.yaml" rk elig=0

  if ! declare -F runner_kind_detach_eligible >/dev/null 2>&1; then
    # shellcheck disable=SC1091  # dynamic repo root path.
    . "$repo_root/scripts/lib/runner-kind.sh" 2>/dev/null || true
  fi
  if ! declare -F runner_kind_detach_eligible >/dev/null 2>&1; then
    printf 'pmctl dispatch run: cannot evaluate detach eligibility for %q (runner-kind lib unavailable)\n' "$adapter" >&2
    return 2
  fi
  if [[ ! -r "$manifest" ]]; then
    printf 'pmctl dispatch run: cannot evaluate detach eligibility for %q (no readable manifest %s)\n' "$adapter" "$manifest" >&2
    return 2
  fi
  rk="$(runner_kind_manifest_field "$manifest" runner_kind 2>/dev/null || true)"
  if [[ -z "$rk" ]]; then
    printf 'pmctl dispatch run: adapter %q declares no runner_kind; detached dispatch requires a known runner-kind\n' "$adapter" >&2
    return 2
  fi
  runner_kind_detach_eligible "$rk" || elig=$?
  case "$elig" in
    0) return 0 ;;
    1)
      printf 'pmctl dispatch run: adapter %q (runner_kind=%s) is not detach-eligible; run it with --lifecycle foreground\n' "$adapter" "$rk" >&2
      return 1
      ;;
    *)
      printf 'pmctl dispatch run: adapter %q has unknown runner_kind %q; refusing detached dispatch\n' "$adapter" "$rk" >&2
      return 2
      ;;
  esac
}

# Serialize a validated, post-preflight run into a durable run-spec (schema v2)
# the detached supervisor consumes. The run-spec is the SINGLE source of truth:
# `cd_arg` (the --cd value the adapter receives) and `brief_file` (the brief that
# is guarded, validated, AND forwarded) are recorded as trusted scalars; the
# `native_b64` section carries ONLY the non-core adapter passthrough args
# (everything except --cd / --brief-file), base64-encoded one per line so the
# supervisor never word-splits user-influenced tokens. The supervisor rebuilds
# the adapter command as `--cd <cd_arg> --brief-file <brief_file> <native…>`, so
# the brief/work-dir the adapter runs are exactly the ones guarded and validated
# — there is no second, divergent source. Written atomically via mktemp + mv.
pmctl_dispatch_write_runspec() {
  local spec_path="${1:-}"; shift || true
  local run_id="${1:-}" adapter="${2:-}" work_dir="${3:-}" cd_arg="${4:-}" brief_file="${5:-}"
  local model="${6:-}" created_ts="${7:-}" print_cmd="${8:-}"
  shift 8 || true
  local -a native=("$@")
  local spec_dir tmp arg
  spec_dir="$(dirname "$spec_path")"
  tmp="$(mktemp "$spec_dir/.runspec.tmp.XXXXXX")" || return 1
  {
    printf 'schema_version=2\n'
    printf 'run_id=%s\n' "$run_id"
    printf 'adapter=%s\n' "$adapter"
    printf 'work_dir=%s\n' "$work_dir"
    printf 'cd_arg=%s\n' "$cd_arg"
    printf 'brief_file=%s\n' "$brief_file"
    printf 'model=%s\n' "$model"
    printf 'created_ts=%s\n' "$created_ts"
    printf 'print_cmd=%s\n' "$print_cmd"
    printf 'initial_state_written=1\n'
    printf 'native_b64:\n'
    for arg in ${native[@]+"${native[@]}"}; do
      printf '%s\n' "$(printf '%s' "$arg" | base64 | tr -d '\n')"
    done
  } > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$spec_path" || { rm -f "$tmp"; return 1; }
}

# Launch the detached supervisor as the only process-detachment boundary. The
# environment is intentionally inherited exactly like foreground dispatch:
# this deployment uses login-authenticated CLIs, not API keys in env, so the
# security gate explicitly approves no env unset/allowlist layer here.

# Derive the private sentinel key file path for a run_id. The key directory is
# per-user with mode 700, so only the owning user can list or read its contents.
# Both pmctl_dispatch_run_detached and pmctl_dispatch_wait use the same derivation
# so they find the same file without storing the path in the workspace.
_pmctl_sentinel_key_file() {
  local _run_id="${1:-}" _uid _key_dir
  _uid="$(id -u 2>/dev/null)" || _uid="0"
  if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR}" ]]; then
    _key_dir="${XDG_RUNTIME_DIR}/pm-dispatch"
  else
    _key_dir="/tmp/pm-dispatch-${_uid}"
  fi
  printf '%s/%s' "$_key_dir" "$_run_id"
}

_pmctl_dispatch_launch_supervisor() {
  local repo_root="${1:-}" spec_path="${2:-}" supervisor_log="${3:-}" pid_file="${4:-}"
  local supervisor pid

  supervisor="$repo_root/scripts/dispatch-supervisor.sh"
  mkdir -p "$(dirname "$supervisor_log")" "$(dirname "$pid_file")" || return 1

  if command -v setsid >/dev/null 2>&1; then
    setsid nohup bash "$supervisor" --run-spec "$spec_path" \
      </dev/null >"$supervisor_log" 2>&1 &
    pid=$!
  else
    nohup bash "$supervisor" --run-spec "$spec_path" \
      </dev/null >"$supervisor_log" 2>&1 &
    pid=$!
    disown "$pid" 2>/dev/null || true
  fi
  printf '%s\n' "$pid" > "$pid_file" || return 1
  return 0
}

# Detached lifecycle launcher. Splits the core --cd /
# --brief-file out of the forward args (recording them as trusted run-spec
# scalars) so the brief/work-dir the supervisor guards and validates are exactly
# the ones it forwards to the adapter, then persists the run-spec and invokes the
# supervisor under setsid/nohup. The parent returns the run_id immediately; use
# `pmctl dispatch wait <run_id> --cd <work_dir>` to resolve the durable terminal
# result. The supervisor re-runs the full
# security preflight (name/containment/route + brief-validate + guard) before any
# executor launch, so this path is never a policy bypass.
pmctl_dispatch_run_detached() {
  local repo_root="${1:-}" work_dir="${2:-}" adapter="${3:-}"
  local run_id="${4:-}" model="${5:-}" brief_file="${6:-}" created_ts="${7:-}" print_cmd="${8:-}"
  shift 8 || true
  local -a forward=("$@")

  # Separate the core --cd / --brief-file (recorded as trusted scalars) from the
  # native passthrough args. The caller passes the EFFECTIVE brief (the auto-pack
  # augmented copy when auto-pack ran, else the original) as brief_file AND has
  # already swapped the forwarded --brief-file to that same path, so the two must
  # match; assert that invariant defensively.
  local cd_arg="" fwd_brief="" i=0
  local -a native=()
  while [[ "$i" -lt "${#forward[@]}" ]]; do
    case "${forward[$i]}" in
      --cd)
        cd_arg="${forward[$((i + 1))]:-}"
        i=$((i + 2))
        ;;
      --brief-file)
        fwd_brief="${forward[$((i + 1))]:-}"
        i=$((i + 2))
        ;;
      *)
        native+=("${forward[$i]}")
        i=$((i + 1))
        ;;
    esac
  done
  if [[ -n "$fwd_brief" && "$fwd_brief" != "$brief_file" ]]; then
    printf 'pmctl dispatch run: internal error: detached forwarded brief (%s) diverges from guarded brief (%s)\n' "$fwd_brief" "$brief_file" >&2
    return 2
  fi

  local spec_dir spec_path supervisor_log pid_file
  spec_dir="$work_dir/.agent-trace"
  spec_path="$spec_dir/$run_id.runspec"
  supervisor_log="$spec_dir/$run_id.supervisor.log"
  pid_file="$spec_dir/$run_id.supervisor.pid"
  if ! mkdir -p "$spec_dir"; then
    printf 'pmctl dispatch run: mkdir failed: %s\n' "$spec_dir" >&2
    return 2
  fi

  # Generate a sentinel nonce unknown to the executor. The nonce is passed to the
  # supervisor via an environment variable (not written to the workspace run-spec)
  # and the supervisor unsets it before exec-ing the adapter subprocess. This makes
  # the sentinel path /tmp/pm-supervisor-sentinel-<run_id>-<nonce> unpredictable to
  # an executor that can only read workspace files. The key file is stored in a
  # per-user private directory (mode 700) so only the owning user can access it.
  local _sup_nonce _sup_key_file _sup_key_dir
  _sup_nonce="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 32 2>/dev/null)" \
    || _sup_nonce="${RANDOM}${RANDOM}${RANDOM}"
  [[ -n "$_sup_nonce" ]] || _sup_nonce="${RANDOM}${RANDOM}${RANDOM}"
  _sup_key_file="$(_pmctl_sentinel_key_file "$run_id")"
  _sup_key_dir="$(dirname "$_sup_key_file")"
  # Create the per-user key dir, then verify it is owner-only AND owned by us.
  # `mkdir -m 700 -p` is insufficient: -m only applies to the deepest *new* dir
  # (SC2174), and a pre-existing dir keeps its prior mode/owner — a pre-seeded
  # permissive or foreign-owned dir could expose nonce files. So: mkdir, chmod 700
  # (tightens an owner-owned-but-loose dir; fails if we do not own it), and refuse
  # any dir not owned by the current uid.
  mkdir -p "$_sup_key_dir" 2>/dev/null || {
    printf 'pmctl dispatch run: failed to create private key directory: %s\n' "$_sup_key_dir" >&2
    return 2
  }
  chmod 700 "$_sup_key_dir" 2>/dev/null || {
    printf 'pmctl dispatch run: failed to secure private key directory (not owner?): %s\n' "$_sup_key_dir" >&2
    return 2
  }
  local _key_dir_owner
  _key_dir_owner="$(stat -c '%u' "$_sup_key_dir" 2>/dev/null || stat -f '%u' "$_sup_key_dir" 2>/dev/null || true)"
  if [[ -n "$_key_dir_owner" && "$_key_dir_owner" != "$(id -u)" ]]; then
    printf 'pmctl dispatch run: refusing key directory not owned by current user (owner uid=%s): %s\n' "$_key_dir_owner" "$_sup_key_dir" >&2
    return 2
  fi
  printf '%s' "$_sup_nonce" > "$_sup_key_file" 2>/dev/null || {
    printf 'pmctl dispatch run: failed to write sentinel key file\n' >&2
    return 2
  }
  # Export nonce to supervisor via env; supervisor reads and immediately unsets.
  export PM_SUPERVISOR_NONCE="$_sup_nonce"

  # Snapshot the brief into /tmp/brief-<run_id>.md before launching so the
  # caller can safely clean up the original temp brief after run_id returns.
  # The snapshot path stays within the /tmp/brief-*.md guard pattern so the
  # supervisor's validate -> guard -> execute all see the same stable bytes
  # with no TOCTOU window (no second copy step needed in the supervisor).
  local brief_snapshot brief_snap_tmp
  brief_snapshot="/tmp/brief-$run_id.md"
  brief_snap_tmp="$(mktemp "/tmp/.brief-$run_id.XXXXXX")" || {
    printf 'pmctl dispatch run: failed to create brief snapshot tempfile\n' >&2
    return 2
  }
  cp "$brief_file" "$brief_snap_tmp" \
    || { rm -f "$brief_snap_tmp"; printf 'pmctl dispatch run: failed to snapshot brief: %s\n' "$brief_file" >&2; return 2; }
  mv -f "$brief_snap_tmp" "$brief_snapshot" \
    || { rm -f "$brief_snap_tmp"; printf 'pmctl dispatch run: failed to commit brief snapshot\n' >&2; return 2; }
  brief_file="$brief_snapshot"
  if ! pmctl_dispatch_write_runspec "$spec_path" "$run_id" "$adapter" "$work_dir" \
      "$cd_arg" "$brief_file" "$model" "$created_ts" "$print_cmd" ${native[@]+"${native[@]}"}; then
    printf 'pmctl dispatch run: failed to write run-spec: %s\n' "$spec_path" >&2
    return 2
  fi

  pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$run_id" \
    "pending" 0 "$model" "$brief_file" "" "$created_ts" "" || return $?
  pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$run_id" \
    "dispatched" 0 "$model" "$brief_file" "" "$created_ts" "pending" || return $?

  if ! _pmctl_dispatch_launch_supervisor "$repo_root" "$spec_path" "$supervisor_log" "$pid_file"; then
    printf 'pmctl dispatch run: failed to launch detached supervisor for %s\n' "$run_id" >&2
    # Write terminal failed record so dispatch wait resolves quickly, and write
    # the supervisor sentinel so dispatch wait can resolve (sentinel is required
    # because dispatch wait trusts sentinel not workspace record). Clean up the
    # brief snapshot (brief_file now points to the /tmp snapshot copy).
    local _launch_fail_ts
    _launch_fail_ts="$(pmctl_dispatch_utc_ts 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$run_id" \
      "failed" 2 "$model" "$brief_file" "" "$created_ts" "dispatched" 2>/dev/null || true
    pmctl_dispatch_write_record_soft "$run_id" "$adapter" "$model" "$brief_file" \
      "$work_dir" 2 "failed" "supervisor launch failed" "" "" "" "$created_ts" "$_launch_fail_ts"
    printf 'final_state=failed\nexit_code=2\n' \
      > "/tmp/pm-supervisor-sentinel-${run_id}-${_sup_nonce}" 2>/dev/null || true
    rm -f "$brief_file" 2>/dev/null || true
    # Keep the key file: dispatch wait must read the nonce to authenticate the
    # failure sentinel above (exit 2). Removing it here would force wait into the
    # key-absent indeterminate (exit 3) path and defeat the sentinel we just wrote.
    # The key is consumed by the first dispatch wait, or reaped by tmpwatch.
    unset PM_SUPERVISOR_NONCE
    return 2
  fi
  unset PM_SUPERVISOR_NONCE
  printf '%s\n' "$run_id"
  return 0
}

pmctl_dispatch_wait() {
  local _repo_root="${1:-}"
  shift || true
  local run_id="" work_dir="" timeout=3600

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch wait: missing value for --cd\n' >&2
          return 2
        fi
        work_dir="$(_portable_canonical_path "$2")"
        shift 2
        ;;
      --timeout)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch wait: missing value for --timeout\n' >&2
          return 2
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          printf 'pmctl dispatch wait: invalid --timeout %q (expected seconds)\n' "$2" >&2
          return 2
        fi
        timeout="$2"
        shift 2
        ;;
      --*)
        printf 'pmctl dispatch wait: unknown option %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [[ -n "$run_id" ]]; then
          printf 'pmctl dispatch wait: unexpected argument %s\n' "$1" >&2
          return 2
        fi
        run_id="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$run_id" ]]; then
    printf 'pmctl dispatch wait: <run_id> is required\n' >&2
    return 2
  fi
  if ! [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]]; then
    printf 'pmctl dispatch wait: invalid run_id %q\n' "$run_id" >&2
    return 2
  fi
  if [[ -z "$work_dir" ]]; then
    printf 'pmctl dispatch wait: --cd <work_dir> is required\n' >&2
    return 2
  fi

  # Resolve the sentinel path from the nonce key file written by the parent
  # before the supervisor was launched. The key file is in a per-user private
  # directory (mode 700) so other OS users cannot read the nonce. An executor
  # that forged a sentinel at the predictable (nonce-free) path would produce a
  # file at a different path that dispatch wait never polls.
  local _key_nonce _key_file
  _key_file="$(_pmctl_sentinel_key_file "$run_id")"
  if [[ ! -f "$_key_file" ]]; then
    # Sentinel key absent. This happens when:
    #   (a) A prior successful dispatch wait already consumed the key (one-shot).
    #   (b) The temp directory was cleaned up (reboot / tmpwatch).
    #   (c) An executor removed it (outside the trusted same-user model).
    # Without the key there is NO authenticated completion signal. The in-workspace
    # dispatch record is executor-writable, so it is NOT authoritative: print it for
    # observability but return an indeterminate (non-zero, 3) status. Callers MUST
    # treat exit 3 as "completion unverified", never as success.
    if dispatch_record_read_state "$work_dir" "$run_id" 2>/dev/null; then
      printf 'run: %s  state: %s  exit: %s  (advisory: durable record, NOT sentinel-authenticated)\n' \
        "$run_id" "$DISPATCH_RECORD_STATE" "${DISPATCH_RECORD_EXIT:-?}"
      if [[ -n "${DISPATCH_RECORD_SUMMARY:-}" ]]; then
        printf '%s\n' "$DISPATCH_RECORD_SUMMARY"
      fi
      printf 'pmctl dispatch wait: indeterminate: sentinel key absent; completion is unverified (durable record shown for observability only; exit=3)\n' >&2
      return 3
    fi
    printf 'pmctl dispatch wait: indeterminate: sentinel key absent and no durable record for %s in %s (exit=3)\n' "$run_id" "$work_dir" >&2
    return 3
  fi
  _key_nonce="$(cat "$_key_file" 2>/dev/null)" || _key_nonce=""
  if [[ -z "$_key_nonce" ]]; then
    printf 'pmctl dispatch wait: empty sentinel key for %s\n' "$run_id" >&2
    return 2
  fi

  local _sentinel="/tmp/pm-supervisor-sentinel-${run_id}-${_key_nonce}"
  local start elapsed
  start="$SECONDS"
  while true; do
    if [[ -f "$_sentinel" ]]; then
      local _sent_state _sent_exit
      _sent_state="$(grep -m1 '^final_state=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      _sent_exit="$(grep -m1 '^exit_code=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      rm -f "$_sentinel" "$_key_file" 2>/dev/null || true
      [[ "$_sent_exit" =~ ^-?[0-9]+$ ]] || _sent_exit="1"
      if dispatch_record_read_state "$work_dir" "$run_id"; then
        printf 'run: %s  state: %s  exit: %s\n' "$run_id" \
          "${_sent_state:-$DISPATCH_RECORD_STATE}" "${_sent_exit:-$DISPATCH_RECORD_EXIT}"
        if [[ -n "${DISPATCH_RECORD_SUMMARY:-}" ]]; then
          printf '%s\n' "$DISPATCH_RECORD_SUMMARY"
        fi
      else
        printf 'run: %s  state: %s  exit: %s\n' "$run_id" \
          "${_sent_state:-unknown}" "${_sent_exit:-1}"
        if [[ "${_sent_exit:-1}" -eq 0 ]]; then
          printf 'pmctl dispatch wait: WARN: sentinel ok but durable dispatch record not found for %s in %s\n' "$run_id" "$work_dir" >&2
        fi
      fi
      return "${_sent_exit:-1}"
    fi
    elapsed=$((SECONDS - start))
    if (( elapsed >= timeout )); then
      printf 'pmctl dispatch wait: timed out after %ss waiting for %s in %s\n' "$timeout" "$run_id" "$work_dir" >&2
      return 124
    fi
    sleep 2
  done
}

pmctl_dispatch_run() {
  local repo_root="${1:-}"
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl dispatch run: missing repo root\n' >&2
    return 2
  fi
  shift || true

  local adapter="" work_dir="" brief_file="" print_cmd=0 auto_pack_flag="" lifecycle_flag=""
  local -a forward=()

  # Peek at the flags the shared steps need (--adapter is consumed; --cd and
  # --brief-file are peeked AND forwarded). Everything else passes through to the
  # adapter opaquely so pmctl never needs to know executor-specific flags.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --adapter)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch run: missing value for --adapter\n' >&2
          return 2
        fi
        adapter="$2"
        shift 2
        ;;
      --cd)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch run: missing value for --cd\n' >&2
          return 2
        fi
        # Canonicalize for internal use (pack path, reuse-scan) so C:/… and /c/…
        # spellings compare equal; forward the original to the adapter unchanged.
        work_dir="$(_portable_canonical_path "$2")"
        forward+=(--cd "$2")
        shift 2
        ;;
      --brief-file)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch run: missing value for --brief-file\n' >&2
          return 2
        fi
        brief_file="$2"
        forward+=(--brief-file "$2")
        shift 2
        ;;
      --print-cmd)
        print_cmd=1
        forward+=(--print-cmd)
        shift
        ;;
      --auto-pack)
        auto_pack_flag="on"
        shift
        ;;
      --no-auto-pack)
        auto_pack_flag="off"
        shift
        ;;
      --lifecycle)
        # Consumed by pmctl (lifecycle is a dispatch-time choice, not an adapter
        # flag); never forwarded to the adapter.
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch run: missing value for --lifecycle\n' >&2
          return 2
        fi
        case "$2" in
          foreground|detached) lifecycle_flag="$2" ;;
          *)
            printf 'pmctl dispatch run: invalid --lifecycle %q (expected foreground or detached)\n' "$2" >&2
            return 2
            ;;
        esac
        shift 2
        ;;
      --)
        # Inline brief form skips brief-validate + guard, so it is a policy
        # bypass. Refuse it at the orchestrator (the policy surface); briefs must
        # be written to a file and passed via --brief-file.
        printf 'pmctl dispatch run: inline brief form (--) is not supported; write the brief to a file and pass --brief-file so policy checks (brief-validate + guard) can run\n' >&2
        return 2
        ;;
      *)
        # Non-core flags pass through to the adapter verbatim (the adapter owns
        # its native-flag surface). pmctl does not interpret adapter-specific
        # flags, so safety-sensitive native values are validated by the adapter —
        # the single effective-policy chokepoint every dispatch path crosses:
        # e.g. the codex adapter rejects --sandbox danger-full-access, so this
        # passthrough cannot reintroduce full machine access past the
        # isolation_level policy.
        forward+=("$1")
        shift
        ;;
    esac
  done

  # ── Required, validated inputs ───────────────────────────────────────────
  if [[ -z "$adapter" ]]; then
    printf 'pmctl dispatch run: --adapter <name> is required\n' >&2
    return 2
  fi
  # Strict identifier: a bare adapter name, never a path. Blocks `../` traversal
  # and any value that could resolve a dispatch.sh outside adapters/<name>/.
  if ! [[ "$adapter" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    printf 'pmctl dispatch run: invalid adapter name %q (must be a bare lowercase identifier: a letter, then letters/digits/hyphen/underscore — no path separators)\n' "$adapter" >&2
    return 2
  fi
  if [[ -z "$work_dir" ]]; then
    printf 'pmctl dispatch run: --cd <dir> is required\n' >&2
    return 2
  fi
  if [[ -z "$brief_file" ]]; then
    printf 'pmctl dispatch run: --brief-file <path> is required (every dispatch must carry a validatable brief)\n' >&2
    return 2
  fi

  # 1-2. Resolve adapter (convention + symlink/containment guard) and enforce the
  #      route ALLOWLIST via the shared security preflight. Fail closed: a missing
  #      routing registry refuses the dispatch, never silently skips the allowlist.
  #      The same helper backs the detached supervisor.
  local adapter_path
  adapter_path="$(pmctl_dispatch_resolve_adapter "$repo_root" "$adapter")" || return 2

  # 3. Optional auto-pack, then brief-validate the EFFECTIVE brief. Auto-pack runs
  # BEFORE validation on purpose: under BRIEF_VALIDATE_RETRIEVAL=fail an appended
  # auto_context: block must count as retrieval evidence for the gate, so the gate
  # has to see the post-pack brief. Config is loaded here because dispatch.auto_pack
  # decides whether the pack step runs; adapter-facing config exports are still
  # applied below before invocation.
  if type -t pm_config_load >/dev/null 2>&1; then pm_config_load; fi
  local _dispatch_model _dispatch_created_ts _dispatch_run_id _auto_pack_effective
  _dispatch_model="$(pmctl_dispatch_extract_model "${forward[@]}")"
  _dispatch_created_ts="$(pmctl_dispatch_utc_ts)"
  _dispatch_run_id="run-$(pmctl_dispatch_stamp)-$(pmctl_dispatch_hex6)"

  # 3b. Resolve the effective lifecycle (flag > dispatch.lifecycle config >
  # detached) and, for detached, reject ineligible adapters BEFORE any executor
  # launch (hard gate). Detached is incompatible with the --print-cmd dry-run.
  local _lifecycle_effective="detached"
  if [[ "$lifecycle_flag" == "foreground" || "$lifecycle_flag" == "detached" ]]; then
    _lifecycle_effective="$lifecycle_flag"
  elif [[ "${PM_CFG_LIFECYCLE:-}" == "foreground" || "${PM_CFG_LIFECYCLE:-}" == "detached" ]]; then
    _lifecycle_effective="$PM_CFG_LIFECYCLE"
  fi
  if [[ "$_lifecycle_effective" == "detached" ]]; then
    if [[ "$print_cmd" -eq 1 ]]; then
      printf 'pmctl dispatch run: --lifecycle detached is incompatible with --print-cmd (nothing to supervise)\n' >&2
      return 2
    fi
    local _detach_elig=0
    pmctl_dispatch_detach_eligible "$repo_root" "$adapter" || _detach_elig=$?
    if [[ "$_detach_elig" -ne 0 ]]; then
      return 2
    fi
  fi

  # Built-in default is ON (context-first by default): retrieval-first discipline
  # wants the structural auto_context mechanism active unless explicitly opted out
  # (flag --no-auto-pack > dispatch.auto_pack config > this built-in default).
  _auto_pack_effective="on"
  if [[ "$auto_pack_flag" == "on" || "$auto_pack_flag" == "off" ]]; then
    _auto_pack_effective="$auto_pack_flag"
  elif [[ "${PM_CFG_AUTO_PACK:-}" == "on" || "${PM_CFG_AUTO_PACK:-}" == "off" ]]; then
    _auto_pack_effective="$PM_CFG_AUTO_PACK"
  fi

  # Auto-pack (best-effort) runs for BOTH lifecycles. It appends a pointer-only
  # auto_context: block to a copy of the brief under .pm-dispatch/ctx/packs/ and,
  # on success, that pack becomes the EFFECTIVE brief. Foreground forwards the pack
  # to the adapter directly; detached snapshots the pack to /tmp/brief-<run_id>.md
  # (the only guardable location) so the supervisor validates == guards == executes
  # the same augmented bytes, preserving the single-brief invariant. The earlier
  # divergence — pack outside the /tmp guard pattern — is resolved by that snapshot,
  # so detached + auto-pack is no longer rejected.
  PMCTL_DISPATCH_AUTO_PACK_PATH=""
  if [[ "$_auto_pack_effective" == "on" ]]; then
    pmctl_dispatch_auto_pack "$repo_root" "$work_dir" "$brief_file" "$_dispatch_run_id" || true
    if [[ -n "${PMCTL_DISPATCH_AUTO_PACK_PATH:-}" ]]; then
      local _brief_i
      for ((_brief_i = 0; _brief_i < ${#forward[@]}; _brief_i += 1)); do
        if [[ "${forward[$_brief_i]}" == "--brief-file" && $((_brief_i + 1)) -lt ${#forward[@]} ]]; then
          forward[_brief_i + 1]="$PMCTL_DISPATCH_AUTO_PACK_PATH"
          break
        fi
      done
      unset _brief_i
    fi
  fi

  # 3c. Validate the EFFECTIVE brief (the augmented pack when auto-pack produced one,
  # else the original). Validating here — after auto-pack — lets the gate count an
  # appended auto_context: block as retrieval evidence under BRIEF_VALIDATE_RETRIEVAL=
  # fail. The check is content-only and path-agnostic; the guard below still runs on
  # the original /tmp brief (the only guardable path), and detached re-validates and
  # re-guards the /tmp snapshot of this same effective brief in the supervisor.
  local _effective_brief="${PMCTL_DISPATCH_AUTO_PACK_PATH:-$brief_file}"
  pmctl_dispatch_validate_brief "$repo_root" "$_effective_brief" || return 2

  # 4. Guard (shared policy) — MANDATORY. Fail closed if the guard is unavailable.
  #    Gates the executor's brief-file write for this runtime via the same code
  #    path the PreToolUse hooks enforce. The dispatch adapter IS the runtime
  #    axis; the role is always `executor` here.
  if ! declare -F pmctl_guard_check >/dev/null; then
    printf 'pmctl dispatch run: guard unavailable (pmctl-guard not sourced) — refusing to dispatch without policy enforcement\n' >&2
    return 2
  fi
  if ! pmctl_guard_check "$repo_root" --event pre-write --role executor --runtime "$adapter" --file "$brief_file"; then
    printf 'pmctl dispatch run: guard denied dispatch for adapter %q\n' "$adapter" >&2
    return 2
  fi

  # 4a. Export config defaults to the adapter subprocess.
  #     Adapters honour PM_CFG_TIMEOUT / PM_CFG_DEFAULT_MODEL at lower priority
  #     than their adapter-specific env vars (CODEX_DISPATCH_TIMEOUT, etc.) and
  #     lower than an explicit --timeout / --model flag — the existing elif chains
  #     in each adapter preserve that ordering without any adapter-side change.
  #     Export is unconditional; adapters that omit the config branch safely ignore
  #     unknown env vars. pm_config_load is guarded so test environments that did
  #     not source pmctl-config.sh degrade silently rather than hitting exit 127.
  # shellcheck disable=SC2163
  export PM_CFG_TIMEOUT PM_CFG_DEFAULT_MODEL PM_CFG_AUTO_PACK

  # 5. Execute. Foreground runs the tail in-process (blocking). Detached persists
  #    a run-spec, snapshots the brief durably, and hands the post-preflight tail
  #    to the supervisor via setsid/nohup; returns run_id immediately.  The
  #    preflight gates above still front every executor invocation in both paths.
  if [[ "$_lifecycle_effective" == "detached" ]]; then
    pmctl_dispatch_run_detached "$repo_root" "$work_dir" "$adapter" \
      "$_dispatch_run_id" "$_dispatch_model" "$_effective_brief" "$_dispatch_created_ts" "$print_cmd" \
      "${forward[@]}"
    return $?
  fi

  pmctl_dispatch_execute_tail "$repo_root" "$work_dir" "$adapter" "$adapter_path" \
    "$_dispatch_run_id" "$_dispatch_model" "$brief_file" "$_dispatch_created_ts" "$print_cmd" \
    "${forward[@]}"
  return $?
}
