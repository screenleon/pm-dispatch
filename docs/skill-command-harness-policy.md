# Where new behavior belongs: prompt, skill, command, or harness

`pm-dispatch` is a three-layer stack: the native Claude Code harness, the
`pm-dispatch` control plane (`pmctl`, guards, state store), and a replaceable
layer of skills/commands/agents on top. That framing is accurate, but until
now nothing wrote down *when new work should land at which layer* — so
placement drifted by convenience rather than by rule, and the same
command/skill terminology confusion kept resurfacing (see `docs/CONCEPTS.md`
Concept 2, historically titled "Slash commands (skills)").

This document is the classification. It replaces ad hoc judgment calls with
four testable tiers.

## Instruction budget — read this before the tiers

Longer prompts do not fail gracefully. As instruction count rises inside one
prompt, instruction-following accuracy drops in a measurable, systematic way,
and the drop is worse for instructions placed later in the prompt — the
model favors earlier constraints over later ones. Frontier models sit around
68% accuracy at roughly 500 simultaneous instructions.
(Source: IFScale, arXiv:2507.11538, 2025-07.)

Two things follow, and they constrain every tier below:

1. **Every tier keeps a hard ceiling on how much text loads into one turn.**
   The tiers below aren't just "where does this file live" — they're "how
   much of it is *always* in context vs. loaded only when relevant."
2. **Put load-bearing constraints early, not late.** A rule buried at line
   400 of a long prompt competes with everything before it for the model's
   attention. If a constraint is safety-relevant or contract-defining, it
   belongs near the top of whatever file carries it — this document does
   that with the tiers themselves, and every skill/command file in this repo
   should do the same with its own most important rule.

## The four tiers

| Tier | Trigger | Where it lands | Contract |
|---|---|---|---|
| **1 — Prompt** | First occurrence, low frequency, no side effect | Nowhere — stays in the conversation | None; if it recurs, promote it |
| **2 — Skill** | Repeats 2-3+ times across repos/sessions, is resumable mid-way, touches no permission boundary | `skills/<name>/SKILL.md` | Thin pointer only — no state transition, no guard bypass |
| **3 — Command** | Needs the user to actively type `/foo`, or needs argument parsing | `commands/<name>.md` | Can be a thin launcher that hands off to a skill or to `pmctl` |
| **4 — Harness** | Needs hard enforcement, persistent state, mechanical evidence, or lifecycle control | `pmctl` / `core/` / a guard hook | Structural — the harness enforces it even if the prompt is silent |

Read the trigger column as a decision order, not a menu: ask "does this need
Tier 4?" first, then 3, then 2, and only stays at Tier 1 if none apply.

### Tier 1 ↔ Tier 4 boundary: degrees of freedom

The dividing line between "leave it as prose" and "make it a script/hook"
is how much judgment the situation actually requires. Multiple valid
approaches, decided per-situation → it belongs in text, because codifying
it would just be picking one approach and forbidding the others. An
operation that is fragile, error-prone by hand, needs strict consistency,
or must happen in a fixed order → it belongs in a script or validator,
because a human (or a model) will eventually skip a step under time
pressure and the failure will be silent.
(Source: <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md>)

This repo already lives this principle without having named it:
`DECISIONS.md` 2026-05-19 `cc030-validate-bidirectional` put it exactly —
"prompt-layer enforcement is not reliable; a structural validator is the
only durable boundary." That decision and this tier boundary reinforce each
other.

### Tier 2 sizing: progressive disclosure

A skill has two parts with two different loading rules: `name` +
`description` in frontmatter load into every session's metadata; the body
loads only when the skill is actually invoked. That split only pays off if
the parts stay small enough to matter:

- `description` ≤ 1,024 characters (it's always-loaded, so it competes with
  everything else that's always loaded)
- `SKILL.md` body < 500 lines
- reference files live one level deep from `SKILL.md` (a deeper link gets
  partially read, not fully read)
- any reference file over 100 lines needs a table of contents at the top

(Source: same best-practices page as above.)

**Current state (2026-08-22, re-measured — do not read this doc's numbers as
current after this date without re-checking):** all three current skills are
comfortably under the body limit — `skills/dispatch-brief/SKILL.md` is 59
lines, `skills/pr-gate-review/SKILL.md` is 76, and
`skills/systematic-debugging/SKILL.md` is 53. The single largest prompt asset
in the repo today is `commands/pr-gate.md` at 482 lines — a *command*,
not a skill, so the 500-line skill-body ceiling doesn't formally bind it,
but it is close enough to that ceiling that any further growth there should
prompt a split rather than an extension. **This section records the current
state as compliant; it is not a mandate to rewrite any existing file.**

## Tier 3 vs. Tier 2 — the actual discriminator

It is tempting to read Tier 3 as "workflow" and Tier 2 as "method," but
that's not what separates them here. `commands/research.md`,
`commands/pre-impl.md`, and `commands/using-git-worktrees.md` are pure
methodology with no state transitions — yet they correctly stay commands,
because the real Tier 3 trigger is narrower and purely mechanical: **does
invoking this require the user to type `/foo`, or does it need argument
parsing?** All three do. A skill, by contrast, is meant to be picked up by
Claude on its own when the situation matches its `description`, without the
user needing to know its name or type anything.

So the inventory below sorts by that mechanical test, not by a "feels like a
workflow" judgment call.

## Inventory (2026-08-22)

Not a rewrite plan — this records where each existing file sits against the
tiers above and calls out the handful that are worth watching.

### `commands/` (Tier 3 — all correctly commands; `/foo`-invoked)

| File | Note |
|---|---|
| `pm.md`, `pr-gate.md`, `ship.md` | Tier 4-adjacent — thin launchers over `pmctl`/guard-enforced workflows. Correctly placed: they need `/foo` invocation *and* hand off to harness-level enforcement immediately. |
| `pre-impl.md`, `research.md`, `using-git-worktrees.md` | Pure methodology, no state transition — but each needs explicit `/foo` invocation or argument parsing (a topic, a feature description, a branch name), which is exactly the Tier 3 trigger. Correctly placed. |
| `discover.md`, `pre-release.md` | Same shape as above — read-only analysis commands, user-triggered. Correctly placed. |
| `mem-recall.md`, `mem-log.md`, `mem-search.md`, `mem-distill.md`, `memory-compress.md`, `skill-refine.md` | User-triggered memory operations. Correctly placed. |

### `skills/` (Tier 2 — thin pointers, no state transition)

| File | Note |
|---|---|
| `dispatch-brief/SKILL.md`, `pr-gate-review/SKILL.md` | Both match the Tier 2 contract exactly: picked up by relevance, not by name; point at authoritative sources rather than restating them; well under the size ceiling. |
| `systematic-debugging/SKILL.md` | A Tier 2 method pointer for bug, regression, and failing-test work: picked up by relevance, carries no state transition or guard bypass, and directs verification through existing tests and git evidence. |

### `agents/` (not covered by this tier system — separate primitive)

Subagents (`agents/*.md`) are a distinct Claude Code primitive (see
`docs/CONCEPTS.md` Concept 3) with their own contract — an independent
session, its own tool allowlist, one-shot return. They are not classified by
this document; the question this policy answers ("prompt, skill, command, or
harness") doesn't have a subagent option, because a subagent is a *runtime*
choice about isolation, not a placement choice about durability.

### Suggested migrations

None. Every file inventoried above already sits at the tier its trigger
implies. This is itself useful to have on record: it means the historical
command/skill confusion in `docs/CONCEPTS.md` was a **naming** problem, not
a **placement** problem — the files were already in the right place, only
the concept explaining "why" was missing.

## Downstream tickets already gated on this document

[[CC-015]], [[CC-026]], and [[CC-054]] each already deferred their own scope
pending this classification, and each already named `skills/<name>/SKILL.md`
(not `commands/`) as their target — confirmed here, not changed: a
skill-shaped deliverable that repeats across sessions and touches no
permission boundary is exactly the Tier 2 case above. They can now cite this
document instead of "pending CC-493."

## Non-goals

This document does not:

- Migrate or rewrite any existing `commands/`/`skills/`/`agents/` file (see
  [[CC-357]] for a machine-readable skill schema, [[CC-393]] for a
  CLI-agnostic skill substrate — both separate, larger efforts this document
  does not replace).
- Mandate a rewrite of any prompt asset for length — every asset in the repo
  is already under the cited thresholds.
