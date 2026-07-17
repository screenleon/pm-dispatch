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
  local rec path code leaf drop expect_orig=0
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

    drop=0
    for leaf in "${PM_ARTIFACT_LEAVES[@]}"; do
      if [[ "$path" == "$leaf" || "$path" == "$leaf/"* ]]; then
        drop=1
        break
      fi
    done

    [[ "$drop" -eq 0 ]] && printf '%s\0' "$rec"
  done
  return 0
}
