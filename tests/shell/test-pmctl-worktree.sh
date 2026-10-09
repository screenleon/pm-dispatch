#!/usr/bin/env bash
# Regression tests for `pmctl worktree create/list/remove/gc`.
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

make_work_repo() {
  local path="$1"
  mkdir -p "$path"
  git init -q "$path"
  git -C "$path" config user.email test@example.com
  git -C "$path" config user.name test
  printf 'seed\n' > "$path/seed.txt"
  git -C "$path" add seed.txt
  git -C "$path" commit -q -m seed
}

wt_list_json() {
  local store="$1" work="$2"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree list --json --cd "$work"
}

# reg_dir_for <store> <work>
# Resolve the worktree-registry directory for a test partition, so a case
# can directly rewrite manifest.jsonl's created_ts to simulate an aged
# entry without waiting.
reg_dir_for() {
  local store="$1" work="$2"
  PM_DISPATCH_STATE_ROOT="$store" bash -c \
    '. "$1/runtime/lib/state-paths.sh" && sw_project_worktree_dir "$2"' \
    _ "$REPO_ROOT" "$work"
}

# manifest_append_raw <reg_dir> <json_line>
# Calls pmctl_worktree_manifest_append directly (bypassing `pmctl worktree
# create`'s git-checkout step) so a test can simulate a concurrent create's
# manifest write landing at a precise point in another operation's sequence.
manifest_append_raw() {
  local reg_dir="$1" json_line="$2"
  bash -c '
    repo_root="$1"; reg_dir="$2"; json_line="$3"
    . "$repo_root/runtime/lib/portable.sh"
    . "$repo_root/runtime/lib/state-writer.sh"
    . "$repo_root/runtime/lib/pmctl-worktree.sh"
    pmctl_worktree_manifest_append "$reg_dir" "$json_line"
  ' _ "$REPO_ROOT" "$reg_dir" "$json_line"
}

# manifest_remove_slugs_raw <reg_dir> <slug...>
# Calls pmctl_worktree_manifest_remove_slugs directly -- the same locked
# read-modify-write primitive `remove`/`gc` commit through.
manifest_remove_slugs_raw() {
  local reg_dir="$1"
  shift
  bash -c '
    repo_root="$1"; reg_dir="$2"; shift 2
    . "$repo_root/runtime/lib/portable.sh"
    . "$repo_root/runtime/lib/state-writer.sh"
    . "$repo_root/runtime/lib/pmctl-worktree.sh"
    pmctl_worktree_manifest_remove_slugs "$reg_dir" "$@"
  ' _ "$REPO_ROOT" "$reg_dir" "$@"
}

case_create_requires_branch() {
  # behavior: pmctl worktree create with no <branch> arg exits 2 and prints usage
  # Steps: run create with only --cd; assert exit 2, stderr has "<branch> is required" and "usage:"
  local name="worktree create: missing <branch> exits 2 with usage"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-create-noarg"
  work="$tmp_root/work-create-noarg"
  make_work_repo "$work"
  out="$tmp_root/c1.out"; err="$tmp_root/c1.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"<branch> is required"* && "$(<"$err")" == *"usage:"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_create_new_branch() {
  # behavior: create with a branch name that doesn't exist yet creates the branch + worktree + manifest entry
  # Steps: run create feat/x; assert exit 0, printed path is a directory, manifest has branch feat/x
  local name="worktree create: new branch creates worktree + manifest entry"
  should_run "$name" || return 0
  local store work out err status=0 wt_path
  store="$tmp_root/state-create-new"
  work="$tmp_root/work-create-new"
  make_work_repo "$work"
  out="$tmp_root/c2.out"; err="$tmp_root/c2.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/x --cd "$work" > "$out" 2> "$err" || status=$?
  wt_path="$(tail -1 "$out")"
  if [[ "$status" -eq 0 && -d "$wt_path" ]] \
     && [[ "$(wt_list_json "$store" "$work" | jq -r '.[0].branch')" == "feat/x" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_create_stdout_single_line_path() {
  # behavior: create's stdout is exactly one line (the worktree path); git's
  # own progress chatter (e.g. "Preparing worktree...") must not leak into it
  # Steps: create feat/y with --from (a path that reliably makes git print
  # chatter); assert stdout has exactly 1 line equal to the printed path
  local name="worktree create: stdout contract is exactly one line (the path)"
  should_run "$name" || return 0
  local store work out err status=0 line_count wt_path
  store="$tmp_root/state-create-stdout"
  work="$tmp_root/work-create-stdout"
  make_work_repo "$work"
  git -C "$work" branch base-branch
  out="$tmp_root/c-stdout.out"; err="$tmp_root/c-stdout.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/y --from base-branch --cd "$work" > "$out" 2> "$err" || status=$?
  line_count="$(wc -l < "$out" | tr -d ' ')"
  wt_path="$(<"$out")"
  if [[ "$status" -eq 0 && "$line_count" -eq 1 && -d "$wt_path" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status line_count=$line_count out=$(<"$out") err=$(<"$err")"
  fi
}

case_create_from_base() {
  # behavior: create --from <base> creates the new branch off the given base commit, not HEAD
  # Steps: create a base-branch pointer; create feat/from-base --from base-branch; assert its HEAD sha == base sha
  local name="worktree create: --from creates a new branch off the given base"
  should_run "$name" || return 0
  local store work out err status=0 wt_path base_sha branch_sha
  store="$tmp_root/state-create-from"
  work="$tmp_root/work-create-from"
  make_work_repo "$work"
  git -C "$work" branch base-branch
  out="$tmp_root/c3.out"; err="$tmp_root/c3.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/from-base --from base-branch --cd "$work" > "$out" 2> "$err" || status=$?
  wt_path="$(tail -1 "$out")"
  base_sha="$(git -C "$work" rev-parse base-branch)"
  branch_sha="$(git -C "$wt_path" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$status" -eq 0 && "$branch_sha" == "$base_sha" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status base_sha=$base_sha branch_sha=$branch_sha err=$(<"$err")"
  fi
}

case_create_existing_branch_no_new_ref() {
  # behavior: create on a branch that already exists attaches to it instead of erroring or creating a duplicate ref
  # Steps: create a local branch; run create <that branch>; assert exit 0 and no "already exists" error
  local name="worktree create: existing branch attaches without creating a duplicate ref"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-create-existing"
  work="$tmp_root/work-create-existing"
  make_work_repo "$work"
  git -C "$work" branch existing-branch
  out="$tmp_root/c4.out"; err="$tmp_root/c4.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create existing-branch --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 && "$(<"$err")" != *"already exists"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_create_name_override_slug() {
  # behavior: create --name <slug> overrides the default branch-derived manifest slug
  # Steps: run create feat/named --name custom-slug; assert the manifest's slug field is custom-slug
  local name="worktree create: --name overrides the manifest slug"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-create-name"
  work="$tmp_root/work-create-name"
  make_work_repo "$work"
  out="$tmp_root/c5.out"; err="$tmp_root/c5.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/named --name custom-slug --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 && "$(wt_list_json "$store" "$work" | jq -r '.[0].slug')" == "custom-slug" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_create_duplicate_slug_rejected() {
  # behavior: create with a slug that is already registered fails and does not add a second manifest entry
  # Steps: create feat/dup twice; assert first succeeds, second fails with "already exists", manifest has exactly 1 entry
  local name="worktree create: duplicate slug is rejected, no duplicate manifest entry"
  should_run "$name" || return 0
  local store work err1 err2 status1=0 status2=0
  store="$tmp_root/state-create-dup"
  work="$tmp_root/work-create-dup"
  make_work_repo "$work"
  err1="$tmp_root/c6a.err"; err2="$tmp_root/c6b.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/dup --cd "$work" > /dev/null 2> "$err1" || status1=$?
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/dup --cd "$work" > /dev/null 2> "$err2" || status2=$?
  if [[ "$status1" -eq 0 && "$status2" -ne 0 && "$(<"$err2")" == *"already exists"* \
        && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status1=$status1 status2=$status2 err2=$(<"$err2")"
  fi
}

case_create_stale_manifest_duplicate_slug_rejected() {
  # behavior: create rejects a slug that is still registered in the manifest even when the checkout was
  #           deleted and pruned OUTSIDE pmctl (rm -rf + git worktree prune, bypassing `remove`/`gc`) --
  #           the live-path and git-worktree-list checks alone would miss this and append a duplicate row
  # Steps: create feat/stale, then rm -rf its directory and `git worktree prune` directly (not via pmctl);
  #        run create feat/stale again; assert it is rejected and the manifest still has exactly 1 entry
  local name="worktree create: stale manifest entry blocks recreating the same slug"
  should_run "$name" || return 0
  local store work wt_path err status=0
  store="$tmp_root/state-create-stale"
  work="$tmp_root/work-create-stale"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/stale --cd "$work" 2>/dev/null | tail -1)"
  rm -rf "$wt_path"
  git -C "$work" worktree prune
  err="$tmp_root/c9.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/stale --cd "$work" > /dev/null 2> "$err" || status=$?
  if [[ "$status" -ne 0 && "$(<"$err")" == *"already registered"* \
        && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err") count=$(wt_list_json "$store" "$work" | jq 'length')"
  fi
}

case_create_rejects_unsafe_symlinked_state_root() {
  # behavior: worktree writes (manifest mkdir, checkout creation) are rejected when PM_DISPATCH_STATE_ROOT
  #           itself is a symlink, mirroring the same unsafe-root policy other state-store writers enforce
  # Steps: point PM_DISPATCH_STATE_ROOT at a symlink to a real directory; run create; assert nonzero exit
  #        and stderr mentions the unsafe-root rejection, and nothing was created under the symlink target
  local name="worktree create: rejects a symlinked PM_DISPATCH_STATE_ROOT"
  should_run "$name" || return 0
  th_require_symlinks "$name" || return 0
  local work real_target link err status=0
  work="$tmp_root/work-create-unsafe-root"
  make_work_repo "$work"
  real_target="$tmp_root/unsafe-root-real"
  mkdir -p "$real_target"
  link="$tmp_root/unsafe-root-link"
  ln -s "$real_target" "$link"
  err="$tmp_root/c10.err"
  PM_DISPATCH_STATE_ROOT="$link" "$PMCTL" worktree create feat/unsafe-root --cd "$work" > /dev/null 2> "$err" || status=$?
  if [[ "$status" -ne 0 && "$(<"$err")" == *"unsafe state root rejected"* \
        && -z "$(find "$real_target" -mindepth 1 2>/dev/null)" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_create_unsafe_slug_rejected() {
  # behavior: a branch name that slugifies to an unsafe segment (e.g. "..") is rejected before touching git
  # Steps: run create '..'; assert non-zero exit and stderr mentions "safe slug"
  local name="worktree create: a branch slug of '..' is rejected before touching git"
  should_run "$name" || return 0
  local store work err status=0
  store="$tmp_root/state-create-unsafe"
  work="$tmp_root/work-create-unsafe"
  make_work_repo "$work"
  err="$tmp_root/c7.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create '..' --cd "$work" > /dev/null 2> "$err" || status=$?
  if [[ "$status" -ne 0 && "$(<"$err")" == *"safe slug"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_create_help() {
  # behavior: create -h prints usage and exits 0 without creating anything
  # Steps: run create -h; assert exit 0 and stderr contains "usage:"
  local name="worktree create: -h prints usage and exits 0"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-create-help"
  work="$tmp_root/work-create-help"
  make_work_repo "$work"
  out="$tmp_root/c8.out"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create -h --cd "$work" > /dev/null 2> "$out" || status=$?
  if [[ "$status" -eq 0 && "$(<"$out")" == *"usage:"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_create_missing_cd_value() {
  # behavior: create --cd with no following operand exits 2 instead of silently falling back to the
  #           invoking pmctl's own repo (a malformed --cd must never resolve to a default target --
  #           that default could be the wrong repo for a command that creates a checkout)
  # Steps: run create feat/x --cd (no value after --cd, nothing else follows); assert exit 2 and
  #        stderr says --cd requires a directory
  local name="worktree create: missing --cd operand exits 2 instead of defaulting to another repo"
  should_run "$name" || return 0
  local err status=0
  err="$tmp_root/cdmiss1.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state-cd-missing-guard" "$PMCTL" worktree create feat/x --cd > /dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"--cd requires a directory"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_list_missing_cd_value() {
  # behavior: list --cd with no following operand exits 2 instead of silently defaulting
  # Steps: run list --cd (no value); assert exit 2 and stderr says --cd requires a directory
  local name="worktree list: missing --cd operand exits 2 instead of defaulting to another repo"
  should_run "$name" || return 0
  local err status=0
  err="$tmp_root/cdmiss2.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state-cd-missing-guard" "$PMCTL" worktree list --cd > /dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"--cd requires a directory"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_remove_missing_cd_value() {
  # behavior: remove --cd with no following operand exits 2 BEFORE any destructive git/manifest
  #           operation, instead of silently defaulting to another repo's worktree registry
  # Steps: run remove sometarget --cd (no value); assert exit 2 and stderr says --cd requires a directory
  local name="worktree remove: missing --cd operand exits 2 instead of defaulting to another repo"
  should_run "$name" || return 0
  local err status=0
  err="$tmp_root/cdmiss3.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state-cd-missing-guard" "$PMCTL" worktree remove sometarget --cd > /dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"--cd requires a directory"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_gc_missing_cd_value() {
  # behavior: gc --cd with no following operand exits 2 BEFORE any destructive git/manifest
  #           operation, instead of silently defaulting to another repo's worktree registry
  # Steps: run gc --cd (no value); assert exit 2 and stderr says --cd requires a directory
  local name="worktree gc: missing --cd operand exits 2 instead of defaulting to another repo"
  should_run "$name" || return 0
  local err status=0
  err="$tmp_root/cdmiss4.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state-cd-missing-guard" "$PMCTL" worktree gc --cd > /dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"--cd requires a directory"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_list_empty() {
  # behavior: list on an empty registry prints a human-readable "no worktrees" message
  # Steps: run list on a fresh repo with no registered worktrees; assert output contains "No registered worktrees."
  local name="worktree list: empty registry prints no-worktrees message"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-list-empty"
  work="$tmp_root/work-list-empty"
  make_work_repo "$work"
  out="$tmp_root/l1.out"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree list --cd "$work" > "$out" 2>&1 || status=$?
  if [[ "$status" -eq 0 && "$(<"$out")" == *"No registered worktrees."* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_list_json_valid() {
  # behavior: list --json prints a valid JSON array with one element per registered worktree
  # Steps: create one worktree; run list --json; assert output type is array with length 1
  local name="worktree list: --json prints a valid JSON array"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-list-json"
  work="$tmp_root/work-list-json"
  make_work_repo "$work"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/j --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && "$(wt_list_json "$store" "$work" | jq 'type')" == '"array"' \
        && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status"
  fi
}

case_list_text_table() {
  # behavior: list (no --json) prints a human-readable SLUG/BRANCH/PATH table
  # Steps: create one worktree; run list; assert header row has SLUG/BRANCH/PATH and a data row has the branch
  local name="worktree list: text mode prints a SLUG/BRANCH/PATH table"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-list-text"
  work="$tmp_root/work-list-text"
  make_work_repo "$work"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/t --cd "$work" > /dev/null 2>&1
  out="$tmp_root/l3.out"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree list --cd "$work" > "$out" 2>&1 || status=$?
  if [[ "$status" -eq 0 && "$(sed -n '1p' "$out")" == *SLUG*BRANCH*PATH* && "$(sed -n '2p' "$out")" == *"feat/t"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_list_cross_worktree_identity() {
  # behavior: list invoked with --cd pointing INSIDE a linked worktree resolves the same manifest partition
  #           as the primary checkout (the identity seam this whole feature depends on)
  # Steps: create a worktree from the primary checkout; run list --json --cd <that worktree's own path>;
  #        assert it sees the same entry it was just registered under
  local name="worktree list: invoked from inside a linked worktree sees the same manifest"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state-list-identity"
  work="$tmp_root/work-list-identity"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/identity --cd "$work" 2>/dev/null | tail -1)"
  local inside_json
  inside_json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree list --json --cd "$wt_path" 2>/dev/null)" || status=$?
  if [[ "$status" -eq 0 && "$(jq -r '.[0].branch' <<<"$inside_json")" == "feat/identity" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status inside_json=$inside_json"
  fi
}

case_main_root_from_linked_worktree() {
  # behavior: _pmctl_worktree_main_root gives a linked worktree the same main-checkout root as the
  #           primary checkout (native Windows git prints a drive-letter common dir there -- CC-601)
  # Steps: make a repo + a real linked worktree, source the lib directly (no state store needed),
  #        resolve the root from both, compare with git's own toplevel of the primary checkout
  local name="worktree main root: a linked worktree resolves to the primary checkout"
  should_run "$name" || return 0
  local work linked expected from_main from_linked
  work="$tmp_root/work-main-root"
  linked="$tmp_root/linked-main-root"
  make_work_repo "$work"
  git -C "$work" worktree add -q --detach "$linked" HEAD
  expected="$(git -C "$work" rev-parse --show-toplevel)"
  # Sourced WITHOUT portable.sh first: the lib must load its own dependency.
  from_main="$(bash -c '. "$1/runtime/lib/pmctl-worktree.sh"; _pmctl_worktree_main_root "$2"' _ "$REPO_ROOT" "$work")" || from_main=""
  from_linked="$(bash -c '. "$1/runtime/lib/pmctl-worktree.sh"; _pmctl_worktree_main_root "$2"' _ "$REPO_ROOT" "$linked")" || from_linked=""
  git -C "$work" worktree remove -f "$linked" || true
  if [[ -n "$expected" && "$from_main" == "$expected" && "$from_linked" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "expected=$expected primary=$from_main linked=$from_linked"
  fi
}

case_main_root_accepts_drive_letter_common_dir() {
  # behavior: _pmctl_worktree_main_root answers the parent of a drive-letter common dir on every
  #           platform (not only where native Windows git prints one), folding a backslash spelling
  # Steps: shadow git with a function answering --git-common-dir with a literal drive path, call it
  local name="worktree main root: a drive-letter common dir resolves to its parent"
  should_run "$name" || return 0
  local forward backslash
  forward="$(bash -c '
    . "$1/runtime/lib/pmctl-worktree.sh"
    git() { if [[ "$*" == *"--git-common-dir"* ]]; then printf "C:/proj/.git\n"; else command git "$@"; fi; }
    _pmctl_worktree_main_root /nonexistent-worktree' _ "$REPO_ROOT")" || forward=""
  backslash="$(bash -c '
    . "$1/runtime/lib/pmctl-worktree.sh"
    git() { if [[ "$*" == *"--git-common-dir"* ]]; then printf "C:\\\\proj\\\\.git\n"; else command git "$@"; fi; }
    _pmctl_worktree_main_root /nonexistent-worktree' _ "$REPO_ROOT")" || backslash=""
  if [[ "$forward" == "C:/proj" && "$backslash" == "C:/proj" ]]; then
    pass "$name"
  else
    fail "$name" "forward='$forward' backslash='$backslash' (both must be C:/proj)"
  fi
}

case_remove_requires_target() {
  # behavior: remove with no <name|branch> arg exits 2 and prints usage
  # Steps: run remove with only --cd; assert exit 2 and stderr has "<name|branch> is required"
  local name="worktree remove: missing <name|branch> exits 2 with usage"
  should_run "$name" || return 0
  local store work err status=0
  store="$tmp_root/state-remove-noarg"
  work="$tmp_root/work-remove-noarg"
  make_work_repo "$work"
  err="$tmp_root/r1.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree remove --cd "$work" > /dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"<name|branch> is required"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_remove_unknown_target() {
  # behavior: remove with a target that matches no manifest entry exits non-zero with a clear error
  # Steps: run remove nope on an empty registry; assert non-zero exit and stderr mentions no match found
  local name="worktree remove: unknown target exits 1"
  should_run "$name" || return 0
  local store work err status=0
  store="$tmp_root/state-remove-unknown"
  work="$tmp_root/work-remove-unknown"
  make_work_repo "$work"
  err="$tmp_root/r2.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree remove nope --cd "$work" > /dev/null 2> "$err" || status=$?
  if [[ "$status" -ne 0 && "$(<"$err")" == *"no registered worktree matches"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_remove_success() {
  # behavior: remove on a clean worktree deletes the git worktree directory and its manifest entry
  # Steps: create feat/rm; remove feat/rm; assert exit 0, directory gone, manifest empty
  local name="worktree remove: removes git worktree and manifest entry"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state-remove-ok"
  work="$tmp_root/work-remove-ok"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/rm --cd "$work" 2>/dev/null | tail -1)"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree remove feat/rm --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && ! -d "$wt_path" && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status wt_path=$wt_path exists=$([[ -d "$wt_path" ]] && echo yes || echo no)"
  fi
}

case_remove_dirty_requires_force() {
  # behavior: remove on a worktree with uncommitted changes fails without --force and succeeds with it
  # Steps: create feat/dirty, add an untracked file; remove without --force (assert fails, dir survives);
  #        remove --force (assert succeeds, dir gone)
  local name="worktree remove: dirty worktree fails without --force, succeeds with it"
  should_run "$name" || return 0
  local store work wt_path status1=0 status2=0 existed_after_first=0 existed_after_second=0
  store="$tmp_root/state-remove-dirty"
  work="$tmp_root/work-remove-dirty"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/dirty --cd "$work" 2>/dev/null | tail -1)"
  printf 'dirty\n' > "$wt_path/dirty.txt"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree remove feat/dirty --cd "$work" > /dev/null 2>&1 || status1=$?
  [[ -d "$wt_path" ]] && existed_after_first=1
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree remove feat/dirty --force --cd "$work" > /dev/null 2>&1 || status2=$?
  [[ -d "$wt_path" ]] && existed_after_second=1
  if [[ "$status1" -ne 0 && "$existed_after_first" -eq 1 && "$status2" -eq 0 && "$existed_after_second" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status1=$status1 existed_after_first=$existed_after_first status2=$status2 existed_after_second=$existed_after_second"
  fi
}

case_manifest_remove_slugs_survives_concurrent_append() {
  # behavior: pmctl_worktree_manifest_remove_slugs (the primitive remove/gc commit their removal
  #           through) reads the manifest FRESH inside its lock, so an entry appended AFTER an
  #           earlier decision-time read but BEFORE the removal commits is never silently dropped --
  #           this is the exact race pattern remove/gc go through: read manifest (unlocked, to decide
  #           what to remove) -> [a concurrent create can land here] -> commit removal (locked)
  # Steps: register A and B; take a manifest snapshot (simulating remove/gc's decision-time read);
  #        THEN append C directly (simulating a concurrent `create` landing in the race window between
  #        that read and the commit below); THEN commit removal of A via the same primitive remove/gc
  #        use; assert the final manifest has B and C but NOT A -- proving C survived even though it
  #        was appended after the snapshot the removal decision was based on
  local name="worktree manifest: concurrent create appended during a remove/gc race window survives"
  should_run "$name" || return 0
  local store work reg_dir status=0
  store="$tmp_root/state-manifest-race"
  work="$tmp_root/work-manifest-race"
  make_work_repo "$work"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/race-a --cd "$work" > /dev/null 2>&1
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/race-b --cd "$work" > /dev/null 2>&1
  reg_dir="$(reg_dir_for "$store" "$work")"

  # Simulate remove/gc's unlocked decision-time read (its content is irrelevant here -- what matters
  # is that this read happens BEFORE the concurrent append below, mirroring the real race window).
  cat "$reg_dir/manifest.jsonl" > /dev/null

  # Concurrent create landing in the race window: appends C AFTER the decision read above but
  # BEFORE the removal of A commits below.
  local race_json
  race_json="$(jq -cn --arg v race-c '{"slug":$v,"branch":"feat/race-c","path":"/tmp/race-c","created_ts":"2026-01-01T00:00:00+00:00"}')"
  manifest_append_raw "$reg_dir" "$race_json"

  # Commit removal of A via the exact same primitive remove/gc use.
  manifest_remove_slugs_raw "$reg_dir" feat-race-a > /dev/null 2>&1 || status=$?

  local final_json has_a has_b has_c
  final_json="$(wt_list_json "$store" "$work")"
  has_a="$(jq '[.[] | select(.slug=="feat-race-a")] | length' <<<"$final_json")"
  has_b="$(jq '[.[] | select(.slug=="feat-race-b")] | length' <<<"$final_json")"
  has_c="$(jq '[.[] | select(.slug=="race-c")] | length' <<<"$final_json")"
  if [[ "$status" -eq 0 && "$has_a" -eq 0 && "$has_b" -eq 1 && "$has_c" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status has_a=$has_a has_b=$has_b has_c=$has_c final=$final_json"
  fi
}

case_gc_no_worktrees() {
  # behavior: gc on an empty registry is a no-op that reports so and exits 0
  # Steps: run gc on a repo with no registered worktrees; assert exit 0 and output mentions no registered worktrees
  local name="worktree gc: empty registry is a no-op"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-gc-empty"
  work="$tmp_root/work-gc-empty"
  make_work_repo "$work"
  out="$tmp_root/g1.out"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --cd "$work" > "$out" 2>&1 || status=$?
  if [[ "$status" -eq 0 && "$(<"$out")" == *"no registered worktrees"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_gc_dry_run_no_mutation() {
  # behavior: gc --dry-run reports what it would remove but leaves the manifest untouched
  # Steps: create a worktree, delete its directory manually (orphan it); run gc --dry-run;
  #        assert output says "would remove" and the manifest still has the entry
  local name="worktree gc: --dry-run reports but does not mutate the manifest"
  should_run "$name" || return 0
  local store work wt_path out status=0
  store="$tmp_root/state-gc-dry"
  work="$tmp_root/work-gc-dry"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/gcdry --cd "$work" 2>/dev/null | tail -1)"
  rm -rf "$wt_path"
  out="$tmp_root/g2.out"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --dry-run --cd "$work" > "$out" 2>&1 || status=$?
  if [[ "$status" -eq 0 && "$(<"$out")" == *"would remove"* \
        && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_gc_removes_orphaned_manifest_entry() {
  # behavior: gc removes a manifest entry whose directory was deleted outside of pmctl (e.g. rm -rf)
  # Steps: create a worktree, delete its directory manually; run gc; assert manifest is empty afterward
  local name="worktree gc: removes a manifest entry whose path was manually deleted"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state-gc-orphan"
  work="$tmp_root/work-gc-orphan"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/orphan --cd "$work" 2>/dev/null | tail -1)"
  rm -rf "$wt_path"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status"
  fi
}

case_gc_merged_flag() {
  # behavior: gc --merged removes a clean worktree whose branch is fully merged into the primary checkout's HEAD
  # Steps: create feat/merged with no new commits (trivially merged); run gc --merged from the primary checkout;
  #        assert manifest is empty afterward
  local name="worktree gc: --merged removes worktrees whose branch is fully merged"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state-gc-merged"
  work="$tmp_root/work-gc-merged"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/merged --cd "$work" 2>/dev/null | tail -1)"
  # feat/merged has no new commits, so it is already fully merged into the base.
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --merged --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status"
  fi
}

case_gc_merged_does_not_self_remove_when_invoked_from_inside() {
  # behavior: gc --merged evaluates "merged" against the PRIMARY checkout's HEAD, not the invoking worktree's
  #           own HEAD -- so it must not treat an unmerged branch as removable just because gc was run
  #           from inside that very worktree (a branch is trivially "merged into itself")
  # Steps: create feat/self, commit something on it that master does NOT have (genuinely unmerged);
  #        run gc --merged --cd <the worktree itself>; assert the worktree and its manifest entry survive
  local name="worktree gc: --merged run from inside the linked worktree does not remove itself"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state-gc-self"
  work="$tmp_root/work-gc-self"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/self --cd "$work" 2>/dev/null | tail -1)"
  git -C "$wt_path" config user.email t@e.com
  git -C "$wt_path" config user.name t
  printf 'unmerged\n' > "$wt_path/unmerged.txt"
  git -C "$wt_path" add unmerged.txt
  git -C "$wt_path" commit -q -m unmerged
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --merged --cd "$wt_path" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && -d "$wt_path" && "$(wt_list_json "$store" "$wt_path" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status wt_path_exists=$([[ -d "$wt_path" ]] && echo yes || echo no)"
  fi
}

case_gc_merged_skips_dirty_without_force() {
  # behavior: gc --merged must not silently discard uncommitted changes -- a merged-but-dirty worktree is
  #           skipped (kept in the manifest, reported) unless the caller explicitly passes gc --force
  # Steps: create feat/dirty-merged (trivially merged), add an untracked file; run gc --merged (no --force):
  #        assert it is skipped with an "uncommitted changes" message and the directory/manifest entry survive;
  #        run gc --merged --force: assert it is now removed
  local name="worktree gc: --merged skips a dirty worktree without --force, removes it with --force"
  should_run "$name" || return 0
  local store work wt_path out status1=0 status2=0 existed_after_skip=0 existed_after_force=0
  store="$tmp_root/state-gc-dirty-merged"
  work="$tmp_root/work-gc-dirty-merged"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/dirty-merged --cd "$work" 2>/dev/null | tail -1)"
  printf 'dirty\n' > "$wt_path/dirty.txt"
  out="$tmp_root/gcd1.out"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --merged --cd "$work" > "$out" 2>&1 || status1=$?
  [[ -d "$wt_path" ]] && existed_after_skip=1
  local kept_after_skip
  kept_after_skip="$(wt_list_json "$store" "$work" | jq 'length')"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --merged --force --cd "$work" > /dev/null 2>&1 || status2=$?
  [[ -d "$wt_path" ]] && existed_after_force=1
  if [[ "$status1" -eq 0 && "$existed_after_skip" -eq 1 && "$kept_after_skip" -eq 1 && "$(<"$out")" == *"uncommitted changes"* \
        && "$status2" -eq 0 && "$existed_after_force" -eq 0 && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status1=$status1 existed_after_skip=$existed_after_skip kept_after_skip=$kept_after_skip status2=$status2 existed_after_force=$existed_after_force out=$(<"$out")"
  fi
}

case_gc_merged_exact_match_ignores_regex_metachar_collision() {
  # behavior: gc --merged uses EXACT branch-name matching, so a branch containing regex metacharacters
  #           (e.g. a literal dot) must not false-positive match an unrelated already-merged branch whose
  #           name happens to satisfy the metachar as a wildcard (a prior version used `grep -E` and a
  #           branch "a.b" would incorrectly match a merged branch literally named "axb")
  # Steps: create an unrelated already-merged plain branch "axb"; create worktree branch "a.b" and give it
  #        a commit master does not have (genuinely unmerged); run gc --merged; assert "a.b" survives
  local name="worktree gc: --merged exact-matches branch names, ignoring regex-metachar collisions"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state-gc-regex"
  work="$tmp_root/work-gc-regex"
  make_work_repo "$work"
  git -C "$work" branch axb
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create 'a.b' --cd "$work" 2>/dev/null | tail -1)"
  git -C "$wt_path" config user.email t@e.com
  git -C "$wt_path" config user.name t
  printf 'unmerged\n' > "$wt_path/unmerged.txt"
  git -C "$wt_path" add unmerged.txt
  git -C "$wt_path" commit -q -m unmerged
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --merged --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && -d "$wt_path" && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status wt_path_exists=$([[ -d "$wt_path" ]] && echo yes || echo no)"
  fi
}

case_gc_max_age_days_filters() {
  # behavior: gc --max-age-days N only removes entries older than N days; a freshly created entry is kept
  # Steps: create feat/fresh; run gc --max-age-days 30 immediately afterward; assert directory and manifest entry survive
  local name="worktree gc: --max-age-days only removes entries older than the threshold"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state-gc-age"
  work="$tmp_root/work-gc-age"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/fresh --cd "$work" 2>/dev/null | tail -1)"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --max-age-days 30 --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && -d "$wt_path" && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status"
  fi
}

case_gc_max_age_days_removes_aged_entry() {
  # behavior: gc --max-age-days N actually removes a worktree whose manifest created_ts is older than N days
  #           (case_gc_max_age_days_filters above only proves a FRESH entry survives -- this proves the
  #           destructive removal side of the same flag actually fires)
  # Steps: create feat/aged, then directly rewrite its manifest created_ts to 60 days ago; run
  #        gc --max-age-days 30; assert the directory is gone and the manifest entry is removed
  local name="worktree gc: --max-age-days removes an entry older than the threshold"
  should_run "$name" || return 0
  local store work wt_path reg_dir manifest old_ts status=0
  store="$tmp_root/state-gc-age-aged"
  work="$tmp_root/work-gc-age-aged"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/aged --cd "$work" 2>/dev/null | tail -1)"
  reg_dir="$(reg_dir_for "$store" "$work")"
  manifest="$reg_dir/manifest.jsonl"
  old_ts="$(date -d '60 days ago' -Is 2>/dev/null || date -v-60d -Is 2>/dev/null)"
  jq -c --arg ts "$old_ts" '.created_ts = $ts' "$manifest" > "$manifest.new" && mv "$manifest.new" "$manifest"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --max-age-days 30 --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && ! -d "$wt_path" && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status wt_path_exists=$([[ -d "$wt_path" ]] && echo yes || echo no)"
  fi
}

case_gc_max_age_days_bsd_fallback_parses_correctly() {
  # behavior: when `date -d` is unavailable (the BSD/macOS case), gc --max-age-days falls back to
  #           `date -jf '%Y-%m-%dT%H:%M:%S' "${created_ts%[+-]*}"` -- this must strip ONLY the trailing
  #           timezone offset, not truncate the whole ISO timestamp down to just the year (a prior `%%`
  #           greedy-strip bug did exactly that, since the date portion itself contains "-")
  # Steps: install a fake `date` on PATH that rejects `-d` (forcing the fallback branch) and re-derives
  #        the epoch for `-jf` calls via the real system date, so this test proves BOTH that the fallback
  #        branch actually executes AND that it computes the correct (not year-only) epoch; assert an
  #        aged entry is removed and a fresh entry survives under the SAME fallback-only `date`
  local name="worktree gc: --max-age-days BSD-fallback path strips only the timezone, not the whole date"
  should_run "$name" || return 0
  local store work wt_path_aged wt_path_fresh reg_dir manifest old_ts fake_bin status=0

  fake_bin="$tmp_root/fake-bsd-date-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/date" <<'EOF'
#!/usr/bin/env bash
# Fake BSD-style `date`: rejects -d (forcing callers onto the -jf fallback
# path), and implements -jf by re-deriving the epoch through the real
# system date binary -- so this stub proves the -jf branch actually ran
# with a correctly-stripped timestamp, not just that SOME epoch came out.
if [[ "$1" == "-d" ]]; then
  exit 1
fi
if [[ "$1" == "-jf" ]]; then
  shift 2
  exec /usr/bin/date -d "$1" "${@:2}"
fi
exec /usr/bin/date "$@"
EOF
  chmod +x "$fake_bin/date"

  store="$tmp_root/state-gc-age-bsd"
  work="$tmp_root/work-gc-age-bsd"
  make_work_repo "$work"
  wt_path_aged="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/bsd-aged --cd "$work" 2>/dev/null | tail -1)"
  wt_path_fresh="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/bsd-fresh --cd "$work" 2>/dev/null | tail -1)"
  reg_dir="$(reg_dir_for "$store" "$work")"
  manifest="$reg_dir/manifest.jsonl"
  old_ts="$(date -d '60 days ago' -Is)"
  jq -c --arg ts "$old_ts" --arg slug feat-bsd-aged 'if .slug == $slug then .created_ts = $ts else . end' "$manifest" \
    > "$manifest.new" && mv "$manifest.new" "$manifest"

  PATH="$fake_bin:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --max-age-days 30 --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && ! -d "$wt_path_aged" && -d "$wt_path_fresh" \
        && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status aged_exists=$([[ -d "$wt_path_aged" ]] && echo yes || echo no) fresh_exists=$([[ -d "$wt_path_fresh" ]] && echo yes || echo no)"
  fi
}

case_gc_max_age_days_rejects_non_integer() {
  # behavior: gc --max-age-days with a non-integer value is rejected with exit 2 and a documented error
  # Steps: run gc --max-age-days nope; assert exit 2 and stderr mentions the requirement
  local name="worktree gc: --max-age-days rejects a non-integer value"
  should_run "$name" || return 0
  local store work err status=0
  store="$tmp_root/state-gc-age-badarg"
  work="$tmp_root/work-gc-age-badarg"
  make_work_repo "$work"
  err="$tmp_root/gcbad.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --max-age-days nope --cd "$work" > /dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 && "$(<"$err")" == *"--max-age-days requires an integer"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_gc_prunes_git_state() {
  # behavior: gc also runs `git worktree prune` so git's own bookkeeping stays in sync with the manifest
  # Steps: create a worktree, delete its directory manually, run gc; assert `git worktree list` shows only
  #        the primary checkout afterward (no stray registered-but-gone entries)
  local name="worktree gc: leaves git's own worktree list in sync (no stray entries)"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state-gc-prune"
  work="$tmp_root/work-gc-prune"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/prune --cd "$work" 2>/dev/null | tail -1)"
  rm -rf "$wt_path"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && "$(git -C "$work" worktree list --porcelain | grep -c '^worktree ')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status"
  fi
}

case_gc_path_with_regex_metachar_not_misclassified() {
  # behavior: gc's "is this path still tracked by git" check must use fixed-string/exact matching, not
  #           regex -- the checkout path is built from PM_DISPATCH_STATE_ROOT, which is arbitrary data
  #           (not something the tool controls the syntax of), so a state root containing a regex
  #           metacharacter like `[` must not make `grep` misparse the pattern and false-negative a
  #           still-tracked, still-dirty LIVE worktree as "git no longer tracks this" -- which would
  #           then force-remove it and discard uncommitted changes with no --force confirmation
  # Steps: use a PM_DISPATCH_STATE_ROOT containing `[`; create a worktree (its path inherits the `[`);
  #        make it dirty; run plain `gc` (no flags); assert the worktree and its uncommitted file
  #        survive and the manifest still has the entry -- proving it was correctly recognized as
  #        still tracked, not force-removed as a false orphan
  local name="worktree gc: a checkout path containing a regex metacharacter is not misclassified as untracked"
  should_run "$name" || return 0
  local store work wt_path status=0
  store="$tmp_root/state[meta"
  work="$tmp_root/work-gc-metachar"
  make_work_repo "$work"
  wt_path="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/metachar --cd "$work" 2>/dev/null | tail -1)"
  # create must have made the checkout where it says; on native Windows a `[` in the path
  # once sent git to C:\c\... while pmctl registered the intended path. Fail this case
  # instead of letting the write below abort the whole suite.
  if [[ ! -d "$wt_path" ]]; then
    fail "$name" "worktree create reported $wt_path but no checkout exists there"
    return 0
  fi
  printf 'dirty\n' > "$wt_path/dirty.txt"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --cd "$work" > /dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 && -d "$wt_path" && -f "$wt_path/dirty.txt" \
        && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status wt_path_exists=$([[ -d "$wt_path" ]] && echo yes || echo no)"
  fi
}

case_git_path_helper_uses_cygpath_when_present() {
  # behavior: the path handed to the native git is the cygpath -m form where cygpath exists
  #   (Git Bash) and unchanged where it does not (Linux, macOS); a glob character in it
  #   ([, * or ?) must not change that. Without this, MSYS leaves such an argument as /c/...
  #   and git creates the checkout at C:\c\... (see case_gc_path_with_regex_metachar...).
  # Steps: source the library; call the helper with a stub cygpath on PATH and with PATH
  #   reduced to a directory without one; compare with the literal expectations.
  local name="worktree: the git path helper converts with cygpath when present and passes through otherwise"
  should_run "$name" || return 0
  local bin with without
  bin="$tmp_root/gitpath-bin"
  mkdir -p "$bin"
  cat > "$bin/cygpath" <<'EOF'
#!/usr/bin/env bash
# stub cygpath -m: /c/x -> C:/x
[[ "${1:-}" == -m ]] && shift
[[ "${1:-}" == -- ]] && shift
printf 'C:%s\n' "${1#/c}"
EOF
  chmod +x "$bin/cygpath"
  with="$(PATH="$bin:$PATH" bash -c '. "$1/runtime/lib/pmctl-worktree.sh"; _pmctl_worktree_git_path "/c/Users/me/state[meta/x"' _ "$REPO_ROOT")"
  if command -v cygpath >/dev/null 2>&1; then
    without=skip-host-has-cygpath
  else
    without="$(bash -c '. "$1/runtime/lib/pmctl-worktree.sh"; _pmctl_worktree_git_path "/c/Users/me/state[meta/x"' _ "$REPO_ROOT")"
  fi
  if [[ "$with" == "C:/Users/me/state[meta/x" ]] \
     && { [[ "$without" == "/c/Users/me/state[meta/x" ]] || [[ "$without" == skip-host-has-cygpath ]]; }; then
    pass "$name"
  else
    fail "$name" "with_cygpath=[$with] without=[$without]"
  fi
}

# Issue #677: without --cd the subcommands acted on the pm-dispatch checkout that
# holds cli/pmctl instead of the repo the shell is in. repo_root is only where the
# libraries come from; the target defaults to the current directory (same as `--cd .`).
case_default_target_is_current_directory_for_list_remove_gc() {
  # behavior: list, remove and gc with no --cd act on the repo of the current directory, from its root and from a subdirectory
  # Steps: register two worktrees in repo A with --cd; from A's subdirectory run list/remove, from A's root run gc --merged,
  #        all without --cd; assert the entries were seen, removed and collected
  local name="worktree list/remove/gc: no --cd targets the current directory's repo"
  should_run "$name" || return 0
  local store work wt_a wt_b listed_sub listed_root status=0
  store="$tmp_root/state-default-cwd"
  work="$tmp_root/work-default-cwd"
  make_work_repo "$work"
  mkdir -p "$work/sub/dir"
  wt_a="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/da --cd "$work" 2>/dev/null | tail -1)"
  wt_b="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree create feat/db --cd "$work" 2>/dev/null | tail -1)"
  listed_sub="$(cd "$work/sub/dir" && PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree list --json 2>/dev/null | jq -r '[.[].branch] | sort | join(",")')" || true
  (cd "$work/sub/dir" && PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree remove feat/da > /dev/null 2>&1) || status=$?
  listed_root="$(cd "$work" && PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree list --json 2>/dev/null | jq -r '[.[].branch] | sort | join(",")')" || true
  if [[ "$status" -eq 0 && "$listed_sub" == "feat/da,feat/db" && ! -d "$wt_a" && "$listed_root" == "feat/db" ]] \
     && (cd "$work" && PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" worktree gc --merged > /dev/null 2>&1) \
     && [[ ! -d "$wt_b" && "$(wt_list_json "$store" "$work" | jq 'length')" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status listed_sub=$listed_sub listed_root=$listed_root wt_a_exists=$([[ -d "$wt_a" ]] && echo yes || echo no) wt_b_exists=$([[ -d "$wt_b" ]] && echo yes || echo no)"
  fi
}

case_default_target_is_current_directory_for_create() {
  # behavior: create with no --cd makes the branch and worktree in the repo of the current directory, never in repo_root
  # Steps: build a decoy install repo that carries a copy of runtime/lib (so the library loads from it), cd into a separate
  #        work repo, call pmctl_worktree_create with the decoy as repo_root and no work dir; assert the branch is in the
  #        work repo only. Done through the function, not the CLI, so a regression cannot touch the real checkout.
  local name="worktree create: no --cd creates in the current directory's repo, not in repo_root"
  should_run "$name" || return 0
  local store work decoy out err status=0
  store="$tmp_root/state-default-create"
  work="$tmp_root/work-default-create"
  decoy="$tmp_root/decoy-install-default-create"
  make_work_repo "$work"
  make_work_repo "$decoy"
  mkdir -p "$decoy/runtime"
  cp -R "$REPO_ROOT/runtime/lib" "$decoy/runtime/lib"
  out="$tmp_root/dc.out"; err="$tmp_root/dc.err"
  (
    cd "$work"
    export PM_DISPATCH_STATE_ROOT="$store"
    # shellcheck source=runtime/lib/pmctl-worktree.sh
    # shellcheck disable=SC1091
    . "$REPO_ROOT/runtime/lib/pmctl-worktree.sh"
    pmctl_worktree_create "$decoy" "" feat/dc
  ) > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 && -n "$(git -C "$work" branch --list feat/dc)" && -z "$(git -C "$decoy" branch --list feat/dc)" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status in_work=$(git -C "$work" branch --list feat/dc | wc -l) in_decoy=$(git -C "$decoy" branch --list feat/dc | wc -l) err=$(<"$err")"
  fi
}

case_create_requires_branch
case_create_new_branch
case_create_stdout_single_line_path
case_create_from_base
case_create_existing_branch_no_new_ref
case_create_name_override_slug
case_create_duplicate_slug_rejected
case_create_stale_manifest_duplicate_slug_rejected
case_create_rejects_unsafe_symlinked_state_root
case_create_unsafe_slug_rejected
case_create_help
case_create_missing_cd_value
case_list_empty
case_list_missing_cd_value
case_list_json_valid
case_list_text_table
case_list_cross_worktree_identity
case_main_root_from_linked_worktree
case_main_root_accepts_drive_letter_common_dir
case_remove_requires_target
case_remove_missing_cd_value
case_remove_unknown_target
case_remove_success
case_remove_dirty_requires_force
case_manifest_remove_slugs_survives_concurrent_append
case_gc_no_worktrees
case_gc_missing_cd_value
case_gc_dry_run_no_mutation
case_gc_removes_orphaned_manifest_entry
case_gc_merged_flag
case_gc_merged_does_not_self_remove_when_invoked_from_inside
case_gc_merged_skips_dirty_without_force
case_gc_merged_exact_match_ignores_regex_metachar_collision
case_gc_max_age_days_filters
case_gc_max_age_days_removes_aged_entry
case_gc_max_age_days_bsd_fallback_parses_correctly
case_gc_max_age_days_rejects_non_integer
case_gc_prunes_git_state
case_gc_path_with_regex_metachar_not_misclassified
case_default_target_is_current_directory_for_list_remove_gc
case_default_target_is_current_directory_for_create
case_git_path_helper_uses_cygpath_when_present

th_summary
