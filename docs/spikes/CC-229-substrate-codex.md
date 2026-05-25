# CC-229 — v0.3.0 substrate design (Codex)

## Section A — Entity type sketches

Below are 7 ≤30-line JSON Schema sketches, chosen for parser-agnostic, CLI-agnostic state definitions in `core/` aligned to the entities in scope §2 (`Task`, `Run`, `Event`, `Review`, `Decision`, `Brief`, `ContextPack`).
Source of location and targets are from `docs/spikes/CC-229-substrate-scope.md:37-49`.

### Task (`core/schema/task.schema.json`)
```json
{
  "title": "Task",
  "type": "object",
  "required": ["id", "title", "state", "created_at", "updated_at"],
  "properties": {
    "id": {"type": "string", "pattern": "^CC-\\d+$"},
    "title": {"type": "string"},
    "state": {"type": "string", "enum": ["open","claimed","in-progress","blocked","done","dropped"]},
    "owner": {"type": ["string", "null"]},
    "assignee": {"type": ["string", "null"]},
    "brief_id": {"type": "string"},
    "labels": {"type": "array", "items": {"type": "string"}},
    "created_at": {"type": "string", "format": "date-time"},
    "updated_at": {"type": "string", "format": "date-time"}
  },
  "additionalProperties": false
}
```

### Run (`core/schema/run.schema.json`)
```json
{
  "title": "Run",
  "type": "object",
  "required": ["id", "task_id", "state", "created_at", "payload"],
  "properties": {
    "id": {"type": "string"},
    "task_id": {"type": "string", "pattern": "^CC-\\d+$"},
    "executor": {"type": "string", "enum": ["codex", "claude"]},
    "state": {"type": "string", "enum": ["pending","dispatched","verifying","ok","partial","failed"]},
    "started_at": {"type": ["string", "null"], "format": "date-time"},
    "ended_at": {"type": ["string", "null"], "format": "date-time"},
    "payload": {"type": "object"}
  },
  "additionalProperties": false
}
```

### Event (`core/schema/event.schema.json`)
```json
{
  "title": "Event",
  "type": "object",
  "required": ["id", "entity_type", "entity_id", "event_type", "at"],
  "properties": {
    "id": {"type": "string"},
    "entity_type": {"type": "string", "enum": ["task","run","review","decision","brief","context-pack"]},
    "entity_id": {"type": "string"},
    "event_type": {"type": "string"},
    "at": {"type": "string", "format": "date-time"},
    "source": {"type": "string"},
    "details": {"type": "object"}
  },
  "additionalProperties": false
}
```

### Review (`core/schema/review.schema.json`)
```json
{
  "title": "Review",
  "type": "object",
  "required": ["id", "run_id", "reviewer", "result", "at"],
  "properties": {
    "id": {"type": "string"},
    "run_id": {"type": "string"},
    "reviewer": {"type": "string"},
    "result": {"type": "string", "enum": ["go", "no-go", "partial"]],
    "notes": {"type": "string"},
    "policy_revision": {"type": "string"},
    "at": {"type": "string", "format": "date-time"}
  },
  "additionalProperties": false
}
```

### Decision (`core/schema/decision.schema.json`)
```json
{
  "title": "Decision",
  "type": "object",
  "required": ["id", "scope", "decision", "evidence", "at"],
  "properties": {
    "id": {"type": "string"},
    "scope": {"type": "string"},
    "decision": {"type": "string"},
    "evidence": {"type": "array", "items": {"type": "string"}},
    "status": {"type": "string", "enum": ["active", "superseded", "retracted"]},
    "at": {"type": "string", "format": "date-time"},
    "owner": {"type": "string"}
  },
  "additionalProperties": false
}
```

### Brief (`core/schema/brief.schema.json`)
```json
{
  "title": "Brief",
  "type": "object",
  "required": ["id", "title", "priority", "acceptance_criteria", "created_at"],
  "properties": {
    "id": {"type": "string"},
    "title": {"type": "string"},
    "summary": {"type": "string"},
    "priority": {"type": "string", "enum": ["p0","p1","p2"]},
    "acceptance_criteria": {"type": "array", "items": {"type": "string"}},
    "handover_id": {"type": "string"},
    "created_at": {"type": "string", "format": "date-time"},
    "target_release": {"type": "string"}
  },
  "additionalProperties": false
}
```

### ContextPack (`core/schema/context-pack.schema.json`)
```json
{
  "title": "ContextPack",
  "type": "object",
  "required": ["id", "brief_id", "files", "created_at"],
  "properties": {
    "id": {"type": "string"},
    "brief_id": {"type": "string"},
    "files": {"type": "array", "items": {"type": "string", "format": "uri"}},
    "topics": {"type": "array", "items": {"type": "string"}},
    "metadata": {"type": "object"},
    "created_at": {"type": "string", "format": "date-time"},
    "ttl_days": {"type": ["integer", "null"], "minimum": 1}
  },
  "additionalProperties": false
}
```

## Section B — Directory tree + filenames

### In-repo (`core/`)
```text
core/
├─ schema/
│  ├─ task.schema.json
│  ├─ run.schema.json
│  ├─ event.schema.json
│  ├─ review.schema.json
│  ├─ decision.schema.json
│  ├─ brief.schema.json
│  ├─ handover.schema.json
│  ├─ context-pack.schema.json
│  ├─ snapshot.schema.json
├─ policy/
│  ├─ executor-enum.yaml
│  ├─ dispatch-states.yaml
│  ├─ reviewer-policy.yaml
│  ├─ task-states.yaml
│  ├─ run-states.yaml
├─ state/
│  ├─ layout.yaml
├─ context-pack/
│  ├─ source.interface.md
│  ├─ source.interface.ts
│  ├─ source.interface.schema.json
```

### On-disk (`~/.claude/.pm/state/`)
```text
~/.claude/.pm/state/
├─ events.jsonl
├─ runs.jsonl
├─ tasks.jsonl
├─ reviews.jsonl
├─ decisions.jsonl
├─ briefs.jsonl
├─ context-packs.jsonl
├─ snapshots.jsonl
├─ manifest.json
├─ indexes/
│  ├─ events.index.json
│  ├─ runs.index.json
│  ├─ tasks.index.json
│  ├─ reviews.index.json
│  ├─ decisions.index.json
│  ├─ briefs.index.json
│  ├─ context-packs.index.json
│  ├─ snapshots.index.json
└─ state.lock
```

Design notes (CLI-agnostic location, per-machine scope, locking, and compatibility with future split): scope defines CLI-agnostic storage under `~/.claude/.pm/state/` and says state is per-machine, gitignored, and accessed via `pmctl` path indirection. These files are therefore definitions only; runtime writes belong to M2. See scope lines 62–63 and 71.
(`core/state/layout.yaml` is the single source of truth for names, lock scope, and index policy.)

## Section C — Module dependency graph

| module | depends on |
|---|---|
| `core/schema/` | `core/policy/` (enum refs only in comments) |
| `core/policy/` | no runtime dependency |
| `core/context-pack/` | `core/schema/`, `core/policy/` |
| `core/state/` | `core/schema/`, `core/policy/` |
| `core/state/` | `runtime/pmctl` (M2 writer boundary) |

Constraint: `core/` remains definition-only, consistent with synthesis guidance that core knows nothing executable (`core/` definitions only in §5.1, mirrored in scope lines 75-84).

## Section D — Migration checklist (surface-by-surface)

| surface | M1 change class | concrete diff sketch (1 sentence) | risk-and-test-plan (1 sentence) |
|---|---|---|---|
| `pm-prep-snapshot.sh` | add schema definition only M1 | Add `core/schema/snapshot.schema.json` and a short `core/README` note that behavior remains unchanged in M1 while schema serves as documentation of current snapshot shape. | Low risk because behavior is untouched; validate with offline schema doc generation smoke-check from existing fixture snippets only (`scripts/pm-prep-snapshot.sh` one-writer usage). |
| `codex-dispatch.sh` | breaking migration M1 | Replace only `routing_log.md` auto-block append in `codex-dispatch.sh` with an append-to-`~/.claude/.pm/state/runs.jsonl` helper (`append_run_record()`) while leaving trace artifacts unchanged. | Medium risk from the single budgeted migration; cover with dual-write compatibility checks in tests and a controlled canary proving new runs rows match existing table columns. |
| `handover-validate.sh` | extract policy M1 | Move executor and dispatch-state checks from hard-coded `case` branches to `core/policy/executor-enum.yaml` and `core/policy/dispatch-states.yaml` lookups, while preserving current CLI behavior. | Low risk because validation behavior is already stable; add policy-lookup unit tests for existing `codex/claude` values and schema drift check against enum files. |
| `BACKLOG.md` / `pm/schema.md` | add schema definition only M1 | Add `core/schema/task.schema.json` documenting existing markdown row shape and relocate `pm/schema.md` to `core/schema/backlog-grammar.md` without replacing Markdown ownership of BACKLOG. | Low risk due docs-only impact; validate by parity checks against existing row parser acceptance of legacy examples. |
| `DECISIONS.md` | add schema definition only M1 | Add `core/schema/decision.schema.json` and reference existing `DECISIONS.md` decision row semantics as source-of-truth text. | Trivial risk: no runtime behavior changes; run lint against the schema with current sample decisions only for schema coverage. |
| `routing_log.md` auto-block | breaking migration M1 | Extract auto-block rows into rows in `runs.jsonl`; keep `routing_log.md` as a generated, read-only human surface stub pointing at canonical JSONL-backed source. | Medium risk because parsing fidelity impacts auditability; risk is reduced by keeping an immutable source and snapshot test that compares rendered views against legacy table snapshots. |

## Section E — Open-questions table

| id | question | recommended answer | reasoning (2 sentences max) | confidence |
|---|---|---|---|---|
| Q1 | JSON Schema source-of-truth vs TypeScript-first | JSON Schema only for M1 | M1 consumers are Bash-oriented and this matches the current contract that JSON is the consumable format in tooling. TS can be generated later (or hand-written in M2) to avoid double-maintenance risk before MCP introduces Node paths. | high |
| Q2 | Single state directory vs per-project | Single global `~/.claude/.pm/state/` directory for all repos | The scope highlights this path as one CLI-agnostic location and this spike’s goal is to minimize M1 migration scope; a per-project split can be introduced as a policy version event later. | high |
| Q3 | Atomic write semantics for append-only logs | Append path uses `serialize_with_lock()` + best-effort fsync; indexes use write-temp-then-rename | The scope explicitly requires lock use and asks single-writer granularity, and crash semantics should be best-effort for M1 to avoid overbuilding without changing behavior. Durable fsync can be a v1 stability hardening if warranted by post-M1 incidents. | medium |
| Q4 | Should the Brief schema be in M1 | Ship `brief.schema.json` in M1; keep `handover.schema.json` adjacent and explicit relation doc in `core/schema` | Brief is explicitly an in-scope entity in the same section as state objects, and documenting it in M1 reduces later schema-shift risk; its consumer footprint is definition-only until M2 activation. | medium |
| Q5 | Where does executor enum live, and is it closed? | Keep closed in M1 at policy + schema (`core/policy/executor-enum.yaml` + `core/schema/run.schema.json`), with controlled expansion via M1-compatible breaking-version events | Scope already ties current validation to a closed `{codex, claude}` branch and this is the safe point to lock behavior before cross-CLI extension in later milestones. | high |
| Q6 | Reviewer-policy extraction depth | Extract the matrix and hard-vs-advisory reviewer roles into YAML; keep prose override discipline text in `agents/project-pm.md` | The policy document is already the prose source of truth for override discipline; YAML-only extraction keeps `core/policy/reviewer-policy.yaml` actionable while avoiding accidental duplicate narrative drift. | medium |
| Q7 | `routing_log.md` after migration | Regenerate a human-readable stub from `runs.jsonl` in read-only form | This preserves discoverability for humans while making `runs.jsonl` canonical and avoiding behavioral coupling to a Markdown anti-pattern. A full UI-style command can be added in M2 without changing M1 schema. | high |
| Q8 | Schema versioning policy | `schema_version` per payload + `core/schema/v1/*` directory lockstep and immutable `core/state/manifest.json` | M1 must be the schema freeze line; per-payload versioning plus directory-level pathing gives both migration safety and auditability while keeping older validators decoupled from path semantics. | medium |

## Section F — Risks + alternatives considered

- Risk: choosing a global state log now may interleave repos and increase cross-project noise; we mitigate by including `task_id`/`run_id` partitioning metadata and reserving per-project directories for a future versioned migration.
- Risk: hard-closing `executor` to `{codex, claude}` in M1 could force a breaking change later; the chosen mitigation is explicit versioned breaking events aligned to M1 freeze policy.
- Alternative rejected: per-project directories for every state file was rejected as higher M1 complexity and mismatch with current migration constraints; global state keeps the single migration path tractable.
- Risk: `routing_log.md` render regeneration might hide malformed rows if render logic is incorrect; this is mitigated by making JSONL canonical and testing render snapshots only, without altering the schema for existing readers.
- Risk: dual-policy/schema maintenance (`core/schema` + `core/policy`) may drift; mitigated by keeping policy files narrowly scoped and documenting enum owners in each schema as comments.
- Alternative rejected: PMCTL CLI command design in this spike was rejected as out-of-scope (`CC-215`, CC-232, etc.), and this output keeps only boundary references to M2 writers (`core/state` → `runtime`).
- Alternative rejected: migrating `pm-prep-snapshot.sh` behavior in M1 was rejected (schema-only) to honor the requirement that only routing log migration is budgeted for M1.
- Risk: index file growth without rotation may eventually degrade read performance; mitigation is append-only event logs plus optional off-cycle archival (not in M1) and sparse index strategy.
- Alternative rejected: generating TypeScript interfaces in M1 was rejected to avoid a second source of truth before MCP introduces Node consumers.
- Risk: this spike intentionally does not define migration tooling and may leave gap between planned and executable steps; this is flagged explicitly because conversions are out-of-scope and belong to M1 implementation tickets.
