# Portable Skill Substrate — idea capture (2026-06-16)

> Status: **idea seed**, not committed design. Tracked by `CC-393` (🟢 someday,
> post-v0.6.0). This note preserves a session synthesis so the idea is not lost;
> it is *not* a milestone commitment. Revisit when planning v0.7.0 (the MCP
> universal bridge, `CC-216`) — the two are the same story at different layers.

## Core thesis

pm-dispatch should dispatch **skill-guided agents**, not just agents. A "skill"
is a **platform-neutral working method** (a portable Markdown contract), kept
strictly separate from execution and state.

```
Agent       = executor
Skill       = method (portable Markdown contract)
pm-dispatch = control plane (task / context / permission / verify / memory)
Tool layer  = permission boundary
Adapter     = platform translation
```

## Five design principles

1. **Platform-neutral skills.** Core `SKILL.md` carries no Claude/Codex/OpenCode
   commands; platform differences live in `adapters/` only.
2. **Capability matching, not platform names.** Skills declare
   `requires_capabilities`; adapters declare what they provide; dispatch matches
   on capability + cost.
3. **Skills do not execute, hold state, or know the platform.** A skill is a
   checklist / output contract. Shell, file writes, status transitions belong to
   the tool layer / core.
4. **Evidence-based completion.** No verification evidence → a task stays
   `IMPLEMENTED`, never `VERIFIED`/`CLOSED`. (pm-dispatch already does this via
   `pmctl` post-verify — `CC-386`.)
5. **Runtime injection, not global install.** Compose the prompt per dispatch and
   record `used_skills@version`; do not pollute `~/.claude/skills` etc.

## Why this is mostly *already built* (the important caveat)

Much of what an external "skills repo" would offer, pm-dispatch grew
independently. The seed is about **naming/indexing an existing control layer**,
not filling a hole:

| Idea | Current state |
|------|---------------|
| adapter translation layer | `adapters/<name>/` + manifest (v0.6.0) |
| capability / runner-kind declaration | `adapter.yaml` runner_kind + derived flags (CC-372) |
| evidence-based completion | `pmctl` post-verify sole verifier (CC-386) |
| guard control layer | manifest-driven guards (CC-374/375) |
| MCP universal bridge | planned v0.7.0 headline (CC-216) |
| guard-aware brief | partial: `dispatch-brief` skill exists |

## Two skill classes (the higher-leverage half)

- **Task skills** — improve dispatch briefs: context-pack, writing-plan,
  execute-plan, code-review, verification-gate.
- **Control skills** — maintain pm-dispatch's own control layer (higher value
  here given the existing Markdown + guard volume):
  - `guard-aware-brief` — brief lists relevant controls + expected guards +
    completion condition.
  - `guard-result-review` — turn guard pass/fail into a workflow decision
    (without mutating state).
  - `markdown-drift-audit` — catch Markdown ↔ script ↔ template ↔ core drift.
  - `control-map` / `policy-coverage-audit` — policy → guard → evidence matrix;
    classify hard / soft / partial / orphan.

Closed loop: **rule (Markdown) → brief (cite) → guard (enforce) → evidence →
state decision**.

## Boundaries (the three red lines)

```
Skill does not run shell / query DB / mutate task status / bypass guards / act
as a workflow engine.
Markdown states rules · scripts enforce · skills select+apply+explain+audit ·
core does state transitions and records.
```

## Smallest landing (when resumed)

Do not build 8 skills, a marketplace, global install, or a skill DSL. Start with
three control skills that amplify existing Markdown + guards without adding
weight: `guard-aware-brief`, `guard-result-review`, `markdown-drift-audit`,
behind a thin "Portable Skill v0" frontmatter spec.

## Sequencing

Resume **after v0.6.0** (executor abstraction proven at N≥2 via `CC-376` +
`CC-377`). The natural home is alongside `CC-216` (v0.7.0 MCP bridge): both make
any host share one pm-dispatch via a stable, platform-neutral contract.
