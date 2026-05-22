# Spikes

A **spike** is an investigation task — work that must reduce uncertainty
*before* an implementation spec can be written. Spike tickets carry the
`spike` epic in `BACKLOG.md`; their committed findings live here as
`docs/spikes/CC-NNN.md`.

Why this directory exists: a spike's findings must survive across sessions.
An investigation done once and left only in conversation context is a gap —
it gets re-done and re-paid for. Committing the result file fixes that.

## Spike ticket body (in `BACKLOG.md`)

A spike ticket uses the **standard three-section entry body** —
`Problem` / `Why` / `Requirement`, per `pm/schema.md` §2.5. It does **not**
add new top-level sections. The spike-specific structure lives *inside* the
`Requirement` section as three labelled parts:

- **Investigation scope** — the concrete questions / angles to explore.
- **Done-when** — the criterion that closes the spike: what must be answered.
- **Result log** — a pointer to `docs/spikes/CC-NNN.md` (added once the
  result file exists).

Skeleton:

```
## CC-NNN — <title>（spike）

**Problem**: <what is unknown; why a spec cannot be written yet>
**Why**: <why resolving the uncertainty matters>
**Requirement**:
- Investigation scope: <questions / angles to explore>
- Done-when: <what answer closes the spike>
- Result log: docs/spikes/CC-NNN.md
```

## Spike result file (`docs/spikes/CC-NNN.md`)

One file per spike, named for the ticket ID (`CC-NNN.md`, optionally
`CC-NNN-slug.md`). It is the committed, reviewable outcome of the
investigation. Structure:

```markdown
# CC-NNN — <title> (spike result)

**Status**: complete | abandoned
**Date**: <YYYY-MM-DD>
**Ticket**: BACKLOG.md CC-NNN

## Investigation scope
<the questions this spike set out to answer>

## Angles
<one subsection per investigation angle: what was tried, what was found>

## Findings
<the evidence — measurements, observations, comparisons>

## Recommendation
<adopt / defer / reject, with reasoning>

## Open risks
<what remains uncertain after the spike>

## Next tasks
<implementation / follow-up tickets the outcome justifies, if any>
```

The **Recommendation** is the load-bearing output — a spike's product is a
*decision*, not code. Any code written during a spike is a throwaway
prototype; the durable artifacts are this result file and the follow-up
tickets it justifies.

## Producing a spike result

v0.3.0 M5 adds `agents/spike.md` + the `/spike` command (CC-220): the spike
agent plans the angles, the main thread fans out one investigation agent per
angle (subagents cannot spawn subagents), and the spike agent synthesizes the
angle outputs into the result file. Until `/spike` lands, a spike result file
may be written by hand following the structure above.

The first formal spike is **CC-209** — evaluating codegraph as a
`context-pack` source (v0.3.0 M5).
