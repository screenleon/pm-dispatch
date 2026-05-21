<!-- pm-schema: v1 -->
# repo-a backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| RA-001 | 🔵 active | 認證體驗調整 | frontend | 2026-04-01 | decisions:#auth |
| RA-002 | 🔵 active | 匯入資料整理 | backend | 2026-04-02 | roadmap:#imports |
| RA-003 | 🔵 active | 營運警示改善 | ops | 2026-04-03 | feedback:2026-04-04 |
| RA-004 | ✅ closed 2026-05-10 | 設定導覽完成 | product | 2026-05-10 | decisions:#settings |

---

## RA-001 — 認證體驗調整

**Problem**: Recovery screens are difficult to scan.
**Why**: Existing labels mix user state with action state.
**Requirement**: Recovery can be completed with clear state transitions.

## RA-002 — 匯入資料整理

**Problem**: Import review omits backend reconciliation context.
**Why**: The initial flow only considered happy-path records.
**Requirement**: Import review exposes the reconciliation state needed for fixes.

## RA-003 — 營運警示改善

**Problem**: Operations alerts do not show enough product context.
**Why**: The alert payload was designed for logs rather than triage.
**Requirement**: Alerts include the minimal context needed for first response.

## RA-004 — 設定導覽完成 ✅ 2026-05-10

**Outcome**: Settings navigation was simplified.
**See**: decisions:#settings
