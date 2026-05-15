#!/usr/bin/env bash
# PreToolUse metadata trace hook.
#
# Appends one JSONL record per tool invocation to the active project's
# memory/tool-trace.jsonl. This hook is deliberately best-effort: it never
# writes to stdout and never blocks the underlying tool call.

set -uo pipefail

HOOK_NAME="hook-tool-trace"
LOG_DIR="${CLAUDE_HOOK_LOG_DIR:-$HOME/.claude/logs}"
ERR_FILE="$LOG_DIR/tool-trace.err"

audit() {
  local reason="$1" detail="${2:-}"
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1 2>/dev/null || ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
  printf '%s %s reason=%q detail=%q\n' "$ts" "$HOOK_NAME" "$reason" "$detail" >> "$ERR_FILE" 2>/dev/null || true
}

encode_path() {
  local cwd="$1" enc
  enc="-${cwd#/}"
  printf '%s' "${enc//\//-}"
}

json_unescape() {
  local value="$1"
  value="${value//\\\"/\"}"
  value="${value//\\\\/\\}"
  value="${value//\\\//\/}"
  value="${value//\\n/$'\n'}"
  value="${value//\\r/$'\r'}"
  value="${value//\\t/$'\t'}"
  printf '%s' "$value"
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

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
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
      *"\"$anchor\""*) scoped="${scoped#*"\"$anchor\""}" ;;
      *) return 1 ;;
    esac
  fi

  if [[ "$scoped" =~ \"$key\"[[:space:]]*:[[:space:]]*\"(([^\"\\]|\\.)*)\" ]]; then
    json_unescape_into "$target" "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

truncate80() {
  local value="$1"
  printf '%s' "${value:0:80}"
}

find_memory_dir() {
  local cwd="$1" config_dir projects_dir current candidate parent

  if [[ -n "${CLAUDE_TOOL_TRACE_DIR:-}" ]]; then
    [[ -d "$CLAUDE_TOOL_TRACE_DIR" ]] && printf '%s' "$CLAUDE_TOOL_TRACE_DIR"
    return 0
  fi

  config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  projects_dir="$config_dir/projects"
  current="${cwd%/}"

  while [[ -n "$current" ]]; do
    candidate="$projects_dir/$(encode_path "$current")/memory"
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
    parent="$(dirname "$current")"
    [[ "$parent" == "$current" ]] && break
    current="$parent"
  done

  return 1
}

[[ "${CLAUDE_TOOL_TRACE_DISABLE:-}" == "1" ]] && exit 0

input="$(cat)"
[[ -z "$input" ]] && exit 0

# NOTE: strict jq validation deferred to CC-027c — `jq -e .` alone is
# ~25ms/call subprocess startup on this host, exceeding the entire
# per-call budget. Brace heuristic below is best-effort; a malformed
# but key-bearing payload may write a garbage line, which is a data
# quality concern, not security/risk (no leak, no block).
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
[[ -z "$tool_name" ]] && tool_name="?"

if [[ -z "$cwd" && "$input" != *'"cwd"'* ]]; then
  exit 0
fi
if [[ "$input" != *'"cwd"'* && "$input" != *'"tool_name"'* && "$input" != *'"tool"'* ]]; then
  audit "malformed JSON on stdin"
  exit 0
fi

[[ -z "${cwd:-}" ]] && exit 0

memory_dir="$(find_memory_dir "$cwd" 2>/dev/null)" || exit 0
[[ -n "$memory_dir" ]] || exit 0

first_arg=""
first_arg_is_null=0
case "$tool_name" in
  Bash)
    command_arg=""
    json_string_after command_arg "$input" tool_input "command" \
      || json_string_after command_arg "$input" "tool" "command" \
      || json_string_after command_arg "$input" params "command" \
      || true
    read -r first_token _ <<<"$command_arg"
    if [[ "$first_token" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      first_arg_is_null=1
    elif [[ "$first_token" =~ ^[a-z][a-z0-9_-]{0,30}$ ]]; then
      first_arg="$first_token"
    else
      first_arg_is_null=1
    fi
    ;;
  Read|Edit|Write)
    file_arg=""
    json_string_after file_arg "$input" tool_input "file_path" \
      || json_string_after file_arg "$input" "tool" "file_path" \
      || json_string_after file_arg "$input" params "file_path" \
      || true
    if [[ -z "$file_arg" ]]; then
      first_arg_is_null=1
    else
      case "$file_arg" in
        "$cwd"/*)
          first_arg="$(truncate80 "${file_arg#"$cwd/"}")"
          ;;
        "$HOME"/*)
          first_arg="$(truncate80 "$(basename "$file_arg")")"
          ;;
        *)
          first_arg_is_null=1
          ;;
      esac
    fi
    ;;
  Agent|Task)
    subagent_arg=""
    json_string_after subagent_arg "$input" tool_input "subagent_type" \
      || json_string_after subagent_arg "$input" "tool" "subagent_type" \
      || json_string_after subagent_arg "$input" params "subagent_type" \
      || true
    first_arg="$(truncate80 "$subagent_arg")"
    ;;
  Glob|Grep)
    first_arg_is_null=1
    ;;
  *)
    first_arg_is_null=1
    ;;
esac

printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1 2>/dev/null || ts="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)"
json_escape_into ts_json "$ts"
json_escape_into session_id_json "$session_id"
json_escape_into tool_name_json "$tool_name"
json_escape_into cwd_json "$cwd"
if [[ "$first_arg_is_null" == "1" ]]; then
  printf -v line '{"ts":"%s","session_id":"%s","tool":"%s","first_arg_or_skill":null,"cwd":"%s"}' \
    "$ts_json" "$session_id_json" "$tool_name_json" "$cwd_json"
else
  json_escape_into first_arg_json "$first_arg"
  printf -v line '{"ts":"%s","session_id":"%s","tool":"%s","first_arg_or_skill":"%s","cwd":"%s"}' \
    "$ts_json" "$session_id_json" "$tool_name_json" "$first_arg_json" "$cwd_json"
fi

target="$memory_dir/tool-trace.jsonl"
if [[ -f "$target" ]]; then
  size=$(stat -c %s "$target" 2>/dev/null || echo 0)
  if (( size > 4194304 )); then
    mv -f "$target" "${target}.1" 2>/dev/null || audit "rotation failed" "$target"
  fi
fi

{ printf '%s\n' "$line" >> "$target"; } 2>/dev/null || {
  audit "append failed" "$target"
  exit 0
}

exit 0
