#!/usr/bin/env bash
# Regression tests for artifact discovery surfaces.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"
WATCH="$REPO_ROOT/ops/diagnostics/codex-watch.sh"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=tests/lib/test-pmctl-fixture.sh
. "$SCRIPT_DIR/../lib/test-pmctl-fixture.sh"
th_init "$@"

# shellcheck source=runtime/lib/state-paths.sh
. "$REPO_ROOT/runtime/lib/state-paths.sh"
# shellcheck source=runtime/lib/pmctl-artifacts.sh
. "$REPO_ROOT/runtime/lib/pmctl-artifacts.sh"

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

# Minimal gate result fixture: frontmatter (final/tier/most_severe/reviewers)
# plus one reviewer_result_v1 fenced block per reviewer with findings.
# reviewers_block is pre-formatted "  name: verdict" lines (frontmatter body);
# findings_blocks is zero or more full fenced ```reviewer_result_v1 ...``` sections.
write_gate_result() {
  local store="$1" work="$2" run_id="$3" final="$4" tier="$5" most_severe="$6"
  local reviewers_block="$7" findings_blocks="$8"
  local rd file
  rd="$(run_dir_for "$store" "$work" "$run_id")"
  file="$rd/.gate-results/gate-${run_id#*-}.md"
  mkdir -p "$(dirname "$file")"
  {
    printf -- '---\n'
    printf 'final: %s\n' "$final"
    [[ -z "$tier" ]] || printf 'tier: %s\n' "$tier"
    [[ -z "$most_severe" ]] || printf 'most_severe: %s\n' "$most_severe"
    printf 'reviewers:\n%s\n' "$reviewers_block"
    printf -- '---\n\n'
    [[ -z "$findings_blocks" ]] || printf '%s\n' "$findings_blocks"
  } > "$file"
  printf '%s' "$file"
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
    --dry-run --keep-last 1 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?

  local out_content; out_content="$(<"$out")"
  # grep -c always prints a count (including "0") but exits 1 on no match, so
  # the `|| printf` idiom this used to use would append a second "0" from the
  # fallback on top of grep's own stdout -- fixed here rather than papering
  # over it, since it silently produced a two-line "0\n0" that broke -eq.
  local would_delete_count; would_delete_count="$(grep -c 'would delete:' "$out" 2>/dev/null)"
  : "${would_delete_count:=0}"
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
    --keep-last 1 --max-age-days 30 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?

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

case_gc_grace_days_env_only_selects_grace_period() {
  # behavior (CC-540, qa-tester-F001): PM_DISPATCH_GC_GRACE_DAYS alone (no
  # --grace-days flag) selects the grace period
  # Steps: env-only grace=0 with one eligible old run; assert immediate
  #        deletion, proving the environment path alone is load-bearing
  local name="pmctl artifacts gc: PM_DISPATCH_GC_GRACE_DAYS alone selects the grace period"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-grace-env-only"
  work="$tmp_root/work-gc-grace-env-only"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-old)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-grace-env-only.out"; err="$tmp_root/gc-grace-env-only.err"
  PM_DISPATCH_STATE_ROOT="$store" PM_DISPATCH_GC_GRACE_DAYS=0 "$PMCTL" artifacts gc \
    --keep-last 1 --cd "$work" > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 && ! -d "$rd_old" && -d "$rd_keep" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_grace_days_flag_overrides_env() {
  # behavior (CC-540, qa-tester-F001): an explicit --grace-days flag wins
  # over a conflicting PM_DISPATCH_GC_GRACE_DAYS
  # Steps: env sets grace=0 (would delete immediately), flag sets grace=3;
  #        assert the run is deferred, not deleted -- the flag governed
  local name="pmctl artifacts gc: --grace-days flag overrides a conflicting PM_DISPATCH_GC_GRACE_DAYS"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-grace-flag-wins"
  work="$tmp_root/work-gc-grace-flag-wins"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-old)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-grace-flag-wins.out"; err="$tmp_root/gc-grace-flag-wins.err"
  PM_DISPATCH_STATE_ROOT="$store" PM_DISPATCH_GC_GRACE_DAYS=0 "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 3 --cd "$work" > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 && -d "$rd_old" && -d "$rd_keep" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_grace_days_env_rejects_non_numeric() {
  # behavior (CC-540, critic-F001): a non-numeric PM_DISPATCH_GC_GRACE_DAYS
  # is rejected up front, the same way an explicit --grace-days flag value
  # already is -- it must not reach the grace_seconds arithmetic context and
  # must not silently collapse the retention safety window
  # Steps: env sets an invalid grace value with one otherwise-eligible run;
  #        assert nonzero exit, a diagnostic, and no mutation at all (run
  #        dir intact, no runs-summary.jsonl written)
  local name="pmctl artifacts gc: rejects a non-numeric PM_DISPATCH_GC_GRACE_DAYS"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-grace-invalid"
  work="$tmp_root/work-gc-grace-invalid"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-old)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-grace-invalid.out"; err="$tmp_root/gc-grace-invalid.err"
  PM_DISPATCH_STATE_ROOT="$store" PM_DISPATCH_GC_GRACE_DAYS=not-a-number "$PMCTL" artifacts gc \
    --keep-last 1 --cd "$work" > "$out" 2> "$err" || status=$?

  local summary_file
  summary_file="$(dirname "$rd_old")/../runs-summary.jsonl"
  summary_file="$(cd "$(dirname "$summary_file")" && pwd)/runs-summary.jsonl"

  if [[ "$status" -ne 0 && -d "$rd_old" && ! -e "$summary_file" ]] \
      && grep -q 'PM_DISPATCH_GC_GRACE_DAYS' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) summary_exists=$(test -e "$summary_file" && echo y||echo n) err=$(<"$err")"
  fi
}

case_gc_grace_days_flag_rejects_non_numeric() {
  # behavior (CC-540, qa-tester-F001): an explicit --grace-days flag with a
  # non-numeric value is rejected by the flag parser itself, not only the
  # environment path -- this is the flag-parsing branch, distinct from
  # case_gc_grace_days_env_rejects_non_numeric which covers the env-only path
  # Steps: one eligible run; gc --grace-days not-a-number; assert nonzero
  #        exit, a --grace-days-specific diagnostic, and no mutation
  local name="pmctl artifacts gc: rejects a non-numeric --grace-days flag value"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-grace-flag-invalid"
  work="$tmp_root/work-gc-grace-flag-invalid"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-old)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-grace-flag-invalid.out"; err="$tmp_root/gc-grace-flag-invalid.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days not-a-number --cd "$work" > "$out" 2> "$err" || status=$?

  local summary_file
  summary_file="$(dirname "$rd_old")/../runs-summary.jsonl"
  summary_file="$(cd "$(dirname "$summary_file")" && pwd)/runs-summary.jsonl"

  if [[ "$status" -ne 0 && -d "$rd_old" && ! -e "$summary_file" ]] \
      && grep -q -- '--grace-days requires an integer' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) summary_exists=$(test -e "$summary_file" && echo y||echo n) err=$(<"$err")"
  fi
}

case_gc_dry_run_positive_grace_previews_without_mutation() {
  # behavior (CC-540, qa-tester-F002): --dry-run under a positive (non-zero)
  # grace period previews both the summarize and the defer decision without
  # ever persisting runs-summary.jsonl or touching the run directory
  # Steps: one eligible, not-yet-summarized run; gc --dry-run with the
  #        default grace (3 days); assert both preview lines appear and
  #        nothing was written or deleted
  local name="pmctl artifacts gc: --dry-run under positive grace previews without persisting or deleting"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-dry-positive-grace"
  work="$tmp_root/work-gc-dry-positive-grace"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-old)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-dry-positive-grace.out"; err="$tmp_root/gc-dry-positive-grace.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --dry-run --keep-last 1 --cd "$work" > "$out" 2> "$err" || status=$?

  local summary_file
  summary_file="$(dirname "$rd_old")/../runs-summary.jsonl"
  summary_file="$(cd "$(dirname "$summary_file")" && pwd)/runs-summary.jsonl"

  if [[ "$status" -eq 0 && -d "$rd_old" && ! -e "$summary_file" && ! -s "$err" ]] \
      && grep -q '^would summarize: run-old' "$out" \
      && grep -q '^would defer: run-old' "$out"; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) summary_exists=$(test -e "$summary_file" && echo y||echo n) out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_concurrent_invocations_produce_one_summary_line() {
  # behavior (CC-540, architecture-reviewer-F001): two gc invocations racing
  # on the same partition serialize per-project instead of each acting on a
  # stale "already summarized?" snapshot -- the shared runs-summary.jsonl
  # ends up with exactly one record for the run, never a duplicate or a
  # cross-rolled-back line
  # Steps: launch two `pmctl artifacts gc --grace-days 0` invocations against
  #        the same store/work back to back (no delay) for one eligible run;
  #        wait for both; assert exactly one summary line for that run_id
  #        and no prune-skipped.log
  local name="pmctl artifacts gc: two concurrent invocations produce exactly one summary line"
  should_run "$name" || return 0
  local store work out1 err1 out2 err2
  store="$tmp_root/state-gc-concurrent"
  work="$tmp_root/work-gc-concurrent"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-race)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out1="$tmp_root/gc-race-1.out"; err1="$tmp_root/gc-race-1.err"
  out2="$tmp_root/gc-race-2.out"; err2="$tmp_root/gc-race-2.err"
  local status1=0 status2=0
  (PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc --keep-last 1 --grace-days 0 --cd "$work" \
    > "$out1" 2> "$err1") &
  local pid1=$!
  (PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc --keep-last 1 --grace-days 0 --cd "$work" \
    > "$out2" 2> "$err2") &
  local pid2=$!
  # Capture each child's own exit status explicitly -- `wait` on multiple
  # pids reports only the last one waited on unless each is waited on
  # individually, and swallowing them (as `|| true` alone would) could mask
  # one invocation genuinely failing while still leaving the shared-state
  # assertions below looking correct by coincidence.
  wait "$pid1" || status1=$?
  wait "$pid2" || status2=$?

  local summary_file skip_log line_count
  summary_file="$(dirname "$rd_old")/../runs-summary.jsonl"
  summary_file="$(cd "$(dirname "$summary_file")" && pwd)/runs-summary.jsonl"
  skip_log="$(dirname "$summary_file")/prune-skipped.log"
  line_count="$(grep -c '"run_id":"run-race"' "$summary_file" 2>/dev/null)"
  : "${line_count:=0}"

  if [[ "$status1" -eq 0 && "$status2" -eq 0 && ! -d "$rd_old" && "$line_count" -eq 1 && ! -e "$skip_log" ]]; then
    pass "$name"
  else
    fail "$name" "status1=$status1 status2=$status2 rd_old_exists=$(test -d "$rd_old" && echo y||echo n) line_count=$line_count out1=$(<"$out1") out2=$(<"$out2") err1=$(<"$err1") err2=$(<"$err2")"
  fi
}

case_gc_append_failure_retains_run_no_false_success() {
  # behavior (CC-540, risk-reviewer-F001): if the summary append itself
  # fails (e.g. the summary file is not writable), gc must not mistake a
  # prior, unrelated valid line for this run's proof of durability -- the
  # candidate run must be retained and the failure recorded, never silently
  # treated as summarized-and-safe-to-delete
  # Steps: pre-seed one valid summary line for a different run_id; make the
  #        summary file read-only so the next append fails; run gc on a
  #        second, unrelated eligible run; assert it is retained, its
  #        run_id never appears in the (unchanged) summary file, and
  #        prune-skipped.log names it
  local name="pmctl artifacts gc: a failed append retains the run and does not report false success"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-append-failure"
  work="$tmp_root/work-gc-append-failure"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-blocked)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  local runs_dir summary_file
  runs_dir="$(dirname "$rd_old")"
  summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"
  jq -nc '{run_id:"run-preexisting", summarized_at:1, kind:"dispatch", status:"complete", duration_seconds:1, gate:null}' \
    > "$summary_file"
  chmod 444 "$summary_file"

  out="$tmp_root/gc-append-failure.out"; err="$tmp_root/gc-append-failure.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?
  chmod 644 "$summary_file"

  local skip_log
  skip_log="$(dirname "$summary_file")/prune-skipped.log"

  if [[ -d "$rd_old" && -e "$skip_log" ]] \
      && grep -q 'run-blocked' "$skip_log" \
      && ! grep -q '"run_id":"run-blocked"' "$summary_file"; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) skip_log_exists=$(test -e "$skip_log" && echo y||echo n) summary=$(<"$summary_file") skip_log_content=$(cat "$skip_log" 2>/dev/null)"
  fi
}

case_gc_summary_fsync_failure_retains_run() {
  # behavior (CC-540, risk-reviewer-F001): an in-process read-back only
  # proves a write reached the OS page cache, not persistent storage -- a
  # crash between a "verified" append and an immediate (--grace-days 0)
  # rm -rf could lose the sole summary while the source run is already gone.
  # If fsync-ing the summary file fails, the run must stay retained (never
  # deleted on an unconfirmed-durable summary), matching how every other
  # verification-failure path in this file behaves: the failing run is
  # logged and kept, while gc's overall run still completes (other runs may
  # have processed fine) -- this is not the separate lock-failure path,
  # which does force a nonzero exit.
  # Steps: stub `sync` on PATH to always fail; one eligible run with
  #        --grace-days 0; assert the run is retained, prune-skipped.log
  #        names it, and the summary line itself was pruned back out (an
  #        unsynced record must not linger as something a later gc could
  #        mistake for a durably-confirmed summary -- see
  #        case_gc_retry_after_fsync_failure_resummarizes_before_deleting for
  #        the follow-up invocation this enables).
  local name="pmctl artifacts gc: a summary fsync failure retains the run instead of deleting it"
  should_run "$name" || return 0
  local store work bin out err status=0
  store="$tmp_root/state-gc-fsync-failure"
  work="$tmp_root/work-gc-fsync-failure"
  bin="$tmp_root/bin-fsync-failure"
  make_work_repo "$work"
  mkdir -p "$bin"
  cat > "$bin/sync" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$bin/sync"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-old)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-fsync-failure.out"; err="$tmp_root/gc-fsync-failure.err"
  PATH="$bin:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?

  local runs_dir summary_file skip_log
  runs_dir="$(dirname "$rd_old")"
  summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"
  skip_log="$(dirname "$summary_file")/prune-skipped.log"

  if [[ -d "$rd_old" && -e "$skip_log" ]] \
      && grep -q 'run-old' "$skip_log" \
      && ! grep -q '"run_id":"run-old"' "$summary_file"; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) skip_log=$(cat "$skip_log" 2>/dev/null) summary=$(<"$summary_file")"
  fi
}

case_gc_retry_after_fsync_failure_resummarizes_before_deleting() {
  # behavior (CC-540, critic-F001/qa-tester-F001/risk-reviewer-F001): a
  # summary that previously failed fsync must never be trusted by a LATER gc
  # invocation as authorization to delete. Prove this end-to-end across two
  # separate invocations rather than just inspecting one call's output:
  #   1st gc (sync forced to fail): run retained, unsynced line pruned back
  #      out (asserted by case_gc_summary_fsync_failure_retains_run above).
  #   2nd gc (sync working normally): must re-summarize from scratch and
  #      re-verify durability before it may delete -- it must NOT delete
  #      merely because a record for this run_id existed at some point.
  # Oracle: after the 2nd invocation the run is gone, and the summary file
  # contains exactly one line for this run_id (the 2nd invocation's own
  # fresh, successfully-synced record) -- proving deletion rode on a new
  # durability confirmation, not a resurrected unsynced one.
  local name="pmctl artifacts gc: a rerun after fsync failure re-summarizes and re-verifies before it may delete"
  should_run "$name" || return 0
  local store work bin out err status=0
  store="$tmp_root/state-gc-fsync-retry"
  work="$tmp_root/work-gc-fsync-retry"
  bin="$tmp_root/bin-fsync-retry"
  make_work_repo "$work"
  mkdir -p "$bin"
  cat > "$bin/sync" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$bin/sync"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-retry)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-fsync-retry-1.out"; err="$tmp_root/gc-fsync-retry-1.err"
  PATH="$bin:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?

  local runs_dir summary_file
  runs_dir="$(dirname "$rd_old")"
  summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"

  if [[ ! -d "$rd_old" ]]; then
    fail "$name" "run was deleted on the FIRST (sync-failing) invocation; the fsync guard did not retain it"
    return 0
  fi

  status=0
  out="$tmp_root/gc-fsync-retry-2.out"; err="$tmp_root/gc-fsync-retry-2.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?

  local run_line_count
  run_line_count="$(grep -c '"run_id":"run-retry"' "$summary_file" 2>/dev/null || true)"
  : "${run_line_count:=0}"

  if [[ ! -d "$rd_old" && "$run_line_count" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) run_line_count=$run_line_count summary=$(<"$summary_file")"
  fi
}

case_gc_lock_timeout_reports_failure_and_retains_run() {
  # behavior (CC-540, architecture-reviewer-F001/risk-reviewer-F001, RCG-002):
  # a summary-lock acquisition timeout must be a machine-detectable failure
  # (nonzero exit, a stderr diagnostic naming the run) -- treating absent
  # serialized output as an ordinary zero-touched-runs success would let an
  # eligible run silently go unprocessed while gc still reports a clean run
  # Steps: hold the same per-project lockfile serialize_with_lock uses, from
  #        an independent process, for longer than a short
  #        PM_DISPATCH_LOCK_TIMEOUT_SECS; run gc against one eligible run;
  #        assert nonzero exit, the run retained, and a lock-failure
  #        diagnostic on stderr naming it
  local name="pmctl artifacts gc: a lock-acquisition timeout is a reported failure, not silent success"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-lock-timeout"
  work="$tmp_root/work-gc-lock-timeout"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-locked)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  local runs_dir summary_file holder_acquired
  runs_dir="$(dirname "$rd_old")"
  summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"
  mkdir -p "$(dirname "$summary_file")"
  holder_acquired="$tmp_root/gc-lock-timeout.acquired"
  rm -f "$holder_acquired"

  # Hold the exact lockfile serialize_with_lock will try to acquire
  # (<runs-summary.jsonl>.lock), from an independent process, well past the
  # short timeout gc is given below. The holder writes a marker file only
  # after flock actually grants the lock, so the poll loop below waits on a
  # real signal instead of a fixed sleep guessing how long acquisition takes
  # -- a plain `sleep N` before launching gc would be nondeterministic under
  # load (qa-tester's finding).
  (
    exec 9>"${summary_file}.lock"
    flock -x 9
    : > "$holder_acquired"
    sleep 5
  ) &
  local holder_pid=$!
  local waited=0
  while [[ ! -e "$holder_acquired" ]]; do
    sleep 0.05
    waited=$((waited + 1))
    if [[ "$waited" -ge 100 ]]; then
      fail "$name" "lock holder never signaled acquisition within 5s"
      wait "$holder_pid" 2>/dev/null || true
      return
    fi
  done

  out="$tmp_root/gc-lock-timeout.out"; err="$tmp_root/gc-lock-timeout.err"
  PM_DISPATCH_STATE_ROOT="$store" PM_DISPATCH_LOCK_TIMEOUT_SECS=1 "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?
  local holder_status=0
  wait "$holder_pid" || holder_status=$?

  if [[ "$status" -ne 0 && "$holder_status" -eq 0 && -d "$rd_old" ]] \
      && grep -q 'lock acquisition' "$err" && grep -q 'run-locked' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status holder_status=$holder_status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_summarizes_before_grace_defers_deletion() {
  # behavior (CC-540): an eligible-for-deletion gate run is summarized into
  # runs-summary.jsonl (surviving prune) before deletion, but physical
  # deletion is deferred until --grace-days has elapsed since summarization
  # Steps: one old gate run past keep-last with a valid result; gc with
  #        default grace (3 days); assert summary written with real fields,
  #        run dir still exists, no prune-skipped.log
  local name="pmctl artifacts gc: summarizes before deleting, defers past grace period"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-summarize"
  work="$tmp_root/work-gc-summarize"
  make_work_repo "$work"

  local rd_keep rd_old gate_file
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  mkdir -p "$rd_keep"
  printf 'k\n' > "$rd_keep/k.footer"
  gate_file="$(write_gate_result "$store" "$work" gate-old GO full block \
    $'  critic: advise' \
    $'```reviewer_result_v1\n{"reviewer":"critic","findings":[{"severity":"low"}]}\n```')"
  local rd_old; rd_old="$(dirname "$(dirname "$gate_file")")"
  printf 'x\n' > "$rd_old/x.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-summarize.out"; err="$tmp_root/gc-summarize.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --cd "$work" > "$out" 2> "$err" || status=$?

  local summary_file skip_log summary_line
  summary_file="$(dirname "$rd_old")/../runs-summary.jsonl"
  summary_file="$(cd "$(dirname "$summary_file")" && pwd)/runs-summary.jsonl"
  skip_log="$(dirname "$summary_file")/prune-skipped.log"
  summary_line="$(grep '"run_id":"gate-old"' "$summary_file" 2>/dev/null || true)"

  if [[ "$status" -eq 0 && -d "$rd_old" && -n "$summary_line" && ! -e "$skip_log" ]] \
      && printf '%s' "$summary_line" | jq -e '
        .kind == "gate" and .status == "complete" and
        .gate.final == "GO" and .gate.tier == "full" and .gate.most_severe == "block"
      ' >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) summary_line=$summary_line out=$(<"$out")"
  fi
}

case_gc_deletes_once_grace_elapses() {
  # behavior (CC-540): a run already summarized long enough ago (past grace)
  # is physically deleted on the next gc invocation, without re-summarizing
  # Steps: pre-seed runs-summary.jsonl with an old summarized_at for the run;
  #        gc; assert the run dir is deleted and no duplicate summary line
  local name="pmctl artifacts gc: deletes a run once its summary has existed past --grace-days"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-grace-elapsed"
  work="$tmp_root/work-gc-grace-elapsed"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-old)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  local runs_dir summary_file old_epoch
  runs_dir="$(dirname "$rd_old")"
  summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"
  old_epoch=$(( $(date +%s) - 10 * 86400 ))
  jq -nc --argjson t "$old_epoch" \
    '{run_id:"run-old", summarized_at:$t, kind:"dispatch", status:"complete", duration_seconds:1, gate:null}' \
    > "$summary_file"

  out="$tmp_root/gc-grace-elapsed.out"; err="$tmp_root/gc-grace-elapsed.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 3 --cd "$work" > "$out" 2> "$err" || status=$?

  local summary_line_count
  summary_line_count="$(grep -c '"run_id":"run-old"' "$summary_file" 2>/dev/null)"
  : "${summary_line_count:=0}"

  if [[ "$status" -eq 0 && ! -d "$rd_old" && -d "$rd_keep" && "$summary_line_count" -eq 1 && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) summary_line_count=$summary_line_count out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_incomplete_preexisting_summary_forces_resummarize() {
  # behavior (CC-540, critic-F001): a pre-existing summary line that matches
  # the run_id and has a non-null summarized_at, but fails the same
  # structural contract append-verification enforces, must not be trusted as
  # proof of durability -- lookup must reject it and force a fresh
  # summarize-and-verify, even though its (old) timestamp alone would
  # otherwise already be past the grace period
  # Steps: pre-seed a summary line for the run with an old summarized_at but
  #        missing the required "status" field (simulating corruption, a
  #        foreign write, or an older/incompatible schema); gc; assert the
  #        run is NOT deleted this round (a fresh valid summary was just
  #        written instead, whose own grace period has not elapsed) and a
  #        second, structurally valid line now exists for the same run_id
  local name="pmctl artifacts gc: an incomplete pre-existing summary does not satisfy lookup"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-incomplete-preexisting"
  work="$tmp_root/work-gc-incomplete-preexisting"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" run-old)"
  mkdir -p "$rd_keep" "$rd_old"
  printf 'k\n' > "$rd_keep/k.footer"
  printf 'a\n' > "$rd_old/a.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  local runs_dir summary_file old_epoch
  runs_dir="$(dirname "$rd_old")"
  summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"
  old_epoch=$(( $(date +%s) - 10 * 86400 ))
  # Deliberately missing "status" -- would satisfy the old (pre-fix) lookup
  # (run_id matches, summarized_at is non-null) but must fail the
  # structural-contract check now applied at lookup time too.
  jq -nc --argjson t "$old_epoch" '{run_id:"run-old", summarized_at:$t, kind:"dispatch"}' \
    > "$summary_file"

  out="$tmp_root/gc-incomplete-preexisting.out"; err="$tmp_root/gc-incomplete-preexisting.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 3 --cd "$work" > "$out" 2> "$err" || status=$?

  local valid_line_count
  valid_line_count="$(jq -c --arg run_id run-old '
      select(.run_id == $run_id and .status != null)
    ' "$summary_file" 2>/dev/null | wc -l | tr -d ' ')"
  : "${valid_line_count:=0}"

  if [[ "$status" -eq 0 && -d "$rd_old" && "$valid_line_count" -eq 1 && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) valid_line_count=$valid_line_count summary=$(<"$summary_file") out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_incomplete_source_not_treated_as_failure() {
  # behavior (CC-540): an empty/malformed gate result summarizes with an
  # explicit incomplete_source status -- not a verification failure, and not
  # silently treated as a passing gate. The run still prunes normally.
  # Steps: gate run whose .gate-results/*.md is 0 bytes (e.g. CC-509 pre-fix
  #        detached-launch early death); gc --grace-days 0; assert summary
  #        marks incomplete_source, no prune-skipped.log, run dir deleted
  local name="pmctl artifacts gc: empty gate result summarizes as incomplete_source, not a failure"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-incomplete"
  work="$tmp_root/work-gc-incomplete"
  make_work_repo "$work"

  local rd_keep rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  rd_old="$(run_dir_for "$store" "$work" gate-empty)"
  mkdir -p "$rd_keep" "$rd_old/.gate-results"
  printf 'k\n' > "$rd_keep/k.footer"
  : > "$rd_old/.gate-results/gate-empty.md"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-incomplete.out"; err="$tmp_root/gc-incomplete.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?

  local runs_dir summary_file skip_log summary_line
  runs_dir="$(dirname "$rd_old")"
  summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"
  skip_log="$(dirname "$runs_dir")/prune-skipped.log"
  summary_line="$(grep '"run_id":"gate-empty"' "$summary_file" 2>/dev/null || true)"

  if [[ "$status" -eq 0 && ! -d "$rd_old" && ! -e "$skip_log" && -n "$summary_line" ]] \
      && printf '%s' "$summary_line" | jq -e '.kind == "gate" and .status == "incomplete_source" and .gate == null' \
        >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) summary_line=$summary_line out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_missing_tier_not_treated_as_failure() {
  # behavior (CC-540): a legacy gate result with `final:` but no `tier:` line
  # (older schema, per docs/skill-command-harness-policy.md-adjacent schema
  # drift already seen in CC-562) still summarizes as status=complete --
  # only .gate.final is required, tier/most_severe may be honestly null
  # Steps: gate run whose frontmatter omits tier/most_severe entirely;
  #        gc --grace-days 0; assert no prune-skipped.log, run dir deleted
  local name="pmctl artifacts gc: gate result missing tier/most_severe is not a verification failure"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-gc-no-tier"
  work="$tmp_root/work-gc-no-tier"
  make_work_repo "$work"

  local rd_keep gate_file rd_old
  rd_keep="$(run_dir_for "$store" "$work" run-keep)"
  mkdir -p "$rd_keep"
  printf 'k\n' > "$rd_keep/k.footer"
  gate_file="$(write_gate_result "$store" "$work" gate-notier GO "" "" $'  critic: approve' "")"
  rd_old="$(dirname "$(dirname "$gate_file")")"
  printf 'x\n' > "$rd_old/x.footer"
  touch -t "$(date -d '40 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-40d +%Y%m%d%H%M)" "$rd_old" 2>/dev/null || true

  out="$tmp_root/gc-no-tier.out"; err="$tmp_root/gc-no-tier.err"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" artifacts gc \
    --keep-last 1 --grace-days 0 --cd "$work" > "$out" 2> "$err" || status=$?

  local runs_dir summary_file skip_log summary_line
  runs_dir="$(dirname "$rd_old")"
  summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"
  skip_log="$(dirname "$runs_dir")/prune-skipped.log"
  summary_line="$(grep '"run_id":"gate-notier"' "$summary_file" 2>/dev/null || true)"

  if [[ "$status" -eq 0 && ! -d "$rd_old" && ! -e "$skip_log" && -n "$summary_line" ]] \
      && printf '%s' "$summary_line" | jq -e '.gate.final == "GO" and .gate.tier == null' >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status rd_old_exists=$(test -d "$rd_old" && echo y||echo n) summary_line=$summary_line out=$(<"$out") err=$(<"$err")"
  fi
}

case_gc_duration_uses_real_mtimes_not_run_id() {
  # behavior (CC-540): duration is the spread between the earliest and latest
  # *file mtime* inside the run dir, never anything parsed from the run id --
  # run/gate id timestamps are known to drift from actual file mtimes
  # Steps: run_id embeds a misleading date; two files touched with a known,
  #        controlled real mtime gap; assert the computed duration matches
  #        the real gap exactly, not zero and not derived from the run id
  local name="_pmctl_artifacts_run_duration_seconds: uses real file mtime spread, not the run id"
  should_run "$name" || return 0
  local dir="$tmp_root/duration-real-mtime"
  mkdir -p "$dir"
  printf 'start\n' > "$dir/a.jsonl"
  touch -t "$(date -d '2000-01-01 00:00:00' +%Y%m%d%H%M.%S 2>/dev/null || date -v1y -v1m -v1d +%Y%m%d%H%M.%S)" \
    "$dir/a.jsonl" 2>/dev/null || touch -t 200001010000 "$dir/a.jsonl"
  printf 'end\n' > "$dir/b.footer"
  touch -t "$(date -d '2000-01-01 00:08:20' +%Y%m%d%H%M.%S 2>/dev/null)" "$dir/b.footer" 2>/dev/null \
    || touch -t 200001010008 "$dir/b.footer"

  local got
  got="$(_pmctl_artifacts_run_duration_seconds "$dir")"
  # 500 seconds (8m20s) apart, regardless of the "run id" this dir is never
  # named after -- the point of the case is that no run-id string is consulted.
  if [[ "$got" -eq 500 ]]; then
    pass "$name"
  else
    fail "$name" "got=$got, expected 500"
  fi
}

case_gc_findings_by_severity_buckets_per_reviewer() {
  # behavior (CC-540): finding counts are bucketed by severity per reviewer
  # from embedded reviewer_result_v1 JSON blocks, not kept as full text
  # Steps: two reviewer blocks (one with two same-severity findings, one
  #        skipped/absent entirely); assert the bucketed counts match
  local name="_pmctl_artifacts_gate_findings_by_severity: buckets counts per reviewer"
  should_run "$name" || return 0
  local dir="$tmp_root/findings-severity"
  mkdir -p "$dir"
  local gate_file="$dir/gate-x.md"
  {
    printf -- '---\nfinal: NO-GO\ntier: standard\nmost_severe: high\nreviewers:\n  critic: block\n  qa-tester: skipped\n---\n\n'
    printf '```reviewer_result_v1\n'
    printf '{"reviewer":"critic","findings":[{"severity":"high"},{"severity":"high"},{"severity":"low"}]}\n'
    printf '```\n'
  } > "$gate_file"

  local got
  got="$(_pmctl_artifacts_gate_findings_by_severity "$gate_file")"
  if printf '%s' "$got" | jq -e '
      (map(select(.reviewer == "critic")) | first | .counts.high) == 2 and
      (map(select(.reviewer == "critic")) | first | .counts.low) == 1
    ' >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "got=$got"
  fi
}

case_gc_findings_by_severity_unavailable_when_unparseable() {
  # behavior (CC-540): a gate result with no reviewer_result_v1 block at all
  # (older schema versions, e.g. gate_result_version v1 seen in this repo's
  # own history) degrades to the string "unavailable", never to zero/empty --
  # zero would misread as "no findings" instead of "could not extract"
  local name="_pmctl_artifacts_gate_findings_by_severity: reports unavailable, not zero, when no block is parseable"
  should_run "$name" || return 0
  local dir="$tmp_root/findings-unavailable"
  mkdir -p "$dir"
  local gate_file="$dir/gate-y.md"
  printf -- '---\nfinal: GO\ntier: standard\nreviewers:\n  critic: approve\n---\n\nNo embedded JSON block here.\n' \
    > "$gate_file"

  local got
  got="$(_pmctl_artifacts_gate_findings_by_severity "$gate_file")"
  if [[ "$got" == '"unavailable"' ]]; then
    pass "$name"
  else
    fail "$name" "got=$got, expected the literal JSON string \"unavailable\""
  fi
}

case_gc_verification_failure_retains_summary_and_logs() {
  # behavior (CC-540): a summary line that fails its own read-back
  # verification is rolled back out of runs-summary.jsonl (never left half
  # -written) and recorded to prune-skipped.log -- the caller must not treat
  # the run as summarized, so its deletion stays blocked
  # Steps: call the append-verify helper directly with a summary claiming
  #        status=complete/kind=gate but gate.final=null; assert it returns
  #        non-zero, the line never lands in the summary file, and
  #        prune-skipped.log names the run
  local name="_pmctl_artifacts_run_summary_append_verified: rolls back and logs a failed verification"
  should_run "$name" || return 0
  local dir="$tmp_root/verify-failure"
  mkdir -p "$dir"
  local summary_file="$dir/runs-summary.jsonl" skip_log="$dir/prune-skipped.log"
  printf '%s\n' '{"run_id":"pre-existing","summarized_at":1,"kind":"dispatch","status":"complete","duration_seconds":1,"gate":null}' \
    > "$summary_file"
  local bad_summary='{"run_id":"gate-bad","summarized_at":123,"kind":"gate","status":"complete","duration_seconds":1,"gate":{"final":null,"tier":"standard","most_severe":"high","reviewers":{},"findings_by_severity":"unavailable"}}'

  local rc=0
  _pmctl_artifacts_run_summary_append_verified "$bad_summary" "$summary_file" "$skip_log" "gate-bad" || rc=$?

  local line_count
  line_count="$(wc -l < "$summary_file" | tr -d ' ')"
  if [[ "$rc" -ne 0 && "$line_count" -eq 1 ]] \
      && ! grep -q '"run_id":"gate-bad"' "$summary_file" \
      && grep -q 'gate-bad' "$skip_log" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "rc=$rc line_count=$line_count summary=$(<"$summary_file") skip_log=$(cat "$skip_log" 2>/dev/null)"
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
  mkdir -p "$work_repo"
  pmctl_fixture_copy_spine "$REPO_ROOT" "$checkout"
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
  mkdir -p "$configured_repo" "$derived_repo"
  pmctl_fixture_copy_spine "$REPO_ROOT" "$checkout"
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
case_gc_grace_days_env_only_selects_grace_period
case_gc_grace_days_flag_overrides_env
case_gc_grace_days_env_rejects_non_numeric
case_gc_grace_days_flag_rejects_non_numeric
case_gc_dry_run_positive_grace_previews_without_mutation
case_gc_concurrent_invocations_produce_one_summary_line
case_gc_append_failure_retains_run_no_false_success
case_gc_summary_fsync_failure_retains_run
case_gc_retry_after_fsync_failure_resummarizes_before_deleting
case_gc_lock_timeout_reports_failure_and_retains_run
case_gc_summarizes_before_grace_defers_deletion
case_gc_deletes_once_grace_elapses
case_gc_incomplete_preexisting_summary_forces_resummarize
case_gc_incomplete_source_not_treated_as_failure
case_gc_missing_tier_not_treated_as_failure
case_gc_duration_uses_real_mtimes_not_run_id
case_gc_findings_by_severity_buckets_per_reviewer
case_gc_findings_by_severity_unavailable_when_unparseable
case_gc_verification_failure_retains_summary_and_logs
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
