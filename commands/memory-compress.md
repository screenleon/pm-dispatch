---
description: Compress MEMORY.md index entries to reduce inject token usage.
argument-hint: "[--dry-run]"
---

Compress the MEMORY.md index for the current project's memory directory. Follow these steps exactly.

## What

`/memory-compress` rewrites the `MEMORY.md` index into a shorter, cheaper-to-load shape without changing the underlying memory facts.

## When to use

- When your inject footprint gets too large for routine sessions.
- Before sharing a fork to keep memory continuity efficient.
- Periodically, after repeated `/mem-distill` runs add new entries.

## Example

```sh
/memory-compress --dry-run
```

## Step 1 — Locate memory directory

Run:
```bash
mem="$(pmctl memory dir)" || { echo "No MEMORY.md found for this project"; exit 1; }
candidate="$mem/MEMORY.md"
[[ -f "$candidate" ]] || { echo "No MEMORY.md found for this project"; exit 1; }
echo "$candidate"
```

If `pmctl memory dir` exits non-zero, or `MEMORY.md` does not exist, report "No MEMORY.md found for this project" and stop.

## Step 2 — Read and inventory

Read the MEMORY.md file found in Step 1. Collect every line that starts with `- [` (index entries). Also note the total line count and entry count.

Report a brief summary:
```
Memory index: <N> entries, <L> total lines
Memory dir: <path>
```

## Step 3 — Read each linked file

For each index entry of the form `- [Title](file.md) — hook text`, read the linked `.md` file (it is in the same directory as MEMORY.md). Note the `name:`, `description:`, `metadata.type:` frontmatter fields and the body content.

## Step 4 — Produce compressed index

Apply these rules to produce a new index:

**Shorten hook text**: Rewrite each `— hook text` to be ≤ 15 words and ≤ 150 characters. Preserve the essential rule or fact. Remove filler phrases like "memory about", "information regarding", "note that".

**Merge overlapping entries**: If two or more entries cover the same topic (e.g., multiple `feedback` entries about the same workflow tool), merge them into one entry pointing to the most comprehensive file. The merged hook text combines the key rules from both.

**Flag stale entries**: An entry is stale if its linked file references a function, script path, or flag that no longer exists in the repo (check via Bash if unsure). Do NOT delete stale entries automatically — list them separately for user confirmation.

**Preserve all `[[name]]` cross-links**: Do not remove slugs from memory file bodies even if the hook line is rewritten.

**Format**: Each compressed entry must be exactly one line:
```
- [Title](file.md) — compressed hook text
```

## Step 5 — Show result and ask for confirmation

Display the new MEMORY.md content in full, followed by:
```
---
Before: <N_before> entries, <L_before> lines
After:  <N_after> entries, <L_after> lines
Merged: <list of merged pairs, or "none">
Flagged stale: <list of stale entries, or "none">
```

If `$ARGUMENTS` contains `--dry-run`, **stop here**. Do not write any files.

Otherwise, ask the user explicitly:
```
Apply this compression?
  - MEMORY.md will be overwritten (timestamped backup created first)
  - Merged source files will be renamed to <name>.archived (not deleted)
  - Stale entries will NOT be removed without a separate confirmation
Reply "yes" to proceed, anything else to cancel.
```

Do not proceed to Step 6 until the user replies "yes" (or equivalent affirmative).

## Step 6 — Write (non-dry-run, after confirmation)

1. **Backup first**: copy MEMORY.md to `MEMORY.md.bak.<YYYYMMDD-HHMMSS>` in the same directory.
2. Write the compressed content to MEMORY.md (overwrite).
3. If any entries were merged, update the surviving memory file's `description:` frontmatter to reflect the merged scope, then **rename** the redundant file(s) to `<filename>.archived` — do NOT delete them.
4. Report:
   ```
   Compressed: <N_before> → <N_after> entries. MEMORY.md updated.
   Backup: MEMORY.md.bak.<timestamp>
   Archived: <list of .archived files, or "none">
   ```

Do not remove stale entries without explicit user confirmation. List them separately and ask.
