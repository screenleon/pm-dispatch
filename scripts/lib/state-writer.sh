#!/usr/bin/env bash
# Best-effort state-store writer for pm-dispatch.

SCRIPT_DIR_SW="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/portable.sh
if [[ "$(type -t serialize_with_lock 2>/dev/null)" != function ]]; then
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
      repo_root="${_SW_REPO_ROOT}"
    elif repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$repo_root" ]]; then
      :
    else
      printf 'global\n'
      return 0
    fi
    project_key="$(printf '%s\n' "$repo_root" | sha1sum 2>/dev/null | cut -c1-40 2>/dev/null || true)"
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
