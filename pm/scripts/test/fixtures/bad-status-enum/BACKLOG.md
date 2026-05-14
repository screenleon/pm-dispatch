<!-- pm-schema: v1 -->
# fixture-bad-status-enum backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| GX-001 | todo | 登入流程調整 | frontend | 2026-04-01 | decisions:#login-flow |
| GX-002 | ✅ done 2026-04-02 | 帶日期的 done | frontend | 2026-04-02 | — |
| GX-003 | ⏸ deferred 2026-04-03 | 帶日期的 deferred | frontend | 2026-04-03 | — |

---

## GX-001 — 登入流程調整

**Problem**: Login recovery is hard to understand during account handoff.
**Why**: The old flow mixes verification and account selection in one screen.
**Requirement**: Users can complete recovery with clear state and no duplicated choice.

## GX-002 — 帶日期的 done

**Problem**: done status should not accept a trailing date.
**Why**: Bare done is the soft-close form; dated done is not a defined variant.
**Requirement**: Validator rejects ✅ done YYYY-MM-DD as E-STATUS-ENUM.

## GX-003 — 帶日期的 deferred

**Problem**: deferred status should not accept a trailing date.
**Why**: Bare deferred is the only accepted form; dated deferred is not defined.
**Requirement**: Validator rejects ⏸ deferred YYYY-MM-DD as E-STATUS-ENUM.
