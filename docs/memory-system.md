# Memory system

For personal forks, memory is the persistence layer that lets PM and Codex sessions keep continuity across time without overloading token budgets.

See [`docs/CONCEPTS.md`](docs/CONCEPTS.md) for the full conceptual framing.

## Why memory exists

Claude Code sessions are stateless by design, and this repo relies on memory files to avoid forgetting owner-specific preferences and repo-specific conventions. Memory exists to make behavior stable across reboots, reduce repeated clarification, and keep memory recall targeted to actual signal.

## On-disk layout

All fork and runtime state lives under:

`~/.claude/projects/<id>/memory/`

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
