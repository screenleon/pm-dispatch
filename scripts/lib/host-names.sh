#!/usr/bin/env bash
# Shared host-name policy for host-neutral pmctl surfaces.

pmctl_host_is_valid() {
  case "${1:-}" in
    claude|codex|opencode|generic) return 0 ;;
    *) return 1 ;;
  esac
}
