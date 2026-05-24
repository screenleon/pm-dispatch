# Executor contract (PM handoff abstraction)

## Purpose

The PM handoff flow needs a stable, profile-agnostic contract so implementation can be swapped without redesigning every brief. This contract lets the owner/peer install profile choose how execution happens (codex today, others later) while keeping the handoff inputs and expected outputs consistent. It also allows future executors to coexist under the same dispatch protocol without redefining PM behavior or brief authoring discipline.

## Input contract

Every executor receives:

1. Brief markdown body in the existing dispatch schema (`docs/dispatch-brief.md`).
2. A `dispatch_handover_v1` metadata header written by PM.

Executor-agnostic metadata (must be interpreted by all concrete profiles):

- `working_dir`: absolute repo path the executor executes against
- `brief_file`: temporary file path containing the brief body
- `timeout`: dispatch SLA budget in seconds
- `model`: wire model alias requested by PM

Executor-specific metadata subsets:

- `sandbox`, `approval`, `skip_git_check`: codex-profile-only today (current validator and CLI assumptions).
- `claude`: minimal subset using main-thread semantics; codex-only fields (`sandbox`, `approval`, `skip_git_check`) are set to canonical no-op values for schema stability.

Executors should ignore unrecognized metadata keys unless they are intentionally documented for that profile.

## Output contract

Every executor must produce these three artifacts in its report:

- `diff`: file-level delta proving changes, with verification rooted in `git diff` from the PM main thread.
- `test evidence`: concrete outputs or artifact references for self-verify checks, and these must be cross-referenced by the report.
- `report`: narrative status record with:
  - `status` (`success`, `partial`, `blocked`)
  - `summary` (what changed and why)
  - `deferred_followups` (open work that should be done next)

The diff is the source of truth for work completion. The report is narrative context and must not replace file-level evidence.

## Executor profiles

| Aspect | codex profile | claude profile |
|---|---|---|
| Invoker | PM writes brief and launches `scripts/codex-dispatch.sh`; codex CLI performs the execution step. | PM writes brief and dispatches to main-thread tools (`Edit`/`Write`/`Bash`) directly. |
| Sandbox model | codex-managed workspace-write semantics with explicit sandbox metadata in metadata header. | Main-thread execution surface; no codex sandbox metadata contract. |
| Write/Bash mechanism | codex CLI drives edits and command execution. | Claude main-thread commands perform edits and checks directly, no codex CLI required. |
| Reviewer pipeline trigger | Existing codex executor path triggers the reviewer pipeline after handoff completion. | `/pr-gate` now routes through `executor` selection: existing codex path continues unchanged, and claude path fan-outs `pr-gate-handover_v1` entries to `claude-executor` then runs the synthesis flow. |
| Install requirement | `codex` install profile (current operational mode). | `claude` install profile (lightweight; no codex binary workflow dependency). |
| Suitable scope | Repo edits that are already in codex dispatch envelope. | Owner/peer hands-on environments where same-shell execution and direct main-thread editing are preferred. |
| Status | Implemented (primary route). | Implemented — `agents/claude-executor.md` + `executor: claude` enum + `install.sh --profile minimal\|full`. |

## Selection

Executor profile is an install-time choice (`codex` full profile versus `claude` minimal profile). PM continues writing briefs against the abstract contract, and the runtime profile determines execution behavior. Per-brief override via `executor: ...` is part of the handover metadata contract.

## Forward-compat notes

`scripts/lib/handover-validate.sh` accepts `executor: codex` and `executor: claude`; any other value is rejected. The `claude` adapter is `agents/claude-executor.md`. This document remains the upstream behavioral contract; future executors (e.g. other CLIs) should match the same input/output shape and add their entry to the executor enum + executor profiles table.
