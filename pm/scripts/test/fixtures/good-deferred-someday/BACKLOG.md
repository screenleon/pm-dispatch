<!-- pm-schema: v1 -->
# fixture-good-deferred-someday backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| GX-001 | 🟡 deferred | 明確延後功能 | process | 2026-04-01 | — |
| GX-002 | 🟢 someday | 低優先功能 | ux | 2026-04-02 | — |
| GX-003 | ⏸ deferred | 標準延後功能 | process | 2026-04-03 | — |

---

## GX-001 — 明確延後功能

**Problem**: Feature is explicitly deferred.
**Why**: Uses alternate deferred visual token.
**Requirement**: Validator accepts 🟡 deferred status without error.

## GX-002 — 低優先功能

**Problem**: Feature is valid but very low priority.
**Why**: No schedule; may be picked up eventually.
**Requirement**: Validator accepts 🟢 someday status without error.

## GX-003 — 標準延後功能

**Problem**: Feature is blocked by external dependency.
**Why**: Not dropped — expected to resume later.
**Requirement**: Validator accepts ⏸ deferred status without error.
