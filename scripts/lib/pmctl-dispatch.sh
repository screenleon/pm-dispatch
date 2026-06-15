#!/usr/bin/env bash

# Executor-agnostic dispatch orchestrator (CC-289, approach B).
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
# defaults and export them to adapter subprocesses (CC-293).
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

pmctl_dispatch_run() {
  local repo_root="${1:-}"
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl dispatch run: missing repo root\n' >&2
    return 2
  fi
  shift || true

  local adapter="" work_dir="" brief_file="" print_cmd=0 auto_pack_flag=""
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
      --)
        # Inline brief form skips brief-validate + guard, so it is a policy
        # bypass. Refuse it at the orchestrator (the policy surface); briefs must
        # be written to a file and passed via --brief-file.
        printf 'pmctl dispatch run: inline brief form (--) is not supported; write the brief to a file and pass --brief-file so policy checks (brief-validate + guard) can run\n' >&2
        return 2
        ;;
      *)
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

  # 1. Resolve adapter by convention — the name is now a validated bare identifier.
  local adapter_path="$repo_root/adapters/$adapter/dispatch.sh"
  if [[ ! -f "$adapter_path" ]]; then
    printf 'pmctl dispatch run: unknown adapter %q (no %s). An adapter must provide adapters/<name>/dispatch.sh; run pmctl adapter generate to scaffold it.\n' "$adapter" "$adapter_path" >&2
    return 2
  fi

  # Containment: the adapter script must be a regular file (not a symlink) whose
  # physical directory stays within repo_root/adapters/. Name validation already
  # blocks `../` in the token; this additionally blocks a symlinked dispatch.sh
  # (or symlinked adapter dir) from escaping the trust boundary to execute an
  # arbitrary script outside the repo.
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

  # 2. Route — the dispatch ALLOWLIST. Fail closed: a missing routing registry
  #    must refuse the dispatch, never silently skip the allowlist.
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

  # 3. Brief-validate (shared) — always runs; there is no brief-less path.
  local brief_result=0
  local brief_msg
  brief_msg="$(bash "$repo_root/scripts/brief-validate.sh" "$brief_file" 2>&1)" || brief_result=$?
  if [[ "$brief_result" -ne 0 ]]; then
    printf 'pmctl dispatch run: brief failed validation: %s\n%s\n' "$brief_file" "$brief_msg" >&2
    return 2
  fi
  if [[ -n "$brief_msg" && "$brief_msg" != "VALID" ]]; then
    printf '%s\n' "$brief_msg" >&2
  fi

  # 3a. Optional auto-pack. Config is loaded here because dispatch.auto_pack
  # decides whether this pre-guard step runs; adapter-facing config exports are
  # still applied below before invocation.
  if type -t pm_config_load >/dev/null 2>&1; then pm_config_load; fi
  local _dispatch_model _dispatch_created_ts _dispatch_run_id _auto_pack_effective
  _dispatch_model="$(pmctl_dispatch_extract_model "${forward[@]}")"
  _dispatch_created_ts="$(pmctl_dispatch_utc_ts)"
  _dispatch_run_id="run-$(pmctl_dispatch_stamp)-$(pmctl_dispatch_hex6)"
  _auto_pack_effective="off"
  if [[ "$auto_pack_flag" == "on" || "$auto_pack_flag" == "off" ]]; then
    _auto_pack_effective="$auto_pack_flag"
  elif [[ "${PM_CFG_AUTO_PACK:-}" == "on" || "${PM_CFG_AUTO_PACK:-}" == "off" ]]; then
    _auto_pack_effective="$PM_CFG_AUTO_PACK"
  fi
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

  # 4. Guard (shared policy) — MANDATORY. Fail closed if the guard is unavailable.
  #    Gates the executor's brief-file write for this runtime via the same code
  #    path the PreToolUse hooks enforce. The dispatch adapter IS the runtime
  #    axis (CC-291); the role is always `executor` here.
  if ! declare -F pmctl_guard_check >/dev/null; then
    printf 'pmctl dispatch run: guard unavailable (pmctl-guard not sourced) — refusing to dispatch without policy enforcement\n' >&2
    return 2
  fi
  if ! pmctl_guard_check "$repo_root" --event pre-write --role executor --runtime "$adapter" --file "$brief_file"; then
    printf 'pmctl dispatch run: guard denied dispatch for adapter %q\n' "$adapter" >&2
    return 2
  fi

  # 4a. Export config defaults to the adapter subprocess (CC-293).
  #     Adapters honour PM_CFG_TIMEOUT / PM_CFG_DEFAULT_MODEL at lower priority
  #     than their adapter-specific env vars (CODEX_DISPATCH_TIMEOUT, etc.) and
  #     lower than an explicit --timeout / --model flag — the existing elif chains
  #     in each adapter preserve that ordering without any adapter-side change.
  #     Export is unconditional; adapters that omit the config branch safely ignore
  #     unknown env vars. pm_config_load is guarded so test environments that did
  #     not source pmctl-config.sh degrade silently rather than hitting exit 127.
  # shellcheck disable=SC2163
  export PM_CFG_TIMEOUT PM_CFG_DEFAULT_MODEL PM_CFG_AUTO_PACK

  if [[ "$print_cmd" -eq 0 ]]; then
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "pending" 0 "$_dispatch_model" "$brief_file" "" "$_dispatch_created_ts" "" || return $?
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "dispatched" 0 "$_dispatch_model" "$brief_file" "" "$_dispatch_created_ts" "pending" || return $?
  fi

  # 5. Invoke the adapter subprocess — the ONLY executor-specific step.
  #    Tee stdout to a temp file so per-run artifact paths in the adapter footer
  #    can be extracted for post-verify without relying on latest.* symlinks.
  #    latest.* is shared mutable state: two concurrent dispatches on the same
  #    work dir both call `ln -sfn <adapter>-<ts>.last latest.last`, so the
  #    second finisher silently overwrites the first's symlink before post-verify
  #    reads it (CC-305). Explicit per-run paths eliminate the race entirely.
  local exit_code=0 _footer_tmp=""
  local -a _pst=(0 0)
  _footer_tmp="$(mktemp)" || { printf 'pmctl dispatch run: mktemp failed\n' >&2; return 2; }
  # Capture PIPESTATUS before any subsequent command clobbers it.  The { } group
  # is the LHS of ||, so set -e is suppressed for a non-zero pipeline exit.
  { bash "$adapter_path" "${forward[@]}" | tee "$_footer_tmp"; _pst=("${PIPESTATUS[@]}"); } || true
  exit_code="${_pst[0]}"

  # Parse per-run paths from the adapter stdout footer ("last:   <path>",
  # "stderr: <path>").  Empty strings → post-verify falls back to latest.*.
  # "model:  <value>" overrides the pmctl-extracted model with the adapter's
  # effective model (e.g. codex always resolves its built-in "default" alias
  # even when no --model or config default is supplied).
  local _run_last="" _run_trace="" _run_stderr="" _run_model=""
  _run_last="$(grep -m1 '^last:' "$_footer_tmp" | sed 's/^last:[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)" || true
  _run_trace="$(grep -m1 '^trace:' "$_footer_tmp" | sed 's/^trace:[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)" || true
  _run_stderr="$(grep -m1 '^stderr:' "$_footer_tmp" | sed 's/^stderr:[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)" || true
  _run_model="$(grep -m1 '^model:' "$_footer_tmp" | sed 's/^model:[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null)" || true
  [[ -n "$_run_model" ]] && _dispatch_model="$_run_model"
  rm -f "$_footer_tmp"

  # Dry-run (--print-cmd): the adapter printed its command and wrote no trace;
  # there is no output contract to read and nothing to post-verify.
  if [[ "$print_cmd" -eq 1 ]]; then
    return "$exit_code"
  fi

  pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
    "verifying" "$exit_code" "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "dispatched" || return $?

  # 6. A failed adapter run short-circuits: propagate its exit verbatim. The
  #    adapter already wrote forensic trace/stderr for post-mortem.
  if [[ "$exit_code" -ne 0 ]]; then
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "failed" "$exit_code" "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "verifying" || return $?
    return "$exit_code"
  fi

  # 7. Post-verify (shared): pass explicit per-run paths (parsed from the adapter
  #    footer) so post-verify never reads latest.*, eliminating the CC-305 race.
  #    Falls back to latest.* defaults when footer parsing found nothing (e.g.,
  #    a print-cmd adapter or a future adapter that omits the footer).
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
  if ! bash "$repo_root/scripts/dispatch-post-verify.sh" "${_pv_args[@]}"; then
    printf 'pmctl dispatch run: post-verify failed\n' >&2
    pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
      "failed" 1 "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "verifying" || return $?
    return 1
  fi

  pmctl_dispatch_write_transition "$repo_root" "$work_dir" "$adapter" "$_dispatch_run_id" \
    "ok" "$exit_code" "$_dispatch_model" "$brief_file" "${_run_last:-}" "$_dispatch_created_ts" "verifying" || return $?

  return "$exit_code"
}
