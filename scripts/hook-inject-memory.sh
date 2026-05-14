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
from datetime import datetime, timezone, timedelta

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
    memory_dir = None
    memory_path = None
    current = cwd.rstrip('/')
    while True:
        candidate_dir = os.path.join(projects_dir, encode_path(current), 'memory')
        candidate = os.path.join(candidate_dir, 'MEMORY.md')
        if os.path.isfile(candidate):
            memory_dir = candidate_dir
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
    EPISODE_REMINDER_HOURS = 24

    content = '\n'.join(index_lines)
    if not content:
        sys.exit(0)

    print('=== auto-memory: MEMORY.md index ===')
    print(content)
    if len(index_lines) >= THRESHOLD_LINES:
        print(f'⚠ MEMORY.md has {len(index_lines)} entries — run /memory-compress before responding.')

    # Episode reminder: check episodes.jsonl for stale or missing log
    episodes_file = os.path.join(memory_dir, 'episodes.jsonl')
    if os.path.isfile(episodes_file):
        last_entry = None
        with open(episodes_file) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        last_entry = json.loads(line)
                    except json.JSONDecodeError:
                        pass
        if last_entry:
            last_date_str = last_entry.get('date', '')
            last_summary = last_entry.get('summary', '')
            try:
                last_date = datetime.fromisoformat(last_date_str)
                now = datetime.now(timezone.utc)
                if last_date.tzinfo is None:
                    last_date = last_date.replace(tzinfo=timezone.utc)
                age_hours = (now - last_date).total_seconds() / 3600
                if age_hours > EPISODE_REMINDER_HOURS:
                    date_short = last_date.strftime('%Y-%m-%d')
                    if not last_summary.strip():
                        print(f'💡 No episode logged since {date_short} — run /mem-log to record this session.')
                    else:
                        print(f'💡 Last episode: {date_short} — run /mem-log if this session has new learnings.')
            except (ValueError, TypeError):
                pass

    print('=== end auto-memory ===')
except Exception:
    sys.exit(0)
PYEOF

exit 0
