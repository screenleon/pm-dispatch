# CC-408 — next-step uncertainty router: /discover · /research · spike (spike result)

**Status**: complete
**Date**: 2026-06-19
**Ticket**: BACKLOG.md CC-408
**Method**: multi-source design spike — three independent analyses then synthesis:
main-thread (opus, read-only repo analysis), a codex second opinion (`gpt-5.5`, effort=high),
and an external ChatGPT analysis. The raw angle artifacts were transient inputs (codex run
output and a user-supplied ChatGPT transcript); their load-bearing content is captured and
attributed per-angle below in §Angles and §Findings, so **this committed synthesis is the
reviewable artifact** — the original scratch files are not required to audit the decision.

## Investigation scope

Re-plan the three "uncertainty-reduction" capabilities and their invocation model:

- `/discover` (CC-343, shipped — `commands/discover.md`): internal divergent opportunity scan.
- `/research` (CC-344, planned, not built): external research with internal-context anchoring.
- spike agent + `/spike` (CC-220, deferred, not built): convergent decision-production workflow.

Two driving questions:

- **Q1** — When the user asks "what should we do next?", should `/discover` and `/research`
  be *automatically* invoked rather than manually typed? Is that the right design, and what
  is the trigger/routing logic?
- **Q2** — When exactly should the spike agent be used, vs `/discover` vs `/research`?

## Angles

Three independent analyses were produced and cross-checked:

- **Angle A — main thread (opus)**: read `commands/discover.md`, `docs/spikes/README.md`,
  BACKLOG CC-343/344/220/244/218, `agents/project-pm.md` Classify table, v0.7.0 retrieval
  epic (CC-403). Framed a two-phase pipeline and a "can I write a confident brief?" rule.
- **Angle B — codex (gpt-5.5)**: independent repo read with the same brief; emphasized
  sibling-modes-that-compose, grounded the router necessity in DECISIONS evidence, surfaced
  the post-research-persistence gap and the CC-344→CC-403 dependency correction.
- **Angle C — ChatGPT (external)**: emphasized main-thread orchestration (not subagent
  nesting), proposed upgrading `/discover` output into a routing input, and proposed a named
  `next_step_recommendation_v1` protocol + a standalone router ticket.

## Findings

### Strong convergence (all three independent analyses agreed)

1. **Auto-invocation direction is correct, but intent must be classified first.**
   "What's next?" splits into a *tactical* intent ("next step for this active ticket/PR/bug"
   — ordinary planning/status, must NOT auto-fire discovery) and a *strategic* intent
   ("what should we do next / next milestone" — the home for discovery).

2. **`/discover` and `/research` have different correct automation levels** — this is the
   key asymmetry:
   - `/discover`: **conditional auto-fire**. Cheap, local, read-only, explicitly
     non-committal (its contract forbids writing briefs/plans/tickets). Safe to run
     automatically for broad strategic "what next?" questions.
   - `/research`: **auto-offer, not auto-fire**. CC-344 requires a *topic* plus 1–2 user
     directioning questions before the expensive WebSearch fan-out. Firing it from a vague
     "what next?" would either invent a topic or interrogate the user before they have
     chosen a direction. It should chain off a *selected* `/discover` candidate (which
     supplies the topic), or off an explicit external-knowledge framing.

3. **The real gap is a missing router.** The three capabilities are tools with no
   dispatcher; the user must manually pick. The routing logic belongs in
   `agents/project-pm.md`'s `Classify` table (the existing triage chokepoint), with the
   **main thread** performing the actual command invocation and fan-out — because subagents
   cannot spawn subagents (same constraint as `/pr-gate` and the CC-220 correction).

4. **A prose-level soft reflex is insufficient.** DECISIONS records that context-pack /
   reuse-scan shipped with no operational callers; instruction-only wiring was necessary but
   not enough, and deterministic auto-pack had to be introduced because model-discipline
   routing did not produce usage. The same failure mode applies here — "maybe run
   discover/research/spike" left only as prose will be skipped exactly when the session is
   busy. (Consistent with `feedback_cut_capability_close_all_paths`.)

5. **Four-way separation of cognitive modes** (agreed wording):
   - `/discover` → "which one?" (internal options)
   - `/research` → "is there an approach we haven't recorded?" (external methods)
   - spike → "does this approach hold up?" (convergent decision)
   - `/pm` → "how do we hand it to an executor?" (implementation)

### Adopted single-source insights

- **(ChatGPT) Upgrade `/discover` output from a human menu into a routing input.** Add
  per-pick fields: `suggested_next_action: pm|spike|research|defer`, `refs`/anchors, and a
  `why_not_direct_pm` rationale. Without this, the router has nothing structured to chain on.
- **(ChatGPT) Open the router as its own design ticket** (protocol `next_step_recommendation_v1`),
  not folded into CC-343.
- **(codex) Post-research persistence rule.** `/research` must not auto-open tickets, but it
  MUST end by asking whether to convert a result into a BACKLOG ticket, a spike ticket, or a
  memory/decision note — otherwise external research becomes another ephemeral artifact
  (the very failure CC-344 exists to prevent).
- **(codex, corrected on review) CC-344's CC-403 link is a forward integration, NOT a hard
  dependency.** The first synthesis overstated this as "depends on". Re-examined: `/research`'s
  internal anchoring reads DECISIONS.md (a repo file, already readable / already in `pmctl
  context` repo source) plus memory cards (accessible today via direct memory-dir grep — what
  `/mem-search` already does — and the per-session injected `MEMORY.md` index). So `/research`
  is **functionally buildable now**. CC-403 (`pmctl context --source memory|all`) only adds the
  single-entry retrieval path for the memory half of anchoring; building before it risks a
  bespoke memory-grep, which is mitigated by isolating anchoring into one step with a documented
  swap-point. Numbering smell noted: CC-344 < CC-403, so a low-number ticket "depending on" a
  higher one was the tell that the dependency was optional/preferential, not blocking. CC-340's
  MVP is superseded by CC-403; the memory-anchoring single-entry integration now references CC-403.

### Reconciled divergences

- **Taxonomy: pipeline vs siblings.** Angle A framed it as a two-phase pipeline; Angle B
  refined it to **sibling modes that can compose into a pipeline, not a mandatory chain** —
  forcing the full chain over-processes small work (many `/discover` outputs go straight to
  planning; some `/research` outputs straight to a ticket; some spikes arise from a concrete
  blocker with no prior discover/research). **Adopted: siblings + one optional composition
  path.**
- **Build CC-220 now?** Angle A leaned "buildable now for symmetry" (CC-218 dependency
  satisfied); Angles B and C both counseled restraint — buildable, but defer until real
  spike volume or repeated ad-hoc spike workflows appear. **Adopted: keep deferred**, which
  matches this repo's "a capability isn't done until it has a caller" lesson.

## Recommendation

**ADOPT** the router as the primary, highest-leverage next step. Concretely:

1. **Build a next-step router** (new ticket CC-408). Phase 1 is pure-docs / zero-risk: a
   `Classify`-table route in `agents/project-pm.md` + a main-thread orchestration rule in
   `commands/pm.md` (PM emits the route; main thread runs `/discover` and feeds the report
   back before the final user-facing recommendation). Acceptance = asking "what should we do
   next?" produces a recommendation that cites `/discover` output and explicitly states the
   next route (pm / spike / research / defer).
2. **Upgrade `/discover` output** (`commands/discover.md`) with `suggested_next_action` +
   `refs` per pick — folded into CC-408 since CC-343 is already closed.
3. **Build `/research` (CC-344) now**: functionally buildable without CC-403 (anchoring uses
   DECISIONS direct-read + existing memory access). Isolate anchoring into one step with a
   documented swap-point to `pmctl context --source memory` for when CC-403 lands. Add the
   post-research persistence rule; keep the no-auto-ticket output contract.
4. **Build spike agent (CC-220) now**: CC-218 is satisfied. Constraint: planner +
   main-thread fan-out (an `agents/spike.md` that spawns agents is structurally invalid).

> **Decision adjustment (2026-06-19, user)**: the original synthesis advised deferring CC-220
> and sequencing CC-344 after CC-403. The user reviewed and chose to **build CC-220 + CC-344
> now, in one PR**, with the user taking the CC-408 router on the same branch. The CC-344→CC-403
> link was downgraded from "hard dependency" to "forward integration" on this review (see the
> corrected finding above) — `/research` does not need CC-403 to function. This adjustment is
> recorded here as the load-bearing change from the spike's first recommendation.

Routing table to add to `agents/project-pm.md` (`Classify` or adjacent "Uncertainty routing"):

| Signal | Route | Main-thread action |
|---|---|---|
| Open-ended project-level "what next?" | Discover | Auto-run `/discover` unless active scope is present |
| External methods / prior art / "how do others solve" | Research | Ask CC-344 narrowing question, then run `/research` |
| Selected ticket blocked by an unknown decision | Spike | Ensure/create spike ticket, run `/spike CC-NNN` |
| Already scoped implementation | Planning/Brief | Do not run an uncertainty mode |

Spike decision rule (answers Q2):

> Use spike only after a candidate/problem is selected and a normal implementation brief
> would be irresponsible because a *durable* feasibility / API / architecture decision must
> first be made and committed. `/discover` chooses options; `/research` imports external
> options; spike commits a decision.

Spike triggers: a `spike`-epic ticket exists; the PM cannot write a brief without resolving
an implementation-blocking unknown (API shape, schema boundary, adapter feasibility,
migration strategy, tool-adoption verdict, cross-layer ownership); the answer must be
committed to `docs/spikes/CC-NNN.md`; the investigation benefits from 2–3 independent angles
(main-thread fan-out); a tool verdict needs a `test_target:` + GREEN/AMBER/RED rubric.
Non-triggers: vague "what next?" (→ discover), "what do others do?" (→ research),
explain-this-code (→ Analysis), plan-an-understood-ticket (→ Planning/Brief).

## Open risks

- **Router over-firing**: auto-running `/discover` on tactical "next step for this ticket"
  questions would be noisy. The active-scope guard (don't auto-fire when a ticket/PR/bug is
  already named) is load-bearing and must be tested, not just stated.
- **`/research` topic invention**: if the auto-offer logic is too eager it will fabricate a
  topic. The directioning question must be mandatory before any WebSearch.
- **CC-344 anchoring drift**: building `/research` before CC-403 risks a bespoke memory-grep.
  Mitigated by isolating anchoring into one step with a documented swap-point to
  `pmctl context --source memory`.
- **CC-220 structural invalidity**: an `agents/spike.md` that tries to spawn agents is
  structurally invalid — it must be a planner whose `spike_plan` the main thread fans out.

## Next tasks

- **CC-408** (new) — next-step router: project-pm Classify route + pm.md main-thread
  orchestration + `/discover` output `suggested_next_action`/`refs`. Phase 1 pure-docs.
- **CC-344** (build now) — `commands/research.md`; anchoring with swap-point to CC-403;
  post-research persistence rule; no-auto-ticket contract.
- **CC-220** (build now) — `agents/spike.md` (planner) + `commands/spike.md`; main-thread fan-out.
- **CC-244** — leave deferred until the documented 3+ spike-doc trigger fires (typed
  spike→brief schema is premature now).
