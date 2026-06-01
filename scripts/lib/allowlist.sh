#!/usr/bin/env bash
# Shared allowlist path helpers - sourced by install.sh and scripts/doctor.sh.

dispatch_allowlist_entries() {
  # REPO_ROOT must be set by the caller.
  local abs_dispatch="$REPO_ROOT/scripts/codex-dispatch.sh"
  local rel="${abs_dispatch#"$HOME/"}"
  local tilde_dispatch="~/$rel"
  local abs_adapter="$REPO_ROOT/adapters/codex/dispatch.sh"
  local rel_adapter="${abs_adapter#"$HOME/"}"
  local tilde_adapter="~/$rel_adapter"

  printf '%s\n' \
    "Bash($abs_dispatch:*)" \
    "Bash($tilde_dispatch:*)" \
    "Bash($abs_adapter:*)" \
    "Bash($tilde_adapter:*)"
}
