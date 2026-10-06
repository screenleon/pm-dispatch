#!/usr/bin/env bash
# Regression tests for ops/diagnostics/run-tests-in-wsl.sh. Running real suites
# needs native Windows plus WSL2 and is exercised by hand (the helper is a
# developer aid, not a release gate); here the argument handling, the platform
# refusal and the pure functions (suite names, file and exec lists, result
# parsing) run anywhere, by executing or sourcing the script.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/ops/diagnostics/run-tests-in-wsl.sh"
# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091  # runner invokes shellcheck without -x
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Defines the rtw_* functions without running the helper.
# shellcheck source=ops/diagnostics/run-tests-in-wsl.sh
# shellcheck disable=SC1091  # runner invokes shellcheck without -x
. "$HELPER"

should_run() {
  if $LIST; then ALL_CASES+=("$1"); return 1; fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

# run_helper <expected-exit> <output-substring> <name> <args...>
run_helper() {
  local expected="$1" needle="$2" name="$3"
  shift 3
  should_run "$name" || return 0
  local output status
  output="$(bash "$HELPER" "$@" 2>&1)"
  status=$?
  if [[ "$status" -eq "$expected" && "$output" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit $expected containing '$needle'; got exit $status: $output"
  fi
}

# Behavior: help text is printed with exit 0 and describes the options a caller
# needs, taken from the file's own header.
# Steps: run with --help; assert exit 0, the usage line and the --timeout text.
run_helper 0 "usage: run-tests-in-wsl.sh" "run-tests-in-wsl/help" --help
run_helper 0 "per-suite limit in seconds" "run-tests-in-wsl/help-documents-options" --help

# Behavior: a call that names no suite (and is not --sync-only) is a usage error.
# Steps: run with no arguments; assert exit 2 and the usage line.
run_helper 2 "usage:" "run-tests-in-wsl/no-suite-is-usage-error"

# Behavior: unknown options and a malformed --timeout are usage errors, not
# silently ignored.
# Steps: run with --bogus, then with --timeout abc and 0; assert exit 2 for each.
run_helper 2 "usage:" "run-tests-in-wsl/unknown-option" --bogus test-foo
run_helper 2 "usage:" "run-tests-in-wsl/non-numeric-timeout" --timeout abc test-foo
run_helper 2 "usage:" "run-tests-in-wsl/zero-timeout" --timeout 0 test-foo

# Behavior: outside native Windows Git Bash the helper refuses, because there
# the suites should simply be run directly.
# Steps: on a non-msys, non-cygwin platform run with a suite name; assert exit 2
#        and the platform message. Skipped on native Windows.
case "${OSTYPE:-}" in
  msys*|cygwin*)
    if should_run "run-tests-in-wsl/refuses-outside-native-windows"; then
      skip "run-tests-in-wsl/refuses-outside-native-windows" "only meaningful off native Windows"
    fi
    ;;
  *)
    run_helper 2 "native-Windows Git Bash" "run-tests-in-wsl/refuses-outside-native-windows" test-doctor
    ;;
esac

# Behavior: a suite is named by its file stem, with or without .sh or the
# tests/shell/ prefix; anything else, or a suite that does not exist, is refused
# (suite names become paths inside WSL).
# Steps: normalize three spellings of a real suite and four bad names.
if should_run "run-tests-in-wsl/suite-name-normalization"; then
  ok=1 detail=""
  for spelling in test-lint-frontmatter test-lint-frontmatter.sh tests/shell/test-lint-frontmatter.sh; do
    got="$(rtw_normalize_suite "$spelling" 2>&1)" || { ok=0; detail+="[$spelling refused: $got] "; continue; }
    [[ "$got" == test-lint-frontmatter ]] || { ok=0; detail+="[$spelling -> $got] "; }
  done
  for bad in "../etc/passwd" "tests/shell/../../x" "lint-frontmatter" "test-no-such-suite-xyz" "test-a b"; do
    if rtw_normalize_suite "$bad" >/dev/null 2>&1; then ok=0; detail+="[$bad accepted] "; fi
  done
  if [[ "$ok" -eq 1 ]]; then pass "run-tests-in-wsl/suite-name-normalization"; else fail "run-tests-in-wsl/suite-name-normalization" "$detail"; fi
fi

# Behavior: the copy list holds tracked and untracked-but-not-ignored files that
# still exist; the exec list holds the index-mode 100755 files plus untracked
# files with a shebang, and nothing else. Both are NUL-separated so a name with
# a space survives.
# Steps: build a temp git repo with every case, run rtw_build_lists, compare.
if should_run "run-tests-in-wsl/file-and-exec-lists"; then
  repo="$(mktemp -d)"
  (
    cd "$repo" || exit 1
    git init -q . && git config user.email t@example.com && git config user.name t
    git config core.autocrlf false
    printf '#!/bin/sh\n' > tracked-exec.sh
    printf '#!/bin/sh\n' > "has space.sh"
    printf 'plain\n' > tracked-plain.txt
    printf '#!/bin/sh\n' > tracked-shebang-but-644.sh
    printf 'gone\n' > deleted.txt
    printf '*.log\n' > .gitignore
    git add -A
    git update-index --chmod=+x tracked-exec.sh "has space.sh"
    git commit -q -m init
    rm -f deleted.txt
    printf '#!/bin/sh\n' > untracked-shebang
    printf 'plain\n' > untracked-plain
    printf 'x\n' > ignored.log
  )
  files="$(mktemp)"; execs="$(mktemp)"
  rtw_build_lists "$repo" "$files" "$execs"
  got_files="$(tr '\0' '\n' < "$files" | LC_ALL=C sort | tr '\n' '|')"
  got_execs="$(tr '\0' '\n' < "$execs" | LC_ALL=C sort | tr '\n' '|')"
  want_files=".gitignore|has space.sh|tracked-exec.sh|tracked-plain.txt|tracked-shebang-but-644.sh|untracked-plain|untracked-shebang|"
  want_execs="has space.sh|tracked-exec.sh|untracked-shebang|"
  if [[ "$got_files" == "$want_files" && "$got_execs" == "$want_execs" ]]; then
    pass "run-tests-in-wsl/file-and-exec-lists"
  else
    fail "run-tests-in-wsl/file-and-exec-lists" "files=$got_files (want $want_files) execs=$got_execs (want $want_execs)"
  fi
  rm -rf "$repo" "$files" "$execs"
fi

# Behavior: the result of a run is read from marker lines that start a line; the
# last marker wins, a marker inside other text is ignored, and a missing or
# non-numeric status is 125 (WSL itself failed), so a broken run can never look
# like a pass.
# Steps: parse a failing run, a timeout, a run with no marker, a non-numeric
#        status, and text with a stray and a repeated marker.
if should_run "run-tests-in-wsl/result-parsing"; then
  ok=1 detail=""
  rtw_parse_result $'__summary=3 passed, 1 failed, 0 skipped\n__failed=failed cases: a, b\n__log=/w/x.log\n__rc=1'
  [[ "$RTW_RC" == 1 && "$RTW_SUMMARY" == "3 passed, 1 failed, 0 skipped" \
     && "$RTW_FAILED" == "failed cases: a, b" && "$RTW_LOG" == "/w/x.log" ]] || { ok=0; detail+="[failing run: $RTW_RC|$RTW_SUMMARY|$RTW_FAILED|$RTW_LOG] "; }
  rtw_parse_result $'__summary=\n__rc=124'
  [[ "$RTW_RC" == 124 && -z "$RTW_SUMMARY" ]] || { ok=0; detail+="[timeout: $RTW_RC] "; }
  rtw_parse_result $'some output\nwithout any marker'
  [[ "$RTW_RC" == 125 ]] || { ok=0; detail+="[no marker: $RTW_RC] "; }
  rtw_parse_result $'__rc=abc'
  [[ "$RTW_RC" == 125 ]] || { ok=0; detail+="[non-numeric: $RTW_RC] "; }
  rtw_parse_result $'x__rc=1\n__rc=0\nlog says __rc=7\n__rc=3'
  [[ "$RTW_RC" == 3 ]] || { ok=0; detail+="[stray and repeated marker: $RTW_RC] "; }
  if [[ "$ok" -eq 1 ]]; then pass "run-tests-in-wsl/result-parsing"; else fail "run-tests-in-wsl/result-parsing" "$detail"; fi
fi

# --- whole flow against a stand-in wsl.exe -----------------------------------
# A fake wsl.exe that runs the command locally lets the sync, mode-bit, run,
# marker, cleanup and --changed paths execute without WSL (the real thing is
# checked by hand and in WSL). Native Windows has the real wsl.exe, so the flow
# cases are skipped there.

FLOW_TMP=""
flow_cleanup() { [[ -z "$FLOW_TMP" ]] || rm -rf "$FLOW_TMP"; }
trap flow_cleanup EXIT

# flow_fixture: build a small checkout with the helper copied in, a stand-in
# wsl.exe and an empty HOME. Sets FX, FLOW_HOME, FLOW_PATH.
flow_fixture() {
  flow_cleanup
  FLOW_TMP="$(mktemp -d)"
  FX="$FLOW_TMP/checkout"
  FLOW_HOME="$FLOW_TMP/home"
  local fake="$FLOW_TMP/fake"
  mkdir -p "$FX/ops/diagnostics" "$FX/tests/shell" "$FX/tests/bin" "$FLOW_HOME" "$fake"
  cp "$HELPER" "$FX/ops/diagnostics/run-tests-in-wsl.sh"
  chmod +x "$FX/ops/diagnostics/run-tests-in-wsl.sh"
  # shellcheck disable=SC2016  # the stand-in's own $1 and $@ must stay literal
  printf '#!/usr/bin/env bash\n[[ "$1" == -d ]] && shift 2\n[[ "$1" == -e ]] && shift\nexec "$@"\n' > "$fake/wsl.exe"
  chmod +x "$fake/wsl.exe"
  FLOW_PATH="$fake:$PATH"
  local t
  printf '#!/usr/bin/env bash\necho "2 passed, 0 failed, 0 skipped"\n' > "$FX/tests/shell/test-ok.sh"
  printf '#!/usr/bin/env bash\necho "FAIL: case-x: boom"\necho "1 passed, 1 failed, 0 skipped"\necho "failed cases: case-x"\nexit 1\n' > "$FX/tests/shell/test-fail.sh"
  printf '#!/usr/bin/env bash\nsleep 30\n' > "$FX/tests/shell/test-slow.sh"
  printf '#!/usr/bin/env bash\necho "no summary line here"\n' > "$FX/tests/shell/test-quiet.sh"
  printf '#!/usr/bin/env bash\nsleep 2\necho "1 passed, 0 failed, 0 skipped"\n' > "$FX/tests/shell/test-pause.sh"
  cat > "$FX/tests/shell/test-env.sh" <<'EOF'
#!/usr/bin/env bash
[ -x tool.sh ] || { echo "tool.sh not executable"; exit 1; }
[ ! -x plain.txt ] || { echo "plain.txt is executable"; exit 1; }
[ -f "has space.txt" ] || { echo "file with a space missing"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo"; exit 1; }
grep -q edited plain.txt || { echo "uncommitted edit not synced"; exit 1; }
[ -f untracked.txt ] || { echo "untracked file not synced"; exit 1; }
[ ! -e ignored.log ] || { echo "ignored file was synced"; exit 1; }
echo "7 passed, 0 failed, 0 skipped"
EOF
  printf '#!/usr/bin/env bash\nprintf "ARGS:"; printf " %%s" "$@"; printf "\\n"\n' > "$FX/tests/bin/run-tests.sh"
  printf '#!/bin/sh\n' > "$FX/tool.sh"
  printf 'orig\n' > "$FX/plain.txt"
  printf 'x\n' > "$FX/has space.txt"
  printf '*.log\n' > "$FX/.gitignore"
  for t in "$FX"/tests/shell/*.sh "$FX"/tests/bin/run-tests.sh "$FX/tool.sh"; do chmod +x "$t"; done
  (
    cd "$FX" || exit 1
    git init -q . && git add -A && git update-index --chmod=+x tool.sh \
      && git -c user.name=t -c user.email=t@example.com commit -q -m init
    printf 'edited\n' > plain.txt
    printf 'new\n' > untracked.txt
    printf 'x\n' > ignored.log
  )
}

# flow_run <args...>: run the copied helper in the fixture with the stand-in
# wsl.exe; prints its output, sets FLOW_RC.
flow_run() {
  local out
  out="$(cd "$FX" && HOME="$FLOW_HOME" PATH="$FLOW_PATH" RUN_TESTS_IN_WSL_ASSUME_WINDOWS=1 \
    bash ops/diagnostics/run-tests-in-wsl.sh "$@" 2>&1)"
  FLOW_RC=$?
  printf '%s\n' "$out"
}

flow_scratch_dirs() { find "$FLOW_HOME/.cache/pm-dispatch-wsl-tests" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' '; }

case "${OSTYPE:-}" in
  msys*|cygwin*)
    for n in passing-run failing-and-slow-run concurrent-runs keep-and-sweep changed-mode; do
      if should_run "run-tests-in-wsl/flow-$n"; then
        skip "run-tests-in-wsl/flow-$n" "native Windows has the real wsl.exe; run in WSL or CI"
      fi
    done
    ;;
  *)
    # Behavior: a passing run syncs the working tree (uncommitted and untracked
    # files, not ignored ones), restores the real executable bits, makes it a git
    # repo, prints one row per suite and removes its scratch tree.
    # Steps: run an ok suite, a quiet suite and an environment-checking suite.
    if should_run "run-tests-in-wsl/flow-passing-run"; then
      flow_fixture
      flow_run test-ok test-env test-quiet > "$FLOW_TMP/out.txt"
      out="$(cat "$FLOW_TMP/out.txt")"
      if [[ "$FLOW_RC" -eq 0 && "$out" == *"test-env"*"7 passed, 0 failed"* \
            && "$out" == *"prints no summary line"* && "$(flow_scratch_dirs)" == 0 ]]; then
        pass "run-tests-in-wsl/flow-passing-run"
      else
        fail "run-tests-in-wsl/flow-passing-run" "rc=$FLOW_RC scratch=$(flow_scratch_dirs) out=$out"
      fi
    fi

    # Behavior: a failing suite and a timed-out suite make the helper exit 1, show
    # the failed-case line and the log path, and leave the scratch tree (it holds
    # the logs) behind.
    # Steps: run a failing and a slow suite with --timeout 3.
    if should_run "run-tests-in-wsl/flow-failing-and-slow-run"; then
      flow_fixture
      flow_run --timeout 3 test-fail test-slow > "$FLOW_TMP/out.txt"
      out="$(cat "$FLOW_TMP/out.txt")"
      log="$(printf '%s\n' "$out" | sed -n 's/^  log (inside WSL): //p' | head -n 1)"
      if [[ "$FLOW_RC" -eq 1 && "$out" == *"failed cases: case-x"* && "$out" == *"timed out after 3s"* \
            && -n "$log" && -f "$log" && "$(flow_scratch_dirs)" == 1 ]]; then
        pass "run-tests-in-wsl/flow-failing-and-slow-run"
      else
        fail "run-tests-in-wsl/flow-failing-and-slow-run" "rc=$FLOW_RC scratch=$(flow_scratch_dirs) log=$log out=$out"
      fi
    fi

    # Behavior: two runs of the same checkout at the same time do not replace each
    # other's scratch tree.
    # Steps: start two runs of a suite that takes two seconds, wait for both.
    if should_run "run-tests-in-wsl/flow-concurrent-runs"; then
      flow_fixture
      ( cd "$FX" && HOME="$FLOW_HOME" PATH="$FLOW_PATH" RUN_TESTS_IN_WSL_ASSUME_WINDOWS=1 \
          bash ops/diagnostics/run-tests-in-wsl.sh test-pause > "$FLOW_TMP/run1.txt" 2>&1; echo $? > "$FLOW_TMP/rc1" ) &
      p1=$!
      ( cd "$FX" && HOME="$FLOW_HOME" PATH="$FLOW_PATH" RUN_TESTS_IN_WSL_ASSUME_WINDOWS=1 \
          bash ops/diagnostics/run-tests-in-wsl.sh test-pause > "$FLOW_TMP/run2.txt" 2>&1; echo $? > "$FLOW_TMP/rc2" ) &
      p2=$!
      wait "$p1" "$p2"
      if [[ "$(cat "$FLOW_TMP/rc1")" == 0 && "$(cat "$FLOW_TMP/rc2")" == 0 \
            && "$(cat "$FLOW_TMP/run1.txt" "$FLOW_TMP/run2.txt")" == *"1 passed, 0 failed"* ]]; then
        pass "run-tests-in-wsl/flow-concurrent-runs"
      else
        fail "run-tests-in-wsl/flow-concurrent-runs" "rc1=$(cat "$FLOW_TMP/rc1") rc2=$(cat "$FLOW_TMP/rc2") out1=$(cat "$FLOW_TMP/run1.txt") out2=$(cat "$FLOW_TMP/run2.txt")"
      fi
    fi

    # Behavior: --keep and --sync-only leave the scratch tree; the next start
    # sweeps trees of the same checkout that are more than a day old and leaves
    # other directories alone.
    # Steps: --keep run, --sync-only run, then an old tree and an unrelated
    #        directory appear and a run starts.
    if should_run "run-tests-in-wsl/flow-keep-and-sweep"; then
      flow_fixture
      flow_run --keep test-ok >/dev/null; rc_keep=$FLOW_RC; n_keep="$(flow_scratch_dirs)"
      flow_run --sync-only >/dev/null; rc_sync=$FLOW_RC; n_sync="$(flow_scratch_dirs)"
      key="$(basename "$FX")-$(printf '%s' "$(cd "$FX" && pwd)" | cksum | cut -d' ' -f1)"
      base="$FLOW_HOME/.cache/pm-dispatch-wsl-tests"
      mkdir -p "$base/$key-old" "$base/unrelated-old"
      touch -d '3 days ago' "$base/$key-old" "$base/unrelated-old"
      flow_run test-ok >/dev/null; rc_after=$FLOW_RC
      if [[ "$rc_keep" -eq 0 && "$n_keep" == 1 && "$rc_sync" -eq 0 && "$n_sync" == 2 && "$rc_after" -eq 0 \
            && ! -e "$base/$key-old" && -d "$base/unrelated-old" ]]; then
        pass "run-tests-in-wsl/flow-keep-and-sweep"
      else
        fail "run-tests-in-wsl/flow-keep-and-sweep" "keep rc=$rc_keep n=$n_keep sync rc=$rc_sync n=$n_sync after rc=$rc_after old-left=$(for f in "$base"/*; do printf '%s ' "${f##*/}"; done)"
      fi
    fi

    # Behavior: --changed hands the changed and untracked paths (not ignored ones)
    # to tests/bin/run-tests.sh inside WSL as --path arguments, and says so when
    # nothing changed.
    # Steps: run --changed in the fixture (an edited and an untracked file), then
    #        commit everything and run it again.
    if should_run "run-tests-in-wsl/flow-changed-mode"; then
      flow_fixture
      flow_run --changed > "$FLOW_TMP/out.txt"
      out="$(cat "$FLOW_TMP/out.txt")"
      rc1=$FLOW_RC
      (cd "$FX" && git add -A && git -c user.name=t -c user.email=t@example.com commit -q -m more)
      flow_run --changed > "$FLOW_TMP/out.txt"
      out2="$(cat "$FLOW_TMP/out.txt")"
      if [[ "$rc1" -eq 0 && "$out" == *"ARGS: --jobs 4"*"--path plain.txt"* && "$out" == *"--path untracked.txt"* \
            && "$out" != *"ignored.log"* && "$FLOW_RC" -eq 0 && "$out2" == *"no changed paths"* ]]; then
        pass "run-tests-in-wsl/flow-changed-mode"
      else
        fail "run-tests-in-wsl/flow-changed-mode" "rc1=$rc1 out=$out rc2=$FLOW_RC out2=$out2"
      fi
    fi
    ;;
esac

th_summary
