#!/usr/bin/env bash
# hook-session-summary.sh — Stop hook: record session metadata to episodes.jsonl.
# Writes a metadata-only entry (no LLM call). Semantic summary is filled in by
# /mem-log after the user explicitly runs it while the session is still active.
set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "$0")/lib/memory.sh"

payload=$(cat)
[[ -z "$payload" ]] && exit 0

_config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
_tmp=$(mktemp)
trap 'rm -f "$_tmp"' EXIT
printf '%s' "$payload" > "$_tmp"

SESSION_WINDOW_HOURS=4

cwd=$(jq -r 'if (.cwd | type) == "string" then .cwd else empty end' "$_tmp" 2>/dev/null) || cwd=""
[[ -n "$cwd" ]] || exit 0

session_id=$(jq -r 'if (.session_id | type) == "string" then .session_id else empty end' "$_tmp" 2>/dev/null) || session_id=""
[[ -n "$session_id" ]] || exit 0

memory_dir=$(find_memory_dir "$cwd" "$_config_dir") || exit 0
episodes_file="$memory_dir/episodes.jsonl"

# Check for existing entry with this session_id
if [[ -f "$episodes_file" ]]; then
  if jq -eRs --arg sid "$session_id" \
    'split("\n") | map(select(length>0) | try fromjson catch empty) | any(.session_id == $sid)' \
    "$episodes_file" >/dev/null 2>&1; then
    exit 0
  fi

  # Check: most recent cwd entry was written by /mem-log (session_id=="") within SESSION_WINDOW_HOURS
  last_cwd_json=$(jq -cRs --arg cwd "$cwd" \
    '[split("\n")[] | select(length>0) | try fromjson catch empty | select(.cwd == $cwd)] | last // empty' \
    "$episodes_file" 2>/dev/null) || last_cwd_json=""

  if [[ -n "$last_cwd_json" ]]; then
    last_sid=$(printf '%s' "$last_cwd_json" | jq -r '.session_id // empty' 2>/dev/null) || last_sid=""
    last_summary=$(printf '%s' "$last_cwd_json" | jq -r '.summary // empty' 2>/dev/null) || last_summary=""
    last_date=$(printf '%s' "$last_cwd_json" | jq -r '.date // empty' 2>/dev/null) || last_date=""
    if [[ -z "$last_sid" && -n "${last_summary// }" && -n "$last_date" ]]; then
      _d_norm="$last_date"
      if [[ "$last_date" == *.*Z ]]; then
        _d_norm="${last_date%%.*}Z"
      elif [[ "$last_date" == *.*[+-][0-9][0-9]:[0-9][0-9] ]]; then
        _d_clean="${last_date%%.*}"
        _d_frac_suffix="${last_date#*.}"
        if [[ "$_d_frac_suffix" == *+* ]]; then
          _d_norm="${_d_clean}+${_d_frac_suffix##*+}"
        else
          _d_norm="${_d_clean}-${_d_frac_suffix##*-}"
        fi
      elif [[ "$last_date" == *.* ]]; then
        _d_norm="${last_date%%.*}Z"
      elif [[ "$last_date" != *Z && ! "$last_date" =~ [+-][0-9][0-9]:[0-9][0-9]$ ]]; then
        _d_norm="${last_date}Z"
      fi

      _d_base="$_d_norm"
      _d_offset=0
      if [[ "$_d_norm" == *[+-][0-9][0-9]:[0-9][0-9] ]]; then
        _d_suffix="${_d_norm: -6}"
        _d_base="${_d_norm:0:${#_d_norm}-6}"
        _d_offset=$((10#${_d_suffix:1:2} * 3600 + 10#${_d_suffix:4:2} * 60))
        [[ "${_d_suffix:0:1}" == "-" ]] && _d_offset=$((-_d_offset))
      else
        _d_base="${_d_norm%Z}"
      fi

      age_hours=$(jq -rn --arg d "${_d_base}Z" --argjson offset "$_d_offset" \
        'try (($d | fromdateiso8601) - $offset) as $ts | (now - $ts) / 3600 catch 9999' 2>/dev/null) || age_hours=9999
      if awk -v h="${age_hours:-9999}" "BEGIN{exit !(h+0 < $SESSION_WINDOW_HOURS)}"; then
        exit 0
      fi
    fi
  fi
fi

# Write new skeleton entry
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
entry=$(jq -cn \
  --arg date "$now" \
  --arg cwd "$cwd" \
  --arg session_id "$session_id" \
  '{date: $date, cwd: $cwd, session_id: $session_id, summary: ""}')
mkdir -p "$memory_dir"
printf '%s\n' "$entry" >> "$episodes_file"

exit 0
