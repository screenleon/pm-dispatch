#!/usr/bin/env bash
# Regression tests for state writer and layout.yaml parity.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LAYOUT="$REPO_ROOT/core/state/layout.yaml"
STATE_WRITER="$REPO_ROOT/runtime/lib/state-writer.sh"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/state-writer.sh
. "$STATE_WRITER"

line_count() {
  local data="${1:-}"
  if [[ -z "$data" ]]; then
    printf '0\n'
  else
    printf '%s\n' "$data" | grep -c '^'
  fi
}

line_set_contains() {
  local data="$1" needle="$2" line
  while IFS= read -r line; do
    [[ "$line" == "$needle" ]] && return 0
  done <<< "$data"
  return 1
}

assert_line_set_contains() {
  local name="$1" data="$2" needle="$3"
  if ! line_set_contains "$data" "$needle"; then
    fail "$name" "missing '$needle' in: $(printf '%s' "$data" | tr '\n' ' ')"
    return 1
  fi
}

layout_project_subdirs() {
  grep -E '^[[:space:]]+- path: "(tasks/|reviews/|decisions/|operations/|context-packs/|archive/)"' "$LAYOUT" |
    sed -E 's/.*"([^"]+)".*/\1/; s:/$::'
}

layout_project_file_paths() {
  grep -E '^[[:space:]]+- path: "(runs\.jsonl|events\.jsonl|runs\.lock|events\.lock)"' "$LAYOUT" |
    sed -E 's/.*"([^"]+)".*/\1/'
}

layout_lock_refs() {
  grep -E '^[[:space:]]+lock: (runs|events)\.lock$' "$LAYOUT" |
    sed -E 's/.*lock: //'
}

layout_archive_paths() {
  grep -E '^[[:space:]]+archive_path: archive/(runs|events)-\$YYYYMM-\$NNNN\.jsonl\.gz$' "$LAYOUT" |
    sed -E 's/.*archive_path: //'
}

layout_archive_file_patterns() {
  grep -E '^[[:space:]]+- "(runs|events)-\$YYYYMM-\$NNNN\.jsonl\.gz"$' "$LAYOUT" |
    sed -E 's/.*"([^"]+)".*/\1/'
}

writer_lock_names() {
  grep -E 'serialize_with_lock "\$proj_dir/(runs|events)"' "$STATE_WRITER" |
    sed -E 's/.*\$proj_dir\/([^"]+)".*/\1.lock/'
}

writer_archive_paths() {
  local proj_dir="$1" entity path
  for entity in runs events; do
    path="$(cd "$proj_dir" && _sw_next_archive_path "$entity")"
    printf '%s\n' "$path" | sed -E 's/[0-9]{6}/$YYYYMM/; s/[0-9]{4}/$NNNN/'
  done
}

writer_archive_file_patterns() {
  writer_archive_paths "$1" | sed 's:^archive/::'
}

make_writer_store() {
  local store="$1" repo="$2"
  mkdir -p "$repo"
  git -C "$repo" init -q
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$repo" state_store_init
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$repo" runs_append \
    '{"schema_version":3,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$repo" events_append \
    '{"schema_version":1,"id":"evt-20260101T000000Z-abcdef","kind":"run.completed","subject_type":"run","subject_id":"run-20260101T000000Z-abcdef","ts":"2026-01-01T00:00:00Z","payload":{"run_id":"run-20260101T000000Z-abcdef","state":"ok","from_state":"verifying","to_state":"ok"}}'
}

case_layout_is_valid_yaml() {
  local name="state-layout-parity: layout is valid YAML"
  should_run "$name" || return 0
  if python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1], encoding="utf-8"))' "$LAYOUT"; then
    pass "$name"
  else
    fail "$name" "YAML parser rejected $LAYOUT"
  fi
}

case_project_subdirs_match_layout() {
  # Verifies the project subdirectories created by state_store_init are declared by layout.yaml.
  #
  # Steps:
  #   1. Initialize a state store for a temporary git repo.
  #   2. List the writer-created project subdirectories.
  #   3. Assert the set exactly matches the subdirectory paths declared in layout.yaml.
  local name="state-layout-parity: project subdirs match layout"
  should_run "$name" || return 0
  local store repo proj_dir actual="" layout="" d base actual_count layout_count
  store="$tmp_root/subdirs-store"
  repo="$tmp_root/subdirs-repo"
  make_writer_store "$store" "$repo"
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$repo" _sw_project_dir)"

  for d in "$proj_dir"/*/; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    actual="${actual}${base}"$'\n'
  done
  actual="${actual%$'\n'}"
  layout="$(layout_project_subdirs)"
  actual_count="$(line_count "$actual")"
  layout_count="$(line_count "$layout")"

  if [[ "$actual_count" -ne 6 || "$layout_count" -ne 6 ]]; then
    fail "$name" "actual_count=$actual_count layout_count=$layout_count"
    return
  fi
  while IFS= read -r d; do
    assert_line_set_contains "$name" "$layout" "$d" || return
  done <<< "$actual"
  while IFS= read -r d; do
    assert_line_set_contains "$name" "$actual" "$d" || return
  done <<< "$layout"
  pass "$name"
}

case_active_files_and_locks_match_layout() {
  # Verifies active JSONL file names and lock names used by the writer are declared by layout.yaml.
  #
  # Steps:
  #   1. Append one Run and one Event through the writer.
  #   2. Assert runs.jsonl and events.jsonl exist and are declared in layout.yaml.
  #   3. Assert the writer's serialize_with_lock lock names match layout.yaml lock declarations.
  local name="state-layout-parity: active files and locks match layout"
  should_run "$name" || return 0
  local store repo proj_dir layout_files locks_from_paths locks_from_refs locks_from_writer f lock
  store="$tmp_root/files-store"
  repo="$tmp_root/files-repo"
  make_writer_store "$store" "$repo"
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$repo" _sw_project_dir)"
  layout_files="$(layout_project_file_paths)"
  locks_from_paths="$(printf '%s\n' "$layout_files" | grep -E '^(runs|events)\.lock$')"
  locks_from_refs="$(layout_lock_refs)"
  locks_from_writer="$(writer_lock_names)"

  for f in runs.jsonl events.jsonl; do
    if [[ ! -f "$proj_dir/$f" ]]; then
      fail "$name" "writer did not create $f"
      return
    fi
    assert_line_set_contains "$name" "$layout_files" "$f" || return
  done
  for lock in runs.lock events.lock; do
    assert_line_set_contains "$name" "$locks_from_paths" "$lock" || return
    assert_line_set_contains "$name" "$locks_from_refs" "$lock" || return
    assert_line_set_contains "$name" "$locks_from_writer" "$lock" || return
  done
  if [[ "$(line_count "$locks_from_writer")" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "writer locks: $(printf '%s' "$locks_from_writer" | tr '\n' ' ')"
  fi
}

case_archive_patterns_match_layout() {
  # Verifies the writer's archive segment shape is declared by layout.yaml.
  #
  # Steps:
  #   1. Initialize a writer store and resolve the next runs/events archive paths.
  #   2. Normalize the concrete month and segment numbers to layout placeholders.
  #   3. Assert both archive_path and archive file_patterns declarations match the writer shape.
  local name="state-layout-parity: archive patterns match layout"
  should_run "$name" || return 0
  local store repo proj_dir writer_paths writer_patterns layout_paths layout_patterns item
  store="$tmp_root/archive-store"
  repo="$tmp_root/archive-repo"
  make_writer_store "$store" "$repo"
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$repo" _sw_project_dir)"
  writer_paths="$(writer_archive_paths "$proj_dir")"
  writer_patterns="$(writer_archive_file_patterns "$proj_dir")"
  layout_paths="$(layout_archive_paths)"
  layout_patterns="$(layout_archive_file_patterns)"

  if [[ "$(line_count "$writer_paths")" -ne 2 || "$(line_count "$layout_paths")" -ne 2 ||
        "$(line_count "$writer_patterns")" -ne 2 || "$(line_count "$layout_patterns")" -ne 2 ]]; then
    fail "$name" "unexpected archive declaration count"
    return
  fi
  while IFS= read -r item; do
    assert_line_set_contains "$name" "$layout_paths" "$item" || return
  done <<< "$writer_paths"
  while IFS= read -r item; do
    assert_line_set_contains "$name" "$layout_patterns" "$item" || return
  done <<< "$writer_patterns"
  pass "$name"
}

case_sw_build_run_json_emits_current_schema_version() {
  local name="sw_build_run_json emits schema_version matching run.schema.json"
  should_run "$name" || return 0
  local schema="$REPO_ROOT/core/schema/run.schema.json"
  local expected_version actual_version row
  expected_version="$(jq -r '.properties.schema_version.const // empty' "$schema" 2>/dev/null || true)"
  if [[ -z "$expected_version" ]]; then
    fail "$name" "could not read schema_version const from $schema"; return
  fi
  row="$(sw_build_run_json codex 0 ok default /tmp/b.md /tmp/wd /tmp/t.jsonl "" "CC-1" 2>/dev/null || true)"
  actual_version="$(jq -r '.schema_version // empty' <<< "$row" 2>/dev/null || true)"
  if [[ "$actual_version" == "$expected_version" ]]; then pass "$name"
  else fail "$name" "writer emits schema_version=$actual_version, schema expects $expected_version"; fi
}

case_layout_is_valid_yaml
case_project_subdirs_match_layout
case_active_files_and_locks_match_layout
case_archive_patterns_match_layout
case_sw_build_run_json_emits_current_schema_version

th_summary
