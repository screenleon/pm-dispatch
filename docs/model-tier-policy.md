# Model Tier Policy

Governs which Claude model tier to use when spawning subagents from the main thread.

## `/pr-gate`: Sonnet for all reviewers and synthesis

Every Agent call spawned by `/pr-gate` — reviewers and the final project-pm
synthesis hop — uses `model: "sonnet"`. These are bounded, scoped tasks:
reviewing a diff and synthesising the result does not benefit from a larger
model, but does incur its cost.

```
# /pr-gate reviewer spawns (Step 2)
Agent(subagent_type: "critic",                model: "sonnet", ...)
Agent(subagent_type: "qa-tester",             model: "sonnet", ...)
Agent(subagent_type: "architecture-reviewer", model: "sonnet", ...)
Agent(subagent_type: "security-reviewer",     model: "sonnet", ...)
Agent(subagent_type: "risk-reviewer",         model: "sonnet", ...)

# /pr-gate synthesis (Step 3)
Agent(subagent_type: "project-pm", model: "sonnet", ...)
```

Always specify `model:` explicitly in `/pr-gate` calls. If you omit it, the
call inherits the main-thread model — which may be Opus, silently multiplying
review cost.

## `/pm`: inherits main-thread model

`/pm` invokes `project-pm` for general work — analysis, planning, brief
writing, memory updates. These tasks may benefit from a more capable model,
so the invocation does **not** force a model. The subagent inherits whichever
model the user started their session with.

Use `/pm` when the user's own model choice should apply. Use `/pr-gate` (which
forces Sonnet) only for the review pipeline.

## Opus escalation (rare)

Only when **all three** conditions hold:

1. Tier is `full`
2. Diff exceeds 1000 changed lines
3. At least one sensitive path triggered `full` (auth, payments, migrations, CI, etc.)

Before escalating, notify the user:
> "This PR is large and sensitive — using Opus for reviewers. Token cost will be approximately 3–5× higher."

Wait for acknowledgement before spawning.

## Implementation tasks

For any code change (bug fix, feature, refactor):

1. **Prefer `codex-executor`** — dispatches via `scripts/codex-dispatch.sh`, sandboxed, trace-logged.
2. **Fallback to `Agent(model: "sonnet")`** — only when:
   - User reports Codex quota errors or slowdowns, OR
   - The task is a single-file, single-line fix where the overhead of a full brief is disproportionate.
3. **Never use Opus for implementation** without explicit user instruction.

## Why

Claude Opus token cost is approximately 3–5× Sonnet. For review and analysis
tasks, Sonnet quality is sufficient. The cost difference is significant over a
multi-hour session with several PR gates.

## Token usage tracking

After any significant agent operation, log the total tokens:

```sh
bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note]
```

Standard types: `pr_gate_full`, `pr_gate_standard`, `pr_gate_express`,
`codex_task`, `pm_analysis`, `pm_synthesis`, `reviewer_critic`, `reviewer_qa`,
`reviewer_arch`, `reviewer_security`, `reviewer_risk`, `session_total`.

View rolling 5-hour or today's usage:

```sh
bash ~/.claude/scripts/claude-usage.sh          # last 5 hours
bash ~/.claude/scripts/claude-usage.sh --today  # today (UTC)
```
