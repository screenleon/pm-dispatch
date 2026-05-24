# `core/` — pm-dispatch v0.3.0 substrate (definitions only)

This directory contains the canonical PM-runtime data contract for pm-dispatch
v0.3.0. **`core/` is definitions only — it knows nothing executable.**

Per `docs/architecture/v0.3.0-synthesis.md` §5.1 and the M1 substrate spike
(`docs/spikes/CC-229-substrate-{scope,claude,codex,synthesis}.md`):

- `schema/`        — JSON Schema files (`.schema.json`) for the 8 first-class
                     entities: Task, Run, Event, Review, Decision, Brief,
                     Handover, ContextPack.
- `policy/`        — declarative tables (YAML) for enums and state machines.
- `state/`         — definition of the on-disk state-store layout
                     (`~/.claude/.pm/state/`). **Definitions, not the writer.**
- `context-pack/`  — source-interface contract for CC-232 context bundles.

## Invariants

These are enforced (or will be enforced via CC-233 layer-boundary test):

1. **`core/*` may NOT import / reference `runtime/`, `scripts/`, `adapters/`,
   or any executable.** Definitions are pure.
2. **No CLI product name** (`codex`, `claude`, `antigravity`, `opencode`)
   appears as a hard-coded field name, path segment, or directory name.
   CLI-agnostic by construction (per `[[feedback_memory_cli_agnostic]]`).
3. **Schema is locked at the end of M1.** Subsequent changes are versioned
   breaking events: bump `schema_version` (each payload carries it as a
   required `const` field) + add a `CHANGELOG.md` entry + record the
   migration in `DECISIONS.md`. No `core/schema/v1/` directory versioning
   (Q8 resolved 2026-05-24).

## Dependency graph (acyclic, downward)

```
core/schema/   →  core/policy/    (via $ref to YAML enum / state files)
core/state/    →  core/schema/    (layout.yaml names which schema each path conforms to)
core/context-pack/  →  core/schema/   (source.interface.md references context-pack.schema.json)
```

`core/policy/` is a leaf — depends on nothing.
`core/state/` does NOT import `core/policy/`.

The runtime writer (M2 / CC-215 `pmctl`) reads `core/schema/`, `core/state/layout.yaml`, and `core/policy/` to validate writes and resolve paths. Only `runtime/pmctl/lib/state-writer.sh` (M2) may write to `~/.claude/.pm/state/` paths.

## Schema versioning

Every payload schema includes `schema_version: { const: 1 }` as a required field. Future breaking changes bump the int; old payloads remain valid against the old schema version. `jq '.schema_version'` is the bash-readable discriminator. No `$id` URLs in M1.

## Status

M1 substrate landed via the CC-229 schema-only PR. Implementation tickets that consume the substrate:
- CC-230 — `runtime/pmctl/lib/state-writer.sh` + `codex-dispatch.sh` pilot consumer
- CC-231 — `scripts/lib/handover-validate.sh` policy extraction
- CC-232 — context-pack source implementations (M4 / CC-237)
