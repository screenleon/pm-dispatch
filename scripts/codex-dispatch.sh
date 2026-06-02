#!/usr/bin/env bash
# Compatibility shim — delegates to adapters/codex/dispatch.sh (CC-289/CC-296).
# Real script (not a symlink) so Windows copy-mode installs copy a working
# wrapper instead of the raw Git-stored symlink target path.
# $SELF_DIR/../ resolves to repo adapters/ (direct run) or ~/.claude/adapters/
# junction/symlink (installed run).
SELF_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SELF_DIR/../adapters/codex/dispatch.sh" "$@"
