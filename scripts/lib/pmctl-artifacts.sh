#!/usr/bin/env bash

pmctl_artifacts_usage() {
  printf 'usage: pmctl artifacts list [--cd <work_dir>]\n' >&2
  printf '       pmctl artifacts show <run_id> [--cd <work_dir>]\n' >&2
}

pmctl_artifacts_ensure_state_paths() {
  local repo_root="${1:-}"
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function ]]; then
    # ${repo_root:-} so a caller without repo_root in scope degrades to the legacy
    # fallback instead of tripping set -u; the dispatch core always binds it.
    local _sp_lib="${repo_root:-}/scripts/lib/state-paths.sh"
    if [[ -r "$_sp_lib" ]]; then
      # shellcheck disable=SC1090,SC1091  # dynamic repo-root path.
      . "$_sp_lib" 2>/dev/null || true
    fi
  fi
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function ]]; then
    printf 'pmctl artifacts: state-paths.sh unavailable; cannot resolve artifact run dirs\n' >&2
    return 2
  fi
}

pmctl_artifacts_parse_cd() {
  _PMCTL_ARTIFACTS_PARSE_HELP=0
  _PMCTL_ARTIFACTS_WORK_DIR="${1:-}"
  shift || true
  _PMCTL_ARTIFACTS_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl artifacts: --cd requires a work dir\n' >&2
          return 2
        fi
        _PMCTL_ARTIFACTS_WORK_DIR="$2"
        shift 2
        ;;
      -h|--help)
        pmctl_artifacts_usage
        _PMCTL_ARTIFACTS_PARSE_HELP=1
        return 0
        ;;
      *)
        _PMCTL_ARTIFACTS_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

pmctl_artifacts_runs_dir() {
  local work_dir="${1:-}" run_dir
  run_dir="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "__pmctl_artifacts_probe__" 2>/dev/null)" || return 1
  dirname "$run_dir"
}

pmctl_artifacts_file_mtime() {
  local path="${1:-}"
  stat -c '%Y' "$path" 2>/dev/null && return 0
  stat -f '%m' "$path" 2>/dev/null && return 0
  printf '0\n'
}

pmctl_artifacts_file_size() {
  local path="${1:-}"
  stat -c '%s' "$path" 2>/dev/null && return 0
  stat -f '%z' "$path" 2>/dev/null && return 0
  wc -c < "$path" | tr -d ' '
}

pmctl_artifacts_epoch_to_ts() {
  local epoch="${1:-0}"
  date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  printf '%s\n' "$epoch"
}

pmctl_artifacts_run_created_epoch() {
  local run_dir="${1:-}" footer newest=0 candidate
  for footer in "$run_dir"/*.footer; do
    [[ -e "$footer" ]] || continue
    candidate="$(pmctl_artifacts_file_mtime "$footer")"
    [[ "$candidate" =~ ^[0-9]+$ ]] || candidate=0
    (( candidate > newest )) && newest="$candidate"
  done
  if [[ "$newest" -eq 0 ]]; then
    newest="$(pmctl_artifacts_file_mtime "$run_dir")"
  fi
  printf '%s\n' "$newest"
}

pmctl_artifacts_list() {
  local repo_root="${1:-}" work_dir="${2:-}"
  shift 2 || true
  local runs_dir run_dir run_id epoch tmp_file any=0

  if [[ -z "$work_dir" ]]; then
    work_dir="$repo_root"
  fi
  if ! pmctl_artifacts_parse_cd "$work_dir" "$@"; then
    return 2
  fi
  if [[ "${_PMCTL_ARTIFACTS_PARSE_HELP:-0}" -eq 1 ]]; then
    return 0
  fi
  if [[ "${#_PMCTL_ARTIFACTS_ARGS[@]}" -ne 0 ]]; then
    printf 'pmctl artifacts list: unexpected argument: %s\n' "${_PMCTL_ARTIFACTS_ARGS[0]}" >&2
    pmctl_artifacts_usage
    return 2
  fi
  work_dir="$_PMCTL_ARTIFACTS_WORK_DIR"

  pmctl_artifacts_ensure_state_paths "$repo_root" || return $?
  runs_dir="$(pmctl_artifacts_runs_dir "$work_dir" 2>/dev/null)" || {
    printf 'pmctl artifacts list: cannot resolve project run directory for %s\n' "$work_dir" >&2
    return 2
  }
  if [[ ! -d "$runs_dir" ]]; then
    printf '(no runs found)\n'
    return 0
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/pmctl-artifacts-list.XXXXXX")" || return 2
  for run_dir in "$runs_dir"/*; do
    [[ -d "$run_dir" ]] || continue
    run_id="$(basename "$run_dir")"
    epoch="$(pmctl_artifacts_run_created_epoch "$run_dir")"
    printf '%s\t%s\t%s\n' "$epoch" "$run_id" "$(pmctl_artifacts_epoch_to_ts "$epoch")" >> "$tmp_file"
    any=1
  done
  if [[ "$any" -eq 0 ]]; then
    rm -f "$tmp_file"
    printf '(no runs found)\n'
    return 0
  fi
  sort -rn "$tmp_file" | awk -F '\t' '{print $2 "\t" $3}'
  rm -f "$tmp_file"
}

pmctl_artifacts_show() {
  local repo_root="${1:-}" run_id="${2:-}" work_dir="${3:-}"
  shift 3 || true
  local run_dir file rel size tmp_file

  if [[ -z "$work_dir" ]]; then
    work_dir="$repo_root"
  fi
  if ! pmctl_artifacts_parse_cd "$work_dir" "$@"; then
    return 2
  fi
  if [[ "${_PMCTL_ARTIFACTS_PARSE_HELP:-0}" -eq 1 ]]; then
    return 0
  fi
  if [[ "${#_PMCTL_ARTIFACTS_ARGS[@]}" -gt 0 ]]; then
    if [[ -n "$run_id" ]]; then
      printf 'pmctl artifacts show: unexpected argument: %s\n' "${_PMCTL_ARTIFACTS_ARGS[0]}" >&2
      pmctl_artifacts_usage
      return 2
    fi
    run_id="${_PMCTL_ARTIFACTS_ARGS[0]}"
  fi
  work_dir="$_PMCTL_ARTIFACTS_WORK_DIR"
  if [[ -z "$run_id" ]]; then
    printf 'pmctl artifacts show: missing run_id\n' >&2
    pmctl_artifacts_usage
    return 2
  fi

  pmctl_artifacts_ensure_state_paths "$repo_root" || return $?
  run_dir="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "$run_id" 2>/dev/null)" || {
    printf 'pmctl artifacts show: cannot resolve run dir for %s under %s\n' "$run_id" "$work_dir" >&2
    return 2
  }
  if [[ ! -d "$run_dir" ]]; then
    printf 'pmctl artifacts show: run dir not found for %s: %s\n' "$run_id" "$run_dir" >&2
    printf 'pmctl artifacts show: run pmctl artifacts list --cd %q to see available runs\n' "$work_dir" >&2
    return 1
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/pmctl-artifacts-show.XXXXXX")" || return 2
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    rel="${file#"$run_dir"/}"
    size="$(pmctl_artifacts_file_size "$file")"
    printf '%s\t%s\n' "$size" "$rel" >> "$tmp_file"
  done < <(find "$run_dir" -type f | sort)
  if [[ ! -s "$tmp_file" ]]; then
    rm -f "$tmp_file"
    return 0
  fi
  cat "$tmp_file"
  rm -f "$tmp_file"
}
