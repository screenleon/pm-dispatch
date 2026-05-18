<!-- pm-schema: v1 -->
# fixture-bad-partial-date backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| BP-001 | ⚠️ partial not-a-date | 部分完成驗證 | ux | 2026-05-18 | — |

---

## BP-001 — 部分完成驗證

**Problem**: Partial date must be a valid YYYY-MM-DD date.
**Why**: Validator must reject malformed partial date strings.
**Requirement**: E-DATE-FORMAT is emitted for `⚠️ partial not-a-date`.
