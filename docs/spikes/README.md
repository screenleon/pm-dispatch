# Spikes

A **spike** is an investigation task — work that must reduce uncertainty
*before* an implementation spec can be written. Spike tickets carry the
`spike` epic in `BACKLOG.md`; their committed findings live here as
`docs/spikes/CC-NNN.md`.

Why this directory exists: a spike's findings must survive across sessions.
An investigation done once and left only in conversation context is a gap —
it gets re-done and re-paid for. Committing the result file fixes that.

## Spike ticket body (in `BACKLOG.md`)

A spike ticket uses the **standard three-section entry body** —
`Problem` / `Why` / `Requirement`, per `pm/schema.md` §2.5. It does **not**
add new top-level sections. The spike-specific structure lives *inside* the
`Requirement` section as three labelled parts:

- **Investigation scope** — the concrete questions / angles to explore.
- **Done-when** — the criterion that closes the spike: what must be answered.
- **Result log** — a pointer to `docs/spikes/CC-NNN.md` (added once the
  result file exists).

Skeleton:

```
## CC-NNN — <title>（spike）

**Problem**: <what is unknown; why a spec cannot be written yet>
**Why**: <why resolving the uncertainty matters>
**Requirement**:
- Investigation scope: <questions / angles to explore>
- Done-when: <what answer closes the spike>
- Result log: docs/spikes/CC-NNN.md
```

## Spike result file (`docs/spikes/CC-NNN.md`)

One file per spike, named for the ticket ID (`CC-NNN.md`, optionally
`CC-NNN-slug.md`). It is the committed, reviewable outcome of the
investigation. Structure:

```markdown
# CC-NNN — <title> (spike result)

**Status**: complete | abandoned
**Date**: <YYYY-MM-DD>
**Ticket**: BACKLOG.md CC-NNN

## Investigation scope
<the questions this spike set out to answer>

## Angles
<one subsection per investigation angle: what was tried, what was found>

## Findings
<the evidence — measurements, observations, comparisons>

## Recommendation
<adopt / defer / reject, with reasoning>

## Open risks
<what remains uncertain after the spike>

## Next tasks
<implementation / follow-up tickets the outcome justifies, if any>
```

The **Recommendation** is the load-bearing output — a spike's product is a
*decision*, not code. Any code written during a spike is a throwaway
prototype; the durable artifacts are this result file and the follow-up
tickets it justifies.

## `test_target:` field (language-aware tool spikes)

When a spike evaluates a **language-aware tool** (codegraph, AST-grep, semgrep,
tree-sitter, etc.) that must index or analyse a representative codebase, the
brief MUST commit to a `test_target:` field:

```
test_target: <absolute path to the representative target repo>
```

**Required** when the spike evaluates a language-aware tool whose verdict depends
on the target's language/size/structure. **Optional** otherwise.

`test_target:` is distinct from `working_dir:` (the spike executor's working
directory, often pm-dispatch itself). A spike evaluating codegraph for a Go
codebase would have `working_dir: ~/github/pm-dispatch` (where the tool setup
lives) but `test_target: ~/github/some-go-project` (the corpus being indexed).

Without a committed `test_target:`, the executor may pick any convenient repo,
making the verdict non-reproducible. Include the language and approximate LOC in
a comment when the exact repo matters for generalizability.

## Verdict rubric for tool-evaluation spikes

Verdict-issuing spikes that evaluate external tools must include a verdict rubric
at `/tmp/cc<NNN>-content/verdict-rubric.md`. Reference template:

```markdown
## Verdict rubric

### GREEN — adopt
- Tool installs and the key capability works end-to-end on `test_target`.
- Results are accurate enough to reduce the stated uncertainty.
- No blocking constraints for the target use case.

### AMBER — conditional
- Tool works but with meaningful caveats (limited language support, index lag,
  precision gap).
- Adoption is viable with a documented workaround or scope restriction.
- Cost or setup overhead is higher than expected but acceptable.

### RED — do not adopt
- Install fails after a reasonable attempt and the failure is **not** a local-env
  issue (e.g. peerDep that the user could resolve, sandbox network isolation,
  missing dev dependencies). ANY constraint of the executor's local environment
  (sandbox, network block, missing tools) counts as local-env — not a project
  quality signal. Only flag RED here when the failure would reproduce on a clean,
  fully-provisioned dev machine.
- Tool produces inaccurate results that cannot be worked around.
- Security or licensing concern blocks use in this repo.
```

The RED criterion 1 enumeration of local-env examples (peerDep, sandbox network
isolation, missing dev dependencies) is intentional: an executor running in a
sandboxed environment that cannot reach the network must classify the failure as
local-env and issue AMBER (needs-network caveat), not RED (tool broken).

## Producing a spike result

The spike agent plans the angles, the main thread fans out one investigation
agent per angle (subagents cannot spawn subagents), and the spike agent
synthesizes the angle outputs into the result file. A spike result file may be
written by hand following the structure above.

The first formal spike is **CC-209** — evaluating codegraph as a
`context-pack` source.
