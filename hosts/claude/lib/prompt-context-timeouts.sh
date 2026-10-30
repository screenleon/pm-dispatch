#!/usr/bin/env bash
# Shared timeout defaults for the synchronous UserPromptSubmit context hook.
# The Claude handler timeout must remain greater than the hook's largest
# internal timeout so fail-open cleanup runs before Claude discards the hook.

# shellcheck disable=SC2034 # Public constant consumed by sourcing callers.
PROMPT_CONTEXT_REFRESH_TIMEOUT_DEFAULT=45
# shellcheck disable=SC2034 # Public constant consumed by sourcing callers.
PROMPT_CONTEXT_INITIAL_TIMEOUT_DEFAULT=120
# Time an index run may spend extracting before it writes what it has and stops (issue #741). The next prompt
# continues from there, so a repository too large for one prompt still converges instead of paying the full
# timeout and discarding the work every time. Well below the timeouts above, which still bound the whole run.
# shellcheck disable=SC2034 # Public constant consumed by sourcing callers.
PROMPT_CONTEXT_INITIAL_BUDGET_MS_DEFAULT=20000
# shellcheck disable=SC2034 # Public constant consumed by sourcing callers.
PROMPT_CONTEXT_REFRESH_BUDGET_MS_DEFAULT=25000
# shellcheck disable=SC2034 # Public constant consumed by sourcing callers.
CLAUDE_PROMPT_CONTEXT_HOOK_TIMEOUT=150
