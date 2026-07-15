#!/usr/bin/env bash
# Shared timeout defaults for the synchronous UserPromptSubmit context hook.
# The Claude handler timeout must remain greater than the hook's largest
# internal timeout so fail-open cleanup runs before Claude discards the hook.

PROMPT_CONTEXT_REFRESH_TIMEOUT_DEFAULT=45
PROMPT_CONTEXT_INITIAL_TIMEOUT_DEFAULT=120
CLAUDE_PROMPT_CONTEXT_HOOK_TIMEOUT=150
