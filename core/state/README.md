# `core/state/` — on-disk state-store layout (definition only)

This directory defines the **path layout** of the pm-dispatch v0.3.0 state store on disk. It does **not** define the writer — that lives at `runtime/pmctl/lib/state-writer.sh` (M2 / CC-230).

`layout.yaml` is the single machine-readable source of truth for paths and naming. Future tooling reads this to resolve where state files live; nothing hardcodes paths.

## Storage location

State lives at `~/.claude/.pm/state/` — per-machine, gitignored, CLI-agnostic. The `~/.claude/` prefix is incidental (existing installer-managed dir); future adapters reach the store only via `pmctl`, never by globbing the dir (per `[[feedback_memory_cli_agnostic]]`).

The memory-private split (`[[reference_memory_private_repo]]`) is provisional; per-project partitioning (`projects/<sha1(git-toplevel)>/`) is forward-compatible with any future memory-architecture rework.

## Partitioning

**Q2 resolved 2026-05-24: per-project**. Each repo gets its own state directory keyed by `sha1(git-toplevel)`. Trade-offs and rejected alternative (global flat) documented in `docs/spikes/CC-229-substrate-synthesis.md` §B.

## Crash-safety class

**Q3 resolved 2026-05-24: best-effort.** `serialize_with_lock` + `printf >> file`. No per-write fsync (opt-in via `PM_STATE_FSYNC=1`). On Linux a single JSONL row < PIPE_BUF (4096 bytes) is atomic — never partial/torn row, but may lose last record on power loss.

## Lifecycle / GC

Append-only logs (`runs.jsonl`, `events.jsonl`) rotate to `archive/<entity>-<YYYYMM>.jsonl.gz` when size > 50 MB OR age > 90 days. ContextPacks keep last 5 per `task_id`. Tasks/Reviews/Decisions have no TTL (one-file-per-row, individually addressable).

Rotation runs at `pmctl maintenance` (M2 command — name reserved, not yet designed). No automatic rotation in M1.

## See

- `layout.yaml` — the actual path definitions
- `docs/spikes/CC-229-substrate-synthesis.md` §B for the trade-off table
- `core/README.md` for invariants + dependency graph
