# CC-229 — v0.3.0 M1 state/schema substrate: Claude design spike

**Status**: independent design spike — Claude side. Codex CLI spiker is producing a parallel proposal; main thread will synthesize.
**Date**: 2026-05-24
**Scope doc**: `docs/spikes/CC-229-substrate-scope.md`
**Branch**: `spike/m1-substrate` @ `3a17ccf4`

This doc answers the six prescribed sections (A–F) in order. Decisions cite `file:line` where load-bearing.

---

## Section A — Entity type sketches

Format: **JSON Schema body** (no `$schema`/`$id` boilerplate). Chosen over TypeScript because `pmctl` is bash (`docs/architecture/v0.3.0-synthesis.md:213-214`, R4); JSON Schema is the only format consumable by bash today via `ajv-cli` or hand-rolled `jq`. TS sketches deferred (see Q1).

All entities use `id` (string), `schema_version` (const `1` in M1 — see Q8), `created_ts` (RFC-3339 UTC). Lifecycle enums live in `core/policy/*.yaml` (see §B); the schema marks the `state` field with `"$ref": "../policy/<name>.yaml#/states"` syntax — Q1 fallback when the format is open-coded YAML, `pmctl` re-validates via a `jq` pass.

### Task

```jsonc
{
  "type": "object",
  "required": ["id", "schema_version", "title", "state", "created_ts"],
  "properties": {
    "id":             { "type": "string", "pattern": "^[A-Z]{1,4}-[0-9]+$" },
    "schema_version": { "const": 1 },
    "title":          { "type": "string", "minLength": 1, "maxLength": 200 },
    "state":          { "$ref": "../policy/task-states.yaml#/states" },
    "priority":       { "enum": ["P1","P2","P3",null] },
    "epic":           { "type": "string" },
    "area":           { "type": "string" },
    "ticket_origin":  { "enum": ["backlog_md","ad_hoc"], "default": "backlog_md" },
    "backlog_ref":    { "type": "string", "description": "repo-relative path + anchor, e.g. BACKLOG.md#CC-229" },
    "created_ts":     { "type": "string", "format": "date-time" },
    "updated_ts":     { "type": "string", "format": "date-time" }
  },
  "additionalProperties": false
}
```

Notes: Task is a **runtime projection of a BACKLOG.md row** — Markdown stays primary (`docs/architecture/v0.3.0-synthesis.md:122-126`). `id` regex matches `pm/schema.md:29` (`<PREFIX>-NNN`). State enum sourced from `core/policy/task-states.yaml`.

### Run

```jsonc
{
  "type": "object",
  "required": ["id", "schema_version", "task_id", "executor", "state", "created_ts"],
  "properties": {
    "id":             { "type": "string", "pattern": "^run-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$" },
    "schema_version": { "const": 1 },
    "task_id":        { "type": "string", "pattern": "^[A-Z]{1,4}-[0-9]+$" },
    "executor":       { "$ref": "../policy/executor-enum.yaml#/values" },
    "dispatch_route": { "$ref": "../policy/dispatch-routes.yaml#/values" },
    "model":          { "type": "string" },
    "brief_file":     { "type": "string" },
    "working_dir":    { "type": "string" },
    "state":          { "$ref": "../policy/run-states.yaml#/states" },
    "trace_path":     { "type": "string", "description": "abs path to .agent-trace/codex-<ts>.jsonl" },
    "exit_code":      { "type": "integer" },
    "started_ts":     { "type": "string", "format": "date-time" },
    "finished_ts":    { "type": ["string","null"], "format": "date-time" },
    "created_ts":     { "type": "string", "format": "date-time" }
  },
  "additionalProperties": false
}
```

Notes: `executor` enum mirrors `scripts/lib/handover-validate.sh:121-125`. `dispatch_route` mirrors `:131-135`. `trace_path` points at the existing `.agent-trace/codex-<ts>.jsonl` (`scripts/codex-dispatch.sh:297`) — Run does NOT duplicate trace contents; it's the index row that the `routing_log.md` auto-block currently is (the anti-pattern, `routing_log` synthesis §5.2). Single migration target.

### Event

```jsonc
{
  "type": "object",
  "required": ["id", "schema_version", "ts", "kind", "subject_type", "subject_id"],
  "properties": {
    "id":             { "type": "string", "pattern": "^evt-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$" },
    "schema_version": { "const": 1 },
    "ts":             { "type": "string", "format": "date-time" },
    "kind": {
      "enum": [
        "task.created","task.state_changed","task.blocked",
        "run.dispatched","run.completed","run.failed",
        "review.started","review.verdict",
        "guard.denied","guard.warned",
        "decision.recorded"
      ]
    },
    "subject_type":   { "enum": ["task","run","review","decision"] },
    "subject_id":     { "type": "string" },
    "actor":          { "type": "string", "description": "pmctl|hook|adapter:<name>" },
    "payload":        { "type": "object", "additionalProperties": true }
  },
  "additionalProperties": false
}
```

Notes: append-only (`docs/architecture/v0.3.0-synthesis.md:118`). `payload` is loose-typed by design — kind-specific schemas can be added per `kind` in M2+ without a breaking version bump. `actor` is intentionally a free string namespaced by prefix; no CLI product name appears in the enum (CLI-agnostic invariant, scope §1.2).

### Review

```jsonc
{
  "type": "object",
  "required": ["id", "schema_version", "task_id", "tier", "verdict", "findings", "created_ts"],
  "properties": {
    "id":             { "type": "string", "pattern": "^rev-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$" },
    "schema_version": { "const": 1 },
    "task_id":        { "type": "string" },
    "run_id":         { "type": ["string","null"] },
    "tier":           { "enum": ["express","standard","full","targeted"] },
    "verdict":        { "enum": ["GO","NO-GO","pending"] },
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["reviewer","verdict"],
        "properties": {
          "reviewer":  { "$ref": "../policy/reviewer-policy.yaml#/reviewers" },
          "verdict":   { "enum": ["pass","pass-not-applicable","advise","block-soft","block"] },
          "summary":   { "type": "string" },
          "findings_path": { "type": "string" }
        }
      }
    },
    "override_path":  { "type": ["string","null"] },
    "created_ts":     { "type": "string", "format": "date-time" }
  },
  "additionalProperties": false
}
```

Notes: `reviewer` and `verdict` enums sourced from `agents/project-pm.md:45-91`. `tier` mirrors `/pr-gate` tier names (synthesis §5.3 Superpowers row). `findings_path` points at `.gate-results/<gate-id>/<reviewer>.{json,md}` — Review is the index, not the data.

### Decision

```jsonc
{
  "type": "object",
  "required": ["id", "schema_version", "date", "title", "decision_md_path"],
  "properties": {
    "id":               { "type": "string", "pattern": "^dec-[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+$" },
    "schema_version":   { "const": 1 },
    "date":             { "type": "string", "format": "date" },
    "title":            { "type": "string" },
    "closes":           { "type": "array", "items": { "type": "string" }, "description": "BACKLOG ticket refs" },
    "decision_md_path": { "type": "string", "description": "abs path to DECISIONS.md anchor" },
    "tags":             { "type": "array", "items": { "type": "string" } }
  },
  "additionalProperties": false
}
```

Notes: per `DECISIONS.md:1-8`, the Markdown file is primary. Schema documents the index row only — body sections (Context/Decision/Alternatives/Constraints) stay Markdown. Append-only.

### Brief

```jsonc
{
  "type": "object",
  "required": ["working_dir","goal","files","acceptance"],
  "properties": {
    "schema_version": { "const": 1 },
    "working_dir":    { "type": "string", "pattern": "^/" },
    "goal":           { "type": "string", "minLength": 1 },
    "files": {
      "type": "array",
      "items": {
        "oneOf": [
          { "type": "object", "required": ["read"],  "properties": { "read":  { "type": "string" } } },
          { "type": "object", "required": ["edit"],  "properties": { "edit":  { "type": "string" } } },
          { "type": "object", "required": ["new"],   "properties": { "new":   { "type": "string" } } },
          { "type": "object", "required": ["write"], "properties": { "write": { "type": "string" } } }
        ]
      }
    },
    "constraints":      { "type": "array", "items": { "type": "string" } },
    "self_verify":      { "type": "array", "items": { "type": "string" } },
    "acceptance":       { "type": "array", "items": { "type": "string" } },
    "qa_checklist":     { "type": "array", "items": { "type": "string" } },
    "expected_head_sha":{ "type": "string", "pattern": "^[a-f0-9]{40}$" },
    "context":          { "type": "string" },
    "task":             { "type": "string" },
    "output_format":    { "type": "string" }
  },
  "additionalProperties": false
}
```

Notes: mirrors `docs/dispatch-brief.md:12-50`. `self_verify` is conditionally required (file-writing briefs) — left as `array` here; cross-field conditional validation handled by `pmctl validate` (M2), not by the schema (keeps M1 schema simple). Brief is distinct from Handover (the dispatch envelope) — Brief is the work definition. Handover schema sketched below for completeness because the synthesis treats them as a pair (scope §2 ContextPack row).

(Handover schema bonus — mirrors `docs/dispatch-brief.md:255-268`; not one of the 7 required entities but listed for §D surface 2/3 alignment.)

```jsonc
{
  "type": "object",
  "required": ["handover_version","executor","dispatch_route","working_dir","brief_file",
               "sandbox","approval","timeout","model","skip_git_check","fallback_allowed"],
  "properties": {
    "handover_version": { "const": 2 },
    "executor":         { "$ref": "../policy/executor-enum.yaml#/values" },
    "dispatch_route":   { "$ref": "../policy/dispatch-routes.yaml#/values" },
    "working_dir":      { "type": "string", "pattern": "^/" },
    "brief_file":       { "type": "string" },
    "sandbox":          { "enum": ["workspace-write","read-only","danger-full-access"] },
    "approval":         { "enum": ["never","on-request","on-failure"] },
    "timeout":          { "type": "integer", "minimum": 1, "maximum": 3600 },
    "model":            { "type": "string" },
    "skip_git_check":   { "type": "boolean" },
    "fallback_allowed": { "type": "boolean" },
    "snapshot_file":    { "type": "string" }
  },
  "additionalProperties": false
}
```

### ContextPack

```jsonc
{
  "type": "object",
  "required": ["schema_version","task_id","built_ts","sources","files"],
  "properties": {
    "schema_version": { "const": 1 },
    "task_id":        { "type": "string" },
    "built_ts":       { "type": "string", "format": "date-time" },
    "sources": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name","version"],
        "properties": {
          "name":    { "type": "string", "description": "e.g. rg, git-log, memory, codegraph" },
          "version": { "type": "string" },
          "config":  { "type": "object" }
        }
      }
    },
    "files":    { "type": "array", "items": { "$ref": "#/$defs/item" } },
    "symbols":  { "type": "array", "items": { "$ref": "#/$defs/item" } },
    "memories": { "type": "array", "items": { "$ref": "#/$defs/item" } },
    "risks":    { "type": "array", "items": { "$ref": "#/$defs/item" } }
  },
  "$defs": {
    "item": {
      "type": "object",
      "required": ["ref","source","confidence"],
      "properties": {
        "ref":        { "type": "string" },
        "source":     { "type": "string", "description": "matches sources[].name" },
        "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
        "rationale":  { "type": "string" }
      }
    }
  }
}
```

Notes: four parallel category arrays (files/symbols/memories/risks) match `BACKLOG.md:1263` (CC-232 requirement). The `source` field per-item enables CC-237 baseline sources to be added without bumping pack schema; `confidence` is required so consumers (M4 CC-237, future CC-209) can rank.

**Source interface contract** (`core/context-pack/source.interface.md`, not a schema — a Markdown contract): every source MUST expose `name`, `version`, `build(task_id) → items[]`; sources MUST NOT mutate state; sources MUST NOT depend on each other.

---

## Section B — Directory tree

### In-repo (`/home/screenleon/github/pm-dispatch/core/`)

```
core/
├── README.md                                     # what core/ is + what it must NOT contain
├── schema/
│   ├── task.schema.json
│   ├── run.schema.json
│   ├── event.schema.json
│   ├── review.schema.json
│   ├── decision.schema.json
│   ├── brief.schema.json
│   ├── handover.schema.json                      # paired with brief; see §A note
│   ├── context-pack.schema.json
│   └── backlog-grammar.md                        # re-homed from pm/schema.md (synthesis §5.1)
├── policy/
│   ├── executor-enum.yaml                        # {codex, claude} — closed (Q5)
│   ├── dispatch-routes.yaml                      # {main_thread_bash_background, agent_executor}
│   ├── dispatch-states.yaml                      # Run state machine (synthesis §5.2)
│   ├── task-states.yaml                          # Task state machine
│   ├── run-states.yaml                           # pending→dispatched→verifying→ok|partial|failed
│   └── reviewer-policy.yaml                      # gate matrix only (Q6); prose stays in agents/project-pm.md
├── state/
│   ├── README.md                                 # describes the on-disk layout (NOT the writer)
│   └── layout.yaml                               # machine-readable spec of paths below
└── context-pack/
    ├── source.interface.md                       # source contract (the "interface")
    └── README.md
```

`pm/schema.md` is **re-homed** (not duplicated) to `core/schema/backlog-grammar.md` per synthesis §5.1; `pm/` folder is left for installer-managed symlinks in M1 and folded fully in M2.

### On-disk (`~/.claude/.pm/state/`)

Per `docs/architecture/v0.3.0-synthesis.md:60` — definitions in repo, state on disk, per-machine, gitignored. **Per-project partitioning** (see Q2):

```
~/.claude/.pm/state/
├── VERSION                                       # plain text: "1" (matches schema_version)
├── store.lock                                    # global lockbase for cross-project ops
└── projects/
    └── <repo-sha1>/                              # sha1(git-toplevel abs path); collision-resistant, opaque
        ├── repo.json                             # {repo_path, repo_name, first_seen_ts} — debug aid
        ├── runs.jsonl                            # append-only Run rows (replaces routing_log auto-block)
        ├── runs.lock                             # serialize_with_lock target (per-store, per-project)
        ├── events.jsonl                          # append-only Event rows
        ├── events.lock
        ├── tasks/
        │   └── <task-id>.json                    # latest Task projection; write-temp-rename
        ├── reviews/
        │   └── <review-id>.json                  # one file per Review (sparse, low-volume)
        ├── decisions/
        │   └── <decision-id>.json                # mirrors DECISIONS.md index rows
        ├── context-packs/
        │   └── <task-id>-<built-ts>.json         # ContextPack snapshots; keep last 5 per task
        └── archive/                              # rotated JSONL segments (see lifecycle in §E Q-add)
            ├── runs-<YYYYMM>.jsonl.gz
            └── events-<YYYYMM>.jsonl.gz
```

**Naming convention** chosen: per-project partition by `sha1(git-toplevel)` (Q2). JSONL append targets are `<entity>.jsonl`; per-entity locks are `<entity>.lock` (per-file granularity, Q3). Tasks/Reviews/Decisions are one-file-per-row because they're low-volume and individually addressable; Runs/Events are JSONL because they're high-volume append streams.

---

## Section C — Module dependency graph

Arrow = "X may import / reference Y". Graph is **strictly acyclic** and **downward-only** per synthesis §5.1.

```
                         ┌─────────────────────────────┐
                         │  runtime/  (M2 — pmctl)     │   <-- the writer boundary
                         │  reads schema, writes state │
                         └──────────┬───────────────┬──┘
                                    │               │
                       references   │               │ reads layout from
                                    ▼               ▼
              ┌────────────────────────────┐   ┌──────────────────────┐
              │ core/schema/*.schema.json  │   │ core/state/layout.yaml│
              │  (pure JSON Schema)        │◄──│  (paths, no behavior) │
              └──────┬─────────────────────┘   └───────────┬──────────┘
                     │                                     │
        $ref-only to │                            $ref-only│
                     ▼                                     ▼
              ┌────────────────────────────┐   ┌──────────────────────┐
              │ core/policy/*.yaml         │   │ core/context-pack/   │
              │  (enums + state machines)  │   │  source.interface.md │
              └────────────────────────────┘   └───────────┬──────────┘
                                                           │
                                              references schema only
                                                           ▼
                                              (back to core/schema/*)
```

### Allowed import / reference table

| From → To | Allowed? | Notes |
|---|---|---|
| `core/schema/` → `core/policy/` | ✅ | via `$ref` to YAML enum/state files |
| `core/schema/` → `core/state/` | ❌ | schema is shape-only; doesn't know storage |
| `core/schema/` → `core/context-pack/` | ❌ | independent peers |
| `core/policy/` → anything in `core/` | ❌ | policies are leaves (terminal definitions) |
| `core/state/` → `core/schema/` | ✅ | layout.yaml may name which schema each file conforms to |
| `core/state/` → `core/policy/` | ❌ | state layout is shape-only, doesn't encode enums |
| `core/context-pack/` → `core/schema/` | ✅ | source contract references `context-pack.schema.json` |
| `core/context-pack/` → `core/policy/` | ❌ | sources are pluggable; not policy-bound |
| **`core/*` → `runtime/`** | ❌ **(invariant)** | core knows nothing executable; CC-233 layer test enforces |
| **`core/*` → `adapters/`** | ❌ **(invariant)** | same as above |
| `runtime/pmctl` → `core/schema/` | ✅ | runtime reads schemas to validate writes |
| `runtime/pmctl` → `core/state/layout.yaml` | ✅ | runtime resolves paths from this file (not hardcoded) |
| `runtime/pmctl` → `core/policy/` | ✅ | guard engine / validator consume enums |
| `adapters/*` → `runtime/pmctl` | ✅ | only via the `pmctl` CLI; never `core/` direct |
| `adapters/*` → `core/*` | ❌ **(invariant)** | adapters get core via `pmctl --json`, not by reading files |

### Writer boundary (M2 insertion point)

`core/state/layout.yaml` is the **definition** of paths; **only `runtime/pmctl` (M2 CC-215) may write to those paths**. No hook, command, agent, or adapter writes state files directly (synthesis §5.2 "pmctl is the only writer"). M2's insertion point is a single Bash module `runtime/pmctl/lib/state-writer.sh` that:
- reads `core/state/layout.yaml` for the target path,
- looks up the matching schema in `core/schema/`,
- wraps every write with `serialize_with_lock` from `scripts/lib/portable.sh:163`,
- exports `runs_append`, `events_append`, `task_upsert`, `review_upsert`, `decision_upsert` functions.

`scripts/hook-routing-log.sh:199-216` already uses `serialize_with_lock` with a per-LOG_DIR key — same pattern, just relocated.

---

## Section D — Migration checklist

| # | Surface | M1 change class | Concrete diff sketch (1 sentence) | Risk-and-test-plan (1 sentence) |
|---|---|---|---|---|
| 1 | `pm-prep-snapshot.sh` (`scripts/pm-prep-snapshot.sh:255-310`) | **no change M1** | Snapshot YAML frontmatter stays one-shot pre-spawn artifact; schema'd in M2 when `pmctl snapshot` extracts the writer. | Risk trivial (one writer / one reader / transient `/tmp` file); no test change needed since output bytes unchanged. |
| 2 | `codex-dispatch.sh` (`scripts/codex-dispatch.sh:296-334`) | **breaking migration M1** | After trace write + `log-usage.sh` block (`:330`), add one new call `runs_append "$RUN_JSON"` (via the new helper in `runtime/pmctl/lib/state-writer.sh`); CLI surface + trace files unchanged; the `usage-tracker.jsonl` line is kept (deprecation deferred to M2). | Risk medium (touches the dispatch hot path); add `scripts/test-codex-dispatch-runs-append.sh` asserting (a) trace files written byte-identical, (b) `runs.jsonl` gains exactly one row per dispatch, (c) on `serialize_with_lock` failure, dispatch still exits with codex's own exit code (state-store failure is non-fatal). |
| 3 | `handover-validate.sh` (`scripts/lib/handover-validate.sh:117-135`) | **extract policy M1** | Replace hardcoded `case "$value" in codex\|claude)` with a `_load_enum core/policy/executor-enum.yaml` helper that `grep`s allowed values; same for `dispatch_route`; validator behavior unchanged. | Risk low (validator is well-tested; `scripts/test-dispatch-handover.sh` already covers); add one fixture per policy enum + test that adding a value to YAML loosens the validator without code change. |
| 4 | `BACKLOG.md` / `pm/schema.md` | **add schema definition only M1** | `git mv pm/schema.md core/schema/backlog-grammar.md`; add `core/schema/task.schema.json` documenting the same rows; keep `pm/schema.md` as a symlink alias (installer-managed per `pm/schema.md:4`) so external readers don't break. | Risk low (Markdown stays primary); existing `pm/scripts/validate.sh` continues to run against the Markdown; new `scripts/test-schema-task-mirrors-backlog.sh` asserts a parsed BACKLOG row validates against `task.schema.json`. |
| 5 | `DECISIONS.md` | **add schema definition only M1** | Add `core/schema/decision.schema.json`; no file moves; no validator changes; document the index-row shape only. | Risk trivial; one fixture parsing `DECISIONS.md:10` (the `## 2026-05-19: cc030-validate-bidirectional` row) against the schema. |
| 6 | `routing_log.md` auto-block (`scripts/hook-routing-log.sh:199-216`) | **breaking migration M1** | Hook keeps writing to per-project memory `routing_log.md` auto-block in M1 (no change to hook in M1 — Q7 (d) variant); **but** `codex-dispatch.sh` (surface #2) also writes `runs.jsonl` so the structured data exists; in M2 the hook is rewritten to call `runs_append` and the Markdown auto-block is regenerated by `pmctl runs render` (a future-named M2 command — naming reserved, not designed). | Risk medium (the migration); `scripts/test-migrate-routing-log.sh` (already exists) extended to assert one row in JSONL per existing legacy bullet; one-time backfill is **out of scope per scope §8** (M1 impl-ticket concern). |

---

## Section E — Open-questions table

| id | question | recommended answer | reasoning (≤2 sentences) | confidence |
|---|---|---|---|---|
| Q1 | JSON Schema source-of-truth vs TypeScript-first | **JSON Schema only in M1.** | `pmctl` is bash (`synthesis:213-214`); one source of truth is cheaper than two-files-to-sync, and TS interfaces can be generated from JSON Schema via `json-schema-to-typescript` when CC-216 (v0.4.0 MCP) actually needs them. Validation via `ajv-cli` (Node, dev-only) with a `jq` fallback for pure-bash environments. | high |
| Q2 | Single state directory vs per-project | **Per-project, partitioned by `sha1(git-toplevel)`.** | Today's `.agent-trace/` is per-repo so engineers already think per-project; a global log loses isolation (one repo's noise drowns another's signal) and complicates backup/wipe. SHA-of-toplevel is opaque (no filesystem-unsafe chars), collision-resistant, and machine-derivable so the same repo cloned in two paths maps to two stores (correct — they have different worktrees). | high |
| Q3 | Atomic-write semantics for append-only logs | **`serialize_with_lock` + `printf >> file` + `sync` (no per-write fsync).** Crash-safety class: **best-effort — may lose last record on power loss; never partial/torn row.** | `serialize_with_lock` (`scripts/lib/portable.sh:163`) already gives single-writer; on Linux a single `write()` < PIPE_BUF (4096 bytes) is atomic, and a single JSONL row is well under that. Per-write `fsync` doubles write latency on the dispatch hot path for a crash window narrower than the dispatch itself; opt-in `PM_STATE_FSYNC=1` env var preserves the choice. | high |
| Q4 | Should Brief schema be in M1 at all | **Yes — ship Brief + Handover schemas in M1.** | Brief + Handover are already de-facto schemas (`docs/dispatch-brief.md` is a schema doc); not schematizing in M1 means re-locking later as a breaking change when `pmctl validate` (CC-202) extracts the validator — exactly the synthesis §8 R3 hazard. Cost is low (≈80 lines of JSON Schema) and the input-side shape is more stable than the state-side. | high |
| Q5 | Where does the executor enum live, and is it closed | **`core/policy/executor-enum.yaml` with `values: [codex, claude]`; treated as a closed list in M1.** Future Antigravity/OpenCode adapters add an entry to the YAML in v0.4.0 (a breaking event per R3, but a one-line one). | Synthesis §7 names `antigravity`/`opencode` as v0.4.0 named slots; if we make the enum "open in schema, closed in policy" we ship two enforcement surfaces with no current consumer — over-engineering. One YAML, hard-validated, and the v0.4.0 ticket adds the slot. | high |
| Q6 | Reviewer-policy extraction depth | **Matrix only — no prose.** `reviewer-policy.yaml` captures: reviewers, advisory-vs-hard-gate flag, applicable phase (all-changes / impl-only / test-phase). Override discipline (Rule A/B) **stays in `agents/project-pm.md:70-91`**. | The matrix is data; override discipline is judgment-encoding-as-prose and currently lives where the PM agent reads it. Splitting prose into YAML produces two-source drift, and `pmctl` doesn't need to enforce override discipline in M1 (no machine reader). | medium |
| Q7 | `routing_log.md` after migration | **(d) Keep human entries above the auto-block boundary; **remove the hook-written auto-block in M2**, not M1.** In M1 both `routing_log.md` auto-block AND `runs.jsonl` are written (dual-write for one milestone); M2 drops the hook write and `routing_log.md` becomes human-only. | Dual-write for one milestone is the safe migration — readers (humans, scripts) keep working unchanged in M1, structured data accumulates in `runs.jsonl`, and the cutover is a small M2 hook edit. Auto-regeneration from JSONL (option b) is a `pmctl runs render` design — out of scope per §8. | medium |
| Q8 | Schema versioning policy | **`schema_version: <int>` field on every payload (required, const=1 in M1); no `$id` URLs, no `v1/` directory.** Breaking changes bump the int + accompany a `CHANGELOG.md` entry + a migration note in `DECISIONS.md`. | Inline version field is bash-readable (`jq '.schema_version'`), survives file moves, and is the standard JSONL discriminator pattern. URL `$id`s are MCP-server-friendly but premature in M1; directory versioning forces a path break which is exactly what we're trying to avoid for the in-repo definitions. | high |
| **Q9 (added)** | Lifecycle / GC for append-only logs | **Monthly archive rotation: `runs.jsonl` / `events.jsonl` rotate to `archive/<entity>-<YYYYMM>.jsonl.gz` when size > 50 MB OR age > 90 days, whichever first.** No TTL on Tasks/Reviews/Decisions/ContextPacks. ContextPacks keep last 5 per `task_id`. | Append-forever is correct for events; rotation prevents one runaway repo from filling disk. Rotation runs at `pmctl maintenance` (M2 command — name reserved, not designed); no automatic rotation in M1. | medium |
| **Q10 (added)** | Cross-machine / memory-private factoring (scope §3.6) | **M1 is strictly per-machine local. The per-project partitioning (`projects/<repo-sha1>/`) is already the factoring boundary for a future memory-private split** — moving one project's state dir between machines is `rsync -a projects/<sha1>/` with no path rewrites. | The synthesis §8 R3 anti-churn rule says lock now, change later as breaking event; choosing the partitioning shape now (Q2) is itself the forward-compat answer for `[[project_memory_architecture]]`. No sync mechanism, no shared blob store in M1. | medium |
| **Q11 (added)** | Pilot-walkthrough owner per `[[feedback_spike_pilot_required]]` (scope §8 last bullet) | **M1 impl ticket for CC-230 owns the pilot.** The pilot consumer is **surface #2 (`codex-dispatch.sh` → `runs_append`)** — smallest real consumer of the new state-writer API. | This spike is investigation, not API design — but the impl ticket *is* API design and must carry a verbatim before/after diff against `codex-dispatch.sh:296-334`. Calling it out here so it isn't forgotten when the impl brief is written. | high |

---

## Section F — Risks + alternatives considered

- **R-design-1 (amplifies synthesis R3 schema churn)**: per-project partitioning via `sha1(git-toplevel)` is a path shape locked in M1; if a future requirement wants project-namespaced IDs (e.g. `<repo>:CC-229`) or cross-repo task graphs, the partition becomes a breaking change. Mitigation: `repo.json` per partition stores the original repo path so re-partitioning is a renaming sweep, not a data migration.
- **R-design-2 (amplifies R5 Markdown/JSON thrash)**: Q7 chooses **dual-write** in M1 (auto-block + `runs.jsonl`) rather than a one-shot migration; the cost is two writers for one milestone. Mitigation budgeted to M2 hook-rewrite ticket; the data shape is identical so no semantic drift.
- **R-design-3 (new)**: `core/policy/*.yaml` `$ref`-from-JSON-Schema is not standard — most JSON Schema tooling expects `$ref` to JSON. Mitigation: M1 ships YAML for human-readability, and the M2 `pmctl validate` extracts enums via `yq → jq` rather than relying on a generic resolver. If this proves brittle, **fallback is to author policy as JSON** with one-time conversion — single-file change.
- **R-design-4 (mitigates R6 silo creep)**: ContextPack source contract is a Markdown file (not a schema) because contracts-as-prose age better than contracts-as-pseudocode for pluggable interfaces; CC-237 baseline sources implement the contract in bash without a schema-validation step.
- **Alternative rejected — SQLite for state store**: ChatGPT seed plan proposed `~/.pm-dispatch/pm.sqlite3` (synthesis §3 table). Rejected because `pmctl` is bash (R4) and bash + SQLite means every read is a subprocess + SQL; JSONL is `tail -1 | jq` away and human-greppable on disk.
- **Alternative rejected — single global `runs.jsonl` with `repo` column**: simpler in directory tree, but `grep '"repo":"X"'` across decades of rows is asymptotically worse than `cat projects/<sha>/runs.jsonl` and loses the natural per-project lifecycle/rotation/wipe boundary.
- **Alternative rejected — TS interfaces in M1 alongside JSON Schema**: two-files-to-sync is the classic source-of-truth trap; codegen exists for the v0.4.0 MCP server to consume when needed (Q1).
- **Alternative rejected — `core/schema/v1/` directory versioning**: forces path moves on every schema bump, which is the exact churn the in-repo `core/` boundary is designed to avoid; inline `schema_version` field (Q8) achieves the same compatibility with no path break.
- **Alternative rejected — extract Rule A/B override discipline to YAML** (Q6 deeper extraction): override discipline is judgment-as-prose, encoding it as YAML produces a second source that drifts from `agents/project-pm.md`; if `pmctl` ever needs to enforce override rules machine-side (post-M2), extract then, not now.
- **Synthesis R7 mitigated**: this spike output is structured as a planner deliverable (no nested dispatch), consistent with CC-220's corrected planner + main-thread-fan-out shape; no implementation is proposed.

---

### Critical files for implementation

- `/home/screenleon/github/pm-dispatch/scripts/codex-dispatch.sh` (surface #2 — the pilot consumer of the new `runs_append` helper)
- `/home/screenleon/github/pm-dispatch/scripts/lib/handover-validate.sh` (surface #3 — policy extraction target; enum case blocks at `:121-125` / `:131-135`)
- `/home/screenleon/github/pm-dispatch/scripts/hook-routing-log.sh` (surface #6 — M2 cutover target; current `serialize_with_lock` consumer at `:199-216`)
- `/home/screenleon/github/pm-dispatch/scripts/lib/portable.sh` (`serialize_with_lock` at `:163` — the locking primitive every state writer reuses)
- `/home/screenleon/github/pm-dispatch/pm/schema.md` (the BACKLOG grammar source that re-homes to `core/schema/backlog-grammar.md` per synthesis §5.1)
