# pr-gate-handover_v1 schema

This schema is only used by `scripts/pr-gate.sh` when the selected executor is
`claude`. It is intentionally separate from `dispatch_handover_v1`.

- Envelope fence: ```pr-gate-handover_v1
- Purpose: instruct the main-thread orchestrator to fan out one or more
  `Agent(subagent_type: "claude-executor")` calls.

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

## Output contract

- The gate script always prints the handover block on stdout when running in
  claude mode.
- The caller must parse the block and dispatch one
  `Agent(subagent_type: "claude-executor")` call for every `role: reviewer`
  entry, passing `brief_file` as the call prompt. The reviewer brief already
  contains an explicit `pmctl guard check --role reviewer --runtime claude
  --event pre-write` constraint (CC-297) — the executor calls it before
  writing, enforcing the `.gate-results/`-only rule via the same policy hook
  (`hook-reviewer-write-guard.sh`) used by the codex route.
- The caller must then dispatch the `role: synthesis` Agent when present.
- The caller must continue writing final output to the shared `output_file` path
  that the gate script also prints as `result:`.
- After the route writes `output_file`, the caller must confirm it with
  `pmctl gate verify <output_file>` (exit 0 = structurally valid result). The
  codex route runs this same contract in-process after its dispatch; the claude
  route's write happens out-of-process, so this explicit verify is what makes
  the host-native result trackable and is the gate's authority on whether a
  result was actually produced. The gate script prints the exact command to run.

Implementation reference: `commands/pr-gate.md` and `scripts/pr-gate.sh`.

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
