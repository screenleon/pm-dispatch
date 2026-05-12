---
description: Route a request to the project-pm agent.
argument-hint: <free-form request, e.g. "status of foo", "add /health endpoint to api">
---

Invoke `project-pm` via Agent. Do not force a model — inherit the main-thread model so the user's own session choice applies (see `docs/model-tier-policy.md` §`/pm`). Brief with: request ($ARGUMENTS), current working directory, and relevant prior-turn context the subagent won't otherwise see.

Relay the PM's user-facing summary. Do not do the PM's job yourself.

**Note**: Subagents cannot spawn subagents. If the PM's reply is "dispatch this brief to codex-executor", the **main thread** must do the dispatching — treat the PM's brief as input to your own `Agent(subagent_type: "codex-executor", ...)` call (illustrative — emit it as a real Agent tool call). If `codex-executor` is unavailable, fallback to invoking `scripts/codex-dispatch.sh` directly via Bash — the script encodes the canonical sandbox / approval / trace-capture flags so this command stays in sync with the rest of the dispatch path.

Briefs must follow the schema at `docs/codex-brief.md` (working_dir / goal / files / acceptance, plus self_verify required for file-writing briefs and optional only for read-only briefs where every files entry is explicitly tagged `read:`). codex-executor rejects briefs missing the required fields.

For PR-gate flows, use `/pr-gate` instead — that skill handles reviewer orchestration; do not re-implement it inline here.
