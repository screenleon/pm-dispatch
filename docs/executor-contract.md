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

- `isolation_level` (canonical, M3+): abstract isolation intent; adapter layer translates to executor-native flags. Values: `none | read-only | workspace-write | workspace-network | sandboxed`. Source of truth: `core/policy/isolation-level.yaml`. Note: `none` is not accepted on `main_thread_bash_background` route (maps to `danger-full-access`).
- `sandbox`, `approval`, `skip_git_check` (legacy, backward-compat): codex-profile-only native flags. Accepted when `isolation_level` is absent (pre-M3 briefs). New briefs must use `isolation_level` instead; mixing both is rejected.
- `claude` profile: use `isolation_level: workspace-write` (or appropriate level); the adapter layer handles translation and the agent itself ignores isolation metadata.

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

## Filesystem output contract

All executors MUST write a trace to `<work_dir>/.agent-trace/` on every run.

| File | Description |
|---|---|
| `<executor>-<ts>.last` | Final agent message, plain text; for example, `codex-1748000000.last` or `claude-1748000000.last`. |
| `latest.last` | Symlink or regular file pointing to the most recent `.last` content. |
| `latest.stderr` | Symlink or regular file containing error output; optional; may be empty; codex profile only. |

### Path validation rules

- `latest.last` and `latest.stderr` MUST be symlinks or files whose resolved path stays within `<work_dir>/.agent-trace/`. A symlink pointing outside that directory causes `dispatch-post-verify.sh` to exit 1.
- The `<executor>-<ts>.last` basename format is: executor name (alphanumeric, hyphens allowed; no path separators) + `-` + wall-clock timestamp plus PID (`date +%Y%m%d-%H%M%S`-PID) + `.last`. Example: `codex-20260526-143048-3455197.last`, `claude-20260526-143048-3455197.last`.
- `dispatch-post-verify.sh` validates symlink targets for both `latest.last` and `latest.stderr` before reading their contents. Executors that write trace files outside `.agent-trace/` violate this contract and will fail Phase 3.
- Self-verify execution (CC-318): `dispatch-post-verify.sh` **executes** each `self_verify:` item from the brief as a bash command in `<work_dir>` and treats exit 0 as PASS, any non-zero (including timeout) as FAIL. It does **not** parse self_verify results out of `latest.last`, so the executor's prose style is irrelevant — an executor may still echo its own self_verify results for human review, but that text is informational and not part of this contract.

`<ts>` is a wall-clock timestamp plus PID written at dispatch time by `date +%Y%m%d-%H%M%S`-PID.

### Adapter stdout footer (explicit path handoff)

Every adapter MUST emit the following lines on **stdout** after the executor exits, in this exact format:

```
---
trace:  <absolute-path-to-trace-jsonl>
last:   <absolute-path-to-per-run-last>
stderr: <absolute-path-to-per-run-stderr>
exit:   <integer-exit-code>
---
```

`pmctl dispatch run` captures this footer and passes `last:` and `stderr:` as `--last`/`--stderr` flags to `dispatch-post-verify.sh`, so post-verify uses the **per-run** explicit paths rather than the `latest.*` symlinks. This prevents a concurrent-dispatch race where a second adapter run overwrites `latest.*` before the first run's post-verify reads it (CC-305). `latest.*` symlinks are updated by the adapter for human observation only and are not load-bearing for post-verify correctness.

Note: codex profile — `adapters/codex/dispatch.sh` (reachable via the `scripts/codex-dispatch.sh` compatibility shim, and invoked through `pmctl dispatch run --adapter codex`) already satisfies this contract. claude profile — `agents/claude-executor.md` Write trace step satisfies this contract. `pmctl dispatch run` captures the adapter stdout footer and passes the explicit per-run `last:` and `stderr:` paths to `dispatch-post-verify.sh` via `--last`/`--stderr` flags; those per-run paths are the load-bearing input to Phase 3. `latest.last` and `latest.stderr` are updated by the adapter for human observation only and are not read by post-verify when explicit paths are present.

## Executor profiles

| Aspect | codex profile | claude profile |
|---|---|---|
| Invoker | PM writes the brief to a file and runs `pmctl dispatch run --adapter codex --brief-file <path>`, which validates + guards before invoking the `adapters/codex/dispatch.sh` adapter (codex CLI performs the execution step). The legacy `scripts/codex-dispatch.sh` shim remains for direct/legacy callers but bypasses the pmctl policy flow. | **Canonical:** `pmctl dispatch run --adapter claude --brief-file <path>` invokes the `adapters/claude/dispatch.sh` adapter, which runs headless `claude --print` as a CLI subprocess — host-independent, so codex-as-PM can drive it. **Same-host optimization:** when Claude IS the main thread, `agents/claude-executor.md` (Agent-spawn) runs the brief inline. |
| Sandbox model | codex-managed workspace-write semantics with explicit sandbox metadata in metadata header. | Main-thread execution surface; no codex sandbox metadata contract. |
| Write/Bash mechanism | codex CLI drives edits and command execution. | Claude main-thread commands perform edits and checks directly, no codex CLI required. |
| Reviewer pipeline trigger | Existing codex executor path triggers the reviewer pipeline after handoff completion. | `/pr-gate` now routes through `executor` selection: existing codex path continues unchanged, and claude path fan-outs `pr-gate-handover_v1` entries to `claude-executor` then runs the synthesis flow. |
| Install requirement | `codex` install profile (current operational mode). | `claude` install profile (lightweight; no codex binary workflow dependency). |
| Suitable scope | Repo edits that are already in codex dispatch envelope. | Owner/peer hands-on environments where same-shell execution and direct main-thread editing are preferred. |
| Status | Implemented (primary route). | Implemented — `agents/claude-executor.md` + `executor: claude` enum + `install.sh --profile minimal\|full`. |

## Guard enforcement

Guard policy (what a role may write or run) is **executor-agnostic and lives in one place**: the guard hook scripts (`hook-pm-write-guard.sh`, `hook-codex-write-guard.sh`, `hook-claude-write-guard.sh`, `hook-codex-bash-guard.sh`), surfaced as a CLI via `pmctl guard check --event <pre-write|pre-bash|post-task> --role <pm|executor|reviewer> [--runtime <codex|claude>] --file/--command <val>`. Guard keys on the **role** (runtime-agnostic for `pm`; the `--runtime` axis is consulted only where a role's policy differs by runtime, e.g. `executor/pre-bash`); dispatch supplies the runtime via its `--adapter` (CC-291). For `executor`, the pre-write hook is selected by runtime convention (`hook-<runtime>-write-guard.sh`) — so the role-level write policy is one rule while the physical hook stays identity-matched, and adding a runtime needs no guard edit. `--profile <pm|codex|claude>` is a deprecated alias that maps onto `(role, runtime)`. The CLI synthesizes the canonical hook input and drives the same hook, so every host enforces the identical decision (deny → non-zero exit + reason).

The **trigger** is asymmetric by capability, not by policy:

| Host | Guard trigger |
|---|---|
| Claude | PreToolUse auto-hook fires before each `Edit`/`Write`/`Bash`; enforcement is automatic and cannot be skipped by the agent. |
| Non-Claude (e.g. codex-as-PM) | The host has no PreToolUse equivalent, so it MUST call `pmctl guard check` explicitly before the action and honor a non-zero exit as a deny. |

This asymmetry is inherent to the host's CLI capabilities — both paths evaluate the same policy. The **`--role`** selects the policy because each role has a different allow-list (pm pre-write → memory dir only; executor pre-write → `/tmp/brief-*.md` only); the **`--runtime`** axis refines it only where a role's policy genuinely differs by runtime (e.g. `executor/pre-bash`, which only codex registers). Claude PreToolUse hooks may later shell to `pmctl guard check` to collapse to a single source, but today they remain the policy source the CLI composes.

**On the two dispatch entrypoints (single policy, not split-brain):** `pmctl dispatch run` is the policy surface — it runs `brief-validate` + `pmctl guard check` before invoking the adapter. The codex adapter (`adapters/codex/dispatch.sh`, and its `scripts/codex-dispatch.sh` compatibility shim) is also directly callable — that is the codex-executor agent path, where the **same** guard policy is enforced by the Claude PreToolUse auto-hook on the brief-file Write. So both entrypoints are guarded by one policy with two triggers (the asymmetry above); the directly-callable adapter is the low-level primitive, not an unguarded bypass. A non-Claude host that calls the adapter directly (outside both `pmctl dispatch run` and a PreToolUse-capable agent) is responsible for calling `pmctl guard check` itself, exactly as the non-Claude row above requires.

The surface is **fail-closed**: a success exit (`0`) always means a registered policy ran and permitted the action — never that enforcement was skipped. Exit codes:

| Exit | Meaning |
|---|---|
| `0` | a registered policy ran and **allowed** the action |
| `2` | usage error (bad/missing flags) **or** a registered policy **denied** the action (the hook's own deny exit is propagated) |
| `3` | request recognized but **no policy registered** to evaluate it — `pm/pre-bash` (project-pm never runs Bash), `executor` + `runtime=claude` + `pre-bash` (claude-executor self-executes under harness perms; no dispatch-guard bash policy), and the reserved-but-unimplemented `post-task` event. Distinct from `2` so a caller can tell "I cannot enforce this" apart from "this was denied". |

## Selection

Executor profile is an install-time choice (`codex` full profile versus `claude` minimal profile). PM continues writing briefs against the abstract contract, and the runtime profile determines execution behavior. Per-brief override via `executor: ...` is part of the handover metadata contract.

## Forward-compat notes

`scripts/lib/handover-validate.sh` accepts `executor: codex` and `executor: claude`; any other value is rejected. The `claude` adapter is `agents/claude-executor.md`. This document remains the upstream behavioral contract; future executors (e.g. other CLIs) should match the same input/output shape and add their entry to the executor enum + executor profiles table.
