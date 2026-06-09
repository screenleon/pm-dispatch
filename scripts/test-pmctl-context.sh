#!/usr/bin/env bash
# Regression tests for pmctl context index / update / query commands.
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# Skip all tests if sqlite3 is not available (rare but possible on stripped envs)
if ! command -v sqlite3 >/dev/null 2>&1; then
  printf 'SKIP test-pmctl-context: sqlite3 not on PATH\n'
  exit 0
fi

# ── Helpers ────────────────────────────────────────────────────────────────────

# Run pmctl context <sub> with a custom PM_DISPATCH_STATE_ROOT pointing at tmp_root.
run_ctx() {
  local out="$1" err="$2"
  shift 2
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context "$@" > "$out" 2> "$err"
}

# Set up a minimal fixture repo in a temp dir for index/update tests.
make_fixture_repo() {
  local dir="$1"
  mkdir -p "$dir/scripts/lib" "$dir/scripts"

  # A shell file with functions
  cat > "$dir/scripts/lib/mymodule.sh" <<'SH'
#!/usr/bin/env bash
my_func_alpha() {
  printf 'alpha\n'
}
my_func_beta() {
  printf 'beta\n'
}
SH

  # A markdown file
  cat > "$dir/README.md" <<'MD'
# My Project

## Getting Started

Some content here.

## API Reference

More content.
MD

  # A python file
  cat > "$dir/main.py" <<'PY'
def run_task(name):
    pass

class TaskRunner:
    pass
PY
}

# ── Test cases ─────────────────────────────────────────────────────────────────

case_context_index_missing_repo() {
  local name="pmctl context index: exits 2 when repo root is missing"
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/idx-mr.out"; err="$tmp_root/idx-mr.err"
  # CLI always sets REPO_ROOT; test the function directly with REPO_ROOT unset.
  env -u REPO_ROOT bash -c \
    ". \"$SCRIPT_DIR/lib/pmctl-context.sh\" 2>/dev/null; pmctl_context_index" \
    > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 2 && pass "$name" || true
}

case_context_index_unknown_flag() {
  local name="pmctl context index: exits 2 for unknown flag"
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/idx-uf.out"; err="$tmp_root/idx-uf.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$REPO_ROOT" --frobnicate > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 2 && pass "$name" || true
}

case_context_index_creates_db() {
  local name="pmctl context index: first run creates repo-index.db with 3 tables"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-idx"
  make_fixture_repo "$fix_repo"

  local out err status=0
  out="$tmp_root/idx-db.out"; err="$tmp_root/idx-db.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" --source repo > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pmctl context index exited $status: $(<"$err")"
    return 0
  fi

  # Locate the DB from the output
  local db
  db="$(grep '^db: ' "$out" | sed 's/^db: //')"
  if [[ -z "$db" || ! -f "$db" ]]; then
    fail "$name" "DB file not found; index output: $(<"$out")"
    return 0
  fi

  local tables
  tables="$(sqlite3 "$db" ".tables" 2>/dev/null || true)"
  if printf '%s\n' "$tables" | grep -q 'file_chunks' \
    && printf '%s\n' "$tables" | grep -q 'files' \
    && printf '%s\n' "$tables" | grep -q 'symbols'; then
    pass "$name"
  else
    fail "$name" "expected tables files/symbols/file_chunks; got: $tables"
  fi
}

case_context_index_incremental_skip() {
  local name="pmctl context index: second run skips unchanged-mtime files"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-skip"
  make_fixture_repo "$fix_repo"

  local out1 err1 out2 err2 status=0
  out1="$tmp_root/idx-inc1.out"; err1="$tmp_root/idx-inc1.err"
  out2="$tmp_root/idx-inc2.out"; err2="$tmp_root/idx-inc2.err"

  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > "$out1" 2> "$err1" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "first run failed: $(<"$err1")"; return 0
  fi

  # Second run without touching any files
  status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > "$out2" 2> "$err2" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "second run failed: $(<"$err2")"; return 0
  fi

  if grep -qE '^context index: 0 indexed, [1-9][0-9]* skipped' "$out2"; then
    pass "$name"
  else
    fail "$name" "expected '0 indexed, N skipped' in second run output; got: $(<"$out2")"
  fi
}

case_context_update_specific_path() {
  local name="pmctl context update: specific path re-indexes only that file"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-upd"
  make_fixture_repo "$fix_repo"

  local out err status=0
  out="$tmp_root/upd-first.out"; err="$tmp_root/upd-first.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "initial index failed: $(<"$err")"; return 0
  fi

  # Touch (modify mtime) of one file
  touch "$fix_repo/scripts/lib/mymodule.sh"

  # Update only that file
  status=0
  out="$tmp_root/upd-path.out"; err="$tmp_root/upd-path.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context update "$fix_repo" scripts/lib/mymodule.sh > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "update failed: $(<"$err")"; return 0
  fi

  if grep -q 're-indexed' "$out"; then
    pass "$name"
  else
    fail "$name" "expected 're-indexed' in output; got: $(<"$out")"
  fi
}

case_context_update_no_path_full_scan() {
  local name="pmctl context update: no path argument triggers full scan"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-upd2"
  make_fixture_repo "$fix_repo"

  local out err status=0
  out="$tmp_root/upd-first2.out"; err="$tmp_root/upd-first2.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "initial index failed: $(<"$err")"; return 0
  fi

  status=0
  out="$tmp_root/upd-noscan.out"; err="$tmp_root/upd-noscan.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context update "$fix_repo" > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "update without path failed: $(<"$err")"
  fi
}

case_context_query_missing_query() {
  local name="pmctl context query: exits 2 when query string is missing"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-qmm"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/q-mq.out"; err="$tmp_root/q-mq.err"

  # First build an index so query doesn't fail for "no DB" reason
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 2 && pass "$name" || true
}

case_context_query_unknown_flag() {
  local name="pmctl context query: exits 2 for unknown flag"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-quf"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/q-uf.out"; err="$tmp_root/q-uf.err"

  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" --bad-flag "search" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 2 && pass "$name" || true
}

case_context_query_known_symbol() {
  local name="pmctl context query: known symbol returns hit with correct ref path"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-qsym"
  make_fixture_repo "$fix_repo"

  local out err status=0
  out="$tmp_root/q-sym-idx.out"; err="$tmp_root/q-sym-idx.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "index failed: $(<"$err")"; return 0
  fi

  status=0
  out="$tmp_root/q-sym.out"; err="$tmp_root/q-sym.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" "my_func_alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi

  if grep -q 'ref:' "$out" && grep -q 'mymodule.sh' "$out"; then
    pass "$name"
  else
    fail "$name" "expected hit referencing mymodule.sh; got: $(<"$out")"
  fi
}

case_context_query_unknown_term_exits_0() {
  local name="pmctl context query: unknown term exits 0 with 0 hits"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-q0"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/q-zero.out"; err="$tmp_root/q-zero.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" "xyzzy_term_that_does_not_exist_8675309" \
    > "$out" 2> "$err" || status=$?

  assert_exit "$name" "$status" 0 && pass "$name" || true
}

case_context_query_like_fallback() {
  local name="pmctl context query: LIKE fallback works when FTS5 unavailable"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-like"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  # Simulate FTS5 unavailable by dropping the content_fts table if it exists
  local db
  db="$(PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" 2>/dev/null | grep '^db: ' | sed 's/^db: //')"
  if [[ -n "$db" && -f "$db" ]]; then
    sqlite3 "$db" "DROP TABLE IF EXISTS content_fts;" 2>/dev/null || true
  fi

  out="$tmp_root/q-like.out"; err="$tmp_root/q-like.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" "my_func_alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 ]] && grep -q 'ref:' "$out"; then
    pass "$name"
  else
    fail "$name" "LIKE fallback did not return hits; status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_context_query_fts5_path() {
  local name="pmctl context query: FTS5 code path taken when FTS5 available"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-fts5"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  # Check whether the content_fts table was created (indicates FTS5 was used)
  local db
  db="$(PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" 2>/dev/null | grep '^db: ' | sed 's/^db: //')"
  if [[ -z "$db" || ! -f "$db" ]]; then
    fail "$name" "could not locate DB"; return 0
  fi

  local fts_table
  fts_table="$(sqlite3 "$db" \
    "SELECT name FROM sqlite_master WHERE type='table' AND name='content_fts';" 2>/dev/null || true)"

  # Also verify query works via FTS5 path (content_fts table present)
  out="$tmp_root/q-fts5.out"; err="$tmp_root/q-fts5.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" "my_func" > "$out" 2> "$err" || status=$?

  if [[ -n "$fts_table" ]] || sqlite3 "$db" \
      "CREATE VIRTUAL TABLE _t USING fts5(x);" 2>/dev/null \
      && sqlite3 "$db" "DROP TABLE _t;" 2>/dev/null; then
    # FTS5 is supported — verify that the content_fts table exists after index
    if [[ -n "$fts_table" ]]; then
      pass "$name"
    else
      fail "$name" "FTS5 supported but content_fts table missing after index"
    fi
  else
    # FTS5 not supported on this system — this test is vacuously true
    pass "$name"
  fi
}

case_context_query_on_real_repo() {
  local name="pmctl context query: pmctl_validate_brief found in real repo index"
  should_run "$name" || return 0

  if [[ ! -f "$REPO_ROOT/scripts/lib/pmctl-validate.sh" ]]; then
    fail "$name" "scripts/lib/pmctl-validate.sh not found in repo"; return 0
  fi

  local out err status=0
  out="$tmp_root/q-real-idx.out"; err="$tmp_root/q-real-idx.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$REPO_ROOT" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "real repo index failed: $(<"$err")"; return 0
  fi

  status=0
  out="$tmp_root/q-real.out"; err="$tmp_root/q-real.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$REPO_ROOT" "pmctl_validate_brief" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi

  if grep -q 'pmctl-validate.sh' "$out"; then
    pass "$name"
  else
    fail "$name" "expected hit for pmctl-validate.sh; got: $(<"$out")"
  fi
}

case_context_layer_boundary() {
  local name="pmctl-context.sh: does not source pmctl-dispatch.sh or adapters"
  should_run "$name" || return 0

  local lib="$REPO_ROOT/scripts/lib/pmctl-context.sh"
  if [[ ! -f "$lib" ]]; then
    fail "$name" "pmctl-context.sh not found"; return 0
  fi

  # Check non-comment lines for forbidden sources
  local violations
  violations="$(grep -vE '^[[:space:]]*#' "$lib" \
    | grep -E '\. .*pmctl-dispatch\.sh|source .*pmctl-dispatch\.sh|\. .*adapter' || true)"

  if [[ -z "$violations" ]]; then
    pass "$name"
  else
    fail "$name" "found forbidden source calls: $violations"
  fi
}

# ── Run all cases ──────────────────────────────────────────────────────────────

case_context_index_missing_repo
case_context_index_unknown_flag
case_context_index_creates_db
case_context_index_incremental_skip
case_context_update_specific_path
case_context_update_no_path_full_scan
case_context_query_missing_query
case_context_query_unknown_flag
case_context_query_known_symbol
case_context_query_unknown_term_exits_0
case_context_query_like_fallback
case_context_query_fts5_path
case_context_query_on_real_repo
case_context_layer_boundary

th_summary
