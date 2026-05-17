---
description: Pre-implementation design review — define boundaries, dependencies, and change seams before writing any code.
argument-hint: "<feature description, e.g. 'add OAuth login to the API'>"
---

Run a design review for `$ARGUMENTS` before any implementation starts. If no argument is provided, ask the user what feature they are about to implement.

The goal is to produce a **design constraint list** — 3–5 structural rules the implementation must not violate — that can be pasted directly into a PM brief's `constraints:` field.

## When to invoke

PM **must** run `/pre-impl` before writing a Codex brief whenever the brief introduces **3 or more behavioral units** (new functions, endpoints, hooks, commands, or schema changes). For single-unit changes, it is optional but recommended when the change touches a module boundary or a shared dependency.

The design constraint list produced here should be pasted into the brief's `constraints:` field so Codex implements with the constraints from the start, not after an architecture-reviewer flag.

## What

`/pre-impl` produces a short constraint list for broader changes so implementation work stays within a safe boundary.

## When to use

- Before introducing three or more new behavioral units.
- Before touching shared modules, schema files, or reviewer flow surfaces.
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

## Step 2 — Answer the three mandatory design questions

You **must** answer all three before producing output. Do not skip or merge questions.

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

## Step 3 — Produce the design constraint list

Based on the three answers above, synthesize 3–5 constraints. Each constraint must be:
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

## Step 4 — Optional: flag risks

If any of the three questions revealed a dependency or boundary that is particularly risky (e.g., touches auth, modifies shared schema, introduces a new cross-layer dependency), add a brief `## Risk flags` section after the constraints listing the specific concern. Keep it to 1–3 bullets.

Do not suggest implementation. Do not write code. The output of this command is constraints, not a plan.
