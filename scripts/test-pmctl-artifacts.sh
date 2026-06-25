#!/usr/bin/env bash
# Regression tests for artifact discovery surfaces.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"
WATCH="$REPO_ROOT/scripts/codex-watch.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# shellcheck source=scripts/lib/state-paths.sh
. "$SCRIPT_DIR/lib/state-paths.sh"

make_work_repo() {
  local path="$1"
  mkdir -p "$path"
  git init -q "$path"
}

run_dir_for() {
  local store="$1" work="$2" run_id="$3"
  PM_DISPATCH_STATE_ROOT="$store" bash -c 'cd "$1" && . "$2/scripts/lib/state-paths.sh" && sw_project_run_dir "$3"' \
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

case_artifacts_list_newest_first
case_artifacts_list_empty
case_artifacts_show_files
case_artifacts_show_missing
case_codex_watch_trace_flag
case_codex_watch_run_flag
case_codex_watch_auto_discover

th_summary
