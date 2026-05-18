<!-- pm-schema: v1 -->
# fixture-bad-changelog-drift-partial backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CP-001 | ⚠️ partial 2026-05-18 | 部分完成功能 | ux | 2026-05-18 | pr:#99 |

---

## CP-001 — 部分完成功能

**Problem**: Feature partially shipped; sub-items remain open.
**Why**: Partial status is non-closed (active); CHANGELOG drift should still fire.
**Requirement**: E-CHANGELOG-DRIFT is emitted when a partial-row PR appears in [Unreleased].
