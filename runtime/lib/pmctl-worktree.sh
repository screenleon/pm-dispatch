#!/usr/bin/env bash
# pmctl worktree create/list/remove/gc -- repo-wide git worktree registry for
# parallel multi-ticket development. Manifest is stored out-of-repo in the
# state store, keyed by the MAIN repo identity (sw_project_worktree_dir /
# state-paths.sh:_sw_worktree_project_key) so a linked worktree and its
# primary checkout resolve to the SAME partition regardless of which one the
# command is invoked from.
#
# Every subcommand resolves reg_dir ONCE, up front, via
# `sw_project_worktree_dir "$work_dir"` (a pure computation that takes an
# explicit repo_root -- no cd required). All manifest reads/writes take that
# resolved reg_dir as an explicit argument instead of re-deriving it via a
# `cd "$work_dir"` subshell each time. This matters because gc/remove can
# delete the very directory `$work_dir` points at (a linked worktree
# removing itself) -- re-deriving reg_dir afterward via cd would fail once
# that directory is gone, but the already-resolved absolute reg_dir (which
# lives in the state store, not the repo) keeps working.

pmctl_worktree_usage() {
  printf 'usage: pmctl worktree create <branch> [--from <base-branch>] [--name <slug>] [--cd <work_dir>]\n' >&2
  printf '       pmctl worktree list   [--cd <work_dir>] [--json]\n' >&2
  printf '       pmctl worktree remove <name|branch> [--force] [--cd <work_dir>]\n' >&2
  printf '       pmctl worktree gc     [--dry-run] [--merged] [--max-age-days D] [--force] [--cd <work_dir>]\n' >&2
}

pmctl_worktree_ensure_state_paths() {
  local repo_root="${1:-}"
  if [[ "$(type -t sw_project_worktree_dir 2>/dev/null)" != function ]]; then
    local _sp_lib="${repo_root:-}/runtime/lib/state-paths.sh"
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
  if [[ "$(type -t _sw_compact_json_line 2>/dev/null)" != function || "$(type -t serialize_with_lock 2>/dev/null)" != function \
        || "$(type -t _sw_ensure_store_root_safe 2>/dev/null)" != function ]]; then
    local _sw_lib="${repo_root:-}/runtime/lib/state-writer.sh"
    if [[ -r "$_sw_lib" ]]; then
      # shellcheck disable=SC1090,SC1091  # dynamic repo-root path.
      . "$_sw_lib" 2>/dev/null || true
    fi
  fi
  if [[ "$(type -t _sw_compact_json_line 2>/dev/null)" != function || "$(type -t serialize_with_lock 2>/dev/null)" != function \
        || "$(type -t _sw_ensure_store_root_safe 2>/dev/null)" != function ]]; then
    printf 'pmctl worktree: state-writer.sh unavailable; cannot write worktree manifest\n' >&2
    return 2
  fi
}

# pmctl_worktree_ensure_root_safe
# Route every worktree-registry write (manifest mkdir/mktemp, and the git
# checkout create/remove/gc perform under it) through the SAME unsafe-root
# check ("state_store_init" / "_sw_ensure_store_root_safe") that guards every
# other state-store writer -- a symlinked or non-owned PM_DISPATCH_STATE_ROOT
# leaf must be rejected here too, not just for runs/events/decisions. Must be
# called (after pmctl_worktree_ensure_writer) before ANY mkdir/mktemp/git-add
# under a resolved reg_dir.
pmctl_worktree_ensure_root_safe() {
  _sw_ensure_store_root_safe "$(_sw_store_root)"
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

# _pmctl_worktree_main_root <work_dir>
# Resolve the PRIMARY (non-worktree) checkout root for work_dir, mirroring
# state-paths.sh:_sw_main_repo_root. Used to evaluate branch --merged status
# against a STABLE reference instead of the caller's own possibly-linked-
# worktree HEAD (see pmctl_worktree_gc for why that distinction matters).
_pmctl_worktree_main_root() {
  local work_dir="$1" common_dir
  common_dir="$(git -C "$work_dir" rev-parse --git-common-dir 2>/dev/null)" || return 1
  if [[ "$common_dir" == /* ]]; then
    dirname "$common_dir"
  else
    git -C "$work_dir" rev-parse --show-toplevel 2>/dev/null
  fi
}

# _pmctl_worktree_branch_is_merged <main_root> <branch>
# Exact-match membership test against `git branch --merged` output. `git
# branch [--merged]` always prints a fixed 2-character marker column
# ("* ", "+ ", "  ") followed by the ref name, so stripping exactly 2
# characters and comparing for equality is both correct and immune to
# branch names containing regex metacharacters (a prior version matched
# via `grep -E`, so a branch named e.g. "a.b" could false-positive match
# an unrelated merged branch "axb").
_pmctl_worktree_branch_is_merged() {
  local main_root="$1" branch="$2" line
  while IFS= read -r line; do
    [[ "${line:2}" == "$branch" ]] && return 0
  done < <(git -C "$main_root" branch --merged 2>/dev/null)
  return 1
}

_pmctl_worktree_manifest_append_inner() {
  local json_line="$1" compact manifest="$2"
  compact="$(_sw_compact_json_line "$json_line")" || return $?
  printf '%s\n' "$compact" >> "$manifest"
}

# pmctl_worktree_manifest_append <reg_dir> <json_line>
pmctl_worktree_manifest_append() {
  local reg_dir="$1" json_line="$2" manifest rc=0
  mkdir -p "$reg_dir" 2>/dev/null || { printf 'pmctl worktree: mkdir failed: %s\n' "$reg_dir" >&2; return 1; }
  chmod 0700 "$reg_dir" 2>/dev/null || true
  manifest="$reg_dir/manifest.jsonl"
  serialize_with_lock "$reg_dir/manifest" _pmctl_worktree_manifest_append_inner "$json_line" "$manifest" || rc=$?
  return "$rc"
}

# _pmctl_worktree_manifest_remove_slugs_inner <reg_dir> <slug...>
# Runs under the SAME lock as append: re-reads the CURRENT manifest content
# (not a snapshot taken before acquiring the lock) and writes back only the
# entries whose slug is NOT in the removal set. Read + filter + write all
# happen inside one locked critical section, so a `create` that appends
# between an earlier (unlocked) decision-making read and this commit is
# never silently dropped -- its new slug simply isn't in the removal set,
# so it survives regardless of when it was appended relative to that
# earlier read.
_pmctl_worktree_manifest_remove_slugs_inner() {
  local reg_dir="$1" manifest="$1/manifest.jsonl" tmp current new_content slugs_json
  shift
  current=""
  [[ -f "$manifest" ]] && current="$(cat "$manifest")"
  [[ -n "$current" ]] || return 0
  slugs_json="$(printf '%s\n' "$@" | jq -R . | jq -s -c .)"
  new_content="$(printf '%s\n' "$current" | jq -c --argjson slugs "$slugs_json" \
    'select(.slug as $s | ($slugs | index($s)) == null)')"
  tmp="$(mktemp "$reg_dir/.manifest.XXXXXX")" || return 1
  printf '%s' "$new_content" > "$tmp"
  mv -f "$tmp" "$manifest"
}

# pmctl_worktree_manifest_remove_slugs <reg_dir> <slug...>
# Atomic (locked read-modify-write) removal of one or more slugs from the
# manifest. This is the ONLY way remove/gc should mutate the manifest --
# never pass a pre-filtered full-content blob to be written blind, since
# that would silently discard any entry a concurrent `create` appended
# after the caller's own (unlocked) read.
pmctl_worktree_manifest_remove_slugs() {
  local reg_dir="$1"
  shift
  [[ $# -gt 0 ]] || return 0
  mkdir -p "$reg_dir" 2>/dev/null || { printf 'pmctl worktree: mkdir failed: %s\n' "$reg_dir" >&2; return 1; }
  serialize_with_lock "$reg_dir/manifest" _pmctl_worktree_manifest_remove_slugs_inner "$reg_dir" "$@"
}

# pmctl_worktree_manifest_read <reg_dir>
pmctl_worktree_manifest_read() {
  local reg_dir="$1" manifest="$1/manifest.jsonl"
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
        [[ -n "$work_dir" ]] || { printf 'pmctl worktree create: --cd requires a directory\n' >&2; return 2; }
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
  pmctl_worktree_ensure_root_safe || return 1

  local slug
  slug="$(_pmctl_worktree_slugify "${name:-$branch}")" || return 1

  local reg_dir wt_path
  reg_dir="$(sw_project_worktree_dir "$work_dir")" || {
    printf 'pmctl worktree create: cannot resolve worktree registry dir from %s\n' "$work_dir" >&2
    return 1
  }
  wt_path="$reg_dir/checkouts/$slug"

  if [[ -e "$wt_path" ]]; then
    printf 'pmctl worktree create: a worktree already exists at %s (slug %s in use)\n' "$wt_path" "$slug" >&2
    return 1
  fi
  # `-Fxq` (fixed-string, whole-line match) -- NOT `grep -q "^worktree $path\$"`.
  # A path is arbitrary data (PM_DISPATCH_STATE_ROOT can contain regex
  # metacharacters like `[`), so treating it as a regex pattern can silently
  # misclassify a tracked path as untracked or vice versa.
  if git -C "$work_dir" worktree list --porcelain 2>/dev/null | grep -Fxq "worktree $wt_path"; then
    printf 'pmctl worktree create: git already tracks a worktree at %s\n' "$wt_path" >&2
    return 1
  fi
  # A manifest entry can outlive its checkout (manual `rm -rf` + `git
  # worktree prune` without going through `pmctl worktree remove`/`gc`
  # first) -- the two checks above only see live filesystem/git state, so
  # they would miss that stale registration and let this same slug get
  # appended a second time. Check the manifest itself too.
  if [[ -n "$(pmctl_worktree_manifest_read "$reg_dir" | jq -c --arg s "$slug" 'select(.slug == $s)' | head -1)" ]]; then
    printf 'pmctl worktree create: slug %s is already registered in the manifest (stale entry? run '\''pmctl worktree gc'\'' first)\n' "$slug" >&2
    return 1
  fi

  mkdir -p "$reg_dir/checkouts" 2>/dev/null || true

  local git_args=(worktree add)
  if [[ -n "$base" ]]; then
    git_args+=(-b "$branch" "$wt_path" "$base")
  elif git -C "$work_dir" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    git_args+=("$wt_path" "$branch")
  else
    git_args+=(-b "$branch" "$wt_path")
  fi

  # `git worktree add` prints progress chatter (e.g. "Preparing worktree...",
  # "HEAD is now at ...") to stdout; redirect it to stderr so this function's
  # stdout contract stays exactly one line (the worktree path) for callers
  # that capture it directly.
  if ! git -C "$work_dir" "${git_args[@]}" 1>&2; then
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
  if ! pmctl_worktree_manifest_append "$reg_dir" "$json_line"; then
    # gc reconciles EXISTING manifest entries against git/filesystem state --
    # it cannot discover a worktree that never got a manifest entry in the
    # first place, so this is not gc-recoverable. Surface it as a failure
    # (not a warning) and point at the manual recovery path instead.
    printf 'pmctl worktree create: worktree created at %s but manifest registration failed -- it will not appear in '\''pmctl worktree list/gc'\''. Run '\''git worktree remove %s'\'' to discard it, or retry '\''pmctl worktree create'\'' after fixing the manifest write error above.\n' "$wt_path" "$wt_path" >&2
    printf '%s\n' "$wt_path"
    return 1
  fi
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
      --cd)
        work_dir="${args[$((i+1))]:-}"
        [[ -n "$work_dir" ]] || { printf 'pmctl worktree list: --cd requires a directory\n' >&2; return 2; }
        i=$((i+2))
        ;;
      --json) json_out=1; i=$((i+1)) ;;
      -h|--help) pmctl_worktree_usage; return 0 ;;
      *) i=$((i+1)) ;;
    esac
  done
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  pmctl_worktree_ensure_state_paths "$repo_root" || return $?

  local reg_dir manifest_content
  reg_dir="$(sw_project_worktree_dir "$work_dir")" || true
  manifest_content="$(pmctl_worktree_manifest_read "$reg_dir")"

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
      --cd)
        work_dir="${args[$((i+1))]:-}"
        [[ -n "$work_dir" ]] || { printf 'pmctl worktree remove: --cd requires a directory\n' >&2; return 2; }
        i=$((i+2))
        ;;
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
  pmctl_worktree_ensure_root_safe || return 1

  local reg_dir manifest_content match_line match_path match_slug
  reg_dir="$(sw_project_worktree_dir "$work_dir")" || {
    printf 'pmctl worktree remove: cannot resolve worktree registry dir from %s\n' "$work_dir" >&2
    return 1
  }
  manifest_content="$(pmctl_worktree_manifest_read "$reg_dir")"
  match_line="$(printf '%s\n' "$manifest_content" | jq -c --arg t "$target" 'select(.slug == $t or .branch == $t)' | head -1)"
  if [[ -z "$match_line" ]]; then
    printf 'pmctl worktree remove: no registered worktree matches %s\n' "$target" >&2
    return 1
  fi
  match_path="$(jq -r '.path' <<<"$match_line")"
  match_slug="$(jq -r '.slug' <<<"$match_line")"

  local git_rm_args=(worktree remove)
  [[ "$force" -eq 1 ]] && git_rm_args+=(--force)
  git_rm_args+=("$match_path")
  if [[ -d "$match_path" ]]; then
    if ! git -C "$work_dir" "${git_rm_args[@]}"; then
      printf 'pmctl worktree remove: git worktree remove failed for %s (dirty? pass --force to override)\n' "$match_path" >&2
      return 1
    fi
  fi
  git -C "$work_dir" worktree prune 2>/dev/null || true

  if ! pmctl_worktree_manifest_remove_slugs "$reg_dir" "$match_slug"; then
    printf 'pmctl worktree remove: worktree removed but manifest cleanup failed for slug %s -- run '\''pmctl worktree gc'\'' to reconcile\n' "$match_slug" >&2
    return 1
  fi
  printf 'removed %s (%s)\n' "$target" "$match_path"
}

pmctl_worktree_gc() {
  local repo_root="${1:-}" work_dir dry_run=0 merged_only=0 max_age_days=0 force=0 args=()
  shift || true
  work_dir="${1:-$repo_root}"
  shift || true
  args=("$@")
  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --dry-run) dry_run=1; i=$((i+1)) ;;
      --merged) merged_only=1; i=$((i+1)) ;;
      --force) force=1; i=$((i+1)) ;;
      --max-age-days)
        max_age_days="${args[$((i+1))]:-0}"
        if ! [[ "$max_age_days" =~ ^[0-9]+$ ]]; then
          printf 'pmctl worktree gc: --max-age-days requires an integer >= 0\n' >&2
          return 2
        fi
        i=$((i+2))
        ;;
      --cd)
        work_dir="${args[$((i+1))]:-}"
        [[ -n "$work_dir" ]] || { printf 'pmctl worktree gc: --cd requires a directory\n' >&2; return 2; }
        i=$((i+2))
        ;;
      -h|--help) pmctl_worktree_usage; return 0 ;;
      *) i=$((i+1)) ;;
    esac
  done
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  pmctl_worktree_ensure_state_paths "$repo_root" || return $?
  pmctl_worktree_ensure_writer "$repo_root" || return $?
  pmctl_worktree_ensure_root_safe || return 1

  local reg_dir manifest_content now_epoch max_age_seconds main_root
  reg_dir="$(sw_project_worktree_dir "$work_dir")" || {
    printf 'pmctl worktree gc: cannot resolve worktree registry dir from %s\n' "$work_dir" >&2
    return 1
  }
  manifest_content="$(pmctl_worktree_manifest_read "$reg_dir")"
  [[ -n "$manifest_content" ]] || { printf 'gc: no registered worktrees\n'; return 0; }
  now_epoch="$(date +%s 2>/dev/null || echo 0)"
  max_age_seconds=$(( max_age_days * 86400 ))
  # --merged must be evaluated against the PRIMARY checkout's HEAD, not
  # work_dir's own HEAD: a branch is trivially "merged into itself", so if
  # work_dir is itself a linked worktree, `git branch --merged` run there
  # would flag the worktree's own checked-out branch as removable.
  main_root="$(_pmctl_worktree_main_root "$work_dir")" || main_root="$work_dir"

  local removed_slugs=() removed_count=0 skipped_dirty=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    local slug branch path created_ts age_seconds should_remove=0 reason="" destructive=0
    slug="$(jq -r '.slug' <<<"$line")"
    branch="$(jq -r '.branch' <<<"$line")"
    path="$(jq -r '.path' <<<"$line")"
    created_ts="$(jq -r '.created_ts' <<<"$line")"

    if [[ ! -d "$path" ]]; then
      should_remove=1; reason="path missing (orphaned manifest entry)"
    elif ! git -C "$work_dir" worktree list --porcelain 2>/dev/null | grep -Fxq "worktree $path"; then
      # `-Fxq`, not a regex `grep -q "^worktree $path\$"`: $path is data (a
      # symlink-free but otherwise arbitrary filesystem path derived from
      # PM_DISPATCH_STATE_ROOT), and this decision gates a `git worktree
      # remove --force` a few lines below -- a false "no longer tracked"
      # here force-deletes a still-live, possibly dirty worktree.
      should_remove=1; reason="git no longer tracks this worktree"
    elif [[ "$merged_only" -eq 1 ]] && _pmctl_worktree_branch_is_merged "$main_root" "$branch"; then
      should_remove=1; destructive=1; reason="branch merged"
    elif [[ "$max_age_days" -gt 0 ]]; then
      local created_epoch
      # Strip only the trailing timezone offset (the LAST +/- in the string,
      # via the shortest-suffix-match `%` form) before handing to BSD/macOS
      # `date -jf`, which has no offset syntax. Using the greedy `%%` form
      # here was a bug: it strips from the FIRST `-` in the string, which
      # for an ISO timestamp is inside the date portion itself
      # ("2026-07-02T..." -> greedy strip left only "2026").
      created_epoch="$(date -d "$created_ts" +%s 2>/dev/null || date -jf '%Y-%m-%dT%H:%M:%S' "${created_ts%[+-]*}" +%s 2>/dev/null || echo "$now_epoch")"
      age_seconds=$(( now_epoch - created_epoch ))
      if [[ "$age_seconds" -ge "$max_age_seconds" ]]; then
        should_remove=1; destructive=1; reason="older than $max_age_days day(s)"
      fi
    fi

    if [[ "$should_remove" -eq 1 ]]; then
      if [[ "$dry_run" -eq 1 ]]; then
        removed_count=$((removed_count+1))
        printf 'would remove %s (%s): %s\n' "$slug" "$path" "$reason"
        continue
      fi
      if [[ "$destructive" -eq 1 && -d "$path" ]]; then
        # merged/age-based reasons touch a LIVE worktree that may have
        # uncommitted changes -- default to git's own dirty-worktree
        # refusal (same as `remove` without --force) unless the caller
        # explicitly opted into `gc --force`.
        local rm_args=(worktree remove)
        [[ "$force" -eq 1 ]] && rm_args+=(--force)
        rm_args+=("$path")
        if ! git -C "$work_dir" "${rm_args[@]}" 2>/dev/null; then
          printf 'skipping %s (%s): has uncommitted changes -- pass gc --force to remove anyway\n' "$slug" "$path"
          skipped_dirty=$((skipped_dirty+1))
          continue
        fi
      elif [[ -d "$path" ]]; then
        # orphaned / no-longer-tracked reasons: nothing live to lose, safe
        # to force since git already doesn't consider this a real worktree.
        git -C "$work_dir" worktree remove --force "$path" 2>/dev/null || true
      fi
      removed_count=$((removed_count+1))
      removed_slugs+=("$slug")
      printf 'removed %s (%s): %s\n' "$slug" "$path" "$reason"
    fi
  done <<<"$manifest_content"

  git -C "$work_dir" worktree prune 2>/dev/null || true

  if [[ "$dry_run" -eq 0 && "${#removed_slugs[@]}" -gt 0 ]]; then
    # Commits the removal atomically against the CURRENT manifest (see
    # pmctl_worktree_manifest_remove_slugs) -- any worktree a concurrent
    # `create` registered after the read at the top of this function is
    # NOT in removed_slugs, so it survives this write even though our
    # should_remove decisions above were made from a stale snapshot.
    pmctl_worktree_manifest_remove_slugs "$reg_dir" "${removed_slugs[@]}" || {
      printf 'pmctl worktree gc: manifest cleanup failed after removal -- some removed worktrees may still be listed; re-run '\''pmctl worktree gc'\'' to reconcile\n' >&2
      return 1
    }
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'gc: dry-run, would remove %d worktree(s)\n' "$removed_count"
  else
    printf 'gc: removed %d worktree(s)' "$removed_count"
    [[ "$skipped_dirty" -gt 0 ]] && printf ', skipped %d dirty worktree(s)' "$skipped_dirty"
    printf '\n'
  fi
}
