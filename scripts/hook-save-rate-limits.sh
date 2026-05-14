#!/usr/bin/env bash
# hook-save-rate-limits.sh — StatusLine hook: save Claude rate-limit data.
# Receives JSON payload via stdin from Claude Code StatusLine event.
# Writes ~/.claude/rate-limits.json for use by token-usage.sh --remaining.
# Chains to the previous statusLine command if statusline-chain.conf exists.
set -euo pipefail

payload=$(cat)
[[ -z "$payload" ]] && exit 0

_config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
_tmp=$(mktemp)
trap 'rm -f "$_tmp"' EXIT
printf '%s' "$payload" > "$_tmp"

python3 - "$_tmp" "$_config_dir" << 'PYEOF'
import json, sys, time, os

payload_file, config_dir = sys.argv[1], sys.argv[2]
try:
    with open(payload_file) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

rl = data.get('rate_limits')
if not rl:
    sys.exit(0)

out = {'updated_at': int(time.time())}
for key in ('five_hour', 'seven_day'):
    part = rl.get(key)
    if part:
        out[key] = {'used_percentage': part.get('used_percentage', 0),
                    'resets_at': part.get('resets_at', 0)}

os.makedirs(config_dir, exist_ok=True)
with open(os.path.join(config_dir, 'rate-limits.json'), 'w') as f:
    json.dump(out, f)
PYEOF

# Chain to previous statusLine command if configured.
# Use bash -c to preserve full command-string semantics (quoted args,
# bash -c wrappers, env prefixes, etc.) from the original statusLine.command.
_chain_conf="${_config_dir}/statusline-chain.conf"
if [[ -f "$_chain_conf" ]]; then
    _chain=$(head -1 "$_chain_conf")
    if [[ -n "$_chain" ]]; then
        printf '%s' "$payload" | bash -c "$_chain" || true
    fi
fi

exit 0
