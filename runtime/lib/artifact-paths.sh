#!/usr/bin/env bash
# Single source of truth for pm-dispatch gate/dispatch artifact leaf directory names.
#
# These are the directories the gate/dispatch machinery writes into a target repo's
# work tree (.agent-trace/ .gate-briefs/ .gate-results/). They are the tooling's OWN
# output, not user source, so any worktree-integrity fingerprint must exclude them --
# otherwise a repo that has not yet had these paths gitignored is misread as having
# been mutated by a reviewer session (false prompt-injection abort).
#
# This file is the canonical artifact-leaf registry. Downstream work that relocates
# or garbage-collects these artifacts MUST extend THIS list rather than re-hardcoding
# leaf names elsewhere. Only LEAF NAMES live here; the artifact ROOT is supplied by
# the caller (today always the repo work dir, because `git status` paths are
# repo-root-relative). Keeping the root out of this file is deliberate: it lets the
# root become configurable later without touching the leaf list or the filter logic.

# Leaf directory names (repo-root-relative) that hold gate/dispatch artifacts.
PM_ARTIFACT_LEAVES=(.agent-trace .gate-briefs .gate-results)

# PM_OWN_OUTPUT_LEAVES: everything pm-dispatch writes into a target repo's work tree --
# the gate artifacts above plus the dispatch run records, the context index and the state
# directory. The dirty-tree preflight, the integrity fingerprint and the scope listings ask
# it, so a repo that never ignored these directories is not called dirty, or its reviewers
# accused of prompt injection, over pm-dispatch's own files (CC-667, CC-668).
#
# Only the generated parts of `.pm-dispatch/` are listed (`ctx/`, the context index, and
# `test-results/`, the full-suite records `pmctl ship finish` writes). The rest
# of that directory is the user's: `config`, `pre-gate.sh` and `post-gate.sh`. Excluding it
# whole would hide a reviewer-written `post-gate.sh` from the integrity check, and
# `--allow-hooks` runs that file.
#
# It is deliberately a SECOND list. `pmctl artifacts gc --all-repos` removes and
# `artifacts migrate` copies every entry of PM_ARTIFACT_LEAVES; the context index and
# the dispatch records are not gate artifacts and must never be swept by them. Add a
# directory here when pm-dispatch starts writing it into a work tree; add it to
# PM_ARTIFACT_LEAVES only when it is safe to garbage-collect.
# The context index directory, named once because the indexer writes the same entry to .gitignore.
PM_CTX_LEAF=.pm-dispatch/ctx
PM_OWN_OUTPUT_LEAVES=("${PM_ARTIFACT_LEAVES[@]}" .dispatch-results "$PM_CTX_LEAF" .pm-dispatch/test-results .pm-dispatch-state)

# artifact_gitignore_covers <gitignore-file> <pattern>
#
# Succeeds when the file has a line that ignores <pattern> or one of its parent directories,
# bare or with a trailing slash. The one place that decides "already ignored" for the context
# indexer, `pmctl ship finish` and (through them) every .gitignore pm-dispatch patches.
artifact_gitignore_covers() {
  local file="$1" p="$2" line
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    local q="$p"
    while :; do
      [[ "$line" == "$q" || "$line" == "$q/" ]] && return 0
      [[ "$q" == */* ]] || break
      q="${q%/*}"
    done
  done < "$file"
  return 1
}

# artifact_path_is_artifact <repo-relative-path>
#
# Succeeds when the path is one of the own-output directories above or lies under one.
# The single place that decides it: the porcelain filter below, the subject fingerprint and
# the scope expansion all ask here instead of repeating the leaf names.
artifact_path_is_artifact() {
  local path="$1" leaf
  for leaf in "${PM_OWN_OUTPUT_LEAVES[@]}"; do
    if [[ "$path" == "$leaf" || "$path" == "$leaf/"* ]]; then
      return 0
    fi
  done
  return 1
}

# artifact_status_porcelain
#
# `git status --porcelain -z` for the integrity fingerprint, with pm-dispatch's own output
# excluded by pathspec. The pathspec is what makes the fingerprint stable: without it git folds
# a directory holding only untracked files into one `?? <dir>/` record, and a path filter on the
# output cannot see inside it. With only `.pm-dispatch/ctx` present the result is empty; a user
# file next to it (a hook a reviewer wrote) leaves a `?? .pm-dispatch/` record, so the change
# is seen. Pipe the result through artifact_filter_porcelain as before.
artifact_status_porcelain() {
  git status --porcelain -z -- "${PM_ARTIFACT_EXCLUDE_PATHSPECS[@]}"
}

# PM_HOOK_FILES: the repo-local scripts `--allow-hooks` executes. A reviewer that writes one gets it
# run with the operator's rights, so the integrity check reads them directly (artifact_hook_state)
# instead of relying on git to report them: a repo whose .gitignore still ignores all of
# `.pm-dispatch/` (older pm-dispatch versions wrote that line) would otherwise never show the change.
PM_HOOK_FILES=(.pm-dispatch/pre-gate.sh .pm-dispatch/post-gate.sh)

# artifact_hook_state
#
# One block per PM_HOOK_FILES entry, relative to the current directory: the file's bytes, the
# target of a symlink, or "absent". Meant to be hashed together with the porcelain status.
artifact_hook_state() {
  local hook
  for hook in "${PM_HOOK_FILES[@]}"; do
    if [[ -L "$hook" ]]; then
      printf 'hook %s -> %s\n' "$hook" "$(readlink "$hook")"
    elif [[ -f "$hook" ]]; then
      printf 'hook %s\n' "$hook"
      cat -- "$hook"
      printf '\n'
    else
      printf 'hook %s absent\n' "$hook"
    fi
  done
}

# artifact_integrity_snapshot
#
# The stream the gate hashes before dispatch, after dispatch and after synthesis: the work
# tree's changed paths (own output excluded) followed by the hook files' state. Run it in the
# work tree; hash its output.
artifact_integrity_snapshot() {
  artifact_status_porcelain | artifact_filter_porcelain
  artifact_hook_state
}

# artifact_filter_porcelain
#
# Reads a NUL-delimited `git status --porcelain -z` stream on stdin and re-emits,
# NUL-delimited, only the records whose path does NOT fall under any artifact leaf
# directory. The result is a stable fingerprint input that ignores the gate's own
# artifacts while preserving every real source change.
#
# NUL-delimited (`-z`) input is mandatory: a line-based filter corrupts on paths
# containing spaces, quotes, or newlines. Porcelain v1 records are `XY<space>PATH`;
# rename/copy records are followed by a second bare-path record (the origin), which
# this filter evaluates independently against the same leaf rule.
artifact_filter_porcelain() {
  local rec path code expect_orig=0
  while IFS= read -r -d '' rec; do
    if [[ "$expect_orig" -eq 1 ]]; then
      # Origin path of the preceding rename/copy: a bare path, no XY prefix.
      expect_orig=0
      path="$rec"
    else
      code="${rec:0:2}"
      path="${rec:3}"
      [[ "$code" == R* || "$code" == C* ]] && expect_orig=1
    fi

    artifact_path_is_artifact "$path" || printf '%s\0' "$rec"
  done
  return 0
}

# PM_ARTIFACT_EXCLUDE_PATHSPECS
#
# The same leaf list as git pathspecs, for listings that must not see the gate's own
# output: `.` followed by one `:(exclude)<leaf>` per entry of PM_OWN_OUTPUT_LEAVES. Pass
# it after `--`. A repo that has not gitignored these paths otherwise reports the
# gate's result file as an untracked change: it entered the scope manifest's
# changed_paths as an empty reference entry, moved a committed head to a working-tree
# subject, and counted toward the dirty-tree checks (#621).
PM_ARTIFACT_EXCLUDE_PATHSPECS=(.)
for _pm_artifact_leaf in "${PM_OWN_OUTPUT_LEAVES[@]}"; do
  PM_ARTIFACT_EXCLUDE_PATHSPECS+=(":(exclude)$_pm_artifact_leaf")
done
unset _pm_artifact_leaf

# artifact_untracked_files [git ls-files options...]
#
# Non-gitignored untracked files of the current repository, without the gate's own
# artifacts. Extra options (for example -z) go to `git ls-files`.
artifact_untracked_files() {
  git ls-files --others --exclude-standard "$@" -- "${PM_ARTIFACT_EXCLUDE_PATHSPECS[@]}"
}
