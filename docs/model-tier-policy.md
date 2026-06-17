# Model Tier Policy

Governs which Claude model tier to use when spawning subagents, and when to
suggest Opus to the user.

**Fundamental rule:** Sonnet is the default for all agent work. Opus is only
used when the user explicitly confirms it after being told why and what it costs.
Never silently upgrade to Opus.

---

## Executor-agnostic `light` alias

The `light` alias selects the lightweight model for a given executor. Use it in
briefs and dispatch policy docs — never hard-code executor-specific model IDs.

| Executor | `light` resolves to | Context | Use case |
|---|---|---|---|
| codex | `gpt-5.3-codex-spark` | ~64K | Small codex dispatches |
| claude | `claude-haiku-4-5-20251001` | ~200K | Small claude dispatches |

Alias tables: `share/model-aliases.tsv` (codex), `share/claude-model-aliases.tsv` (claude).

**When to use `light`**: all three criteria must hold — (a) expected diff < 50 lines,
(b) changes confined to ≤ 2 adjacent files with no cross-module dependencies,
(c) no new interfaces, abstractions, or hooks introduced.

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

Route by task size first; executor and model follow from size:

| Size | Criteria | Route |
|---|---|---|
| **Tiny** | < 30 lines, 1–2 files, no new behavior | Main thread inline (Edit tool directly — no dispatch) |
| **Small** | < 50 lines, ≤ 2 adjacent files, no new interfaces/abstractions/hooks | Main thread inline, OR dispatch with `model: light` (codex-spark / haiku) |
| **Medium** | 50–300 lines, 3–5 files, 3+ behavioral units | Dispatch with `model: default` (Codex default via `pmctl dispatch run --adapter codex`) |
| **Large** | > 300 lines, 5+ files, new modules/schemas | Dispatch with `model: default`; `/pre-impl` required |

Decision rules:

1. **Size determines route** — check the table above before writing a brief. Tiny tasks never need a brief; Small tasks may be handled inline by the main thread directly.
2. **`light` for confirmed-small dispatches** — use `model: light` when all three Small criteria hold: diff < 50 lines, ≤ 2 adjacent files, no new interfaces/abstractions/hooks. Misrouting a medium task to `light` degrades quality without a loud failure.
3. **Codex default for medium/large** — follow the dispatch contract in `docs/dispatch-brief.md`; main-thread Bash route via `pmctl dispatch run --adapter codex`. There is no Agent executor fallback; all dispatch is the main-thread Bash route.
4. **Never use Opus for implementation** without explicit user instruction.

**Main thread vs. PM routing**: the table above governs main-thread decisions. When the main thread invokes `/pm`, the PM always writes a brief for Small and above (PM does not perform inline edits). The "inline" route in the Small row applies when the main thread handles the change directly without going through PM.

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
