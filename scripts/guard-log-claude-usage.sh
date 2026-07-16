#!/usr/bin/env bash
# Compatibility hook path retained for installed Claude settings.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
exec "$BASH" "$repo_root/hosts/claude/hooks/log-usage.sh" "$@"
