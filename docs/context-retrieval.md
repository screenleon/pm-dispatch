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
`pmctl context query` emits a `context.queried` event after each call.
These are readable via `pmctl trace tail --kind context.reuse_scanned` (or
`--kind context.queried`).  `pmctl context pack` does not emit usage events.

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
