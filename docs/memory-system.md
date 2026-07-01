# Memory system

For personal forks, memory is the persistence layer that lets PM and Codex sessions keep continuity across time without overloading token budgets.

See [`CONCEPTS.md`](CONCEPTS.md) for the full conceptual framing.

## Why memory exists

Claude Code sessions are stateless by design, and this repo relies on memory files to avoid forgetting owner-specific preferences and repo-specific conventions. Memory exists to make behavior stable across reboots, reduce repeated clarification, and keep memory recall targeted to actual signal.

## On-disk layout

By default, all fork and runtime state lives under:

`~/.claude/projects/<id>/memory/`

This default is overridable — see [Cross-tool portability](#cross-tool-portability) below.

Typical files are:

```
MEMORY.md
feedback_*.md
project_*.md
reference_*.md
user_*.md
episodes.jsonl
```

`<id>` is the project identifier derived from the sanitized absolute path of the checked-out project root.

## MEMORY.md as the inject index

`MEMORY.md` is loaded into context automatically for applicable sessions. Keep it as the index only:

- short bullet list entries (`- [Title](file.md) — hook text`)
- concise link text and hook lines
- frontmatter-rich detail in the referenced files

The runtime flow is simple: one always-loaded entry file (`MEMORY.md`) plus optional reads from its linked cards.

## Four card tiers

The curated cards are split by purpose so the index can stay compact and the loader can fetch depth only when needed.

| Pattern | Tier purpose | Scope |
|---|---|---|
| `feedback_*.md` | Durable feedback memory | Explicit preferences, constraints, and repeated user or reviewer guidance |
| `project_*.md` | Durable project memory | Architecture, flow definitions, PM decisions, and repo-specific invariants |
| `reference_*.md` | Durable reference memory | Stable references for command usage, scripts, and external expectations |
| `user_*.md` | Durable user memory | Personal workflow preferences and maintainable guardrail notes for the maintainer |

`episodes.jsonl` remains the episodic layer (append-only session summaries) and feeds `/mem-recall` and `/mem-distill` when needed.

## Card frontmatter schema

Card frontmatter is **additive**. The legacy block — `name`, `description`, and
the `metadata:` map (`node_type`, `type`, `originSessionId`) — is preserved
byte-for-byte; the standardized fields append as **top-level YAML after the
`metadata:` block**. The `metadata:` block must never be removed or renamed: the
external memory-graph tool keys off `metadata.node_type`/`type`, and
`/memory-compress` reads `metadata.type` for merge-by-tier.

| Field | Type | Notes |
|---|---|---|
| `topics` | list<str> | retrieval/trust ranking facets (consumed by `pmctl context --source memory`) |
| `priority` | enum | exactly one of `always` / `normal` / `low` |
| `status` | str | lifecycle, e.g. `active` |
| `updated_at` | str | `"YYYY-MM-DD"` |
| `expires_at` | str | optional expiry date |
| `repo_refs` | list<str> | machine-checkable refs (may be empty `[]`) — see grammar below |

Example (additive — legacy block unchanged):

```yaml
---
name: development-workflow
description: …
metadata:
  node_type: memory
  type: feedback
  originSessionId: …
topics:
  - workflow
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs:
  - flag:pmctl gate run --executor codex
---
```

### `repo_refs` grammar

Each ref is a machine-checkable pointer so the health check can detect staleness.

| Kind | Syntax | Fresh when |
|---|---|---|
| file | `path:<repo-root-relative>` (no leading `/`) | `test -f "$REPO_ROOT/<path>"` |
| symbol | `fn:<rel-path>#<symbol>` | file exists AND a shell def `^<symbol>()` / `^function <symbol>` is found |
| flag | `flag:<invocation> <--flag-token>` | the `--token` is found under `scripts/` |

A ref that fails its check is **stale** and surfaces in `pmctl memory doctor`.
An out-of-grammar ref is also reported stale rather than silently fresh: a
`path:`/`fn:` path that is absolute or contains a `..` segment (it must stay
repo-root-relative), or an `fn:` symbol that is not a shell identifier. `repo_refs`
accepts both block-style (one `- ` item per line) and flow-style (`[a, b]`) YAML
lists; the doctor parses and staleness-checks both.

## Health check: `pmctl memory doctor`

`pmctl memory doctor` is a **read-only** reporter over the memory dir — it
mutates nothing. Write-time enforcement is already live: `/mem-distill` and
`/memory-compress` both block a write when a card is missing a required field.

```sh
pmctl memory doctor [--json] [--repo-root <path>]
```

Report fields (ordered): `memory_dir`, `entry_count`, `memory_bytes`,
`episodes_bytes` (0 if absent), `shard_count`, `dead_links` (MEMORY.md link → missing file),
`orphan_cards` (card present but unreferenced, MEMORY.md excluded),
`duplicate_hooks` (hook text on ≥2 index lines), `stale_repo_refs`
(`{card, ref}` per the grammar above), `cards_missing_fields`
(`{card, missing: [...]}` for any card lacking a required field —
`topics`/`priority`/`status`/`updated_at`/`repo_refs`; `repo_refs` may be `[]`
but the key must exist), `issues_count`. `--json` emits a single object carrying
`schema_version: 1`. Exit codes: `0` healthy, `1` issues found, `2` usage error.

`cards_missing_fields` lists any not-yet-migrated card still lacking a required
field — useful for spot-checking coverage even though write-time enforcement is
already active.

## Bootstrap-empty pattern for fork users

Fork users can start with no cards and still keep the setup stable:

1. Create the memory directory path only:

```sh
mkdir -p "$HOME/.claude/projects/<id>/memory"
```

2. Add a minimal `MEMORY.md` seed:

```text
# Memory

This is a fork-owned inject file.
```

3. Use `/mem-log` at the end of a useful session to build the first episodic entries.

4. Promote recurring session facts with `/mem-distill` when the first durable rules appear.

This keeps bootstrap lightweight and avoids carrying stale upstream defaults into a private adaptation.

## Private-repo symlink pattern (optional)

If you want durable memory cards to stay outside this public repo, you may symlink the memory directory to a separate private repository and keep this repo as launcher-only state.

Use this pattern when:

- you want memory cards to be version-controlled privately,
- your private note history should evolve independently from public installer scaffolding,
- you want to share installer behavior without sharing personal memory snapshots.

The key behavior stays unchanged: hooks still target `~/.claude/projects/<id>/memory/`, while that path can be backed by a private location maintained in your fork workflow.

## Cross-tool portability

Memory cards, `pmctl memory doctor`, and `pmctl context --source memory` are
already tool-neutral: cards are plain Markdown+YAML, and retrieval goes
through `pmctl`, not a Claude-specific format. The two remaining Claude-only
pieces are the memory directory's default *location* and its *injection*
mechanism — both now have an explicit seam so other tools (codex, opencode,
future hosts) can share the same memory without depending on Claude Code.

**Location seam**: the memory-dir resolver (`find_memory_dir`) honors an
explicit override, checked in this order:

1. `PM_MEMORY_DIR` environment variable (highest priority; works everywhere,
   including the Claude Code hook path, at zero extra cost)
2. `dispatch.memory_dir` in `~/.pm-dispatch/config` (checked by CLI-driven
   callers — `pmctl memory *`, `pmctl context --source memory`,
   installer/migrator scripts — not by the hook path, to avoid adding a
   config-file read to every Claude Code turn)
3. the `CLAUDE_CONFIG_DIR/projects/<id>/memory/` convention (unchanged
   default when neither override is set)

An override is only honored when the target directory already exists; an
unset or nonexistent override falls through to the next tier, so existing
installs see byte-identical resolution with no environment changes.

**Injection is a per-tool adapter, not part of the portable core.** The
portable core is the retrieval API: `pmctl context --source memory` (and
`pmctl memory doctor` for health checks). Claude Code's `UserPromptSubmit`
hook (`guard-inject-memory.sh`) is one adapter that calls into this core
automatically every turn. A tool without an equivalent hook (codex, opencode)
gets the same memory by calling `pmctl context --source memory` directly —
there is no requirement to replicate Claude's hook-based injection timing.

## Practical conventions

- Keep `MEMORY.md` short and high-signal.
- Put permanence into card files (`feedback_`, `project_`, `reference_`, `user_`).
- Use `/memory-compress` after heavy memory growth.
- Run `/mem-recall` for session continuity before a major `/pm` batch.
- Keep `episodes.jsonl` append-only for auditability.


## Runtime conventions

1. Keep the index (`MEMORY.md`) deterministic: one purpose per entry, one sentence per hook.
2. Prefer edits through slash-command flows so changes stay within the declared scope.
3. Treat `/mem-distill` output as a proposal until reviewed; write only when confirmed.
4. Keep stale entries visible until manually archived to avoid accidental loss of context.
5. Let a fork owner keep this document as a local contract and update it with their own private conventions over time.
