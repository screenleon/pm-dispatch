#!/usr/bin/env bash
# Shared allowlist path helpers - sourced by install.sh, doctor.sh, uninstall-guards.sh.

dispatch_allowlist_entries() {
  # REPO_ROOT and HOME must be set by the caller.
  # Emits one "Bash(path:*)" entry per line — absolute and tilde-relative forms —
  # for every adapters/*/dispatch.sh that exists.
  local f rel

  # All registered adapter dispatch scripts
  for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
    [[ -f "$f" ]] || continue
    rel="${f#"$HOME/"}"
    printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
  done

  # A headless `claude` dispatch (adapters/claude/dispatch.sh) always runs
  # with --permission-mode acceptEdits or stricter (isolation-map.yaml) --
  # acceptEdits auto-approves file EDITS but, empirically (confirmed via a
  # real CC-441 ship --parallel dispatch), NOT Bash tool calls: a headlessly
  # dispatched executor asking "need user approval to run `pmctl gate run`"
  # has no approver and stalls until timeout.
  #
  # Approved broadly at the `pmctl` PREFIX (both the bare `pmctl` form a
  # dispatched lane's PATH resolves via this file's own adapter/*.sh
  # symlink-into-~/.local/bin install step, and the `bash cli/pmctl` form
  # used when invoking from inside the repo checkout) rather than pinned to
  # the two specific subcommands the ship contract happens to need
  # (`gate run` / `ship finish`). `pmctl` itself is the trusted, audited
  # entry point -- every subcommand goes through brief-validate, guard
  # checks, and/or a manifest-tracked state mutation (worktree
  # create/remove, dispatch run, gate run, backlog archive, artifacts gc);
  # none of them expose a raw, unconstrained passthrough to an arbitrary
  # shell command the way `git push`/`gh pr create` do. That distinction --
  # not "narrow string == safe, broad string == unsafe" -- is why this is a
  # different call than the raw `git push`/`gh pr create` widening pr-gate's
  # security/risk reviewers correctly blocked in an earlier draft of this
  # file (do not re-introduce a raw `Bash(git push:*)`/`Bash(gh *:*)` entry;
  # push/PR must stay behind a wrapper like `pmctl ship finish` that
  # constrains the exact form, e.g. no --force, no ref deletion, branch ==
  # feat/<ticket-id> only -- pmctl-ship.sh:pmctl_ship_finish enforces this).
  printf 'Bash(pmctl:*)\n'
  printf 'Bash(bash cli/pmctl:*)\n'
}
