# Codex brief schema

The canonical structure for any brief dispatched to `codex-executor` (directly via Agent, or indirectly via `scripts/codex-dispatch.sh`).

`codex-executor` rejects briefs missing the four required fields. PMs and main-thread dispatchers should always write briefs against this schema; reach for the optional macros below when the task warrants them.

## Required fields

| Field | What | Example |
|---|---|---|
| `working_dir` | Absolute path. Must exist. | `/home/screenleon/github/japanese-site/` |
| `goal` | One sentence. What changes after this runs. | "Backfill 40 N4 / 40 N3 / 40 N2 kanji entries to fill the empty middle-tier overlay." |
| `files` | Concrete paths or a search hint. Both create-new and edit-existing must be enumerated. | `server/data/corpus/kanji/{N4,N3,N2}.jsonl` (new); read `N1.jsonl` and `N5.jsonl` for schema |
| `acceptance` | Testable post-conditions Codex itself can verify before declaring done. | Lint passes (`bash scripts/lint-agents.sh` exit 0); new file exists at the declared path; `git status --short` shows only allowlisted files. |

A brief missing any of these is a request for guesswork. Reject and ask the caller.

## Optional sections

Use as needed; not all briefs require all of them.

- **`constraints`** — what NOT to do. File paths off-limits, conventions to preserve, tests that must still pass after the change.
- **`self_verify`** — see macros below. Use whenever the work has external authority (sources, schema, level tag) Codex must not invent.
- **`output_format`** — when the deliverable is a report (audit, plan), specify the file path and required sections.
- **`sandbox`** / **`approval`** — only set when overriding the defaults (`workspace-write` / `never`). Caller must authorize.

## Self-verify macros

Reusable phrases. Drop into `self_verify` block of any brief.

### `cross-source` — N independent sources per item

> For each `<item type>`, cross-check against ≥`<N>` independent authoritative sources from `<allowed source list>`. Cite the source in the report column. Do not rely on internal knowledge alone.

Used for: JLPT level audits, fact-checked content batches.

### `sample-N OK re-check` — false-positive guard

> After producing the report, sample `<N>` random items you marked `OK` and re-verify them against the same source list. Note the re-check at the report footer (which items, sources re-checked, conclusion held).

Used when most items will be `OK`; protects against rubber-stamping.

### `git-status no-collateral-damage` — scope discipline

> When done, run `git status --short` and confirm only the brief's allowlisted files changed. If anything else is modified or created, flag it in the report — do not claim success.

Used for any brief with a strict allowlist (audit reports that must NOT touch source data, etc.).

### `dedup-across-N` — collision check across multiple files

> After writing, concatenate `<files>` and confirm <key> is unique across all of them (`sort -u | wc -l` matches input line count).

Used when the same key (e.g. kanji character) must not appear in multiple level files.

### `schema-match` — preserve existing JSONL/JSON shape

> Read `<reference file>` first to learn the schema. Every new entry must include exactly the same keys, same types, same canonical values for non-content fields (e.g. `source`, `license`).

Used when extending an existing data file family.

## Example brief (good)

```
working_dir: /home/screenleon/github/japanese-site/
goal: Audit PR #8 N1 corpus additions for JLPT level appropriateness — flag mis-classification.
files:
  - read: server/data/corpus/grammar/N1/{ga-hayai-ka,...}.{json,examples.jsonl}
  - read: server/data/corpus/vocab/N1.jsonl (60 net-new rows)
  - read: server/data/corpus/kanji/N1.jsonl (40 net-new rows)
  - write: audits/pr-8-jlpt-level-audit-2026-05-02.md
constraints:
  - READ-ONLY on all files under server/data/corpus/
  - Only write the audit report
self_verify:
  - cross-source: vocab+kanji ≥1 source from Jisho/Tanos; grammar ≥2 sources from Bunpro/JLPT-Sensei/Maggie/Tanos
  - sample-N OK re-check: 3 random OK items at the footer
  - git-status no-collateral-damage: only the audit file as new
acceptance:
  - report file exists at the specified path
  - every flagged entry has citations
  - footer contains the 3-item OK re-check
output_format: markdown with three grouped sections (## OK / ## needs review / ## re-classify); table columns per row
```

## Example brief (bad — would be rejected)

```
"Audit the N1 stuff and flag anything wrong."
```

No working_dir, no files, no acceptance criteria. Codex would have to guess what corpus, what sources, how to verify, where to write the report. Reject and ask.

## Style notes

- Prose is fine; YAML-like keys above are conventions, not strict syntax. Use a heredoc when piping the brief on stdin.
- Keep briefs in the active voice ("Audit X", not "X should be audited"). Codex parses imperatives more reliably than declaratives.
- Don't write implementation steps. The brief tells Codex *what* and *what counts as done*; *how* is Codex's job.
