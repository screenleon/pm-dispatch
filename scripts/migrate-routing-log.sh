#!/usr/bin/env bash
# One-time migrator for routing_log.md legacy bullet sections.

set -uo pipefail

AUTO_START="<!-- routing-log:auto-block:start -->"
AUTO_END="<!-- routing-log:auto-block:end -->"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/memory-dir.sh
. "$SCRIPT_DIR/lib/memory-dir.sh"

CWD="$PWD"
if [[ "${1:-}" == "--cwd" ]]; then
  CWD="${2:-}"
  if [[ -z "$CWD" ]]; then
    printf 'migrate-routing-log: --cwd requires a path\n' >&2
    exit 2
  fi
fi

if [[ -n "${CLAUDE_ROUTING_LOG_PATH:-}" ]]; then
  TARGET="$CLAUDE_ROUTING_LOG_PATH"
else
  if ! MEMORY_DIR="$(find_memory_dir "$CWD")"; then
    printf 'migrate-routing-log: failed to discover routing_log.md memory dir for cwd=%s\n' "$CWD" >&2
    exit 1
  fi
  TARGET="$MEMORY_DIR/routing_log.md"
fi

json_escape_into() {
  local target="$1" value="$2"
  if [[ "$value" =~ ^[A-Za-z0-9_:./~+-]+$ ]]; then
    printf -v "$target" '%s' "$value"
    return 0
  fi
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf -v "$target" '%s' "$value"
}

audit() {
  printf 'migrate-routing-log: %s\n' "$*" >&2
}

make_row() {
  local date="$1" task="$2" routed="$3" kind subagent_json="null" task_json ts
  if [[ -z "$task" ]]; then
    audit "skipping malformed bullet dated $date: missing Task line"
    return 1
  fi
  case "$routed" in
    *"main-thread direct"*)
      audit "skipping bullet dated $date: main-thread direct"
      return 1
      ;;
    *Codex*)
      kind="bash-dispatch"
      ;;
    *"Claude (main thread)"*)
      kind="agent-dispatch"
      ;;
    *)
      audit "skipping bullet dated $date: unrecognized Routed to line"
      return 1
      ;;
  esac
  if [[ "$routed" == *subagent* ]]; then
    subagent_json='"codex-executor"'
  fi
  ts="${date}T00:00:00+0000"
  json_escape_into task_json "${task:0:120}"
  printf '{"ts":"%s","session_id":"","kind":"%s","subagent_type":%s,"brief_file":null,"goal_excerpt":"%s","q_hit":null,"second_thoughts":null}\n' \
    "$ts" "$kind" "$subagent_json" "$task_json"
  return 0
}

if [[ ! -f "$TARGET" ]]; then
  audit "$TARGET not found"
  exit 1
fi

if grep -q -F "$AUTO_START" "$TARGET" 2>/dev/null; then
  echo "migrate-routing-log: already migrated, nothing to do"
  exit 0
fi

if [[ -e "${TARGET}.bak" ]]; then
  audit "${TARGET}.bak already exists; refusing to overwrite"
  exit 1
fi

tmp="$(mktemp "${TARGET}.migrate.XXXXXX" 2>/dev/null)" || {
  audit "failed to create temp file"
  exit 1
}
rows_tmp="$(mktemp "${TARGET}.rows.XXXXXX" 2>/dev/null)" || {
  rm -f "$tmp"
  audit "failed to create rows temp file"
  exit 1
}
trap 'rm -f "$tmp" "$rows_tmp"' EXIT

in_bullet=0
current_date=""
current_task=""
current_routed=""
prefix_written=0

flush_bullet() {
  [[ "$in_bullet" == "1" ]] || return 0
  make_row "$current_date" "$current_task" "$current_routed" >> "$rows_tmp" || true
  current_date=""
  current_task=""
  current_routed=""
  in_bullet=0
}

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^##[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]] ]]; then
    flush_bullet
    in_bullet=1
    current_date="${line#'## '}"
    current_date="${current_date:0:10}"
    continue
  fi

  if [[ "$in_bullet" == "1" ]]; then
    case "$line" in
      "- Task:"*)
        current_task="${line#- Task: }"
        ;;
      "- Routed to:"*)
        current_routed="${line#- Routed to: }"
        ;;
    esac
    continue
  fi

  printf '%s\n' "$line" >> "$tmp"
  prefix_written=1
done < "$TARGET"
flush_bullet

if [[ "$prefix_written" != "1" ]]; then
  audit "no content copied"
  exit 1
fi

while [[ -s "$tmp" ]] && [[ "$(tail -n 1 "$tmp")" == "" ]]; do
  head -n -1 "$tmp" > "${tmp}.trim" && mv "${tmp}.trim" "$tmp"
done

{
  printf '\n%s\n' "$AUTO_START"
  cat "$rows_tmp"
  printf '%s\n' "$AUTO_END"
} >> "$tmp"

cp "$TARGET" "${TARGET}.bak" || {
  audit "failed to create backup"
  exit 1
}
mv "$tmp" "$TARGET" || {
  audit "failed to rewrite target"
  exit 1
}
trap - EXIT
rm -f "$rows_tmp"
echo "migrate-routing-log: migrated $(grep -c '^{' "$TARGET" 2>/dev/null || echo 0) row(s)"
exit 0
