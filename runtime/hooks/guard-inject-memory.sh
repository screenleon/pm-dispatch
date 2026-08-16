#!/usr/bin/env bash
# guard-inject-memory.sh — host-neutral UserPromptSubmit canonical-memory adapter.
# Claude and Codex both provide cwd/prompt on stdin and accept plain stdout as
# additional context. Hosts without that contract use `pmctl pm prepare`.
set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "$0")/../lib/pmctl-memory.sh"
if ! declare -F retrieval_extract_terms >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  . "$(dirname "$0")/../lib/retrieval-terms.sh"
fi

MAX_INJECT_ENTRIES=20
MAX_INJECT_BYTES=3000

# Usage-based ranking knobs (integer-only; see lib/memory.sh).
# Decay threshold: global keyword-hit events before W-TinyLFU halving.
MEMORY_DECAY_THRESHOLD="${PM_MEMORY_DECAY_THRESHOLD:-256}"
# Keyword tier weight: composite = keyword_score * WEIGHT + frecency. Keeping
# WEIGHT above the max attainable frecency makes ranking layered — any card the
# current prompt's keywords hit outranks every non-hit card, with frecency only
# ordering within each tier.
MEMORY_KEYWORD_WEIGHT="${PM_MEMORY_FRECENCY_KEYWORD_WEIGHT:-100000}"

payload=$(cat)
[[ -z "$payload" ]] && exit 0

_tmp=$(mktemp)
_t2tmp=$(mktemp)
trap 'rm -f "$_tmp" "$_t2tmp"' EXIT
printf '%s' "$payload" > "$_tmp"

cwd=$(jq -r 'if (.cwd | type) == "string" then .cwd else empty end' "$_tmp" 2>/dev/null) || cwd=""
[[ -n "$cwd" ]] || exit 0

memory_resolution=""
memory_rc=0
memory_resolution="$(pmctl_memory_resolve --repo-root "$cwd" --allow-non-git --json 2>/dev/null)" || memory_rc=$?
if [[ "$memory_rc" -eq 3 ]]; then
  reason="$(jq -r '.reason // "invalid explicit canonical memory"' <<<"$memory_resolution" 2>/dev/null || printf 'invalid explicit canonical memory')"
  jq -cn --arg reason "pmctl canonical memory configuration is invalid: $reason" \
    '{decision:"block",reason:$reason}'
  exit 0
fi
[[ "$memory_rc" -eq 0 ]] || exit 0
memory_dir="$(jq -r '.memory_dir // empty' <<<"$memory_resolution")"
memory_project_key="$(jq -r '.project_key // empty' <<<"$memory_resolution")"
memory_resolution_source="$(jq -r '.resolution_source // "none"' <<<"$memory_resolution")"
[[ -n "$memory_dir" ]] || exit 0
memory_path="$memory_dir/MEMORY.md"
[[ -f "$memory_path" ]] || exit 0

# Load usage telemetry (read-only snapshot; ranking uses pre-access state).
usage_sidecar=$(memory_usage_sidecar_path "$memory_dir")
today_day=$(( $(date +%s) / 86400 ))
declare -A _usage_acc=() _usage_last=()
if [[ -f "$usage_sidecar" || ( "$usage_sidecar" == *.sqlite3 && -f "${usage_sidecar%.sqlite3}.tsv" ) ]]; then
  while IFS=$'\t' read -r _u_rel _u_acc _u_last; do
    [[ -z "$_u_rel" || "$_u_rel" == \#* ]] && continue
    [[ "$_u_acc"  =~ ^[0-9]+$ ]] || _u_acc=0
    [[ "$_u_last" =~ ^[0-9]+$ ]] || _u_last=0
    _usage_acc["$_u_rel"]="$_u_acc"
    _usage_last["$_u_rel"]="$_u_last"
  done < <(memory_usage_read "$usage_sidecar")
fi
# Relpaths whose access_count should be incremented this run (keyword hits).
usage_hits=()

index_lines=()
while IFS= read -r _line; do
  index_lines+=("$_line")
done < <(grep '^- ' "$memory_path" 2>/dev/null) || true
[[ "${#index_lines[@]}" -gt 0 ]] || exit 0

total_count="${#index_lines[@]}"

# Extract prompt keywords via the shared retrieval term lib (ASCII + CJK).
# English policy stays pre-CC-465: length >= 4 and no stop-list filter.
# CJK overlapping 2-grams come from the shared implementation.
prompt_text=$(jq -r '.prompt // empty' "$_tmp" 2>/dev/null) || prompt_text=""
prompt_kws=()
if [[ -n "$prompt_text" ]]; then
  while IFS= read -r _kw; do
    [[ -n "$_kw" ]] && prompt_kws+=("$_kw")
  done < <(retrieval_extract_terms "$prompt_text" 4 0)
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
  card_file="" card_rel=""
  # Extract card filename from markdown link: [name](file.md)
  _link_re='^\- \[([^]]*)\]\(([^)]*\.md)\)'
  if [[ "$_line" =~ $_link_re ]]; then
    card_rel="${BASH_REMATCH[2]}"
    card_file="$memory_dir/$card_rel"
  fi

  priority=""
  if [[ -n "$card_file" && -f "$card_file" ]]; then
    priority=$(_card_field "$card_file" "priority") || priority=""
  fi

  # tier1 = manual pin only. `status` is lifecycle metadata (used for GC), not
  # an injection priority, so it no longer forces always-inject.
  if [[ "$priority" == "always" ]]; then
    tier1_lines+=("$_line")
  else
    topics_text=""
    if [[ -n "$card_file" && -f "$card_file" ]]; then
      topics_text=$(_card_topics "$card_file") || true
    fi
    score=$(_score "$_line $topics_text")

    # frecency = access_count * age_bucket(last_access); 0 for never-accessed
    # cards. Clamp below the keyword weight so a hit always outranks a non-hit.
    frecency=0
    if [[ -n "$card_rel" ]]; then
      _acc="${_usage_acc["$card_rel"]:-0}"
      if (( _acc > 0 )); then
        _bucket=$(memory_age_bucket "$today_day" "${_usage_last["$card_rel"]:-0}")
        frecency=$(( _acc * _bucket ))
        (( frecency >= MEMORY_KEYWORD_WEIGHT )) && frecency=$(( MEMORY_KEYWORD_WEIGHT - 1 ))
      fi
    fi
    composite=$(( score * MEMORY_KEYWORD_WEIGHT + frecency ))

    # Record a keyword-hit access (counted before budget truncation, so a
    # relevant-but-cold card still accrues signal even when it does not make the
    # cut this run). Pinned tier1 cards are orthogonal to usage and not counted.
    if (( score > 0 )) && [[ -n "$card_rel" ]]; then
      usage_hits+=("$card_rel")
    fi

    # Lifecycle validity gate: stale/superseded cards are demoted to the tail
    # of tier2 regardless of frecency. is_degraded=1 sorts after is_degraded=0.
    is_degraded=0
    if [[ -n "$card_file" && -f "$card_file" ]]; then
      _status=$(_card_field "$card_file" "status") || _status=""
      if [[ "$_status" == "stale" || "$_status" == "superseded" ]]; then
        is_degraded=1
      fi
    fi

    # Store as degraded-flag TAB zero-padded composite TAB sequence TAB line.
    printf '%d\t%010d\t%05d\t%s\n' "$is_degraded" "$composite" "$tier2_count" "$_line" >> "$_t2tmp"
    tier2_count=$((tier2_count + 1))
  fi
done

# Sort tier2 entries by composite score descending (keyword tier first, then
# frecency within tier), stable by original sequence.
sorted_tier2=()
if [[ "$tier2_count" -gt 0 ]]; then
  while IFS= read -r _pair; do
    # Strip "DEGRADED\tCOMPOSITE\tSEQ\t" prefix to recover original line.
    _rest="${_pair#*$'\t'}"   # drop is_degraded
    _rest="${_rest#*$'\t'}"   # drop composite
    sorted_tier2+=("${_rest#*$'\t'}")  # drop seq
  done < <(sort -t$'\t' -k1,1n -k2,2rn -k3,3n "$_t2tmp")
fi

# Persist this run's keyword-hit accesses (and apply periodic decay). SQLite is
# transactionally safe across hook processes; the TSV compatibility fallback
# retains the existing shell lock. Failures remain best-effort.
if [[ "${#usage_hits[@]}" -gt 0 ]]; then
  # The lock file lives beside the sidecar; its directory must exist before
  # serialize_with_lock opens it.
  mkdir -p "$(dirname "$usage_sidecar")" 2>/dev/null || true
  if [[ "$usage_sidecar" == *.sqlite3 ]]; then
    memory_usage_commit "$usage_sidecar" "$MEMORY_DECAY_THRESHOLD" "$today_day" \
      "${usage_hits[@]}" >/dev/null 2>&1 || true
  else
    serialize_with_lock "$usage_sidecar" \
      memory_usage_commit "$usage_sidecar" "$MEMORY_DECAY_THRESHOLD" "$today_day" \
      "${usage_hits[@]}" >/dev/null 2>&1 || true
  fi
fi

# Determine how many tier2 slots remain after tier1
tier1_count="${#tier1_lines[@]}"
remaining_slots=$((MAX_INJECT_ENTRIES - tier1_count))
[[ "$remaining_slots" -lt 0 ]] && remaining_slots=0

# Compute bytes already used by preamble + tier1 (tier1 is never byte-capped)
preamble_line1='=== auto-memory: MEMORY.md index ==='
preamble_line2="Provider: pmctl | authority: canonical | project_key: ${memory_project_key} | resolution: ${memory_resolution_source}"
preamble_line3="Memory dir: ${memory_dir} | ${total_count} cards total | native memory: auxiliary/unknown"
preamble_line4='Use /mem-search <topic> for full retrieval'
bytes_used=$(( ${#preamble_line1} + 1 + ${#preamble_line2} + 1 + ${#preamble_line3} + 1 + ${#preamble_line4} + 1 ))
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
printf '%s\n' "$preamble_line1" "$preamble_line2" "$preamble_line3" "$preamble_line4"

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
    IFS=$'\t' read -r _d_base _d_offset < <(memory_iso8601_normalize "$last_date")

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
