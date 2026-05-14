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

**Do not embed `$ARGUMENTS` in any shell command string.** Use Python with `subprocess` so the query is never parsed by a shell:

```python
python3 - << 'PYEOF'
import subprocess, os, sys

# Assign query and memory_dir as Python string literals.
# Claude: replace the placeholders below with the actual values,
# properly escaped for Python string syntax (use repr() if needed).
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
# Argument list — query is never parsed by a shell.
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

Replace `QUERY_PLACEHOLDER` with the search query as a properly-escaped Python string literal. Replace `MEMORY_DIR_PLACEHOLDER` with the path from Step 1.

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
