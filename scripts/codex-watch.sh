#!/usr/bin/env bash
# codex-watch.sh
#
# Tail the most recent codex dispatch's JSONL trace and print a one-line
# human-readable summary of each event as it arrives. Use to watch a long
# dispatch in real time without knowing the timestamp.
#
# Usage:
#   codex-watch.sh [--cd <work_dir>] [--trace <abs_jsonl>|--run <run_id>]
#
# Defaults to the newest out-of-repo run trace for $PWD, falling back to
# $PWD/.agent-trace/latest.jsonl.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_PATHS="$SCRIPT_DIR/lib/state-paths.sh"

WORK_DIR="${PWD}"
TRACE_ARG=""
RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    --trace) TRACE_ARG="$2"; shift 2;;
    --run) RUN_ID="$2"; shift 2;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ -n "$TRACE_ARG" && -n "$RUN_ID" ]]; then
  echo "codex-watch: pass only one of --trace or --run" >&2
  exit 2
fi

load_state_paths_required() {
  if [[ ! -r "$STATE_PATHS" ]]; then
    echo "codex-watch: state-paths.sh not found at $STATE_PATHS" >&2
    echo "codex-watch: pass --trace <abs_jsonl> directly, or run from a complete pm-dispatch checkout" >&2
    exit 2
  fi
  # shellcheck disable=SC1090,SC1091  # script-relative library path.
  . "$STATE_PATHS"
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function ]]; then
    echo "codex-watch: sw_project_run_dir unavailable after loading $STATE_PATHS" >&2
    echo "codex-watch: pass --trace <abs_jsonl> directly, or repair the pm-dispatch checkout" >&2
    exit 2
  fi
}

try_load_state_paths() {
  [[ -r "$STATE_PATHS" ]] || return 1
  # shellcheck disable=SC1090,SC1091  # script-relative library path.
  . "$STATE_PATHS" 2>/dev/null || return 1
  [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]]
}

project_runs_dir() {
  local run_dir
  run_dir="$(cd "$WORK_DIR" 2>/dev/null && sw_project_run_dir "__codex_watch_probe__" 2>/dev/null)" || return 1
  dirname "$run_dir"
}

TRACE=""
if [[ -n "$TRACE_ARG" ]]; then
  if [[ "$TRACE_ARG" != /* ]]; then
    echo "codex-watch: --trace must be an absolute path: $TRACE_ARG" >&2
    exit 2
  fi
  TRACE="$TRACE_ARG"
elif [[ -n "$RUN_ID" ]]; then
  load_state_paths_required
  RUN_DIR="$(cd "$WORK_DIR" 2>/dev/null && sw_project_run_dir "$RUN_ID" 2>/dev/null)" || {
    echo "codex-watch: could not resolve run dir for $RUN_ID under $WORK_DIR" >&2
    exit 2
  }
  if [[ ! -d "$RUN_DIR" ]]; then
    echo "codex-watch: run dir not found for $RUN_ID: $RUN_DIR" >&2
    echo "codex-watch: check the run id or pass --trace <abs_jsonl> directly" >&2
    exit 1
  fi
  TRACE="$RUN_DIR/.agent-trace/latest.jsonl"
elif try_load_state_paths; then
  RUNS_DIR="$(project_runs_dir 2>/dev/null || true)"
  if [[ -n "$RUNS_DIR" && -d "$RUNS_DIR" ]]; then
    NEWEST_RUN_DIR=""
    NEWEST_RUN_MTIME=-1
    for _run_dir in "$RUNS_DIR"/*; do
      [[ -d "$_run_dir" ]] || continue
      _run_mtime="$(stat -c '%Y' "$_run_dir" 2>/dev/null || stat -f '%m' "$_run_dir" 2>/dev/null || printf '0')"
      if [[ "$_run_mtime" =~ ^[0-9]+$ ]] && (( _run_mtime > NEWEST_RUN_MTIME )); then
        NEWEST_RUN_MTIME="$_run_mtime"
        NEWEST_RUN_DIR="$_run_dir"
      fi
    done
    if [[ -n "$NEWEST_RUN_DIR" && -e "$NEWEST_RUN_DIR/.agent-trace/latest.jsonl" ]]; then
      TRACE="$NEWEST_RUN_DIR/.agent-trace/latest.jsonl"
    fi
  fi
fi

if [[ -z "$TRACE" ]]; then
  TRACE="$WORK_DIR/.agent-trace/latest.jsonl"
fi

if [[ ! -e "$TRACE" ]]; then
  echo "no trace yet at $TRACE" >&2
  echo "(run pmctl dispatch run --adapter codex first, or wait for the trace symlink to appear)" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "watch needs jq; falling back to raw tail -F" >&2
  exec tail -F "$TRACE"
fi

# Each codex event is one JSON object per line. Pretty-print only the fields
# a watcher cares about: type, item type, command (truncated), exit code,
# token usage on turn.completed.
exec tail -F "$TRACE" | jq -r --unbuffered '
  if .type == "turn.started" then
    "[\(.type)]"
  elif .type == "turn.completed" then
    "[\(.type)] tokens: in=\(.usage.input_tokens // 0) cached=\(.usage.cached_input_tokens // 0) out=\(.usage.output_tokens // 0)"
  elif .type == "item.completed" and .item.type == "command_execution" then
    "[cmd] exit=\(.item.exit_code // "?") \(.item.command | tostring | .[0:120])"
  elif .type == "item.completed" and .item.type == "agent_message" then
    "[msg] \(.item.text | tostring | .[0:200] | gsub("\n"; " "))"
  elif .type == "item.completed" and .item.type == "file_change" then
    "[edit] \(.item.path // .item.file // "?")"
  else
    "[\(.type)]"
  end
'
