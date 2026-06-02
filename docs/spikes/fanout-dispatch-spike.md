# Fan-out Dispatch — Architecture Spike

## Problem Definition

`pmctl dispatch run` currently models one guarded executor invocation:

```text
one brief file -> one adapter/runtime -> one executor result -> one post-verify result
```

That shape is intentional. `scripts/lib/pmctl-dispatch.sh` owns adapter name
validation, route allowlisting, brief validation, `pmctl guard check`, adapter
subprocess invocation, output-contract reading, and post-verification. The adapter
is supposed to stay thin and executor-specific.

`scripts/pr-gate.sh` has a different computational shape:

```text
one diff -> choose reviewer set -> N reviewer briefs -> N reviewer outputs
         -> validate all reviewer outputs -> one synthesis brief -> one gate result
```

In sequential mode, gate compresses that shape into one combined executor session.
That is not true fan-out; it is one prompt that asks the same session to play
multiple reviewer roles and then synthesize.

In parallel mode, gate is real fan-out/reduce:

- one independent dispatch per reviewer
- per-reviewer output files under `.gate-results/`
- fail-closed validation for missing, empty, or malformed reviewer outputs
- worktree and reviewer-artifact tamper checks
- a final synthesis dispatch after all reviewer arms succeed
- an authoritative shell-computed final verdict that synthesis must match

The gap is that this orchestration lives outside `pmctl`'s command surface.
`pr-gate.sh` constructs briefs and dispatches through executor-specific helpers;
the Claude route emits a `pr-gate-handover_v1` block for the command wrapper to
fan out main-thread Agent calls. That keeps gate working, but it means the
runtime spine does not yet expose the multi-run shape that gate already depends
on.

The architectural question is not just "can `pmctl dispatch run` run more than
one thing?" It is: where should pm-dispatch represent an orchestration that has
cardinality, role-specific guards, partial-failure policy, progress reporting,
and a reduce/synthesis step?

## Approach A — Generic `pmctl dispatch fan-out`

### Gate expression

Gate would become a caller of a generic dispatch primitive:

```bash
pmctl dispatch fan-out \
  --cd "$WORK_DIR" \
  --arm critic:codex:.gate-briefs/pr-gate-TS-critic.md:.gate-results/reviewer-critic-TS.md \
  --arm qa-tester:codex:.gate-briefs/pr-gate-TS-qa-tester.md:.gate-results/reviewer-qa-tester-TS.md \
  --fail-policy all-required \
  --reduce-brief .gate-briefs/pr-gate-TS-synthesis.md \
  --reduce-output .gate-results/gate-TS.md
```

The exact syntax could be flags, a small manifest, or stdin JSON. The important
shape is that `pmctl` owns the N reviewer dispatches and the final reduce
dispatch, while gate still owns diff collection, tier selection, reviewer list
selection, brief text, verdict validation, and gate-specific output schema.

### Pros

- Makes fan-out a first-class runtime primitive rather than a gate-only script
  idiom.
- Reuses the `pmctl dispatch run` invariant for every arm: route allowlist,
  brief validation, guard, adapter invocation, output contract, post-verify.
- Gives future non-gate workflows a reusable substrate: spike fan-out, dual-PM
  planning, multi-reviewer design review, or compare-two-adapters experiments.
- Can model executor heterogeneity naturally if each arm carries its own
  adapter/runtime.
- Can provide uniform observability: arm id, adapter, pid, status, output path,
  exit code, and reduce status.

### Cons

- A generic primitive needs a contract before the second real consumer exists.
  That risks inventing a private mini-orchestrator too early.
- The reduce step is hard to keep generic. Gate's synthesis is not just "concat
  outputs"; it has deterministic shell verdict computation, schema validation,
  tamper checks, and reviewer-specific parsing.
- Error handling is policy-dependent. Gate should fail closed if one selected
  reviewer fails, but another fan-out workflow might accept partial results.
- A CLI flag syntax for multiple arms becomes awkward quickly; a manifest pushes
  the design toward Approach C.
- It may blur the meaning of `dispatch`: today a dispatch is one executor run.
  A fan-out dispatch would be a collection of runs plus a reducer.

### Fit with CC-215

Medium. This approach respects the CC-215 direction that `pmctl` is the runtime
spine and entry points should not reimplement logic. It also keeps adapters thin
because orchestration is above adapters.

The risk is scope. CC-215 has been implemented pragmatically as small sourceable
bash libraries behind explicit subcommands. A public generic fan-out primitive is
a larger contract than the current spine has elsewhere; it starts to resemble a
workflow engine before `pmctl task`, `decision`, `trace`, and stable JSON output
exist.

## Approach B — `pmctl gate run`

### Gate expression

Gate becomes a named pmctl orchestration command:

```bash
pmctl gate run \
  --cd "$WORK_DIR" \
  --tier full \
  --reviewers critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer \
  --executor auto \
  --parallel \
  --output "$WORK_DIR/.gate-results/gate-TS.md"
```

`scripts/pr-gate.sh` can remain as a compatibility wrapper that delegates to
`pmctl gate run`, or `pmctl gate run` can initially call into a shared
`scripts/lib/pmctl-gate.sh` extracted from the current script.

Internally, parallel mode can still have a small fan-out helper, but that helper
does not need to be a public CLI surface in v0.4.0.

### Pros

- Fits the concrete problem exactly: PR gate is already a named workflow with
  tiering, reviewer role semantics, output schema, and fail-closed validation.
- Keeps gate-specific reduce logic in the right place. Shell can continue to
  compute the authoritative final verdict before synthesis writes prose.
- Allows `pmctl` to enforce the dispatch spine for each reviewer arm by calling
  `pmctl dispatch run` instead of bypassing it.
- Gives callers a stable user-facing surface without committing to a generic
  workflow DSL.
- Can preserve current behavior: sequential as the default, `--parallel` for
  independent reviewer sessions, same `.gate-briefs/` and `.gate-results/`
  artifact layout, same tier/reviewer flags.
- Provides a natural home for reviewer guard integration:
  `pmctl guard check --role reviewer --runtime <adapter> --event pre-write`.

### Cons

- Does not immediately solve other fan-out use cases. A future spike or
  dual-planning workflow would either duplicate a small amount of orchestration
  or wait for an internal helper to graduate.
- Gate remains a special command in `pmctl`, so the command surface grows by
  domain workflow rather than only generic primitives.
- If implemented as a thin wrapper around today's script without moving dispatch
  calls through `pmctl dispatch run`, it would not actually close the current
  architectural gap.
- Executor heterogeneity should probably be deferred; adding per-reviewer
  adapter selection to the first `gate run` would expand test and guard matrix
  size.

### Fit with CC-215

High. CC-215's design intent is a runtime spine that centralizes tested behavior
while delivery surfaces stay thin. `pmctl gate run` moves an existing runtime
workflow behind the spine without forcing a premature generic abstraction.

It also matches the repo's extraction style: sourceable bash libraries, explicit
subcommands in `cli/pmctl`, and thin wrappers for legacy surfaces. The gate
command can be concrete while still extracting reusable internals where they are
real: arm launch/wait/status, output validation, and progress events.

## Approach C — Pipeline/DAG primitive

### Gate expression

Gate would be declared as a small plan:

```yaml
schema_version: 1
kind: pmctl_plan
working_dir: /repo
steps:
  - id: critic
    type: dispatch
    adapter: codex
    role: reviewer
    brief_file: .gate-briefs/pr-gate-TS-critic.md
    output_file: .gate-results/reviewer-critic-TS.md
  - id: qa
    type: dispatch
    adapter: codex
    role: reviewer
    brief_file: .gate-briefs/pr-gate-TS-qa-tester.md
    output_file: .gate-results/reviewer-qa-tester-TS.md
  - id: synthesis
    type: dispatch
    adapter: codex
    role: pm
    brief_file: .gate-briefs/pr-gate-TS-synthesis.md
    output_file: .gate-results/gate-TS.md
    needs: [critic, qa]
```

The command might be:

```bash
pmctl run .gate-briefs/pr-gate-TS-plan.yaml
```

Gate would generate the plan after collecting the diff and reviewer set.

### Pros

- Most expressive. Fan-out, reduce, dependencies, future retries, mixed adapters,
  and later state integration all have a natural representation.
- Gives MCP and future `pmctl` JSON/state surfaces a machine-readable workflow
  contract.
- Avoids overloading `dispatch`; a plan is explicitly a graph of steps, not one
  executor run.
- Could eventually subsume gate, spike fan-out, dual-executor planning, and
  task lifecycle workflows.

### Cons

- Too large for the current bash-first runtime. It requires a plan schema,
  parser, validator, DAG scheduler, status model, failure semantics, and tests.
- YAML parsing is a known project constraint. The repo intentionally avoids
  adding a full YAML dependency; line-oriented YAML works for tiny manifests but
  is brittle for nested workflow graphs.
- The reduce step still needs gate-specific semantics outside the generic DAG
  engine unless the DSL grows custom validators and reducers.
- `pmctl` does not yet have the stable state/event substrate that would make a
  DAG runner pay for itself.
- This would likely delay the practical gate integration behind workflow-engine
  design.

### Fit with CC-215

Low for v0.4.0, high as a possible later direction. It aligns with the long-term
schema-first/runtime-spine architecture, but it overshoots the as-built CC-215
surface. CC-215 explicitly favored pragmatic bash extraction and deferred MCP
until `pmctl` stabilizes. A general DAG runner is closer to MCP-era substrate
work than to the next gate cleanup.

## Approach D — Multi-adapter extension

### Gate expression

This approach extends `pmctl dispatch run` so one invocation can carry multiple
briefs/adapters, for example:

```bash
pmctl dispatch run \
  --cd "$WORK_DIR" \
  --adapter codex --brief-file .gate-briefs/pr-gate-TS-critic.md --output .gate-results/reviewer-critic-TS.md \
  --adapter codex --brief-file .gate-briefs/pr-gate-TS-qa-tester.md --output .gate-results/reviewer-qa-tester-TS.md \
  --reduce-brief .gate-briefs/pr-gate-TS-synthesis.md \
  --reduce-output .gate-results/gate-TS.md
```

Another variant would keep one primary brief but allow `--adapter codex,claude`
or `--adapter critic=codex,qa=claude`.

### Pros

- Reuses the command users already know.
- The implementation can start by looping over today's single-run function.
- Natural if the desired feature is "try the same brief on multiple adapters"
  rather than "orchestrate a gate."
- Per-arm adapter heterogeneity can be represented without inventing a new top
  level command.

### Cons

- It breaks the strongest current invariant: `dispatch run` is one brief, one
  adapter, one result, one post-verify decision.
- The flag grammar becomes ambiguous. Repeated `--adapter` and `--brief-file`
  groups are hard to validate and hard to explain in shell.
- Gate needs reviewer roles, output files, verdict parsing, and synthesis. Adding
  those to `dispatch run` would make dispatch know too much about gate.
- Partial failure semantics do not belong in a single-dispatch command. A caller
  seeing `pmctl dispatch run` exit 1 should not need to ask which of N arms failed.
- This risks putting orchestration into the same layer that is deliberately
  focused on guarded executor invocation.

### Fit with CC-215

Low. It appears incremental, but it weakens the adapter-thin/runtime-spine split.
The current `pmctl dispatch run` implementation is valuable because it has a
small, auditable policy invariant: every executor call that reaches an adapter is
validated and guarded. Multi-adapter dispatch would either complicate that
invariant or turn `dispatch run` into a hidden orchestration surface.

## Comparison Matrix

| Approach | Gate fit | Reuse beyond gate | Synthesis location | Partial failure handling | Heterogeneous adapters | Observability | CC-215 fit | v0.4.0 complexity |
|---|---|---:|---|---|---|---|---|---|
| A. `dispatch fan-out` | Good, but needs gate-specific reducer around it | High | Split between generic runner and gate | Configurable, must be designed | Strong | Strong if events/status are defined | Medium | Medium-high |
| B. `gate run` | Excellent | Medium via internal helpers | Gate command owns reducer and validation | Gate-specific fail-closed semantics | Defer or limited v1 | Good, tailored to gate | High | Medium |
| C. `run plan.yaml` | Good once plan generator exists | Very high | DAG plus custom gate reducer | Powerful but schema-heavy | Strong | Best long-term | Low now, high later | High |
| D. Extend `dispatch run` | Superficial | Low-medium | Awkward inside dispatch | Awkward, muddies exit code | Medium | Confusing unless run model changes | Low | Medium |

## Recommendation

Recommend **Approach B: add `pmctl gate run` as the v0.4.0 public surface**.

The reason is scope discipline. Gate is the only fully-real fan-out/reduce
workflow in the repo today, and it already has domain-specific behavior that a
generic primitive would not naturally own: tier selection, reviewer dimensions,
reviewer output parsing, shell-computed verdicts, tamper checks, `.gate-results/`
schema, and GO/NO-GO synthesis rules.

At the same time, the implementation should avoid baking everything into one
large script again. The right v0.4.0 shape is:

1. Add `pmctl gate run` and a sourceable `scripts/lib/pmctl-gate.sh`.
2. Preserve the existing user-facing gate flags: `--cd`, `--tier`,
   `--reviewers`/`--targeted`, `--scope`, `--base`, `--output`, `--executor`,
   `--isolation`, `--timeout`, `--parallel`, `--sequential`, `--allow-hooks`,
   `--allow-dirty`.
3. Keep sequential mode behavior-compatible as the default.
4. In parallel mode, have every reviewer and synthesis arm invoke
   `pmctl dispatch run --adapter <runtime> --cd <dir> --brief-file <file>`
   rather than calling adapter scripts directly.
5. Keep the reducer gate-specific:
   - all selected reviewers are required
   - missing, empty, or malformed reviewer output fails the gate
   - shell computes the authoritative final GO/NO-GO before synthesis
   - synthesis output must match the shell verdict
6. Keep reviewer guard semantics explicit:
   - reviewer briefs continue to require `pmctl guard check --role reviewer
     --runtime <runtime> --event pre-write --file <output>`
   - the orchestrator should also reject gate output paths that make that guard
     impossible unless an explicit operator escape hatch is retained and
     documented
7. Emit progress in a stable human-readable form first:
   - selected tier and reviewers
   - one line per arm launch
   - one line per arm completion/failure
   - final result path
   A later `--json` or events stream should wait for the broader pmctl state
   substrate.
8. Leave public `pmctl dispatch fan-out` and `pmctl run plan.yaml` deferred.
   If `gate run` and a second workflow end up needing the same launch/wait logic,
   promote the internal helper into a public primitive then.

Minimal v0.4.0 scope should not include:

- a general plan/DAG schema
- per-reviewer adapter selection
- retry policy
- generic reducer plugins
- MCP-facing workflow introspection
- a new artifact store beyond the current `.gate-briefs/`, `.gate-results/`,
  and `.agent-trace/` layout

This gives pmctl ownership of gate as a runtime workflow without prematurely
turning pmctl into a workflow engine.

## Open Design Questions

1. Should `scripts/pr-gate.sh` remain the canonical implementation and delegate
   into `pmctl gate run`, or should it become a compatibility wrapper after the
   gate library is extracted?
2. Should `pmctl gate run --parallel` abort on the first failed reviewer, or wait
   for all already-launched reviewers and then report all failures? Current code
   launches all reviewers and reports the failed set after waiting.
3. Should a failed reviewer produce a partial gate artifact with `final: NO-GO`,
   or should the command fail without writing the final gate result? Current code
   aborts rather than certifying an incomplete review.
4. Should reviewer guard enforcement stay prompt-mediated, or should the
   orchestrator preflight every reviewer output path with
   `pmctl guard check --role reviewer` before dispatch as well?
   **Decision (2026-06-02)**: No pmctl guard check preflight needed. The orchestrator
   should do a lightweight bash structural check on the output path
   (`basename(dirname(output)) == ".gate-results"`) before dispatch. This achieves
   fail-fast without the complexity of a full guard check roundtrip. The runtime check
   in the reviewer brief remains the canonical enforcement point.
5. How should `--output` outside `.gate-results/` behave once reviewer guard is
   runtime-enforced? Is it a documented operator escape hatch, or should
   `pmctl gate run` require outputs under `.gate-results/`?
6. Is the Claude `pr-gate-handover_v1` route still needed once `pmctl gate run`
   exists, or should the command wrapper call `pmctl gate run` and stop owning
   fan-out parsing?
7. Should `pmctl gate run` expose any machine-readable progress in v0.4.0, or
   wait for a broader `pmctl --json` / event-log convention?
8. When, if ever, should per-arm adapter heterogeneity be allowed? The first
   version should probably keep one selected runtime for the whole gate.
9. Should the internal fan-out helper record each arm as a `Run` in the existing
   state writer, or should gate wait until the CC-211 state model questions are
   settled?
10. What is the compatibility window for existing `/pr-gate` behavior and
    `scripts/pr-gate.sh` direct callers?
