#!/usr/bin/env bash

pmctl_trace_usage() {
  printf 'usage: pmctl trace tail [--kind <K>] [--task <ID>|--subject <ID>] [--id <EVTID>] [--since <TS>] [--until <TS>] [-n <N>|--limit <N>] [--all] [--json]\n' >&2
}

pmctl_trace_ensure_state_writer() {
  local repo_root="${1:-}"

  if declare -F _sw_project_dir >/dev/null 2>&1; then
    return 0
  fi
  if [[ -z "$repo_root" || ! -r "$repo_root/runtime/lib/state-writer.sh" ]]; then
    printf 'pmctl trace tail: state writer unavailable\n' >&2
    return 2
  fi
  # shellcheck disable=SC1091  # dynamic repo root path.
  . "$repo_root/runtime/lib/state-writer.sh"
}

pmctl_trace_scan_line() {
  local line="${1:-}" compact fields
  local event_id ts kind subject_id

  if ! compact="$(printf '%s\n' "$line" | jq -c 'if type == "object" then . else error("not object") end' 2>/dev/null)"; then
    _PMCTL_TRACE_SKIPPED=$((_PMCTL_TRACE_SKIPPED + 1))
    return 0
  fi

  # Only the fields used for filtering are extracted into shell vars; the
  # emitters re-read subject_type / actor / operation_id from the JSON itself.
  if ! fields="$(printf '%s\n' "$compact" | jq -r '[.id // "", .ts // "", .kind // "", .subject_id // ""] | @tsv' 2>/dev/null)"; then
    _PMCTL_TRACE_SKIPPED=$((_PMCTL_TRACE_SKIPPED + 1))
    return 0
  fi
  IFS=$'\t' read -r event_id ts kind subject_id <<< "$fields"

  if [[ -n "${_PMCTL_TRACE_ID_FILTER:-}" && "$event_id" != "$_PMCTL_TRACE_ID_FILTER" ]]; then
    return 0
  fi
  if [[ -n "${_PMCTL_TRACE_KIND_FILTER:-}" && "$kind" != "$_PMCTL_TRACE_KIND_FILTER" ]]; then
    return 0
  fi
  if [[ -n "${_PMCTL_TRACE_SUBJECT_FILTER:-}" && "$subject_id" != "$_PMCTL_TRACE_SUBJECT_FILTER" ]]; then
    return 0
  fi
  if [[ -n "${_PMCTL_TRACE_SINCE_FILTER:-}" && ( -z "$ts" || "$ts" < "$_PMCTL_TRACE_SINCE_FILTER" ) ]]; then
    return 0
  fi
  if [[ -n "${_PMCTL_TRACE_UNTIL_FILTER:-}" && ( -z "$ts" || "$ts" > "$_PMCTL_TRACE_UNTIL_FILTER" ) ]]; then
    return 0
  fi

  _PMCTL_TRACE_SEQ=$((_PMCTL_TRACE_SEQ + 1))
  printf '%s\t%012d\t%s\n' "$ts" "$_PMCTL_TRACE_SEQ" "$compact" >> "$_PMCTL_TRACE_RECORDS"
}

pmctl_trace_scan_path() {
  local path="${1:-}" line

  [[ -f "$path" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    pmctl_trace_scan_line "$line"
  done < "$path"
}

pmctl_trace_scan_gzip_path() {
  local path="${1:-}" line

  [[ -f "$path" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    pmctl_trace_scan_line "$line"
  done < <(gzip -dc "$path" 2>/dev/null)
}

pmctl_trace_emit_json() {
  local path="${1:-}" ts seq json

  while IFS=$'\t' read -r ts seq json; do
    : "$ts" "$seq"
    printf '%s\n' "$json"
  done < "$path"
}

pmctl_trace_emit_human() {
  local path="${1:-}" ts seq json

  while IFS=$'\t' read -r ts seq json; do
    : "$ts" "$seq"
    printf '%s\n' "$json" | jq -r '
      (.ts // "") as $ts |
      (.kind // "") as $kind |
      (.subject_type // "") as $subject_type |
      (.subject_id // "") as $subject_id |
      (if (.actor? == null or .actor == "") then "[no-actor]" else .actor end) as $actor |
      (if (.operation_id? == null or .operation_id == "") then "" else " op=\(.operation_id)" end) as $op |
      "\($ts)  \($kind)  \($subject_type)/\($subject_id)  \($actor)\($op)"
    '
  done < "$path"
}

pmctl_trace_tail() {
  local repo_root="${1:-}"
  local kind_filter="" subject_filter="" id_filter="" since_filter="" until_filter=""
  local limit=20 all=0 json=0
  local proj_dir active_file archive_dir read_archives=1
  local tmp_dir records sorted limited emit_file rc=0
  local -a archives=()

  if [[ -z "$repo_root" ]]; then
    printf 'pmctl trace tail: missing repo root\n' >&2
    pmctl_trace_usage
    return 2
  fi
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --kind)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl trace tail: missing value for --kind\n' >&2
          pmctl_trace_usage
          return 2
        fi
        kind_filter="$2"
        shift 2
        ;;
      --task|--subject)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl trace tail: missing value for %s\n' "$1" >&2
          pmctl_trace_usage
          return 2
        fi
        subject_filter="$2"
        shift 2
        ;;
      --id)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl trace tail: missing value for --id\n' >&2
          pmctl_trace_usage
          return 2
        fi
        id_filter="$2"
        shift 2
        ;;
      --since)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl trace tail: missing value for --since\n' >&2
          pmctl_trace_usage
          return 2
        fi
        since_filter="$2"
        shift 2
        ;;
      --until)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl trace tail: missing value for --until\n' >&2
          pmctl_trace_usage
          return 2
        fi
        until_filter="$2"
        shift 2
        ;;
      -n|--limit)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl trace tail: missing value for %s\n' "$1" >&2
          pmctl_trace_usage
          return 2
        fi
        limit="$2"
        if [[ ! "$limit" =~ ^[0-9]+$ ]]; then
          printf 'pmctl trace tail: invalid limit: %s\n' "$limit" >&2
          pmctl_trace_usage
          return 2
        fi
        shift 2
        ;;
      --json)
        json=1
        shift
        ;;
      --all)
        all=1
        shift
        ;;
      *)
        printf 'pmctl trace tail: unknown flag: %s\n' "$1" >&2
        pmctl_trace_usage
        return 2
        ;;
    esac
  done

  if ! command -v jq >/dev/null 2>&1; then
    printf 'pmctl trace tail: jq is required\n' >&2
    return 2
  fi
  pmctl_trace_ensure_state_writer "$repo_root" || return $?
  proj_dir="$(_SW_REPO_ROOT="$repo_root" _sw_project_dir)"
  active_file="$proj_dir/events.jsonl"
  archive_dir="$proj_dir/archive"

  if [[ -d "$archive_dir" ]]; then
    while IFS= read -r -d '' _pmctl_trace_archive; do
      archives+=("$_pmctl_trace_archive")
    done < <(find "$archive_dir" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print0 2>/dev/null | sort -z)
    unset _pmctl_trace_archive
  fi

  if [[ "${#archives[@]}" -gt 0 ]] && ! command -v gzip >/dev/null 2>&1; then
    printf 'trace: gzip unavailable; reading active events only\n' >&2
    read_archives=0
  fi
  if [[ ! -f "$active_file" && ( "${#archives[@]}" -eq 0 || "$read_archives" -eq 0 ) ]]; then
    return 0
  fi

  tmp_dir="$(mktemp -d)" || return 1
  records="$tmp_dir/records.tsv"
  sorted="$tmp_dir/sorted.tsv"
  limited="$tmp_dir/limited.tsv"
  : > "$records" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    rm -rf "$tmp_dir"
    return "$rc"
  fi

  _PMCTL_TRACE_KIND_FILTER="$kind_filter"
  _PMCTL_TRACE_SUBJECT_FILTER="$subject_filter"
  _PMCTL_TRACE_ID_FILTER="$id_filter"
  _PMCTL_TRACE_SINCE_FILTER="$since_filter"
  _PMCTL_TRACE_UNTIL_FILTER="$until_filter"
  _PMCTL_TRACE_RECORDS="$records"
  _PMCTL_TRACE_SEQ=0
  _PMCTL_TRACE_SKIPPED=0

  if [[ "$read_archives" -eq 1 ]]; then
    for _pmctl_trace_archive in "${archives[@]}"; do
      pmctl_trace_scan_gzip_path "$_pmctl_trace_archive"
    done
    unset _pmctl_trace_archive
  fi
  pmctl_trace_scan_path "$active_file"

  if [[ "$_PMCTL_TRACE_SKIPPED" -gt 0 ]]; then
    printf 'trace: skipped %s malformed row(s)\n' "$_PMCTL_TRACE_SKIPPED" >&2
  fi

  unset _PMCTL_TRACE_KIND_FILTER _PMCTL_TRACE_SUBJECT_FILTER _PMCTL_TRACE_ID_FILTER
  unset _PMCTL_TRACE_SINCE_FILTER _PMCTL_TRACE_UNTIL_FILTER _PMCTL_TRACE_RECORDS
  unset _PMCTL_TRACE_SEQ _PMCTL_TRACE_SKIPPED

  if [[ ! -s "$records" ]]; then
    rm -rf "$tmp_dir"
    return 0
  fi
  if ! LC_ALL=C sort -s -t $'\t' -k1,1 -k2,2n "$records" > "$sorted"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  emit_file="$sorted"
  if [[ "$all" -eq 0 ]]; then
    if [[ "$limit" -eq 0 ]]; then
      : > "$limited" || rc=$?
    else
      tail -n "$limit" "$sorted" > "$limited" || rc=$?
    fi
    if [[ "$rc" -ne 0 ]]; then
      rm -rf "$tmp_dir"
      return "$rc"
    fi
    emit_file="$limited"
  fi

  if [[ "$json" -eq 1 ]]; then
    pmctl_trace_emit_json "$emit_file" || rc=$?
  else
    pmctl_trace_emit_human "$emit_file" || rc=$?
  fi

  rm -rf "$tmp_dir"
  return "$rc"
}
