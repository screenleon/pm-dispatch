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

**When**: before writing a dispatch brief for any task where `behavioral_units ≥ 3` or `architecture_impact ≠ none` — any change touching a shared module, crossing a layer boundary, or introducing a new interface or schema field.

**Mechanism**: `/pre-impl "<task description>"` — produces a **structured pre-impl artifact** with six fixed sections: Intention, Non-goals, Bounded Context, Conceptual Map, Acceptance Metrics, Verification Plan. Paste the `Conceptual Map` section into the brief's `conceptual_map:` field and the design constraint list into `constraints:`.

The point is not to produce documentation — it is to catch a wrong direction before any code is written. A five-minute pre-impl that reveals a scope disagreement saves a multi-round gate cycle.

### Layer 2 — Cross-Context Isolation

**When**: after the executor finishes; triggered by `/pr-gate`.

**Mechanism**: `/pr-gate` runs its reviewers (`critic`, `qa-tester`, `security-reviewer`, `risk-reviewer`, `architecture-reviewer`) in a review session *separate from the one that produced the diff*. Each reviewer receives a brief with the diff, task context, and (if present) the conceptual map — but not the dispatch session's reasoning, prior attempts, or implicit anchors. The default sequential gate runs the reviewers together in one fresh session (codex or Claude, per `--executor`); the `--parallel` path gives each reviewer its own independent session followed by a PM synthesis pass.

This isolation matters because context-window anchoring is real: a reviewer who watched the code being written will tend to evaluate the approach rather than the outcome. A reviewer who arrives at the finished diff cold asks "does this make sense in isolation?" — a harder and more valuable question.

The isolation *from the dispatch session* is structural, not advisory: the review session is a separate process and cannot read the implementer's context. Per-reviewer independence — each reviewer also blind to the others — is provided by the `--parallel` path; the sequential default trades that for a single combined review session. See [pr-gate-handover-schema.md](pr-gate-handover-schema.md) for the handover protocol.

### Layer 3 — Conceptual Map review

**When**: as part of the Layer 2 gate; specifically the `architecture-reviewer` subagent's role.

**Mechanism**: the architecture-reviewer reads `conceptual_map` first — a plain-text description of the proposed structure — and verifies layer boundaries and module ownership from the map. Source file inspection is used **selectively**: when the map and diff disagree, when a specific risk surface warrants a spot check, when `architecture_impact` is `major`, or when the map is silent on a boundary the diff crosses.

This distinguishes the architecture-reviewer's role as **Architect / Editor** rather than inspector. The aim is to evaluate structural correctness from a ten-line conceptual map without scanning 300 changed lines to form a layer-boundary opinion.

When `conceptual_map` is absent, the architecture-reviewer falls back to diff inspection and notes the absence in its findings — the fallback is slower, noisier, and more likely to produce false-positive findings.

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

For small tasks (`behavioral_units < 3` and `architecture_impact: none`), Layer 1 may be skipped and Layer 3 is lightweight. For tasks with architecture impact, all four layers are active and Layer 3 gets a full conceptual map as input.

### Evidence chain

Each layer produces an artifact that the next layer consumes. This is not abstract philosophy — every arrow carries a concrete handoff:

| Layer | Input | Artifact produced | Consumed by |
|---|---|---|---|
| Layer 1 | task request | `/pre-impl` sections: Conceptual Map + design constraints | brief `conceptual_map:` + `constraints:` fields |
| Layer 2 | final diff + handover brief | isolated reviewer findings (critic / qa / security / risk) | pr-gate synthesis |
| Layer 3 | `conceptual_map` + diff | architecture finding (map vs. diff alignment) | pr-gate synthesis |
| Layer 4 | `self_verify cmd:` entries | command exit codes (pass / fail) | PM / merger decision |

When an artifact is missing — no `conceptual_map`, no `self_verify cmd:`, no isolated review — the downstream consumer degrades or falls back. The four-layer model produces a reliable signal only when the full chain is intact.

---

## pr-gate rigor tiers

The `/pr-gate` `--tier` flag selects the **rigor level** required for this change — not just the number of reviewers. Choose based on `architecture_impact` and blast radius:

| Tier | When | Rigor |
|---|---|---|
| `express` | hotfix, docs-only, `architecture_impact: none` | machine verification + combined session (critic + qa) |
| `standard` | feature, `architecture_impact: minor` | conceptual map required + critic + qa + architecture-reviewer |
| `full` | architectural change, `architecture_impact: major`, sensitive path | parallel cross-context sessions + security + risk hard gates + synthesis |

**Tier suggestion**: when a `--brief` is passed to `pr-gate.sh`, it reads `architecture_impact` from the brief and emits an advisory to stderr before dispatch if the auto-detected tier is lower than the impact level implies. The user-selected or auto-detected tier always takes precedence; the advisory is informational only and does not block or alter the tier.

**Tier vs. reviewer count**: `express` is not "fewer reviewers" — it is "this change has bounded impact and does not need architecture-level judgment." `full` is not "more reviewers" — it is "this change has wide blast radius and needs independent parallel review with hard security/risk gates."

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
- [docs/dispatch-brief.md](dispatch-brief.md) — the brief schema, including `self_verify`, `acceptance`, `conceptual_map`, and `architecture_impact` fields
- [docs/pr-gate-handover-schema.md](pr-gate-handover-schema.md) — the handover protocol that enforces Layer 2 isolation
