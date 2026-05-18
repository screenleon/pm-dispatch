---
description: Generate an ultra-compressed conventional commit message for staged changes.
argument-hint: "[hint about the change]"
---

Generate a commit message for the current staged diff. Applies ultra compression — one line subject, no body unless a breaking change or non-obvious constraint must be recorded.

## What

`/caveman-commit` reads `git diff --cached`, infers type + scope + subject, and outputs a ready-to-paste commit message. Skips ceremony.

## When to use

- After staging files, before running `git commit`
- When the change is self-evident from the diff and a long message adds no value
- As a faster alternative to `/commit` in high-velocity sessions

## Example

```sh
/caveman-commit
/caveman-commit "split executor router from pm.md"
```

## Step 1 — Read staged diff

```bash
git diff --cached --stat
git diff --cached
```

If nothing is staged, print: `Nothing staged. Run git add first.` and stop.

## Step 2 — Infer commit fields

Determine:

- **type**: `feat` / `fix` / `docs` / `chore` / `refactor` / `test` / `ci` — pick the single best fit
- **scope** (optional): the module, script, or command most affected — omit if change spans 3+ unrelated areas
- **subject**: imperative, lowercase, ≤ 50 chars, no trailing period

If `$ARGUMENTS` is non-empty, use it as a hint for the subject.

Breaking change rule: if the diff removes a public interface, renames a hook script, or changes a required schema field — prefix subject with `!` after type, e.g. `feat(hooks)!: rename write-guard`.

## Step 3 — Output

Print only the commit message, ready to paste:

```
<type>[(<scope>)][!]: <subject>
```

No body unless:
- Breaking change (`!`) — add one blank line then `BREAKING CHANGE: <what breaks and migration path>`
- A non-obvious constraint that is not visible from the diff — one line max

No "Co-Authored-By" trailer (caller adds that separately if needed).
No markdown fences around the output — plain text so it can be piped directly.
