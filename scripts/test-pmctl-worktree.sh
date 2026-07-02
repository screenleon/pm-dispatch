#!/usr/bin/env bash
# Regression tests for `pmctl worktree create/list/remove/gc`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
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

case_create_requires_branch() {
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

case_create_from_base() {
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

case_create_unsafe_slug_rejected() {
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

case_list_empty() {
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

case_remove_requires_target() {
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

case_gc_no_worktrees() {
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

case_gc_max_age_days_filters() {
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

case_gc_prunes_git_state() {
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

case_create_requires_branch
case_create_new_branch
case_create_from_base
case_create_existing_branch_no_new_ref
case_create_name_override_slug
case_create_duplicate_slug_rejected
case_create_unsafe_slug_rejected
case_create_help
case_list_empty
case_list_json_valid
case_list_text_table
case_list_cross_worktree_identity
case_remove_requires_target
case_remove_unknown_target
case_remove_success
case_remove_dirty_requires_force
case_gc_no_worktrees
case_gc_dry_run_no_mutation
case_gc_removes_orphaned_manifest_entry
case_gc_merged_flag
case_gc_max_age_days_filters
case_gc_prunes_git_state

th_summary
