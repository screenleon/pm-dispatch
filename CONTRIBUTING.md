# Contributing to pm-dispatch

Welcome! This project is maintained for cross-user use, and PRs should be easy for external contributors to follow.

## Branch flow

- Start from `main` and create short-lived feature branches.
- Use branch names such as:
  - `feat/CC-123-topic`
  - `fix/CC-123-topic`
  - `chore/CC-123-topic`
- Keep one coherent change per branch.
- Rebase onto `main` before opening a PR if your branch is old.

## Conventional Commit messages

This repo uses Conventional Commits. Match the existing style (lowercase, imperative summary):

```text
feat(cc-###): short summary
fix(cc-###): short summary
chore(cc-###): short summary
```

- Use ticket-like scope (for example `cc-100`, `cc-101`) when available.
- Keep subject lines to one concise sentence.
- PR titles should mirror commit convention, for example:
  - `feat(cc-100): sanitize hardcoded repo path`
  - `chore(cc-100): add OSS baseline docs`

## PR workflow

Before opening a PR:

1. Run `/pr-gate` in the main thread.
2. Address any required review blocks.
3. Confirm the final checklist in your PR description.

[`/pr-gate` skill](commands/pr-gate.md) is the hard-gate review entry point and is documented alongside the same execution patterns in [`docs/dispatch-brief.md`](docs/dispatch-brief.md).

## PM brief schema and contracts

The current authoritative schema and handoff contract is in [`docs/dispatch-brief.md`](docs/dispatch-brief.md). Use it as the source-of-truth for:

- `working_dir`, `goal`, and `acceptance` structure
- file scope and self-verify requirements
- expected handover fields and evidence style

If this repository adds changes to the dispatch pipeline, update this schema first and keep examples aligned with it.

## Testing and validation

For every file-writing or schema-affecting PR, run:

- `bash scripts/test-hooks.sh`
- `bash scripts/test-codex-dispatch.sh`
- `bash scripts/test-dispatch-handover.sh`

Run with default environment unless a script documents different fixtures or temporary overrides.

Include output or exit status in your PR notes.

## Path convention

Use `${PM_DISPATCH_REPO}` in examples and docs to denote your local clone root.

Examples:

- `${PM_DISPATCH_REPO}/scripts/install-hooks.sh --dry-run`
- `${PM_DISPATCH_REPO}/commands/pm.md`
- `export PM_DISPATCH_REPO="/tmp/my-pm-dispatch"`

Do not add personal absolute paths in docs or examples.

## Code expectations

- Keep behavior changes minimal and documented.
- Preserve existing defaults whenever possible.
- Keep scripts idempotent when they are installer or hook logic.
- Prefer compatibility for existing users before introducing new defaults.

## Review behavior

Project-specific checks run from installer and PR-gate flow may fail fast if conventions or hook contracts drift. If a check fails, include a minimal repro and evidence in your PR notes.

## Communication

For larger refactors, include:

- the motivating issue/ticket id,
- expected impact,
- rollback plan,
- and any migration caveats.
