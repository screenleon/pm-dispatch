#!/usr/bin/env bash
# Canonical and compatibility hook identities owned by the Codex host.

codex_host_command_guard_path() {
  local repo_root="$1"
  printf '%s/hosts/codex/hooks/command-guard.sh\n' "$repo_root"
}

codex_host_command_guard_legacy_path() {
  local repo_root="$1"
  printf '%s/scripts/hook-codex-command-guard.sh\n' "$repo_root"
}
