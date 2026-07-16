#!/usr/bin/env bash
# Compatibility entrypoint for hooks.json entries installed before host migration.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
exec "$repo_root/hosts/codex/hooks/command-guard.sh" "$@"
