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

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck disable=SC1091,SC1090
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
  # Behavior: _pra_extract_scope_rows returns only the tickets under the named milestone heading.
  # Steps: write MILESTONES.md with v1.0 and v0.9 sections; call with v1.0;
  #        assert 4 rows returned, CC-001 present, CC-099 (v0.9) absent.
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

case_extract_scope_rows_prefix_boundary() {
  local name="pre-release/extract-scope-rows-prefix-boundary"
  # Behavior: milestone_id v1.0 must not match ## v1.0.1 heading (exact boundary check).
  # Steps: write MILESTONES.md with only a v1.0.1 section; call with v1.0; assert 0 rows returned.
  should_run "$name" || return 0

  local tmp="$tmp_root/extract-boundary"
  mkdir -p "$tmp"
  cat > "$tmp/MILESTONES.md" <<'EOF'
# Milestones

## v1.0.1 — patch release

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-050 | patch ticket | ✅ pr:#50 |
EOF

  local rows
  rows="$(_pra_extract_scope_rows "$tmp/MILESTONES.md" "v1.0")"

  if [[ -n "$rows" ]]; then
    fail "$name" "v1.0 must not match v1.0.1 heading; got: $rows"
    return
  fi
  pass "$name"
}

case_check11_canonical_pr() {
  local name="pre-release/check11-canonical-pr"
  # Behavior: check 1.1 marks ✅ for canonical pr:#NNN, ❌ for missing ref, TBD ref, or non-✅ status.
  # Steps: pass scope_rows with four tickets covering each classification; assert leading marker.
  should_run "$name" || return 0

  local scope_rows
  scope_rows="$(printf 'CC-001\t✅ pr:#10\nCC-002\t✅\nCC-003\t✅ pr:#TBD\nCC-004\t🔵 active')"

  local out
  out="$(_pra_check_11_pr_refs "$scope_rows" "")"

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
  # Behavior: check 1.2 emits ✅ for closed tickets whose bodies contain no residual markers.
  # Steps: write BACKLOG.md with CC-001/CC-002 clean bodies; assert both output ✅.
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
  # Behavior: check 1.2 emits ❌ when a closed ticket body contains a literal TODO marker.
  # Steps: write BACKLOG.md with CC-003 body containing "TODO:"; assert ❌ output.
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
  # Behavior: check 1.2 skips body scan for tickets that are not closed (not ✅ in scope status).
  # Steps: pass CC-004 with 🔵 active status; assert output is ⏭ skipped, not ❌.
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
  # Behavior: check 1.2 does not flag TODO or 仍待辦 that appear inside a code fence.
  # Steps: write BACKLOG.md with CC-005 body containing TODO inside ```bash fence; assert ✅.
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
  # Behavior: check 1.3 marks ✅ for tickets mentioned in CHANGELOG [Unreleased], ❌/⚠️ for absent ones.
  # Steps: write CHANGELOG.md with CC-001/CC-002 in [Unreleased] but not CC-003; assert markers.
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

case_check13_ticket_id_boundary() {
  local name="pre-release/check13-ticket-id-boundary"
  # Behavior: CC-42 in scope must NOT be marked covered when only CC-420 appears in CHANGELOG.
  # Steps: write CHANGELOG.md [Unreleased] containing CC-420; pass CC-42 as scope ticket;
  #        assert output is ❌ or ⚠️ (not ✅).
  should_run "$name" || return 0

  local tmp="$tmp_root/check13-boundary"
  mkdir -p "$tmp"
  cat > "$tmp/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

- CC-420: some feature (pr:#420).

## [0.9.0] — 2026-01-01

- Old stuff.
EOF

  local scope_rows="CC-42	✅ pr:#42"

  local out
  out="$(_pra_check_13_changelog "$tmp/CHANGELOG.md" "$scope_rows")"

  if printf '%s\n' "$out" | grep -q "^✅ CC-42"; then
    fail "$name" "CC-42 must not be falsely matched by CC-420 in changelog: $out"
    return
  fi
  pass "$name"
}

case_check13_no_unreleased_section() {
  local name="pre-release/check13-no-unreleased-section"
  # Behavior: check 1.3 emits ❌ for all scope tickets when CHANGELOG has no [Unreleased] section.
  # Steps: write CHANGELOG.md with only a past release section; assert ❌ for every ticket.
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
  # Behavior: check 1.4 emits ✅ when BACKLOG index and body heading share the same leading emoji.
  # Steps: write BACKLOG.md with CC-001 (✅/✅) and CC-004 (🔵/🔵); assert both ✅ consistent.
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

case_check11_non_canonical_pr() {
  local name="pre-release/check11-non-canonical-pr"
  # Behavior: a scope ticket with ✅ and a bare #NNN ref (no pr: prefix) emits ⚠️.
  # Steps: pass scope_rows with status "✅ #9"; assert output starts with ⚠️ for that ticket.
  should_run "$name" || return 0

  local scope_rows="CC-009	✅ #9"

  local out
  out="$(_pra_check_11_pr_refs "$scope_rows" "")"

  if ! printf '%s\n' "$out" | grep -qE "^⚠️.*CC-009"; then
    fail "$name" "non-canonical '#9' format should emit ⚠️: $out"
    return
  fi
  pass "$name"
}

case_check11_file_line_ref() {
  local name="pre-release/check11-file-line-ref"
  # Behavior: non-OK findings for check 1.1 include MILESTONES.md:line in the output.
  # Steps: write MILESTONES.md with CC-002 (✅ no PR ref); extract real scope_rows; call
  #        _pra_check_11_pr_refs with the file path; assert ❌ row contains MILESTONES.md:N.
  should_run "$name" || return 0

  local tmp="$tmp_root/check11-file-line"
  mkdir -p "$tmp"
  write_milestones "$tmp/MILESTONES.md"

  local scope_rows
  scope_rows="$(_pra_extract_scope_rows "$tmp/MILESTONES.md" "v1.0")"

  local out
  out="$(_pra_check_11_pr_refs "$scope_rows" "$tmp/MILESTONES.md")"

  if ! printf '%s\n' "$out" | grep -qE "^❌ CC-002.*MILESTONES\.md:[0-9]+"; then
    fail "$name" "check 1.1 ❌ finding must include MILESTONES.md:line reference: $out"
    return
  fi
  pass "$name"
}

case_check13_file_line_ref() {
  local name="pre-release/check13-file-line-ref"
  # Behavior: ❌ findings for check 1.3 include CHANGELOG.md:line pointing to [Unreleased] section.
  # Steps: write CHANGELOG.md; pass scope_rows for CC-005 (✅ pr:#5, absent from changelog);
  #        assert ❌ row contains CHANGELOG.md:N.
  should_run "$name" || return 0

  local tmp="$tmp_root/check13-file-line"
  mkdir -p "$tmp"
  write_changelog "$tmp/CHANGELOG.md"

  local scope_rows="CC-005	✅ pr:#5"

  local out
  out="$(_pra_check_13_changelog "$tmp/CHANGELOG.md" "$scope_rows")"

  if ! printf '%s\n' "$out" | grep -qE "^❌ CC-005.*CHANGELOG\.md:[0-9]+"; then
    fail "$name" "check 1.3 ❌ finding must include CHANGELOG.md:line reference: $out"
    return
  fi
  pass "$name"
}

case_check14_file_line_ref() {
  local name="pre-release/check14-file-line-ref"
  # Behavior: ❌ mismatch findings for check 1.4 include BACKLOG.md:line for both index and body.
  # Steps: write BACKLOG.md with CC-008 index=✅ but body=🔵; assert ❌ includes two BACKLOG.md:N refs.
  should_run "$name" || return 0

  local tmp="$tmp_root/check14-file-line"
  mkdir -p "$tmp"
  cat > "$tmp/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-008 | ✅ closed 2026-01-08 | mismatch | ops | 2026-01-08 | pr:#8 | P2 | — |

## CC-008 — mismatch 🔵 active

**Goal**: body says active, index says closed.

EOF

  local out
  out="$(_pra_check_14_status_consistency "$tmp/BACKLOG.md" "" "CC-008")"

  if ! printf '%s\n' "$out" | grep -qE "^❌ CC-008.*BACKLOG\.md:[0-9]+.*BACKLOG\.md:[0-9]+"; then
    fail "$name" "check 1.4 ❌ finding must include two BACKLOG.md:line references: $out"
    return
  fi
  pass "$name"
}

case_check12_skips_japanese_quoted_mention() {
  local name="pre-release/check12-skips-japanese-quoted"
  # Behavior: markers appearing only inside Japanese brackets 「」 in a closed body are not flagged.
  # Steps: write BACKLOG.md with CC-006 body containing 「仍待辦」/「TODO」 as examples; assert ✅.
  should_run "$name" || return 0

  local tmp="$tmp_root/check12-jquote"
  mkdir -p "$tmp"
  cat > "$tmp/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-006 | ✅ closed 2026-01-06 | quoted test | ops | 2026-01-06 | pr:#6 | P2 | — |

## CC-006 — quoted test ✅ 2026-01-06

**Goal**: Requirement: closed body 無「仍待辦」/「待辦」/「TODO」殘留文字（僅需確認引號內不算）.

**See**: pr:#6

EOF

  local scope_rows="CC-006	✅ pr:#6"

  local out
  out="$(_pra_check_12_body_residuals "$tmp/BACKLOG.md" "" "$scope_rows")"

  if ! printf '%s\n' "$out" | grep -q "^✅ CC-006"; then
    fail "$name" "Japanese-quoted TODO/仍待辦 should not trigger: $out"
    return
  fi
  pass "$name"
}

case_check12_body_missing() {
  local name="pre-release/check12-body-missing"
  # Behavior: a closed ticket whose ## body section is absent in BACKLOG.md emits ⚠️.
  # Steps: write BACKLOG.md with index row but no body section; assert ⚠️ for that ticket.
  should_run "$name" || return 0

  local tmp="$tmp_root/check12-nomatch"
  mkdir -p "$tmp"
  cat > "$tmp/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-007 | ✅ closed 2026-01-07 | no body | ops | 2026-01-07 | pr:#7 | P2 | — |

EOF

  local scope_rows="CC-007	✅ pr:#7"

  local out
  out="$(_pra_check_12_body_residuals "$tmp/BACKLOG.md" "" "$scope_rows")"

  if ! printf '%s\n' "$out" | grep -qE "^⚠️.*CC-007"; then
    fail "$name" "missing body should emit warning: $out"
    return
  fi
  pass "$name"
}

case_check14_mismatch() {
  local name="pre-release/check14-status-mismatch"
  # Behavior: index row ✅ and body heading 🔵 produces ❌ mismatch finding.
  # Steps: write BACKLOG.md with CC-008 index=✅ but body heading=🔵; assert ❌.
  should_run "$name" || return 0

  local tmp="$tmp_root/check14-mismatch"
  mkdir -p "$tmp"
  cat > "$tmp/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-008 | ✅ closed 2026-01-08 | mismatch | ops | 2026-01-08 | pr:#8 | P2 | — |

## CC-008 — mismatch 🔵 active

**Goal**: body says active, index says closed.

EOF

  local out
  out="$(_pra_check_14_status_consistency "$tmp/BACKLOG.md" "" "CC-008")"

  if ! printf '%s\n' "$out" | grep -q "^❌ CC-008"; then
    fail "$name" "index ✅ vs body 🔵 should be flagged as mismatch: $out"
    return
  fi
  pass "$name"
}

case_audit_unknown_flag() {
  local name="pre-release/audit-unknown-flag"
  # Behavior: passing an unrecognised flag to pmctl_pre_release_audit exits 2.
  # Steps: call audit with --unknown-flag; assert exit code is 2.
  should_run "$name" || return 0

  local tmp="$tmp_root/audit-unknown-flag"
  mkdir -p "$tmp"
  write_milestones "$tmp/MILESTONES.md"
  write_backlog "$tmp/BACKLOG.md"
  write_changelog "$tmp/CHANGELOG.md"

  local rc=0
  pmctl_pre_release_audit "$tmp" "v1.0" --unknown-flag 2>/dev/null || rc=$?

  if [[ "$rc" -ne 2 ]]; then
    fail "$name" "unknown flag should exit 2, got $rc"
    return
  fi
  pass "$name"
}

case_audit_empty_args() {
  local name="pre-release/audit-empty-args"
  # Behavior: pmctl_pre_release_audit exits 2 with usage text when repo_root is empty.
  # Steps: call audit with "" as repo_root; assert exit 2.
  should_run "$name" || return 0

  local rc=0
  pmctl_pre_release_audit "" "v1.0" 2>/dev/null || rc=$?

  if [[ "$rc" -ne 2 ]]; then
    fail "$name" "empty repo_root should exit 2, got $rc"
    return
  fi
  pass "$name"
}

case_audit_missing_file() {
  local name="pre-release/audit-missing-file"
  # Behavior: audit with a repo root that has no MILESTONES.md/BACKLOG.md/CHANGELOG.md exits 2.
  # Steps: call audit against an empty tmp dir; assert exit code is 2.
  should_run "$name" || return 0

  local tmp="$tmp_root/audit-missing-file"
  mkdir -p "$tmp"
  # No files created — all required files missing

  local rc=0
  pmctl_pre_release_audit "$tmp" "v1.0" 2>/dev/null || rc=$?

  if [[ "$rc" -ne 2 ]]; then
    fail "$name" "missing files should exit 2, got $rc"
    return
  fi
  pass "$name"
}

case_audit_missing_milestone() {
  local name="pre-release/audit-missing-milestone"
  # Behavior: pmctl_pre_release_audit exits 2 when the requested milestone is not found in MILESTONES.md.
  # Steps: write valid fixture files; call audit with v99.0 (absent); assert exit 2.
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
  # Behavior: pmctl_pre_release_audit exits 0 and emits Layer 1 + Layer 3 headers for a clean milestone.
  # Steps: write minimal fixture with one clean closed ticket; assert exit 0, Source block, Layer 1, Layer 3.
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

case_check14_archive_only() {
  local name="pre-release/check14-archive-only"
  # Behavior: a ticket with no index row in BACKLOG.md but a heading in BACKLOG-ARCHIVE.md
  #           produces ✅ archived (not ⚠️ not-found).
  # Steps: write BACKLOG-ARCHIVE.md with CC-010 heading; omit it from BACKLOG.md; assert ✅ archived.
  should_run "$name" || return 0

  local tmp="$tmp_root/check14-archive"
  mkdir -p "$tmp"
  write_backlog "$tmp/BACKLOG.md"
  write_backlog_archive "$tmp/BACKLOG-ARCHIVE.md"

  local out
  out="$(_pra_check_14_status_consistency "$tmp/BACKLOG.md" "$tmp/BACKLOG-ARCHIVE.md" "CC-010")"

  if ! printf '%s\n' "$out" | grep -qE "^✅ CC-010.*archived"; then
    fail "$name" "archive-only ticket should be ✅ archived: $out"
    return
  fi
  pass "$name"
}

case_cli_route() {
  local name="pre-release/cli-route"
  # Behavior: cli/pmctl pre-release audit dispatches to pmctl_pre_release_audit and produces a report.
  # Steps: invoke cli/pmctl pre-release audit v0.7.0; assert exit ≠ 2 and output contains Layer 1 and Layer 3.
  should_run "$name" || return 0

  # Verify the CLI wiring by calling the actual binary against the real repo.
  # REPO_ROOT is resolved from the binary location, so we use a real milestone.
  local pmctl_bin="$REPO_ROOT/cli/pmctl"
  local out rc=0
  out="$("$pmctl_bin" pre-release audit "v0.7.0" 2>&1)" || rc=$?

  # Exit code 2 = dispatch/arg error; 0 or 1 = audit ran (found issues or not)
  if [[ "$rc" -eq 2 ]]; then
    fail "$name" "cli pmctl pre-release audit dispatch failed (exit 2): $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q 'Layer 1'; then
    fail "$name" "cli output missing Layer 1 header (exit $rc): $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q 'Layer 3'; then
    fail "$name" "cli output missing Layer 3 blind spots (exit $rc): $out"
    return
  fi
  # At least one finding must carry a file:line reference (covers the output contract)
  if ! printf '%s\n' "$out" | grep -qE '\.md:[0-9]+'; then
    fail "$name" "cli output must contain at least one file:line reference (exit $rc): $out"
    return
  fi
  pass "$name"
}

# ---- run all ---------------------------------------------------------------

case_extract_scope_rows
case_extract_scope_rows_prefix_boundary
case_check11_canonical_pr
case_check11_non_canonical_pr
case_check11_file_line_ref
case_check12_no_residuals
case_check12_detects_todo
case_check12_skips_non_closed
case_check12_skips_code_fence
case_check12_skips_japanese_quoted_mention
case_check12_body_missing
case_check13_coverage
case_check13_ticket_id_boundary
case_check13_no_unreleased_section
case_check13_file_line_ref
case_check14_status_consistent
case_check14_mismatch
case_check14_archive_only
case_check14_file_line_ref
case_audit_unknown_flag
case_audit_empty_args
case_audit_missing_file
case_audit_missing_milestone
case_audit_happy_path
case_cli_route

th_summary
