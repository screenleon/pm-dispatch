#!/usr/bin/env bash
# Batch-only PM coordinator for non-Claude hosts.
#
# It deliberately does not classify an open-ended request or manufacture a
# dispatch brief. A host/LLM supplies the reasoning and a complete brief; this
# command owns the repeatable shell steps around it: snapshot, validation,
# detached dispatch, and authenticated wait.

pmctl_pm_usage() {
  cat >&2 <<'EOF'
usage: pmctl pm prepare --request <text> [--cd <work_dir>] [--focus <CC-N,...>] [--json]
       pmctl pm run --adapter <name> --brief-file <path> --cd <work_dir> [--model <model>] [--isolation <level>] [--timeout <seconds>] [--no-auto-pack] [--json]

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

pmctl_pm_emit_prepare() {
  local json="$1" work_dir="$2" request="$3" focus="$4" snapshot="$5" snapshot_status="$6"
  local memory_resolution="$7" memory_context_status="$8" memory_context="$9"
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
      '{schema_version:1,mode:"batch-only",working_dir:$work_dir,request:$request,focus_tickets:(if $focus == "" then [] else $focus | split(",") end),snapshot_file:(if $snapshot == "" then null else $snapshot end),snapshot_status:$snapshot_status,memory_resolution:$memory_resolution,memory_context_status:$memory_context_status,memory_context:(if $memory_context == "" then null else $memory_context end),handover_required:true,ambiguity_policy:"reject-and-return-to-host"}'
  else
    printf 'mode: batch-only\nworking_dir: %s\n' "$work_dir"
    [[ -n "$focus" ]] && printf 'focus_tickets: %s\n' "$focus"
    printf 'snapshot_status: %s\n' "$snapshot_status"
    [[ -n "$snapshot" ]] && printf 'snapshot_file: %s\n' "$snapshot"
    printf 'memory_status: %s\n' "$memory_context_status"
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
  local request="" work_dir="" focus="" json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --request) [[ $# -ge 2 ]] || { printf 'pmctl pm prepare: --request requires a value\n' >&2; return 2; }; request="$2"; shift 2 ;;
      --cd) [[ $# -ge 2 ]] || { printf 'pmctl pm prepare: --cd requires a value\n' >&2; return 2; }; work_dir="$2"; shift 2 ;;
      --focus) [[ $# -ge 2 ]] || { printf 'pmctl pm prepare: --focus requires a value\n' >&2; return 2; }; focus="$2"; shift 2 ;;
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

  local snapshot="" snapshot_status="unavailable" snapshot_err snapshot_rc=0
  snapshot_err="$(mktemp "${TMPDIR:-/tmp}/pmctl-pm-snapshot.XXXXXX")" || return 1
  if [[ -n "$focus" ]]; then
    snapshot="$(cd "$work_dir" && bash "$repo_root/scripts/pm-prep-snapshot.sh" --focus "$focus" 2>"$snapshot_err")" || snapshot_rc=$?
  else
    snapshot="$(cd "$work_dir" && bash "$repo_root/scripts/pm-prep-snapshot.sh" 2>"$snapshot_err")" || snapshot_rc=$?
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

  # Host-neutral memory hydration. The strict resolver prevents an explicitly
  # selected memory path from silently falling back to Claude's legacy path.
  local memory_resolution memory_rc=0 memory_context="" memory_context_status="unavailable" query_rc=0
  memory_resolution='{"schema_version":1,"status":"unavailable","repo_root":"","project_key":"","memory_dir":null,"resolution_source":"none","readable":false,"writable":false,"reason":null}'
  if declare -F pmctl_memory_resolve >/dev/null 2>&1; then
    memory_resolution="$(pmctl_memory_resolve --repo-root "$work_dir" --json)" || memory_rc=$?
    if [[ "$memory_rc" -eq 3 ]]; then
      printf 'pmctl pm prepare: explicit memory configuration is invalid: %s\n' \
        "$(jq -r '.reason // "unknown reason"' <<<"$memory_resolution" 2>/dev/null || printf 'unknown reason')" >&2
      [[ -n "$snapshot" && -f "$snapshot" ]] && rm -f "$snapshot"
      return 1
    elif [[ "$memory_rc" -eq 0 ]]; then
      memory_context_status="no-hits"
      if declare -F pmctl_context_pack >/dev/null 2>&1; then
        local -a memory_terms=() memory_pack_args=("$work_dir" --task-id pm-prepare --source memory)
        local memory_term
        if declare -F _ctx_extract_terms >/dev/null 2>&1; then
          while IFS= read -r memory_term; do
            [[ -n "$memory_term" ]] && memory_terms+=("$memory_term")
            [[ "${#memory_terms[@]}" -ge 8 ]] && break
          done < <(_ctx_extract_terms "$request")
        fi
        # Empty extraction (currently CJK-only text, short English, or
        # stopword-only requests; CC-465 covers CJK) falls back to the whole
        # request so LIKE/FTS can still find exact substrings.
        [[ "${#memory_terms[@]}" -gt 0 ]] || memory_terms+=("$request")
        for memory_term in "${memory_terms[@]}"; do
          memory_pack_args+=(--query "$memory_term")
        done
        memory_context="$(pmctl_context_pack "${memory_pack_args[@]}")" || query_rc=$?
        if [[ "$query_rc" -ne 0 ]]; then
          memory_context=""
          memory_context_status="query-failed"
        elif ! jq -e '.memories | length > 0' <<<"$memory_context" >/dev/null 2>&1; then
          memory_context=""
        else
          # Preparation is bounded but remains a valid context-pack document.
          if memory_context="$(pmctl_pm_bound_memory_pack "$memory_context" 6000)"; then
            memory_context_status="hydrated"
          else
            memory_context=""
            memory_context_status="query-failed"
          fi
        fi
      fi
    fi
  fi
  pmctl_pm_emit_prepare "$json" "$work_dir" "$request" "$focus" "$snapshot" "$snapshot_status" \
    "$memory_resolution" "$memory_context_status" "$memory_context"
}

pmctl_pm_run() {
  local repo_root="$1"; shift
  local adapter="" brief_file="" work_dir="" model="" isolation="" timeout="" no_auto_pack=0 json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --adapter) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --adapter requires a value\n' >&2; return 2; }; adapter="$2"; shift 2 ;;
      --brief-file) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --brief-file requires a value\n' >&2; return 2; }; brief_file="$2"; shift 2 ;;
      --cd) [[ $# -ge 2 ]] || { printf 'pmctl pm run: --cd requires a value\n' >&2; return 2; }; work_dir="$2"; shift 2 ;;
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
  pmctl_validate_brief "$repo_root" "$brief_file" >/dev/null || {
    printf 'pmctl pm run: brief validation failed\n' >&2; return 2;
  }

  local -a dispatch_args=(--adapter "$adapter" --brief-file "$brief_file" --cd "$work_dir" --lifecycle detached)
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
    jq -cn --arg run_id "$run_id" --arg work_dir "$work_dir" --arg adapter "$adapter" --argjson exit_code "$wait_rc" \
      '{schema_version:1,mode:"batch-only",run_id:$run_id,working_dir:$work_dir,adapter:$adapter,wait_exit_code:$exit_code}'
  else
    printf 'run_id: %s\nworking_dir: %s\nadapter: %s\nwait_exit_code: %s\n' "$run_id" "$work_dir" "$adapter" "$wait_rc"
  fi
  return "$wait_rc"
}
