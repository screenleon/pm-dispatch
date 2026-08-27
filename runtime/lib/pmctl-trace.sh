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

# Single streaming jq program over the concatenated archive+active event stream
# (raw input, one JSON object per line). Replaces the former per-line pair of
# jq spawns: this runs once for the whole partition regardless of event count.
#
# For every input line it prints exactly one control line to stdout:
#   "M"                                  -> line is not a JSON object (skip + count)
#   "E\t<ts>\t<line_no>\t<compact-json>" -> line matched all active filters
#   (nothing)                            -> valid object that a filter excluded
#
# <line_no> is jq's cumulative input_line_number across the whole concatenated
# stream, so it is a global monotonic read-order sequence: archives first (in
# filename-sorted order), then the active file, each in line order. The caller
# uses it as the stable-sort tiebreaker for events sharing a timestamp.
#
# Filters are passed as --arg strings; an empty string means "no constraint".
# Timestamp comparisons are lexicographic on the ISO-8601 string, matching the
# shell `<` / `>` semantics this previously used, and an empty ts is excluded
# whenever a --since or --until bound is set.
pmctl_trace_filter_program() {
  cat <<'JQ'
    (try fromjson catch null) as $o
    | if ($o | type) != "object" then "M"
      else
        ($o.ts // "")         as $ts
        | ($o.id // "")         as $id
        | ($o.kind // "")       as $kind
        | ($o.subject_id // "") as $sid
        | if   ($idf    != "" and $id   != $idf)                 then empty
          elif ($kindf  != "" and $kind != $kindf)               then empty
          elif ($subjf  != "" and $sid  != $subjf)               then empty
          elif ($sincef != "" and ($ts == "" or $ts < $sincef))  then empty
          elif ($untilf != "" and ($ts == "" or $ts > $untilf))  then empty
          else "E\t\($ts)\t\(input_line_number)\t\($o | tojson)"
          end
      end
JQ
}

# emit helpers consume the sorted "<ts>\t<seq>\t<compact-json>" record file.
# The compact JSON is the third tab field and never contains a literal tab
# (jq -c escapes tabs inside strings), so `cut -f3` recovers it exactly.
pmctl_trace_emit_json() {
  local path="${1:-}"

  [[ -s "$path" ]] || return 0
  cut -f3 "$path"
}

pmctl_trace_emit_human() {
  local path="${1:-}"

  [[ -s "$path" ]] || return 0
  cut -f3 "$path" | jq -r '
    (.ts // "") as $ts |
    (.kind // "") as $kind |
    (.subject_type // "") as $subject_type |
    (.subject_id // "") as $subject_id |
    (if (.actor? == null or .actor == "") then "[no-actor]" else .actor end) as $actor |
    (if (.operation_id? == null or .operation_id == "") then "" else " op=\(.operation_id)" end) as $op |
    "\($ts)  \($kind)  \($subject_type)/\($subject_id)  \($actor)\($op)"
  '
}

pmctl_trace_tail() {
  local repo_root="${1:-}"
  local kind_filter="" subject_filter="" id_filter="" since_filter="" until_filter=""
  local limit=20 all=0 json=0
  local proj_dir active_file archive_dir read_archives=1
  local tmp_dir records sorted limited emit_file rc=0
  local skipped=0 program out_line _pmctl_trace_archive
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

  program="$(pmctl_trace_filter_program)"
  while IFS= read -r out_line; do
    if [[ "$out_line" == "M" ]]; then
      skipped=$((skipped + 1))
    else
      printf '%s\n' "${out_line#E$'\t'}" >> "$records"
    fi
  done < <(
    {
      if [[ "$read_archives" -eq 1 ]]; then
        for _pmctl_trace_archive in "${archives[@]}"; do
          [[ -f "$_pmctl_trace_archive" ]] && gzip -dc "$_pmctl_trace_archive" 2>/dev/null
        done
      fi
      [[ -f "$active_file" ]] && cat "$active_file"
    } | jq -R -r \
      --arg idf "$id_filter" \
      --arg kindf "$kind_filter" \
      --arg subjf "$subject_filter" \
      --arg sincef "$since_filter" \
      --arg untilf "$until_filter" \
      "$program"
  )

  if [[ "$skipped" -gt 0 ]]; then
    printf 'trace: skipped %s malformed row(s)\n' "$skipped" >&2
  fi

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
