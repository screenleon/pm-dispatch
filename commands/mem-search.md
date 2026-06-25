---
description: Search across all memory files using keyword + semantic understanding.
argument-hint: "<query>"
---

Search the project memory for `$ARGUMENTS`. If no query is provided, ask the user what to search for.

## What

`/mem-search` performs keyword and semantic lookup across the memory directory. It queries the `pmctl context` index first (structured, ranked), then falls back to direct rg/grep if the index returns no results.

## When to use

- When you need a quick answer from existing memory cards before rewriting flow.
- When an implementation question depends on past decisions in this project.
- When a query has no clear file path and needs semantic triage.

## Example

```sh
/mem-search "hook bypass policy"
```

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

## Step 2 — Index query via pmctl context (primary path)

Run `pmctl context query --source memory <query>` via Python subprocess to avoid shell injection:

```python
python3 - << 'PYEOF'
import subprocess, sys

# Claude: replace the placeholders below with actual values,
# properly escaped for Python string syntax (use repr() if needed).
query = "QUERY_PLACEHOLDER"
memory_dir = "MEMORY_DIR_PLACEHOLDER"

result = subprocess.run(
    ['pmctl', 'context', 'query', '--source', 'memory', query],
    capture_output=True, text=True, cwd=memory_dir
)

refs = []
for line in result.stdout.splitlines():
    if line.startswith('- ref: '):
        ref = line[len('- ref: '):].strip()
        if ref:
            refs.append(ref)

if refs:
    print('\n'.join(refs))
PYEOF
```

Replace `QUERY_PLACEHOLDER` with the search query as a properly-escaped Python string literal. Replace `MEMORY_DIR_PLACEHOLDER` with the path from Step 1.

If refs are returned, these are the matching memory card paths. Proceed directly to Step 4 using these files — skip Step 3.

## Step 3 — Keyword search via rg/grep (fallback when index has no hits)

Run this only when Step 2 returned no refs (index unavailable or no hits).

```python
python3 - << 'PYEOF'
import subprocess, os, sys

query = "QUERY_PLACEHOLDER"
memory_dir = "MEMORY_DIR_PLACEHOLDER"

files = []
try:
    for name in os.listdir(memory_dir):
        if name.endswith('.md') or name == 'episodes.jsonl':
            files.append(os.path.join(memory_dir, name))
except OSError:
    sys.exit(0)

if not files or not query:
    sys.exit(0)

# -F: fixed-string (not regex), -i: case-insensitive, -l: filenames only
# subprocess raises FileNotFoundError (not returncode 127) when the binary
# is absent, so catch that explicitly before falling back to grep.
try:
    result = subprocess.run(
        ['rg', '-ilF', '--', query] + files,
        capture_output=True, text=True
    )
except FileNotFoundError:
    result = subprocess.run(
        ['grep', '-rilF', '--', query] + files,
        capture_output=True, text=True
    )
print(result.stdout.strip())
PYEOF
```

Replace `QUERY_PLACEHOLDER` and `MEMORY_DIR_PLACEHOLDER` with the actual values from Steps 1 and the original query.

## Step 4 — Semantic search (fallback when Steps 2 and 3 both empty)

If no files were found in Steps 2 or 3, read MEMORY.md and identify entries whose hook text or title is semantically related to the query — even if the exact words don't appear. Read those linked files.

## Step 5 — Read and synthesize

Read all files found in Steps 2, 3, or 4. Answer the question implied by the query:
- What does the memory say about this topic?
- Are there conflicting or overlapping entries?
- Is the memory potentially stale (references old code/decisions)?

## Step 6 — Report

```
## Memory search: "<query>"

Found in <N> file(s):

**<filename>** (<type>: feedback/project/user/reference)
> <relevant excerpt or summary>

**episodes.jsonl** (if applicable)
> [<date>] <relevant episode summary>

Source: <memory_dir>
```

If nothing was found in any layer, say "No memory found for '<query>'. Consider running /mem-log if this session covers relevant ground."
