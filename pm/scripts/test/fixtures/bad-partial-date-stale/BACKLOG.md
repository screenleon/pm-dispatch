<!-- pm-schema: v1 -->
# fixture-bad-partial-date-stale backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| BP-001 | ⚠️ partial 2026-05-18 | 部分完成驗證 | ux | 2026-05-18 | — |

---

## BP-001 — 部分完成驗證

**Problem**: A later delivery was written into the body while the index row kept
its earlier reconciliation date.
**Why**: A partial row whose body records newer work is a stale planning record.
**Requirement**: E-PARTIAL-DATE-STALE is emitted when a body date is newer than
the date on the partial row.

**Update 2026-06-02**: follow-up slice delivered; the index row still says 2026-05-18.
