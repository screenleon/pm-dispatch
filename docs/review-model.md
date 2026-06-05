# pm-dispatch Review Model

## The core idea: Relocating Rigor

Traditional code review puts rigor in the middle of the pipeline — a human (or AI) reads every changed line after the code is written. pm-dispatch relocates that rigor to the two ends:

- **Upstream**: confirm intention and boundaries *before* the agent starts writing anything.
- **Downstream**: machine-verify postconditions *after* the agent finishes, independent of session context.

The middle — line-by-line diff inspection — becomes an exception rather than the default. It fires only when the upstream check was skipped, when a reviewer flags a structural concern, or when the machine check fails and the cause is not obvious.

---

## The four layers

```
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 1 — Intention & Spec review          (before dispatch)        │
│   What are we solving? What's out of scope? What's the boundary?    │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 2 — Cross-Context Isolation          (pr-gate reviewers)      │
│   Clean sessions read the final product; no dispatch-session bias   │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 3 — Conceptual Map review            (architecture lens)      │
│   Does the structure make sense? Boundaries respected? Map vs diff? │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 4 — Machine Verification             (after gate)             │
│   self_verify cmd: runs postconditions; pass = done, fail = reopen  │
└─────────────────────────────────────────────────────────────────────┘
```

### Layer 1 — Intention & Spec review

**When** (current): before writing a dispatch brief for any task with `behavioral_units ≥ 3`, or when the change touches a shared module or reviewer-flow surface.

> **Planned** (CC-323): the trigger will expand to also cover `architecture_impact ≠ none` once the dispatch brief schema ships the `architecture_impact` field.

**Mechanism**: `/pre-impl "<task description>"` — produces a **design constraint list** of 3–5 structural rules the implementation must not violate. Paste the output directly into the brief's `constraints:` field.

> **Planned** (CC-323): the output contract will be extended to a fixed set of sections — Intention, Non-goals, Bounded Context, Conceptual Map, Acceptance Metrics, Verification Plan — aligning with the `conceptual_map:` and `acceptance:` brief fields.

The point is not to produce documentation — it is to catch a wrong direction before any code is written. A five-minute pre-impl that reveals a scope disagreement saves a multi-round gate cycle.

### Layer 2 — Cross-Context Isolation

**When**: after the executor finishes; triggered by `/pr-gate`.

**Mechanism**: `/pr-gate` runs its reviewers (`critic`, `qa-tester`, `security-reviewer`, `risk-reviewer`, `architecture-reviewer`) in a review session *separate from the one that produced the diff*. Each reviewer receives a brief with the diff, task context, and (if present) the conceptual map — but not the dispatch session's reasoning, prior attempts, or implicit anchors. The default sequential gate runs the reviewers together in one fresh session (codex or Claude, per `--executor`); the `--parallel` path gives each reviewer its own independent session followed by a PM synthesis pass.

This isolation matters because context-window anchoring is real: a reviewer who watched the code being written will tend to evaluate the approach rather than the outcome. A reviewer who arrives at the finished diff cold asks "does this make sense in isolation?" — a harder and more valuable question.

The isolation *from the dispatch session* is structural, not advisory: the review session is a separate process and cannot read the implementer's context. Per-reviewer independence — each reviewer also blind to the others — is provided by the `--parallel` path; the sequential default trades that for a single combined review session. See [pr-gate-handover-schema.md](pr-gate-handover-schema.md) for the handover protocol.

### Layer 3 — Conceptual Map review

**When**: as part of the Layer 2 gate; specifically the `architecture-reviewer` subagent's role.

**Mechanism**: the architecture-reviewer's intended primary input is `conceptual_map` — a plain-text description of the proposed structure — from which it verifies layer boundaries and module ownership *before* looking at any source lines. Source file inspection is reserved for cases where the map and the diff disagree, or where a specific risk surface warrants a spot check.

> **Planned** (CC-326): this conceptual-map-first ordering is the target reviewer prompt and lands once CC-326 updates `architecture-reviewer` (and the brief ships the `conceptual_map` field under CC-324). Today the architecture-reviewer still leads with diff inspection and treats `conceptual_map`, when present, as supporting context rather than primary input.

This distinguishes the architecture-reviewer's intended role as **Architect / Editor** rather than inspector. The aim is to evaluate structural correctness from a ten-line conceptual map without grepping through 300 changed lines to form a layer-boundary opinion.

When `conceptual_map` is absent, the architecture-reviewer falls back to diff inspection — which is slower, noisier, and more likely to produce false-positive findings. Under the target model the map is not optional decoration; it is meant to be the reviewer's primary input.

### Layer 4 — Machine Verification

**When**: at the end of every executor run; the executor itself evaluates `self_verify` before declaring done.

**Mechanism**: the `self_verify:` block in a dispatch brief contains one or more postcondition checks. Items tagged `cmd:` are shell commands the executor runs; a non-zero exit means the task is *not* done, regardless of what the diff looks like. The outer `codex-executor` (or `claude-executor`) then re-checks `acceptance:` from outside the subagent.

```
self_verify:
  - cmd: "bash scripts/lint-agents.sh"
  - cmd: "bash scripts/test-run-all-tests.sh"
  - git-status no-collateral-damage    # executor-evaluated (not a shell cmd)
```

The pairing matters:

| Field | Evaluated by | Purpose |
|---|---|---|
| `self_verify cmd:` | executor (inside) | prove done before returning |
| `acceptance:` | codex-executor (outside) | contract from the brief author's perspective |

If machine verification passes, the task is done. If it fails, it re-opens. This replaces "looks good to me after a quick scan" with a reproducible binary signal.

---

## How the layers interact

```
/pre-impl → dispatch brief → executor → /pr-gate → merged
    L1            L1               L4      L2+L3+L4
```

A typical task flows left to right. Each arrow is a checkpoint; a failure at any checkpoint stops forward motion rather than producing a bad merge.

For small tasks (`behavioral_units < 3`), Layer 1 may be skipped and Layer 3 is lightweight. For tasks with significant architecture impact, all four layers are active and Layer 3 gets a full conceptual map as input.

---

## When line-by-line review is appropriate

Line-by-line code inspection is not banned — it is *demoted to an exception*. Use it when:

- The upstream intention check was skipped and the diff reveals an approach that seems wrong.
- A Layer 2 or Layer 3 reviewer flags a specific structural concern and the conceptual map does not resolve it.
- Machine verification fails and the root cause is not obvious from the failing command's output.
- The task was a spike or research output (no `self_verify` was possible) and the reviewer needs to evaluate reasoning quality.

In all other cases, the four-layer model gives a faster signal with less noise.

---

## Cross-references

- [docs/CONCEPTS.md](CONCEPTS.md) — the four Claude Code extensibility surfaces (hooks / slash commands / subagents / memory) that implement this model
- [docs/dispatch-brief.md](dispatch-brief.md) — the brief schema, including the `self_verify` and `acceptance` fields (the `conceptual_map` field is planned under CC-324)
- [docs/pr-gate-handover-schema.md](pr-gate-handover-schema.md) — the handover protocol that enforces Layer 2 isolation
