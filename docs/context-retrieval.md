# Context retrieval

## Query before grep

Before opening a large knowledge doc to search for a ticket or decision, run:

    pmctl context query --domain knowledge <term>

This returns heading-anchored hits with line numbers. Paste the ref directly
into a brief's context block instead of re-deriving the background.

For code symbols, omit --domain or use --domain repo:

    pmctl context query <symbol-name>

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

## Dispatch auto-pack

`pmctl dispatch run` can opt in to a deterministic prior-art packing step:

    pmctl dispatch run --adapter <executor> --cd <repo-root> --brief-file <brief> --auto-pack

The equivalent config default is:

    dispatch.auto_pack = on

Use `--no-auto-pack` to override a config default for one dispatch. Auto-pack is
off by default.

When auto-pack is on, dispatch extracts the brief `goal`, runs
`pmctl context reuse-scan` against the work repo, and forwards the executor an
augmented brief copy at:

    <repo-root>/.pm-dispatch/ctx/packs/<run_id>.md

The copy contains the original brief plus an appended `auto_context:` block with
up to 5 pointer-only candidates. The authored brief file stays unchanged. If
reuse-scan, pack creation, or validation fails, dispatch warns on stderr and
continues with the original brief and the same exit semantics.

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
database is never committed.

Auto-pack files are written under the same repo-local context directory at
`<repo-root>/.pm-dispatch/ctx/packs/<run_id>.md`; they are derived dispatch
artifacts and are not committed.

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
called is observable via `pmctl trace tail --kind context.queried` and
`pmctl trace tail --kind context.reuse_scanned`.
