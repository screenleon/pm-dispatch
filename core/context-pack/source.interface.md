# ContextPack Source Interface

Every ContextPack source MUST satisfy this contract. The contract is intentionally Markdown-prose (not a typed interface file) — see `README.md` for rationale.

## Required surface

A source is a bash module (or equivalent) exposing at minimum:

### `name`

A unique identifier. Matches `sources[].name` in the assembled `ContextPack` (see `../schema/context-pack.schema.json`).

- Free string, lowercase + hyphens (`rg`, `git-log`, `memory`, `codegraph`).
- MUST be CLI-agnostic: no CLI product name (`codex`, `claude`, `antigravity`, `opencode`).

### `version`

Source-implementation version. Bumps when the source's output shape or filter logic changes.

- Free string. Semver-ish recommended (`1.0.0`, `1.1.0-rc1`). No format enforcement.

### `build(task_id) → items[]`

Builds a list of items relevant to the given task. Each item populates one of the four categorical arrays in the pack: `files`, `symbols`, `memories`, `risks`.

Returns an array of objects matching the `item` schema in `context-pack.schema.json`:

- `ref` — what the item points at (file path, symbol fqn, memory slug, risk id)
- `source` — MUST equal this source's `name`
- `confidence` — float ∈ [0, 1]; consumer ranking signal
- `rationale` — optional human-readable explanation (`"matched 3× in test files"`, etc.)

The source decides which category each item belongs to. Convention: a file path → `files[]`; a function/class fqn → `symbols[]`; a memory slug → `memories[]`; a risk id → `risks[]`.

## Required invariants

1. **No state mutation.** Sources are pure functions of `(task_id, repository state at time of build)`. They MUST NOT write to disk, modify the working tree, or change any process state. The store is `pmctl`'s exclusive territory.

2. **No inter-source dependencies.** Sources MUST NOT depend on the output of other sources. The assembler invokes sources in arbitrary order; sources cannot rely on a specific ordering.

3. **Bounded runtime.** A source SHOULD complete in < 5 seconds for typical `task_id` input. The assembler MAY enforce a hard timeout.

4. **No network calls.** Sources operate on local repository state only. Indexed remote sources MAY relax this only when the contract is extended (schema_version bump).

5. **Confidence MUST be meaningful.** `confidence: 1.0` reserved for exact matches; `confidence: 0.0` for "the consumer should reject this." Sources MUST NOT emit items at `confidence: 0`. (Convention; not schema-enforced.)

6. **Deterministic for fixed input.** Same `task_id` + same repository state ⇒ same `items[]`. No randomness, no time-based variation. Required so context-pack assembly is reproducible / cacheable.

## Optional surface

### `config`

A source MAY accept a configuration object (matching `sources[].config` in the pack). Examples:

- `rg`: `{glob: "*.sh", max_matches_per_query: 50}`
- `git-log`: `{since_days: 30, exclude_paths: ["docs/"]}`
- `memory`: `{include_types: ["feedback", "project"], exclude_stale_days: 60}`
- `codegraph`: `{language: "typescript", max_depth: 3}`

If a source supports config, it MUST also accept absent / empty config and behave with sensible defaults.

### `health_check() → ok | reason: string`

A source MAY implement a self-test that the assembler runs before invoking `build()`. Used to detect installation issues (e.g. `rg` not on PATH, codegraph index not built).

## What sources are NOT

- Sources do NOT decide which categories a task needs. The assembler / brief author picks the source set.
- Sources do NOT mutate the pack after assembly. They contribute items; the assembler combines.
- Sources do NOT implement caching beyond what their underlying tool already provides. Pack caching is the assembler / consumer's concern.
- Sources are NOT `pmctl` subcommands. They are libraries the assembler invokes.

## Versioning

Breaking changes to this contract bump `context-pack.schema.json` `schema_version` (the pack's required `const` field). Source authors update the `schema_version` they produce; consumers handle both versions during a deprecation window.
