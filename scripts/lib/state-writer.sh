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

_sw_json_line_has_nul() {
  command -v perl >/dev/null 2>&1 || return 1
  printf '%s' "${1:-}" | perl -0777 -ne 'exit(index($_, "\0") >= 0 ? 0 : 1)'
}

_sw_compact_json_line() {
  local json_line="${1:-}" compact
  if [[ "$json_line" == *$'\n'* ]]; then
    printf 'state-writer: refusing JSONL append with embedded newline\n' >&2
    return 1
  fi
  if _sw_json_line_has_nul "$json_line"; then
    printf 'state-writer: refusing JSONL append with embedded NUL\n' >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'state-writer: jq is required to compact JSONL appends\n' >&2
    return 1
  fi
  if ! compact="$(printf '%s' "$json_line" | jq -c .)"; then
    printf 'state-writer: refusing malformed JSONL append\n' >&2
    return 1
  fi
  printf '%s\n' "$compact"
}

_sw_validate_compacted_json_line() {
  local entity="${1:-}" compact="${2:-}" schema_file tmp rc=0
  schema_file="$SCRIPT_DIR_SW/../../core/schema/${entity}.schema.json"
  if ! command -v jsonschema >/dev/null 2>&1; then
    printf 'state-writer: warning: jsonschema not available; skipping %s schema validation\n' "$entity" >&2
    return 0
  fi
  if [[ ! -f "$schema_file" ]]; then
    printf 'state-writer: schema not found for %s: %s\n' "$entity" "$schema_file" >&2
    return 1
  fi
  tmp="$(mktemp)" || return 1
  printf '%s\n' "$compact" > "$tmp" || { rm -f "$tmp"; return 1; }
  jsonschema -i "$tmp" "$schema_file" >/dev/null || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    printf 'state-writer: %s schema validation failed\n' "$entity" >&2
  fi
  rm -f "$tmp"
  return "$rc"
}

state_store_init() {
  local store_root proj_dir version_file version_value
  store_root="$(_sw_store_root)"
  version_file="$store_root/VERSION"
  # Version compatibility check before any layout creation — unsupported stores
  # must be observed but not mutated.
  if [[ -f "$version_file" ]]; then
    version_value="$(<"$version_file")"
    if [[ "$version_value" != "1" ]]; then
      printf 'state-writer: unsupported store version %s (expected 1); run '\''pmctl state migrate'\''\n' "$version_value" >&2
      return 1
    fi
  fi
  # Only reach here on first-time init (VERSION absent) or VERSION == "1".
  proj_dir="$(_sw_project_dir)"
  { mkdir -p "$proj_dir/tasks" "$proj_dir/reviews" "$proj_dir/decisions" \
      "$proj_dir/context-packs" "$proj_dir/archive"; } 2>/dev/null || true
  if [[ ! -f "$version_file" ]]; then
    mkdir -p "$store_root" || { printf 'state-writer: mkdir failed: %s\n' "$store_root" >&2; return 1; }
    printf '1\n' > "$version_file" || { printf 'state-writer: VERSION write failed: %s\n' "$version_file" >&2; return 1; }
  fi
  return 0
}

_runs_append_inner() {
  local json_line="$1" compact
  compact="$(_sw_compact_json_line "$json_line")" || return $?
  _sw_validate_compacted_json_line run "$compact" || return $?
  printf '%s\n' "$compact" >> runs.jsonl
}

runs_append() {
  local json_line="${1:-}" proj_dir rc=0
  state_store_init || return $?
  proj_dir="$(_sw_project_dir)"
  ( cd "$proj_dir" && serialize_with_lock "$proj_dir/runs" _runs_append_inner "$json_line" ) || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    _sw_log_error "runs_append failed: $proj_dir/runs.jsonl"
    return "$rc"
  fi
  return 0
}

_events_append_inner() {
  local json_line="$1" compact
  compact="$(_sw_compact_json_line "$json_line")" || return $?
  _sw_validate_compacted_json_line event "$compact" || return $?
  printf '%s\n' "$compact" >> events.jsonl
}

events_append() {
  local json_line="${1:-}" proj_dir rc=0
  state_store_init || return $?
  proj_dir="$(_sw_project_dir)"
  ( cd "$proj_dir" && serialize_with_lock "$proj_dir/events" _events_append_inner "$json_line" ) || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    _sw_log_error "events_append failed: $proj_dir/events.jsonl"
    return "$rc"
  fi
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

# Build a dispatch Run row. Does not append.
# Usage: sw_build_run_json <executor> <exit_code> <state> <model> \
#            <brief_file> <work_dir> <trace_path> [brief_inline] [operation_id]
sw_build_run_json() {
  local _executor="${1:-}" _exit_code="${2:-1}" _state="${3:-}"
  local _model="${4:-}" _brief_file="${5:-}" _work_dir="${6:-}" _trace_path="${7:-}"
  local _brief_inline="${8:-}" _operation_id="${9:-}"
  local _task_id _ts _hex _run_id

  [[ "$_exit_code" =~ ^-?[0-9]+$ ]] || return 1
  [[ -n "$_state" ]] || return 1
  _task_id="$(sw_extract_task_id "$_brief_file" "$_brief_inline")"
  _ts="${_SW_CREATED_TS_OVERRIDE:-$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)}"
  if [[ -n "${_SW_RUN_ID_OVERRIDE:-}" ]]; then
    _run_id="$_SW_RUN_ID_OVERRIDE"
  else
    _hex="$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    _run_id="run-$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)-${_hex:0:6}"
  fi
  jq -cn \
    --arg id "$_run_id" \
    --arg task_id "$_task_id" \
    --arg executor "$_executor" \
    --arg state "$_state" \
    --argjson exit_code "$_exit_code" \
    --arg model "$_model" \
    --arg brief_file "$_brief_file" \
    --arg working_dir "$_work_dir" \
    --arg trace_path "$_trace_path" \
    --arg operation_id "$_operation_id" \
    --arg created_ts "$_ts" \
    '{schema_version:1,id:$id,task_id:$task_id,executor:$executor,state:$state,exit_code:$exit_code,model:$model,brief_file:$brief_file,working_dir:$working_dir,trace_path:$trace_path,created_ts:$created_ts} + (if $operation_id == "" then {} else {operation_id:$operation_id} end)'
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
