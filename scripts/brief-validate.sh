#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf 'deprecated: use runtime/bin/brief-validate.sh\n' >&2
exec "$repo_root/runtime/bin/brief-validate.sh" "$@"
