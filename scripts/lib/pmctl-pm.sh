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

pmctl_pm_emit_prepare() {
  local json="$1" work_dir="$2" request="$3" focus="$4" snapshot="$5" snapshot_status="$6"
  if [[ "$json" -eq 1 ]]; then
    jq -cn \
      --arg work_dir "$work_dir" \
      --arg request "$request" \
      --arg focus "$focus" \
      --arg snapshot "$snapshot" \
      --arg snapshot_status "$snapshot_status" \
      '{schema_version:1,mode:"batch-only",working_dir:$work_dir,request:$request,focus_tickets:(if $focus == "" then [] else $focus | split(",") end),snapshot_file:(if $snapshot == "" then null else $snapshot end),snapshot_status:$snapshot_status,handover_required:true,ambiguity_policy:"reject-and-return-to-host"}'
  else
    printf 'mode: batch-only\nworking_dir: %s\n' "$work_dir"
    [[ -n "$focus" ]] && printf 'focus_tickets: %s\n' "$focus"
    printf 'snapshot_status: %s\n' "$snapshot_status"
    [[ -n "$snapshot" ]] && printf 'snapshot_file: %s\n' "$snapshot"
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
  pmctl_pm_emit_prepare "$json" "$work_dir" "$request" "$focus" "$snapshot" "$snapshot_status"
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
