#!/usr/bin/env bash
# Backward-compatible full-suite entry point.
# The primary runner surface is run-tests.sh; this wrapper selects its --all mode.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run-tests.sh" --all "$@"
