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
memory_dir="$(pmctl memory dir)" || { echo "No memory directory found for this project"; exit 1; }
```

If `pmctl memory dir` exits non-zero, report "No memory directory found for this project" and stop.

## Step 2 — Index query via pmctl context (primary path)

Run `pmctl context query "$(pwd)" --source memory -- "$query"` to query the index. Using `$(pwd)` scopes the lookup to this project's memory automatically — `pmctl context query` walks up to find the correct project. The `--` separator before `"$query"` prevents injection.

```bash
pmctl_out="$(pmctl context query "$(pwd)" --source memory -- "$query" 2>/dev/null)"
pmctl_exit=$?
```

Parse `$pmctl_out` for lines starting with `- ref: ` (strip the prefix, trim whitespace) and collect the file paths as refs.

On nonzero exit (query failure), print a warning to stderr and fall through to Step 3.

If the output contains `# no hits`, fall through to Step 3.

If refs are found, these are the matching memory card paths. Proceed directly to Step 5 using these files — skip Steps 3 and 4.

If no refs are printed (no hits → `# no hits for: …` in stdout) or `$pmctl_exit` is nonzero (query failure → warning on stderr), fall through to Step 3.

## Step 3 — Keyword search via rg/grep (fallback when index has no hits)

Run this only when Step 2 returned no refs (index unavailable or no hits).

```bash
files=()
while IFS= read -r f; do files+=("$f"); done < <(
    find "$memory_dir" -maxdepth 1 \( -name "*.md" -o -name "episodes.jsonl" \) 2>/dev/null
)
if [[ ${#files[@]} -gt 0 ]] && [[ -n "$query" ]]; then
    rg -ilF -- "$query" "${files[@]}" 2>/dev/null || grep -rilF -- "$query" "${files[@]}" 2>/dev/null
fi
```

Use `$memory_dir` (first line from Step 1) and `$query` (the original search query). The `--` separator prevents injection. `-F` uses fixed-string (not regex), `-i` is case-insensitive, `-l` returns filenames only.

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
