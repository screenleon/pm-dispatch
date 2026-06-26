#!/usr/bin/env bash
# Contract tests for scripts/lib/pmctl-pre-release.sh
#
# Behavioral units under test:
#   - _pra_extract_scope_rows:    parses MILESTONES.md milestone scope table → TSV
#   - _pra_check_11_pr_refs:      detects missing/TBD/non-canonical PR refs and non-✅ status
#   - _pra_check_12_body_residuals: detects TODO/仍待辦 markers in bodies; skips code fences
#   - _pra_check_13_changelog:    flags tickets not mentioned in CHANGELOG [Unreleased]
#   - _pra_check_14_status_consistency: flags index vs body heading status mismatch
#   - pmctl_pre_release_audit:    missing milestone exits 2; happy path exits 0

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/pmctl-pre-release.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/pmctl-pre-release.sh
. "$LIB"

tmp_root=""  # assigned by th_init
th_init "$@"

# ---- fixture helpers -------------------------------------------------------

write_milestones() {
  local path="$1"
  cat > "$path" <<'EOF'
# Milestones

---

## v1.0 — test milestone

### Phase 1

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-001 | closed with canonical PR | ✅ pr:#10 |
| CC-002 | closed without PR ref | ✅ |
| CC-003 | closed with TBD PR | ✅ pr:#TBD |
| CC-004 | still active | 🔵 active |

## v0.9 — previous milestone

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-099 | old ticket | ✅ pr:#1 |
EOF
}

write_backlog() {
  local path="$1"
  cat > "$path" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-001 | ✅ closed 2026-01-01 | closed ok | ops | 2026-01-01 | pr:#10 | P2 | — |
| CC-002 | ✅ closed 2026-01-02 | closed no pr | ops | 2026-01-02 | — | P3 | — |
| CC-003 | ✅ closed 2026-01-03 | closed tbd | ops | 2026-01-03 | — | P3 | — |
| CC-004 | 🔵 active | still active | ops | 2026-01-04 | — | P2 | — |

## CC-001 — closed ok ✅ 2026-01-01

**Goal**: something done.

## CC-002 — closed no pr ✅ 2026-01-02

**Goal**: something done. No PR ref.

## CC-003 — closed tbd ✅ 2026-01-03

**Goal**: done but pr:#TBD still in body.

TODO: remove this line

## CC-004 — still active 🔵 active

**Goal**: still being worked on.

EOF
}

write_backlog_archive() {
  local path="$1"
  cat > "$path" <<'EOF'
<!-- pm-dispatch: backlog-archive 2026-01-01 -->
# archive

Last archived: 2026-01-01

---

## CC-010 — archived ticket ✅ 2026-01-01

**Goal**: was archived.

EOF
}

write_changelog() {
  local path="$1"
  cat > "$path" <<'EOF'
# Changelog

---

## [Unreleased]

### Added

- Something related to CC-001 (pr:#10).
- Another change referencing CC-002.

---

## [0.9.0] — 2026-01-01

### Added

- Old stuff.
EOF
}

# ---- test cases ------------------------------------------------------------

case_extract_scope_rows() {
  local name="pre-release/extract-scope-rows"
  should_run "$name" || return 0

  local tmp="$tmp_root/extract"
  mkdir -p "$tmp"
  write_milestones "$tmp/MILESTONES.md"

  local rows
  rows="$(_pra_extract_scope_rows "$tmp/MILESTONES.md" "v1.0")"

  if [[ "$(printf '%s\n' "$rows" | wc -l | tr -d ' ')" != "4" ]]; then
    fail "$name" "expected 4 rows, got: $rows"
    return
  fi
  if ! printf '%s\n' "$rows" | grep -q "^CC-001"; then
    fail "$name" "CC-001 not found in scope rows"
    return
  fi
  if printf '%s\n' "$rows" | grep -q "^CC-099"; then
    fail "$name" "CC-099 from v0.9 should not appear in v1.0 scope"
    return
  fi
  pass "$name"
}

case_check11_canonical_pr() {
  local name="pre-release/check11-canonical-pr"
  should_run "$name" || return 0

  local scope_rows
  scope_rows="$(printf 'CC-001\t✅ pr:#10\nCC-002\t✅\nCC-003\t✅ pr:#TBD\nCC-004\t🔵 active')"

  local out
  out="$(_pra_check_11_pr_refs "$scope_rows" "v1.0")"

  if ! printf '%s\n' "$out" | grep -q "^✅ CC-001"; then
    fail "$name" "CC-001 with pr:#10 should pass: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -qE "^❌ CC-002"; then
    fail "$name" "CC-002 missing PR should fail: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -qE "^❌ CC-003"; then
    fail "$name" "CC-003 with pr:#TBD should fail: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -qE "^❌ CC-004"; then
    fail "$name" "CC-004 not ✅ should fail: $out"
    return
  fi
  pass "$name"
}

case_check12_no_residuals() {
  local name="pre-release/check12-no-residuals"
  should_run "$name" || return 0

  local tmp="$tmp_root/check12"
  mkdir -p "$tmp"
  write_backlog "$tmp/BACKLOG.md"

  # scope_rows TSV: CC-001 and CC-002 are both closed (✅)
  local scope_rows
  scope_rows="$(printf 'CC-001\t✅ pr:#10\nCC-002\t✅')"

  local out
  out="$(_pra_check_12_body_residuals "$tmp/BACKLOG.md" "" "$scope_rows")"

  if ! printf '%s\n' "$out" | grep -q "^✅ CC-001"; then
    fail "$name" "CC-001 clean body should pass: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q "^✅ CC-002"; then
    fail "$name" "CC-002 clean body should pass: $out"
    return
  fi
  pass "$name"
}

case_check12_detects_todo() {
  local name="pre-release/check12-detects-todo"
  should_run "$name" || return 0

  local tmp="$tmp_root/check12-todo"
  mkdir -p "$tmp"
  write_backlog "$tmp/BACKLOG.md"

  # CC-003 is closed (✅ pr:#TBD) so its body is scanned
  local scope_rows="CC-003	✅ pr:#TBD"

  local out
  out="$(_pra_check_12_body_residuals "$tmp/BACKLOG.md" "" "$scope_rows")"

  if ! printf '%s\n' "$out" | grep -q "^❌ CC-003"; then
    fail "$name" "CC-003 has TODO in body, should fail: $out"
    return
  fi
  pass "$name"
}

case_check12_skips_non_closed() {
  local name="pre-release/check12-skips-non-closed"
  should_run "$name" || return 0

  local tmp="$tmp_root/check12-active"
  mkdir -p "$tmp"
  write_backlog "$tmp/BACKLOG.md"

  # CC-004 is active — body with TODO should NOT be flagged
  local scope_rows="CC-004	🔵 active"

  local out
  out="$(_pra_check_12_body_residuals "$tmp/BACKLOG.md" "" "$scope_rows")"

  if printf '%s\n' "$out" | grep -q "^❌ CC-004"; then
    fail "$name" "active ticket body should not be scanned for residuals: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -qE "^⏭  CC-004"; then
    fail "$name" "active ticket should be marked as skipped: $out"
    return
  fi
  pass "$name"
}

case_check12_skips_code_fence() {
  local name="pre-release/check12-skips-code-fence"
  should_run "$name" || return 0

  local tmp="$tmp_root/check12-fence"
  mkdir -p "$tmp"
  cat > "$tmp/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-005 | ✅ closed 2026-01-01 | fence test | ops | 2026-01-01 | pr:#1 | P2 | — |

## CC-005 — fence test ✅ 2026-01-01

**Goal**: Code comments inside fences must not be flagged.

```bash
# TODO: example code comment — should be ignored
echo "仍待辦"
```

**Result**: Clean.

EOF

  local scope_rows="CC-005	✅ pr:#1"

  local out
  out="$(_pra_check_12_body_residuals "$tmp/BACKLOG.md" "" "$scope_rows")"

  if ! printf '%s\n' "$out" | grep -q "^✅ CC-005"; then
    fail "$name" "TODO inside code fence should not trigger: $out"
    return
  fi
  pass "$name"
}

case_check13_coverage() {
  local name="pre-release/check13-changelog-coverage"
  should_run "$name" || return 0

  local tmp="$tmp_root/check13"
  mkdir -p "$tmp"
  write_changelog "$tmp/CHANGELOG.md"

  local scope_rows
  scope_rows="$(printf 'CC-001\t✅ pr:#10\nCC-002\t✅\nCC-003\t✅ pr:#99')"

  local out
  out="$(_pra_check_13_changelog "$tmp/CHANGELOG.md" "$scope_rows")"

  if ! printf '%s\n' "$out" | grep -q "^✅ CC-001"; then
    fail "$name" "CC-001 mentioned in changelog should pass: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q "^✅ CC-002"; then
    fail "$name" "CC-002 mentioned in changelog should pass: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -qE "^(❌|⚠️) CC-003"; then
    fail "$name" "CC-003 with PR#99 not in changelog should warn/fail: $out"
    return
  fi
  pass "$name"
}

case_check13_no_unreleased_section() {
  local name="pre-release/check13-no-unreleased-section"
  should_run "$name" || return 0

  local tmp="$tmp_root/check13-nounreleased"
  mkdir -p "$tmp"
  cat > "$tmp/CHANGELOG.md" <<'EOF'
# Changelog

## [0.9.0] — 2026-01-01

### Added

- Old stuff.
EOF

  local scope_rows
  scope_rows="$(printf 'CC-001\t✅ pr:#10\nCC-002\t✅')"

  local out
  out="$(_pra_check_13_changelog "$tmp/CHANGELOG.md" "$scope_rows")"

  if ! printf '%s\n' "$out" | grep -q "^❌ CC-001"; then
    fail "$name" "CC-001 should be ❌ when [Unreleased] missing: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q "^❌ CC-002"; then
    fail "$name" "CC-002 should be ❌ when [Unreleased] missing: $out"
    return
  fi
  pass "$name"
}

case_check14_status_consistent() {
  local name="pre-release/check14-status-consistent"
  should_run "$name" || return 0

  local tmp="$tmp_root/check14"
  mkdir -p "$tmp"
  write_backlog "$tmp/BACKLOG.md"

  local out
  out="$(_pra_check_14_status_consistency "$tmp/BACKLOG.md" "" "$(printf 'CC-001\nCC-004')")"

  if ! printf '%s\n' "$out" | grep -q "^✅ CC-001"; then
    fail "$name" "CC-001 index=✅ closed body=✅ should be consistent: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q "^✅ CC-004"; then
    fail "$name" "CC-004 index=🔵 active body=🔵 active should be consistent: $out"
    return
  fi
  pass "$name"
}

case_audit_missing_milestone() {
  local name="pre-release/audit-missing-milestone"
  should_run "$name" || return 0

  local tmp="$tmp_root/audit-missing"
  mkdir -p "$tmp"
  write_milestones "$tmp/MILESTONES.md"
  write_backlog "$tmp/BACKLOG.md"
  write_changelog "$tmp/CHANGELOG.md"

  local rc=0
  pmctl_pre_release_audit "$tmp" "v99.0" 2>/dev/null || rc=$?

  if [[ "$rc" -ne 2 ]]; then
    fail "$name" "missing milestone should exit 2, got $rc"
    return
  fi
  pass "$name"
}

case_audit_happy_path() {
  local name="pre-release/audit-happy-path"
  should_run "$name" || return 0

  local tmp="$tmp_root/audit-happy"
  mkdir -p "$tmp"

  # Minimal passing scenario: one ticket, closed with PR, body clean, in changelog
  cat > "$tmp/MILESTONES.md" <<'EOF'
# Milestones

## v2.0 — happy path test

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-020 | happy ticket | ✅ pr:#20 |
EOF

  cat > "$tmp/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-020 | ✅ closed 2026-01-20 | happy ticket | ops | 2026-01-20 | pr:#20 | P2 | — |

## CC-020 — happy ticket ✅ 2026-01-20

**Goal**: All done cleanly.

EOF

  cat > "$tmp/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

- CC-020: happy ticket done (pr:#20).
EOF

  local out rc=0
  out="$(pmctl_pre_release_audit "$tmp" "v2.0" 2>&1)" || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "happy path should exit 0, got $rc; output: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -qF 'Source'; then
    fail "$name" "output missing provenance block: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q 'Layer 1'; then
    fail "$name" "output missing Layer 1 header: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q 'Layer 3'; then
    fail "$name" "output missing Layer 3 blind spots: $out"
    return
  fi
  pass "$name"
}

# ---- run all ---------------------------------------------------------------

case_extract_scope_rows
case_check11_canonical_pr
case_check12_no_residuals
case_check12_detects_todo
case_check12_skips_non_closed
case_check12_skips_code_fence
case_check13_coverage
case_check13_no_unreleased_section
case_check14_status_consistent
case_audit_missing_milestone
case_audit_happy_path

th_summary
