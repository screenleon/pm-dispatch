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
  # has no approver and stalls until timeout. The isolation SANDBOX (network/
  # filesystem scope) is the actual security boundary here, not the
  # permission prompt -- an already-dispatched, already-sandboxed executor
  # gains nothing from also being blocked on these two specific, narrowly-
  # scoped command prefixes, which are exactly the top-level Bash tool calls
  # the ship contract (commands/ship.md / pmctl-ship.sh) requires every
  # dispatched lane to run unattended.
  #
  # Deliberately NOT allowlisted: raw `git push`/`gh pr create`. `pmctl ship
  # finish` already runs `git push -u origin <branch>` and `gh pr create`
  # itself as ordinary subprocess calls INSIDE that one approved Bash tool
  # invocation -- Claude's permission system gates model-issued tool calls,
  # not the subprocess tree spawned by an already-approved command, so those
  # two entries added nothing functionally and only widened the blast radius
  # (a raw `Bash(git push:*)` prefix-matches force pushes, ref deletion, and
  # pushes issued from any repo, not just the ship flow's own narrow push).
  # Pr-gate's security/risk reviewers correctly blocked an earlier draft of
  # this file that included them; do not re-add without a wrapper that
  # constrains the exact push form (no --force, no ref deletion, current
  # branch only).
  printf 'Bash(pmctl gate run:*)\n'
  printf 'Bash(pmctl ship finish:*)\n'
}
