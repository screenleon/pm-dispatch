#!/usr/bin/env bash
# Sourceable executor routing helpers for codex/claude dispatch callers.
# No shell options are set here; callers own their execution policy.

_EXECUTOR_ROUTER_SELF="${BASH_SOURCE[0]}"
while [[ -L "$_EXECUTOR_ROUTER_SELF" ]]; do
  _EXECUTOR_ROUTER_DIR="$(cd "$(dirname "$_EXECUTOR_ROUTER_SELF")" && pwd)"
  _EXECUTOR_ROUTER_SELF="$(readlink "$_EXECUTOR_ROUTER_SELF")"
  [[ "$_EXECUTOR_ROUTER_SELF" == /* ]] || _EXECUTOR_ROUTER_SELF="$_EXECUTOR_ROUTER_DIR/$_EXECUTOR_ROUTER_SELF"
done
EXECUTOR_ROUTER_LIB_DIR="$(cd "$(dirname "$_EXECUTOR_ROUTER_SELF")" && pwd)"
EXECUTOR_ROUTER_SCRIPT_DIR="$(cd "$EXECUTOR_ROUTER_LIB_DIR/.." && pwd)"

# shellcheck source=scripts/lib/portable.sh
. "$EXECUTOR_ROUTER_LIB_DIR/portable.sh"

detect_executor_auto() {
  if codex_available; then
    printf 'codex\n'
  else
    printf 'claude\n'
  fi
}

resolve_executor() {
  local option=${1-}

  [[ $# -eq 1 ]] || {
    printf 'executor-router: resolve_executor expects exactly one argument\n' >&2
    return 2
  }

  case "$option" in
    auto) detect_executor_auto ;;
    codex|claude) printf '%s\n' "$option" ;;
    *)
      printf 'executor-router: unknown executor: %s (expected codex, claude, or auto)\n' "$option" >&2
      return 2
      ;;
  esac
}

dispatch_route_for() {
  local executor=${1-}

  [[ $# -eq 1 ]] || {
    printf 'executor-router: dispatch_route_for expects exactly one argument\n' >&2
    return 2
  }

  case "$executor" in
    codex) printf 'main_thread_bash_background\n' ;;
    claude) printf 'agent_executor\n' ;;
    *)
      printf 'executor-router: unknown executor: %s (expected codex or claude)\n' "$executor" >&2
      return 2
      ;;
  esac
}

executor_router_safe_argv() {
  local value=${1-}
  printf '%q' "$value"
}

# dispatch_via_codex <brief_file> <working_dir> <model> <sandbox> <approval> <timeout>
# Prints a safely-quoted shell command string. The caller still owns when/how to
# execute it, including foreground/background dispatch and redirection.
dispatch_via_codex() {
  local brief_file=${1-}
  local working_dir=${2-}
  local model=${3-}
  local sandbox=${4-}
  local approval=${5-}
  local timeout=${6-}
  local dispatch_script="$EXECUTOR_ROUTER_SCRIPT_DIR/codex-dispatch.sh"
  local -a cmd
  local arg
  local first=1

  [[ $# -eq 6 ]] || {
    printf 'executor-router: dispatch_via_codex expects brief_file, working_dir, model, sandbox, approval, timeout\n' >&2
    return 2
  }

  cmd=(bash "$dispatch_script" --cd "$working_dir" --sandbox "$sandbox" --approval "$approval" --timeout "$timeout" --brief-file "$brief_file")
  if [[ -n "$model" && "$model" != "default" ]]; then
    cmd=(bash "$dispatch_script" --cd "$working_dir" --model "$model" --sandbox "$sandbox" --approval "$approval" --timeout "$timeout" --brief-file "$brief_file")
  fi

  for arg in "${cmd[@]}"; do
    if [[ "$first" -eq 1 ]]; then
      first=0
    else
      printf ' '
    fi
    executor_router_safe_argv "$arg"
  done
  printf '\n'
}

unset _EXECUTOR_ROUTER_SELF _EXECUTOR_ROUTER_DIR

export EXECUTOR_ROUTER_LIB_DIR
export EXECUTOR_ROUTER_SCRIPT_DIR
export -f detect_executor_auto
export -f resolve_executor
export -f dispatch_route_for
export -f executor_router_safe_argv
export -f dispatch_via_codex
