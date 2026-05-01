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
- **project-pm** — PM across `~/github/` repos. Triages requests, decomposes work, dispatches to `codex-executor`, runs the PR gate, maintains per-project memory at `~/.claude/projects/-home-screenleon-github/memory/project_<repo>.md`.
- **codex-executor** — Thin wrapper subagent. Accepts a complete brief, dispatches to the Codex CLI via `scripts/codex-dispatch.sh`, verifies via `git diff`, reports back.

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

- **codex-dispatch.sh** — Invokes `codex exec` with tracing, sandbox/approval flags, and final-message capture. All `.agent-trace/codex-*.{jsonl,last}` writes happen inside the target project's `.agent-trace/` directory.

## Design notes

- **PM thinks, Codex implements.** `project-pm` writes the brief; `codex-executor` is a dispatcher, not a designer. Architecture, scope, and acceptance criteria stay with the PM.
- **Definitions in repo, state on disk.** Agent and command definitions are version-controlled here. Per-project state (memory, traces) lives in `~/.claude/` and stays out of this repo.
- **Decoupled from agent-playbook-template.** The playbook is a methodology framework; this repo is a personal config. They evolve independently.

## Adding new pieces

- New agent: drop a `name.md` (with frontmatter) into `agents/`, re-run `install.sh`.
- New command: drop a `name.md` into `commands/`, re-run `install.sh`.
- Settings allowlist additions: edit `~/.claude/settings.json` directly (or use the `update-config` skill); don't try to symlink settings.
