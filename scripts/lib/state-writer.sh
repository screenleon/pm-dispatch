#!/usr/bin/env bash
# Best-effort state-store writer for pm-dispatch.

SCRIPT_DIR_SW="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/portable.sh
if [[ "$(type -t serialize_with_lock 2>/dev/null)" != function || "$(type -t _portable_sha1 2>/dev/null)" != function || "$(type -t file_size_bytes 2>/dev/null)" != function ]]; then
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

# Rotation is best-effort maintenance, not a canonical state write: it must
# never fail the Run/Event append (a missing `gzip` binary must not break the
# substrate). So when rotation cannot proceed we keep the write succeeding, but
# the degradation is surfaced LOUDLY (stderr + state-writer.err), never silent,
# so operators see that bounded growth has stopped. The canonical append still
# fails loudly on its own errors; only rotation is best-effort.
_sw_rotate_warn() {
  printf 'state-writer: %s\n' "${1:-}" >&2
  _sw_log_error "${1:-}"
}

_sw_rotate_max_bytes() {
  local raw="${PM_DISPATCH_ROTATE_MAX_BYTES:-}" default=52428800
  if [[ "$raw" =~ ^[0-9]+$ ]] && (( 10#$raw > 0 )); then
    printf '%s\n' "$((10#$raw))"
  else
    printf '%s\n' "$default"
  fi
}

_sw_next_archive_path() {
  local entity="$1" period max=0 path base segment n
  period="$(date -u +%Y%m 2>/dev/null || date +%Y%m)"
  # Consider published segments AND pending .staging files, so a crashed stage
  # reserves its segment number and a fresh rotation never reuses it.
  for path in "archive/${entity}-${period}-"*.jsonl.gz "archive/${entity}-${period}-"*.jsonl.gz.staging; do
    [[ -e "$path" ]] || continue
    base="${path##*/}"
    segment="${base#"${entity}-${period}-"}"
    segment="${segment%.staging}"
    segment="${segment%.jsonl.gz}"
    if [[ "$segment" =~ ^[0-9]{4}$ ]]; then
      n=$((10#$segment))
      (( n > max )) && max="$n"
    fi
  done
  printf 'archive/%s-%s-%04d.jsonl.gz\n' "$entity" "$period" "$((max + 1))"
}

_sw_clean_stale_archive_tmp() {
  local entity="$1" tmp
  for tmp in "archive/${entity}-"*.jsonl.gz.tmp; do
    [[ -e "$tmp" ]] || continue
    rm -f -- "$tmp" 2>/dev/null || _sw_rotate_warn "state rotation: failed to remove stale tmp: $tmp"
  done
  return 0
}

_sw_has_staged_segments() {
  local entity="$1" staging
  for staging in "archive/${entity}-"*.jsonl.gz.staging; do
    [[ -e "$staging" ]] && return 0
  done
  return 1
}

# Publish one destination-named staging file to its final .gz segment.
# IDEMPOTENT: the staging name encodes its destination, so if that segment is
# already published (a crash or `rm` failure after a prior publish left the
# stage behind), the staged copy is dropped instead of re-archived — no
# duplicate rows. Returns 0 on success or already-published; returns 1 only when
# publish failed before the segment was created (the stage is kept for retry).
_sw_publish_staged_segment() {
  local staging="$1" dest tmp_path
  [[ -f "$staging" ]] || return 0
  dest="${staging%.staging}"
  if [[ -f "$dest" ]]; then
    rm -f -- "$staging" 2>/dev/null \
      || _sw_rotate_warn "state rotation: failed to drop already-published stage: $staging"
    return 0
  fi
  tmp_path="${dest}.tmp"
  rm -f -- "$tmp_path" 2>/dev/null || true
  if ! gzip -c "$staging" > "$tmp_path" 2>/dev/null; then
    _sw_rotate_warn "state rotation: gzip failed for $staging"
    rm -f -- "$tmp_path" 2>/dev/null || true
    return 1
  fi
  if ! mv -f -- "$tmp_path" "$dest" 2>/dev/null; then
    _sw_rotate_warn "state rotation: archive publish failed: $dest"
    rm -f -- "$tmp_path" 2>/dev/null || true
    return 1
  fi
  rm -f -- "$staging" 2>/dev/null \
    || _sw_rotate_warn "state rotation: failed to remove staged file after publish: $staging"
  return 0
}

# Recover any crashed staging files idempotently. Returns 1 if any could not be
# published, so the caller skips starting a fresh rotation (avoids reusing a
# segment number still owned by an unpublished stage).
_sw_recover_staged_segments() {
  local entity="$1" staging rc=0
  for staging in "archive/${entity}-"*.jsonl.gz.staging; do
    [[ -e "$staging" ]] || continue
    _sw_publish_staged_segment "$staging" || rc=1
  done
  return "$rc"
}

_sw_rotate_entity_if_needed() {
  local entity="$1" active staging dest
  local threshold size
  active="${entity}.jsonl"

  threshold="$(_sw_rotate_max_bytes)"

  # gzip gate: rotation and recovery both need gzip. Degrade loudly, never fail
  # the append. A pending stage or an over-threshold active means growth is no
  # longer bounded until gzip returns.
  if ! command -v gzip >/dev/null 2>&1; then
    if _sw_has_staged_segments "$entity"; then
      _sw_rotate_warn "state rotation: gzip unavailable; cannot recover staged ${entity} segment(s)"
    elif [[ -f "$active" ]] \
        && size="$(file_size_bytes "$active" 2>/dev/null)" \
        && [[ "$size" =~ ^[0-9]+$ ]] && (( size >= threshold )); then
      _sw_rotate_warn "state rotation: gzip unavailable; skipping $active rotation"
    fi
    return 0
  fi

  _sw_clean_stale_archive_tmp "$entity"
  # Recover crashed stages FIRST (idempotent). If any cannot publish, do not
  # start a new rotation this round.
  _sw_recover_staged_segments "$entity" || return 0

  [[ -f "$active" ]] || return 0
  size="$(file_size_bytes "$active" 2>/dev/null)" || {
    _sw_rotate_warn "state rotation: failed to read size for $active"
    return 0
  }
  [[ "$size" =~ ^[0-9]+$ ]] || return 0
  (( size >= threshold )) || return 0

  dest="$(_sw_next_archive_path "$entity")"
  staging="${dest}.staging"
  # Stage active to a destination-named file (atomic). The name pins the target
  # segment, so a crash before publish is recovered to the SAME segment.
  if ! mv -f -- "$active" "$staging" 2>/dev/null; then
    _sw_rotate_warn "state rotation: failed to stage $active"
    return 0
  fi
  if ! : > "$active"; then
    _sw_rotate_warn "state rotation: failed to recreate $active"
    mv -f -- "$staging" "$active" 2>/dev/null \
      || _sw_rotate_warn "state rotation: rollback failed for $active"
    return 0
  fi
  # Publish now. On a pre-publish failure (gzip/mv) the segment was NOT created,
  # so restore the staged rows to the empty active file for visibility instead
  # of leaving them staged. Post-publish, recovery is idempotent (above).
  if ! _sw_publish_staged_segment "$staging"; then
    if [[ ! -f "$dest" && -f "$staging" && ! -s "$active" ]]; then
      rm -f -- "$active" 2>/dev/null || true
      mv -f -- "$staging" "$active" 2>/dev/null \
        || _sw_rotate_warn "state rotation: restore failed for $active"
    fi
  fi
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

# run_transition_valid from_state to_state
# Returns 0 if the transition is allowed by the Run FSM, 1 otherwise.
# This is the canonical policy source; pmctl-dispatch.sh delegates here.
run_transition_valid() {
  local from_state="${1:-}" to_state="${2:-}"
  case "$from_state" in
    ""|none)
      [[ "$to_state" == "pending" ]] && return 0 ;;
    pending)
      [[ "$to_state" == "dispatched" || "$to_state" == "failed" ]] && return 0 ;;
    dispatched)
      [[ "$to_state" == "verifying" || "$to_state" == "failed" ]] && return 0 ;;
    verifying)
      [[ "$to_state" == "ok" || "$to_state" == "partial" || "$to_state" == "failed" ]] && return 0 ;;
  esac
  return 1
}

_sw_write_repo_json() {
  local proj_dir="$1" repo_path repo_name git_common_dir cygpath_alias tmp ts
  if [[ -n "${_SW_REPO_ROOT:-}" ]]; then
    repo_path="$(git -C "${_SW_REPO_ROOT}" rev-parse --show-toplevel 2>/dev/null \
      || printf '%s' "${_SW_REPO_ROOT}")"
  else
    repo_path="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  [[ -z "$repo_path" ]] && return 0
  repo_name="$(basename "$repo_path")"
  git_common_dir="$(git -C "$repo_path" rev-parse --git-common-dir 2>/dev/null || true)"
  if [[ -n "$git_common_dir" && "$git_common_dir" != /* ]]; then
    git_common_dir="$repo_path/$git_common_dir"
  fi
  cygpath_alias=""
  if command -v cygpath >/dev/null 2>&1; then
    cygpath_alias="$(cygpath -m "$repo_path" 2>/dev/null || true)"
  fi
  ts="${_SW_CREATED_TS_OVERRIDE:-$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)}"
  tmp="$(mktemp "$proj_dir/.repo-XXXXXX.json")" || {
    _sw_log_error "_sw_write_repo_json: mktemp failed: $proj_dir"
    return 0
  }
  if jq -cn \
    --arg repo_path "$repo_path" \
    --arg repo_name "$repo_name" \
    --arg git_common_dir "$git_common_dir" \
    --arg cygpath_alias "$cygpath_alias" \
    --arg first_seen_ts "$ts" \
    '{repo_path:$repo_path,repo_name:$repo_name,git_common_dir:$git_common_dir,first_seen_ts:$first_seen_ts}
     | if $git_common_dir == "" then del(.git_common_dir) else . end
     | if $cygpath_alias != "" then . + {cygpath_alias:$cygpath_alias} else . end' \
    > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$proj_dir/repo.json" 2>/dev/null || {
      _sw_log_error "_sw_write_repo_json: mv failed: $proj_dir/repo.json"
      rm -f "$tmp"
    }
  else
    _sw_log_error "_sw_write_repo_json: jq failed for $proj_dir"
    rm -f "$tmp"
  fi
  return 0
}

# state_project_identity_write
# Public entry point: write (or refresh) repo.json for the current project partition.
# Best-effort — always returns 0. Callers that need to inspect or refresh the
# partition identity (e.g. after a worktree move) can call this directly without
# going through state_store_init.
state_project_identity_write() {
  local proj_dir
  proj_dir="$(_sw_project_dir)" || return 0
  _sw_write_repo_json "$proj_dir"
  return 0
}

state_store_init() {
  local store_root proj_dir version_file version_value proj_key
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
  # CC-313: refuse the global partition for load-bearing writes unless explicitly allowed.
  proj_key="$(_sw_project_key)"
  if [[ "$proj_key" == "global" && -z "${_SW_ALLOW_GLOBAL_PARTITION:-}" ]]; then
    printf 'state-writer: cannot determine project partition (not in a git repo or hash unavailable)\n' >&2
    return 1
  fi
  proj_dir="$store_root/projects/$proj_key/"
  # CC-330: fail loud on layout mkdir failure to match the VERSION-gate fail-loud semantics.
  if ! mkdir -p "$proj_dir/tasks" "$proj_dir/reviews" "$proj_dir/decisions" \
      "$proj_dir/context-packs" "$proj_dir/archive" 2>/dev/null; then
    printf 'state-writer: layout mkdir failed: %s\n' "$proj_dir" >&2
    return 1
  fi
  # CC-313: write repo.json on first use for partition identity (best-effort).
  if [[ ! -f "$proj_dir/repo.json" ]]; then
    _sw_write_repo_json "$proj_dir"
  fi
  if [[ ! -f "$version_file" ]]; then
    mkdir -p "$store_root" || { printf 'state-writer: mkdir failed: %s\n' "$store_root" >&2; return 1; }
    printf '1\n' > "$version_file" || { printf 'state-writer: VERSION write failed: %s\n' "$version_file" >&2; return 1; }
  fi
  return 0
}

_runs_append_inner() {
  local json_line="$1" compact
  _sw_rotate_entity_if_needed runs
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
  _sw_rotate_entity_if_needed events
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
  local task_id="${1:-}" json_line="${2:-}" proj_dir tmp=""
  if [[ ! "${task_id}" =~ ^[A-Z]{1,4}-[0-9]+[a-z]?$ ]]; then
    _sw_log_error "task_upsert: invalid task_id='${task_id}'"
    return 0
  fi
  state_store_init || return 1
  {
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
