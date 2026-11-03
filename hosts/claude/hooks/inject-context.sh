#!/usr/bin/env bash
# Claude UserPromptSubmit adapter for the host-neutral prompt scan primitive.
set -euo pipefail

# CC-594: native Windows jq writes CRLF to a pipe/file; -b keeps LF (see runtime/lib/jq-lf.sh)
case "${OSTYPE:-}" in msys*|cygwin*) if type -P jq >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi ;; esac

# No `dirname` and no second subshell: a process start costs 0.3 to 2.5 s on the host that reported issue #741.
_self="$0"
[[ "$_self" == */* ]] || _self="./$_self"
REPO_ROOT="$(cd "${_self%/*}/../../.." && pwd)"
unset _self
# shellcheck source=hosts/claude/lib/prompt-context-timeouts.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/hosts/claude/lib/prompt-context-timeouts.sh"
# shellcheck source=runtime/lib/prompt-context.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/prompt-context.sh"

if [[ "${PM_DISPATCH_DISABLE_PROMPT_CONTEXT:-0}" == "1" ]]; then
  exit 0
fi
# No sqlite3, no index to scan: skip the payload parsing (the jq run) as well.
command -v sqlite3 >/dev/null 2>&1 || exit 0
# The payload is read with the shell's own `read` (not `cat`) and handed to jq on stdin (no temp file): a process
# start costs 0.3 to 2.5 s on the host that reported issue #741. One jq prints the two strings, each ended by a NUL.
IFS= read -r -d '' payload || true
if [[ -z "$payload" ]]; then
  exit 0
fi
PM_PROMPT_CONTEXT_CWD=""
PM_PROMPT_CONTEXT_PROMPT=""
{ IFS= read -r -d '' PM_PROMPT_CONTEXT_CWD && IFS= read -r -d '' PM_PROMPT_CONTEXT_PROMPT; } < <(
  jq -j '(if (.cwd | type) == "string" then .cwd else "" end), "\u0000",
         (if (.prompt | type) == "string" then .prompt else "" end), "\u0000"' <<<"$payload" 2>/dev/null) || true
# What `$(jq -r ...)` returned: no trailing newlines.
while [[ "$PM_PROMPT_CONTEXT_CWD" == *$'\n' ]]; do PM_PROMPT_CONTEXT_CWD="${PM_PROMPT_CONTEXT_CWD%$'\n'}"; done
while [[ "$PM_PROMPT_CONTEXT_PROMPT" == *$'\n' ]]; do PM_PROMPT_CONTEXT_PROMPT="${PM_PROMPT_CONTEXT_PROMPT%$'\n'}"; done
export PM_PROMPT_CONTEXT_CWD PM_PROMPT_CONTEXT_PROMPT
export PM_PROMPT_CONTEXT_INITIAL_TIMEOUT="${PM_DISPATCH_PROMPT_CONTEXT_INITIAL_TIMEOUT:-$PROMPT_CONTEXT_INITIAL_TIMEOUT_DEFAULT}"
export PM_PROMPT_CONTEXT_TIMEOUT="${PM_DISPATCH_PROMPT_CONTEXT_TIMEOUT:-$PROMPT_CONTEXT_REFRESH_TIMEOUT_DEFAULT}"
# An override that is not a positive integer falls back to the default, as the timeouts do.
PM_PROMPT_CONTEXT_INITIAL_BUDGET_MS="${PM_DISPATCH_PROMPT_CONTEXT_INITIAL_BUDGET_MS:-}"
[[ "$PM_PROMPT_CONTEXT_INITIAL_BUDGET_MS" =~ ^[1-9][0-9]{0,9}$ ]] || PM_PROMPT_CONTEXT_INITIAL_BUDGET_MS="$PROMPT_CONTEXT_INITIAL_BUDGET_MS_DEFAULT"
PM_PROMPT_CONTEXT_BUDGET_MS="${PM_DISPATCH_PROMPT_CONTEXT_BUDGET_MS:-}"
[[ "$PM_PROMPT_CONTEXT_BUDGET_MS" =~ ^[1-9][0-9]{0,9}$ ]] || PM_PROMPT_CONTEXT_BUDGET_MS="$PROMPT_CONTEXT_REFRESH_BUDGET_MS_DEFAULT"
export PM_PROMPT_CONTEXT_INITIAL_BUDGET_MS PM_PROMPT_CONTEXT_BUDGET_MS
# "sync" makes a prompt wait for the index refresh; anything else is the default, a refresh in the background.
case "${PM_DISPATCH_PROMPT_CONTEXT_REFRESH:-}" in sync) export PM_PROMPT_CONTEXT_REFRESH=sync ;; *) export PM_PROMPT_CONTEXT_REFRESH=background ;; esac
pm_prompt_context_scan
