---
description: Run the pre-PR review pipeline (critic + architecture + security + risk + qa) on the current branch.
argument-hint: [optional context, e.g. "skip qa, already audited"]
---

Run the PR gate. Subagents cannot spawn subagents in Claude Code, so the **main thread** orchestrates reviewers; `project-pm` synthesizes.

## Step 1 — classify the diff

In the main thread, run `git diff main...HEAD --stat` (substitute the actual integration branch). Decide:

- **docs / content-only** (no runtime code change) → spawn `critic` + `architecture-reviewer` only. Security / risk / qa are `pass-not-applicable`.
- **implementation change** (any runtime code diff) → spawn all four advisors + qa-tester.

If unsure, invoke `project-pm` first with the diff stat to get the classification, then proceed to step 2.

## Step 2 — spawn reviewers in parallel from main thread

In a single message, make multiple Agent calls (this is the parallel pattern):

```
Agent(subagent_type: "critic", prompt: <branch + diff context + $ARGUMENTS>)
Agent(subagent_type: "architecture-reviewer", prompt: <same>)
Agent(subagent_type: "security-reviewer", prompt: <same>)   # implementation only
Agent(subagent_type: "risk-reviewer", prompt: <same>)       # implementation only
Agent(subagent_type: "qa-tester", prompt: <same>)           # implementation only
```

Each reviewer brief should include: working dir, branch name vs integration branch, diff summary, scope hints from $ARGUMENTS.

## Step 3 — synthesize via project-pm

After all reviewers return, invoke `project-pm` with their verbatim outputs and ask it to:
- Compose the final gate summary (each reviewer's verdict, any blocks with override paths, final go/no-go).
- Record `block-soft` overrides or trade-off advisories into project memory.

## Step 4 — relay to user

Relay PM's gate summary verbatim. Do not collapse blocks into "looks good".

If any hard gate (security / risk / qa red-line) blocks, do NOT open a PR. Surface the override path to the user and wait for explicit acknowledgment.
