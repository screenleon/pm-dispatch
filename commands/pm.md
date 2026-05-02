---
description: Route a request to the project-pm agent.
argument-hint: <free-form request, e.g. "status of foo", "add /health endpoint to api">
---

Invoke `project-pm` via Agent. Brief with: request ($ARGUMENTS), current working directory, and relevant prior-turn context the subagent won't otherwise see.

Relay the PM's user-facing summary. Do not do the PM's job yourself.

**Note**: Subagents cannot spawn subagents. If the PM's reply is "dispatch this brief to codex-executor" or "spawn reviewers X / Y / Z", the **main thread** must do the dispatching. Treat the PM's brief as the input to your own `Agent(subagent_type: "codex-executor", ...)` call (or `Bash(codex exec ...)` if `codex-executor` itself is unavailable in your environment).
