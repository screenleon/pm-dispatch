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

if jq -e '.rate_limits | objects | select(length > 0)' "$_tmp" >/dev/null 2>&1; then
    now_ts=$(date +%s)
    out=$(jq -cn \
      --argjson rl "$(jq '.rate_limits' "$_tmp")" \
      --argjson ts "$now_ts" \
      '{updated_at: $ts}
      + (if $rl.five_hour then {five_hour: {used_percentage: ($rl.five_hour.used_percentage // 0), resets_at: ($rl.five_hour.resets_at // 0)}} else {} end)
      + (if $rl.seven_day then {seven_day: {used_percentage: ($rl.seven_day.used_percentage // 0), resets_at: ($rl.seven_day.resets_at // 0)}} else {} end)'
    ) || out=""

    if [[ -n "$out" ]]; then
        _out_dir="$_config_dir"
        mkdir -p "$_out_dir" 2>/dev/null || true
        _rate_tmp=$(mktemp "${_out_dir}/.rate-limits.json.tmp.XXXXXX" 2>/dev/null) || _rate_tmp=""
        if [[ -n "$_rate_tmp" ]]; then
            printf '%s\n' "$out" > "$_rate_tmp"
            mv "$_rate_tmp" "${_out_dir}/rate-limits.json" || {
              printf '  (note: could not write rate-limits.json)\n' >&2
              rm -f "$_rate_tmp"
            }
        else
            printf '  (note: could not write rate-limits.json)\n' >&2
        fi
    fi
fi

# Chain to previous statusLine command if configured.
# Use bash -c to preserve full command-string semantics (quoted args,
# bash -c wrappers, env prefixes, etc.) from the original statusLine.command.
_chain_conf="${_config_dir}/statusline-chain.conf"
if [[ "${CLAUDE_STATUSLINE_CHAIN_ACTIVE:-${CAS_STATUSLINE_CHAIN_ACTIVE:-}}" != "1" && -f "$_chain_conf" ]]; then
    _chain=$(head -1 "$_chain_conf")
    if [[ -n "$_chain" ]]; then
        printf '%s' "$payload" | CLAUDE_STATUSLINE_CHAIN_ACTIVE=1 CAS_STATUSLINE_CHAIN_ACTIVE=1 bash -c "$_chain" || true
    fi
fi

exit 0
