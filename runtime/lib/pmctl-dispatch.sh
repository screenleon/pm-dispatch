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
#   3. brief-validate                runtime/bin/brief-validate.sh
#  3a. optional auto-pack             context reuse-scan + pointer-only brief copy
#   4. guard                         pmctl guard check (shared policy, MANDATORY)
#   5. invoke adapter subprocess     the ONLY executor-specific step
#   6. read output contract          .agent-trace/latest.last (read-only)
#   7. post-verify                   runtime/bin/dispatch-post-verify.sh
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
if ! declare -F pm_identifier_adapter_is_valid >/dev/null 2>&1; then
  _pmctl_dispatch_lib_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck disable=SC1091  # dynamic path; identifier policy is source-safe
  . "$_pmctl_dispatch_lib_dir/identifier-policy.sh" 2>/dev/null || true
  unset _pmctl_dispatch_lib_dir
fi

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
  . "$repo_root/runtime/lib/state-writer.sh"
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
    cancelled)
      event_kind="run.cancelled"
      note="cancelled"
      ;;
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
  local goal reuse_yaml reuse_err block_file block_hits pack_dir pack_path validate_msg validate_status=0 ctx_root

  if ! declare -F pmctl_context_reuse_scan >/dev/null 2>&1; then
    # shellcheck disable=SC1091  # dynamic repo root path.
    . "$repo_root/runtime/lib/pmctl-context.sh" 2>/dev/null || true
  fi
  if ! declare -F pmctl_context_reuse_scan >/dev/null 2>&1; then
    printf 'pmctl dispatch run: warning: auto-pack skipped: pmctl context reuse-scan unavailable\n' >&2
    pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
    return 0
  fi

  # Context artifacts (the reuse-scan DB and the pack) are repo-root-local by contract
  # (docs/context-retrieval.md), and the state-writer already keys a subdirectory --cd
  # to its git top-level. So resolve work_dir to the git top-level for ALL context I/O
  # below — otherwise a subdirectory --cd would scatter context.db / .gitignore / packs
  # under the subdir instead of the repo root. Fall back to work_dir verbatim when it is
  # not a git work tree (best-effort, same as reuse-scan's own behavior). The adapter
  # still receives the caller's original --cd; only context placement is normalized.
  ctx_root="$(git -C "$work_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -z "$ctx_root" ]]; then
    # git rev-parse failed (work_dir is not a git work tree). Only fall back
    # to work_dir verbatim when it is a real, absolute, existing directory --
    # never let a relative/garbage work_dir reach the mkdir -p below, which
    # would silently create directories under the current CWD instead.
    if [[ "$work_dir" != /* || ! -d "$work_dir" ]]; then
      printf 'pmctl dispatch run: warning: auto-pack skipped: work_dir %q is not an absolute existing directory and is not a git work tree\n' "$work_dir" >&2
      pmctl_dispatch_emit_auto_packed_event "$repo_root" "$run_id" 0 "" "$brief_file"
      return 0
    fi
    ctx_root="$work_dir"
  fi
  if declare -F _portable_canonical_path >/dev/null 2>&1; then
    ctx_root="$(_portable_canonical_path "$ctx_root" 2>/dev/null || printf '%s' "$ctx_root")"
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
  if ! reuse_yaml="$(pmctl_context_reuse_scan "$ctx_root" "$goal" 2>"$reuse_err")"; then
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

  pack_dir="$ctx_root/.pm-dispatch/ctx/packs"
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

  validate_msg="$(bash "$repo_root/runtime/bin/brief-validate.sh" "$pack_path" 2>&1)" || validate_status=$?
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

# _pmctl_dispatch_trace_dir <work_dir> <run_id> [explicit_trace_dir]
# Single source of truth for where a dispatch's harness/adapter artifacts
# (footer, executor trace, runspec, supervisor.log/pid) land. Pure computation —
# deterministic in (work_dir, run_id) so the parent (which writes the runspec)
# and the detached supervisor (which re-runs execute_tail) independently derive
# the SAME directory without threading a value through the run-spec.
# Precedence:
#   explicit --trace-dir flag on THIS dispatch (per-dispatch caller opt-in)
#   > out-of-repo $(sw_project_run_dir)/.agent-trace
#   > legacy in-repo $work_dir/.agent-trace (fail-soft when the helper is absent).
# It deliberately does NOT read the ambient PM_DISPATCH_TRACE_DIR env: that var is
# adapter-facing (where the adapter writes its trace) and is inherited across
# nested dispatches, so consuming it here would route a CHILD pmctl run's footer/
# runspec into an unrelated PARENT's (possibly read-only) trace dir — e.g. a test
# suite's dispatch inheriting a pr-gate sandbox's gate trace dir. pmctl's own
# artifact location derives from (work_dir, run_id) or an explicit per-dispatch
# flag only. The partition key is bound to work_dir (NOT the caller's cwd) by
# computing the run dir from inside work_dir — same fix CC-416's pmctl-gate
# applies — so a dispatch invoked from a different directory still lands under the
# target repo's partition.
# Lazy-source state-paths helpers (sw_project_run_dir / _sw_project_dir).
# ${repo_root:-} so callers without repo_root degrade instead of tripping set -u.
_pmctl_dispatch_ensure_state_paths() {
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function \
     && "$(type -t _sw_project_dir 2>/dev/null)" == function ]]; then
    return 0
  fi
  local _sp_lib="${repo_root:-}/runtime/lib/state-paths.sh"
  [[ -r "$_sp_lib" ]] || return 1
  # shellcheck disable=SC1090,SC1091  # dynamic repo-root path
  . "$_sp_lib" 2>/dev/null || return 1
  [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]] || return 1
  return 0
}

# Lazy-source detached-launch helpers used by wait/cancel/status.
_pmctl_dispatch_ensure_detached_launch() {
  local rr="${1:-${repo_root:-}}"
  if [[ "$(type -t detached_launch_under_setsid 2>/dev/null)" == function \
     && "$(type -t detached_launch_verify_identity 2>/dev/null)" == function \
     && "$(type -t detached_launch_wait_for_sentinel 2>/dev/null)" == function ]]; then
    return 0
  fi
  local _dl_lib="${rr}/runtime/lib/detached-launch.sh"
  [[ -r "$_dl_lib" ]] || return 1
  # shellcheck disable=SC1090,SC1091
  . "$_dl_lib" 2>/dev/null || return 1
  [[ "$(type -t detached_launch_under_setsid 2>/dev/null)" == function ]] || return 1
  return 0
}

# Resolve the state-store project run directory for work_dir/run_id.
# Prints path on success; returns 1 when state partition cannot be resolved.
_pmctl_dispatch_project_run_dir() {
  local work_dir="${1:-}" run_id="${2:-}" _rd=""
  _pmctl_dispatch_ensure_state_paths || return 1
  _rd="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "$run_id" 2>/dev/null)" || _rd=""
  [[ -n "$_rd" ]] || return 1
  printf '%s\n' "$_rd"
  return 0
}

_pmctl_dispatch_trace_dir() {
  local work_dir="${1:-}" run_id="${2:-}" explicit="${3:-}" _rd=""
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  if _rd="$(_pmctl_dispatch_project_run_dir "$work_dir" "$run_id")"; then
    printf '%s\n' "$_rd/.agent-trace"
    return 0
  fi
  # Legacy in-workspace fallback for observability only (never cancel authority).
  printf '%s\n' "$work_dir/.agent-trace"
}

# Out-of-repo trusted artifact directory for cancel authority (identity,
# terminal claim, runspec, supervisor pid). ALWAYS derived from the state
# store project run dir — never honors an explicit --trace-dir override
# (that path is adapter observability only and may be workspace-writable).
# Returns non-zero (prints nothing) when the state partition cannot be
# resolved — callers must fail closed rather than fall back to workspace.
_pmctl_dispatch_trusted_artifact_dir() {
  local work_dir="${1:-}" run_id="${2:-}" _rd=""
  _rd="$(_pmctl_dispatch_project_run_dir "$work_dir" "$run_id")" || return 1
  printf '%s\n' "$_rd/.agent-trace"
  return 0
}

# Exclusive terminal claim (CAS). First writer wins; content is key=value.
#   0 — this caller owns the terminal claim for $state
#   1 — a terminal claim already exists (read via _pmctl_dispatch_read_terminal_claim)
_pmctl_dispatch_try_terminal_claim() {
  local work_dir="${1:-}" run_id="${2:-}" state="${3:-}" claimer="${4:-unknown}"
  local art_dir claim_path
  case "$state" in ok|failed|partial|cancelled) : ;; *) return 1 ;; esac
  art_dir="$(_pmctl_dispatch_trusted_artifact_dir "$work_dir" "$run_id")" || return 1
  [[ -n "$art_dir" ]] || return 1
  mkdir -p "$art_dir" 2>/dev/null || return 1
  claim_path="$art_dir/$run_id.terminal"
  # noclobber: exclusive create so cancel and natural complete cannot both win.
  if (
    set -C
    umask 077
    printf 'final_state=%s\nclaimer=%s\nts=%s\n' \
      "$state" "$claimer" "$(pmctl_dispatch_utc_ts)" >"$claim_path"
  ) 2>/dev/null; then
    return 0
  fi
  return 1
}

# Single-pass read of the four runspec fields cancel/reconcile both need.
# Sets PMCTL_RS_ADAPTER PMCTL_RS_MODEL PMCTL_RS_BRIEF_FILE PMCTL_RS_CREATED_TS
# (empty when the runspec is absent/unreadable or a field is missing).
_pmctl_dispatch_read_runspec_fields() {
  local runspec="${1:-}"
  PMCTL_RS_ADAPTER=""
  PMCTL_RS_MODEL=""
  PMCTL_RS_BRIEF_FILE=""
  PMCTL_RS_CREATED_TS=""
  [[ -f "$runspec" ]] || return 1
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      adapter) PMCTL_RS_ADAPTER="$val" ;;
      model) PMCTL_RS_MODEL="$val" ;;
      brief_file) PMCTL_RS_BRIEF_FILE="$val" ;;
      created_ts) PMCTL_RS_CREATED_TS="$val" ;;
    esac
  done <"$runspec"
  return 0
}

_pmctl_dispatch_read_terminal_claim() {
  local work_dir="${1:-}" run_id="${2:-}"
  local art_dir claim_path
  # Output globals for callers (cancel/wait/supervisor). CLAIMER is set for
  # diagnostics/tests even when current call sites only branch on STATE.
  PMCTL_TERMINAL_STATE=""
  PMCTL_TERMINAL_CLAIMER=""
  art_dir="$(_pmctl_dispatch_trusted_artifact_dir "$work_dir" "$run_id")" || return 1
  claim_path="${art_dir:-}/$run_id.terminal"
  [[ -f "$claim_path" ]] || return 1
  # shellcheck disable=SC2034  # public output global; read by cancel/wait/tests
  PMCTL_TERMINAL_STATE="$(grep -m1 '^final_state=' "$claim_path" 2>/dev/null | cut -d= -f2-)" || true
  # shellcheck disable=SC2034  # public output global; claimer identity for diagnostics
  PMCTL_TERMINAL_CLAIMER="$(grep -m1 '^claimer=' "$claim_path" 2>/dev/null | cut -d= -f2-)" || true
  [[ -n "$PMCTL_TERMINAL_STATE" ]] || return 1
  return 0
}

# Infer the latest non-terminal run state for cancel transitions. Best-effort
# scan of runs.jsonl; falls back to dispatched (the common in-flight state).
_pmctl_dispatch_infer_from_state() {
  local work_dir="${1:-}" run_id="${2:-}"
  local proj_dir runs_file last=""
  if _pmctl_dispatch_ensure_state_paths; then
    proj_dir="$(cd "$work_dir" 2>/dev/null && _SW_REPO_ROOT="$work_dir" _sw_project_dir 2>/dev/null)" || proj_dir=""
    runs_file="${proj_dir}runs.jsonl"
    if [[ -f "$runs_file" ]]; then
      last="$(jq -r --arg id "$run_id" \
        'select(.id == $id) | .state' "$runs_file" 2>/dev/null | tail -n 1)" || last=""
    fi
  fi
  case "$last" in
    pending|dispatched|verifying) printf '%s\n' "$last" ;;
    *) printf 'dispatched\n' ;;
  esac
}

# Shared already-terminal report for cancel (and CAS losers).
#   0 — already cancelled (idempotent success)
#   1 — other terminal present (do not overwrite)
#   2 — no terminal claim yet
_pmctl_dispatch_cancel_report_if_terminal() {
  local work_dir="${1:-}" run_id="${2:-}"
  if ! _pmctl_dispatch_read_terminal_claim "$work_dir" "$run_id"; then
    return 2
  fi
  if [[ "${PMCTL_TERMINAL_STATE:-}" == "cancelled" ]]; then
    printf 'pmctl dispatch cancel: run %s already cancelled\n' "$run_id"
    return 0
  fi
  printf 'pmctl dispatch cancel: run %s already terminal (%s); not overwritten\n' \
    "$run_id" "${PMCTL_TERMINAL_STATE:-unknown}" >&2
  return 1
}

# Cancel may only signal when the supervisor was launched under setsid.
_pmctl_dispatch_cancel_require_isolated() {
  local run_id="${1:-}" isolated="${2:-0}"
  if [[ "$isolated" == "1" ]]; then
    return 0
  fi
  printf 'pmctl dispatch cancel: run %s is not in an isolated process group (no setsid); refusing cancel (fail-closed)\n' \
    "$run_id" >&2
  return 2
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
  # Route harness/adapter artifacts to the out-of-repo run dir (CC-417). The footer
  # lands here; the adapter's own trace follows via the forwarded --trace-dir below
  # (a flag, NOT an exported env — so no ambient state leaks to nested/later runs),
  # and post-verify's containment boundary follows via --run-dir/--trace-dir.
  # An explicit caller --trace-dir on this dispatch is the per-dispatch override and
  # drives the footer too, so footer and adapter trace stay colocated. _run_dir is
  # the trace dir's parent (the post-verify containment boundary).
  local _trace_dir _run_dir _explicit_td="" _tf_i
  for ((_tf_i = 0; _tf_i < ${#_forward[@]}; _tf_i += 1)); do
    if [[ "${_forward[$_tf_i]}" == "--trace-dir" ]]; then
      _explicit_td="${_forward[$((_tf_i + 1))]:-}"
      break
    fi
  done
  _trace_dir="$(_pmctl_dispatch_trace_dir "$work_dir" "$_dispatch_run_id" "$_explicit_td")"
  _run_dir="$(dirname "$_trace_dir")"
  _footer_dir="$_trace_dir"
  _footer_path="$_footer_dir/$_dispatch_run_id.footer"
  mkdir -p "$_footer_dir" || { printf 'pmctl dispatch run: mkdir failed: %s\n' "$_footer_dir" >&2; return 2; }
  # Forward the resolved trace dir to the adapter (flag wins over any inherited
  # PM_DISPATCH_TRACE_DIR env in sw_resolve_trace_dir) so its trace/last/stderr
  # land alongside the footer. Append only when the caller did not already pass
  # one — in which case _explicit_td already drove _trace_dir, so the adapter has
  # the matching flag.
  [[ -z "$_explicit_td" ]] && _forward+=(--trace-dir "$_trace_dir")
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
    if ! _pmctl_dispatch_try_terminal_claim "$work_dir" "$_dispatch_run_id" "failed" "supervisor"; then
      _pmctl_dispatch_read_terminal_claim "$work_dir" "$_dispatch_run_id" || true
      printf 'pmctl dispatch run: terminal already claimed as %s; skipping failed write\n' \
        "${PMCTL_TERMINAL_STATE:-unknown}" >&2
      return 130
    fi
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
      . "$repo_root/runtime/lib/runner-kind.sh" 2>/dev/null || true
    fi
    if declare -F runner_kind_manifest_field >/dev/null 2>&1; then
      _terminal_event="$(runner_kind_manifest_field "$_adapter_manifest" terminal_event 2>/dev/null || true)"
    fi
  fi

  local -a _pv_args=("$work_dir" "$brief_file")
  # Containment boundary + trace base follow the relocated artifacts (CC-417/CC-415
  # seam) so the post-verify .agent-trace guard checks the out-of-repo run dir.
  _pv_args+=(--run-dir "$_run_dir" --trace-dir "$_trace_dir")
  [[ -n "$_run_last" ]] && _pv_args+=(--last "$_run_last")
  [[ -n "$_run_trace" ]] && _pv_args+=(--jsonl "$_run_trace")
  [[ -n "$_run_stderr" ]] && _pv_args+=(--stderr "$_run_stderr")
  [[ -n "$_terminal_event" ]] && _pv_args+=(--terminal-event "$_terminal_event")
  local _pv_out="" _pv_rc=0
  if _pv_out="$(bash "$repo_root/runtime/bin/dispatch-post-verify.sh" "${_pv_args[@]}")"; then
    _pv_rc=0
  else
    _pv_rc=$?
  fi
  printf '%s\n' "$_pv_out"
  if [[ -n "$_trace_dir" ]]; then
    printf 'trace-dir: %s\nrun-dir: %s\n' "$_trace_dir" "$_run_dir"
  fi
  if [[ "$_pv_rc" -ne 0 ]]; then
    printf 'pmctl dispatch run: post-verify failed\n' >&2
    if ! _pmctl_dispatch_try_terminal_claim "$work_dir" "$_dispatch_run_id" "failed" "supervisor"; then
      _pmctl_dispatch_read_terminal_claim "$work_dir" "$_dispatch_run_id" || true
      printf 'pmctl dispatch run: terminal already claimed as %s; skipping failed write\n' \
        "${PMCTL_TERMINAL_STATE:-unknown}" >&2
      return 130
    fi
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "failed" 1 "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "verifying" || return $?
    pmctl_dispatch_write_record_soft "$_dispatch_run_id" "$adapter" "$_dispatch_model" "$brief_file" \
      "$work_dir" 1 "failed" "$_pv_out" "${_run_last:-}" "${_run_trace:-}" "${_run_stderr:-}" \
      "$_dispatch_created_ts" "$(pmctl_dispatch_utc_ts)"
    return 1
  fi

  if ! _pmctl_dispatch_try_terminal_claim "$work_dir" "$_dispatch_run_id" "ok" "supervisor"; then
    _pmctl_dispatch_read_terminal_claim "$work_dir" "$_dispatch_run_id" || true
    printf 'pmctl dispatch run: terminal already claimed as %s; skipping ok write\n' \
      "${PMCTL_TERMINAL_STATE:-unknown}" >&2
    return 130
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
# detached supervisor (runtime/bin/dispatch-supervisor.sh), so a supervisor handed a
# tampered run-spec can never reach an executor that `pmctl dispatch run` would
# have refused. The identifier regex is duplicated in pmctl_dispatch_run's early
# input-validation block by design: each entry point is an independent gate.
pmctl_dispatch_resolve_adapter() {
  local repo_root="${1:-}" adapter="${2:-}"

  if ! pm_identifier_adapter_is_valid "$adapter"; then
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

# Shared brief-validate step: runs runtime/bin/brief-validate.sh on the brief the
# adapter will consume, echoing any non-fatal validator notes to stderr. Used by
# BOTH pmctl_dispatch_run and the detached supervisor so every executor launch —
# foreground or detached — is fronted by the same brief schema check (a detached
# supervisor must not be able to launch an executor on a brief that
# `pmctl dispatch run` would reject). Returns 2 on validation failure.
pmctl_dispatch_validate_brief() {
  local repo_root="${1:-}" brief_file="${2:-}"
  local brief_result=0 brief_msg
  brief_msg="$(bash "$repo_root/runtime/bin/brief-validate.sh" "$brief_file" 2>&1)" || brief_result=$?
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
    . "$repo_root/runtime/lib/runner-kind.sh" 2>/dev/null || true
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
  local _run_id="${1:-}"
  detached_launch_key_file "pm-dispatch" "$_run_id"
}

_pmctl_dispatch_launch_supervisor() {
  local repo_root="${1:-}" spec_path="${2:-}" supervisor_log="${3:-}" pid_file="${4:-}"
  local supervisor="$repo_root/runtime/bin/dispatch-supervisor.sh"
  detached_launch_under_setsid "$supervisor" "$supervisor_log" "$pid_file" -- --run-spec "$spec_path"
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

  _pmctl_dispatch_ensure_detached_launch "$repo_root" || true

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
  # Authoritative runspec / supervisor log / pid / identity live ONLY under the
  # state-derived trusted artifact dir (CC-495). An explicit --trace-dir in
  # native args is adapter observability only and must never host cancel
  # authority (identity, terminal claim). The supervisor is launched with an
  # absolute --run-spec path so it reads the trusted location regardless of
  # where adapter traces land. Fail closed if the state partition is unavailable.
  if ! spec_dir="$(_pmctl_dispatch_trusted_artifact_dir "$work_dir" "$run_id")"; then
    printf 'pmctl dispatch run: cannot resolve state-derived run directory for %s (fail-closed)\n' "$run_id" >&2
    return 2
  fi
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
  _sup_nonce="$(detached_launch_generate_nonce)"
  _sup_key_file="$(_pmctl_sentinel_key_file "$run_id")"
  _sup_key_dir="$(dirname "$_sup_key_file")"
  # Create the per-user key dir, then verify it is owner-only AND owned by us.
  # `mkdir -m 700 -p` is insufficient: -m only applies to the deepest *new* dir
  # (SC2174), and a pre-existing dir keeps its prior mode/owner — a pre-seeded
  # permissive or foreign-owned dir could expose nonce files. So: mkdir, chmod 700
  # (tightens an owner-owned-but-loose dir; fails if we do not own it), and refuse
  # any dir not owned by the current uid.
  detached_launch_secure_key_dir "$_sup_key_dir"
  case "$?" in
    0) : ;;
    1) printf 'pmctl dispatch run: failed to create private key directory: %s\n' "$_sup_key_dir" >&2; return 2 ;;
    2) printf 'pmctl dispatch run: failed to secure private key directory (not owner?): %s\n' "$_sup_key_dir" >&2; return 2 ;;
    3) printf 'pmctl dispatch run: refusing key directory not owned by current user: %s\n' "$_sup_key_dir" >&2; return 2 ;;
  esac
  detached_launch_write_key_file "$_sup_key_file" "$_sup_nonce" || {
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
    _pmctl_dispatch_try_terminal_claim "$work_dir" "$run_id" "failed" "parent" 2>/dev/null || true
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$run_id" \
      "failed" 2 "$model" "$brief_file" "" "$created_ts" "dispatched" 2>/dev/null || true
    pmctl_dispatch_write_record_soft "$run_id" "$adapter" "$model" "$brief_file" \
      "$work_dir" 2 "failed" "supervisor launch failed" "" "" "" "$created_ts" "$_launch_fail_ts"
    detached_launch_write_sentinel \
      "$(detached_launch_sentinel_path "pm-supervisor" "$run_id" "$_sup_nonce")" \
      "final_state=failed" "exit_code=2"
    rm -f "$brief_file" 2>/dev/null || true
    # Keep the key file: dispatch wait must read the nonce to authenticate the
    # failure sentinel above (exit 2). Removing it here would force wait into the
    # key-absent indeterminate (exit 3) path and defeat the sentinel we just wrote.
    # The key is consumed by the first dispatch wait, or reaped by tmpwatch.
    unset PM_SUPERVISOR_NONCE
    return 2
  fi
  # Record PID/PGID/starttime/comm/isolated in the trusted run dir (not
  # workspace) so cancel can re-verify identity before signaling. isolated=
  # comes from whether setsid was used at launch (DETACHED_LAUNCH_ISOLATED).
  local _sup_pid _id_file _isolated="${DETACHED_LAUNCH_ISOLATED:-0}"
  _id_file="$spec_dir/$run_id.supervisor.identity"
  if [[ -f "$pid_file" ]]; then
    _sup_pid="$(tr -d ' \n' <"$pid_file" 2>/dev/null || true)"
    if [[ "$_sup_pid" =~ ^[0-9]+$ ]]; then
      sleep 0.05
      if ! detached_launch_capture_identity "$_sup_pid" "$_isolated" >"$_id_file" 2>/dev/null; then
        sleep 0.15
        if ! detached_launch_capture_identity "$_sup_pid" "$_isolated" >"$_id_file" 2>/dev/null; then
          printf 'pmctl dispatch run: WARN: failed to capture supervisor identity for %s (cancel will refuse process kill)\n' "$run_id" >&2
          rm -f "$_id_file" 2>/dev/null || true
        fi
      fi
      # Prove isolation: if recorded pgid is the caller's group, rewrite isolated=0
      # so cancel never treats a non-isolated launch as safe to signal.
      if [[ -f "$_id_file" ]]; then
        local _cap_pgid _self_pgid
        _cap_pgid="$(grep -m1 '^pgid=' "$_id_file" 2>/dev/null | cut -d= -f2-)" || _cap_pgid=""
        _self_pgid="$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')" || _self_pgid=""
        if [[ -n "$_cap_pgid" && -n "$_self_pgid" && "$_cap_pgid" == "$_self_pgid" ]]; then
          printf 'pmctl dispatch run: WARN: supervisor not isolated from caller pgid=%s; cancel will refuse kill\n' "$_self_pgid" >&2
          if ! detached_launch_capture_identity "$_sup_pid" "0" >"$_id_file" 2>/dev/null; then
            rm -f "$_id_file" 2>/dev/null || true
          fi
        fi
      fi
    fi
  fi
  unset PM_SUPERVISOR_NONCE
  printf '%s\n' "$run_id"
  return 0
}

pmctl_dispatch_wait() {
  local _repo_root="${1:-}"
  shift || true
  local run_id="" work_dir="" timeout=3600

  _pmctl_dispatch_ensure_detached_launch "$_repo_root" || true

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
  if ! pm_identifier_run_is_valid "$run_id"; then
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

  local _sentinel
  _sentinel="$(detached_launch_sentinel_path "pm-supervisor" "$run_id" "$_key_nonce")"
  if detached_launch_wait_for_sentinel "$_sentinel" "$timeout" "${PM_DISPATCH_WAIT_POLL_INTERVAL:-2}"; then
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
    # Distinct exit contract for authenticated outcomes:
    #   0     — ok
    #   130   — cancelled (user cancel; do not treat as generic failure)
    #   other — failed / adapter exit (including 1, 2, …)
    #   3 / 124 handled above (indeterminate / timeout)
    if [[ "${_sent_state:-}" == "cancelled" ]]; then
      return 130
    fi
    return "${_sent_exit:-1}"
  fi
  printf 'pmctl dispatch wait: timed out after %ss waiting for %s in %s\n' "$timeout" "$run_id" "$work_dir" >&2
  return 124
}

# Cancel an in-flight detached run. Authority is the out-of-repo trusted run
# directory (identity + terminal claim), never workspace-writable PID/records.
# Exit contract:
#   0  — cancel terminalized (cancelled sentinel durable)
#   1  — already terminal with a non-cancelled state (not overwritten)
#   2  — usage / identity mismatch fail-closed / evidence write failure
pmctl_dispatch_cancel() {
  local repo_root="${1:-}"
  shift || true
  local run_id="" work_dir="" grace=5

  _pmctl_dispatch_ensure_detached_launch "$repo_root" || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch cancel: missing value for --cd\n' >&2
          return 2
        fi
        work_dir="$(_portable_canonical_path "$2")"
        shift 2
        ;;
      --grace)
        if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
          printf 'pmctl dispatch cancel: --grace requires a non-negative integer (seconds)\n' >&2
          return 2
        fi
        grace="$2"
        shift 2
        ;;
      --*)
        printf 'pmctl dispatch cancel: unknown option %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [[ -n "$run_id" ]]; then
          printf 'pmctl dispatch cancel: unexpected argument %s\n' "$1" >&2
          return 2
        fi
        run_id="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$run_id" ]]; then
    printf 'pmctl dispatch cancel: <run_id> is required\n' >&2
    return 2
  fi
  if ! pm_identifier_run_is_valid "$run_id"; then
    printf 'pmctl dispatch cancel: invalid run_id %q\n' "$run_id" >&2
    return 2
  fi
  if [[ -z "$work_dir" ]]; then
    printf 'pmctl dispatch cancel: --cd <work_dir> is required\n' >&2
    return 2
  fi

  local art_dir identity_file pid_file runspec
  if ! art_dir="$(_pmctl_dispatch_trusted_artifact_dir "$work_dir" "$run_id")"; then
    printf 'pmctl dispatch cancel: cannot resolve state-derived run directory for %s (fail-closed)\n' "$run_id" >&2
    return 2
  fi
  identity_file="$art_dir/$run_id.supervisor.identity"
  pid_file="$art_dir/$run_id.supervisor.pid"
  runspec="$art_dir/$run_id.runspec"

  # Already terminal? Never overwrite.
  local _term_rc=0
  _pmctl_dispatch_cancel_report_if_terminal "$work_dir" "$run_id" || _term_rc=$?
  case "$_term_rc" in
    0) return 0 ;;
    1) return 1 ;;
  esac

  # Require dispatch evidence before terminalizing. A valid-but-unknown run_id
  # with no trusted identity/pid/runspec must not invent a cancelled terminal.
  if [[ ! -f "$identity_file" && ! -f "$pid_file" && ! -f "$runspec" && ! -f "$art_dir/$run_id.terminal" ]]; then
    printf 'pmctl dispatch cancel: no trusted dispatch evidence for %s under %s (unknown run; fail-closed)\n' \
      "$run_id" "$art_dir" >&2
    return 2
  fi

  # Identity + signal decision from trusted run dir only. Kill (when needed)
  # happens BEFORE terminal claim so we never publish cancelled while the
  # process group is still alive. Natural complete may win the CAS race after
  # kill; that is acceptable (process is already dead).
  local verify_rc=1 pid="" pgid="" isolated=""
  if [[ -f "$identity_file" ]]; then
    if ! detached_launch_load_identity_file "$identity_file"; then
      printf 'pmctl dispatch cancel: unreadable identity file for %s (fail-closed)\n' "$run_id" >&2
      return 2
    fi
    pid="$DL_ID_PID"
    pgid="$DL_ID_PGID"
    isolated="${DL_ID_ISOLATED:-0}"
    verify_rc=0
    detached_launch_verify_identity "$pid" "$identity_file" || verify_rc=$?
    case "$verify_rc" in
      0)
        # Live leader matches identity — only safe path that may signal.
        _pmctl_dispatch_cancel_require_isolated "$run_id" "$isolated" || return 2
        if [[ -n "$pgid" ]] && kill -0 -- "-$pgid" 2>/dev/null; then
          if ! detached_launch_kill_process_group "$pgid" "$grace"; then
            printf 'pmctl dispatch cancel: process group %s for %s still alive after SIGKILL; not marking cancelled\n' \
              "$pgid" "$run_id" >&2
            return 2
          fi
        fi
        ;;
      1)
        # Leader PID is gone. Do NOT signal a still-live PGID: without the
        # original leader we cannot re-prove identity, so a reused PGID could
        # belong to an unrelated same-user workload. Fail closed unless the
        # recorded group is already empty (nothing left to signal).
        _pmctl_dispatch_cancel_require_isolated "$run_id" "$isolated" || return 2
        if [[ -n "$pgid" ]] && kill -0 -- "-$pgid" 2>/dev/null; then
          printf 'pmctl dispatch cancel: supervisor pid gone but process group %s still live for %s; refusing kill without identity re-proof (fail-closed)\n' \
            "$pgid" "$run_id" >&2
          return 2
        fi
        ;;
      2)
        printf 'pmctl dispatch cancel: process identity mismatch for %s (pid=%s); refusing to signal (fail-closed)\n' \
          "$run_id" "$pid" >&2
        return 2
        ;;
    esac
  elif [[ -f "$pid_file" ]]; then
    # Identity missing: refuse kill (cannot prove process identity). Still allow
    # terminalization if the process is already gone and dispatch evidence exists.
    pid="$(tr -d ' \n' <"$pid_file" 2>/dev/null || true)"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      printf 'pmctl dispatch cancel: no verified identity for live pid %s of %s; refusing to signal (fail-closed)\n' \
        "$pid" "$run_id" >&2
      return 2
    fi
  fi

  # Re-check claim after kill (natural complete may have won while we signalled).
  _term_rc=0
  _pmctl_dispatch_cancel_report_if_terminal "$work_dir" "$run_id" || _term_rc=$?
  case "$_term_rc" in
    0) return 0 ;;
    1) return 1 ;;
  esac

  # CAS — if natural complete wins the race after kill, do not overwrite.
  if ! _pmctl_dispatch_try_terminal_claim "$work_dir" "$run_id" "cancelled" "cancel"; then
    _term_rc=0
    _pmctl_dispatch_cancel_report_if_terminal "$work_dir" "$run_id" || _term_rc=$?
    case "$_term_rc" in
      0) return 0 ;;
      *) return 1 ;;
    esac
  fi

  # Load metadata from trusted runspec when available (not workspace).
  local adapter="" model="" brief_file="" created_ts="" from_state
  _pmctl_dispatch_read_runspec_fields "$runspec" || true
  adapter="$PMCTL_RS_ADAPTER"; model="$PMCTL_RS_MODEL"
  brief_file="$PMCTL_RS_BRIEF_FILE"; created_ts="$PMCTL_RS_CREATED_TS"
  from_state="$(_pmctl_dispatch_infer_from_state "$work_dir" "$run_id")"
  [[ -n "$created_ts" ]] || created_ts="$(pmctl_dispatch_utc_ts)"
  local finished_ts
  finished_ts="$(pmctl_dispatch_utc_ts)"

  # After kill + exclusive claim, NEVER release the claim: the supervisor may
  # already have observed it and skipped its own terminal write. Publish the
  # authenticated cancelled sentinel so wait can resolve even if some durable
  # Run/Event/record writes fail; return non-zero when evidence is incomplete.
  local evidence_rc=0
  if [[ -n "$adapter" ]]; then
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$run_id" \
      "cancelled" 130 "$model" "${brief_file:-}" "" "$created_ts" "$from_state" || evidence_rc=$?
  else
    pmctl_dispatch_ensure_state_writer "$repo_root" 2>/dev/null || true
    if declare -F pmctl_dispatch_write_event >/dev/null 2>&1; then
      pmctl_dispatch_write_event "$repo_root" "$work_dir" "run.cancelled" "$run_id" \
        "cancelled" 130 "unknown" "cancelled without adapter metadata" "" "$from_state" || evidence_rc=$?
    else
      evidence_rc=1
    fi
  fi
  if declare -F dispatch_record_write >/dev/null 2>&1; then
    local task_id=""
    if declare -F sw_extract_task_id >/dev/null 2>&1; then
      task_id="$(sw_extract_task_id "${brief_file:-}" "" 2>/dev/null || true)"
      [[ "$task_id" == "UNKN-0" ]] && task_id=""
    fi
    dispatch_record_write "$run_id" "$task_id" "${adapter:-unknown}" "$model" \
      "${brief_file:-}" "$work_dir" 130 "cancelled" "cancelled by pmctl dispatch cancel" \
      "" "" "" "$created_ts" "$finished_ts" || evidence_rc=$?
  else
    evidence_rc=1
  fi

  # Authenticated cancelled sentinel — required so wait is never stranded after
  # a successful claim (supervisor will not publish a competing terminal).
  local _key_file _key_nonce _sentinel
  _key_file="$(_pmctl_sentinel_key_file "$run_id")"
  if [[ ! -f "$_key_file" ]]; then
    printf 'pmctl dispatch cancel: sentinel key absent for %s; claim held as cancelled but wait may be indeterminate\n' "$run_id" >&2
    return 2
  fi
  _key_nonce="$(cat "$_key_file" 2>/dev/null)" || _key_nonce=""
  if [[ -z "$_key_nonce" ]]; then
    printf 'pmctl dispatch cancel: empty sentinel key for %s; claim held as cancelled\n' "$run_id" >&2
    return 2
  fi
  _sentinel="$(detached_launch_sentinel_path "pm-supervisor" "$run_id" "$_key_nonce")"
  detached_launch_write_sentinel "$_sentinel" "final_state=cancelled" "exit_code=130"
  if [[ ! -f "$_sentinel" ]]; then
    printf 'pmctl dispatch cancel: failed to write cancelled sentinel for %s; claim held as cancelled\n' "$run_id" >&2
    return 2
  fi

  # Non-evidence cleanup only after terminal proof is durable. Keep
  # sentinel + key for wait consumption; drop pid/identity/runspec/brief.
  rm -f "$pid_file" "$identity_file" "$runspec" 2>/dev/null || true
  if [[ -n "$brief_file" && "$brief_file" == "/tmp/brief-${run_id}.md" ]]; then
    rm -f "$brief_file" 2>/dev/null || true
  fi

  if [[ "$evidence_rc" -ne 0 ]]; then
    printf 'pmctl dispatch cancel: run %s cancelled (sentinel ok) but durable evidence incomplete (rc=%s)\n' \
      "$run_id" "$evidence_rc" >&2
    printf 'run: %s  state: cancelled  exit: 130\n' "$run_id"
    return 2
  fi

  printf 'run: %s  state: cancelled  exit: 130\n' "$run_id"
  return 0
}

pmctl_dispatch_status() {
  local repo_root="${1:-}"
  shift || true
  local work_dir=""

  _pmctl_dispatch_ensure_detached_launch "$repo_root" || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch status: missing value for --cd\n' >&2
          return 2
        fi
        work_dir="$(_portable_canonical_path "$2")"
        shift 2
        ;;
      --*)
        printf 'pmctl dispatch status: unknown option %s\n' "$1" >&2
        return 2
        ;;
      *)
        printf 'pmctl dispatch status: unexpected argument %s\n' "$1" >&2
        return 2
        ;;
    esac
  done
  if [[ -z "$work_dir" ]]; then
    printf 'pmctl dispatch status: --cd <work_dir> is required\n' >&2
    return 2
  fi

  if ! _pmctl_dispatch_ensure_state_paths; then
    printf 'pmctl dispatch status: state-paths unavailable\n' >&2
    return 2
  fi

  local proj_dir runs_root
  proj_dir="$(cd "$work_dir" 2>/dev/null && _SW_REPO_ROOT="$work_dir" _sw_project_dir 2>/dev/null)" || proj_dir=""
  runs_root="${proj_dir}runs"
  if [[ -z "$proj_dir" || ! -d "$runs_root" ]]; then
    printf 'pmctl dispatch status: no runs under %s\n' "$work_dir"
    return 0
  fi

  local found=0 run_path run_id art_dir claim_state pid_alive="no"
  for run_path in "$runs_root"/*; do
    [[ -d "$run_path" ]] || continue
    run_id="$(basename "$run_path")"
    pm_identifier_run_is_valid "$run_id" || continue
    art_dir="$run_path/.agent-trace"
    if [[ -f "$art_dir/$run_id.terminal" ]]; then
      claim_state="$(grep -m1 '^final_state=' "$art_dir/$run_id.terminal" 2>/dev/null | cut -d= -f2-)" || claim_state="?"
      printf 'run: %s  status: terminal  final_state: %s\n' "$run_id" "$claim_state"
      found=1
      continue
    fi
    pid_alive="no"
    if [[ -f "$art_dir/$run_id.supervisor.identity" ]]; then
      if detached_launch_load_identity_file "$art_dir/$run_id.supervisor.identity" 2>/dev/null; then
        if detached_launch_verify_identity "$DL_ID_PID" "$art_dir/$run_id.supervisor.identity" 2>/dev/null; then
          pid_alive="yes"
        fi
      fi
    elif [[ -f "$art_dir/$run_id.supervisor.pid" ]]; then
      local _p
      _p="$(tr -d ' \n' <"$art_dir/$run_id.supervisor.pid" 2>/dev/null || true)"
      if [[ "$_p" =~ ^[0-9]+$ ]] && kill -0 "$_p" 2>/dev/null; then
        pid_alive="unknown-identity"
      fi
    fi
    printf 'run: %s  status: in-flight  process_alive: %s\n' "$run_id" "$pid_alive"
    found=1
  done
  if [[ "$found" -eq 0 ]]; then
    printf 'pmctl dispatch status: no runs under %s\n' "$work_dir"
  fi
  return 0
}

# Classify (and, unless apply=0, converge) a single detached run from trusted
# out-of-repo evidence only (identity, pid file, runspec, terminal claim).
# Never infers success from advisory records; only ever converges to "failed"
# (never "ok"/"partial") and only when absence-of-process is provable; never
# overwrites an existing terminal claim (CC-499).
#   0 — classified (see printed status line); apply may have written a claim
#   2 — no trusted dispatch evidence at all for this run_id (unknown run)
_pmctl_dispatch_reconcile_one() {
  local repo_root="${1:-}" work_dir="${2:-}" run_id="${3:-}" apply="${4:-1}"
  local art_dir identity_file pid_file runspec

  art_dir="$(_pmctl_dispatch_trusted_artifact_dir "$work_dir" "$run_id")" || {
    printf 'run: %s  status: indeterminate  detail: state partition unresolved\n' "$run_id"
    return 0
  }
  identity_file="$art_dir/$run_id.supervisor.identity"
  pid_file="$art_dir/$run_id.supervisor.pid"
  runspec="$art_dir/$run_id.runspec"

  if _pmctl_dispatch_read_terminal_claim "$work_dir" "$run_id"; then
    printf 'run: %s  status: terminal-authenticated  final_state: %s\n' "$run_id" "${PMCTL_TERMINAL_STATE:-?}"
    return 0
  fi

  if [[ ! -f "$identity_file" && ! -f "$pid_file" && ! -f "$runspec" ]]; then
    printf 'pmctl dispatch reconcile: no trusted dispatch evidence for %s under %s (unknown run)\n' \
      "$run_id" "$art_dir" >&2
    return 2
  fi

  if [[ -f "$identity_file" ]]; then
    if ! detached_launch_load_identity_file "$identity_file"; then
      printf 'run: %s  status: indeterminate  detail: unreadable identity file\n' "$run_id"
      return 0
    fi
    local verify_rc=0
    detached_launch_verify_identity "$DL_ID_PID" "$identity_file" || verify_rc=$?
    if [[ "$verify_rc" -eq 0 ]]; then
      printf 'run: %s  status: in-flight  process_alive: yes\n' "$run_id"
      return 0
    fi
    if [[ "$verify_rc" -eq 2 ]]; then
      # Live pid, but identity mismatch (e.g. PID reuse). Cannot prove the
      # original process is gone or still running — refuse to converge.
      printf 'run: %s  status: indeterminate  detail: identity mismatch (possible PID reuse); not converged\n' "$run_id"
      return 0
    fi
    # verify_rc==1: process (or, per boot_id, the whole boot) is provably
    # gone. No terminal claim exists (checked above) — orphaned.
    printf 'run: %s  status: orphaned  detail: process no longer exists, no terminal evidence\n' "$run_id"
    if [[ "$apply" -eq 1 ]]; then
      _pmctl_dispatch_reconcile_converge "$repo_root" "$work_dir" "$run_id"
    fi
    return 0
  fi

  if [[ -f "$pid_file" ]]; then
    local p
    p="$(tr -d ' \n' <"$pid_file" 2>/dev/null || true)"
    if [[ "$p" =~ ^[0-9]+$ ]]; then
      if kill -0 "$p" 2>/dev/null; then
        printf 'run: %s  status: in-flight  process_alive: unknown-identity\n' "$run_id"
        return 0
      fi
      # Recorded pid confirmed not currently running: provable absence for
      # THIS specific pid (a negative kill -0 carries no PID-reuse ambiguity —
      # nothing is running under it right now), even without a full
      # pid/pgid/starttime identity match. Safe to converge.
      printf 'run: %s  status: process-gone-without-evidence  detail: recorded pid no longer running, no identity captured\n' "$run_id"
      if [[ "$apply" -eq 1 ]]; then
        _pmctl_dispatch_reconcile_converge "$repo_root" "$work_dir" "$run_id"
      fi
      return 0
    fi
    # Malformed/unparseable pid_file content (not a bare integer) — no
    # liveness signal at all; falls through to the no-evidence indeterminate
    # path below rather than being treated as proof of absence.
  fi

  # No identity file AND no parseable pid — only a runspec (or a malformed
  # pid_file). Zero liveness signal in either direction; the supervisor could
  # still be alive with lost or never-written identity artifacts. Report
  # only, never converge: claiming
  # "failed" here would fabricate proof of absence the run never gave us
  # (gate critic finding — a false terminal claim could overwrite a still-live
  # job; the "never infer success/failure without provable absence" contract
  # from CC-499's Requirement #3 applies just as much to failure as success).
  printf 'run: %s  status: indeterminate  detail: no identity or pid ever captured; cannot prove process absence\n' "$run_id"
  return 0
}

# Shared convergence tail for both orphaned and process-gone-without-evidence:
# CAS-claim "failed" (never invented "ok"/"partial"), then best-effort durable
# Run/Event/dispatch-record evidence from trusted runspec metadata. Mirrors
# pmctl_dispatch_cancel's post-claim evidence block but writes "failed"
# (reconcile never signals a process, so 130/"cancelled" would be dishonest).
# art_dir/identity_file/runspec are re-derived here (same as the caller) so
# this stays a two-argument-plus-context call, not a five-parameter one.
_pmctl_dispatch_reconcile_converge() {
  local repo_root="${1:-}" work_dir="${2:-}" run_id="${3:-}"
  local art_dir identity_file runspec
  art_dir="$(_pmctl_dispatch_trusted_artifact_dir "$work_dir" "$run_id")" || return 1
  identity_file="$art_dir/$run_id.supervisor.identity"
  runspec="$art_dir/$run_id.runspec"

  if ! _pmctl_dispatch_try_terminal_claim "$work_dir" "$run_id" "failed" "reconcile"; then
    # Lost the CAS race (e.g. a concurrent cancel/supervisor write) — read
    # back whatever won; never overwrite.
    if _pmctl_dispatch_read_terminal_claim "$work_dir" "$run_id"; then
      printf 'run: %s  status: terminal-authenticated  final_state: %s  detail: reconcile lost race, not overwritten\n' \
        "$run_id" "${PMCTL_TERMINAL_STATE:-?}"
    fi
    return 0
  fi
  printf 'run: %s  action: claimed failed (reconcile)\n' "$run_id"

  local adapter="" model="" brief_file="" created_ts="" from_state finished_ts
  _pmctl_dispatch_read_runspec_fields "$runspec" || true
  adapter="$PMCTL_RS_ADAPTER"; model="$PMCTL_RS_MODEL"
  brief_file="$PMCTL_RS_BRIEF_FILE"; created_ts="$PMCTL_RS_CREATED_TS"
  from_state="$(_pmctl_dispatch_infer_from_state "$work_dir" "$run_id")"
  [[ -n "$created_ts" ]] || created_ts="$(pmctl_dispatch_utc_ts)"
  finished_ts="$(pmctl_dispatch_utc_ts)"

  if [[ -n "$adapter" ]]; then
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$run_id" \
      "failed" 1 "$model" "${brief_file:-}" "" "$created_ts" "$from_state" 2>/dev/null || true
  fi
  if declare -F pmctl_dispatch_write_record_soft >/dev/null 2>&1; then
    pmctl_dispatch_write_record_soft "$run_id" "${adapter:-unknown}" "$model" "${brief_file:-}" \
      "$work_dir" 1 "failed" "reconciled: process gone, no terminal evidence found" \
      "" "" "" "$created_ts" "$finished_ts" 2>/dev/null || true
  fi

  # Evidence is durable; drop stale non-evidence trust artifacts (mirrors cancel).
  rm -f "$art_dir/$run_id.supervisor.pid" "$identity_file" "$runspec" 2>/dev/null || true
}

# `pmctl dispatch reconcile <run_id> --cd <dir> [--dry-run]` or
# `pmctl dispatch reconcile --all --cd <dir> [--dry-run]` (CC-499). Converges
# stale detached runs to a conservative, evidence-backed terminal state
# without the user hand-inspecting the state directory or `ps`.
pmctl_dispatch_reconcile() {
  local repo_root="${1:-}"
  shift || true
  local run_id="" work_dir="" all=0 dry_run=0

  _pmctl_dispatch_ensure_detached_launch "$repo_root" || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch reconcile: missing value for --cd\n' >&2
          return 2
        fi
        work_dir="$(_portable_canonical_path "$2")"
        shift 2
        ;;
      --all)
        all=1
        shift
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      --*)
        printf 'pmctl dispatch reconcile: unknown option %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [[ -n "$run_id" ]]; then
          printf 'pmctl dispatch reconcile: unexpected argument %s\n' "$1" >&2
          return 2
        fi
        run_id="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$work_dir" ]]; then
    printf 'pmctl dispatch reconcile: --cd <work_dir> is required\n' >&2
    return 2
  fi
  if [[ "$all" -eq 1 && -n "$run_id" ]]; then
    printf 'pmctl dispatch reconcile: <run_id> and --all are mutually exclusive\n' >&2
    return 2
  fi
  if [[ "$all" -eq 0 && -z "$run_id" ]]; then
    printf 'pmctl dispatch reconcile: <run_id> is required unless --all is given\n' >&2
    return 2
  fi
  if [[ "$all" -eq 0 ]] && ! pm_identifier_run_is_valid "$run_id"; then
    printf 'pmctl dispatch reconcile: invalid run_id %q\n' "$run_id" >&2
    return 2
  fi

  local apply=1
  [[ "$dry_run" -eq 1 ]] && apply=0

  if [[ "$all" -eq 0 ]]; then
    _pmctl_dispatch_reconcile_one "$repo_root" "$work_dir" "$run_id" "$apply"
    return $?
  fi

  if ! _pmctl_dispatch_ensure_state_paths; then
    printf 'pmctl dispatch reconcile: state-paths unavailable\n' >&2
    return 2
  fi
  local proj_dir runs_root run_path found=0
  proj_dir="$(cd "$work_dir" 2>/dev/null && _SW_REPO_ROOT="$work_dir" _sw_project_dir 2>/dev/null)" || proj_dir=""
  runs_root="${proj_dir}runs"
  if [[ -z "$proj_dir" || ! -d "$runs_root" ]]; then
    printf 'pmctl dispatch reconcile: no runs under %s\n' "$work_dir"
    return 0
  fi
  for run_path in "$runs_root"/*; do
    [[ -d "$run_path" ]] || continue
    run_id="$(basename "$run_path")"
    pm_identifier_run_is_valid "$run_id" || continue
    _pmctl_dispatch_reconcile_one "$repo_root" "$work_dir" "$run_id" "$apply" || true
    found=1
  done
  if [[ "$found" -eq 0 ]]; then
    printf 'pmctl dispatch reconcile: no runs under %s\n' "$work_dir"
  fi
  return 0
}

pmctl_dispatch_run() {
  local repo_root="${1:-}"
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl dispatch run: missing repo root\n' >&2
    return 2
  fi
  shift || true

  local adapter="" work_dir="" brief_file="" print_cmd=0 auto_pack_flag="" lifecycle_flag="" parent_operation="" parent_operation_work_dir=""
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
      --parent-operation)
        if [[ $# -lt 2 ]] || ! pm_identifier_operation_is_valid "$2"; then
          printf 'pmctl dispatch run: --parent-operation requires a valid operation id\n' >&2
          return 2
        fi
        parent_operation="$2"
        shift 2
        ;;
      --parent-operation-cd)
        [[ $# -ge 2 && "$2" == /* && -d "$2" ]] || {
          printf 'pmctl dispatch run: --parent-operation-cd requires an existing absolute directory\n' >&2
          return 2
        }
        parent_operation_work_dir="$(_portable_canonical_path "$2")"
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
  if ! pm_identifier_adapter_is_valid "$adapter"; then
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
  elif [[ -n "$parent_operation" ]]; then
    printf 'pmctl dispatch run: --parent-operation requires --lifecycle detached\n' >&2
    return 2
  elif [[ -n "$parent_operation_work_dir" ]]; then
    printf 'pmctl dispatch run: --parent-operation-cd requires --parent-operation\n' >&2
    return 2
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

  # 3c. Guard (shared policy) — MANDATORY, FAIL CLOSED if the guard is unavailable.
  #     Gates the executor brief-file path for this runtime via the same code path the
  #     PreToolUse hooks enforce. The dispatch adapter IS the runtime axis; the role is
  #     always `executor` here.
  if ! declare -F pmctl_guard_check >/dev/null; then
    printf 'pmctl dispatch run: guard unavailable (pmctl-guard not sourced) — refusing to dispatch without policy enforcement\n' >&2
    return 2
  fi
  # 3d. Guard the AUTHORED brief (the caller-supplied --brief-file) for path policy
  #     FIRST — BEFORE auto-pack reads or copies it. A brief outside the /tmp guard
  #     pattern is denied here, so a guard-denied path can never be read into or
  #     persisted as a derived pack artifact under .pm-dispatch/ctx/packs/. Both
  #     lifecycles (detached additionally re-guards its /tmp snapshot in the supervisor).
  if ! pmctl_guard_check "$repo_root" --event pre-write --role executor --runtime "$adapter" --file "$brief_file"; then
    printf 'pmctl dispatch run: guard denied dispatch for adapter %q\n' "$adapter" >&2
    return 2
  fi

  # 3e. Auto-pack (best-effort) runs for BOTH lifecycles, deriving a pack ONLY from the
  # now guard-approved authored brief. It appends a pointer-only auto_context: block to
  # a copy of the brief under .pm-dispatch/ctx/packs/ and, on success, that pack becomes
  # the EFFECTIVE brief.
  PMCTL_DISPATCH_AUTO_PACK_PATH=""
  if [[ "$_auto_pack_effective" == "on" ]]; then
    pmctl_dispatch_auto_pack "$repo_root" "$work_dir" "$brief_file" "$_dispatch_run_id" || true
  fi

  # 3f. Validate the EFFECTIVE brief (the augmented pack when auto-pack produced one,
  # else the original). Validating here — after auto-pack — lets the gate count an
  # appended auto_context: block as retrieval evidence under BRIEF_VALIDATE_RETRIEVAL=
  # fail. The check is content-only and path-agnostic.
  local _effective_brief="${PMCTL_DISPATCH_AUTO_PACK_PATH:-$brief_file}"
  pmctl_dispatch_validate_brief "$repo_root" "$_effective_brief" || return 2

  # 3g. Foreground: land the effective brief at the guardable /tmp/brief-<run_id>.md
  # path and guard THAT too, so a SINGLE brief is guarded == validated == executed ==
  # post-verified == recorded — matching the detached supervisor, which re-guards its
  # own /tmp snapshot before the executor runs. The auto-pack pack lives under
  # .pm-dispatch/ctx/packs/ (not a guardable path), so when one was produced we
  # snapshot it to /tmp here. No-op when no pack was produced: the effective brief is
  # already the authored /tmp brief just guarded above. Detached keeps the work-repo
  # pack as its effective brief and snapshots it inside run_detached/the supervisor.
  if [[ "$_lifecycle_effective" == "foreground" && -n "$PMCTL_DISPATCH_AUTO_PACK_PATH" ]]; then
    local _fg_snapshot="/tmp/brief-$_dispatch_run_id.md" _fg_snap_tmp
    _fg_snap_tmp="$(mktemp "/tmp/.brief-$_dispatch_run_id.XXXXXX")" || {
      printf 'pmctl dispatch run: failed to create foreground pack snapshot tempfile\n' >&2
      return 2
    }
    if ! { cp "$_effective_brief" "$_fg_snap_tmp" && mv -f "$_fg_snap_tmp" "$_fg_snapshot"; }; then
      rm -f "$_fg_snap_tmp"
      printf 'pmctl dispatch run: failed to snapshot foreground pack to %s\n' "$_fg_snapshot" >&2
      return 2
    fi
    _effective_brief="$_fg_snapshot"
    if ! pmctl_guard_check "$repo_root" --event pre-write --role executor --runtime "$adapter" --file "$_effective_brief"; then
      printf 'pmctl dispatch run: guard denied dispatch for adapter %q (effective brief)\n' "$adapter" >&2
      return 2
    fi
  fi

  # 3h. Point the adapter argv at the effective brief (single rewrite, both lifecycles).
  if [[ "$_effective_brief" != "$brief_file" ]]; then
    local _brief_i
    for ((_brief_i = 0; _brief_i < ${#forward[@]}; _brief_i += 1)); do
      if [[ "${forward[$_brief_i]}" == "--brief-file" && $((_brief_i + 1)) -lt ${#forward[@]} ]]; then
        forward[_brief_i + 1]="$_effective_brief"
        break
      fi
    done
    unset _brief_i
  fi

  # 4. Export config defaults to the adapter subprocess.
  #     Adapters honour PM_CFG_TIMEOUT / PM_CFG_DEFAULT_MODEL at lower priority
  #     than their adapter-specific env vars (CODEX_DISPATCH_TIMEOUT, etc.) and
  #     lower than an explicit --timeout / --model flag — the existing elif chains
  #     in each adapter preserve that ordering without any adapter-side change.
  #     Export is unconditional; adapters that omit the config branch safely ignore
  #     unknown env vars. pm_config_load is guarded so test environments that did
  #     not source pmctl-config.sh degrade silently rather than hitting exit 127.
  # shellcheck disable=SC2163
  export PM_CFG_TIMEOUT PM_CFG_DEFAULT_MODEL PM_CFG_AUTO_PACK PM_CFG_USAGE_LOG_PATH

  # 5. Execute. Foreground runs the tail in-process (blocking). Detached persists
  #    a run-spec, snapshots the brief durably, and hands the post-preflight tail
  #    to the supervisor via setsid/nohup; returns run_id immediately.  The
  #    preflight gates above still front every executor invocation in both paths.
  if [[ "$_lifecycle_effective" == "detached" ]]; then
    # Parent ownership must be durable BEFORE the launch boundary.  If this
    # append cannot succeed, no executor has started and the caller can safely
    # retry; attaching after launch would create an un-cancellable orphan.
    if [[ -n "$parent_operation" ]]; then
      if ! declare -F pmctl_operation_attach_child >/dev/null 2>&1; then
        printf 'pmctl dispatch run: parent-operation library unavailable; refusing unrecorded child %s\n' "$_dispatch_run_id" >&2
        return 2
      fi
      local _parent_operation_dir="${parent_operation_work_dir:-$work_dir}"
      if ! pmctl_operation_attach_child "$repo_root" "$_parent_operation_dir" "$parent_operation" "$_dispatch_run_id" "$work_dir"; then
        printf 'pmctl dispatch run: failed to reserve child %s under parent %s; executor was not launched\n' "$_dispatch_run_id" "$parent_operation" >&2
        return 2
      fi
    fi
    local _detached_out _detached_rc=0
    _detached_out="$(pmctl_dispatch_run_detached "$repo_root" "$work_dir" "$adapter" \
      "$_dispatch_run_id" "$_dispatch_model" "$_effective_brief" "$_dispatch_created_ts" "$print_cmd" \
      "${forward[@]}")" || _detached_rc=$?
    if [[ "$_detached_rc" -ne 0 ]]; then
      # The child is already recorded under the parent, so the reservation must
      # not outlive the failed launch as an unresolvable record.  Supervisor
      # launch failure writes its own claim; every earlier failure inside
      # run_detached (runspec, transitions, brief snapshot) does not, and without
      # one reconcile can only report `indeterminate` for a launch that provably
      # never happened.  The claim is an exclusive-create CAS, so writing it here
      # is a no-op when the inner path already claimed the run.
      if [[ -n "$parent_operation" ]]; then
        _pmctl_dispatch_try_terminal_claim "$work_dir" "$_dispatch_run_id" "failed" "launch" 2>/dev/null || true
      fi
      return "$_detached_rc"
    fi
    printf '%s\n' "$_detached_out"
    return 0
  fi

  pmctl_dispatch_execute_tail "$repo_root" "$work_dir" "$adapter" "$adapter_path" \
    "$_dispatch_run_id" "$_dispatch_model" "$_effective_brief" "$_dispatch_created_ts" "$print_cmd" \
    "${forward[@]}"
  return $?
}
