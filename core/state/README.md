# `core/state/` — on-disk state-store layout (definition only)

This directory defines the **path layout** of the pm-dispatch state store on disk. It does **not** define the writer.

`layout.yaml` is the single machine-readable source of truth for paths and naming. Future tooling reads this to resolve where state files live; nothing hardcodes paths.

## Storage location

State lives under `~/.local/share/pm-dispatch/state/` by default — per-machine, gitignored, tool-agnostic. The root is resolved at runtime by `state-writer.sh` using the following precedence: `$PM_DISPATCH_STATE_ROOT` (explicit override) → `$XDG_DATA_HOME/pm-dispatch/state` (XDG-aware) → `~/.local/share/pm-dispatch/state` (fallback). Adapters reach the store only via the runtime writer, never by globbing the dir.

## Partitioning

**Per-project.** Each repo gets its own state directory keyed by `sha1(git-toplevel)`. Cross-repo isolation is structural — `rsync` / `rm` a single project's directory without touching others.

## Crash-safety class

**Best-effort.** `serialize_with_lock` + `printf >> file`. No per-write fsync (opt-in via `PM_STATE_FSYNC=1`). On Linux a single JSONL row < PIPE_BUF (4096 bytes) is atomic — never partial/torn row, but may lose last record on power loss.

## Lifecycle / GC

Append-only logs (`runs.jsonl`, `events.jsonl`) rotate to `archive/<entity>-<YYYYMM>.jsonl.gz` when size > 50 MB OR age > 90 days. ContextPacks keep last 5 per `task_id`. Tasks/Reviews/Decisions have no TTL (one-file-per-row, individually addressable).

Rotation runs at the maintenance entry-point in the runtime writer module.
