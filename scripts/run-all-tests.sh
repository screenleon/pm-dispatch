#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf 'deprecated: use tests/bin/run-all-tests.sh\n' >&2
exec "$repo_root/tests/bin/run-all-tests.sh" "$@"
