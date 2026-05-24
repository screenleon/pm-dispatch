# `core/context-pack/` — ContextPack source contract

This directory defines the pluggable source-interface contract for ContextPack assembly.

A **ContextPack** is a pre-dispatch context bundle — assembled from one or more **sources** (rg, git-log, memory, codegraph, ...) and injected into a brief's `context:` field or into a separate context file the executor reads. The shape is defined in `../schema/context-pack.schema.json`.

This directory contains:
- `source.interface.md` — the contract every source MUST implement.

It does NOT contain source implementations. Those live in the runtime layer and are pluggable.

## Why a prose contract (not a schema or interface file)?

Contracts-as-prose age better than contracts-as-pseudocode for pluggable interfaces. Source authors implement the contract in bash without a schema-validation step. If a future typed-interface consumer needs one, generate it from this prose + the context-pack schema at that point.

## See

- `source.interface.md` — the contract
- `../schema/context-pack.schema.json` — the assembled-pack shape
