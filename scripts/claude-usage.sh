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
MODE="--5h"
REMAINING_PCT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --today|--all|--[0-9]*h)
      MODE="$1"; shift ;;
    --remaining)
      [[ $# -ge 2 ]] || { echo "claude-usage: --remaining requires a value" >&2; exit 2; }
      REMAINING_PCT="$2"; shift 2 ;;
    *)
      echo "claude-usage: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$LOGFILE" ]]; then
  echo "No usage log at $LOGFILE"
  echo "Use: bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note]"
  exit 0
fi

python3 - "$MODE" "$LOGFILE" "$CALIB_FILE" "$REMAINING_PCT" << 'PYEOF'
import sys, json, re
from collections import defaultdict
from datetime import datetime, timezone, timedelta

mode              = sys.argv[1]
logfile           = sys.argv[2]
calib_file        = sys.argv[3]
remaining_pct_raw = sys.argv[4] if len(sys.argv) > 4 else ''

# Validate mode before doing any work
if mode not in ('--today', '--all') and not re.fullmatch(r'--\d+h', mode):
    sys.stderr.write(f'claude-usage: unknown mode: {mode!r}\n')
    sys.stderr.write('Usage: claude-usage.sh [--today|--all|--Nh]  (default: --5h)\n')
    sys.exit(2)

remaining_pct = None
if remaining_pct_raw != '':
    try:
        remaining_pct = float(remaining_pct_raw)
    except ValueError:
        sys.stderr.write(f'claude-usage: --remaining must be a number, got: {remaining_pct_raw!r}\n')
        sys.exit(2)
    if not (0.0 <= remaining_pct <= 100.0):
        sys.stderr.write(f'claude-usage: --remaining must be 0–100, got: {remaining_pct}\n')
        sys.exit(2)

# Load entries — skip malformed lines and entries missing required 'ts' field
entries = []
skipped = 0
with open(logfile) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        try:
            entry = json.loads(line)
            if 'ts' not in entry:
                skipped += 1
                continue
            entries.append(entry)
        except (json.JSONDecodeError, ValueError):
            skipped += 1

if skipped:
    sys.stderr.write(f'  (warning: {skipped} malformed/incomplete line(s) skipped)\n')

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

# Load calibration — distinguish missing file (silent) from corrupt file (warn)
known_limit = None
rate_limit_events = []
try:
    with open(calib_file) as f:
        calib = json.load(f)
        known_limit = calib.get('known_limit_tokens')
        rate_limit_events = calib.get('rate_limit_events', [])
except FileNotFoundError:
    pass
except (json.JSONDecodeError, ValueError) as ex:
    sys.stderr.write(f'  (warning: calibration file malformed — {ex})\n')

def entry_pool(entry):
    pool = entry.get('pool') or 'claude'
    return pool if pool in ('claude', 'codex', 'spark') else 'claude'

claude_entries = [e for e in entries if entry_pool(e) == 'claude']
codex_entries  = [e for e in entries if entry_pool(e) == 'codex']
spark_entries  = [e for e in entries if entry_pool(e) == 'spark']

claude_log_tokens = sum(e.get('tokens', 0) for e in claude_entries)
codex_log_tokens  = sum(e.get('tokens', 0) for e in codex_entries)
spark_log_tokens  = sum(e.get('tokens', 0) for e in spark_entries)
codex_tokens      = codex_log_tokens  # from usage-tracker.jsonl pool=codex entries only
codex_dispatches  = len(codex_entries)
total_tokens      = claude_log_tokens + codex_tokens + spark_log_tokens
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
print(f' Claude  : {claude_log_tokens:,} tokens  (~{claude_log_tokens/1000:.0f}k)')
print(f' Codex   : {codex_tokens:,} tokens  ({codex_dispatches} logged)  [separate quota]')
if spark_log_tokens > 0:
    print(f' Spark   : {spark_log_tokens:,} tokens  [separate quota]')
print(f' Total   : {total_tokens:,} tokens  (~{total_tokens/1000:.0f}k)')

if known_limit:
    pct = claude_log_tokens / known_limit * 100
    remaining = max(0, known_limit - claude_log_tokens)
    bar_filled = min(20, int(pct / 5))
    bar = '█' * bar_filled + '░' * (20 - bar_filled)
    print(f' Limit  : {known_limit:,} tokens (calibrated)')
    print(f' Used   : [{bar}] {pct:.1f}%')
    print(f' Remain : ~{remaining:,} tokens')
    if claude_log_tokens > 0 and len(claude_entries) > 1:
        # Estimate based on current session rate
        first_ts = min(datetime.fromisoformat(e['ts'].replace('Z','+00:00')) for e in claude_entries)
        elapsed_h = max(0.01, (now - first_ts).total_seconds() / 3600)
        rate_per_h = claude_log_tokens / elapsed_h
        remaining_h = remaining / rate_per_h if rate_per_h > 0 else 0
        print(f' Rate   : ~{rate_per_h/1000:.0f}k tokens/hour at current pace')
        print(f' Est.   : ~{remaining_h*60:.0f} min remaining at this rate')
else:
    print(f' Limit  : not yet calibrated')
    if claude_log_tokens > 0:
        print(f'  -> Edit ~/.claude/usage-calibration.json and set:')
        print(f'       "known_limit_tokens": {claude_log_tokens}')
        print(f'  -> Then re-run to see % used and estimated time remaining')
    else:
        print(f'  -> No Claude-pool log data in this window; calibrate after Claude usage is logged')

if remaining_pct is not None:
    print()
    print('─' * 47)
    print(' Remaining Capacity Estimate')
    print('─' * 47)
    print(f' Remaining (from dashboard): {remaining_pct:.1f}%')
    print(f' Tokens used (Claude pool) : {claude_log_tokens:,}')
    if codex_tokens > 0 or spark_log_tokens > 0:
        print(f' Separate quota tokens     : Codex {codex_tokens:,}  Spark {spark_log_tokens:,}')

    used_pct = 100.0 - remaining_pct

    inferred_total    = None
    calibration_total = None
    remaining_tokens  = None
    method_label      = ''

    if known_limit and known_limit > 0:
        calibration_total = known_limit
        remaining_tokens  = int(known_limit * remaining_pct / 100)
        method_label      = 'from calibration'

    if used_pct > 0 and claude_log_tokens > 0:
        inferred_total = int(claude_log_tokens / (used_pct / 100))
        if remaining_tokens is None:
            remaining_tokens = int(inferred_total * remaining_pct / 100)
            method_label     = 'inferred from log'

    if inferred_total is not None:
        print(f' Inferred total limit      : {inferred_total:,} tokens')
    if calibration_total is not None:
        print(f' Calibrated limit          : {calibration_total:,} tokens')
    if inferred_total is not None and calibration_total is not None:
        diff_pct = abs(inferred_total - calibration_total) / calibration_total * 100
        if diff_pct > 10:
            sys.stderr.write(
                f'  (note: inferred {inferred_total:,} differs from calibrated '
                f'{calibration_total:,} by {diff_pct:.0f}% — consider recalibrating)\n'
            )

    if remaining_tokens is None:
        print(f' Remaining tokens          : cannot estimate (0% used and no calibration)')
        if claude_log_tokens == 0:
            print(' Estimated time remaining  : no Claude log data — rate unknown')
    else:
        print(f' Remaining tokens          : ~{remaining_tokens:,}  [{method_label}]')

        first_ts = None
        if len(claude_entries) > 1:
            first_ts = min(datetime.fromisoformat(e['ts'].replace('Z', '+00:00')) for e in claude_entries)

        if remaining_tokens > 0 and claude_log_tokens > 0 and first_ts is not None:
            elapsed_h  = max(0.01, (now - first_ts).total_seconds() / 3600)
            rate_per_h = claude_log_tokens / elapsed_h
            if rate_per_h > 0:
                remaining_h = remaining_tokens / rate_per_h
                eta_utc     = now + timedelta(hours=remaining_h)
                eta_str     = eta_utc.strftime('%H:%M UTC')
                print(f' Current rate              : ~{rate_per_h/1000:.1f}k tokens/hr  (Claude only)')
                print(f' Estimated time remaining  : ~{remaining_h:.1f} hrs  (until ~{eta_str})')
        elif claude_log_tokens == 0:
            print(' Estimated time remaining  : no Claude log data — rate unknown')
        elif first_ts is None:
            print(f' Estimated time remaining  : cannot estimate (need ≥2 data points for rate)')

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
