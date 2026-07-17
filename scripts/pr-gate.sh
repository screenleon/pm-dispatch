#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf 'deprecated: use runtime/bin/pr-gate.sh\n' >&2
exec "$repo_root/runtime/bin/pr-gate.sh" "$@"
