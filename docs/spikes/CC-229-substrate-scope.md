# CC-229 — v0.3.0 M1 state / schema substrate: spike scope

**Status**: investigation/design scope — shared by two independent design spikes
(Codex CLI + Claude Plan). Each spiker produces an independent proposal against
Section 6 below; the main thread (Claude PM + user) synthesizes the strengths
into one M1 implementation plan.

**Date**: 2026-05-24
**Branch**: `spike/m1-substrate` @ `3a17ccf4`
**Tickets in scope**: CC-229, CC-230, CC-231, CC-232 (one milestone, four tickets, one substrate)
**Tickets this enables** (must not pre-empt): CC-211 epic, CC-202, CC-204, CC-200, CC-215 (`pmctl`), CC-216 (MCP, v0.4.0), CC-232/CC-237 context-pack consumers, CC-233 layer-boundary test, CC-234 memory v2, CC-235 lifecycle gate

---

## 1. The question to answer

What is the **smallest schema + state-store layout** that:

1. Lets CC-211 / CC-215 / CC-216 / CC-232 build on top of it **without re-shaping** it later (schema locked at end of M1; later changes are versioned breaking events — see synthesis §8 R3 and `[[breaking_change_for_maintainability]]`);
2. Is **CLI-agnostic by construction** — usable through `pmctl` from Claude Code today, Codex CLI / Antigravity / OpenCode later, with no schema field or storage path named after one CLI's hook taxonomy (per `[[feedback_memory_cli_agnostic]]`);
3. Migrates one existing surface (`routing_log.md` auto-block → `runs.jsonl`) as the single budgeted breaking migration, while leaving four other surfaces (`pm-prep-snapshot.sh`, `codex-dispatch.sh`, `handover-validate.sh`, `BACKLOG.md` / `DECISIONS.md`) **structurally compatible** through a thin adapter step;
4. Ships with **no behavior change** — every existing consumer continues to work after M1 lands; M2's `pmctl` is what activates the substrate (synthesis §8 R3).

Citations:
- `MILESTONES.md:37-44` — M1 ticket list
- `docs/architecture/v0.3.0-synthesis.md:84-167` — four-layer + substrate detail (§5.1, §5.2, §5.3)
- `docs/architecture/v0.3.0-synthesis.md:203-227` — risk + sequencing constraints
- `BACKLOG.md:1209-1269` — CC-229 / CC-230 / CC-231 / CC-232 deep sections
- `[[feedback_memory_cli_agnostic]]` — CLI-agnostic invariant
- `[[breaking_change_for_maintainability]]` — prefer breaking shape change over compat hacks
- `[[project_memory_architecture]]` — repo-split + future memory phases

---

## 2. In-scope entities

Seven entities — five are first-class state, two are first-class definitions.
"Currently" = where the concept lives today; "Target" = where it goes in `core/`.

| Entity | Currently (file / surface) | Target (in-repo definition) |
|---|---|---|
| **Task** | `BACKLOG.md` markdown row + body section (grammar in `pm/schema.md`) | `core/schema/task.schema.json` + re-home `pm/schema.md` → `core/schema/backlog-grammar.md` |
| **Run** | `.agent-trace/codex-<ts>.{jsonl,last,stderr}` + machine-written `routing_log.md` auto-block (anti-pattern) | `core/schema/run.schema.json` |
| **Event** | scattered: trace JSONL events, hook stderr logs, gate result files, BACKLOG.md status-flips | `core/schema/event.schema.json` (append-only) |
| **Review** | `.gate-results/<gate-id>/<reviewer>.{json,md}` + the synthesized `Final: GO|NO-GO` doc; reviewer-policy prose in `agents/project-pm.md:45-91` | `core/schema/review.schema.json` + `core/policy/reviewer-policy.yaml` |
| **Decision** | `DECISIONS.md` markdown rows + per-project memory `## Decisions / constraints` section | `core/schema/decision.schema.json` (DECISIONS.md stays Markdown-primary) |
| **Brief** | inline prose in `agents/project-pm.md:97-156`, `dispatch_handover_v1` block body, `docs/dispatch-brief.md` schema | `core/schema/brief.schema.json` + `core/schema/handover.schema.json` (related but distinct: brief is the work definition, handover is the dispatch envelope) |
| **ContextPack** (CC-232) | does not exist; brief `files:` block is the closest analogue | `core/schema/context-pack.schema.json` + `core/context-pack/source.interface.{md,ts/json-schema}` |

**Also in scope as definitions (not state)**:

- `core/policy/executor-enum.yaml` — the closed enum `{codex, claude}` currently hard-coded in `scripts/lib/handover-validate.sh:121-125`
- `core/policy/dispatch-states.yaml` — the dispatch state machine (currently implicit: brief → dispatched → verifying → ok/partial/failed, see synthesis §5.2 table)
- `core/policy/reviewer-policy.yaml` — the gate matrix (critic/architecture-reviewer advisory, security/risk/qa hard gate) currently in `agents/project-pm.md:45-91`
- `core/policy/task-states.yaml` — Task lifecycle `open → claimed → in-progress → blocked → done/dropped` (synthesis §5.2)
- `core/policy/run-states.yaml` — Run lifecycle `pending → dispatched → verifying → ok/partial/failed`

---

## 3. State store layout (`~/.claude/.pm/state/`)

Synthesis §5.2 fixes the location: `~/.claude/.pm/state/` — *definitions in repo, state on disk; per-machine, gitignored*. The dir name lives under `~/.claude/` only because that path is already an installer-managed symlink today; the **storage path is treated as a CLI-agnostic location** managed by `pmctl` (per `[[feedback_memory_cli_agnostic]]`). Future adapters must reach it only via `pmctl`, never by globbing the dir.

**Required answers from each spiker**:

1. Directory tree under `~/.claude/.pm/state/` — name every file and sub-directory the substrate writes.
2. File naming convention — JSONL append targets (`runs.jsonl`, `events.jsonl`?), per-entity index (`runs.index.json`?), per-task scoping (`tasks/<id>/...`?) — pick one shape and justify.
3. Locking strategy — single-writer guarantee uses `serialize_with_lock()` from `scripts/lib/portable.sh` (CC-104p, Windows-portable shim). Specify which files need locking and the lock granularity (per-file? per-store?).
4. Lifecycle / GC — do append-only logs ever rotate? Is there a TTL? A compaction step? Or is "infinite append + rare manual archive" acceptable?
5. Atomic-write semantics — write-temp-then-rename for the index? Same for any non-append file?
6. Cross-machine concern — the store is per-machine and gitignored, but `[[project_memory_architecture]]` mentions a future memory-private split. Should `~/.claude/.pm/state/` be similarly factorable later? Or is M1 strictly local?

---

## 4. Module boundaries (what may import what)

`core/` must be **pure definitions** (synthesis §5.1: "knows nothing executable — definitions only"). Spikers propose a dependency graph for these sub-modules:

```
core/schema/           — JSON Schema files (.schema.json)
core/policy/           — declarative tables (YAML or JSON)
core/state/            — definitions of the state-store layout (NOT the runtime)
core/context-pack/     — context-pack schema + the source interface contract
```

**Required answers from each spiker**:

1. Which sub-modules may reference each other? (E.g. may `core/state/` reference `core/schema/` JSON Schemas? May `core/policy/` reference schema enums?)
2. What is the file format for each sub-module — JSON Schema (`.schema.json`), YAML (`.yaml`), Markdown grammar (`.md`), or something else? Justify per sub-module.
3. JSON Schema source-of-truth strategy — `pmctl` is bash (synthesis §8 R4); is JSON Schema authored hand or generated? Validation tool (`ajv-cli`? hand-rolled `jq`?)
4. Where do TypeScript type definitions live, if anywhere? (M1 has no TypeScript yet; CC-216 MCP server is v0.4.0 and may add Node. Decide: TS types in M1 (forward-compat) vs JSON-Schema-only (defer until MCP).)
5. `core/state/` is the **definition** of the on-disk layout, not the runtime that writes it. Where does the actual writer live (M2's `pmctl`)? The spiker must name the boundary so M2 has somewhere to insert.

---

## 5. Migration path (consumer-by-consumer)

The five existing surfaces below must keep working through M1 (no behavior change). Each spiker delivers a per-surface migration row.

| # | Surface | Today's shape | M1 expected change | Risk class |
|---|---|---|---|---|
| 1 | `pm-prep-snapshot.sh` | writes typed YAML frontmatter snapshot to `/tmp/pm-snapshot-*.md` (see `scripts/pm-prep-snapshot.sh:255-310`) | shape must align with new `core/schema/snapshot.schema.json`? OR no change in M1, snapshot stays a one-shot pre-spawn artifact and gets schema'd in M2? | low (one writer, one reader, transient file) |
| 2 | `codex-dispatch.sh` | CLI args + writes `.agent-trace/codex-<ts>.{jsonl,last,stderr}` + auto-logs to `usage-tracker.jsonl` + appends to `routing_log.md` auto-block (see `scripts/codex-dispatch.sh:296-334`) | continues to write trace files unchanged; the `routing_log.md` append becomes an append to `runs.jsonl` via a new helper (the budgeted migration); CLI surface unchanged | **medium** (the one breaking migration) |
| 3 | `handover-validate.sh` | inline-validates `dispatch_handover_v1` metadata; hardcodes `executor` enum `{codex, claude}` (`:121-125`) and `dispatch_route` enum (`:131-135`) (see `scripts/lib/handover-validate.sh:117-135`) | consumes `core/policy/executor-enum.yaml` and `core/policy/dispatch-states.yaml` instead of hardcoded `case` blocks? OR keep hardcoded in M1 and convert in M2 when `pmctl validate` extracts the validator? | low (validator is well-tested) |
| 4 | `BACKLOG.md` / `pm/schema.md` | Markdown-primary BACKLOG rows + grammar in `pm/schema.md` (see `pm/schema.md` v1.2) | re-home `pm/schema.md` under `core/` (synthesis §5.1: "`pm/` folds into `core/`"); add `core/schema/task.schema.json` as a parallel definition that documents the same rows, without replacing the Markdown source | low (Markdown stays primary; schema is documentation-of-existing) |
| 5 | `DECISIONS.md` | Markdown-primary decision log | add `core/schema/decision.schema.json` as documentation-of-existing; no migration | trivial |
| 6 | `routing_log.md` auto-block | machine-written Markdown table (anti-pattern, synthesis §5.2) inside an otherwise human-edited `routing_log.md` | promote the auto-block content to `runs.jsonl` (M1 budget); the Markdown table either gets deleted or replaced with a generated stub pointing at the JSONL | **medium** (the migration) |

**Required answers from each spiker**:

1. For each surface 1–6, name **exactly one** of: `no change M1`, `add schema definition only M1`, `extract policy M1`, `breaking migration M1`. Justify each.
2. For surface 2 (`codex-dispatch.sh` / `runs.jsonl`), specify the append helper interface (function name, location, single-writer guarantee, what fields a Run row contains).
3. For surface 6 (`routing_log.md`), specify what replaces the human-readable view — is `routing_log.md` regenerated from `runs.jsonl` via a renderer, or is it abandoned in favor of a `pmctl runs ls` command (M2)?

---

## 6. Required deliverable shape (each spiker produces this)

Both spikers' output documents must contain these six sections, in this order, so the synthesis step can compare like-with-like. Output goes to `docs/spikes/CC-229-substrate-{codex,claude}.md`.

### Section A — Entity type sketches

For each of the 7 entities in §2, give a ≤30-line JSON Schema (`.schema.json` body) **or** TypeScript interface sketch. Include required fields, allowed enums, lifecycle states (link to the policy file in §B). Do not write boilerplate `$schema` / `$id` headers unless the choice is load-bearing.

### Section B — Directory tree + filenames

ASCII tree for both:
- In-repo: `core/schema/*`, `core/policy/*`, `core/state/*`, `core/context-pack/*` (every file named)
- On-disk: `~/.claude/.pm/state/*` (every file + sub-directory the substrate writes)

### Section C — Module dependency graph

A diagram (ASCII or table) showing which `core/` sub-module may import which. Use the form `core/X → core/Y` (X depends on Y). Include the `core` → `runtime` boundary (M2's `pmctl` writers) as an outgoing arrow from `core/state/`.

### Section D — Migration checklist (surface-by-surface)

A table with one row per surface from §5 (6 surfaces). Columns: `surface`, `M1 change class`, `concrete diff sketch (1 sentence)`, `risk-and-test-plan (1 sentence)`.

### Section E — Open-questions table

A table with one row per open question (§7 below) plus any additional questions the spiker surfaces. Columns: `id`, `question`, `recommended answer`, `reasoning (2 sentences max)`, `confidence (high/medium/low)`.

### Section F — Risks + alternatives considered

A bulleted list (≤ 10 bullets) covering: top risks specific to this spike's choices, alternatives considered and rejected with one-sentence rationale, anything in the synthesis §8 risk list that this spike's choices amplify or mitigate.

---

## 7. Open-questions list (each spiker must take a stance)

These are the design choices the synthesis step expects an answer to. Spikers may add questions but must answer every one of these.

| id | question | why it matters |
|---|---|---|
| Q1 | **JSON Schema source-of-truth vs TypeScript-first** | `pmctl` is bash (synthesis §8 R4). JSON Schema is the only format consumable by bash today. But M2 / v0.4.0 MCP server may add Node — does M1 ship `.ts` interfaces alongside `.schema.json` (forward-compat, two files to keep in sync) or `.schema.json` only (one source, generators later)? |
| Q2 | **Single state directory vs per-project** | `~/.claude/.pm/state/runs.jsonl` is one global log across all repos; `~/.claude/.pm/state/projects/<repo>/runs.jsonl` partitions by repo. Today's `.agent-trace/` is per-repo. Trade-off: global = simple, per-project = isolatable + portable. Which? |
| Q3 | **Atomic write semantics for append-only logs** | JSONL append + `serialize_with_lock()` gives single-writer; do we also need fsync? Crash-safety class — best-effort (lose last record) vs durable (no loss)? |
| Q4 | **Should the Brief schema (§2) be in M1 at all** | CC-229's named entities are task/run/event/review/decision; Brief + Handover + ContextPack are arguably the "input side" while those five are the "state side". The synthesis treats them as related but distinct. Does M1 ship Brief + Handover schemas now (one substrate, fewer later breaks) or defer them to M2 (smaller M1, less to lock)? |
| Q5 | **Where does the executor enum live, and is it actually closed** | Today: hardcoded `case "$value" in codex\|claude)` in `handover-validate.sh:121-125`. Synthesis §5.2 says "executor-enum (closed: codex/claude)". But future Antigravity / OpenCode adapters are explicitly v0.4.0 named slots (synthesis §7). Is the enum truly closed in M1, or is the schema an open enum the policy file restricts? |
| Q6 | **Reviewer-policy extraction depth** | The gate matrix in `agents/project-pm.md:45-91` mixes data (which reviewers are advisory vs hard-gate) with prose (override discipline, rule A/B). Does `core/policy/reviewer-policy.yaml` capture only the matrix (clean separation) or also the override rules (single source, but data + prose)? |
| Q7 | **`routing_log.md` after migration** | Six options: (a) delete entirely, (b) auto-regenerate from `runs.jsonl` as a stable view, (c) stub pointing at `pmctl runs ls`, (d) keep human entries above the auto-block boundary and remove only the auto-block, (e) keep the file as a per-user free-form notes file unrelated to runs, (f) other. Pick one. |
| Q8 | **Schema versioning policy** | Per synthesis §8 R3: schema locked at end of M1; later changes are versioned breaking events. What is the version-encoding mechanism? `$id` URL? a `schema_version` field on every payload? `core/schema/v1/...` directory structure? |

---

## 8. Out of scope (explicit non-goals)

These are **not** in the spike's scope and proposing them is a defect:

- **No implementation code** — the spike outputs are design docs and (optionally) example JSON / YAML files, not working bash or runtime code.
- **No PRs against any consumer surface** — `pm-prep-snapshot.sh`, `codex-dispatch.sh`, `handover-validate.sh`, `BACKLOG.md`, `DECISIONS.md` remain untouched until the M1 impl ticket is briefed.
- **No `pmctl` CLI design** — that is CC-215 (M2). The spike may *name* the future `pmctl` surface where a boundary requires it, but must not propose subcommand syntax, flags, or output formats.
- **No MCP surface** — that is CC-216 (v0.4.0). The spike may reference `mcp/README.md` as a design constraint but must not design MCP tools.
- **No migration tooling** — converting existing `routing_log.md` auto-block content to `runs.jsonl` is an M1 impl-ticket concern, not a spike concern. The spike defines the *shape* `runs.jsonl` must take; the conversion script is later.
- **No new memory architecture** — `[[project_memory_architecture]]` Phase 1+ memory schema (event-sourced writes, schema v2, frontmatter validator) is a separate workstream. M1's state substrate must be **compatible with** future memory work (per `[[feedback_memory_cli_agnostic]]` storage location), but does not implement it.
- **No spec for `context-enricher` sources** — CC-237 (M4) builds the rg/git/memory sources. The spike defines the *interface* (source contract) that any source must satisfy; the spike does not enumerate sources.
- **No layer-boundary test** — CC-233 (M3). The spike may suggest forbidden tokens for grep but does not write the test.
- **No spike-pilot rule activation** — per `[[feedback_spike_pilot_required]]`, API-design spikes must include a pilot walkthrough. This scope doc is itself an investigation spike, not an API-design spike. The substrate's pilot walkthrough is owned by the M2 impl ticket (where the first consumer migrates) — the spike output must call this out so it is not forgotten.

---

## 9. Synthesis criteria (how main thread will combine the two spikes)

After both spikers return:

1. **Section A (entity sketches)** — pick the smallest schema per entity that covers both proposals' use cases. Reject fields neither proposal justifies.
2. **Section B (directory tree)** — adopt the simpler tree if both have equal coverage; adopt the more partitioned tree if one is materially safer (e.g. per-project scoping for cross-repo isolation).
3. **Section C (module deps)** — adopt the more restrictive graph (smaller import surface = easier to enforce in CC-233 layer test).
4. **Section D (migration checklist)** — adopt the lower-risk option per surface; if both pick the same change class, adopt the proposal with the more concrete diff sketch.
5. **Section E (open questions)** — when both agree, take the answer; when they disagree, surface the conflict to the user with both reasonings.
6. **Section F (risks)** — union the risk lists, dedupe by underlying cause.

The synthesis is recorded as `docs/spikes/CC-229-substrate-synthesis.md` and becomes the input to the M1 impl-ticket brief.
