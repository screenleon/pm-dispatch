#!/usr/bin/env bash
#
# claude-usage.sh — rolling 5-hour Claude token usage estimator
#
# Usage:
#   bash ~/.claude/scripts/claude-usage.sh          # last 5 hours
#   bash ~/.claude/scripts/claude-usage.sh --today  # today only
#   bash ~/.claude/scripts/claude-usage.sh --all    # all time

set -euo pipefail

LOGFILE="$HOME/.claude/usage-tracker.jsonl"
CALIB_FILE="$HOME/.claude/usage-calibration.json"
MODE="${1:---5h}"

if [[ ! -f "$LOGFILE" ]]; then
  echo "No usage log at $LOGFILE"
  echo "Use: bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note]"
  exit 0
fi

python3 - "$MODE" "$LOGFILE" "$CALIB_FILE" << 'PYEOF'
import sys, json
from collections import defaultdict
from datetime import datetime, timezone, timedelta

mode = sys.argv[1]
logfile = sys.argv[2]
calib_file = sys.argv[3]

# Load entries
entries = []
with open(logfile) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        try:
            entries.append(json.loads(line))
        except:
            pass

# Filter by time window
now = datetime.now(timezone.utc)
if mode == '--today':
    label = 'today (UTC)'
    cutoff = now.replace(hour=0, minute=0, second=0, microsecond=0)
    entries = [e for e in entries if datetime.fromisoformat(e['ts'].replace('Z', '+00:00')) >= cutoff]
elif mode == '--all':
    label = 'all time'
else:
    hours = int(mode.lstrip('-').rstrip('h'))
    label = f'last {hours}h'
    cutoff = now - timedelta(hours=hours)
    entries = [e for e in entries if datetime.fromisoformat(e['ts'].replace('Z', '+00:00')) >= cutoff]

# Load calibration
known_limit = None
rate_limit_events = []
try:
    with open(calib_file) as f:
        calib = json.load(f)
        known_limit = calib.get('known_limit_tokens')
        rate_limit_events = calib.get('rate_limit_events', [])
except:
    pass

total_tokens = sum(e.get('tokens', 0) for e in entries)
by_type = defaultdict(lambda: {'count': 0, 'tokens': 0})
by_session = defaultdict(lambda: {'count': 0, 'tokens': 0})
for e in entries:
    t = e.get('type', 'unknown')
    s = (e.get('session') or '?')[:10]
    by_type[t]['count'] += 1
    by_type[t]['tokens'] += e.get('tokens', 0)
    by_session[s]['count'] += 1
    by_session[s]['tokens'] += e.get('tokens', 0)

print('═══════════════════════════════════════════════')
print(' Claude Code Usage Estimator')
print('═══════════════════════════════════════════════')
print(f' Window : {label}')
print(f' Entries: {len(entries)}')
print(f' Total  : {total_tokens:,} tokens  (~{total_tokens/1000:.0f}k)')

if known_limit:
    pct = total_tokens / known_limit * 100
    remaining = max(0, known_limit - total_tokens)
    bar_filled = min(20, int(pct / 5))
    bar = '█' * bar_filled + '░' * (20 - bar_filled)
    print(f' Limit  : {known_limit:,} tokens (calibrated)')
    print(f' Used   : [{bar}] {pct:.1f}%')
    print(f' Remain : ~{remaining:,} tokens')
    if total_tokens > 0 and len(entries) > 1:
        # Estimate based on current session rate
        first_ts = min(datetime.fromisoformat(e['ts'].replace('Z','+00:00')) for e in entries)
        elapsed_h = max(0.01, (now - first_ts).total_seconds() / 3600)
        rate_per_h = total_tokens / elapsed_h
        remaining_h = remaining / rate_per_h if rate_per_h > 0 else 0
        print(f' Rate   : ~{rate_per_h/1000:.0f}k tokens/hour at current pace')
        print(f' Est.   : ~{remaining_h*60:.0f} min remaining at this rate')
else:
    print(f' Limit  : not yet calibrated')
    print(f'  → When you hit a rate limit, note the total and run:')
    print(f'    python3 -c "import json; d=json.load(open(\\\"~/.claude/usage-calibration.json\\\")); d[\\\"known_limit_tokens\\\"]={total_tokens}; ..."')
    print(f'  → Or edit ~/.claude/usage-calibration.json directly')

if by_type:
    print()
    print(' By operation type:')
    for t, v in sorted(by_type.items(), key=lambda x: -x[1]['tokens']):
        print(f'   {t:<32} {v["tokens"]:>9,}  ({v["count"]}x)')

if by_session:
    print()
    print(' By session:')
    for s, v in sorted(by_session.items(), key=lambda x: -x[1]['tokens']):
        print(f'   {s:<14} {v["tokens"]:>9,}  ({v["count"]} ops)')

if rate_limit_events:
    print()
    print(f' Rate-limit events: {len(rate_limit_events)}')
    last = rate_limit_events[-1]
    print(f'   Last: {last.get("ts","?")} — {last.get("tokens_before","?"):,} tokens before limit hit')

print('═══════════════════════════════════════════════')
PYEOF
