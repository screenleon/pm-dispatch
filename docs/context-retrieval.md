# Context retrieval

## Query before grep

Before opening a large knowledge doc to search for a ticket or decision, run:

    pmctl context query --domain knowledge <term>

This returns heading-anchored hits with line numbers. Paste the ref directly
into a brief's context block instead of re-deriving the background.

For code symbols, omit --domain or use --domain repo:

    pmctl context query <symbol-name>

## Domain values

| Domain      | Classification rule                                                    |
|-------------|------------------------------------------------------------------------|
| `knowledge` | BACKLOG.md, DECISIONS.md, MILESTONES.md, or any file under `docs/`    |
| `repo`      | All other files                                                        |

Note: domain classification is path-based. Only extensions in the `pmctl context index`
scan list (.sh, .go, .py, .ts/.tsx, .js/.jsx, .md, .yaml/yml, .json, .txt) are indexed.
HTML files are not currently scanned; HTML semantic chunking is deferred to a later ticket.

## Success metric

Not query-count > 0. A later brief cites knowledge-doc anchors with heading
and line number directly from query output instead of the PM re-deriving context
from memory or a full-file read.
