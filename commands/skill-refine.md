---
description: Refine a named skill using the M1 feedback signal bundler.
argument-hint: "<skill-name>"
---

Run the M1 skill-refine signal bundler for exactly one named skill.

This command supports single-skill invocation only. Do not use `--all`, multiple skill names, or globs.

## Prerequisites

`/skill-refine` resolves the current repository's canonical project memory through `pmctl memory resolve`. For an explicit cross-host override, export `PM_MEMORY_DIR` as an existing absolute directory:

```sh
export PM_MEMORY_DIR="/absolute/path/to/project-memory"
```

An invalid explicit `PM_MEMORY_DIR` fails closed. `CLAUDE_MEMORY_DIR` remains a temporary compatibility input for existing Claude wrappers, but is not the shared contract.

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
