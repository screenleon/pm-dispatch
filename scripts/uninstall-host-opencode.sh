#!/usr/bin/env bash
# Compatibility entrypoint; OpenCode host removal is owned by its manifest.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
printf 'uninstall-host-opencode: deprecated path; use %s\n' \
  "$repo_root/hosts/opencode/bin/uninstall.sh" >&2
exec bash "$repo_root/hosts/opencode/bin/uninstall.sh" --repo-root "$repo_root" "$@"
