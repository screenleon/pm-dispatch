#!/usr/bin/env bash
# Shared timeout defaults for the synchronous UserPromptSubmit context hook.
# The Claude handler timeout must remain greater than the hook's largest
# internal timeout so fail-open cleanup runs before Claude discards the hook.

# shellcheck disable=SC2034 # Public constant consumed by sourcing callers.
PROMPT_CONTEXT_REFRESH_TIMEOUT_DEFAULT=45
# shellcheck disable=SC2034 # Public constant consumed by sourcing callers.
PROMPT_CONTEXT_INITIAL_TIMEOUT_DEFAULT=120
# shellcheck disable=SC2034 # Public constant consumed by sourcing callers.
CLAUDE_PROMPT_CONTEXT_HOOK_TIMEOUT=150
