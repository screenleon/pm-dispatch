# Live dogfood report: create-t3-turbo on native Windows (CC-447 Requirement 2)

Filled from [`live-dogfood-report-template.md`](live-dogfood-report-template.md). Times are wall clock
from the session log; interventions were counted by the operator, which in this run was Claude acting
for the maintainer, so "interventions" means commands or edits the documented flow did not tell the
operator to make. Where something was not run, it says so.

## Run

| Field | Value |
|---|---|
| Date, host | 2026-10-23 22:18 to 2026-10-24 02:31 (local), Windows 11 Home 10.0.26200, Git Bash, native (no WSL) |
| pm-dispatch commit | `db561f6` (main) |
| Target repository | `t3-oss/create-t3-turbo` at `8f945b7`, 141 tracked files |
| Operator | Claude (Sonnet 5.5) for the maintainer; the maintainer chose the target, the removal of stale symlinks and option A in step 6 |
| Hosts and executors | Claude Code host; gate executor `codex` (reviewers critic, qa-tester, architecture-reviewer, risk-reviewer) |

The machine is the maintainer's development machine, not a clean one. Step 1 is therefore not evidence
of a clean install.

## Steps

| # | Step | Wall time | Interventions | Unclear message? | Ticket |
|---|---|---|---|---|---|
| 1 | `install.sh`, then `doctor.sh` | install 13 s (refused), 43 s, 42 s (done); doctor 4 m 49 s | 3: removed 5 stale symlinks into `.gate-results/native-gate/` in three rounds, each after the maintainer approved; wrong guess of the doctor path (`doctor.sh` at the root instead of `runtime/bin/doctor.sh`, operator error, no ticket) | `install: load-bearing copy bundle conflict` listed two paths; the next run reported one more (`.pm`), the next two more (`scripts/doctor.sh`, `scripts/pr-gate.sh`). Only the first conflict is reported per run | [[CC-672]] |
| 2 | `pmctl worktree create dogfood-1 --path C:\dogfood\w1`; install dependencies | create 3.8 s; first `pnpm install` 7 m 57 s; rerun 6.8 s | 2: `pnpm` was not installed (operator prerequisite, not a tool problem); `corepack pnpm` does not put `pnpm` on the child PATH, so the repo's `postinstall` failed until a wrapper script was added to PATH | none from pmctl | none |
| 3 | A small change, then `pmctl gate run --lifecycle detached --test-cmd "pnpm --filter @acme/api typecheck"` | round 1 failed after 2 m, round 2 after about 10 m | 2: added `.pm-dispatch/`, then the other five bookkeeping directories, to the target's `.git/info/exclude` | round 1: `working tree is dirty while the branch has committed changes against main` (the dirt was pm-dispatch's own `.pm-dispatch/`); round 2: `reviewer sessions modified working tree -- possible prompt injection` (the change was pm-dispatch's own `.dispatch-results/`) | [[CC-667]], [[CC-668]] |
| 4 | A review NO-GO, read from the output alone | round 3: 17 m 18 s from launch to verdict | 0 | none: `NO-GO is the gate verdict (exit 1), not an execution error; findings are in the result file above` | none |
| 5 | A tool failure, read from the output alone | rounds 1, 2, 4 and 5 (below) | 0 | none for the first two: `failed is an execution error, not a review verdict; the gate produced no GO or NO-GO` followed by the last supervisor error | none |
| 6 | Fix, then targeted re-run | 3 gate rounds of 1 m 28 s, 11 m and 12 m, plus 29 s for the dependency install and the edits | 4: added vitest and a test with a stand-in `ctx.db` after the maintainer chose option A; relaunched with the three policy-floor reviewers; checked and reverted a lockfile drift; relaunched once more | policy floor rejection: `coverage: requested=explicit required=["architecture-reviewer","risk-reviewer"]` did not say that the requested `qa-tester` had to stay in the set; `reviewer protocol INCOMPLETE ... truncated reviewer result` for results that were complete | [[CC-669]], [[CC-671]] |
| 7 | `gate verify`, then `pmctl worktree remove` | remove failed after 2 s, manual removal 44 s | 2: `gate verify` takes the result file, not the gate id (error was an `awk` "cannot open file"); `worktree remove` failed with `Filename too long` and the hint "dirty? pass --force" | both | [[CC-670]], [[CC-671]] |
| ship | `pmctl ship` | not run | | | |

`pmctl ship` was not run. It is the ticket workflow (`CC-NNN` in a `BACKLOG.md`) and ends in a push and a
pull request; the target is another party's public repository where the operator has no push right.
That path is still unexercised on an external repository.

Totals: first command 22:18, last 02:31, of which 2 h 42 m (23:20 to 02:02) was waiting for the maintainer's
choice in step 6, so about 1 h 30 m of working time, most of it reviewer time (about 1 h of the six rounds)
and the first dependency download (8 m). 13 counted interventions, 6 tickets opened (CC-667 to CC-672).

## The gate rounds

| Round | gate id | Outcome | Cause |
|---|---|---|---|
| 1 | `gate-20261023-135013-b906a6` | `failed`, exit 3 | `.pm-dispatch/` untracked in the target worktree |
| 2 | `gate-20261023-135204-085a5d` | `failed`, exit 2 | `.dispatch-results/` written by the reviewers tripped the "possible prompt injection" check |
| 3 | `gate-20261023-140304-77a868` | NO-GO, exit 1 | `qa-tester-F001`, hard_block: no runnable test protects the cap of `post.all`; critic and architecture-reviewer approved |
| 4 | `gate-20261023-170355-d68648` | `failed`, exit 3 | targeted pass asked for `qa-tester` only; the policy floor also requires architecture-reviewer and risk-reviewer (the change now touched dependencies) |
| 5 | `gate-20261023-170532-692188` | `failed`, exit 2 | architecture-reviewer and risk-reviewer results were complete but ended in a closing fence with a carriage return, which `gate-result-verify.sh` did not accept; the automatic retry hit the same thing |
| 6 | `gate-20261023-171811-2b6ad9` | **GO**, exit 0 | same subject as round 5; `gate verify`: `assurance: verified`, `artifact_valid: pass`, `subject_current: pass` |

Rounds 5 and 6 reviewed the same commits; the difference was the line endings the reviewers wrote, so the
fault is intermittent.

## Facts, not conclusions

- Longest tracked path in the worktree: 51 characters. The worktree was at `C:\dogfood\w1`. Installed
  `node_modules` paths are longer than 260 characters and made `git worktree remove` fail
  (`Filename too long`).
- Change set: 2 commits, 4 files (`post.ts`, `post.test.ts`, `packages/api/package.json`, `pnpm-lock.yaml`).
  `scope manifest built in 5s` for 1 changed path, `10s` for 4.
- `--test-cmd` ran `pnpm --filter @acme/api typecheck` in round 3 and `pnpm --filter @acme/api test` in
  rounds 4 to 6. The test file has 7 cases against a stand-in `ctx.db`; with the cap changed to 11, three of
  them fail. The repository has no other tests. A GO here is not a pass of any wider suite.
- Adding `vitest` and regenerating the lockfile with pnpm 10.19 also rewrote `better-auth` peer resolution
  and removed the `metro-config` `utf-8-validate` variant, even when regenerated from the unchanged base. The
  risk-reviewer flagged this as `advise`. The upstream lockfile is out of date relative to that pnpm; the
  committed change carries the drift (about 350 lines, 330 of them vitest's own entries).
- NO-GO versus tool failure: told apart by the output alone in every round that ended in `failed` or
  NO-GO, except round 5, where the label said `failed` correctly but the cause text (`truncated reviewer
  result`) was wrong.
- Not exercised: the unset `QA_RULES_DIR` case (Requirement 5). It was set in every round.

## Evidence boundary

What this run shows: on native Windows, a pnpm monorepo of 141 tracked files can be taken from install
to a verified full-flow GO through `pmctl worktree create --path`, a detached gate, a targeted re-run and
`gate verify`, with `failed` and NO-GO distinguishable from the output.

What it does not show:

- A clean install: the machine had stale symlinks from earlier gate experiments.
- Behaviour at the size of the monorepo behind #621 or #620; scope manifest time was 5 to 10 s here.
- `pmctl ship`, the ticket workflow, or anything that pushes.
- That the repository's own test suite passes on native Windows. It has none to run, and only the new
  7-case file ran.
- The case where `QA_RULES_DIR` is missing.
- Reproducibility across reviewers: one run, one executor family, one target. Two of the six rounds were
  consumed by faults that depend on the reviewer's output, so another run can differ.
