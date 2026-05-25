# `core/` — pm-dispatch substrate (definitions only)

This directory contains the canonical PM-runtime data contract. **`core/` is definitions only — it knows nothing executable.**

- `schema/`        — JSON Schema files (`.schema.json`) for the 8 first-class
                     entities: Task, Run, Event, Review, Decision, Brief,
                     Handover, ContextPack.
- `policy/`        — declarative tables (YAML) for enums and state machines.
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
core/schema/         → core/policy/  (via inline enum + YAML editing source-of-truth)
core/state/          → core/schema/  (layout.yaml names which schema each path conforms to)
core/context-pack/   → core/schema/  (source.interface.md references context-pack.schema.json)
```

`core/policy/` is a leaf — depends on nothing.
`core/state/` does NOT import `core/policy/`.

The designated writer module reads `core/schema/`, `core/state/layout.yaml`, and `core/policy/` to validate writes and resolve paths. Only the designated writer module may write to `~/.local/share/pm-dispatch/state/` paths.

## Schema versioning

Every payload schema includes `schema_version: { const: 1 }` as a required field. Future breaking changes bump the int; old payloads remain valid against the old schema version. `jq '.schema_version'` is the bash-readable discriminator. No `$id` URLs.
