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

- `isolation_level` (canonical, M3+): abstract isolation intent; adapter layer translates to executor-native flags. Values: `none | read-only | workspace-write | workspace-network | sandboxed`. Source of truth: `core/policy/isolation-level.yaml`. Note: `none` (full machine access) is **opencode-only** (load-bearing — it has no finer-grained sandbox); codex and claude reject `none` on all routes, and the codex adapter additionally rejects a raw `--sandbox danger-full-access` flag, so their max isolation is `workspace-write`.
- `sandbox`, `approval`, `skip_git_check` (legacy): removed. A brief carrying any of them is rejected; use `isolation_level` instead.
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

All executors MUST write a trace to an `.agent-trace/` directory on every run. The
default location is **out-of-repo**: `sw_project_run_dir <run_id>`
resolves to `~/.local/share/pm-dispatch/state/projects/<project_key>/runs/<run_id>/.agent-trace/`
(precedence: explicit `--trace-dir` flag > `PM_DISPATCH_TRACE_DIR` env > this
default). The legacy in-repo `<work_dir>/.agent-trace/` path is only reached as a
fallback when the out-of-repo state store is unavailable. Discover the effective
path per run via `trace_path:` in the dispatch record (`pmctl artifacts show <run_id>`),
not by assuming a fixed location.

| File | Description |
|---|---|
| `<executor>-<ts>.last` | Final agent message, plain text; for example, `codex-1748000000.last` or `claude-1748000000.last`. |
| `latest.last` | Symlink or regular file pointing to the most recent `.last` content. |
| `latest.stderr` | Symlink or regular file containing error output; optional; may be empty; codex profile only. |

### Path validation rules

- `latest.last` and `latest.stderr` MUST be symlinks or files whose resolved path stays within the resolved `.agent-trace/` directory for the run. A symlink pointing outside that directory causes `dispatch-post-verify.sh` to exit 1.
- The `<executor>-<ts>.last` basename format is: executor name (alphanumeric, hyphens allowed; no path separators) + `-` + wall-clock timestamp plus PID (`date +%Y%m%d-%H%M%S`-PID) + `.last`. Example: `codex-20260526-143048-3455197.last`, `claude-20260526-143048-3455197.last`.
- `dispatch-post-verify.sh` validates symlink targets for both `latest.last` and `latest.stderr` before reading their contents. Executors that write trace files outside the resolved `.agent-trace/` directory violate this contract and will fail Phase 3.
- Self-verify execution: `dispatch-post-verify.sh` **executes** each `self_verify:` item written in the structured `- cmd: "<bash>"` form, running the command in `<work_dir>` and treating exit 0 as PASS, any non-zero (including timeout) as FAIL. Every other item shape (named macros, prose, bare scalars) is a semantic check the executor — not a shell — evaluates; post-verify marks it `SKIP (executor-evaluated)` and never fails on it. post-verify does **not** parse self_verify results out of `latest.last`, so the executor's prose style is irrelevant to the executed checks; an executor may still echo its own self_verify results for human review, but that text is informational and not part of this contract.

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

`pmctl dispatch run` captures this footer durably at `<run_dir>/.agent-trace/<run_id>.footer` (the resolved run directory, out-of-repo by default per the Filesystem output contract above) and passes `trace:`, `last:`, and `stderr:` as explicit `--jsonl`/`--last`/`--stderr` flags to `dispatch-post-verify.sh`, so post-verify uses the **per-run** explicit paths rather than the `latest.*` symlinks. This prevents a concurrent-dispatch race where a second adapter run overwrites `latest.*` before the first run's post-verify reads it. The persisted footer is local durable evidence of the adapter-declared per-run artifacts for recovery paths; `latest.*` symlinks are updated by the adapter for human observation only and are not load-bearing for post-verify correctness.

Note: codex profile — `adapters/codex/dispatch.sh` (invoked through `pmctl dispatch run --adapter codex`) already satisfies this contract. claude profile — `adapters/claude/dispatch.sh` writes the trace via the headless `claude --print` subprocess. `pmctl dispatch run` persists the adapter stdout footer and passes the explicit per-run `trace:`, `last:`, and `stderr:` paths to `dispatch-post-verify.sh`; those per-run paths are the load-bearing input to Phase 3. `latest.last`, `latest.jsonl`, and `latest.stderr` are updated by the adapter for human observation only and are not read by post-verify when explicit paths are present.

### Durable dispatch record

After `pmctl dispatch run` reaches a terminal foreground state (`ok` or `failed`), it writes a repo-local record at `<work_dir>/.dispatch-results/<run_id>.md`. This record is keyed by the same `run_id` used in the state store, but it is a standalone artifact: it does not add fields to `runs.jsonl` and does not change `core/schema/run.schema.json`.

The record contains YAML frontmatter with machine-readable summary fields (`run_id`, optional `task_id`, `executor`, `model`, `brief_file`, `working_dir`, `exit_code`, `final_state`, `verify_summary`, per-run trace paths, `created_ts`, and `finished_ts`) plus a short human-readable body. For successful adapter exits, `verify_summary` is the captured stdout from `dispatch-post-verify.sh`; for adapter non-zero exits that short-circuit before post-verify, it is a short adapter-exit verdict.

`.dispatch-results/` is intentionally gitignored like `.gate-results/` and `.agent-trace/`: it is durable for local recovery across threads or shell sessions, not a committed project artifact.

**Record-write contract depends on lifecycle:**
- **Foreground (`--lifecycle foreground`)**: record writes are best-effort observability. If writing the markdown file fails, `pmctl dispatch run` logs a warning to stderr and preserves the original dispatch exit code.
- **Detached (`--lifecycle detached`)**: the authoritative completion signal for `pmctl dispatch wait` is a **supervisor sentinel** written to `/tmp/pm-supervisor-sentinel-<run_id>-<nonce>` by `scripts/dispatch-supervisor.sh`. The nonce is generated by the parent before supervisor launch and is **not** stored in the workspace run-spec; the supervisor reads it from an environment variable, unsets it before exec-ing the adapter, and the key file lives in a per-user `mode 700` directory.

  **Trust model (read this — the boundary is deliberately scoped):** the nonce sentinel defends the completion signal against (a) *other OS users*, who cannot read the `mode 700` key directory, and (b) accidental cross-run / predictable-path collisions. It does **not** defend against a hostile *same-user* executor: a process running under the same uid can read the key directory and forge the nonce-bearing sentinel — this is a filesystem invariant, not a fixable gap. pm-dispatch treats the executor as **trusted** (same-user, login-authenticated, the operator's own coding agent); a compromised executor is out of scope for this signal because it already has full same-uid filesystem access. This is a deliberate, user-accepted trust boundary, not an oversight.

  The in-workspace dispatch record (`.dispatch-results/<run_id>.md`) is executor-writable and therefore **never authoritative**: `dispatch wait` resolves a terminal outcome only from the supervisor sentinel at the nonce-including `/tmp` path. If the sentinel key is absent (consumed by a prior wait, cleaned up by reboot/tmpwatch, or removed), `dispatch wait` returns an **indeterminate** non-zero status (**exit 3**) and prints the durable record for observability only — it never reports the workspace record as authenticated success.

## Non-interactive executor contract (Model B)

Model B is the canonical dispatch topology: `pmctl dispatch run` lands the brief and the executor runs as an **independent subprocess** that consumes it (see DECISIONS.md 2026-06-15). Every Model B executor — codex, claude, and future third-party adapters (opencode, antigravity) — MUST satisfy the following common contract. This is the baseline a new adapter is measured against; each requirement maps to an adapter self-check or a `doctor` check.

1. **Brief is pmctl-landed.** The brief body is written to a file by trusted code (`pmctl`, or PM via `Write` to `/tmp/brief-*.md`) and passed to the adapter with `--brief-file`. An executor subagent does **not** self-write its own brief on the main route; that path is a fallback only (see 5).

2. **Executor is an independent subprocess driven by a headless CLI.** The adapter invokes the executor's headless CLI (`codex exec`, `claude --print`, …) as a child process. There is no in-process agent on the main route.

3. **Auth precondition is pre-login; unauthenticated runs fail loud.** The executor CLI MUST already be authenticated before dispatch (interactive login, API key, or OAuth token) — pm-dispatch never authenticates on the executor's behalf. An unauthenticated executor MUST fail loudly, never silently report success. Two enforcement layers:
   - **Proactive:** `doctor.sh` probes each present executor CLI for credentials (best-effort, non-interactive: checks well-known credential files and API-key/OAuth env vars without running the CLI or reading secret contents) and emits a **FAIL** when the binary is present but no credentials are detected. Heuristic — on hosts that store credentials outside these locations (e.g. macOS Keychain) it can false-negative; the supported platform (Linux/WSL2) uses files.
   - **Authoritative (dispatch-time):** an unauthenticated run produces no semantic terminal event, so the post-verify terminal-event check (see 4) fails the run regardless of the proactive probe.

4. **Output contract + triple-machine-check verification.** The load-bearing outputs are `<run_dir>/.agent-trace/latest.last` (per-run `<executor>-<ts>.last`, the final-message artifact) and the `<executor>-<ts>.jsonl` event stream (load-bearing for machine verification — the structural and terminal-event checks below run against it); both are surfaced via the stdout footer. `pmctl` is the **sole result verifier** — the executor's natural-language conclusion is a self-report, never the verdict. Verification is three machine checks:
   - (a) **exit code** — a non-zero adapter exit short-circuits to `failed` (no post-verify).
   - (b) **trace structural integrity** — `latest.jsonl` must parse as a JSON stream with at least one value (catches truncated/orphaned traces); adapter-agnostic.
   - (c) **semantic terminal event** — the adapter DECLARES its completion marker as `terminal_event` in `adapter.yaml` (the JSONL event `.type` emitted at the end of a finished run); `pmctl dispatch run` reads it and passes `--terminal-event <type>` to `dispatch-post-verify.sh`, which asserts at least one trace record carries that `.type`. A structurally-whole trace that never reached completion (e.g. stops at `turn.started`) passes (b) but fails (c). The predicate shape is fixed to `.type == <declared value>` (the value is injected, never an arbitrary jq filter from the manifest). Flag-gated: positional/legacy callers that pass no `--terminal-event` stay structure-only (back-compat).

   | Executor | `terminal_event` | Trace shape |
   |---|---|---|
   | codex | `turn.completed` | `codex exec --json` emits one `turn.completed` event at end of turn |
   | claude | `result` | `claude --print --output-format stream-json` emits per-event JSONL ending with a trailing `type==result` event |
   | opencode | `step_finish` | opencode CLI emits per-event JSONL ending with a `step_finish` event |

5. **Fallback policy — no headless CLI → subagent path (none ships).** A runtime with **no** headless CLI could not run Model B and would need a subagent (Agent-spawn) route gated by the live PreToolUse write hook. No such runtime ships: every supported executor (codex, claude, opencode) has a headless CLI and runs as an independent subprocess via `pmctl dispatch run`, with the brief authored by trusted main-thread code. The `claude-executor` and `codex-executor` subagents were both retired, so there is no Agent-spawn executor route today; the live-hook write-guard branch survives only as defensive infrastructure for a hypothetical future no-CLI self-writing runtime.

6. **Output format prefers streaming.** When an executor CLI supports both a streaming (per-event JSONL) and a single-blob output mode, the adapter selects streaming so the trace can be confirmed event-by-event. (claude uses `--output-format stream-json`; codex `--json` is already a per-event stream.)

`model` alias and `isolation_level` translation follow the existing adapter convention (each adapter's `isolation-map.yaml` and the shared model-alias table); they are not redefined here.

## Executor profiles

| Aspect | codex profile | claude profile |
|---|---|---|
| Invoker | PM writes the brief to a file and runs `pmctl dispatch run --adapter codex --brief-file <path>`, which validates + guards before invoking the `adapters/codex/dispatch.sh` adapter (codex CLI performs the execution step). | `pmctl dispatch run --adapter claude --brief-file <path>` invokes the `adapters/claude/dispatch.sh` adapter, which runs headless `claude --print` as a CLI subprocess — host-independent, so codex-as-PM can drive it. |
| Sandbox model | Isolation intent comes from the required handover `isolation_level:` field; the codex adapter translates it to codex-native `--sandbox`/`--approval`/`-c` flags (workspace-write default). | Headless `claude --print` subprocess: `isolation_level:` translates to a `--permission-mode`; the claude adapter tolerates any stray codex-native `--sandbox`/`--approval` CLI flag as a no-op. |
| Write/Bash mechanism | codex CLI drives edits and command execution. | The headless `claude --print` adapter subprocess drives edits and command execution via the Claude CLI (`runner_kind: cli-subprocess`); claude self-governs Bash via `--permission-mode`. |
| Reviewer pipeline trigger | `/pr-gate` dispatches the codex reviewer session via `pmctl dispatch run` and integrity-checks the result in-process. | `/pr-gate --executor claude` dispatches an **independent headless `claude --print` subprocess** (`adapters/claude/dispatch.sh`), symmetric with codex, and integrity-checks the result via `gate_result_verify` / `pmctl gate verify`. The former `pr-gate-handover_v1` in-session fan-out was retired. |
| Install requirement | `codex` install profile (current operational mode). | `claude` install profile (lightweight; no codex binary workflow dependency). |
| Suitable scope | Repo edits that are already in codex dispatch envelope. | Any dispatch where a headless `claude --print` subprocess is the executor (host-independent; codex-as-PM can drive it). |
| Status | Implemented (primary route). | Implemented — `adapters/claude/` + `executor: claude` enum + `install.sh --profile minimal\|full`. |

`opencode` is a third shipped profile, not shown as a column above for brevity: `pmctl dispatch run --adapter opencode --brief-file <path>` invokes `adapters/opencode/dispatch.sh` (headless CLI subprocess, `runner_kind: cli-subprocess`, `write_guard_mode: cli-only`). It is the only adapter that accepts `isolation_level: none` (full machine access — opencode has no finer-grained sandbox); codex and claude reject that value. Model resolution uses `share/opencode-model-aliases.tsv` with a fallback chain across free-tier models.

## Guard enforcement

Guard policy (what a role may write or run) is **executor-agnostic and lives in one place**: the guard hook scripts (`guard-pm-write.sh`, `guard-executor-write.sh`, `guard-reviewer-write.sh`), surfaced as a CLI via `pmctl guard check --event <pre-write|pre-bash|post-task> --role <pm|executor|reviewer> [--runtime <codex|claude>] --file/--command <val>`. Guard keys on the **role** (runtime-agnostic for `pm`; the `--runtime` axis refines policy only where a role differs by runtime); dispatch supplies the runtime via its `--adapter`. The `pre-bash` event currently registers no policy for any role/runtime (the codex-executor subagent that needed one was retired), so every `pre-bash` check fail-closes; it remains in the CLI as defensive infrastructure. For `executor`, ONE unified `guard-executor-write.sh` covers every runtime: it derives the runtime from `agent_type` (`<runtime>-executor`) and reads that runtime's `write_guard_mode` from its adapter manifest. The role-level write policy is one shared rule, so adding a runtime needs no guard edit. The CLI synthesizes the canonical hook input and drives the same hook, so every host enforces the identical decision (deny → non-zero exit + reason).

The **live-hook vs CLI-only** behavior is declared by the manifest's `write_guard_mode`, not inferred from which files exist:

| `write_guard_mode` | runner_kind | Wrapper behavior |
|---|---|---|
| `hook` | `cli-subprocess` default — **no shipped adapter is in this class today** | Reserved for a runtime whose executor subagent SELF-WRITES its brief via the host `Write` tool — i.e. the no-headless-CLI fallback class (see Model B contract item 5). Thin dispatcher gated by a **live PreToolUse hook** — enforced on every `Edit`/`Write`, whether fired live or via `pmctl guard check`. codex was the former occupant but overrode to `cli-only` once its brief became pmctl-landed; the branch now survives only for the fallback case and is unit-locked by `test-runner-kind.sh` (`default/cli/guardmode` → `hook`). |
| `cli-only` | `cli-subprocess` with an explicit override (all three shipped adapters — codex, claude, and opencode) | No executor subagent self-writes a brief via a live host `Write` on this path: the brief is pmctl-landed and the executor runs as an independent headless subprocess (codex, claude's `claude --print` route, and opencode's CLI — all `cli-subprocess` overriding `write_guard_mode` to `cli-only`). So a live hook must NOT gate it: the unified wrapper **no-ops when fired live** and enforces the brief-location policy only when driven by `pmctl guard check` (which sets `PM_GUARD_CHECK_CLI`). |

When the CLI drives the wrapper for a runtime with no valid adapter manifest, it **fails closed** (deny); a missing/non-executable hook file likewise fails closed at the `pmctl guard check` `-x` check.

The **trigger** is asymmetric by capability, not by policy:

| Host | Guard trigger |
|---|---|
| Claude | PreToolUse auto-hook fires before each `Edit`/`Write`/`Bash`; enforcement is automatic and cannot be skipped by the agent. |
| Non-Claude (e.g. codex-as-PM) | pm-dispatch does not yet wire native hooks for a non-Claude host, so today it MUST call `pmctl guard check` explicitly before the action and honor a non-zero exit as a deny. (Some non-Claude hosts have their own — possibly partial — hook mechanism, e.g. Codex's emerging hooks; wiring guard enforcement into each host's native interception point, rather than relying on the explicit-call fallback, is a tracked future direction.) |

This asymmetry is inherent to the host's CLI capabilities — both paths evaluate the same policy. The **`--role`** selects the policy because each role has a different allow-list (pm pre-write → memory dir only; executor pre-write → `/tmp/brief-*.md` only); the **`--runtime`** axis refines it only where a role's policy genuinely differs by runtime. (No role registers a `pre-bash` policy today — the only one that did, codex's, was retired with the codex-executor subagent.) Claude PreToolUse hooks may later shell to `pmctl guard check` to collapse to a single source, but today they remain the policy source the CLI composes.

**On the dispatch entrypoint and the low-level primitive (single policy, not split-brain):** `pmctl dispatch run` is the **sole routine** codex path and the policy surface — it runs `brief-validate` + `pmctl guard check` before invoking the adapter, and no executor subagent ever holds brief-write authority. The codex adapter (`adapters/codex/dispatch.sh`) is also directly callable as a low-level primitive; because codex's `write_guard_mode` is `cli-only` the live PreToolUse hook **no-ops** there, so the brief-location policy is enforced via `pmctl guard check`, not a live hook. The directly-callable adapter is the low-level primitive, not an unguarded bypass. A non-Claude host that calls the adapter directly (outside `pmctl dispatch run`) is responsible for calling `pmctl guard check` itself, exactly as the non-Claude row above requires.

The surface is **fail-closed**: a success exit (`0`) always means a registered policy ran and permitted the action — never that enforcement was skipped. Exit codes:

| Exit | Meaning |
|---|---|
| `0` | a registered policy ran and **allowed** the action |
| `2` | usage error (bad/missing flags) **or** a registered policy **denied** the action (the hook's own deny exit is propagated) |
| `3` | request recognized but **no policy registered** to evaluate it — `executor` + `runtime=claude` + `pre-bash` (claude headless subprocess governs its own Bash via `--permission-mode`; pm-dispatch registers no executor bash policy for claude), `executor` + any other runtime + `pre-bash` (no adapter needs one today), and the reserved-but-unimplemented `post-task` event. Distinct from `2` so a caller can tell "I cannot enforce this" apart from "this was denied". `pm/pre-bash` DOES have a registered policy (`guard-pm-bash.sh`, a curated denylist — codex-as-host runs Bash directly, unlike claude's project-pm subagent), so it now returns `0`/`2`, not `3`. |

### `pmctl guard check` vs `pmctl safe bash`

These two surfaces share the same policy engine but serve different purposes and must not be substituted for each other:

| Surface | Purpose | Executes a command? |
|---|---|---|
| `pmctl guard check` | Introspection-only policy query | No |
| `pmctl safe bash` | Atomic guard check + execution | Yes |

**`pmctl guard check`** queries the policy and exits. It does not run any command. Legitimate uses:
- PR gate pre-write verification (`pmctl guard check --role reviewer --runtime claude --event pre-write`)
- Pre-flight sanity checks before setting up a multi-step workflow
- Debugging: testing what the policy would decide without side effects

**`pmctl safe bash`** is the enforcement path for any bash execution under policy. It calls the guard internally, and only runs the command if the guard permits. Guard check and exec are atomic — there is no window between them.

```
usage: pmctl safe bash --role <ROLE> --runtime <RUNTIME> [--] <COMMAND>
```

**Anti-pattern — never use `guard check` as a gate for manual exec:**

```bash
# WRONG: not atomic — policy could be bypassed between check and exec
pmctl guard check --role executor --runtime codex --event pre-bash --command "$cmd" && bash -c "$cmd"
```

Use `pmctl safe bash` instead:

```bash
# CORRECT: guard and exec are one atomic operation
pmctl safe bash --role executor --runtime codex "$cmd"
```

The bypass risk: a caller that uses `guard check` alone and then manually executes the command is not enforced — the policy check is advisory, not a barrier. `pmctl safe bash` is the only surface that atomically checks and runs. On the deny path it propagates the guard's own exit status unchanged so callers can tell a refusal apart from a fail-closed enforcement gap:

| Exit | Meaning |
|---|---|
| `0` | Allowed and executed — the command's own exit status is returned |
| `2` | Guard denied the command (policy blocked it), or a usage error — command not run |
| `3` | No policy registered for this role/runtime/event — fail-closed deny, command not run |

## Selection

Executor profile is an install-time choice (`codex` full profile versus `claude` minimal profile). PM continues writing briefs against the abstract contract, and the runtime profile determines execution behavior. Per-brief override via `executor: ...` is part of the handover metadata contract.

## Async dispatch behavior

When the main thread dispatches a subagent via the `Agent` tool, the Claude Code harness decides — independently of `run_in_background` — whether to run the agent **synchronously** (blocks until done) or **asynchronously** (returns immediately with `Async agent launched successfully`). The harness currently promotes to async when the estimated wall-clock exceeds ~2–3 minutes.

**Observable difference:**
- **Sync**: the `Agent` call blocks; the main thread cannot send new commands while it runs; result is returned inline.
- **Async**: the `Agent` call returns `Async agent launched successfully` immediately; main thread receives a completion notification when done.

**Rules for callers:**

| Scenario | Rule |
|---|---|
| Single dispatch — primary (Bash/pmctl) | Both `pmctl gate run` and `pmctl dispatch run --adapter <profile> --brief-file <path>` default to `--lifecycle detached`: the call returns a bare `gate_id`/`run_id` immediately (inline, NOT `run_in_background`), then a separate `pmctl gate wait <gate_id> --cd <work_dir>` / `pmctl dispatch wait <run_id> --cd <work_dir>` call — with `run_in_background: true` on THAT call — resolves the terminal result. Pass `--lifecycle foreground` on the run call instead if you want the old single-call synchronous behavior (with `run_in_background: true` on that call directly); do not mix the two shapes (foreground run + a wait call, or detached run without a matching wait, both leave the dispatch unresolved). A plain Bash process is not subject to Agent async-escalation surprises. The detached run+wait shape is the preferred path (see `commands/pr-gate.md` for the worked gate example). |
| Single dispatch — Agent fallback | If the primary Bash/pmctl path is unavailable, use an `Agent` call and omit `run_in_background`. The harness decides sync vs async; either path completes correctly. Do not mix Agent fallback with the Bash path in the same dispatch. |
| Parallel fan-out dispatches (e.g. pr-gate reviewers) | Set `run_in_background: true` explicitly on every `Agent` call. Without it the harness may promote one subagent to async while another blocks, making the completion order non-deterministic. |

**Diagnosis:** If you see `Async agent launched successfully` when you expected blocking, the harness promoted the dispatch. Wait for the completion notification — the subagent is still running. If the notification never arrives, check whether the agent exited early or a background Bash job inside it was orphaned.

## Forward-compat notes

`scripts/lib/handover-validate.sh` accepts `executor: codex`, `executor: claude`, and `executor: opencode`; any other value is rejected. The `claude` adapter is `adapters/claude/dispatch.sh` (headless subprocess); the `opencode` adapter is `adapters/opencode/dispatch.sh` (headless subprocess, `isolation_level: none` only). This document remains the upstream behavioral contract; future executors (e.g. other CLIs) should match the same input/output shape and add their entry to the executor enum + executor profiles table.
