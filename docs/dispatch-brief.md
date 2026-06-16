# Dispatch brief schema

The canonical structure for any brief dispatched to an executor (`codex-executor` via `pmctl dispatch run --adapter codex` or Agent fallback, or `claude-executor` via Agent).

Both executors reject briefs missing the required fields. PMs and main-thread dispatchers should always write briefs against this schema; pick the matching skeleton in §"Brief skeletons" and fill the slots — don't write from scratch.
The executor-level abstraction is defined in [docs/executor-contract.md](docs/executor-contract.md); this file is the concrete brief schema (independent of executor profile).

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

The handover metadata's `executor:` field selects which executor receives the brief. Valid values today: `codex`, `claude`, and `opencode`. The default is set at install time via `./install.sh --profile minimal|full` (auto-detected from `command -v codex` when unset): `full` → `codex`, `minimal` → `claude`. PM may override per-brief by setting `executor:` explicitly in the `dispatch_handover_v1` block. Use `isolation_level:` in the handover metadata (canonical values: `none | read-only | workspace-write | workspace-network | sandboxed`); the adapter layer translates this to executor-native flags — note that `opencode` only supports `none` and `workspace-write` (others are rejected at dispatch time). The legacy fields `sandbox`, `approval`, and `skip_git_check` are still accepted for backward compatibility with pre-M3 briefs but must not appear alongside `isolation_level:` in the same block.

## Required fields

| Field | What | Example |
|---|---|---|
| `schema_version` | Always `1`. Identifies the brief format version. | `1` |
| `working_dir` | Absolute path. Must exist. | `/home/example/github/my-app/` |
| `goal` | One sentence. What changes after this runs. | "Backfill 40 N4 / 40 N3 / 40 N2 kanji entries to fill the empty middle-tier overlay." |
| `files` | Concrete paths or a search hint. Both create-new and edit-existing must be enumerated. | `server/data/corpus/kanji/{N4,N3,N2}.jsonl` (new); read `N1.jsonl` and `N5.jsonl` for schema |
| `acceptance` | Testable post-conditions Codex itself can verify before declaring done. | Lint passes (`bash scripts/lint-agents.sh` exit 0); new file exists at the declared path; `git status --short` shows only allowlisted files. |
| `self_verify` | **Required for any file-writing brief.** A brief is file-writing if its `files` block contains any entry tagged `write:` or `new:`, or any entry with no explicit `read:` tag. When in doubt, treat as file-writing. Read-only briefs (every `files:` entry explicitly tagged `read:`) may omit this field — do not inline checks into `acceptance` as a substitute for `self_verify` in file-writing briefs. Machine-verifiable items use `- cmd: "<bash>"` (post-verify executes them); macros/prose are executor-evaluated (post-verify skips them). | `- cmd: "bash scripts/test.sh"`; `git-status no-collateral-damage` (executor-evaluated). |

A brief missing any of these is a request for guesswork. Reject and ask the caller.

The pairing matters: `acceptance` is **what** must be true after the run; `self_verify` is **how** Codex proves it before declaring done. Don't conflate them — Codex evaluates `self_verify` itself, but `codex-executor` re-checks `acceptance` against `git diff` from outside.

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

- **`architecture_impact`** — `none | minor | major`. Declares the architectural weight of this change. When `architecture_impact: major`, `conceptual_map` is **required** — `brief-validate.sh` will FAIL without it. When `architecture_impact: minor`, `conceptual_map` is recommended — `brief-validate.sh` will WARN if absent. Drives `pr-gate` tier suggestion: `none` → express; `minor` → standard; `major` → full.

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
- **`task`** — free-form instruction block used by composed workflows to pass per-run task instructions distinct from the brief's `goal` field.
- **`output_format`** — when the deliverable is a report (audit, plan), specify the file path and required sections.
- **`isolation_level`** — use for new briefs: `workspace-write` (default), `read-only`, `workspace-network`, `sandboxed`, or `none` (requires `agent_executor` dispatch route). The adapter layer translates to executor-native flags. Source of truth: `core/policy/isolation-level.yaml`.
- **`sandbox`** / **`approval`** (legacy) — backward-compat only; accepted when `isolation_level` is absent; new briefs must use `isolation_level`.
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

For deterministic opt-in packing at dispatch time, run:

    pmctl dispatch run --adapter <executor> --cd <repo_root> --brief-file <brief> --auto-pack

or set:

    dispatch.auto_pack = on

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
bash scripts/brief-validate.sh <brief-file>
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
# dispatch via Agent(claude-executor)

# opencode profile:
pmctl dispatch run --adapter opencode --cd <work_dir> --brief-file <brief-file>
```

Invoke in background from the main thread. Wait for completion notification.

### Phase 3 — Post-dispatch verification (executor-agnostic shell, <5s)

```bash
bash scripts/dispatch-post-verify.sh <work_dir> <brief-file>
```

Reads `.agent-trace/latest.{last,stderr}`, shows `git diff --stat`, and processes each `self_verify` item by kind (CC-318):

- A **machine-executable check** in the structured `- cmd: "<bash>"` form is **executed** in `<work_dir>` — `PASS` iff the command exits 0, `FAIL` on non-zero or timeout (`DISPATCH_SELF_VERIFY_TIMEOUT`, default 300s). This does not depend on the executor's prose: the command is run, not searched for in the executor's final message.
- Any **other shape** (a named macro like `git-status no-collateral-damage`, free prose, or a bare scalar) is a **semantic check the executor evaluates**, not a shell — post-verify marks it `SKIP (executor-evaluated)` and does not fail on it. Confirm these by reading the executor's report.

Works for any executor (codex, claude, or opencode). Exits 0 = ok (no executed check failed); exits 1 = partial/failed. **Write any check you want machine-verified as `- cmd: "..."`.**

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

`project-pm` hands implementation briefs back to the main thread as one fenced block tagged `dispatch_handover_v1`. The main thread extracts the block, writes the brief body to `brief_file`, then dispatches via `pmctl dispatch run --adapter codex` in the background. This is the **sole routine codex path** — no subagent ever holds brief-write authority on it. `Agent(codex-executor)` is a **fallback only** (the cases below); even there the main thread pre-writes the brief — codex-executor has no `Write` tool — so no subagent self-writes a brief on any codex route.

```dispatch_handover_v1
handover_version: 3
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
| `handover_version` | yes | Currently `3`; bump on shape change. |
| `executor` | yes | Closed enum: `codex`, `claude`, `opencode`. Main-thread dispatch uses this field to choose the executor-specific adapter. |
| `dispatch_route` | yes | `main_thread_bash_background` by default, or `agent_executor` for fallback. |
| `working_dir` | yes | Absolute path; must exist; must match the brief body. |
| `brief_file` | yes | Absolute path under `/tmp/brief-...`; main thread creates this file with unique `mktemp`-style exclusive semantics, then writes the brief body. |
| `isolation_level` | yes (new) | Canonical isolation intent: `none \| read-only \| workspace-write \| workspace-network \| sandboxed`. Adapter layer expands to executor-native flags. Cannot be mixed with legacy `sandbox`/`approval`/`skip_git_check`. |
| `timeout` | yes | Seconds; `1200` default. Passed through to the executor adapter. For `opencode`, must be 0 (no limit) or ≥ 120 (per-attempt floor). |
| `model` | yes | `default` or an executor-specific model wire-id. For `opencode`, aliases like `light`/`default` are resolved by the adapter. |
| `fallback_allowed` | yes | Whether main thread may use `Agent(codex-executor)` if the Bash route is unsuitable. |
| `sandbox` | backward-compat | Legacy field accepted when `isolation_level` is absent. Bash route accepts only `workspace-write` or `read-only`; `danger-full-access` requires Agent(codex-executor) fallback. |
| `approval` | backward-compat | Legacy field accepted when `isolation_level` is absent. Bash route accepts only `never`. |
| `skip_git_check` | backward-compat | Legacy field accepted when `isolation_level` is absent. Bash route accepts only `false`. |
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

## Executor-agnostic model aliases

Use these aliases in briefs and PM routing — never hard-code executor wire-format IDs.
Each adapter resolves the alias to its own wire format at dispatch time.

| PM-facing alias | codex wire ID | claude wire ID | When to use |
|---|---|---|---|
| `default` | `gpt-5.5` | `claude-sonnet-4-6` | All medium/large tasks (omit `--model` or write `model: default`) |
| `light` | `gpt-5.3-codex-spark` | `claude-haiku-4-5-20251001` | Small tasks only (see §When to dispatch) |

See `docs/model-tier-policy.md` §Executor-agnostic `light` alias for routing criteria.

## Model aliases

PM short-form model aliases are resolved from the source-of-truth file
`share/model-aliases.tsv`, then passed as wire-format model IDs to `codex exec`.
`scripts/lint-model-aliases.sh` asserts that this table stays in sync with the PM-facing table below and any template hardcoded references.

| PM-facing alias | Wire-format model ID | reasoning effort |
|---|---|---|
| `default` | `gpt-5.5` | `high` |
| `gpt-5.5` | `gpt-5.5` | `high` |
| `gpt-5.4` | `gpt-5.4` | `high` |
| `codex-spark` | `gpt-5.3-codex-spark` | `high` |
| `light` | `gpt-5.3-codex-spark` | `high` |

`light` is opt-in only and draws from an independent usage pool — see §Executor-agnostic model aliases above.

## Claude model aliases

PM short-form model aliases for the claude executor, resolved from `share/claude-model-aliases.tsv`.
`scripts/lint-model-aliases.sh` asserts that this table stays in sync with the source TSV.

| PM-facing alias | Wire-format model ID | reasoning effort |
|---|---|---|
| `default` | `claude-sonnet-4-6` | `normal` |
| `sonnet` | `claude-sonnet-4-6` | `normal` |
| `light` | `claude-haiku-4-5-20251001` | `normal` |
| `haiku` | `claude-haiku-4-5-20251001` | `normal` |
| `opus` | `claude-opus-4-8` | `high` |

`default` is applied when `PM_CFG_DEFAULT_MODEL` is set or when `--model default` is given explicitly; omitting `--model` with no config default delegates to the claude CLI built-in default. Every alias in these tables is a valid handover `model:` value (`scripts/lib/handover-validate.sh`).

Direct Bash dispatch shape (substitute `<executor>` with `codex`, `claude`, or `opencode`):

```text
Bash(command: "pmctl dispatch run --adapter <executor> --cd <safe working_dir> --isolation <safe isolation_level> --timeout <safe timeout> --brief-file <safe brief_file>", run_in_background: true, description: "Dispatch <executor> for <slug>")
```

When dispatching a legacy brief that has `sandbox:` instead of `isolation_level:`, use `--sandbox <safe sandbox> --approval <safe approval>` in place of `--isolation <safe isolation_level>`.

Before constructing this Bash command, the dispatcher MUST source `scripts/lib/handover-validate.sh`, extract the fenced block with `handover_extract_block`, split it with `handover_extract_metadata` and `handover_extract_body`, require metadata with `handover_validate_required_fields`, validate the complete metadata header with `handover_validate_all_metadata`, confirm body consistency with `handover_validate_working_dir_match`, then use `handover_safe_argv <field> <value>` for the argv fragment inserted into the one-line command. This is the enforcement mechanism for the handover route, not optional formatting guidance.

`handover_validate_all_metadata` applies these field validators:

- `handover_validate_handover_version`
- `handover_validate_executor`
- `handover_validate_dispatch_route`
- `handover_validate_working_dir`
- `handover_validate_brief_file`
- `handover_validate_isolation_level` (when `isolation_level:` present) **OR** the legacy trio below (when absent):
  - `handover_validate_sandbox`
  - `handover_validate_approval`
  - `handover_validate_skip_git_check`
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
handover_version: 3
executor: claude
dispatch_route: mystery_route
working_dir: relative/path
brief_file: /etc/passwd
sandbox: danger-full-access
approval: on-request
timeout: 3601
model: Codex_Spark!
skip_git_check: true
fallback_allowed: maybe
```

Each example above must reject before command construction through the corresponding field validator.

Argument order is stable:

1. `pmctl dispatch run --adapter codex`
2. `--cd <safe working_dir>`
3. `--model <safe model>` only if `model` is not `default`
4. `--isolation <safe isolation_level>` (canonical) OR `--sandbox <safe sandbox> --approval <safe approval>` (legacy fallback when `isolation_level` is absent)
5. `--timeout <safe timeout>`
6. `--brief-file <safe brief_file>`

The Bash route never emits `--skip-git-check`. Validator hard-rejects `skip_git_check: true`; callers needing this flag must use the Agent(codex-executor) fallback.

Quoting and command-shape rules:

- Validate metadata first with `scripts/lib/handover-validate.sh`; never insert raw metadata into the Bash command.
- Use `handover_safe_argv` output for every metadata-derived argv value.
- Single physical line, with no `\` continuation.
- No `cd <dir> && ...` compounds; this avoids the stale agent-context lifecycle leak described in `[[feedback_codex_dispatch_lifecycle_leak]]`.
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

Runnable coverage for extraction, validation, safe argv construction, and footer parsing lives in `scripts/test-dispatch-handover.sh`.

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

If the completion notification does not arrive within `<timeout>+30s`, run the diagnostic checklist from `[[feedback_codex_dispatch_foreground]]`: check for a live `codex-dispatch` process, inspect `.agent-trace/latest.*` mtimes, and decide whether the task is still running or orphaned before retrying. If the direct Bash route exits 124, retry exactly once with the same brief and flags after the diagnostic check; do not retry other non-zero exits without main-thread review.

### Fallback

Use `Agent(codex-executor)` only for this fallback allowlist:

| Condition | Rationale |
|---|---|
| Strict pre-flight validation is the primary need. | `codex-executor` rejects missing schema fields, missing file-writing `self_verify`, and subtle read/write ambiguity before a long dispatch is wasted. |
| Main-thread context is near-full. | The fallback moves validation, trace-reading, and result verification out of the main thread when the conversation window is the limiting factor. |
| Sync workflow must remain serialized. | Some composed flows need foreground sequencing and artifact validation rather than an asynchronous completion notification. |
| Direct Bash route is locally unavailable. | Missing script path, unreachable `working_dir`, or an unavailable Bash tool means the documented primary route cannot run. |
| Brief requires skip_git_check: true, sandbox: danger-full-access, or approval other than never. | Bash route validator hard-rejects these values with no override channel; the Agent route accepts them via codex-executor's documented override flags. |
| User explicitly requests codex-executor validation. | User intent overrides the ergonomic default when it does not conflict with safety rules. |

When using fallback, set `dispatch_route: agent_executor` and state the reason in one sentence before dispatch. Do not expand the fallback list casually; the default route is main-thread background Bash.

#### claude executor fallback (symmetric)

The `executor: claude` profile follows the same shape: the canonical route is main-thread `pmctl dispatch run --adapter claude` → headless `claude --print`, and `Agent(claude-executor)` is the narrow fallback / sanctioned in-session route. The conditions differ only where the executors differ:

| Condition | Rationale |
|---|---|
| Headless `claude --print` unavailable (e.g. `claude` CLI not in PATH). | The canonical route spawns the external `claude` binary; without it, the in-session Agent is the only host-independent way to run a claude brief. This is the primary reason the claude Agent route exists. |
| Main-thread context is near-full. | Execution, self-verify, and trace-writing move out of the main thread when the window is the limiting factor. |
| Sync workflow must remain serialized. | Foreground sequencing + inline artifact validation instead of an asynchronous completion notification. |
| `/pr-gate` reviewer fan-out (**sanctioned, not a fallback**). | `pr-gate` orchestrates parallel `Agent(claude-executor)` reviewers itself — the intended in-session model. Do not hand-roll claude-executor review dispatches outside pr-gate. |
| User explicitly requests claude-executor. | User intent overrides the ergonomic default when it does not conflict with safety rules. |

Authoritative per-executor checklists live in `agents/codex-executor.md` and `agents/claude-executor.md` §When NOT to use this agent; both delegate brief schema validation to `scripts/brief-validate.sh` (codex via the `pmctl dispatch run` pre-flight, claude via a direct call — see each agent's §Validation).

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
pmctl dispatch run --adapter codex --cd <abs path> --isolation workspace-write --brief-file /tmp/brief-<task>.md
```

**Why `--brief-file` and not inline `-- "<brief>"`?**
- The `hook-codex-bash-guard.sh` PreToolUse hook blocks any command that contains a newline or `\` continuation. Long briefs with code blocks, JSON, and shell paths almost always trigger this.
- `--brief-file` decouples brief content from the shell invocation — the hook only sees the single-line dispatch command.
- Inline `-- <brief>` is kept only for trivial smoke checks. Do not use it for real implementation briefs.

## Fallback Agent Call Checklist

Before the main thread dispatches `codex-executor` via `Agent(subagent_type: "codex-executor", ...)` as a fallback route, verify these checks:

| Check | Rule | Why |
|---|---|---|
| `isolation` absent | **Never set `isolation: "worktree"`** | Harness tries to create a worktree from the main thread's CWD, which may not be a git repo → instant "Cannot create agent worktree" error before codex-executor starts |
| `run_in_background: true` | **Required for parallel dispatches** | Without it the main thread blocks on each agent; user cannot send new commands while agents run |
| `self_verify` in brief | **Required for file-writing briefs** | codex-executor rejects immediately with 0 tool uses if absent; entire invocation is wasted |
| brief file pre-written | **Required before the Agent call** | codex-executor has no Write tool, so it cannot create `/tmp/brief-*.md` for itself |
| `qa_checklist` in brief | **Required when ≥ 3 behavioral units introduced** | Without it, `qa-tester` blocks in gate round 1 for missing coverage; fixing after the fact adds 1–2 extra gate rounds |

Failing any check wastes the agent invocation before a single tool call is made. Check every item before sending.

## Commit delegation rule

**Executors MUST NOT include `git add`, `git commit`, or any commit step in briefs, `self_verify`, `constraints`, or `acceptance`.**

Commit is always delegated to the main thread after dispatch-post-verify succeeds. This is a structural rule, not a style preference:

- `hook-codex-bash-guard.sh` blocks `git commit` inside the executor sandbox. Any brief that includes a commit step will cause the executor to report `status: partial` — even when every code change landed correctly. This is a false partial that pollutes the signal.
- `hook-executor-write-guard.sh` (the unified executor write-guard) prevents an executor from writing to the repo outside its allowed brief-file surface at dispatch time.
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

Write it to a unique path such as `/tmp/brief-pm-dispatch-cc036-smoke-<utc-ts>-<rand>.md` with exclusive `mktemp`-style creation, validate each metadata value with `scripts/lib/handover-validate.sh`, then launch one physical line built from `handover_safe_argv` values:

```text
Bash(command: "pmctl dispatch run --adapter codex --cd ${PM_DISPATCH_REPO} --isolation workspace-write --timeout 1200 --brief-file /tmp/brief-pm-dispatch-cc036-smoke-<utc-ts>-<rand>.md", run_in_background: true, description: "Dispatch codex for cc036-smoke")
```

Expected sequence:

1. Harness returns a background Bash task id.
2. Completion notification arrives.
3. Main thread reads `BashOutput(bash_id: <id>)`.
4. Footer parse finds `trace:`, `last:`, `stderr:`, and `exit:` from the stable stdout footer emitted by `adapters/codex/dispatch.sh`.
5. Main thread reads `<last>` and `<stderr>`, ignoring only the standard start and finish banners.
6. Main thread runs `git -C ${PM_DISPATCH_REPO} status --short` and confirms no unexpected changes.
7. The run's lifecycle events (`pending` → `dispatched` → `verifying` → `ok`) are visible via `pmctl trace tail --kind run.dispatched`.
