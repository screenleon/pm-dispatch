#!/usr/bin/env bash
# Regression tests for artifact discovery surfaces.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"
WATCH="$REPO_ROOT/ops/diagnostics/codex-watch.sh"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/state-paths.sh
. "$REPO_ROOT/runtime/lib/state-paths.sh"

make_work_repo() {
  local path="$1"
  mkdir -p "$path"
  git init -q "$path"
}

run_dir_for() {
  local store="$1" work="$2" run_id="$3"
  PM_DISPATCH_STATE_ROOT="$store" bash -c 'cd "$1" && . "$2/runtime/lib/state-paths.sh" && sw_project_run_dir "$3"' \
    _ "$work" "$REPO_ROOT" "$run_id"
}

write_run_file() {
  local store="$1" work="$2" run_id="$3" rel="$4" body="$5"
  local rd file
  rd="$(run_dir_for "$store" "$work" "$run_id")"
  file="$rd/$rel"
  mkdir -p "$(dirname "$file")"
  printf '%s' "$body" > "$file"
}

install_jq_stub() {
  local bin="$1"
  mkdir -p "$bin"
  cat > "$bin/jq" <<'EOF'
#!/usr/bin/env bash
while IFS= read -r line; do
  printf 'JQ:%s\n' "$line"
done
EOF
  chmod +x "$bin/jq"
}

run_watch_for_sample() {
  local out="$1" err="$2"
  shift 2
  local status=0
  timeout 1s "$@" > "$out" 2> "$err" || status=$?
  [[ "$status" -eq 124 || "$status" -eq 0 ]]
}

case_artifacts_list_newest_first() {
  local name="pmctl artifacts list: run dirs sorted newest-first with timestamps"
  should_run "$name" || return 0
  local store work old new out err status=0 first second
  store="$tmp_root/state-list"
  work="$tmp_root/work-list"
  make_work_repo "$work"
  old="$(run_dir_for "$store" "$work" run-old)"
  new="$(run_dir_for "$store" "$work" run-new)"
  mkdir -p "$old" "$new"
  printf 'old\n' > "$old/run-old.footer"
  printf 'new\n' > "$new/run-new.footer"
  touch -t 202606250101 "$old/run-old.footer" "$old"
  touch -t 202606250102 "$new/run-new.footer" "$new"
  out="$tmp_root/list.out"; err="$tmp_root/list.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts list --cd "$work" > "$out" 2> "$err" || status=$?
  first="$(sed -n '1p' "$out" | cut -f1)"
  second="$(sed -n '2p' "$out" | cut -f1)"
  if [[ "$status" -eq 0 && "$first" == "run-new" && "$second" == "run-old" &&
        "$(sed -n '1p' "$out")" == *$'\t'* && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_artifacts_list_empty() {
  local name="pmctl artifacts list: empty partition prints no runs"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-empty"
  work="$tmp_root/work-empty"
  make_work_repo "$work"
  out="$tmp_root/empty.out"; err="$tmp_root/empty.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts list --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 && "$(<"$out")" == "(no runs found)" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_artifacts_show_files() {
  local name="pmctl artifacts show: prints files with sizes"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-show"
  work="$tmp_root/work-show"
  make_work_repo "$work"
  write_run_file "$store" "$work" run-show ".agent-trace/latest.jsonl" $'abc\n'
  write_run_file "$store" "$work" run-show ".gate-results/result.md" "go"
  out="$tmp_root/show.out"; err="$tmp_root/show.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts show run-show --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 ]] &&
     grep -Fq $'4\t.agent-trace/latest.jsonl' "$out" &&
     grep -Fq $'2\t.gate-results/result.md' "$out" &&
     [[ ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_artifacts_show_missing() {
  local name="pmctl artifacts show: missing run exits 1 with actionable message"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-missing"
  work="$tmp_root/work-missing"
  make_work_repo "$work"
  out="$tmp_root/missing.out"; err="$tmp_root/missing.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts show run-missing --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 1 && ! -s "$out" ]] &&
     grep -Fq 'run dir not found for run-missing' "$err" &&
     grep -Fq 'pmctl artifacts list' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_codex_watch_trace_flag() {
  local name="codex-watch: --trace tails explicit absolute JSONL path"
  should_run "$name" || return 0
  local bin trace out err status=0
  bin="$tmp_root/bin-trace"
  install_jq_stub "$bin"
  trace="$tmp_root/direct.jsonl"
  printf '{"type":"turn.started"}\n' > "$trace"
  out="$tmp_root/watch-trace.out"; err="$tmp_root/watch-trace.err"
  run_watch_for_sample "$out" "$err" env PATH="$bin:$PATH" bash "$WATCH" --trace "$trace" || status=$?
  if [[ "$status" -eq 0 && "$(<"$out")" == *'JQ:{"type":"turn.started"}'* && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_codex_watch_run_flag() {
  local name="codex-watch: --run resolves out-of-repo latest trace"
  should_run "$name" || return 0
  local store work bin out err status=0
  store="$tmp_root/state-watch-run"
  work="$tmp_root/work-watch-run"
  bin="$tmp_root/bin-run"
  make_work_repo "$work"
  install_jq_stub "$bin"
  write_run_file "$store" "$work" run-watch ".agent-trace/latest.jsonl" $'{"type":"turn.completed"}\n'
  out="$tmp_root/watch-run.out"; err="$tmp_root/watch-run.err"
  run_watch_for_sample "$out" "$err" env PM_DISPATCH_STATE_ROOT="$store" PATH="$bin:$PATH" bash "$WATCH" --cd "$work" --run run-watch || status=$?
  if [[ "$status" -eq 0 && "$(<"$out")" == *'JQ:{"type":"turn.completed"}'* && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_codex_watch_auto_discover() {
  local name="codex-watch: auto-discovers newest out-of-repo run trace"
  should_run "$name" || return 0
  local store work bin old new out err status=0
  store="$tmp_root/state-watch-auto"
  work="$tmp_root/work-watch-auto"
  bin="$tmp_root/bin-auto"
  make_work_repo "$work"
  install_jq_stub "$bin"
  write_run_file "$store" "$work" run-old ".agent-trace/latest.jsonl" $'{"type":"old"}\n'
  write_run_file "$store" "$work" run-new ".agent-trace/latest.jsonl" $'{"type":"new"}\n'
  old="$(run_dir_for "$store" "$work" run-old)"
  new="$(run_dir_for "$store" "$work" run-new)"
  touch -t 202606250101 "$old"
  touch -t 202606250102 "$new"
  out="$tmp_root/watch-auto.out"; err="$tmp_root/watch-auto.err"
  run_watch_for_sample "$out" "$err" env PM_DISPATCH_STATE_ROOT="$store" PATH="$bin:$PATH" bash "$WATCH" --cd "$work" || status=$?
  if [[ "$status" -eq 0 && "$(<"$out")" == *'JQ:{"type":"new"}'* && "$(<"$out")" != *'JQ:{"type":"old"}'* && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_dry_run() {
  # behavior: pmctl artifacts gc --dry-run lists would-delete candidates with exact count and leaves dirs intact
  # Steps: create partition with 3 runs (1 keep, 2 old); run gc --dry-run --keep-last 1;
  #        assert 2 "would delete" lines, final summary reports 2, no dirs removed
  local name="pmctl artifacts gc: --dry-run lists would-delete but deletes nothing"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-dry"
  work="$tmp_root/work-gc-dry"
  make_work_repo "$work"

  # Create 3 runs; make 2 older than 30 days
  local rd_keep rd_old1 rd_old2
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old1="$(run_dir_for "$store" "$work" run-old1)"
  rd_old2="$(run_dir_for "$store" "$work" run-old2)"
  mkdir -p "$rd_keep" "$rd_old1" "$rd_old2"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old1/a.footer"
  printf 'b\n' > "$rd_old2/b.footer"
  # Make old runs appear 40 days old
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old1" "$rd_old2" 2>/dev/null || true

  out="$tmp_root/gc-dry.out"; err="$tmp_root/gc-dry.err"
  PM_DISPATCH_STATE_ROOT="$store" PM_DISPATCH_GC_KEEP_LAST=1 "$PMCTL" artifacts gc \
    --dry-run --keep-last 1 --cd "$work" > "$out" 2> "$err" || status=$?

  local out_content; out_content="$(<"$out")"
  local would_delete_count; would_delete_count="$(grep -c 'would delete:' "$out" 2>/dev/null || printf '0')"
  # Check: 2 "would delete" lines, final summary says "would delete 2", dirs still exist
  if [[ "$status" -eq 0 && "$would_delete_count" -eq 2 &&
        "$out_content" == *"would delete 2 runs"* &&
        -d "$rd_old1" && -d "$rd_old2" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status would_delete_count=$would_delete_count out=$out_content err=$(<"$err")"
  fi
}

case_gc_keep_last() {
  # behavior: pmctl artifacts gc --keep-last N deletes eligible old runs, keeps newest N
  # Steps: create 3 runs with different timestamps; gc --keep-last 1 --max-age-days 30;
  #        assert oldest 2 are deleted and newest 1 survives
  local name="pmctl artifacts gc: --keep-last retains newest N runs"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-keep"
  work="$tmp_root/work-gc-keep"
  make_work_repo "$work"

  local rd1 rd2 rd3
  rd1="$(run_dir_for "$store" "$work" run-1)"
  rd2="$(run_dir_for "$store" "$work" run-2)"
  rd3="$(run_dir_for "$store" "$work" run-3)"
  mkdir -p "$rd1" "$rd2" "$rd3"
  printf 'a\n' > "$rd1/a.footer"
  printf 'b\n' > "$rd2/b.footer"
  printf 'c\n' > "$rd3/c.footer"
  # Assign distinct timestamps: rd3 newest, rd1 oldest
  touch -t "$(date -d '50 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-50d +%Y%m%d%H%M)" "$rd1" 2>/dev/null || true
  touch -t "$(date -d '45 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-45d +%Y%m%d%H%M)" "$rd2" 2>/dev/null || true
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd3" 2>/dev/null || true

  out="$tmp_root/gc-keep.out"; err="$tmp_root/gc-keep.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --max-age-days 30 --cd "$work" > "$out" 2> "$err" || status=$?

  # rd3 (newest) should survive; rd1 and rd2 should be deleted
  if [[ "$status" -eq 0 && -d "$rd3" && ! -d "$rd1" && ! -d "$rd2" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err") rd3=$(test -d "$rd3" && echo y||echo n) rd1=$(test -d "$rd1" && echo y||echo n)"
  fi
}

case_gc_max_age_zero() {
  # behavior: pmctl artifacts gc --max-age-days 0 disables age filter; only keep-last applies
  # Steps: create 2 runs (1 very old); gc --keep-last 2 --max-age-days 0;
  #        assert both survive because keep-last covers them all
  local name="pmctl artifacts gc: --max-age-days 0 applies only keep-last (skips age filter)"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-age0"
  work="$tmp_root/work-gc-age0"
  make_work_repo "$work"

  local rd1 rd2
  rd1="$(run_dir_for "$store" "$work" run-a)"
  rd2="$(run_dir_for "$store" "$work" run-b)"
  mkdir -p "$rd1" "$rd2"
  printf 'a\n' > "$rd1/a.footer"
  printf 'b\n' > "$rd2/b.footer"
  # Make rd1 appear very old — should still survive if keep-last covers it
  touch -t "$(date -d '365 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-365d +%Y%m%d%H%M)" "$rd1" 2>/dev/null || true

  out="$tmp_root/gc-age0.out"; err="$tmp_root/gc-age0.err"
  # keep-last=2 means both survive even with age=0 (no age filter)
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 2 --max-age-days 0 --cd "$work" > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 && -d "$rd1" && -d "$rd2" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_safety_rejects_pm_dispatch() {
  # behavior: _pmctl_artifacts_safe_rm_check returns 1 and stderr error for .pm-dispatch paths
  # Steps: call safety check with a path containing .pm-dispatch; assert exit 1 and error message
  local name="pmctl artifacts gc: safety check rejects path containing .pm-dispatch"
  should_run "$name" || return 0
  # Source the lib directly to test the safety function
  local status=0 out err
  out="$tmp_root/safe-check.out"; err="$tmp_root/safe-check.err"
  bash -c ". '$REPO_ROOT/runtime/lib/pmctl-artifacts.sh' && _pmctl_artifacts_safe_rm_check '/some/.pm-dispatch/runs/run-abc'" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 && "$(<"$err")" == *".pm-dispatch"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_all_repos_removes_inrepo() {
  # behavior: pmctl artifacts gc --all-repos deletes in-repo .agent-trace dirs and reports count
  # Steps: create a git repo with a non-empty .agent-trace; run gc --all-repos --repos-root;
  #        assert .agent-trace removed, output contains "found:" and "removed 1"
  local name="pmctl artifacts gc --all-repos: removes in-repo remnant .agent-trace dirs"
  should_run "$name" || return 0
  local repos_root work_repo trace_dir out err status=0
  repos_root="$tmp_root/all-repos-root"
  work_repo="$repos_root/test-repo"
  mkdir -p "$work_repo"
  git init -q "$work_repo"
  trace_dir="$work_repo/.agent-trace"
  mkdir -p "$trace_dir"
  printf 'trace data\n' > "$trace_dir/some.jsonl"

  out="$tmp_root/all-repos.out"; err="$tmp_root/all-repos.err"
  "$PMCTL" artifacts gc --all-repos --repos-root "$repos_root" > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 && ! -d "$trace_dir" && "$(<"$out")" == *"found:"* && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status trace_exists=$(test -d "$trace_dir" && echo y||echo n) out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_all_repos_dry_run() {
  # behavior: pmctl artifacts gc --all-repos --dry-run lists found dirs and reports count without deleting
  # Steps: create a git repo with non-empty .agent-trace; run gc --all-repos --dry-run;
  #        assert .agent-trace still exists and final line reports "found N" count > 0
  local name="pmctl artifacts gc --all-repos: --dry-run lists found dirs without deleting"
  should_run "$name" || return 0
  local repos_root work_repo trace_dir out err status=0
  repos_root="$tmp_root/all-repos-dry"
  work_repo="$repos_root/dry-repo"
  mkdir -p "$work_repo"
  git init -q "$work_repo"
  trace_dir="$work_repo/.agent-trace"
  mkdir -p "$trace_dir"
  printf 'trace data\n' > "$trace_dir/some.jsonl"

  out="$tmp_root/all-repos-dry.out"; err="$tmp_root/all-repos-dry.err"
  "$PMCTL" artifacts gc --all-repos --repos-root "$repos_root" --dry-run > "$out" 2> "$err" || status=$?

  local out_content; out_content="$(<"$out")"
  if [[ "$status" -eq 0 && -d "$trace_dir" &&
        "$out_content" == *"found:"* &&
        "$out_content" == *"found 1 in-repo remnant directories"* && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status trace_exists=$(test -d "$trace_dir" && echo y||echo n) out=$out_content err=$(<"$err")"
  fi
}

case_gc_all_repos_never_deletes_pm_dispatch() {
  # behavior: pmctl artifacts gc --all-repos never touches .pm-dispatch directories
  # Steps: create a git repo with .pm-dispatch; run gc --all-repos; assert .pm-dispatch survives
  local name="pmctl artifacts gc --all-repos: never deletes .pm-dispatch"
  should_run "$name" || return 0
  local repos_root work_repo pm_dir out err status=0
  repos_root="$tmp_root/all-repos-safe"
  work_repo="$repos_root/safe-repo"
  mkdir -p "$work_repo"
  git init -q "$work_repo"
  pm_dir="$work_repo/.pm-dispatch"
  mkdir -p "$pm_dir"
  printf 'state\n' > "$pm_dir/context.db"

  out="$tmp_root/all-repos-safe.out"; err="$tmp_root/all-repos-safe.err"
  "$PMCTL" artifacts gc --all-repos --repos-root "$repos_root" > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 && -d "$pm_dir" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status pm_dir_exists=$(test -d "$pm_dir" && echo y||echo n) out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_all_repos_uses_checkout_parent_default() {
  # behavior: --all-repos derives its default root from the active pm-dispatch checkout
  # Steps: create a sibling git repo beside a copied checkout path; run without --repos-root;
  #        assert the sibling remnant is found and removed even when HOME points elsewhere
  local name="pmctl artifacts gc --all-repos: default follows checkout parent, not HOME"
  should_run "$name" || return 0
  local layout checkout work_repo trace_dir out err status=0
  layout="$tmp_root/nonstandard-layout"
  checkout="$layout/pm-dispatch-copy"
  work_repo="$layout/product-repo"
  mkdir -p "$checkout/cli" "$checkout/runtime/lib" "$work_repo"
  cp "$REPO_ROOT/cli/pmctl" "$checkout/cli/pmctl"
  cp "$REPO_ROOT/runtime/lib/repo-layout.sh" "$checkout/runtime/lib/repo-layout.sh"
  cp "$REPO_ROOT/runtime/lib/pmctl-artifacts.sh" "$checkout/runtime/lib/pmctl-artifacts.sh"
  cp "$REPO_ROOT/runtime/lib/artifact-paths.sh" "$checkout/runtime/lib/artifact-paths.sh"
  git init -q "$work_repo"
  trace_dir="$work_repo/.agent-trace"
  mkdir -p "$trace_dir"
  printf 'trace data\n' > "$trace_dir/some.jsonl"

  out="$tmp_root/all-repos-derived.out"; err="$tmp_root/all-repos-derived.err"
  env -u PM_DISPATCH_REPO -u PM_DISPATCH_REPOS_ROOT HOME="$tmp_root/unrelated-home" \
    "$checkout/cli/pmctl" artifacts gc --all-repos > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 && ! -d "$trace_dir" && "$(<"$out")" == *"found:"* && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status trace_exists=$(test -d "$trace_dir" && echo y||echo n) out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_all_repos_env_overrides_derived_default() {
  # behavior: PM_DISPATCH_REPOS_ROOT overrides the checkout-parent default
  # Steps: create remnants under derived and configured roots; run without --repos-root;
  #        assert only the configured-root remnant is removed
  local name="pmctl artifacts gc --all-repos: PM_DISPATCH_REPOS_ROOT overrides default"
  should_run "$name" || return 0
  local layout checkout configured_repo derived_repo configured_trace derived_trace out err status=0
  layout="$tmp_root/env-layout"
  checkout="$layout/pm-dispatch-copy"
  configured_repo="$tmp_root/configured-root/product"
  derived_repo="$layout/derived-product"
  mkdir -p "$checkout/cli" "$checkout/runtime/lib" "$configured_repo" "$derived_repo"
  cp "$REPO_ROOT/cli/pmctl" "$checkout/cli/pmctl"
  cp "$REPO_ROOT/runtime/lib/repo-layout.sh" "$checkout/runtime/lib/repo-layout.sh"
  cp "$REPO_ROOT/runtime/lib/pmctl-artifacts.sh" "$checkout/runtime/lib/pmctl-artifacts.sh"
  cp "$REPO_ROOT/runtime/lib/artifact-paths.sh" "$checkout/runtime/lib/artifact-paths.sh"
  git init -q "$configured_repo"
  git init -q "$derived_repo"
  configured_trace="$configured_repo/.agent-trace"
  derived_trace="$derived_repo/.agent-trace"
  mkdir -p "$configured_trace" "$derived_trace"
  printf 'configured\n' > "$configured_trace/trace.jsonl"
  printf 'derived\n' > "$derived_trace/trace.jsonl"

  out="$tmp_root/all-repos-env.out"; err="$tmp_root/all-repos-env.err"
  PM_DISPATCH_REPOS_ROOT="$tmp_root/configured-root" "$checkout/cli/pmctl" artifacts gc --all-repos > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 && ! -d "$configured_trace" && -d "$derived_trace" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status configured=$(test -d "$configured_trace" && echo y||echo n) derived=$(test -d "$derived_trace" && echo y||echo n) out=$(<"$out") err=$(<"$err")"
  fi
}

case_migrate_copies_leaves() {
  # behavior: pmctl artifacts migrate copies in-repo .agent-trace to out-of-repo partition,
  #           preserves original, and the destination contains the same files
  # Steps: create .agent-trace with a file; run migrate; assert original preserved,
  #        output contains "migrated:", destination dir exists with the copied file
  local name="pmctl artifacts migrate: copies in-repo leaves to out-of-repo partition"
  should_run "$name" || return 0
  local store work trace_dir out err status=0
  store="$tmp_root/state-migrate"
  work="$tmp_root/work-migrate"
  make_work_repo "$work"
  trace_dir="$work/.agent-trace"
  mkdir -p "$trace_dir"
  printf 'old trace\n' > "$trace_dir/run.jsonl"

  out="$tmp_root/migrate.out"; err="$tmp_root/migrate.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts migrate --cd "$work" > "$out" 2> "$err" || status=$?

  # Verify destination was actually created with the copied file
  local out_content; out_content="$(<"$out")"
  local dest_path
  dest_path="$(grep 'migrated:' "$out" | sed 's/.*-> //' | head -1)"

  # cp -a .agent-trace $dest (when $dest doesn't exist) copies contents directly into $dest
  if [[ "$status" -eq 0 && -d "$trace_dir" && "$out_content" == *"migrated:"* &&
        -n "$dest_path" && -d "$dest_path" &&
        -f "$dest_path/run.jsonl" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status trace_exists=$(test -d "$trace_dir" && echo y||echo n) dest_path=$dest_path dest_exists=$(test -d "$dest_path" && echo y||echo n) out=$out_content err=$(<"$err")"
  fi
}

case_migrate_idempotent() {
  # behavior: pmctl artifacts migrate skips already-migrated destinations on re-run
  # Steps: run migrate twice on same work dir; first output contains "migrated:", second contains "skip"
  local name="pmctl artifacts migrate: idempotent on re-run (skips already-migrated)"
  should_run "$name" || return 0
  local store work trace_dir out1 out2 err status=0
  store="$tmp_root/state-migrate-idem"
  work="$tmp_root/work-migrate-idem"
  make_work_repo "$work"
  trace_dir="$work/.agent-trace"
  mkdir -p "$trace_dir"
  printf 'trace\n' > "$trace_dir/x.jsonl"

  out1="$tmp_root/migrate-idem1.out"; out2="$tmp_root/migrate-idem2.out"; err="$tmp_root/migrate-idem.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts migrate --cd "$work" > "$out1" 2> "$err" || status=$?
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts migrate --cd "$work" > "$out2" 2> "$err" || status=$?

  if [[ "$status" -eq 0 && "$(<"$out1")" == *"migrated:"* && "$(<"$out2")" == *"skip"* && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out1=$(<"$out1") out2=$(<"$out2") err=$(<"$err")"
  fi
}

case_inrepo_notice_emitted() {
  # behavior: sw_resolve_trace_dir emits one-time stderr notice when PM_DISPATCH_TRACE_DIR is inside work_dir
  # Steps: call sw_resolve_trace_dir with env pointing inside work_dir; assert stderr contains migration hint
  local name="sw_resolve_trace_dir: emits stderr notice when PM_DISPATCH_TRACE_DIR points inside work_dir"
  should_run "$name" || return 0
  local work err status=0
  work="$tmp_root/work-notice"
  mkdir -p "$work"
  err="$tmp_root/notice.err"
  PM_DISPATCH_TRACE_DIR="$work/.agent-trace" bash -c \
    ". '$REPO_ROOT/runtime/lib/state-paths.sh' && sw_resolve_trace_dir '' '' '$work'" \
    > /dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 0 && "$(<"$err")" == *"out-of-repo by default"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status err=$(<"$err")"
  fi
}

case_artifacts_list_newest_first
case_artifacts_list_empty
case_artifacts_show_files
case_artifacts_show_missing
case_codex_watch_trace_flag
case_codex_watch_run_flag
case_codex_watch_auto_discover
case_gc_dry_run
case_gc_keep_last
case_gc_max_age_zero
case_gc_safety_rejects_pm_dispatch
case_gc_all_repos_removes_inrepo
case_gc_all_repos_dry_run
case_gc_all_repos_never_deletes_pm_dispatch
case_gc_all_repos_uses_checkout_parent_default
case_gc_all_repos_env_overrides_derived_default
case_migrate_copies_leaves
case_migrate_idempotent
case_inrepo_notice_emitted

th_summary
