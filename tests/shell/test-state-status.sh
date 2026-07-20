#!/usr/bin/env bash
# Regression tests for `pmctl state status` and the store-layout compatibility
# surface (state-compat.sh + the writer's version gate remediation).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091  # runner invokes shellcheck without -x
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/state-status-test-XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

# tree_snapshot <dir>
# Print path+mode+mtime for every entry so before/after comparison catches any
# mutation (creation, chmod, rewrite) the status path might sneak in.
tree_snapshot() {
  local dir="$1"
  [[ -e "$dir" ]] || { printf 'ABSENT\n'; return 0; }
  find "$dir" -printf '%p %m %T@\n' 2>/dev/null | LC_ALL=C sort
}

mk_store() {
  local name="$1" version="${2:-}"
  local store="$TMP_ROOT/$name"
  mkdir -p "$store"
  [[ -n "$version" ]] && printf '%s\n' "$version" > "$store/VERSION"
  printf '%s\n' "$store"
}

status_json() {
  local store="$1"; shift
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" state status --json "$@"
}

# Behavior: a compatible store (VERSION == supported) reports state
# "compatible", exits 0, and the JSON carries every contract key.
# Steps: create a store with VERSION=1; run state status --json; assert exit 0
#        and every contract key (root, versions, project key, entities,
#        writable, safe_root, migration) via one jq -e predicate.
case_compatible_store_json_contract() {
  local name="compatible store: exit 0 + full JSON key contract"
  local store out rc=0
  store="$(mk_store compat 1)"
  out="$(status_json "$store")" || rc=$?
  if [[ "$rc" -ne 0 ]]; then fail "$name" "exit $rc"; return; fi
  if jq -e '
      .store_root and
      .store_state == "compatible" and
      .store_layout_version == 1 and
      (.supported_layout_versions | index(1) != null) and
      .current_layout_version == 1 and
      (.entity_schema_versions | has("run") and has("event") and has("task") and has("review") and has("decision") and has("context-pack")) and
      (.writable | type == "boolean") and
      (.safe_root | type == "boolean") and
      (.migration | has("available") and has("from") and has("to") and has("reason"))
    ' <<< "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "JSON contract violated: $out"
  fi
}

# Behavior: entity schema versions in the report are read from
# core/schema/*.schema.json, not a parallel table — run's const must match.
# Steps: read run.schema.json's schema_version const with jq; run status --json;
#        assert entity_schema_versions.run[0] equals the schema const.
case_entity_versions_match_schema_files() {
  local name="entity schema versions mirror core/schema files"
  local store out expected actual
  store="$(mk_store entities 1)"
  out="$(status_json "$store")" || { fail "$name" "status failed"; return; }
  expected="$(jq -r '.properties.schema_version.const' "$REPO_ROOT/core/schema/run.schema.json")"
  actual="$(jq -r '.entity_schema_versions.run[0]' <<< "$out")"
  if [[ -n "$expected" && "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "run schema const=$expected, status reports $actual"
  fi
}

# Behavior: a future-version store is reported fail-closed — state
# "incompatible", exit 3, migration.available false with an honest reason.
# Steps: create a store with VERSION=99; run status --json; assert exit 3 and
#        store_state incompatible, layout version 99, migration.available false.
case_future_version_fail_closed() {
  local name="future-version store: exit 3, migration unavailable"
  local store out rc=0
  store="$(mk_store future 99)"
  out="$(status_json "$store")" || rc=$?
  if [[ "$rc" -ne 3 ]]; then fail "$name" "expected exit 3, got $rc"; return; fi
  if jq -e '.store_state == "incompatible" and .store_layout_version == 99 and .migration.available == false' \
      <<< "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "unexpected report: $out"
  fi
}

# Behavior: observing a future-version store mutates nothing — no mkdir,
# chmod, or VERSION rewrite (path+mode+mtime snapshot identical).
# Steps: create a VERSION=99 store; snapshot path+mode+mtime; run status in
#        both JSON and human modes; re-snapshot and assert byte-identical.
case_future_version_zero_mutation() {
  local name="future-version store: zero mutation"
  local store before after
  store="$(mk_store future-mutation 99)"
  before="$(tree_snapshot "$store")"
  status_json "$store" >/dev/null 2>&1 || true
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" state status >/dev/null 2>&1 || true
  after="$(tree_snapshot "$store")"
  if [[ "$before" == "$after" ]]; then pass "$name"
  else fail "$name" "store changed:$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") || true)"; fi
}

# Behavior: pointing at a store root that does not exist reports
# "uninitialized", exits 0, and does not create the directory.
# Steps: point PM_DISPATCH_STATE_ROOT at a nonexistent path; run status --json;
#        assert exit 0, store_state uninitialized, null layout version, and the
#        path still does not exist afterwards.
case_uninitialized_store_not_created() {
  local name="uninitialized store: exit 0, nothing created"
  local store="$TMP_ROOT/never-created" out rc=0
  out="$(status_json "$store")" || rc=$?
  if [[ "$rc" -ne 0 ]]; then fail "$name" "exit $rc"; return; fi
  if ! jq -e '.store_state == "uninitialized" and .store_layout_version == null' <<< "$out" >/dev/null; then
    fail "$name" "unexpected report: $out"; return
  fi
  if [[ -e "$store" ]]; then fail "$name" "status created the store root"; return; fi
  pass "$name"
}

# Behavior: a store dir whose VERSION file is absent is first-time-init
# territory for the writer, so status reports it "uninitialized".
# Steps: create the store dir without a VERSION file; run status --json;
#        assert store_state is uninitialized.
case_missing_version_file_uninitialized() {
  local name="store dir without VERSION: reported uninitialized"
  local store out
  store="$(mk_store no-version)"
  out="$(status_json "$store")" || { fail "$name" "status failed"; return; }
  if jq -e '.store_state == "uninitialized"' <<< "$out" >/dev/null; then pass "$name"
  else fail "$name" "unexpected report: $out"; fi
}

# Behavior: an unreadable VERSION file is reported as store_state
# "unreadable" with exit 3 and zero store mutation.
# Steps: create a VERSION=1 store, chmod 000 the VERSION file, snapshot the
#        tree; run status --json; assert exit 3, store_state unreadable, null
#        layout version, and an identical post-run snapshot.
case_unreadable_version_fail_closed() {
  local name="unreadable VERSION: exit 3, store_state unreadable, zero mutation"
  local store out rc=0 before after
  store="$(mk_store unreadable 1)"
  chmod 000 "$store/VERSION"
  before="$(tree_snapshot "$store")"
  out="$(status_json "$store")" || rc=$?
  after="$(tree_snapshot "$store")"
  chmod 644 "$store/VERSION"
  if [[ "$rc" -ne 3 ]]; then fail "$name" "expected exit 3, got $rc"; return; fi
  if [[ "$before" != "$after" ]]; then fail "$name" "store mutated"; return; fi
  if jq -e '.store_state == "unreadable" and .store_layout_version == null' <<< "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "unexpected report: $out"
  fi
}

# Behavior: --cd pointing at a nonexistent directory is a usage error — exit 2
# and the store is never touched.
# Steps: run status --json --cd <missing dir> with a nonexistent store root;
#        assert exit 2 and that the store root was not created.
case_cd_nonexistent_dir_usage_error() {
  local name="--cd nonexistent dir: exit 2, store untouched"
  local rc=0
  PM_DISPATCH_STATE_ROOT="$TMP_ROOT/cd-unused" "$PMCTL" state status --json --cd "$TMP_ROOT/no-such-dir" \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 && ! -e "$TMP_ROOT/cd-unused" ]]; then pass "$name"
  else fail "$name" "exit=$rc"; fi
}

# Behavior: --cd without a value is a usage error — exit 2.
# Steps: run state status --cd with no following argument; assert exit 2.
case_cd_missing_value_usage_error() {
  local name="--cd missing value: exit 2"
  local rc=0
  PM_DISPATCH_STATE_ROOT="$TMP_ROOT/cd-unused2" "$PMCTL" state status --cd >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 && ! -e "$TMP_ROOT/cd-unused2" ]]; then pass "$name"
  else fail "$name" "exit=$rc"; fi
}

# Behavior: a garbage (non-numeric) VERSION value is unsupported — reported
# incompatible with exit 3, and the raw value is surfaced.
# Steps: write VERSION=banana; run status --json; assert exit 3,
#        store_state incompatible, and store_layout_version "banana".
case_garbage_version_incompatible() {
  local name="garbage VERSION value: incompatible, exit 3"
  local store out rc=0
  store="$(mk_store garbage banana)"
  out="$(status_json "$store")" || rc=$?
  if [[ "$rc" -eq 3 ]] && jq -e '.store_state == "incompatible" and .store_layout_version == "banana"' \
      <<< "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "exit=$rc report=$out"
  fi
}

# Behavior: neither the status report nor the writer's unsupported-version
# error recommends `pmctl state migrate` while no migration path exists.
# Steps: against a VERSION=99 store, capture human status, JSON status, and
#        state_store_init stderr; grep the combined output and assert the
#        string "pmctl state migrate" never appears.
case_no_phantom_migrate_recommendation() {
  local name="no surface recommends nonexistent 'pmctl state migrate'"
  local store human_out json_out writer_err
  store="$(mk_store phantom 99)"
  human_out="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" state status 2>&1)" || true
  json_out="$(status_json "$store" 2>&1)" || true
  writer_err="$(PM_DISPATCH_STATE_ROOT="$store" bash -c \
    'set -euo pipefail; . "'"$REPO_ROOT"'/runtime/lib/state-writer.sh"; state_store_init' 2>&1 || true)"
  if grep -Fq "pmctl state migrate" <<< "$human_out$json_out$writer_err"; then
    fail "$name" "a surface still recommends pmctl state migrate"
  else
    pass "$name"
  fi
}

# Behavior: the writer's version gate rejects a future store BEFORE any
# mutation and its error points at a real surface (pmctl state status).
# Steps: snapshot a VERSION=99 store; source state-writer.sh and call
#        state_store_init; assert nonzero exit, unchanged snapshot, stderr
#        mentions "pmctl state status" and never "pmctl state migrate".
case_writer_gate_honest_remediation() {
  local name="writer gate: fail-closed with honest remediation"
  local store err rc=0 before after
  store="$(mk_store writer-gate 99)"
  before="$(tree_snapshot "$store")"
  err="$(PM_DISPATCH_STATE_ROOT="$store" bash -c \
    'set -euo pipefail; . "'"$REPO_ROOT"'/runtime/lib/state-writer.sh"; state_store_init' 2>&1)" || rc=$?
  after="$(tree_snapshot "$store")"
  if [[ "$rc" -eq 0 ]]; then fail "$name" "init accepted a future store"; return; fi
  if [[ "$before" != "$after" ]]; then fail "$name" "init mutated a future store"; return; fi
  if grep -Fq "pmctl state status" <<< "$err" && ! grep -Fq "pmctl state migrate" <<< "$err"; then
    pass "$name"
  else
    fail "$name" "remediation text wrong: $err"
  fi
}

# Behavior: an unrecognized flag is a usage error — exit 2, no store access
# side effects.
# Steps: run state status --bogus with a store root that does not exist;
#        assert exit 2 and that the store root was not created.
case_unknown_flag_usage_error() {
  local name="unknown flag: usage error exit 2"
  local rc=0
  PM_DISPATCH_STATE_ROOT="$TMP_ROOT/unused" "$PMCTL" state status --bogus >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 && ! -e "$TMP_ROOT/unused" ]]; then pass "$name"
  else fail "$name" "exit=$rc"; fi
}

# Behavior: run from a non-git cwd without --cd, project_key degrades to null
# (the writer's "global" partition) while the store-level report still succeeds.
# Steps: cd into a plain (non-git) temp dir; run status --json without --cd;
#        assert exit 0, project_key null, store_state compatible.
case_non_git_cwd_null_project_key() {
  local name="non-git cwd, no --cd: project_key null, still exit 0"
  local store dir out rc=0
  store="$(mk_store non-git 1)"
  dir="$TMP_ROOT/plain-dir"
  mkdir -p "$dir"
  out="$(cd "$dir" && PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" state status --json)" || rc=$?
  if [[ "$rc" -eq 0 ]] && jq -e '.project_key == null and .store_state == "compatible"' <<< "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "exit=$rc report=$out"
  fi
}

# Behavior: from a git repo, project_key matches the writer's partitioning key
# so status and writer agree on which partition is being described.
# Steps: compute _sw_project_key directly from state-paths.sh in the repo;
#        run status --json --cd <repo>; assert project_key equals that value.
case_git_cd_matches_writer_key() {
  local name="--cd git repo: project_key matches _sw_project_key"
  local store out expected actual
  store="$(mk_store git-key 1)"
  expected="$(cd "$REPO_ROOT" && bash -c '. runtime/lib/state-paths.sh; _sw_project_key')"
  out="$(status_json "$store" --cd "$REPO_ROOT")" || { fail "$name" "status failed"; return; }
  actual="$(jq -r '.project_key' <<< "$out")"
  if [[ -n "$expected" && "$actual" == "$expected" ]]; then pass "$name"
  else fail "$name" "expected $expected, got $actual"; fi
}

# Behavior: a group/world-writable store root is reported safe_root=false with
# a reason, without status attempting to chmod it back.
# Steps: chmod 0777 a VERSION=1 store; record mode; run status --json; assert
#        safe_root false with a nonempty reasons list and the mode unchanged.
case_unsafe_mode_reported_not_repaired() {
  local name="world-writable root: safe_root false, mode untouched"
  local store out mode_before mode_after
  store="$(mk_store unsafe-mode 1)"
  chmod 0777 "$store"
  mode_before="$(stat -c %a "$store" 2>/dev/null || stat -f %Lp "$store")"
  out="$(status_json "$store")" || { fail "$name" "status failed"; return; }
  mode_after="$(stat -c %a "$store" 2>/dev/null || stat -f %Lp "$store")"
  if [[ "$mode_before" != "$mode_after" ]]; then fail "$name" "status changed mode $mode_before -> $mode_after"; return; fi
  if jq -e '.safe_root == false and (.safe_root_reasons | length > 0)' <<< "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "unexpected report: $out"
  fi
}

# Behavior: human-readable output carries the same load-bearing facts as the
# JSON (store root, layout version, migration availability).
# Steps: run plain (human) state status against a VERSION=1 store; grep for
#        the store root, layout version, supported versions, and migration
#        availability lines.
case_human_output_facts() {
  local name="human output: store root + versions + migration line present"
  local store out
  store="$(mk_store human 1)"
  out="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" state status)" || { fail "$name" "status failed"; return; }
  if grep -q "store root:" <<< "$out" \
    && grep -q "store layout version:" <<< "$out" \
    && grep -q "supported layout versions:" <<< "$out" \
    && grep -q "migration available:" <<< "$out"; then
    pass "$name"
  else
    fail "$name" "missing lines in: $out"
  fi
}

case_compatible_store_json_contract
case_entity_versions_match_schema_files
case_future_version_fail_closed
case_future_version_zero_mutation
case_uninitialized_store_not_created
case_missing_version_file_uninitialized
case_unreadable_version_fail_closed
case_cd_nonexistent_dir_usage_error
case_cd_missing_value_usage_error
case_garbage_version_incompatible
case_no_phantom_migrate_recommendation
case_writer_gate_honest_remediation
case_unknown_flag_usage_error
case_non_git_cwd_null_project_key
case_git_cd_matches_writer_key
case_unsafe_mode_reported_not_repaired
case_human_output_facts

th_summary
