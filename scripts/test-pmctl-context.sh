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

# Isolate ALL state writes — including the context usage telemetry that query /
# reuse-scan emit — into the throwaway tmp_root, so the suite never pollutes or
# contends on the developer's real install partition. Cases that need a specific
# root override this locally.
export PM_DISPATCH_STATE_ROOT="$tmp_root/suite-state"

# ── Helpers ────────────────────────────────────────────────────────────────────

# Set up a minimal fixture repo in a temp dir for index/update tests.
make_fixture_repo() {
  local dir="$1"
  mkdir -p "$dir/scripts/lib" "$dir/scripts" "$dir/docs"

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

  # Knowledge docs
  cat > "$dir/BACKLOG.md" <<'MD'
# Backlog

## Section One

alpha knowledge body one.

## Section Two

beta knowledge body two.

## Section Three

gamma knowledge body three.
MD

  cat > "$dir/docs/arch.md" <<'MD'
# Architecture

## Architecture

alpha architecture note.
MD

  cat > "$dir/notes.txt" <<'TXT'
plain text note line one
plain text note line two
TXT

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

    "$PMCTL" context index "$fix_repo" > "$out1" 2> "$err1" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "first run failed: $(<"$err1")"; return 0
  fi

  # Second run without touching any files
  status=0
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
    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "initial index failed: $(<"$err")"; return 0
  fi

  # Touch (modify mtime) of one file
  touch "$fix_repo/scripts/lib/mymodule.sh"

  # Update only that file
  status=0
  out="$tmp_root/upd-path.out"; err="$tmp_root/upd-path.err"
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
    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "initial index failed: $(<"$err")"; return 0
  fi

  status=0
  out="$tmp_root/upd-noscan.out"; err="$tmp_root/upd-noscan.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/upd-abs.out"; err="$tmp_root/upd-abs.err"
    "$PMCTL" context update "$fix_repo" /etc/passwd > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for absolute path; got $status err=$(<"$err")"; return 0
  fi

  # Confirm no /etc/passwd row was written to DB
  local db
  db="$fix_repo/.pm-dispatch/ctx/context.db"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/upd-trav.out"; err="$tmp_root/upd-trav.err"
    "$PMCTL" context update "$fix_repo" '../../etc/passwd' > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for traversal; got $status err=$(<"$err")"; return 0
  fi

  local db
  db="$fix_repo/.pm-dispatch/ctx/context.db"
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

case_context_index_markdown_no_symbols() {
  local name="pmctl context index: Markdown headings are not indexed as symbols"
  # Behavior: indexing a Markdown file must produce 0 symbol rows and at least
  # 1 file_chunk row — headings are document structure, not reusable code symbols.
  # Steps: index a repo containing only a Markdown file with headings; assert
  # symbols table is empty and file_chunks has at least one row for the file.
  should_run "$name" || return 0

  local md_repo="$tmp_root/md-only-repo"
  mkdir -p "$md_repo"
  cat > "$md_repo/NOTES.md" <<'MD'
# Getting Started

Some introductory text.

## Installation

Run the install script.

### Advanced

More details here.
MD

  local out err status=0
  out="$tmp_root/md-idx.out"; err="$tmp_root/md-idx.err"
    "$PMCTL" context index "$md_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "index failed: $(<"$err")"; return 0
  fi

  local db
  db="$(grep '^db: ' "$out" | sed 's/^db: //')"
  if [[ -z "$db" || ! -f "$db" ]]; then
    fail "$name" "DB file not found; index output: $(<"$out")"; return 0
  fi

  local sym_count chunk_count
  sym_count="$(sqlite3 "$db" "SELECT COUNT(*) FROM symbols;" 2>/dev/null || printf '0')"
  chunk_count="$(sqlite3 "$db" \
    "SELECT COUNT(*) FROM file_chunks fc JOIN files f ON fc.file_id=f.id WHERE f.path='NOTES.md';" \
    2>/dev/null || printf '0')"

  if [[ "$sym_count" -ne 0 ]]; then
    fail "$name" "expected 0 symbols for Markdown-only repo; got $sym_count"; return 0
  fi
  if [[ "$chunk_count" -lt 1 ]]; then
    fail "$name" "expected at least 1 file_chunk for NOTES.md; got $chunk_count"; return 0
  fi
  pass "$name"
}

case_context_query_missing_query() {
  local name="pmctl context query: exits 2 when query string is missing"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-qmm"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/q-mq.out"; err="$tmp_root/q-mq.err"

  # First build an index so query doesn't fail for "no DB" reason
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

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
    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "index failed: $(<"$err")"; return 0
  fi

  status=0
  out="$tmp_root/q-sym.out"; err="$tmp_root/q-sym.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/q-zero.out"; err="$tmp_root/q-zero.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  # Simulate FTS5 unavailable by dropping the content_fts table if it exists
  local db
  db="$fix_repo/.pm-dispatch/ctx/context.db"
  if [[ -n "$db" && -f "$db" ]]; then
    sqlite3 "$db" "DROP TABLE IF EXISTS content_fts;" 2>/dev/null || true
  fi

  out="$tmp_root/q-like.out"; err="$tmp_root/q-like.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  # Drop FTS table to force LIKE path through file_chunks
  local db
  db="$fix_repo/.pm-dispatch/ctx/context.db"
  if [[ -n "$db" && -f "$db" ]]; then
    sqlite3 "$db" "DROP TABLE IF EXISTS content_fts;" 2>/dev/null || true
  fi

  out="$tmp_root/q-chunks.out"; err="$tmp_root/q-chunks.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  # Check whether the content_fts table was created (indicates FTS5 was used)
  local db
  db="$fix_repo/.pm-dispatch/ctx/context.db"
  if [[ -z "$db" || ! -f "$db" ]]; then
    fail "$name" "could not locate DB"; return 0
  fi

  local fts_table
  fts_table="$(sqlite3 "$db" \
    "SELECT name FROM sqlite_master WHERE type='table' AND name='content_fts';" 2>/dev/null || true)"

  # Also verify query works via FTS5 path (content_fts table present)
  out="$tmp_root/q-fts5.out"; err="$tmp_root/q-fts5.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  # Remove the file that contains my_func_alpha
  rm -f "$fix_repo/scripts/lib/mymodule.sh"

  # Re-index — reconciliation should remove stale rows
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/q-del.out"; err="$tmp_root/q-del.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  # Only test if FTS5 is available; skip otherwise
  local db
  db="$fix_repo/.pm-dispatch/ctx/context.db"
  if [[ -z "$db" || ! -f "$db" ]]; then
    pass "$name"; return 0
  fi
  local fts_tbl
  fts_tbl="$(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='content_fts';" 2>/dev/null || true)"
  if [[ -z "$fts_tbl" ]]; then
    pass "$name"; return 0  # FTS5 not available — LIKE path tested elsewhere
  fi

  out="$tmp_root/q-fts-ml.out"; err="$tmp_root/q-fts-ml.err"
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
    "$PMCTL" context index "$REPO_ROOT" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "real repo index failed: $(<"$err")"; return 0
  fi

  status=0
  out="$tmp_root/q-real.out"; err="$tmp_root/q-real.err"
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
  local name="pmctl context pack: exits 0 with empty JSON when index DB not found"
  # Behavior: context pack is an acceleration path — missing DB must return graceful
  # empty JSON (schema_version 2, empty files/symbols arrays) rather than exiting 1.
  # Steps: call pack on a repo with no prior index run; assert exit 0 and valid empty JSON.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-nodb.out"; err="$tmp_root/pack-nodb.err"
  local nodb_repo="$tmp_root/nodb-repo-pack"
  mkdir -p "$nodb_repo"
    "$PMCTL" context pack "$nodb_repo" --task-id TASK-1 --query foo \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if ! jq -e '.schema_version == 2 and (.files | length) == 0 and (.symbols | length) == 0' \
      "$out" > /dev/null 2>&1; then
    fail "$name" "expected empty schema_version-2 JSON; got: $(<"$out")"; return 0
  fi
  pass "$name"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/pack-json.out"; err="$tmp_root/pack-json.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/pack-split.out"; err="$tmp_root/pack-split.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/pack-dedup.out"; err="$tmp_root/pack-dedup.err"
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
    "$PMCTL" context reuse-scan "$noarg_repo" > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_reuse_scan_no_db() {
  local name="pmctl context reuse-scan: exits 0 with empty YAML when index DB not found"
  # Behavior: reuse-scan is an acceleration path — missing DB must return graceful empty
  # YAML (reuse_candidates: header, hits: []) rather than exiting 1.
  # Steps: call reuse-scan on a repo with no prior index run; assert exit 0 and empty hits.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/scan-nodb.out"; err="$tmp_root/scan-nodb.err"
  local nodb_repo="$tmp_root/nodb-repo-scan"
  mkdir -p "$nodb_repo"
    "$PMCTL" context reuse-scan "$nodb_repo" "some description" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if grep -q '^reuse_candidates:' "$out" && grep -q 'hits: \[\]' "$out"; then
    pass "$name"
  else
    fail "$name" "expected reuse_candidates: header and hits: []; got: $(<"$out")"
  fi
}

case_context_query_no_db() {
  local name="pmctl context query: exits 0 with no-hits + zero-hit event when index DB not found"
  # Behavior: query is an acceleration path — a missing index must return exit 0 with
  # '# no hits', AND (telemetry contract) still emit a zero-hit context.queried event.
  should_run "$name" || return 0

  local nodb_repo="$tmp_root/nodb-repo-query"
  mkdir -p "$nodb_repo"
  local state_root="$tmp_root/state-query-nodb"; mkdir -p "$state_root"

  local out err status=0
  out="$tmp_root/query-nodb.out"; err="$tmp_root/query-nodb.err"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context query "$nodb_repo" "alpha" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if ! grep -q '# no hits' "$out"; then
    fail "$name" "expected '# no hits' output; got: $(<"$out")"; return 0
  fi
  if grep -q 'telemetry not recorded' "$err" 2>/dev/null; then
    fail "$name" "no-db query reported a telemetry emit failure: $(<"$err")"; return 0
  fi
  local evt hits
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.queried --all --json 2>/dev/null \
    | jq -c 'select(.payload.query == "alpha")' 2>/dev/null | tail -1)"
  if [[ -z "$evt" ]]; then
    fail "$name" "expected a context.queried event for the no-db query"; return 0
  fi
  hits="$(printf '%s\n' "$evt" | jq -r '.payload.hits' 2>/dev/null)"
  if [[ "$hits" != "0" ]]; then
    fail "$name" "expected payload.hits=0 for no-db query; got: $hits"; return 0
  fi
  pass "$name"
}

case_context_reuse_scan_no_db_emits() {
  local name="pmctl context reuse-scan: emits zero-hit context.reuse_scanned when index DB not found"
  should_run "$name" || return 0

  local nodb_repo="$tmp_root/nodb-repo-scan-evt"
  mkdir -p "$nodb_repo"
  local state_root="$tmp_root/state-scan-nodb"; mkdir -p "$state_root"

  local err status=0
  err="$tmp_root/scan-nodb-evt.err"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context reuse-scan "$nodb_repo" "alpha beta function" \
    > /dev/null 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if grep -q 'telemetry not recorded' "$err" 2>/dev/null; then
    fail "$name" "no-db reuse-scan reported a telemetry emit failure: $(<"$err")"; return 0
  fi
  local evt hits
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.reuse_scanned --all --json 2>/dev/null \
    | jq -c 'select(.payload.query == "alpha beta function")' 2>/dev/null | tail -1)"
  if [[ -z "$evt" ]]; then
    fail "$name" "expected a context.reuse_scanned event for the no-db scan"; return 0
  fi
  hits="$(printf '%s\n' "$evt" | jq -r '.payload.hits' 2>/dev/null)"
  if [[ "$hits" != "0" ]]; then
    fail "$name" "expected payload.hits=0 for no-db reuse-scan; got: $hits"; return 0
  fi
  pass "$name"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/scan-valid.out"; err="$tmp_root/scan-valid.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/scan-noterms.out"; err="$tmp_root/scan-noterms.err"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/scan-dedup.out"; err="$tmp_root/scan-dedup.err"
  # "func alpha" extracts terms ["alpha","func"] — both match my_func_alpha and my_func_beta,
  # triggering the dedup path where the same ref from term "func" is already in seen_file.
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
    "$PMCTL" context index "$REPO_ROOT" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/scan-real.out"; err="$tmp_root/scan-real.err"
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

case_context_reuse_scan_hit_cap() {
  local name="pmctl context reuse-scan: output capped at 5 hits even when more exist"
  # Behavior: reuse-scan must emit at most 5 '- ref:' entries regardless of how many index hits exist.
  # Steps: index a fixture repo with many symbols; describe with a broad term that matches many symbols;
  # assert ref-count <= 5.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-scan-cap"
  mkdir -p "$fix_repo/scripts/lib"
  # Generate a shell file with 10 functions that all share the term "captest"
  {
    printf '#!/usr/bin/env bash\n'
    for i in $(seq 1 10); do
      printf 'captest_func_%d() { printf captest_%d; }\n' "$i" "$i"
    done
  } > "$fix_repo/scripts/lib/captest.sh"

  local out err status=0
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/scan-cap.out"; err="$tmp_root/scan-cap.err"
    "$PMCTL" context reuse-scan "$fix_repo" "captest func" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi

  # The fixture generates 10 captest_func_* symbols; the cap must truncate to
  # exactly 5 — asserting == 5 proves both the upper bound and that useful
  # output was not silently dropped to zero.
  local ref_count
  ref_count="$(grep -c '^    - ref:' "$out" 2>/dev/null || printf '0')"
  if [[ "$ref_count" -eq 5 ]]; then
    pass "$name"
  else
    fail "$name" "expected exactly 5 refs (cap), got $ref_count; output: $(<"$out")"
  fi
}

case_context_query_emits_event() {
  local name="pmctl context query: emits context.queried event readable via pmctl trace"
  # Behavior: after a successful query, pmctl trace tail --kind context.queried must return at least one event.
  # Steps: index fixture; run query; run trace with --kind context.queried --all --json; assert >= 1 line.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-query-evt"
  make_fixture_repo "$fix_repo"

  # Telemetry honors PM_DISPATCH_STATE_ROOT, so the whole test runs in an isolated
  # state root — no pollution of, or lock contention on, the shared install partition.
  local state_root="$tmp_root/state-query-evt"
  mkdir -p "$state_root"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  # Snapshot event count before query to detect the new event (delta check).
  local before_count=0
  before_count="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.queried --all --json 2>/dev/null \
    | wc -l | tr -d ' ')" || before_count=0

  local out err status=0
  out="$tmp_root/query-evt.out"; err="$tmp_root/query-evt.err"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context query "$fix_repo" "alpha" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "context query exited $status: $(<"$err")"; return 0
  fi

  # Emit is observable: a dropped telemetry event prints a "telemetry not recorded"
  # warning to stderr (see _ctx_emit_warn). Catch it at the source — this turns a
  # silent event drop into a diagnosable failure instead of an unexplained after=0.
  if grep -q 'telemetry not recorded' "$err" 2>/dev/null; then
    fail "$name" "context query reported a telemetry emit failure: $(<"$err")"; return 0
  fi

  local trace_out trace_err trace_status=0
  trace_out="$tmp_root/query-trace.out"; trace_err="$tmp_root/query-trace.err"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.queried --all --json \
    > "$trace_out" 2> "$trace_err" || trace_status=$?

  if [[ "$trace_status" -ne 0 ]]; then
    fail "$name" "pmctl trace exited $trace_status; stderr: $(<"$trace_err")"; return 0
  fi

  local after_count
  after_count="$(wc -l < "$trace_out" | tr -d ' ')"
  if [[ "$after_count" -le "$before_count" ]]; then
    fail "$name" "expected new context.queried event in trace (before=$before_count after=$after_count); query stderr: $(<"$err")"; return 0
  fi

  # Isolation: a DIFFERENT, fresh state root must NOT see our event — proves the
  # event is scoped to $state_root (i.e. PM_DISPATCH_STATE_ROOT is honored, not
  # forced global). Reads a known-empty root, so it stays fast regardless of how
  # large the real install partition has grown.
  local other_root="$tmp_root/state-query-other"; mkdir -p "$other_root"
  local leak_count=0
  leak_count="$(PM_DISPATCH_STATE_ROOT="$other_root" \
    "$PMCTL" trace tail --kind context.queried --all --json 2>/dev/null \
    | wc -l | tr -d ' ')" || true
  if [[ "$leak_count" -gt 0 ]]; then
    fail "$name" "context.queried event visible under an unrelated state root ($leak_count events); state-root scoping failure"; return 0
  fi

  # Assert payload contract from OUR event (match by query term, not tail-1 which
  # could be a concurrent hook event added between our query and this trace read).
  local our_event evt_kind evt_subject_type payload_query payload_hits
  our_event="$(jq -c 'select(.payload.query == "alpha")' "$trace_out" 2>/dev/null | tail -1)"
  if [[ -z "$our_event" ]]; then
    fail "$name" "no context.queried event with payload.query=alpha found in trace"; return 0
  fi
  evt_kind="$(printf '%s\n' "$our_event" | jq -r '.kind' 2>/dev/null)"
  evt_subject_type="$(printf '%s\n' "$our_event" | jq -r '.subject_type' 2>/dev/null)"
  payload_query="$(printf '%s\n' "$our_event" | jq -r '.payload.query' 2>/dev/null)"
  payload_hits="$(printf '%s\n' "$our_event" | jq -r '.payload.hits' 2>/dev/null)"

  if [[ "$evt_kind" != "context.queried" ]]; then
    fail "$name" "event kind: expected context.queried, got: $evt_kind"; return 0
  fi
  if [[ "$evt_subject_type" != "context" ]]; then
    fail "$name" "event subject_type: expected context, got: $evt_subject_type"; return 0
  fi
  if [[ "$payload_query" != "alpha" ]]; then
    fail "$name" "event payload.query: expected alpha, got: $payload_query"; return 0
  fi
  if ! [[ "$payload_hits" =~ ^[0-9]+$ ]]; then
    fail "$name" "event payload.hits: expected integer, got: $payload_hits"; return 0
  fi
  pass "$name"
}

case_context_reuse_scan_emits_event() {
  local name="pmctl context reuse-scan: emits context.reuse_scanned event readable via pmctl trace"
  # Behavior: after a successful reuse-scan, pmctl trace tail --kind context.reuse_scanned must return >= 1 event.
  # Steps: index fixture; run reuse-scan; run trace; assert >= 1 line.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-reuse-evt"
  make_fixture_repo "$fix_repo"

  # Telemetry honors PM_DISPATCH_STATE_ROOT, so the whole test runs in an isolated
  # state root — no pollution of, or lock contention on, the shared install partition.
  local state_root="$tmp_root/state-reuse-evt"
  mkdir -p "$state_root"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  # Snapshot event count before reuse-scan (for delta check).
  local before_count=0
  before_count="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.reuse_scanned --all --json 2>/dev/null \
    | wc -l | tr -d ' ')" || before_count=0

  local out err status=0
  out="$tmp_root/reuse-evt.out"; err="$tmp_root/reuse-evt.err"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context reuse-scan "$fix_repo" "alpha beta function" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "context reuse-scan exited $status: $(<"$err")"; return 0
  fi

  # Catch a dropped telemetry event at its source (see _ctx_emit_warn) rather than
  # inferring it later from an unexplained after=0.
  if grep -q 'telemetry not recorded' "$err" 2>/dev/null; then
    fail "$name" "context reuse-scan reported a telemetry emit failure: $(<"$err")"; return 0
  fi

  local trace_out trace_err trace_status=0
  trace_out="$tmp_root/reuse-trace.out"; trace_err="$tmp_root/reuse-trace.err"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.reuse_scanned --all --json \
    > "$trace_out" 2> "$trace_err" || trace_status=$?

  if [[ "$trace_status" -ne 0 ]]; then
    fail "$name" "pmctl trace exited $trace_status; stderr: $(<"$trace_err")"; return 0
  fi

  local after_count
  after_count="$(wc -l < "$trace_out" | tr -d ' ')"
  if [[ "$after_count" -le "$before_count" ]]; then
    fail "$name" "expected new context.reuse_scanned event in trace (before=$before_count after=$after_count); reuse-scan stderr: $(<"$err")"; return 0
  fi

  # Isolation: a DIFFERENT, fresh state root must NOT see our event — proves it is
  # scoped to $state_root (PM_DISPATCH_STATE_ROOT honored, not forced global), and
  # stays fast because the read target is always empty.
  local other_root="$tmp_root/state-reuse-other"; mkdir -p "$other_root"
  local leak_count=0
  leak_count="$(PM_DISPATCH_STATE_ROOT="$other_root" \
    "$PMCTL" trace tail --kind context.reuse_scanned --all --json 2>/dev/null \
    | wc -l | tr -d ' ')" || true
  if [[ "$leak_count" -gt 0 ]]; then
    fail "$name" "context.reuse_scanned event visible under an unrelated state root ($leak_count events); state-root scoping failure"; return 0
  fi

  # Assert payload contract from OUR event (match by query term, not tail-1).
  local our_event evt_kind evt_subject_type payload_query payload_hits
  our_event="$(jq -c 'select(.payload.query == "alpha beta function")' "$trace_out" 2>/dev/null | tail -1)"
  if [[ -z "$our_event" ]]; then
    fail "$name" "no context.reuse_scanned event with payload.query='alpha beta function' found in trace"; return 0
  fi
  evt_kind="$(printf '%s\n' "$our_event" | jq -r '.kind' 2>/dev/null)"
  evt_subject_type="$(printf '%s\n' "$our_event" | jq -r '.subject_type' 2>/dev/null)"
  payload_query="$(printf '%s\n' "$our_event" | jq -r '.payload.query' 2>/dev/null)"
  payload_hits="$(printf '%s\n' "$our_event" | jq -r '.payload.hits' 2>/dev/null)"

  if [[ "$evt_kind" != "context.reuse_scanned" ]]; then
    fail "$name" "event kind: expected context.reuse_scanned, got: $evt_kind"; return 0
  fi
  if [[ "$evt_subject_type" != "context" ]]; then
    fail "$name" "event subject_type: expected context, got: $evt_subject_type"; return 0
  fi
  if [[ "$payload_query" != "alpha beta function" ]]; then
    fail "$name" "event payload.query: expected 'alpha beta function', got: $payload_query"; return 0
  fi
  if ! [[ "$payload_hits" =~ ^[0-9]+$ ]]; then
    fail "$name" "event payload.hits: expected integer, got: $payload_hits"; return 0
  fi
  pass "$name"
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
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/pack-schema.out"; err="$tmp_root/pack-schema.err"
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

case_context_query_domain_invalid() {
  local name="pmctl context query: --domain invalid exits 2"
  should_run "$name" || return 0
  # Behavior: --domain with an unrecognized value must exit 2 with a diagnostic.
  # Steps: run query with --domain invalid; assert exit 2 and error message on stderr.

  local fix_repo="$tmp_root/fix-repo-domain-invalid"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/q-domain-invalid.out"; err="$tmp_root/q-domain-invalid.err"

    "$PMCTL" context query "$fix_repo" --domain invalid "alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2; got $status err=$(<"$err")"; return 0
  fi
  if grep -q -- '--domain must be' "$err"; then
    pass "$name"
  else
    fail "$name" "expected --domain diagnostic; got: $(<"$err")"
  fi
}

case_context_query_domain_knowledge_only() {
  local name="pmctl context query: --domain knowledge returns only knowledge hits"
  should_run "$name" || return 0
  # Behavior: --domain knowledge must return hits only from knowledge-domain paths and set source_domain: knowledge.
  # Steps: index fixture with BACKLOG.md and a .sh file; query --domain knowledge; assert BACKLOG.md hit and no .sh hit.

  local fix_repo="$tmp_root/fix-repo-domain-knowledge"
  make_fixture_repo "$fix_repo"
  local out err status=0

    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/q-domain-knowledge.out"; err="$tmp_root/q-domain-knowledge.err"
    "$PMCTL" context query "$fix_repo" --domain knowledge "alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi
  if ! grep -q 'BACKLOG.md' "$out"; then
    fail "$name" "expected BACKLOG.md hit; got: $(<"$out")"; return 0
  fi
  if grep -q '\.sh:' "$out"; then
    fail "$name" "repo-domain .sh hit leaked into knowledge output: $(<"$out")"; return 0
  fi
  if grep -q 'source_domain: knowledge' "$out"; then
    pass "$name"
  else
    fail "$name" "expected source_domain: knowledge; got: $(<"$out")"
  fi
}

case_context_query_domain_repo_only() {
  local name="pmctl context query: --domain repo returns only repo hits"
  should_run "$name" || return 0
  # Behavior: --domain repo must return hits only from code files and exclude knowledge-domain paths.
  # Steps: index fixture with BACKLOG.md and a .sh file; query --domain repo; assert .sh hit and no BACKLOG.md hit.

  local fix_repo="$tmp_root/fix-repo-domain-repo"
  make_fixture_repo "$fix_repo"
  local out err status=0

    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/q-domain-repo.out"; err="$tmp_root/q-domain-repo.err"
    "$PMCTL" context query "$fix_repo" --domain repo "alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi
  if ! grep -q '\.sh:' "$out"; then
    fail "$name" "expected .sh hit; got: $(<"$out")"; return 0
  fi
  if grep -q 'BACKLOG.md\|DECISIONS.md' "$out"; then
    fail "$name" "knowledge hit leaked into repo output: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_query_domain_no_flag_backward_compat() {
  local name="pmctl context query: no --domain returns both domains"
  should_run "$name" || return 0
  # Behavior: omitting --domain must preserve existing behavior — hits from both knowledge and repo domains.
  # Steps: index fixture with BACKLOG.md and a .sh file; query without --domain; assert both domains appear.

  local fix_repo="$tmp_root/fix-repo-domain-none"
  make_fixture_repo "$fix_repo"
  local out err status=0

    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/q-domain-none.out"; err="$tmp_root/q-domain-none.err"
    "$PMCTL" context query "$fix_repo" "alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi
  if grep -q 'BACKLOG.md' "$out" && grep -q '\.sh:' "$out"; then
    pass "$name"
  else
    fail "$name" "expected both BACKLOG.md and .sh hits; got: $(<"$out")"
  fi
}

case_context_index_markdown_heading_chunks() {
  local name="pmctl context index: Markdown knowledge docs chunk by heading"
  should_run "$name" || return 0
  # Behavior: indexing a Markdown file with multiple headings must produce one file_chunks row per heading.
  # Steps: index fixture BACKLOG.md with 3 sections; assert 3 rows with non-empty heading field in file_chunks.

  local fix_repo="$tmp_root/fix-repo-heading-chunks"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/idx-heading.out"; err="$tmp_root/idx-heading.err"

    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "index failed: $(<"$err")"; return 0
  fi

  local db count
  db="$(grep '^db: ' "$out" | sed 's/^db: //')"
  count="$(sqlite3 "$db" \
    "SELECT COUNT(*) FROM file_chunks fc JOIN files f ON fc.file_id=f.id WHERE f.path='BACKLOG.md' AND fc.heading LIKE 'Section %';" \
    2>/dev/null || printf '0')"

  if [[ "$count" -eq 3 ]]; then
    pass "$name"
  else
    fail "$name" "expected 3 section heading chunks; got $count"
  fi
}

case_context_chunk_markdown_no_code_fence_headings() {
  local name="pmctl context index: Markdown headings inside fences are ignored"
  should_run "$name" || return 0
  # Behavior: a ## heading inside a fenced code block must not produce a separate file_chunks row.
  # Steps: index a Markdown file with one real heading and one ## inside ```; assert no chunk with fenced heading text.

  local fix_repo="$tmp_root/fix-repo-fence-headings"
  mkdir -p "$fix_repo"
  cat > "$fix_repo/BACKLOG.md" <<'MD'
# Backlog

## Real Heading

alpha outside fence.

```
## Not A Heading
```
MD

  local out err status=0
  out="$tmp_root/idx-fence.out"; err="$tmp_root/idx-fence.err"
    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "index failed: $(<"$err")"; return 0
  fi

  local db fenced
  db="$(grep '^db: ' "$out" | sed 's/^db: //')"
  fenced="$(sqlite3 "$db" \
    "SELECT COUNT(*) FROM file_chunks fc JOIN files f ON fc.file_id=f.id WHERE f.path='BACKLOG.md' AND fc.heading='Not A Heading';" \
    2>/dev/null || printf '0')"
  if [[ "$fenced" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "fenced heading was indexed as a chunk"
  fi
}

case_context_index_txt_indexed() {
  local name="pmctl context index: .txt files are indexed"
  should_run "$name" || return 0
  # Behavior: .txt files must appear in the files table after pmctl context index.
  # Steps: index fixture containing notes.txt; query files table; assert notes.txt row exists.

  local fix_repo="$tmp_root/fix-repo-txt"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/idx-txt.out"; err="$tmp_root/idx-txt.err"

    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "index failed: $(<"$err")"; return 0
  fi

  local db row
  db="$(grep '^db: ' "$out" | sed 's/^db: //')"
  row="$(sqlite3 "$db" "SELECT path FROM files WHERE path='notes.txt';" 2>/dev/null || true)"
  if [[ "$row" == "notes.txt" ]]; then
    pass "$name"
  else
    fail "$name" "notes.txt missing from files table"
  fi
}

case_context_classify_domain() {
  local name="pmctl-context.sh: _ctx_classify_domain classifies knowledge paths"
  should_run "$name" || return 0
  # Behavior: _ctx_classify_domain must return "knowledge" for top-level knowledge docs and docs/* paths, "repo" for all others.
  # Steps: call _ctx_classify_domain with BACKLOG.md, docs/arch.md, scripts/foo.sh, CHANGELOG.md; assert exact classification sequence.

  local out err status=0
  out="$tmp_root/classify.out"; err="$tmp_root/classify.err"
  bash -c ". \"$SCRIPT_DIR/lib/pmctl-context.sh\" 2>/dev/null; \
    _ctx_classify_domain BACKLOG.md; printf '\n'; \
    _ctx_classify_domain docs/arch.md; printf '\n'; \
    _ctx_classify_domain scripts/foo.sh; printf '\n'; \
    _ctx_classify_domain CHANGELOG.md; printf '\n'" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "classification command failed: $(<"$err")"; return 0
  fi
  if [[ "$(<"$out")" == $'knowledge\nknowledge\nrepo\nrepo' ]]; then
    pass "$name"
  else
    fail "$name" "unexpected classifications: $(<"$out")"
  fi
}

case_context_chunk_window_multiwindow() {
  local name="pmctl context index: window chunker produces multiple chunks for large .txt"
  should_run "$name" || return 0
  # Behavior: a .txt file larger than one window (40 lines) must produce ≥ 2 file_chunks rows with distinct line ranges.
  # Steps: index a 90-line .txt fixture; assert chunk count ≥ 2 and second chunk line_start > 1.

  local fix_repo="$tmp_root/fix-repo-multiwin"
  mkdir -p "$fix_repo"

  # Write a 90-line .txt file; window size=40 → expect 3 chunks (lines 1-40, 41-80, 81-90).
  local i
  for i in $(seq 1 90); do
    printf 'line%d content for window test\n' "$i"
  done > "$fix_repo/large.txt"

  local out err status=0
  out="$tmp_root/mwin-idx.out"; err="$tmp_root/mwin-idx.err"
    "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "index failed: $(<"$err")"; return 0
  fi

  local db chunk_count
  db="$(grep '^db: ' "$out" | sed 's/^db: //')"
  chunk_count="$(sqlite3 "$db" \
    "SELECT COUNT(*) FROM file_chunks fc JOIN files f ON fc.file_id=f.id
     WHERE f.path='large.txt';" 2>/dev/null || printf '0')"

  if [[ "$chunk_count" -ge 2 ]]; then
    # Also verify that the second window's line_start is > 1
    local second_start
    second_start="$(sqlite3 "$db" \
      "SELECT line_start FROM file_chunks fc JOIN files f ON fc.file_id=f.id
       WHERE f.path='large.txt' ORDER BY line_start LIMIT 1 OFFSET 1;" 2>/dev/null || printf '0')"
    if [[ "$second_start" -gt 1 ]]; then
      pass "$name"
    else
      fail "$name" "second chunk line_start=$second_start, expected > 1 (chunk_count=$chunk_count)"
    fi
  else
    fail "$name" "expected ≥ 2 chunks for 90-line .txt, got $chunk_count"
  fi
}

case_context_index_gitignore_new() {
  local name="pmctl context index: patches .gitignore that has no .pm-dispatch entry"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-gi-new"
  make_fixture_repo "$fix_repo"
  printf '*.log\n' > "$fix_repo/.gitignore"

  "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 \
    || { fail "$name" "context index failed"; return 0; }

  if grep -qxF '.pm-dispatch' "$fix_repo/.gitignore" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" ".pm-dispatch not added to .gitignore; contents: $(<"$fix_repo/.gitignore")"
  fi
}

case_context_index_gitignore_idempotent_exact() {
  local name="pmctl context index: no duplicate when .gitignore already has .pm-dispatch (exact)"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-gi-exact"
  make_fixture_repo "$fix_repo"
  printf '*.log\n.pm-dispatch\n' > "$fix_repo/.gitignore"

  "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 \
    || { fail "$name" "context index failed"; return 0; }

  local count
  count="$(grep -cxF '.pm-dispatch' "$fix_repo/.gitignore" 2>/dev/null || printf '0')"
  if [[ "$count" -eq 1 ]]; then pass "$name"
  else fail "$name" "expected 1 .pm-dispatch line, got $count"; fi
}

case_context_index_gitignore_idempotent_slash() {
  local name="pmctl context index: no duplicate when .gitignore already has .pm-dispatch/ (slash form)"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-gi-slash"
  make_fixture_repo "$fix_repo"
  printf '*.log\n.pm-dispatch/\n' > "$fix_repo/.gitignore"

  "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 \
    || { fail "$name" "context index failed"; return 0; }

  local line_count
  line_count="$(grep -cE '^\.pm-dispatch' "$fix_repo/.gitignore" 2>/dev/null || printf '0')"
  if [[ "$line_count" -eq 1 ]]; then pass "$name"
  else fail "$name" "expected 1 .pm-dispatch* line total, got $line_count; contents: $(<"$fix_repo/.gitignore")"; fi
}

case_context_index_gitignore_absent() {
  local name="pmctl context index: creates .gitignore with .pm-dispatch when none exists"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-gi-absent"
  make_fixture_repo "$fix_repo"
  rm -f "$fix_repo/.gitignore"

  "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 \
    || { fail "$name" "context index failed"; return 0; }

  if [[ -f "$fix_repo/.gitignore" ]] && grep -qxF '.pm-dispatch' "$fix_repo/.gitignore" 2>/dev/null; then
    pass "$name"
  else
    local gi_exists; gi_exists=$(test -f "$fix_repo/.gitignore" && printf 'yes' || printf 'no')
    fail "$name" ".gitignore exists=$gi_exists; expected to contain .pm-dispatch"
  fi
}

case_context_db_path_repo_local() {
  local name="pmctl context index: DB is repo-local and ignores PM_DISPATCH_STATE_ROOT"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-dbpath"
  make_fixture_repo "$fix_repo"
  local alt_state="$tmp_root/alt-state-root"
  mkdir -p "$alt_state"

  # Index with a non-default STATE_ROOT exported. Contract: the context DB is a
  # per-repo derived cache, so it must still land repo-local and nothing
  # context.db-shaped may appear under the state root.
  PM_DISPATCH_STATE_ROOT="$alt_state" "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 \
    || { fail "$name" "context index failed"; return 0; }

  if [[ ! -f "$fix_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "expected repo-local DB at .pm-dispatch/ctx/context.db (not found)"; return 0
  fi
  if find "$alt_state" -name 'context.db' 2>/dev/null | grep -q .; then
    fail "$name" "context.db leaked into PM_DISPATCH_STATE_ROOT ($alt_state); DB must be repo-local"; return 0
  fi
  pass "$name"
}

case_context_index_gitignore_symlink() {
  local name="pmctl context index: does not write through a symlinked .gitignore"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-gi-symlink"
  make_fixture_repo "$fix_repo"
  local target="$tmp_root/gi-symlink-target"
  printf 'ORIGINAL\n' > "$target"
  ln -sf "$target" "$fix_repo/.gitignore"

  local status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/gi-symlink.err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "context index exited $status: $(<"$tmp_root/gi-symlink.err")"; return 0
  fi

  # The symlink target must be untouched — no write-through into an out-of-tree file.
  if grep -q '.pm-dispatch' "$target" 2>/dev/null; then
    fail "$name" "index wrote .pm-dispatch through the symlink into $target"; return 0
  fi
  if ! grep -q 'not a regular file' "$tmp_root/gi-symlink.err" 2>/dev/null; then
    fail "$name" "expected 'not a regular file' skip warning; stderr: $(<"$tmp_root/gi-symlink.err")"; return 0
  fi
  pass "$name"
}

case_context_index_gitignore_hardlink() {
  local name="pmctl context index: does not write through a hardlinked .gitignore"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-gi-hardlink"
  make_fixture_repo "$fix_repo"
  local target="$tmp_root/gi-hardlink-target"
  printf 'ORIGINAL\n' > "$target"
  # A hardlink shares the inode with $target; writing through .gitignore would
  # append into the out-of-tree file. Skip if the platform/FS can't hardlink.
  if ! ln "$target" "$fix_repo/.gitignore" 2>/dev/null; then
    pass "$name (skipped: hardlink unsupported here)"; return 0
  fi

  local status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/gi-hardlink.err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "context index exited $status: $(<"$tmp_root/gi-hardlink.err")"; return 0
  fi

  # The shared-inode target must be untouched.
  if grep -q '.pm-dispatch' "$target" 2>/dev/null; then
    fail "$name" "index wrote .pm-dispatch through the hardlink into $target"; return 0
  fi
  if ! grep -q 'hardlinked' "$tmp_root/gi-hardlink.err" 2>/dev/null; then
    fail "$name" "expected 'hardlinked' skip warning; stderr: $(<"$tmp_root/gi-hardlink.err")"; return 0
  fi
  pass "$name"
}

case_context_index_gitignore_preexisting_dir() {
  local name="pmctl context index: patches .gitignore even when .pm-dispatch/ctx already exists"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-gi-preexist"
  make_fixture_repo "$fix_repo"
  # Pre-existing cache dir + a .gitignore that lacks the entry — the previous
  # first-creation-only guard would leave the DB unignored.
  mkdir -p "$fix_repo/.pm-dispatch/ctx"
  printf '*.log\n' > "$fix_repo/.gitignore"

  "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 \
    || { fail "$name" "context index failed"; return 0; }

  if grep -qxF '.pm-dispatch' "$fix_repo/.gitignore" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" ".pm-dispatch not added despite pre-existing cache dir; contents: $(<"$fix_repo/.gitignore")"
  fi
}

case_context_emit_event_failure_observable() {
  local name="_ctx_emit_usage_event: surfaces an observable warning when the event cannot be recorded"
  should_run "$name" || return 0

  local out err status=0
  out="$tmp_root/emit-warn.out"; err="$tmp_root/emit-warn.err"
  # Stub events_append to fail. Emit must stay best-effort (return 0, no stdout)
  # yet surface a "telemetry not recorded" warning on stderr — the observability
  # contract that turns a silent event drop into a diagnosable one.
  HOME="$tmp_root" bash -c '
    . "'"$SCRIPT_DIR"'/lib/pmctl-context.sh" 2>/dev/null
    events_append() { printf "boom\n" >&2; return 7; }
    state_store_init() { return 0; }
    _ctx_emit_usage_event "context.queried" "ignored" "alpha" 3
    printf "rc=%s\n" "$?"
  ' > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "harness exited $status: $(<"$err")"; return 0
  fi
  if ! grep -q 'rc=0' "$out" 2>/dev/null; then
    fail "$name" "emit must return 0 (best-effort); stdout: $(<"$out")"; return 0
  fi
  if ! grep -q 'context.queried telemetry not recorded' "$err" 2>/dev/null; then
    fail "$name" "expected observable warning on stderr; got: $(<"$err")"; return 0
  fi
  pass "$name"
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
case_context_index_markdown_no_symbols
case_context_query_missing_query
case_context_query_unknown_flag
case_context_query_domain_invalid
case_context_query_domain_knowledge_only
case_context_query_domain_repo_only
case_context_query_domain_no_flag_backward_compat
case_context_query_known_symbol
case_context_query_unknown_term_exits_0
case_context_query_like_fallback
case_context_query_file_chunks_text_path
case_context_query_fts5_path
case_context_index_deleted_file_reconciled
case_context_query_fts_multiline_no_bogus_refs
case_context_query_on_real_repo
case_context_layer_boundary
case_context_index_markdown_heading_chunks
case_context_chunk_markdown_no_code_fence_headings
case_context_index_txt_indexed
case_context_chunk_window_multiwindow
case_context_classify_domain
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
case_context_query_no_db
case_context_reuse_scan_no_db_emits
case_context_reuse_scan_unknown_flag
case_context_reuse_scan_valid_output
case_context_reuse_scan_no_terms
case_context_reuse_scan_dedup
case_context_reuse_scan_on_real_repo
case_context_reuse_scan_hit_cap
case_context_query_emits_event
case_context_reuse_scan_emits_event
case_context_index_gitignore_new
case_context_index_gitignore_idempotent_exact
case_context_index_gitignore_idempotent_slash
case_context_index_gitignore_absent
case_context_db_path_repo_local
case_context_index_gitignore_symlink
case_context_index_gitignore_hardlink
case_context_index_gitignore_preexisting_dir
case_context_emit_event_failure_observable

th_summary
