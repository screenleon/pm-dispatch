# CC-385: Dispatch-model unification — brief authored by trusted code, executor consumes (scope)

**Type**: design spike (decision-only; no implementation in this ticket)
**Author**: project-pm (main thread)
**Status**: open — pending decision
**Relates**: CC-333 (runtime decoupling, hook-mechanism layer), CC-374 (guard collapse — enabler), CC-383 (claude already on this model), CC-366 (dispatch auto-pack), dispatch-route-primary (current user preference)

## Problem / why now

The executor write-guard today has an unavoidable asymmetry (consolidated, not removed, by CC-374):

- **codex** runs as an in-harness `Agent(codex-executor)` subagent that **writes its own brief** to `/tmp` via the host's Write tool → the only place to gate that write is a **live PreToolUse hook** → `write_guard_mode=hook`.
- **claude** (since CC-383) runs as an **independent headless `claude --print` subprocess** with the brief passed in → no agent writes a brief via the host → `write_guard_mode=cli-only`.

So the live-hook half of the guard exists **only because the codex-executor subagent authors its own brief**. If every executor instead consumed a brief authored by trusted code (the `pmctl dispatch run` path, which already exists for codex), the live hook would be unnecessary and `write_guard_mode` could be **uniformly cli-only**.

This spike decides whether to make "trusted code authors the brief → executor runs as an independent subprocess consuming it" the **sole** dispatch model, retiring the subagent-authors-its-own-brief path.

## The two models

- **Model A — subagent authors its own brief** (current codex path): main thread spawns `Agent(codex-executor)`; the subagent writes the brief (live-hook gated) and dispatches the executor.
- **Model B — trusted code authors the brief, executor consumes** (proposed; claude's CC-383 path; `pmctl dispatch run`'s path): `pmctl` lands the brief; the executor runs as an independent subprocess with the brief passed in. No agent ever holds brief-write authority.

## Trade-offs

| Dimension | Model A (subagent self-writes) | Model B (trusted code writes, subprocess consumes) |
|---|---|---|
| Control / trust boundary | reactive: agent has Write authority, gated after the fact by a live hook | proactive: executor never has brief-write authority; one guard check before dispatch |
| Guard complexity | needs live PreToolUse hook + cli-only (the CC-374 asymmetry) | single cli-only check point, atomic with dispatch |
| Runtime-agnostic | depends on the host having a PreToolUse hook mechanism (Claude-specific) | no platform hook required → advances CC-333 |
| Reproducible / automatable | harness-bound; not replayable headless (CI/cron) | pure subprocess; replayable; trace + exit code integrity-checkable |
| Token economy | extra Claude agent turn; the subagent re-reads context the main thread already holds | no intermediary; main thread (which already understands the project) authors the brief |
| Auth / credentials | subagent inherits the host's live session | independent subprocess needs its own auth **(ASSUMED pre-logged-in — see decision D3)** |
| Executor intelligence | an agent could assemble the brief interactively | brief pre-authored — but pm-dispatch's executors are deliberately thin, so unused |
| Applicability | only path for a runtime with no standalone CLI | requires the runtime to have a runnable CLI (codex/claude both do) |

## User framing (2026-06-14)

1. **Auth is assumed pre-logged-in.** Model A's only hard advantage (credential inheritance) is therefore out of scope — Model B's auth cost is treated as a solved precondition, not a blocker.
2. **Token duplication via the intermediary subagent.** The main thread has already read and understood the project. In Model A the dispatched subagent starts fresh and **re-reads** what the main thread already knows — duplicate token spend just to author/forward a brief. Model B removes that intermediary; and if the brief carries the main thread's digested understanding (context-pack, CC-366), the executor re-discovers less too.

With both of these, Model B's two named downsides (auth, agent-intelligence) fall away for this system, and Model A's intermediary becomes pure overhead.

## Design wrinkles to resolve in the spike

- **D1 — who authors the brief?** It must NOT be the PM agent via its Write tool: the pm-write-guard restricts PM writes to the memory dir, so `/tmp/brief-*.md` would be denied. Candidate: **`pmctl` lands the brief** (pmctl is already the sole trusted machine-state writer, CC-309), or `pmctl dispatch run` accepts brief content directly. Resolve the exact authoring surface + which guard (if any) applies to it.
- **D2 — context-pack into the brief (CC-366).** To realize the token win, the brief should carry the main thread's digested context so the executor doesn't rediscover from scratch. Decide how this composes with auto-pack (pointer-only today, opt-in OFF).
- **D3 — executor independent auth.** Assumed pre-logged-in (user). Spike should still document the precondition + a clear failure mode if an executor CLI is unauthenticated (fail loud, not silent).
- **D4 — retire the subagent path?** Model B implies retiring `Agent(codex-executor)` self-authoring dispatch. This contradicts the current stated preference (dispatch-route-primary). Decide: retire fully, or keep the subagent path as a fallback for no-CLI runtimes while making Model B the documented default.
- **D5 — guard collapse follow-through.** Once no executor self-authors a brief, codex flips to `cli-only` (a one-line manifest change thanks to CC-374's per-flag override seam) and the live-hook write-guard machinery can be retired. Sequence this so the guard is never weakened mid-migration.

## Why CC-374 is the enabler, not wasted

CC-374 turned `write_guard_mode` into a **manifest declaration** and collapsed the two duplicated policies into one wrapper. So adopting Model B later is cheap: flip codex's `write_guard_mode` to `cli-only` in its manifest (or via the CC-372 per-flag override) — core code unchanged — and eventually delete the now-unused live-hook branch.

## Acceptance (what this spike must output)

A decision — **adopt / partial-adopt / defer** — plus, if adopting:
- the brief-authoring surface (D1) and its guard,
- the context-pack composition (D2),
- the migration order that keeps the guard fail-closed throughout (D5),
- the fate of the subagent path (D4),
- a validation that an independent codex subprocess with a pre-landed brief + pre-authed CLI produces an equivalent result to the current subagent path (one real run each).

## Non-goals

Not implementing the migration here. Not changing CC-374's shipped behavior. Not resolving codex-as-host install (CC-381) — this is the PM→executor dispatch axis, not the host-PM axis.
