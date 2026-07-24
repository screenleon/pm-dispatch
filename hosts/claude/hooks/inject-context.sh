#!/usr/bin/env bash
# Claude UserPromptSubmit adapter for the host-neutral prompt scan primitive.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=hosts/claude/lib/prompt-context-timeouts.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/hosts/claude/lib/prompt-context-timeouts.sh"
# shellcheck source=runtime/lib/prompt-context.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/prompt-context.sh"

if [[ "${PM_DISPATCH_DISABLE_PROMPT_CONTEXT:-0}" == "1" ]]; then
  exit 0
fi
payload=$(cat)
if [[ -z "$payload" ]]; then
  exit 0
fi
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '%s' "$payload" > "$tmp"
PM_PROMPT_CONTEXT_CWD="$(jq -r 'if (.cwd | type) == "string" then .cwd else empty end' "$tmp" 2>/dev/null || true)"
PM_PROMPT_CONTEXT_PROMPT="$(jq -r 'if (.prompt | type) == "string" then .prompt else empty end' "$tmp" 2>/dev/null || true)"
export PM_PROMPT_CONTEXT_CWD PM_PROMPT_CONTEXT_PROMPT
export PM_PROMPT_CONTEXT_INITIAL_TIMEOUT="${PM_DISPATCH_PROMPT_CONTEXT_INITIAL_TIMEOUT:-$PROMPT_CONTEXT_INITIAL_TIMEOUT_DEFAULT}"
export PM_PROMPT_CONTEXT_TIMEOUT="${PM_DISPATCH_PROMPT_CONTEXT_TIMEOUT:-$PROMPT_CONTEXT_REFRESH_TIMEOUT_DEFAULT}"
pm_prompt_context_scan
