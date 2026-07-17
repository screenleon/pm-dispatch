#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf 'deprecated: use ops/release/release-verify.sh\n' >&2
exec "$repo_root/ops/release/release-verify.sh" "$@"
