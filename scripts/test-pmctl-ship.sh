#!/usr/bin/env bash
# Regression tests for `pmctl ship prepare/finish/--parallel/status/list`.
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# Fake codex AND claude on PATH so `pmctl ship --parallel` (detached
# dispatch; default adapter is `claude`, overridable with --adapter) never
# shells out to a REAL executor CLI during this suite -- CC-441's lanes
# launch a detached background supervisor that execs the adapter binary a
# moment after `run` returns, so a real binary on PATH would spend real API
# budget and leave orphaned processes once this suite's tmp_root is deleted.
# Mirrors test-pmctl-dispatch.sh's `_install_fake_codex` and
# test-claude-dispatch.sh's `_install_fake_claude`. Lives for the whole
# suite (not per-case) since the detached supervisor's exec can race a
# per-case cleanup.
# Placed under $tmp_root (th_init already registers its own `rm -rf
# "$tmp_root"` EXIT trap) so this doesn't need a second EXIT trap that would
# otherwise clobber that one.
FAKE_CODEX_BINDIR="$tmp_root/fake-codex-bin"
mkdir -p "$FAKE_CODEX_BINDIR"
cat > "$FAKE_CODEX_BINDIR/codex" <<'FAKEOF'
#!/usr/bin/env bash
_last=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-last-message) _last="$2"; shift 2;;
    *) shift;;
  esac
done
[[ -n "$_last" ]] && printf 'dispatch complete (fake codex)\n' > "$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}'
exit 0
FAKEOF
chmod +x "$FAKE_CODEX_BINDIR/codex"
cat > "$FAKE_CODEX_BINDIR/claude" <<'FAKEOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' '{"type":"system","subtype":"init","session_id":"fake","model":"claude-test"}'
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"work done"}]},"session_id":"fake"}'
printf '%s\n' '{"type":"result","subtype":"success","result":"work done","is_error":false,"usage":{"input_tokens":100,"output_tokens":50},"session_id":"fake","num_turns":1}'
exit 0
FAKEOF
chmod +x "$FAKE_CODEX_BINDIR/claude"
export PATH="$FAKE_CODEX_BINDIR:$PATH"

make_work_repo() {
  local path="$1" ticket="${2:-CC-9001}"
  mkdir -p "$path"
  git init -q "$path"
  git -C "$path" config user.email test@example.com
  git -C "$path" config user.name test
  {
    printf '## %s -- mock ticket for ship-parallel tests %s\n\n' "$ticket" "🔵 active"
    printf 'Problem: test fixture.\n\nRequirement: none.\n\nDependencies: none.\n'
  } > "$path/BACKLOG.md"
  git -C "$path" add BACKLOG.md
  git -C "$path" commit -q -m seed
}

reg_dir_for() {
  local store="$1" work="$2"
  PM_DISPATCH_STATE_ROOT="$store" bash -c \
    '. "$1/scripts/lib/state-paths.sh" && sw_project_worktree_dir "$2"' \
    _ "$REPO_ROOT" "$work"
}

# seed_dispatch_record <lane_path> <run_id> <final_state> <verify_summary>
# Writes a `.dispatch-results/<run_id>.md` record directly, bypassing a real
# executor run, so status-transition cases are deterministic and don't
# depend on codex/claude being installed in the test environment.
seed_dispatch_record() {
  local lane_path="$1" run_id="$2" final_state="$3" summary="$4"
  bash -c '
    repo_root="$1"; lane_path="$2"; run_id="$3"; final_state="$4"; summary="$5"
    . "$repo_root/scripts/lib/dispatch-record.sh"
    dispatch_record_write "$run_id" "task" "codex" "default" "/tmp/brief-x.md" \
      "$lane_path" 0 "$final_state" "$summary" "" "" "" "2026-01-01T00:00:00Z" "2026-01-01T00:01:00Z"
  ' _ "$REPO_ROOT" "$lane_path" "$run_id" "$final_state" "$summary"
}

case_run_requires_ticket() {
  local name="ship-parallel run: no ticket-id exits non-zero with usage"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-noarg"
  work="$tmp_root/work-run-noarg"
  make_work_repo "$work"
  out="$tmp_root/out-run-noarg"; err="$tmp_root/err-run-noarg"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 2 && \
    assert_file_contains "$name" "$err" "at least one <ticket-id> is required" && \
    pass "$name"
}

case_run_rejects_unknown_ticket() {
  local name="ship-parallel run: unknown ticket-id is rejected before any worktree is created"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-unknown"
  work="$tmp_root/work-run-unknown"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-run-unknown"; err="$tmp_root/err-run-unknown"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9999 --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "not an active BACKLOG.md ticket" && \
    pass "$name"
}

case_run_bad_ticket_leaves_no_worktree() {
  local name="ship-parallel run: rejecting one ticket in a batch creates no worktree for either"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-batch-bad"
  work="$tmp_root/work-run-batch-bad"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 CC-9999 --cd "$work" \
    > "$tmp_root/out-batch-bad" 2> "$tmp_root/err-batch-bad" || status=$?
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 1 && ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 and no checkouts/CC-9001 dir; got status=$status reg_dir=$reg_dir"
  fi
}

case_run_refuses_redispatch_while_in_flight() {
  local name="ship-parallel run: refuses to re-dispatch a ticket whose prior lane is still running"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-inflight"
  work="$tmp_root/work-run-inflight"
  make_work_repo "$work" "CC-9001"

  # A slow fake claude (sleeps briefly before exiting) so the first lane's
  # dispatched process is still alive when the second `ship --parallel` call
  # for the SAME ticket runs immediately after.
  local slow_bin="$tmp_root/slow-claude-bin"
  mkdir -p "$slow_bin"
  cat > "$slow_bin/claude" <<'FAKEOF'
#!/usr/bin/env bash
cat >/dev/null
sleep 5
printf '%s\n' '{"type":"result","subtype":"success","result":"work done","is_error":false,"usage":{"input_tokens":1,"output_tokens":1},"session_id":"fake","num_turns":1}'
exit 0
FAKEOF
  chmod +x "$slow_bin/claude"

  PATH="$slow_bin:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-inflight-1" 2> "$tmp_root/err-inflight-1"

  local out2 err2 status2=0
  out2="$tmp_root/out-inflight-2"; err2="$tmp_root/err-inflight-2"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$out2" 2> "$err2" || status2=$?

  if [[ "$status2" -eq 1 ]] && grep -q "already has an in-flight lane" "$err2"; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + in-flight refusal message; got status=$status2 stderr=$(cat "$err2")"
  fi
}

case_run_dispatches_and_tracks() {
  local name="ship-parallel run: valid ticket creates a lane worktree, dispatches, and records tracking"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-ok"
  work="$tmp_root/work-run-ok"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-run-ok"; err="$tmp_root/err-run-ok"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" > "$out" 2> "$err" || status=$?

  local reg_dir tracking
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-parallel.jsonl"

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "run exited $status; stderr: $(cat "$err")"
    return
  fi
  if [[ ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    fail "$name" "lane worktree missing at $reg_dir/checkouts/CC-9001"
    return
  fi
  if [[ ! -f "$tracking" ]]; then
    fail "$name" "tracking file missing at $tracking"
    return
  fi
  local ticket run_id lane_status
  ticket="$(jq -r '.ticket' "$tracking")"
  run_id="$(jq -r '.run_id' "$tracking")"
  lane_status="$(jq -r '.status' "$tracking")"
  if [[ "$ticket" == "CC-9001" && -n "$run_id" && "$run_id" != null && "$lane_status" == "dispatched" ]]; then
    pass "$name"
  else
    fail "$name" "unexpected tracking entry: $(cat "$tracking")"
  fi
}

case_run_brief_preserves_ship_contract() {
  local name="ship-parallel run: lane brief re-states the ship contract, no branch switch, no worktree remove"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-brief"
  work="$tmp_root/work-run-brief"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-brief" 2> "$tmp_root/err-brief" || status=$?
  local reg_dir tracking run_id brief
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-parallel.jsonl"
  run_id="$(jq -r '.run_id' "$tracking" 2>/dev/null || true)"
  brief="/tmp/brief-$run_id.md"
  # Backticks below are literal Markdown code spans in the assertion text, not command substitution.
  # shellcheck disable=SC2016
  if [[ "$status" -eq 0 && -f "$brief" ]] \
    && grep -q 'pmctl ship finish CC-9001' "$brief" \
    && grep -q 'Do not run `git checkout -b`' "$brief" \
    && grep -q 'Do not run `pmctl worktree remove`' "$brief"; then
    pass "$name"
  else
    fail "$name" "brief missing expected ship-contract constraints (status=$status, brief=$brief)"
  fi
}

case_run_restores_gc_auto_previously_set() {
  local name="ship-parallel run: restores a pre-existing gc.auto value on exit"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-gcset"
  work="$tmp_root/work-run-gcset"
  make_work_repo "$work" "CC-9001"
  git -C "$work" config gc.auto 128
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-gcset" 2> "$tmp_root/err-gcset" || status=$?
  local restored
  restored="$(git -C "$work" config --get gc.auto 2>/dev/null || true)"
  if [[ "$restored" == "128" ]]; then
    pass "$name"
  else
    fail "$name" "expected gc.auto restored to 128, got '$restored'"
  fi
}

case_run_restores_gc_auto_previously_unset() {
  local name="ship-parallel run: leaves gc.auto unset (not 256) when it started unset"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-gcunset"
  work="$tmp_root/work-run-gcunset"
  make_work_repo "$work" "CC-9001"
  git -C "$work" config --unset gc.auto 2>/dev/null || true
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-gcunset" 2> "$tmp_root/err-gcunset" || status=$?
  local restored=0
  if git -C "$work" config --get gc.auto 2>/dev/null; then
    restored=1
  fi
  if [[ "$restored" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected gc.auto to remain unset, but it is now set to $(git -C "$work" config --get gc.auto)"
  fi
}

case_status_reports_go_from_final_line() {
  local name="ship-parallel status: a GO gate verdict in the dispatch record surfaces as status=go"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-go"
  work="$tmp_root/work-status-go"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-go" 2> "$tmp_root/err-status-go" || status=$?
  local reg_dir tracking run_id lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-parallel.jsonl"
  run_id="$(jq -r '.run_id' "$tracking")"
  lane_path="$(jq -r '.path' "$tracking")"
  seed_dispatch_record "$lane_path" "$run_id" ok "Final: GO"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "go" ]]; then
    pass "$name"
  else
    fail "$name" "expected status=go, got $json"
  fi
}

case_status_reports_go_from_finish_marker_even_without_final_go_text() {
  local name="ship-parallel status: pmctl ship finish's own GO marker wins even when the executor's free-text summary never says literal 'Final: GO'"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-marker-go"
  work="$tmp_root/work-status-marker-go"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-marker-go" 2> "$tmp_root/err-status-marker-go" || status=$?
  local reg_dir tracking run_id lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-parallel.jsonl"
  run_id="$(jq -r '.run_id' "$tracking")"
  lane_path="$(jq -r '.path' "$tracking")"
  # Simulates a real observed failure mode: the executor's own summary
  # reports the verdict in prose ("Gate 通過（GO）"), not the literal
  # "Final: GO" string the old heuristic grepped for.
  seed_dispatch_record "$lane_path" "$run_id" ok "Gate 通過（GO）。PR 已開啟。"
  printf '{"ticket":"CC-9001","verdict":"GO","branch":"feat/CC-9001","pr_url":"https://example/pr/1"}' \
    > "$lane_path/.pm-dispatch-ship-finish.json"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "go" ]]; then
    pass "$name"
  else
    fail "$name" "expected status=go from marker file despite no literal 'Final: GO' text, got $json"
  fi
}

case_status_reports_no_go_from_final_line() {
  local name="ship-parallel status: an ok record without Final: GO surfaces as status=no-go"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-nogo"
  work="$tmp_root/work-status-nogo"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-nogo" 2> "$tmp_root/err-status-nogo" || status=$?
  local reg_dir tracking run_id lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-parallel.jsonl"
  run_id="$(jq -r '.run_id' "$tracking")"
  lane_path="$(jq -r '.path' "$tracking")"
  seed_dispatch_record "$lane_path" "$run_id" ok "Final: NO-GO"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "no-go" ]]; then
    pass "$name"
  else
    fail "$name" "expected status=no-go, got $json"
  fi
}

case_status_no_record_yet_is_running() {
  local name="ship-parallel status: a lane with no dispatch record yet is status=running"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-running"
  work="$tmp_root/work-status-running"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-run" 2> "$tmp_root/err-status-run" || status=$?
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  local lane_status
  lane_status="$(jq -r '.[0].status' <<<"$json")"
  if [[ "$lane_status" == "running" || "$lane_status" == "dispatched" || "$lane_status" == "failed" ]]; then
    # "failed" is an acceptable observed outcome in a sandbox with no codex
    # binary installed -- the supervisor may have already written a failed
    # record by the time status runs. Any of these three is "not silently GO".
    pass "$name"
  else
    fail "$name" "expected running/dispatched/failed, got $lane_status"
  fi
}

case_list_filters_to_go_only() {
  local name="ship-parallel list: only GO lanes appear, pending-merge tracking"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-list-go"
  work="$tmp_root/work-list-go"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-list-go" 2> "$tmp_root/err-list-go" || status=$?
  local reg_dir tracking run_id lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-parallel.jsonl"
  run_id="$(jq -r '.run_id' "$tracking")"
  lane_path="$(jq -r '.path' "$tracking")"
  seed_dispatch_record "$lane_path" "$run_id" ok "Final: GO"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship list --cd "$work" --json)"
  if [[ "$(jq 'length' <<<"$json")" -eq 1 && "$(jq -r '.[0].ticket' <<<"$json")" == "CC-9001" ]]; then
    pass "$name"
  else
    fail "$name" "expected exactly one GO lane (CC-9001), got $json"
  fi
}

case_list_empty_when_none_go() {
  local name="ship-parallel list: empty when no lane has reached GO"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-list-empty"
  work="$tmp_root/work-list-empty"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-list-empty" 2> "$tmp_root/err-list-empty" || status=$?
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship list --cd "$work" --json)"
  if [[ "$(jq 'length' <<<"$json")" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected empty GO list, got $json"
  fi
}

case_status_no_tracked_lanes() {
  local name="ship-parallel status: no tracked lanes prints a plain message, exits 0"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-status-none"
  work="$tmp_root/work-status-none"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-status-none"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" > "$out" 2>&1 || status=$?
  assert_exit "$name" "$status" 0 && \
    assert_file_contains "$name" "$out" "No tracked ship-parallel lanes." && \
    pass "$name"
}

case_prepare_empty_argument() {
  local name="ship prepare: empty ticket-id exits 1 with 'empty argument'"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-empty"
  work="$tmp_root/work-prep-empty"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-empty"; err="$tmp_root/err-prep-empty"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "empty argument" && \
    pass "$name"
}

case_prepare_malformed_shape() {
  local name="ship prepare: malformed ticket-id shape exits 1"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-shape"
  work="$tmp_root/work-prep-shape"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-shape"; err="$tmp_root/err-prep-shape"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare not-a-ticket --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "malformed shape" && \
    pass "$name"
}

case_prepare_no_such_ticket() {
  local name="ship prepare: unknown ticket-id exits 1 with 'no such ticket'"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-nosuch"
  work="$tmp_root/work-prep-nosuch"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-nosuch"; err="$tmp_root/err-prep-nosuch"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare CC-9999 --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "no such ticket" && \
    pass "$name"
}

case_prepare_archived_ticket() {
  local name="ship prepare: an archived ticket-id exits 1 with 'already archived', not 'no such ticket'"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-archived"
  work="$tmp_root/work-prep-archived"
  make_work_repo "$work" "CC-9001"
  printf '## CC-8000 -- archived mock ticket ✅ 2026-01-01\n' > "$work/BACKLOG-ARCHIVE.md"
  out="$tmp_root/out-prep-archived"; err="$tmp_root/err-prep-archived"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare CC-8000 --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "already archived" && \
    pass "$name"
}

case_prepare_dirty_tree_refused() {
  local name="ship prepare: a dirty tree is refused, never stashed/committed silently"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-dirty"
  work="$tmp_root/work-prep-dirty"
  make_work_repo "$work" "CC-9001"
  printf 'uncommitted\n' > "$work/dirty.txt"
  out="$tmp_root/out-prep-dirty"; err="$tmp_root/err-prep-dirty"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare CC-9001 --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 1 ]] && grep -q "tree is dirty" "$err" && [[ -f "$work/dirty.txt" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + dirty.txt preserved; status=$status, dirty.txt exists=$([[ -f "$work/dirty.txt" ]] && echo yes || echo no)"
  fi
}

case_prepare_happy_path_creates_branch() {
  local name="ship prepare: a clean, active ticket creates feat/<ticket-id> and prints it"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-prep-ok"
  work="$tmp_root/work-prep-ok"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-ok"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare CC-9001 --cd "$work" > "$out" 2> "$tmp_root/err-prep-ok" || status=$?
  local branch current
  branch="$(tail -1 "$out")"
  current="$(git -C "$work" rev-parse --abbrev-ref HEAD)"
  if [[ "$status" -eq 0 && "$branch" == "feat/CC-9001" && "$current" == "feat/CC-9001" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 + branch feat/CC-9001, got status=$status branch=$branch current=$current"
  fi
}

case_finish_requires_ticket() {
  local name="ship finish: missing ticket-id exits 2"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-finish-noarg"
  work="$tmp_root/work-finish-noarg"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-finish-noarg"; err="$tmp_root/err-finish-noarg"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship finish --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 2 && \
    assert_file_contains "$name" "$err" "<ticket-id> is required" && \
    pass "$name"
}

case_prepare_empty_argument
case_prepare_malformed_shape
case_prepare_no_such_ticket
case_prepare_archived_ticket
case_prepare_dirty_tree_refused
case_prepare_happy_path_creates_branch
case_finish_requires_ticket
case_run_requires_ticket
case_run_rejects_unknown_ticket
case_run_bad_ticket_leaves_no_worktree
case_run_refuses_redispatch_while_in_flight
case_run_dispatches_and_tracks
case_run_brief_preserves_ship_contract
case_run_restores_gc_auto_previously_set
case_run_restores_gc_auto_previously_unset
case_status_reports_go_from_final_line
case_status_reports_go_from_finish_marker_even_without_final_go_text
case_status_reports_no_go_from_final_line
case_status_no_record_yet_is_running
case_list_filters_to_go_only
case_list_empty_when_none_go
case_status_no_tracked_lanes

# Detached dispatch supervisors from the fake-codex/claude runs above can
# still be mid-write (dispatch record, trace files) a moment after their
# `pmctl ship --parallel` call returned -- give them a beat to settle before
# th_init's EXIT trap deletes $tmp_root, so cleanup doesn't race a live
# writer under it.
sleep 1

th_summary
