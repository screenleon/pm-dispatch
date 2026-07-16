#!/usr/bin/env bash
# Compatibility entrypoint; Claude host hook removal is manifest-owned.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
printf 'uninstall-guards: deprecated path; use %s\n' \
  "$repo_root/hosts/claude/bin/uninstall-guards.sh" >&2
exec "$BASH" "$repo_root/hosts/claude/bin/uninstall-guards.sh" --repo-root "$repo_root" "$@"
