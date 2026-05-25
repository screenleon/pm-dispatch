#!/usr/bin/env bash
# Regression tests for the pm-dispatch state-store writer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# shellcheck source=scripts/lib/state-writer.sh
. "$SCRIPT_DIR/lib/state-writer.sh"

reset_state_env() {
  unset PM_DISPATCH_STATE_ROOT XDG_DATA_HOME
}

case_store_root_override() {
  local name="state_store_root: PM_DISPATCH_STATE_ROOT override"
  should_run "$name" || return 0
  local out
  reset_state_env
  out="$(PM_DISPATCH_STATE_ROOT=/tmp/test-state-override _sw_store_root)"
  if [[ "$out" == "/tmp/test-state-override" ]]; then
    pass "$name"
  else
    fail "$name" "got: $out"
  fi
}

case_store_root_xdg() {
  local name="state_store_root: XDG_DATA_HOME fallback"
  should_run "$name" || return 0
  local out
  reset_state_env
  out="$(XDG_DATA_HOME=/tmp/test-xdg _sw_store_root)"
  if [[ "$out" == "/tmp/test-xdg/pm-dispatch/state" ]]; then
    pass "$name"
  else
    fail "$name" "got: $out"
  fi
}

case_store_root_default() {
  local name="state_store_root: default path"
  should_run "$name" || return 0
  local out
  reset_state_env
  out="$(HOME=/tmp/test-home _sw_store_root)"
  if [[ "$out" == "/tmp/test-home/.local/share/pm-dispatch/state" ]]; then
    pass "$name"
  else
    fail "$name" "got: $out"
  fi
}

case_state_store_init_structure() {
  local name="state_store_init: creates directory structure"
  should_run "$name" || return 0
  local store proj_dir missing=()
  store="$tmp_root/state-init"
  PM_DISPATCH_STATE_ROOT="$store" state_store_init
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  for d in tasks reviews decisions context-packs archive; do
    [[ -d "$proj_dir/$d" ]] || missing+=("$d")
  done
  if [[ "${#missing[@]}" -eq 0 && -f "$store/VERSION" && "$(cat "$store/VERSION")" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "missing=${missing[*]} version=$(cat "$store/VERSION" 2>/dev/null || true)"
  fi
}

case_runs_append_valid_jsonl() {
  local name="runs_append: creates runs.jsonl with valid JSONL"
  should_run "$name" || return 0
  local store proj_dir line
  store="$tmp_root/runs-one"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  line="$(cat "$proj_dir/runs.jsonl" 2>/dev/null || true)"
  if [[ -f "$proj_dir/runs.jsonl" && "$(wc -l < "$proj_dir/runs.jsonl")" == "1" ]] &&
    jq . >/dev/null 2>&1 <<< "$line"; then
    pass "$name"
  else
    fail "$name" "runs.jsonl not one valid JSON line"
  fi
}

case_runs_append_appends() {
  local name="runs_append: second call appends (not overwrites)"
  should_run "$name" || return 0
  local store proj_dir
  store="$tmp_root/runs-two"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000001Z-123456","task_id":"CC-230","executor":"codex","state":"failed","exit_code":1,"created_ts":"2026-01-01T00:00:01Z"}'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  if [[ -f "$proj_dir/runs.jsonl" && "$(wc -l < "$proj_dir/runs.jsonl")" == "2" ]]; then
    pass "$name"
  else
    fail "$name" "line_count=$(wc -l < "$proj_dir/runs.jsonl" 2>/dev/null || true)"
  fi
}

case_events_append() {
  local name="events_append: creates events.jsonl"
  should_run "$name" || return 0
  local store proj_dir
  store="$tmp_root/events-one"
  PM_DISPATCH_STATE_ROOT="$store" events_append '{"schema_version":1,"id":"evt-20260101T000000Z-abcdef","kind":"run.completed","subject_type":"run","subject_id":"run-20260101T000000Z-abcdef","ts":"2026-01-01T00:00:00Z"}'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  if [[ -f "$proj_dir/events.jsonl" && "$(wc -l < "$proj_dir/events.jsonl")" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "events.jsonl missing or wrong line count"
  fi
}

case_task_upsert() {
  local name="task_upsert: write-temp-then-rename"
  should_run "$name" || return 0
  local store proj_dir task_file expected
  store="$tmp_root/task-upsert"
  expected='{"schema_version":1,"id":"CC-230","title":"test","state":"planned","created_ts":"2026-01-01T00:00:00Z"}'
  PM_DISPATCH_STATE_ROOT="$store" task_upsert "CC-230" "$expected"
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  task_file="$proj_dir/tasks/CC-230.json"
  if [[ -f "$task_file" && "$(cat "$task_file")" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "task file mismatch"
  fi
}

case_runs_append_read_only_nonfatal() {
  local name="runs_append: non-fatal on read-only store dir"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/read-only-store"
  mkdir -p "$store"
  chmod 500 "$store"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}' || rc=$?
  chmod 700 "$store"
  if [[ "$rc" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "exit=$rc"
  fi
}

case_codex_dispatch_state_store_self_contained() {
  local name="codex-dispatch.sh: state store block is self-contained"
  should_run "$name" || return 0
  if bash -n "$REPO_ROOT/scripts/codex-dispatch.sh" &&
    grep -Fq '. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true' "$REPO_ROOT/scripts/codex-dispatch.sh"; then
    pass "$name"
  else
    fail "$name" "syntax check or source guard missing"
  fi
}

case_dispatch_creates_run_row() {
  # Verifies that invoking codex-dispatch.sh with a fake codex binary writes
  # exactly one row to runs.jsonl under the state store, confirming the end-to-end
  # dispatch-to-state-store path works.
  #
  # Steps:
  #   1. Create a fake `codex` script that exits 0 and emit no output.
  #   2. Write a brief file containing a task_id field.
  #   3. Run codex-dispatch.sh --cd <workdir> --brief-file <brief> with the fake
  #      codex on PATH and PM_DISPATCH_STATE_ROOT pointing to a fresh tmpdir.
  #   4. Assert runs.jsonl exists anywhere under the store root.
  local name="codex-dispatch.sh: creates runs.jsonl row after dispatch"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir
  store="$tmp_root/dispatch-run"
  fake_bin_dir="$tmp_root/dispatch-bin"
  work_dir="$tmp_root/dispatch-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin_dir/codex"
  chmod +x "$fake_bin_dir/codex"
  brief_file="$tmp_root/dispatch-brief.md"
  printf 'task_id: CC-230\nDo nothing.\n' > "$brief_file"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    bash "$REPO_ROOT/scripts/codex-dispatch.sh" \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  local runs_file
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  if [[ -n "$runs_file" && -s "$runs_file" ]]; then
    pass "$name"
  else
    fail "$name" "runs.jsonl not created or empty in $store"
  fi
}

case_dispatch_correct_partition() {
  # Verifies that codex-dispatch.sh writes the run row into the target repo's
  # project partition (derived from WORK_DIR's git root), not the caller's cwd.
  #
  # Steps:
  #   1. git init a fresh tmpdir (work_dir) so it has its own git root.
  #   2. Compute the expected sha1 partition key for work_dir.
  #   3. Run codex-dispatch.sh --cd <work_dir>.
  #   4. Assert runs.jsonl appears under projects/<expected_key>/, not elsewhere.
  local name="codex-dispatch.sh: run written to target project partition"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir work_dir_key expected_partition
  store="$tmp_root/partition-store"
  fake_bin_dir="$tmp_root/partition-bin"
  work_dir="$tmp_root/partition-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  ( cd "$work_dir" && git init -q && git commit --allow-empty -m "init" -q ) 2>/dev/null || true
  work_dir_key="$(printf '%s\n' "$work_dir" | sha1sum 2>/dev/null | cut -c1-40 || true)"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin_dir/codex"
  chmod +x "$fake_bin_dir/codex"
  brief_file="$tmp_root/partition-brief.md"
  printf 'task_id: CC-230\nDo nothing.\n' > "$brief_file"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    bash "$REPO_ROOT/scripts/codex-dispatch.sh" \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  expected_partition="$store/projects/$work_dir_key"
  if [[ -f "$expected_partition/runs.jsonl" ]]; then
    pass "$name"
  else
    local actual
    actual="$(find "$store/projects" -name "runs.jsonl" 2>/dev/null | tr '\n' ' ' || true)"
    fail "$name" "expected $expected_partition/runs.jsonl; found: ${actual:-none}"
  fi
}

case_dispatch_run_json_valid() {
  # Verifies that runs.jsonl row produced by codex-dispatch.sh is valid JSON
  # even when MODEL contains characters that would corrupt raw printf interpolation.
  #
  # Steps:
  #   1. Create a fake codex that exits 0.
  #   2. Run codex-dispatch.sh with --model set to a value with quotes/backslashes.
  #   3. Assert the runs.jsonl row parses with jq (exit 0).
  local name="codex-dispatch.sh: run row is valid JSON with special chars in model"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file
  store="$tmp_root/json-valid"
  fake_bin_dir="$tmp_root/json-valid-bin"
  work_dir="$tmp_root/json-valid-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin_dir/codex"
  chmod +x "$fake_bin_dir/codex"
  brief_file="$tmp_root/json-valid-brief.md"
  printf 'task_id: CC-230\nDo nothing.\n' > "$brief_file"
  # Use a model name with characters that would corrupt printf-based JSON
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    bash "$REPO_ROOT/scripts/codex-dispatch.sh" \
    --cd "$work_dir" --model 'model-with-"quotes"' \
    --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  if [[ -n "$runs_file" ]] && jq -e . "$runs_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "runs.jsonl missing or not valid JSON (file=${runs_file:-none})"
  fi
}

case_dispatch_subdir_partition_key() {
  # Verifies that dispatching with --cd pointing to a repo subdirectory writes
  # the run row under the repo root's partition key, not the subdirectory's key.
  #
  # Steps:
  #   1. git init a fresh tmpdir (repo_root); create a subdir inside it.
  #   2. Compute the expected partition key for the repo root.
  #   3. Run codex-dispatch.sh --cd <repo_root>/subdir.
  #   4. Assert runs.jsonl appears under projects/<root_key>/, not subdir key.
  local name="codex-dispatch.sh: subdirectory --cd resolves to repo root partition"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file repo_root work_subdir root_key expected_partition
  store="$tmp_root/subdir-store"
  fake_bin_dir="$tmp_root/subdir-bin"
  repo_root="$tmp_root/subdir-repo"
  work_subdir="$repo_root/sub/dir"
  mkdir -p "$fake_bin_dir" "$work_subdir"
  ( cd "$repo_root" && git init -q && git commit --allow-empty -m "init" -q ) 2>/dev/null || true
  root_key="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null | sha1sum 2>/dev/null | cut -c1-40 || true)"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin_dir/codex"
  chmod +x "$fake_bin_dir/codex"
  brief_file="$tmp_root/subdir-brief.md"
  printf 'task_id: CC-230\nDo nothing.\n' > "$brief_file"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    bash "$REPO_ROOT/scripts/codex-dispatch.sh" \
    --cd "$work_subdir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  expected_partition="$store/projects/$root_key"
  if [[ -f "$expected_partition/runs.jsonl" ]]; then
    pass "$name"
  else
    local actual
    actual="$(find "$store/projects" -name "runs.jsonl" 2>/dev/null | tr '\n' ' ' || true)"
    fail "$name" "expected $expected_partition/runs.jsonl; found: ${actual:-none}"
  fi
}

case_dispatch_task_id_anchor() {
  # Verifies that prefixed keys like `parent_task_id:` are not mistaken for the
  # real `task_id:` line when extracting the task attribution for the run row.
  #
  # Steps:
  #   1. Write a brief with parent_task_id: CC-999 before task_id: CC-230.
  #   2. Run fake-codex dispatch.
  #   3. Assert that runs.jsonl has task_id == "CC-230", not "CC-999" or "UNKN-0".
  local name="codex-dispatch.sh: task_id extraction is anchored (ignores parent_task_id)"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file task_id_found
  store="$tmp_root/anchor-store"
  fake_bin_dir="$tmp_root/anchor-bin"
  work_dir="$tmp_root/anchor-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin_dir/codex"
  chmod +x "$fake_bin_dir/codex"
  brief_file="$tmp_root/anchor-brief.md"
  # parent_task_id: appears BEFORE task_id: - unanchored grep would pick CC-999
  printf 'parent_task_id: CC-999\ntask_id: CC-230\nDo nothing.\n' > "$brief_file"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    bash "$REPO_ROOT/scripts/codex-dispatch.sh" \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  task_id_found=""
  [[ -n "$runs_file" ]] && task_id_found="$(jq -r '.task_id' "$runs_file" 2>/dev/null | head -1 || true)"
  if [[ "$task_id_found" == "CC-230" ]]; then
    pass "$name"
  else
    fail "$name" "expected task_id=CC-230 but got task_id=${task_id_found:-none} (file=${runs_file:-none})"
  fi
}

case_store_root_override
case_store_root_xdg
case_store_root_default
case_state_store_init_structure
case_runs_append_valid_jsonl
case_runs_append_appends
case_events_append
case_task_upsert
case_runs_append_read_only_nonfatal
case_codex_dispatch_state_store_self_contained
case_dispatch_creates_run_row
case_dispatch_correct_partition
case_dispatch_run_json_valid
case_dispatch_subdir_partition_key
case_dispatch_task_id_anchor

th_summary
