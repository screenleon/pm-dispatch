#!/usr/bin/env bash
# hook-inject-memory.sh — UserPromptSubmit hook: inject MEMORY.md index.
# Receives JSON payload via stdin from Claude Code UserPromptSubmit event.
set -euo pipefail

payload=$(cat)
[[ -z "$payload" ]] && exit 0

_config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
_tmp=$(mktemp)
trap 'rm -f "$_tmp"' EXIT
printf '%s' "$payload" > "$_tmp"

python3 - "$_tmp" "$_config_dir" << 'PYEOF'
import json, os, sys

payload_file, config_dir = sys.argv[1], sys.argv[2]


def encode_path(path):
    return '-' + path.lstrip('/').replace('/', '-')


try:
    with open(payload_file) as f:
        data = json.load(f)

    cwd = data.get('cwd')
    if not isinstance(cwd, str) or not cwd:
        sys.exit(0)

    projects_dir = os.path.join(config_dir, 'projects')
    memory_path = None
    current = cwd.rstrip('/')
    while True:
        candidate = os.path.join(projects_dir, encode_path(current), 'memory', 'MEMORY.md')
        if os.path.isfile(candidate):
            memory_path = candidate
            break
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent

    if not memory_path:
        sys.exit(0)

    with open(memory_path) as f:
        index_lines = [line.rstrip('\n') for line in f if line.startswith('- ')]

    if not index_lines:
        sys.exit(0)

    THRESHOLD_LINES = 50

    content = '\n'.join(index_lines)
    if not content:
        sys.exit(0)

    print('=== auto-memory: MEMORY.md index ===')
    print(content)
    if len(index_lines) >= THRESHOLD_LINES:
        print(f'⚠ MEMORY.md has {len(index_lines)} entries — run /memory-compress before responding.')
    print('=== end auto-memory ===')
except Exception:
    sys.exit(0)
PYEOF

exit 0
