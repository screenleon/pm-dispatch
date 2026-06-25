#!/usr/bin/env bash

pmctl_artifacts_usage() {
  printf 'usage: pmctl artifacts list [--cd <work_dir>]\n' >&2
  printf '       pmctl artifacts show <run_id> [--cd <work_dir>]\n' >&2
  printf '       pmctl artifacts gc [--dry-run] [--keep-last N] [--max-age-days D]\n' >&2
  printf '                          [--cd <work_dir>] [--all-repos] [--repos-root <dir>]\n' >&2
  printf '       pmctl artifacts migrate [--cd <work_dir>]\n' >&2
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

# _pmctl_artifacts_safe_rm_check <path> [leaf_registry...]
# Returns 0 if it is safe to rm -rf <path>, 1 if any safety assertion fails.
# Safety rules:
#   1. path must be absolute
#   2. path must NOT contain .pm-dispatch as a path component
#   3. path must end with one of the known artifact leaves, OR be a runs/<run_id>
#      directory where run_id contains no slashes or ..
_pmctl_artifacts_safe_rm_check() {
  local target="${1:-}"
  shift || true
  local known_leaves=("$@")

  if [[ -z "$target" || "$target" != /* ]]; then
    printf 'pmctl artifacts: safety check: path is not absolute: %s\n' "$target" >&2
    return 1
  fi
  # Component check: split by / and look for .pm-dispatch
  local part
  local IFS_SAVE="$IFS"
  IFS='/'
  # shellcheck disable=SC2206
  local parts=($target)
  IFS="$IFS_SAVE"
  for part in "${parts[@]}"; do
    if [[ "$part" == ".pm-dispatch" ]]; then
      printf 'pmctl artifacts: safety check: path contains .pm-dispatch — refusing: %s\n' "$target" >&2
      return 1
    fi
  done

  # Check if path ends with a known artifact leaf
  local base
  base="$(basename "$target")"
  local leaf found_leaf=0
  for leaf in "${known_leaves[@]}"; do
    if [[ "$base" == "$leaf" ]]; then
      found_leaf=1
      break
    fi
  done
  if [[ "$found_leaf" -eq 1 ]]; then
    return 0
  fi

  # Check if path looks like runs/<run_id> (run_id has no slashes or ..)
  local parent_base
  parent_base="$(basename "$(dirname "$target")")"
  if [[ "$parent_base" == "runs" && "$base" != */* && "$base" != *..*  ]]; then
    return 0
  fi

  printf 'pmctl artifacts: safety check: path does not match a known artifact pattern: %s\n' "$target" >&2
  return 1
}

_pmctl_artifacts_dir_size() {
  local path="${1:-}"
  du -sb "$path" 2>/dev/null | cut -f1 || du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}' || printf '0'
}

pmctl_artifacts_gc() {
  local repo_root="${1:-}" work_dir="${2:-}"
  shift 2 || true

  local dry_run=0 keep_last all_repos=0 repos_root max_age_days
  keep_last="${PM_DISPATCH_GC_KEEP_LAST:-10}"
  max_age_days="${PM_DISPATCH_GC_MAX_AGE_DAYS:-30}"
  repos_root="${HOME:-}/github"

  if [[ -z "$work_dir" ]]; then
    work_dir="$repo_root"
  fi

  local extra_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --keep-last)
        if [[ $# -lt 2 || ! "${2:-}" =~ ^[0-9]+$ || "${2:-}" -lt 1 ]]; then
          printf 'pmctl artifacts gc: --keep-last requires an integer >= 1\n' >&2; return 2
        fi
        keep_last="$2"; shift 2 ;;
      --max-age-days)
        if [[ $# -lt 2 || ! "${2:-}" =~ ^[0-9]+$ ]]; then
          printf 'pmctl artifacts gc: --max-age-days requires an integer >= 0\n' >&2; return 2
        fi
        max_age_days="$2"; shift 2 ;;
      --all-repos) all_repos=1; shift ;;
      --repos-root)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl artifacts gc: --repos-root requires a directory\n' >&2; return 2
        fi
        repos_root="$2"; shift 2 ;;
      --cd)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl artifacts gc: --cd requires a work dir\n' >&2; return 2
        fi
        work_dir="$2"; shift 2 ;;
      -h|--help) pmctl_artifacts_usage; return 0 ;;
      *) extra_args+=("$1"); shift ;;
    esac
  done
  if [[ "${#extra_args[@]}" -gt 0 ]]; then
    printf 'pmctl artifacts gc: unexpected argument: %s\n' "${extra_args[0]}" >&2
    pmctl_artifacts_usage; return 2
  fi

  # Load PM_ARTIFACT_LEAVES from artifact-paths.sh
  local artifact_paths_sh
  artifact_paths_sh="${repo_root}/scripts/lib/artifact-paths.sh"
  if [[ -r "$artifact_paths_sh" ]]; then
    # shellcheck disable=SC1091
    . "$artifact_paths_sh" 2>/dev/null || true
  fi
  local leaves=("${PM_ARTIFACT_LEAVES[@]-.agent-trace .gate-briefs .gate-results}")

  # --all-repos: scan repos-root for in-repo remnant leaves
  if [[ "$all_repos" -eq 1 ]]; then
    local total_found=0 total_removed=0 repo leaf_path leaf_size
    if [[ ! -d "$repos_root" ]]; then
      printf 'pmctl artifacts gc: --repos-root does not exist: %s\n' "$repos_root" >&2
      return 2
    fi
    for repo in "$repos_root"/*/; do
      [[ -d "$repo/.git" ]] || continue
      repo="${repo%/}"
      for leaf in "${leaves[@]}"; do
        leaf_path="$repo/$leaf"
        [[ -d "$leaf_path" ]] || continue
        # Skip empty dirs
        if [[ -z "$(ls -A "$leaf_path" 2>/dev/null)" ]]; then
          continue
        fi
        leaf_size="$(_pmctl_artifacts_dir_size "$leaf_path")"
        printf 'found: %s  (approx %s bytes)\n' "$leaf_path" "$leaf_size"
        (( total_found++ )) || true
        if [[ "$dry_run" -eq 0 ]]; then
          if _pmctl_artifacts_safe_rm_check "$leaf_path" "${leaves[@]}"; then
            rm -rf "$leaf_path"
            (( total_removed++ )) || true
          fi
        fi
      done
    done
    if [[ "$dry_run" -eq 1 ]]; then
      printf 'gc --all-repos: dry-run, found %d in-repo remnant directories\n' "$total_found"
    else
      printf 'gc --all-repos: removed %d in-repo remnant directories\n' "$total_removed"
    fi
    return 0
  fi

  # Per-partition GC
  pmctl_artifacts_ensure_state_paths "$repo_root" || return $?
  local runs_dir
  runs_dir="$(pmctl_artifacts_runs_dir "$work_dir" 2>/dev/null)" || {
    printf 'pmctl artifacts gc: cannot resolve project run directory for %s\n' "$work_dir" >&2
    return 2
  }
  if [[ ! -d "$runs_dir" ]]; then
    printf 'gc: deleted 0 runs, freed 0 bytes\n'
    return 0
  fi

  # Build sorted list of run dirs by mtime (newest first)
  local tmp_sort
  tmp_sort="$(mktemp "${TMPDIR:-/tmp}/pmctl-artifacts-gc.XXXXXX")" || return 2
  local run_dir mtime
  for run_dir in "$runs_dir"/*/; do
    [[ -d "$run_dir" ]] || continue
    run_dir="${run_dir%/}"
    mtime="$(pmctl_artifacts_file_mtime "$run_dir")"
    printf '%s\t%s\n' "$mtime" "$run_dir" >> "$tmp_sort"
  done

  # Sort newest-first
  local sorted_runs
  sorted_runs="$(sort -rn "$tmp_sort")"
  rm -f "$tmp_sort"

  local now_epoch
  now_epoch="$(date +%s 2>/dev/null || printf '0')"
  local max_age_seconds=$(( max_age_days * 86400 ))

  local rank=0 deleted=0 freed=0 run_id run_size run_mtime age_seconds
  while IFS=$'\t' read -r run_mtime run_dir; do
    (( rank++ )) || true
    run_id="$(basename "$run_dir")"

    # Always keep the youngest keep_last runs
    if (( rank <= keep_last )); then
      continue
    fi

    # Check age filter (skip age check if max_age_days=0)
    if [[ "$max_age_days" -gt 0 ]]; then
      age_seconds=$(( now_epoch - run_mtime ))
      if (( age_seconds < max_age_seconds )); then
        continue
      fi
    fi

    # Also always delete empty run dirs regardless of age
    run_size="$(_pmctl_artifacts_dir_size "$run_dir")"
    if [[ "$dry_run" -eq 1 ]]; then
      printf 'would delete: %s  (%s bytes)\n' "$run_id" "$run_size"
      (( deleted++ )) || true
    else
      if _pmctl_artifacts_safe_rm_check "$run_dir"; then
        printf 'deleted: %s  (%s bytes)\n' "$run_id" "$run_size"
        rm -rf "$run_dir"
        (( deleted++ )) || true
        (( freed += run_size )) || true
      fi
    fi
  done <<< "$sorted_runs"

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'gc: dry-run, would delete %d runs\n' "$deleted"
  else
    printf 'gc: deleted %d runs, freed %d bytes\n' "$deleted" "$freed"
  fi
}

pmctl_artifacts_migrate() {
  local repo_root="${1:-}" work_dir="${2:-}"
  shift 2 || true

  if [[ -z "$work_dir" ]]; then
    work_dir="$repo_root"
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl artifacts migrate: --cd requires a work dir\n' >&2; return 2
        fi
        work_dir="$2"; shift 2 ;;
      -h|--help) pmctl_artifacts_usage; return 0 ;;
      *)
        printf 'pmctl artifacts migrate: unexpected argument: %s\n' "$1" >&2
        pmctl_artifacts_usage; return 2 ;;
    esac
  done

  # Load PM_ARTIFACT_LEAVES
  local artifact_paths_sh
  artifact_paths_sh="${repo_root}/scripts/lib/artifact-paths.sh"
  if [[ -r "$artifact_paths_sh" ]]; then
    # shellcheck disable=SC1091
    . "$artifact_paths_sh" 2>/dev/null || true
  fi
  local leaves=("${PM_ARTIFACT_LEAVES[@]-.agent-trace .gate-briefs .gate-results}")

  pmctl_artifacts_ensure_state_paths "$repo_root" || return $?

  local moved=0 leaf_path run_id dest mtime
  for leaf in "${leaves[@]}"; do
    leaf_path="${work_dir}/${leaf}"
    [[ -d "$leaf_path" ]] || continue

    # Generate synthetic run_id from leaf name + dir mtime
    mtime="$(pmctl_artifacts_file_mtime "$leaf_path")"
    run_id="migrate-${leaf#.}-${mtime}"

    dest="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "$run_id" 2>/dev/null)" || {
      printf 'pmctl artifacts migrate: cannot resolve destination for %s\n' "$leaf" >&2
      continue
    }

    if [[ -e "$dest" ]]; then
      printf 'skip (already migrated): %s -> %s\n' "$leaf_path" "$dest"
      continue
    fi

    mkdir -p "$(dirname "$dest")"
    if cp -a "$leaf_path" "$dest"; then
      printf 'migrated: %s -> %s\n' "$leaf_path" "$dest"
      (( moved++ )) || true
    else
      printf 'pmctl artifacts migrate: cp failed for %s\n' "$leaf_path" >&2
    fi
  done

  printf 'migrate: moved %d directories (originals preserved; verify then remove manually)\n' "$moved"
}
