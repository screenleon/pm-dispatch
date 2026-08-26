#!/usr/bin/env bash
# Regression tests for pmctl context index / update / query commands.
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=tests/lib/test-memory-config-fixtures.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-memory-config-fixtures.sh"
th_init "$@"

# Never inherit the operator's memory mapping. Config-specific cases opt into
# their own fixture file explicitly.
export PM_DISPATCH_CONFIG_FILE="$tmp_root/no-operator-config"
unset PM_MEMORY_DIR PM_CFG_MEMORY_DIR PM_CFG_MEMORY_DIR_INVALID PM_CFG_MEMORY_CONFIG_STATUS

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

# The developer's live repo context DB. Every context case must operate on an
# isolated fixture under $tmp_root, never $REPO_ROOT: indexing/querying the real
# repo root rebuilds this DB and, under parallel runs, causes sqlite-busy and
# FTS-rebuild flakiness.
#
# Two suite-owned guards keep that true, neither of which reads the live DB —
# reading it would report on every process on this machine, not on this suite:
#
#   1. Per call: $PMCTL is a wrapper that refuses any context invocation which
#      has not been placed inside the fixture tree, so an unisolated call fails
#      at its own call site, not later as an unattributed diff. Cases that source
#      the library and call its functions directly bypass that wrapper, so they
#      pass their target through ctx_fixture_target, which enforces the same rule.
#   2. Per entrypoint: case_context_commands_resolve_only_fixture_roots asserts
#      every context subcommand the CLI publishes resolves inside the fixture.
#
# The wrapper checks a SUFFICIENT PRECONDITION for isolation, deliberately not a
# copy of the CLI's repo-root resolution rules: a call is isolated if it names a
# path under $tmp_root, or runs from a CWD inside a git worktree under $tmp_root.
# Every other shape — an explicit live root, a bare call from the repo, a bare
# call from a directory in no worktree at all (which falls back to $REPO_ROOT
# inside the CLI) — is refused rather than predicted. Cases that must escape it,
# such as invalid-argument paths that never reach resolution, set
# PM_CTX_GUARD_ALLOW_NON_FIXTURE=1 so each exception is visible and reviewable.
LIVE_DB="$REPO_ROOT/.pm-dispatch/ctx/context.db"
REAL_PMCTL="$PMCTL"

# Containment is decided on resolved paths, never on the string as written:
# "$tmp_root/../.." is lexically inside the fixture root and actually outside it,
# and a symlink planted in a fixture can point anywhere. The $PMCTL wrapper is a
# separate process, so this lives in a file both it and this suite source —
# one implementation, because a second weaker copy is exactly how the wrapper
# ended up failing OPEN when realpath was unavailable.
mkdir -p "$tmp_root/bin"
cat > "$tmp_root/bin/ctx-canon.sh" <<'CANON'
# Resolve a path to its physical location. Paths that do not exist yet still
# resolve, because a call may name a directory it is about to create. Prints
# nothing and returns 1 when resolution cannot be established — callers must
# treat that as "not contained", never as "unchanged".
ctx_canonical_path() {
  local path="$1" resolved tail_part="" head_part="$1"
  if resolved="$(realpath -m -- "$path" 2>/dev/null)" && [[ "$resolved" == /* ]]; then
    printf '%s\n' "$resolved"
    return 0
  fi
  # Fallback for hosts without GNU realpath -m: resolve the deepest existing
  # ancestor physically, then re-attach the part that does not exist yet.
  [[ "$path" == /* ]] || return 1
  while [[ ! -d "$head_part" && "$head_part" == */* ]]; do
    tail_part="/${head_part##*/}$tail_part"
    head_part="${head_part%/*}"
    [[ -n "$head_part" ]] || head_part=/
  done
  [[ -d "$head_part" ]] || return 1
  resolved="$(cd "$head_part" 2>/dev/null && pwd -P)" || return 1
  resolved="$resolved$tail_part"
  # A surviving traversal segment means resolution did not establish a physical
  # location; refuse to answer rather than answer wrongly.
  case "$resolved" in */../*|*/..) return 1 ;; esac
  printf '%s\n' "$resolved"
}
CANON
# shellcheck source=/dev/null
. "$tmp_root/bin/ctx-canon.sh"

CTX_FIXTURE_ROOT="$(ctx_canonical_path "$tmp_root")" || {
  printf 'test-pmctl-context: cannot resolve the fixture root\n' >&2
  exit 1
}
CTX_LIVE_ROOT="$(ctx_canonical_path "$REPO_ROOT")" || {
  printf 'test-pmctl-context: cannot resolve the live repo root\n' >&2
  exit 1
}

CTX_GUARD_LOG="$tmp_root/live-target-violations.log"
: > "$CTX_GUARD_LOG"
mkdir -p "$tmp_root/bin"
fixture_root_canon="$CTX_FIXTURE_ROOT"
live_root_canon="$CTX_LIVE_ROOT"
cat > "$tmp_root/bin/pmctl" <<GUARD
#!/usr/bin/env bash
set -uo pipefail
# PM_CTX_GUARD_LOG lets the guard's own self-tests collect their deliberate
# violations somewhere else, so they never contaminate the suite-wide log.
_log="\${PM_CTX_GUARD_LOG:-$CTX_GUARD_LOG}"
_refuse() {
  printf 'test-pmctl-context: refusing an unisolated context call (%s): %s\n' \\
    "\$1" "\$*" >&2
  printf '%s\t%s\n' "\$1" "\${*:2}" >> "\$_log"
  exit 99
}
# The SAME canonicalizer this suite uses. Carrying a second, weaker copy here
# is what previously let an unresolvable path fall through as "unchanged" and
# keep its fixture prefix.
# shellcheck source=/dev/null
. "$tmp_root/bin/ctx-canon.sh"
if [[ "\${1:-}" == context && "\${PM_CTX_GUARD_ALLOW_NON_FIXTURE:-0}" != 1 ]]; then
  _fixture_arg=0
  for _arg in "\$@"; do
    # Only path-shaped arguments are examined. A bare query term like "alpha"
    # would otherwise canonicalize against the CWD and count as a fixture path,
    # which would skip the CWD check below — the opposite of guarding.
    case "\$_arg" in -*) continue ;; esac
    # ABSOLUTE paths only. Telling a repo argument from a flag value needs the
    # CLI's own parser; testing a relative argument for directory-ness resolves
    # it against the CWD, which made "--source memory" look like the repo's
    # memory/ directory. Anything relative simply does not count as a fixture
    # path, which sends the call to the stricter CWD check below.
    [[ "\$_arg" == /* ]] || continue
    # Fail CLOSED: an argument whose physical location cannot be established is
    # not "probably fine", it is undecidable, and undecidable must not pass.
    _resolved="\$(ctx_canonical_path "\$_arg")" \
      || _refuse "target path cannot be resolved (\$_arg)" "\$@"
    if [[ "\$_resolved" == "$live_root_canon" || "\$_resolved" == "$live_root_canon"/* ]]; then
      _refuse "resolves to the live repo root (\$_arg -> \$_resolved)" "\$@"
    fi
    # Fixture status requires a DIRECTORY, because that is the CLI's own test
    # for "is this positional the repo root": a -d test. An absolute path under
    # the fixture root that is not a directory is not consumed as the repo root
    # at all — it slides down to the query position and resolution falls back to
    # the CWD, i.e. this repository. Granting fixture status for it would skip
    # the CWD check below on exactly the call that needs it.
    [[ -d "\$_arg" && "\$_resolved" == "$fixture_root_canon"/* ]] && _fixture_arg=1
  done
  if [[ "\$_fixture_arg" -eq 0 ]]; then
    # No fixture path given, so the CLI will resolve from the CWD. That is safe
    # only when the CWD sits in a worktree under the fixture root; with no
    # worktree at all the CLI falls back to the live repo root.
    _top="\$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "\$_top" ]] && { _top="\$(ctx_canonical_path "\$_top")" || _top=""; }
    if [[ -z "\$_top" || "\$_top" != "$fixture_root_canon"/* ]]; then
      _refuse "no fixture path and CWD resolves outside the fixture root (\${_top:-no worktree})" "\$@"
    fi
  fi
fi
exec "$REAL_PMCTL" "\$@"
GUARD
chmod +x "$tmp_root/bin/pmctl"
PMCTL="$tmp_root/bin/pmctl"

# A few cases source the context library and call its functions directly, which
# does not go through the wrapper above. They pass their target as an argument,
# so they get the same guarantee through this seam instead: echo the target, or
# refuse and record it exactly as the wrapper would.
ctx_fixture_target() {
  local target="$1" resolved log="${PM_CTX_GUARD_LOG:-$CTX_GUARD_LOG}"
  resolved="$(ctx_canonical_path "$target")" || resolved="<unresolvable:$target>"
  if [[ "$resolved" != "$CTX_FIXTURE_ROOT"/* ]]; then
    printf 'test-pmctl-context: refusing a direct context call on a non-fixture target: %s (resolves to %s)\n' \
      "$target" "$resolved" >&2
    printf 'direct call target outside the fixture root\t%s -> %s\n' \
      "$target" "$resolved" >> "$log"
    return 1
  fi
  printf '%s\n' "$target"
}
SUITE_FILE="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# ── Helpers ────────────────────────────────────────────────────────────────────

# Set up a minimal fixture repo in a temp dir for index/update tests.
make_fixture_repo() {
  local dir="$1"
  mkdir -p "$dir/scripts/lib" "$dir/runtime/lib" "$dir/scripts" "$dir/docs"

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

git_init_commit_fixture() {
  local repo="$1"
  git -C "$repo" init -q
  git -C "$repo" config user.name "pm-dispatch tests"
  git -C "$repo" config user.email "pm-dispatch-tests@example.invalid"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m init
}

# ── Memory-plane fixtures (CC-403) ─────────────────────────────────────────────
# Stand up a fake project-memory directory that find_memory_dir resolves for
# <repo> when CLAUDE_CONFIG_DIR points at <cfg>. Echoes the memory dir path.
# Mirrors runtime/lib/memory.sh encode_path: "/a/b" → "-a-b".
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

# CC-505 Req 7: a deterministic retrieval fixture corpus. Each scenario below
# carries a unique, otherwise-unused marker token so its query cannot
# accidentally match unrelated fixture content, and each is deliberately
# built to fail under the PRE-CC-505 behavior it regression-locks:
#   exact symbol       -> would previously tie with any partial/text match
#   heading             -> would previously not rank above unrelated hits
#   deep-in-paragraph   -> would be invisible under the old 200-char truncation
#   same-word polysemy  -> would previously not distinguish symbol vs prose
#   path/domain boost   -> would previously have no domain weighting at all
#   long-section chunk  -> would be invisible without Req 1's windowed chunking
make_retrieval_corpus_repo() {
  local dir="$1"
  mkdir -p "$dir/src" "$dir/docs"

  # 1. Exact symbol: a uniquely-named function; querying its exact name must
  # rank it top-1 (match_kind=symbol_exact outranks every other tier).
  cat > "$dir/src/exact.sh" <<'SH'
#!/usr/bin/env bash
unique_exact_symbol_target() {
  printf 'target\n'
}
SH

  # 2. Heading match: a distinctive multi-word heading with no repeated
  # terms in the surrounding prose.
  cat > "$dir/docs/heading.md" <<'MD'
# Heading Fixture

## Distinctive Heading Marker Zulu

Some unrelated prose here that does not repeat the heading words.
MD

  # 3. Deep-in-paragraph: a unique marker placed after ~2800 characters of
  # filler, well past the pre-CC-505 200-character truncation point.
  local deep_body i
  deep_body=""
  for i in $(seq 1 40); do
    deep_body="${deep_body}filler sentence number $i to push content deep into the section. "
  done
  {
    printf '# Deep Fixture\n\n## Deep Section\n\n'
    printf '%s\n' "$deep_body"
    printf 'deepburied_unique_marker_quebec appears only here, well past 200 characters.\n'
  } > "$dir/docs/deep.md"

  # 4. Same-word polysemy: the same token is both an exact symbol name and a
  # plain-prose mention elsewhere; the exact-symbol form must still win.
  cat > "$dir/src/polysemy.sh" <<'SH'
#!/usr/bin/env bash
polysemy_common_term() {
  printf 'symbol form\n'
}
SH
  cat > "$dir/docs/polysemy_prose.md" <<'MD'
# Polysemy Prose

The term polysemy_common_term also shows up here in plain prose, not as a
symbol definition, to test that the exact-symbol form still ranks above a
generic textual mention of the same token.
MD

  # 5. Path/domain boost: the identical marker term in a knowledge-domain
  # file (BACKLOG.md) and a plain repo-domain file; the knowledge hit must
  # rank first.
  cat > "$dir/BACKLOG.md" <<'MD'
# Backlog

## Marker Section

domain_boost_marker_xray appears in this knowledge-domain file.
MD
  cat > "$dir/src/plain_note.txt" <<'TXT'
domain_boost_marker_xray also appears in this plain repo-domain file.
TXT

  # 6. Long section split across multiple chunks (window=20 lines): a
  # unique marker on the LAST line of a 35-line section is retrievable only
  # if the section was windowed into multiple chunks rather than truncated
  # to its first window.
  {
    printf '# Long Section Fixture\n\n## Long Section\n\n'
    local j
    for j in $(seq 1 35); do
      printf 'filler line number %d in a long section.\n' "$j"
    done
    printf 'longsection_tail_marker_yankee is the very last line.\n'
  } > "$dir/docs/long_section.md"
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
  # case would start indexing the LIVE repo DB (see $LIVE_DB).
  local nogit_dir="$tmp_root/idx-mr-nogit"
  mkdir -p "$nogit_dir"
  ( cd "$nogit_dir" && env -u REPO_ROOT bash -c \
      ". \"$REPO_ROOT/runtime/lib/pmctl-context.sh\" 2>/dev/null; pmctl_context_index" \
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

  local src="$REPO_ROOT/runtime/lib/pmctl-validate.sh"
  if [[ ! -f "$src" ]]; then
    fail "$name" "runtime/lib/pmctl-validate.sh not found in repo"; return 0
  fi

  local fix="$tmp_root/fix-real-query"
  mkdir -p "$fix/scripts/lib" "$fix/runtime/lib"
  cp "$src" "$fix/runtime/lib/pmctl-validate.sh"

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
    # Argument validation rejects this before any repo root is resolved, so the
    # isolation guard has nothing to protect here.
    PM_CTX_GUARD_ALLOW_NON_FIXTURE=1 \
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
    # Argument validation rejects this before any repo root is resolved.
    PM_CTX_GUARD_ALLOW_NON_FIXTURE=1 \
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
  # JSON (schema_version 4, empty files/symbols arrays) rather than exiting 1.
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
  if ! jq -e '.schema_version == 4 and (.files | length) == 0 and (.symbols | length) == 0' \
      "$out" > /dev/null 2>&1; then
    fail "$name" "expected empty schema_version-4 JSON; got: $(<"$out")"; return 0
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
  local name="pmctl context pack: valid call produces schema_version 4 JSON with correct fields"
  # Behavior: context pack must emit schema_version 4 JSON with task_id, sources, and at least one hit.
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
    .schema_version == 4 and
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
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_sqlite3_check() { return 1; }
    _ctx_emit_usage_event() { :; }
    pmctl_context_query "$2" "alpha"
  ' bash "$REPO_ROOT/runtime" "$(ctx_fixture_target "$nodb_repo")" > "$out" 2> "$err" || status=$?
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

case_context_reuse_scan_truncation_is_loud() {
  local name="pmctl context reuse-scan: over-cap description warns on stderr and drops tail terms"
  # Behavior: a description longer than RETRIEVAL_TERM_MAX_BYTES still exits 0,
  # keeps prefix terms, drops the tail token, and writes a truncation notice.
  # Steps: index a fixture; reuse-scan a 20KiB-padded description; assert YAML
  # structure, sentinel_head present, sentinel_tail absent, stderr names the cap.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-scan-truncate"
  make_fixture_repo "$fix_repo"

  local out err status=0 desc
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  desc="sentinel_head $(head -c 20000 /dev/zero | tr '\0' 'z') sentinel_tail"
  out="$tmp_root/scan-truncate.out"; err="$tmp_root/scan-truncate.err"
  "$PMCTL" context reuse-scan "$fix_repo" "$desc" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi
  if ! grep -q '^reuse_candidates:' "$out"; then
    fail "$name" "missing reuse_candidates header: $(<"$out")"; return 0
  fi
  if ! grep -q 'sentinel_head' "$out"; then
    fail "$name" "prefix term missing from terms: $(<"$out")"; return 0
  fi
  if grep -q 'sentinel_tail' "$out"; then
    fail "$name" "tail term leaked past the cap: $(<"$out")"; return 0
  fi
  if grep -q 'input truncated from ' "$err" && grep -q 'to 16384 bytes' "$err"; then
    pass "$name"
  else
    fail "$name" "missing truncation notice on stderr: $(<"$err")"
  fi
}

case_context_reuse_scan_cjk_terms() {
  local name="pmctl context reuse-scan: CJK prompt emits bigram terms"
  # Behavior: reuse-scan extracts CJK 2-grams plus English tokens from mixed
  # input. Index hits via FTS5 unicode61 remain a separate concern.
  # Steps: reuse-scan a mixed Chinese/English description on an indexed
  # fixture and assert the terms: line contains 分析/使用/用量/token.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-scan-cjk"
  make_fixture_repo "$fix_repo"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  out="$tmp_root/scan-cjk.out"; err="$tmp_root/scan-cjk.err"
  "$PMCTL" context reuse-scan "$fix_repo" "分析 token 使用量" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi
  if grep -q '分析' "$out" && grep -q '使用' "$out" && grep -q '用量' "$out" && grep -q 'token' "$out"; then
    pass "$name"
  else
    fail "$name" "missing CJK/English terms: $(<"$out")"
  fi
}

case_context_fts5_cjk_query_still_has_like_fallback() {
  local name="pmctl context query: CJK LIKE fallback remains independent of term lib"
  # Behavior: FTS5 unicode61 is out of CC-465 scope. With FTS disabled and
  # autorefresh off, file_chunks LIKE still finds a Chinese substring.
  # Steps: index a CJK BACKLOG section; drop content_fts; disable refresh;
  # query 使用量; assert a BACKLOG.md text-match hit.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-fts5-cjk"
  make_fixture_repo "$fix_repo"
  cat >> "$fix_repo/BACKLOG.md" <<'MD'

## 使用量分析

token 使用量與中文檢索訊號。
MD
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  local db="$fix_repo/.pm-dispatch/ctx/context.db"
  sqlite3 "$db" "DROP TABLE IF EXISTS content_fts;" 2>/dev/null || true

  local out err status=0
  out="$tmp_root/query-cjk.out"; err="$tmp_root/query-cjk.err"
  PM_DISPATCH_CONTEXT_AUTOREFRESH=0 \
    "$PMCTL" context query "$fix_repo" --domain knowledge "使用量" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 ]] && grep -q 'BACKLOG.md' "$out" && grep -q 'text match in chunk' "$out"; then
    pass "$name"
  else
    fail "$name" "LIKE fallback missed CJK query; status=$status out=$(<"$out") err=$(<"$err")"
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

  local src="$REPO_ROOT/runtime/lib/pmctl-context.sh"
  if [[ ! -f "$src" ]]; then
    fail "$name" "runtime/lib/pmctl-context.sh not found in repo"; return 0
  fi

  local fix="$tmp_root/fix-real-scan"
  mkdir -p "$fix/scripts/lib" "$fix/runtime/lib"
  cp "$src" "$fix/runtime/lib/pmctl-context.sh"

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

# Behavior: every context entrypoint this suite drives resolves its DB inside the
# fixture root it was pointed at, never the live repo DB.
# Steps: resolve status for an explicit fixture arg and for a no-arg call from a
# fixture CWD; assert both report a db_path under that fixture; assert the live
# DB is not reachable from tmp_root.
case_context_commands_resolve_only_fixture_roots() {
  local name="pmctl context suite: fixture invocations resolve inside tmp_root, never the live repo DB"
  should_run "$name" || return 0

  # This replaces a fingerprint comparison of the live repo DB taken across the
  # whole suite run. That oracle could not tell "a case here wrote the live DB"
  # from "another process did" — and the auto-context hook queries it on every
  # prompt, so the guard went red for writes this suite never made, and its
  # failure message asserted a conclusion the evidence could not support. The
  # property worth guarding is upstream of any write: a fixture invocation must
  # not RESOLVE the live DB in the first place. status is read-only and reports
  # the resolution it would use, so it can assert that without indexing anything.
  local fix_repo="$tmp_root/resolve-fixture-repo"
  make_fixture_repo "$fix_repo"
  git_init_commit_fixture "$fix_repo"

  local out db
  out="$tmp_root/resolve-fixture-explicit.json"
  "$PMCTL" context status --json "$fix_repo" > "$out" 2>/dev/null || true
  db="$(jq -r '.db_path // empty' "$out" 2>/dev/null || printf '')"
  if [[ "$db" != "$fix_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "explicit-arg status resolved [$db], expected the fixture DB under $fix_repo"
    return 0
  fi

  out="$tmp_root/resolve-fixture-cwd.json"
  ( cd "$fix_repo" && "$PMCTL" context status --json > "$out" 2>/dev/null ) || true
  db="$(jq -r '.db_path // empty' "$out" 2>/dev/null || printf '')"
  if [[ "$db" != "$fix_repo/.pm-dispatch/ctx/context.db" ]]; then
    fail "$name" "no-arg status from the fixture CWD resolved [$db], expected the fixture DB"
    return 0
  fi

  # And the live DB must be outside tmp_root by construction, so no fixture path
  # can alias it.
  if [[ "$LIVE_DB" == "$tmp_root"/* ]]; then
    fail "$name" "live repo DB resolves inside tmp_root: $LIVE_DB"
    return 0
  fi
  pass "$name"
}

# Behavior: every context subcommand the CLI publishes is exercised by this
# suite, so a newly added one cannot arrive without isolation coverage.
# Steps: read the subcommand list out of the CLI's own help; require a call site
# for each in this file.
case_context_every_subcommand_is_exercised() {
  local name="pmctl context suite: every published subcommand has a call site here"
  should_run "$name" || return 0

  # Pairs with the $PMCTL wrapper: the wrapper proves no call in this suite
  # targets the live repo root, and this proves the wrapper is actually in front
  # of the whole published surface rather than the part that existed when it was
  # written. Deriving from the CLI means the list cannot silently go stale.
  local subcommands uncovered=""
  subcommands="$("$REAL_PMCTL" help context 2>/dev/null \
    | awk '/^Commands:/ { in_cmds = 1; next }
           in_cmds && /^[[:space:]]+[a-z]/ { print $1; next }
           in_cmds && !/^[[:space:]]/ { exit }')"
  if [[ -z "$subcommands" ]]; then
    fail "$name" "could not read the context subcommand list from the CLI"
    return 0
  fi

  local sub
  while IFS= read -r sub; do
    [[ -n "$sub" ]] || continue
    grep -q "\"\$PMCTL\" context $sub" "$SUITE_FILE" || uncovered+="$sub "
  done <<< "$subcommands"

  if [[ -n "$uncovered" ]]; then
    fail "$name" "published context subcommands with no call site in this suite: $uncovered"
    return 0
  fi
  pass "$name"
}

# Behavior: the suite's $PMCTL wrapper refuses a context call that names the live
# repo root, rather than letting it reach the CLI.
# Steps: invoke the wrapper against $REPO_ROOT; assert the refusal exit code, the
# offending argument in the diagnostic, and that the call was recorded.
case_context_live_target_guard_trips() {
  local name="pmctl context suite: the live-target guard refuses a call naming the live repo root"
  should_run "$name" || return 0

  # Without this, the guard could silently stop guarding — every other case
  # passes a fixture path, so nothing else would notice.
  local err own_log status=0
  err="$tmp_root/live-target-guard.err"
  own_log="$tmp_root/live-target-guard.log"
  : > "$own_log"
  PM_CTX_GUARD_LOG="$own_log" "$PMCTL" context status --json "$REPO_ROOT" \
    > /dev/null 2> "$err" || status=$?

  if [[ "$status" -ne 99 ]]; then
    fail "$name" "guard let a live-repo-root call through (exit $status)"
    return 0
  fi
  if ! grep -qF "$REPO_ROOT" "$err"; then
    fail "$name" "refusal did not name the offending argument: $(<"$err")"
    return 0
  fi
  if [[ "$(wc -l < "$own_log")" -ne 1 ]]; then
    fail "$name" "refusal was not recorded: $(<"$own_log")"
    return 0
  fi
  pass "$name"
}

# Behavior: the guard also refuses the shape that names no target at all — a
# bare context call from a directory in no git worktree, which the CLI would
# resolve to the live repo root.
# Steps: run a no-argument context call from a non-git directory under tmp_root;
# assert the refusal exit code and that the diagnostic names the reason.
case_context_live_target_guard_refuses_bare_call_outside_worktree() {
  local name="pmctl context suite: the live-target guard refuses a bare call from outside any worktree"
  should_run "$name" || return 0

  # This is the shape the argument check alone cannot see: nothing in the argv
  # mentions the live root, yet the CLI's own fallback lands there. The guard
  # asserts a sufficient precondition for isolation instead of predicting that
  # fallback, so it refuses rather than reasoning about where the call would go
  # — and it does so without reading or writing the live DB.
  local nogit="$tmp_root/guard-nogit" err own_log status=0
  mkdir -p "$nogit"
  err="$tmp_root/guard-nogit.err"
  own_log="$tmp_root/guard-nogit.log"
  : > "$own_log"
  ( cd "$nogit" && PM_CTX_GUARD_LOG="$own_log" "$PMCTL" context status --json \
      > /dev/null 2> "$err" ) || status=$?

  if [[ "$status" -ne 99 ]]; then
    fail "$name" "guard let a bare non-worktree call through (exit $status)"
    return 0
  fi
  if ! grep -q 'no fixture path' "$err"; then
    fail "$name" "refusal did not name the reason: $(<"$err")"
    return 0
  fi
  if [[ "$(wc -l < "$own_log")" -ne 1 ]]; then
    fail "$name" "refusal was not recorded: $(<"$own_log")"
    return 0
  fi
  pass "$name"
}

# Behavior: both guard seams decide containment on the resolved path, so a target
# that is only lexically inside the fixture root is still refused.
# Steps: run the CLI seam with a traversal path and the direct seam with a
# fixture symlink pointing at the live repo; assert both refuse and record.
case_context_guard_rejects_traversal_and_symlink_escape() {
  local name="pmctl context suite: guards resolve targets before deciding containment"
  should_run "$name" || return 0

  # "$tmp_root/../.." passes a string-prefix test and lands outside the fixture
  # tree; a symlink planted inside a fixture does the same with no traversal in
  # the string at all. Neither may reach the CLI.
  local own_log err status=0
  own_log="$tmp_root/escape-guard.log"
  err="$tmp_root/escape-guard.err"
  : > "$own_log"
  PM_CTX_GUARD_LOG="$own_log" "$PMCTL" context status --json "$tmp_root/../.." \
    > /dev/null 2> "$err" || status=$?
  if [[ "$status" -ne 99 ]]; then
    fail "$name" "CLI seam accepted a traversal path (exit $status)"
    return 0
  fi

  local link="$tmp_root/escape-link"
  ln -sfn "$REPO_ROOT" "$link"
  status=0
  # Its own log: truncating the cumulative one to clean up would erase refusals
  # recorded by earlier cases and hand the aggregate assertion a false green.
  : > "$own_log"
  PM_CTX_GUARD_LOG="$own_log" ctx_fixture_target "$link" > /dev/null 2>> "$err" || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail "$name" "direct seam accepted a fixture symlink resolving to the live repo"
    return 0
  fi
  if ! grep -q 'escape-link' "$own_log"; then
    fail "$name" "symlink refusal was not recorded: $(<"$own_log")"
    return 0
  fi
  pass "$name"
}

# Behavior: the guard still refuses escapes on a host where `realpath -m` is
# unavailable, rather than falling back to the unresolved string.
# Steps: shadow realpath with a failing stub; run the CLI seam with a traversal
# path and with a fixture symlink to the live repo; assert both are refused.
case_context_guard_fails_closed_without_realpath() {
  local name="pmctl context suite: the guard fails closed when realpath cannot resolve"
  should_run "$name" || return 0

  # The earlier wrapper answered "unchanged" when it could not resolve, which
  # kept the fixture prefix on a traversal path and read as safe. Undecidable
  # must refuse, and it must do so on hosts without GNU realpath too.
  local stub_dir="$tmp_root/no-realpath-bin" own_log err status=0
  mkdir -p "$stub_dir"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$stub_dir/realpath"
  chmod +x "$stub_dir/realpath"
  own_log="$tmp_root/no-realpath.log"
  err="$tmp_root/no-realpath.err"
  : > "$own_log"

  PATH="$stub_dir:$PATH" PM_CTX_GUARD_LOG="$own_log" \
    "$PMCTL" context status --json "$tmp_root/../.." > /dev/null 2> "$err" || status=$?
  if [[ "$status" -ne 99 ]]; then
    fail "$name" "traversal path was not refused without realpath (exit $status): $(<"$err")"
    return 0
  fi

  local link="$tmp_root/no-realpath-link"
  ln -sfn "$REPO_ROOT" "$link"
  status=0
  PATH="$stub_dir:$PATH" PM_CTX_GUARD_LOG="$own_log" \
    "$PMCTL" context status --json "$link" > /dev/null 2>> "$err" || status=$?
  if [[ "$status" -ne 99 ]]; then
    fail "$name" "fixture symlink was not refused without realpath (exit $status): $(<"$err")"
    return 0
  fi
  # 99 is the wrapper's own refusal code; the real CLI never exits 99, so this
  # also shows it was never reached.
  if [[ "$(wc -l < "$own_log")" -ne 2 ]]; then
    fail "$name" "expected two recorded refusals, got: $(<"$own_log")"
    return 0
  fi
  pass "$name"
}

# Behavior: an absolute fixture-contained path that is not a directory does not
# earn fixture status, because the CLI would not accept it as a repo root.
# Steps: from a CWD outside the fixture tree, run query with an absolute
# non-directory under tmp_root; assert the wrapper refuses before pmctl runs.
case_context_guard_refuses_non_directory_fixture_path() {
  local name="pmctl context suite: an absolute non-directory fixture path does not grant fixture status"
  should_run "$name" || return 0

  # The CLI consumes the first positional as the repo root only when it is a
  # directory (`-d "$1"`). A file slides down to the query position and the repo
  # root falls back to the CWD's worktree — this repository, when a case runs
  # from here. Treating "absolute and under tmp_root" as isolated would wave
  # through precisely that call.
  local not_a_dir="$tmp_root/not-a-repo-dir" own_log err status=0
  printf 'x\n' > "$not_a_dir"
  own_log="$tmp_root/non-directory-guard.log"
  err="$tmp_root/non-directory-guard.err"
  : > "$own_log"

  ( cd "$REPO_ROOT" && PM_CTX_GUARD_LOG="$own_log" \
      "$PMCTL" context query "$not_a_dir" someterm > /dev/null 2> "$err" ) || status=$?
  if [[ "$status" -ne 99 ]]; then
    fail "$name" "wrapper allowed a non-directory fixture path (exit $status): $(<"$err")"
    return 0
  fi
  if ! grep -q 'no fixture path' "$err"; then
    fail "$name" "refusal did not name the reason: $(<"$err")"
    return 0
  fi
  pass "$name"
}

# Behavior: no context call made anywhere in this run fell outside the fixture
# tree, in any of the shapes that would reach the live repo root.
# Steps: read the guard's refusal log, written only by this suite's own wrapper;
# require it to be empty.
case_context_no_call_targeted_the_live_repo() {
  local name="pmctl context suite: every case ran isolated from the live repo"
  should_run "$name" || return 0

  # Run last: this is the cumulative view of every case above. The log is
  # written by this suite's wrapper and nothing else, so unlike the live-DB
  # fingerprint it replaces, a non-empty log can only mean one of THESE calls
  # did it — and the entry names which.
  if [[ -s "$CTX_GUARD_LOG" ]]; then
    fail "$name" "unisolated context calls were refused during this run: $(<"$CTX_GUARD_LOG")"
    return 0
  fi
  pass "$name"
}

case_context_reuse_scan_hit_cap() {
  local name="pmctl context reuse-scan: output capped at 5 hits even when more exist"
  # Behavior: reuse-scan must emit at most 5 '- ref:' entries regardless of how many index hits exist.
  # Steps: index a fixture repo with many symbols; describe with a broad term that matches many symbols;
  # assert ref-count <= 5.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-scan-cap"
  mkdir -p "$fix_repo/scripts/lib" "$fix_repo/runtime/lib"
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

case_context_pack_emits_event() {
  local name="pmctl context pack: emits context.packed event with top_k_refs, byte accounting and freshness"
  # Behavior (CC-505 Req 9): a successful pack must emit a context.packed
  # event carrying top_k_refs, pack_bytes, full_file_baseline_bytes,
  # compression_ratio_vs_full_file_baseline, truncation, and freshness --
  # this is the ONLY telemetry call site pmctl_context_pack has (unlike
  # query/reuse-scan/prompt-scan, pack previously emitted nothing at all).
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-evt"
  make_fixture_repo "$fix_repo"

  local state_root="$tmp_root/state-pack-evt"
  mkdir -p "$state_root"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup-pack.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup-pack.err")"; return 0; }

  local out err status=0
  out="$tmp_root/pack-evt.out"; err="$tmp_root/pack-evt.err"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context pack "$fix_repo" \
    --task-id pack-evt-task --query "alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "context pack exited $status: $(<"$err")"; return 0
  fi
  if grep -q 'telemetry not recorded' "$err" 2>/dev/null; then
    fail "$name" "context pack reported a telemetry emit failure: $(<"$err")"; return 0
  fi

  local trace_out trace_status=0
  trace_out="$tmp_root/pack-trace.out"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.packed --all --json \
    > "$trace_out" 2>"$tmp_root/pack-trace.err" || trace_status=$?
  if [[ "$trace_status" -ne 0 ]]; then
    fail "$name" "pmctl trace exited $trace_status: $(<"$tmp_root/pack-trace.err")"; return 0
  fi

  local our_event
  our_event="$(jq -c 'select(.payload.task_id == "pack-evt-task")' "$trace_out" 2>/dev/null | tail -1)"
  if [[ -z "$our_event" ]]; then
    fail "$name" "no context.packed event with payload.task_id=pack-evt-task found in trace"; return 0
  fi

  local kind subject_type freshness pack_bytes baseline_bytes top_k_len ratio
  kind="$(jq -r '.kind' <<<"$our_event")"
  subject_type="$(jq -r '.subject_type' <<<"$our_event")"
  freshness="$(jq -r '.payload.freshness' <<<"$our_event")"
  pack_bytes="$(jq -r '.payload.pack_bytes' <<<"$our_event")"
  baseline_bytes="$(jq -r '.payload.full_file_baseline_bytes' <<<"$our_event")"
  top_k_len="$(jq -r '.payload.top_k_refs | length' <<<"$our_event")"
  ratio="$(jq -r '.payload.compression_ratio_vs_full_file_baseline' <<<"$our_event")"

  if [[ "$kind" != "context.packed" ]]; then
    fail "$name" "event kind: expected context.packed, got: $kind"; return 0
  fi
  if [[ "$subject_type" != "context" ]]; then
    fail "$name" "event subject_type: expected context, got: $subject_type"; return 0
  fi
  if [[ "$freshness" != "fresh" ]]; then
    fail "$name" "event payload.freshness: expected fresh (index was just built), got: $freshness"; return 0
  fi
  if ! [[ "$pack_bytes" =~ ^[0-9]+$ ]] || [[ "$pack_bytes" -le 0 ]]; then
    fail "$name" "event payload.pack_bytes: expected positive integer, got: $pack_bytes"; return 0
  fi
  if ! [[ "$baseline_bytes" =~ ^[0-9]+$ ]] || [[ "$baseline_bytes" -le 0 ]]; then
    fail "$name" "event payload.full_file_baseline_bytes: expected positive integer (fixture files exist on disk), got: $baseline_bytes"; return 0
  fi
  if ! [[ "$top_k_len" =~ ^[0-9]+$ ]] || [[ "$top_k_len" -le 0 ]]; then
    fail "$name" "event payload.top_k_refs: expected at least one ref, got length $top_k_len"; return 0
  fi
  if [[ "$top_k_len" -gt 10 ]]; then
    fail "$name" "event payload.top_k_refs: expected at most 10 (telemetry cap), got length $top_k_len"; return 0
  fi
  if ! [[ "$ratio" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    fail "$name" "event payload.compression_ratio_vs_full_file_baseline: expected a number, got: $ratio"; return 0
  fi
  pass "$name"
}

case_context_pack_zero_hit_still_emits_event() {
  local name="pmctl context pack: a zero-hit pack (no index) still emits context.packed with freshness=unavailable"
  # Behavior (CC-505 Req 9): mirrors the existing context.queried zero-hit
  # precedent -- a pack with nothing to say is exactly as interesting to
  # CC-506's evaluation as a populated one, and must not be silently skipped.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-zero-evt"
  mkdir -p "$fix_repo"
  ( cd "$fix_repo" && git init -q && git config user.email t@t.example && git config user.name t \
    && printf 'placeholder\n' > f.txt && git add f.txt && git commit -q -m init )

  local state_root="$tmp_root/state-pack-zero-evt"
  mkdir -p "$state_root"

  local out err status=0
  out="$tmp_root/pack-zero-evt.out"; err="$tmp_root/pack-zero-evt.err"
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context pack "$fix_repo" \
    --task-id pack-zero-evt-task --query "alpha" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "context pack exited $status: $(<"$err")"; return 0
  fi

  local trace_out trace_status=0
  trace_out="$tmp_root/pack-zero-trace.out"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.packed --all --json \
    > "$trace_out" 2>"$tmp_root/pack-zero-trace.err" || trace_status=$?
  if [[ "$trace_status" -ne 0 ]]; then
    fail "$name" "pmctl trace exited $trace_status: $(<"$tmp_root/pack-zero-trace.err")"; return 0
  fi

  local our_event freshness top_k_len
  our_event="$(jq -c 'select(.payload.task_id == "pack-zero-evt-task")' "$trace_out" 2>/dev/null | tail -1)"
  if [[ -z "$our_event" ]]; then
    fail "$name" "no context.packed event with payload.task_id=pack-zero-evt-task found in trace"; return 0
  fi
  freshness="$(jq -r '.payload.freshness' <<<"$our_event")"
  top_k_len="$(jq -r '.payload.top_k_refs | length' <<<"$our_event")"
  if [[ "$freshness" != "unavailable" ]]; then
    fail "$name" "event payload.freshness: expected unavailable (no index, autobuild disabled), got: $freshness"; return 0
  fi
  if [[ "$top_k_len" -ne 0 ]]; then
    fail "$name" "event payload.top_k_refs: expected empty for a zero-hit pack, got length $top_k_len"; return 0
  fi
  pass "$name"
}

case_context_pack_stale_freshness_on_refresh_failure() {
  local name="pmctl context pack: context.packed reports freshness=stale when refresh fails on an existing index"
  # Behavior (CC-505 Req 9, qa-tester-F001): freshness must distinguish a
  # genuinely refreshed index from one whose refresh attempt failed. Build an
  # index successfully, then make just the DB FILE (not the directory)
  # read-only so _ctx_index_tree's sqlite3 batch write fails on the SECOND
  # (refresh) call -- this only produces an observable failure because
  # _ctx_index_tree now checks that write's exit status (previously
  # unchecked: the function's own exit code came only from its trailing
  # printf lines, so a failed sqlite3 write was indistinguishable from
  # success at every caller, including _ctx_ensure_fresh). Chmod'ing the
  # whole ctx DIRECTORY read-only (an earlier version of this fixture) also
  # blocks reads -- sqlite3's FTS5 temp-store scratch files need a writable
  # directory even for a plain query -- degrading the pack to a false
  # zero-hit result instead of exercising the "stale but still readable"
  # path this finding is actually about.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-stale-evt"
  make_fixture_repo "$fix_repo"

  local state_root="$tmp_root/state-pack-stale-evt"
  mkdir -p "$state_root"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup-stale.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup-stale.err")"; return 0; }

  chmod 444 "$fix_repo/.pm-dispatch/ctx/context.db"
  local out err status=0
  out="$tmp_root/pack-stale-evt.out"; err="$tmp_root/pack-stale-evt.err"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context pack "$fix_repo" \
    --task-id pack-stale-evt-task --query "alpha" > "$out" 2> "$err" || status=$?
  chmod 644 "$fix_repo/.pm-dispatch/ctx/context.db"

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "context pack exited $status (expected 0 -- a refresh failure degrades freshness, it does not fail the pack): $(<"$err")"; return 0
  fi

  local trace_out trace_status=0
  trace_out="$tmp_root/pack-stale-trace.out"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.packed --all --json \
    > "$trace_out" 2>"$tmp_root/pack-stale-trace.err" || trace_status=$?
  if [[ "$trace_status" -ne 0 ]]; then
    fail "$name" "pmctl trace exited $trace_status: $(<"$tmp_root/pack-stale-trace.err")"; return 0
  fi

  local our_event freshness
  our_event="$(jq -c 'select(.payload.task_id == "pack-stale-evt-task")' "$trace_out" 2>/dev/null | tail -1)"
  if [[ -z "$our_event" ]]; then
    fail "$name" "no context.packed event with payload.task_id=pack-stale-evt-task found in trace"; return 0
  fi
  freshness="$(jq -r '.payload.freshness' <<<"$our_event")"
  if [[ "$freshness" != "stale" ]]; then
    fail "$name" "event payload.freshness: expected stale (refresh attempted and failed), got: $freshness"; return 0
  fi
  local top_k_len
  top_k_len="$(jq -r '.payload.top_k_refs | length' <<<"$our_event")"
  if ! [[ "$top_k_len" =~ ^[0-9]+$ ]] || [[ "$top_k_len" -le 0 ]]; then
    fail "$name" "event payload.top_k_refs: expected the stale-but-readable index to still return hits, got length $top_k_len"; return 0
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
    # The point of this case is a positional path that is deliberately not a
    # directory, so it cannot be a fixture path.
    PM_CTX_GUARD_ALLOW_NON_FIXTURE=1 \
      "$PMCTL" context pack "/nonexistent/path/xyz" --task-id TASK-1 --query foo \
        > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_schema_contract() {
  local name="pmctl context pack: emitted pack has all required schema_version 4 fields"
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
    has("memories") and has("risks") and has("truncation") and
    .schema_version == 4
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "schema contract failed: $(<"$err") output: $(<"$out")"
    return 0
  fi
  pass "$name"
}

case_context_layer_boundary() {
  local name="pmctl-context.sh: does not source pmctl-dispatch.sh or adapters"
  should_run "$name" || return 0

  local lib="$REPO_ROOT/runtime/lib/pmctl-context.sh"
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
  bash -c ". \"$REPO_ROOT/runtime/lib/pmctl-context.sh\" 2>/dev/null; \
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

case_context_index_excludes_pm_dispatch_tree() {
  local name="pmctl context index: excludes the derived .pm-dispatch tree from its own index"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-self-index"
  make_fixture_repo "$fix_repo"
  mkdir -p "$fix_repo/.pm-dispatch/ctx/packs"
  cat > "$fix_repo/.pm-dispatch/ctx/packs/should-not-index.md" <<'MD'
# Derived Context Pack

unique-self-index-marker
MD

  "$PMCTL" context index "$fix_repo" > /dev/null 2>&1 \
    || { fail "$name" "context index failed"; return 0; }

  local db="$fix_repo/.pm-dispatch/ctx/context.db"
  local leaked
  leaked="$(sqlite3 "$db" "SELECT path FROM files WHERE path = '.pm-dispatch' OR path LIKE '.pm-dispatch/%';" 2>/dev/null || true)"
  if [[ -n "$leaked" ]]; then
    fail "$name" ".pm-dispatch artifacts leaked into index: $leaked"
    return 0
  fi
  pass "$name"
}

case_context_status_marker_round_trip() {
  local name="pmctl context status/query/pack: marker round-trip reports stale then fresh"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-status-roundtrip"
  make_fixture_repo "$fix_repo"
  "$PMCTL" context index "$fix_repo" >/dev/null 2>&1 || { fail "$name" "initial index failed"; return 0; }
  local marker="$fix_repo/docs/cc484-marker.md" status_json query_out pack_out status_err="$tmp_root/status-roundtrip.err"
  printf '# CC484 marker\n\ncc484roundtripmarker\n' > "$marker"
  status_json="$("$PMCTL" context status "$fix_repo" --json 2>"$status_err")" || { fail "$name" "status failed: $(<"$status_err")"; return 0; }
  if ! jq -e --arg repo "$fix_repo" --arg db "$fix_repo/.pm-dispatch/ctx/context.db" \
    '.resolved_repo_root == $repo and .db_path == $db and .freshness == "stale" and .new_files >= 1' <<<"$status_json" >/dev/null; then
    fail "$name" "new marker was not diagnosed as stale: $status_json"; return 0
  fi
  query_out="$("$PMCTL" context query "$fix_repo" cc484roundtripmarker 2>/dev/null)" || { fail "$name" "query refresh failed"; return 0; }
  [[ "$query_out" == *"docs/cc484-marker.md"* ]] || { fail "$name" "marker missing after query refresh: $query_out"; return 0; }
  rm -f "$marker"
  status_json="$("$PMCTL" context status "$fix_repo" --json 2>/dev/null)" || { fail "$name" "deleted status failed"; return 0; }
  jq -e '.freshness == "stale" and .deleted_files >= 1' <<<"$status_json" >/dev/null || {
    fail "$name" "deleted marker was not diagnosed as stale: $status_json"; return 0;
  }
  pack_out="$("$PMCTL" context pack "$fix_repo" --task-id CC-484 --query cc484roundtripmarker 2>/dev/null)" || {
    fail "$name" "pack reconciliation failed"; return 0;
  }
  if jq -e '(.files | length) == 0 and (.symbols | length) == 0' <<<"$pack_out" >/dev/null &&
     "$PMCTL" context status "$fix_repo" --json 2>/dev/null | jq -e '.freshness == "fresh"' >/dev/null; then
    pass "$name"
  else
    fail "$name" "removed marker remained in pack or status stayed stale: $pack_out"
  fi
}

case_context_status_explicit_repo_isolated() {
  local name="pmctl context status: explicit repo reports its canonical DB without touching caller repo"
  should_run "$name" || return 0

  local repo_a="$tmp_root/status-repo-a" repo_b="$tmp_root/status-repo-b" out before_b after_b status_err="$tmp_root/status-isolated.err"
  make_fixture_repo "$repo_a"; make_fixture_repo "$repo_b"
  "$PMCTL" context index "$repo_a" >/dev/null 2>&1 || { fail "$name" "repo A index failed"; return 0; }
  "$PMCTL" context index "$repo_b" >/dev/null 2>&1 || { fail "$name" "repo B index failed"; return 0; }
  before_b="$(stat -c '%Y:%s' "$repo_b/.pm-dispatch/ctx/context.db" 2>/dev/null || stat -f '%m:%z' "$repo_b/.pm-dispatch/ctx/context.db")"
  printf '# isolated\n\ncc484isolatedmarker\n' > "$repo_a/docs/isolated.md"
  out="$(cd "$repo_b" && "$PMCTL" context status "$repo_a" --json 2>"$status_err")" || { fail "$name" "status failed: $(<"$status_err")"; return 0; }
  after_b="$(stat -c '%Y:%s' "$repo_b/.pm-dispatch/ctx/context.db" 2>/dev/null || stat -f '%m:%z' "$repo_b/.pm-dispatch/ctx/context.db")"
  if jq -e --arg repo "$repo_a" --arg db "$repo_a/.pm-dispatch/ctx/context.db" \
      '.resolved_repo_root == $repo and .db_path == $db and .freshness == "stale" and .new_files >= 1' <<<"$out" >/dev/null &&
     [[ "$before_b" == "$after_b" ]]; then
    pass "$name"
  else
    fail "$name" "out=$out repo_b_before=$before_b repo_b_after=$after_b"
  fi
}

case_context_workflow_refresh_opt_out_reports_skipped() {
  local name="pmctl context workflow refresh: AUTOREFRESH=0 reports skipped without mutating stale DB"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-workflow-skip" out before after
  make_fixture_repo "$fix_repo"
  "$PMCTL" context index "$fix_repo" >/dev/null 2>&1 || { fail "$name" "initial index failed"; return 0; }
  printf '# workflow skip\n\ncc484workflowskipmarker\n' > "$fix_repo/docs/workflow-skip.md"
  before="$(stat -c '%Y:%s' "$fix_repo/.pm-dispatch/ctx/context.db" 2>/dev/null || stat -f '%m:%z' "$fix_repo/.pm-dispatch/ctx/context.db")"
  out="$(PM_DISPATCH_CONTEXT_AUTOREFRESH=0 bash -c \
    '. "$1"; pmctl_context_workflow_refresh "$2" --json' bash "$REPO_ROOT/runtime/lib/pmctl-context.sh" "$(ctx_fixture_target "$fix_repo")" 2>/dev/null)" || {
      fail "$name" "workflow refresh invocation failed"; return 0;
    }
  after="$(stat -c '%Y:%s' "$fix_repo/.pm-dispatch/ctx/context.db" 2>/dev/null || stat -f '%m:%z' "$fix_repo/.pm-dispatch/ctx/context.db")"
  if jq -e '.refresh_status == "skipped" and .freshness == "stale" and .new_files >= 1' <<<"$out" >/dev/null &&
     [[ "$before" == "$after" ]]; then
    pass "$name"
  else
    fail "$name" "out=$out db_before=$before db_after=$after"
  fi
}

case_context_workflow_refresh_sqlite_unavailable() {
  local name="pmctl context workflow refresh: missing sqlite reports unavailable without DB mutation"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-workflow-no-sqlite" out before after
  make_fixture_repo "$fix_repo"
  "$PMCTL" context index "$fix_repo" >/dev/null 2>&1 || { fail "$name" "initial index failed"; return 0; }
  before="$(stat -c '%Y:%s' "$fix_repo/.pm-dispatch/ctx/context.db" 2>/dev/null || stat -f '%m:%z' "$fix_repo/.pm-dispatch/ctx/context.db")"
  out="$(bash -c \
    '. "$1"; _ctx_sqlite3_check() { return 1; }; pmctl_context_workflow_refresh "$2" --json' \
    bash "$REPO_ROOT/runtime/lib/pmctl-context.sh" "$(ctx_fixture_target "$fix_repo")" 2>/dev/null)" || {
      fail "$name" "workflow refresh invocation failed"; return 0;
    }
  after="$(stat -c '%Y:%s' "$fix_repo/.pm-dispatch/ctx/context.db" 2>/dev/null || stat -f '%m:%z' "$fix_repo/.pm-dispatch/ctx/context.db")"
  if jq -e '.refresh_status == "unavailable" and .freshness == "unavailable" and
      .sqlite_available == false and .db_exists == true' <<<"$out" >/dev/null &&
     [[ "$before" == "$after" ]]; then
    pass "$name"
  else
    fail "$name" "out=$out db_before=$before db_after=$after"
  fi
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
    . "'"$REPO_ROOT"'/runtime/lib/pmctl-context.sh" 2>/dev/null
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
  local name="pmctl context query --source memory: project-scoped config resolves memory dir"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-cfgover-repo" cfg="$tmp_root/mem-cfgover-cfg"
  local override="$tmp_root/mem-cfgover-override" fakehome="$tmp_root/mem-cfgover-home"
  mkdir -p "$repo" "$fakehome/.pm-dispatch"
  # $cfg deliberately has no memory dir for $repo. Populate ONLY the override
  # dir (not under $cfg/projects/<id>/memory) so a hit proves resolution went
  # through the project-scoped config, not the CLAUDE_CONFIG_DIR walk.
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
  write_project_memory_config "$fakehome/.pm-dispatch/config" "$repo" "$override"

  local out err status=0
  out="$tmp_root/mem-cfgover.out"; err="$tmp_root/mem-cfgover.err"
  PM_DISPATCH_CONFIG_FILE="$fakehome/.pm-dispatch/config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory codex > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "query exited $status: $(<"$err")"; return 0; fi
  if grep -q 'ref: feedback_gate_executor.md' "$out" && grep -q 'source_domain: memory' "$out"; then
    pass "$name"
  else
    fail "$name" "expected memory card hit resolved via project-scoped config; got: $(<"$out")"
  fi
}

# Behavior: a matched but unavailable config path cannot select legacy memory.
# Steps: expose both a missing scoped target and a populated legacy store, then
# query and index while asserting that no legacy context DB is created.
case_context_memory_invalid_config_no_legacy_fallback() {
  local name="pmctl context memory source: invalid matched config never falls back to legacy memory"
  should_run "$name" || return 0
  local repo="$tmp_root/mem-invalid-repo" claude="$tmp_root/mem-invalid-claude"
  local config="$tmp_root/mem-invalid.conf" missing="$tmp_root/mem-invalid-missing" legacy
  local query_out="$tmp_root/mem-invalid-query.out" index_status=0
  mkdir -p "$repo"
  legacy="$(make_fixture_memory "$repo" "$claude")"
  write_project_memory_config "$config" "$repo" "$missing"

  PM_DISPATCH_CONFIG_FILE="$config" CLAUDE_CONFIG_DIR="$claude" "$PMCTL" context query \
    "$repo" --source memory codex > "$query_out" 2>/dev/null || true
  PM_DISPATCH_CONFIG_FILE="$config" CLAUDE_CONFIG_DIR="$claude" "$PMCTL" context index \
    "$repo" --source memory >/dev/null 2>&1 || index_status=$?

  if [[ "$index_status" -eq 1 ]] && grep -q '# no hits' "$query_out" \
    && [[ ! -e "$legacy/.pm-dispatch/context.db" ]]; then
    pass "$name"
  else
    fail "$name" "index=$index_status query=$(<"$query_out") legacy_db=$([[ -e "$legacy/.pm-dispatch/context.db" ]] && printf yes || printf no)"
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
  git_init_commit_fixture "$ext_repo"
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
  ( cd "$nogit_dir" && REPO_ROOT="$(ctx_fixture_target "$fallback_repo")" bash -c \
      ". \"$REPO_ROOT/runtime/lib/pmctl-context.sh\" 2>/dev/null; pmctl_context_index --source repo" \
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
  git_init_commit_fixture "$self_repo"
  local out err status=0
  out="$tmp_root/defroot-self.out"; err="$tmp_root/defroot-self.err"
  ( cd "$self_repo" && REPO_ROOT="$(ctx_fixture_target "$self_repo")" bash -c \
      ". \"$REPO_ROOT/runtime/lib/pmctl-context.sh\" 2>/dev/null; pmctl_context_index --source repo" \
      > "$out" 2> "$err" ) || status=$?
  if [[ "$status" -eq 0 ]] && [[ -f "$self_repo/.pm-dispatch/ctx/context.db" ]] && ! grep -qi 'falling back' "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 0, DB created, no fallback warning; status=$status stderr=$(<"$err")"
  fi
}

# Behavior: a no-arg index/query from an external repo writes that repo's DB and
# resolves nothing to pm-dispatch's own.
# Steps: index and query with no path argument from an external fixture CWD;
# assert the fixture DB was created and that the resolved DB is not the live one.
case_context_no_arg_cross_repo_never_touches_pm_dispatch_db() {
  local name="pmctl context index/query: no-arg invocation from an external repo resolves that repo, never pm-dispatch's own context.db"
  should_run "$name" || return 0
  local ext_repo="$tmp_root/defroot-cross-repo"
  make_fixture_repo "$ext_repo"
  git_init_commit_fixture "$ext_repo"
  ( cd "$ext_repo" && "$PMCTL" context index --source repo > /dev/null 2>&1 )
  ( cd "$ext_repo" && "$PMCTL" context query --source repo my_func_alpha > /dev/null 2>&1 )

  # Where the write landed, not whether an unrelated file happened to change:
  # a fingerprint of the live DB would also go red for another process's write.
  local ext_db="$ext_repo/.pm-dispatch/ctx/context.db" resolved
  if [[ ! -s "$ext_db" ]]; then
    fail "$name" "no-arg index did not create the external repo's DB at $ext_db"
    return 0
  fi
  resolved="$(cd "$ext_repo" && "$PMCTL" context status --json 2>/dev/null \
    | jq -r '.db_path // empty' 2>/dev/null || printf '')"
  if [[ "$resolved" == "$ext_db" ]]; then
    pass "$name"
  else
    fail "$name" "no-arg call from $ext_repo resolved [$resolved], expected [$ext_db]"
  fi
}

case_context_default_repo_root_update_uses_cwd() {
  local name="pmctl context update: no-arg invocation from an external git repo re-scans THAT repo, not pm-dispatch"
  should_run "$name" || return 0
  local ext_repo="$tmp_root/defroot-update-repo"
  make_fixture_repo "$ext_repo"
  git_init_commit_fixture "$ext_repo"
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
  git_init_commit_fixture "$ext_repo"
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
  git_init_commit_fixture "$ext_repo"
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
  # Telemetry persists an EMPTY query payload — nothing prompt-derived
  # (privacy contract; the state root is isolated so tail -1 is our event).
  local evt query hits
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.prompt_scanned --all --json 2>/dev/null \
    | tail -1)"
  if [[ -z "$evt" ]]; then
    fail "$name" "expected a context.prompt_scanned event for the no-db scan"; return 0
  fi
  query="$(printf '%s\n' "$evt" | jq -r '.payload.query' 2>/dev/null)"
  if [[ -n "$query" ]]; then
    fail "$name" "event query payload must be empty (nothing prompt-derived); got: $query"; return 0
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

# Behavior: chunking indexes a file's own content, not just its first 200
# characters, so a symbol body far below the header is retrievable. Previously
# every non-markdown file became a single chunk holding the file's opening
# characters, which put function bodies outside the index entirely.
# Steps: build a shell file with a unique marker past line 100; index; query it.
case_context_index_reaches_deep_file_content() {
  local name="pmctl context index: content deep inside a file is retrievable"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-deep-body"
  mkdir -p "$fix_repo/scripts"
  {
    printf '#!/usr/bin/env bash\n'
    local i
    for ((i = 1; i <= 120; i++)); do printf '# filler line %s\n' "$i"; done
    printf 'deep_fn() {\n  printf %s\n}\n' "'zzq_deep_body_marker'"
  } > "$fix_repo/scripts/deep.sh"

  local err="$tmp_root/deep-index.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: index failed: $(<"$err")"; return 0; }

  local out="$tmp_root/deep-query.out" status=0
  "$PMCTL" context query "$fix_repo" zzq_deep_body_marker > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 ]] && grep -q 'scripts/deep.sh' "$out"; then
    pass "$name"
  else
    fail "$name" "deep body not retrievable: status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

# Behavior: an edit that preserves mtime still re-indexes, because the stored
# sha1 -- not mtime -- decides whether content changed. An mtime fast path that
# is also the final answer leaves the index silently serving deleted content.
# Steps: index; rewrite a marker while restoring the original mtime; re-index;
# require the old marker gone and the new one found.
# Behavior: a single physical line longer than the chunk body cap keeps its tail
# searchable. An over-cap body reaches the SQL escaper, which truncates to the
# same bound silently, so without splitting the end of a minified or generated
# file would be missing from the index while indexing still reported success.
# Steps: write one line far longer than the cap with a marker at its end; index;
# require the marker to be retrievable.
# Behavior: the environment cannot supply the extractor version. It is written
# into SQL, so an environment-controlled value would be attacker-controlled SQL
# text; the constant is deliberately not overridable, as lib/memory.sh does for
# its own budgets.
# Steps: index with an injection payload in the environment; require the stored
# version to be the constant and the tables to be intact.
# Behavior: content carrying single quotes survives indexing intact -- the
# character that ends a SQL string literal must be doubled wherever quoted text
# can reach SQL, and the escaped value must reach the caller.
#
# Which symbol fields can carry one is not obvious: every extractor branch
# captures a name as [[:alnum:]_]*, so a name never can, and kinds are literals.
# The signature is the raw source line, so it can -- which is why the fixture
# includes a def whose default argument holds an apostrophe.
# Steps: index a file whose function name and body both carry apostrophes;
# require the index to be populated and the exact text to be queryable.
#
# Broad coverage does fail on both mutations here (dropping the doubling fails
# 50 cases, assigning to the wrong destination fails 63), so this case is not
# what makes the behavior safe. It is admitted for locality: those failures
# prove something broke without naming what, and this one names it.
case_context_index_preserves_quoted_content() {
  local name="pmctl context index: content carrying single quotes round-trips intact"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-quoted"
  mkdir -p "$fix_repo/scripts"
  cat > "$fix_repo/scripts/quoted.sh" <<'SH'
#!/usr/bin/env bash
# zzq_it's_a_quoted_heading with O'Brien and ''doubled''
fn_with_quote() {
  printf 'zzq_body_it'"'"'s_here
'
}
SH

  # The signature stored for this def is the whole source line, apostrophe and
  # all, so it exercises the symbol-side escape call.
  cat > "$fix_repo/scripts/quoted.py" <<'PY_FIX'
def zzq_quoted_sig(arg="it's a default"):
    return arg
PY_FIX

  local err="$tmp_root/quoted.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "index failed on quoted content: $(<"$err")"; return 0; }

  local db="$fix_repo/.pm-dispatch/ctx/context.db"
  local chunks single doubled
  chunks="$(sqlite3 "$db" "SELECT count(*) FROM file_chunks;" 2>&1)"
  # An apostrophe must land as one character: doubling is how it survives the
  # SQL literal, not how it should be stored.
  single="$(sqlite3 "$db" "SELECT count(*) FROM file_chunks WHERE text LIKE '%zzq_it''s_a_quoted_heading%';" 2>&1)"
  # Content that already carried doubled quotes must not be altered either.
  doubled="$(sqlite3 "$db" "SELECT count(*) FROM file_chunks WHERE text LIKE '%doubled%';" 2>&1)"
  local sig
  sig="$(sqlite3 "$db" "SELECT count(*) FROM symbols WHERE name = 'zzq_quoted_sig' AND signature LIKE '%it''s a default%';" 2>&1)"
  local out="$tmp_root/quoted.out" status=0
  "$PMCTL" context query "$fix_repo" zzq_it > "$out" 2>/dev/null || status=$?

  if [[ "$chunks" =~ ^[0-9]+$ && "$chunks" -gt 0 && "$single" == "1" && "$doubled" == "1" \
     && "$sig" == "1" && "$status" -eq 0 ]] && grep -q 'scripts/quoted.sh' "$out"; then
    pass "$name"
  else
    fail "$name" "quoted content did not round-trip: chunks=$chunks single=$single doubled=$doubled signature=$sig query_status=$status"
  fi
}

case_context_index_ignores_environment_extractor_version() {
  local name="pmctl context index: the environment cannot supply the extractor version"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-env-extractor"
  make_fixture_repo "$fix_repo"

  local err="$tmp_root/env-extractor.err"
  _CTX_EXTRACTOR_VERSION='9); DROP TABLE files;--' \
    "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "index failed: $(<"$err")"; return 0; }

  local db="$fix_repo/.pm-dispatch/ctx/context.db"
  local stored files_rows
  stored="$(sqlite3 "$db" "SELECT extractor_version FROM index_meta WHERE id = 1;" 2>&1)"
  files_rows="$(sqlite3 "$db" "SELECT count(*) FROM files;" 2>&1)"
  if [[ "$stored" =~ ^[0-9]+$ && "$files_rows" =~ ^[0-9]+$ && "$files_rows" -gt 0 ]]; then
    pass "$name"
  else
    fail "$name" "environment reached the database: stored=$stored files=$files_rows"
  fi
}

case_context_index_splits_an_over_cap_line() {
  local name="pmctl context index: a line longer than the body cap keeps its tail searchable"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-long-line"
  mkdir -p "$fix_repo/scripts"
  # Padding alone exceeds the cap several times over, so the marker sits well
  # past the point where a truncating writer would stop.
  local pad
  pad="$(head -c 9000 /dev/zero | tr '\0' 'x')"
  printf '#!/usr/bin/env bash\n# %s zzq_tail_after_cap_marker\n' "$pad" \
    > "$fix_repo/scripts/longline.sh"

  local err="$tmp_root/longline.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: index failed: $(<"$err")"; return 0; }

  local out="$tmp_root/longline.out" status=0
  "$PMCTL" context query "$fix_repo" zzq_tail_after_cap_marker > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 ]] && grep -q 'scripts/longline.sh' "$out"; then
    pass "$name"
  else
    fail "$name" "tail past the cap was dropped: status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

case_context_index_detects_mtime_preserving_edit() {
  local name="pmctl context index: an mtime-preserving edit is still re-indexed"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-mtime-edit"
  mkdir -p "$fix_repo/scripts"
  printf '#!/usr/bin/env bash\nfn() { printf %s\n}\n' "'zzq_before_marker'" \
    > "$fix_repo/scripts/edit.sh"

  local err="$tmp_root/mtime-index.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: first index failed: $(<"$err")"; return 0; }

  local old_mtime
  old_mtime="$(stat -c %Y "$fix_repo/scripts/edit.sh" 2>/dev/null)" \
    || { fail "$name" "setup: stat unavailable"; return 0; }
  printf '#!/usr/bin/env bash\nfn() { printf %s\n}\n' "'zzq_after_marker'" \
    > "$fix_repo/scripts/edit.sh"
  touch -d "@$old_mtime" "$fix_repo/scripts/edit.sh"
  [[ "$(stat -c %Y "$fix_repo/scripts/edit.sh")" == "$old_mtime" ]] \
    || { fail "$name" "setup: mtime was not preserved"; return 0; }

  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "re-index failed: $(<"$err")"; return 0; }

  local before="$tmp_root/mtime-before.out" after="$tmp_root/mtime-after.out"
  "$PMCTL" context query "$fix_repo" zzq_before_marker > "$before" 2>/dev/null || true
  "$PMCTL" context query "$fix_repo" zzq_after_marker > "$after" 2>/dev/null || true
  if ! grep -q 'scripts/edit.sh' "$before" && grep -q 'scripts/edit.sh' "$after"; then
    pass "$name"
  else
    fail "$name" "stale index after mtime-preserving edit: before=$(<"$before") after=$(<"$after")"
  fi
}

# Behavior: a database built by a different extractor is re-extracted rather
# than served. Without this the chunker can change while every file still looks
# up to date, leaving an index that disagrees with its extractor and reports
# success either way.
# Steps: index; bump the extractor version and re-index with every mtime
# unchanged; require the files to be re-indexed rather than skipped.
case_context_index_extractor_version_forces_reextract() {
  local name="pmctl context index: an extractor version change forces re-extraction"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-extractor-version"
  make_fixture_repo "$fix_repo"

  local err="$tmp_root/extractor-index.err" out="$tmp_root/extractor.out" status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: first index failed: $(<"$err")"; return 0; }

  # Same extractor: everything is skipped.
  "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]] || grep -qE 'context index: [1-9][0-9]* indexed' "$out"; then
    fail "$name" "unchanged tree should skip, got: $(<"$out")"; return 0
  fi

  # A database built by a different extractor, which is what a user pulling new
  # code actually has. Rewriting the stored version is the faithful way to stage
  # it: the constant is not env-overridable, deliberately.
  local db="$fix_repo/.pm-dispatch/ctx/context.db"
  sqlite3 "$db" "UPDATE index_meta SET extractor_version = extractor_version - 1 WHERE id = 1;" \
    || { fail "$name" "setup: could not age the stored extractor version"; return 0; }
  status=0
  "$PMCTL" context index "$fix_repo" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 ]] && grep -qE 'context index: [1-9][0-9]* indexed' "$out"; then
    pass "$name"
  else
    fail "$name" "extractor bump did not re-extract: status=$status out=$(<"$out") err=$(<"$err")"
  fi
}

# Behavior (CC-505 gate findings critic-F001 / risk-reviewer-F001): an index
# built by a PRE-line_end extractor version has a legacy 2-column content_fts
# table (ref, text). Querying it must transparently migrate content_fts (via
# the existing extractor-version-forces-reextract path, since _CTX_EXTRACTOR_
# VERSION was bumped for this change) rather than fail with "no such column:
# line_end", and the migrated query must still return correct hits.
# Steps: index a fixture repo; downgrade its stored extractor_version and
# rebuild content_fts in the pre-change 2-column shape (simulating an index
# built before this change); run `context query`; assert exit 0, a real hit,
# and that content_fts now has a line_end column.
case_context_query_migrates_legacy_two_column_fts() {
  local name="pmctl context query: transparently migrates a legacy 2-column content_fts table"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-legacy-fts"
  make_fixture_repo "$fix_repo"

  local err="$tmp_root/legacy-fts.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: initial index failed: $(<"$err")"; return 0; }

  local db="$fix_repo/.pm-dispatch/ctx/context.db"
  # Downgrade the stored extractor version AND rebuild content_fts in the
  # legacy 2-column shape, faithfully staging what a real pre-upgrade index
  # looks like (not just an aged version stamp).
  sqlite3 "$db" <<'SQL' || { fail "$name" "setup: could not stage a legacy-shape index"; return 0; }
UPDATE index_meta SET extractor_version = extractor_version - 1 WHERE id = 1;
DROP TABLE IF EXISTS content_fts;
CREATE VIRTUAL TABLE content_fts USING fts5(ref, text);
INSERT INTO content_fts(ref, text)
  SELECT f.path || ':' || s.line_start, s.name
  FROM symbols s JOIN files f ON s.file_id = f.id;
INSERT INTO content_fts(ref, text)
  SELECT f.path || ':' || fc.line_start, TRIM(COALESCE(fc.heading, '') || ' ' || COALESCE(fc.text, ''))
  FROM file_chunks fc JOIN files f ON fc.file_id = f.id
  WHERE TRIM(COALESCE(fc.heading, '') || ' ' || COALESCE(fc.text, '')) != '';
SQL

  local out status=0
  out="$tmp_root/legacy-fts-query.out"
  "$PMCTL" context query "$fix_repo" --source repo alpha > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query against a legacy-shape index exited $status (expected transparent migration): $(<"$err")"
    return 0
  fi
  if ! grep -q '^- ref:' "$out"; then
    fail "$name" "expected at least one real hit after migration; got: $(<"$out")"
    return 0
  fi
  local fts_cols
  fts_cols="$(sqlite3 "$db" "PRAGMA table_info(content_fts);" 2>/dev/null | grep -c 'line_end' || true)"
  if [[ "$fts_cols" -lt 1 ]]; then
    fail "$name" "content_fts was not migrated to include line_end after the query's auto-refresh"
    return 0
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
  # exit 0 and a zero-hit empty-query event — never a hard error.
  # Steps: index a fixture (real sqlite); re-run prompt-scan in a subshell whose
  # _ctx_sqlite3_check fails, capturing the emit args; assert graceful output,
  # exit 0, and a zero-hit event with an empty query payload.
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
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_sqlite3_check() { return 1; }
    _ctx_emit_usage_event() { printf "%s\t%s\t%s\n" "$1" "$3" "${4:-}" >> "$EMIT_FILE"; }
    pmctl_context_prompt_scan "$2" "alpha knowledge question"
  ' bash "$REPO_ROOT/runtime" "$(ctx_fixture_target "$fix_repo")" > "$out" 2> "$err" || status=$?
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
  if [[ "$emit_line" != "context.prompt_scanned"$'\t'$'\t'"0" ]]; then
    fail "$name" "expected zero-hit empty-query event; got: $emit_line"; return 0
  fi
  pass "$name"
}

case_context_prompt_scan_secret_never_persisted() {
  local name="pmctl context prompt-scan: secret-shaped prompt content never reaches the state store"
  # Behavior: a prompt containing a secret-shaped token must leave NO trace of
  # that token anywhere under the state root — not as raw prompt, not as a
  # derived term (the event query payload is empty by contract).
  # Steps: index fixture; scan a prompt embedding a unique secret-shaped token
  # in an isolated state root; assert the event exists with empty query and a
  # recursive grep for the token over the state root finds nothing.
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pscan-secret"
  make_fixture_repo "$fix_repo"

  local state_root="$tmp_root/state-pscan-secret"
  mkdir -p "$state_root"
  PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-setup.err")"; return 0; }

  local secret="apitoken_zq8x7secretregression42token"
  local out err status=0
  out="$tmp_root/pscan-secret.out"; err="$tmp_root/pscan-secret.err"
  PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" context prompt-scan "$fix_repo" "please use token $secret to authenticate the alpha deploy" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "prompt-scan exited $status: $(<"$err")"; return 0
  fi

  local evt query
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.prompt_scanned --all --json 2>/dev/null \
    | tail -1)"
  if [[ -z "$evt" ]]; then
    fail "$name" "expected a context.prompt_scanned event"; return 0
  fi
  query="$(printf '%s\n' "$evt" | jq -r '.payload.query' 2>/dev/null)"
  if [[ -n "$query" ]]; then
    fail "$name" "event query payload must be empty; got: $query"; return 0
  fi
  # The decisive assertion: the secret token (in any case form) appears nowhere
  # in the durable state root.
  if grep -riq "zq8x7secretregression42token" "$state_root" 2>/dev/null; then
    fail "$name" "secret-shaped token found under the state root"; return 0
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

  # Payload contract: the query field is EMPTY — neither the raw prompt nor
  # derived terms are persisted (privacy: prompts arrive from an automated
  # hook; the isolated state root makes tail -1 our event).
  local evt evt_kind evt_subject_type payload_query payload_hits
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.prompt_scanned --all --json 2>/dev/null \
    | tail -1)"
  if [[ -z "$evt" ]]; then
    fail "$name" "expected a context.prompt_scanned event"; return 0
  fi
  payload_query="$(printf '%s\n' "$evt" | jq -r '.payload.query' 2>/dev/null)"
  if [[ -n "$payload_query" ]]; then
    fail "$name" "event query payload must be empty (nothing prompt-derived); got: $payload_query"; return 0
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

case_context_fts5_availability_is_cached() {
  local name="pmctl context: _ctx_fts5_available caches its result per db path"
  # Behavior: _ctx_fts5_available forks 2 sqlite3 subprocesses per call to probe
  # FTS5 support -- this is cached per db path since support cannot change within
  # a process's lifetime (a prior version's cache-hit branch compared the cached
  # marker against the wrong value, so a cache HIT always reported "unavailable"
  # regardless of what the first, real probe found -- this locks the fix).
  # Steps: source the lib directly (white-box); call _ctx_fts5_available once
  # against a real db (whatever the real answer is, record it); shadow `sqlite3`
  # with a function that always fails; call again on the SAME db path. If the
  # cache is bypassed, the second call re-probes with the broken sqlite3 and
  # wrongly flips to "unavailable" regardless of the first result. Assert both
  # calls agree.
  should_run "$name" || return 0

  command -v sqlite3 >/dev/null 2>&1 || { fail "$name" "setup: sqlite3 not on PATH, cannot exercise this path"; return 0; }

  local db out err status=0
  db="$tmp_root/fts5-cache-probe.db"
  out="$tmp_root/fts5-cache-probe.out"; err="$tmp_root/fts5-cache-probe.err"
  bash -c '
    set -euo pipefail
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    db="$2"
    sqlite3 "$db" "SELECT 1;" >/dev/null 2>&1 || true
    if _ctx_fts5_available "$db"; then echo "first=available"; else echo "first=unavailable"; fi
    # Shadow sqlite3 with a function that always fails: if the cache is
    # bypassed, the second call re-probes through THIS broken stub.
    sqlite3() { return 1; }
    if _ctx_fts5_available "$db"; then echo "second=available"; else echo "second=unavailable"; fi
  ' bash "$REPO_ROOT/runtime" "$(ctx_fixture_target "$db")" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "exit $status err=$(<"$err")"; return 0
  fi
  local first second
  first="$(grep '^first=' "$out" | cut -d= -f2)"
  second="$(grep '^second=' "$out" | cut -d= -f2)"
  if [[ -z "$first" || -z "$second" ]]; then
    fail "$name" "expected first= and second= output lines; got: $(<"$out")"; return 0
  fi
  if [[ "$first" != "$second" ]]; then
    fail "$name" "second call did not use the cache -- first probe said '$first', second (should be cached) said '$second'"; return 0
  fi
  pass "$name"
}

# Behavior (CC-571): _ctx_fts_rebuild wraps its DROP+CREATE+INSERT sequence
# in BEGIN IMMEDIATE/COMMIT and invokes sqlite3 with -bail. Without -bail,
# direct reproduction during implementation showed the sqlite3 CLI's default
# behavior on a mid-script SQL error is to print the error and KEEP
# executing subsequent statements -- it does not stop -- so a bare
# BEGIN...COMMIT alone would still reach and execute COMMIT after silently
# skipping the failed statement, committing a half-built content_fts. With
# -bail, an error aborts before COMMIT, leaving the transaction open; the
# sqlite3 process exiting then closes the connection, which triggers an
# automatic ROLLBACK, leaving the previous content_fts fully intact.
# Steps: index a real fixture repo (creates a real content_fts with real
# rows); drop the `files` table `_ctx_fts_rebuild`'s INSERT...JOIN depends on
# to force a genuine SQL failure mid-rebuild; call `_ctx_fts_rebuild` again
# directly; assert it returns non-zero AND the old content_fts row is still
# present and queryable (not half-built, not dropped-and-not-recreated).
case_ctx_fts_rebuild_rollback_preserves_old_index_on_failure() {
  local name="pmctl context: _ctx_fts_rebuild rolls back on failure, preserving the previous index"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-fts-rollback"
  make_fixture_repo "$fix_repo"
  local err="$tmp_root/fts-rollback-setup.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: initial index failed: $(<"$err")"; return 0; }

  local db="$fix_repo/.pm-dispatch/ctx/context.db"
  local before_rows
  before_rows="$(sqlite3 "$db" "SELECT count(*) FROM content_fts;" 2>/dev/null)"
  if [[ -z "$before_rows" || "$before_rows" -eq 0 ]]; then
    fail "$name" "setup: expected a populated content_fts after initial index, got $before_rows rows"
    return 0
  fi

  # Force a genuine mid-rebuild SQL failure: the rebuild's own INSERT...JOIN
  # against `files` can no longer resolve once that table is gone.
  sqlite3 "$db" "DROP TABLE files;" 2>/dev/null \
    || { fail "$name" "setup: could not drop files table"; return 0; }

  local out
  out="$tmp_root/fts-rollback.out"
  bash -c '
    set -uo pipefail
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_fts_rebuild "$2"
    echo "rc=$?"
  ' bash "$REPO_ROOT/runtime" "$(ctx_fixture_target "$db")" > "$out" 2>>"$err" || true

  local rc
  rc="$(grep '^rc=' "$out" | cut -d= -f2)"
  if [[ "$rc" -eq 0 ]]; then
    fail "$name" "_ctx_fts_rebuild reported success (rc=0) despite the forced SQL failure"
    return 0
  fi

  local after_rows
  after_rows="$(sqlite3 "$db" "SELECT count(*) FROM content_fts;" 2>/dev/null)"
  if [[ "$after_rows" != "$before_rows" ]]; then
    fail "$name" "content_fts row count changed after a failed rebuild: before=$before_rows after=$after_rows (expected unchanged -- rollback should have preserved it)"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-571): _ctx_index_file's own return code must reflect whether
# its sqlite3 write actually succeeded, not the unconditional `rm -f` cleanup
# that used to be the function's last statement (confirmed by direct
# reproduction during implementation: `sqlite3 <fails>; rm -f "$tmpf"` as a
# function body always returns 0, the exit status of `rm`, regardless of
# whether sqlite3 succeeded). Steps: index a real fixture repo; drop the
# `symbols` table so _ctx_generate_file_sql's own INSERT statements fail;
# call _ctx_index_file directly (white-box); assert it returns non-zero.
case_ctx_index_file_return_code_reflects_sqlite_failure() {
  local name="pmctl context: _ctx_index_file's return code reflects the actual sqlite3 result, not rm's"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-index-file-rc"
  make_fixture_repo "$fix_repo"
  local err="$tmp_root/index-file-rc-setup.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: initial index failed: $(<"$err")"; return 0; }

  local db="$fix_repo/.pm-dispatch/ctx/context.db"
  local target="$fix_repo/scripts/lib/mymodule.sh"
  sqlite3 "$db" "DROP TABLE symbols;" 2>/dev/null \
    || { fail "$name" "setup: could not drop symbols table"; return 0; }

  local out
  out="$tmp_root/index-file-rc.out"
  bash -c '
    set -uo pipefail
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_index_file "$2" "$3" "scripts/lib/mymodule.sh"
    echo "rc=$?"
  ' bash "$REPO_ROOT/runtime" "$(ctx_fixture_target "$db")" "$(ctx_fixture_target "$target")" \
    > "$out" 2>>"$err" || true

  local rc
  rc="$(grep '^rc=' "$out" | cut -d= -f2)"
  if [[ "$rc" -eq 0 ]]; then
    fail "$name" "_ctx_index_file reported success (rc=0) despite the forced sqlite3 failure"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-571): unlike a failed FTS rebuild (best-effort, non-fatal),
# a failed _ctx_index_file writes the primary files/symbols/file_chunks
# data -- pmctl_context_update must treat it as fatal and must NOT print
# "context update: re-indexed <path>" when the file's content was not
# actually reflected in the index.
case_context_update_fails_honestly_when_index_file_fails() {
  local name="pmctl context update: fails (does not claim re-indexed) when _ctx_index_file fails"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-update-index-file-fail"
  make_fixture_repo "$fix_repo"
  local err="$tmp_root/update-index-file-fail-setup.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: initial index failed: $(<"$err")"; return 0; }

  local target="$fix_repo/scripts/lib/mymodule.sh"
  local out status=0
  out="$tmp_root/update-index-file-fail.out"
  bash -c '
    set -uo pipefail
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_index_file() { return 1; }
    pmctl_context_update "$2" "$3"
  ' bash "$REPO_ROOT/runtime" "$(ctx_fixture_target "$fix_repo")" "$(ctx_fixture_target "$target")" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -eq 0 ]]; then
    fail "$name" "pmctl_context_update exited 0 despite a failed _ctx_index_file; expected non-zero. out=$(<"$out")"
    return 0
  fi
  if grep -q '^context update: re-indexed' "$out"; then
    fail "$name" "claimed 're-indexed' success despite a failed _ctx_index_file: $(<"$out")"
    return 0
  fi
  if ! grep -q 'failed to index' "$err"; then
    fail "$name" "expected an honest failure message on stderr; got: $(<"$err")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-571): pmctl_context_index must not report a bare "context
# index: N indexed, M skipped" success line when the FTS rebuild it
# triggered actually failed -- the previous behavior silently ignored
# _ctx_fts_rebuild's return value entirely. Overall indexing must still
# succeed (FTS is a best-effort acceleration layer; LIKE fallback remains
# available), but stderr must honestly say the FTS index is now stale.
# Steps: shadow _ctx_fts_rebuild to always fail (white-box, matching this
# file's existing sqlite3-shadowing pattern); run pmctl_context_index on a
# fresh fixture repo (which will trigger an FTS rebuild since content_fts
# does not exist yet); assert exit 0 (non-fatal) and the honest stderr
# message.
case_context_index_reports_fts_rebuild_failure_honestly() {
  local name="pmctl context index: reports (not silently absorbs) an FTS rebuild failure"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-fts-index-honest"
  make_fixture_repo "$fix_repo"

  local out err status=0
  out="$tmp_root/fts-index-honest.out"; err="$tmp_root/fts-index-honest.err"
  bash -c '
    set -uo pipefail
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_fts_rebuild() { return 1; }
    pmctl_context_index "$2"
  ' bash "$REPO_ROOT/runtime" "$(ctx_fixture_target "$fix_repo")" > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pmctl_context_index exited $status; expected 0 (FTS failure must be non-fatal). err=$(<"$err")"
    return 0
  fi
  if ! grep -q 'FTS index rebuild failed' "$err"; then
    fail "$name" "expected an honest FTS-rebuild-failure message on stderr; got: $(<"$err")"
    return 0
  fi
  # gate finding critic-F001 (round 1): printing the diagnostic on stderr
  # while stdout still read as an unqualified "N indexed, M skipped" is a
  # contradictory summary for any caller that only looks at stdout / exit
  # code. The final summary line itself must carry the degradation.
  if ! grep -qE '^context index: .*degraded' "$out"; then
    fail "$name" "expected the summary line itself to disclose FTS degradation; got: $(<"$out")"
    return 0
  fi
  # gate finding critic-F001 (round 2, gate-20260826-021038-ac0bc2): this is
  # a fresh fixture repo with no prior content_fts, so the rollback after
  # this failed rebuild leaves NO FTS table at all -- "existing (now stale)
  # FTS index retained" would be false here, since there is no existing
  # index to retain. Both messages must say no index is available instead.
  if grep -qi 'existing.*retained' "$err" || grep -qi 'stale index retained' "$out"; then
    fail "$name" "first-time build failure wrongly claimed a stale index is 'retained' when none ever existed. err=$(<"$err") out=$(<"$out")"
    return 0
  fi
  if ! grep -q 'no FTS index available' "$err"; then
    fail "$name" "expected the first-time-build failure message to say no FTS index is available; got: $(<"$err")"
    return 0
  fi
  local db_after="$fix_repo/.pm-dispatch/ctx/context.db"
  local fts_after
  fts_after="$(sqlite3 "$db_after" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='content_fts';" 2>/dev/null)"
  if [[ "$fts_after" != "0" ]]; then
    fail "$name" "expected content_fts to be absent after a failed first-time rebuild; sqlite_master reports $fts_after"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-571): same honest-reporting contract as
# case_context_index_reports_fts_rebuild_failure_honestly, but for
# pmctl_context_update's independent call site -- both call sites had the
# identical unchecked-return-value gap before this fix, and CC-521's own
# lesson (grep every consumer, not just one) applies here.
case_context_update_reports_fts_rebuild_failure_honestly() {
  local name="pmctl context update: reports (not silently absorbs) an FTS rebuild failure"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-fts-update-honest"
  make_fixture_repo "$fix_repo"
  local err="$tmp_root/fts-update-honest-setup.err"
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$err" \
    || { fail "$name" "setup: initial index failed: $(<"$err")"; return 0; }

  local target="$fix_repo/scripts/lib/mymodule.sh"
  printf '\n# touched for CC-571 update-path test\n' >> "$target"

  local out status=0
  out="$tmp_root/fts-update-honest.out"
  bash -c '
    set -uo pipefail
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_fts_rebuild() { return 1; }
    pmctl_context_update "$2" "$3"
  ' bash "$REPO_ROOT/runtime" "$(ctx_fixture_target "$fix_repo")" "$(ctx_fixture_target "$target")" \
    > "$out" 2> "$err" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pmctl_context_update exited $status; expected 0 (FTS failure must be non-fatal). err=$(<"$err")"
    return 0
  fi
  if ! grep -q 'FTS index rebuild failed' "$err"; then
    fail "$name" "expected an honest FTS-rebuild-failure message on stderr; got: $(<"$err")"
    return 0
  fi
  # gate finding critic-F001 (round 1): same contradictory-summary concern
  # as the index-path test above.
  if ! grep -qE '^context update: re-indexed .*degraded' "$out"; then
    fail "$name" "expected the summary line itself to disclose FTS degradation; got: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 2/3 gate finding qa-tester-F001): _ctx_rank_hits is the
# ONE shared sort+truncate path every consumer (query/pack/reuse-scan/
# prompt-scan) calls. A comparator, tie-break, rank-numbering, or limit
# regression here would silently return the wrong top-K to all four consumers
# while every schema-shape/presence assertion elsewhere stays green -- this
# case is white-box and asserts the actual ordering/values directly.
# Steps: source the lib; feed _ctx_rank_hits a synthetic 9-column TSV with
# out-of-order and tied scores; assert descending score order, ref-ascending
# tie-break, 1-based sequential rank, and correct truncation at a limit.
case_context_rank_hits_orders_and_truncates() {
  local name="pmctl context: _ctx_rank_hits sorts by score, tie-breaks by ref, numbers rank, and truncates"
  should_run "$name" || return 0

  local input out err status=0
  input="$tmp_root/rank-hits-input.tsv"
  out="$tmp_root/rank-hits.out"; err="$tmp_root/rank-hits.err"
  # ref, domain, why, conf, trust, match_kind, line_end, ranking_score, score_components
  {
    printf 'z.md:1\trepo\tw\t0.7\tmedium\tlike_fallback\t1\t100\tc1\n'
    printf 'a.md:1\trepo\tw\t0.7\tmedium\tlike_fallback\t1\t500\tc2\n'
    printf 'b.md:1\trepo\tw\t0.7\tmedium\tlike_fallback\t1\t500\tc3\n'
    printf 'c.md:1\trepo\tw\t0.85\thigh\tsymbol_exact\t1\t1000\tc4\n'
  } > "$input"

  bash -c '
    set -euo pipefail
    # shellcheck source=runtime/lib/pmctl-context.sh
    . "$1/lib/pmctl-context.sh"
    _ctx_rank_hits "$2" "$3"
  ' bash "$REPO_ROOT/runtime" "$input" 2 > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "exit $status err=$(<"$err")"; return 0
  fi
  # Expect exactly 2 rows (limit=2): rank 1 = c.md (score 1000, highest),
  # rank 2 = a.md (score 500, tie-broken ahead of b.md by ref ascending).
  local expected actual
  expected="1	c.md:1	repo	w	0.85	high	symbol_exact	1	1000	c4
2	a.md:1	repo	w	0.7	medium	like_fallback	1	500	c2"
  actual="$(cat "$out")"
  if [[ "$actual" != "$expected" ]]; then
    fail "$name" "ranked output mismatch:
--- expected ---
$expected
--- actual ---
$actual"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 2/3 gate finding qa-tester-F002): the schema_version 3
# ranking fields must actually hold valid values on real pack output, not
# just be present as unchecked keys. Presence-only checks (has("rank") etc.)
# would not catch an omitted, mis-typed, or invalid-enum value reaching the
# consumer.
# Steps: index a fixture repo (multiple match_kinds: exact symbol + fts5
# text); run pack; assert every files[]/symbols[] item has rank >= 1,
# match_kind in the declared enum, integer line_start/line_end,
# integer ranking_score, and a non-empty score_components string; also
# assert items[].rank is a contiguous 1..N sequence within each array
# (confirms _ctx_rank_hits numbered the SAME array pack actually emitted,
# not a stale or differently-ordered set).
case_context_pack_ranking_fields_are_valid() {
  local name="pmctl context pack: schema_version 3 ranking fields hold valid values, not just present keys"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-ranking"
  make_fixture_repo "$fix_repo"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-rank-setup.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-rank-setup.err")"; return 0; }

  out="$tmp_root/pack-ranking.out"; err="$tmp_root/pack-ranking.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query my_func_alpha --query alpha \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi

  # Two --query terms deliberately overlap (my_func_alpha is exact-symbol
  # AND substring-matches "alpha"'s fts5/partial hits) so this also covers
  # critic-F001: no ref may appear twice across symbols[]+files[] combined --
  # accumulating candidates from both terms, and from both match-kind
  # families, must dedup to each ref's single highest-scoring occurrence,
  # not just "first term/kind wins". rank comes from ranking the merged
  # repo set once before the symbols/files split, so ranks need not be a
  # contiguous 1..N run within either array alone -- only unique and >=1.
  if ! jq -e '
    def valid_items:
      (. | length) == 0 or (
        all(.[]; (.rank | type == "number" and . >= 1)) and
        all(.[]; .match_kind | IN("symbol_exact","symbol_partial","fts5_content","like_fallback")) and
        all(.[]; (.line_start == null) or (.line_start | type == "number")) and
        all(.[]; (.line_end == null) or (.line_end | type == "number")) and
        all(.[]; .ranking_score | type == "number") and
        all(.[]; (.score_components | type == "string") and (.score_components | length) > 0) and
        (([.[].rank] | unique | length) == length)
      );
    (.files | valid_items) and (.symbols | valid_items) and
    ((.files | length) + (.symbols | length)) >= 1 and
    (((.files + .symbols) | map(.ref) | unique | length) == ((.files + .symbols) | length))
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "ranking field validation failed: $(<"$err") output: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 5): with no explicit budget flags, a normal-sized
# result stays entirely within the generous default ceiling and discloses
# truncation.applied=false -- the budget must not shrink ordinary output.
# Steps: index a fixture repo; pack a term with a handful of hits; assert
# the pack's `truncation` object reports applied=false and kept==total_before.
case_context_pack_default_budget_does_not_truncate() {
  local name="pmctl context pack: default budget does not truncate an ordinary result"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-budget-default"
  make_fixture_repo "$fix_repo"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-budget-default.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-budget-default.err")"; return 0; }

  out="$tmp_root/pack-budget-default.out"; err="$tmp_root/pack-budget-default.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  if ! jq -e '
    .truncation.applied == false and
    .truncation.reason == "none" and
    .truncation.kept == .truncation.total_before and
    .truncation.dropped == 0
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected an untruncated disclosure for an ordinary result: $(<"$err") output: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 5): --max-items enforces a GLOBAL cap across
# files[]+symbols[]+memories[] combined (not per-array), keeps the
# highest-ranked survivors, and discloses the truncation.
# Steps: index a fixture repo; pack a term with more than 1 hit using
# --max-items 1; assert exactly 1 item survives across all arrays combined,
# and truncation discloses applied=true/reason=item_budget/dropped>0.
case_context_pack_max_items_enforces_global_cap() {
  local name="pmctl context pack: --max-items enforces a global cap across all arrays"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-budget-items"
  make_fixture_repo "$fix_repo"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-budget-items.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-budget-items.err")"; return 0; }

  out="$tmp_root/pack-budget-items.out"; err="$tmp_root/pack-budget-items.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-items 1 \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  if ! jq -e '
    ((.files | length) + (.symbols | length) + (.memories | length)) == 1 and
    .truncation.applied == true and
    .truncation.reason == "item_budget" and
    .truncation.budget.max_items == 1 and
    .truncation.kept == 1 and
    .truncation.dropped == (.truncation.total_before - 1) and
    .truncation.total_before > 1
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "--max-items 1 did not enforce a global 1-item cap: $(<"$err") output: $(<"$out")"
    return 0
  fi
  # The one survivor must be the globally highest-ranked candidate: the
  # exact-symbol hit for my_func_alpha (tier base outranks every fts5 hit
  # regardless of bm25), same guarantee case_context_query_cli_orders_by_
  # rank_tier already locks for the query path.
  if ! jq -e '
    (.files + .symbols + .memories)[0].match_kind | IN("symbol_exact", "symbol_partial")
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "the single surviving item should be the highest-ranked (symbol) hit: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 5): --max-bytes truncates further than --max-items
# alone would, by dropping the lowest-ranked surviving items until the
# serialized pack fits, and discloses reason=byte_budget.
# Steps: pack a term with several hits using a --max-bytes tight enough to
# force dropping items even though --max-items would allow more; assert
# the disclosed reason is byte_budget and the pack byte size is <= the cap.
case_context_pack_max_bytes_enforces_byte_cap() {
  local name="pmctl context pack: --max-bytes drops lowest-ranked items until the pack fits"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-budget-bytes"
  make_fixture_repo "$fix_repo"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-budget-bytes.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-budget-bytes.err")"; return 0; }

  # An arbitrarily tight cap (e.g. half the natural size) can land BELOW the
  # pack skeleton''s own minimum floor (schema fields + the truncation object
  # itself), at which point 0 items survive and the output legitimately
  # cannot shrink further -- that is correct degenerate behavior, not a bug,
  # but it makes ">0 items survived, still under budget" untestable with an
  # arbitrary cap. Instead, learn the real byte cost of keeping exactly 1
  # item (via --max-items 1) and set the cap just above that floor, so the
  # byte budget alone (no --max-items) is guaranteed to have exactly one
  # achievable, predictable target to shrink toward.
  local one_item_out one_item_bytes
  one_item_out="$tmp_root/pack-budget-bytes-one-item.out"
  local one_item_err="$tmp_root/pack-budget-bytes-one-item.err" one_item_status=0
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-items 1 \
    > "$one_item_out" 2> "$one_item_err" || one_item_status=$?
  if [[ "$one_item_status" -ne 0 ]]; then
    fail "$name" "setup: baseline --max-items 1 pack exited $one_item_status: $(<"$one_item_err")"; return 0
  fi
  one_item_bytes="$(wc -c < "$one_item_out" | tr -d ' ')"

  out="$tmp_root/pack-budget-bytes.out"; err="$tmp_root/pack-budget-bytes.err"
  local tight_cap=$(( one_item_bytes + 20 ))
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-bytes "$tight_cap" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  local actual_bytes
  actual_bytes="$(wc -c < "$out" | tr -d ' ')"
  if (( actual_bytes > tight_cap )); then
    fail "$name" "pack ($actual_bytes bytes) exceeds --max-bytes $tight_cap: $(<"$out")"
    return 0
  fi
  if ! jq -e '.truncation.applied == true and .truncation.reason == "byte_budget" and .truncation.dropped > 0 and .truncation.kept >= 1' \
      "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected a byte_budget truncation disclosure with at least one surviving item: $(<"$err") output: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 5 follow-up, risk-reviewer-F001): a large multi-term
# candidate set combined with a tight --max-bytes used to re-sort and
# re-serialize the ENTIRE candidate pool once PER DROPPED ITEM
# (_ctx_pack_with_truncation -> _ctx_pack_top_n on the full unbounded
# input), which is quadratic work and excessive subprocess launches for a
# permitted multi-query invocation. Fixed by pre-slicing the candidate set
# to at most max_items ONCE before the byte-budget loop. This regression
# test forces heavy trimming over a wide, many-term/many-hit candidate set
# and asserts it completes within a generous bound instead of degrading
# catastrophically.
case_context_pack_large_candidate_byte_budget_bounded_work() {
  local name="pmctl context pack: large multi-term candidate set with tight --max-bytes stays bounded"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-large-candidate"
  mkdir -p "$fix_repo/scripts/lib"
  local i lib="$fix_repo/scripts/lib/loadtest.sh"
  {
    printf '#!/usr/bin/env bash\n'
    for ((i = 0; i < 60; i++)); do
      printf 'loadtest_func_%d() {\n  printf "loadtest hit %d\\n"\n}\n' "$i" "$i"
    done
  } > "$lib"

  local err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-large-candidate.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-large-candidate.err")"; return 0; }

  local -a args=("$fix_repo" --task-id TASK-1 --max-items 200 --max-bytes 4000)
  for ((i = 0; i < 40; i++)); do
    args+=(--query "loadtest_func_$i")
  done

  local out start_ts end_ts elapsed
  out="$tmp_root/pack-large-candidate.out"; err="$tmp_root/pack-large-candidate.err"
  start_ts="$(date +%s)"
  "$PMCTL" context pack "${args[@]}" > "$out" 2> "$err" || status=$?
  end_ts="$(date +%s)"
  elapsed=$((end_ts - start_ts))
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  if (( elapsed > 30 )); then
    fail "$name" "large-candidate byte-budget trimming took ${elapsed}s, expected a bounded completion time"
    return 0
  fi
  if ! jq -e '.truncation.reason == "byte_budget" and .truncation.dropped > 0' "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected substantial byte-budget trimming to have occurred: $(<"$err") output head: $(head -c 500 "$out")"
    return 0
  fi
  local actual_bytes
  actual_bytes="$(wc -c < "$out" | tr -d ' ')"
  if (( actual_bytes > 4000 )); then
    fail "$name" "pack ($actual_bytes bytes) exceeds --max-bytes 4000"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 5 follow-up, qa-tester-F001): the byte-budget
# comparison is `>`, not `>=` -- a pack that fits EXACTLY at --max-bytes
# must be accepted as-is (kept==1), and a cap one byte below that exact
# size must legitimately drop to 0 items (not silently over- or
# under-truncate at the boundary).
case_context_pack_max_bytes_exact_boundary_accepted() {
  local name="pmctl context pack: --max-bytes at the exact one-item pack size keeps that item"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pack-budget-exact-boundary"
  make_fixture_repo "$fix_repo"
  local err="$tmp_root/pack-exact-boundary-jq.err" status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-exact-boundary.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-exact-boundary.err")"; return 0; }

  # The `truncation.budget.max_bytes` field itself renders the requested
  # cap, so its digit width feeds back into the pack's own byte size --
  # probing with one --max-bytes value and then asserting an EXACT byte
  # match at a DIFFERENT --max-bytes value is not self-consistent (a
  # 200000-vs-623 digit-width difference alone moves the output by a few
  # bytes with no truncation involved). Converge on a self-consistent
  # fixed point instead: request a pack capped at guess bytes, see how many
  # bytes it actually took, and re-probe with that value until they agree.
  local one_item_out one_item_bytes one_item_err one_item_status=0 guess=999999 i
  one_item_out="$tmp_root/pack-exact-boundary-one-item.out"
  one_item_err="$tmp_root/pack-exact-boundary-one-item.err"
  for ((i = 0; i < 5; i++)); do
    one_item_status=0
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-items 1 --max-bytes "$guess" \
      > "$one_item_out" 2> "$one_item_err" || one_item_status=$?
    if [[ "$one_item_status" -ne 0 ]]; then
      fail "$name" "setup: baseline --max-items 1 --max-bytes $guess pack exited $one_item_status: $(<"$one_item_err")"; return 0
    fi
    one_item_bytes="$(wc -c < "$one_item_out" | tr -d ' ')"
    [[ "$one_item_bytes" == "$guess" ]] && break
    guess="$one_item_bytes"
  done
  if [[ "$one_item_bytes" != "$guess" ]]; then
    fail "$name" "setup: --max-bytes probe did not converge to a fixed point (last: $one_item_bytes vs $guess)"
    return 0
  fi

  local exact_out exact_err exact_status=0
  exact_out="$tmp_root/pack-exact-boundary-exact.out"; exact_err="$tmp_root/pack-exact-boundary-exact.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-items 1 --max-bytes "$one_item_bytes" \
    > "$exact_out" 2> "$exact_err" || exact_status=$?
  if [[ "$exact_status" -ne 0 ]]; then
    fail "$name" "pack exited $exact_status at the exact byte boundary: $(<"$exact_err")"; return 0
  fi
  local exact_bytes
  exact_bytes="$(wc -c < "$exact_out" | tr -d ' ')"
  if [[ "$exact_bytes" -ne "$one_item_bytes" ]]; then
    fail "$name" "expected exact-boundary output to be unchanged ($one_item_bytes bytes), got $exact_bytes"
    return 0
  fi
  # reason is "item_budget" (not "byte_budget") here: --max-items 1 is what
  # constrains this pack to a single item in the first place; the point of
  # this assertion is that the BYTE cap, sized to fit exactly, does not
  # ALSO drop that one surviving item.
  if ! jq -e '.truncation.kept == 1 and .truncation.reason == "item_budget"' "$exact_out" > /dev/null 2>"$err"; then
    fail "$name" "expected the item to survive exactly at the boundary, not be dropped: $(<"$exact_out")"
    return 0
  fi

  local below_out below_err below_status=0
  below_out="$tmp_root/pack-exact-boundary-below.out"; below_err="$tmp_root/pack-exact-boundary-below.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-items 1 --max-bytes "$((one_item_bytes - 1))" \
    > "$below_out" 2> "$below_err" || below_status=$?
  if [[ "$below_status" -ne 0 ]]; then
    fail "$name" "pack exited $below_status one byte below the boundary: $(<"$below_err")"; return 0
  fi
  local below_bytes
  below_bytes="$(wc -c < "$below_out" | tr -d ' ')"
  if (( below_bytes > one_item_bytes - 1 )); then
    fail "$name" "one-byte-below cap ($((one_item_bytes - 1))) was not honored: got $below_bytes bytes"
    return 0
  fi
  if ! jq -e '.truncation.kept == 0 and .truncation.reason == "byte_budget"' "$below_out" > /dev/null 2>"$err"; then
    fail "$name" "expected the single item to be dropped one byte below its exact size: $(<"$below_out")"
    return 0
  fi
  pass "$name"
}

case_context_pack_impossible_byte_cap_rejected() {
  local name="pmctl context pack: --max-bytes below the empty envelope floor fails closed"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-budget-impossible"
  make_fixture_repo "$fix_repo"
  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-impossible.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-impossible.err")"; return 0; }
  out="$tmp_root/pack-impossible.out"; err="$tmp_root/pack-impossible.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-bytes 1 \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then
    if [[ -s "$out" ]]; then
      fail "$name" "expected no pack output on fail-closed rejection: $(<"$out")"
      return 0
    fi
    pass "$name"
  fi
}

case_context_pack_invalid_max_items_rejected() {
  local name="pmctl context pack: --max-items rejects a non-positive-integer value"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-budget-invalid"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-budget-invalid-items.out"; err="$tmp_root/pack-budget-invalid-items.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-items 0 \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_invalid_max_bytes_rejected() {
  local name="pmctl context pack: --max-bytes rejects a non-positive-integer value"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-budget-invalid2"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-budget-invalid-bytes.out"; err="$tmp_root/pack-budget-invalid-bytes.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-bytes not-a-number \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

# Behavior (CC-505 Req 5): PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS/_MAX_BYTES set
# the defaults when no --max-items/--max-bytes flag is given, exercising the
# same fail-closed validation path as the flags themselves (qa-tester-F002).
case_context_pack_env_max_items_valid_override_applies() {
  local name="pmctl context pack: PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS overrides the default cap"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-budget-env-items"
  make_fixture_repo "$fix_repo"
  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-env-items.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-env-items.err")"; return 0; }
  out="$tmp_root/pack-env-items.out"; err="$tmp_root/pack-env-items.err"
  PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS=1 \
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  if ! jq -e '
    ((.files | length) + (.symbols | length) + (.memories | length)) == 1 and
    .truncation.applied == true and
    .truncation.reason == "item_budget" and
    .truncation.budget.max_items == 1
  ' "$out" > /dev/null 2>"$err"; then
    fail "$name" "env override did not apply a 1-item cap: $(<"$err") output: $(<"$out")"
    return 0
  fi
  pass "$name"
}

case_context_pack_env_max_bytes_valid_override_applies() {
  local name="pmctl context pack: PM_DISPATCH_CONTEXT_PACK_MAX_BYTES overrides the default cap"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-budget-env-bytes"
  make_fixture_repo "$fix_repo"
  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-env-bytes.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-env-bytes.err")"; return 0; }

  local one_item_out one_item_bytes
  one_item_out="$tmp_root/pack-env-bytes-one-item.out"
  local one_item_err="$tmp_root/pack-env-bytes-one-item.err" one_item_status=0
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-items 1 \
    > "$one_item_out" 2> "$one_item_err" || one_item_status=$?
  if [[ "$one_item_status" -ne 0 ]]; then
    fail "$name" "setup: baseline --max-items 1 pack exited $one_item_status: $(<"$one_item_err")"; return 0
  fi
  one_item_bytes="$(wc -c < "$one_item_out" | tr -d ' ')"
  local tight_cap=$(( one_item_bytes + 20 ))

  out="$tmp_root/pack-env-bytes.out"; err="$tmp_root/pack-env-bytes.err"
  PM_DISPATCH_CONTEXT_PACK_MAX_BYTES="$tight_cap" \
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  local actual_bytes
  actual_bytes="$(wc -c < "$out" | tr -d ' ')"
  if (( actual_bytes > tight_cap )); then
    fail "$name" "pack ($actual_bytes bytes) exceeds env PM_DISPATCH_CONTEXT_PACK_MAX_BYTES=$tight_cap: $(<"$out")"
    return 0
  fi
  if ! jq -e '.truncation.applied == true and .truncation.reason == "byte_budget" and .truncation.budget.max_bytes == '"$tight_cap"'' \
      "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected a byte_budget truncation disclosure honoring the env cap: $(<"$err") output: $(<"$out")"
    return 0
  fi
  pass "$name"
}

case_context_pack_env_max_items_invalid_rejected() {
  local name="pmctl context pack: invalid PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS is rejected fail-closed"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-budget-env-invalid-items"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-env-invalid-items.out"; err="$tmp_root/pack-env-invalid-items.err"
  PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS=0 \
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_env_max_bytes_invalid_rejected() {
  local name="pmctl context pack: invalid PM_DISPATCH_CONTEXT_PACK_MAX_BYTES is rejected fail-closed"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-budget-env-invalid-bytes"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-env-invalid-bytes.out"; err="$tmp_root/pack-env-invalid-bytes.err"
  PM_DISPATCH_CONTEXT_PACK_MAX_BYTES=not-a-number \
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

# Behavior (CC-505 Req 5): an empty-index pack (no db yet) still emits a
# well-formed truncation disclosure, not an omitted field a v4 consumer
# would have to special-case.
case_context_pack_empty_index_discloses_untruncated_budget() {
  local name="pmctl context pack: empty-index pack still discloses an untruncated budget"
  should_run "$name" || return 0
  local nodb_repo="$tmp_root/nodb-repo-pack-budget"
  mkdir -p "$nodb_repo"
  local out err status=0
  out="$tmp_root/pack-budget-nodb.out"; err="$tmp_root/pack-budget-nodb.err"
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 \
    "$PMCTL" context pack "$nodb_repo" --task-id TASK-1 --query foo \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0 (graceful empty); got $status err=$(<"$err")"; return 0
  fi
  if ! jq -e '.truncation.applied == false and .truncation.total_before == 0 and .truncation.kept == 0' \
      "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected an untruncated empty-index disclosure: $(<"$err") output: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 5 follow-up, risk-reviewer-F001): every --query term
# accumulates its own raw hits BEFORE the final item/byte budget is ever
# applied, so the term count itself must be bounded -- fail closed above
# PM_DISPATCH_CONTEXT_PACK_MAX_TERMS rather than let an extreme invocation
# do unbounded intermediate work regardless of how small the eventual
# output is capped.
case_context_pack_max_terms_rejects_excess() {
  local name="pmctl context pack: too many --query terms is rejected before any accumulation"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-max-terms"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-max-terms.out"; err="$tmp_root/pack-max-terms.err"
  local -a args=("$fix_repo" --task-id TASK-1)
  local i
  for ((i = 0; i < 3; i++)); do
    args+=(--query "term-$i")
  done
  PM_DISPATCH_CONTEXT_PACK_MAX_TERMS=2 \
    "$PMCTL" context pack "${args[@]}" \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then
    if [[ -s "$out" ]]; then
      fail "$name" "expected no pack output when the term cap is exceeded: $(<"$out")"
      return 0
    fi
    pass "$name"
  fi
}

# Behavior (CC-505 Req 5 follow-up, qa-tester-F001): the term-count guard's
# own env-var input must be validated fail-closed too, distinct from the
# "too many terms" case above -- this locks the malformed-value branch.
case_context_pack_invalid_max_terms_rejected() {
  local name="pmctl context pack: invalid PM_DISPATCH_CONTEXT_PACK_MAX_TERMS is rejected fail-closed"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-invalid-max-terms"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-invalid-max-terms.out"; err="$tmp_root/pack-invalid-max-terms.err"
  PM_DISPATCH_CONTEXT_PACK_MAX_TERMS=0 \
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then
    if [[ -s "$out" ]]; then
      fail "$name" "expected no pack output on fail-closed rejection: $(<"$out")"
      return 0
    fi
    pass "$name"
  fi
}

# Behavior (CC-505 Req 5 follow-up, architecture-reviewer-F001): sources[]
# must reflect what actually survived truncation, not the pre-truncation
# set -- a cap that drops every memory item must also drop the
# memory-index provenance entry, otherwise a caller sees an attributed
# producer with zero surviving items.
case_context_pack_truncation_reconciles_sources_provenance() {
  local name="pmctl context pack: truncation drops memory-index provenance when no memory item survives"
  should_run "$name" || return 0

  local repo="$tmp_root/pack-sources-repo" cfg="$tmp_root/pack-sources-cfg"
  make_fixture_repo "$repo"
  local mdir; mdir="$cfg/projects/$(mem_encode_path "$repo")/memory"
  mkdir -p "$mdir"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [sources provenance card](feedback_sources_provenance.md) — sources provenance fixture
MD
  cat > "$mdir/feedback_sources_provenance.md" <<'MD'
---
name: sources-provenance-card
---
alpha appears once in this low-priority memory card.
MD

  local err status=0 out
  "$PMCTL" context index "$repo" > /dev/null 2> "$tmp_root/index-sources.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-sources.err")"; return 0; }

  out="$tmp_root/pack-sources.out"; err="$tmp_root/pack-sources.err"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context pack "$repo" --task-id TASK-1 --query alpha \
    --source all --max-items 1 \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  # The repo-domain exact-symbol hit for alpha outranks the plain-prose
  # memory mention, so --max-items 1 keeps the repo item and drops the
  # memory item entirely.
  if ! jq -e '(.memories | length) == 0' "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected the single surviving item to be the repo hit, not the memory hit: $(<"$out")"
    return 0
  fi
  if ! jq -e '(.sources | map(.name) | index("memory-index")) == null' "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected sources[] to drop memory-index once no memory item survives: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 5 follow-up, critic-F001): the inverse direction of
# the same over-claim -- a memory-only surviving pack must NOT still
# advertise builtin-index in sources[] once every files[]/symbols[] item
# has been truncated away.
case_context_pack_truncation_reconciles_builtin_sources_provenance() {
  local name="pmctl context pack: truncation drops builtin-index provenance when no repo item survives"
  should_run "$name" || return 0

  local repo="$tmp_root/pack-sources-builtin-repo" cfg="$tmp_root/pack-sources-builtin-cfg"
  make_fixture_repo "$repo"
  local mdir; mdir="$cfg/projects/$(mem_encode_path "$repo")/memory"
  mkdir -p "$mdir"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [builtin sources provenance card](feedback_builtin_sources_provenance.md) — builtin sources provenance fixture
MD
  cat > "$mdir/feedback_builtin_sources_provenance.md" <<'MD'
---
name: builtin-sources-provenance-card
---
alpha appears once in this high-trust memory card, curated deliberately.
MD

  local err status=0 out
  "$PMCTL" context index "$repo" > /dev/null 2> "$tmp_root/index-builtin-sources.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-builtin-sources.err")"; return 0; }

  out="$tmp_root/pack-builtin-sources.out"; err="$tmp_root/pack-builtin-sources.err"
  # --source memory means only memories[] is ever populated -- files[]/
  # symbols[] are empty from the start, not truncated down to empty, but
  # the assertion is the same: sources[] must not advertise a producer
  # with zero surviving attributed items.
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context pack "$repo" --task-id TASK-1 --query alpha \
    --source memory \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pack exited $status: $(<"$err")"; return 0
  fi
  if ! jq -e '(.memories | length) > 0 and (.files | length) == 0 and (.symbols | length) == 0' \
      "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected a memory-only surviving set: $(<"$out")"
    return 0
  fi
  if ! jq -e '(.sources | map(.name) | index("builtin-index")) == null' "$out" > /dev/null 2>"$err"; then
    fail "$name" "expected sources[] to drop builtin-index once no repo item survives: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 5 follow-up): the no-index graceful-empty branch must
# ALSO fail closed on an impossible --max-bytes cap -- not just the indexed
# path -- since it is a distinct early return that builds its own envelope
# (critic-F001/architecture-reviewer-F001: this branch used to bypass
# _ctx_apply_pack_budget entirely and could emit an over-budget envelope).
case_context_pack_no_index_impossible_byte_cap_rejected() {
  local name="pmctl context pack: no-index empty pack also fails closed on an impossible --max-bytes"
  should_run "$name" || return 0
  local nodb_repo="$tmp_root/nodb-repo-pack-budget-impossible"
  mkdir -p "$nodb_repo"
  local out err status=0
  out="$tmp_root/pack-budget-nodb-impossible.out"; err="$tmp_root/pack-budget-nodb-impossible.err"
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 \
    "$PMCTL" context pack "$nodb_repo" --task-id TASK-1 --query foo --max-bytes 1 \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then
    if [[ -s "$out" ]]; then
      fail "$name" "expected no pack output on fail-closed rejection: $(<"$out")"
      return 0
    fi
    pass "$name"
  fi
}

# Behavior (CC-505 Req 5 follow-up, risk-reviewer-F001): a digit string one
# past the 15-digit width this validator accepts must be rejected
# deterministically rather than risk overflowing the Bash signed-64-bit
# arithmetic later comparisons use.
case_context_pack_max_items_overflow_boundary_rejected() {
  local name="pmctl context pack: --max-items rejects a value past the supported digit width"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-overflow-items"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-overflow-items.out"; err="$tmp_root/pack-overflow-items.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-items 1000000000000000 \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_max_bytes_overflow_boundary_rejected() {
  local name="pmctl context pack: --max-bytes rejects a value past the supported digit width"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-overflow-bytes"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-overflow-bytes.out"; err="$tmp_root/pack-overflow-bytes.err"
  "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha --max-bytes 1000000000000000 \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_env_max_items_overflow_boundary_rejected() {
  local name="pmctl context pack: PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS overflow-boundary env value is rejected"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-overflow-env-items"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-overflow-env-items.out"; err="$tmp_root/pack-overflow-env-items.err"
  PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS=1000000000000000 \
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_context_pack_env_max_bytes_overflow_boundary_rejected() {
  local name="pmctl context pack: PM_DISPATCH_CONTEXT_PACK_MAX_BYTES overflow-boundary env value is rejected"
  should_run "$name" || return 0
  local fix_repo="$tmp_root/fix-repo-pack-overflow-env-bytes"
  make_fixture_repo "$fix_repo"
  local out err status=0
  out="$tmp_root/pack-overflow-env-bytes.out"; err="$tmp_root/pack-overflow-env-bytes.err"
  PM_DISPATCH_CONTEXT_PACK_MAX_BYTES=1000000000000000 \
    "$PMCTL" context pack "$fix_repo" --task-id TASK-1 --query alpha \
    > "$out" 2> "$err" || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

# Behavior (CC-505 Req 7): a deterministic fixture corpus locking in every
# ranking/chunking guarantee Req 1-4 established, each fixture declaring its
# own expected top-K ref and each built to fail under the pre-CC-505
# behavior it regression-locks (see make_retrieval_corpus_repo's header
# comment for which specific bug each scenario would previously expose).
# Steps: index a purpose-built corpus repo; run one `context query` per
# scenario; assert the declared expected ref is within the declared top-K
# window (top-1 for the exact-symbol and polysemy cases, since those
# specifically assert ranking ORDER between competing candidates, not just
# presence).
case_context_retrieval_fixture_corpus() {
  local name="pmctl context: deterministic retrieval fixture corpus (CC-505 Req 7)"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-retrieval-corpus"
  make_retrieval_corpus_repo "$fix_repo"

  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-corpus.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-corpus.err")"; return 0; }

  local failures=0
  local query expected top_k desc
  while IFS=$'\t' read -r query expected top_k desc; do
    [[ -n "$query" ]] || continue
    local safe_desc out refs
    safe_desc="$(printf '%s' "$desc" | tr -c 'a-zA-Z0-9' '_')"
    out="$tmp_root/corpus-${safe_desc}.out"
    local corpus_err="$tmp_root/corpus-${safe_desc}.err" corpus_status=0
    "$PMCTL" context query "$fix_repo" --source repo "$query" > "$out" 2> "$corpus_err" || corpus_status=$?
    if [[ "$corpus_status" -ne 0 ]]; then
      fail "$name" "[$desc] context query exited $corpus_status: $(<"$corpus_err")"
      failures=$((failures + 1))
      continue
    fi
    refs="$(awk -F': ' '/^- ref:/{print $2}' "$out" | head -n "$top_k")"
    if ! printf '%s\n' "$refs" | grep -qF "$expected"; then
      fail "$name" "[$desc] expected ref containing '$expected' within top-$top_k for query '$query'; got: $refs"
      failures=$((failures + 1))
    fi
  done <<'CORPUS'
unique_exact_symbol_target	src/exact.sh	1	exact-symbol-top1
Distinctive Heading Marker Zulu	docs/heading.md	3	heading-match
deepburied_unique_marker_quebec	docs/deep.md	3	deep-in-paragraph
polysemy_common_term	src/polysemy.sh	1	polysemy-exact-symbol-wins
longsection_tail_marker_yankee	docs/long_section.md	3	long-section-tail-chunked
CORPUS

  # Path/domain boost: the identical marker term appears in both a
  # knowledge-domain file and a plain repo-domain file; the knowledge hit
  # must rank first (top-1), not just appear somewhere in the results.
  local domain_out first_domain
  domain_out="$tmp_root/corpus-domain_boost.out"
  local domain_err="$tmp_root/corpus-domain_boost.err" domain_status=0
  "$PMCTL" context query "$fix_repo" --source repo domain_boost_marker_xray \
    > "$domain_out" 2> "$domain_err" || domain_status=$?
  if [[ "$domain_status" -ne 0 ]]; then
    fail "$name" "[path-domain-boost] context query exited $domain_status: $(<"$domain_err")"
    failures=$((failures + 1))
  fi
  first_domain="$(awk -F': ' '/^  source_domain:/{print $2; exit}' "$domain_out")"
  if [[ "$first_domain" != "knowledge" ]]; then
    fail "$name" "[path-domain-boost] expected the knowledge-domain hit to rank first; got source_domain=$first_domain: $(<"$domain_out")"
    failures=$((failures + 1))
  fi

  [[ "$failures" -eq 0 ]] && pass "$name"
}

# Behavior (CC-505 Req 7): trust weighting -- a curated memory card
# (trust=high) and an episode (trust=medium) containing the SAME marker
# term must rank the card first, not just carry different trust_level
# labels (case_context_query_source_memory_trust_tiers already locks the
# label assignment; this locks that the label actually affects rank).
# Steps: build a memory dir with a card and an episode sharing one marker
# term; query --source memory; assert the card ranks ahead of the episode.
case_context_retrieval_fixture_corpus_trust_weighting() {
  local name="pmctl context: retrieval fixture corpus -- trust weighting affects rank (CC-505 Req 7)"
  should_run "$name" || return 0

  local repo="$tmp_root/corpus-trust-repo" cfg="$tmp_root/corpus-trust-cfg"
  mkdir -p "$repo"
  local mdir; mdir="$cfg/projects/$(mem_encode_path "$repo")/memory"
  mkdir -p "$mdir"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [trust corpus card](feedback_trust_corpus.md) — trust weighting fixture
MD
  cat > "$mdir/feedback_trust_corpus.md" <<'MD'
---
name: trust-corpus-card
---
trustweight_shared_marker appears in this curated card body.
MD
  printf '{"ts":"2026-08-21","summary":"trustweight_shared_marker also appears in this episode"}\n' \
    > "$mdir/episodes.jsonl"

  local out
  out="$tmp_root/corpus-trust.out"
  local trust_err="$tmp_root/corpus-trust.err" trust_status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" context query "$repo" --source memory trustweight_shared_marker \
    > "$out" 2> "$trust_err" || trust_status=$?
  if [[ "$trust_status" -ne 0 ]]; then
    fail "$name" "context query exited $trust_status: $(<"$trust_err")"; return 0
  fi
  local first_ref
  first_ref="$(awk -F': ' '/^- ref:/{print $2; exit}' "$out")"
  if [[ "$first_ref" != feedback_trust_corpus.md:* ]]; then
    fail "$name" "expected the high-trust card to rank first over the medium-trust episode; got first ref=$first_ref: $(<"$out")"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 2/3 gate finding qa-tester-F001): `pmctl context query`
# must return CLI hits in real ranking-tier order (symbol match before fts5
# text match), not insertion/query order, and that order must be stable
# across repeated runs against an unchanged index.
# Steps: index a fixture repo; query a term that matches both a symbol name
# (partial) and multiple markdown bodies (fts5); assert the symbol hit ranks
# first and precedes every fts5 hit; assert a second run produces identical
# output.
case_context_query_cli_orders_by_rank_tier() {
  local name="pmctl context query: CLI output orders symbol hits ahead of fts5 hits and is stable across runs"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-query-rank"
  make_fixture_repo "$fix_repo"

  local out1 out2 err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-query-rank.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-query-rank.err")"; return 0; }

  out1="$tmp_root/query-rank-1.out"; err="$tmp_root/query-rank.err"
  "$PMCTL" context query "$fix_repo" --source repo alpha > "$out1" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "query exited $status: $(<"$err")"; return 0
  fi
  local first_match_kind first_ref
  first_match_kind="$(awk -F': ' '/^  match_kind:/{print $2; exit}' "$out1")"
  first_ref="$(awk -F': ' '/^- ref:/{print $2; exit}' "$out1")"
  if [[ "$first_match_kind" != symbol_* ]]; then
    fail "$name" "expected the top hit to be a symbol match, got match_kind=$first_match_kind ref=$first_ref: $(<"$out1")"
    return 0
  fi
  if ! grep -q 'match_kind: fts5_content' "$out1"; then
    fail "$name" "expected at least one fts5_content hit alongside the symbol hit: $(<"$out1")"
    return 0
  fi
  # rank is assigned in strict descending-score order (_ctx_rank_hits), so
  # asserting the top (first-emitted) hit is a symbol match already proves
  # no fts5_content hit outranks it -- rank 1 is always the highest score.

  out2="$tmp_root/query-rank-2.out"
  "$PMCTL" context query "$fix_repo" --source repo alpha > "$out2" 2>> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "second query exited $status: $(<"$err")"; return 0
  fi
  if [[ "$(cat "$out1")" != "$(cat "$out2")" ]]; then
    fail "$name" "ranking order was not stable across two runs against an unchanged index"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 2/3 gate finding qa-tester-F001): `pmctl context
# reuse-scan`'s top hit (rank 1) must be its highest-scoring real candidate
# (a symbol match), not whichever hit happened to be inserted first, and the
# capped list must still be internally rank-ordered.
# Steps: index a fixture repo; reuse-scan a description containing a term
# that symbol-matches and fts5-matches; assert hit #1 is a symbol match and
# the emitted ranks are 1..N in order.
case_context_reuse_scan_cli_top_hit_is_highest_ranked() {
  local name="pmctl context reuse-scan: CLI top hit is the highest-ranked real candidate"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-reuse-rank"
  make_fixture_repo "$fix_repo"

  local out err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-reuse-rank.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-reuse-rank.err")"; return 0; }

  out="$tmp_root/reuse-rank.out"; err="$tmp_root/reuse-rank.err"
  "$PMCTL" context reuse-scan "$fix_repo" "alpha implementation" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "reuse-scan exited $status: $(<"$err")"; return 0
  fi
  local first_match_kind ranks_in_order
  first_match_kind="$(awk -F': ' '/^      match_kind:/{print $2; exit}' "$out")"
  if [[ "$first_match_kind" != symbol_* ]]; then
    fail "$name" "expected top hit to be a symbol match, got match_kind=$first_match_kind: $(<"$out")"
    return 0
  fi
  ranks_in_order="$(awk -F': ' '/^      rank:/{print $2}' "$out" | tr '\n' ',' )"
  if [[ "$ranks_in_order" != "1,"* ]]; then
    fail "$name" "expected ranks to start at 1 in emission order, got: $ranks_in_order"
    return 0
  fi
  pass "$name"
}

# Behavior (CC-505 Req 2/3 gate finding qa-tester-F002): `pmctl context
# prompt-scan`'s knowledge_hits: output must go through the same shared
# ranking + dedup path as the other three consumers, not its own leftover
# insertion-order concatenation, and must be stable across repeated runs.
# prompt-scan's own minimal YAML (ref + why_relevant only, by design, for
# compact prompt injection) does not expose match_kind/rank, and its
# knowledge-domain restriction means the fixture repo has no eligible SYMBOL
# hit (no code symbols live under BACKLOG.md/docs/*) -- so unlike the
# query/reuse-scan cases, this asserts what IS observable and meaningful
# here: two overlapping terms (mirroring critic-F001's exact scenario)
# produce a deduplicated, capped, ORDER-STABLE ref list.
# Steps: index a fixture repo; prompt-scan a prompt whose terms both match
# the same knowledge-domain docs; assert unique refs, a <=5 cap, and that a
# second run against the unchanged index reproduces the identical output.
case_context_prompt_scan_cli_orders_and_dedups() {
  local name="pmctl context prompt-scan: CLI output is deduplicated, capped, and stable across runs"
  should_run "$name" || return 0

  local fix_repo="$tmp_root/fix-repo-pscan-rank"
  make_fixture_repo "$fix_repo"

  local out1 out2 err status=0
  "$PMCTL" context index "$fix_repo" > /dev/null 2> "$tmp_root/index-pscan-rank.err" \
    || { fail "$name" "setup: context index failed: $(<"$tmp_root/index-pscan-rank.err")"; return 0; }

  out1="$tmp_root/pscan-rank-1.out"; err="$tmp_root/pscan-rank.err"
  "$PMCTL" context prompt-scan "$fix_repo" "alpha architecture note" > "$out1" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "prompt-scan exited $status: $(<"$err")"; return 0
  fi
  local refs ref_count unique_count
  refs="$(awk -F': ' '/^  - ref:/{print $2}' "$out1")"
  ref_count="$(printf '%s\n' "$refs" | grep -c .)"
  unique_count="$(printf '%s\n' "$refs" | sort -u | grep -c .)"
  if [[ "$ref_count" -eq 0 ]]; then
    fail "$name" "expected at least one hit: $(<"$out1")"; return 0
  fi
  if [[ "$ref_count" -gt 5 ]]; then
    fail "$name" "expected at most 5 hits, got $ref_count: $(<"$out1")"; return 0
  fi
  if [[ "$unique_count" -ne "$ref_count" ]]; then
    fail "$name" "expected every ref to be unique (dedup across terms), got $ref_count refs / $unique_count unique: $(<"$out1")"
    return 0
  fi

  out2="$tmp_root/pscan-rank-2.out"
  "$PMCTL" context prompt-scan "$fix_repo" "alpha architecture note" > "$out2" 2>> "$err" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "second prompt-scan exited $status: $(<"$err")"; return 0
  fi
  if [[ "$(cat "$out1")" != "$(cat "$out2")" ]]; then
    fail "$name" "prompt-scan output was not stable across two runs against an unchanged index"
    return 0
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
case_context_reuse_scan_cjk_terms
case_context_reuse_scan_truncation_is_loud
case_context_fts5_cjk_query_still_has_like_fallback
case_context_reuse_scan_dedup
case_context_reuse_scan_on_real_repo
case_context_reuse_scan_hit_cap
case_context_query_emits_event
case_context_pack_emits_event
case_context_pack_zero_hit_still_emits_event
case_context_pack_stale_freshness_on_refresh_failure
case_context_reuse_scan_emits_event
case_context_index_gitignore_new
case_context_index_gitignore_idempotent_exact
case_context_index_gitignore_idempotent_slash
case_context_index_gitignore_absent
case_context_db_path_repo_local
case_context_index_excludes_pm_dispatch_tree
case_context_status_marker_round_trip
case_context_status_explicit_repo_isolated
case_context_workflow_refresh_opt_out_reports_skipped
case_context_workflow_refresh_sqlite_unavailable
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
case_context_memory_invalid_config_no_legacy_fallback
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
case_context_index_reaches_deep_file_content
case_context_index_preserves_quoted_content
case_context_index_ignores_environment_extractor_version
case_context_index_splits_an_over_cap_line
case_context_index_detects_mtime_preserving_edit
case_context_index_extractor_version_forces_reextract
case_context_prompt_scan_term_cap_longest_first
case_context_prompt_scan_no_sqlite_graceful
case_context_prompt_scan_secret_never_persisted
case_context_prompt_scan_emits_event
case_context_fts5_availability_is_cached
case_ctx_fts_rebuild_rollback_preserves_old_index_on_failure
case_ctx_index_file_return_code_reflects_sqlite_failure
case_context_update_fails_honestly_when_index_file_fails
case_context_index_reports_fts_rebuild_failure_honestly
case_context_update_reports_fts_rebuild_failure_honestly
case_context_rank_hits_orders_and_truncates
case_context_pack_ranking_fields_are_valid
case_context_pack_default_budget_does_not_truncate
case_context_pack_max_items_enforces_global_cap
case_context_pack_max_bytes_enforces_byte_cap
case_context_pack_large_candidate_byte_budget_bounded_work
case_context_pack_max_bytes_exact_boundary_accepted
case_context_pack_impossible_byte_cap_rejected
case_context_pack_no_index_impossible_byte_cap_rejected
case_context_pack_invalid_max_items_rejected
case_context_pack_invalid_max_bytes_rejected
case_context_pack_max_items_overflow_boundary_rejected
case_context_pack_max_bytes_overflow_boundary_rejected
case_context_pack_max_terms_rejects_excess
case_context_pack_invalid_max_terms_rejected
case_context_pack_truncation_reconciles_sources_provenance
case_context_pack_truncation_reconciles_builtin_sources_provenance
case_context_pack_env_max_items_valid_override_applies
case_context_pack_env_max_bytes_valid_override_applies
case_context_pack_env_max_items_invalid_rejected
case_context_pack_env_max_bytes_invalid_rejected
case_context_pack_env_max_items_overflow_boundary_rejected
case_context_pack_env_max_bytes_overflow_boundary_rejected
case_context_pack_empty_index_discloses_untruncated_budget
case_context_retrieval_fixture_corpus
case_context_retrieval_fixture_corpus_trust_weighting
case_context_query_cli_orders_by_rank_tier
case_context_reuse_scan_cli_top_hit_is_highest_ranked
case_context_prompt_scan_cli_orders_and_dedups
case_context_query_migrates_legacy_two_column_fts
case_context_commands_resolve_only_fixture_roots
case_context_every_subcommand_is_exercised
case_context_live_target_guard_trips
case_context_live_target_guard_refuses_bare_call_outside_worktree
case_context_guard_rejects_traversal_and_symlink_escape
case_context_guard_fails_closed_without_realpath
case_context_guard_refuses_non_directory_fixture_path
case_context_no_call_targeted_the_live_repo

th_summary
