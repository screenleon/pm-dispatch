<!-- pm-schema: v1.2 -->
# fixture-good-area-schema-hook backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|
| GX-001 | 🔵 active | schema evolution work | schema | 2026-06-05 | — | P2 | — |
| GX-002 | 🔵 active | hook mechanism work | hook | 2026-06-05 | — | P2 | — |
| GX-003 | 🔵 active | compound schema and ops | ops/schema | 2026-06-05 | — | P3 | — |
| GX-004 | 🔵 active | compound arch and hook | arch/hook | 2026-06-05 | — | P3 | — |

---

## GX-001 — schema evolution work

**Problem**: Schema token was not in the area enum.
**Why**: Schema-level work (BACKLOG schema, state schema, brief schema) is distinct from arch.
**Requirement**: Validator accepts `schema` as a valid area token without error.

## GX-002 — hook mechanism work

**Problem**: Hook token was not in the area enum.
**Why**: Hook scripts, install paths, and policy are a first-class layer in pm-dispatch.
**Requirement**: Validator accepts `hook` as a valid area token without error.

## GX-003 — compound schema and ops

**Problem**: Compound area with schema was not valid.
**Why**: Topic tokens should compose with layer tokens.
**Requirement**: Validator accepts `ops/schema` compound area without error.

## GX-004 — compound arch and hook

**Problem**: Compound area with hook was not valid.
**Why**: Topic tokens should compose with layer tokens.
**Requirement**: Validator accepts `arch/hook` compound area without error.
