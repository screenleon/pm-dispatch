#!/usr/bin/env bash
# Regression tests for scripts/archive-closed-backlog.sh.

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

write_happy_backlog() {
  local repo="$1"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

## CC-001 - test closed ✅ 2026-01-01

**Problem**: something

**Why**: reason

## CC-002 - active section

**Problem**: still active

EOF
}

write_dropped_backlog() {
  local repo="$1"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

## CC-003 - dropped section 🚫 2026-01-01

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
  # Verifies that a non-stub closed (✅) section body is appended to BACKLOG-ARCHIVE.md,
  # replaced with a **See** stub in BACKLOG.md, and archive timestamps are updated.
  #
  # Steps:
  #   1. Create BACKLOG.md with one non-stub closed section and one active section.
  #   2. Create BACKLOG-ARCHIVE.md with a minimal header.
  #   3. Run archive-closed-backlog.sh.
  #   4. Assert exit 0, stub in BACKLOG.md, body in BACKLOG-ARCHIVE.md,
  #      active section unchanged, timestamps updated, output "Archived 1 section(s)".
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
  if ! grep -Fq '**See**: BACKLOG-ARCHIVE.md' "$repo/BACKLOG.md"; then
    fail "$name" "stub not written to BACKLOG.md"
    return
  fi
  if grep -Fq '**Problem**: something' "$repo/BACKLOG.md"; then
    fail "$name" "original body still in BACKLOG.md"
    return
  fi
  if ! grep -Fq '**Problem**: something' "$repo/BACKLOG-ARCHIVE.md"; then
    fail "$name" "body not in BACKLOG-ARCHIVE.md"
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
  if [[ "$output" != *"Archived 1 section(s)"* ]]; then
    fail "$name" "unexpected output: $output"
    return
  fi

  pass "$name"
}

case_idempotency() {
  # Verifies that running the script twice does not create duplicate archive entries.
  #
  # Steps:
  #   1. Create same fixtures as happy path.
  #   2. Run archive-closed-backlog.sh once (first run).
  #   3. Run archive-closed-backlog.sh a second time (second run).
  #   4. Assert second run exits 0, output "Archived 0 section(s)",
  #      and the section header appears exactly once in BACKLOG-ARCHIVE.md.
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
  if [[ "$second_output" != *"Archived 0 section(s)"* ]]; then
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
  # Verifies that --dry-run reports the count of archiveable sections but makes no file changes.
  #
  # Steps:
  #   1. Create fixtures with one non-stub closed section; snapshot both files.
  #   2. Run archive-closed-backlog.sh --dry-run.
  #   3. Assert exit 0, output "Would archive 1 section(s)",
  #      and both files are byte-identical to their snapshots.
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
  if [[ "$output" != *"Would archive 1 section(s)"* ]]; then
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
  # Verifies that dropped (🚫) sections are archived and stubbed identically to closed (✅) sections.
  #
  # Steps:
  #   1. Create BACKLOG.md with one non-stub dropped section.
  #   2. Create minimal BACKLOG-ARCHIVE.md.
  #   3. Run archive-closed-backlog.sh.
  #   4. Assert exit 0, stub in BACKLOG.md, body in BACKLOG-ARCHIVE.md,
  #      output "Archived 1 section(s)".
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
  if ! grep -Fq '**See**: BACKLOG-ARCHIVE.md' "$repo/BACKLOG.md"; then
    fail "$name" "dropped section stub not written"
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
  if [[ "$output" != *"Archived 1 section(s)"* ]]; then
    fail "$name" "unexpected output: $output"
    return
  fi

  pass "$name"
}

case_unknown_flag() {
  # Verifies that an unsupported CLI flag causes the script to exit 1 with an error message.
  #
  # Steps:
  #   1. Create minimal BACKLOG.md and BACKLOG-ARCHIVE.md.
  #   2. Run archive-closed-backlog.sh --unsupported-flag.
  #   3. Assert exit 1 and output contains "unknown arg".
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
  # Verifies that a BACKLOG.md with only active sections exits 0, reports
  # "Archived 0 section(s)", and leaves both files byte-identical.
  #
  # Steps:
  #   1. Create BACKLOG.md with only one active (non-terminal) section.
  #   2. Create a minimal BACKLOG-ARCHIVE.md.
  #   3. Snapshot both files.
  #   4. Run archive-closed-backlog.sh.
  #   5. Assert exit 0, output "Archived 0 section(s)", and both files are unchanged.
  local name="archive-no-terminal-sections"
  should_run "$name" || return 0

  local repo="$tmp_root/no-terminal"
  setup_repo "$repo"
  write_archive "$repo"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

## CC-010 - active only

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
  if [[ "$output" != *"Archived 0 section(s)"* ]]; then
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

case_recovery_partial_write() {
  # Verifies safe recovery when BACKLOG-ARCHIVE.md was already updated (archive written)
  # but BACKLOG.md was not yet stubbed (simulating a partial-write failure between the
  # two mv operations). A retry must stub BACKLOG.md without duplicating the archive entry.
  #
  # Steps:
  #   1. Create BACKLOG.md with a non-stub closed section (body still present).
  #   2. Create BACKLOG-ARCHIVE.md that ALREADY contains the same section body
  #      (simulating the state after archive mv succeeded but backlog mv failed).
  #   3. Run archive-closed-backlog.sh.
  #   4. Assert exit 0, BACKLOG.md has stub, BACKLOG-ARCHIVE.md has section exactly once.
  local name="archive-recovery-partial-write"
  should_run "$name" || return 0

  local repo="$tmp_root/recovery"
  setup_repo "$repo"

  # Backlog still has the body (archive mv succeeded, backlog mv did not)
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

## CC-020 - recovery test ✅ 2026-01-01

**Problem**: partial write body

**Why**: testing recovery

EOF

  # Archive already has the section from the first (partial) run
  cat > "$repo/BACKLOG-ARCHIVE.md" <<'EOF'
<!-- pm-dispatch: backlog-archive 2026-01-01 -->
# archive

Last archived: 2026-01-01

---

## CC-020 - recovery test ✅ 2026-01-01

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
  if ! grep -Fq '**See**: BACKLOG-ARCHIVE.md' "$repo/BACKLOG.md"; then
    fail "$name" "stub not written after recovery run"
    return
  fi
  if grep -Fq '**Problem**: partial write body' "$repo/BACKLOG.md"; then
    fail "$name" "original body still in BACKLOG.md after recovery"
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

case_happy_path
case_idempotency
case_dry_run
case_dropped_section
case_unknown_flag
case_no_terminal_sections
case_recovery_partial_write

th_summary
