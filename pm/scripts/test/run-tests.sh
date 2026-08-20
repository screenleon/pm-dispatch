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

# lint-ticket-ids.sh：active-board × archive 撞號偵測。
run_idlint_case() {
  name=$1
  want_code=$2
  want_token=$3
  backlog=$4
  archive=$5
  err=$(mktemp)
  set +e
  bash "$root_dir/lint-ticket-ids.sh" "$backlog" "$archive" >/dev/null 2>"$err"
  got_code=$?
  set -e
  if [ "$got_code" -ne "$want_code" ]; then
    fail "$name" "exit $got_code, expected $want_code"
    rm -f "$err"; return
  fi
  if [ -n "$want_token" ] && ! grep -q "$want_token" "$err"; then
    fail "$name" "missing $want_token"
    rm -f "$err"; return
  fi
  if [ "$want_code" -eq 0 ] && [ -s "$err" ]; then
    fail "$name" "stderr was not empty"
    rm -f "$err"; return
  fi
  rm -f "$err"
  pass "$name"
}

run_idlint_case "idlint good-ticket-ids" 0 "" \
  "$fixtures/good-ticket-ids/BACKLOG.md" "$fixtures/good-ticket-ids/BACKLOG-ARCHIVE.md"
# Boundary: a valid board whose active side is only ✅/🚫 tombstone stubs (no
# open ids) must pass cleanly, not trip pipefail on an empty open-id set.
run_idlint_case "idlint good-stubs-only (empty open set)" 0 "" \
  "$fixtures/good-ticket-ids-stubs-only/BACKLOG.md" "$fixtures/good-ticket-ids-stubs-only/BACKLOG-ARCHIVE.md"
run_idlint_case "idlint bad-id-collision" 1 "E-ID-COLLISION" \
  "$fixtures/bad-id-collision/BACKLOG.md" "$fixtures/bad-id-collision/BACKLOG-ARCHIVE.md"
# Negative input: an OPEN ticket whose title contains ✅/🚫 must still collide,
# i.e. only a TERMINAL status marker counts as a tombstone stub.
run_idlint_case "idlint bad-id-collision (glyph in open title)" 1 "E-ID-COLLISION" \
  "$fixtures/bad-id-collision-glyph-title/BACKLOG.md" "$fixtures/bad-id-collision-glyph-title/BACKLOG-ARCHIVE.md"
run_idlint_case "idlint archive file not found" 2 "E-SCHEMA-HEADER" \
  "$fixtures/good-ticket-ids/BACKLOG.md" "/nonexistent/BACKLOG-ARCHIVE.md"
# Arity: omitting the archive argument entirely must exit 2 (usage), not run.
idlint_arity_err=$(mktemp)
set +e
bash "$root_dir/lint-ticket-ids.sh" "$fixtures/good-ticket-ids/BACKLOG.md" >/dev/null 2>"$idlint_arity_err"
idlint_arity_code=$?
set -e
if [ "$idlint_arity_code" -eq 2 ] && grep -q 'Usage:' "$idlint_arity_err"; then
  pass "idlint missing archive arg (arity)"
else
  fail "idlint missing archive arg (arity)" "exit $idlint_arity_code, expected 2 with usage"
fi
rm -f "$idlint_arity_err"

# validate.sh 基本案例。
run_validate_case "validate good" 0 "" "$fixtures/good/BACKLOG.md"
run_validate_case "v1.1 good" 0 "" "$fixtures/good-v11/BACKLOG.md"
run_validate_case "v1.2 good" 0 "" "$fixtures/good-v12/BACKLOG.md"
run_validate_case "v1.1 design-epic good" 0 "" "$fixtures/good-v11-design/BACKLOG.md"
run_validate_case "v1.1 spike-epic good" 0 "" "$fixtures/good-v11-spike/BACKLOG.md"
run_validate_case "v1.2 spike-epic good" 0 "" "$fixtures/good-v12-spike/BACKLOG.md"
run_validate_case "v1.1 bad-priority-enum" 1 "E-PRIORITY-ENUM" "$fixtures/bad-priority-enum/BACKLOG.md"
run_validate_case "v1.1 bad-epic-enum" 1 "E-EPIC-ENUM" "$fixtures/bad-epic-enum/BACKLOG.md"
run_validate_case "v1.2 bad-epic-enum" 1 "E-EPIC-ENUM" "$fixtures/bad-v12-epic/BACKLOG.md"
run_validate_case_warn "v1.1 warn-missing-cols" "$fixtures/warn-missing-cols/BACKLOG.md" "W-MISSING-COLS"
run_validate_case_warn "v1.2 warn-missing-cols" "$fixtures/warn-missing-cols-v12/BACKLOG.md" "W-MISSING-COLS"
run_validate_case "v1.1 good-subletter" 0 "" "$fixtures/good-v11-subletter/BACKLOG.md"
run_validate_case "v1.1 bad-priority-subletter" 1 "E-PRIORITY-ENUM" "$fixtures/bad-priority-subletter/BACKLOG.md"
run_validate_case "validate bad-no-header" 2 "E-SCHEMA-HEADER" "$fixtures/bad-no-header/BACKLOG.md"
run_validate_case "validate bad-index-mismatch" 1 "E-INDEX-MISMATCH" "$fixtures/bad-index-mismatch/BACKLOG.md"
run_validate_case "validate bad-orphan-section" 1 "E-INDEX-MISMATCH" "$fixtures/bad-orphan-section/BACKLOG.md"
run_validate_case "validate bad-dup-id" 1 "E-DUP-ID" "$fixtures/bad-dup-id/BACKLOG.md"
run_validate_case "validate bad-status-enum" 1 "E-STATUS-ENUM" "$fixtures/bad-status-enum/BACKLOG.md"
run_validate_case "validate bad-area-enum" 1 "E-AREA-ENUM" "$fixtures/bad-area-enum/BACKLOG.md"
run_validate_case "validate good-area-alias-documentation" 0 "" "$fixtures/good-area-alias-documentation/BACKLOG.md"
run_validate_case "validate good-area-schema-hook" 0 "" "$fixtures/good-area-schema-hook/BACKLOG.md"
run_validate_case "validate bad-date-format" 1 "E-DATE-FORMAT" "$fixtures/bad-date-format/BACKLOG.md"
run_validate_case "validate bad-refs-prefix" 1 "E-REFS-PREFIX" "$fixtures/bad-refs-prefix/BACKLOG.md"
run_validate_case "validate bad-tags-format" 1 "E-TAGS-FORMAT" "$fixtures/bad-tags-format/BACKLOG.md"
run_validate_case "validate bad-closure-no-see" 1 "E-CLOSURE-NO-SEE" "$fixtures/bad-closure-no-see/BACKLOG.md"
run_validate_case "validate bad-closure-date-mismatch" 1 "E-CLOSURE-DATE-MISMATCH" "$fixtures/bad-closure-date-mismatch/BACKLOG.md"
run_validate_case "validate bad-closure-date-dropped-mismatch" 1 "E-CLOSURE-DATE-MISMATCH" "$fixtures/bad-closure-date-dropped-mismatch/BACKLOG.md"
run_validate_case "validate bad-closure-date-trailing-junk" 1 "E-DATE-FORMAT" "$fixtures/bad-closure-date-trailing-junk/BACKLOG.md"
run_validate_case "validate bad-outcome-date-misplaced" 1 "E-CLOSURE-DATE-MISMATCH" "$fixtures/bad-outcome-date-misplaced/BACKLOG.md"
run_validate_case "validate good-closure-outcome-date" 0 "" "$fixtures/good-closure-outcome-date/BACKLOG.md"
run_validate_case "validate bad-changelog-drift" 1 "E-CHANGELOG-DRIFT" "$fixtures/bad-changelog-drift/BACKLOG.md"
run_validate_case "validate bad-changelog-drift-active-ref" 1 "E-CHANGELOG-DRIFT" "$fixtures/bad-changelog-drift-active-ref/BACKLOG.md"
run_validate_case "validate bad-changelog-drift-cross-repo-ref" 1 "E-CHANGELOG-DRIFT" "$fixtures/bad-changelog-drift-cross-repo-ref/BACKLOG.md"
run_validate_case "validate good-changelog-closed-ref" 0 "" "$fixtures/good-changelog-closed-ref/BACKLOG.md"
run_validate_case "validate good-deferred-someday" 0 "" "$fixtures/good-deferred-someday/BACKLOG.md"
run_validate_case "validate good-archive-stub" 0 "" "$fixtures/good-archive-stub/BACKLOG.md"
run_validate_case "validate good-partial" 0 "" "$fixtures/good-partial/BACKLOG.md"
run_validate_case "validate bad-partial-date" 1 "E-DATE-FORMAT" "$fixtures/bad-partial-date/BACKLOG.md"
run_validate_case "validate good-superseded" 0 "" "$fixtures/good-superseded/BACKLOG.md"
run_validate_case "validate bad-superseded-date" 1 "E-DATE-FORMAT" "$fixtures/bad-superseded-date/BACKLOG.md"
run_validate_case "validate bad-changelog-drift partial-row" 1 "E-CHANGELOG-DRIFT" "$fixtures/bad-changelog-drift-partial/BACKLOG.md"
run_validate_case "v1.1 drift-pipe-topic" 0 "" "$fixtures/good-drift-v11-pipe/BACKLOG.md" "" "$fixtures/good-drift-v11-pipe/CHANGELOG.md"
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
run_validate_case "validate bad-changelog-drift explicit args" 1 "E-CHANGELOG-DRIFT" "$fixtures/bad-changelog-drift/BACKLOG.md" "$fixtures/bad-changelog-drift/DECISIONS.md" "$fixtures/bad-changelog-drift/CHANGELOG.md"
# DECISIONS.md is intentionally only an existing file; validate.sh does not parse it yet.
run_validate_case "validate bad-changelog-drift legacy decisions arg" 1 "E-CHANGELOG-DRIFT" "$fixtures/bad-changelog-drift/BACKLOG.md" "$fixtures/bad-changelog-drift/DECISIONS.md"
run_validate_case "validate bad-changelog-missing explicit arg" 2 "E-SCHEMA-HEADER: changelog file not found:" "$fixtures/bad-changelog-drift/BACKLOG.md" "" "/nonexistent/path/CHANGELOG.md"

# rollup.sh 彙整案例。
rollup_out=$(mktemp)
set +e
bash "$root_dir/rollup.sh" --root "$fixtures/rollup" --out "$rollup_out" --today 2026-05-20 >/dev/null 2>/dev/null
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
elif ! grep -q '| repo-v11 | 4 | 1 |' "$rollup_out"; then
  fail "rollup fixtures" "repo-v11 summary mismatch"
elif ! grep -q 'RV-004' "$rollup_out"; then
  fail "rollup fixtures" "RV-004 escaped-pipe row missing from rollup"
elif ! grep -q '^### repo-v12$' "$rollup_out"; then
  fail "rollup fixtures" "missing repo-v12 section (v1.2 backlog not included)"
elif ! grep -q '| repo-v12 | 1 | 0 |' "$rollup_out"; then
  fail "rollup fixtures" "repo-v12 summary mismatch"
else
  pass "rollup fixtures"
fi
rm -f "$rollup_out"

# Deprecation invariant: CC-NNN ID-range-to-epic mapping must not reappear in
# pm/schema.md or BACKLOG.md Convention section after CC-067 removed the guidance.
# BACKLOG.md is scoped to the Convention meta-block only (excludes index rows and
# archived stubs) so CC-051's historical description does not produce false positives.
_repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
_convention_block=$(awk '/^## Convention$/{f=1} f && /^<!-- archived stubs/{exit} f{print}' \
  "$_repo_root/BACKLOG.md")
_deprecated_pat='CC-1NN 列填|CC-2NN 列填|CC-1NN OSS 系列|CC-2NN 技術債|CC-100.*CC-199|CC-200.*CC-299|CC-1NN.*CC-OSS epic|CC-2NN.*reuse-debt markers'
if { printf '%s\n' "$_convention_block"; cat "$_repo_root/pm/schema.md"; } \
    | grep -qE "$_deprecated_pat"; then
  fail "deprecation-invariant: no CC-NNN epic-grouping guidance in schema/convention" \
    "deprecated ID-range epic mapping still present"
else
  pass "deprecation-invariant: no CC-NNN epic-grouping guidance in schema/convention"
fi

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
