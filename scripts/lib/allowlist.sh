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
}
