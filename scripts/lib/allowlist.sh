#!/usr/bin/env bash
# Shared allowlist path helpers - sourced by install.sh, doctor.sh, uninstall-hooks.sh.

dispatch_allowlist_entries() {
  # REPO_ROOT and HOME must be set by the caller.
  # Emits one "Bash(path:*)" entry per line — absolute and tilde-relative forms —
  # for the compat shim and every adapters/*/dispatch.sh that exists.
  local f rel

  # Compatibility shim (scripts/codex-dispatch.sh → adapters/codex/; sunset CC-296)
  f="$REPO_ROOT/scripts/codex-dispatch.sh"
  if [[ -f "$f" ]]; then
    rel="${f#"$HOME/"}"
    printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
  fi

  # All registered adapter dispatch scripts
  for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
    [[ -f "$f" ]] || continue
    rel="${f#"$HOME/"}"
    printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
  done
}
