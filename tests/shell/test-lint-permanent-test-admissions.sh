#!/usr/bin/env bash
# Regression tests for tools/lint/lint-permanent-test-admissions.sh -- the
# mechanical floor that fails a PR which grew a pre-existing test suite but
# omits (or leaves as `none`) the Step 4 `Permanent test admissions:` record.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$REPO_ROOT/tools/lint/lint-permanent-test-admissions.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# want <name> <expected-rc> <actual-rc> [needle] [output]
# Asserts the exit code, and (when a needle is given) that it appears in output.
want() {
  local name="$1" exp="$2" got="$3" needle="${4:-}" body="${5:-}"
  if [[ "$got" -ne "$exp" ]]; then
    fail "$name" "expected exit $exp, got $got${body:+ :: $body}"
    return
  fi
  if [[ -n "$needle" && "$body" != *"$needle"* ]]; then
    fail "$name" "missing expected text '$needle' in: $body"
    return
  fi
  pass "$name"
}

# --- fixture repo -----------------------------------------------------------
# A throwaway git repo whose base commit already carries tests/shell/test-existing.sh
# with two test functions. Callers stage further commits, then run the lint with
# --base pointed at the recorded base SHA.
BASE_SHA=""
FIXTURE=""
init_fixture() {
  # shellcheck disable=SC2154  # tmp_root is initialized by th_init.
  FIXTURE="$tmp_root/repo"
  rm -rf "$FIXTURE"
  mkdir -p "$FIXTURE/tests/shell"
  git -C "$FIXTURE" init -q -b main
  git -C "$FIXTURE" config user.email t@example.invalid
  git -C "$FIXTURE" config user.name  test
  cat > "$FIXTURE/tests/shell/test-existing.sh" <<'EOF'
#!/usr/bin/env bash
test_alpha() {
  :
}
test_beta() {
  :
}
EOF
  git -C "$FIXTURE" add -A
  git -C "$FIXTURE" commit -qm base
  BASE_SHA="$(git -C "$FIXTURE" rev-parse HEAD)"
}
commit_all() { git -C "$FIXTURE" add -A && git -C "$FIXTURE" commit -qm "$1"; }
append_existing() { printf '%s\n' "$1" >> "$FIXTURE/tests/shell/test-existing.sh"; }

# run_lint <body-string> [base-ref] -> prints combined output, returns exit code
run_lint() {
  local body="$1" base="${2:-$BASE_SHA}"
  "$LINT" --pr-body <(printf '%s' "$body") --base "$base" --repo-root "$FIXTURE" 2>&1
}

BODY_NONE="$(printf -- '- Permanent test admissions: none\n- Full suite: 120 passed\n')"
BODY_REAL="$(printf -- '- Permanent test admissions:\n  - qa-F001: new blocking test for the empty-input path; criterion 2 (user-observable contract)\n- Full suite: 120 passed\n')"
BODY_NOLINE="$(printf -- 'Summary: did a thing.\n- Full suite: 120 passed\n')"

# --- usage / environment errors (exit 2) ----------------------------------
name="admissions/missing --pr-body exits 2"
if should_run "$name"; then
  init_fixture
  "$LINT" --base "$BASE_SHA" --repo-root "$FIXTURE" >/dev/null 2>&1
  want "$name" 2 "$?"
fi

name="admissions/unknown flag exits 2"
if should_run "$name"; then
  "$LINT" --pr-body - --frobnicate </dev/null >/dev/null 2>&1
  want "$name" 2 "$?"
fi

name="admissions/unreadable body file exits 2"
if should_run "$name"; then
  init_fixture
  "$LINT" --pr-body "$tmp_root/nope-does-not-exist" --base "$BASE_SHA" --repo-root "$FIXTURE" >/dev/null 2>&1
  want "$name" 2 "$?"
fi

name="admissions/unresolvable base ref exits 2 (never treated as no-new-tests)"
if should_run "$name"; then
  init_fixture
  append_existing 'test_gamma() {'
  append_existing '  :'
  append_existing '}'
  commit_all add-gamma
  out="$(run_lint "$BODY_NONE" "0000000000000000000000000000000000000000")"; rc=$?
  want "$name" 2 "$rc" "base ref not found" "$out"
fi

# --- missing line (exit 1) ----------------------------------------------------
name="admissions/absent line fails even with no test changes"
if should_run "$name"; then
  init_fixture
  append_existing '# a trailing note'
  commit_all note
  out="$(run_lint "$BODY_NOLINE")"; rc=$?
  want "$name" 1 "$rc" "missing the 'Permanent test admissions:' line" "$out"
fi

# --- none + net-new fn in a pre-existing file (exit 1) ----------------------
name="admissions/none while a pre-existing suite gained a test fn fails, naming the file"
if should_run "$name"; then
  init_fixture
  append_existing 'test_new_boundary() {'
  append_existing '  assert_eq 1 1'
  append_existing '}'
  commit_all grow-existing
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 1 "$rc" "tests/shell/test-existing.sh" "$out"
  [[ "$out" == *"1 net-new"* ]] || fail "$name (count)" "expected '1 net-new' in: $out"
fi

name="admissions/case_ prefix counts the same as test_"
if should_run "$name"; then
  init_fixture
  append_existing 'case_new_one() { :; }'
  commit_all grow-case
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 1 "$rc" "1 net-new" "$out"
fi

name="admissions/multiple net-new fns are all counted"
if should_run "$name"; then
  init_fixture
  append_existing 'test_one_more() {'
  append_existing '  :'
  append_existing '}'
  append_existing 'test_two_more() {'
  append_existing '  :'
  append_existing '}'
  commit_all grow-two
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 1 "$rc" "2 net-new" "$out"
fi

# --- claim classification edge cases ---------------------------------------
name="admissions/empty text after the colon is treated as none"
if should_run "$name"; then
  init_fixture
  append_existing 'test_needs_record() {'
  append_existing '  :'
  append_existing '}'
  commit_all grow-empty-claim
  out="$(run_lint "$(printf -- '- Permanent test admissions:\n- Full suite: 120 passed\n')")"; rc=$?
  want "$name" 1 "$rc" "<empty>" "$out"
fi

name="admissions/N/A synonym is treated as none"
if should_run "$name"; then
  init_fixture
  append_existing 'test_na_case() {'
  append_existing '  :'
  append_existing '}'
  commit_all grow-na
  out="$(run_lint "$(printf -- '- Permanent test admissions: N/A\n')")"; rc=$?
  want "$name" 1 "$rc"
fi

# --- real record + net-new fn (exit 0) -----------------------------------
name="admissions/a real multi-line record passes with net-new test fns"
if should_run "$name"; then
  init_fixture
  append_existing 'test_recorded_boundary() {'
  append_existing '  :'
  append_existing '}'
  commit_all grow-recorded
  out="$(run_lint "$BODY_REAL")"; rc=$?
  want "$name" 0 "$rc" "admission record present" "$out"
fi

name="admissions/a folded sub-bullet under the header is read as the record, not a sibling"
if should_run "$name"; then
  # Guards the awk continuation logic: an indented '- ' sub-bullet is content,
  # a de-dented sibling '- ' field ends the record.
  init_fixture
  append_existing 'test_folded_case() {'
  append_existing '  :'
  append_existing '}'
  commit_all grow-folded
  body="$(printf -- '- Permanent test admissions:\n    - qa-F002: added a blocking assertion; criterion 3\n    - risk-F004: alternative path (a) -- widened an existing case\n- Full suite: 120 passed\n')"
  out="$(run_lint "$body")"; rc=$?
  want "$name" 0 "$rc" "admission record present" "$out"
fi

# --- exemptions (exit 0) --------------------------------------------------
name="admissions/none passes when a brand-new test file is the only added suite"
if should_run "$name"; then
  init_fixture
  cat > "$FIXTURE/tests/shell/test-brandnew.sh" <<'EOF'
#!/usr/bin/env bash
test_fresh_contract() {
  :
}
EOF
  commit_all add-newfile
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 0 "$rc" "0 net-new" "$out"
fi

name="admissions/none passes when a pre-existing suite changed but gained no test fn"
if should_run "$name"; then
  init_fixture
  append_existing '# adjust a comment only'
  commit_all comment-only
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 0 "$rc" "0 net-new" "$out"
fi

name="admissions/a removed test fn does not count as an admission trigger"
if should_run "$name"; then
  init_fixture
  cat > "$FIXTURE/tests/shell/test-existing.sh" <<'EOF'
#!/usr/bin/env bash
test_alpha() {
  :
}
EOF
  commit_all drop-beta
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 0 "$rc" "0 net-new" "$out"
fi

name="admissions/a new test fn outside tests/ does not count"
if should_run "$name"; then
  init_fixture
  mkdir -p "$FIXTURE/runtime/lib"
  cat > "$FIXTURE/runtime/lib/thing.sh" <<'EOF'
test_helper_shape() {
  :
}
EOF
  commit_all nontest-path
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 0 "$rc" "0 net-new" "$out"
fi

name="admissions/a commented-out or quoted test_ token is not counted"
if should_run "$name"; then
  init_fixture
  append_existing '# test_commented_out() {'
  append_existing 'STR="case_in_a_string() {"'
  commit_all noise-tokens
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 0 "$rc" "0 net-new" "$out"
fi

name="admissions/a moved declaration is not counted as net-new"
if should_run "$name"; then
  # test_beta already exists at base; relocating its declaration within the
  # file must not read as a new function.
  init_fixture
  cat > "$FIXTURE/tests/shell/test-existing.sh" <<'EOF'
#!/usr/bin/env bash
test_beta() {
  :
}
test_alpha() {
  :
}
EOF
  commit_all reorder
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 0 "$rc" "0 net-new" "$out"
fi

name="admissions/a formatting-only declaration edit is not counted as net-new"
if should_run "$name"; then
  init_fixture
  cat > "$FIXTURE/tests/shell/test-existing.sh" <<'EOF'
#!/usr/bin/env bash
test_alpha ()    {
  :
}
test_beta() {
  :
}
EOF
  commit_all reformat
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 0 "$rc" "0 net-new" "$out"
fi

name="admissions/a renamed pre-existing suite that gains a fn fails none, naming the new path"
if should_run "$name"; then
  init_fixture
  git -C "$FIXTURE" mv tests/shell/test-existing.sh tests/shell/test-renamed.sh
  cat >> "$FIXTURE/tests/shell/test-renamed.sh" <<'EOF'
test_after_rename() {
  :
}
EOF
  commit_all rename-and-grow
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 1 "$rc" "tests/shell/test-renamed.sh" "$out"
  [[ "$out" == *"1 net-new"* ]] || fail "$name (count)" "expected '1 net-new' in: $out"
fi

name="admissions/a renamed pre-existing suite that gains a fn passes with a real record"
if should_run "$name"; then
  init_fixture
  git -C "$FIXTURE" mv tests/shell/test-existing.sh tests/shell/test-renamed.sh
  cat >> "$FIXTURE/tests/shell/test-renamed.sh" <<'EOF'
test_after_rename() {
  :
}
EOF
  commit_all rename-and-grow-recorded
  out="$(run_lint "$BODY_REAL")"; rc=$?
  want "$name" 0 "$rc" "admission record present" "$out"
fi

name="admissions/a pure rename with no fn change passes none"
if should_run "$name"; then
  init_fixture
  git -C "$FIXTURE" mv tests/shell/test-existing.sh tests/shell/test-renamed.sh
  commit_all pure-rename
  out="$(run_lint "$BODY_NONE")"; rc=$?
  want "$name" 0 "$rc" "0 net-new" "$out"
fi

name="admissions/reads the PR body from stdin with -"
if should_run "$name"; then
  init_fixture
  append_existing 'test_stdin_path() {'
  append_existing '  :'
  append_existing '}'
  commit_all stdin-case
  out="$(printf '%s' "$BODY_REAL" | "$LINT" --pr-body - --base "$BASE_SHA" --repo-root "$FIXTURE" 2>&1)"; rc=$?
  want "$name" 0 "$rc" "admission record present" "$out"
fi

th_summary
