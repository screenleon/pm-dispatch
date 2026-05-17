# Dispatch brief schema

The canonical structure for any brief dispatched to `codex-executor` (directly via Agent, or indirectly via `scripts/codex-dispatch.sh`).

`codex-executor` rejects briefs missing the required fields. PMs and main-thread dispatchers should always write briefs against this schema; pick the matching skeleton in §"Brief skeletons" and fill the slots — don't write from scratch.

## Required fields

| Field | What | Example |
|---|---|---|
| `working_dir` | Absolute path. Must exist. | `/home/example/github/my-app/` |
| `goal` | One sentence. What changes after this runs. | "Backfill 40 N4 / 40 N3 / 40 N2 kanji entries to fill the empty middle-tier overlay." |
| `files` | Concrete paths or a search hint. Both create-new and edit-existing must be enumerated. | `server/data/corpus/kanji/{N4,N3,N2}.jsonl` (new); read `N1.jsonl` and `N5.jsonl` for schema |
| `acceptance` | Testable post-conditions Codex itself can verify before declaring done. | Lint passes (`bash scripts/lint-agents.sh` exit 0); new file exists at the declared path; `git status --short` shows only allowlisted files. |
| `self_verify` | **Required for any file-writing brief.** A brief is file-writing if its `files` block contains any entry tagged `write:` or `new:`, or any entry with no explicit `read:` tag. When in doubt, treat as file-writing. Read-only briefs (every `files:` entry explicitly tagged `read:`) may omit this field — do not inline checks into `acceptance` as a substitute for `self_verify` in file-writing briefs. | `git-status no-collateral-damage`; `schema-match` against the reference file. |

A brief missing any of these is a request for guesswork. Reject and ask the caller.

The pairing matters: `acceptance` is **what** must be true after the run; `self_verify` is **how** Codex proves it before declaring done. Don't conflate them — Codex evaluates `self_verify` itself, but `codex-executor` re-checks `acceptance` against `git diff` from outside.

## Optional sections

Use as needed; not all briefs require all of them.

- **`constraints`** — what NOT to do. File paths off-limits, conventions to preserve, tests that must still pass after the change. **When the brief introduces ≥ 3 behavioral units**, run `/pre-impl "<feature description>"` first and paste the output's design constraint list here — this prevents architecture-reviewer blocks from boundary/dependency issues caught too late.
- **`context`** — free-form background section used by composed workflows (e.g., `pr-gate`) to pass reviewer context or codebase summary to the agent.
- **`task`** — free-form instruction block used by composed workflows to pass per-run task instructions distinct from the brief's `goal` field.
- **`output_format`** — when the deliverable is a report (audit, plan), specify the file path and required sections.
- **`sandbox`** / **`approval`** — only set when overriding the defaults (`workspace-write` / `never`). Caller must authorize.
- **`qa_checklist`** — **Conditionally required**: include when the brief introduces ≥ 3 distinct behavioral units (new code paths, new flags, new hooks, new error-handling branches). For each unit, list its expected test name or scenario. `qa-tester` will block in gate round 1 for any introduced unit without adjacent coverage — writing this upfront costs one minute and prevents multiple gate/fix cycles. Example:
  ```
  qa_checklist:
    - happy path: dispatch exits 0, trace file exists
    - failed dispatch: exit preserved, stderr records message
    - spark pool: --model *spark* → pool=spark in log entry
    - log failure: log-usage.sh unavailable → dispatch still exits 0
  ```

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
# qa_checklist: add if introducing ≥ 3 behavioral units (see Optional sections)
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

`project-pm` hands implementation briefs back to the main thread as one fenced block tagged `dispatch_handover_v1`. The main thread extracts the block, writes the brief body to `brief_file`, then dispatches `scripts/codex-dispatch.sh` directly with Bash in the background. `Agent(codex-executor)` remains available only for the fallback cases below.

```dispatch_handover_v1
handover_version: 2
executor: codex
dispatch_route: main_thread_bash_background
working_dir: /home/screenleon/github/pm-dispatch
brief_file: /tmp/brief-<repo>-<slug>-<utc-ts>-<rand>.md
sandbox: workspace-write
approval: never
timeout: 1200
model: default
skip_git_check: false
fallback_allowed: true
---
working_dir: /home/screenleon/github/pm-dispatch
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
| `handover_version` | yes | Currently `2`; bump on shape change. |
| `executor` | yes | Closed enum. Currently only `codex`; main-thread dispatch uses this field to choose the executor-specific dispatcher. |
| `dispatch_route` | yes | `main_thread_bash_background` by default, or `agent_executor` for fallback. |
| `working_dir` | yes | Absolute path; must exist; must match the brief body. |
| `brief_file` | yes | Absolute path under `/tmp/brief-...`; main thread creates this file with unique `mktemp`-style exclusive semantics, then writes the brief body. |
| `sandbox` | yes | Bash route accepts only `workspace-write` or `read-only`; `danger-full-access` requires Agent(codex-executor) fallback. |
| `approval` | yes | Bash route accepts only `never`; other values require Agent(codex-executor) fallback. |
| `timeout` | yes | `1200` default, in seconds. |
| `model` | yes | `default` or a specific Codex model name. |
| `skip_git_check` | yes | Bash route accepts only `false`; `true` requires Agent(codex-executor) fallback. |
| `fallback_allowed` | yes | Whether main thread may use `Agent(codex-executor)` if the Bash route is unsuitable. |

## Model aliases

PM short-form model aliases are mapped to wire-format model IDs inside
`scripts/codex-dispatch.sh` before invoking `codex exec`.

| PM-facing alias | Wire-format model ID | reasoning effort |
|---|---|---|
| `codex-spark` | `gpt-5.3-codex-spark` | `high` |

This table is hardcoded in `scripts/codex-dispatch.sh` and must be kept in
sync if CLI alias behavior or Codex model availability changes.

Direct Bash dispatch shape:

```text
Bash(command: "bash /home/screenleon/github/pm-dispatch/scripts/codex-dispatch.sh --cd <safe working_dir> --sandbox <safe sandbox> --approval <safe approval> --timeout <safe timeout> --brief-file <safe brief_file>", run_in_background: true, description: "Dispatch codex for <slug>")
```

Before constructing this Bash command, the dispatcher MUST source `scripts/lib/handover-validate.sh`, extract the fenced block with `handover_extract_block`, split it with `handover_extract_metadata` and `handover_extract_body`, require metadata with `handover_validate_required_fields`, validate the complete metadata header with `handover_validate_all_metadata`, confirm body consistency with `handover_validate_working_dir_match`, then use `handover_safe_argv <field> <value>` for the argv fragment inserted into the one-line command. This is the enforcement mechanism for the handover route, not optional formatting guidance.

`handover_validate_all_metadata` applies these field validators:

- `handover_validate_handover_version`
- `handover_validate_executor`
- `handover_validate_dispatch_route`
- `handover_validate_working_dir`
- `handover_validate_brief_file`
- `handover_validate_sandbox`
- `handover_validate_approval`
- `handover_validate_timeout`
- `handover_validate_model`
- `handover_validate_skip_git_check`
- `handover_validate_fallback_allowed`

Rejected example:

```text
working_dir: /tmp/x'; touch /tmp/pwned; #
```

Reject this before command construction because `working_dir` contains shell metacharacters.

Control-field reject examples:

```text
handover_version: 2
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

1. `bash <abs path>/scripts/codex-dispatch.sh`
2. `--cd <safe working_dir>`
3. `--model <safe model>` only if `model` is not `default`
4. `--sandbox <safe sandbox>`
5. `--approval <safe approval>`
6. `--timeout <safe timeout>`
7. `--brief-file <safe brief_file>`

The Bash route never emits `--skip-git-check`. Validator hard-rejects `skip_git_check: true`; callers needing this flag must use the Agent(codex-executor) fallback, which passes it through `codex-executor`'s own override mechanism.

Quoting and command-shape rules:

- Validate metadata first with `scripts/lib/handover-validate.sh`; never insert raw metadata into the Bash command.
- Use `handover_safe_argv` output for every metadata-derived argv value.
- Single physical line, with no `\` continuation.
- No `cd <dir> && ...` compounds; this avoids the stale agent-context lifecycle leak described in `[[feedback_codex_dispatch_lifecycle_leak]]`.
- No inline `-- <brief>` form; always dispatch a file-backed brief.
- Use `run_in_background: true` on the main-thread Bash call so the main thread can continue and receive the completion notification later.

Completion-parse procedure:

1. When the completion notification arrives, read `BashOutput(bash_id: <id>)` to get the full merged stdout and stderr captured by the harness.
2. Parse the stable stdout footer emitted by `scripts/codex-dispatch.sh:203-207`: `trace:`, `last:`, `stderr:`, and `exit:` between `---` separators.
3. Use `scripts/codex-dispatch.sh:142-154` to recognize the start banner in stderr: cwd, model, sandbox, approval, timeout, trace, and brief.
4. Use `scripts/codex-dispatch.sh:196-199` to recognize the finish banner and the optional timeout note.
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
~/github/pm-dispatch/scripts/codex-dispatch.sh --cd <abs path> --sandbox workspace-write --approval never --brief-file /tmp/brief-<task>.md
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

## Style notes

- Prose is fine; YAML-like keys above are conventions, not strict syntax. Keep real dispatches file-backed via `--brief-file`.
- Keep briefs in the active voice ("Audit X", not "X should be audited"). Codex parses imperatives more reliably than declaratives.
- Don't write implementation steps. The brief tells Codex *what* and *what counts as done*; *how* is Codex's job.

## Trial dispatch end-to-end recipe

Use this smoke recipe after changing dispatch policy. It should complete without modifying the repo.

Minimal no-op brief body:

```yaml
working_dir: /home/screenleon/github/pm-dispatch
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
Bash(command: "bash /home/screenleon/github/pm-dispatch/scripts/codex-dispatch.sh --cd /home/screenleon/github/pm-dispatch --sandbox workspace-write --approval never --timeout 1200 --brief-file /tmp/brief-pm-dispatch-cc036-smoke-<utc-ts>-<rand>.md", run_in_background: true, description: "Dispatch codex for cc036-smoke")
```

Expected sequence:

1. Harness returns a background Bash task id.
2. Completion notification arrives.
3. Main thread reads `BashOutput(bash_id: <id>)`.
4. Footer parse finds `trace:`, `last:`, `stderr:`, and `exit:` from `scripts/codex-dispatch.sh:203-207`.
5. Main thread reads `<last>` and `<stderr>`, ignoring only the standard start banner from `scripts/codex-dispatch.sh:142-154` and finish banner from `scripts/codex-dispatch.sh:196-199`.
6. Main thread runs `git -C /home/screenleon/github/pm-dispatch status --short` and confirms no unexpected changes.
7. `routing_log.md` receives one route-agnostic dispatch row from the PostToolUse hook; the future CC-036b schema extension may add `dispatch_route` after two weeks of telemetry.
