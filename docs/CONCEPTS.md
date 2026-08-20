# Concepts

This document explains the four Claude Code extensibility primitives that `pm-dispatch` builds on. If you've used Claude Code conversationally but never written a hook or an agent, this is the right place to start.

## TL;DR

Claude Code gives you a chat interface plus four extensibility surfaces:

| Surface | What it is | Where it lives |
|---|---|---|
| **Hooks** | Shell commands the harness runs around every tool call | `settings.json` + `scripts/guard-*.sh` |
| **Slash commands** | User-invokable prompts (a.k.a. "skills") | `commands/*.md` |
| **Subagents** | Specialised Claude sessions with their own tools and prompts | `agents/*.md` |
| **Memory** | Files Claude reads at session start and writes to over time | `~/.claude/projects/<id>/memory/` |

`pm-dispatch` is one opinionated way to combine those four into a project-management workflow. Every other directory in this repo (scripts, docs, install) exists to support those four pieces.

If you've used Claude Code without touching any of these, you have implicitly used the **defaults**. This repo is what happens when you take the defaults seriously and start writing your own.

---

## Concept 1 — Hooks-as-policy

### The Claude Code primitive

A **hook** is a shell command the Claude Code harness runs at well-defined points in the loop: before a tool runs (`PreToolUse`), after a tool returns (`PostToolUse`), when a session starts (`SessionStart`), when it stops (`SessionStop`), and a few others. Hooks are configured in `~/.claude/settings.json` or `.claude/settings.local.json`. Each hook is just a shell script that reads JSON from stdin and exits 0 (allow), 1 (deny), or writes JSON back to influence the harness.

The Claude Code docs cover the schema; this document is about *how* `pm-dispatch` uses them.

### The pattern: "hooks-as-policy"

Most users think of hooks as "automation" — *do X every time Y happens*. `pm-dispatch` uses them as **policy**: rules that fail loudly when something is about to violate a design invariant. The hook is not a helper; it is a guardrail.

Two examples:

- **`guard-pm-write.sh`** — blocks the `project-pm` subagent from writing to anywhere except the memory directory and a small allowlist. The PM agent is supposed to plan and write briefs, not edit production code. If a PM session tries to `Write(src/api.go)`, the hook denies the call and the user sees why. Without the hook this is a strong suggestion in the prompt; with the hook it is structural.

The general shape is: identify a recurring "you should not have done that" moment in your workflow, write the rule once as a hook, and the harness enforces it forever after. The cost of writing the hook is paid once; the policy then applies to every future session, including the ones you don't remember.

### Why this matters

A prompt rule lives in one agent's context window. A hook lives in the harness. If three agents could in principle make the same mistake, you write one hook instead of three prompt rules and you get the rule back even after a context compaction.

The trade-off is that hooks are shell, not English. They are harder to write and harder to test. `tests/shell/test-guards.sh` is how this repo keeps them honest — every hook has at least one test case that drives a JSON fixture and asserts the exit code and stderr shape.

### Where to look

- `scripts/guard-*.sh` — every guard policy script in this repo
- `tests/shell/test-guards.sh` — the test harness for them
- `~/.claude/settings.json` after `bash install.sh` — the registration

---

## Concept 2 — Slash commands (skills)

### The Claude Code primitive

A **slash command** is a markdown file in `commands/` (or `~/.claude/commands/`) with YAML frontmatter and a body. When the user types `/foo`, Claude Code reads `commands/foo.md`, treats the body as a system-level instruction, and includes it in the next turn. The frontmatter contains `description:` (shown in the slash menu) and `argument-hint:` (the literal hint shown next to the command name).

You can think of it as a saved prompt with a name.

### The pattern in this repo

`pm-dispatch` uses slash commands as **named workflows**. Each one names a thing the user does often enough to deserve a verb:

- `/pm` — "route this request through the project-pm subagent"
- `/pr-gate` — "run the multi-reviewer review pipeline on the current branch"
- `/mem-recall` — "load the last few session summaries into context"
- `/skill-refine` — "scan feedback memory about this skill and propose edits to its definition"

The body of the markdown is the *contract*: what should happen when this command fires. It usually delegates the heavy lifting to a shell script in `scripts/` and tells the main thread how to interpret the output.

### Why slash commands, not prompts

If you find yourself typing the same multi-line instruction twice, that's a candidate for a slash command. The first time you write the command you pay a small cost for the markdown file; every later invocation costs one keystroke (`/`) and the command list.

Slash commands also become an artifact you can review. A reusable workflow that lives only in your head will drift; a slash command that lives in a markdown file gets `git log`, gets reviewed, and gets refined.

### Where to look

- `commands/*.md` — every slash command shipped here
- `tools/skills/skill-refine.sh` — example of a script that supports a slash command (`/skill-refine`)

---

## Concept 3 — Subagents

### The Claude Code primitive

A **subagent** is a separate Claude session spawned by the main session. The main thread calls `Agent(subagent_type="…", prompt="…")` and gets back one final message. The subagent has its own context window, its own tool allowlist (declared in `agents/<name>.md` frontmatter), and its own system prompt.

Subagents can do things the main thread shouldn't have to do: long research, opinion-forming, deep tool sequences. Their finite return shape (one message) is the contract.

### The pattern in this repo

`pm-dispatch` uses subagents for two purposes:

1. **Specialised roles.** `agents/project-pm.md` is a planner. `agents/critic.md`, `agents/qa-tester.md`, `agents/security-reviewer.md`, `agents/risk-reviewer.md`, `agents/architecture-reviewer.md` are five reviewers, each with a different lens. Each has a tight tool allowlist (e.g. the security-reviewer has read tools only) so the role enforces itself. Executors are not subagents — they run as independent CLI subprocesses driven by `pmctl dispatch run --adapter <name>` (see `adapters/`).

2. **Context isolation.** A long PR review can produce thousands of tokens of intermediate analysis. If the main thread did that work, every later turn would carry it. A subagent returns one summary message, leaving the main thread context lean.

### Two rules subagents always obey

- **A subagent cannot spawn another subagent.** Claude Code prevents nested `Agent` calls. The main thread is the only orchestrator. If you want a pipeline of three reviewers, the *main thread* invokes them; the reviewers don't invoke each other.

- **A subagent's Bash calls cannot reliably run in the background.** The harness can kill the subagent process when its `Agent` call returns, taking the background process with it. The fix in this repo is to run long Bash from the main thread instead — see `commands/pr-gate.md` for how `/pr-gate` runs its long-running review pipeline from the main thread with `run_in_background: true`.

These two rules shape how every workflow in this repo is wired. The main thread is not just an orchestrator by convention — it's the orchestrator by structural necessity.

### Where to look

- `agents/*.md` — every subagent definition (one markdown per role)
- `commands/pm.md` — how the main thread invokes the `project-pm` subagent
- `runtime/bin/pr-gate.sh` — how the main thread dispatches review as an independent executor subprocess (`pmctl gate run`), not an in-session subagent fan-out

---

## Concept 4 — Memory tiers

### The Claude Code primitive

Claude Code lets a session save files to a per-project memory directory at `~/.claude/projects/<project-id>/memory/`. A `MEMORY.md` file in that directory is loaded into every session as a context inject. Other files in the directory are *referenced* from `MEMORY.md` and read on demand.

That's all Claude Code provides. The structure on top is up to you.

### The pattern in this repo

`pm-dispatch` divides memory into three tiers by purpose:

| Tier | File pattern | Purpose | Lifetime |
|---|---|---|---|
| **Auto-injected index** | `MEMORY.md` | One-line entries pointing at full memory files | Always loaded |
| **Curated cards** | `feedback_*.md`, `project_*.md`, `reference_*.md`, `user_*.md` | Durable rules, project state, references | Long |
| **Episodic** | `episodes.jsonl` | Per-session summaries appended at SessionStop | Append-only |

A typical user-facing fact ("I prefer terse responses with no trailing summary") lives as a feedback card. A long-lived project fact ("this repo's PR-gate dispatches an independent reviewer subprocess") lives as a project card. A historical moment ("yesterday's session shipped the new release checklist") lives as an episode.

The point of the tiering is **token budget**. The index is always loaded; the cards are loaded on demand by `MEMORY.md` links; the episodes are loaded only when `/mem-recall` is invoked. Without this split, either you load nothing (no continuity) or you load everything (every session pays for every memory).

### How memory gets written

- **Auto** — the `mem-distill` skill scans recent episodes and proposes updates to `MEMORY.md` and curated cards. The main thread runs it after sessions that produced new rules.
- **By hand** — the user (or Claude on the user's behalf) writes a card directly when a moment is worth remembering.
- **By hook** — `SessionStop` writes a one-line episode to `episodes.jsonl` with metadata about what happened in the session.

This three-way write path is on purpose: not every fact wants the same author.

### Where to look

- `MEMORY.md` — the index for the current session
- `commands/mem-recall.md` / `mem-log.md` / `mem-distill.md` / `mem-search.md` — the four memory skills; `/mem-log` is the sole episode writer

---

## How they fit together — a worked example

Suppose you ask Claude: *"please plan the next milestone for project X."*

1. **Slash command.** You type `/pm please plan the next milestone for project X`. Claude Code looks up `commands/pm.md` and follows its body: invoke the `project-pm` subagent with the user request, the current working directory, and any context the main thread has that the subagent won't see.

2. **Subagent.** The main thread calls `Agent(subagent_type="project-pm", prompt="…")`. A fresh Claude session opens. Its tool allowlist (declared in `agents/project-pm.md`) gives it Read/Write/Edit/Bash/Glob/Grep — enough to read code, edit briefs, and grep the backlog. No tools that could write to production code, because of the next item.

3. **Hook.** When the PM subagent tries to `Write(src/some-file.go)`, the `guard-pm-write.sh` hook fires in `PreToolUse`. It reads the JSON, sees the target is outside the memory/brief allowlist, and exits non-zero. The harness denies the tool call and tells the agent why. The PM cannot accidentally edit production code; the rule is structural.

4. **Memory.** When the PM starts thinking, the `MEMORY.md` injected into its context tells it that the user prefers terse responses, that the project is mid-refactor, and that a similar question was asked yesterday. The PM doesn't ask the user to re-explain.

5. **Return.** The PM produces one final message: a phased plan with one immediate next-step brief. That message goes back to the main thread. Nothing else carries over.

6. **Episode.** When the session ends, the `SessionStop` hook writes a one-line summary to `episodes.jsonl`. Tomorrow's `/mem-recall` can replay it. Every week or two, `/mem-distill` reads the new episodes and proposes durable card updates.

Every step uses one of the four concepts. None of them is "magic" — each is a small mechanism with a documented contract.

---

## Where to read next

- **Set up the repo on your machine** → `docs/GETTING_STARTED.md`
- **Understand the dispatch flow used by `/pm` and `/pr-gate`** → `docs/dispatch-brief.md`
- **Query the repo index before writing a brief** → `docs/context-retrieval.md`
- **Add a new slash command** → look at any existing `commands/*.md` and `tests/shell/test-guards.sh`
- **Write a new hook** → read `runtime/hooks/guard-pm-write.sh` as a reference and add a test in `tests/shell/test-guards.sh`
- **Add a memory card** → see `~/.claude/projects/<id>/memory/MEMORY.md` for the index format; cards have YAML frontmatter (`name:` / `description:` / `metadata.type:`) and live next to the index
- **Platform support** → `docs/platform-support.md`

If you find a concept missing here or a section that confused you, that's a documentation bug — please open an issue.
