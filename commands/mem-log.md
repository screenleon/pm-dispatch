---
description: Record a semantic summary of the current session to episodes.jsonl.
argument-hint: "[brief note to include in summary]"
---

Record what happened in this session to the episodic memory layer. Follow these steps.

## What

`/mem-log` records the active session summary into episodic memory so future sessions can recall what was decided and why.

## When to use

- When a session adds durable context for later continuity or `/mem-recall`.
- When a brief, evidence-based summary is needed before handoff.
- When you need a durable fallback when session recall is the only memory source.

## Example

```sh
/mem-log "Session delivered first-pass migration plan and closed a hook exception."
```

## Step 1 — Find episodes.jsonl

Run `pmctl memory dir` to locate the memory directory, then derive the episodes path:

```bash
mem="$(pmctl memory dir)" || { echo "No memory directory found for this project"; exit 1; }
ep="$mem/episodes.jsonl"
```

If `pmctl memory dir` exits non-zero, report "No memory directory found for this project" and stop. The file `$ep` may not exist yet — that is expected when logging for the first time.

## Step 2 — Write the summary

Think about this session: what was accomplished, what decisions were made, what new rules or facts emerged that future sessions should know?

Write a summary of **3–5 lines** covering:
- The main task or goal worked on
- Key decisions or design choices made
- Any new persistent rules or facts discovered (if none, omit)
- Blockers or unresolved items (if any)

If `$ARGUMENTS` is non-empty, incorporate it as a hint about what to emphasize.

Keep the summary factual and dense. No filler phrases.

## Step 3 — Update episodes.jsonl

**/mem-log owns summary creation.** Do not assume the Stop hook has already written a skeleton — the Stop hook runs at session end, after /mem-log. If a skeleton already exists (e.g., from a previous session), update it; otherwise append a new entry.

Read the episodes.jsonl file (it may not exist yet). Then:

1. **Find an updatable entry**: scan all lines for one where `session_id` matches the current session AND `summary` is empty. If found, replace that line with the full entry (same `date`/`cwd`/`session_id`, filled `summary`).
2. **Otherwise**: append a new entry with the current date and cwd.

The entry format:
```json
{"date":"<ISO8601>","cwd":"<absolute path>","session_id":"<id>","summary":"<3-5 line text>"}
```

`session_id` is only available inside hook payloads; from a slash command it may not be accessible. Use an empty string `""` if it is unknown — the Stop hook will still skip this session correctly if the last entry for this cwd already has a non-empty summary.

Write the updated file (replace the matched line in-place or append; preserve all other lines).

## Step 4 — Confirm

Print:
```
Logged: <date> — <first line of summary>
```
