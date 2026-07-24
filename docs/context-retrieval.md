# Context retrieval

## Query before Read/Grep/full-file open

For knowledge-doc lookups, retrieval comes first. Run the context query before
any Read, Grep, or full-file open:

    pmctl context query <repo_root> --domain knowledge <term>

This returns heading-anchored hits with line numbers. Paste the ref directly
into a brief's context block instead of re-deriving the background. Fall back to
targeted Read/Grep only when the query returns no hits.

For code symbols, omit --domain or use --domain repo:

    pmctl context query <repo_root> <symbol-name>

`<repo_root>` is optional — when omitted (or the first argument isn't a
directory), the query defaults to the **git toplevel of the current working
directory**, so running these commands from inside your target project
resolves correctly without naming it explicitly. Only when the CWD is not
inside any git worktree does it fall back to `pmctl`'s own `REPO_ROOT` (the
pm-dispatch install repo), printing a one-line stderr warning when it does.
When scripting or dispatching from an unknown CWD, pass `<repo_root>`
explicitly to be unambiguous.

For a read-only diagnosis of that resolution, the canonical DB path, sqlite
capability, and whether files have been added/changed/deleted since indexing:

    pmctl context status [<repo_root>]
    pmctl context status [<repo_root>] --json

`status` never creates or refreshes a DB. The repo-plane DB is always
`<repo_root>/.pm-dispatch/ctx/context.db`; `.pm-dispatch/` is excluded from
index discovery and is added to `.gitignore` when the first DB is built.

## Source planes — repo and memory

`--source` selects which **index plane** is searched and is orthogonal to
`--domain` (which classifies paths *within* the repo plane):

| `--source` | Searches                                                                 |
|------------|--------------------------------------------------------------------------|
| `repo`     | The repo index (default). Behaviour is unchanged from before this flag.   |
| `memory`   | The project-memory plane — cards, `MEMORY.md`, and `episodes.jsonl` under `~/.claude/projects/<id>/memory/`. |
| `all`      | Repo **and** memory hits, merged.                                        |

    pmctl context query <repo_root> --source memory <term>      # decisions / rules / preferences
    pmctl context query <repo_root> --source all <term>          # repo + memory

Memory hits carry `source_domain: memory` and a trust tier: curated cards and
`MEMORY.md` rank `high`, raw `episodes.jsonl` ranks `medium`. `--domain` is a
repo-plane path classifier and is **only valid with `--source repo`** — pairing
it with `memory`/`all` is rejected.

`reuse-scan` stays **repo-only by construction** (it surfaces reusable repo
prior-art for executors; memory decisions/preferences would crowd out real
helpers) and has no `--source` flag.

`pmctl context pack --source memory|all` populates the pack's `memories[]` array
**pointer-only**: the ref and trust tier travel, never the matched card body —
private memory must not be copied into a repo-bound (and possibly archived) pack.

## Prior-art scan before authoring a brief

Before writing the `files:` / `context:` sections of a dispatch brief, run a
repo-plane prior-art scan to surface existing code that the executor should
reuse rather than rewrite:

    pmctl context reuse-scan [<repo_root>] "<task description>"

This extracts search terms from the description, queries the repo index, and
emits a `reuse_candidates:` YAML block.  Paste at most **5 candidates** into
the brief's `context:` block after manual review — stop-word noise in
unfiltered output inflates executor token cost without adding signal.

For a targeted multi-term query (when key symbol names are already known), use
`context pack` instead:

    pmctl context pack [<repo_root>] --task-id <id> --query <term> [--query <term> ...]

`pmctl context reuse-scan` emits a `context.reuse_scanned` event and
`pmctl context query` emits a `context.queried` event after **every** call —
including calls that find no hits and calls against a repo with no index yet
(emitted with `hits: 0`).  These are readable via
`pmctl trace tail --kind context.reuse_scanned` (or `--kind context.queried`).
`pmctl context pack` does not emit usage events.

## Prompt auto-scan (deterministic retrieval at prompt time)

The query-before-Read discipline above is a prose rule, and prose rules degrade
exactly when a session is busy. The prompt auto-scan makes the knowledge-doc
half of that rule deterministic: a `UserPromptSubmit` hook
(`hosts/claude/hooks/inject-context.sh`, wired by `install-guards.sh`) runs

    pmctl context prompt-scan [<repo_root>] "<prompt text>"

against the git toplevel of the session's working directory on every prompt.
`prompt-scan` extracts search terms from the prompt (longest-first, capped at
`PM_DISPATCH_PROMPT_SCAN_MAX_TERMS`, default 8), queries the repo plane with
`--domain knowledge`, and emits a pointer-only `knowledge_hits:` YAML block of
up to 5 deduped hits. When the scan finds hits, the hook injects them as an
`=== auto-context ===` block; zero hits stay silent. The agent starts the turn
with heading-anchored refs already in context — citing them replaces the
full-file Read it would otherwise reach for.

The hook never fails a prompt: every failure path (no git repo, no prompt text,
scan error, timeout) exits 0 silently. Context indexing is capability-gated:
when `sqlite3` is absent the hook skips pmctl entirely; when it is available,
the first eligible prompt automatically builds the repo-local DB. Initial builds
have a 120-second budget (`PM_DISPATCH_PROMPT_CONTEXT_INITIAL_TIMEOUT`), while
incremental refreshes use 45 seconds (`PM_DISPATCH_PROMPT_CONTEXT_TIMEOUT`). A
Claude install explicitly gives this handler 150 seconds, leaving cleanup time
outside the largest internal budget instead of inheriting Claude Code's shorter
`UserPromptSubmit` default. Re-running the installer upgrades an older managed
hook in place. A timed-out first build removes only its incomplete derived DB so
the next prompt can retry with the initial-build budget; a schema-only DB with
zero committed file rows is also treated as an interrupted initial build.
Unchanged refreshes preserve the FTS table instead of rebuilding it, keeping the
normal prompt path short. `doctor.sh` reports a managed context hook whose
handler timeout is absent or below this envelope.

Set `PM_DISPATCH_DISABLE_PROMPT_CONTEXT=1` to disable the scan entirely. Use
this whenever the live context DB must not be touched — for example while the
full test suite is running against the pm-dispatch repo itself.

The same optional repo-context refresh is used at pmctl-owned workflow
boundaries: `pmctl pm prepare` reports it as `repo_context`, and `pmctl gate
run` refreshes the effective `--cd` repository before dispatch. Missing
`sqlite3` is an explicit `unavailable` capability state and does not fail PM
preparation, prompt submission, or a gate. This wiring does not make context,
PM preparation, testing, or PR-gate mandatory for tool users; each surface can
still be invoked independently.

`pmctl context prompt-scan` emits a `context.prompt_scanned` event after every
call (including zero-hit, no-index, and no-sqlite calls — the last two degrade
to an empty `knowledge_hits: []` scan rather than erroring, because the caller
is an automated hook), readable via
`pmctl trace tail --kind context.prompt_scanned`. The kind is deliberately
distinct from `context.queried`: automated prompt-time scans must not pollute
the telemetry signal for whether an agent ran a query on its own.

**Privacy (load-bearing)**: the event's `query` payload field is always
**empty** for prompt scans — neither the raw prompt nor derived search terms
are persisted, because even a derived term can reproduce a secret-shaped token
verbatim. Prompts arrive from an automated hook and can carry secrets or PII;
nothing prompt-derived may reach the durable state store. Only the hit count
is recorded.

**Scrub procedure**: if a pre-fix build ever persisted prompt-derived content,
remove those events by filtering the state store's `events.jsonl` (under the
pmctl install partition, honoring `PM_DISPATCH_STATE_ROOT`):

    jq -c 'select(.kind != "context.prompt_scanned")' events.jsonl > events.jsonl.scrubbed
    mv events.jsonl.scrubbed events.jsonl

Rotated archives (`archive/events-*.jsonl.gz`) need the same filter after
decompression.

`PM_DISPATCH_PROMPT_CONTEXT_PMCTL` overrides the `pmctl` entrypoint the hook
invokes (non-standard install layouts; also the regression-test seam for the
timeout path).

## Dispatch auto-pack

`pmctl dispatch run` runs a deterministic prior-art packing step. Auto-pack is
**on by default** (the built-in `dispatch.auto_pack` default is `on`):

    pmctl dispatch run --adapter <executor> --cd <repo-root> --brief-file <brief>

Use `--no-auto-pack` to opt out for one dispatch (or set `dispatch.auto_pack =
off`); `--auto-pack` forces it on where a config disabled it. Precedence is
flag > config > built-in default (on).

When auto-pack is on, dispatch extracts the brief `goal`, runs
`pmctl context reuse-scan` against the work repo, and produces an augmented brief
copy (the original brief plus an appended `auto_context:` block of up to 5
pointer-only candidates) at:

    <repo-root>/.pm-dispatch/ctx/packs/<run_id>.md

In BOTH lifecycles the augmented brief is landed at the guardable
`/tmp/brief-<run_id>.md` path and used as the single brief that is guarded,
validated, executed, post-verified, and recorded. Under `--lifecycle foreground`
dispatch snapshots the pack there before guarding and forwarding it; under the
default `detached` lifecycle the snapshot is recorded as the run-spec's trusted
`brief_file` and the supervisor validates, guards, and executes exactly that
brief — so the single guarded == validated == executed brief invariant holds
identically in both lifecycles. The authored brief file stays unchanged. If reuse-scan,
pack creation, or validation fails, dispatch warns on stderr and continues with
the original brief and the same exit semantics.

Because auto-pack supplies retrieval evidence (the `auto_context:` block) only
when reuse-scan finds hits, a file-writing brief with **zero** reuse hits and no
hand-authored `context:` / `retrieval_skip_reason:` is still rejected under the
default `BRIEF_VALIDATE_RETRIEVAL=fail` — auto-pack does not stamp empty evidence.

Every dispatch with auto-pack enabled records a `context.auto_packed` event,
including zero-hit and fail-open cases. Inspect it with:

    pmctl trace tail --kind context.auto_packed

Use `--json` to read the payload fields: `run_id`, `hits`, `pack`, and
`source_brief`.

## Context DB location

The context index is **always** written to `<repo-root>/.pm-dispatch/ctx/context.db`
(repo-local).  This path
is fixed per repo and is **not** affected by `PM_DISPATCH_STATE_ROOT` — the
database is a derived per-repo cache, so it lives next to the code it indexes.
The `.pm-dispatch/` directory is added to `.gitignore` automatically so the
database is never committed. The context file discovery walk also excludes the
entire `.pm-dispatch/` tree; the DB, WAL files, generated packs, gate artifacts,
and other derived pm-dispatch state can therefore never feed back into the
repo's own context index.

Auto-pack files are written under the same repo-local context directory at
`<repo-root>/.pm-dispatch/ctx/packs/<run_id>.md`; they are derived dispatch
artifacts and are not committed.

The **memory** plane has a separate, out-of-repo DB at
`<memory-dir>/.pm-dispatch/context.db` (where `<memory-dir>` is the
`find_memory_dir`-resolved `~/.claude/projects/<id>/memory/`). This is a
load-bearing privacy boundary: the memory index lives beside the cards it is
built from and is **never** written into the repo checkout — even a gitignored
repo-local copy could be carried out by tooling or an archive. Memory honours the
same `PM_DISPATCH_CONTEXT_AUTOBUILD` / `AUTOREFRESH` env vars and degrades to
`# no hits` when no memory directory exists for the working dir.

`pmctl context query`, `pmctl context pack`, and `pmctl context reuse-scan` are
self-sufficient readers: if the repo-local DB is missing and `sqlite3` is
available, they build it before reading.  If the DB already exists, they run the
same mtime-based incremental index pass first, so changed files are reflected
without a manual `pmctl context index` or `pmctl context update`.

Set `PM_DISPATCH_CONTEXT_AUTOBUILD=0` to keep a missing DB as a graceful empty
read (`# no hits`, empty pack JSON, or empty `reuse_candidates:`).  Set
`PM_DISPATCH_CONTEXT_AUTOREFRESH=0` to skip the incremental refresh when a DB
already exists.

`PM_DISPATCH_STATE_ROOT` governs only the **state partition** (tasks, reviews,
decisions, events) written by the state-writer — not the context DB.  Context
*usage telemetry* (the `context.queried` / `context.reuse_scanned` events you
can read via `pmctl trace`) is the one part of `pmctl context` that the
state-writer records.  Those events are keyed to the pmctl **installation
repo** partition (so `pmctl trace` shows context usage aggregated across every
repo pmctl indexes, no matter which repo you run the query from), but they live
under whatever store root `PM_DISPATCH_STATE_ROOT` selects — like every other
state write, the telemetry follows a redirected store root rather than forcing
the default location.

## Domain values

| Domain      | Classification rule                                                    |
|-------------|------------------------------------------------------------------------|
| `knowledge` | BACKLOG.md, DECISIONS.md, MILESTONES.md, or any file under `docs/`    |
| `repo`      | All other files                                                        |

Note: domain classification is path-based. Only extensions in the `pmctl context index`
scan list (.sh, .go, .py, .ts/.tsx, .js/.jsx, .md, .yaml/yml, .json, .txt) are indexed.
HTML files are not currently scanned; HTML semantic chunking is deferred to a later ticket.

## Success metric

Not query-count > 0. A later brief cites knowledge-doc anchors or repo-plane
reuse candidates directly from query output instead of the PM re-deriving
context from memory or a full-file read. The number of times each tool was
called is observable via `pmctl trace tail --kind context.queried`,
`pmctl trace tail --kind context.reuse_scanned`, and
`pmctl trace tail --kind context.prompt_scanned` (automated prompt auto-scans;
kept as a separate kind so they never inflate the manual-query signal).
