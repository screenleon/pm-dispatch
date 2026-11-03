#!/usr/bin/env bash
# Claude UserPromptSubmit adapter for the host-neutral prompt scan primitive.
set -euo pipefail

# CC-594: native Windows jq writes CRLF to a pipe/file; -b keeps LF (see runtime/lib/jq-lf.sh)
case "${OSTYPE:-}" in msys*|cygwin*) if type -P jq >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi ;; esac

# The hook's own work starts no `dirname`, `cat`, `mktemp` or `rm` and no subshell for its path: a process start costs
# 0.3 to 2.5 s on the host that reported issue #741. Same idiom as runtime/hooks/guard-inject-memory.sh.
_hook_dir=.
[[ "$0" == */* ]] && _hook_dir="${0%/*}"
REPO_ROOT="$_hook_dir/../../.."
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
# The payload is read in one block (`$(</dev/stdin)`: a fork, no `cat`; `read` on a pipe takes one byte per system
# call, which is slow for a large paste) and handed to jq on stdin (no temp file). A closed stdin is checked first,
# without a process: the substitution's own pipe would take file descriptor 0 and `/dev/stdin` would read that.
{ : 3<&0; } 2>/dev/null || exit 0
payload=$(</dev/stdin) || payload=""
if [[ -z "$payload" ]]; then
  exit 0
fi
# One jq prints the two strings with U+001F between them. A path has none, so the first one splits cwd from the
# prompt even if the prompt holds more. Like `$(jq -r ...)` before, a NUL is dropped and the prompt loses its
# trailing newlines (the substitution strips them); the cwd's are stripped below. A payload jq cannot read leaves both empty.
fields=$(jq -j '(if (.cwd | type) == "string" then .cwd else "" end), "\u001f",
                (if (.prompt | type) == "string" then .prompt else "" end)' <<<"$payload" 2>/dev/null) || fields=""
PM_PROMPT_CONTEXT_CWD="${fields%%$'\x1f'*}"
PM_PROMPT_CONTEXT_PROMPT="${fields#*$'\x1f'}"
while [[ "$PM_PROMPT_CONTEXT_CWD" == *$'\n' ]]; do PM_PROMPT_CONTEXT_CWD="${PM_PROMPT_CONTEXT_CWD%$'\n'}"; done
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
