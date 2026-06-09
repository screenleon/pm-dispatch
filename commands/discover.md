---
description: Divergent-mode opportunity scan — reads backlog + decisions + milestones and outputs a ranked leverage list for milestone planning.
argument-hint: "[theme, e.g. 'v0.5.0 themes', 'dispatch improvements']"
---

Scan the current project for high-leverage improvement opportunities and output a ranked list. Switch into **divergent mode** — the goal is breadth of options, not commitment to any.

## What

`/discover` reads the project's accumulated intent (backlog deferred/someday items, decisions, milestone scope, recent git activity) and surfaces 5–10 opportunities ranked by leverage. It is a **milestone seeder** — the output is a menu for the user to pick from, not a plan.

## When to use

- Before planning a new milestone and you want a systematic "what should we do next?"
- When active work completes and you want to see what's high-leverage before the next stretch
- When you want to explore themes or areas beyond the current active tickets

## Example

```sh
/discover
/discover v0.5.0 themes
/discover dispatch pipeline improvements
```

## Step 1 — Locate project files

Check that the required files exist:

```bash
ls BACKLOG.md DECISIONS.md MILESTONES.md 2>/dev/null
```

Report each missing file explicitly and stop if any are absent:
- `BACKLOG.md` missing → "No BACKLOG.md found — /discover requires a pm-dispatch project"
- `DECISIONS.md` missing → "No DECISIONS.md found — design context unavailable; /discover cannot run"
- `MILESTONES.md` missing → "No MILESTONES.md found — milestone scope unavailable; /discover cannot run"

## Step 2 — Extract backlog opportunities

Read `BACKLOG.md` and collect all entries whose status marker is any of the open/deferred states:
- `🟢 someday` — explicitly queued for future consideration
- `⏸ deferred` — explicitly deferred (non-emoji form)
- `🟡 deferred` — deferred with caution flag (also a live deferred state)

Skip `✅ done`, `🔵 active`, and `⚠️ partial` — those are either finished or already in progress.

For each entry record: ticket id, one-line description, priority label (`P0`–`P3` or blank), tag (e.g. `arch`, `ux`, `ops`, `process`, `test`).

## Step 3 — Read context

Read in order:

1. **DECISIONS.md** — last 10 entries (bottom of file) for recent design constraints and intent
2. **MILESTONES.md** — locate the first milestone section without a `✅` on its heading; read its Phase breakdown to understand the current scope boundary
3. **Recent git activity** — run:

   ```bash
   git log --oneline -30
   ```

   Scan the commit subjects for themes: what shipped recently, what area has been moving.

## Step 4 — Filter by theme (if provided)

If `$ARGUMENTS` is non-empty, narrow the candidate set to entries related to that theme. "Related" means: the description, tag, or dependent tickets match the theme keyword — fuzzy match is fine.

If `$ARGUMENTS` is empty, scan the full candidate set globally.

## Step 5 — Rank by leverage

For each candidate, evaluate three axes:

| Axis | Question |
|---|---|
| **Impact** | Does completing this unblock other work, reduce recurring debt, or improve measurable DX? |
| **Why now** | Does the current project state make this timely — recent decision creates a clear path, or a related ticket just shipped? |
| **Size** | XS (< half day), S (1 day), M (2–3 days), L (week+) |

Rank by `(impact × timeliness) / size`. Surface the top 5–10. Prefer items where the "why now" signal is strong (a dependency just landed, a gap just became visible).

## Step 6 — Output

Produce the discovery report in this format:

```
## /discover — <theme or "all areas"> — <YYYY-MM-DD>

| # | Title | Problem | Why now | Size |
|---|---|---|---|---|
| 1 | <short title> | <one sentence: what problem this solves> | <one sentence: why this moment is right> | XS |
| 2 | … | … | … | S |
…

**Top pick**: <ticket id if applicable> — <one-sentence rationale for why this is the highest-leverage next step>
```

Close with one line:

> *These are options, not commitments. To act on one, use `/pm` to open or plan the ticket.*

**Hard constraints on the output**:
- Do not write a dispatch brief
- Do not suggest implementation steps
- Do not open or modify tickets
- Do not rank active or done items — divergent mode reads only the open opportunity space
