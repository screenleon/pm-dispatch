#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf 'deprecated: use ops/usage/log-usage.sh\n' >&2
exec "$repo_root/ops/usage/log-usage.sh" "$@"
