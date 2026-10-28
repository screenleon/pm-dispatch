#!/usr/bin/env bash
# Regression tests for the change planner of an index refresh (CC-690, issue #741): which files of a scan are
# unchanged and which are indexed again is decided by context-index-plan.awk in a handful of passes, not by a
# bash loop that runs several associative-array lookups for every file. The decisions must be the ones the
# loops made (an edit that keeps the mtime is still caught by its hash, a file that is gone leaves the index,
# ...), a planner that cannot run must never turn into "delete every row", and the number of processes of a
# refresh must not grow with the number of files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# new_repo <name> <file count>: a git repository with that many docs/*.md files, one commit. Prints its path.
new_repo() {
  local dir="$tmp_root/$1" count="$2" i
  mkdir -p "$dir/docs"
  for ((i = 1; i <= count; i++)); do
    printf '%s\n' "# Doc $i" "line one of $i" > "$dir/docs/doc$i.md"
  done
  git init -q "$dir"
  git -C "$dir" add -A >/dev/null 2>&1
  git -C "$dir" -c user.name=t -c user.email=t@example.invalid commit -q -m docs
  printf '%s' "$dir"
}

# refresh <repo>: one index refresh; prints the line with its counts. A refresh that exits non-zero prints
# "FAILED rc=<n>: <its output>" instead, so a case that compares the counts cannot pass on a failed run.
refresh() {
  local out rc=0
  out="$("$PMCTL" context index "$1" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAILED rc=%s: %s' "$rc" "${out:0:300}"
    return 0
  fi
  grep -m1 'indexed' <<< "$out" || true
}

# db_paths <repo>: the paths the index holds, sorted.
db_paths() {
  sqlite3 "$1/.pm-dispatch/ctx/context.db" "SELECT path FROM files ORDER BY path;" 2>/dev/null | tr -d '\r'
}

# db_sha1 <repo> <path>: the stored hash of one path.
db_sha1() {
  sqlite3 "$1/.pm-dispatch/ctx/context.db" "SELECT sha1 FROM files WHERE path = '$2';" 2>/dev/null | tr -d '\r'
}

case_unchanged_tree_indexes_nothing() {
  local name="index plan: a tree that did not change is skipped file by file"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo first second
  repo="$(new_repo plan-noop 6)"
  first="$(refresh "$repo")"
  second="$(refresh "$repo")"
  if [[ "$first" == *"6 indexed, 0 skipped"* && "$second" == *"0 indexed, 6 skipped"* ]]; then
    pass "$name"
  else
    fail "$name" "first='$first' second='$second'"
  fi
}

case_changed_content_is_found_with_or_without_a_new_mtime() {
  local name="index plan: an edit is found by its mtime, and an edit that keeps the mtime is found by its hash"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo a b out_a out_b old_sha new_sha
  repo="$(new_repo plan-edit 4)"
  refresh "$repo" >/dev/null
  a="$repo/docs/doc1.md"
  b="$repo/docs/doc2.md"
  printf '%s\n' "more" >> "$a"
  out_a="$(refresh "$repo")"
  # Same bytes length, new content, the old modification time put back.
  old_sha="$(db_sha1 "$repo" docs/doc2.md)"
  cp -p "$b" "$tmp_root/doc2.keep"
  printf '%s\n' "# Doc 2" "LINE ONE OF 2" > "$b"
  touch -r "$tmp_root/doc2.keep" "$b"
  out_b="$(refresh "$repo")"
  new_sha="$(db_sha1 "$repo" docs/doc2.md)"
  if [[ "$out_a" == *"1 indexed, 3 skipped"* && "$out_b" == *"1 indexed, 3 skipped"* \
        && -n "$old_sha" && -n "$new_sha" && "$old_sha" != "$new_sha" ]]; then
    pass "$name"
  else
    fail "$name" "after edit='$out_a' after same-mtime edit='$out_b' old=$old_sha new=$new_sha"
  fi
}

case_added_and_removed_files_reach_the_index() {
  local name="index plan: a new file is indexed and a file that is gone leaves the index"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo out paths
  repo="$(new_repo plan-addrm 3)"
  refresh "$repo" >/dev/null
  printf '%s\n' "# New" > "$repo/docs/new.md"
  # A tracked file that is deleted from the working tree is still listed by git; it must not stay indexed.
  mv "$repo/docs/doc3.md" "$tmp_root/doc3.moved"
  out="$(refresh "$repo")"
  paths="$(db_paths "$repo" | tr '\n' ' ')"
  if [[ "$out" == *"1 indexed, 2 skipped"* && "$paths" == *"docs/new.md"* && "$paths" != *"docs/doc3.md"* ]]; then
    pass "$name"
  else
    fail "$name" "out='$out' paths='$paths'"
  fi
}

case_odd_file_names_are_indexed() {
  local name="index plan: names with a space or a quote are indexed under their own path"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo out paths
  repo="$(new_repo plan-names 2)"
  printf '%s\n' "# a" > "$repo/docs/with space.md"
  printf '%s\n' "# b" > "$repo/docs/it's.md"
  refresh "$repo" >/dev/null
  out="$(refresh "$repo")"
  paths="$(db_paths "$repo")"
  if [[ "$out" == *"0 indexed, 4 skipped"* && "$paths" == *"docs/with space.md"* && "$paths" == *"docs/it's.md"* ]]; then
    pass "$name"
  else
    fail "$name" "second refresh='$out' paths='$paths'"
  fi
}

case_a_bar_in_a_file_name_is_indexed() {
  local name="index plan: a file name with a bar is indexed under its own path (the stored rows used to split on it)"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  th_require_special_filenames "$name" || return 0
  local repo out paths
  repo="$(new_repo plan-bar 2)"
  printf '%s\n' "# c" > "$repo/docs/a|b.md"
  refresh "$repo" >/dev/null
  out="$(refresh "$repo")"
  paths="$(db_paths "$repo")"
  if [[ "$out" == *"0 indexed, 3 skipped"* && "$paths" == *"docs/a|b.md"* ]]; then
    pass "$name"
  else
    fail "$name" "second refresh='$out' paths='$paths'"
  fi
}

case_symlinks_follow_the_old_rules() {
  local name="index plan: a symbolic link to a file is indexed; links to a directory or to nothing are not"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  th_require_symlinks "$name" || return 0
  local repo out paths
  repo="$(new_repo plan-links 2)"
  mkdir -p "$repo/docs/adir"
  ln -s doc1.md "$repo/docs/link-to-file.md"
  ln -s adir "$repo/docs/link-to-dir.md"
  ln -s nowhere.md "$repo/docs/broken.md"
  out="$(refresh "$repo")"
  paths="$(db_paths "$repo" | tr '\n' ' ')"
  if [[ "$out" == *"3 indexed"* && "$paths" == *"docs/link-to-file.md"* \
        && "$paths" != *"docs/link-to-dir.md"* && "$paths" != *"docs/broken.md"* ]]; then
    pass "$name"
  else
    fail "$name" "out='$out' paths='$paths'"
  fi
}

case_a_new_extractor_version_reindexes_everything() {
  local name="index plan: a database built by another extractor is indexed again in full"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo out out_none
  repo="$(new_repo plan-force 4)"
  refresh "$repo" >/dev/null
  sqlite3 "$repo/.pm-dispatch/ctx/context.db" "UPDATE index_meta SET extractor_version = extractor_version + 999;" >/dev/null 2>&1 \
    || { fail "$name" "setup: could not change the stored extractor version"; return 0; }
  out="$(refresh "$repo")"
  # No version at all (an emptied index_meta) is another extractor too.
  sqlite3 "$repo/.pm-dispatch/ctx/context.db" "DELETE FROM index_meta;" >/dev/null 2>&1 \
    || { fail "$name" "setup: could not empty index_meta"; return 0; }
  out_none="$(refresh "$repo")"
  if [[ "$out" == *"4 indexed, 0 skipped"* && "$out_none" == *"4 indexed, 0 skipped"* ]]; then
    pass "$name"
  else
    fail "$name" "other version='$out' no version='$out_none'"
  fi
}

case_a_missing_file_does_not_stop_a_strict_caller() {
  local name="index plan: a file that vanished from the scan does not end a caller running under set -e"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo got
  repo="$(new_repo plan-strict 3)"
  refresh "$repo" >/dev/null
  mv "$repo/docs/doc2.md" "$tmp_root/doc2.strict"
  got="$(bash -c '
    set -euo pipefail
    . "$1/runtime/lib/pmctl-context.sh"
    _ctx_index_tree "$2" "$2/.pm-dispatch/ctx/context.db" 1 repo >/dev/null 2>&1
    echo survived
  ' _ "$REPO_ROOT" "$repo" 2>&1)" || true
  if [[ "$got" == survived && "$(db_paths "$repo" | grep -c 'docs/doc2.md' || true)" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "got='$got'"
  fi
}

case_a_planner_that_cannot_run_keeps_the_index() {
  local name="index plan: when awk fails the refresh stops and the stored rows stay"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo got before after
  repo="$(new_repo plan-noawk 3)"
  refresh "$repo" >/dev/null
  before="$(db_paths "$repo" | grep -c . || true)"
  got="$(bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    awk() { return 1; }
    _ctx_index_tree "$2" "$2/.pm-dispatch/ctx/context.db" 1 repo >/dev/null 2>&1
    echo "rc=$?"
  ' _ "$REPO_ROOT" "$repo" 2>&1)" || true
  after="$(db_paths "$repo" | grep -c . || true)"
  if [[ "$got" == "rc=1" && "$before" -eq 3 && "$after" -eq 3 ]]; then
    pass "$name"
  else
    fail "$name" "got='$got' rows before=$before after=$after"
  fi
}

# tool_calls <repo>: how many times a refresh starts each of the tools it uses, as "stat=1 sha1sum=1 ...".
tool_calls() {
  local repo="$1" stubs="$tmp_root/plan-stubs" log="$tmp_root/plan-tool-calls" tool real
  : > "$log"
  for tool in stat sha1sum sqlite3 awk git; do
    real="$(command -v "$tool")" || continue
    make_stub "$stubs" "$tool" "echo $tool >> \"$log\"" "exec \"$real\" \"\$@\""
  done
  local rc=0
  PATH="$stubs:$PATH" "$PMCTL" context index "$repo" >/dev/null 2>&1 || rc=$?
  printf 'rc=%s ' "$rc"
  sort "$log" | uniq -c | awk '{printf "%s=%s ", $2, $1}'
}

case_process_count_does_not_grow_with_the_number_of_files() {
  local name="index plan: a refresh that changes nothing starts the same processes for 5 files as for 40"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local small big small_calls big_calls
  small="$(new_repo plan-small 5)"
  big="$(new_repo plan-big 40)"
  refresh "$small" >/dev/null
  refresh "$big" >/dev/null
  small_calls="$(tool_calls "$small")"
  big_calls="$(tool_calls "$big")"
  # Both refreshes have to succeed (the calls begin with "rc=0 ") before their tool counts mean anything.
  if [[ "$small_calls" == "rc=0 "* && "$small_calls" == "$big_calls" ]]; then
    pass "$name"
  else
    fail "$name" "5 files: $small_calls; 40 files: $big_calls"
  fi
}

# make_stub <dir> <tool> <script line>...: an executable `tool` in <dir> (created if needed) made of a /bin/sh
# shebang and the given lines, to put in front of the real one on PATH.
make_stub() {
  local dir="$1" tool="$2"
  shift 2
  mkdir -p "$dir"
  printf '%s\n' '#!/bin/sh' "$@" > "$dir/$tool"
  chmod +x "$dir/$tool"
}

# localized_stat_stubs <obey_lc_all: yes|no>: a directory with a `stat` that answers in another language, the way a
# Chinese-locale stat prints the file type word. With "yes" it answers in English when it is run with
# LC_ALL=C (a real stat does); with "no" it always answers in the other language (a stat that ignores the
# variable). Prints the directory.
localized_stat_stubs() {
  local obey="$1" dir="$tmp_root/locale-stubs-$1" real
  real="$(command -v stat)"
  make_stub "$dir" stat \
    "out=\$(\"$real\" \"\$@\"); rc=\$?" \
    "if [ \"$obey\" = yes ] && [ \"\${LC_ALL:-}\" = C ]; then printf '%s\\n' \"\$out\"; exit \$rc; fi" \
    "printf '%s\\n' \"\$out\" | sed -e 's/regular empty file/一般空檔案/' -e 's/regular file/一般檔案/'" \
    'exit $rc'
  printf '%s' "$dir"
}

# check_locale_run <name> <obey>: an index and a prompt-scan with a stat that answers in another language must
# keep every file: the run succeeds, every path stays in the index, a second refresh skips them all and the
# documents can still be found.
check_locale_run() {
  local name="$1" obey="$2" repo stubs first second paths found status=0
  repo="$(new_repo "plan-locale-$obey" 4)"
  stubs="$(localized_stat_stubs "$obey")"
  first="$(PATH="$stubs:$PATH" refresh "$repo")"
  second="$(PATH="$stubs:$PATH" refresh "$repo")"
  paths="$(db_paths "$repo" | tr '\n' ' ')"
  local query_out
  query_out="$(PATH="$stubs:$PATH" PM_DISPATCH_STATE_ROOT="$tmp_root/plan-locale-state" "$PMCTL" context query "$repo" "line one of 3" 2>/dev/null)" || status=$?
  found="$(grep -c 'docs/doc3.md' <<< "$query_out" || true)"
  if [[ "$status" -eq 0 && "$first" == *"4 indexed, 0 skipped"* && "$second" == *"0 indexed, 4 skipped"* \
        && "$paths" == *"docs/doc1.md"* && "$paths" == *"docs/doc4.md"* && "$found" -ge 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status first='$first' second='$second' paths='$paths' hits for doc3=$found"
  fi
}

case_a_localized_stat_keeps_every_file() {
  local name="index plan: a stat that translates the file type is run with LC_ALL=C and every file stays indexed"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  check_locale_run "$name" yes
}

case_a_stat_that_ignores_lc_all_still_keeps_every_file() {
  local name="index plan: a type word the planner does not know is checked with [[ -f ]], never taken for a non-file"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  check_locale_run "$name" no
}

case_a_unit_separator_in_a_name_cannot_reach_the_sql() {
  local name="index plan: a file name holding the planner's separator is indexed under its exact path and injects nothing"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local dir="$tmp_root/plan-us" sep=$'\x1f' odd out second tables rows
  mkdir -p "$dir/docs"
  odd="p.md${sep}0${sep}1);DROP TABLE files;--.md"
  printf '%s\n' "# p" > "$dir/docs/p.md"
  # Not every file system accepts a control character in a name; that is a skip, not a pass.
  if ! printf '%s\n' "# odd" > "$dir/docs/$odd" 2>/dev/null; then
    skip "$name" "this file system cannot hold a unit separator in a file name"
    return 0
  fi
  # A directory that is not a git repository: the scan comes from find, which lists such a name as it is
  # (git quotes it). The first refresh builds the index; the second must succeed and account for both files.
  # (It need not skip the odd one: a newer sqlite3 prints a control character in a stored path in caret
  # notation, so that row never matches and the file is indexed again, which is slower but correct.)
  out="$(refresh "$dir")"
  second="$(refresh "$dir")"
  local second_total=-1
  if [[ "$second" =~ ([0-9]+)\ indexed,\ ([0-9]+)\ skipped ]]; then
    second_total=$((BASH_REMATCH[1] + BASH_REMATCH[2]))
  fi
  tables="$(sqlite3 "$dir/.pm-dispatch/ctx/context.db" "SELECT count(*) FROM sqlite_master WHERE name = 'files';" 2>/dev/null | tr -d '\r')"
  rows="$(sqlite3 "$dir/.pm-dispatch/ctx/context.db" "SELECT count(*) FROM files WHERE path = 'docs/p.md' OR path = 'docs/p.md' || char(31) || '0' || char(31) || '1);DROP TABLE files;--.md';" 2>/dev/null | tr -d '\r')"
  if [[ "$out" == *"2 indexed, 0 skipped"* && "$second_total" -eq 2 && "$tables" == 1 && "$rows" == 2 ]]; then
    pass "$name"
  else
    fail "$name" "first='$out' second='$second' files table present=$tables exact rows=$rows"
  fi
}

case_unchanged_tree_indexes_nothing
case_changed_content_is_found_with_or_without_a_new_mtime
case_added_and_removed_files_reach_the_index
case_odd_file_names_are_indexed
case_a_bar_in_a_file_name_is_indexed
case_a_unit_separator_in_a_name_cannot_reach_the_sql
case_symlinks_follow_the_old_rules
case_a_new_extractor_version_reindexes_everything
case_a_missing_file_does_not_stop_a_strict_caller
case_a_planner_that_cannot_run_keeps_the_index
case_a_localized_stat_keeps_every_file
case_a_stat_that_ignores_lc_all_still_keeps_every_file
case_process_count_does_not_grow_with_the_number_of_files

th_summary
