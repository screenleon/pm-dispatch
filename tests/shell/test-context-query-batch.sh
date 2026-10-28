#!/usr/bin/env bash
# Regression tests for the batched index query (CC-690, issue #741): _ctx_query_hits_batch answers every term
# of a scan with one capability probe and one sqlite3 process. Its rows must be exactly the rows the per-term
# implementation produced (the expected rows below were taken from that implementation on this fixture), and
# the number of processes must not grow with the number of terms.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Expected rows for the terms alpha, beta, gamma. <TAB> stands for a tab character.
EXPECT_FTS_ALL='src/b.sh:30<TAB>repo<TAB>symbol: alpha (function)<TAB>0.85<TAB>high<TAB>symbol_exact<TAB>35<TAB>1002000<TAB>base:1000000,trust:2000,domain:0
src/b.sh:10<TAB>repo<TAB>symbol: alpha_fn (function)<TAB>0.85<TAB>high<TAB>symbol_partial<TAB>20<TAB>502000<TAB>base:500000,trust:2000,domain:0
docs/a.md:4<TAB>knowledge<TAB>fts5 match: alpha beta gamma<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>9<TAB>101549<TAB>base:100000,bm25:49,trust:1000,domain:500
docs/a.md:5<TAB>knowledge<TAB>symbol: beta_helper (heading)<TAB>0.85<TAB>high<TAB>symbol_partial<TAB>9<TAB>502500<TAB>base:500000,trust:2000,domain:500
docs/a.md:4<TAB>knowledge<TAB>fts5 match: alpha beta gamma<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>9<TAB>101500<TAB>base:100000,bm25:0,trust:1000,domain:500
src/b.sh:11<TAB>repo<TAB>fts5 match: beta gamma delta<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>19<TAB>101000<TAB>base:100000,bm25:0,trust:1000,domain:0
BACKLOG.md:1<TAB>knowledge<TAB>fts5 match: gamma ticket<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>3<TAB>101500<TAB>base:100000,bm25:0,trust:1000,domain:500
docs/a.md:4<TAB>knowledge<TAB>fts5 match: alpha beta gamma<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>9<TAB>101500<TAB>base:100000,bm25:0,trust:1000,domain:500
src/b.sh:11<TAB>repo<TAB>fts5 match: beta gamma delta<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>19<TAB>101000<TAB>base:100000,bm25:0,trust:1000,domain:0'
EXPECT_FTS_KNOWLEDGE='docs/a.md:4<TAB>knowledge<TAB>fts5 match: alpha beta gamma<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>9<TAB>101549<TAB>base:100000,bm25:49,trust:1000,domain:500
docs/a.md:5<TAB>knowledge<TAB>symbol: beta_helper (heading)<TAB>0.85<TAB>high<TAB>symbol_partial<TAB>9<TAB>502500<TAB>base:500000,trust:2000,domain:500
docs/a.md:4<TAB>knowledge<TAB>fts5 match: alpha beta gamma<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>9<TAB>101500<TAB>base:100000,bm25:0,trust:1000,domain:500
BACKLOG.md:1<TAB>knowledge<TAB>fts5 match: gamma ticket<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>3<TAB>101500<TAB>base:100000,bm25:0,trust:1000,domain:500
docs/a.md:4<TAB>knowledge<TAB>fts5 match: alpha beta gamma<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>9<TAB>101500<TAB>base:100000,bm25:0,trust:1000,domain:500'
EXPECT_FTS_REPO='src/b.sh:30<TAB>repo<TAB>symbol: alpha (function)<TAB>0.85<TAB>high<TAB>symbol_exact<TAB>35<TAB>1002000<TAB>base:1000000,trust:2000,domain:0
src/b.sh:10<TAB>repo<TAB>symbol: alpha_fn (function)<TAB>0.85<TAB>high<TAB>symbol_partial<TAB>20<TAB>502000<TAB>base:500000,trust:2000,domain:0
src/b.sh:11<TAB>repo<TAB>fts5 match: beta gamma delta<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>19<TAB>101000<TAB>base:100000,bm25:0,trust:1000,domain:0
src/b.sh:11<TAB>repo<TAB>fts5 match: beta gamma delta<TAB>0.75<TAB>medium<TAB>fts5_content<TAB>19<TAB>101000<TAB>base:100000,bm25:0,trust:1000,domain:0'
EXPECT_LIKE_ALL='src/b.sh:30<TAB>repo<TAB>symbol: alpha (function)<TAB>0.85<TAB>high<TAB>symbol_exact<TAB>35<TAB>1002000<TAB>base:1000000,trust:2000,domain:0
src/b.sh:10<TAB>repo<TAB>symbol: alpha_fn (function)<TAB>0.85<TAB>high<TAB>symbol_partial<TAB>20<TAB>502000<TAB>base:500000,trust:2000,domain:0
docs/a.md:4<TAB>knowledge<TAB>text match in chunk<TAB>0.7<TAB>medium<TAB>like_fallback<TAB>9<TAB>11500<TAB>base:10000,trust:1000,domain:500
docs/a.md:5<TAB>knowledge<TAB>symbol: beta_helper (heading)<TAB>0.85<TAB>high<TAB>symbol_partial<TAB>9<TAB>502500<TAB>base:500000,trust:2000,domain:500
docs/a.md:4<TAB>knowledge<TAB>text match in chunk<TAB>0.7<TAB>medium<TAB>like_fallback<TAB>9<TAB>11500<TAB>base:10000,trust:1000,domain:500
src/b.sh:11<TAB>repo<TAB>text match in chunk<TAB>0.7<TAB>medium<TAB>like_fallback<TAB>19<TAB>11000<TAB>base:10000,trust:1000,domain:0
BACKLOG.md:1<TAB>knowledge<TAB>text match in chunk<TAB>0.7<TAB>medium<TAB>like_fallback<TAB>3<TAB>11500<TAB>base:10000,trust:1000,domain:500
docs/a.md:4<TAB>knowledge<TAB>text match in chunk<TAB>0.7<TAB>medium<TAB>like_fallback<TAB>9<TAB>11500<TAB>base:10000,trust:1000,domain:500
src/b.sh:11<TAB>repo<TAB>text match in chunk<TAB>0.7<TAB>medium<TAB>like_fallback<TAB>19<TAB>11000<TAB>base:10000,trust:1000,domain:0'

# make_fixtures: two repositories whose index database holds the same files, symbols and chunks; the first also
# has the FTS5 table, the second does not (so it takes the LIKE fallback). Sets FIX_FTS and FIX_LIKE and returns
# non-zero when sqlite3 cannot build them here (no FTS5). Built once per run; the cases only read the databases.
make_fixtures() {
  if [[ -z "${_FIXTURES_RC:-}" ]]; then
    _FIXTURES_RC=0
    _build_fixtures || _FIXTURES_RC=$?
  fi
  return "$_FIXTURES_RC"
}

_build_fixtures() {
  FIX_FTS="$tmp_root/batch-fts"
  FIX_LIKE="$tmp_root/batch-like"
  local dir
  for dir in "$FIX_FTS" "$FIX_LIKE"; do
    mkdir -p "$dir/.pm-dispatch/ctx"
    sqlite3 "$dir/.pm-dispatch/ctx/context.db" "
      CREATE TABLE files(id INTEGER PRIMARY KEY, path TEXT);
      CREATE TABLE symbols(file_id INTEGER, name TEXT, kind TEXT, line_start INTEGER, line_end INTEGER);
      CREATE TABLE file_chunks(file_id INTEGER, heading TEXT, text TEXT, line_start INTEGER, line_end INTEGER);
      INSERT INTO files VALUES (1,'docs/a.md'),(2,'src/b.sh'),(3,'BACKLOG.md');
      INSERT INTO symbols VALUES (2,'alpha_fn','function',10,20),(2,'alpha','function',30,35),(1,'beta_helper','heading',5,9);
      INSERT INTO file_chunks VALUES (1,'Alpha','alpha beta gamma',4,9),(2,'Code','beta gamma delta',11,19),(3,'Ticket','gamma ticket',1,3);"       >/dev/null 2>&1 || return 1
  done
  sqlite3 "$FIX_FTS/.pm-dispatch/ctx/context.db" "
    CREATE VIRTUAL TABLE content_fts USING fts5(ref, text, line_end UNINDEXED);
    INSERT INTO content_fts VALUES ('docs/a.md:4','alpha beta gamma',9),('src/b.sh:11','beta gamma delta',19),('BACKLOG.md:1','gamma ticket',3);"     >/dev/null 2>&1 || return 2
}

# batch_rows <repo> <domain> <term>...: the rows of one _ctx_query_hits_batch call, tabs shown as <TAB>.
batch_rows() {
  local repo="$1" domain="$2"
  shift 2
  bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    root="$2"; domain="$3"; shift 3
    _ctx_query_hits_batch "$root" "$domain" "" "" "$@"
  ' _ "$REPO_ROOT" "$repo" "$domain" "$@" 2>/dev/null | sed 's/\t/<TAB>/g'
}

# single_rows <repo> <domain> <term>...: the same terms asked one call at a time through _ctx_query_hits_raw.
single_rows() {
  local repo="$1" domain="$2"
  shift 2
  bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    root="$2"; domain="$3"; shift 3
    for t in "$@"; do _ctx_query_hits_raw "$root" "$t" "$domain"; done
  ' _ "$REPO_ROOT" "$repo" "$domain" "$@" 2>/dev/null | sed 's/\t/<TAB>/g'
}

# check_rows <name> <repo> <domain> <expected>: a batch of alpha, beta, gamma gives the expected rows, and the
# one-call-per-term form gives the same.
check_rows() {
  local name="$1" repo="$2" domain="$3" expected="$4" got single
  got="$(batch_rows "$repo" "$domain" alpha beta gamma)"
  single="$(single_rows "$repo" "$domain" alpha beta gamma)"
  if [[ "$got" == "$expected" && "$single" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "batch=$(printf '%s' "$got" | wc -l) rows, one-by-one=$(printf '%s' "$single" | wc -l) rows, expected $(printf '%s' "$expected" | wc -l); first difference: $(diff <(printf '%s\n' "$expected") <(printf '%s\n' "$got") | head -3 | tr '\n' '|')"
  fi
}

case_batch_fts_rows_match_the_per_term_rows() {
  local name="query batch: FTS5 path, three terms give the rows the per-term code gave"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  make_fixtures || { skip "$name" "this sqlite3 build cannot create the FTS5 table"; return 0; }
  check_rows "$name" "$FIX_FTS" "" "$EXPECT_FTS_ALL"
}

case_batch_domain_filters_match() {
  local name="query batch: knowledge and repo domain filters keep the same rows as before"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  make_fixtures || { skip "$name" "this sqlite3 build cannot create the FTS5 table"; return 0; }
  local got_k got_r
  got_k="$(batch_rows "$FIX_FTS" knowledge alpha beta gamma)"
  got_r="$(batch_rows "$FIX_FTS" repo alpha beta gamma)"
  if [[ "$got_k" == "$EXPECT_FTS_KNOWLEDGE" && "$got_r" == "$EXPECT_FTS_REPO" ]]; then
    pass "$name"
  else
    fail "$name" "knowledge rows=$(printf '%s' "$got_k" | wc -l) (want $(printf '%s' "$EXPECT_FTS_KNOWLEDGE" | wc -l)), repo rows=$(printf '%s' "$got_r" | wc -l) (want $(printf '%s' "$EXPECT_FTS_REPO" | wc -l))"
  fi
}

case_batch_like_fallback_rows_match() {
  local name="query batch: without content_fts the LIKE fallback gives the rows the per-term code gave"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  make_fixtures || { skip "$name" "this sqlite3 build cannot create the FTS5 table"; return 0; }
  check_rows "$name" "$FIX_LIKE" "" "$EXPECT_LIKE_ALL"
}

case_batch_memory_plane_label() {
  local name="query batch: a labelled plane (memory) stamps every row with that domain"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  make_fixtures || { skip "$name" "this sqlite3 build cannot create the FTS5 table"; return 0; }
  local got bad
  got="$(bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    _ctx_query_hits_batch "$2" "" "$2/.pm-dispatch/ctx/context.db" memory alpha beta gamma
  ' _ "$REPO_ROOT" "$FIX_FTS" 2>/dev/null)"
  bad="$(awk -F'\t' '$2 != "memory" {n++} END {print n + 0}' <<< "$got")"
  if [[ -n "$got" && "$bad" -eq 0 && "$(grep -c . <<< "$got")" -eq 9 ]]; then
    pass "$name"
  else
    fail "$name" "rows=$(grep -c . <<< "$got") not-memory=$bad"
  fi
}

# sqlite3_calls <repo> <term>...: how many times _ctx_query_hits_batch starts sqlite3.
sqlite3_calls() {
  local repo="$1" log="$tmp_root/sqlite3-calls"
  shift
  : > "$log"
  bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    log="$2"; root="$3"; shift 3
    sqlite3() { echo call >> "$log"; command sqlite3 "$@"; }
    _ctx_query_hits_batch "$root" "" "" "" "$@" >/dev/null
  ' _ "$REPO_ROOT" "$log" "$repo" "$@" 2>/dev/null || true
  grep -c call "$log" || true
}

case_batch_process_count_does_not_grow_with_terms() {
  local name="query batch: starting sqlite3 costs the same for one term as for eight (FTS5 and LIKE paths)"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  make_fixtures || { skip "$name" "this sqlite3 build cannot create the FTS5 table"; return 0; }
  local fts_one fts_many like_one like_many
  fts_one="$(sqlite3_calls "$FIX_FTS" alpha)"
  fts_many="$(sqlite3_calls "$FIX_FTS" alpha beta gamma delta epsilon zeta eta theta)"
  like_one="$(sqlite3_calls "$FIX_LIKE" alpha)"
  like_many="$(sqlite3_calls "$FIX_LIKE" alpha beta gamma delta epsilon zeta eta theta)"
  if [[ "$fts_one" -ge 1 && "$fts_one" == "$fts_many" && "$like_one" -ge 1 && "$like_one" == "$like_many" ]]; then
    pass "$name"
  else
    fail "$name" "fts: 1 term=$fts_one 8 terms=$fts_many; like: 1 term=$like_one 8 terms=$like_many"
  fi
}

case_batch_one_failing_statement_keeps_the_other_terms() {
  local name="query batch: a plane without a symbols table still returns its text hits"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  make_fixtures || { skip "$name" "this sqlite3 build cannot create the FTS5 table"; return 0; }
  local repo="$tmp_root/batch-nosymbols" got
  mkdir -p "$repo/.pm-dispatch/ctx"
  # The memory plane's database has no symbols table: every symbol statement fails, the text statements must
  # still run for every term.
  sqlite3 "$repo/.pm-dispatch/ctx/context.db" "
    CREATE TABLE files(id INTEGER PRIMARY KEY, path TEXT);
    CREATE VIRTUAL TABLE content_fts USING fts5(ref, text, line_end UNINDEXED);
    INSERT INTO files VALUES (1,'docs/a.md');
    INSERT INTO content_fts VALUES ('docs/a.md:4','alpha beta gamma',9);" >/dev/null 2>&1 \
    || { skip "$name" "this sqlite3 build cannot create the FTS5 table"; return 0; }
  got="$(batch_rows "$repo" "" alpha beta)"
  if [[ "$(grep -c 'fts5_content' <<< "$got")" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "got=$got"
  fi
}

case_prompt_scan_process_count_does_not_grow_with_terms() {
  local name="prompt-scan: a six-term prompt starts sqlite3 as often as a one-term prompt"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo="$tmp_root/ps-repo" stubs="$tmp_root/ps-stub" log="$tmp_root/ps-calls" real one many
  mkdir -p "$repo/docs" "$stubs"
  git init -q "$repo"
  printf '# Alpha\nalpha beta gamma delta epsilon zeta\n' > "$repo/docs/a.md"
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q -m docs
  real="$(command -v sqlite3)"
  printf '%s\n' '#!/bin/sh' "echo call >> \"$log\"" "exec \"$real\" \"\$@\"" > "$stubs/sqlite3"
  chmod +x "$stubs/sqlite3"
  # The first scan builds the index; only the scans after it find it fresh and are counted.
  PATH="$stubs:$PATH" PM_DISPATCH_STATE_ROOT="$tmp_root/ps-state" \
    bash "$REPO_ROOT/cli/pmctl" context prompt-scan "$repo" "alpha" >/dev/null 2>&1 || true
  : > "$log"
  PATH="$stubs:$PATH" PM_DISPATCH_STATE_ROOT="$tmp_root/ps-state" \
    bash "$REPO_ROOT/cli/pmctl" context prompt-scan "$repo" "alpha" >/dev/null 2>&1 || true
  one="$(grep -c call "$log" || true)"
  : > "$log"
  PATH="$stubs:$PATH" PM_DISPATCH_STATE_ROOT="$tmp_root/ps-state" \
    bash "$REPO_ROOT/cli/pmctl" context prompt-scan "$repo" "alpha beta gamma delta epsilon zeta" >/dev/null 2>&1 || true
  many="$(grep -c call "$log" || true)"
  if [[ "$one" =~ ^[0-9]+$ && "$one" -ge 1 && "$one" == "$many" ]]; then
    pass "$name"
  else
    fail "$name" "sqlite3 started $one times for one term and $many times for six"
  fi
}

case_batch_fts_rows_match_the_per_term_rows
case_batch_domain_filters_match
case_batch_like_fallback_rows_match
case_batch_memory_plane_label
case_batch_process_count_does_not_grow_with_terms
case_batch_one_failing_statement_keeps_the_other_terms
case_prompt_scan_process_count_does_not_grow_with_terms

th_summary
