---
description: Pre-implementation design review — define boundaries, dependencies, and change seams before writing any code.
argument-hint: "<feature description, e.g. 'add OAuth login to the API'>"
---

Run a design review for `$ARGUMENTS` before any implementation starts. If no argument is provided, ask the user what feature they are about to implement.

The output is a **structured pre-impl artifact** with six fixed sections, ending in a design constraint list that can be pasted directly into a PM brief's `constraints:` field. The `Conceptual Map` section maps directly to the brief's `conceptual_map:` field.

## When to invoke

PM **must** run `/pre-impl` before writing a dispatch brief whenever:

- the brief introduces **3 or more behavioral units**, OR
- the task has **architecture impact** (`architecture_impact: minor` or `major` in the planned brief — any change that touches a shared module, crosses a layer boundary, or introduces a new interface/schema).

A **behavioral unit** is one externally observable behavior change: a new command output, a new validation rule, a new dispatch decision path, a new reviewer behavior, a new file-writing side effect, or a new user-visible workflow branch. Examples: adding one brief validation rule = 1 unit; adding one enum field = 1 unit; changing PM routing = 1 unit; changing pr-gate tier selection = 1 unit; changing architecture-reviewer process = 1 unit.

For single-unit changes that do not touch a module boundary, it is optional but recommended.

The structured output produced here should be used to fill the brief's `constraints:` field (constraint list) and `conceptual_map:` field (Conceptual Map section).

## What

`/pre-impl` produces a structured pre-impl artifact that captures intention, scope boundaries, architecture sketch, acceptance metrics, and a verification plan — so the implementation agent starts with a clear, approved direction rather than inferring it from the brief alone.

## When to use

- Before introducing three or more new behavioral units.
- Before touching shared modules, schema files, or reviewer flow surfaces.
- Before any task where `architecture_impact: minor` or `major` — i.e., any cross-layer dependency, new abstraction, or shared-module change.
- When a design guardrail is needed before dispatch to avoid avoidable PR-gate rework.

## Example

```sh
/pre-impl "add onboarding docs for first-time fork users"
```

## Step 1 — Understand the codebase entry points

Scan the current working directory to build a minimal structural picture. Run the following (adjust depth if the repo is large):

```bash
# Public-facing entry points
find . \( -path './node_modules' -o -path './.git' -o -path './dist' -o -path './__pycache__' -o -path './vendor' \) -prune \
  -o \( -name "main.*" -o -name "index.*" -o -name "app.*" -o -name "server.*" \) -print \
  | head -20

# Existing modules/packages
find . -maxdepth 3 \( -path './node_modules' -o -path './.git' -o -path './dist' -o -path './__pycache__' -o -path './vendor' \) -prune \
  -o -type d -print

# Files related to the feature (keyword from $ARGUMENTS)
grep -rli "KEYWORD" . \
  --include="*.go" --include="*.ts" --include="*.py" \
  --include="*.js" --include="*.java" --include="*.rb" \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=__pycache__ --exclude-dir=vendor \
  | head -20
```

Replace `KEYWORD` with the most specific noun from `$ARGUMENTS` (e.g., for "add OAuth login", use `auth` or `oauth`).

Read the 2–4 most relevant files found. Focus on: public function signatures, interface definitions, existing dependency imports.

## Step 2 — Answer the mandatory design questions (Q1–Q3 always; Q4 when a new test script is added)

You **must** answer Q1–Q3 before producing output. Answer Q4 when the brief adds a new contract test script. Do not skip or merge questions.

### Q1 — Responsibility boundary
> "What is the **single responsibility** of this module/feature? What is explicitly **out of scope**?"

- State what the new code does in one sentence.
- List 2–3 things it must **not** do (even if tempting).
- Identify which existing module would own those out-of-scope concerns.

### Q2 — Dependency direction
> "Which existing modules does this feature depend on? Can any direct dependency be replaced with an interface or injection?"

- List every existing module/service this feature will call or import.
- For each dependency: is it a stable abstraction (interface/type) or a concrete implementation?
- Flag any dependency that points inward (toward core business logic from infra layer, or vice versa) — these are the dangerous ones.

### Q3 — Change seam
> "Where is this feature most likely to change in the future? What seam must be preserved to allow that change without touching everything else?"

- Name the most volatile part (e.g., "the auth provider could be swapped", "the schema format is not final").
- State what interface or boundary must exist so that change is isolated.
- If no seam is needed, explicitly say "no seam needed because X".

### Q4 — Contract test completeness (applies only when a new test script is added in the same PR)
> "If this PR introduces both a new command/feature AND a new contract test script, enumerate every behavioral contract before writing any assertion."

Skip this question if the brief only modifies existing tests.

When applicable, list:
- Every **input state** the command accepts: empty arg, each valid value, unrecognized/invalid values
- Every **output format** the command specifies: success path confirmation, each error message, each mode or type variant
- Every **rule section** the command documents: per-mode rules, per-type rules, per-section invariants
- Every **stop condition**: steps that must not proceed on bad input

For each entry in the list, confirm there is a corresponding assertion in the test script before dispatch. `qa-tester` treats each uncovered behavioral contract as a missing-coverage block — finding gaps one per gate round. This enumeration costs five minutes and prevents 4–6 extra rounds.

## Step 3 — Produce the structured pre-impl artifact

Based on the answers above, produce the following six sections. All six are required; do not omit or merge any.

```markdown
## Intention
<One sentence: what specific problem this solves. Not "we want to improve X" — state the concrete outcome.>

## Non-goals
- <What this change explicitly does NOT do, even if related>
- <Second explicit exclusion>
[add entries as needed]

## Bounded Context
**May touch**: <comma-separated list of modules / scripts / commands / schema files>
**Must not touch**: <anything off-limits — shared schemas modified only through their declared owner, etc.>

## Conceptual Map
<Plain-text diagram or structured prose describing the proposed structure: data flow, module interactions, layer ownership. No source code. 5–15 lines. Example:>

  caller → /pre-impl → [scan codebase] → [Q1-Q3 analysis] → artifact
  artifact.constraints  → brief.constraints:  (paste verbatim)
  artifact.conceptual_map → brief.conceptual_map: (paste verbatim)
  architecture-reviewer reads conceptual_map first; source diff only if map/diff diverge.

## Acceptance Metrics
- <Concrete, testable condition — not "works correctly" or "no errors">
- <Second measurable condition>
[each metric must be independently verifiable by a machine or a reviewer reading the diff]

## Verification Plan
| Check | Method |
|---|---|
| <condition> | cmd: <shell command> |
| <condition> | semantic: <what a reviewer checks manually> |
```

Optionally, add a seventh section when there are genuine unknowns:

```markdown
## Assumptions / Open Questions
- <Assumption the implementation must make because the answer is not yet known>
- <Open question that PM should resolve before dispatch>
```

This section is not required. Include it when the analysis in Q1–Q3 reveals something the implementation will have to assume without a definitive answer. PM reads this before approving the brief — unresolved open questions are a signal to pause dispatch until the question is answered, not to proceed and hope.

The `Conceptual Map` section content can be pasted verbatim into the brief's `conceptual_map:` field. The constraints section (Step 4 below) pastes into `constraints:`.

## Step 4 — Synthesize the design constraint list

Based on Q1–Q3 and the artifact above, synthesize 3–5 constraints. Each constraint must be:
- **Structural** (about what can/cannot depend on what, or what belongs where) — not a style rule
- **Falsifiable** (a reviewer can check whether the implementation violates it)
- **Negative or boundary** (what NOT to do, or what MUST be separated)

Format:

```
## Design constraints: <feature name>

1. <constraint>
2. <constraint>
3. <constraint>
[4. <constraint>]
[5. <constraint>]

Ready to paste into brief `constraints:` field.
```

## Step 5 — Optional: flag risks

If any of the questions revealed a dependency or boundary that is particularly risky (e.g., touches auth, modifies shared schema, introduces a new cross-layer dependency), add a brief `## Risk flags` section after the constraints listing the specific concern. Keep it to 1–3 bullets.

Do not suggest implementation. Do not write code. The output of this command is a structured pre-impl artifact plus a constraint list — not a plan.
