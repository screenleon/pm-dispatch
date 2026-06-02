#!/usr/bin/env bash
# Best-effort state-store writer for pm-dispatch.

SCRIPT_DIR_SW="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/portable.sh
if [[ "$(type -t serialize_with_lock 2>/dev/null)" != function || "$(type -t _portable_sha1 2>/dev/null)" != function ]]; then
  _SW_SHELL_FLAGS="$-"
  _SW_PIPEFAIL=0
  set -o | grep -qE '^pipefail[[:space:]]+on$' && _SW_PIPEFAIL=1
  . "$SCRIPT_DIR_SW/portable.sh" 2>/dev/null || true
  case "$_SW_SHELL_FLAGS" in *e*) set -e ;; *) set +e ;; esac
  case "$_SW_SHELL_FLAGS" in *u*) set -u ;; *) set +u ;; esac
  case "$_SW_SHELL_FLAGS" in *x*) set -x ;; *) set +x ;; esac
  if [[ "$_SW_PIPEFAIL" -eq 1 ]]; then
    set -o pipefail
  else
    set +o pipefail
  fi
  unset _SW_SHELL_FLAGS _SW_PIPEFAIL
fi

_sw_log_error() {
  {
    local log_dir="${HOME:-}/.claude/logs"
    [[ -n "$log_dir" ]] || return 0
    mkdir -p "$log_dir"
    printf '[%s] %s\n' "$(date -Is 2>/dev/null || date)" "$*" >> "$log_dir/state-writer.err"
  } 2>/dev/null || true
  return 0
}

_sw_store_root() {
  {
    if [[ -n "${PM_DISPATCH_STATE_ROOT:-}" ]]; then
      printf '%s\n' "$PM_DISPATCH_STATE_ROOT"
    elif [[ -n "${XDG_DATA_HOME:-}" ]]; then
      printf '%s\n' "$XDG_DATA_HOME/pm-dispatch/state"
    else
      printf '%s\n' "${HOME:-}/.local/share/pm-dispatch/state"
    fi
  } 2>/dev/null || true
  return 0
}

_sw_project_key() {
  {
    local repo_root project_key
    if [[ -n "${_SW_REPO_ROOT:-}" ]]; then
      # Resolve to git top-level so subdirectory dispatches hash the same key.
      repo_root="$(git -C "${_SW_REPO_ROOT}" rev-parse --show-toplevel 2>/dev/null \
        || printf '%s\n' "${_SW_REPO_ROOT}")"
    elif repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$repo_root" ]]; then
      :
    else
      printf 'global\n'
      return 0
    fi
    if ! project_key="$(printf '%s\n' "$repo_root" | _portable_sha1 2>/dev/null)"; then
      _sw_log_error "_sw_project_key: failed to hash repo root; falling back to global: $repo_root"
      project_key=""
    fi
    if [[ -n "$project_key" ]]; then
      printf '%s\n' "$project_key"
    else
      printf 'global\n'
    fi
  } 2>/dev/null || true
  return 0
}

_sw_project_dir() {
  {
    printf '%s/projects/%s/\n' "$(_sw_store_root)" "$(_sw_project_key)"
  } 2>/dev/null || true
  return 0
}

state_store_init() {
  {
    local store_root proj_dir version_file version_value
    store_root="$(_sw_store_root)"
    proj_dir="$(_sw_project_dir)"
    mkdir -p "$proj_dir/tasks" "$proj_dir/reviews" "$proj_dir/decisions" \
      "$proj_dir/context-packs" "$proj_dir/archive" || _sw_log_error "mkdir failed: $proj_dir"
    version_file="$store_root/VERSION"
    version_value=""
    [[ -f "$version_file" ]] && version_value="$(<"$version_file")"
    if [[ "$version_value" != "1" ]]; then
      mkdir -p "$store_root" || _sw_log_error "mkdir failed: $store_root"
      printf '1\n' > "$version_file" || _sw_log_error "VERSION write failed: $version_file"
    fi
  } 2>/dev/null || true
  return 0
}

_runs_append_inner() {
  {
    local json_line="$1"
    printf '%s\n' "$json_line" >> runs.jsonl
  } 2>/dev/null || true
  return 0
}

runs_append() {
  {
    local json_line="${1:-}" proj_dir
    state_store_init
    proj_dir="$(_sw_project_dir)"
    ( cd "$proj_dir" && serialize_with_lock "$proj_dir/runs" _runs_append_inner "$json_line" ) || \
      _sw_log_error "runs_append failed: $proj_dir/runs.jsonl"
  } 2>/dev/null || true
  return 0
}

_events_append_inner() {
  {
    local json_line="$1"
    printf '%s\n' "$json_line" >> events.jsonl
  } 2>/dev/null || true
  return 0
}

events_append() {
  {
    local json_line="${1:-}" proj_dir
    state_store_init
    proj_dir="$(_sw_project_dir)"
    ( cd "$proj_dir" && serialize_with_lock "$proj_dir/events" _events_append_inner "$json_line" ) || \
      _sw_log_error "events_append failed: $proj_dir/events.jsonl"
  } 2>/dev/null || true
  return 0
}

# Extract the task_id field from a brief file (path) and/or inline brief text.
# Outputs the ID (e.g. CC-123) or the sentinel "UNKN-0" when none is found.
sw_extract_task_id() {
  {
    local _brief_file="${1:-}" _brief_inline="${2:-}"
    local _task_id="UNKN-0" _tid=""
    if [[ -n "$_brief_file" && -f "$_brief_file" ]]; then
      _tid="$(grep -oE '^task_id:[[:space:]]*[A-Z]{1,4}-[0-9]+[a-z]?' \
        "$_brief_file" 2>/dev/null | head -1 | \
        sed 's/task_id:[[:space:]]*//' 2>/dev/null || true)"
      [[ -n "$_tid" ]] && _task_id="$_tid"
    fi
    if [[ "$_task_id" == "UNKN-0" && -n "$_brief_inline" ]]; then
      _tid="$(printf '%s' "$_brief_inline" | \
        grep -oE '^task_id:[[:space:]]*[A-Z]{1,4}-[0-9]+[a-z]?' \
        2>/dev/null | head -1 | \
        sed 's/task_id:[[:space:]]*//' 2>/dev/null || true)"
      [[ -n "$_tid" ]] && _task_id="$_tid"
    fi
    printf '%s\n' "$_task_id"
  } 2>/dev/null || printf 'UNKN-0\n'
}

# Append a dispatch Run row to the state store. Best-effort — never fatal.
# Usage: sw_append_dispatch_run <executor> <exit_code> <model> \
#            <brief_file> <work_dir> <trace_path> [brief_inline]
sw_append_dispatch_run() {
  {
    local _executor="${1:-}" _exit_code="${2:-1}" _model="${3:-}"
    local _brief_file="${4:-}" _work_dir="${5:-}" _trace_path="${6:-}"
    local _brief_inline="${7:-}"
    local _task_id _state _ts _hex _run_id _run_json

    _task_id="$(sw_extract_task_id "$_brief_file" "$_brief_inline")"
    _state="failed"; [[ "$_exit_code" -eq 0 ]] && _state="ok"
    _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
    _hex="$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    _run_id="run-$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)-${_hex:0:6}"
    _SW_REPO_ROOT="$_work_dir"
    _run_json="$(jq -cn \
      --arg id "$_run_id" \
      --arg task_id "$_task_id" \
      --arg executor "$_executor" \
      --arg state "$_state" \
      --argjson exit_code "$_exit_code" \
      --arg model "$_model" \
      --arg brief_file "$_brief_file" \
      --arg working_dir "$_work_dir" \
      --arg trace_path "$_trace_path" \
      --arg created_ts "$_ts" \
      '{schema_version:1,id:$id,task_id:$task_id,executor:$executor,state:$state,exit_code:$exit_code,model:$model,brief_file:$brief_file,working_dir:$working_dir,trace_path:$trace_path,created_ts:$created_ts}' \
      2>/dev/null || true)"
    if [[ -z "$_run_json" ]]; then
      _sw_log_error "sw_append_dispatch_run: jq JSON construction failed (executor=${_executor} task_id=${_task_id} exit=${_exit_code})"
      return 0
    fi
    runs_append "$_run_json"
  } 2>/dev/null || true
  return 0
}

task_upsert() {
  {
    local task_id="${1:-}" json_line="${2:-}" proj_dir tmp=""
    if [[ ! "${task_id}" =~ ^[A-Z]{1,4}-[0-9]+[a-z]?$ ]]; then
      _sw_log_error "task_upsert: invalid task_id='${task_id}'"
      return 0
    fi
    state_store_init
    proj_dir="$(_sw_project_dir)"
    tmp="$(mktemp "$proj_dir/tasks/.tmp-XXXXXX")" || {
      _sw_log_error "task_upsert mktemp failed: $proj_dir/tasks"
      return 0
    }
    printf '%s\n' "$json_line" > "$tmp" || {
      _sw_log_error "task_upsert temp write failed: $tmp"
      rm -f "$tmp"
      return 0
    }
    mv -f "$tmp" "$proj_dir/tasks/${task_id}.json" || {
      _sw_log_error "task_upsert rename failed: $proj_dir/tasks/${task_id}.json"
      rm -f "$tmp"
      return 0
    }
  } 2>/dev/null || true
  return 0
}
