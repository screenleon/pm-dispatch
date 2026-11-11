#!/usr/bin/env bash
# Regression tests for ops/diagnostics/run-tests-in-wsl.sh. Running real suites
# needs native Windows plus WSL2 and is exercised by hand (the helper is a
# developer aid, not a release gate); here the argument handling, the platform
# refusal and the pure functions (suite names, file and exec lists, changed paths,
# result parsing) run anywhere, by executing or sourcing the script.

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
run_helper 0 "limit in seconds for each named suite" "run-tests-in-wsl/help-documents-options" --help

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
    # Executable on disk but 100644 in the index (what an NTFS checkout looks
    # like): the index wins, so it must not be in the exec list.
    chmod +x tracked-shebang-but-644.sh
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

# joined_paths <nul-list-file>: the paths of a NUL-separated list, sorted and
# joined with "|" (compared as one string by the cases below).
joined_paths() {
  local f acc=""
  local -a all=()
  while IFS= read -r -d '' f; do all+=("$f"); done < "$1"
  while IFS= read -r f; do acc+="$f|"; done < <(printf '%s\n' "${all[@]}" | LC_ALL=C sort)
  printf '%s' "$acc"
}

# Behavior: the changed-path list holds modified, added and renamed (new name)
# files plus untracked files that are not ignored, and leaves out deleted and
# ignored ones; names with spaces survive; a base other than HEAD widens the set
# to what the branch changed since the merge base. An unknown ref is refused with
# a hint, and the ref actually used is reported.
# Steps: build a temp git repo with two commits and one of each kind of change,
#        run rtw_changed_paths for the default base, an older commit and a bad ref.
if should_run "run-tests-in-wsl/changed-paths"; then
  repo="$(mktemp -d)"
  out="$(mktemp)"
  (
    cd "$repo" || exit 1
    git init -q . && git config user.email t@example.com && git config user.name t
    printf 'a\n' > kept.txt; printf 'b\n' > edited.txt; printf 'c\n' > gone.txt
    printf 'd\n' > renamed-from.txt; printf '*.log\n' > .gitignore
    git add -A && git commit -q -m one
    printf 'e\n' > second-commit.txt
    git add -A && git commit -q -m two
    printf 'edited\n' > edited.txt
    rm -f gone.txt
    git mv renamed-from.txt renamed-to.txt
    printf 'new\n' > "has space.txt"
    printf 'x\n' > ignored.log
  )
  ok=1 detail=""
  rtw_changed_paths "$repo" "" "$out" 2>/dev/null || { ok=0; detail+="[default base failed] "; }
  got="$(joined_paths "$out")"
  want="edited.txt|has space.txt|renamed-to.txt|"
  [[ "$got" == "$want" ]] || { ok=0; detail+="[HEAD base: $got want $want] "; }
  [[ "$RTW_BASE_USED" == HEAD ]] || { ok=0; detail+="[base used: $RTW_BASE_USED] "; }
  rtw_changed_paths "$repo" "HEAD~1" "$out" 2>/dev/null || { ok=0; detail+="[HEAD~1 base failed] "; }
  got="$(joined_paths "$out")"
  want="edited.txt|has space.txt|renamed-to.txt|second-commit.txt|"
  [[ "$got" == "$want" ]] || { ok=0; detail+="[HEAD~1 base: $got want $want] "; }
  # With an origin/main ref present the default base is origin/main, not HEAD.
  git -C "$repo" update-ref refs/remotes/origin/main HEAD~1
  rtw_changed_paths "$repo" "" "$out" 2>/dev/null || { ok=0; detail+="[origin/main base failed] "; }
  got="$(joined_paths "$out")"
  [[ "$RTW_BASE_USED" == origin/main && "$got" == "edited.txt|has space.txt|renamed-to.txt|second-commit.txt|" ]] \
    || { ok=0; detail+="[origin/main default: used=$RTW_BASE_USED paths=$got] "; }
  msg="$(rtw_changed_paths "$repo" "no-such-ref" "$out" 2>&1)" && { ok=0; detail+="[bad ref accepted] "; }
  [[ "$msg" == *"no merge base"*"unknown ref"* ]] || { ok=0; detail+="[bad ref message: $msg] "; }
  if [[ "$ok" -eq 1 ]]; then pass "run-tests-in-wsl/changed-paths"; else fail "run-tests-in-wsl/changed-paths" "$detail"; fi
  rm -rf "$repo" "$out"
fi

# wsl-run.sh (script files and pmctl arguments sent to WSL without re-quoting): usage errors and unreadable or CRLF
# input are refused before WSL is needed, so they run on any host. The WSL round trip itself is exercised by hand.
WSL_RUN="$REPO_ROOT/ops/diagnostics/wsl-run.sh"
run_wsl_run() {
  local expected="$1" needle="$2" name="$3"
  shift 3
  should_run "$name" || return 0
  local output status
  output="$(bash "$WSL_RUN" "$@" 2>&1)"
  status=$?
  if [[ "$status" -eq "$expected" && "$output" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit $expected containing '$needle'; got exit $status: $output"
  fi
}
run_wsl_run 2 "usage:" "wsl-run/no-mode-is-usage-error"
run_wsl_run 2 "unknown mode" "wsl-run/unknown-mode" bogus
run_wsl_run 2 "no such file" "wsl-run/missing-script-file" script /no/such/file.sh
if should_run "wsl-run/crlf-script-is-refused"; then
  _crlf_dir="$(mktemp -d)"
  printf 'echo hi\r\n' > "$_crlf_dir/crlf.sh"
  _out="$(bash "$WSL_RUN" script "$_crlf_dir/crlf.sh" 2>&1)"; _st=$?
  if [[ "$_st" -eq 2 && "$_out" == *"CRLF line endings"* ]]; then pass "wsl-run/crlf-script-is-refused"; else fail "wsl-run/crlf-script-is-refused" "exit $_st: $_out"; fi
  rm -rf "$_crlf_dir"
fi
# The refusal must not catch an ordinary LF script: with WSL absent it gets past the CRLF check and stops at
# "wsl.exe not found" (exit 3); with WSL present it runs. Exit 2 or "CRLF" would be the false refusal.
if should_run "wsl-run/lf-script-is-not-refused"; then
  _lf_dir="$(mktemp -d)"
  printf 'echo hi\n' > "$_lf_dir/lf.sh"
  _out="$(bash "$WSL_RUN" script "$_lf_dir/lf.sh" 2>&1)"; _st=$?
  if [[ "$_out" != *"CRLF"* && "$_st" -ne 2 ]]; then pass "wsl-run/lf-script-is-not-refused"; else fail "wsl-run/lf-script-is-not-refused" "exit $_st: $_out"; fi
  rm -rf "$_lf_dir"
fi

# The WSL round trip: arguments with spaces, an apostrophe, `$`, a command substitution and a backquote reach the script as
# the exact bytes given, and none of them is executed on the way (the failure `wsl.exe -e bash -lc '<text>'` has).
# Needs a working WSL; elsewhere it is skipped with that reason.
if should_run "wsl-run/argv-reaches-the-script-unchanged"; then
  if ! command -v wsl.exe >/dev/null 2>&1 || ! wsl.exe -e true >/dev/null 2>&1; then
    skip "wsl-run/argv-reaches-the-script-unchanged" "WSL is not available on this host"
  else
    _argv_dir="$(mktemp -d)"
    printf '%s\n' '#!/usr/bin/env bash' 'for a in "$@"; do printf "<%s>\n" "$a"; done' > "$_argv_dir/args.sh"
    _out="$(bash "$WSL_RUN" script "$_argv_dir/args.sh" 'a b' "it's" '$HOME' '$(echo INJECTED1)' '`echo INJECTED2`' 'x;echo INJECTED3' 2>&1)"
    _want="$(printf '%s\n' '<a b>' "<it's>" '<$HOME>' '<$(echo INJECTED1)>' '<`echo INJECTED2`>' '<x;echo INJECTED3>')"
    if [[ "$_out" == "$_want" ]]; then
      pass "wsl-run/argv-reaches-the-script-unchanged"
    else
      fail "wsl-run/argv-reaches-the-script-unchanged" "got: $_out"
    fi
    rm -rf "$_argv_dir"
  fi
fi

# pmctl mode passes the arguments and the exit status through unchanged. The pmctl that runs inside WSL is a fixture (a
# script that prints each argument and exits 7), so the boundary is real and nothing else is installed; with a real
# pmctl a swallowed status would hide a gate NO-GO the same way.
if should_run "wsl-run/pmctl-mode-keeps-arguments-and-exit-status"; then
  if ! command -v wsl.exe >/dev/null 2>&1 || ! wsl.exe -e true >/dev/null 2>&1; then
    skip "wsl-run/pmctl-mode-keeps-arguments-and-exit-status" "WSL is not available on this host"
  else
    _pm_dir="$(mktemp -d)"
    printf '%s\n' '#!/usr/bin/env bash' 'for a in "$@"; do printf "<%s>\n" "$a"; done' 'exit 7' > "$_pm_dir/fakepmctl"
    chmod +x "$_pm_dir/fakepmctl"
    _pm_wsl="$(MSYS2_ARG_CONV_EXCL='*' wsl.exe -e wslpath -a -u "$(cygpath -w "$_pm_dir/fakepmctl" 2>/dev/null || printf '%s' "$_pm_dir/fakepmctl")" | tr -d '\r')"
    _out="$(bash "$WSL_RUN" --pmctl-command "$_pm_wsl" pmctl gate status 'a b' "it's" '$HOME' '$(echo INJECTED1)' 2>&1)"; _st=$?
    _want="$(printf '%s\n' '<gate>' '<status>' '<a b>' "<it's>" '<$HOME>' '<$(echo INJECTED1)>')"
    if [[ "$_st" -eq 7 && "$_out" == "$_want" ]]; then
      pass "wsl-run/pmctl-mode-keeps-arguments-and-exit-status"
    else
      fail "wsl-run/pmctl-mode-keeps-arguments-and-exit-status" "exit $_st (want 7), got: $_out"
    fi
    rm -rf "$_pm_dir"
  fi
fi

th_summary
