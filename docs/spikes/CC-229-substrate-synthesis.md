# CC-229 — v0.3.0 M1 substrate spike: synthesis

**Status**: main-thread synthesis of two independent design spikes.
**Date**: 2026-05-24
**Branch**: `spike/m1-substrate` @ `3a17ccf4`
**Inputs**:
- `docs/spikes/CC-229-substrate-scope.md` (shared scope, PM-authored)
- `docs/spikes/CC-229-substrate-claude.md` (380 lines, Claude Plan agent)
- `docs/spikes/CC-229-substrate-codex.md` (248 lines, Codex CLI, v3 lazy-read brief succeeded after v1/v2 hit context overflow)

**Synthesis rule** (scope §9): pick smallest covering schema; restrict graph; lower-risk migration; agreed Q-answers taken; disagreed Q-answers surfaced to user.

---

## Headline: 3 design questions need user decision

| # | Question | Claude says | Codex says | Why it matters |
|---|---|---|---|---|
| **Q2** | State store partitioning | Per-project (`projects/<repo-sha1>/`) | Single global (`~/.claude/.pm/state/runs.jsonl` flat) | Determines whether cross-repo isolation is structural or via post-hoc filtering. Path shape locks in M1. |
| **Q7** | `routing_log.md` after migration | Dual-write in M1 (auto-block + jsonl), M2 hook cuts over | Auto-regenerate `routing_log.md` from `runs.jsonl` as stub in M1 | Determines whether M1 is a behavior-preserving change or introduces a Markdown-render pipeline. |
| **Q8** | Schema versioning mechanism | `schema_version: <int>` inline field, no directory | Both inline field AND `core/schema/v1/*` directory | Directory versioning forces path moves on every bump; field-only avoids that churn. |

All other 8 Q's converge (see §E below).

---

## Section A — Entity schemas (synthesized)

Adopting Claude's typed shapes throughout — Claude's sketches match the existing surfaces (handover-validate, codex-dispatch trace, /pr-gate output) more tightly. Codex's sketches were thinner and in some places shipped invented fields (`priority: p0|p1|p2` on Brief, `event_type: string` free-form on Event) without grounding.

| Entity | Adopted | Rationale |
|---|---|---|
| Task | **Claude** | `^[A-Z]{1,4}-[0-9]+$` covers JS-/CC-/future prefixes (codex's `^CC-\d+$` over-restricts) |
| Run | **Claude** | Typed `id`, `trace_path`, `model`, `brief_file`, `dispatch_route` — matches `.agent-trace/codex-<ts>.jsonl` shape that already exists. Codex's `payload: object` defers shape decisions. |
| Event | **Claude** | Closed `kind` enum prevents string drift; codex's free `event_type: string` invites adapter-specific kinds (CLI-agnostic invariant violation risk) |
| Review | **Claude** | `tier` + `findings[]` per-reviewer mirrors actual `/pr-gate` output. Codex's flat `reviewer/result/notes` can't represent multi-reviewer gates. |
| Decision | **Claude + 1 codex field** | Claude's `closes[]` and `decision_md_path` + add codex's `evidence[]` array (it's useful and DECISIONS.md does list them) |
| Brief | **Claude** | Mirrors `docs/dispatch-brief.md` 1:1 (working_dir/goal/files/constraints/self_verify/expected_head_sha). Codex's `priority: p0|p1|p2` was invented — pm-dispatch uses `P1/P2/P3` per `pm/schema.md`. |
| Handover | **Claude bonus** | Full handover envelope (handover_version: 2, executor, dispatch_route, sandbox, approval, timeout, model, skip_git_check, fallback_allowed) — exact mirror of `dispatch_handover_v1` schema |
| ContextPack | **Claude** | Typed categorical arrays (files/symbols/memories/risks) with per-item `source` + `confidence` matches CC-232's requirement. Codex's flat `files: array of URI` doesn't enable source attribution. |

**Codex over-reach rejected**: `snapshot.schema.json` was added by codex but the scope says surface 1 (`pm-prep-snapshot.sh`) is `no change M1` with schema deferred to M2. Snapshot stays out of M1.

**Final canonical entity list for M1** (8 schemas + 5 policy files):
- `core/schema/{task,run,event,review,decision,brief,handover,context-pack}.schema.json`
- `core/policy/{executor-enum,dispatch-routes,dispatch-states,task-states,run-states,reviewer-policy}.yaml`

See Claude doc §A for the verbatim JSON Schema bodies — adopted as-is.

---

## Section B — Directory tree (synthesized)

### In-repo `core/` — adopt Claude's tree

Claude's tree adds READMEs and `core/state/layout.yaml` as machine-readable single source of truth for paths. Codex's tree omitted these.

Adopted as-is from Claude §B. Difference from codex:
- + `core/README.md` (what `core/` is / what it must NOT contain)
- + `core/state/README.md` + `core/state/layout.yaml` (Claude has both; codex had only `layout.yaml`)
- − `core/schema/snapshot.schema.json` (codex added, scope says no)
- − `core/context-pack/source.interface.ts` and `*.schema.json` (codex added 3 files; Claude argued contract-as-prose ages better than contract-as-pseudocode for pluggable interfaces — accepted)

### On-disk `~/.claude/.pm/state/` — **CONFLICT — user decision required (Q2)**

Two incompatible shapes:

**Option A (Claude — per-project)**:
```
~/.claude/.pm/state/
├── VERSION
├── store.lock
└── projects/
    └── <repo-sha1>/                  # sha1(git-toplevel abs path)
        ├── repo.json                 # {repo_path, repo_name, first_seen_ts}
        ├── runs.jsonl + runs.lock
        ├── events.jsonl + events.lock
        ├── tasks/<task-id>.json      # one file per task
        ├── reviews/<review-id>.json
        ├── decisions/<decision-id>.json
        ├── context-packs/<task-id>-<ts>.json
        └── archive/                  # rotated jsonl
```

**Option B (Codex — flat global)**:
```
~/.claude/.pm/state/
├── events.jsonl
├── runs.jsonl                # all repos interleaved
├── tasks.jsonl               # JSONL not one-file-per-task
├── reviews.jsonl
├── decisions.jsonl
├── briefs.jsonl
├── context-packs.jsonl
├── snapshots.jsonl
├── manifest.json
├── indexes/<entity>.index.json
└── state.lock
```

**Trade-offs** (taken from both spike docs):

| | Option A (per-project) | Option B (global flat) |
|---|---|---|
| Cross-repo isolation | structural (rsync/rm per project) | filter by `task_id` prefix at read time |
| Disk wipe scope | targeted (`rm -rf projects/<sha1>/`) | requires curated grep + reconstruct |
| Backup granularity | per-project | all-or-nothing |
| Lock contention | per-entity-per-project | per-entity global |
| Implementation complexity (M1) | one extra layer (sha1 derivation) | simpler |
| Symmetry with existing `.agent-trace/` | matches (today is per-repo) | breaks |
| Future memory-private split | already factored | requires re-partitioning |

**Main-thread recommendation**: **Option A (per-project)**. Three reasons:
1. Today's `.agent-trace/` is per-repo — users already think per-project. Going global breaks the mental model.
2. `[[project_memory_architecture]]` Phase 0 already split memory per-repo (memory-private). State-store should mirror that.
3. Lock contention matters as soon as the user dispatches two repos in parallel (which I literally just did in this session — pm-dispatch CC-229 spike + japanese-site CC-251 close-out earlier).

But this is your call — codex's argument for "simpler M1" is legitimate.

---

## Section C — Module dependency graph (synthesized)

Adopt Claude's restrictive graph (smaller import surface = easier CC-233 layer test).

| From → To | Allowed | Notes |
|---|---|---|
| `core/schema/` → `core/policy/` | ✅ | `$ref` to YAML enum/state files |
| `core/schema/` → `core/state/` | ❌ | schema = shape-only |
| `core/schema/` → `core/context-pack/` | ❌ | independent peers |
| `core/policy/` → anything in `core/` | ❌ | policies are leaves |
| `core/state/` → `core/schema/` | ✅ | `layout.yaml` names which schema each path conforms to |
| `core/state/` → `core/policy/` | ❌ | layout = paths, not enums |
| `core/context-pack/` → `core/schema/` | ✅ | source contract → context-pack.schema.json |
| `core/context-pack/` → `core/policy/` | ❌ | sources are pluggable |
| **`core/*` → `runtime/`** | ❌ INVARIANT | CC-233 enforces |
| **`core/*` → `adapters/`** | ❌ INVARIANT | same |
| `runtime/pmctl` → `core/schema/`, `core/state/layout.yaml`, `core/policy/` | ✅ | runtime reads schemas to validate writes |
| `adapters/*` → `runtime/pmctl` | ✅ | adapters get core ONLY via pmctl CLI |
| `adapters/*` → `core/*` | ❌ INVARIANT | adapters never touch core direct |

**Writer boundary (M2 insertion point)**: only `runtime/pmctl/lib/state-writer.sh` writes state files. No hook, command, agent, or adapter writes direct. `scripts/hook-routing-log.sh:199-216` already uses `serialize_with_lock` — same pattern, just relocated under `runtime/`.

Codex's graph allowed `core/state/ → runtime/pmctl` as a forward arrow (mixed direction) — rejected. Boundary should be runtime → core, not the other way.

---

## Section D — Migration checklist (synthesized)

Lower-risk option per surface. Where both pick same class, take the more concrete diff sketch.

| # | Surface | Class | Diff sketch (1 sentence) | Test plan |
|---|---|---|---|---|
| 1 | `pm-prep-snapshot.sh` | **no change M1** (Claude) | Snapshot YAML stays one-shot pre-spawn artifact; schema'd in M2. | No test change needed; output bytes unchanged. (Codex over-reached with `snapshot.schema.json` — rejected per scope §5.) |
| 2 | `codex-dispatch.sh` | **breaking migration M1** | After trace write at `:330`, add one `runs_append "$RUN_JSON"` call to write a Run row to `runs.jsonl`; CLI surface + trace files unchanged. | New `scripts/test-codex-dispatch-runs-append.sh`: (a) trace files byte-identical, (b) `runs.jsonl` gains 1 row per dispatch, (c) state-store failure non-fatal (codex exit preserved). |
| 3 | `handover-validate.sh` | **extract policy M1** | Replace hardcoded `case "$value" in codex\|claude)` at `:121-125` with `_load_enum core/policy/executor-enum.yaml` helper; same for `dispatch_route` at `:131-135`; behavior unchanged. | Fixture per policy enum + test that YAML edit loosens validator without code change. |
| 4 | `BACKLOG.md` / `pm/schema.md` | **add schema definition only M1** | `git mv pm/schema.md core/schema/backlog-grammar.md`; add `core/schema/task.schema.json`; keep `pm/schema.md` as installer-managed symlink. | New `scripts/test-schema-task-mirrors-backlog.sh`: parsed BACKLOG row validates against `task.schema.json`. |
| 5 | `DECISIONS.md` | **add schema definition only M1** | Add `core/schema/decision.schema.json` documenting index-row shape; no file moves. | One fixture parsing existing DECISIONS.md row against schema. |
| 6 | `routing_log.md` auto-block | **breaking migration M1** | **CONFLICT — Q7 decision needed.** Claude: dual-write in M1 (auto-block kept, jsonl also written), M2 cuts hook. Codex: M1 already replaces Markdown auto-block with generated stub pointing at jsonl. | Both depend on Q7 answer. |

---

## Section E — Open-questions answers

### Converged (5 answers taken)

| Q | Answer | Source |
|---|---|---|
| **Q1** | JSON Schema only in M1. TS interfaces generated later via `json-schema-to-typescript` when v0.4.0 MCP needs them. | Both agree |
| **Q3** | `serialize_with_lock` + `printf >> file` + best-effort write. No per-write fsync (opt-in via `PM_STATE_FSYNC=1`). Crash-safety: best-effort, never partial/torn row (PIPE_BUF guarantee for <4KB rows). | Both agree (Claude has more detail) |
| **Q4** | **Yes — ship Brief + Handover schemas in M1.** Cost ~80 lines JSON Schema; not schematizing now means re-locking later as breaking change when `pmctl validate` extracts the validator (synthesis §8 R3 hazard). | Both agree |
| **Q5** | `core/policy/executor-enum.yaml` with `values: [codex, claude]`. **Treated as closed in M1.** v0.4.0 Antigravity/OpenCode adapters add an entry — one-line breaking event. No "open in schema, closed in policy" — over-engineering. | Both agree |
| **Q6** | Matrix only in YAML (reviewers, advisory-vs-hard-gate, applicable phase). **Override discipline (Rule A/B) stays in `agents/project-pm.md:70-91`** — judgment-as-prose; splitting produces drift. | Both agree |

### Genuinely added by Claude only (3 answers taken)

| Q | Answer | Why |
|---|---|---|
| **Q9** | Append-only log rotation: `runs.jsonl`/`events.jsonl` → `archive/<entity>-<YYYYMM>.jsonl.gz` when size > 50 MB OR age > 90 days. ContextPacks keep last 5 per `task_id`. Rotation runs at future `pmctl maintenance` (name reserved, M2). | Codex flagged this as a §F risk; Claude proposed a concrete answer. Taking Claude's. |
| **Q10** | M1 is strictly per-machine local. Per-project partitioning (Q2 Option A) is already the factoring boundary for future memory-private split — `rsync -a projects/<sha>/` between machines, no path rewrites. | Only matters if Q2 = per-project. If Q2 = global, this Q is moot. |
| **Q11** | M1 impl ticket for CC-230 owns the pilot walkthrough (per `[[feedback_spike_pilot_required]]`). Pilot consumer = surface #2 (`codex-dispatch.sh` → `runs_append`). | Spike-pilot rule activation point. |

### Conflicts to surface — 3 user decisions needed

#### Q2 — Single global vs per-project state directory

| Claude (recommend) | Codex |
|---|---|
| **Per-project** `projects/<sha1(git-toplevel)>/` | **Global** flat `runs.jsonl` |
| matches existing `.agent-trace/` mental model | matches "minimize M1 migration scope" framing |
| isolatable backup/wipe | simpler tree, fewer moving parts |
| natural future memory-private split | partition can be added as v2 breaking event later |

**My recommendation**: **Per-project**. See §B above for full reasoning.

#### Q7 — `routing_log.md` migration shape

| Claude (recommend) | Codex |
|---|---|
| **Dual-write in M1** (hook keeps writing auto-block AND `runs.jsonl`); M2 drops hook write | **M1 replaces auto-block with generated stub** pointing at jsonl |
| Zero-disruption M1 (humans + scripts see no change) | Smaller M1 surface (one shape, not two) |
| M2 is a small hook edit | M1 needs render logic for the stub |
| Risk: dual-write maintenance for one milestone | Risk: render logic correctness in M1 (codex flagged this) |

**My recommendation**: **Claude's dual-write**. Safer for "M1 = zero behavior change" invariant (synthesis §8 R3 explicit goal). Codex's stub-in-M1 builds rendering logic before the canonical data path is stable.

#### Q8 — Schema versioning mechanism

| Claude (recommend) | Codex |
|---|---|
| `schema_version: <int>` field on every payload only | Inline field **AND** `core/schema/v1/*` directory |
| Bash-readable (`jq '.schema_version'`); survives file moves | Two enforcement surfaces; directory move on every bump |
| No path break on schema evolution | Forces path moves — exact churn `core/` is designed to avoid |

**My recommendation**: **Claude's field-only**. Codex's directory versioning is the failure mode the in-repo `core/` boundary explicitly avoids.

---

## Section F — Risks (union, deduplicated)

From both spikes' §F lists, deduplicated by underlying cause.

1. **Per-project partitioning locks path shape** (Claude R-design-1 / Codex Risk-2): if a future need wants project-namespaced IDs or cross-repo task graphs, the partition path becomes breaking. Mitigation: `repo.json` per partition preserves debuggability so re-partitioning is renaming, not data migration. (Risk only if Q2 = per-project.)

2. **Dual-write maintenance burden** (Claude R-design-2): if Q7 = dual-write, two writers exist for one milestone. Mitigation: data shape identical, no semantic drift; M2 hook-cutover ticket is small.

3. **`core/policy/*.yaml` `$ref` from JSON Schema is non-standard** (Claude R-design-3): most JSON Schema tooling expects `$ref` to JSON. Mitigation: M2 `pmctl validate` uses `yq → jq` not generic resolver. Fallback: rewrite policies as JSON if YAML proves brittle.

4. **CLI-agnostic invariant drift** (Codex Risk-4 / cross-cutting): one stray field named `claude_*` or `codex_*` in any schema breaks the invariant. Mitigation: CC-233 layer-boundary test greps for forbidden tokens.

5. **State-store failure must not break dispatch** (synthesis surface #2 risk): if `runs_append` fails, `codex-dispatch.sh` must still exit with codex's own exit code. Mitigation: explicit non-fatal path + test case.

6. **Schema-version bump churn** (Codex Risk-3 / Claude implicit): bumping `schema_version` later requires every consumer to handle both. Mitigation: schema locked at end of M1 (synthesis §8 R3); breaking events accompanied by `CHANGELOG.md` + `DECISIONS.md` entry.

7. **ContextPack source contract drift** (Claude R-design-4): contracts-as-prose age better than contracts-as-pseudocode; CC-237 source authors implement the contract in bash without schema-validation. Mitigation: keep `source.interface.md` as the prose contract; no programmatic enforcement until v0.4.0 MCP demands it.

8. **`routing_log.md` render fidelity** (Codex Risk-1, only if Q7 = codex's stub option): malformed rows hidden by render logic. Mitigation only if Q7 = codex: snapshot tests against legacy table format.

9. **TOCTOU / symlink-jump on state writers** (cross-cutting, both implicit): attacker swaps symlink between realpath and write. Mitigation: PreToolUse hooks can't prevent TOCTOU — out of scope. Same risk class as existing surfaces.

10. **`pmctl` (M2) hasn't been designed yet** (synthesis §8 R7 / cross-cutting): `core/state/layout.yaml` names paths but the writer that reads it doesn't exist. Mitigation: scope explicitly leaves `pmctl` design to CC-215 (M2); this spike only specifies the boundary.

---

## Final M1 implementation outline

Once user resolves Q2/Q7/Q8, the M1 impl-ticket brief writes itself:

**Deliverables** (one PR per ticket, in order):

1. **CC-229 — schema-only PR**: 8 `core/schema/*.schema.json` files + `core/policy/*.yaml` (matrix-only) + `core/state/layout.yaml` + `core/context-pack/source.interface.md` + READMEs. No consumer touches. **Lock the shape.**
2. **CC-230 — `runtime/pmctl/lib/state-writer.sh`**: bash functions (`runs_append`, `events_append`, `task_upsert`, `review_upsert`, `decision_upsert`) wrapping `serialize_with_lock`. Pure additive, no consumer wired yet.
3. **CC-230 pilot — `codex-dispatch.sh` migration**: add the `runs_append "$RUN_JSON"` call after trace write. **First pilot consumer per Q11.**
4. **CC-231 — `handover-validate.sh` policy extraction**: replace hardcoded case blocks with `_load_enum` calls.
5. **CC-232 — context-pack docs**: `source.interface.md` + the JSON Schema. No source implementations (CC-237 owns M4).
6. **`pm/schema.md` → `core/schema/backlog-grammar.md`** re-home + `task.schema.json` + `decision.schema.json`. Markdown stays primary.

**Out of M1**: `routing_log.md` hook cutover (M2 if Q7 = dual-write), `pmctl` CLI design (CC-215, M2), MCP surface (CC-216, v0.4.0), migration tooling (M1 impl detail not in spike), per-machine sync (not in scope §3.6 for M1).

---

## Next step

Tell me Q2 / Q7 / Q8 — once those three are pinned, I'll write the M1 implementation brief (CC-229 schema-only PR).

If you want to defer the decisions and let me pick on `[[breaking_change_for_maintainability]]` + audience-of-one judgment: **per-project / dual-write / field-only versioning** (my recommendations stand). Say the word and I'll write the brief assuming those.
