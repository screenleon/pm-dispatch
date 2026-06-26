---
description: Inject recent session episodes into context for continuity across sessions.
argument-hint: "[N=5]"
---

Read and inject the most recent episodic memory entries into the current context.

## What

`/mem-recall` injects the most recent episodic summaries into the current context for continuity. It combines **recent** entries (last N) with **relevant** entries found via `pmctl context query --source memory`, so older episodes that match the current project are surfaced even when buried past the N window.

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

## Step 2b — Find relevant old episodes via context index (fallback gracefully)

Run `pmctl context query --source memory` to find older episodes relevant to the current project:

```bash
cwd_name="$(basename "$PWD")"
relevant_hits="$(pmctl context query --source memory -- "$cwd_name" 2>/dev/null || true)"
```

From `relevant_hits`, extract lines that reference `episodes` files (file paths containing `episodes`). Parse each hit's `date` and `summary` fields. Deduplicate against the recent-N set by `date` value. Keep at most 3 relevant hits that are not already in the recent-N set.

If `pmctl context query` fails (sqlite3 absent, index not built, or any error), skip this step silently — the recent-N set from Step 2 is sufficient.

## Step 3 — Display and inject

Merge the recent-N entries with the relevant hits from Step 2b. Sort the combined set by `date` descending. Format the entries as:

```
== Recent episodes (last <N> + up to 3 relevant) ==

[<date>] <cwd>
<summary>

[<date>] <cwd>
<summary>
...
== end episodes ==
```

Print this to the conversation so it becomes part of the active context. Then briefly summarize what you found: "Loaded N episode(s) from <project>."
