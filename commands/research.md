---
description: Grounded external research — anchor on internal memory/decisions, ask a directioning question, fetch external methods, then filter them against internal constraints into a feasibility list.
argument-hint: "[topic, e.g. 'agent memory systems', 'adapter ecosystem']"
---

Bring **external** knowledge (competitor designs, community implementations, academic
techniques) into the project **without it becoming noise**. `/research` is the outward
complement to `/discover`: discover scans "what we already intend but haven't done";
research scans "what the outside world has that we haven't thought of" — but always
anchored by what we already have and what we have already ruled out.

The output is a **feasibility assessment list**, not a dump of search results.

## When to use

- An opportunity (often surfaced by `/discover`) needs an external method we don't have.
- You're framing the gap as external: "how do other tools solve this?", "what's the state
  of the art?", "is there an existing pattern/library?".

Not for: internal opportunity scanning (use `/discover`), validating an already-selected
design with a committed decision (use `/spike`), or implementing a known ticket (write the
brief directly). Research never auto-opens tickets — it ends by *asking* whether to persist.

## Step 1 — Internal anchoring (mandatory, before any search)

Establish two anchors so external results can be judged, not just collected:

- **(a) What we already have** — avoid recommending something we've built.
- **(b) Which paths were already ruled out, and why** — avoid surfacing excluded approaches.

Retrieve, related to the topic:

1. **Decisions** — search `DECISIONS.md` for prior constraints and rejected approaches:
   ```bash
   grep -ni "<topic-keyword>" DECISIONS.md
   ```
   Read the matching entries (section-targeted; do not full-file Read).
2. **Memory cards** — the per-session-injected `MEMORY.md` index plus the project memory
   directory carry "what we have / why we didn't". Use the available memory access
   (`/mem-search <topic>`, or direct read of the relevant memory cards) to pull the
   on-topic ones.

> **Retrieval-first swap-point**: this anchoring step is intentionally isolated. When the
> single retrieval entry gains a memory source (`pmctl context query --source memory|all`),
> replace the ad-hoc memory read here with that one call — do not let a bespoke memory
> search path persist. The DECISIONS read already goes through the repo; keep it that way.

Produce a short internal baseline: "already have: …", "ruled out: … because …".

## Step 2 — Directioning question

Before spending any external search, ask the user **1–2 precise questions** that narrow the
query. The topic alone is usually too broad — narrowing is what keeps the search grounded.

> Example — topic "memory optimization": "Do you mean recall precision, token compression,
> or episodic coherence?"

Wait for the answer. Do not invent a topic or skip this step — a search fired from a vague
topic becomes the free web crawl this skill exists to avoid.

## Step 3 — External search

With the narrowed query, dispatch a **WebSearch-capable agent** (Agent tool,
`subagent_type: general-purpose`, or a dedicated research agent) to fetch **3–5** external
data points — real implementations, papers, community discussions. Ask it to return, per
source: what it does, the core idea, and a citation/link. Keep it bounded — this is targeted
retrieval, not a survey.

## Step 4 — Filter against internal constraints

The main thread evaluates each external method against the Step 1 baseline. Mark each:

- **可採用 / adoptable** — fits our constraints; note how it would map onto our design.
- **與約束衝突 / conflicts** — name the specific internal constraint it violates and the
  decision that established it (e.g. "conflicts with [constraint X], per [decision Y]").

This filtering is the value of the skill: the same external result is signal once judged
against what we have and what we ruled out, noise otherwise.

## Step 5 — Output

```
## /research — <narrowed topic> — <YYYY-MM-DD>

**Internal baseline**: already have <…>; ruled out <…> because <…>.

| # | External method | Source | Verdict | Maps to / conflicts with |
|---|---|---|---|---|
| 1 | <method> | <link> | 可採用 | <how it fits our design> |
| 2 | <method> | <link> | 衝突 | <constraint X, per decision Y> |
…

**Top adoptable**: <one-line: the highest-value external method that fits, and why>.
```

## Step 6 — Persistence prompt (mandatory)

`/research` does not auto-open tickets, but it must not leave the result as an ephemeral
conversation artifact. End by asking the user which (if any) to persist:

- a **BACKLOG ticket** (to act on an adoptable method),
- a **spike ticket** (if adopting needs a committed feasibility decision — then `/spike`),
- a **memory note** (a durable "we evaluated X; verdict Z; because …").

**Hard constraints on the output**:
- Do not auto-open tickets, dispatch, or modify files without user confirmation.
- Do not produce a free web crawl — every external query must trace to the Step 2 narrowing.
- Do not skip the internal anchoring or the persistence prompt.
