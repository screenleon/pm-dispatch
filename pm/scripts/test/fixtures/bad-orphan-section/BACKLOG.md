<!-- pm-schema: v1 -->
# fixture-bad-orphan-section backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| GX-001 | 🔵 active | 登入流程調整 | frontend | 2026-04-01 | — |

---

## GX-001 — 登入流程調整

**Problem**: Login recovery is hard to understand during account handoff.
**Why**: The old flow mixes verification and account selection in one screen.
**Requirement**: Users can complete recovery with clear state and no duplicated choice.

## GX-002 — 匯出資料改善

**Problem**: Export data improvement has no matching index row.
**Why**: This body section is an orphan — it exists without an index entry.
**Requirement**: Validator must flag this as E-INDEX-MISMATCH.
