# Dispatch brief schema

The canonical structure for any brief dispatched to an executor (codex, claude, opencode, or grok via `pmctl dispatch run --adapter <name>`).

Executors reject briefs missing the required fields. PMs and main-thread dispatchers should always write briefs against this schema; pick the matching skeleton in §"Brief skeletons" and fill the slots — don't write from scratch.
The executor-level abstraction is defined in [executor-contract.md](executor-contract.md); this file is the concrete brief schema (independent of executor profile).

## When to dispatch vs. handle inline

Dispatch overhead (brief write + executor startup + post-verify) costs ~30–120s and
~50–100K tokens in a subprocess. Only dispatch when that cost is justified:

| Dispatch (write a brief + run executor) | Handle inline on main thread (Edit tool) |
|---|---|
| ≥ 3 behavioral units (new functions / hooks / schema) | Targeted fix: 1–3 files, change already specified |
| ≥ 3 files to edit | diff < ~50 lines |
| Expected diff > 50 lines | No new behavioral units |
| Context protection: session already deep in a long exchange | Gate finding with explicit line references |
| Parallelizable reviewer pattern (pr-gate) | Change is obviously correct, post-verify adds no signal |

**Model routing for dispatched tasks** (use `model: light` for small dispatches — see §Model aliases):

| Task size | model | Pre-impl? | PM brief? |
|---|---|---|---|
| Tiny (< 30 lines, 1–2 files, no new behavior) | — | No | No — inline Edit |
| Small (< 50 lines, ≤ 2 adjacent files, no new interfaces/abstractions/hooks) | `light` | No | Optional — write brief inline |
| Medium (50–300 lines, 3–5 files, 3+ behavioral units) | `default` | Recommended | /pm or inline |
| Large (> 300 lines, 5+ files, new modules/schemas) | `default` | Required | /pm |

**Rule of thumb**: if you can write the Edit calls in less time than it takes to write the `self_verify` block, do it inline.

## Selecting an executor

The handover metadata's `executor:` field selects which executor receives the brief. Valid values today: `codex`, `claude`, `opencode`, and `grok`. The default is set at install time via `./install.sh --profile minimal|full` (auto-detected from `command -v codex` when unset): `full` → `codex`, `minimal` → `claude`. PM may override per-brief by setting `executor:` explicitly in the `dispatch_handover_v1` block. Use `isolation_level:` in the handover metadata (canonical values: `none | read-only | workspace-write | workspace-network | sandboxed`); the adapter layer translates this to executor-native flags — note that `opencode` only supports `none` (all others are rejected at dispatch time; workspace boundaries for opencode are configured via host opencode.json), while `grok` maps levels to dual `--sandbox` + `--permission-mode` flags (see `adapters/grok/isolation-map.yaml`). `isolation_level:` is required. The legacy fields `sandbox`, `approval`, and `skip_git_check` were removed in v0.6.0; a brief that still carries any of them is rejected with a migration error.

## Required fields

| Field | What | Example |
|---|---|---|
| `schema_version` | Always `1`. Identifies the brief format version. | `1` |
| `working_dir` | Absolute path. Must exist. | `/home/example/github/my-app/` |
| `goal` | One sentence. What changes after this runs. | "Backfill 40 N4 / 40 N3 / 40 N2 kanji entries to fill the empty middle-tier overlay." |
| `files` | Concrete paths or a search hint. Both create-new and edit-existing must be enumerated. | `server/data/corpus/kanji/{N4,N3,N2}.jsonl` (new); read `N1.jsonl` and `N5.jsonl` for schema |
| `acceptance` | Testable post-conditions Codex itself can verify before declaring done. | Lint passes (`bash tools/lint/lint-agents.sh` exit 0); new file exists at the declared path; `git status --short` shows only allowlisted files. |
| `self_verify` | **Required for any file-writing brief.** A brief is file-writing if its `files` block contains any entry tagged `write:` or `new:`, or any entry with no explicit `read:` tag. When in doubt, treat as file-writing. Read-only briefs (every `files:` entry explicitly tagged `read:`) may omit this field — do not inline checks into `acceptance` as a substitute for `self_verify` in file-writing briefs. Machine-verifiable items use `- cmd: "<bash>"` (post-verify executes them); macros/prose are executor-evaluated (post-verify skips them). | `- cmd: "bash scripts/test.sh"`; `git-status no-collateral-damage` (executor-evaluated). |

A brief missing any of these is a request for guesswork. Reject and ask the caller.

File-writing briefs must also carry retrieval evidence. A brief is
file-writing under the same rule used for `self_verify`: any `files:` entry not
tagged `read:` makes it non-trivial. Retrieval evidence is satisfied by any one
of:

- a non-empty `context:` block with copied refs or prior-art anchors,
- the `auto_context:` block that `pmctl dispatch run --auto-pack` (or
  `dispatch.auto_pack = on`) appends to the augmented brief — dispatch-time
  prior-art packing supplies evidence by appending this block, not via any brief
  field,
- `retrieval_skip_reason:` with a non-empty reason.

Read-only briefs are exempt. `brief-validate.sh` defaults to **rejecting** a
file-writing brief with no retrieval evidence (`BRIEF_VALIDATE_RETRIEVAL=fail` is
the default); set `BRIEF_VALIDATE_RETRIEVAL=warn` to downgrade to a non-blocking
warning. The only supported values are `warn` and `fail`. With
`dispatch.auto_pack` on by default, a dispatch normally supplies this evidence
automatically (the appended `auto_context:` block) whenever reuse-scan finds
hits; briefs with no reuse hits still need a `context:` block or a
`retrieval_skip_reason:`.

The pairing matters: `acceptance` is **what** must be true after the run; `self_verify` is **how** Codex proves it before declaring done. Don't conflate them — Codex evaluates `self_verify` itself, but the main-thread dispatch route (and `dispatch-post-verify.sh`) re-checks `acceptance` against `git diff` from outside.

### `files:` block semantics — sandbox allowlist, NOT must-read list

A `read:`-tagged entry means **"executor MAY read this if it needs the content"**, not **"executor MUST read this upfront"**. The block doubles as the sandbox/audit declaration of which files the brief is authorised to touch — not as a checklist of mandatory ingestion.

For survey-style briefs (spikes, audits, broad reviews), pre-loading every cited source file exhausts the executor's context window before useful work begins. Codex's default model has ~120K token context; pre-reading large project files (`BACKLOG.md`, `docs/architecture/*-synthesis.md`, `agents/*.md`) consumes most of it before useful work begins.

When authoring a brief whose `files:` block lists more than ~4 reads totaling > 50KB:

- Add a `context:` or `constraints:` instruction telling the executor to **read on demand only**: open only the cited line ranges via `grep -n` / `sed -n` / targeted `head`, not full files.
- If the brief depends on a self-contained scope/RFC doc, mark that one file as the single up-front read and treat all other `read:` entries as on-demand lookups.
- BACKLOG.md, large synthesis docs, and `agents/*.md` should always be opened via section-targeted commands (`grep -A 30 '^## CC-NNN' BACKLOG.md`), never read whole.

This applies to both `codex` and `claude` executors — Claude has more context budget, but lazy reading is still better hygiene.

## Optional sections

Use as needed; not all briefs require all of them.

- **`architecture_impact`** — `none | minor | major`. Declares the architectural weight of this change. When `architecture_impact: major`, `conceptual_map` is **required** — `brief-validate.sh` will FAIL without it. When `architecture_impact: minor`, `conceptual_map` is recommended — `brief-validate.sh` will WARN if absent. When supplied to `pr-gate`, this trusted metadata participates in canonical policy resolution: `minor` establishes at least a `standard` tier, `major` establishes `full`, and `none` adds no floor beyond the diff's own signals.

  | Value | Definition | Examples |
  |---|---|---|
  | `none` | No runtime behavior change, no command contract change, no module boundary touched | docs-only, typo fix, comment, pure test addition |
  | `minor` | Single bounded context changed; external contract stable or locally narrowed | single command behavior tweak, agent prompt update, new validation rule, new optional field |
  | `major` | Workflow, schema, cross-module contract, dispatch behavior, or security/risk path changed | brief schema change, pr-gate tier policy, PM routing logic, handover schema, new module |

  **When in doubt**: schema changes (even optional fields) are typically `minor` at minimum and often `major` if downstream validators, reviewers, or PM routing consume the field.
- **`conceptual_map`** — plain-text description of the proposed structure: data flow, module interactions, layer ownership. No source code. 5–15 lines. **Required when `architecture_impact: major`**; recommended for `minor`. This is the primary input for `architecture-reviewer` — the reviewer reads the map first and inspects source files only when the map and diff disagree. Produce this from `/pre-impl`'s `## Conceptual Map` output section. Example:
  ```yaml
  conceptual_map: |
    caller → pmctl dispatch run → brief-validate → guard → route → executor
    executor writes to working_dir; post-verify reads git diff from outside
    architecture-reviewer: reads conceptual_map first; source diff only if map/diff diverge
    layer boundary: cli/ → scripts/ → core/ (no reverse dependency)
  ```
- **`constraints`** — what NOT to do. File paths off-limits, conventions to preserve, tests that must still pass after the change. **When the brief introduces ≥ 3 behavioral units or has `architecture_impact ≠ none`**, run `/pre-impl "<feature description>"` first and paste the output's design constraint list here — this prevents architecture-reviewer blocks from boundary/dependency issues caught too late.
- **`context`** — free-form background section used by composed workflows (e.g., `pr-gate`) to pass reviewer context or codebase summary to the agent.
- **`retrieval_skip_reason`** — non-empty reason why retrieval was intentionally skipped for a file-writing brief. Use this only when query/reuse-scan evidence would add no signal, such as a mechanical edit with all context already supplied in the brief.
- **`task`** — free-form instruction block used by composed workflows to pass per-run task instructions distinct from the brief's `goal` field.
- **`output_format`** — when the deliverable is a report (audit, plan), specify the file path and required sections.
- **`isolation_level`** — required: `workspace-write` (default), `read-only`, `workspace-network`, `sandboxed`, or `none`. `none` means full machine access and is **opencode-only** (it has no finer-grained sandbox); codex, claude, and grok reject `none` (their max isolation is `workspace-write`). The adapter layer translates to executor-native flags. **Grok narrowing:** for `executor: grok`, `workspace-write` maps to Grok's OS `workspace` sandbox (writes CWD + `~/.grok` session/config store + temp) — not pure CWD-only; see `adapters/grok/isolation-map.yaml` and `docs/executor-contract.md`. Source of truth for abstract levels: `core/policy/isolation-level.yaml`. The legacy `sandbox` / `approval` / `skip_git_check` fields were removed in v0.6.0; a brief carrying any of them is rejected.
- **`qa_checklist`** — **Conditionally required**: include when the brief introduces ≥ 3 distinct behavioral units (new code paths, new flags, new hooks, new error-handling branches). For each unit, list its expected test name or scenario. `qa-tester` will block in gate round 1 for any introduced unit without adjacent coverage — writing this upfront costs one minute and prevents multiple gate/fix cycles. Example:
  ```
  qa_checklist:
    - happy path: dispatch exits 0, trace file exists
    - failed dispatch: exit preserved, stderr records message
    - spark pool: --model *spark* → pool=spark in log entry
    - log failure: log-usage.sh unavailable → dispatch still exits 0
  ```
- **`test_target`** — **Required for language-aware tool spikes** (codegraph, AST-grep, semgrep, tree-sitter, etc.); optional otherwise. Commits to the representative target codebase the spike will exercise, distinct from `working_dir`. Without this field, the executor may choose any convenient repo, making the verdict non-reproducible. Example: `test_target: /home/user/github/my-go-project`. When the target's language and approximate LOC matter for generalizability, add a comment. See `docs/spikes/README.md` for the full `test_target:` contract.
- **`expected_head_sha`** — **Recommended for any brief that touches > 4 files OR depends on a specific base commit**. 40-char git HEAD sha the brief was authored against. Codex should verify `git rev-parse HEAD == <sha>` at dispatch start; mismatch → HALT and report (catches "wrong branch / branch advanced / file changed under me" failures before any patch is attempted). Example:
  ```
  expected_head_sha: e2711dd802a3...
  ```
  And in `self_verify`:
  ```
  - expected-head: bash -c "[[ \$(git rev-parse HEAD) == e2711dd802a3... ]]"
  ```

## Prior-art scan

Before filling in `files:` and `context:`, run a repo-plane prior-art scan so
the executor reuses existing code rather than reimplementing it:

    pmctl context reuse-scan [<repo_root>] "<task description>"

This manual route is the curated default. Review the `reuse_candidates:` output
and paste **at most 5 entries** into the brief's `context:` block. Do not paste
the raw block unfiltered — stop-word noise in the candidates inflates executor
token cost without adding signal.

Auto-pack at dispatch time is **on by default** (`dispatch.auto_pack` built-in
default is `on`); pass `--no-auto-pack` to opt out, or `--auto-pack` to force it
on where a config disabled it:

    pmctl dispatch run --adapter <executor> --cd <repo_root> --brief-file <brief>

Auto-pack works under **both** lifecycles, and in both the augmented brief is
landed at the guardable `/tmp/brief-<run_id>.md` path so a single brief is
guarded == validated == executed == recorded. Under the default `detached`
lifecycle that snapshot is recorded as the run-spec's trusted `brief_file` and the
supervisor validates, guards, and executes it. Under `--lifecycle foreground`
dispatch snapshots the pack to the same `/tmp` path before guarding and forwarding
it to the executor.

When enabled, `pmctl dispatch run` extracts the brief `goal`, runs
`pmctl context reuse-scan`, and writes a temporary augmented copy under the
work repo with an `auto_context:` block containing up to 5 pointer-only hits.
The authored brief file is not modified. If reuse-scan, pack writing, or
validation fails, dispatch prints a warning to stderr and continues with the
original brief.

For tasks with known symbol names, use `pmctl context pack` with explicit
`--query` flags instead.

See `docs/context-retrieval.md` for full usage and observable usage events.

## Brief skeletons

Pick the closest skeleton, fill the angle-bracketed slots, drop unused lines. Skeletons exist so brief-writing time stays roughly constant regardless of task type.

### `edit` — small, well-specified textual edits

Use when: ≤ ~10 file edits, you already know the exact OLD → NEW strings, no exploration needed.

```
schema_version: 1
working_dir: <abs path>
goal: <one sentence>
context:
  - <≤5 prior-art refs from `pmctl context reuse-scan`; or drop this and use retrieval_skip_reason:>
files:
  - edit: <path 1>
  - edit: <path 2>
constraints:
  - Do not modify any other files.
  - Preserve existing formatting / indentation in each file.
# qa_checklist: add if introducing ≥ 3 behavioral units (see Optional sections)
self_verify:
  - cmd: "<grep / wc / file-exists check that the edits landed>"
  - git-status no-collateral-damage
acceptance:
  - <textual delta description, file by file>
  - <self_verify all pass>
```

### `audit` — read-only review producing a report

Use when: Codex reads inputs, writes one report file, source data is off-limits.

```
schema_version: 1
working_dir: <abs path>
goal: Audit <subject> against <criteria>; produce report at <path>.
context:
  - <≤5 prior-art refs from `pmctl context reuse-scan`; or drop this and use retrieval_skip_reason:>
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
schema_version: 1
working_dir: <abs path>
goal: Add <N> <content type> entries to <target file family>.
context:
  - <≤5 prior-art refs from `pmctl context reuse-scan`; or drop this and use retrieval_skip_reason:>
files:
  - new: <new paths>
  - read: <reference paths to learn schema>
constraints:
  - Match reference file schema exactly (keys, types, canonical values).
  - Do not modify reference files or unrelated content.
self_verify:
  - schema-match against <reference>
  - dedup-across-N for <key> across <files>
  - cmd: "<count check, e.g. test \"$(wc -l < <file>)\" -eq N>"
  - git-status no-collateral-damage
acceptance:
  - <count> entries per new file
  - schema check passes
  - no duplicates across files
```

### `refactor` — rename / restructure across multiple files

Use when: mechanical change preserving semantics (rename, move, signature update).

```
schema_version: 1
working_dir: <abs path>
goal: Rename <X> → <Y> across <module / scope>.
context:
  - <≤5 prior-art refs from `pmctl context reuse-scan`; or drop this and use retrieval_skip_reason:>
files:
  - read: <scope>           # discover all occurrences (grep -rn '<X>' <scope>)
  - edit: <file-to-change>  # repeat for each file requiring updates
constraints:
  - Do not change semantics, only naming/structure.
  - Keep public API stable unless the goal explicitly says otherwise.
self_verify:
  - cmd: "! grep -rn '<X>' <scope>"          # passes when no matches remain
  - cmd: "<existing test suite command, e.g. bash scripts/test.sh>"
  - git-status no-collateral-damage
acceptance:
  - all references updated, no callers broken
  - test suite still green
```

## Dispatch protocol

The recommended 3-phase shell dispatch pipeline. Each phase is a single Bash call from the main thread — no subagent spawned.

### Phase 1 — Pre-dispatch validation (shell, <1s)

```bash
bash runtime/bin/brief-validate.sh <brief-file>
```

Validates required fields (`schema_version`, `working_dir`, `goal`, `files`, `acceptance`) and enforces `self_verify` for file-writing briefs. Exits 0 = VALID; exits 1 = REJECT with reason. Run before dispatching to catch schema errors without wasting a full codex execution.

**Quick check via pmctl:** `pmctl dispatch run` runs this validation automatically, but you can also run the handover-block check standalone:

```bash
pmctl validate brief <brief-file>
```

It extracts the `dispatch_handover_v1` block, validates the full metadata header (`handover_validate_all_metadata`), and confirms body consistency — the body's `working_dir` must match the metadata header (`handover_validate_working_dir_match`) — mirroring the dispatcher's enforcement so a brief that would be rejected at dispatch is rejected here too.

Exit codes: `0` = valid handover block (metadata and body consistent); `1` = invalid block, metadata, or body/metadata `working_dir` mismatch; `2` = usage error or file not found. This is read-only — no state is written. Use it to verify a hand-authored brief before committing to a full dispatch.

### Phase 2 — Dispatch (executor-specific)

```bash
# codex profile:
pmctl dispatch run --adapter codex --cd <work_dir> --brief-file <brief-file>

# claude profile:
pmctl dispatch run --adapter claude --cd <work_dir> --brief-file <brief-file>

# opencode profile:
pmctl dispatch run --adapter opencode --cd <work_dir> --brief-file <brief-file>
# grok profile:
pmctl dispatch run --adapter grok --cd <work_dir> --brief-file <brief-file>
```

Bare `pmctl dispatch run` defaults to `--lifecycle detached` for eligible adapters: it returns a `run_id` immediately, then use `pmctl dispatch wait <run_id> --cd <work_dir>` (run that in background) to reattach and resolve the terminal outcome. Pass `--lifecycle foreground` explicitly to block in-process and get the adapter's stdout footer directly instead — see §Dispatch lifecycle below for the full contract.

### Phase 3 — Post-dispatch verification (executor-agnostic shell, <5s)

```bash
bash runtime/bin/dispatch-post-verify.sh <work_dir> <brief-file>
```

Reads `.agent-trace/latest.{last,stderr}`, shows `git diff --stat`, and processes each `self_verify` item by kind:

- A **machine-executable check** in the structured `- cmd: "<bash>"` form is **executed** in `<work_dir>` — `PASS` iff the command exits 0, `FAIL` on non-zero or timeout (`DISPATCH_SELF_VERIFY_TIMEOUT`, default 300s). This does not depend on the executor's prose: the command is run, not searched for in the executor's final message.
- Any **other shape** (a named macro like `git-status no-collateral-damage`, free prose, or a bare scalar) is a **semantic check the executor evaluates**, not a shell — post-verify marks it `SKIP (executor-evaluated)` and does not fail on it. Confirm these by reading the executor's report.

Works for any executor (codex, claude, opencode, or grok). Exits 0 = ok (no executed check failed); exits 1 = partial/failed. **Write any check you want machine-verified as `- cmd: "..."`.**

> **Note**: The `/pm` command implements the same verification inline via its manual completion-handling steps (steps 2–8 in the main-thread protocol); `dispatch-post-verify.sh` provides the same checks as a standalone shell tool for automation, re-checks, and CI use.

### Go repo self_verify

The Codex sandbox cannot write to `~/.cache/go/build` (GOCACHE) because `/home`
is read-only. Set `GOCACHE=/tmp/go-cache` in every `self_verify` command that
invokes `go build` or `go test` — this redirects compiled artifacts to `/tmp`
without severing module access.

```yaml
self_verify:
  - cmd: "GOCACHE=/tmp/go-cache go build ./..."
    expect: "exits 0"
  - cmd: "GOCACHE=/tmp/go-cache go test ./..."
    expect: "exits 0"
```

See [sandbox-limitations.md](sandbox-limitations.md) for details on the full
capability boundary and additional patterns (Docker, external DBs).

## Self-verify macros

Reusable phrases. Drop into the `self_verify` block of any brief. These are
**semantic checks the executor evaluates** (judgment an LLM applies, not a shell
command) — `dispatch-post-verify.sh` marks them `SKIP (executor-evaluated)` and
relies on the executor's report. For anything you want machine-verified, use the
structured `- cmd: "<bash>"` form instead (e.g. express
`git-status no-collateral-damage` as a concrete `cmd:` when it is shell-checkable).

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
working_dir: /home/example/github/my-app/
goal: Audit PR #8 N1 corpus additions for JLPT level appropriateness — flag mis-classification.
retrieval_skip_reason: audit reads its own corpus inputs directly; no repo prior-art to retrieve
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

## Main-thread dispatch via dispatch_handover_v1

`project-pm` hands implementation briefs back to the main thread as one fenced block tagged `dispatch_handover_v1`. The main thread extracts the block, writes the brief body to `brief_file`, then dispatches via `pmctl dispatch run --adapter <executor>` in the background. This is the **only** dispatch path — no executor subagent exists or holds brief-write authority; the brief is always authored by trusted main-thread code.

```dispatch_handover_v1
handover_version: 4
executor: codex
dispatch_route: main_thread_bash_background
working_dir: ${PM_DISPATCH_REPO}
brief_file: /tmp/brief-<repo>-<slug>-<utc-ts>-<rand>.md
isolation_level: workspace-write
timeout: 1200
model: default
fallback_allowed: true
---
working_dir: ${PM_DISPATCH_REPO}
goal: ...
files:
  - read: ...
  - edit: ...
constraints:
  - ...
self_verify:
  - ...
acceptance:
  - ...
```

Extraction rules:

1. Read the fenced block tagged exactly `dispatch_handover_v1`.
2. Treat the metadata header as dispatch-control data only.
3. Treat everything after the first standalone `---` line as the brief body to write to `brief_file`.
4. Validate `working_dir` in metadata matches `working_dir` in the brief body.
5. Reject, or re-prompt the PM once, if metadata is absent or contradictory.
6. Ignore any human prose summary outside the fence when constructing the dispatch.

Metadata fields:

| Field | Required | Notes |
|---|---|---|
| `handover_version` | yes | Currently `4`; bump on shape change. |
| `executor` | yes | Closed enum: `codex`, `claude`, `opencode`, `grok`. Main-thread dispatch uses this field to choose the executor-specific adapter. |
| `dispatch_route` | yes | `main_thread_bash_background` — the routine route for every shipped (cli-subprocess) adapter. `agent_executor` remains a valid value reserved for a future host-native adapter, but no shipped executor uses it. |
| `working_dir` | yes | Absolute path; must exist; must match the brief body. |
| `brief_file` | yes | Absolute path under `/tmp/brief-...`; main thread creates this file with unique `mktemp`-style exclusive semantics, then writes the brief body. |
| `isolation_level` | yes | Canonical isolation intent: `none \| read-only \| workspace-write \| workspace-network \| sandboxed`. Adapter layer expands to executor-native flags. The legacy `sandbox`/`approval`/`skip_git_check` fields were removed in v0.6.0; a brief carrying any of them is rejected. |
| `timeout` | yes | Seconds; `1200` default. Passed through to the executor adapter. For `opencode`, must be 0 (no limit) or ≥ 120 (per-attempt floor). |
| `model` | yes | `default` or an executor-specific model wire-id. For `opencode`, aliases like `light`/`default` are resolved by the adapter. |
| `fallback_allowed` | yes | Legacy flag retained for schema compatibility. The Agent-spawn executor fallback was retired, so all dispatch uses the main-thread Bash route regardless of this value. |
| `snapshot_file` | no | Absolute path to a PM-generated context snapshot; if present, PM uses it for orientation. PM re-derives security-sensitive fields (current branch, HEAD SHA) from git — see `agents/project-pm.md` `## Snapshot ingestion`. |

### Env / config precedence

Timeout resolution for the codex adapter follows this chain (highest priority first):

- brief `timeout` value
- `CODEX_DISPATCH_TIMEOUT` environment variable (public)
- `dispatch.default_timeout` in `~/.pm-dispatch/config`
- hardcoded fallback `1200` in `adapters/codex/dispatch.sh`

Example `~/.pm-dispatch/config`:

```text
dispatch.default_timeout=900
```

Invalid lines (for example `dispatch.default_timeout=oops`) are logged as warnings and ignored. Unknown keys are ignored for forward compatibility.

### Dispatch lifecycle

`pmctl dispatch run` supports a `--lifecycle foreground|detached` flag, with a `dispatch.lifecycle = foreground|detached` config default the flag overrides. **The built-in default is `detached` for eligible adapters** (`cli-subprocess` runner kind, e.g. codex): bare `pmctl dispatch run` returns a `run_id` immediately without waiting for the adapter to complete. Callers that need the old synchronous, blocking behavior must pass `--lifecycle foreground` or set `dispatch.lifecycle = foreground` in their project config. This axis is **orthogonal** to an adapter's `runner_kind` (which says *how* the executor is reached): lifecycle says *who owns the executor after launch*.

- `foreground` runs the post-preflight executor tail (adapter invocation → footer parse → post-verify → terminal state + durable record) in-process and blocks until the adapter exits — the historical behavior. No run-spec is written; the dispatch exit code is the adapter exit code.
- `detached` persists a run-spec under `<work_dir>/.agent-trace/<run_id>.runspec`, launches `runtime/bin/dispatch-supervisor.sh` via `setsid`/`nohup` (falling back to `nohup ... & disown`), writes the `run_id` to stdout, and exits 0 without waiting for the adapter. The supervisor re-runs the **full** security preflight — adapter name/containment, route allowlist, `brief-validate.sh`, and `pmctl guard check` — before invoking any executor, so it can never bypass the gates `pmctl dispatch run` enforces. The run-spec records the `--cd` and `--brief-file` values as trusted scalars and carries only the non-core adapter args as passthrough; the supervisor rebuilds the adapter command from those scalars, so the brief that is guarded and validated is exactly the one executed (it rejects any attempt to smuggle a second `--cd`/`--brief-file` through the passthrough args).

Use `pmctl dispatch wait <run_id> --cd <work_dir> [--timeout <secs>]` to reattach and resolve the terminal outcome. `--cd` is mandatory; timeout exits 124. The authoritative completion signal is the supervisor sentinel written to `/tmp` (never the in-workspace `.dispatch-results/<run_id>.md` record, which is executor-writable and used for observability only). The sentinel path includes a per-run nonce held in a per-user `mode 700` key dir and not stored in the workspace run-spec: this stops *other OS users* and cross-run/predictable-path collisions from resolving the wait, but a *same-user* executor (same uid) can read the key — so the executor is **trusted** not to forge it (the deployment runs the operator's own login-authenticated agent; see `docs/executor-contract.md` → Durable dispatch record for the full trust model — this is a deliberate, user-accepted trust boundary, not an oversight). If the sentinel key is absent, `dispatch wait` returns **indeterminate (exit 3)** and prints the durable record for observability only — never as authenticated success.

Only **detach-eligible** adapters accept `--lifecycle detached`: eligibility is derived from the adapter's `runner_kind` (`cli-subprocess` = eligible; `host-native` = not). An ineligible adapter or `--lifecycle detached --print-cmd` is rejected before any executor launch. `--lifecycle detached` **is** compatible with auto-pack: the augmented brief is snapshotted to the guardable `/tmp/brief-<run_id>.md` path and recorded as the run-spec's trusted `brief_file`, so the supervisor validates, guards, and executes exactly that augmented brief — preserving the single-brief invariant.

## Executor-agnostic model aliases

Use these aliases in briefs and PM routing — never hard-code executor wire-format IDs.
Each adapter resolves the alias to its own wire format at dispatch time.

| PM-facing alias | codex wire ID | claude wire ID | opencode wire ID | grok wire ID | When to use |
|---|---|---|---|---|---|
| `default` | `gpt-5.6-terra` | `claude-sonnet-5` | `opencode/nemotron-3-ultra-free` | `grok-4.5` | All medium/large tasks (omit `--model` or write `model: default`) |
| `light` | `gpt-5.3-codex-spark` | `claude-haiku-4-5-20251001` | `opencode/deepseek-v4-flash-free` | `grok-4.5` (low effort) | Small tasks only (see §When to dispatch) |

See `docs/model-tier-policy.md` §Executor-agnostic `light` alias for routing criteria.

## Model aliases

PM short-form model aliases are resolved from the source-of-truth file
`share/codex-model-aliases.tsv`, then passed as wire-format model IDs to `codex exec`.
`tools/lint/lint-model-aliases.sh` asserts that this table stays in sync with the PM-facing table below and any template hardcoded references.

| PM-facing alias | Wire-format model ID | reasoning effort |
|---|---|---|
| `default` | `gpt-5.6-terra` | `medium` |
| `gpt-5.6-terra` | `gpt-5.6-terra` | `medium` |
| `gpt-5.6-sol` | `gpt-5.6-sol` | `medium` |
| `gpt-5.6-luna` | `gpt-5.6-luna` | `medium` |
| `gpt-5.5` | `gpt-5.5` | `medium` |
| `gpt-5.4` | `gpt-5.4` | `medium` |
| `codex-spark` | `gpt-5.3-codex-spark` | `high` |
| `light` | `gpt-5.3-codex-spark` | `high` |

GPT 5.6 ships as three named tiers: `gpt-5.6-sol` (frontier), `gpt-5.6-terra` (balanced/everyday — the `default`), `gpt-5.6-luna` (fast/affordable). `light` is opt-in only and draws from an independent usage pool — see §Executor-agnostic model aliases above.

## Claude model aliases

PM short-form model aliases for the claude executor, resolved from `share/claude-model-aliases.tsv`.
`tools/lint/lint-model-aliases.sh` asserts that this table stays in sync with the source TSV.

| PM-facing alias | Wire-format model ID | reasoning effort |
|---|---|---|
| `default` | `claude-sonnet-5` | `normal` |
| `sonnet` | `claude-sonnet-5` | `normal` |
| `light` | `claude-haiku-4-5-20251001` | `normal` |
| `haiku` | `claude-haiku-4-5-20251001` | `normal` |
| `opus` | `claude-opus-4-8` | `high` |
| `sonnet-4-6` | `claude-sonnet-4-6` | `normal` |
| `sonnet-4-5` | `claude-sonnet-4-5-20250929` | `normal` |
| `opus-4-6` | `claude-opus-4-6` | `high` |
| `opus-4-7` | `claude-opus-4-7` | `high` |

`sonnet-4-6`/`sonnet-4-5`/`opus-4-6`/`opus-4-7` are prior-generation aliases kept selectable for rollback — none is the default.

Model resolution precedence: `--model` flag > `PM_CFG_DEFAULT_MODEL` (from `~/.pm-dispatch/config` `dispatch.default_model`) > pm-dispatch's own built-in `default` alias (→ `claude-sonnet-5` via `share/claude-model-aliases.tsv`), decoupled from the claude CLI's own built-in default. Every alias in these tables is a valid handover `model:` value (`runtime/lib/handover-validate.sh`).

## Reasoning effort

`--effort <low|medium|high>` is independent of `--model`: use it to dial reasoning depth up or down without switching models (e.g. keep the same model but drop to `low` for a quick pass, or raise to `high` for a hard diagnosis). Resolution precedence: `--effort` flag > the resolved model alias's own effort column (only when that column holds a valid `low`/`medium`/`high` value) > global default `medium`. This is a fixed, executor-agnostic vocabulary — narrower than either CLI's raw surface (claude's native `--effort` also accepts `xhigh`/`max`) — chosen so an invalid value is rejected up front by pm-dispatch, not mid-run inside the executor subprocess. See `runtime/lib/reasoning-effort.sh` for the resolution logic.

The "reasoning effort" columns in the alias tables above are the per-alias default that applies whenever `--effort` is omitted — an alias's own valid column value wins over the global default, so it is the practical default, not just a fallback label. `default`/`gpt-5.5`/`gpt-5.4` carry `medium` for exactly this reason (a plain dispatch/gate call is `medium` by default without needing `--effort medium` on every invocation); `codex-spark`/`light` intentionally keep `high`, unchanged and orthogonal to this convergence. The claude table's legacy `normal` values are not a valid `low`/`medium`/`high` literal, so they are ignored and those aliases fall through to the `medium` global default in practice (`opus`'s `high` is valid and is honored as-is). `pmctl gate run` accepts the same `--effort` flag; reach for `--effort high` only when you need deeper analysis (e.g. escalating after repeated gate NO-GOs).

opencode has no reasoning-effort equivalent; `--effort` is accepted as a no-op with a warning by that adapter (non-goal — see `docs/executor-contract.md`). grok wires `--effort` to native `--reasoning-effort`.

Direct Bash dispatch shape (substitute `<executor>` with `codex`, `claude`, `opencode`, or `grok`):

```text
Bash(command: "pmctl dispatch run --adapter <executor> --cd <safe working_dir> --isolation <safe isolation_level> --timeout <safe timeout> --brief-file <safe brief_file> --lifecycle foreground", run_in_background: true, description: "Dispatch <executor> for <slug>")
```

(Omit `--lifecycle foreground` to use the two-step `run` + `pmctl dispatch wait` pattern instead — see §Dispatch lifecycle.)

Before constructing this Bash command, the dispatcher MUST source `runtime/lib/handover-validate.sh`, extract the fenced block with `handover_extract_block`, split it with `handover_extract_metadata` and `handover_extract_body`, require metadata with `handover_validate_required_fields`, validate the complete metadata header with `handover_validate_all_metadata`, confirm body consistency with `handover_validate_working_dir_match`, then use `handover_safe_argv <field> <value>` for the argv fragment inserted into the one-line command. This is the enforcement mechanism for the handover route, not optional formatting guidance.

`handover_validate_all_metadata` applies these field validators:

- `handover_validate_handover_version`
- `handover_validate_executor`
- `handover_validate_dispatch_route`
- `handover_validate_working_dir`
- `handover_validate_brief_file`
- `handover_validate_isolation_level` (required; the legacy `sandbox`/`approval`/`skip_git_check` fields were removed in v0.6.0 and are rejected if present)
- `handover_validate_timeout`
- `handover_validate_model`
- `handover_validate_fallback_allowed`

Rejected example:

```text
working_dir: /tmp/x'; touch /tmp/pwned; #
```

Reject this before command construction because `working_dir` contains shell metacharacters.

Control-field reject examples:

```text
handover_version: 4
executor: claude
dispatch_route: mystery_route
working_dir: relative/path
brief_file: /etc/passwd
isolation_level: danger-full-access
timeout: 3601
model: Codex_Spark!
sandbox: workspace-write
fallback_allowed: maybe
```

Each example above must reject before command construction: the control fields (`dispatch_route`, `working_dir`, `brief_file`, `isolation_level`, `timeout`, `model`, `fallback_allowed`) reject through their field validators, while the `sandbox` line rejects through the removed-legacy-field check (no `handover_validate_sandbox` validator exists anymore — the field was removed in v0.6.0).

Argument order is stable:

1. `pmctl dispatch run --adapter codex`
2. `--cd <safe working_dir>`
3. `--model <safe model>` only if `model` is not `default`
4. `--isolation <safe isolation_level>`
5. `--timeout <safe timeout>`
6. `--brief-file <safe brief_file>`

`isolation_level: none` (full machine access) is **opencode-only**, where it is load-bearing (opencode has no finer-grained sandbox). For codex, claude, and grok it is hard-rejected on every route — their max isolation is `workspace-write`, and the Agent escape hatch that once carried full access for codex was retired. There is no full-access route for codex/claude/grok. The codex adapter also rejects a raw `--sandbox danger-full-access` flag (fail-loud, exit 2), so native-flag passthrough through `pmctl dispatch run` cannot reintroduce full access.

### Grok profile model aliases

PM short-form model aliases for the grok executor, resolved from `share/grok-model-aliases.tsv`:

| PM-facing alias | Wire model ID | Default effort | Notes |
|---|---|---|---|
| `default` | `grok-4.5` | medium | Default when `--model` omitted |
| `light` | `grok-4.5` | low | Same model, lower reasoning effort |
| `build` / `grok-build` | `grok-build` | medium | Grok Build product alias |
| `grok-4.5-build` | `grok-4.5-build` | medium | Telemetry/usage key form |

Quoting and command-shape rules:

- Validate metadata first with `runtime/lib/handover-validate.sh`; never insert raw metadata into the Bash command.
- Use `handover_safe_argv` output for every metadata-derived argv value.
- Single physical line, with no `\` continuation.
- No `cd <dir> && ...` compounds; a `cd`-prefixed compound can leave the dispatched agent resolving later paths against the pre-`cd` directory (a stale agent-context lifecycle leak). Pass the working directory as `--cd` instead.
- No inline `-- <brief>` form; always dispatch a file-backed brief.
- Use `run_in_background: true` on the main-thread Bash call so the main thread can continue and receive the completion notification later.

Completion-parse procedure:

1. When the completion notification arrives, read `BashOutput(bash_id: <id>)` to get the full merged stdout and stderr captured by the harness.
2. Parse the stable stdout footer emitted by `adapters/codex/dispatch.sh`: `trace:`, `last:`, `stderr:`, and `exit:` between `---` separators.
3. Use the start banner in stderr to verify: cwd, model, sandbox, approval, timeout, trace, and brief.
4. Use the finish banner in stderr to confirm completion and note any timeout.
5. Read `<last>` for the final Codex message. If it is empty, fall back to the last `agent_message` item in the `.jsonl` trace.
6. Read `<stderr>` regardless of exit code. Surface any non-empty content beyond the standard start and finish banners as `dispatch_errors`.
7. Verify `git -C <working_dir> status --short`, `git -C <working_dir> diff --stat <base>...HEAD`, and observed `command_execution` events against the brief's `files:` and `self_verify:` blocks before reporting `ok`; otherwise report `partial` or `failed`.

Runnable coverage for extraction, validation, safe argv construction, and footer parsing lives in `tests/shell/test-dispatch-handover.sh`.

Report shape:

```text
Codex dispatch completed: ok | partial | failed
Brief: <one-line goal>
Exit: <N>
Trace: <trace path>
Last message: <summary from .last or trace fallback>
Verification: <self_verify checks observed or missing>
Worktree: <git status/diff summary>
Dispatch stderr: <none | concise warning summary>
```

If the completion notification does not arrive within `<timeout>+30s`, run this diagnostic checklist: check for a live `codex-dispatch` process, inspect `.agent-trace/latest.*` mtimes, and decide whether the task is still running or orphaned before retrying. If the direct Bash route exits 124, retry exactly once with the same brief and flags after the diagnostic check; do not retry other non-zero exits without main-thread review.

### No Agent executor fallback

There is no Agent-spawn executor route. Both the `claude-executor` and `codex-executor` subagents were retired; every executor now runs as an independent subprocess driven by `pmctl dispatch run`, and the brief is always authored by trusted main-thread code (no subagent self-writes a brief). Schema validation is delegated to `runtime/bin/brief-validate.sh` via the `pmctl dispatch run` pre-flight. (`agent_executor` survives only as a reserved `dispatch_route` value for a possible future host-native adapter.)

## Dispatching a brief

Write the brief to `/tmp/brief-<task>.md` first, then pass it via `--brief-file`. This is the **canonical** way to dispatch. The main thread creates the brief file with its own Write tool before invoking `pmctl dispatch run`.

For a human shell only, a heredoc is an acceptable way to create the same file:

```bash
cat > /tmp/brief-<task>.md << 'EOF'
working_dir: ...
goal: ...
...
EOF

# Dispatch (single line — no backslash continuation)
pmctl dispatch run --adapter codex --cd <abs path> --isolation workspace-write --brief-file /tmp/brief-<task>.md
```

**Why `--brief-file` and not inline `-- "<brief>"`?**
- `--brief-file` decouples brief content from the shell invocation — the dispatch command stays a single line with no newline or `\` continuation, no matter how large the brief. Long briefs with code blocks, JSON, and shell paths embed cleanly in the file instead of the command.
- It keeps the dispatch command free of shell-metacharacter and quoting hazards that inline brief bodies introduce.
- Inline `-- <brief>` is kept only for trivial smoke checks. Do not use it for real implementation briefs.

## Commit delegation rule

**Executors MUST NOT include `git add`, `git commit`, or any commit step in briefs, `self_verify`, `constraints`, or `acceptance`.**

Commit is always delegated to the main thread after dispatch-post-verify succeeds. This is a structural rule, not a style preference:

- The executor runs sandboxed (e.g. codex's `--sandbox workspace-write`), which blocks `git commit`. Any brief that includes a commit step will cause the executor to report `status: partial` — even when every code change landed correctly. This is a false partial that pollutes the signal.
- `guard-executor-write.sh` (the unified executor write-guard) prevents an executor from writing to the repo outside its allowed brief-file surface at dispatch time.
- The main thread is always the commit authority: it runs `git diff`, reviews changes, and commits when satisfied.

**What to write instead:**

```yaml
# ✗ Do not write:
self_verify:
  - cmd: "git add -A && git commit -m 'feat: ...'"
acceptance:
  - changes committed to branch

# ✓ Write instead:
self_verify:
  - cmd: "<your actual test or check command>"
  - git-status no-collateral-damage
acceptance:
  - <describe the file changes and test results>
  - git status --short shows only the expected files modified
```

The main thread commits after Phase 3 (dispatch-post-verify) exits 0. If dispatch-post-verify exits 1, the main thread reviews the partial and decides whether to commit, fix-and-re-dispatch, or discard.

## Style notes

- Prose is fine; YAML-like keys above are conventions, not strict syntax. Keep real dispatches file-backed via `--brief-file`.
- Keep briefs in the active voice ("Audit X", not "X should be audited"). Codex parses imperatives more reliably than declaratives.
- Don't write implementation steps. The brief tells Codex *what* and *what counts as done*; *how* is Codex's job.
- Never include `git add` or `git commit` in `self_verify`, `constraints`, or `acceptance` — see §Commit delegation rule above.

## Trial dispatch end-to-end recipe

Use this smoke recipe after changing dispatch policy. It should complete without modifying the repo.

Minimal no-op brief body:

```yaml
working_dir: ${PM_DISPATCH_REPO}
goal: Confirm codex-dispatch can run a read-only no-op brief and report cleanly.
files:
  - read: README.md
constraints:
  - Do not modify files.
acceptance:
  - Codex reports the README exists.
  - git status --short is unchanged.
```

Write it to a unique path such as `/tmp/brief-pm-dispatch-cc036-smoke-<utc-ts>-<rand>.md` with exclusive `mktemp`-style creation, validate each metadata value with `runtime/lib/handover-validate.sh`, then launch one physical line built from `handover_safe_argv` values:

```text
Bash(command: "pmctl dispatch run --adapter codex --cd ${PM_DISPATCH_REPO} --isolation workspace-write --timeout 1200 --brief-file /tmp/brief-pm-dispatch-cc036-smoke-<utc-ts>-<rand>.md --lifecycle foreground", run_in_background: true, description: "Dispatch codex for cc036-smoke")
```

Expected sequence:

1. Harness returns a background Bash task id.
2. Completion notification arrives.
3. Main thread reads `BashOutput(bash_id: <id>)`.
4. Footer parse finds `trace:`, `last:`, `stderr:`, and `exit:` from the stable stdout footer emitted by `adapters/codex/dispatch.sh`.
5. Main thread reads `<last>` and `<stderr>`, ignoring only the standard start and finish banners.
6. Main thread runs `git -C ${PM_DISPATCH_REPO} status --short` and confirms no unexpected changes.
7. The run's lifecycle events (`pending` → `dispatched` → `verifying` → `ok`) are visible via `pmctl trace tail --kind run.dispatched`.
