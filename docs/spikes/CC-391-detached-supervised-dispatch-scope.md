# CC-391: Detached-supervised dispatch - executor lifecycle ownership axis (scope)

**Type**: design spike (decision-only; no implementation in this ticket)  
**Author**: project-pm (main thread)  
**Status**: open - pending decision  
**Relates**: CC-333 (runtime decoupling), CC-385 (Model B decision), CC-386/CC-389 (post-verify triple check), CC-211 (run FSM/events substrate), CC-225 (durable run-state/result record), CC-238 (background fan-out hardening), CC-273 (lifecycle hook events, separate axis), CC-376/CC-377 (real adapter sequencing)

## Problem / why now

CC-385 chose Model B: trusted code lands the brief, then the executor consumes it as a subprocess. The current implementation matches that shape only up to process launch. `pmctl_dispatch_run` is still the foreground lifecycle owner: it validates the adapter and brief, runs the guard, writes run transitions, invokes the adapter, parses the adapter footer, runs post-verify, and returns the final exit code from one blocking shell function (`scripts/lib/pmctl-dispatch.sh:422`, `scripts/lib/pmctl-dispatch.sh:600`, `scripts/lib/pmctl-dispatch.sh:631`, `scripts/lib/pmctl-dispatch.sh:697`, `scripts/lib/pmctl-dispatch.sh:702`, `scripts/lib/pmctl-dispatch.sh:709`).

The blocking point is the adapter pipeline in `pmctl_dispatch_run`: `{ bash "$adapter_path" "${forward[@]}" | tee "$_footer_tmp"; ... }` does not return until the adapter exits (`scripts/lib/pmctl-dispatch.sh:631`, `scripts/lib/pmctl-dispatch.sh:640`, `scripts/lib/pmctl-dispatch.sh:643`). Main-thread `run_in_background: true` around that Bash command keeps the host UI responsive, but it does not create an independently supervised run. The documented primary route is still a main-thread Bash call with `run_in_background: true` (`docs/executor-contract.md:208`, `docs/dispatch-brief.md:498`, `docs/dispatch-brief.md:564`), and the foreground `pmctl` process still owns the adapter child, footer capture, post-verify, and state writes.

So the missing axis is not "how do we reach the executor?" CC-372 already models that with `runner_kind`. The missing axis is "who owns the executor after launch, how is the result made durable, and how can a later main thread reattach?" The backlog names that split directly: `runner_kind` is how to call the executor; lifecycle is who holds/waits/finishes after launch (`BACKLOG.md:228`, `BACKLOG.md:232`, `BACKLOG.md:237`).

## The axis

| Axis | Existing code / current value | Proposed value | Verdict |
|---|---|---|---|
| `runner_kind` | Adapter property. Valid values are `cli-subprocess` and `host-native` (`scripts/lib/runner-kind.sh:21`, `scripts/lib/runner-kind.sh:34`). It derives `dispatch_route`, `write_guard_mode`, and `needs_bash_guard`, not lifecycle (`scripts/lib/runner-kind.sh:56`, `scripts/lib/runner-kind.sh:63`, `scripts/lib/runner-kind.sh:69`). | Keep as adapter topology: how pm-dispatch reaches the executor. | Do not add lifecycle here. |
| `lifecycle` | Implicit foreground-sync in `pmctl_dispatch_run`; caller may background the host Bash task, but `pmctl` still owns the adapter and verification (`scripts/lib/pmctl-dispatch.sh:631`, `scripts/lib/pmctl-dispatch.sh:702`). | Dispatch-time choice: `foreground` or `detached-supervised`, defaulting to `foreground` until proven. | Orthogonal in concept, but eligibility must be derived carefully. |
| `notify` | Host completion notification is incidental to background Bash / Agent behavior (`docs/executor-contract.md:200`, `docs/executor-contract.md:202`, `docs/dispatch-brief.md:564`). No durable inbox exists. | Durable outbox/inbox is load-bearing; fifo/socket notification is best-effort only. | Reasonable for Bash/Linux/WSL2. Do not make fifo/socket the source of truth. |
| `verify` | `pmctl_dispatch_run` parses adapter stdout footer and passes explicit `--last`, `--jsonl`, `--stderr`, and `--terminal-event` to `dispatch-post-verify.sh` (`scripts/lib/pmctl-dispatch.sh:651`, `scripts/lib/pmctl-dispatch.sh:697`). | Supervisor calls the same verifier with the same arguments after the executor exits. | Reuse, but persist the footer before verify. |

**Verdict on orthogonality:** lifecycle is genuinely orthogonal to `runner_kind` as a design axis, because the runner-kind table does not encode ownership-after-launch. However, the proposed derivation "all headless-CLI Model B executors are detachable; host-native is not" is not yet sound against the current manifests. `codex` is cleanly `runner_kind: cli-subprocess` and explicitly Model B (`adapters/codex/adapter.yaml:12`, `adapters/codex/adapter.yaml:20`). `claude` is contradictory: `adapters/claude/adapter.yaml` declares `runner_kind: host-native` (`adapters/claude/adapter.yaml:12`, `adapters/claude/adapter.yaml:16`), while `adapters/claude/dispatch.sh` says it is a headless `claude --print` adapter driven by `pmctl dispatch run` (`adapters/claude/dispatch.sh:4`, `adapters/claude/dispatch.sh:5`, `adapters/claude/dispatch.sh:7`) and actually builds `CMD=(claude -p ...)` (`adapters/claude/dispatch.sh:229`). A detached implementation must first resolve that classification gap or derive eligibility from the effective executable primitive plus route, not from the adapter name or a stale manifest story.

## Trade-offs

| Dimension | Foreground-sync today | Detached-supervised |
|---|---|---|
| Lifecycle owner | The `pmctl dispatch run` process owns adapter execution, footer parsing, verification, and final exit (`scripts/lib/pmctl-dispatch.sh:631`, `scripts/lib/pmctl-dispatch.sh:657`, `scripts/lib/pmctl-dispatch.sh:702`). | A supervisor owns the executor child, captures footer/results, runs verifier, writes durable state, and exits. |
| User responsiveness | Main thread can background the outer Bash call, but the result is still tied to that live process and host task notification (`docs/dispatch-brief.md:564`). | Main can receive a run id immediately, leave, and later `wait`/reattach from durable state. |
| Verification | Proven: exit code + structural JSONL + terminal event (`docs/executor-contract.md:90`, `docs/executor-contract.md:91`, `docs/executor-contract.md:92`, `docs/executor-contract.md:93`). | Reused unchanged if the supervisor supplies the same footer-derived arguments. |
| Crash recovery | Weak between adapter exit and state/verify completion; `_footer_tmp` is deleted after parse and is not durable (`scripts/lib/pmctl-dispatch.sh:640`, `scripts/lib/pmctl-dispatch.sh:657`). | Strong only if footer/result handoff and final state are written before volatile cleanup. |
| State writes | Existing run/event appends are locked per file (`scripts/lib/state-writer.sh:495`, `scripts/lib/state-writer.sh:515`), but a transition is two appends (`scripts/lib/pmctl-dispatch.sh:205`, `scripts/lib/pmctl-dispatch.sh:207`). | Works with concurrent supervisors, but recovery must tolerate run/event skew. |
| Security | One `pmctl` process runs route, brief validation, guard, and adapter path containment before invocation (`scripts/lib/pmctl-dispatch.sh:546`, `scripts/lib/pmctl-dispatch.sh:559`, `scripts/lib/pmctl-dispatch.sh:600`, `scripts/lib/pmctl-dispatch.sh:520`). | Must preserve the same preflight before detaching; supervisor cannot become a bypass around guard or adapter containment. |

## Design wrinkles to resolve in the spike

- **D1 - lifecycle as dispatch flag, not manifest field.** Recommended: keep lifecycle off adapter manifests. The current runner-kind resolver validates only three derived flags (`dispatch_route`, `write_guard_mode`, `needs_bash_guard`) and allows explicit overrides only for those domains (`scripts/lib/runner-kind.sh:82`, `scripts/lib/runner-kind.sh:99`, `scripts/lib/runner-kind.sh:101`, `scripts/lib/runner-kind.sh:110`, `scripts/lib/runner-kind.sh:119`). Lifecycle is a caller choice: the same eligible executor should support foreground for interactive observation and detached for fire-and-reattach. The caveat is eligibility: require both a valid routable adapter (`scripts/lib/executor-router.sh:97`, `scripts/lib/executor-router.sh:104`) and a proven subprocess dispatch primitive. Current `claude` manifest/adapter disagreement makes a blind `runner_kind == cli-subprocess` rule too brittle.

- **D2 - supervisor component boundary.** Recommended: introduce a thin `pmctl dispatch start`/supervisor boundary rather than overloading `pmctl_dispatch_run` with `&`. The supervisor should own exactly the existing post-preflight tail: invoke adapter, capture stdout footer, persist the footer, write `verifying`, run post-verify, write terminal state, and notify. The current foreground code already has that boundary after guard and config export (`scripts/lib/pmctl-dispatch.sh:600`, `scripts/lib/pmctl-dispatch.sh:613`, `scripts/lib/pmctl-dispatch.sh:631`). Do not detach before route, adapter containment, brief validation, and guard have all passed.

- **D3 - durable run-state schema/location.** Recommended: use `run_id` as the durable identity and treat PID as advisory only. `pmctl_dispatch_run` already creates a run id before execution (`scripts/lib/pmctl-dispatch.sh:575`, `scripts/lib/pmctl-dispatch.sh:578`) and `sw_build_run_json` stores it as `id` (`scripts/lib/state-writer.sh:563`, `scripts/lib/state-writer.sh:581`). The current run schema has no supervisor PID, process start time, footer path, verifier verdict, or outbox path (`core/schema/run.schema.json:5`, `core/schema/run.schema.json:47`, `core/schema/run.schema.json:51`). Also, the state store lives under `$PM_DISPATCH_STATE_ROOT`, `$XDG_DATA_HOME`, or `~/.local/share/pm-dispatch/state` (`scripts/lib/state-writer.sh:32`, `scripts/lib/state-writer.sh:36`, `scripts/lib/state-writer.sh:39`), while CC-225 asks for a repo-tracked durable result record aligned with `.gate-results/` (`BACKLOG.md:263`, `MILESTONES.md:78`). Partial adoption should therefore define a repo-local durable result/outbox artifact and mirror summaries into the existing state store, rather than pretending the current `runs.jsonl` alone is the outbox.

- **D4 - verify reuse.** Recommended: reuse `dispatch-post-verify.sh` unchanged, but make the supervisor persist the adapter footer before invoking it. Post-verify already accepts `--last`, `--jsonl`, `--stderr`, `--brief-file`, and `--terminal-event` (`scripts/dispatch-post-verify.sh:9`, `scripts/dispatch-post-verify.sh:39`, `scripts/dispatch-post-verify.sh:41`, `scripts/dispatch-post-verify.sh:46`). It validates explicit paths stay inside `.agent-trace` (`scripts/dispatch-post-verify.sh:104`, `scripts/dispatch-post-verify.sh:114`, `scripts/dispatch-post-verify.sh:131`) and fails closed on missing explicit JSONL/stderr (`scripts/dispatch-post-verify.sh:176`, `scripts/dispatch-post-verify.sh:208`). Nothing in the verifier requires an in-process foreground caller. The blocker is the current caller's temp footer: `_footer_tmp` is a `mktemp` file deleted immediately after parsing (`scripts/lib/pmctl-dispatch.sh:640`, `scripts/lib/pmctl-dispatch.sh:657`), so a supervisor crash after adapter exit but before durable footer persistence can lose the race-free handoff that CC-305 depends on.

- **D5 - notify channel.** Recommended: durable outbox first, live notification second. The existing trace tailer reads active and archived `events.jsonl` and skips malformed rows rather than treating the active file as a synchronous message bus (`scripts/lib/pmctl-trace.sh:199`, `scripts/lib/pmctl-trace.sh:203`, `scripts/lib/pmctl-trace.sh:245`). That is a good query substrate, not a reliable wakeup channel. A fifo/socket can reduce latency for a live main thread, but `pmctl dispatch wait <run_id>` must resolve from durable run/outbox records even if no listener existed when the supervisor finished.

- **D6 - true detachment.** Recommended: use `setsid` when available, plus `nohup`/stdio redirection and a supervisor log path; record `supervisor_pid`, process start time, and run id in the durable record. Current `run_in_background: true` is a host-tool option, not a process-supervision contract (`docs/executor-contract.md:198`, `docs/executor-contract.md:208`). The codex guard documents the failure mode for backgrounding inside a subagent: the background job can be orphaned/killed when the agent exits (`scripts/hook-codex-bash-guard.sh:283`, `scripts/hook-codex-bash-guard.sh:299`). Detached dispatch must not rely on that host behavior. PID reuse means `wait <id>` must never identify a run by PID alone; use `run_id` plus recorded supervisor metadata and terminal durable state.

- **D7 - foreground-to-detached migration order.** Recommended ordering:
  1. Extract the post-preflight executor tail into a shared internal function, preserving current foreground behavior and tests.
  2. Add durable footer/result/outbox writes in foreground mode and verify they do not change guard or adapter invocation.
  3. Add supervisor entrypoint that can run the same tail in foreground test mode.
  4. Add `--lifecycle foreground|detached` parsing with default `foreground`; reject `detached` for ineligible adapters before launch.
  5. Only then wire `setsid`/`nohup` and `dispatch wait`.

  This keeps the hard gates in front of every executor invocation. `pmctl dispatch run` already refuses inline briefs because they bypass validation/guard (`scripts/lib/pmctl-dispatch.sh:479`, `scripts/lib/pmctl-dispatch.sh:483`), rejects adapter path traversal and symlink escapes (`scripts/lib/pmctl-dispatch.sh:498`, `scripts/lib/pmctl-dispatch.sh:525`, `scripts/lib/pmctl-dispatch.sh:538`), fails closed if the routing registry is missing (`scripts/lib/pmctl-dispatch.sh:546`, `scripts/lib/pmctl-dispatch.sh:548`), and refuses dispatch if guard is unavailable or denies (`scripts/lib/pmctl-dispatch.sh:600`, `scripts/lib/pmctl-dispatch.sh:604`, `scripts/lib/pmctl-dispatch.sh:608`). The detached implementation must not introduce a code path around those checks.

## Risk table

| Risk | Likelihood | Blast radius | Mitigation |
|---|---:|---:|---|
| `run_in_background` mistaken for true detach. The foreground Bash task can keep the UI responsive, but `pmctl_dispatch_run` still owns the adapter pipeline (`scripts/lib/pmctl-dispatch.sh:631`, `docs/dispatch-brief.md:564`). | High | Medium | Add a separate supervisor launched with `setsid`/`nohup` and redirected stdio. Treat host background notification as UI sugar only. |
| Orphaned/killed child from backgrounding under an agent. This is already a hard-denied codex-executor failure mode (`scripts/hook-codex-bash-guard.sh:283`, `scripts/hook-codex-bash-guard.sh:299`). | Medium | High | Never implement detached by adding inner `&`. Supervisor must be the parent until executor exit, then reap and write terminal state. |
| Zombie or unreaped executor if supervisor mishandles child exit. | Medium | Medium | Supervisor should `wait` its direct child, trap termination, and write a non-ok terminal state when it terminates the child. Acceptance must include no leftover child for one real run. |
| PID reuse on reattach. Current durable run identity is `run-...`, not PID (`scripts/lib/pmctl-dispatch.sh:578`, `core/schema/run.schema.json:7`). | High | Medium | `dispatch wait <run_id>` resolves by run id and durable state. PID checks are only advisory and must include recorded start time when available. |
| Supervisor dies after executor finishes but before durable footer/result write. Current footer temp file is deleted after parse (`scripts/lib/pmctl-dispatch.sh:640`, `scripts/lib/pmctl-dispatch.sh:657`). | Medium | High | Persist raw adapter stdout/footer under the run directory before parsing. Recovery scans per-run trace/footer paths and marks `needs-reconcile` or `failed` if verifier cannot be completed. |
| Supervisor dies while executor is still running, leaving an orphan executor. | Medium | High | Prefer supervisor-as-parent with traps. Recovery uses durable state plus process metadata to distinguish live, orphaned, and silent-dead runs; if uncertain, mark `unknown`/`failed` rather than ok. |
| State-store contention from multiple supervisors and main thread. `runs_append` and `events_append` use `serialize_with_lock` (`scripts/lib/state-writer.sh:495`, `scripts/lib/state-writer.sh:515`), backed by `flock` or mkdir locks (`scripts/lib/portable.sh:182`, `scripts/lib/portable.sh:192`, `scripts/lib/portable.sh:201`). | Medium | Medium | Reuse state-writer for JSONL appends. Keep rows compact and append-only. Add tests with concurrent supervisors. |
| Non-transactional run/event pair. A transition writes `runs.jsonl` then `events.jsonl` separately (`scripts/lib/pmctl-dispatch.sh:205`, `scripts/lib/pmctl-dispatch.sh:207`). | Medium | Medium | Readers must tolerate skew via `operation_id`; recovery should prefer terminal durable result/outbox, then reconcile run/event telemetry. |
| Guard weakened during migration. Existing `pmctl dispatch run` has route, brief validation, and guard before adapter execution (`scripts/lib/pmctl-dispatch.sh:546`, `scripts/lib/pmctl-dispatch.sh:559`, `scripts/lib/pmctl-dispatch.sh:600`). | Medium | High | Detach only after those checks pass. Do not expose a supervisor CLI that accepts raw adapter paths or unvalidated briefs. |
| Adapter path/security boundary bypass. Current code rejects non-bare adapter names, symlinked dispatch scripts, and adapter dirs outside `adapters/` (`scripts/lib/pmctl-dispatch.sh:498`, `scripts/lib/pmctl-dispatch.sh:525`, `scripts/lib/pmctl-dispatch.sh:538`). | Low | High | Supervisor receives a run spec produced by pmctl after containment checks, not user-supplied paths. |
| Credential/env leakage from a detached process outliving the session. Model B assumes pre-authenticated CLIs and env/file credentials (`docs/executor-contract.md:86`, `docs/executor-contract.md:87`); current pmctl exports config env to adapters (`scripts/lib/pmctl-dispatch.sh:613`, `scripts/lib/pmctl-dispatch.sh:621`). | Medium | High | Define an env allowlist for supervisor launch. Do not log secrets. Document that auth is inherited and long-lived by design, or require explicit opt-in for detached runs. |
| Detached verifier writes outside work dir through malicious footer paths. | Low | High | Reuse post-verify explicit path containment: `--last`, `--jsonl`, and `--stderr` are resolved under `.agent-trace` (`scripts/dispatch-post-verify.sh:104`, `scripts/dispatch-post-verify.sh:114`, `scripts/dispatch-post-verify.sh:131`). |
| CC-305 race reintroduced by losing explicit footer handoff. The contract says per-run footer paths prevent `latest.*` races (`docs/executor-contract.md:61`, `docs/executor-contract.md:74`), and pmctl currently passes those explicit paths (`scripts/lib/pmctl-dispatch.sh:697`, `scripts/lib/pmctl-dispatch.sh:699`). | Medium | High | Supervisor must persist footer-derived paths per run and never post-verify from `latest.*` when explicit paths exist. |
| `claude` detach eligibility misderived from current manifest. Manifest says `host-native` (`adapters/claude/adapter.yaml:16`), but adapter runs headless CLI (`adapters/claude/dispatch.sh:5`, `adapters/claude/dispatch.sh:229`). | High | Medium | Resolve manifest semantics before enforcing eligibility, or compute eligibility from the actual adapter route/runner contract with a test. |
| Durable outbox not actually durable. Current state store is under user data paths (`scripts/lib/state-writer.sh:32`, `scripts/lib/state-writer.sh:39`), while CC-225 asks for repo-tracked durable result records (`MILESTONES.md:78`). | Medium | High | Add repo-local result/outbox artifact as load-bearing; mirror to state store/events for traceability. |

## Recommendation

**Partial-adopt.** Adopt lifecycle ownership as a new dispatch-time axis, and adopt a detached supervisor as the right long-term shape. Defer enabling user-facing detached dispatch until two prerequisites are handled:

1. Fix or formalize detach eligibility. The `claude` manifest/adapter mismatch means `runner_kind` alone is not currently a trustworthy eligibility predicate.
2. Add a durable per-run result/outbox artifact before true detach. The current state writer is concurrency-safe enough for append telemetry, but it is not the whole durable recovery contract for a detached supervisor.

The migration should be fail-closed:

1. Keep default `foreground`.
2. Extract the adapter execution/footer/post-verify tail with no behavior change.
3. Persist footer/result/outbox in foreground mode and validate CC-305 explicit-path behavior still holds.
4. Add supervisor in foreground test mode.
5. Add `--lifecycle detached` as opt-in and reject ineligible adapters before launch.
6. Launch supervisor via `setsid`/`nohup`, write run id immediately, then implement `dispatch wait <run_id>` from durable records.

Do not add a manifest `lifecycle_mode`. Do not make fifo/socket notification load-bearing. Do not let the supervisor accept raw brief or adapter paths that skipped the existing `pmctl dispatch run` preflight.

## Acceptance (what one real detached dispatch must prove)

- A real eligible adapter run starts with `pmctl dispatch run --lifecycle detached` or `pmctl dispatch start`, returns a `run_id` before executor completion, and the original main thread can exit.
- The supervisor survives the caller leaving, owns and reaps the executor child, and writes terminal durable state keyed by `run_id`, not PID.
- The supervisor runs the same post-verify checks as foreground dispatch: exit code, JSONL structural integrity, and declared terminal event (`docs/executor-contract.md:90`, `docs/executor-contract.md:93`).
- The verifier receives explicit per-run `--last`, `--jsonl`, and `--stderr` paths from the persisted footer, not `latest.*` symlinks.
- `pmctl dispatch wait <run_id>` reports the terminal outcome from durable state after the original shell/session is gone.
- Concurrent detached runs append valid `runs.jsonl` and `events.jsonl` rows without malformed JSONL, and any run/event skew is reconciled or reported.
- Guard behavior is unchanged: route/allowlist, brief validation, and `pmctl guard check` still happen before the supervisor can launch an executor.
- A negative test proves `detached` is rejected for a non-detachable effective topology.

## Non-goals

Not implementing the supervisor in this ticket. Not changing CC-385 Model B verification semantics. Not adding a general lifecycle hook event system (CC-273 is separate). Not solving host-PM install or native hook wiring (CC-381). Not moving all state into a new database. Not making fifo/socket notification reliable enough to be the result source of truth.

## Open questions

- What is the intended final classification for `adapters/claude`: `host-native`, `cli-subprocess`, or two distinct profiles for `claude-as-host` and headless `claude --print`?
- Where exactly should the repo-local durable result/outbox live? CC-225 says `.gate-results/`-style, but no concrete path or schema is present in the inspected files.
- Should detached supervisor launch inherit all environment variables, or should it run under an allowlist with explicit credential variables?
- What terminal state should recovery write when it finds `dispatched` with no live supervisor and no durable footer: `failed`, `unknown`, or a new reconciler-only state?
- Should `dispatch wait <run_id>` tail `events.jsonl`, poll the durable outbox, or both?
