---
description: Inject recent session episodes into context for continuity across sessions.
argument-hint: "[N=5]"
---

Read and inject the most recent episodic memory entries into the current context.

## Step 1 — Find episodes.jsonl

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
    if os.path.isfile(ep):
        print(ep)
        break
    parent = os.path.dirname(current)
    if parent == current:
        break
    current = parent
"
```

If nothing is printed, report "No episodes found for this project" and stop.

## Step 2 — Read last N entries

Parse `$ARGUMENTS` for an integer N (default: 5). Read the last N lines of episodes.jsonl that have a non-empty `summary` field. Ignore skeleton entries with `"summary": ""`.

## Step 3 — Display and inject

Format the entries as:

```
== Recent episodes (last <N>) ==

[<date>] <cwd>
<summary>

[<date>] <cwd>
<summary>
...
== end episodes ==
```

Print this to the conversation so it becomes part of the active context. Then briefly summarize what you found: "Loaded N episode(s) from <project>."
