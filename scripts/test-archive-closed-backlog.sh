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

case_happy_path
case_idempotency
case_dry_run
case_dropped_section

th_summary
