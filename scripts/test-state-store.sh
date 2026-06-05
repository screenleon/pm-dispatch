#!/usr/bin/env bash
# Regression tests for the pm-dispatch state-store writer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# shellcheck source=scripts/lib/state-writer.sh
. "$SCRIPT_DIR/lib/state-writer.sh"

reset_state_env() {
  unset PM_DISPATCH_STATE_ROOT XDG_DATA_HOME
}

mk_pmctl_brief() {
  local work="$1" brief
  brief="/tmp/brief-state-store-$$-$(date +%s%N).md"
  cat > "$brief" <<EOF
schema_version: 1
working_dir: $work
goal: exercise pmctl-owned state writes
files:
  - read: $work/README
acceptance:
  - dispatch exits with expected state rows
EOF
  printf '%s\n' "$brief"
}

install_fake_codex() {
  local bindir="$1" code="${2:-0}" probe_file="${3:-}"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2;;
    *) shift;;
  esac
done
if [[ -n "$probe_file" && -n "\${PM_DISPATCH_STATE_ROOT:-}" ]]; then
  if find "\$PM_DISPATCH_STATE_ROOT" -name events.jsonl -type f -exec grep -q '"kind":"run.dispatched"' {} \\; -print -quit 2>/dev/null | grep -q .; then
    printf 'seen\n' > "$probe_file"
  fi
fi
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# Probing codex: unconditionally writes to probe_file on invocation.
# Used to verify whether the adapter (and therefore the underlying codex binary)
# was actually called by pmctl.
install_probing_codex() {
  local bindir="$1" code="${2:-0}" probe_file="$3"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2;;
    *) shift;;
  esac
done
printf 'invoked\n' > "$probe_file"
[[ -n "\$_last" ]] && printf 'dispatch complete (probing codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# Poison codex: makes events.jsonl unwritable (chmod 000) after the adapter
# runs so a post-adapter transition Event append fails while the paired Run
# append still succeeds.
install_poison_codex() {
  local bindir="$1" code="${2:-0}"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2;;
    *) shift;;
  esac
done
if [[ -n "\${PM_DISPATCH_STATE_ROOT:-}" ]]; then
  while IFS= read -r -d '' _ef; do
    chmod 000 "\$_ef"
  done < <(find "\${PM_DISPATCH_STATE_ROOT}" -name events.jsonl -type f -print0 2>/dev/null)
fi
[[ -n "\$_last" ]] && printf 'dispatch complete (poison codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

case_store_root_override() {
  # Verifies that PM_DISPATCH_STATE_ROOT env var overrides the default state store root path.
  #
  # Steps:
  #   1. Unset all store-root env vars.
  #   2. Call _sw_store_root with PM_DISPATCH_STATE_ROOT=/tmp/test-state-override.
  #   3. Assert the printed path equals the override value.
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
  # Verifies that XDG_DATA_HOME is used as a fallback store root when PM_DISPATCH_STATE_ROOT is unset.
  #
  # Steps:
  #   1. Unset PM_DISPATCH_STATE_ROOT; set XDG_DATA_HOME=/tmp/test-xdg.
  #   2. Call _sw_store_root.
  #   3. Assert the printed path equals /tmp/test-xdg/pm-dispatch/state.
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
  # Verifies that the default store root ~/.local/share/pm-dispatch/state is used when no env override is set.
  #
  # Steps:
  #   1. Unset PM_DISPATCH_STATE_ROOT and XDG_DATA_HOME; set HOME=/tmp/test-home.
  #   2. Call _sw_store_root.
  #   3. Assert the printed path equals /tmp/test-home/.local/share/pm-dispatch/state.
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
  # Verifies that state_store_init creates all required project subdirs and a VERSION=1 file.
  #
  # Steps:
  #   1. Set PM_DISPATCH_STATE_ROOT to a fresh tmpdir.
  #   2. Call state_store_init.
  #   3. Assert tasks/, reviews/, decisions/, context-packs/, and archive/ all exist.
  #   4. Assert $STORE/VERSION contains exactly "1".
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

case_state_store_init_version1_noop() {
  local name="state_store_init: VERSION=1 existing -> noop (file unchanged)"
  should_run "$name" || return 0
  local store before after
  store="$tmp_root/init-v1-noop"
  mkdir -p "$store"
  printf '1\n' > "$store/VERSION"
  before="$(cat "$store/VERSION")"
  PM_DISPATCH_STATE_ROOT="$store" state_store_init
  after="$(cat "$store/VERSION")"
  if [[ "$before" == "$after" && "$after" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "VERSION changed: before=$before after=$after"
  fi
}

case_state_store_init_version2_fails() {
  # Verifies that state_store_init rejects VERSION=2 with a non-zero exit and an
  # "unsupported" stderr message, and does NOT create any new layout entries.
  #
  # Steps:
  #   1. Create a store root containing only a VERSION=2 file.
  #   2. Call state_store_init; assert it returns non-zero.
  #   3. Assert stderr contains "unsupported".
  #   4. Assert no new entries were created beyond VERSION (no tasks/, no project dirs).
  local name="state_store_init: VERSION=2 -> fail loud (unsupported)"
  should_run "$name" || return 0
  local store rc=0 stderr_out new_entries
  store="$tmp_root/init-v2-fail"
  mkdir -p "$store"
  printf '2\n' > "$store/VERSION"
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$store" state_store_init 2>&1 >/dev/null)" || rc=$?
  # Count everything in the store except the VERSION file itself.
  new_entries="$(find "$store" -mindepth 1 ! -name VERSION 2>/dev/null | wc -l)"
  if [[ "$rc" -ne 0 ]] && printf '%s' "$stderr_out" | grep -q "unsupported" \
      && [[ "$new_entries" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=$stderr_out new_entries=$new_entries"
  fi
}

case_runs_append_fails_on_version2() {
  local name="state_store_init: runs_append returns non-zero when VERSION=2"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/runs-v2-fail"
  mkdir -p "$store"
  printf '2\n' > "$store/VERSION"
  PM_DISPATCH_STATE_ROOT="$store" runs_append \
    '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}' \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero, got rc=$rc"
  fi
}

case_runs_append_valid_jsonl() {
  # Verifies that runs_append creates runs.jsonl with exactly one valid JSON line.
  #
  # Steps:
  #   1. Call runs_append with a minimal valid Run JSON object.
  #   2. Resolve the project dir for the store root.
  #   3. Assert runs.jsonl exists and has exactly one line.
  #   4. Assert that line parses as valid JSON via jq.
  local name="runs_append: creates runs.jsonl with valid JSONL"
  should_run "$name" || return 0
  local store proj_dir line
  store="$tmp_root/runs-one"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
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
  # Verifies that a second runs_append call appends a new row rather than overwriting.
  #
  # Steps:
  #   1. Call runs_append twice with distinct run IDs into the same store.
  #   2. Assert runs.jsonl contains exactly two lines.
  local name="runs_append: second call appends (not overwrites)"
  should_run "$name" || return 0
  local store proj_dir
  store="$tmp_root/runs-two"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000001Z-123456","task_id":"CC-230","executor":"codex","state":"failed","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":1,"created_ts":"2026-01-01T00:00:01Z"}'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  if [[ -f "$proj_dir/runs.jsonl" && "$(wc -l < "$proj_dir/runs.jsonl")" == "2" ]]; then
    pass "$name"
  else
    fail "$name" "line_count=$(wc -l < "$proj_dir/runs.jsonl" 2>/dev/null || true)"
  fi
}

case_events_append() {
  # Verifies that events_append creates events.jsonl with exactly one valid JSON line.
  #
  # Steps:
  #   1. Call events_append with a schema-valid Event JSON object.
  #   2. Resolve the project dir for the store root.
  #   3. Assert events.jsonl exists and has exactly one line.
  #   4. Assert that line parses as valid JSON via jq.
  local name="events_append: creates events.jsonl"
  should_run "$name" || return 0
  local store proj_dir line
  store="$tmp_root/events-one"
  PM_DISPATCH_STATE_ROOT="$store" events_append '{"schema_version":1,"id":"evt-20260101T000000Z-abcdef","kind":"run.completed","subject_type":"run","subject_id":"run-20260101T000000Z-abcdef","ts":"2026-01-01T00:00:00Z","payload":{"run_id":"run-20260101T000000Z-abcdef","state":"ok","from_state":"verifying","to_state":"ok"}}'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  line="$(cat "$proj_dir/events.jsonl" 2>/dev/null || true)"
  if [[ -f "$proj_dir/events.jsonl" && "$(wc -l < "$proj_dir/events.jsonl")" == "1" ]] &&
    jq . >/dev/null 2>&1 <<< "$line"; then
    pass "$name"
  else
    fail "$name" "events.jsonl not one valid JSON line"
  fi
}

case_runs_append_rejects_newline() {
  local name="state-store: runs_append rejects json_line with embedded newline"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/runs-newline"
  PM_DISPATCH_STATE_ROOT="$store" runs_append $'{"schema_version":1,\n"id":"run-20260101T000000Z-abcdef"}' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name runs.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no runs.jsonl, rc=$rc"
  fi
}

case_runs_append_rejects_nul() {
  local name="state-store: runs_append rejects json_line with embedded NUL"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/runs-nul"
  PM_DISPATCH_STATE_ROOT="$store" runs_append $'{"schema_version":1\0' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name runs.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no runs.jsonl, rc=$rc"
  fi
}

case_events_append_rejects_newline() {
  local name="state-store: events_append rejects json_line with embedded newline"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/events-newline"
  PM_DISPATCH_STATE_ROOT="$store" events_append $'{"schema_version":1,\n"id":"evt-20260101T000000Z-abcdef"}' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name events.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no events.jsonl, rc=$rc"
  fi
}

case_events_append_rejects_nul() {
  local name="state-store: events_append rejects json_line with embedded NUL"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/events-nul"
  PM_DISPATCH_STATE_ROOT="$store" events_append $'{"schema_version":1\0' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name events.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no events.jsonl, rc=$rc"
  fi
}

case_runs_append_compacts_json() {
  local name="state-store: runs_append compacts JSON through jq -c"
  should_run "$name" || return 0
  local store proj_dir line expected
  store="$tmp_root/runs-compact"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{ "schema_version" : 1, "id" : "run-20260101T000000Z-abcdef", "task_id" : "CC-230", "executor" : "codex", "state" : "ok", "working_dir" : "/tmp/test", "trace_path" : "/tmp/test.jsonl", "exit_code" : 0, "created_ts" : "2026-01-01T00:00:00Z" }'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  line="$(cat "$proj_dir/runs.jsonl" 2>/dev/null || true)"
  expected='{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
  if [[ "$line" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "got: $line"
  fi
}

case_runs_append_rejects_malformed_json() {
  local name="state-store: runs_append rejects malformed JSON (jq -c fails)"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/runs-malformed"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name runs.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no runs.jsonl, rc=$rc"
  fi
}

case_runs_append_rejects_schema_invalid() {
  local name="state-store: runs_append rejects schema-invalid Run JSON"
  should_run "$name" || return 0
  if ! command -v jsonschema >/dev/null 2>&1; then
    pass "$name (skip: jsonschema not available)"
    return 0
  fi
  local store rc=0
  store="$tmp_root/runs-schema-invalid"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"not-a-run"}' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name runs.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero schema failure, rc=$rc"
  fi
}

case_task_upsert() {
  # Verifies that task_upsert atomically writes the task file using write-temp-then-rename.
  #
  # Steps:
  #   1. Call task_upsert with task_id "CC-230" and a JSON body.
  #   2. Resolve tasks/CC-230.json under the project dir.
  #   3. Assert the file exists and its content matches the input JSON exactly.
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

case_task_upsert_invalid_id() {
  # Verifies that task_upsert with an invalid task_id returns 0 (non-fatal) and
  # does not create any file, preventing path traversal or unexpected file creation.
  #
  # Steps:
  #   1. Call task_upsert with "../evil" as task_id and any JSON body.
  #   2. Assert the return code is 0.
  #   3. Assert no file was created at or near the tasks/ dir.
  local name="task_upsert: invalid task_id is rejected non-fatally, no file created"
  should_run "$name" || return 0
  local store proj_dir rc=0
  store="$tmp_root/task-invalid"
  PM_DISPATCH_STATE_ROOT="$store" task_upsert "../evil" '{"id":"evil"}' || rc=$?
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  # Check: exit code is 0 AND no evil file was written anywhere in the store
  if [[ "$rc" -eq 0 ]] && ! find "$store" -name "evil.json" -o -name "evil" 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "rc=$rc or unexpected file exists under $store"
  fi
}

case_runs_append_read_only_fails_loudly() {
  # Verifies that runs_append returns non-zero when the canonical write path fails.
  #
  # Steps:
  #   1. Create a tmpdir and chmod it to 500 (read+execute, no write).
  #   2. Call runs_append against that store; capture its exit code.
  #   3. Restore permissions; assert exit code is non-zero.
  local name="state-store: runs_append propagates non-zero when inner append fails"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/read-only-store"
  mkdir -p "$store"
  chmod 500 "$store"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}' >/dev/null 2>&1 || rc=$?
  chmod 700 "$store"
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "exit=$rc"
  fi
}

case_codex_dispatch_state_store_self_contained() {
  # Verifies that the state-writer source guard in the adapter uses 2>/dev/null || true
  # so dispatch is functional even when state-writer.sh is absent.
  # scripts/codex-dispatch.sh is now a thin exec shim; the state-store block lives in
  # adapters/codex/dispatch.sh (CC-308 Windows compat migration).
  #
  # Steps:
  #   1. Run bash -n on adapters/codex/dispatch.sh to verify syntax.
  #   2. Grep for the '. ... 2>/dev/null || true' source guard line.
  #   3. Assert both checks pass.
  local name="codex-dispatch.sh: state store block is self-contained"
  should_run "$name" || return 0
  if bash -n "$REPO_ROOT/adapters/codex/dispatch.sh" &&
    grep -Fq '. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true' "$REPO_ROOT/adapters/codex/dispatch.sh"; then
    pass "$name"
  else
    fail "$name" "syntax check or source guard missing"
  fi
}

case_pmctl_dispatch_creates_run_row() {
  # Verifies that pmctl dispatch owns the dispatch-to-state-store Run write and
  # that the row contains the expected load-bearing fields.
  local name="pmctl-dispatch: creates runs.jsonl row with correct schema/executor/state/exit fields"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir
  store="$tmp_root/dispatch-run"
  fake_bin_dir="$tmp_root/dispatch-bin"
  work_dir="$tmp_root/dispatch-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  local runs_file schema_v executor state exit_code events_file event_kinds
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  schema_v="$(jq -r '.schema_version' "$runs_file" 2>/dev/null | tail -1 || true)"
  executor="$(jq -r '.executor' "$runs_file" 2>/dev/null | tail -1 || true)"
  state="$(jq -r '.state' "$runs_file" 2>/dev/null | tail -1 || true)"
  exit_code="$(jq -r '.exit_code' "$runs_file" 2>/dev/null | tail -1 || true)"
  events_file="$(find "$store" -name "events.jsonl" -type f 2>/dev/null | head -1 || true)"
  event_kinds="$(jq -r '.kind' "$events_file" 2>/dev/null | paste -sd, - || true)"
  if [[ "$schema_v" == "1" && "$executor" == "codex" && "$state" == "ok" && \
        "$exit_code" == "0" && "$event_kinds" == "run.pending,run.dispatched,run.verifying,run.completed" ]]; then
    pass "$name"
  else
    fail "$name" "schema=$schema_v executor=$executor state=$state exit=$exit_code events=${event_kinds:-none}"
  fi
}

case_pmctl_dispatch_correct_partition() {
  # Verifies that pmctl writes the run row into the target repo's
  # project partition (derived from WORK_DIR's git root), not the caller's cwd.
  #
  # Steps:
  #   1. git init a fresh tmpdir (work_dir) so it has its own git root.
  #   2. Compute the expected sha1 partition key for work_dir.
  #   3. Run codex-dispatch.sh --cd <work_dir>.
  #   4. Assert runs.jsonl appears under projects/<expected_key>/, not elsewhere.
  local name="pmctl-dispatch: run written to target project partition"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir work_dir_key expected_partition
  store="$tmp_root/partition-store"
  fake_bin_dir="$tmp_root/partition-bin"
  work_dir="$tmp_root/partition-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  ( cd "$work_dir" && git init -q && git commit --allow-empty -m "init" -q ) 2>/dev/null || true
  work_dir_key="$(printf '%s\n' "$work_dir" | _portable_sha1 2>/dev/null || true)"
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
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

case_pmctl_dispatch_run_json_valid() {
  # Verifies that runs.jsonl row produced by pmctl dispatch is valid JSON
  # even when MODEL contains characters that would corrupt raw printf interpolation.
  #
  # Steps:
  #   1. Create a fake codex that exits 0.
  #   2. Run codex-dispatch.sh with --model set to a value with quotes/backslashes.
  #   3. Assert the runs.jsonl row parses with jq (exit 0).
  local name="pmctl-dispatch: run row is valid JSON with special chars in model"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file
  store="$tmp_root/json-valid"
  fake_bin_dir="$tmp_root/json-valid-bin"
  work_dir="$tmp_root/json-valid-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  # Use a model name with characters that would corrupt printf-based JSON
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --model 'model-with-"quotes"' \
    --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  if [[ -n "$runs_file" ]] && jq -e . "$runs_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "runs.jsonl missing or not valid JSON (file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_model_explicit() {
  # Verifies that an explicit --model flag is recorded in the Run row.
  local name="pmctl-dispatch: explicit --model stored in run row"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file model_found
  store="$tmp_root/model-explicit-store"
  fake_bin_dir="$tmp_root/model-explicit-bin"
  work_dir="$tmp_root/model-explicit-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --model "explicit-model-x" \
    --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  model_found="$(jq -r '.model' "$runs_file" 2>/dev/null | tail -1 || true)"
  if [[ "$model_found" == "explicit-model-x" ]]; then
    pass "$name"
  else
    fail "$name" "expected model=explicit-model-x got '${model_found:-none}' (runs_file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_model_config_default() {
  # Verifies that dispatch.default_model from the config file is stored in the
  # Run row when no explicit --model flag is given (uses PM_DISPATCH_CONFIG_FILE
  # to inject a fake config without touching ~/.pm-dispatch/config).
  local name="pmctl-dispatch: config dispatch.default_model stored in run row when no explicit --model"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file model_found cfg_file
  store="$tmp_root/model-config-store"
  fake_bin_dir="$tmp_root/model-config-bin"
  work_dir="$tmp_root/model-config-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  cfg_file="$tmp_root/model-config.cfg"
  printf 'dispatch.default_model = config-default-model\n' > "$cfg_file"
  PM_DISPATCH_STATE_ROOT="$store" PM_DISPATCH_CONFIG_FILE="$cfg_file" \
    PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  model_found="$(jq -r '.model' "$runs_file" 2>/dev/null | tail -1 || true)"
  if [[ "$model_found" == "config-default-model" ]]; then
    pass "$name"
  else
    fail "$name" "expected model=config-default-model got '${model_found:-none}' (runs_file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_model_builtin_default() {
  # Verifies that when neither --model nor PM_CFG_DEFAULT_MODEL is set, the Run
  # row records the adapter's built-in default alias ("default" for codex),
  # extracted from the adapter footer's "model:" line.
  local name="pmctl-dispatch: no --model and no PM_CFG_DEFAULT_MODEL stores adapter built-in default"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file model_found
  store="$tmp_root/model-builtin-store"
  fake_bin_dir="$tmp_root/model-builtin-bin"
  work_dir="$tmp_root/model-builtin-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    unset PM_CFG_DEFAULT_MODEL 2>/dev/null; \
    PM_DISPATCH_STATE_ROOT="$store" PM_CFG_DEFAULT_MODEL="" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  model_found="$(jq -r '.model' "$runs_file" 2>/dev/null | tail -1 || true)"
  if [[ "$model_found" == "default" ]]; then
    pass "$name"
  else
    fail "$name" "expected 'default' (adapter built-in via footer) but got '${model_found}' (runs_file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_subdir_partition_key() {
  # Verifies that dispatching with --cd pointing to a repo subdirectory writes
  # the run row under the repo root's partition key, not the subdirectory's key.
  #
  # Steps:
  #   1. git init a fresh tmpdir (repo_root); create a subdir inside it.
  #   2. Compute the expected partition key for the repo root.
  #   3. Run codex-dispatch.sh --cd <repo_root>/subdir.
  #   4. Assert runs.jsonl appears under projects/<root_key>/, not subdir key.
  local name="pmctl-dispatch: subdirectory --cd resolves to repo root partition"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file repo_root work_subdir root_key expected_partition git_top
  store="$tmp_root/subdir-store"
  fake_bin_dir="$tmp_root/subdir-bin"
  repo_root="$tmp_root/subdir-repo"
  work_subdir="$repo_root/sub/dir"
  mkdir -p "$fake_bin_dir" "$work_subdir"
  ( cd "$repo_root" && git init -q && git commit --allow-empty -m "init" -q ) 2>/dev/null || true
  git_top="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null || true)"
  root_key="$(printf '%s\n' "$git_top" | _portable_sha1 2>/dev/null || true)"
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_subdir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
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

case_sw_build_run_json_task_id_anchor() {
  # Verifies that prefixed keys like `parent_task_id:` are not mistaken for the
  # real `task_id:` line when extracting the task attribution for the run row.
  #
  # Steps:
  #   1. Write a brief with parent_task_id: CC-999 before task_id: CC-230.
  #   2. Run fake-codex dispatch.
  #   3. Assert that runs.jsonl has task_id == "CC-230", not "CC-999" or "UNKN-0".
  local name="sw_build_run_json: task_id extraction is anchored (ignores parent_task_id)"
  should_run "$name" || return 0
  local brief_file work_dir run_json task_id_found
  work_dir="$tmp_root/anchor-workdir"
  mkdir -p "$work_dir"
  brief_file="$tmp_root/anchor-brief.md"
  # parent_task_id: appears BEFORE task_id: - unanchored grep would pick CC-999
  printf 'parent_task_id: CC-999\ntask_id: CC-230\nDo nothing.\n' > "$brief_file"
  run_json="$(sw_build_run_json codex 0 ok model "$brief_file" "$work_dir" "")"
  task_id_found="$(jq -r '.task_id' <<< "$run_json" 2>/dev/null || true)"
  if [[ "$task_id_found" == "CC-230" ]]; then
    pass "$name"
  else
    fail "$name" "expected task_id=CC-230 but got task_id=${task_id_found:-none}"
  fi
}

case_sw_build_run_json_inline_brief_task_id() {
  # Verifies the backward-compatible builder still extracts task_id from inline brief text.
  local name="sw_build_run_json: inline brief task_id extraction"
  should_run "$name" || return 0
  local work_dir run_json task_id_found
  work_dir="$tmp_root/inline-brief-workdir"
  mkdir -p "$work_dir"
  run_json="$(sw_build_run_json codex 0 ok model "" "$work_dir" "" "task_id: CC-230
Do nothing.")"
  task_id_found="$(jq -r '.task_id' <<< "$run_json" 2>/dev/null || true)"
  if [[ "$task_id_found" == "CC-230" ]]; then
    pass "$name"
  else
    fail "$name" "expected task_id=CC-230 but got '${task_id_found:-none}'"
  fi
}

case_pmctl_dispatch_failed_records_state() {
  # Verifies that when the dispatched codex process exits non-zero, the run row
  # records state:"failed" and the actual exit code, not "ok".
  #
  # Steps:
  #   1. Create a fake codex that exits with code 42.
  #   2. Write a brief file with task_id: CC-230.
  #   3. Run codex-dispatch.sh (it exits non-zero but the wrapper may still exit 0).
  #   4. Assert runs.jsonl row has state == "failed" and exit_code == 42.
  local name="pmctl-dispatch: failed dispatch records state:failed and exit code"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file state_found exit_found
  store="$tmp_root/failed-dispatch-store"
  fake_bin_dir="$tmp_root/failed-dispatch-bin"
  work_dir="$tmp_root/failed-dispatch-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 42
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  state_found=""
  exit_found=""
  if [[ -n "$runs_file" ]]; then
    state_found="$(jq -r '.state' "$runs_file" 2>/dev/null | tail -1 || true)"
    exit_found="$(jq -r '.exit_code' "$runs_file" 2>/dev/null | tail -1 || true)"
  fi
  if [[ "$state_found" == "failed" && "$exit_found" == "42" ]]; then
    pass "$name"
  else
    fail "$name" "expected state=failed exit_code=42 but got state=${state_found:-none} exit_code=${exit_found:-none} (file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_pre_event_before_adapter() {
  local name="pmctl-dispatch: run.pending/run.dispatched Events emitted before adapter invocation"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir probe_file events_file first_two_kinds
  store="$tmp_root/pre-event-store"
  fake_bin_dir="$tmp_root/pre-event-bin"
  work_dir="$tmp_root/pre-event-workdir"
  probe_file="$tmp_root/pre-event-seen"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0 "$probe_file"
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  first_two_kinds=""
  [[ -n "$events_file" ]] && first_two_kinds="$(jq -r '.kind' "$events_file" 2>/dev/null | head -2 | paste -sd, - || true)"
  if [[ -s "$probe_file" && "$first_two_kinds" == "run.pending,run.dispatched" ]]; then
    pass "$name"
  else
    fail "$name" "probe=$([[ -s "$probe_file" ]] && echo seen || echo missing) first_two_kinds=${first_two_kinds:-none}"
  fi
}

case_pmctl_dispatch_completed_event() {
  local name="pmctl-dispatch: run.completed Event in events.jsonl after successful dispatch"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir events_file kinds run_ids
  store="$tmp_root/completed-event-store"
  fake_bin_dir="$tmp_root/completed-event-bin"
  work_dir="$tmp_root/completed-event-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  kinds=""
  run_ids=""
  if [[ -n "$events_file" ]]; then
    kinds="$(jq -r '.kind' "$events_file" 2>/dev/null | paste -sd, - || true)"
    run_ids="$(jq -r '.payload.run_id' "$events_file" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  fi
  if [[ "$kinds" == "run.pending,run.dispatched,run.verifying,run.completed" && "$run_ids" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "kinds=${kinds:-none} unique_run_ids=${run_ids:-none}"
  fi
}

case_pmctl_dispatch_full_fsm_sequence() {
  local name="pmctl-dispatch: full Run FSM event sequence after successful dispatch"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir events_file runs_file kinds states
  store="$tmp_root/full-fsm-store"
  fake_bin_dir="$tmp_root/full-fsm-bin"
  work_dir="$tmp_root/full-fsm-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  runs_file="$(find "$store" -name runs.jsonl -type f 2>/dev/null | head -1 || true)"
  kinds=""
  states=""
  [[ -n "$events_file" ]] && kinds="$(jq -r '.kind' "$events_file" 2>/dev/null | paste -sd, - || true)"
  [[ -n "$runs_file" ]] && states="$(jq -r '.state' "$runs_file" 2>/dev/null | paste -sd, - || true)"
  if [[ "$kinds" == "run.pending,run.dispatched,run.verifying,run.completed" && \
        "$states" == "pending,dispatched,verifying,ok" ]]; then
    pass "$name"
  else
    fail "$name" "kinds=${kinds:-none} states=${states:-none}"
  fi
}

case_pmctl_dispatch_terminal_run_event_invariant() {
  local name="pmctl-dispatch: every terminal Run has exactly one matching terminal Event"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file events_file terminal_count violations
  store="$tmp_root/terminal-invariant-store"
  fake_bin_dir="$tmp_root/terminal-invariant-bin"
  work_dir="$tmp_root/terminal-invariant-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name runs.jsonl -type f 2>/dev/null | head -1 || true)"
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  terminal_count="0"
  violations=""
  if [[ -n "$runs_file" && -n "$events_file" ]]; then
    terminal_count="$(jq -s '[.[] | select(.state == "ok" or .state == "partial" or .state == "failed")] | length' "$runs_file" 2>/dev/null || true)"
    violations="$(jq -nr --slurpfile runs "$runs_file" --slurpfile events "$events_file" '
      def terminal_run: .state == "ok" or .state == "partial" or .state == "failed";
      def terminal_event: .kind == "run.completed" or .kind == "run.failed";
      [
        $runs[] | select(terminal_run) as $run |
        {
          run_id: $run.id,
          run_op: ($run.operation_id // ""),
          events: [$events[] | select(terminal_event and .subject_id == $run.id)]
        } |
        select((.events | length) != 1 or .run_op == "" or (.events[0].operation_id // "") != .run_op)
      ] |
      map("\(.run_id):events=\(.events | length):run_op=\(.run_op):event_op=\(.events[0].operation_id // "")") |
      join(";")
    ' 2>/dev/null || true)"
  fi
  if [[ "$terminal_count" == "1" && -z "$violations" ]]; then
    pass "$name"
  else
    fail "$name" "terminal_count=${terminal_count:-none} violations=${violations:-missing-files}"
  fi
}

case_pmctl_dispatch_failed_event() {
  local name="pmctl-dispatch: run.failed Event in events.jsonl after failed adapter exit"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir events_file failed_exit
  store="$tmp_root/failed-event-store"
  fake_bin_dir="$tmp_root/failed-event-bin"
  work_dir="$tmp_root/failed-event-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 42
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  failed_exit=""
  [[ -n "$events_file" ]] && failed_exit="$(jq -r 'select(.kind=="run.failed") | .payload.exit_code' "$events_file" 2>/dev/null || true)"
  if [[ "$failed_exit" == "42" ]]; then
    pass "$name"
  else
    fail "$name" "failed_exit=${failed_exit:-none}"
  fi
}

case_pmctl_dispatch_pre_event_fail_blocks_adapter() {
  # Verifies that a run.pending Event write failure causes pmctl to return
  # non-zero and NOT invoke the adapter (adapter binary not called).
  #
  # Strategy: use a read-only store root so partition dir creation fails →
  # events_append for run.pending returns non-zero → pmctl returns early.
  # A probing codex writes a probe file on any invocation; its absence proves
  # the adapter was not called.
  local name="pmctl-dispatch: run.pending Event write failure blocks adapter invocation"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir probe_file rc=0
  store="$tmp_root/pre-event-fail-store"
  fake_bin_dir="$tmp_root/pre-event-fail-bin"
  work_dir="$tmp_root/pre-event-fail-workdir"
  probe_file="$tmp_root/pre-event-fail-probe"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_probing_codex "$fake_bin_dir" 0 "$probe_file"
  brief_file="$(mk_pmctl_brief "$work_dir")"
  mkdir -p "$store"
  chmod 500 "$store"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || rc=$?
  chmod 700 "$store"
  if [[ "$rc" -ne 0 && ! -f "$probe_file" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc probe=$([[ -f "$probe_file" ]] && echo invoked || echo not-invoked)"
  fi
}

case_pmctl_dispatch_terminal_event_append_fail() {
  # Verifies that when events_append fails for a transition after runs_append
  # succeeds, pmctl_dispatch_write_transition propagates non-zero.
  #
  # Strategy: use a poison codex that chmod 000s events.jsonl after the pre-adapter
  # transitions have been written, so the post-adapter Run append still succeeds
  # but the subsequent Event append fails.
  local name="pmctl-dispatch: write_transition returns non-zero when events_append fails after runs_append succeeds"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file events_files rc=0
  store="$tmp_root/terminal-event-fail-store"
  fake_bin_dir="$tmp_root/terminal-event-fail-bin"
  work_dir="$tmp_root/terminal-event-fail-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_poison_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  rc=0
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex \
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || rc=$?
  # Restore events.jsonl permissions so the temp dir can be cleaned up.
  find "$store" -name events.jsonl | xargs chmod 600 2>/dev/null || true
  runs_file="$(find "$store" -name runs.jsonl -type f 2>/dev/null | head -1 || true)"
  if [[ "$rc" -ne 0 && -s "$runs_file" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc runs_file=${runs_file:-none}"
  fi
}

if ! type -t pmctl_dispatch_write_transition >/dev/null 2>&1; then
  # shellcheck source=scripts/lib/pmctl-dispatch.sh
  . "$SCRIPT_DIR/lib/pmctl-dispatch.sh"
fi

case_fsm_valid_pending_to_dispatched() {
  local name="FSM: valid transition pending->dispatched succeeds"
  should_run "$name" || return 0
  local store work rc=0
  store="$tmp_root/fsm-valid-store"
  work="$tmp_root/fsm-valid-work"
  mkdir -p "$work"; git -C "$work" init -q
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-aaaaaa" "pending" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "" \
    >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && { fail "$name" "pending write rc=$rc"; return; }
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-aaaaaa" "dispatched" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "pending" \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "dispatched rc=$rc"; fi
}

case_fsm_invalid_ok_to_dispatched() {
  local name="FSM: invalid transition ok->dispatched returns non-zero"
  should_run "$name" || return 0
  local store work rc=0 stderr_out
  store="$tmp_root/fsm-ok-dispatched-store"
  work="$tmp_root/fsm-ok-dispatched-work"
  mkdir -p "$work"; git -C "$work" init -q
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-bbbbbb" "dispatched" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "ok" \
    2>&1 >/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 ]] && printf '%s' "$stderr_out" | grep -q "invalid transition"; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=$stderr_out"
  fi
}

case_fsm_invalid_verifying_to_pending() {
  local name="FSM: invalid transition verifying->pending returns non-zero"
  should_run "$name" || return 0
  local store work rc=0 stderr_out
  store="$tmp_root/fsm-vp-store"
  work="$tmp_root/fsm-vp-work"
  mkdir -p "$work"; git -C "$work" init -q
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-cccccc" "pending" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "verifying" \
    2>&1 >/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 ]] && printf '%s' "$stderr_out" | grep -q "invalid transition"; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=$stderr_out"
  fi
}

case_project_key_shasum_fallback() {
  local name="project_key: sha1sum missing but shasum available produces hash (not global)"
  should_run "$name" || return 0

  local tmp_git fake_bin result
  tmp_git="$(mktemp -d)"
  fake_bin="$(mktemp -d)"
  git -C "$tmp_git" init -q

  # shasum shim that ignores -a 1 args and delegates stdin to openssl
  printf '#!/bin/sh\nopenssl dgst -sha1 < /dev/stdin | awk '"'"'{print $NF}'"'"'\n' > "$fake_bin/shasum"
  chmod +x "$fake_bin/shasum"

  # FAKE_SHA1SUM_MISSING=1 blocks the direct sha1sum branch in _portable_sha1;
  # the shasum shim in fake_bin provides a working fallback via openssl internally.
  result="$(
    FAKE_SHA1SUM_MISSING=1 PATH="$fake_bin:$PATH" _SW_REPO_ROOT="$tmp_git" \
      bash -c "source '$REPO_ROOT/scripts/lib/state-writer.sh' 2>/dev/null
               _sw_project_key"
  )" || true
  rm -rf "$tmp_git" "$fake_bin"

  # Must be a 40-char hex string, NOT "global" - proves shasum fallback was used
  if [[ "$result" =~ ^[0-9a-f]{40}$ ]]; then
    pass "$name"
  else
    fail "$name" "expected 40-char hex via shasum fallback, got '${result:-empty}'"
  fi
}

case_project_key_no_sha1sum() {
  local name="project_key: no sha1sum or shasum falls back to global"
  # Create a minimal repo so _sw_project_key has a git root to hash.
  local tmp_root
  tmp_root="$(mktemp -d)"
  git -C "$tmp_root" init -q
  # Force both sha1sum and shasum unavailable via FAKE_SHA1_MISSING=1.
  # Source state-writer.sh (which sources portable.sh) and call _sw_project_key.
  local result
  result="$(
    FAKE_SHA1_MISSING=1 _SW_REPO_ROOT="$tmp_root" \
      bash -c "source '$REPO_ROOT/scripts/lib/state-writer.sh' 2>/dev/null; _sw_project_key"
  )" || true
  rm -rf "$tmp_root"
  if [[ "$result" == "global" ]]; then
    pass "$name"
  else
    fail "$name" "expected 'global' but got '${result:-empty}'"
  fi
}

case_store_root_override
case_store_root_xdg
case_store_root_default
case_state_store_init_structure
case_state_store_init_version1_noop
case_state_store_init_version2_fails
case_runs_append_fails_on_version2
case_runs_append_valid_jsonl
case_runs_append_appends
case_events_append
case_runs_append_rejects_newline
case_runs_append_rejects_nul
case_events_append_rejects_newline
case_events_append_rejects_nul
case_events_append_rejects_run_event_without_payload() {
  local name="state-store: events_append rejects run.completed event missing payload"
  should_run "$name" || return 0
  if ! command -v jsonschema >/dev/null 2>&1; then
    pass "$name (skip: jsonschema not available)"
    return 0
  fi
  local store rc=0
  store="$tmp_root/events-no-payload"
  PM_DISPATCH_STATE_ROOT="$store" events_append \
    '{"schema_version":1,"id":"evt-20260101T000000Z-abcdef","ts":"2026-01-01T00:00:00Z","kind":"run.completed","subject_type":"run","subject_id":"run-20260101T000000Z-abcdef"}' \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero for run.completed event without payload, got rc=$rc"
  fi
}
case_events_append_rejects_run_event_without_payload
case_runs_append_compacts_json
case_runs_append_rejects_malformed_json
case_runs_append_rejects_schema_invalid
case_task_upsert
case_task_upsert_invalid_id
case_runs_append_read_only_fails_loudly
case_codex_dispatch_state_store_self_contained
case_pmctl_dispatch_creates_run_row
case_pmctl_dispatch_correct_partition
case_pmctl_dispatch_run_json_valid
case_pmctl_dispatch_model_explicit
case_pmctl_dispatch_model_config_default
case_pmctl_dispatch_model_builtin_default
case_pmctl_dispatch_subdir_partition_key
case_sw_build_run_json_task_id_anchor
case_sw_build_run_json_inline_brief_task_id
case_pmctl_dispatch_failed_records_state
case_pmctl_dispatch_pre_event_before_adapter
case_pmctl_dispatch_completed_event
case_pmctl_dispatch_full_fsm_sequence
case_pmctl_dispatch_terminal_run_event_invariant
case_pmctl_dispatch_failed_event
case_pmctl_dispatch_pre_event_fail_blocks_adapter
case_pmctl_dispatch_terminal_event_append_fail
case_fsm_valid_pending_to_dispatched
case_fsm_invalid_ok_to_dispatched
case_fsm_invalid_verifying_to_pending
case_project_key_shasum_fallback
case_project_key_no_sha1sum

th_summary
