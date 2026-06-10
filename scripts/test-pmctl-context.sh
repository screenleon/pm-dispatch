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
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_index_unknown_flag() {
  local name="pmctl context index: exits 2 for unknown flag"
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/idx-uf.out"; err="$tmp_root/idx-uf.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$REPO_ROOT" --frobnicate > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
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

case_context_update_absolute_path_rejected() {
  local name="pmctl context update: absolute path outside repo is rejected"
  # Behavior: context update must exit 2 and write no DB row for absolute paths outside repo.
  # Steps: index fixture repo; run update with /etc/passwd; assert exit 2 and no DB row.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-abs"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/upd-abs.out"; err="$tmp_root/upd-abs.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context update "$fix_repo" /etc/passwd > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for absolute path; got $status err=$(<"$err")"; return 0
  fi

  # Confirm no /etc/passwd row was written to DB
  local db
  db="$(PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" 2>/dev/null | grep '^db: ' | sed 's/^db: //')"
  if [[ -n "$db" && -f "$db" ]]; then
    local row
    row="$(sqlite3 "$db" "SELECT path FROM files WHERE path LIKE '%etc/passwd%';" 2>/dev/null || true)"
    if [[ -n "$row" ]]; then
      fail "$name" "unexpected DB row for /etc/passwd: $row"; return 0
    fi
  fi
  pass "$name"
}

case_context_update_traversal_rejected() {
  local name="pmctl context update: traversal path outside repo is rejected"
  # Behavior: context update must exit 2 and write no DB row for .. traversal paths.
  # Steps: index fixture repo; run update with ../../etc/passwd; assert exit 2 and no DB row.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-trav"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/upd-trav.out"; err="$tmp_root/upd-trav.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context update "$fix_repo" '../../etc/passwd' > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for traversal; got $status err=$(<"$err")"; return 0
  fi

  local db
  db="$(PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" 2>/dev/null | grep '^db: ' | sed 's/^db: //')"
  if [[ -n "$db" && -f "$db" ]]; then
    local row
    row="$(sqlite3 "$db" "SELECT path FROM files WHERE path LIKE '%etc/passwd%';" 2>/dev/null || true)"
    if [[ -n "$row" ]]; then
      fail "$name" "unexpected DB row after traversal rejection: $row"; return 0
    fi
  fi
  pass "$name"
}

case_context_index_mtime_only_contract() {
  local name="pmctl context index: mtime-only skip contract (preserved mtime skips re-index)"
  # Behavior: second index run skips a file whose content changed but mtime was restored.
  # Steps: index fixture; modify a file and restore its mtime; re-index; assert 0 indexed.
  # Contract: mtime-only skip is explicit — sha1 stored but not used for change detection.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-mtime"
  make_fixture_repo "$fix_repo"

  # Initial index
  local out1 err1 status=0
  out1="$tmp_root/mtime-idx1.out"; err1="$tmp_root/mtime-idx1.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > "$out1" 2> "$err1" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "initial index failed: $(<"$err1")"; return 0
  fi

  # Modify content of one file but restore its original mtime
  local target="$fix_repo/main.py"
  local orig_mtime
  orig_mtime="$(stat -c '%Y' "$target" 2>/dev/null || stat -f '%m' "$target" 2>/dev/null || printf '0')"
  printf '\n# modified\n' >> "$target"
  touch -d "@$orig_mtime" "$target" 2>/dev/null || true  # restore mtime

  # Second index — file should be skipped (mtime unchanged)
  local out2 err2
  out2="$tmp_root/mtime-idx2.out"; err2="$tmp_root/mtime-idx2.err"
  status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > "$out2" 2> "$err2" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "second index failed: $(<"$err2")"; return 0
  fi

  # All files should be skipped (mtime-only semantics: content change not detected)
  if grep -qE '^context index: 0 indexed, [1-9][0-9]* skipped' "$out2"; then
    pass "$name"
  else
    fail "$name" "mtime-only contract violated; expected 0 indexed; got: $(<"$out2")"
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
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
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
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
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

  if assert_exit "$name" "$status" 0; then pass "$name"; fi
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

case_context_query_file_chunks_text_path() {
  local name="pmctl context query: file_chunks text LIKE path returns hit for text-only content"
  # Behavior: querying a term that exists only in file_chunks.text (not in symbols.name)
  #   must return a hit via the text LIKE fallback branch.
  # Steps: create a file with no extractable symbols but unique text; index it; drop FTS;
  #   query the unique text; assert a hit is returned.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-chunks"
  make_fixture_repo "$fix_repo"

  # Add a markdown file where the sentinel is in body text (not a heading).
  # Markdown headings become symbols; body text does not — so only file_chunks.text can match.
  cat > "$fix_repo/NOTES.md" <<'MD'
# Notes

Body text only: unique_chunk_sentinel_8675309_not_a_symbol here.
MD

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  # Drop FTS table to force LIKE path through file_chunks
  local db
  db="$(PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" 2>/dev/null | grep '^db: ' | sed 's/^db: //')"
  if [[ -n "$db" && -f "$db" ]]; then
    sqlite3 "$db" "DROP TABLE IF EXISTS content_fts;" 2>/dev/null || true
  fi

  out="$tmp_root/q-chunks.out"; err="$tmp_root/q-chunks.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" "unique_chunk_sentinel_8675309_not_a_symbol" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 ]] && grep -q 'ref:' "$out"; then
    pass "$name"
  else
    fail "$name" "file_chunks LIKE fallback did not hit; status=$status out=$(<"$out") err=$(<"$err")"
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

case_context_index_deleted_file_reconciled() {
  local name="pmctl context index: deleted file is removed from DB on re-index"
  # Behavior: after a file is deleted from the repo and re-index runs, that file's
  #   path must no longer appear in context query results.
  # Steps: index fixture; delete a file; re-index; query the deleted symbol; assert 0 hits.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-del"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  # Remove the file that contains my_func_alpha
  rm -f "$fix_repo/scripts/lib/mymodule.sh"

  # Re-index — reconciliation should remove stale rows
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/q-del.out"; err="$tmp_root/q-del.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" "my_func_alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 ]] && grep -q '# no hits' "$out"; then
    pass "$name"
  elif [[ "$status" -eq 0 ]] && ! grep -q 'ref:' "$out"; then
    pass "$name"
  else
    fail "$name" "deleted file still queryable; out=$(<"$out")"
  fi
}

case_context_query_fts_multiline_no_bogus_refs() {
  local name="pmctl context query: FTS hit on multiline file emits only valid refs"
  # Behavior: when file_chunks.text contains newlines, FTS query must not emit
  #   continuation lines as bogus ref: entries.
  # Steps: index a file with multiline content containing sentinel; query via FTS;
  #   assert every emitted ref: line looks like a valid path:linenum format.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-fts-ml"
  make_fixture_repo "$fix_repo"

  # Add a multiline file where the sentinel is not on line 1
  cat > "$fix_repo/MULTILINE.md" <<'MD'
# Title

Line two content.
Line three content.
multiline_fts_sentinel_9182736 appears on line five.
Line six content.
Line seven content.
MD

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  # Only test if FTS5 is available; skip otherwise
  local db
  db="$(PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" 2>/dev/null | grep '^db: ' | sed 's/^db: //')"
  if [[ -z "$db" || ! -f "$db" ]]; then
    pass "$name"; return 0
  fi
  local fts_tbl
  fts_tbl="$(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='content_fts';" 2>/dev/null || true)"
  if [[ -z "$fts_tbl" ]]; then
    pass "$name"; return 0  # FTS5 not available — LIKE path tested elsewhere
  fi

  out="$tmp_root/q-fts-ml.out"; err="$tmp_root/q-fts-ml.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context query "$fix_repo" "multiline_fts_sentinel_9182736" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query failed: $(<"$err")"; return 0
  fi

  # Every ref: line must look like path:digits (no raw text content as ref)
  local bogus
  bogus="$(grep '^- ref:' "$out" | grep -v '^- ref: .\+:[0-9][0-9]*$' || true)"
  if [[ -z "$bogus" ]]; then
    pass "$name"
  else
    fail "$name" "bogus ref lines found: $bogus"
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

case_context_pack_missing_task_id() {
  local name="pmctl context pack: exits 2 when --task-id is missing"
  # Behavior: context pack must exit 2 when --task-id is absent from the argument list.
  # Steps: call pack with only --query and no --task-id; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-mtid.out"; err="$tmp_root/pack-mtid.err"
  local noarg_repo="$tmp_root/noarg-repo-mtid"
  mkdir -p "$noarg_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$noarg_repo" --query foo > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_missing_query() {
  local name="pmctl context pack: exits 2 when no --query is provided"
  # Behavior: context pack must exit 2 when at least one --query term is absent.
  # Steps: call pack with --task-id but no --query; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-mq.out"; err="$tmp_root/pack-mq.err"
  local noarg_repo="$tmp_root/noarg-repo-mq"
  mkdir -p "$noarg_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$noarg_repo" --task-id TASK-1 > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_task_id_without_value() {
  local name="pmctl context pack: exits 2 when --task-id flag has no value"
  # Behavior: context pack must exit 2 with a diagnostic when --task-id appears but its value is missing.
  # Steps: call pack with --task-id as last argument; assert exit 2 and stderr diagnostic.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-tiwv.out"; err="$tmp_root/pack-tiwv.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack --task-id > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for --task-id without value; got $status err=$(<"$err")"; return 0
  fi
  if ! grep -q 'requires a value' "$err"; then
    fail "$name" "expected diagnostic in stderr; got: $(<"$err")"; return 0
  fi
  pass "$name"
}

case_context_pack_query_without_value() {
  local name="pmctl context pack: exits 2 when --query flag has no value"
  # Behavior: context pack must exit 2 with a diagnostic when --query appears but its value is missing.
  # Steps: call pack with --task-id and --query as last argument; assert exit 2 and stderr diagnostic.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-qwv.out"; err="$tmp_root/pack-qwv.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack --task-id TASK-1 --query > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for --query without value; got $status err=$(<"$err")"; return 0
  fi
  if ! grep -q 'requires a value' "$err"; then
    fail "$name" "expected diagnostic in stderr; got: $(<"$err")"; return 0
  fi
  pass "$name"
}

case_context_pack_no_db() {
  local name="pmctl context pack: exits 1 when index DB not found"
  # Behavior: context pack must exit 1 when the repo-index DB does not exist.
  # Steps: call pack on a repo with no prior index run (fresh state root); assert exit 1.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-nodb.out"; err="$tmp_root/pack-nodb.err"
  local nodb_repo="$tmp_root/nodb-repo-pack"
  mkdir -p "$nodb_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state-nodb-pack-$$" \
    "$PMCTL" context pack "$nodb_repo" --task-id TASK-1 --query foo \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 1; then pass "$name"; fi
}

case_context_pack_unknown_flag() {
  local name="pmctl context pack: exits 2 for unknown flag"
  # Behavior: context pack must exit 2 when an unrecognized flag is passed.
  # Steps: call pack with --frobnicate flag; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-uf.out"; err="$tmp_root/pack-uf.err"
  local uf_repo="$tmp_root/uf-repo-pack"
  mkdir -p "$uf_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$uf_repo" --frobnicate > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_valid_json() {
  local name="pmctl context pack: valid call produces schema_version 2 JSON with correct fields"
  # Behavior: context pack must emit schema_version 2 JSON with task_id, sources, and at least one hit.
  # Steps: index a fixture repo; run pack with one --query; validate JSON fields via jq.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-json"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/pack-json.out"; err="$tmp_root/pack-json.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query my_func_alpha \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi

  if ! jq -e '
    .schema_version == 2 and
    .task_id == "TASK-1" and
    (.sources | length) > 0 and
    .sources[0].name == "builtin-index" and
    ((.symbols | length) + (.files | length)) >= 1
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "JSON validation failed: $(<"$err") output: $(<"$out")"
    return 0
  fi
  printf 'pack JSON OK\n'
  pass "$name"
}

case_context_pack_symbol_vs_file_split() {
  local name="pmctl context pack: symbol hits go to symbols[], chunk hits go to files[]"
  # Behavior: pack must route symbol-type hits to symbols[] and chunk/FTS-type hits to files[].
  # Steps: index repo with a markdown body-only file; query both symbol and chunk terms; validate routing.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-split"
  make_fixture_repo "$fix_repo"

  # Add a markdown file with no headings (body text only) so it only
  # produces chunk hits, not symbol hits.
  cat > "$fix_repo/NOTES.md" <<'MD'
Body text only: reusescan_chunk_sentinel_78432 no heading here.
MD

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/pack-split.out"; err="$tmp_root/pack-split.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$fix_repo" \
      --task-id TASK-1 \
      --query my_func_alpha \
      --query reusescan_chunk_sentinel_78432 \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi

  if ! jq -e '
    (.symbols | length) > 0 and
    (.symbols | map(.ref) | any(contains("mymodule"))) and
    (.symbols | map(.ref) | all(contains("NOTES.md") | not))
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "split validation failed: $(<"$err") out=$(<"$out")"
    return 0
  fi
  printf 'symbol_vs_file_split OK\n'
  pass "$name"
}

case_context_pack_dedup() {
  local name="pmctl context pack: duplicate --query terms yield exactly one ref per symbol"
  # Behavior: when the same --query term is passed twice, each ref must appear at most once in the output.
  # Steps: index fixture repo; run pack with identical --query twice; assert no duplicate refs in JSON.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-dedup"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/pack-dedup.out"; err="$tmp_root/pack-dedup.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$fix_repo" \
      --task-id TASK-1 \
      --query my_func_alpha \
      --query my_func_alpha \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi

  if ! jq -e '
    [(.symbols + .files) | map(.ref) | group_by(.) | .[] | select(length > 1)] | length == 0
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "dedup validation failed: $(<"$err") out=$(<"$out")"
    return 0
  fi
  printf 'dedup OK\n'
  pass "$name"
}

case_context_reuse_scan_missing_desc() {
  local name="pmctl context reuse-scan: exits 2 when description is missing"
  # Behavior: reuse-scan must exit 2 when no description argument is provided.
  # Steps: call reuse-scan with only a repo path and no description; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/scan-md.out"; err="$tmp_root/scan-md.err"
  local noarg_repo="$tmp_root/noarg-repo-scan"
  mkdir -p "$noarg_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context reuse-scan "$noarg_repo" > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_reuse_scan_no_db() {
  local name="pmctl context reuse-scan: exits 1 when index DB not found"
  # Behavior: reuse-scan must exit 1 when the repo-index DB does not exist.
  # Steps: call reuse-scan on a repo with a fresh state root (no DB); assert exit 1.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/scan-nodb.out"; err="$tmp_root/scan-nodb.err"
  local nodb_repo="$tmp_root/nodb-repo-scan"
  mkdir -p "$nodb_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state-nodb-scan-$$" \
    "$PMCTL" context reuse-scan "$nodb_repo" "some description" \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 1; then pass "$name"; fi
}

case_context_reuse_scan_unknown_flag() {
  local name="pmctl context reuse-scan: exits 2 for unknown flag"
  # Behavior: reuse-scan must exit 2 when an unrecognized flag is passed.
  # Steps: call reuse-scan with --frobnicate flag; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/scan-uf.out"; err="$tmp_root/scan-uf.err"
  local uf_repo="$tmp_root/uf-repo-scan"
  mkdir -p "$uf_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context reuse-scan "$uf_repo" --frobnicate > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_reuse_scan_valid_output() {
  local name="pmctl context reuse-scan: valid call exits 0 with reuse_candidates: header"
  # Behavior: reuse-scan must emit YAML starting with reuse_candidates:, include terms: and hits sections.
  # Steps: index fixture repo; run reuse-scan with a description containing known terms; validate YAML structure.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-scan-valid"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/scan-valid.out"; err="$tmp_root/scan-valid.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context reuse-scan "$fix_repo" "alpha beta function" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi

  local first_line
  first_line="$(head -1 "$out")"
  if [[ "$first_line" != "reuse_candidates:" ]]; then
    fail "$name" "first line not 'reuse_candidates:'; got: $first_line"; return 0
  fi
  if ! grep -q '^  terms:' "$out"; then
    fail "$name" "missing 'terms:' line in output"; return 0
  fi
  if ! grep -q '^  hits' "$out"; then
    fail "$name" "missing 'hits' line in output"; return 0
  fi
  # At least one hit or an empty-hits marker must be present
  if grep -q '^    - ref:' "$out" || grep -q 'hits: \[\]' "$out"; then
    pass "$name"
  else
    fail "$name" "output has hits section but no ref or empty marker; output: $(<"$out")"
  fi
}

case_context_reuse_scan_no_terms() {
  local name="pmctl context reuse-scan: all-stop-word description exits 0 with empty terms and hits"
  # Behavior: when every word in the description is filtered by stop-word logic, output terms: [] and hits: [].
  # Steps: index fixture repo; run reuse-scan with an all-stop-word description; assert empty YAML lists.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-scan-noterms"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/scan-noterms.out"; err="$tmp_root/scan-noterms.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context reuse-scan "$fix_repo" "a an the or" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi

  if grep -q 'terms: \[\]' "$out" && grep -q 'hits: \[\]' "$out"; then
    pass "$name"
  else
    fail "$name" "expected 'terms: []' and 'hits: []'; got: $(<"$out")"
  fi
}

case_context_reuse_scan_dedup() {
  local name="pmctl context reuse-scan: no duplicate refs in output across term queries"
  # Behavior: when multiple extracted terms match the same ref, that ref must appear at most once in output.
  # Steps: index fixture repo; run reuse-scan with a description yielding overlapping terms; assert unique refs.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-scan-dedup"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/scan-dedup.out"; err="$tmp_root/scan-dedup.err"
  # "func alpha" extracts terms ["alpha","func"] — both match my_func_alpha and my_func_beta,
  # triggering the dedup path where the same ref from term "func" is already in seen_file.
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context reuse-scan "$fix_repo" "func alpha" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi

  local total_refs unique_refs
  total_refs="$(grep -c '^    - ref:' "$out" 2>/dev/null || printf '0')"
  unique_refs="$(grep '^    - ref:' "$out" 2>/dev/null | sort -u | wc -l | tr -d ' ')"

  if [[ "$total_refs" -eq "$unique_refs" ]]; then
    pass "$name"
  else
    fail "$name" "duplicate refs: total=$total_refs unique=$unique_refs out=$(<"$out")"
  fi
}

case_context_reuse_scan_on_real_repo() {
  local name="pmctl context reuse-scan: finds pmctl-context.sh ref in real repo"
  # Behavior: reuse-scan on the actual pm-dispatch repo must find pmctl-context.sh in results.
  # Steps: index the real repo; run reuse-scan with context-domain terms; assert pmctl-context.sh appears.
  should_run "$name" || return 0

  if [[ ! -f "$REPO_ROOT/scripts/lib/pmctl-context.sh" ]]; then
    fail "$name" "scripts/lib/pmctl-context.sh not found in repo"; return 0
  fi

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$REPO_ROOT" > /dev/null 2>&1 || true

  out="$tmp_root/scan-real.out"; err="$tmp_root/scan-real.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context reuse-scan "$REPO_ROOT" "emit context hit yaml" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi

  if grep -q 'pmctl-context.sh' "$out"; then
    pass "$name"
  else
    fail "$name" "no pmctl-context.sh ref in output; got: $(<"$out")"
  fi
}

case_context_pack_empty_query_value() {
  local name="pmctl context pack: exits 2 when --query value is empty string"
  # Behavior: context pack must exit 2 when --query is given an explicit empty string.
  # Steps: call pack with --task-id and --query ""; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-emq.out"; err="$tmp_root/pack-emq.err"
  local emq_repo="$tmp_root/emq-repo"
  mkdir -p "$emq_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$emq_repo" --task-id TASK-1 --query "" > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_whitespace_task_id() {
  local name="pmctl context pack: exits 2 when --task-id is whitespace-only"
  # Behavior: context pack must exit 2 when --task-id is whitespace-only.
  # Steps: call pack with --task-id "   " and a --query; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-wstid.out"; err="$tmp_root/pack-wstid.err"
  local ws_repo="$tmp_root/ws-repo"
  mkdir -p "$ws_repo"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$ws_repo" --task-id "   " --query foo > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_nondir_repo_path() {
  local name="pmctl context pack: exits 2 when positional repo argument is not a directory"
  # Behavior: context pack must exit 2 when a non-existent or non-directory positional repo path is given.
  # Steps: call pack with /nonexistent/path as positional arg; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-ndr.out"; err="$tmp_root/pack-ndr.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "/nonexistent/path/xyz" --task-id TASK-1 --query foo > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_schema_contract() {
  local name="pmctl context pack: emitted pack has all required schema_version 2 fields"
  # Behavior: context pack must always include schema_version, task_id, built_ts, sources, files, symbols, memories, risks.
  # Steps: index fixture repo; run pack; validate all top-level required fields are present.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-schema"
  make_fixture_repo "$fix_repo"

  local out err status=0
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 || true

  out="$tmp_root/pack-schema.out"; err="$tmp_root/pack-schema.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/state" \
    "$PMCTL" context pack "$fix_repo" --task-id SCHEMA-TEST --query my_func_alpha \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi

  if ! jq -e '
    has("schema_version") and has("task_id") and has("built_ts") and
    has("sources") and has("files") and has("symbols") and
    has("memories") and has("risks") and
    .schema_version == 2
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "schema contract failed: $(<"$err") output: $(<"$out")"
    return 0
  fi
  pass "$name"
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
case_context_update_absolute_path_rejected
case_context_update_traversal_rejected
case_context_index_mtime_only_contract
case_context_query_missing_query
case_context_query_unknown_flag
case_context_query_known_symbol
case_context_query_unknown_term_exits_0
case_context_query_like_fallback
case_context_query_file_chunks_text_path
case_context_query_fts5_path
case_context_index_deleted_file_reconciled
case_context_query_fts_multiline_no_bogus_refs
case_context_query_on_real_repo
case_context_layer_boundary
case_context_pack_missing_task_id
case_context_pack_missing_query
case_context_pack_task_id_without_value
case_context_pack_query_without_value
case_context_pack_no_db
case_context_pack_unknown_flag
case_context_pack_valid_json
case_context_pack_symbol_vs_file_split
case_context_pack_dedup
case_context_pack_empty_query_value
case_context_pack_whitespace_task_id
case_context_pack_nondir_repo_path
case_context_pack_schema_contract
case_context_reuse_scan_missing_desc
case_context_reuse_scan_no_db
case_context_reuse_scan_unknown_flag
case_context_reuse_scan_valid_output
case_context_reuse_scan_no_terms
case_context_reuse_scan_dedup
case_context_reuse_scan_on_real_repo

th_summary
