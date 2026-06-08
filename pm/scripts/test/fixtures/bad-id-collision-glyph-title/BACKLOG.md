<!-- pm-schema: v1 -->
# fixture-bad-id-collision-glyph-title backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| GX-009 | 🟢 someday | 標題本身含 ✅ 字元的 open 票 | frontend | 2026-05-01 | — |

---

## GX-009 — render ✅ badge and 🚫 state correctly 🟢 someday

**Problem**: This is an OPEN ticket whose title contains ✅ and 🚫 glyphs. It
must not be mistaken for a tombstone stub: the id is still open on the board,
and it reuses GX-009 — already closed in the archive — so it must collide.
**Why**: —
**Requirement**: —
