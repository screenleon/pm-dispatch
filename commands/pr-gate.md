---
description: Run the pre-PR review pipeline (critic + architecture + security + risk + qa) on the current branch.
argument-hint: [optional context, e.g. "skip qa, already audited"]
---

Invoke `project-pm` via Agent to run the PR gate. Brief with:
- Current working directory and branch.
- Integration branch (default `main`; PM detects via `git remote show origin` or project memory if different).
- $ARGUMENTS (user context — skip requests with reasoning, scope hints).
- Instruction: classify diff (implementation vs docs-only) and run the appropriate gate per project-pm's PR gate section.

Relay the PM's gate summary verbatim — each reviewer's verdict, any blocks with override paths, final go/no-go. Do not collapse blocks into "looks good".

If any hard gate (security/risk/qa red-line) blocks, do NOT open a PR. Surface the override path to the user and wait for explicit acknowledgment.
