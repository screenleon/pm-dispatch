# Contributing to pm-dispatch

`pm-dispatch` is published as **source-available**: the code is public so anyone can read it, fork it, and adapt it to their own workflow, but the upstream repository is currently maintained for personal use and does **not accept external pull requests**.

## Contribution policy

- **Pull requests from non-maintainers are not accepted at this time.** PRs opened against this repository may be closed without review. Please fork the project and apply your changes there.
- **Issues are welcome but have no SLA.** Bug reports, feature ideas, and questions are useful signal; we'll respond when we can. There is no commitment to triage, fix, or implement.
- **The Code of Conduct still applies** to issues and any other interaction in this repository — see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- **This policy may change.** If external contribution interest emerges and there is bandwidth to maintain a reviewer relationship, the policy may be revisited. For now, the bar is "demonstrated interest via thoughtful issues" before any reopening.

The rest of this document describes the **internal workflow** the maintainers use. It is included here so that anyone reading their own fork can follow the same conventions if they want to keep their fork close to upstream.

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

For every file-writing or schema-affecting PR, run the full test suite:

```bash
bash scripts/run-all-tests.sh
```

This runs all suites (hooks, install, portable, pr-gate, usage, pm-scripts, etc.) and
prints a pass/fail/skip summary. To run only the affected suite in isolation, use
`--skip` for everything else or call the individual `scripts/test-*.sh` directly.

Additionally, for any BACKLOG.md or CHANGELOG.md changes:

```bash
bash pm/scripts/validate.sh BACKLOG.md CHANGELOG.md
```

Include exit code and summary line in your PR notes.

**Why `--no-verify` is not acceptable**: pre-commit hooks enforce schema validation and
hook-guard contract tests. Bypassing them lets malformed entries or broken hook policies
reach `main` silently. If a hook blocks your commit, diagnose and fix the root cause —
do not skip the hook.

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

## Communication (for forks / future maintainers)

If you maintain a fork and want to keep diffs reviewable, include in each significant change:

- the motivating issue/ticket id,
- expected impact,
- rollback plan,
- and any migration caveats.

## Working language

Primary working language is Mandarin Chinese. Commit messages and code identifiers are
English. Issue threads and PR descriptions may be bilingual; non-Mandarin contributors
are welcome and should expect bilingual responses.

Pre-commit hooks and shell scripts must remain in English for portability.

## If you've found a bug in upstream

Open an issue describing the smallest reproduction you can produce and the workaround you used in your fork. Even though external PRs are not accepted, useful bug reports help shape future versions and are the primary signal we use to consider reopening contributions.
