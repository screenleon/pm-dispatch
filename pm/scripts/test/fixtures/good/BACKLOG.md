<!-- pm-schema: v1 -->
# fixture-good backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| GX-001 | 🔵 active | 登入流程調整 | frontend | 2026-04-01 | decisions:#login-flow, roadmap:#q2-auth |
| GX-002 | 🔵 active | 匯出資料改善 | backend/ops | 2026-04-02 | pr:#12, commit:abc1234, feedback:2026-04-03 |
| GX-003 | ✅ closed 2026-04-10 | 設定頁面整理 | product | 2026-04-10 | decisions:#settings-cleanup |
| GX-004 | 🚫 dropped 2026-04-11 | 舊版同步移除 | arch | 2026-04-11 | decisions:#drop-legacy-sync |

---

## GX-001 — 登入流程調整

**Problem**: Login recovery is hard to understand during account handoff.
**Why**: The old flow mixes verification and account selection in one screen.
**Requirement**: Users can complete recovery with clear state and no duplicated choice.
**Tags**: P1, M2
**Status note (2026-04-04)**: Waiting for final copy review.

## GX-002 — 匯出資料改善

**Problem**: Exported reports omit operational context needed for review.
**Why**: The current report shape was scoped to support tickets only.
**Requirement**: Exports include enough context for backend and ops audits.
**Tags**: P2, M10

## GX-003 — 設定頁面整理 ✅ 2026-04-10

**Outcome**: Settings navigation now groups related product controls together.
**See**: decisions:#settings-cleanup

## GX-004 — 舊版同步移除 🚫 2026-04-11

**Outcome**: Legacy sync work was dropped after the migration path changed.
**See**: decisions:#drop-legacy-sync
