---
description: Take one explicit backlog ticket from implementation through pr-gate to an open PR, without stopping for step-by-step confirmation.
argument-hint: "<ticket-id>"
---

Run a single, explicitly named ticket end-to-end: implement → affected tests →
refactor/reuse audit → gate → fix → conditional re-audit → gate → full suite →
open PR. This is the main-thread's own default operating discipline made
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

**Ticket-id validation** (fail fast, not a discussion point): `/ship` only
ever acts on an active `BACKLOG.md` ticket — `BACKLOG-ARCHIVE.md` is
consulted solely to produce a precise error message, never as a source to
implement from.

- If `$ARGUMENTS` is empty or does not match this repo's ticket-id shape
  (`<PREFIX>-<NNN>` per `pm/schema.md`): stop and report "empty argument" or
  "malformed shape".
- If there is no matching `## <ticket-id>` heading in `BACKLOG.md`: check
   `BACKLOG-ARCHIVE.md`. A match there means the ticket is already terminal
   (done/closed/dropped/superseded) — stop and report "ticket already
   archived", not "no such ticket". No match in either file: stop and report
   "no such ticket".

Either way this is a plain input error, resolved by the caller supplying a
valid, currently-active ticket id, not something to deliberate about.

**Consistency check**: once the ticket id resolves to an active `BACKLOG.md`
heading, read its full body (`grep -n '^## <ticket-id>'` then `sed -n` the
section — do not full-file Read). Extract `Problem` / `Requirement` /
`Dependencies`.

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

**Dirty-tree precondition** (fail fast, not a discussion point — same bucket
as Step 0's ticket-id validation): run `git status` first. If the tree is
dirty with changes unrelated to this ticket, stop immediately and report that
the tree must be clean before `/ship` will branch — do not stash, commit, or
otherwise mutate the caller's uncommitted work on their behalf. This has one
predetermined resolution (the caller commits or stashes it themselves and
re-invokes `/ship`), so it is not the negotiated stop this command reserves
for genuine ambiguity, and it is not an automatic mutation either — never
branch over uncommitted work silently, and never take a repo-mutating action
the caller did not ask for.

```bash
git checkout -b feat/<ticket-id>
```

## Step 2 — Implement

Implement directly with Read/Edit/Write/Bash in this session — do not dispatch
implementation to codex/claude/opencode. `pmctl dispatch run` is not part of
this flow; the only executor dispatch in `/ship` is the gate's own reviewer
dispatch in Step 3.

Use `bash tests/bin/run-tests.sh --base <base-ref>` for implementation feedback.
Pass explicit `--path` or suite inputs when narrowing an iteration further.
Do not run `run-all-tests.sh` before the first PR gate: the affected-test
planner is the fast feedback path, while the authoritative full suite belongs
after a GO verdict.

## Step 2.5 — Refactor/reuse audit

After the primary implementation and its affected verification are complete,
run one maintainability audit on the actual diff **before the first PR gate**.
This is a pm-dispatch maintainer policy, not a prerequisite built into the
generic `pmctl gate` command.

1. **Simplify**: inspect changed production code for duplicated branches,
   wrappers, parsing, locking, path handling, or indirection that can be made
   smaller without changing behavior.
2. **Reuse**: use `rg` to inspect existing helpers, peer implementations, and
   all call sites in the affected scope. Prefer a proven shared helper over a
   second local implementation, but do not introduce speculative abstractions.
3. **Verify**: apply warranted behavior-preserving cleanup, rerun the affected
   focused tests, and record either `CHANGED: <what was consolidated>` or
   `PASS: no warranted refactor/reuse change` for the PR handoff.

This initial audit runs exactly once even when it finds no cleanup. It is not
delegated to PR-gate reviewers: doing the cheap maintainability pass first
keeps avoidable duplication and incidental complexity out of the expensive
cross-model review loop.

## Step 3 — Gate loop

Choose `<gate_executor>` and, when needed, `<gate_model>` before the first gate
using the authoritative [gate model diversity policy](../docs/review-model.md#gate-model-diversity).
Base the choice on actual model identities, record both identities in the
handoff, and keep the same resolved pair for targeted re-runs. Add
`--model "<gate_model>"` below only when the executor default does not already
resolve to the selected gate model.

Run `pmctl gate run --executor <gate_executor> --cd "<work_dir>" --lifecycle foreground`
(substitute `<work_dir>` with the literal absolute working directory, not
`"$PWD"` — a shell-variable expansion makes the command unanalyzable
statically and forces a manual approval every time even though a bare
`pmctl ...` invocation matches allowlisted `Bash(pmctl:*)`-style permission
rules). The `/pr-gate` command is the orchestration wrapper around this exact
invocation — either entry point is acceptable, but the underlying gate call
is always this one, never `bash runtime/bin/pr-gate.sh` directly.
`--lifecycle foreground` is required here: the default `--lifecycle detached`
returns only a `gate_id` immediately and the gate keeps running in the
background — reading `Final:` right after that call would read a stale or
missing result. `/ship` is already a long-running autonomous loop with
nothing else for the main thread to do while it waits, so there is no reason
to pay the detached/`pmctl gate wait` two-call complexity that `/pr-gate`
uses to keep the main thread free for other work; run `foreground` and read
the resulting `Final: GO|NO-GO` verdict directly from the gate result file
once the call returns.

- **GO** → go to Step 3.5.
- **NO-GO** → invoke the `project-pm` agent to synthesize the gate result
  against the verdict table and Rules A/B in `agents/project-pm.md` (source-first
  read of every cited diff file, discovery sweep of all call sites of a
  flagged helper, minimum-list is a floor not a ceiling). Fix **every** finding
  it returns — high, medium, and low, hard gate and advisory alike, not only
  the blocking ones.

  Before re-running the gate, classify the remediation:

  - **Re-run the refactor/reuse audit** when the fix changes a shared helper or
    public interface, schema, ownership, data flow, layer boundary, introduces
    or removes an abstraction, moves logic across files, performs cross-file
    deduplication, raises `architecture_impact`, or leaves the structural scope
    unclear. Rerun affected focused tests if the audit changes the diff.
  - **Skip the re-audit with a recorded reason** for localized corrections that
    preserve the established structure, such as wording/comments, a narrow
    assertion or fixture adjustment, or a small guard/error-handling fix.

  Then re-run `pmctl gate run --executor <gate_executor> --cd "<work_dir>"
  --lifecycle foreground --reviewers <reviewer,...>` (same literal-path
  substitution as Step 3's first call — never `"$PWD"`; the `/pr-gate`
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

## Step 3.5 — Authoritative full suite

Only after PR-gate returns GO, run `bash tests/bin/run-all-tests.sh` once and
verify its authoritative result artifact. This is the final repo-wide
regression check, not an iteration tool.

If the full suite finds a diff-caused failure, fix it, rerun affected tests,
apply the same refactor/reuse recheck threshold, and return to the targeted
gate path for every reviewer territory the fix touched. After GO, run the full
suite again against the new tree. Keep pre-existing or infrastructure failures
separate; do not silently attach unrelated repairs to the ticket.

## Step 4 — Open the PR

```bash
git push -u origin feat/<ticket-id>
gh pr create --title "<type>(<ticket-id>): <short summary>" --body "$(cat <<'EOF'
## Summary
- <one-line summary of the change>

## Gate
- Refactor/reuse audit: <CHANGED summary | PASS no change>
- Implementation model: <model id/family>
- Review executor/model: <executor + resolved model id/family>
- Rounds: <N>
- Final verdict: GO
- Result file: <path from the last /pr-gate relay>
- Full suite: <passed count and authoritative result artifact>

Ticket: <ticket-id>
EOF
)"
```

Do not merge. GO is not merge authorization — merge only when the user
explicitly says so.

## Step 5 — Close-out report

Report one of four outcomes: (1) invalid ticket id — the exact problem
(empty argument / malformed shape / no such ticket / already archived); (2)
dirty tree — that `/ship` aborted without touching the caller's uncommitted
work, and that a clean tree is required to re-invoke; (3) consistency-check
stop — the ticket id, the conflicting `DECISIONS.md` entry or unmet
dependency, and what decision is needed from the user; or (4) PR opened —
ticket id, what changed, how many gate rounds it took, the final verdict, and
the PR URL.
