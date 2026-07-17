---
description: Use a dedicated git worktree per ticket/branch for parallel development — isolates uncommitted changes and build artifacts so multiple branches can be worked on at once without stepping on each other.
argument-hint: "[branch-name]"
---

Set up an isolated `git worktree` for parallel development using `pmctl worktree`, instead of switching branches in place or cloning the repo again.

## What

`pmctl worktree` wraps `git worktree` with a small out-of-repo registry (manifest) so linked worktrees are easy to list and clean up later, without hand-tracking which directory belongs to which branch.

**Prerequisite: this requires git.** `pmctl worktree` is a thin wrapper over `git worktree add/remove/prune` — there is no non-git fallback. The target directory must already be a git repository; `pmctl worktree create` fails immediately (git itself rejects the operation) if it is not.

Worktrees are stored out-of-repo, under the state store (`~/.local/share/pm-dispatch/state/projects/<project>/worktrees/checkouts/<slug>`), not inside the repo — so they never show up in `git status`, don't need a `.gitignore` entry, and survive `git clean`. The registry (manifest) resolves to the **same partition** whether `pmctl worktree` is invoked from the primary checkout or from inside one of the linked worktrees it created, so `pmctl worktree list` always shows the full picture regardless of which checkout you run it from. Manifest writes (`create` appending, `remove`/`gc` removing entries) are serialized under a single lock and always commit against the manifest's current on-disk state, not a snapshot taken earlier — running `pmctl worktree create` concurrently with `remove`/`gc` from another shell or process is safe.

## When to use

- You're mid-way through one ticket and need to start a second one without stashing/committing WIP just to switch branches.
- You want to run a long build/test in one branch's worktree while continuing to edit another branch.
- You need a disposable checkout of a branch (e.g. to inspect an old PR) without disturbing your primary working tree.

## Example

```sh
pmctl worktree create feat/my-feature
pmctl worktree list
pmctl worktree remove feat/my-feature
```

## Usage

```
pmctl worktree create <branch> [--from <base-branch>] [--name <slug>] [--cd <work_dir>]
pmctl worktree list   [--cd <work_dir>] [--json]
pmctl worktree remove <name|branch> [--force] [--cd <work_dir>]
pmctl worktree gc     [--dry-run] [--merged] [--max-age-days D] [--force] [--cd <work_dir>]
```

- `create <branch>` — attaches an existing local branch, or creates a new one off the current `HEAD` if it doesn't exist yet. Pass `--from <base-branch>` to create the new branch off a specific base instead of `HEAD`. Prints the new worktree's absolute path on success — capture it if you need to `cd` into it.
- `create --name <slug>` — override the manifest slug (defaults to the branch name with `/` replaced by `-`). Two worktrees cannot share a slug; `create` fails rather than silently overwriting an existing one.
- `list` — table of registered worktrees (`SLUG`, `BRANCH`, `PATH`). Add `--json` for a machine-readable array (each entry: `slug`, `branch`, `path`, `created_ts`).
- `remove <name|branch>` — matches by slug or by branch name. Fails if the worktree has uncommitted changes; pass `--force` to discard them and remove anyway. **`--force` is destructive** — it discards uncommitted work in that worktree with no recovery path, so confirm you don't need those changes before passing it.
- `gc` — reconciles the manifest against actual git/filesystem state: drops entries whose directory was removed manually (e.g. `rm -rf`) or that git no longer tracks (these are never destructive — the worktree is already gone or already untracked, so `gc` only cleans up the leftover manifest entry). Add `--merged` to also remove worktrees whose branch is fully merged, or `--max-age-days N` to remove entries older than N days — by default `gc` will *not* remove a merged/aged worktree that still has uncommitted changes (same dirty-worktree protection as plain `remove` without `--force`); it prints a `skipping ... has uncommitted changes` line and keeps the manifest entry instead. Pass `gc --force` to override that protection and force-remove merged/aged worktrees even when dirty — treat it with the same caution as `remove --force`. `--merged` is evaluated against the primary checkout's branch, not whichever worktree you happen to run `gc` from, so running `gc --merged` from inside a linked worktree never mistakes "merged into itself" for "safe to delete". Always run with `--dry-run` first to see what would be removed before running for real.

All four subcommands accept `--cd <work_dir>` to target a repo other than the current directory (same convention as `pmctl artifacts`/`pmctl dispatch`).

## Typical workflow

1. `pmctl worktree create feat/my-feature` — creates the worktree and prints its path.
2. `cd <printed path>` and, for a project with a gitignored dependency directory (e.g. `node_modules`, Python `venv`, vendored packages), install dependencies with that project's own package manager (`npm ci`/`yarn install --frozen-lockfile`/`pnpm install --frozen-lockfile`/`pip install -r requirements.txt`, etc. — check the repo's lockfile or existing install docs to tell which one applies) before running anything. `git worktree` never copies gitignored files, so a fresh worktree starts without them; skipping this step surfaces later as confusing test/build failures, or as a pr-gate "non-runnable" block. **Never substitute a symlink to another checkout's dependency directory** — a symlink is a tracked-type file, not an ignored directory, so it does not match the gitignore pattern and makes the worktree show up dirty, which pr-gate then rejects outright ("working tree is dirty while the branch has committed changes against main").
3. Work there like a normal checkout: `git add`, `git commit`, push, open a PR — all git operations behave exactly as in a regular checkout, because a linked worktree shares the same object store and refs as the primary checkout.
4. When the ticket's PR is merged (or abandoned), `pmctl worktree remove feat/my-feature` from either the primary checkout or from inside the worktree itself.
5. Periodically run `pmctl worktree gc --dry-run --merged` to spot worktrees left behind for already-merged branches, then `pmctl worktree gc --merged` to clean them up.

## Cleanup and orphan recovery

If a worktree directory is deleted directly (`rm -rf` instead of `pmctl worktree remove`), git and the manifest both still reference it. Run `pmctl worktree gc` — it detects the missing path, removes the stale manifest entry, and runs `git worktree prune` so `git worktree list` stays in sync too. By default `gc` never discards a directory that still exists and has uncommitted changes: for `--merged`/`--max-age-days` matches it attempts a plain (non-forced) removal and skips + reports any that turn out dirty, exactly like `remove` without `--force`. Only entries that are already gone or already untracked by git are removed unconditionally, since there is nothing live left to lose. Pass `gc --force` if you want merged/aged dirty worktrees discarded anyway.

## Out of scope

This tool does not touch the `--parallel` PR gate's reviewer-isolation logic (`runtime/bin/pr-gate.sh`) — that is a separate integration tracked independently. `pmctl worktree` is a general-purpose utility for any parallel branch work, not specific to the gate.
