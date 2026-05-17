---
description: Refine a named skill using the M1 feedback signal bundler.
argument-hint: "<skill-name>"
---

Run the M1 skill-refine signal bundler for exactly one named skill.

This command supports single-skill invocation only. Do not use `--all`, multiple skill names, or globs.

## Validate arguments

If `$ARGUMENTS` is empty, stop and say:

```
Pass a <skill-name> to refine, for example: /skill-refine codex-pr-gate
```

If `$ARGUMENTS` contains whitespace, stop and say:

```
Only single-skill invocation is supported in M2. Pass exactly one <skill-name>; do not use --all, multiple skill names, or globs.
```

## Run the bundler

From the repository working directory, run:

```bash
bash scripts/skill-refine.sh "$ARGUMENTS"
```

Return the script output verbatim so it can be pasted into a refinement brief.
