#!/usr/bin/env bash
# Shared builder for minimal fixture repositories that execute the real pmctl.

pmctl_fixture_copy_spine() {
  local source_root="$1" target_root="$2"
  mkdir -p "$target_root/cli" "$target_root/runtime/lib"
  cp "$source_root/cli/pmctl" "$target_root/cli/pmctl"
  cp "$source_root/cli/commands.tsv" "$target_root/cli/commands.tsv"
  cp "$source_root/runtime/lib/pmctl-discovery.sh" "$target_root/runtime/lib/pmctl-discovery.sh"
  chmod +x "$target_root/cli/pmctl"
}
