---
description: Record a semantic summary of the current session to episodes.jsonl.
argument-hint: "[brief note to include in summary]"
---

Record what happened in this session to the episodic memory layer. Follow these steps.

## Step 1 — Find episodes.jsonl

Run the same project-lookup as the memory inject hook:

```bash
python3 -c "
import os
cwd = os.getcwd()
config = os.environ.get('CLAUDE_CONFIG_DIR', os.path.expanduser('~/.claude'))
projects = os.path.join(config, 'projects')
current = cwd.rstrip('/')
while True:
    encoded = '-' + current.lstrip('/').replace('/', '-')
    ep = os.path.join(projects, encoded, 'memory', 'episodes.jsonl')
    if os.path.exists(os.path.dirname(ep)):
        print(ep)
        break
    parent = os.path.dirname(current)
    if parent == current:
        break
    current = parent
"
```

If nothing is printed, report "No memory directory found for this project" and stop.

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

Read the episodes.jsonl file. Find the **last entry** where `session_id` matches the current session (the Stop hook should have already written a skeleton entry with `"summary": ""`).

- If a matching skeleton entry exists: overwrite it with the full entry (same date/cwd/session_id, add the summary).
- If no matching entry exists: append a new entry.

The entry format:
```json
{"date":"<ISO8601>","cwd":"<absolute path>","session_id":"<id>","summary":"<3-5 line text>"}
```

To get the current session_id, check if it is available in the hook payload context. If not, use an empty string.

Write the updated file (overwrite the matching line, preserve all other lines).

## Step 4 — Confirm

Print:
```
Logged: <date> — <first line of summary>
```
