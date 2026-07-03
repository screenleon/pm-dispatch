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
  # gains nothing from also being blocked on these specific, narrowly-scoped
  # command prefixes, which are exactly the steps the ship contract
  # (commands/ship.md / pmctl-ship.sh) requires every dispatched lane to run
  # unattended. Scoped to prefixes, not a blanket `git:*`/`gh:*`, so this does
  # not pre-approve unrelated destructive git/gh invocations.
  printf 'Bash(pmctl gate run:*)\n'
  printf 'Bash(pmctl ship finish:*)\n'
  printf 'Bash(git push:*)\n'
  printf 'Bash(gh pr create:*)\n'
}
