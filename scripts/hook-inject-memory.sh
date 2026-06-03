#!/usr/bin/env bash
# hook-inject-memory.sh — UserPromptSubmit hook: inject MEMORY.md index.
# Receives JSON payload via stdin from Claude Code UserPromptSubmit event.
set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "$0")/lib/memory.sh"

payload=$(cat)
[[ -z "$payload" ]] && exit 0

_config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
_tmp=$(mktemp)
trap 'rm -f "$_tmp"' EXIT
printf '%s' "$payload" > "$_tmp"

cwd=$(jq -r 'if (.cwd | type) == "string" then .cwd else empty end' "$_tmp" 2>/dev/null) || cwd=""
[[ -n "$cwd" ]] || exit 0

memory_dir=$(find_memory_dir "$cwd" "$_config_dir") || exit 0
memory_path="$memory_dir/MEMORY.md"
[[ -f "$memory_path" ]] || exit 0

index_lines=()
while IFS= read -r _line; do
  index_lines+=("$_line")
done < <(grep '^- ' "$memory_path" 2>/dev/null) || true
[[ "${#index_lines[@]}" -gt 0 ]] || exit 0

printf '=== auto-memory: MEMORY.md index ===\n'
printf '%s\n' "${index_lines[@]}"
if [[ "${#index_lines[@]}" -ge 50 ]]; then
  printf '⚠ MEMORY.md has %d entries — run /memory-compress before responding.\n' \
    "${#index_lines[@]}"
fi

# Episode reminder
episodes_file="$memory_dir/episodes.jsonl"
if [[ -f "$episodes_file" ]]; then
  last_date=$(jq -rRs '[split("\n")[] | select(length>0) | try fromjson catch empty] | last // {} | .date // empty' "$episodes_file" 2>/dev/null) || last_date=""
  last_summary=$(jq -rRs '[split("\n")[] | select(length>0) | try fromjson catch empty] | last // {} | .summary // empty' "$episodes_file" 2>/dev/null) || last_summary=""
  if [[ -n "$last_date" ]]; then
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
      'try ((($d | fromdateiso8601) - $offset) as $ts | (now - $ts) / 3600) catch 0' 2>/dev/null) || age_hours=0
    if awk -v h="${age_hours:-0}" 'BEGIN{exit !(h+0 > 24)}'; then
      date_short=$(jq -rn --arg d "${_d_base}Z" \
        'try ($d | fromdateiso8601 | strftime("%Y-%m-%d")) catch ""' 2>/dev/null) || date_short="${last_date:0:10}"
      [[ -n "$date_short" ]] || date_short="${last_date:0:10}"
      if [[ -z "${last_summary// }" ]]; then
        printf '💡 No episode logged since %s — run /mem-log to record this session.\n' "$date_short"
      else
        printf '💡 Last episode: %s — run /mem-log if this session has new learnings.\n' "$date_short"
      fi
    fi
  fi
fi

printf '=== end auto-memory ===\n'

exit 0
