#!/usr/bin/env bash
# PostToolUse routing decision log hook — DEPRECATED (CC-314).
#
# Previously appended JSONL routing records to routing_log.md. Now exits 0
# immediately. Use migrate-routing-to-events.sh to move legacy records into
# events.jsonl. New installs do not wire this hook (ROUTE_LOG_ENABLED=0).

set -uo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/lib/portable.sh
. "$_SCRIPT_DIR/lib/portable.sh"
# shellcheck source=scripts/lib/memory.sh
. "$_SCRIPT_DIR/lib/memory.sh"

printf '%s\n' 'hook-routing-log: deprecated; routing_log.md writes disabled' >&2
exit 0

HOOK_NAME="hook-routing-log"
LOG_DIR="${CLAUDE_HOOK_LOG_DIR:-$HOME/.claude/logs}"
ERR_FILE="$LOG_DIR/routing-log.err"
unset _SCRIPT_DIR

AUTO_START="<!-- routing-log:auto-block:start -->"
AUTO_END="<!-- routing-log:auto-block:end -->"
MAX_SIZE=1048576

audit() {
  local reason="$1" detail="${2:-}"
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1 2>/dev/null || ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
  printf '%s %s reason=%q detail=%q reason_text="%s"\n' "$ts" "$HOOK_NAME" "$reason" "$detail" "$reason" >> "$ERR_FILE" 2>/dev/null || true
}

json_unescape_into() {
  local target="$1" value="$2"
  value="${value//\\\"/\"}"
  value="${value//\\\\/\\}"
  value="${value//\\\//\/}"
  value="${value//\\n/$'\n'}"
  value="${value//\\r/$'\r'}"
  value="${value//\\t/$'\t'}"
  printf -v "$target" '%s' "$value"
}

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

json_string_after() {
  local target="$1" haystack="$2" anchor="$3" key="$4" scoped
  scoped="$haystack"
  if [[ -n "$anchor" ]]; then
    case "$scoped" in
      *"\"$anchor\""*) scoped="${scoped#*\"$anchor\"}" ;;
      *) return 1 ;;
    esac
  fi

  if [[ "$scoped" =~ \"$key\"[[:space:]]*:[[:space:]]*\"(([^\"\\]|\\.)*)\" ]]; then
    json_unescape_into "$target" "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

extract_brief_file() {
  local command="$1" token next_is_brief=0
  for token in $command; do
    if [[ "$next_is_brief" == "1" ]]; then
      token="${token%\"}"
      token="${token#\"}"
      token="${token%\'}"
      token="${token#\'}"
      [[ "$token" == /* ]] && printf '%s' "$token"
      return 0
    fi
    [[ "$token" == "--brief-file" ]] && next_is_brief=1
  done
  return 0
}

goal_excerpt_from_brief() {
  local brief_file="$1"
  [[ -r "$brief_file" ]] || { printf ''; return 0; }
  awk '
    /^[[:space:]]*goal:[[:space:]]*/ {
      sub(/^[[:space:]]*goal:[[:space:]]*/, "")
      if ($0 != "") { print; exit }
      in_goal=1
      next
    }
    in_goal && NF {
      sub(/^[[:space:]]+/, "")
      print
      exit
    }
  ' "$brief_file" 2>/dev/null | head -n 1 | cut -c 1-120
}

create_minimal_log() {
  local target="$1"
  mkdir -p "$(dirname "$target")" 2>/dev/null || return 1
  {
    printf '%s\n' '---'
    printf '%s\n' 'name: routing_log'
    printf '%s\n' 'type: log'
    printf '%s\n' '---'
    printf '\n'
    printf '%s\n' "$AUTO_START"
    printf '%s\n' "$AUTO_END"
  } > "$target"
}

rotate_if_needed() {
  local target="$1" size tmp
  [[ -f "$target" ]] || return 0
  size=$(file_size_bytes "$target" 2>/dev/null || echo 0)
  (( size > MAX_SIZE )) || return 0

  if ! grep -q -F "$AUTO_START" "$target" 2>/dev/null; then
    audit "rotation skipped; auto-block missing" "$target"
    return 1
  fi

  tmp="$(mktemp "${target}.rotate.XXXXXX" 2>/dev/null)" || {
    audit "rotation temp failed" "$target"
    return 1
  }
  awk -v marker="$AUTO_START" '$0 == marker { exit } { print }' "$target" > "$tmp" 2>/dev/null || {
    rm -f "$tmp"
    audit "rotation header copy failed" "$target"
    return 1
  }
  {
    printf '%s\n' "$AUTO_START"
    printf '%s\n' "$AUTO_END"
  } >> "$tmp" 2>/dev/null || {
    rm -f "$tmp"
    audit "rotation block recreate failed" "$target"
    return 1
  }

  mv -f "$target" "${target}.1" 2>/dev/null || {
    rm -f "$tmp"
    audit "rotation failed" "$target"
    return 1
  }
  mv -f "$tmp" "$target" 2>/dev/null || {
    audit "rotation restore failed" "$target"
    return 1
  }
  return 0
}

_do_append_locked() {
  local target="$1" line="$2" tmp
  if [[ ! -f "$target" ]]; then
    if ! create_minimal_log "$target" 2>/dev/null; then
      audit "create routing log failed" "$target"
      return 1
    fi
  fi
  if ! grep -q -F "$AUTO_START" "$target" 2>/dev/null || ! grep -q -F "$AUTO_END" "$target" 2>/dev/null; then
    audit "auto-block missing; run migrator first" "$target"
    return 1
  fi
  if ! rotate_if_needed "$target"; then
    return 1
  fi
  tmp="$(mktemp "${target}.append.XXXXXX" 2>/dev/null)" || {
    audit "append temp failed" "$target"
    return 1
  }
  if ! awk -v end="$AUTO_END" -v row="$line" '
    $0 == end && !done { print row; done=1 }
    { print }
  ' "$target" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    audit "append rewrite failed" "$target"
    return 1
  fi
  if ! mv -f "$tmp" "$target" 2>/dev/null; then
    rm -f "$tmp"
    audit "append move failed" "$target"
    return 1
  fi
  return 0
}

append_inside_block() {
  local target="$1" line="$2"
  local lockdir
  lockdir="$(dirname "$target")"
  mkdir -p "$lockdir" 2>/dev/null || {
    audit "lock directory failed" "$target"
    return 1
  }
  # Lock parent must exist before flock/mkdir can create the lock file.
  mkdir -p "$LOG_DIR" 2>/dev/null || {
    audit "lock directory failed" "$target"
    return 1
  }
  # Lock files live in LOG_DIR so a non-writable memory dir only prevents
  # rotation/append, not lock acquisition. Global per-LOG_DIR lock key is
  # intentional: appends are short-lived; per-target hashing adds complexity
  # without throughput benefit.
  if ! serialize_with_lock "${LOG_DIR}/routing_log_append" _do_append_locked "$target" "$line"; then
    audit "lock or append failed" "$target"
    return 1
  fi
  return 0
}

[[ "${CLAUDE_ROUTING_LOG_DISABLE:-}" == "1" ]] && exit 0

input="$(cat)"
[[ -z "$input" ]] && exit 0

case "$input" in
  *\{*\}*) ;;
  *)
    audit "malformed JSON on stdin"
    exit 0
    ;;
esac

cwd=""
session_id=""
tool_name=""
json_string_after cwd "$input" "" "cwd" || true
json_string_after session_id "$input" "" "session_id" || true
json_string_after tool_name "$input" "" "tool_name" \
  || json_string_after tool_name "$input" "" "tool" \
  || json_string_after tool_name "$input" tool_use "name" \
  || true

[[ -z "${cwd:-}" ]] && exit 0
[[ -z "$tool_name" ]] && tool_name="?"

kind=""
subagent_type=""
subagent_type_is_null=1
brief_file=""
brief_file_is_null=1
goal_excerpt=""
goal_excerpt_is_null=1

case "$tool_name" in
  Bash)
    command_arg=""
    json_string_after command_arg "$input" tool_input "command" \
      || json_string_after command_arg "$input" "tool" "command" \
      || json_string_after command_arg "$input" params "command" \
      || true
    [[ "$command_arg" == *"scripts/codex-dispatch.sh"* ]] || exit 0
    kind="bash-dispatch"
    brief_file="$(extract_brief_file "$command_arg")"
    if [[ -n "$brief_file" ]]; then
      brief_file_is_null=0
      goal_excerpt="$(goal_excerpt_from_brief "$brief_file")"
      goal_excerpt_is_null=0
    fi
    ;;
  Agent|Task)
    json_string_after subagent_type "$input" tool_input "subagent_type" \
      || json_string_after subagent_type "$input" "" "subagent_type" \
      || json_string_after subagent_type "$input" "tool" "subagent_type" \
      || json_string_after subagent_type "$input" params "subagent_type" \
      || true
    case "$subagent_type" in
      codex-executor|codex_executor|codex) ;;
      *) exit 0 ;;
    esac
    kind="agent-dispatch"
    subagent_type_is_null=0
    ;;
  *)
    exit 0
    ;;
esac

if [[ -n "${CLAUDE_ROUTING_LOG_DIR:-}" && -d "$CLAUDE_ROUTING_LOG_DIR" ]]; then
  memory_dir="$CLAUDE_ROUTING_LOG_DIR"
else
  memory_dir="$(find_memory_dir "$cwd" 2>/dev/null)" || exit 0
fi
[[ -n "$memory_dir" ]] || exit 0

# shellcheck disable=SC2155
memory_file="${memory_dir}/routing_log.md"
printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1 2>/dev/null || ts="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)"
json_escape_into ts_json "$ts"
json_escape_into session_id_json "$session_id"
json_escape_into kind_json "$kind"

subagent_json="null"
if [[ "$subagent_type_is_null" == "0" ]]; then
  json_escape_into subagent_escaped "$subagent_type"
  subagent_json="\"$subagent_escaped\""
fi
brief_json="null"
if [[ "$brief_file_is_null" == "0" ]]; then
  json_escape_into brief_escaped "$brief_file"
  brief_json="\"$brief_escaped\""
fi
goal_json="null"
if [[ "$goal_excerpt_is_null" == "0" ]]; then
  json_escape_into goal_escaped "$goal_excerpt"
  goal_json="\"$goal_escaped\""
fi

printf -v line '{"ts":"%s","session_id":"%s","kind":"%s","subagent_type":%s,"brief_file":%s,"goal_excerpt":%s,"q_hit":null,"second_thoughts":null}' \
  "$ts_json" "$session_id_json" "$kind_json" "$subagent_json" "$brief_json" "$goal_json"

append_inside_block "$memory_file" "$line" || exit 0
exit 0
