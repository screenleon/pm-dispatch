#!/usr/bin/env bash
# Compatibility entrypoint; Codex host installation is owned by its manifest.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
printf 'install-guards-codex: deprecated path; use %s\n' \
  "$repo_root/hosts/codex/bin/install.sh" >&2
exec bash "$repo_root/hosts/codex/bin/install.sh" --repo-root "$repo_root" "$@"
