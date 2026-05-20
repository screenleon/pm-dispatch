<!-- pm-schema: v1.2 -->
# test-v12-bad-epic backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|
| XX-001 | 🔵 active | v1.2 invalid epic smoke | process | 2026-05-20 | — | P1 | invalid-epic |

## XX-001 — v1.2 invalid epic smoke

**Problem**: smoke test to confirm E-EPIC-ENUM fires for invalid epic in v1.2 files
**Why**: mutation guard — if schema_ver=="v1.2" branch is removed, v1.2 files skip epic validation and this test would pass when it should fail
**Requirement**: validate.sh must exit 1 with E-EPIC-ENUM for this file
