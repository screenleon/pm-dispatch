#!/usr/bin/env bash
#
# Print a single Markdown weekly usage report to stdout.
#
# Data sources:
# - Claude: read-only inspection of "$HOME/.claude/stats-cache.json" with jq.
# - Codex: read-only scan of "$HOME/.codex/sessions/YYYY/MM/DD" JSONL files.
#
# This script does not write to, mutate, compact, or regenerate Claude or Codex
# data. Missing tools, missing files, and unexpected schemas degrade to markers,
# zeros, or dashes, and the script exits 0.
#
# TZ note: dates are computed using the local system timezone. Run with
# TZ=UTC prefix if UTC-anchored output is needed.

LC_ALL=C
IFS=$' \t\n'
set -uo pipefail

CLAUDE_STATS="${HOME}/.claude/stats-cache.json"
CODEX_SESSIONS="${HOME}/.codex/sessions"

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# date_for_offset N: print YYYY-MM-DD for N days ago.
# Supports GNU date (-d) and BSD date (-v).
date_for_offset() {
  date -d "$1 days ago" +%F 2>/dev/null \
    || date -v -${1}d +%F 2>/dev/null \
    || true
}

START="$(date_for_offset 6)"
END="$(date_for_offset 0)"

if [ -z "$START" ]; then
  START="unknown"
fi

if [ -z "$END" ]; then
  END="unknown"
fi

# file_mtime PATH: print Unix mtime integer.
# Supports GNU stat (-c) and BSD stat (-f).
file_mtime() {
  stat -c %Y "$1" 2>/dev/null \
    || stat -f %m "$1" 2>/dev/null \
    || true
}

# file_size PATH: print byte size integer.
# Supports GNU stat (-c) and BSD stat (-f).
file_size() {
  stat -c %s "$1" 2>/dev/null \
    || stat -f %z "$1" 2>/dev/null \
    || true
}

# epoch_to_date EPOCH: convert Unix timestamp to YYYY-MM-DD.
# Supports GNU date (-d @) and BSD date (-r).
epoch_to_date() {
  date -d "@$1" +%F 2>/dev/null \
    || date -r "$1" +%F 2>/dev/null \
    || true
}

claude_last_computed() {
  local computed="" mtime=""

  if [ -f "$CLAUDE_STATS" ] && has_cmd jq; then
    computed="$(jq -r '.lastComputedDate // .lastComputed // .computedAt // empty' "$CLAUDE_STATS" 2>/dev/null || true)"
  fi

  if [ -n "$computed" ] && [ "$computed" != "null" ]; then
    printf '%s\n' "${computed:0:10}"
    return 0
  fi

  if [ -f "$CLAUDE_STATS" ]; then
    mtime="$(file_mtime "$CLAUDE_STATS")"
    if [ -n "$mtime" ]; then
      epoch_to_date "$mtime"
      return 0
    fi
  fi

  printf 'n/a\n'
}

claude_schema() {
  if [ ! -f "$CLAUDE_STATS" ] || ! has_cmd jq; then
    printf 'unavailable\n'
    return 0
  fi

  # Simplified: detect by key presence/type only, without separate
  # populated-vs-empty branches. Empty arrays/objects return zeros in
  # claude_counts_for_date regardless of schema variant.
  jq -r '
    if (.dailyActivity | type) == "array" then "dailyActivity-array"
    elif (.dailyActivity | type) == "object" then "dailyActivity-object"
    elif (.days | type) == "array" then "days-array"
    elif (.daily | type) == "object" then "daily-object"
    else "unknown"
    end
  ' "$CLAUDE_STATS" 2>/dev/null || true
}

claude_counts_for_date() {
  local report_date="$1"
  local schema="$2"

  if [ ! -f "$CLAUDE_STATS" ] || ! has_cmd jq || [ "$schema" = "unknown" ] || [ "$schema" = "unavailable" ]; then
    printf '0|0|0\n'
    return 0
  fi

  jq -r --arg d "$report_date" --arg schema "$schema" '
    def n($v): ($v // 0 | tonumber? // 0);
    def row:
      if $schema == "dailyActivity-array" then
        (.dailyActivity[]? | select(.date == $d)) // {}
      elif $schema == "dailyActivity-object" then
        .dailyActivity[$d] // {}
      elif $schema == "days-array" then
        (.days[]? | select(.date == $d)) // {}
      elif $schema == "daily-object" then
        .daily[$d] // {}
      else
        {}
      end;
    row as $r
    | [
        n($r.messageCount // $r.messages // $r.message_count),
        n($r.sessionCount // $r.sessions // $r.session_count),
        n($r.toolCallCount // $r.toolCalls // $r.tool_calls // $r.toolUseCount)
      ]
    | @tsv
  ' "$CLAUDE_STATS" 2>/dev/null | {
    IFS=$'\t' read -r messages sessions tools || true
    printf '%s|%s|%s\n' "${messages:-0}" "${sessions:-0}" "${tools:-0}"
  }
}

print_claude_model_tokens() {
  local schema_mismatch="$1"

  printf 'Per-model tokens last 7d aggregate\n'

  if ! has_cmd jq; then
    printf '(tool missing: jq)\n'
    return 0
  fi

  if [ ! -f "$CLAUDE_STATS" ]; then
    printf -- '- none: 0\n'
    return 0
  fi

  if [ "$schema_mismatch" = "1" ]; then
    printf -- '- none: 0\n'
    return 0
  fi

  jq -r --arg start "$START" --arg stop "$END" '
    def token_entries:
      if (.dailyModelTokens | type) == "array" then
        .dailyModelTokens[]?
        | select((.date // "") >= $start and (.date // "") <= $stop)
        | (.tokensByModel // .models // {})
        | to_entries[]?
      elif (.dailyModelTokens | type) == "object" then
        .dailyModelTokens
        | to_entries[]?
        | select(.key >= $start and .key <= $stop)
        | (.value.tokensByModel // .value.models // .value // {})
        | to_entries[]?
      else
        empty
      end;
    [token_entries]
    | group_by(.key)
    | map({model: .[0].key, tokens: (map(.value | tonumber? // 0) | add)})
    | sort_by(.model)
    | if length == 0 then
        "- none: 0"
      else
        .[] | "- \(.model): \(.tokens)"
      end
  ' "$CLAUDE_STATS" 2>/dev/null || true
}

codex_counts_for_date() {
  local report_date="$1"
  local year="${report_date:0:4}"
  local month="${report_date:5:2}"
  local day="${report_date:8:2}"
  local dir="${CODEX_SESSIONS}/${year}/${month}/${day}"
  local sessions=0
  local bytes=0
  local size=""

  if [ ! -d "$dir" ]; then
    printf '0|0\n'
    return 0
  fi

  while IFS= read -r -d '' file; do
    sessions=$((sessions + 1))
    size="$(file_size "$file")"
    if [ -n "$size" ]; then
      bytes=$((bytes + size))
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.jsonl' -print0 2>/dev/null || true)

  printf '%s|%s\n' "$sessions" "$bytes"
}

printf '# Weekly Usage Report %s ~ %s\n' "$START" "$END"
printf '\n'
printf '## Claude\n'

if [ ! -f "$CLAUDE_STATS" ]; then
  printf '(stats-cache.json not found)\n'
else
  # Soft stale: >2 days old — data may be slightly behind.
  # Hard stale: >14 days old — data is likely meaningless.
  if [ -n "$(find "$CLAUDE_STATS" -maxdepth 0 -type f -mtime +14 -print 2>/dev/null || true)" ]; then
    printf '(stale >14d, last computed %s)\n' "$(claude_last_computed)"
  elif [ -n "$(find "$CLAUDE_STATS" -maxdepth 0 -type f -mtime +2 -print 2>/dev/null || true)" ]; then
    printf '(slightly stale, last computed %s)\n' "$(claude_last_computed)"
  fi
fi

SCHEMA="$(claude_schema)"
SCHEMA_MISMATCH=0
if [ "$SCHEMA" = "unknown" ]; then
  SCHEMA_MISMATCH=1
  printf '<!-- schema-mismatch: Claude stats-cache.json schema not detected -->\n'
fi

printf '| Date | Messages | Sessions | Tool calls |\n'
printf '| --- | --- | --- | --- |\n'

for offset in 6 5 4 3 2 1 0; do
  report_date="$(date_for_offset "$offset")"
  if [ -z "$report_date" ]; then
    report_date="unknown"
  fi
  counts="$(claude_counts_for_date "$report_date" "$SCHEMA")"
  messages="${counts%%|*}"
  rest="${counts#*|}"
  sessions="${rest%%|*}"
  tools="${rest#*|}"
  printf '| %s | %s | %s | %s |\n' "$report_date" "${messages:-0}" "${sessions:-0}" "${tools:-0}"
done

printf '\n'
print_claude_model_tokens "$SCHEMA_MISMATCH"
printf '\n'
printf '\n'
printf '## Codex\n'
printf '| Date | Sessions | JSONL bytes proxy |\n'
printf '| --- | --- | --- |\n'

for offset in 6 5 4 3 2 1 0; do
  report_date="$(date_for_offset "$offset")"
  if [ -z "$report_date" ]; then
    report_date="unknown"
  fi
  counts="$(codex_counts_for_date "$report_date")"
  sessions="${counts%%|*}"
  bytes="${counts#*|}"
  printf '| %s | %s | %s |\n' "$report_date" "${sessions:-0}" "${bytes:-0}"
done

printf '\n'
printf -- '---\n'
if [ ! -f "$CLAUDE_STATS" ]; then
  printf 'Data freshness: Claude stats-cache.json not found. Codex session files scanned live.\n'
else
  printf 'Data freshness: Claude stats-cache.json last computed %s. Codex session files scanned live. Codex byte counts are an activity proxy, not token counts.\n' "$(claude_last_computed)"
fi

exit 0
