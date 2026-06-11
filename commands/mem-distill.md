---
description: Synthesize recent episodes and run anomalies into MEMORY.md updates (add/modify/remove entries).
argument-hint: "[--dry-run]"
---

Review recent session episodes **and** run failure events, then propose changes to the permanent memory index. Follow these steps.

## What

`/mem-distill` turns recent `/mem-log` sessions **and** `run.failed` / `guard.denied` / `task.blocked` events into a durable MEMORY index plan, proposing add/update/remove actions without writing until confirmed.

## When to use

- When a session produced new rules that should persist beyond one recall window.
- Before creating or editing `MEMORY.md` to avoid duplicating long-lived facts.
- When you want a clean handoff from episodic notes to durable cards.
- Periodically, to surface recurring failure patterns as operational feedback.

## Example

```sh
/mem-distill --dry-run
```

## Step 1 — Find memory directory

```bash
config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
current="$(pwd)"
while [[ "$current" != "/" ]]; do
    encoded="-${current#/}"
    encoded="${encoded//\//-}"
    mem="$config/projects/$encoded/memory"
    if [[ -d "$mem" ]]; then echo "$mem"; break; fi
    current="$(dirname "$current")"
done
```

If nothing is printed, report "No memory directory found" and stop.

## Step 2 — Read episode inputs

Read both:
1. **episodes.jsonl** — last 10 entries with non-empty summaries
2. **MEMORY.md** — current index (all `- [Title](file.md) — hook` entries)

## Step 2b — Read anomaly slice

Run these commands to fetch recent anomaly events:

```bash
pmctl trace tail --kind run.failed     --json -n 30
pmctl trace tail --kind guard.denied   --json -n 20
pmctl trace tail --kind task.blocked   --json -n 20
pmctl trace tail --kind review.verdict --json -n 20
```

If `review.verdict` returns no output (events not yet written by the gate), fall back to scanning gate result files for blocked verdicts:

```bash
ls -t .gate-results/gate-*.md 2>/dev/null | head -10 | xargs grep -l "Final: NO-GO" 2>/dev/null
```

Payload fields differ by kind — do not apply run-shaped fields to guard, task, or review events:

| kind | key payload fields |
|------|--------------------|
| `run.failed` | `payload.adapter`, `payload.exit_code`, `subject_id` (run-id) |
| `guard.denied` | `payload.path` (denied file path), `subject_id` |
| `task.blocked` | `payload.from_state`, `payload.to_state`, `subject_id` (task-id) |
| `review.verdict` | `payload.verdict` (block/block-soft/advise/approve), `payload.reviewer`, `subject_id` |

Build a separate summary table per kind. For `run.failed`:

| id | subject_id | ts | adapter | exit_code | exit_class |
|----|------------|----|---------|-----------|------------|
| evt-... | run-... | ... | codex  | 124       | timeout    |
| evt-... | run-... | ... | claude | 1         | failure    |

Exit class rules (run.failed only):
- exit_code == 124 → `timeout`
- exit_code == 0 → `ok` (skip — not an anomaly)
- any other non-zero → `failure`

Ignore events older than 60 days. If all four commands return no output and no NO-GO gate files exist, skip this step.

## Step 3 — Identify changes

### 3a — From episodes

For each episode, ask: does this session reveal a fact or rule that should be permanently remembered?

| Type | Condition |
|------|-----------|
| **Add** | New durable rule/fact not yet in MEMORY.md |
| **Update** | Existing entry's hook text is now inaccurate or too vague |
| **Remove** | Entry refers to something resolved, merged, or no longer relevant |
| **No change** | Episode adds no permanent value (routine work, no new rules) |

### 3b — From anomalies

Group and analyze **per kind**:

- **`run.failed`**: group by `(adapter, exit_class)`.
  - **≥ 2 occurrences**: candidate for a `feedback` memory card describing the recurring failure pattern.
  - **1 occurrence, exit_class == timeout**: candidate only if no existing memory card already covers this adapter's timeout behaviour.

- **`guard.denied`**: group by the denied path prefix (`payload.path`); ≥ 2 denials on the same prefix → candidate for a policy or workflow feedback card.

- **`task.blocked`**: group by `(from_state, to_state)` transition pair; ≥ 2 occurrences of the same blocked transition → candidate for a workflow friction card.

- **`review.verdict` (block/block-soft) / gate NO-GO files**: group by `payload.reviewer` (or reviewer name parsed from gate file); ≥ 2 blocked verdicts from the same reviewer area → candidate for a feedback card capturing the recurring gate-block pattern. For gate file fallback, extract reviewer block lines from the `## <reviewer> -- block` sections.

- Skip any anomaly where the same `subject_id` (run) was followed by a successful run on the same adapter, or where context makes clear the failure is already resolved (e.g., the brief_file name corresponds to a ticket now `✅ closed` in BACKLOG.md).

**Evidence**: When proposing an anomaly-derived card, cite the event `id`(s) that evidence the pattern (e.g. `evt-20260611T100000Z-abc123`). Where the anomaly date range overlaps an episode in `episodes.jsonl`, note the episode line number for cross-reference.

**Only promote genuinely persistent, cross-session patterns.** A one-time fluke is not a memory card.

## Step 4 — Show proposed changes

Present the changes as a diff-style list, with episode-derived and anomaly-derived proposals clearly separated:

```
Proposed MEMORY.md changes:

[from episodes]
  ADD  - [NewTopic](new-topic.md) — brief rule about X
  UPD  - [ExistingTopic](existing.md) — old hook → new hook
  ---
  No change: 7 episodes, nothing new to promote

[from anomalies]
  ADD  - [RunnerTimeout](feedback_runner_timeout.md) — claude adapter times out (exit 124) at verifying stage; use codex for long-running tasks
  ---
  Skipped: 3 anomalies (resolved tickets); 2 grouped into above card
```

If no changes are needed in either section, say so clearly.

If `$ARGUMENTS` contains `--dry-run`, **stop here**. Do not write any files.

## Step 5 — Confirm before writing (non-dry-run only)

Present the proposed changes from Step 4 to the user and ask:

> "Apply these <N> change(s) to MEMORY.md and the linked memory files? (yes/no)"

**Do not proceed until the user explicitly confirms with "yes" (or equivalent affirmative).** If the user declines or does not respond affirmatively, stop and report "Distillation cancelled — no changes written."

## Step 6 — Write changes

After explicit user confirmation, apply each change:

- **ADD**: Create the new memory file in the memory directory (using the standard frontmatter format); add the entry to MEMORY.md index.
- **UPDATE**: Edit the hook line in MEMORY.md; update the `description:` field in the linked memory file if needed.
- **REMOVE**: Remove the line from MEMORY.md index; do NOT delete the memory file (archive in place).

Report: "Distilled <N> episode(s) + <A> anomaly group(s) → <M> MEMORY.md change(s)."
