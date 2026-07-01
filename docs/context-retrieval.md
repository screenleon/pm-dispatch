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

`<repo_root>` must be an explicit directory argument — if the first argument
isn't a directory, the query falls back to `pmctl`'s own `REPO_ROOT` (the
pm-dispatch install repo), not your target project.

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
database is never committed.

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
called is observable via `pmctl trace tail --kind context.queried` and
`pmctl trace tail --kind context.reuse_scanned`.
