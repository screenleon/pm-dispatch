# Live dogfood report (CC-447 Requirement 2)

Fill in one copy per run and keep it next to the evidence (gate result files, logs). The point is a
real public project taken through the whole flow once, with the time and the human interventions
counted by the person who did them. Nothing here claims more than was run: write "not run" where
something was not.

## Run

| Field | Value |
|---|---|
| Date, host (OS build, shell, WSL or native) | |
| pm-dispatch commit | |
| Target repository (URL, commit) | |
| Operator (who counted the interventions) | |
| Hosts and executors used (Claude, Codex, models) | |

## Steps

For each step record the wall time, the number of human interventions (a command or edit that the
documented flow did not tell you to make, a retry, a log you had to open) with one line on each, and
whether any message was unclear or not actionable. Open one ticket per stumble; do not fix it here.

| # | Step | Wall time | Interventions | Unclear message? (quote it) | Ticket |
|---|---|---|---|---|---|
| 1 | Install or update (`install.sh`, then `doctor.sh`) | | | | |
| 2 | `pmctl worktree create <branch> --path <short dir>` in the target; install dependencies | | | | |
| 3 | A small real change, then `pmctl gate run` (tier, mode, `--test-cmd`) | | | | |
| 4 | Provoke a review NO-GO; read why from the output alone | | | | |
| 5 | Provoke a tool failure (for example unset `QA_RULES_DIR`); read why from the output alone | | | | |
| 6 | Fix, then targeted re-run | | | | |
| 7 | `pmctl ship` (or the PR by hand if it is not available), then `pmctl worktree remove` | | | | |

Totals: wall time ____, interventions ____, tickets opened ____.

## Facts to record, not conclusions

- Longest path inside the worktree (characters), and whether the 260-character Windows limit was hit.
- Files in the change set; seconds in the `scope manifest built in <N>s` log line.
- What `--test-cmd` ran and what it did not cover. A gate GO is not a test-suite pass; say which tests
  ran and where.
- Whether a NO-GO and a tool failure were told apart by the output alone (`NO-GO is the gate verdict`
  versus `failed is an execution error, not a review verdict`), and what you read to find out.

## Evidence boundary

State, for this run, what it shows and what it does not. The standing list is in
[`platform-support.md`](../platform-support.md#evidence-boundary-for-native-windows); copy the lines that
apply. A single public repository shows that the flow completes; it does not show behaviour at the
size of a larger private monorepo.
