#!/usr/bin/env bash
# Migrate routing_log.md JSONL rows into state-store events.jsonl.

set -uo pipefail

BASH_DISPATCH_KIND="run.dispatched"
AGENT_DISPATCH_KIND="run.dispatched"

AUTO_START="<!-- routing-log:auto-block:start -->"
AUTO_END="<!-- routing-log:auto-block:end -->"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/state-writer.sh
. "$SCRIPT_DIR/lib/state-writer.sh"
# shellcheck source=scripts/lib/memory.sh
. "$SCRIPT_DIR/lib/memory.sh"

CWD="$PWD"
if [[ "${1:-}" == "--cwd" ]]; then
  CWD="${2:-}"
  if [[ -z "$CWD" ]]; then
    printf 'migrate-routing-to-events: --cwd requires a path\n' >&2
    exit 2
  fi
elif [[ $# -gt 0 ]]; then
  printf 'migrate-routing-to-events: unknown flag %s\n' "$1" >&2
  exit 2
fi

if [[ -n "${CLAUDE_ROUTING_LOG_PATH:-}" ]]; then
  TARGET="$CLAUDE_ROUTING_LOG_PATH"
elif [[ -n "${CLAUDE_ROUTING_LOG_DIR:-}" ]]; then
  TARGET="$CLAUDE_ROUTING_LOG_DIR/routing_log.md"
else
  if ! MEMORY_DIR="$(find_memory_dir "$CWD")"; then
    printf 'migrate-routing-to-events: routing_log.md not found for cwd=%s\n' "$CWD" >&2
    exit 0
  fi
  TARGET="$MEMORY_DIR/routing_log.md"
fi

if [[ ! -f "$TARGET" ]]; then
  printf 'migrate-routing-to-events: routing_log.md not found: %s\n' "$TARGET" >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'migrate-routing-to-events: jq is required\n' >&2
  exit 2
fi

audit() {
  printf 'migrate-routing-to-events: %s\n' "$*" >&2
}

routing_kind_table() {
  printf 'bash-dispatch\t%s\n' "$BASH_DISPATCH_KIND"
  printf 'agent-dispatch\t%s\n' "$AGENT_DISPATCH_KIND"
}

event_kind_for_routing_kind() {
  local routing_kind="$1" table_kind event_kind
  while IFS=$'\t' read -r table_kind event_kind; do
    if [[ "$routing_kind" == "$table_kind" ]]; then
      printf '%s' "$event_kind"
      return 0
    fi
  done < <(routing_kind_table)
  return 1
}

normalize_event_ts() {
  local ts="$1"
  if [[ "$ts" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?)(Z|[+-][0-9]{2}:[0-9]{2})$ ]]; then
    printf '%s' "$ts"
    return 0
  fi
  if [[ "$ts" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?)([+-][0-9]{2})([0-9]{2})$ ]]; then
    printf '%s%s:%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
    return 0
  fi
  return 1
}

compact_ts_from_event_ts() {
  local ts="$1" seconds
  if [[ "$ts" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})$ ]]; then
    seconds="${BASH_REMATCH[1]}Z"
    printf '%s' "$seconds" | tr -cd '[:alnum:]'
    return 0
  fi
  return 1
}

load_seen_event_ids() {
  local events_file="$1"
  [[ -f "$events_file" ]] || return 0
  jq -r 'select(type == "object" and (.id | type == "string")) | .id' "$events_file" 2>/dev/null || true
}

event_seen() {
  local event_id="$1"
  printf '%s\n' "$seen_event_ids" | grep -Fxq "$event_id"
}

_SW_REPO_ROOT="$CWD"
proj_dir="$(_sw_project_dir)"
events_file="$proj_dir/events.jsonl"
seen_event_ids="$(load_seen_event_ids "$events_file")"

migrated=0
skipped=0
rows=0

while IFS= read -r row || [[ -n "$row" ]]; do
  [[ -n "$row" ]] || continue
  rows=$((rows + 1))

  if ! parsed="$(printf '%s' "$row" | jq -r '[.ts, .session_id, .kind] | @tsv' 2>/dev/null)"; then
    audit "skipping malformed JSON row"
    skipped=$((skipped + 1))
    continue
  fi
  IFS=$'\t' read -r ts session_id routing_kind <<EOF
$parsed
EOF

  if ! event_kind="$(event_kind_for_routing_kind "$routing_kind")"; then
    audit "skipping unknown kind: $routing_kind"
    skipped=$((skipped + 1))
    continue
  fi
  if ! event_ts="$(normalize_event_ts "$ts")"; then
    audit "skipping row with invalid ts: $ts"
    skipped=$((skipped + 1))
    continue
  fi
  if ! ts_compact="$(compact_ts_from_event_ts "$event_ts")"; then
    audit "skipping row with invalid event id timestamp: $ts"
    skipped=$((skipped + 1))
    continue
  fi

  session_6="${session_id:0:6}"
  if [[ ! "$session_6" =~ ^[a-f0-9]{6}$ ]]; then
    audit "skipping row with invalid session_id prefix: $session_id"
    skipped=$((skipped + 1))
    continue
  fi

  row_hash="$(printf '%s' "$row" | sha256sum | cut -c1-8)"
  event_id="evt-${ts_compact}-${session_6}-${row_hash}"
  subject_id="run-${ts_compact}-${session_6}-${row_hash}"
  if event_seen "$event_id"; then
    skipped=$((skipped + 1))
    continue
  fi

  if ! event_json="$(printf '%s' "$row" | jq -c \
      --arg id "$event_id" \
      --arg ts "$event_ts" \
      --arg kind "$event_kind" \
      --arg subject_id "$subject_id" \
      '{
        id: $id,
        schema_version: 1,
        ts: $ts,
        kind: $kind,
        subject_type: "run",
        subject_id: $subject_id,
        actor: "hook-routing-log:migrator",
        payload: {
          run_id: $subject_id,
          state: "dispatched",
          from_state: "pending",
          to_state: "dispatched",
          legacy_kind: (.kind // null),
          session_id: (.session_id // null),
          subagent_type: (.subagent_type // null),
          brief_file: (.brief_file // null),
          goal_excerpt: (.goal_excerpt // null),
          q_hit: (.q_hit // null),
          second_thoughts: (.second_thoughts // null)
        }
      }' 2>/dev/null)"; then
    audit "skipping row that could not be converted"
    skipped=$((skipped + 1))
    continue
  fi

  if events_append "$event_json"; then
    migrated=$((migrated + 1))
    seen_event_ids="${seen_event_ids}"$'\n'"$event_id"
  else
    audit "failed to append event: $event_id"
    exit 1
  fi
done < <(
  awk -v start="$AUTO_START" -v end="$AUTO_END" '
    $0 == start { in_block=1; next }
    $0 == end { in_block=0; next }
    in_block && $0 ~ /^\{/ { print }
  ' "$TARGET"
)

if [[ "$rows" -eq 0 ]]; then
  audit "no routing rows found"
else
  audit "migrated $migrated event(s), skipped $skipped row(s)"
fi
exit 0
