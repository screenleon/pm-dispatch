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

# Snapshot the developer's live repo context DB up-front so a dedicated guard
# case can prove the suite never indexes/queries/scans the real repo root (which
# would write or rebuild this DB and, under parallel runs, cause sqlite-busy /
# FTS-rebuild flakiness). Every context case must operate on an isolated fixture
# under $tmp_root, never $REPO_ROOT.
LIVE_DB="$REPO_ROOT/.pm-dispatch/ctx/context.db"
_live_db_fingerprint() {
  if [[ -e "$LIVE_DB" ]]; then
    stat -c '%Y:%s' "$LIVE_DB" 2>/dev/null || stat -f '%m:%z' "$LIVE_DB"
  else
    printf 'ABSENT\n'
  fi
}
LIVE_DB_BASELINE="$(_live_db_fingerprint)"

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

# ── Memory-plane fixtures (CC-403) ─────────────────────────────────────────────
# Stand up a fake project-memory directory that find_memory_dir resolves for
# <repo> when CLAUDE_CONFIG_DIR points at <cfg>. Echoes the memory dir path.
# Mirrors scripts/lib/memory.sh encode_path: "/a/b" → "-a-b".
mem_encode_path() {
  printf '%s' "-${1#/}" | tr '/' '-'
}

make_fixture_memory() {
  local repo="$1" cfg="$2"
  local mdir
  mdir="$cfg/projects/$(mem_encode_path "$repo")/memory"
  mkdir -p "$mdir"

  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [gate executor codex](feedback_gate_executor.md) — pr-gate prefers codex executor
MD

  cat > "$mdir/feedback_gate_executor.md" <<'MD'
---
name: gate-executor-codex
---
The pr-gate flow should prefer the codex executor for separation.
zebraword appears only in this curated card body.
MD

  printf '{"ts":"2026-06-22","summary":"worked on quokkatask parallelism"}\n' > "$mdir/episodes.jsonl"
  printf '%s' "$mdir"
}

# ── Test cases ─────────────────────────────────────────────────────────────────

case_context_index_missing_repo() {
  local name="pmctl context index: exits 2 when repo root is missing"
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/idx-mr.out"; err="$tmp_root/idx-mr.err"
  # CLI always sets REPO_ROOT; test the function directly with REPO_ROOT unset.
  # Must also run from a CWD outside any git worktree — otherwise the
  # git-toplevel default would resolve to this repo's own toplevel and this
  # case would start indexing the LIVE repo DB (see LIVE_DB_BASELINE guard).
  local nogit_dir="$tmp_root/idx-mr-nogit"
  mkdir -p "$nogit_dir"
  ( cd "$nogit_dir" && env -u REPO_ROOT bash -c \
      ". \"$SCRIPT_DIR/lib/pmctl-context.sh\" 2>/dev/null; pmctl_context_index" \
      > "$out" 2> "$err" ) || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_index_unknown_flag() {
  local name="pmctl context index: exits 2 for unknown flag"
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/idx-uf.out"; err="$tmp_root/idx-uf.err"
  # Use an isolated (existing) fixture dir as the index target so the case never
  # names $REPO_ROOT. The dir must EXIST: pmctl_context_index only consumes the
  # positional repo arg when it is a directory, otherwise it falls back to
  # $REPO_ROOT — which would index the live repo before the unknown flag is seen.
  local uf_repo="$tmp_root/idx-uf-repo"
  mkdir -p "$uf_repo"
    "$PMCTL" context index "$uf_repo" --frobnicate > "$out" 2> "$err" || status=$?
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
  local name="pmctl context query: pmctl_validate_brief found in isolated fixture of real lib file"
  # Behavior: a real lib file's symbol is findable via context query. Seed an
  # isolated fixture with an actual copy of the lib file and index THAT — never
  # $REPO_ROOT, whose DB the suite must not write.
  should_run "$name" || return 0

  local src="$REPO_ROOT/scripts/lib/pmctl-validate.sh"
  if [[ ! -f "$src" ]]; then
    fail "$name" "scripts/lib/pmctl-validate.sh not found in repo"; return 0
  fi

  local fix="$tmp_root/fix-real-query"
  mkdir -p "$fix/scripts/lib"
  cp "$src" "$fix/scripts/lib/pmctl-validate.sh"

  local out err status=0
  out="$tmp_root/q-real-idx.out"; err="$tmp_root/q-real-idx.err"
    "$PMCTL" context index "$fix" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "fixture index failed: $(<"$err")"; return 0
  fi

  status=0
  out="$tmp_root/q-real.out"; err="$tmp_root/q-real.err"
    "$PMCTL" context query "$fix" "pmctl_validate_brief" > "$out" 2> "$err" || status=$?

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
  # Behavior: with autobuild disabled, missing DB must still return graceful empty
  # JSON (schema_version 2, empty files/symbols arrays) rather than exiting 1.
  # Steps: call pack on a repo with no prior index run and autobuild disabled; assert exit 0 and valid empty JSON.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pack-nodb.out"; err="$tmp_root/pack-nodb.err"
  local nodb_repo="$tmp_root/nodb-repo-pack"
  mkdir -p "$nodb_repo"
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 \
    "$PMCTL" context pack "$nodb_repo" --task-id TASK-1 --query foo \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if ! jq -e '.schema_version == 2 and (.files | length) == 0 and (.symbols | length) == 0' \
      "$out" > /dev/null 2>&1; then
    fail "$name" "expected empty schema_version-2 JSON; got: $(<"$out")"; return 0
  fi
  if [[ -e "$nodb_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "autobuild disabled but context.db was created"; return 0
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
  # Behavior: with autobuild disabled, missing DB must still return graceful empty
  # YAML (reuse_candidates: header, hits: []) rather than exiting 1.
  # Steps: call reuse-scan on a repo with no prior index run and autobuild disabled; assert exit 0 and empty hits.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/scan-nodb.out"; err="$tmp_root/scan-nodb.err"
  local nodb_repo="$tmp_root/nodb-repo-scan"
  mkdir -p "$nodb_repo"
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 \
    "$PMCTL" context reuse-scan "$nodb_repo" "some description" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if [[ -e "$nodb_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "autobuild disabled but context.db was created"; return 0
  fi
  if grep -q '^reuse_candidates:' "$out" && grep -q 'hits: \[\]' "$out"; then
    pass "$name"
  else
    fail "$name" "expected reuse_candidates: header and hits: []; got: $(<"$out")"
  fi
}

case_context_query_no_db() {
  local name="pmctl context query: exits 0 with no-hits + zero-hit event when index DB not found"
  # Behavior: with autobuild disabled, a missing index must return exit 0 with
  # '# no hits', and still emit a zero-hit context.queried event.
  should_run "$name" || return 0

  local nodb_repo="$tmp_root/nodb-repo-query"
  mkdir -p "$nodb_repo"
  local state_root="$tmp_root/state-query-nodb"; mkdir -p "$state_root"

  local out err status=0
  out="$tmp_root/query-nodb.out"; err="$tmp_root/query-nodb.err"
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" context query "$nodb_repo" "alpha" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if [[ -e "$nodb_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "autobuild disabled but context.db was created"; return 0
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

case_context_query_no_db_sqlite_missing() {
  local name="pmctl context query: missing sqlite keeps no-db graceful fallback"
  should_run "$name" || return 0

  local nodb_repo="$tmp_root/nodb-repo-query-nosqlite"
  mkdir -p "$nodb_repo"

  local out err status=0
  out="$tmp_root/query-nodb-nosqlite.out"; err="$tmp_root/query-nodb-nosqlite.err"
  bash -c '
    set -euo pipefail
    # shellcheck source=scripts/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_sqlite3_check() { return 1; }
    _ctx_emit_usage_event() { :; }
    pmctl_context_query "$2" "alpha"
  ' bash "$SCRIPT_DIR" "$nodb_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if [[ -e "$nodb_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "sqlite unavailable but context.db was created"; return 0
  fi
  if ! grep -q '# no hits' "$out"; then
    fail "$name" "expected '# no hits' output; got: $(<"$out")"; return 0
  fi
  if grep -q 'sqlite3 not found' "$err" 2>/dev/null; then
    fail "$name" "missing DB path should not emit sqlite error; stderr: $(<"$err")"; return 0
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
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" context reuse-scan "$nodb_repo" "alpha beta function" \
    > /dev/null 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if [[ -e "$nodb_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "autobuild disabled but context.db was created"; return 0
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

case_context_query_autobuilds_missing_db() {
  local name="pmctl context query: auto-builds missing index DB"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-query-autobuild"
  make_fixture_repo "$fix_repo"

  local out err status=0
  out="$tmp_root/query-autobuild.out"; err="$tmp_root/query-autobuild.err"
  "$PMCTL" context query "$fix_repo" "my_func_alpha" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi
  if [[ ! -f "$fix_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "expected auto-built context.db"; return 0
  fi
  if ! grep -q 'context: no index found' "$err" || ! grep -q 'building' "$err"; then
    fail "$name" "expected auto-build notice on stderr; got: $(<"$err")"; return 0
  fi
  if grep -q '^context index:' "$out"; then
    fail "$name" "index summary leaked to query stdout: $(<"$out")"; return 0
  fi
  if ! grep -q 'mymodule.sh' "$out"; then
    fail "$name" "expected query hit after auto-build; got: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_pack_autobuilds_missing_db() {
  local name="pmctl context pack: auto-builds missing index DB"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-autobuild"
  make_fixture_repo "$fix_repo"

  local out err status=0
  out="$tmp_root/pack-autobuild.out"; err="$tmp_root/pack-autobuild.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-AUTO --query my_func_alpha \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  if [[ ! -f "$fix_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "expected auto-built context.db"; return 0
  fi
  if ! grep -q 'context: no index found' "$err"; then
    fail "$name" "expected auto-build notice on stderr; got: $(<"$err")"; return 0
  fi
  if ! jq -e '((.symbols | length) + (.files | length)) >= 1' "$out" > /dev/null 2>&1; then
    fail "$name" "expected pack hits after auto-build; got: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_query_autorefresh_existing_db() {
  local name="pmctl context query: refreshes existing index before search"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-query-refresh"
  make_fixture_repo "$fix_repo"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/query-refresh-index.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/query-refresh-index.err")"; return 0; }

  printf '\nautorefresh_query_sentinel_365\n' >> "$fix_repo/notes.txt"
  # Deterministic mtime bump: a fixed future timestamp beats sleeping across a
  # filesystem timestamp-granularity boundary.
  touch -m -t 210001010000 "$fix_repo/notes.txt"

  local out err status=0
  out="$tmp_root/query-refresh.out"; err="$tmp_root/query-refresh.err"
  "$PMCTL" context query "$fix_repo" "autorefresh_query_sentinel_365" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi
  if grep -q '^context index:' "$out"; then
    fail "$name" "index summary leaked to query stdout: $(<"$out")"; return 0
  fi
  if ! grep -q 'notes.txt' "$out"; then
    fail "$name" "expected refreshed query hit; got: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_query_autorefresh_opt_out() {
  local name="pmctl context query: auto-refresh can be disabled"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-query-refresh-off"
  make_fixture_repo "$fix_repo"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/query-refresh-off-index.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/query-refresh-off-index.err")"; return 0; }

  printf '\nautorefresh_off_sentinel_365\n' >> "$fix_repo/notes.txt"
  touch -m -t 210001010000 "$fix_repo/notes.txt"

  local out err status=0
  out="$tmp_root/query-refresh-off.out"; err="$tmp_root/query-refresh-off.err"
  PM_DISPATCH_CONTEXT_AUTOREFRESH=0 \
    "$PMCTL" context query "$fix_repo" "autorefresh_off_sentinel_365" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi
  if ! grep -q '# no hits' "$out"; then
    fail "$name" "expected stale no-hit output with auto-refresh disabled; got: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_reuse_scan_autorefresh_existing_db() {
  local name="pmctl context reuse-scan: refreshes existing index before scan"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-scan-refresh"
  make_fixture_repo "$fix_repo"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/scan-refresh-index.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/scan-refresh-index.err")"; return 0; }

  printf '\nautorefresh_reuse_sentinel_365\n' >> "$fix_repo/notes.txt"
  touch -m -t 210001010000 "$fix_repo/notes.txt"

  local out err status=0
  out="$tmp_root/scan-refresh.out"; err="$tmp_root/scan-refresh.err"
  "$PMCTL" context reuse-scan "$fix_repo" "autorefresh_reuse_sentinel_365" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi
  if grep -q '^context index:' "$out"; then
    fail "$name" "index summary leaked to reuse-scan stdout: $(<"$out")"; return 0
  fi
  if ! grep -q 'notes.txt' "$out"; then
    fail "$name" "expected refreshed reuse-scan hit; got: $(<"$out")"; return 0
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
  local name="pmctl context reuse-scan: finds pmctl-context.sh ref in isolated fixture of real lib file"
  # Behavior: a real lib file is findable via reuse-scan. Seed an isolated fixture
  # with an actual copy of the lib file and scan THAT — never $REPO_ROOT, whose DB
  # the suite must not write.
  # Steps: copy the real lib file into a $tmp_root fixture; index the fixture;
  # run reuse-scan with context-domain terms; assert pmctl-context.sh appears.
  should_run "$name" || return 0

  local src="$REPO_ROOT/scripts/lib/pmctl-context.sh"
  if [[ ! -f "$src" ]]; then
    fail "$name" "scripts/lib/pmctl-context.sh not found in repo"; return 0
  fi

  local fix="$tmp_root/fix-real-scan"
  mkdir -p "$fix/scripts/lib"
  cp "$src" "$fix/scripts/lib/pmctl-context.sh"

  local out err status=0
    "$PMCTL" context index "$fix" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/scan-real.out"; err="$tmp_root/scan-real.err"
    "$PMCTL" context reuse-scan "$fix" "emit context hit yaml" \
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

case_context_no_live_db_mutation() {
  local name="pmctl context suite: never creates or mutates the live repo context DB"
  # Regression guard: the suite must operate only on isolated $tmp_root fixtures.
  # Compares the live repo DB fingerprint against the baseline captured before any
  # case ran; any change means a case indexed/queried/scanned $REPO_ROOT directly.
  should_run "$name" || return 0

  local now
  now="$(_live_db_fingerprint)"
  if [[ "$now" == "$LIVE_DB_BASELINE" ]]; then
    pass "$name"
  else
    fail "$name" "live repo DB changed during suite (a case operated on \$REPO_ROOT): baseline=$LIVE_DB_BASELINE now=$now"
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

# ── Memory-plane cases (CC-403) ────────────────────────────────────────────────

case_context_query_source_memory_finds_card() {
  local name="pmctl context query --source memory: finds memory card with source_domain memory"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-find-repo" cfg="$tmp_root/mem-find-cfg"
  mkdir -p "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  local out err status=0
  out="$tmp_root/mem-find.out"; err="$tmp_root/mem-find.err"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory codex > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "query exited $status: $(<"$err")"; return 0; fi
  if grep -q 'ref: feedback_gate_executor.md' "$out" && grep -q 'source_domain: memory' "$out"; then
    pass "$name"
  else
    fail "$name" "expected memory card hit with source_domain: memory; got: $(<"$out")"
  fi
}

case_context_query_source_memory_trust_tiers() {
  local name="pmctl context query --source memory: card trust=high, episode trust=medium"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-trust-repo" cfg="$tmp_root/mem-trust-cfg"
  mkdir -p "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  local card_out epi_out
  card_out="$tmp_root/mem-trust-card.out"; epi_out="$tmp_root/mem-trust-epi.out"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory codex > "$card_out" 2>/dev/null || true
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory quokkatask > "$epi_out" 2>/dev/null || true
  # The card hit block must carry trust_level: high; the episode hit must be medium.
  if grep -q 'ref: feedback_gate_executor.md' "$card_out" \
    && awk '/ref: feedback_gate_executor.md/{c=1} c&&/trust_level: high/{ok=1} END{exit !ok}' "$card_out" \
    && grep -q 'ref: episodes.jsonl' "$epi_out" \
    && awk '/ref: episodes.jsonl/{c=1} c&&/trust_level: medium/{ok=1} END{exit !ok}' "$epi_out"; then
    pass "$name"
  else
    fail "$name" "expected card=high / episode=medium; card=$(<"$card_out") epi=$(<"$epi_out")"
  fi
}

case_context_memory_db_out_of_repo() {
  local name="pmctl context query --source memory: memory DB lives under memory dir, never in repo checkout (privacy)"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-priv-repo" cfg="$tmp_root/mem-priv-cfg"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$repo" "$cfg")"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory codex >/dev/null 2>&1 || true
  if [[ ! -f "$mdir/.pm-dispatch/context.db" ]]; then
    fail "$name" "expected memory DB at $mdir/.pm-dispatch/context.db (not found)"; return 0
  fi
  if [[ -e "$repo/.pm-dispatch" ]]; then
    fail "$name" "memory query created repo-local .pm-dispatch — private memory must not land in the repo checkout"; return 0
  fi
  pass "$name"
}

case_context_query_source_all_merges() {
  local name="pmctl context query --source all: merges repo + memory hits"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-all-repo" cfg="$tmp_root/mem-all-cfg"
  make_fixture_repo "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  # Index repo so a repo hit exists; use a term present in both planes is hard,
  # so assert both a repo-domain and a memory-domain hit appear across two terms.
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context index "$repo" >/dev/null 2>&1 || true
  local out="$tmp_root/mem-all.out"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source all my_func_alpha > "$out" 2>/dev/null || true
  local out2="$tmp_root/mem-all2.out"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source all codex > "$out2" 2>/dev/null || true
  if grep -q 'source_domain: repo' "$out" && grep -q 'source_domain: memory' "$out2"; then
    pass "$name"
  else
    fail "$name" "expected repo hit (out1) and memory hit (out2); out1=$(<"$out") out2=$(<"$out2")"
  fi
}

case_context_query_source_repo_excludes_memory() {
  local name="pmctl context query --source repo (default): never returns memory hits"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-repoonly-repo" cfg="$tmp_root/mem-repoonly-cfg"
  make_fixture_repo "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context index "$repo" >/dev/null 2>&1 || true
  local out="$tmp_root/mem-repoonly.out"
  # "codex" only exists in memory; default repo source must miss it.
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" codex > "$out" 2>/dev/null || true
  if grep -q 'source_domain: memory' "$out"; then
    fail "$name" "default --source repo leaked memory hits: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_query_source_memory_no_dir_graceful() {
  local name="pmctl context query --source memory: missing memory dir degrades to # no hits"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-nodir-repo" cfg="$tmp_root/mem-nodir-cfg"
  mkdir -p "$repo" "$cfg/projects"   # cfg exists but no memory dir for this repo
  local out err status=0
  out="$tmp_root/mem-nodir.out"; err="$tmp_root/mem-nodir.err"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory codex > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "expected exit 0; got $status err=$(<"$err")"; return 0; fi
  if grep -q '# no hits' "$out"; then pass "$name"; else fail "$name" "expected '# no hits'; got: $(<"$out")"; fi
}

case_context_query_source_memory_config_override() {
  local name="pmctl context query --source memory: dispatch.memory_dir config resolves memory dir"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-cfgover-repo" cfg="$tmp_root/mem-cfgover-cfg"
  local override="$tmp_root/mem-cfgover-override" fakehome="$tmp_root/mem-cfgover-home"
  mkdir -p "$repo" "$fakehome/.pm-dispatch"
  # $cfg deliberately has no memory dir for $repo. Populate ONLY the override
  # dir (not under $cfg/projects/<id>/memory) so a hit proves resolution went
  # through dispatch.memory_dir, not the CLAUDE_CONFIG_DIR walk.
  mkdir -p "$override"
  cat > "$override/MEMORY.md" <<'MD'
# Memory Index
- [gate executor codex](feedback_gate_executor.md) — pr-gate prefers codex executor
MD
  cat > "$override/feedback_gate_executor.md" <<'MD'
---
name: gate-executor-codex
---
The pr-gate flow should prefer the codex executor for separation.
MD
  printf 'dispatch.memory_dir = %s\n' "$override" > "$fakehome/.pm-dispatch/config"

  local out err status=0
  out="$tmp_root/mem-cfgover.out"; err="$tmp_root/mem-cfgover.err"
  HOME="$fakehome" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory codex > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "query exited $status: $(<"$err")"; return 0; fi
  if grep -q 'ref: feedback_gate_executor.md' "$out" && grep -q 'source_domain: memory' "$out"; then
    pass "$name"
  else
    fail "$name" "expected memory card hit resolved via dispatch.memory_dir; got: $(<"$out")"
  fi
}

case_context_query_source_memory_domain_rejected() {
  local name="pmctl context query: --domain with --source memory is rejected (exit 2)"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-domrej-repo"; mkdir -p "$repo"
  local err status=0
  err="$tmp_root/mem-domrej.err"
  "$PMCTL" context query "$repo" --source memory --domain knowledge codex >/dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] && grep -q 'only valid with --source repo' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + guidance; got $status err=$(<"$err")"
  fi
}

case_context_query_source_invalid_rejected() {
  local name="pmctl context query: invalid --source value is rejected (exit 2)"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-srcrej-repo"; mkdir -p "$repo"
  local err status=0
  err="$tmp_root/mem-srcrej.err"
  "$PMCTL" context query "$repo" --source bogus codex >/dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] && grep -q 'must be "repo", "memory", or "all"' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + guidance; got $status err=$(<"$err")"
  fi
}

case_context_index_source_memory_builds_db() {
  local name="pmctl context index --source memory: builds memory DB under memory dir"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-idx-repo" cfg="$tmp_root/mem-idx-cfg"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$repo" "$cfg")"
  local out err status=0
  out="$tmp_root/mem-idx.out"; err="$tmp_root/mem-idx.err"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context index "$repo" --source memory > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "index exited $status: $(<"$err")"; return 0; fi
  if [[ -f "$mdir/.pm-dispatch/context.db" ]] && grep -q "^db: $mdir/.pm-dispatch/context.db" "$out"; then
    pass "$name"
  else
    fail "$name" "expected memory DB + db: line; out=$(<"$out")"
  fi
}

case_context_index_source_invalid_rejected() {
  local name="pmctl context index: invalid --source value is rejected with repo|memory guidance"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-idxrej-repo"; mkdir -p "$repo"
  local err status=0
  err="$tmp_root/mem-idxrej.err"
  "$PMCTL" context index "$repo" --source bogus >/dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] && grep -q 'expected repo|memory' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + 'expected repo|memory'; got $status err=$(<"$err")"
  fi
}

case_context_pack_source_memory_pointer_only() {
  local name="pmctl context pack --source memory: populates memories[] pointer-only (no card snippet leak)"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-pack-repo" cfg="$tmp_root/mem-pack-cfg"
  mkdir -p "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  local out err status=0
  out="$tmp_root/mem-pack.out"; err="$tmp_root/mem-pack.err"
  # "zebraword" appears ONLY in the card body — a pointer-only pack must reference
  # the card but must NOT copy the matched body text into the pack JSON.
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context pack "$repo" --task-id CC-403 --query zebraword --source memory > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "pack exited $status: $(<"$err")"; return 0; fi
  if ! command -v jq >/dev/null 2>&1; then
    fail "$name" "jq required for this assertion"; return 0
  fi
  local mem_count leaked
  mem_count="$(jq '.memories | length' "$out" 2>/dev/null || printf 'ERR')"
  leaked="$(jq -r '.memories[].source_domain' "$out" 2>/dev/null | grep -vc '^memory$' || true)"
  if [[ "$mem_count" -ge 1 ]] \
    && jq -e '.memories[0].source_domain == "memory"' "$out" >/dev/null 2>&1 \
    && [[ "$leaked" == "0" ]] \
    && ! grep -q 'zebraword' "$out"; then
    pass "$name"
  else
    fail "$name" "expected pointer-only memories (count=$mem_count, no 'zebraword'); got: $(<"$out")"
  fi
}

case_context_pack_source_repo_memories_empty() {
  local name="pmctl context pack --source repo (default): memories[] stays empty (byte-compatible)"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-packrepo-repo" cfg="$tmp_root/mem-packrepo-cfg"
  make_fixture_repo "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  local out="$tmp_root/mem-packrepo.out"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context pack "$repo" --task-id CC-403 --query codex > "$out" 2>/dev/null || true
  if command -v jq >/dev/null 2>&1; then
    if jq -e '.memories == []' "$out" >/dev/null 2>&1; then pass "$name"; else fail "$name" "expected memories []; got: $(<"$out")"; fi
  else
    if grep -q '"memories":\[\]' "$out"; then pass "$name"; else fail "$name" "expected empty memories; got: $(<"$out")"; fi
  fi
}

case_context_pack_source_all_populates_both() {
  local name="pmctl context pack --source all: files/symbols from repo AND memories from memory"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-packall-repo" cfg="$tmp_root/mem-packall-cfg"
  make_fixture_repo "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context index "$repo" >/dev/null 2>&1 || true
  local out="$tmp_root/mem-packall.out"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context pack "$repo" --task-id CC-403 --query my_func_alpha --query codex --source all > "$out" 2>/dev/null || true
  if command -v jq >/dev/null 2>&1; then
    if jq -e '(.symbols | length) >= 1 and (.memories | length) >= 1' "$out" >/dev/null 2>&1; then
      pass "$name"
    else
      fail "$name" "expected both symbols and memories populated; got: $(<"$out")"
    fi
  else
    pass "$name (skipped: jq absent)"
  fi
}

case_context_pack_source_invalid_rejected() {
  local name="pmctl context pack: invalid --source value is rejected (exit 2)"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-packrej-repo"; mkdir -p "$repo"
  local err status=0
  err="$tmp_root/mem-packrej.err"
  "$PMCTL" context pack "$repo" --task-id CC-403 --query codex --source bogus >/dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] && grep -q 'must be "repo", "memory", or "all"' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + guidance; got $status err=$(<"$err")"
  fi
}

case_context_reuse_scan_never_returns_memory() {
  local name="pmctl context reuse-scan: repo-only by construction — never surfaces memory hits (regression lock)"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-reuse-repo" cfg="$tmp_root/mem-reuse-cfg"
  make_fixture_repo "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context index "$repo" >/dev/null 2>&1 || true
  local out="$tmp_root/mem-reuse.out"
  # Description uses memory-only terms; reuse-scan echoes them in its terms: line
  # (expected), but must never reach the memory plane — so assert on leak markers
  # that only appear in actual HITS: a memory source_domain or a memory file ref.
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context reuse-scan "$repo" "codex executor preference gate" > "$out" 2>/dev/null || true
  if grep -qE 'source_domain: memory|ref: feedback_gate_executor|ref: episodes.jsonl|ref: MEMORY.md' "$out"; then
    fail "$name" "reuse-scan leaked memory-plane content: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_index_source_missing_value() {
  local name="pmctl context index: --source with no value is rejected (exit 2)"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-idx-noval-repo"; mkdir -p "$repo"
  local err status=0
  err="$tmp_root/mem-idx-noval.err"
  # Bare trailing --source (no value) must guard like query/pack, not silently
  # default to an empty source flag.
  "$PMCTL" context index "$repo" --source >/dev/null 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] && grep -q -- '--source requires a value' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + 'requires a value'; got $status err=$(<"$err")"
  fi
}

case_context_memory_source_attribution() {
  local name="pmctl context: memory hits attribute source=memory-index (query + pack sources[])"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-attr-repo" cfg="$tmp_root/mem-attr-cfg"
  mkdir -p "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  # Query: memory hit YAML carries `source: memory-index`.
  local q="$tmp_root/mem-attr-q.out"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory codex > "$q" 2>/dev/null || true
  # Pack: memory item source == memory-index AND sources[] registers it.
  local p="$tmp_root/mem-attr-p.out"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context pack "$repo" --task-id CC-403 --query codex --source memory > "$p" 2>/dev/null || true
  if ! command -v jq >/dev/null 2>&1; then
    fail "$name" "jq required for this assertion"; return 0
  fi
  if grep -q 'source: memory-index' "$q" \
    && ! grep -q 'source: builtin-index' "$q" \
    && jq -e '.memories[0].source == "memory-index"' "$p" >/dev/null 2>&1 \
    && jq -e 'any(.sources[]; .name == "memory-index")' "$p" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "expected memory-index attribution in query+pack; q=$(<"$q") p=$(<"$p")"
  fi
}

case_context_pack_repo_sources_no_memory_index() {
  local name="pmctl context pack --source repo: sources[] does NOT register memory-index"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-attr-repo2" cfg="$tmp_root/mem-attr-cfg2"
  make_fixture_repo "$repo"
  make_fixture_memory "$repo" "$cfg" >/dev/null
  local p="$tmp_root/mem-attr-p2.out"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context pack "$repo" --task-id CC-403 --query my_func_alpha > "$p" 2>/dev/null || true
  if command -v jq >/dev/null 2>&1; then
    if jq -e 'all(.sources[]; .name != "memory-index")' "$p" >/dev/null 2>&1; then pass "$name"; else fail "$name" "repo pack leaked memory-index source: $(<"$p")"; fi
  else
    if ! grep -q 'memory-index' "$p"; then pass "$name"; else fail "$name" "repo pack leaked memory-index: $(<"$p")"; fi
  fi
}

# ── repo_root defaults to CWD git toplevel, not the pmctl install repo ────────

case_context_default_repo_root_uses_cwd_git_toplevel() {
  local name="pmctl context index: no-arg invocation from an external git repo indexes THAT repo, not pm-dispatch"
  should_run "$name" || return 0
  local ext_repo="$tmp_root/defroot-ext-repo"
  make_fixture_repo "$ext_repo"
  ( cd "$ext_repo" && git init -q && git add -A && git commit -q -m init )
  local out err status=0
  out="$tmp_root/defroot-idx.out"; err="$tmp_root/defroot-idx.err"
  ( cd "$ext_repo" && "$PMCTL" context index --source repo > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "index exited $status: $(<"$err")"; return 0; fi
  if [[ -f "$ext_repo/.pm-dispatch/ctx/context.db" ]]; then
    pass "$name"
  else
    fail "$name" "expected $ext_repo/.pm-dispatch/ctx/context.db to exist; index output: $(<"$out")"
  fi
}

case_context_default_repo_root_falls_back_to_repo_root_env() {
  local name="pmctl context index: no-arg invocation outside any git worktree falls back to REPO_ROOT with a stderr warning"
  should_run "$name" || return 0
  local nogit_dir="$tmp_root/defroot-nogit"
  local fallback_repo="$tmp_root/defroot-fallback-repo"
  mkdir -p "$nogit_dir"
  make_fixture_repo "$fallback_repo"
  local out err status=0
  out="$tmp_root/defroot-fb.out"; err="$tmp_root/defroot-fb.err"
  ( cd "$nogit_dir" && REPO_ROOT="$fallback_repo" bash -c \
      ". \"$SCRIPT_DIR/lib/pmctl-context.sh\" 2>/dev/null; pmctl_context_index --source repo" \
      > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "index exited $status: $(<"$err")"; return 0; fi
  if [[ -f "$fallback_repo/.pm-dispatch/ctx/context.db" ]] && grep -qi 'falling back to REPO_ROOT' "$err"; then
    pass "$name"
  else
    fail "$name" "expected fallback DB + stderr warning; db exists=$([[ -f "$fallback_repo/.pm-dispatch/ctx/context.db" ]] && echo yes || echo no) stderr=$(<"$err")"
  fi
}

case_context_default_repo_root_pm_dispatch_tree_unchanged() {
  local name="pmctl context index: when CWD git toplevel equals REPO_ROOT (running from within a checkout), resolution is a no-op change (self-consistent, matches legacy behavior) — verified on an isolated fixture, never the live repo"
  should_run "$name" || return 0
  # Simulate "running from inside a pm-dispatch-like checkout" without touching
  # the real live repo DB: a fixture that is its OWN git toplevel AND its own
  # REPO_ROOT, mirroring the case where the two values coincide.
  local self_repo="$tmp_root/defroot-self-repo"
  make_fixture_repo "$self_repo"
  ( cd "$self_repo" && git init -q && git add -A && git commit -q -m init )
  local out err status=0
  out="$tmp_root/defroot-self.out"; err="$tmp_root/defroot-self.err"
  ( cd "$self_repo" && REPO_ROOT="$self_repo" bash -c \
      ". \"$SCRIPT_DIR/lib/pmctl-context.sh\" 2>/dev/null; pmctl_context_index --source repo" \
      > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -eq 0 ]] && [[ -f "$self_repo/.pm-dispatch/ctx/context.db" ]] && ! grep -qi 'falling back' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 0, DB created, no fallback warning; status=$status stderr=$(<"$err")"
  fi
}

case_context_no_arg_cross_repo_never_touches_pm_dispatch_db() {
  local name="pmctl context index/query: no-arg invocation from an external repo never creates or mutates pm-dispatch's own context.db"
  should_run "$name" || return 0
  local ext_repo="$tmp_root/defroot-cross-repo"
  make_fixture_repo "$ext_repo"
  ( cd "$ext_repo" && git init -q && git add -A && git commit -q -m init )
  local before after
  before="$(_live_db_fingerprint)"
  ( cd "$ext_repo" && "$PMCTL" context index --source repo > /dev/null 2>&1 )
  ( cd "$ext_repo" && "$PMCTL" context query --source repo my_func_alpha > /dev/null 2>&1 )
  after="$(_live_db_fingerprint)"
  if [[ "$before" == "$after" ]]; then
    pass "$name"
  else
    fail "$name" "pm-dispatch's own context.db changed after cross-repo no-arg calls: before=$before after=$after"
  fi
}

case_context_default_repo_root_update_uses_cwd() {
  local name="pmctl context update: no-arg invocation from an external git repo re-scans THAT repo, not pm-dispatch"
  should_run "$name" || return 0
  local ext_repo="$tmp_root/defroot-update-repo"
  make_fixture_repo "$ext_repo"
  ( cd "$ext_repo" && git init -q && git add -A && git commit -q -m init )
  ( cd "$ext_repo" && "$PMCTL" context index --source repo > /dev/null 2>&1 )
  local out err status=0
  out="$tmp_root/defroot-update.out"; err="$tmp_root/defroot-update.err"
  ( cd "$ext_repo" && "$PMCTL" context update > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -eq 0 ]] && [[ -f "$ext_repo/.pm-dispatch/ctx/context.db" ]]; then
    pass "$name"
  else
    fail "$name" "update exited $status; db exists=$([[ -f "$ext_repo/.pm-dispatch/ctx/context.db" ]] && echo yes || echo no) stderr=$(<"$err")"
  fi
}

case_context_default_repo_root_pack_uses_cwd() {
  local name="pmctl context pack: no-arg (no positional repo) invocation from an external git repo packs THAT repo"
  should_run "$name" || return 0
  local ext_repo="$tmp_root/defroot-pack-repo"
  make_fixture_repo "$ext_repo"
  ( cd "$ext_repo" && git init -q && git add -A && git commit -q -m init )
  local out err status=0
  out="$tmp_root/defroot-pack.out"; err="$tmp_root/defroot-pack.err"
  ( cd "$ext_repo" && "$PMCTL" context pack --task-id T-DEFROOT --query my_func_alpha > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -eq 0 ]] && grep -q '"task_id":"T-DEFROOT"' "$out"; then
    pass "$name"
  else
    fail "$name" "pack exited $status: $(<"$out") stderr=$(<"$err")"
  fi
}

case_context_default_repo_root_reuse_scan_uses_cwd() {
  local name="pmctl context reuse-scan: no-arg (no positional repo) invocation from an external git repo scans THAT repo"
  should_run "$name" || return 0
  local ext_repo="$tmp_root/defroot-reuse-repo"
  make_fixture_repo "$ext_repo"
  ( cd "$ext_repo" && git init -q && git add -A && git commit -q -m init )
  local out err status=0
  out="$tmp_root/defroot-reuse.out"; err="$tmp_root/defroot-reuse.err"
  ( cd "$ext_repo" && "$PMCTL" context reuse-scan "reuse my_func_alpha helper" > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -eq 0 ]] && grep -q '^reuse_candidates:' "$out"; then
    pass "$name"
  else
    fail "$name" "reuse-scan exited $status: $(<"$out") stderr=$(<"$err")"
  fi
}

case_context_pack_explicit_repo_no_fallback_warning() {
  local name="pmctl context pack: explicit repo argument from a non-git CWD does NOT emit the fallback-to-REPO_ROOT warning"
  should_run "$name" || return 0
  local nogit_dir="$tmp_root/defroot-pack-nogit"
  local explicit_repo="$tmp_root/defroot-pack-explicit-repo"
  mkdir -p "$nogit_dir"
  make_fixture_repo "$explicit_repo"
  local out err status=0
  out="$tmp_root/defroot-pack-explicit.out"; err="$tmp_root/defroot-pack-explicit.err"
  ( cd "$nogit_dir" && "$PMCTL" context pack "$explicit_repo" --task-id T-EXPLICIT --query my_func_alpha \
      > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -eq 0 ]] && ! grep -qi 'falling back' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with no fallback warning; status=$status stderr=$(<"$err")"
  fi
}

case_context_reuse_scan_explicit_repo_no_fallback_warning() {
  local name="pmctl context reuse-scan: explicit repo argument from a non-git CWD does NOT emit the fallback-to-REPO_ROOT warning"
  should_run "$name" || return 0
  local nogit_dir="$tmp_root/defroot-reuse-nogit"
  local explicit_repo="$tmp_root/defroot-reuse-explicit-repo"
  mkdir -p "$nogit_dir"
  make_fixture_repo "$explicit_repo"
  local out err status=0
  out="$tmp_root/defroot-reuse-explicit.out"; err="$tmp_root/defroot-reuse-explicit.err"
  ( cd "$nogit_dir" && "$PMCTL" context reuse-scan "$explicit_repo" "reuse my_func_alpha helper" \
      > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -eq 0 ]] && ! grep -qi 'falling back' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with no fallback warning; status=$status stderr=$(<"$err")"
  fi
}

# ── prompt-scan cases ──────────────────────────────────────────────────────────

case_context_prompt_scan_missing_prompt() {
  local name="pmctl context prompt-scan: exits 2 when prompt text is missing"
  # Behavior: prompt-scan must exit 2 when no prompt argument is provided.
  # Steps: call prompt-scan with only a repo path and no prompt; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pscan-mp.out"; err="$tmp_root/pscan-mp.err"
  local noarg_repo="$tmp_root/noarg-repo-pscan"
  mkdir -p "$noarg_repo"
  "$PMCTL" context prompt-scan "$noarg_repo" > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_prompt_scan_unknown_flag() {
  local name="pmctl context prompt-scan: exits 2 on unknown flag"
  # Behavior: prompt-scan must reject unknown flags with exit 2.
  # Steps: call prompt-scan with --bogus; assert exit 2.
  should_run "$name" || return 0
  local out err status=0
  out="$tmp_root/pscan-uf.out"; err="$tmp_root/pscan-uf.err"
  local flag_repo="$tmp_root/flag-repo-pscan"
  mkdir -p "$flag_repo"
  "$PMCTL" context prompt-scan "$flag_repo" --bogus "some prompt" > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_prompt_scan_no_db() {
  local name="pmctl context prompt-scan: exits 0 with empty YAML + zero-hit event when index DB not found"
  # Behavior: with autobuild disabled, a missing index must return graceful empty
  # output (knowledge_hits: []) with exit 0, never create the DB, and still emit
  # a zero-hit context.prompt_scanned event.
  # Steps: run prompt-scan on a repo with no index and autobuild disabled; assert
  # exit 0, empty hits, no DB, and a hits=0 event in the isolated state root.
  should_run "$name" || return 0

  local nodb_repo="$tmp_root/nodb-repo-pscan"
  mkdir -p "$nodb_repo"
  local state_root="$tmp_root/state-pscan-nodb"; mkdir -p "$state_root"

  local out err status=0
  out="$tmp_root/pscan-nodb.out"; err="$tmp_root/pscan-nodb.err"
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" context prompt-scan "$nodb_repo" "how does the gate verdict work" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if [[ -e "$nodb_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "autobuild disabled but context.db was created"; return 0
  fi
  if ! grep -q '^knowledge_hits: \[\]' "$out"; then
    fail "$name" "expected 'knowledge_hits: []'; got: $(<"$out")"; return 0
  fi
  if grep -q 'telemetry not recorded' "$err" 2>/dev/null; then
    fail "$name" "no-db prompt-scan reported a telemetry emit failure: $(<"$err")"; return 0
  fi
  # Telemetry stores derived terms, never the raw prompt (privacy contract).
  local evt hits
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.prompt_scanned --all --json 2>/dev/null \
    | jq -c 'select(.payload.query | contains("verdict"))' 2>/dev/null | tail -1)"
  if [[ -z "$evt" ]]; then
    fail "$name" "expected a context.prompt_scanned event for the no-db scan"; return 0
  fi
  if [[ "$(printf '%s\n' "$evt" | jq -r '.payload.query')" == "how does the gate verdict work" ]]; then
    fail "$name" "event stored the raw prompt; must store derived terms only"; return 0
  fi
  hits="$(printf '%s\n' "$evt" | jq -r '.payload.hits' 2>/dev/null)"
  if [[ "$hits" != "0" ]]; then
    fail "$name" "expected payload.hits=0 for no-db prompt-scan; got: $hits"; return 0
  fi
  pass "$name"
}

case_context_prompt_scan_knowledge_domain_only() {
  local name="pmctl context prompt-scan: returns knowledge-domain hits only"
  # Behavior: prompt-scan is knowledge-domain by construction — a prompt whose
  # terms match both knowledge docs (BACKLOG.md) and repo code (mymodule.sh)
  # must return the knowledge refs and never the repo-plane code refs.
  # Steps: index fixture; scan with a prompt matching both planes; assert a
  # BACKLOG.md ref is present and no scripts/ ref appears.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pscan-domain"
  make_fixture_repo "$fix_repo"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/pscan-domain.out"; err="$tmp_root/pscan-domain.err"
  # "alpha" matches BACKLOG.md/docs (knowledge) AND my_func_alpha (repo code).
  "$PMCTL" context prompt-scan "$fix_repo" "tell me about alpha knowledge" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "prompt-scan exited $status: $(<"$err")"; return 0
  fi
  if ! grep -q '^knowledge_hits:' "$out"; then
    fail "$name" "expected knowledge_hits: header; got: $(<"$out")"; return 0
  fi
  if ! grep -qE '  - ref: (BACKLOG\.md|docs/)' "$out"; then
    fail "$name" "expected a knowledge-domain ref (BACKLOG.md or docs/); got: $(<"$out")"; return 0
  fi
  if grep -q 'mymodule.sh' "$out"; then
    fail "$name" "repo-plane code ref leaked into knowledge-only output: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_prompt_scan_dedup_and_hit_cap() {
  local name="pmctl context prompt-scan: refs are unique and capped at 5"
  # Behavior: overlapping terms must not produce duplicate refs, and output must
  # emit at most 5 refs regardless of how many knowledge chunks match.
  # Steps: index a fixture with many matching knowledge headings; scan with
  # overlapping terms; assert unique refs and count <= 5.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pscan-cap"
  mkdir -p "$fix_repo/docs"
  {
    printf '# Captest\n\n'
    for i in $(seq 1 10); do
      printf '## Heading %d\n\ncaptest knowledge body %d.\n\n' "$i" "$i"
    done
  } > "$fix_repo/docs/captest.md"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/pscan-cap.out"; err="$tmp_root/pscan-cap.err"
  "$PMCTL" context prompt-scan "$fix_repo" "captest knowledge captest" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "prompt-scan exited $status: $(<"$err")"; return 0
  fi
  local total_refs unique_refs
  total_refs="$(grep -c '^  - ref:' "$out" 2>/dev/null || printf '0')"
  unique_refs="$(grep '^  - ref:' "$out" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  if [[ "$total_refs" -ne "$unique_refs" ]]; then
    fail "$name" "duplicate refs: total=$total_refs unique=$unique_refs out=$(<"$out")"; return 0
  fi
  if [[ "$total_refs" -lt 1 || "$total_refs" -gt 5 ]]; then
    fail "$name" "expected 1..5 refs (cap), got $total_refs; output: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_prompt_scan_term_cap_longest_first() {
  local name="pmctl context prompt-scan: term cap keeps longest terms first"
  # Behavior: terms are ranked longest-first and capped at
  # PM_DISPATCH_PROMPT_SCAN_MAX_TERMS. With cap=1 and a prompt whose longest
  # term matches nothing, the shorter matching term must be dropped (no hits);
  # with the default cap the same prompt must find hits.
  # Steps: index fixture; scan with cap=1 (longest term is a no-match) → expect
  # empty; rescan with default cap → expect hits.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pscan-termcap"
  make_fixture_repo "$fix_repo"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  # "zzzzzzunmatchable" (17 chars) outranks "alpha" (5 chars) under cap=1.
  out="$tmp_root/pscan-termcap1.out"; err="$tmp_root/pscan-termcap1.err"
  PM_DISPATCH_PROMPT_SCAN_MAX_TERMS=1 \
    "$PMCTL" context prompt-scan "$fix_repo" "alpha zzzzzzunmatchable" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "prompt-scan (cap=1) exited $status: $(<"$err")"; return 0
  fi
  if ! grep -q '^knowledge_hits: \[\]' "$out"; then
    fail "$name" "cap=1 should query only the longest (no-match) term; got: $(<"$out")"; return 0
  fi

  status=0
  out="$tmp_root/pscan-termcap8.out"; err="$tmp_root/pscan-termcap8.err"
  "$PMCTL" context prompt-scan "$fix_repo" "alpha zzzzzzunmatchable" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "prompt-scan (default cap) exited $status: $(<"$err")"; return 0
  fi
  if grep -q '^knowledge_hits: \[\]' "$out"; then
    fail "$name" "default cap should reach the matching term 'alpha'; got: $(<"$out")"; return 0
  fi
  pass "$name"
}

case_context_prompt_scan_no_sqlite_graceful() {
  local name="pmctl context prompt-scan: missing sqlite degrades to empty scan + zero-hit event (DB present)"
  # Behavior: prompt-scan is driven by an automated prompt hook, so a missing
  # sqlite3 with an EXISTING index DB must degrade to 'knowledge_hits: []' with
  # exit 0 and a zero-hit derived-terms event — never a hard error.
  # Steps: index a fixture (real sqlite); re-run prompt-scan in a subshell whose
  # _ctx_sqlite3_check fails, capturing the emit args; assert graceful output,
  # exit 0, and a zero-hit event carrying derived terms (not the raw prompt).
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pscan-nosqlite"
  make_fixture_repo "$fix_repo"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }
  if [[ ! -f "$fix_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "setup: index DB missing after context index"; return 0
  fi

  local out err emit_capture status=0
  out="$tmp_root/pscan-nosqlite.out"; err="$tmp_root/pscan-nosqlite.err"
  emit_capture="$tmp_root/pscan-nosqlite-emit.txt"
  EMIT_FILE="$emit_capture" bash -c '
    set -euo pipefail
    # shellcheck source=scripts/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_sqlite3_check() { return 1; }
    _ctx_emit_usage_event() { printf "%s\t%s\t%s\n" "$1" "$3" "${4:-}" >> "$EMIT_FILE"; }
    pmctl_context_prompt_scan "$2" "alpha knowledge question"
  ' bash "$SCRIPT_DIR" "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if ! grep -q '^knowledge_hits: \[\]' "$out"; then
    fail "$name" "expected 'knowledge_hits: []'; got: $(<"$out")"; return 0
  fi
  if grep -q 'sqlite3 not found' "$err" 2>/dev/null; then
    fail "$name" "missing sqlite must not emit a hard error; stderr: $(<"$err")"; return 0
  fi
  local emit_line
  emit_line="$(cat "$emit_capture" 2>/dev/null || true)"
  if [[ "$emit_line" != "context.prompt_scanned"$'\t'"knowledge question alpha"$'\t'"0" ]]; then
    fail "$name" "expected zero-hit derived-terms event; got: $emit_line"; return 0
  fi
  pass "$name"
}

case_context_prompt_scan_emits_event() {
  local name="pmctl context prompt-scan: emits context.prompt_scanned event, never context.queried"
  # Behavior: a successful prompt-scan must emit context.prompt_scanned (readable
  # via pmctl trace) and must NOT emit context.queried — automated scans must not
  # pollute the manual-query telemetry signal.
  # Steps: index fixture in isolated state root; run prompt-scan; assert a
  # prompt_scanned event with integer hits exists and zero context.queried events.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pscan-evt"
  make_fixture_repo "$fix_repo"

  local state_root="$tmp_root/state-pscan-evt"
  mkdir -p "$state_root"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  local out err status=0
  out="$tmp_root/pscan-evt.out"; err="$tmp_root/pscan-evt.err"
  PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" context prompt-scan "$fix_repo" "alpha knowledge question" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "prompt-scan exited $status: $(<"$err")"; return 0
  fi
  if grep -q 'telemetry not recorded' "$err" 2>/dev/null; then
    fail "$name" "prompt-scan reported a telemetry emit failure: $(<"$err")"; return 0
  fi

  # Payload contract: query field carries the derived, length-ranked terms —
  # "alpha knowledge question" extracts to "knowledge question alpha" — and
  # NEVER the raw prompt (privacy: prompts arrive from an automated hook).
  local evt evt_kind evt_subject_type payload_query payload_hits
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.prompt_scanned --all --json 2>/dev/null \
    | jq -c 'select(.payload.query == "knowledge question alpha")' 2>/dev/null | tail -1)"
  if [[ -z "$evt" ]]; then
    fail "$name" "expected a context.prompt_scanned event with derived-terms query"; return 0
  fi
  payload_query="$(printf '%s\n' "$evt" | jq -r '.payload.query' 2>/dev/null)"
  if [[ "$payload_query" == "alpha knowledge question" ]]; then
    fail "$name" "event stored the raw prompt; must store derived terms only"; return 0
  fi
  evt_kind="$(printf '%s\n' "$evt" | jq -r '.kind' 2>/dev/null)"
  evt_subject_type="$(printf '%s\n' "$evt" | jq -r '.subject_type' 2>/dev/null)"
  payload_hits="$(printf '%s\n' "$evt" | jq -r '.payload.hits' 2>/dev/null)"
  if [[ "$evt_kind" != "context.prompt_scanned" ]]; then
    fail "$name" "event kind: expected context.prompt_scanned, got: $evt_kind"; return 0
  fi
  if [[ "$evt_subject_type" != "context" ]]; then
    fail "$name" "event subject_type: expected context, got: $evt_subject_type"; return 0
  fi
  if ! [[ "$payload_hits" =~ ^[0-9]+$ ]]; then
    fail "$name" "event payload.hits: expected integer, got: $payload_hits"; return 0
  fi

  # Kind separation: the scan must not have recorded any context.queried event.
  local queried_count=0
  queried_count="$(PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" trace tail --kind context.queried --all --json 2>/dev/null \
    | wc -l | tr -d ' ')" || queried_count=0
  if [[ "$queried_count" -gt 0 ]]; then
    fail "$name" "prompt-scan leaked $queried_count context.queried event(s); kinds must stay separate"; return 0
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
case_context_query_no_db_sqlite_missing
case_context_reuse_scan_no_db_emits
case_context_query_autobuilds_missing_db
case_context_pack_autobuilds_missing_db
case_context_query_autorefresh_existing_db
case_context_query_autorefresh_opt_out
case_context_reuse_scan_autorefresh_existing_db
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
case_context_query_source_memory_finds_card
case_context_query_source_memory_trust_tiers
case_context_memory_db_out_of_repo
case_context_query_source_all_merges
case_context_query_source_repo_excludes_memory
case_context_query_source_memory_no_dir_graceful
case_context_query_source_memory_config_override
case_context_query_source_memory_domain_rejected
case_context_query_source_invalid_rejected
case_context_index_source_memory_builds_db
case_context_index_source_invalid_rejected
case_context_pack_source_memory_pointer_only
case_context_pack_source_repo_memories_empty
case_context_pack_source_all_populates_both
case_context_pack_source_invalid_rejected
case_context_reuse_scan_never_returns_memory
case_context_index_source_missing_value
case_context_memory_source_attribution
case_context_pack_repo_sources_no_memory_index
case_context_default_repo_root_uses_cwd_git_toplevel
case_context_default_repo_root_falls_back_to_repo_root_env
case_context_default_repo_root_pm_dispatch_tree_unchanged
case_context_no_arg_cross_repo_never_touches_pm_dispatch_db
case_context_default_repo_root_update_uses_cwd
case_context_default_repo_root_pack_uses_cwd
case_context_default_repo_root_reuse_scan_uses_cwd
case_context_pack_explicit_repo_no_fallback_warning
case_context_reuse_scan_explicit_repo_no_fallback_warning
case_context_prompt_scan_missing_prompt
case_context_prompt_scan_unknown_flag
case_context_prompt_scan_no_db
case_context_prompt_scan_knowledge_domain_only
case_context_prompt_scan_dedup_and_hit_cap
case_context_prompt_scan_term_cap_longest_first
case_context_prompt_scan_no_sqlite_graceful
case_context_prompt_scan_emits_event
case_context_no_live_db_mutation

th_summary
