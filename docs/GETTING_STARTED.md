# Getting started

This guide is for a maintainer or fork owner setting up `pm-dispatch` on a new machine.
It assumes you already want to treat this repository as a personal bootstrap, not a public
collaboration portal.

If you want to understand the design shape first, read [`docs/CONCEPTS.md`](docs/CONCEPTS.md) before continuing.

## 1) Prerequisites

Before cloning or running anything, confirm the host has:

- **Claude Code** installed and launched on your machine.
- **`jq`** on `PATH` (required by hooks and install checks).
- **GNU `realpath`** equivalent on `PATH` (or a shell that provides equivalent behavior).
- Optional: **Codex CLI** (`codex`) if you want the default `full` install profile.

You can verify the minimum tooling quickly:

```sh
command -v claude
command -v jq
command -v realpath
```

If `codex` is present and later discoverable from your shell, the installer may default to the full profile.

```sh
command -v codex && echo "codex detected" || echo "no codex detected"
```

## 2) Clone this repository

Start from your fork root (or the upstream branch you want to adapt):

```sh
git clone <repo-url> ${PM_DISPATCH_REPO}
cd ${PM_DISPATCH_REPO}
```

If you cloned from an existing personal fork, define the placeholder once:

```sh
export PM_DISPATCH_REPO="$(pwd)"
```

Use any absolute path for `${PM_DISPATCH_REPO}`; that convention is used by several scripts and docs.

## 3) Install with `install.sh`

Run the installer dry run before applying:

```sh
cd ${PM_DISPATCH_REPO}
bash install.sh --dry-run
```

Then apply:

```sh
bash install.sh
```

`install.sh` has two explicit profiles and one auto-detected mode:

- `--profile full` — wires codex-related hooks and assumes Codex CLI workflow.
- `--profile minimal` — installs everything except codex hook guard paths.
- `--profile` omitted (default) — auto-detects profile from `command -v codex`.

Auto-detect is a simple presence check:

```sh
if command -v codex >/dev/null 2>&1; then
  echo "full profile"
else
  echo "minimal profile"
fi
```

When codex is intentionally absent, you can still run the full stack as a lightweight personal setup using
`bash install.sh --profile minimal`.

## 4) Verify install succeeded

Run the built-in health check:

```sh
bash scripts/doctor.sh
```

`doctor.sh` checks that `claude` and `jq` are on PATH, hooks are wired in
`~/.claude/settings.json`, the memory directory is present, scripts are
executable, and frontmatter passes lint. Each failing check prints a concrete
remediation command.

If you want to see what was linked rather than just whether it is healthy:

```sh
readlink -f "$HOME/.claude/commands/pm.md"
readlink -f "$HOME/.claude/agents/project-pm.md"
readlink -f "$HOME/.claude/.pm"
```

For a full regression sweep (takes ~30 s):

```sh
bash scripts/run-all-tests.sh
```

In normal docs-first workflows, passing `doctor.sh` alone is sufficient before
your first `/pm` run.

## 5) (Optional) Set up a repo-local context index

By default `pmctl context` stores the repository index in a global path under
`~/.local/share/pm-dispatch/state/`.  To keep the index alongside the repository
instead, export one environment variable before your first `pmctl context index`
run:

```sh
export PM_DISPATCH_STATE_ROOT=.pm-dispatch
pmctl context index "$PM_DISPATCH_REPO"
```

The `.pm-dispatch/` directory is gitignored, so the database file is never
committed.  See [`docs/context-retrieval.md`](docs/context-retrieval.md) for the
full convention and available subcommands.

## 6) First `/pm` run (end-to-end walkthrough)

After the checks are green, open a Claude Code session in the repo and send a concrete request:

```text
/pm draft a minimal onboarding change plan for this repo and list the exact command sequence to validate it
```

Expected flow:

1. `/pm` calls the `project-pm` subagent with your request and working context.
2. PM composes a brief against the dispatch schema.
3. If PM chooses codex/Claude execution, it routes through the accepted executor path.
4. The brief is run only against the declared file paths.
5. The executor returns with concrete outputs and a summary.

In a stable first run, you should see:

- A brief summary that names the edited targets.
- A test/reference plan in the executor report.
- A clean status against the accepted scope.

If you use a non-destructive request for this walkthrough, run:

```text
/pm review the current `/pm` onboarding docs and suggest one follow-up cleanup task
```

That gives the full PM + dispatch chain without requiring immediate code changes.

## 7) Useful follow-up reading

After you finish the first `/pm` cycle, keep these in sync:

- [`docs/CONCEPTS.md`](docs/CONCEPTS.md)
- [`docs/memory-system.md`](docs/memory-system.md)
- [`docs/dispatch-brief.md`](docs/dispatch-brief.md)
- [`docs/executor-contract.md`](docs/executor-contract.md)
- [`docs/context-retrieval.md`](docs/context-retrieval.md) — query the repo index before authoring a brief
- [`docs/pmctl-task.md`](docs/pmctl-task.md) — full task lifecycle commands
- [`docs/platform-support.md`](docs/platform-support.md)

If a fork user path differs from yours, keep your edits small and local; this repo is designed to be copied and adapted.

