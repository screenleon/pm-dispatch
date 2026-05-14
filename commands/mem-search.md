---
description: Search across all memory files using keyword + semantic understanding.
argument-hint: "<query>"
---

Search the project memory for `$ARGUMENTS`. If no query is provided, ask the user what to search for.

## Step 1 — Find memory directory

```bash
python3 -c "
import os
cwd = os.getcwd()
config = os.environ.get('CLAUDE_CONFIG_DIR', os.path.expanduser('~/.claude'))
projects = os.path.join(config, 'projects')
current = cwd.rstrip('/')
while True:
    encoded = '-' + current.lstrip('/').replace('/', '-')
    mem = os.path.join(projects, encoded, 'memory')
    if os.path.isdir(mem):
        print(mem)
        break
    parent = os.path.dirname(current)
    if parent == current:
        break
    current = parent
"
```

If nothing is printed, report "No memory directory found for this project" and stop.

## Step 2 — Keyword search (Layer 1)

```bash
rg -il "<QUERY>" <MEMORY_DIR>/*.md <MEMORY_DIR>/episodes.jsonl 2>/dev/null || true
```

Replace `<QUERY>` with `$ARGUMENTS` and `<MEMORY_DIR>` with the path from Step 1.

If `rg` is not available, fall back to:
```bash
grep -ril "<QUERY>" <MEMORY_DIR>/ 2>/dev/null || true
```

## Step 3 — Semantic search (Layer 2, fallback)

If no files were found in Step 2, read MEMORY.md and identify entries whose hook text or title is semantically related to the query — even if the exact words don't appear. Read those linked files.

## Step 4 — Read and synthesize

Read all files found in Steps 2 or 3. Answer the question implied by the query:
- What does the memory say about this topic?
- Are there conflicting or overlapping entries?
- Is the memory potentially stale (references old code/decisions)?

## Step 5 — Report

```
## Memory search: "<query>"

Found in <N> file(s):

**<filename>** (<type>: feedback/project/user/reference)
> <relevant excerpt or summary>

**episodes.jsonl** (if applicable)
> [<date>] <relevant episode summary>

Source: <memory_dir>
```

If nothing was found in either layer, say "No memory found for '<query>'. Consider running /mem-log if this session covers relevant ground."
