#!/usr/bin/env bash

pmctl_backlog_view() {
  local backlog_path status_filter="" area_filter=""

  backlog_path="${1:-}"
  if [[ -z "$backlog_path" ]]; then
    printf 'pmctl backlog view: missing backlog path\n' >&2
    return 2
  fi
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl backlog view: missing value for --status\n' >&2
          return 2
        fi
        status_filter="$2"
        shift 2
        ;;
      --area)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl backlog view: missing value for --area\n' >&2
          return 2
        fi
        area_filter="$2"
        shift 2
        ;;
      *)
        printf 'pmctl backlog view: unknown flag: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done

  awk -v status_filter="$status_filter" -v area_filter="$area_filter" '
function trim(s) {
  gsub(/^[[:space:]]+/, "", s)
  gsub(/[[:space:]]+$/, "", s)
  return s
}

BEGIN {
  in_index = 0
  header_count = 0
}

$0 == "## Index" {
  in_index = 1
  header_count = 0
  next
}

in_index && /^## / {
  exit
}

in_index && header_count < 2 && /^\|/ {
  print
  header_count++
  next
}

in_index && /^\| [A-Z]+-[0-9]/ {
  row = $0
  sub(/^\|[[:space:]]*/, "", row)
  sub(/[[:space:]]*\|[[:space:]]*$/, "", row)
  split(row, cols, "|")

  status = trim(cols[2])
  area = trim(cols[4])

  if ((status_filter == "" || index(status, status_filter) > 0) &&
      (area_filter == "" || index(area, area_filter) > 0)) {
    print $0
  }
}
' "$backlog_path"
}

pmctl_backlog_lint() {
  local repo_root rc=0

  repo_root="$1"
  bash "$repo_root/pm/scripts/validate.sh" "$repo_root/BACKLOG.md" || rc=$?
  return "$rc"
}

pmctl_backlog_archive() {
  local repo_root rc=0

  repo_root="$1"
  shift
  bash "$repo_root/scripts/archive-closed-backlog.sh" "$@" || rc=$?
  return "$rc"
}
