---
description: Run a spike investigation — plan angles, fan out one agent per angle, synthesize a committed docs/spikes/<id>.md decision file.
argument-hint: "<ticket-id> [--executor claude|codex] [--model <alias>] [--test-target <path>]"
---

Run a structured spike: turn a `spike`-epic ticket into a committed, reviewable
**decision** in `docs/spikes/<ticket-id>.md`. A spike reduces uncertainty *before*
an implementation spec can be written — its product is a recommendation
(adopt / defer / reject), not code.

This skill is the **main-thread orchestrator** for the `spike` agent. The agent is a
planner; the main thread fans out one agent per angle (subagents cannot spawn
subagents — same shape as `/pr-gate`'s reviewer fan-out), then re-invokes the agent
to synthesize.

## When to use

Use `/spike` when a candidate is selected but a normal implementation brief would be
irresponsible because a **durable** feasibility / API / architecture decision must be
made first:

- The ticket carries the `spike` epic.
- You cannot write a confident dispatch brief without resolving an implementation-blocking
  unknown (API shape, schema boundary, adapter feasibility, migration strategy,
  tool-adoption verdict, cross-layer ownership).
- The answer must survive across sessions and be reviewable.

Not for: "what should we do next?" (use `/discover`), "how do others solve this?"
(use `/research`), explaining existing code (ordinary analysis), or planning an
already-understood ticket (write the brief directly).

## Step 1 — Resolve the ticket and validate

Read the named ticket from `BACKLOG.md` (section-target with `grep -n` / `sed -n` —
do not full-file Read). Confirm:

- The ticket exists and carries the `spike` epic. If not, stop and report — a spike
  needs a scoped ticket with `Investigation scope` and `Done-when` inside `Requirement`.
- A `Result log` line exists (or note that synthesis will add one).

If the ticket is missing the spike structure, offer to add the `Investigation scope`
/ `Done-when` / `Result log` parts to `Requirement` before proceeding.

## Step 2 — Plan pass

Invoke the `spike` agent (Agent tool, `subagent_type: spike`) with the ticket id, the
resolved `working_dir`, and any `--test-target`. The agent returns a `spike_plan_v1`
block: 2–3 diverging angles, each with an executor + model + a short brief.

Relay the plan to the user for a quick confirmation when the angle count, executor
choice, or model would be costly; otherwise proceed.

## Step 3 — Fan out one agent per angle

For each `angles[]` entry, the **main thread** runs the investigation — these run
concurrently (one message, multiple tool calls):

- `executor: claude` → Agent tool with an appropriate subagent (`general-purpose`),
  passing the angle `brief` and `question`. Override model per the angle.
- `executor: Explore` → Agent tool `subagent_type: Explore` for read-only code/prior-art
  search angles.
- `executor: codex` → write a brief to `/tmp/brief-spike-<ticket-id>-<angle>.md` and
  dispatch the codex adapter (`pmctl dispatch run --adapter codex --lifecycle foreground
  --cd <working_dir> --brief-file <path>`) with `run_in_background: true`, then parse the
  footer for completion (same synchronous-orchestration contract as `commands/pm.md`). Use
  this when sandbox isolation or a heavy build/index is needed. **`--lifecycle foreground` is
  required**: the dispatch default is `detached`, which returns only a `run_id` and never
  hands back the angle findings — a detached angle must instead be resolved with
  `pmctl dispatch wait <run_id> --cd <working_dir>` before synthesis. Either way, do not
  proceed to synthesis until every angle's output is collected.

Collect each angle's findings. If an angle fails or returns nothing usable, record that
and continue — a partial spike with a stated gap is better than a silent one.

## Step 4 — Synthesis pass

Re-invoke the `spike` agent with the ticket id and the collected angle outputs. The agent
writes `docs/spikes/<ticket-id>.md` following the result-file structure in
`docs/spikes/README.md` (`Investigation scope` / `Angles` / `Findings` / `Recommendation`
/ `Open risks` / `Next tasks`), adds a `## Pilot walkthrough` for API-design spikes, states
any GREEN/AMBER/RED verdict against the rubric, and updates the ticket's `Result log`.

## Step 5 — Main-thread validation (verdict spikes)

For spikes that issue a tool-adoption verdict (GREEN/AMBER/RED), the main thread must
sanity-check the verdict before trusting it — a sandbox / network / missing-dev-tool
failure is local-env (→ AMBER), never RED. Amend the result file if the executor
misapplied the rubric, recording the amendment.

## Output

Report: the written result-file path, the headline recommendation (adopt / defer /
reject) in one line, and the follow-up tickets the outcome justifies (if any). Do not
dump the whole result file — it is committed and reviewable.

> *A spike produces a decision, not code. To act on the recommendation, open or plan the
> follow-up ticket with `/pm`.*
