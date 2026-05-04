# claude-config

Personal Claude Code configuration: subagents, slash commands, skills, and dispatch scripts. Source of truth lives in this repo; entries are symlinked into `~/.claude/` by `install.sh`.

## Layout

```
agents/      → ~/.claude/agents/    subagents callable via the Agent tool
skills/      → ~/.claude/skills/    invocable skills
commands/    → ~/.claude/commands/  /slash commands
scripts/                            wrappers (not symlinked; called by absolute path)
settings/                           settings fragments to merge into ~/.claude/settings.json by hand
```

## Install

```sh
./install.sh --dry-run   # preview
./install.sh             # apply
```

Idempotent — re-run safely after adding files. Per-file symlinks so other tools' agents in `~/.claude/agents/` are not clobbered. If a destination already exists and is not our symlink, it is skipped with a CONFLICT warning.

## What's here

### Agents

**Orchestration**
- **project-pm** — PM across `~/github/` repos. Triages requests, decomposes work, writes briefs (main thread dispatches), synthesizes PR-gate reviews, maintains per-project memory at `~/.claude/projects/-home-screenleon-github/memory/project_<repo>.md`.
- **codex-executor** — Thin wrapper subagent, dispatched by the main thread. Accepts a complete brief, calls Codex via `scripts/codex-dispatch.sh`, verifies via `git diff`, reports back.

**Reviewers (advisors — PM may override with reasoning)**
- **critic** — Adversarial review of plan / diff. Scope creep, incompleteness, convention drift.
- **architecture-reviewer** — Layer / coupling / abstraction fit. Does the change respect the existing design.

**Reviewers (HARD GATES — only the user can override a `block`)**
- **security-reviewer** — OWASP-style security review for any implementation change. Auth, injection, secrets, deps, deserialization, etc.
- **risk-reviewer** — Blast radius, reversibility, migration safety, fail mode, observability. Distinct from security.
- **qa-tester** — Owns the testing phase. Loads `~/github/qa-testing-rules/AGENT.md` as Tier 1 source of truth for test categories, layer choice, and anti-patterns. Red-line violations are blocking.

### Commands

- **/pm `<request>`** — Routes a free-form request to the `project-pm` agent.
- **/pr-gate `[context]`** — Explicitly runs the full review pipeline before opening a PR.

### External dependencies

- [`screenleon/qa-testing-rules`](https://github.com/screenleon/qa-testing-rules) cloned at `~/github/qa-testing-rules/`. Used by `qa-tester`. If missing, qa-tester will stop and ask you to clone it.

### Scripts

- **codex-dispatch.sh** — Invokes `codex exec` with tracing, sandbox/approval flags, timeout (default 1200s, override via `--timeout` or `$CODEX_DISPATCH_TIMEOUT`), and final-message capture. Writes `.agent-trace/codex-<ts>.{jsonl,last,stderr}` and refreshes `.agent-trace/latest.{jsonl,last,stderr}` symlinks so observers can attach without knowing the timestamp. Exit 124 = hit the timeout (silent codex hang most likely cause).
- **codex-watch.sh** — Tails `.agent-trace/latest.jsonl` and prints a one-line human summary per event (`[turn.started]`, `[cmd] exit=0 …`, `[msg] …`, `[turn.completed] tokens: …`). Run from another terminal during a long dispatch to see real-time progress.
- **hook-pm-write-guard.sh** — `PreToolUse` hook (matcher `Edit|Write`). Blocks `project-pm` from editing/writing outside `~/.claude/projects/-home-screenleon-github/memory/`. No-op for any other agent or the main thread. Bypass: `CLAUDE_HOOK_PM_GUARD=off`.
- **hook-codex-bash-guard.sh** — `PreToolUse` hook (matcher `Bash`). Restricts `codex-executor` to `codex-dispatch.sh` plus read-only verify commands (`git`, `cat`, `ls`, `head`, `tail`, `wc`, `grep`, `find`, `realpath`). Blocks direct `codex exec` etc. Bypass: `CLAUDE_HOOK_CODEX_GUARD=off`.

## Design notes

- **Subagents cannot spawn subagents.** Claude Code intentionally restricts nested `Agent` tool calls regardless of frontmatter declaration ([Agent SDK docs](https://code.claude.com/docs/en/agent-sdk/subagents.md)). The **main thread** orchestrates: it spawns subagents (PM, reviewers, codex-executor) and relays outputs between them. PM produces briefs and synthesizes verdicts; it does not dispatch. Reviewers run in parallel from the main thread, not from PM. Never include `Agent` in any subagent's `tools:` frontmatter — `scripts/lint-agents.sh` enforces this.
- **Hooks enforce hard rules; prose alone leaks.** CLAUDE.md compliance for "never do X" rules sits around 70% in the public research, so structural enforcement matters for invariants. Two `PreToolUse` hooks live in `~/.claude/settings.json`: `hook-pm-write-guard.sh` (project-pm can only Edit/Write inside the memory dir) and `hook-codex-bash-guard.sh` (codex-executor's Bash is restricted to the dispatch script + read-only verify commands). Both no-op for the main thread and other subagents. Bypass via `CLAUDE_HOOK_PM_GUARD=off` / `CLAUDE_HOOK_CODEX_GUARD=off`.
- **PM thinks, Codex implements.** `project-pm` writes the brief; `codex-executor` is a dispatcher, not a designer. Architecture, scope, and acceptance criteria stay with the PM.
- **Definitions in repo, state on disk.** Agent and command definitions are version-controlled here. Per-project state (memory, traces) lives in `~/.claude/` and stays out of this repo.
- **Decoupled from agent-playbook-template.** The playbook is a methodology framework; this repo is a personal config. They evolve independently.

## Adding new pieces

- New agent: drop a `name.md` (with frontmatter) into `agents/`, re-run `install.sh`. **Don't include `Agent` in `tools:`** — `scripts/lint-agents.sh` will reject the install.
- New command: drop a `name.md` into `commands/`, re-run `install.sh`.
- Settings allowlist additions: edit `~/.claude/settings.json` directly (or use the `update-config` skill); don't try to symlink settings.

## Codex briefs

Schema and reusable self-verify macros: [`docs/codex-brief.md`](docs/codex-brief.md). All briefs dispatched to `codex-executor` must include `working_dir`, `goal`, `files`, and `acceptance`; the executor rejects briefs missing those fields.

### Watching a long dispatch

Codex briefs that touch many files can run 10–30 minutes. The `codex-executor` subagent blocks until codex returns, so the parent agent has no incremental view. Two recovery patterns:

1. **External tail (any session, no Claude Code involvement).** From another terminal:
   ```sh
   ~/github/claude-config/scripts/codex-watch.sh --cd /path/to/project
   ```
   Prints one line per codex event as it streams. Works whether the dispatcher was launched from Claude Code, the CLI, or a CI job.

2. **Background dispatch from main thread.** When you need progress visible *inside* a Claude Code session, skip `codex-executor` and run the wrapper as a background Bash command, then `Monitor` (or periodically `Bash` with `tail -n 5 .agent-trace/latest.jsonl`) the trace file. Invoke `codex-executor` only at the end for `git diff` verification. Trade-off: you lose the executor's pre-dispatch brief validation, so write the brief carefully.

If a dispatch exits 124, codex hit the timeout — almost always a silent startup hang. The wrapper banner + closing line in `.agent-trace/latest.stderr` is the post-mortem: re-dispatching usually clears the hang. Extend `--timeout` (or `$CODEX_DISPATCH_TIMEOUT`) only when codex is genuinely doing more work than the default 20 minutes.
