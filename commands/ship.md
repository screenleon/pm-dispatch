---
description: Take one explicit backlog ticket from implementation through pr-gate to an open PR, without stopping for step-by-step confirmation.
argument-hint: "<ticket-id>"
---

Run a single, explicitly named ticket end-to-end: implement → gate → fix → gate
→ open PR. This is the main-thread's own default operating discipline made
runnable as one command, not a new background/unattended supervisor — the
session stays open and you stay reachable the whole time.

**Scope**: one ticket per invocation, named in `$ARGUMENTS`. Do not scan
`BACKLOG.md` for other candidates or batch multiple tickets in one run.

## The one legal stopping point

Everywhere in this flow, the only reason to stop and ask the user for a
substantive discussion instead of continuing is: **the ticket's premise
fundamentally conflicts with something already decided** — its approach
contradicts a `DECISIONS.md` entry's `**Constraints introduced**`, a named
`Dependencies` ticket is not actually done, or (discovered mid-implementation)
the ticket's own assumption turns out to be wrong. Ordinary reviewer findings
— hard gate or advisory, however many rounds it takes — are not a stopping
point; fix them and continue. This mirrors `agents/project-pm.md`'s PR-gate
verdict table and Rules A/B, which this command invokes rather than
re-implements.

This is distinct from Step 0's plain input validation and Step 1's dirty-tree
precondition below — those are deterministic fail-fast/fail-safe checks with
one predetermined outcome each, not a negotiated decision. "The one legal
stopping point" refers only to cases where the *next action is genuinely
ambiguous* and needs the user's judgment.

## Step 0 — Validate the ticket id, then check consistency

**Ticket-id validation** (fail fast, not a discussion point): if `$ARGUMENTS`
is empty, does not match this repo's ticket-id shape (`<PREFIX>-<NNN>` per
`pm/schema.md`), or has no matching `## <ticket-id>` heading in either
`BACKLOG.md` or `BACKLOG-ARCHIVE.md`, stop immediately and report the exact
problem (empty argument / malformed shape / no such ticket) — this is a plain
input error, resolved by the caller supplying a valid id, not something to
deliberate about.

**Consistency check**: once the ticket id resolves, read its full body from
`BACKLOG.md` (`grep -n '^## <ticket-id>'` then `sed -n` the section — do not
full-file Read). Extract `Problem` / `Requirement` / `Dependencies`.

- **Dependencies**: for every ticket referenced in `Dependencies`, confirm its
  status in `BACKLOG.md`'s index table (or `BACKLOG-ARCHIVE.md` if terminal)
  is actually a terminal state (`✅ done`/`✅ closed`) when the requirement
  reads as a hard blocker. A dependency that is merely "related" (not a
  blocker) does not stop the run.
- **Decisions**: `grep -n '\*\*Constraints introduced\*\*' DECISIONS.md` and
  read the handful of entries whose `Context`/`Decision` mentions the same
  subsystem, files, or concept as the ticket. Judge — as PM-level judgment,
  not string matching — whether the ticket's `Requirement` asks for something
  a constraint explicitly rules out, or whose premise a later decision has
  superseded. `DECISIONS.md` is a human/PM-only audit record and stays that
  way here: read it yourself, do not paste it into any dispatch brief.

If either check finds a real conflict: **stop here.** Do not create a branch,
do not implement. Report the ticket id, the conflicting `DECISIONS.md` entry
or unmet dependency, and wait for the user's direction.

If clear: continue to Step 1.

## Step 1 — Branch

**Dirty-tree precondition** (fail-safe, not a discussion point): run `git
status` first. If the tree is dirty with changes unrelated to this ticket,
`git stash -u` before branching (note the stash in the Step 5 report so it's
easy to recover) — never branch over uncommitted work silently, and never
stop to ask about it, since stashing is reversible and there is nothing to
deliberate.

```bash
git checkout -b feat/<ticket-id>
```

## Step 2 — Implement

Implement directly with Read/Edit/Write/Bash in this session — do not dispatch
implementation to codex/claude/opencode. `pmctl dispatch run` is not part of
this flow; the only executor dispatch in `/ship` is the gate's own reviewer
dispatch in Step 3.

## Step 3 — Gate loop

Run `pmctl gate run --executor codex --cd "$PWD" --lifecycle foreground` (the
`/pr-gate` command is the orchestration wrapper around this exact invocation
— either entry point is acceptable, but the underlying gate call is always
this one, never `bash scripts/pr-gate.sh` directly).
`--lifecycle foreground` is required here: the default `--lifecycle detached`
returns only a `gate_id` immediately and the gate keeps running in the
background — reading `Final:` right after that call would read a stale or
missing result. `/ship` is already a long-running autonomous loop with
nothing else for the main thread to do while it waits, so there is no reason
to pay the detached/`pmctl gate wait` two-call complexity that `/pr-gate`
uses to keep the main thread free for other work; run `foreground` and read
the resulting `Final: GO|NO-GO` verdict directly from the gate result file
once the call returns.

- **GO** → go to Step 4.
- **NO-GO** → invoke the `project-pm` agent to synthesize the gate result
  against the verdict table and Rules A/B in `agents/project-pm.md` (source-first
  read of every cited diff file, discovery sweep of all call sites of a
  flagged helper, minimum-list is a floor not a ceiling). Fix **every** finding
  it returns — high, medium, and low, hard gate and advisory alike, not only
  the blocking ones. Re-run `pmctl gate run --executor codex --cd "$PWD"
  --lifecycle foreground --reviewers <reviewer,...>` (the `/pr-gate`
  `--targeted` flag maps to this same `--reviewers` option) for the reviewers
  whose territory the fix touched. Repeat.

**Stop the loop only when**:
1. Step 0's check would have caught this but didn't — implementation revealed
   the ticket's own assumption is wrong, or a fix genuinely requires
   contradicting a `DECISIONS.md` constraint; or
2. Rule A's 3-strike audit (`agents/project-pm.md`) has already run, the
   remaining blockers are confirmed diff-caused (not the pre-existing issues
   Rule A downgrades to `advise`+separate issue), and a further round produces
   no new progress — same blockers, same state, nothing fixed. This is "no
   fix is being found," not "this is taking many rounds": a real gate has
   already needed 7 normal rounds to converge, and round count alone was not
   a stop signal that time.

Any other NO-GO, at any round count, gets fixed and re-gated without asking.

## Step 4 — Open the PR

```bash
git push -u origin feat/<ticket-id>
gh pr create --title "<type>(<ticket-id>): <short summary>" --body "$(cat <<'EOF'
## Summary
- <one-line summary of the change>

## Gate
- Rounds: <N>
- Final verdict: GO
- Result file: <path from the last /pr-gate relay>

Ticket: <ticket-id>
EOF
)"
```

Do not merge. GO is not merge authorization — merge only when the user
explicitly says so.

## Step 5 — Close-out report

Report one of three outcomes: (1) invalid ticket id — the exact problem
(empty argument / malformed shape / no such ticket); (2) consistency-check
stop — the ticket id, the conflicting `DECISIONS.md` entry or unmet
dependency, and what decision is needed from the user; or (3) PR opened —
ticket id, what changed, how many gate rounds it took, the final verdict, the
PR URL, and whether Step 1 stashed pre-existing changes.
