# `core/` — pm-dispatch substrate (definitions only)

This directory contains the canonical PM-runtime data contract. **`core/` is definitions only — it knows nothing executable.**

- `schema/`        — JSON Schema files (`.schema.json`) for runtime entities
                     and evidence envelopes, including gate assurance.
- `policy/`        — declarative YAML/TSV tables for enums, presets, and state
                     machines.
- `state/`         — definition of the on-disk state-store layout
                     (`~/.local/share/pm-dispatch/state/`). **Definitions, not the writer.**
- `context-pack/`  — source-interface contract for ContextPack assembly.

## Invariants

1. **`core/*` may NOT import / reference `runtime/`, `scripts/`, `adapters/`,
   or any executable.** Definitions are pure.
2. **No CLI product name** (`codex`, `claude`, `antigravity`, `opencode`)
   appears as a hard-coded field name, path segment, or directory name.
   CLI-agnostic by construction.
3. **Schema is locked.** Subsequent changes are versioned breaking events:
   bump `schema_version` (each payload carries it as a required `const`
   field) + add a `CHANGELOG.md` entry + record the migration in
   `DECISIONS.md`. No directory versioning under `core/schema/`.

## Dependency graph (acyclic, downward)

```
core/schema/         → core/policy/  (via inline enum + declarative editing source-of-truth)
core/state/          → core/schema/  (layout.yaml names which schema each path conforms to)
core/context-pack/   → core/schema/  (source.interface.md references context-pack.schema.json)
```

`core/policy/` is a leaf — depends on nothing.
`core/state/` does NOT import `core/policy/`.

The designated writer module in `runtime/lib/state-writer.sh` is the sole manager of writes to `~/.local/share/pm-dispatch/state/` paths. It validates every durable Run, Event, Task, and Decision write against recursive object requirements, constants, primitive types, enums, and `if`/`then` conditionals declared in `core/schema/`, using `jq` only. Runtime enum consumers read the corresponding declarative source under `core/policy/`, while parity tests keep inline schema mirrors and generated portability snapshots synchronized. Full draft-07 validation remains a development/test concern rather than a runtime dependency.

## Schema versioning

Every payload schema includes `schema_version` as a required integer `const`
field. Breaking changes bump that integer; old payloads remain valid against
the schema version that defines them. `jq '.schema_version'` is the
bash-readable discriminator. No `$id` URLs.
