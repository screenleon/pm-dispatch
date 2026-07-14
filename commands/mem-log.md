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

## Step 1 — Confirm canonical memory

Resolve the same strict canonical memory that every host uses:

```bash
pmctl memory resolve --repo-root "$(pwd)" --json
```

If resolution is unavailable or an explicit path is invalid, report the resolver error and stop. Never derive or guess a host-local path.

## Step 2 — Write the summary

Think about this session: what was accomplished, what decisions were made, what new rules or facts emerged that future sessions should know?

Write a summary of **3–5 lines** covering:
- The main task or goal worked on
- Key decisions or design choices made
- Any new persistent rules or facts discovered (if none, omit)
- Blockers or unresolved items (if any)

If `$ARGUMENTS` is non-empty, incorporate it as a hint about what to emphasize.

Keep the summary factual and dense. No filler phrases.

## Step 3 — Append through the strict write API

Call the host-neutral writer; do not open or mutate `episodes.jsonl` directly:

```bash
pmctl memory append-episode \
  --repo-root "$(pwd)" \
  --host claude \
  --session-id "" \
  --summary "$SUMMARY" \
  --json
```

`session_id` may be unavailable from a slash command; use `""` in that case. The API re-runs strict resolution, appends under a lock, rejects a symlink target, and fails closed instead of falling through to another host's memory.

## Step 4 — Confirm

Print:
```
Logged: <date> — <first line of summary>
```
