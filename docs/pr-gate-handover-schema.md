# pr-gate-handover_v1 schema

> **DEPRECATED.** `pmctl gate run --executor claude` no longer emits this
> block. The claude executor now dispatches an independent headless `claude --print`
> subprocess (`adapters/claude/dispatch.sh`) and writes the result in-process,
> symmetric to codex — there is no handover/fan-out. `runtime/bin/pr-gate.sh` no longer
> produces a `pr-gate-handover_v1` block for any executor. This document is retained
> for historical reference only; the schema below describes the retired behavior.

This schema was used by `runtime/bin/pr-gate.sh` when the selected executor was
`claude`, before this route was retired. It is intentionally separate from `dispatch_handover_v1`.

- Envelope fence: ```pr-gate-handover_v1
- Purpose: instructed the main-thread orchestrator to fan out one or more
  in-session reviewer Agent calls.

## Schema shape

Top-level is a YAML sequence. Each list item is one handover entry.

Required keys per entry:

- `role:` one of `reviewer` or `synthesis`.
- `brief_file:` absolute path to a pre-written brief that includes all context.
- `output_file:` absolute path where that route must write its report.

Required keys by role:

- `role: reviewer`
  - `reviewer_name:` required.
- `role: synthesis`
  - `reviewer_name:` forbidden.

## Cardinality

- Sequential mode (`pr-gate.sh` no `--parallel`):
  - exactly one entry
  - `role: reviewer`
- Parallel mode (`--parallel`):
  - one `role: reviewer` entry per selected reviewer
  - exactly one trailing `role: synthesis` entry.

## Output contract (historical — retired)

The behavior below describes the retired handover route and no longer occurs;
`runtime/bin/pr-gate.sh` does not print a handover block for any executor.

- The gate script printed the handover block on stdout when running in claude mode.
- The caller parsed the block and dispatched one in-session Agent call for every
  `role: reviewer` entry, passing `brief_file` as the call prompt. The reviewer brief already
  contains an explicit `pmctl guard check --role reviewer --runtime claude
  --event pre-write` constraint — the executor calls it before
  writing, enforcing the `.gate-results/`-only rule via the same policy hook
  (`guard-reviewer-write.sh`) used by the codex route.
- The caller must then dispatch the `role: synthesis` Agent when present.
- The caller must continue writing final output to the shared `output_file` path
  that the gate script also prints as `result:`.
- After the route writes `output_file`, the caller must confirm it with
  `pmctl gate verify <output_file> --cd <reviewed-repo> --consumer embedded --json`.
  A named consumer requires `artifact_valid`, `subject_current`, and
  `policy_applicable` all to pass; the default single-argument inspection form
  preserves only the historical artifact-validity exit contract. The codex
  route runs this verification in-process after dispatch; the retired claude
  route's write happened out-of-process, so explicit verification made the
  host-native result trackable. Legacy results without immutable subject or
  consumer-applicability evidence cannot authorize continuation.

Implementation reference: `commands/pr-gate.md` and `runtime/bin/pr-gate.sh`.

## Example: sequential mode

```pr-gate-handover_v1
- role: reviewer
  reviewer_name: combined
  brief_file: /repo/.gate-briefs/pr-gate-20260517-120000.md
  output_file: /repo/.gate-results/gate-20260517-120000.md
```

## Example: parallel mode

```pr-gate-handover_v1
- role: reviewer
  reviewer_name: critic
  brief_file: /repo/.gate-briefs/pr-gate-20260517-120000-critic.md
  output_file: /repo/.gate-results/reviewer-critic-20260517-120000.md

- role: reviewer
  reviewer_name: qa-tester
  brief_file: /repo/.gate-briefs/pr-gate-20260517-120000-qa-tester.md
  output_file: /repo/.gate-results/reviewer-qa-tester-20260517-120000.md

- role: synthesis
  brief_file: /repo/.gate-briefs/pr-gate-20260517-120000-synthesis.md
  output_file: /repo/.gate-results/gate-20260517-120000.md
```

### Error cases

- Duplicate or missing fence, missing keys, or mixed-role shape violations are
  parser errors.
- Incomplete `reviewer_name` for a `role: reviewer` entry must be rejected before
  dispatch.
- Any malformed fence shape must be surfaced as claude route completion failure.
