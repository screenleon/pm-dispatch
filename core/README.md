# `core/` — pm-dispatch substrate (definitions only)

This directory contains the canonical PM-runtime data contract. **`core/` is definitions only — it knows nothing executable.**

- `schema/`        — JSON Schema files (`.schema.json`) for runtime entities
                     and evidence envelopes, including gate assurance.
- `policy/`        — declarative YAML/TSV tables for enums, presets, and state
                     machines.
- `state/`         — definition of the on-disk state-store layout
                     (`~/.local/share/pm-dispatch/state/`). **Definitions, not the writer.**
- `context-pack/`  — source-interface contract for ContextPack assembly.

Gate assurance definitions are split deliberately:

- `policy/gate-tiers.tsv`, `gate-modes.tsv`, and `gate-pass-kinds.tsv` define
  the independent assurance coordinates.
- `policy/gate-policy-consumers.tsv` and `gate-policy-signals.tsv` define
  consumer-specific coverage and deterministic risk floors.
- `schema/gate-policy-override.schema.json` defines explicit scope-bound user
  approval for a tier or reviewer-coverage downgrade; mode remains a direct
  user choice.
- `schema/gate-assurance.schema.json` defines the portable envelope that records
  resolved coordinates, policy resolution, immutable subject, and linked
  evidence.
- `schema/gate-scope-manifest.schema.json` defines the content-addressed,
  immutable-subject-bound scope declaration shared by every selected reviewer.
  It records exact changed inputs, bounded review hints, and explicit
  truncation rather than claiming a complete call graph. Current producers also
  index allowed evidence paths with snapshot line counts and content digests.
- `schema/gate-reviewer-result.schema.json` defines the selected-reviewer
  coverage checklist and actionable finding contract. Its JSON verdict is the
  machine source of truth; Markdown headings are presentation only.
- `schema/gate-verification.schema.json` defines the shared three-axis
  assessment returned to gate consumers.

## Invariants

1. **`core/*` may NOT import / reference `runtime/`, `scripts/`, `adapters/`,
   or any executable.** Definitions are pure.
2. **No CLI product name** (`codex`, `claude`, `antigravity`, `opencode`)
   appears as a hard-coded field name, path segment, or directory name.
   CLI-agnostic by construction.
3. **Schema is locked.** Subsequent changes are versioned breaking events:
   bump `schema_version` (each payload carries a required positive integer
   `const` or a closed compatibility `enum`) + add a `CHANGELOG.md` entry + record the migration in
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

Every payload schema includes `schema_version` as a required positive integer.
A single-version schema uses `const`; a compatibility schema may use a closed
`enum` with kind/version pairing. Breaking changes bump that integer; old
payloads remain valid against the schema version that defines them.
`jq '.schema_version'` is the bash-readable discriminator. No `$id` URLs.
