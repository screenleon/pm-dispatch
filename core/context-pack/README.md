# `core/context-pack/` — ContextPack source contract

This directory defines the pluggable source-interface contract for v0.3.0 ContextPack assembly (CC-232).

A **ContextPack** is a pre-dispatch context bundle — assembled from one or more **sources** (rg, git-log, memory, codegraph, ...) and injected into a brief's `context:` field or into a separate context file the executor reads. The shape is defined in `../schema/context-pack.schema.json`.

This directory contains:
- `source.interface.md` — the contract every source MUST implement (M1 deliverable; design only).

It does NOT contain source implementations. Those live in `runtime/pmctl/lib/source-*.sh` (M4 / CC-237) and are pluggable.

## Why a prose contract (not a schema or interface file)?

Synthesis Q1 (Markdown contract vs `.ts` interface vs `.schema.json`): contracts-as-prose age better than contracts-as-pseudocode for pluggable interfaces. CC-237 baseline sources implement the contract in bash without a schema-validation step. If a future MCP server (CC-216, v0.4.0) needs a typed interface, generate it from this prose + the context-pack schema at that point.

## See

- `source.interface.md` — the contract
- `../schema/context-pack.schema.json` — the assembled-pack shape
- `docs/spikes/CC-229-substrate-synthesis.md` §A ContextPack — design rationale
