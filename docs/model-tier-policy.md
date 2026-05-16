# Model Tier Policy

Governs which Claude model tier to use when spawning subagents, and when to
suggest Opus to the user.

**Fundamental rule:** Sonnet is the default for all agent work. Opus is only
used when the user explicitly confirms it after being told why and what it costs.
Never silently upgrade to Opus.

---

## Default: Sonnet

For reviewer and implementation-adjacent agent spawns, use `model: "sonnet"`
unless one of the Opus criteria below is met. Always specify `model:`
explicitly unless a named exception below says otherwise — omitting it inherits
the main-thread model, which may already be Opus, silently multiplying cost.

**Exception — `/pm` skill**: The `/pm` command intentionally omits `model:` on
its Agent call so the subagent inherits the main thread's active model. Do not
add `model:` when invoking PM from the `/pm` skill; specify it only when
invoking PM from non-pm contexts (e.g., PR-gate synthesis step).

---

## When to suggest Opus

Opus brings meaningful benefit in tasks that require:

| Signal | Examples |
|--------|---------|
| **Novel cross-cutting architecture** | Designing a new auth layer, restructuring module boundaries, evaluating trade-offs across many interdependent systems |
| **High-stakes, hard-to-reverse decisions** | Database schema design, public API contract definition, infrastructure topology, security model design |
| **Deep security design** | Not just reviewing code for bugs, but designing crypto/auth/session flows from scratch |
| **Very large context analysis** | Understanding interactions across 10+ significant files with complex dependencies |
| **Ambiguous or unprecedented problems** | No clear solution path; wrong first step is costly to undo |

Single-file edits, routine reviews, standard planning, brief writing, and
memory updates do **not** warrant Opus.

### Mandatory ask-before-use flow

Whenever one of the above signals is present, **stop and ask the user** before
proceeding. Do not spawn Opus agents first and explain later.

The ask must include:
1. **Why** Opus is being suggested for this specific task
2. **Cost warning**: approximately 3–5× higher than Sonnet
3. **A clear choice**: confirm Opus, or continue with Sonnet

Example phrasing:
> "This task involves [specific reason — e.g. 'designing the auth session model from scratch, a novel cross-cutting decision']. Opus may produce a more thorough analysis, but costs roughly 3–5× more than Sonnet. Use Opus, or continue with Sonnet?"

Wait for user confirmation before spawning any agent.

---

## `/pr-gate`: Sonnet for all reviewers and synthesis

Every Agent call spawned by `/pr-gate` — reviewers and the final project-pm
synthesis hop — uses `model: "sonnet"`. These are bounded, scoped tasks:
reviewing a diff and synthesising the result does not benefit from a larger
model but does incur its cost.

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

**`/pr-gate` Opus escalation** — suggest Opus (and ask the user per the flow
above) only when **all three** hold:

1. Tier is `full`
2. Diff exceeds 1000 changed lines
3. At least one sensitive path triggered `full` (auth, payments, migrations, CI, etc.)

Example ask:
> "This PR is large and sensitive (>1000 lines, touches [path]). Opus reviewers
> may catch more subtle issues, but cost is roughly 3–5× higher. Use Opus for
> this gate, or keep Sonnet?"

---

## `/pm`: inherits main-thread model

`/pm` invokes `project-pm` for general work — analysis, planning, brief
writing, memory updates. These tasks may benefit from a more capable model,
so the invocation does **not** force a model. The subagent inherits whichever
model the user started their session with.

If the task meets an Opus signal above, apply the mandatory ask-before-use flow
before spawning.

---

## Implementation tasks

For any code change (bug fix, feature, refactor):

1. **Follow the dispatch contract in `docs/dispatch-brief.md`** — `/pm`
   implementation handovers use the main-thread Bash route by default,
   sandboxed and trace-logged via `scripts/codex-dispatch.sh`.
2. **Use `codex-executor` only for the fallback allowlist** documented in
   `docs/dispatch-brief.md` §Fallback.
3. **Fallback to `Agent(model: "sonnet")`** — only when Codex quota is
   exhausted or the change is a single-line fix where a full brief is
   disproportionate.
4. **Never use Opus for implementation** without explicit user instruction.

---

## Why Sonnet by default

Claude Opus costs approximately 3–5× Sonnet per token. A typical session with
several pr-gate passes and PM analyses can consume 500k–1M tokens; at Opus
rates that becomes a material difference. Sonnet quality is sufficient for
the vast majority of review, analysis, and planning work.

---

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
bash ~/.claude/scripts/token-usage.sh          # last 5 hours
bash ~/.claude/scripts/token-usage.sh --today  # today (UTC)
```
