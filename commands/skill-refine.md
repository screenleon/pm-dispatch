---
description: Refine a named skill using the M1 feedback signal bundler.
argument-hint: "<skill-name>"
---

Run the M1 skill-refine signal bundler for exactly one named skill.

This command supports single-skill invocation only. Do not use `--all`, multiple skill names, or globs.

## Prerequisites

`CLAUDE_MEMORY_DIR` must be exported and point to an existing memory directory before invoking this command. Claude Code sets this automatically; if running from a bare shell, select the directory for the current absolute project path and export it first:

```sh
export CLAUDE_MEMORY_DIR="${HOME}/.claude/projects/<claude-project-id>/memory"
```

If `CLAUDE_MEMORY_DIR` is unset or points to a nonexistent directory, `tools/skills/skill-refine.sh` will exit 2 with a clear error.

## What

`/skill-refine` runs the one-skill feedback bundling path to produce concrete refinement output for a single target command or skill.

## When to use

- When a named skill has stale scope, unclear constraints, or repeated feedback signals.
- Before drafting a revision pass for a specific skill.
- When you need signal packaging before opening a follow-up refinement brief.

## Example

```sh
/skill-refine mem-recall
```

## Validate arguments

If `$ARGUMENTS` is empty, stop and say:

```
Pass a <skill-name> to refine, for example: /skill-refine codex-pr-gate
```

If `$ARGUMENTS` contains whitespace, stop and say:

```
Only single-skill invocation is supported in M1. Pass exactly one <skill-name>; do not use --all, multiple skill names, or globs.
```

## Run the bundler

From the repository working directory, run:

```bash
bash tools/skills/skill-refine.sh "$ARGUMENTS"
```

Return the script output verbatim so it can be pasted into a refinement brief.
