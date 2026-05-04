---
description: Run the pre-PR review pipeline (critic + architecture + security + risk + qa) on the current branch.
argument-hint: [optional context, e.g. "skip qa, already audited"]
---

Run the PR gate. Subagents cannot spawn subagents in Claude Code, so the **main thread** orchestrates reviewers; `project-pm` is invoked once at the end to synthesize.

## Step 1 — classify the diff (main thread, no PM hop)

Detect the integration branch and check the diff:

```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
: "${BASE:=main}"
git diff "$BASE"...HEAD --stat
```

Apply the heuristic — bias toward `implementation` when ambiguous (an unnecessary security/risk spawn returns `pass-not-applicable` cheaply; a missed implementation review can ship a real bug):

```bash
non_docs=$(git diff "$BASE"...HEAD --name-only | grep -vE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true)
[ -z "$non_docs" ] && CLASS=docs-only || CLASS=implementation
```

- `docs-only` → spawn `critic` + `architecture-reviewer`. Security / risk / qa are implicitly `pass-not-applicable`; do not spawn.
- `implementation` → spawn all four advisors + `qa-tester`.

Do not invoke PM at this step. PM's role is synthesis only.

## Step 2 — spawn reviewers in parallel from main thread

In a single message, make N parallel Agent tool calls — one per applicable reviewer. Pseudocode (illustrative, not literal call syntax):

```
# pseudocode — emit each as a real Agent tool call in one message
Agent(subagent_type: "critic", ...)
Agent(subagent_type: "architecture-reviewer", ...)
Agent(subagent_type: "security-reviewer", ...)   # implementation only
Agent(subagent_type: "risk-reviewer", ...)       # implementation only
Agent(subagent_type: "qa-tester", ...)           # implementation only
```

Each reviewer brief should include: working dir, branch name vs integration branch, diff summary, scope hints from $ARGUMENTS.

## Step 3 — synthesize via project-pm (single hop)

After all reviewers return, invoke `project-pm` once with the classification + their verbatim outputs and ask it to:

- Compose the final gate summary (each reviewer's verdict, any blocks with override paths, final go/no-go).
- Record `block-soft` overrides or trade-off advisories into project memory.

## Step 4 — relay to user

Relay PM's gate summary verbatim. Do not collapse blocks into "looks good".
