#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")" && pwd)/test-pr-gate.sh" --shard 1/4 "$@"
