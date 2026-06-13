#!/usr/bin/env bash
# Regression tests for scripts/archive-closed-backlog.sh.
#
# Contract under test (pm-schema §4 "working-set" model):
#   A terminal ticket — index status `✅ done` (dated or not), `✅ closed
#   YYYY-MM-DD`, `🟢 superseded YYYY-MM-DD`, or `🚫 dropped YYYY-MM-DD` — is
#   moved OUT of BACKLOG.md entirely: its index row is dropped AND its body
#   section is moved to BACKLOG-ARCHIVE.md, with NO `**See**:` stub left
#   behind. Non-terminal rows/bodies (`🔵 active`, `🟡`/`⏸ deferred`,
#   `🟢 someday`, `⚠️ partial`) are untouched. (CC-378: `✅ done` and
#   `🟢 superseded` became terminal — the prior soft-close-stays-active rule
#   was retired.)

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVER="$REPO_ROOT/scripts/archive-closed-backlog.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

setup_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts"
  cp "$ARCHIVER" "$repo/scripts/archive-closed-backlog.sh"
  chmod +x "$repo/scripts/archive-closed-backlog.sh"
}

write_archive() {
  local repo="$1"
  cat > "$repo/BACKLOG-ARCHIVE.md" <<'EOF'
<!-- pm-dispatch: backlog-archive 2026-01-01 -->
# archive

Last archived: 2026-01-01

---

EOF
}

# One closed (CC-001) + one active (CC-002), each with an index row and a body.
write_happy_backlog() {
  local repo="$1"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-001 | ✅ closed 2026-01-01 | test closed | ops | 2026-01-01 | pr:#1 | P3 | — |
| CC-002 | 🔵 active | active section | ops | 2026-01-02 | — | P2 | — |

## CC-001 — test closed ✅ 2026-01-01

**Problem**: something

**Why**: reason

## CC-002 — active section 🔵 active

**Problem**: still active

EOF
}

write_dropped_backlog() {
  local repo="$1"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-003 | 🚫 dropped 2026-01-01 | dropped section | ops | 2026-01-01 | — | — | — |

## CC-003 — dropped section 🚫 2026-01-01

**Problem**: obsolete

**Why**: no longer needed

EOF
}

run_archiver() {
  local repo="$1"
  shift
  (cd "$repo" && bash "$repo/scripts/archive-closed-backlog.sh" "$@")
}

count_literal() {
  local file="$1" needle="$2"
  { grep -F -- "$needle" "$file" || true; } | wc -l | tr -d ' '
}

case_happy_path() {
  # A closed (✅) ticket: its index row AND body leave BACKLOG.md (no stub),
  # the body lands in BACKLOG-ARCHIVE.md, the active ticket is untouched, and
  # archive timestamps update. Output: "Archived 1 ticket(s)".
  local name="archive-happy-path"
  should_run "$name" || return 0

  local repo="$tmp_root/happy"
  setup_repo "$repo"
  write_happy_backlog "$repo"
  write_archive "$repo"

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if grep -Fq '**See**: BACKLOG-ARCHIVE.md' "$repo/BACKLOG.md"; then
    fail "$name" "working-set contract leaves no stub, but a **See** stub was written"
    return
  fi
  if grep -Eq '^\| CC-001 \|' "$repo/BACKLOG.md"; then
    fail "$name" "closed index row not removed from BACKLOG.md"
    return
  fi
  if grep -Fq '## CC-001' "$repo/BACKLOG.md"; then
    fail "$name" "closed body section not removed from BACKLOG.md"
    return
  fi
  if ! grep -Fq '**Problem**: something' "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "closed body not in BACKLOG-ARCHIVE.md"
    return
  fi
  if ! grep -Eq '^\| CC-002 \|' "$repo/BACKLOG.md"; then
    fail "$name" "active index row was removed"
    return
  fi
  if ! grep -Fq '**Problem**: still active' "$repo/BACKLOG.md"; then
    fail "$name" "active section was modified"
    return
  fi
  local today
  today="$(date +%Y-%m-%d)"
  if ! grep -Fq "Last archived: $today" "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "archive timestamp line not updated"
    return
  fi
  if ! grep -Fq "<!-- pm-dispatch: backlog-archive $today -->" "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "archive marker not updated"
    return
  fi
  if [[ "$output" != *"Archived 1 ticket(s)"* ]]; then
    fail "$name" "unexpected output: $output"
    return
  fi

  pass "$name"
}

case_idempotency() {
  # Running twice must not duplicate the archived body, and the second run
  # reports "Archived 0 ticket(s)".
  local name="archive-idempotency"
  should_run "$name" || return 0

  local repo="$tmp_root/idempotency"
  setup_repo "$repo"
  write_happy_backlog "$repo"
  write_archive "$repo"

  local first_output="" second_output="" rc=0
  set +e
  first_output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "first run exited $rc: $first_output"
    return
  fi

  set +e
  second_output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "second run exited $rc: $second_output"
    return
  fi
  if [[ "$second_output" != *"Archived 0 ticket(s)"* ]]; then
    fail "$name" "unexpected second-run output: $second_output"
    return
  fi
  if [[ "$(count_literal "$repo/BACKLOG-ARCHIVE.md" '## CC-001')" != "1" ]]; then
    fail "$name" "archive contains duplicate CC-001 section"
    return
  fi

  pass "$name"
}

case_dry_run() {
  # --dry-run reports the count but makes no file changes.
  local name="archive-dry-run"
  should_run "$name" || return 0

  local repo="$tmp_root/dry-run"
  setup_repo "$repo"
  write_happy_backlog "$repo"
  write_archive "$repo"
  cp "$repo/BACKLOG.md" "$repo/BACKLOG.before"
  cp "$repo/BACKLOG-ARCHIVE.md" "$repo/BACKLOG-ARCHIVE.before"

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" --dry-run 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if [[ "$output" != *"Would archive 1 ticket(s)"* ]]; then
    fail "$name" "unexpected output: $output"
    return
  fi
  if ! cmp -s "$repo/BACKLOG.before" "$repo/BACKLOG.md"; then
    fail "$name" "BACKLOG.md changed during dry-run"
    return
  fi
  if ! cmp -s "$repo/BACKLOG-ARCHIVE.before" "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "BACKLOG-ARCHIVE.md changed during dry-run"
    return
  fi

  pass "$name"
}

case_dropped_section() {
  # Dropped (🚫) tickets archive identically to closed ones.
  local name="archive-dropped-section"
  should_run "$name" || return 0

  local repo="$tmp_root/dropped"
  setup_repo "$repo"
  write_dropped_backlog "$repo"
  write_archive "$repo"

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if grep -Eq '^\| CC-003 \|' "$repo/BACKLOG.md"; then
    fail "$name" "dropped index row not removed"
    return
  fi
  if grep -Fq '**Problem**: obsolete' "$repo/BACKLOG.md"; then
    fail "$name" "dropped body still in BACKLOG.md"
    return
  fi
  if ! grep -Fq '**Problem**: obsolete' "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "dropped body not archived"
    return
  fi
  if [[ "$output" != *"Archived 1 ticket(s)"* ]]; then
    fail "$name" "unexpected output: $output"
    return
  fi

  pass "$name"
}

case_unknown_flag() {
  # An unsupported flag exits 1 with an error message.
  local name="archive-unknown-flag"
  should_run "$name" || return 0

  local repo="$tmp_root/unknown-flag"
  mkdir -p "$repo/scripts"
  cp "$ARCHIVER" "$repo/scripts/archive-closed-backlog.sh"
  printf '' > "$repo/BACKLOG.md"
  printf '' > "$repo/BACKLOG-ARCHIVE.md"

  local output rc=0
  set +e
  output=$(bash "$repo/scripts/archive-closed-backlog.sh" --unsupported-flag 2>&1)
  rc=$?
  set -e

  if [[ "$rc" -ne 1 ]]; then
    fail "$name" "expected exit 1 for unknown flag, got $rc"
    return
  fi
  if [[ "$output" != *"unknown arg"* ]]; then
    fail "$name" "expected 'unknown arg' in output, got: $output"
    return
  fi
  pass "$name"
}

case_no_terminal_sections() {
  # Only non-terminal tickets → exit 0, "Archived 0 ticket(s)", files unchanged.
  local name="archive-no-terminal-sections"
  should_run "$name" || return 0

  local repo="$tmp_root/no-terminal"
  setup_repo "$repo"
  write_archive "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-010 | 🔵 active | active only | ops | 2026-01-01 | — | — | — |

## CC-010 — active only 🔵 active

**Problem**: still open

EOF
  cp "$repo/BACKLOG.md" "$repo/BACKLOG.before"
  cp "$repo/BACKLOG-ARCHIVE.md" "$repo/BACKLOG-ARCHIVE.before"

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if [[ "$output" != *"Archived 0 ticket(s)"* ]]; then
    fail "$name" "unexpected output: $output"
    return
  fi
  if ! cmp -s "$repo/BACKLOG.before" "$repo/BACKLOG.md"; then
    fail "$name" "BACKLOG.md changed on no-op run"
    return
  fi
  if ! cmp -s "$repo/BACKLOG-ARCHIVE.before" "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "BACKLOG-ARCHIVE.md changed on no-op run"
    return
  fi

  pass "$name"
}

case_index_row_removed() {
  # The index row of a terminal ticket is dropped while non-terminal rows are
  # preserved verbatim (the row-shedding behavior is the core working-set fix).
  local name="archive-index-row-removed"
  should_run "$name" || return 0

  local repo="$tmp_root/index-row"
  setup_repo "$repo"
  write_archive "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-040 | ✅ closed 2026-03-01 | closed | ops | 2026-03-01 | pr:#7 | — | — |
| CC-041 | 🟡 deferred | deferred | ops | 2026-03-02 | — | P3 | — |

## CC-040 — closed ✅ 2026-03-01

**Problem**: done

## CC-041 — deferred 🟡 deferred

**Problem**: later

EOF

  local rc=0
  set +e
  run_archiver "$repo" >/dev/null 2>&1
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc"
    return
  fi
  if grep -Eq '^\| CC-040 \|' "$repo/BACKLOG.md"; then
    fail "$name" "terminal row CC-040 still present in index"
    return
  fi
  if ! grep -Eq '^\| CC-041 \| 🟡 deferred \| deferred \|' "$repo/BACKLOG.md"; then
    fail "$name" "non-terminal row CC-041 not preserved verbatim"
    return
  fi

  pass "$name"
}

case_cc283_sentinel_regression() {
  # CC-283: a closed body that QUOTES the stub sentinel in its prose must still
  # be archived (the old substring-anywhere has_see scan mis-skipped it).
  local name="archive-cc283-sentinel-regression"
  should_run "$name" || return 0

  local repo="$tmp_root/cc283"
  setup_repo "$repo"
  write_archive "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-050 | ✅ closed 2026-04-01 | quotes sentinel | ops | 2026-04-01 | pr:#8 | — | — |

## CC-050 — quotes sentinel ✅ 2026-04-01

**Problem**: documents that the archiver replaces a body with `**See**: BACKLOG-ARCHIVE.md`.

**Why**: this prose must not cause the section to be skipped.

EOF

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if [[ "$output" != *"Archived 1 ticket(s)"* ]]; then
    fail "$name" "sentinel-quoting body was not archived: $output"
    return
  fi
  if grep -Fq '## CC-050' "$repo/BACKLOG.md"; then
    fail "$name" "CC-050 body still in BACKLOG.md (CC-283 regression)"
    return
  fi
  if ! grep -Fq 'this prose must not cause' "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "CC-050 body not archived"
    return
  fi

  pass "$name"
}

case_done_and_superseded_archived() {
  # CC-378: `✅ done` (dated or not) and `🟢 superseded YYYY-MM-DD` are terminal
  # and must be archived — index row dropped, body moved to BACKLOG-ARCHIVE.md.
  # `🟢 someday` (active) is left untouched (guards the 🟢 someday↔superseded
  # collision: same emoji, opposite liveness).
  local name="archive-done-and-superseded"
  should_run "$name" || return 0

  local repo="$tmp_root/done-superseded"
  setup_repo "$repo"
  write_archive "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-060 | ✅ done | soft close | ops | 2026-05-01 | — | — | — |
| CC-061 | 🟢 superseded 2026-06-14 | replaced | ops | 2026-05-01 | — | — | — |
| CC-062 | 🟢 someday | live idea | ops | 2026-05-01 | — | — | — |
| CC-063 | ✅ done 2026-06-14 | dated done | ops | 2026-05-01 | pr:#9 | — | — |

## CC-060 — soft close ✅ done

**Problem**: completed, no PR tracking needed

## CC-061 — replaced 🟢 superseded 2026-06-14

**Superseded by [[CC-999]]**: work moved.

## CC-062 — live idea 🟢 someday

**Problem**: still open

## CC-063 — dated done ✅ done 2026-06-14

**Problem**: shipped with a date

EOF

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if [[ "$output" != *"Archived 3 ticket(s)"* ]]; then
    fail "$name" "expected 3 archived (undated done + dated done + superseded): $output"
    return
  fi
  # done + superseded gone from BACKLOG; someday preserved.
  if grep -q '^## CC-060 ' "$repo/BACKLOG.md" || grep -qE '^\| CC-060 \|' "$repo/BACKLOG.md"; then
    fail "$name" "✅ done CC-060 should be archived out of BACKLOG"
    return
  fi
  if grep -q '^## CC-061 ' "$repo/BACKLOG.md" || grep -qE '^\| CC-061 \|' "$repo/BACKLOG.md"; then
    fail "$name" "🟢 superseded CC-061 should be archived out of BACKLOG"
    return
  fi
  if ! grep -qE '^\| CC-062 \|' "$repo/BACKLOG.md"; then
    fail "$name" "🟢 someday CC-062 (active) must be preserved"
    return
  fi
  # dated `✅ done YYYY-MM-DD` is terminal too (optional-date branch).
  if grep -q '^## CC-063 ' "$repo/BACKLOG.md" || grep -qE '^\| CC-063 \|' "$repo/BACKLOG.md"; then
    fail "$name" "dated ✅ done CC-063 should be archived out of BACKLOG"
    return
  fi
  # bodies landed in the archive.
  if ! grep -q '^## CC-060 ' "$repo/BACKLOG-ARCHIVE.md" || ! grep -q '^## CC-061 ' "$repo/BACKLOG-ARCHIVE.md" || ! grep -q '^## CC-063 ' "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "done/superseded/dated-done bodies not appended to archive"
    return
  fi

  pass "$name"
}

case_malformed_status_not_archived() {
  # CC-378 gate fix: the terminal predicate matches EXACT token/date forms only.
  # Malformed near-miss statuses must NOT be silently archived (no prefix
  # over-match): `done`-prefixed non-tokens, `superseded`-prefixed non-tokens,
  # undated `superseded` (date required), and structurally-bad dates.
  local name="archive-malformed-status-not-archived"
  should_run "$name" || return 0

  local repo="$tmp_root/malformed-status"
  setup_repo "$repo"
  write_archive "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-070 | ✅ done-ish | near-miss done suffix | ops | 2026-05-01 | — | — | — |
| CC-071 | 🟢 supersededsoon | near-miss superseded suffix | ops | 2026-05-01 | — | — | — |
| CC-072 | ✅ donezo | near-miss done token | ops | 2026-05-01 | — | — | — |
| CC-073 | 🟢 superseded | superseded missing required date | ops | 2026-05-01 | — | — | — |
| CC-074 | ✅ done 2026-6-14 | done with non-YYYY-MM-DD date | ops | 2026-05-01 | — | — | — |

## CC-070 — near-miss done suffix ✅ done-ish

**Problem**: malformed

## CC-071 — near-miss superseded suffix 🟢 supersededsoon

**Problem**: malformed

## CC-072 — near-miss done token ✅ donezo

**Problem**: malformed

## CC-073 — superseded missing required date 🟢 superseded

**Problem**: malformed

## CC-074 — done with non-YYYY-MM-DD date ✅ done 2026-6-14

**Problem**: malformed

EOF
  cp "$repo/BACKLOG.md" "$repo/BACKLOG.before"

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if [[ "$output" != *"Archived 0 ticket(s)"* ]]; then
    fail "$name" "malformed near-miss statuses must not be archived: $output"
    return
  fi
  if ! cmp -s "$repo/BACKLOG.before" "$repo/BACKLOG.md"; then
    fail "$name" "BACKLOG was modified — a malformed status was archived"
    return
  fi

  pass "$name"
}

case_legacy_stub_sweep() {
  # A legacy ✅ stub (row + `**See**:` body) whose full body already lives in
  # the archive is swept: the row and the stub body are removed, and the
  # archive body is not duplicated.
  local name="archive-legacy-stub-sweep"
  should_run "$name" || return 0

  local repo="$tmp_root/legacy-stub"
  setup_repo "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-070 | ✅ closed 2026-02-02 | legacy stub | ops | 2026-02-01 | pr:#9 | — | — |
| CC-071 | 🔵 active | live | ops | 2026-02-03 | — | — | — |

## CC-070 — legacy stub ✅ 2026-02-02

**See**: BACKLOG-ARCHIVE.md

## CC-071 — live 🔵 active

**Problem**: active body

EOF
  cat > "$repo/BACKLOG-ARCHIVE.md" <<'EOF'
<!-- pm-dispatch: backlog-archive 2026-02-01 -->
# archive

Last archived: 2026-02-01

---

## CC-070 — legacy stub ✅ 2026-02-02

**Problem**: original full body archived earlier

**Why**: reason

EOF

  local rc=0
  set +e
  run_archiver "$repo" >/dev/null 2>&1
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc"
    return
  fi
  if grep -Eq '^\| CC-070 \|' "$repo/BACKLOG.md"; then
    fail "$name" "legacy stub row not removed"
    return
  fi
  if grep -Fq '## CC-070' "$repo/BACKLOG.md"; then
    fail "$name" "legacy stub body not removed"
    return
  fi
  if [[ "$(count_literal "$repo/BACKLOG-ARCHIVE.md" '## CC-070')" != "1" ]]; then
    fail "$name" "archive body duplicated during stub sweep"
    return
  fi
  if ! grep -Fq 'original full body archived earlier' "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "archive full body was clobbered by the stub"
    return
  fi
  if ! grep -Eq '^\| CC-071 \|' "$repo/BACKLOG.md"; then
    fail "$name" "active row CC-071 was removed"
    return
  fi

  pass "$name"
}

case_recovery_partial_write() {
  # Archive mv succeeded but backlog mv did not on a prior run: the archive
  # already has the full body while BACKLOG.md still has the row + full body.
  # A retry drops the row and body (no stub) without duplicating the archive.
  local name="archive-recovery-partial-write"
  should_run "$name" || return 0

  local repo="$tmp_root/recovery"
  setup_repo "$repo"

  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-020 | ✅ closed 2026-01-01 | recovery test | ops | 2026-01-01 | — | — | — |

## CC-020 — recovery test ✅ 2026-01-01

**Problem**: partial write body

**Why**: testing recovery

EOF

  cat > "$repo/BACKLOG-ARCHIVE.md" <<'EOF'
<!-- pm-dispatch: backlog-archive 2026-01-01 -->
# archive

Last archived: 2026-01-01

---

## CC-020 — recovery test ✅ 2026-01-01

**Problem**: partial write body

**Why**: testing recovery

EOF

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if grep -Fq '**See**: BACKLOG-ARCHIVE.md' "$repo/BACKLOG.md"; then
    fail "$name" "no stub should be written under the working-set contract"
    return
  fi
  if grep -Fq '**Problem**: partial write body' "$repo/BACKLOG.md"; then
    fail "$name" "original body still in BACKLOG.md after recovery"
    return
  fi
  if grep -Eq '^\| CC-020 \|' "$repo/BACKLOG.md"; then
    fail "$name" "terminal row still in BACKLOG.md after recovery"
    return
  fi
  local count
  count="$(count_literal "$repo/BACKLOG-ARCHIVE.md" '## CC-020')"
  if [[ "$count" != "1" ]]; then
    fail "$name" "expected CC-020 exactly once in archive, got $count"
    return
  fi

  pass "$name"
}

case_suffixed_and_multiprefix_ids() {
  # ID grammar (§2.2) allows sub-ticket suffixes (CC-104b) and any 1–4 letter
  # prefix (JS-200). Both must be recognized as terminal and archived; a
  # suffixed NON-terminal row must be preserved.
  local name="archive-suffixed-and-multiprefix-ids"
  should_run "$name" || return 0

  local repo="$tmp_root/suffixed"
  setup_repo "$repo"
  write_archive "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-104b | ✅ closed 2026-01-01 | suffixed closed | ops | 2026-01-01 | pr:#2 | — | — |
| JS-200 | 🚫 dropped 2026-01-02 | other prefix dropped | ops | 2026-01-02 | — | — | — |
| CC-104d | 🟡 deferred | suffixed deferred | ops | 2026-01-03 | — | P3 | — |

## CC-104b — suffixed closed ✅ 2026-01-01

**Problem**: a sub-ticket closed body

## JS-200 — other prefix dropped 🚫 2026-01-02

**Problem**: a different-prefix dropped body

## CC-104d — suffixed deferred 🟡 deferred

**Problem**: still open

EOF

  local output="" rc=0
  set +e
  output="$(run_archiver "$repo" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $output"
    return
  fi
  if [[ "$output" != *"Archived 2 ticket(s)"* ]]; then
    fail "$name" "expected 2 archived (CC-104b + JS-200), got: $output"
    return
  fi
  if grep -Eq '^\| CC-104b \|' "$repo/BACKLOG.md"; then
    fail "$name" "suffixed terminal row CC-104b not removed"
    return
  fi
  if grep -Eq '^\| JS-200 \|' "$repo/BACKLOG.md"; then
    fail "$name" "multi-prefix terminal row JS-200 not removed"
    return
  fi
  if grep -Fq '## CC-104b' "$repo/BACKLOG.md" || grep -Fq '## JS-200' "$repo/BACKLOG.md"; then
    fail "$name" "terminal suffixed/multi-prefix body not removed"
    return
  fi
  if ! grep -Eq '^\| CC-104d \|' "$repo/BACKLOG.md"; then
    fail "$name" "non-terminal suffixed row CC-104d was removed"
    return
  fi

  pass "$name"
}

case_orphan_terminal_row_warns() {
  # A terminal index row with NO matching body section: the row is dropped and
  # a warning is emitted to stderr so the operator can reconcile (no silent
  # data loss). The active ticket is preserved.
  local name="archive-orphan-terminal-row-warns"
  should_run "$name" || return 0

  local repo="$tmp_root/orphan-row"
  setup_repo "$repo"
  write_archive "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-090 | ✅ closed 2026-01-01 | orphan row, no body | ops | 2026-01-01 | pr:#3 | — | — |
| CC-091 | 🔵 active | live | ops | 2026-01-02 | — | — | — |

## CC-091 — live 🔵 active

**Problem**: active body

EOF

  local stderr_out="" rc=0
  set +e
  stderr_out="$(run_archiver "$repo" 2>&1 >/dev/null)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "script exited $rc: $stderr_out"
    return
  fi
  if [[ "$stderr_out" != *"CC-090"*"terminal index row dropped"* ]]; then
    fail "$name" "expected orphan-row warning for CC-090, got: $stderr_out"
    return
  fi
  if grep -Eq '^\| CC-090 \|' "$repo/BACKLOG.md"; then
    fail "$name" "orphan terminal row CC-090 not dropped"
    return
  fi
  if ! grep -Eq '^\| CC-091 \|' "$repo/BACKLOG.md"; then
    fail "$name" "active row CC-091 was removed"
    return
  fi

  pass "$name"
}

case_happy_path
case_idempotency
case_dry_run
case_dropped_section
case_unknown_flag
case_no_terminal_sections
case_suffixed_and_multiprefix_ids
case_index_row_removed
case_cc283_sentinel_regression
case_done_and_superseded_archived
case_malformed_status_not_archived
case_legacy_stub_sweep
case_recovery_partial_write
case_orphan_terminal_row_warns

th_summary
