#!/usr/bin/env bash
# hook-session-summary.sh — Stop hook: record session metadata to episodes.jsonl.
# Writes a metadata-only entry (no LLM call). Semantic summary is filled in by
# /mem-log after the user explicitly runs it while the session is still active.
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

SESSION_WINDOW_HOURS = 4  # /mem-log entries older than this do not suppress new sessions

payload_file, config_dir = sys.argv[1], sys.argv[2]

def encode_path(path):
    return '-' + path.lstrip('/').replace('/', '-')

try:
    with open(payload_file) as f:
        data = json.load(f)
    cwd = data.get('cwd')
    if not isinstance(cwd, str) or not cwd:
        sys.exit(0)
    session_id = data.get('session_id', '')
    if not isinstance(session_id, str):
        session_id = ''

    # Find project memory dir (same ancestor-walk as hook-inject-memory.sh)
    projects_dir = os.path.join(config_dir, 'projects')
    memory_dir = None
    current = cwd.rstrip('/')
    while True:
        candidate = os.path.join(projects_dir, encode_path(current), 'memory')
        if os.path.isdir(candidate):
            memory_dir = candidate
            break
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    if not memory_dir:
        sys.exit(0)

    episodes_file = os.path.join(memory_dir, 'episodes.jsonl')
    now = datetime.now(timezone.utc).isoformat()

    # Read existing entries to check for duplicates
    entries = []
    if os.path.isfile(episodes_file):
        with open(episodes_file) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        entries.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass

    # Skip if any entry already records this session_id (with or without summary).
    # /mem-log runs during the session and may have written a full entry already;
    # the Stop hook should not add a duplicate skeleton in that case.
    if session_id and any(e.get('session_id') == session_id for e in entries):
        sys.exit(0)

    # Also skip if the most recent entry for the same cwd was written by /mem-log
    # (session_id="") within the last SESSION_WINDOW_HOURS hours and already has
    # a non-empty summary. This covers /mem-log running before Stop in the same
    # session. Time-bounded: an old /mem-log entry must not suppress later sessions.
    cwd_entries = [e for e in entries if e.get('cwd') == cwd]
    if cwd_entries:
        last = cwd_entries[-1]
        if (not last.get('session_id', '').strip() and last.get('summary', '').strip()):
            try:
                last_date = datetime.fromisoformat(last.get('date', ''))
                if last_date.tzinfo is None:
                    last_date = last_date.replace(tzinfo=timezone.utc)
                age_hours = (datetime.now(timezone.utc) - last_date).total_seconds() / 3600
                if age_hours < SESSION_WINDOW_HOURS:
                    sys.exit(0)
            except (ValueError, TypeError):
                pass

    # Append new metadata entry
    entry = {
        'date': now,
        'cwd': cwd,
        'session_id': session_id,
        'summary': '',
    }
    with open(episodes_file, 'a') as f:
        f.write(json.dumps(entry, ensure_ascii=False, separators=(',', ':')) + '\n')

except Exception:
    sys.exit(0)
PYEOF

exit 0
