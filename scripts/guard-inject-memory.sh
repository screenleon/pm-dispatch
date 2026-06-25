#!/usr/bin/env bash
# guard-inject-memory.sh — UserPromptSubmit hook: inject MEMORY.md index.
# Receives JSON payload via stdin from Claude Code UserPromptSubmit event.
set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "$0")/lib/memory.sh"

MAX_INJECT_ENTRIES=20
MAX_INJECT_BYTES=3000

payload=$(cat)
[[ -z "$payload" ]] && exit 0

_config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
_tmp=$(mktemp)
_t2tmp=$(mktemp)
trap 'rm -f "$_tmp" "$_t2tmp"' EXIT
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

total_count="${#index_lines[@]}"

# Extract prompt keywords: lowercase words of 4+ chars, sorted unique
prompt_text=$(jq -r '.prompt // empty' "$_tmp" 2>/dev/null) || prompt_text=""
prompt_kws=()
if [[ -n "$prompt_text" ]]; then
  while IFS= read -r _kw; do
    [[ -n "$_kw" ]] && prompt_kws+=("$_kw")
  done < <(printf '%s' "$prompt_text" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | awk 'length>=4' | sort -u)
fi

# Read a single-line YAML field from a card file's frontmatter block
_card_field() {
  local f="$1" field="$2"
  [[ -f "$f" ]] || return 1
  awk -v fld="$field:" '/^---/{if(++n==2) exit; next} n==1 && index($0, fld)==1{sub("^"fld"[[:space:]]*",""); gsub(/^"|"$/,""); print; exit}' "$f"
}

# Read topics list items from a card file's frontmatter
_card_topics() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  awk '/^---/{if(++n==2) exit; next} n==1 && /^topics:/{found=1; next} n==1 && found && /^  - /{sub(/^  - /,""); print; next} n==1 && found && /^[^ \t]/{found=0}' "$f"
}

# Score a text string by how many prompt keywords it contains
_score() {
  local text kw score=0
  text=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  for kw in "${prompt_kws[@]+"${prompt_kws[@]}"}"; do
    [[ "$text" == *"$kw"* ]] && score=$((score + 1))
  done
  printf '%d' "$score"
}

# Classify each index line as tier1 (always-inject) or tier2 (budget-ranked)
tier1_lines=()
tier2_count=0

for _line in "${index_lines[@]}"; do
  card_file=""
  # Extract card filename from markdown link: [name](file.md)
  _link_re='^\- \[([^]]*)\]\(([^)]*\.md)\)'
  if [[ "$_line" =~ $_link_re ]]; then
    card_file="$memory_dir/${BASH_REMATCH[2]}"
  fi

  priority="" card_status=""
  if [[ -n "$card_file" && -f "$card_file" ]]; then
    priority=$(_card_field "$card_file" "priority") || priority=""
    card_status=$(_card_field "$card_file" "status") || card_status=""
  fi

  if [[ "$priority" == "always" || "$card_status" == "active" ]]; then
    tier1_lines+=("$_line")
  else
    topics_text=""
    if [[ -n "$card_file" && -f "$card_file" ]]; then
      topics_text=$(_card_topics "$card_file") || true
    fi
    score=$(_score "$_line $topics_text")
    # Store as zero-padded score TAB sequence TAB line for stable sort
    printf '%05d\t%05d\t%s\n' "$score" "$tier2_count" "$_line" >> "$_t2tmp"
    tier2_count=$((tier2_count + 1))
  fi
done

# Sort tier2 entries by score descending
sorted_tier2=()
if [[ "$tier2_count" -gt 0 ]]; then
  while IFS= read -r _pair; do
    # Strip "SCORE\tSEQ\t" prefix to recover original line
    _rest="${_pair#*$'\t'}"
    sorted_tier2+=("${_rest#*$'\t'}")
  done < <(sort -t$'\t' -k1,1rn -k2,2n "$_t2tmp")
fi

# Determine how many tier2 slots remain after tier1
tier1_count="${#tier1_lines[@]}"
remaining_slots=$((MAX_INJECT_ENTRIES - tier1_count))
[[ "$remaining_slots" -lt 0 ]] && remaining_slots=0

# Compute bytes already used by preamble + tier1 (tier1 is never byte-capped)
preamble_line1='=== auto-memory: MEMORY.md index ==='
preamble_line2="Memory dir: ${memory_dir} | ${total_count} cards total"
preamble_line3='Use /mem-search <topic> for full retrieval'
bytes_used=$(( ${#preamble_line1} + 1 + ${#preamble_line2} + 1 + ${#preamble_line3} + 1 ))
for _line in "${tier1_lines[@]+"${tier1_lines[@]}"}"; do
  bytes_used=$(( bytes_used + ${#_line} + 1 ))
done

# Select tier2 entries within entry and byte budgets
selected_tier2=()
for _line in "${sorted_tier2[@]+"${sorted_tier2[@]}"}"; do
  [[ "${#selected_tier2[@]}" -ge "$remaining_slots" ]] && break
  _lbytes=$(( ${#_line} + 1 ))
  [[ $(( bytes_used + _lbytes )) -gt "$MAX_INJECT_BYTES" ]] && break
  selected_tier2+=("$_line")
  bytes_used=$(( bytes_used + _lbytes ))
done

omitted_count=$(( total_count - tier1_count - "${#selected_tier2[@]}" ))

# Emit preamble
printf '%s\n' "$preamble_line1" "$preamble_line2" "$preamble_line3"

# Emit tier1 (always-inject)
[[ "${#tier1_lines[@]}" -gt 0 ]] && printf '%s\n' "${tier1_lines[@]}"

# Emit selected tier2
[[ "${#selected_tier2[@]}" -gt 0 ]] && printf '%s\n' "${selected_tier2[@]}"

# Omission notice
[[ "$omitted_count" -gt 0 ]] && \
  printf '(%d entries omitted — use /mem-search <topic> to retrieve them)\n' "$omitted_count"

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
