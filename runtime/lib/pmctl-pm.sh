#!/usr/bin/env bash
# Batch-only PM coordinator for non-Claude hosts.
#
# It deliberately does not classify an open-ended request or manufacture a
# dispatch brief. A host/LLM supplies the reasoning and a complete brief; this
# command owns the repeatable shell steps around it: snapshot, validation,
# detached dispatch, and authenticated wait.

# shellcheck source=runtime/lib/host-names.sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/host-names.sh"

pmctl_pm_usage() {
  cat >&2 <<'EOF'
usage: pmctl pm prepare --request <text> [--cd <work_dir>] [--focus <CC-N,...>] [--host <claude|codex|opencode|grok|generic>] [--json]
       pmctl pm run --adapter <name> --brief-file <path> --cd <work_dir> [--host <claude|codex|opencode|grok|generic>] [--model <model>] [--isolation <level>] [--timeout <seconds>] [--no-auto-pack] [--json]

Batch-only interface: prepare captures context for a fully specified request;
run requires a complete dispatch_handover_v1 brief. Ambiguous requests are not
interactive and must be resolved by the calling host before `pmctl pm run`.
EOF
}

pmctl_pm_default_cd() {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  printf '%s\n' "${top:-$PWD}"
}

pmctl_pm_append_focus_ticket() {
  local focus="$1" ticket="$2"
  case ",$focus," in
    *",$ticket,"*) printf '%s\n' "$focus" ;;
    *) printf '%s\n' "${focus:+$focus,}$ticket" ;;
  esac
}

# Keep the context pack parseable while enforcing a byte budget. Remove whole
# memories[] entries from the tail and re-serialize; never raw-slice JSON.
pmctl_pm_bound_memory_pack() {
  local pack="$1" max_bytes="${2:-6000}" count bounded bytes
  [[ "$max_bytes" =~ ^[1-9][0-9]*$ ]] || return 1
  count="$(jq -r '.memories | length' <<<"$pack" 2>/dev/null)" || return 1
  [[ "$count" =~ ^[0-9]+$ ]] || return 1
  while (( count >= 0 )); do
    bounded="$(jq -c --argjson count "$count" '.memories = (.memories[:$count])' <<<"$pack" 2>/dev/null)" || return 1
    bytes="$(printf '%s' "$bounded" | wc -c | tr -d '[:space:]')"
    if [[ "$bytes" =~ ^[0-9]+$ ]] && (( bytes <= max_bytes )); then
      printf '%s\n' "$bounded"
      return 0
    fi
    count=$((count - 1))
  done
  return 1
}

# Resolve and query canonical memory with one failure/status contract for both
# preparation and dispatch. Results are returned in the three PMCTL_PM_MEMORY_*
# globals so callers can retain the resolver document even on fail-closed rc 3.
pmctl_pm_hydrate_memory() {
  local work_dir="$1" task_id="$2"; shift 2
  local memory_rc=1 query_rc=0 query
  local -a pack_args=("$work_dir" --task-id "$task_id" --source memory)
  PMCTL_PM_MEMORY_RESOLUTION="$(jq -cn --arg repo "$work_dir" '{schema_version:1,status:"unavailable",repo_root:$repo,project_key:"",memory_dir:null,resolution_source:"none",readable:false,writable:false,reason:null}')"
  PMCTL_PM_MEMORY_CONTEXT=""
  PMCTL_PM_MEMORY_CONTEXT_STATUS="unavailable"

  declare -F pmctl_memory_resolve >/dev/null 2>&1 || return 0
  memory_rc=0
  PMCTL_PM_MEMORY_RESOLUTION="$(pmctl_memory_resolve --repo-root "$work_dir" --json)" || memory_rc=$?
  [[ "$memory_rc" -ne 3 ]] || return 3
  [[ "$memory_rc" -eq 0 ]] || return 0

  PMCTL_PM_MEMORY_CONTEXT_STATUS="no-hits"
  declare -F pmctl_context_pack >/dev/null 2>&1 || return 0
  for query in "$@"; do
    [[ -n "${query//[[:space:]]/}" ]] && pack_args+=(--query "$query")
  done
  [[ "${#pack_args[@]}" -gt 5 ]] || pack_args+=(--query "dispatch brief")
  PMCTL_PM_MEMORY_CONTEXT="$(pmctl_context_pack "${pack_args[@]}")" || query_rc=$?
  if [[ "$query_rc" -ne 0 ]]; then
    PMCTL_PM_MEMORY_CONTEXT=""
    PMCTL_PM_MEMORY_CONTEXT_STATUS="query-failed"
  elif ! jq -e '.memories | length > 0' <<<"$PMCTL_PM_MEMORY_CONTEXT" >/dev/null 2>&1; then
    PMCTL_PM_MEMORY_CONTEXT=""
  elif PMCTL_PM_MEMORY_CONTEXT="$(pmctl_pm_bound_memory_pack "$PMCTL_PM_MEMORY_CONTEXT" 6000)"; then
    PMCTL_PM_MEMORY_CONTEXT_STATUS="hydrated"
  else
    PMCTL_PM_MEMORY_CONTEXT=""
    PMCTL_PM_MEMORY_CONTEXT_STATUS="query-failed"
  fi
}

pmctl_pm_memory_provenance() {
  local memory_resolution="$1" memory_context_status="$2" memory_context="$3" host="${4:-generic}"
  local refs='[]' hit_count=0
  if [[ -n "$memory_context" ]]; then
    refs="$(jq -c '[.memories[]?.ref] | unique' <<<"$memory_context" 2>/dev/null)" || refs='[]'
    hit_count="$(jq -r 'length' <<<"$refs" 2>/dev/null)" || hit_count=0
  fi
  [[ "$hit_count" =~ ^[0-9]+$ ]] || hit_count=0
  jq -cn \
    --argjson resolution "$memory_resolution" \
    --arg context_status "$memory_context_status" --arg host "$host" \
    --argjson hit_count "$hit_count" --argjson refs "$refs" \
    '{schema_version:1,host:$host,provider:"pmctl",authority:"canonical",project_key:($resolution.project_key // ""),memory_dir:($resolution.memory_dir // null),resolution_source:($resolution.resolution_source // "none"),resolution_status:($resolution.status // "unavailable"),context_status:$context_status,hit_count:$hit_count,refs:$refs,auxiliary_memory:{provider:"host-native",host:$host,role:"auxiliary",status:"unknown",observable:false,hit_count:null,refs:null}}'
}

pmctl_pm_emit_prepare() {
  local json="$1" work_dir="$2" request="$3" focus="$4" snapshot="$5" snapshot_status="$6"
  local memory_resolution="$7" memory_context_status="$8" memory_context="$9"
  local repo_context="${10}" host="${11:-generic}" memory_provenance
  memory_provenance="$(pmctl_pm_memory_provenance "$memory_resolution" "$memory_context_status" "$memory_context" "$host")" || return 1
  if [[ "$json" -eq 1 ]]; then
    jq -cn \
      --arg work_dir "$work_dir" \
      --arg request "$request" \
      --arg focus "$focus" \
      --arg snapshot "$snapshot" \
      --arg snapshot_status "$snapshot_status" \
      --argjson memory_resolution "$memory_resolution" \
      --arg memory_context_status "$memory_context_status" \
      --arg memory_context "$memory_context" \
      --argjson memory_provenance "$memory_provenance" \
      --argjson repo_context "$repo_context" \
      '{schema_version:1,mode:"batch-only",working_dir:$work_dir,request:$request,focus_tickets:(if $focus == "" then [] else $focus | split(",") end),snapshot_file:(if $snapshot == "" then null else $snapshot end),snapshot_status:$snapshot_status,repo_context:$repo_context,memory_resolution:$memory_resolution,memory_provenance:$memory_provenance,memory_context_status:$memory_context_status,memory_context:(if $memory_context == "" then null else $memory_context end),handover_required:true,ambiguity_policy:"reject-and-return-to-host"}'
  else
    printf 'mode: batch-only\nworking_dir: %s\n' "$work_dir"
    [[ -n "$focus" ]] && printf 'focus_tickets: %s\n' "$focus"
    printf 'snapshot_status: %s\n' "$snapshot_status"
    [[ -n "$snapshot" ]] && printf 'snapshot_file: %s\n' "$snapshot"
    printf 'context_status: %s\n' "$(jq -r '.freshness // "unavailable"' <<<"$repo_context")"
    printf 'context_db: %s\n' "$(jq -r '.db_path // ""' <<<"$repo_context")"
    printf 'memory_status: %s\n' "$memory_context_status"
    printf 'memory_provider: %s\n' "$(jq -r '.provider' <<<"$memory_provenance")"
    printf 'memory_authority: %s\n' "$(jq -r '.authority' <<<"$memory_provenance")"
    printf 'memory_project_key: %s\n' "$(jq -r '.project_key' <<<"$memory_provenance")"
    printf 'memory_resolution_source: %s\n' "$(jq -r '.resolution_source' <<<"$memory_provenance")"
    printf 'memory_hit_count: %s\n' "$(jq -r '.hit_count' <<<"$memory_provenance")"
    printf 'memory_refs: %s\n' "$(jq -c '.refs' <<<"$memory_provenance")"
    printf 'memory_host: %s\n' "$(jq -r '.host' <<<"$memory_provenance")"
    printf 'auxiliary_memory_role: %s\n' "$(jq -r '.auxiliary_memory.role' <<<"$memory_provenance")"
    printf 'auxiliary_memory_status: %s\n' "$(jq -r '.auxiliary_memory.status' <<<"$memory_provenance")"
    local memory_dir
    memory_dir="$(jq -r '.memory_dir // empty' <<<"$memory_resolution")"
    [[ -n "$memory_dir" ]] && printf 'memory_dir: %s\n' "$memory_dir"
    if [[ -n "$memory_context" ]]; then
      printf '%s\n%s\n%s\n' '--- memory_context ---' "$memory_context" '--- end_memory_context ---'
    fi
    printf 'next: author a complete dispatch_handover_v1 brief, then run pmctl pm run\n'
  fi
}

pmctl_pm_prepare() {
  local repo_root="$1"; shift
  local request="" work_dir="" focus="" host="generic" json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --request) [[ $# -ge 2 ]] || { printf 'pmctl pm prepare: --request requires a value\n' >&2; return 2; }; request="$2"; shift 2 ;;
      --cd) [[ $# -ge 2 ]] || { printf 'pmctl pm prepare: --cd requires a value\n' >&2; return 2; }; work_dir="$2"; shift 2 ;;
      --focus) [[ $# -ge 2 ]] || { printf 'pmctl pm prepare: --focus requires a value\n' >&2; return 2; }; focus="$2"; shift 2 ;;
      --host)
        [[ $# -ge 2 ]] || { printf 'pmctl pm prepare: --host requires a value\n' >&2; return 2; }
        pmctl_host_is_valid "$2" || { printf 'pmctl pm prepare: --host must be claude, codex, opencode, grok, or generic\n' >&2; return 2; }
        host="$2"
        shift 2 ;;
      --json) json=1; shift ;;
      -h|--help) pmctl_pm_usage; return 0 ;;
      *) printf 'pmctl pm prepare: unknown option: %s\n' "$1" >&2; return 2 ;;
    esac
  done
  [[ -n "${request//[[:space:]]/}" ]] || { printf 'pmctl pm prepare: --request must not be empty\n' >&2; return 2; }
  work_dir="${work_dir:-$(pmctl_pm_default_cd)}"
  work_dir="$(cd "$work_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'pmctl pm prepare: --cd must be inside a git worktree: %s\n' "$work_dir" >&2
    return 2
  }

  if [[ -z "$focus" ]]; then
    local rest="$request" ticket
    while [[ "$rest" =~ (CC-[0-9]+) ]]; do
      ticket="${BASH_REMATCH[1]}"
      focus="$(pmctl_pm_append_focus_ticket "$focus" "$ticket")"
      rest="${rest#*"$ticket"}"
    done
  fi

  local repo_context
  repo_context="$(jq -cn --arg repo "$work_dir" '{schema_version:1,resolved_repo_root:$repo,db_path:null,sqlite_available:false,db_exists:false,freshness:"unavailable",indexed_files:0,new_files:0,changed_files:0,deleted_files:0,db_mtime:null,latest_indexed_at:null,refresh_status:"unavailable"}')"
  if declare -F pmctl_context_workflow_refresh >/dev/null 2>&1; then
    repo_context="$(pmctl_context_workflow_refresh "$work_dir" --json 2>/dev/null)" || \
      repo_context="$(jq -cn --arg repo "$work_dir" '{schema_version:1,resolved_repo_root:$repo,db_path:null,sqlite_available:true,db_exists:false,freshness:"error",indexed_files:0,new_files:0,changed_files:0,deleted_files:0,db_mtime:null,latest_indexed_at:null,refresh_status:"error"}')"
  fi

  local snapshot="" snapshot_status="unavailable" snapshot_err snapshot_rc=0
  snapshot_err="$(mktemp "${TMPDIR:-/tmp}/pmctl-pm-snapshot.XXXXXX")" || return 1
  if [[ -n "$focus" ]]; then
    snapshot="$(cd "$work_dir" && bash "$repo_root/runtime/bin/pm-prep-snapshot.sh" --focus "$focus" 2>"$snapshot_err")" || snapshot_rc=$?
  else
    snapshot="$(cd "$work_dir" && bash "$repo_root/runtime/bin/pm-prep-snapshot.sh" 2>"$snapshot_err")" || snapshot_rc=$?
  fi
  if [[ "$snapshot_rc" -ne 0 && -s "$snapshot_err" ]]; then
    printf 'pmctl pm prepare: snapshot unavailable:\n' >&2
    cat "$snapshot_err" >&2
  fi
  rm -f "$snapshot_err"
  if [[ -n "$snapshot" && -f "$snapshot" ]]; then
    snapshot_status="created"
  else
    snapshot=""
  fi

  # Host-neutral memory hydration. Empty term extraction (currently CJK-only,
  # short English, or stopword-only requests) falls back to the whole request.
  local -a memory_terms=()
  local memory_term memory_hydrate_rc=0
  if declare -F _ctx_extract_terms >/dev/null 2>&1; then
    while IFS= read -r memory_term; do
      [[ -n "$memory_term" ]] && memory_terms+=("$memory_term")
      [[ "${#memory_terms[@]}" -ge 8 ]] && break
    done < <(_ctx_extract_terms "$request")
  fi
  [[ "${#memory_terms[@]}" -gt 0 ]] || memory_terms+=("$request")
  pmctl_pm_hydrate_memory "$work_dir" pm-prepare "${memory_terms[@]}" || memory_hydrate_rc=$?
  local memory_resolution="$PMCTL_PM_MEMORY_RESOLUTION"
  local memory_context="$PMCTL_PM_MEMORY_CONTEXT"
  local memory_context_status="$PMCTL_PM_MEMORY_CONTEXT_STATUS"
  if [[ "$memory_hydrate_rc" -eq 3 ]]; then
    printf 'pmctl pm prepare: explicit memory configuration is invalid: %s\n' \
      "$(jq -r '.reason // "unknown reason"' <<<"$memory_resolution" 2>/dev/null || printf 'unknown reason')" >&2
    [[ -n "$snapshot" && -f "$snapshot" ]] && rm -f "$snapshot"
    return 1
  fi
  pmctl_pm_emit_prepare "$json" "$work_dir" "$request" "$focus" "$snapshot" "$snapshot_status" \
    "$memory_resolution" "$memory_context_status" "$memory_context" "$repo_context" "$host"
}

pmctl_pm_run() {
  local repo_root="$1"; shift
  local adapter="" brief_file="" work_dir="" host="generic" model="" isolation="" timeout="" no_auto_pack=0 json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --adapter) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --adapter requires a value\n' >&2; return 2; }; adapter="$2"; shift 2 ;;
      --brief-file) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --brief-file requires a value\n' >&2; return 2; }; brief_file="$2"; shift 2 ;;
      --cd) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --cd requires a value\n' >&2; return 2; }; work_dir="$2"; shift 2 ;;
      --host)
        [[ $# -ge 2 ]] || { printf 'pmctl pm run: --host requires a value\n' >&2; return 2; }
        pmctl_host_is_valid "$2" || { printf 'pmctl pm run: --host must be claude, codex, opencode, grok, or generic\n' >&2; return 2; }
        host="$2"
        shift 2 ;;
      --model) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --model requires a value\n' >&2; return 2; }; model="$2"; shift 2 ;;
      --isolation) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --isolation requires a value\n' >&2; return 2; }; isolation="$2"; shift 2 ;;
      --timeout) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --timeout requires a value\n' >&2; return 2; }; timeout="$2"; shift 2 ;;
      --no-auto-pack) no_auto_pack=1; shift ;;
      --json) json=1; shift ;;
      -h|--help) pmctl_pm_usage; return 0 ;;
      *) printf 'pmctl pm run: unknown option: %s\n' "$1" >&2; return 2 ;;
    esac
  done
  [[ -n "$adapter" && -n "$brief_file" && -n "$work_dir" ]] || { printf 'pmctl pm run: --adapter, --brief-file, and --cd are required\n' >&2; return 2; }
  work_dir="$(cd "$work_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'pmctl pm run: --cd must be inside a git worktree\n' >&2; return 2;
  }

  # Re-resolve at the dispatch boundary. Preparation output may be stale or
  # caller-modified; the actual executor brief must carry fresh canonical
  # provenance and an invalid explicit selector must stop before dispatch.
  local goal="" memory_hydrate_rc=0 memory_resolution memory_context memory_context_status memory_provenance
  if declare -F pmctl_dispatch_extract_goal >/dev/null 2>&1; then
    goal="$(pmctl_dispatch_extract_goal "$brief_file" 2>/dev/null || true)"
  fi
  [[ -n "${goal//[[:space:]]/}" ]] || goal="dispatch brief"
  pmctl_pm_hydrate_memory "$work_dir" pm-run "$goal" || memory_hydrate_rc=$?
  memory_resolution="$PMCTL_PM_MEMORY_RESOLUTION"
  memory_context="$PMCTL_PM_MEMORY_CONTEXT"
  memory_context_status="$PMCTL_PM_MEMORY_CONTEXT_STATUS"
  if [[ "$memory_hydrate_rc" -eq 3 ]]; then
    printf 'pmctl pm run: explicit memory configuration is invalid: %s\n' \
      "$(jq -r '.reason // "unknown reason"' <<<"$memory_resolution" 2>/dev/null || printf 'unknown reason')" >&2
    return 1
  fi
  memory_provenance="$(pmctl_pm_memory_provenance "$memory_resolution" "$memory_context_status" "$memory_context" "$host")" || return 1

  pmctl_validate_brief "$repo_root" "$brief_file" >/dev/null || {
    printf 'pmctl pm run: brief validation failed\n' >&2; return 2;
  }

  local effective_brief="$brief_file"
  if [[ "$(jq -r '.resolution_status' <<<"$memory_provenance")" == "resolved" ]]; then
    effective_brief="$(mktemp "${TMPDIR:-/tmp}/brief-pm-memory-XXXXXX.md")" || return 1
    cp "$brief_file" "$effective_brief" || return 1
    {
      printf '\n\ncanonical_memory_provenance:\n'
      printf '  provider: pmctl\n  authority: canonical\n'
      printf '  host: "%s"\n' "$host"
      printf '  project_key: %s\n' "$(jq -r '.project_key | @json' <<<"$memory_provenance")"
      printf '  memory_dir: %s\n' "$(jq -r '.memory_dir | @json' <<<"$memory_provenance")"
      printf '  resolution_source: %s\n' "$(jq -r '.resolution_source | @json' <<<"$memory_provenance")"
      printf '  context_status: %s\n' "$(jq -r '.context_status | @json' <<<"$memory_provenance")"
      printf '  hit_count: %s\n  refs:\n' "$(jq -r '.hit_count' <<<"$memory_provenance")"
      jq -r '.refs[]? | "    - " + (@json)' <<<"$memory_provenance"
      printf '  auxiliary_memory:\n    role: auxiliary\n    status: unknown\n'
    } >> "$effective_brief" || return 1
  fi

  local -a dispatch_args=(--adapter "$adapter" --brief-file "$effective_brief" --cd "$work_dir" --lifecycle detached)
  [[ -n "$model" ]] && dispatch_args+=(--model "$model")
  [[ -n "$isolation" ]] && dispatch_args+=(--isolation "$isolation")
  [[ -n "$timeout" ]] && dispatch_args+=(--timeout "$timeout")
  [[ "$no_auto_pack" -eq 1 ]] && dispatch_args+=(--no-auto-pack)
  local run_id wait_rc=0
  run_id="$(pmctl_dispatch_run "$repo_root" "${dispatch_args[@]}")" || return $?
  [[ "$run_id" =~ ^run-[A-Za-z0-9._-]+$ ]] || { printf 'pmctl pm run: dispatch returned invalid run id: %s\n' "$run_id" >&2; return 1; }
  local -a wait_args=("$run_id" --cd "$work_dir")
  [[ -n "$timeout" ]] && wait_args+=(--timeout "$timeout")
  # In JSON mode the coordinator owns stdout. dispatch wait may print an
  # advisory record, which remains useful for human callers but would make the
  # JSON response unparsable. Keep stderr and the authenticated exit status.
  if [[ "$json" -eq 1 ]]; then
    pmctl_dispatch_wait "$repo_root" "${wait_args[@]}" >/dev/null || wait_rc=$?
  else
    pmctl_dispatch_wait "$repo_root" "${wait_args[@]}" || wait_rc=$?
  fi
  if [[ "$json" -eq 1 ]]; then
    jq -cn --arg run_id "$run_id" --arg work_dir "$work_dir" --arg adapter "$adapter" --arg dispatch_brief "$effective_brief" --argjson memory_provenance "$memory_provenance" --argjson exit_code "$wait_rc" \
      '{schema_version:1,mode:"batch-only",run_id:$run_id,working_dir:$work_dir,adapter:$adapter,dispatch_brief:$dispatch_brief,memory_provenance:$memory_provenance,wait_exit_code:$exit_code}'
  else
    printf 'run_id: %s\nworking_dir: %s\nadapter: %s\ndispatch_brief: %s\nmemory_provider: pmctl\nmemory_project_key: %s\nmemory_resolution_source: %s\nmemory_hit_count: %s\nmemory_refs: %s\nauxiliary_memory_status: unknown\nwait_exit_code: %s\n' \
      "$run_id" "$work_dir" "$adapter" "$effective_brief" \
      "$(jq -r '.project_key' <<<"$memory_provenance")" "$(jq -r '.resolution_source' <<<"$memory_provenance")" \
      "$(jq -r '.hit_count' <<<"$memory_provenance")" "$(jq -c '.refs' <<<"$memory_provenance")" "$wait_rc"
  fi
  return "$wait_rc"
}
