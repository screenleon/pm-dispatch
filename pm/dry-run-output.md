# D2.5 Dry-Run Output (refreshed against schema v1 post-decisions)

## Item 1 — JS-009 (was: doing)

## JS-009 — 語料規模擴充

**Problem**: Learner corpus scale is uneven: vocabulary row count already clears the floor, but grammar coverage is still below the 100-point target and Japanese/Traditional Chinese learner support is still being filled through overlays.
**Why**: The existing seeded corpus was enough for the deterministic quiz loop, but not for the larger content-depth target; small 5-point grammar passes no longer match the needed level-balanced scale.
**Requirement**: Corpus data reaches at least 100 grammar points with level-balanced learner-usable coverage, Japanese-first and Traditional Chinese support fields, preserved source/license/validated_by metadata, and validation commands passing.
**Tags**: P?, M?  <!-- placeholder: original YAML priority/milestone values not retained in prior dry-run; fill from source YAML in real migration -->

**Status note (2026-04-30)**: Added curated JLPT overrides and documented remaining uncertain vocabulary level issues.
**Status note (2026-04-30)**: Added first N3 vocabulary support overlay plus 10 N3 grammar points and 50 cloze examples; grammar total reached 66 points / 324 cloze questions.
**Status note (2026-04-30)**: Last recorded validations: make lint-rules, make corpus-scale, make seed-corpus, go test ./..., npm run build.

## Item 2 — JS-013 (was: todo)

## JS-013 — 語料儲存格式重評

**Problem**: Corpus authoring is approaching a scale where JSON-per-grammar-point and repeated per-row metadata may become hard to review and maintain.
**Why**: The target scale is 1000+ JLPT-tagged learner-usable vocabulary rows and 100+ grammar points, while runtime storage remains SQLite and source content needs to stay human-reviewable.
**Requirement**: Decide whether the corpus source format still fits the target scale, including reviewability, metadata defaults, runtime compilation boundaries, git size constraints, and L2 cache shard growth.
**Tags**: P?, M?  <!-- placeholder, see JS-009 note -->

## Item 3 — JS-008 (done, closure stub)

## JS-008 — 日本語優先文法解釋 ✅ 2026-04-30

**Outcome**: Grammar explanations now follow a Japanese-first contract with Traditional Chinese revealed as learner support and legacy fallback preserved for unauthored rows.
**See**: decisions:#2026-04-30-japanese-first-explanations-with-chinese-reveal

## Index table preview (new schema)

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| JS-008 | ✅ closed 2026-04-30 | 日本語優先文法解釋 | product | 2026-04-30 | decisions:#2026-04-30-japanese-first-explanations-with-chinese-reveal |
| JS-009 | 🔵 active | 語料規模擴充 | content | 2026-04-30 | roadmap:#quiz--content-depth |
| JS-013 | 🔵 active | 語料儲存格式重評 | arch/content | 2026-04-30 | roadmap:#content-storage--scale |

Note: JS-008 / JS-009 `首次記錄` follow §2.4.2 fallback rule 1 / 2 respectively (closed → completed_at; active → earliest status note). JS-013 has no status notes; it falls to rule 3 — using migration date 2026-04-30 with backfill comment in body when applied to real BACKLOG. (Demo here keeps 2026-04-30 because that's when the dry-run conversion happened.)

## Findings (refreshed)

### 1. Schema gaps now covered

- `priority` / `milestone` → schema §2.5 `Tags` body line. Demo uses `P?, M?` placeholder because earlier dry-run didn't record raw values.
- Old `status: todo / doing / done` → schema §2.3 enum (`🔵 active` / `✅ closed`).
- `area`: schema §2.4.1 enum now includes `connector` plus alias `architecture → arch`. JS-013's `area: architecture` resolves cleanly to `arch`; the dry-run kept `arch/content` as a domain judgment (storage + corpus), still valid under the 2-segment slash composite rule.
- `source` (ROADMAP / DECISIONS anchors): schema §2.4.3 Refs syntax. ROADMAP anchors now first-class via `roadmap:` prefix.
- `首次記錄` blank: schema §2.4.2 fallback ladder.
- `notes`: condensed into `Status note` (active) or dropped at closure (closed).
- `completed_at`: feeds H2 status marker date and Refs fallback rule 1.
- `validation history`: still kept as one status note for active items; still discarded for closed stubs.

### 2. New-schema residual concerns

- **Tags real values not present**: prior dry-run discarded raw priority/milestone numbers. Real migration must re-read YAML to fill `Tags`. Marked `P?, M?` here so it's not mistaken for ground truth.
- **JS-013 first-record fallback**: under the strict ladder it should be migration-day-with-comment because no status notes exist. Demo elided that comment for table readability; real migration must add `<!-- 首次記錄: backfilled 2026-04-30 -->`.
- **Refs prefix coverage check** against actual prior dry-run sources: `decisions` ✓, `roadmap` ✓. PR / commit / feedback prefixes were not exercised by these 3 samples — first real test will come from JapanJob or mma-news repos. No "make-it-up" risk in this sample set.

### 3. "Make-it-up" risk under new schema

Reduced but not zero:

- `Tags`: any value invented at migration time would be a fabrication. Mitigation: write `P?, M?` (or omit row) until source YAML is consulted.
- `首次記錄` rule 3: schema requires the backfill comment, which makes invented dates auditable. Acceptable.
- Refs prefixes are closed-set, so invalid sources can no longer be silently encoded as free-form text — they would visibly fail the prefix list. Net safer than v0 free-form column.

### 4. Closure stub friction (unchanged)

JS-008 fits 3-line stub. Information lost: priority, milestone, validation commands, full implementation note list, fallback detail depth. Same as before — not a new-schema issue.

### 5. Stop/go signal

No new schema-level ambiguity introduced. The only outstanding non-schema item is "real Tags values need source YAML re-read at migration time," which is a migration-execution concern, not a schema-design concern.
