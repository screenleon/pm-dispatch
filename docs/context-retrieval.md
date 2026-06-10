# Context retrieval

## Query before grep

Before opening a large knowledge doc to search for a ticket or decision, run:

    pmctl context query --domain knowledge <term>

This returns heading-anchored hits with line numbers. Paste the ref directly
into a brief's context block instead of re-deriving the background.

For code symbols, omit --domain or use --domain repo:

    pmctl context query <symbol-name>

## Domain values

| Domain      | Paths indexed                                              |
|-------------|------------------------------------------------------------|
| `knowledge` | BACKLOG.md, DECISIONS.md, MILESTONES.md, docs/* (any ext) |
| `repo`      | All other files (shell, Go, Python, TS/JS, JSON, YAML)    |

## Success metric

Not query-count > 0. A later brief cites knowledge-doc anchors with heading
and line number directly from query output instead of the PM re-deriving context
from memory or a full-file read.
