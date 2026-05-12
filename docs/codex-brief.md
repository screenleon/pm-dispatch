# Codex brief schema

The canonical structure for any brief dispatched to `codex-executor` (directly via Agent, or indirectly via `scripts/codex-dispatch.sh`).

`codex-executor` rejects briefs missing the required fields. PMs and main-thread dispatchers should always write briefs against this schema; pick the matching skeleton in §"Brief skeletons" and fill the slots — don't write from scratch.

## Required fields

| Field | What | Example |
|---|---|---|
| `working_dir` | Absolute path. Must exist. | `/home/screenleon/github/japanese-site/` |
| `goal` | One sentence. What changes after this runs. | "Backfill 40 N4 / 40 N3 / 40 N2 kanji entries to fill the empty middle-tier overlay." |
| `files` | Concrete paths or a search hint. Both create-new and edit-existing must be enumerated. | `server/data/corpus/kanji/{N4,N3,N2}.jsonl` (new); read `N1.jsonl` and `N5.jsonl` for schema |
| `acceptance` | Testable post-conditions Codex itself can verify before declaring done. | Lint passes (`bash scripts/lint-agents.sh` exit 0); new file exists at the declared path; `git status --short` shows only allowlisted files. |
| `self_verify` | **Required for any file-writing brief.** A brief is file-writing if its `files` block contains any entry tagged `write:` or `new:`, or any entry with no explicit `read:` tag. When in doubt, treat as file-writing. Read-only briefs (every `files:` entry explicitly tagged `read:`) may omit this field — do not inline checks into `acceptance` as a substitute for `self_verify` in file-writing briefs. | `git-status no-collateral-damage`; `schema-match` against the reference file. |

A brief missing any of these is a request for guesswork. Reject and ask the caller.

The pairing matters: `acceptance` is **what** must be true after the run; `self_verify` is **how** Codex proves it before declaring done. Don't conflate them — Codex evaluates `self_verify` itself, but `codex-executor` re-checks `acceptance` against `git diff` from outside.

## Optional sections

Use as needed; not all briefs require all of them.

- **`constraints`** — what NOT to do. File paths off-limits, conventions to preserve, tests that must still pass after the change.
- **`context`** — free-form background section used by composed workflows (e.g., `codex-pr-gate`) to pass reviewer context or codebase summary to the agent.
- **`task`** — free-form instruction block used by composed workflows to pass per-run task instructions distinct from the brief's `goal` field.
- **`output_format`** — when the deliverable is a report (audit, plan), specify the file path and required sections.
- **`sandbox`** / **`approval`** — only set when overriding the defaults (`workspace-write` / `never`). Caller must authorize.

## Brief skeletons

Pick the closest skeleton, fill the angle-bracketed slots, drop unused lines. Skeletons exist so brief-writing time stays roughly constant regardless of task type.

### `edit` — small, well-specified textual edits

Use when: ≤ ~10 file edits, you already know the exact OLD → NEW strings, no exploration needed.

```
working_dir: <abs path>
goal: <one sentence>
files:
  - edit: <path 1>
  - edit: <path 2>
constraints:
  - Do not modify any other files.
  - Preserve existing formatting / indentation in each file.
self_verify:
  - <grep / wc / file-exists check that the edits landed>
  - git-status no-collateral-damage
acceptance:
  - <textual delta description, file by file>
  - <self_verify all pass>
```

### `audit` — read-only review producing a report

Use when: Codex reads inputs, writes one report file, source data is off-limits.

```
working_dir: <abs path>
goal: Audit <subject> against <criteria>; produce report at <path>.
files:
  - read: <inputs>
  - write: <report path>
constraints:
  - READ-ONLY on all source files.
  - Only write the audit report.
self_verify:
  - cross-source: <macro-fill>
  - sample-N OK re-check
  - git-status no-collateral-damage
acceptance:
  - report file exists at the declared path
  - every flagged entry has citations
  - footer contains the N-item OK re-check
output_format: <markdown sections, table columns, etc.>
```

### `content-add` — new entries in an existing schema'd file family

Use when: extending JSONL/JSON corpora, new entries must match the existing schema exactly.

```
working_dir: <abs path>
goal: Add <N> <content type> entries to <target file family>.
files:
  - new: <new paths>
  - read: <reference paths to learn schema>
constraints:
  - Match reference file schema exactly (keys, types, canonical values).
  - Do not modify reference files or unrelated content.
self_verify:
  - schema-match against <reference>
  - dedup-across-N for <key> across <files>
  - <count check, e.g. wc -l == N for each file>
  - git-status no-collateral-damage
acceptance:
  - <count> entries per new file
  - schema check passes
  - no duplicates across files
```

### `refactor` — rename / restructure across multiple files

Use when: mechanical change preserving semantics (rename, move, signature update).

```
working_dir: <abs path>
goal: Rename <X> → <Y> across <module / scope>.
files:
  - search hint: grep -rn '<X>' <scope>
  - all matches updated; callers fixed
constraints:
  - Do not change semantics, only naming/structure.
  - Keep public API stable unless the goal explicitly says otherwise.
self_verify:
  - grep -rn '<X>' <scope> returns no matches
  - <existing test suite>: <command> exit 0
  - git-status no-collateral-damage
acceptance:
  - all references updated, no callers broken
  - test suite still green
```

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

## Dispatching a brief

Write the brief to `/tmp/brief-<task>.md` first, then pass it via `--brief-file`. This is the **canonical** way to dispatch.

When dispatching from an agent path such as `codex-executor`, the spawning main thread (or spawning agent's parent) must create the brief file before the Agent call. `codex-executor` has no Write tool, so it cannot create `/tmp/brief-<task>.md` for itself.

For a human shell only, a heredoc is an acceptable way to create the same file:

```bash
cat > /tmp/brief-<task>.md << 'EOF'
working_dir: ...
goal: ...
...
EOF

# Dispatch (single line — no backslash continuation)
~/github/claude-config/scripts/codex-dispatch.sh --cd <abs path> --sandbox workspace-write --approval never --brief-file /tmp/brief-<task>.md
```

**Why `--brief-file` and not inline `-- "<brief>"`?**
- The `hook-codex-bash-guard.sh` PreToolUse hook blocks any command that contains a newline or `\` continuation. Long briefs with code blocks, JSON, and shell paths almost always trigger this.
- `--brief-file` decouples brief content from the shell invocation — the hook only sees the single-line dispatch command.
- Inline `-- <brief>` is kept only for trivial smoke checks. Do not use it for real implementation briefs.

## Main-thread Agent call checklist

Before the main thread dispatches `codex-executor` via `Agent(subagent_type: "codex-executor", ...)`, verify all four:

| Check | Rule | Why |
|---|---|---|
| `isolation` absent | **Never set `isolation: "worktree"`** | Harness tries to create a worktree from the main thread's CWD, which may not be a git repo → instant "Cannot create agent worktree" error before codex-executor starts |
| `run_in_background: true` | **Required for parallel dispatches** | Without it the main thread blocks on each agent; user cannot send new commands while agents run |
| `self_verify` in brief | **Required for file-writing briefs** | codex-executor rejects immediately with 0 tool uses if absent; entire invocation is wasted |
| brief file pre-written | **Required before the Agent call** | codex-executor has no Write tool, so it cannot create `/tmp/brief-*.md` for itself |

Failing any check wastes the agent invocation before a single tool call is made. Check all four before sending.

## Style notes

- Prose is fine; YAML-like keys above are conventions, not strict syntax. Keep real dispatches file-backed via `--brief-file`.
- Keep briefs in the active voice ("Audit X", not "X should be audited"). Codex parses imperatives more reliably than declaratives.
- Don't write implementation steps. The brief tells Codex *what* and *what counts as done*; *how* is Codex's job.
