#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
fixtures="$script_dir/fixtures"

passed=0
failed=0

pass() {
  printf 'PASS: %s\n' "$1"
  passed=$((passed + 1))
}

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2"
  failed=$((failed + 1))
}

run_validate_case() {
  name=$1
  file=$2
  want_code=$3
  want_token=$4
  err=$(mktemp)
  set +e
  bash "$root_dir/validate.sh" "$file" >/dev/null 2>"$err"
  got_code=$?
  set -e
  if [ "$got_code" -ne "$want_code" ]; then
    fail "$name" "exit $got_code, expected $want_code"
    rm -f "$err"
    return
  fi
  if [ -n "$want_token" ] && ! grep -q "$want_token" "$err"; then
    fail "$name" "missing $want_token"
    rm -f "$err"
    return
  fi
  if [ "$want_code" -eq 1 ]; then
    tokens=$(grep -o 'E-[A-Z0-9-]*' "$err" | sort | uniq | tr '\n' ' ')
    if [ "$tokens" != "$want_token " ]; then
      fail "$name" "unexpected rule tokens: $tokens"
      rm -f "$err"
      return
    fi
  fi
  if [ "$want_code" -eq 0 ] && [ -s "$err" ]; then
    fail "$name" "stderr was not empty"
    rm -f "$err"
    return
  fi
  rm -f "$err"
  pass "$name"
}

run_validate_case_warn() {
  local name=$1 file=$2 want_token=$3
  local err
  err=$(mktemp)
  set +e
  bash "$root_dir/validate.sh" "$file" >/dev/null 2>"$err"
  local got_code=$?
  set -e
  if [ "$got_code" -ne 0 ]; then
    fail "$name" "exit $got_code, expected 0"
    rm -f "$err"; return
  fi
  if grep -q '^E-' "$err"; then
    fail "$name" "unexpected E-* errors in stderr: $(grep '^E-' "$err" | head -3)"
    rm -f "$err"; return
  fi
  if ! grep -q "$want_token" "$err"; then
    fail "$name" "missing $want_token in stderr"
    rm -f "$err"; return
  fi
  rm -f "$err"
  pass "$name"
}

run_validate_case_multi() {
  name=$1
  want_code=$2
  want_token=$3
  shift 3
  err=$(mktemp)
  set +e
  bash "$root_dir/validate.sh" "$@" >/dev/null 2>"$err"
  got_code=$?
  set -e
  if [ "$got_code" -ne "$want_code" ]; then
    fail "$name" "exit $got_code, expected $want_code"
    rm -f "$err"
    return
  fi
  if [ -n "$want_token" ] && ! grep -q "$want_token" "$err"; then
    fail "$name" "missing $want_token"
    rm -f "$err"
    return
  fi
  if [ "$want_code" -eq 1 ]; then
    tokens=$(grep -o 'E-[A-Z0-9-]*' "$err" | sort | uniq | tr '\n' ' ')
    if [ "$tokens" != "$want_token " ]; then
      fail "$name" "unexpected rule tokens: $tokens"
      rm -f "$err"
      return
    fi
  fi
  if [ "$want_code" -eq 0 ] && [ -s "$err" ]; then
    fail "$name" "stderr was not empty"
    rm -f "$err"
    return
  fi
  rm -f "$err"
  pass "$name"
}

# validate.sh 基本案例。
run_validate_case "validate good" "$fixtures/good/BACKLOG.md" 0 ""
run_validate_case "v1.1 good" "$fixtures/good-v11/BACKLOG.md" 0 ""
run_validate_case "v1.1 bad-priority-enum" "$fixtures/bad-priority-enum/BACKLOG.md" 1 "E-PRIORITY-ENUM"
run_validate_case "v1.1 bad-epic-enum" "$fixtures/bad-epic-enum/BACKLOG.md" 1 "E-EPIC-ENUM"
run_validate_case_warn "v1.1 warn-missing-cols" "$fixtures/warn-missing-cols/BACKLOG.md" "W-MISSING-COLS"
run_validate_case "v1.1 good-subletter" "$fixtures/good-v11-subletter/BACKLOG.md" 0 ""
run_validate_case "v1.1 bad-priority-subletter" "$fixtures/bad-priority-subletter/BACKLOG.md" 1 "E-PRIORITY-ENUM"
run_validate_case "validate bad-no-header" "$fixtures/bad-no-header/BACKLOG.md" 2 "E-SCHEMA-HEADER"
run_validate_case "validate bad-index-mismatch" "$fixtures/bad-index-mismatch/BACKLOG.md" 1 "E-INDEX-MISMATCH"
run_validate_case "validate bad-dup-id" "$fixtures/bad-dup-id/BACKLOG.md" 1 "E-DUP-ID"
run_validate_case "validate bad-status-enum" "$fixtures/bad-status-enum/BACKLOG.md" 1 "E-STATUS-ENUM"
run_validate_case "validate bad-area-enum" "$fixtures/bad-area-enum/BACKLOG.md" 1 "E-AREA-ENUM"
run_validate_case "validate bad-date-format" "$fixtures/bad-date-format/BACKLOG.md" 1 "E-DATE-FORMAT"
run_validate_case "validate bad-refs-prefix" "$fixtures/bad-refs-prefix/BACKLOG.md" 1 "E-REFS-PREFIX"
run_validate_case "validate bad-tags-format" "$fixtures/bad-tags-format/BACKLOG.md" 1 "E-TAGS-FORMAT"
run_validate_case "validate bad-closure-no-see" "$fixtures/bad-closure-no-see/BACKLOG.md" 1 "E-CLOSURE-NO-SEE"
run_validate_case "validate bad-closure-date-mismatch" "$fixtures/bad-closure-date-mismatch/BACKLOG.md" 1 "E-CLOSURE-DATE-MISMATCH"
run_validate_case "validate bad-closure-date-dropped-mismatch" "$fixtures/bad-closure-date-dropped-mismatch/BACKLOG.md" 1 "E-CLOSURE-DATE-MISMATCH"
run_validate_case "validate bad-closure-date-trailing-junk" "$fixtures/bad-closure-date-trailing-junk/BACKLOG.md" 1 "E-DATE-FORMAT"
run_validate_case "validate bad-outcome-date-misplaced" "$fixtures/bad-outcome-date-misplaced/BACKLOG.md" 1 "E-CLOSURE-DATE-MISMATCH"
run_validate_case "validate good-closure-outcome-date" "$fixtures/good-closure-outcome-date/BACKLOG.md" 0 ""
run_validate_case "validate bad-changelog-drift" "$fixtures/bad-changelog-drift/BACKLOG.md" 1 "E-CHANGELOG-DRIFT"
run_validate_case "validate bad-changelog-drift-active-ref" "$fixtures/bad-changelog-drift-active-ref/BACKLOG.md" 1 "E-CHANGELOG-DRIFT"
run_validate_case "validate bad-changelog-drift-cross-repo-ref" "$fixtures/bad-changelog-drift-cross-repo-ref/BACKLOG.md" 1 "E-CHANGELOG-DRIFT"
run_validate_case "validate good-changelog-closed-ref" "$fixtures/good-changelog-closed-ref/BACKLOG.md" 0 ""
run_validate_case "validate good-deferred-someday" "$fixtures/good-deferred-someday/BACKLOG.md" 0 ""
run_validate_case "validate good-archive-stub" "$fixtures/good-archive-stub/BACKLOG.md" 0 ""
run_validate_case "validate good-partial" "$fixtures/good-partial/BACKLOG.md" 0 ""
run_validate_case "validate bad-partial-date" "$fixtures/bad-partial-date/BACKLOG.md" 1 "E-DATE-FORMAT"
run_validate_case "validate bad-changelog-drift partial-row" "$fixtures/bad-changelog-drift-partial/BACKLOG.md" 1 "E-CHANGELOG-DRIFT"
run_validate_case_multi "v1.1 drift-pipe-topic" 0 "" "$fixtures/good-drift-v11-pipe/BACKLOG.md" "" "$fixtures/good-drift-v11-pipe/CHANGELOG.md"
# Smoke: repo BACKLOG.md archive/stub changes introduce no new validator errors.
# Uses baseline comparison — any error not in the known pre-existing set is a regression.
# Pre-existing errors are listed in BACKLOG_validator_baseline.txt (CC-030 owns cleanup).
repo_backlog=$(CDPATH= cd -- "$script_dir/../../.." && pwd)/BACKLOG.md
baseline="$script_dir/BACKLOG_validator_baseline.txt"
if [ -f "$repo_backlog" ] && [ -f "$baseline" ]; then
  new_errs=$(comm -23 \
    <(bash "$root_dir/validate.sh" "$repo_backlog" 2>&1 | sort) \
    <(sort "$baseline"))
  if [ -z "$new_errs" ]; then
    pass "validate BACKLOG.md no new errors (archive smoke)"
  else
    fail "validate BACKLOG.md no new errors (archive smoke)" "$(printf '%s' "$new_errs" | head -3)"
  fi
fi
run_validate_case_multi "validate bad-changelog-drift explicit args" 1 "E-CHANGELOG-DRIFT" "$fixtures/bad-changelog-drift/BACKLOG.md" "$fixtures/bad-changelog-drift/DECISIONS.md" "$fixtures/bad-changelog-drift/CHANGELOG.md"
# DECISIONS.md is intentionally only an existing file; validate.sh does not parse it yet.
run_validate_case_multi "validate bad-changelog-drift legacy decisions arg" 1 "E-CHANGELOG-DRIFT" "$fixtures/bad-changelog-drift/BACKLOG.md" "$fixtures/bad-changelog-drift/DECISIONS.md"
run_validate_case_multi "validate bad-changelog-missing explicit arg" 2 "E-SCHEMA-HEADER: changelog file not found:" "$fixtures/bad-changelog-drift/BACKLOG.md" "" "/nonexistent/path/CHANGELOG.md"

# rollup.sh 彙整案例。
rollup_out=$(mktemp)
set +e
bash "$root_dir/rollup.sh" --root "$fixtures/rollup" --out "$rollup_out" >/dev/null 2>/dev/null
rollup_code=$?
set -e
if [ "$rollup_code" -ne 0 ]; then
  fail "rollup fixtures" "exit $rollup_code"
elif ! grep -q '^## Summary$' "$rollup_out"; then
  fail "rollup fixtures" "missing summary"
elif ! grep -q '^### repo-a$' "$rollup_out"; then
  fail "rollup fixtures" "missing repo-a section"
elif ! grep -q '^### repo-b$' "$rollup_out"; then
  fail "rollup fixtures" "missing repo-b section"
elif ! grep -q '^### repo-v11$' "$rollup_out"; then
  fail "rollup fixtures" "missing repo-v11 section"
elif grep -q 'repo-c-no-marker' "$rollup_out"; then
  fail "rollup fixtures" "included unmarked repo"
elif ! grep -q '| repo-a | 3 | 1 |' "$rollup_out"; then
  fail "rollup fixtures" "repo-a summary mismatch"
elif ! grep -q '| repo-b | 2 | 0 |' "$rollup_out"; then
  fail "rollup fixtures" "repo-b summary mismatch"
elif ! grep -q '| repo-v11 | 3 | 1 |' "$rollup_out"; then
  fail "rollup fixtures" "repo-v11 summary mismatch"
else
  pass "rollup fixtures"
fi
rm -f "$rollup_out"

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
