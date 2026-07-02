#!/usr/bin/env bash
# pmctl worktree create/list/remove/gc -- repo-wide git worktree registry for
# parallel multi-ticket development. Manifest is stored out-of-repo in the
# state store, keyed by the MAIN repo identity (sw_project_worktree_dir /
# state-paths.sh:_sw_worktree_project_key) so a linked worktree and its
# primary checkout resolve to the SAME partition regardless of which one the
# command is invoked from.

pmctl_worktree_usage() {
  printf 'usage: pmctl worktree create <branch> [--from <base-branch>] [--name <slug>] [--cd <work_dir>]\n' >&2
  printf '       pmctl worktree list   [--cd <work_dir>] [--json]\n' >&2
  printf '       pmctl worktree remove <name|branch> [--force] [--cd <work_dir>]\n' >&2
  printf '       pmctl worktree gc     [--dry-run] [--merged] [--max-age-days D] [--cd <work_dir>]\n' >&2
}

pmctl_worktree_ensure_state_paths() {
  local repo_root="${1:-}"
  if [[ "$(type -t sw_project_worktree_dir 2>/dev/null)" != function ]]; then
    local _sp_lib="${repo_root:-}/scripts/lib/state-paths.sh"
    if [[ -r "$_sp_lib" ]]; then
      # shellcheck disable=SC1090,SC1091  # dynamic repo-root path.
      . "$_sp_lib" 2>/dev/null || true
    fi
  fi
  if [[ "$(type -t sw_project_worktree_dir 2>/dev/null)" != function ]]; then
    printf 'pmctl worktree: state-paths.sh unavailable; cannot resolve worktree registry dir\n' >&2
    return 2
  fi
}

pmctl_worktree_ensure_writer() {
  local repo_root="${1:-}"
  if [[ "$(type -t _sw_compact_json_line 2>/dev/null)" != function || "$(type -t serialize_with_lock 2>/dev/null)" != function ]]; then
    local _sw_lib="${repo_root:-}/scripts/lib/state-writer.sh"
    if [[ -r "$_sw_lib" ]]; then
      # shellcheck disable=SC1090,SC1091  # dynamic repo-root path.
      . "$_sw_lib" 2>/dev/null || true
    fi
  fi
  if [[ "$(type -t _sw_compact_json_line 2>/dev/null)" != function || "$(type -t serialize_with_lock 2>/dev/null)" != function ]]; then
    printf 'pmctl worktree: state-writer.sh unavailable; cannot write worktree manifest\n' >&2
    return 2
  fi
}

# _pmctl_worktree_slugify <branch>
# Normalize a branch name into a filesystem-safe, single-path-segment slug:
# `/` -> `-`, then strip everything outside [A-Za-z0-9._-]. Rejects a branch
# that slugifies to empty or that still contains a path-escape sequence.
_pmctl_worktree_slugify() {
  local branch="${1:-}" slug
  slug="${branch//\//-}"
  slug="$(printf '%s' "$slug" | tr -c 'A-Za-z0-9._-' '-')"
  if [[ -z "$slug" || "$slug" == *..* || "$slug" == .* ]]; then
    printf 'pmctl worktree: branch name does not produce a safe slug: %s\n' "$branch" >&2
    return 1
  fi
  printf '%s\n' "$slug"
}

pmctl_worktree_manifest_path() {
  local reg_dir
  reg_dir="$(sw_project_worktree_dir)" || return 1
  printf '%s/manifest.jsonl\n' "$reg_dir"
}

_pmctl_worktree_manifest_append_inner() {
  local json_line="$1" compact manifest="$2"
  compact="$(_sw_compact_json_line "$json_line")" || return $?
  printf '%s\n' "$compact" >> "$manifest"
}

pmctl_worktree_manifest_append() {
  local json_line="$1" reg_dir manifest rc=0
  reg_dir="$(sw_project_worktree_dir)" || return 1
  mkdir -p "$reg_dir" 2>/dev/null || { printf 'pmctl worktree: mkdir failed: %s\n' "$reg_dir" >&2; return 1; }
  chmod 0700 "$reg_dir" 2>/dev/null || true
  manifest="$reg_dir/manifest.jsonl"
  serialize_with_lock "$reg_dir/manifest" _pmctl_worktree_manifest_append_inner "$json_line" "$manifest" || rc=$?
  return "$rc"
}

# _pmctl_worktree_manifest_rewrite_inner <manifest> <tmp_content_file>
# Atomically replace manifest.jsonl with tmp_content_file's contents, run
# under the same lock as append so remove/gc never race a concurrent create.
_pmctl_worktree_manifest_rewrite_inner() {
  local manifest="$1" tmp_content="$2"
  mv -f "$tmp_content" "$manifest"
}

pmctl_worktree_manifest_rewrite() {
  local new_content="$1" reg_dir manifest tmp rc=0
  reg_dir="$(sw_project_worktree_dir)" || return 1
  manifest="$reg_dir/manifest.jsonl"
  tmp="$(mktemp "$reg_dir/.manifest.XXXXXX")" || return 1
  printf '%s' "$new_content" > "$tmp"
  serialize_with_lock "$reg_dir/manifest" _pmctl_worktree_manifest_rewrite_inner "$manifest" "$tmp" || rc=$?
  [[ -f "$tmp" ]] && rm -f "$tmp"
  return "$rc"
}

pmctl_worktree_manifest_read() {
  local manifest
  manifest="$(pmctl_worktree_manifest_path)" || return 1
  [[ -f "$manifest" ]] && cat "$manifest"
  return 0
}

pmctl_worktree_create() {
  local repo_root="${1:-}" work_dir="${2:-}" branch="" base="" name="" args=()
  shift 2 || true
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  args=("$@")
  local i=0 rest=()
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --from)
        base="${args[$((i+1))]:-}"
        [[ -n "$base" ]] || { printf 'pmctl worktree create: --from requires a branch\n' >&2; return 2; }
        i=$((i+2))
        ;;
      --name)
        name="${args[$((i+1))]:-}"
        [[ -n "$name" ]] || { printf 'pmctl worktree create: --name requires a slug\n' >&2; return 2; }
        i=$((i+2))
        ;;
      --cd)
        work_dir="${args[$((i+1))]:-}"
        i=$((i+2))
        ;;
      -h|--help)
        pmctl_worktree_usage
        return 0
        ;;
      *)
        rest+=("${args[$i]}")
        i=$((i+1))
        ;;
    esac
  done
  branch="${rest[0]:-}"
  if [[ -z "$branch" ]]; then
    printf 'pmctl worktree create: <branch> is required\n' >&2
    pmctl_worktree_usage
    return 2
  fi
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  pmctl_worktree_ensure_state_paths "$repo_root" || return $?
  pmctl_worktree_ensure_writer "$repo_root" || return $?

  local slug
  slug="$(_pmctl_worktree_slugify "${name:-$branch}")" || return 1

  local reg_dir wt_path
  reg_dir="$(cd "$work_dir" 2>/dev/null && sw_project_worktree_dir)" || {
    printf 'pmctl worktree create: cannot resolve worktree registry dir from %s\n' "$work_dir" >&2
    return 1
  }
  wt_path="$reg_dir/checkouts/$slug"

  if [[ -e "$wt_path" ]]; then
    printf 'pmctl worktree create: a worktree already exists at %s (slug %s in use)\n' "$wt_path" "$slug" >&2
    return 1
  fi
  if (cd "$work_dir" && git worktree list --porcelain 2>/dev/null | grep -q "^worktree $wt_path\$"); then
    printf 'pmctl worktree create: git already tracks a worktree at %s\n' "$wt_path" >&2
    return 1
  fi

  mkdir -p "$reg_dir/checkouts" 2>/dev/null || true

  local git_args=(worktree add)
  if [[ -n "$base" ]]; then
    git_args+=(-b "$branch" "$wt_path" "$base")
  elif (cd "$work_dir" && git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null); then
    git_args+=("$wt_path" "$branch")
  else
    git_args+=(-b "$branch" "$wt_path")
  fi

  if ! (cd "$work_dir" && git "${git_args[@]}"); then
    printf 'pmctl worktree create: git worktree add failed\n' >&2
    return 1
  fi

  local created_ts json_line
  created_ts="$(date -Is 2>/dev/null || date)"
  json_line="$(printf '{"slug":%s,"branch":%s,"path":%s,"created_ts":%s}' \
    "$(jq -Rn --arg v "$slug" '$v')" \
    "$(jq -Rn --arg v "$branch" '$v')" \
    "$(jq -Rn --arg v "$wt_path" '$v')" \
    "$(jq -Rn --arg v "$created_ts" '$v')")"
  (cd "$work_dir" && pmctl_worktree_manifest_append "$json_line") || {
    printf 'pmctl worktree create: worktree created but manifest write failed -- run '\''pmctl worktree gc'\'' to reconcile\n' >&2
  }
  printf '%s\n' "$wt_path"
}

pmctl_worktree_list() {
  local repo_root="${1:-}" work_dir json_out=0 args=()
  shift || true
  work_dir="${1:-$repo_root}"
  shift || true
  args=("$@")
  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --cd) work_dir="${args[$((i+1))]:-}"; i=$((i+2)) ;;
      --json) json_out=1; i=$((i+1)) ;;
      -h|--help) pmctl_worktree_usage; return 0 ;;
      *) i=$((i+1)) ;;
    esac
  done
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  pmctl_worktree_ensure_state_paths "$repo_root" || return $?

  local manifest_content
  manifest_content="$(cd "$work_dir" 2>/dev/null && pmctl_worktree_manifest_read)" || true

  if [[ "$json_out" -eq 1 ]]; then
    if [[ -z "$manifest_content" ]]; then
      printf '[]\n'
    else
      printf '%s\n' "$manifest_content" | jq -s -c .
    fi
    return 0
  fi

  if [[ -z "$manifest_content" ]]; then
    printf 'No registered worktrees.\n'
    return 0
  fi
  printf '%-30s %-30s %s\n' SLUG BRANCH PATH
  printf '%s\n' "$manifest_content" | while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    jq -r '[.slug, .branch, .path] | @tsv' <<<"$line" | while IFS=$'\t' read -r slug branch path; do
      printf '%-30s %-30s %s\n' "$slug" "$branch" "$path"
    done
  done
}

pmctl_worktree_remove() {
  local repo_root="${1:-}" work_dir target force=0 args=()
  shift || true
  work_dir="${1:-$repo_root}"
  shift || true
  args=("$@")
  local i=0 rest=()
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --force) force=1; i=$((i+1)) ;;
      --cd) work_dir="${args[$((i+1))]:-}"; i=$((i+2)) ;;
      -h|--help) pmctl_worktree_usage; return 0 ;;
      *) rest+=("${args[$i]}"); i=$((i+1)) ;;
    esac
  done
  target="${rest[0]:-}"
  if [[ -z "$target" ]]; then
    printf 'pmctl worktree remove: <name|branch> is required\n' >&2
    pmctl_worktree_usage
    return 2
  fi
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  pmctl_worktree_ensure_state_paths "$repo_root" || return $?
  pmctl_worktree_ensure_writer "$repo_root" || return $?

  local manifest_content match_line match_path
  manifest_content="$(cd "$work_dir" 2>/dev/null && pmctl_worktree_manifest_read)" || true
  match_line="$(printf '%s\n' "$manifest_content" | jq -c --arg t "$target" 'select(.slug == $t or .branch == $t)' | head -1)"
  if [[ -z "$match_line" ]]; then
    printf 'pmctl worktree remove: no registered worktree matches %s\n' "$target" >&2
    return 1
  fi
  match_path="$(jq -r '.path' <<<"$match_line")"

  local git_rm_args=(worktree remove)
  [[ "$force" -eq 1 ]] && git_rm_args+=(--force)
  git_rm_args+=("$match_path")
  if [[ -d "$match_path" ]]; then
    if ! (cd "$work_dir" && git "${git_rm_args[@]}"); then
      printf 'pmctl worktree remove: git worktree remove failed for %s (dirty? pass --force to override)\n' "$match_path" >&2
      return 1
    fi
  fi
  (cd "$work_dir" && git worktree prune) 2>/dev/null || true

  local remaining
  remaining="$(printf '%s\n' "$manifest_content" | jq -c --arg t "$target" 'select(.slug != $t and .branch != $t)')"
  (cd "$work_dir" && pmctl_worktree_manifest_rewrite "$remaining") || {
    printf 'pmctl worktree remove: worktree removed but manifest cleanup failed -- run '\''pmctl worktree gc'\'' to reconcile\n' >&2
  }
  printf 'removed %s (%s)\n' "$target" "$match_path"
}

pmctl_worktree_gc() {
  local repo_root="${1:-}" work_dir dry_run=0 merged_only=0 max_age_days=0 args=()
  shift || true
  work_dir="${1:-$repo_root}"
  shift || true
  args=("$@")
  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --dry-run) dry_run=1; i=$((i+1)) ;;
      --merged) merged_only=1; i=$((i+1)) ;;
      --max-age-days)
        max_age_days="${args[$((i+1))]:-0}"
        if ! [[ "$max_age_days" =~ ^[0-9]+$ ]]; then
          printf 'pmctl worktree gc: --max-age-days requires an integer >= 0\n' >&2
          return 2
        fi
        i=$((i+2))
        ;;
      --cd) work_dir="${args[$((i+1))]:-}"; i=$((i+2)) ;;
      -h|--help) pmctl_worktree_usage; return 0 ;;
      *) i=$((i+1)) ;;
    esac
  done
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  pmctl_worktree_ensure_state_paths "$repo_root" || return $?
  pmctl_worktree_ensure_writer "$repo_root" || return $?

  local manifest_content now_epoch max_age_seconds
  manifest_content="$(cd "$work_dir" 2>/dev/null && pmctl_worktree_manifest_read)" || true
  [[ -n "$manifest_content" ]] || { printf 'gc: no registered worktrees\n'; return 0; }
  now_epoch="$(date +%s 2>/dev/null || echo 0)"
  max_age_seconds=$(( max_age_days * 86400 ))

  local kept_lines="" removed_count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    local slug branch path created_ts age_seconds should_remove=0 reason=""
    slug="$(jq -r '.slug' <<<"$line")"
    branch="$(jq -r '.branch' <<<"$line")"
    path="$(jq -r '.path' <<<"$line")"
    created_ts="$(jq -r '.created_ts' <<<"$line")"

    if [[ ! -d "$path" ]]; then
      should_remove=1; reason="path missing (orphaned manifest entry)"
    elif ! (cd "$work_dir" && git worktree list --porcelain 2>/dev/null | grep -q "^worktree $path\$"); then
      should_remove=1; reason="git no longer tracks this worktree"
    elif [[ "$merged_only" -eq 1 ]] && (cd "$work_dir" && git branch --merged 2>/dev/null | grep -qE "^[*+ ]+$branch\$"); then
      should_remove=1; reason="branch merged"
    elif [[ "$max_age_days" -gt 0 ]]; then
      local created_epoch
      created_epoch="$(date -d "$created_ts" +%s 2>/dev/null || date -jf '%Y-%m-%dT%H:%M:%S' "${created_ts%%[+-]*}" +%s 2>/dev/null || echo "$now_epoch")"
      age_seconds=$(( now_epoch - created_epoch ))
      if [[ "$age_seconds" -ge "$max_age_seconds" ]]; then
        should_remove=1; reason="older than $max_age_days day(s)"
      fi
    fi

    if [[ "$should_remove" -eq 1 ]]; then
      removed_count=$((removed_count+1))
      if [[ "$dry_run" -eq 1 ]]; then
        printf 'would remove %s (%s): %s\n' "$slug" "$path" "$reason"
      else
        printf 'removing %s (%s): %s\n' "$slug" "$path" "$reason"
        if [[ -d "$path" ]]; then
          (cd "$work_dir" && git worktree remove --force "$path") 2>/dev/null || true
        fi
      fi
    else
      kept_lines="${kept_lines}${line}"$'\n'
    fi
  done <<<"$manifest_content"

  (cd "$work_dir" && git worktree prune) 2>/dev/null || true

  if [[ "$dry_run" -eq 0 ]]; then
    (cd "$work_dir" && pmctl_worktree_manifest_rewrite "$kept_lines") || {
      printf 'pmctl worktree gc: manifest rewrite failed after removal\n' >&2
      return 1
    }
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'gc: dry-run, would remove %d worktree(s)\n' "$removed_count"
  else
    printf 'gc: removed %d worktree(s)\n' "$removed_count"
  fi
}
