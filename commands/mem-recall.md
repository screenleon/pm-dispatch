---
description: Inject recent session episodes into context for continuity across sessions.
argument-hint: "[N=5]"
---

Read and inject the most recent episodic memory entries into the current context.

## What

`/mem-recall` injects the most recent episodic summaries into the current context for continuity.

## When to use

- Before work where project state has drifted and you need a short memory refresh.
- When `/pm` or `/pr-gate` should inherit session-level context.
- When there is no confidence that you remember why a recent decision was made.

## Example

```sh
/mem-recall 8
```

## Step 1 — Find episodes.jsonl

```bash
mem="$(pmctl memory dir)" || { echo "No episodes found for this project"; exit 1; }
ep="$mem/episodes.jsonl"
[[ -f "$ep" ]] || { echo "No episodes found for this project"; exit 1; }
```

If `pmctl memory dir` exits non-zero, or the episodes file does not exist, report "No episodes found for this project" and stop.

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
