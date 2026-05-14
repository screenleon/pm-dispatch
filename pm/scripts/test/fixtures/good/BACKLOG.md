<!-- pm-schema: v1 -->
# fixture-good backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| GX-001 | 🔵 active | 登入流程調整 | frontend | 2026-04-01 | decisions:#login-flow, roadmap:#q2-auth |
| GX-002 | 🔵 active | 匯出資料改善 | backend/ops | 2026-04-02 | pr:#12, commit:abc1234, feedback:2026-04-03 |
| GX-003 | ✅ closed 2026-04-10 | 設定頁面整理 | product | 2026-04-10 | decisions:#settings-cleanup |
| GX-004 | 🚫 dropped 2026-04-11 | 舊版同步移除 | arch | 2026-04-11 | decisions:#drop-legacy-sync |
| GX-005 | ✅ done | 軟關閉功能 | ux | 2026-04-12 | — |
| GX-006 | ⏸ deferred | 延後功能 | process | 2026-04-13 | — |
| GX-007 | 🔵 active | 記憶體功能 | ux/memory | 2026-04-14 | — |
| GX-008 | 🔵 active | 測試流程 | ops/test | 2026-04-15 | — |
| GX-009 | 🔵 active | Token 追蹤 | ux/token | 2026-04-16 | — |
| GX-010 | 🔵 active | Gate 整合 | ops/gate | 2026-04-17 | — |

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

## GX-005 — 軟關閉功能

**Problem**: Feature was completed informally without a dated closure record.
**Why**: Done status is used for soft-close tracking without requiring a PR reference.
**Requirement**: Validator accepts bare done status.

## GX-006 — 延後功能

**Problem**: Feature is valid but blocked by external dependency.
**Why**: Not dropped — expected to resume after dependency resolves.
**Requirement**: Validator accepts deferred status without a date.

## GX-007 — 記憶體功能

**Problem**: Memory layer lacks cross-session recall.
**Why**: Context is lost after auto-compact.
**Requirement**: Episodic memory persists across sessions.

## GX-008 — 測試流程

**Problem**: Test suite lacks filter support.
**Why**: Full suite run is slow during targeted iteration.
**Requirement**: --filter flag runs matching cases only.

## GX-009 — Token 追蹤

**Problem**: Token usage is not visible during sessions.
**Why**: Users cannot judge when to compress context.
**Requirement**: Token usage indicator in status line.

## GX-010 — Gate 整合

**Problem**: Gate does not check coupling metrics.
**Why**: High coupling is caught late in review.
**Requirement**: Coupling check step added to gate flow.
