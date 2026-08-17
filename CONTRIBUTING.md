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

The authoritative maintainer sequence and failure loop are defined in
[`/ship` Steps 2.5–3.5](commands/ship.md#step-25--refactorreuse-audit).

1. Use affected tests during implementation, then complete `/ship` Step 2.5's
   refactor/reuse audit.
2. Run `/pr-gate` in the main thread.
3. Address findings and apply `/ship` Step 3's conditional recheck rule.
4. After GO, complete `/ship` Step 3.5's authoritative full-suite check.
5. Confirm the final checklist in your PR description.

[`/pr-gate` skill](commands/pr-gate.md) is the hard-gate review entry point and is documented alongside the same execution patterns in [`docs/dispatch-brief.md`](docs/dispatch-brief.md).
The refactor/reuse checkpoint is this repository's maintainer policy; it does
not make `pmctl gate` or its component tools mandatory for downstream users.

## PM brief schema and contracts

The current authoritative schema and handoff contract is in [`docs/dispatch-brief.md`](docs/dispatch-brief.md). Use it as the source-of-truth for:

- `working_dir`, `goal`, and `acceptance` structure
- file scope and self-verify requirements
- expected handover fields and evidence style

If this repository adds changes to the dispatch pipeline, update this schema first and keep examples aligned with it.

## Testing and validation

### Maintainer development dependencies

Running lint or the authoritative full suite requires the pinned **ShellCheck**
in the tool cache. It is a maintainer/fork development dependency only: ordinary
users who install and use pm-dispatch tools do not need ShellCheck. The
repository pins the exact version in `.shellcheck-version`; do not rely on a
platform package or runner image choosing a compatible version. Install the
checksum-verified pinned binary into the tool cache and prepend it for the
current shell:

```bash
shellcheck_bin_dir="$(bash tools/lint/bootstrap-shellcheck.sh)" &&
  export PATH="$shellcheck_bin_dir:$PATH"
bash tools/lint/bootstrap-shellcheck.sh --check
```

Prepending it is a convenience, not a requirement: lint resolves the pinned
binary from the cache when `PATH` carries a different version, so a subprocess
with an ambient `shellcheck` (a gate reviewer sandbox, for one) still scans with
the pin. Resolution stays offline — once the cache is empty, lint fails before
scanning and names both probes rather than downloading. Set
`PM_DISPATCH_TOOL_CACHE` when the default `$XDG_CACHE_HOME/pm-dispatch/tools`
(or `$HOME/.cache/pm-dispatch/tools`) is not suitable.

During implementation and gate-fix iteration, run only the affected suites:

```bash
bash tests/bin/run-tests.sh --base <base-ref>
```

After PR-gate returns GO, run the full test suite once against the final tree:

```bash
bash tests/bin/run-all-tests.sh
```

For full-suite failures and re-gating, follow the authoritative loop in
[`/ship` Step 3.5](commands/ship.md#step-35--authoritative-full-suite).

This runs all suites (hooks, install, portable, pr-gate, usage, pm-scripts, etc.) and
prints a pass/fail/skip summary. For a focused run on one suite, invoke it directly,
for example `bash tests/shell/test-guards.sh` or `bash tests/shell/test-install.sh`. Use
`--skip <suite>` to opt out of environment-specific suites, such as
`--skip test-codex-dispatch` when the Codex CLI is not installed.

Additionally, for any BACKLOG.md or CHANGELOG.md changes:

```bash
bash pm/scripts/validate.sh BACKLOG.md CHANGELOG.md
```

The command may exit non-zero due to pre-existing baseline debt in `BACKLOG.md`: `E-AREA-ENUM` (compound area tokens not yet in enum), `E-INDEX-MISMATCH` (entries without body stubs), and legacy `E-STATUS-ENUM` / `E-DATE-FORMAT` on some CC-104x entries. The PR requirement is that your changes do not introduce **new** error lines beyond the pre-existing baseline. Run the command, capture the output, and confirm no new `E-*:` codes appear in the diff. Include the `validate.sh` output in your PR notes.

**Why `--no-verify` is not acceptable**: pre-commit hooks enforce schema validation and
hook-guard contract tests. Bypassing them lets malformed entries or broken hook policies
reach `main` silently. If a hook blocks your commit, diagnose and fix the root cause —
do not skip the hook.

## Path convention

Use `${PM_DISPATCH_REPO}` in examples and docs to denote your local clone root.

Examples:

- `${PM_DISPATCH_REPO}/scripts/install-guards.sh --dry-run`
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
