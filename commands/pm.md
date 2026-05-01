---
description: Route a request to the project-pm agent.
argument-hint: <free-form request, e.g. "status of foo", "add /health endpoint to api">
---

Invoke `project-pm` via Agent. Brief with: request ($ARGUMENTS), current working directory, and relevant prior-turn context the subagent won't otherwise see.

Relay the PM's user-facing summary. Do not do the PM's job yourself.
