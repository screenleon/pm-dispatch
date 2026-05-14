---
description: Synthesize recent episodes into MEMORY.md updates (add/modify/remove entries).
argument-hint: "[--dry-run]"
---

Review recent session episodes and propose changes to the permanent memory index. Follow these steps.

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

If nothing is printed, report "No memory directory found" and stop.

## Step 2 — Read inputs

Read both:
1. **episodes.jsonl** — last 10 entries with non-empty summaries
2. **MEMORY.md** — current index (all `- [Title](file.md) — hook` entries)

## Step 3 — Identify changes

For each episode, ask: does this session reveal a fact or rule that should be permanently remembered?

Classify proposed changes:

| Type | Condition |
|------|-----------|
| **Add** | New durable rule/fact not yet in MEMORY.md |
| **Update** | Existing entry's hook text is now inaccurate or too vague |
| **Remove** | Entry refers to something resolved, merged, or no longer relevant |
| **No change** | Episode adds no permanent value (routine work, no new rules) |

**Only promote genuinely persistent, cross-session facts.** Do not add entries for task status, temporary decisions, or things already captured accurately in MEMORY.md.

## Step 4 — Show proposed changes

Present the changes as a diff-style list:

```
Proposed MEMORY.md changes:
  ADD  - [NewTopic](new-topic.md) — brief rule about X
  UPD  - [ExistingTopic](existing.md) — old hook → new hook
  DEL  - [StaleEntry](stale.md) — reason: merged in PR #44
  ---
  No change: 7 episodes, nothing new to promote
```

If no changes are needed, say so clearly.

If `$ARGUMENTS` contains `--dry-run`, **stop here**. Do not write any files.

## Step 5 — Confirm before writing (non-dry-run only)

Present the proposed changes from Step 4 to the user and ask:

> "Apply these <N> change(s) to MEMORY.md and the linked memory files? (yes/no)"

**Do not proceed until the user explicitly confirms with "yes" (or equivalent affirmative).** If the user declines or does not respond affirmatively, stop and report "Distillation cancelled — no changes written."

## Step 6 — Write changes

After explicit user confirmation, apply each change:

- **ADD**: Create the new memory file in the memory directory (using the standard frontmatter format); add the entry to MEMORY.md index.
- **UPDATE**: Edit the hook line in MEMORY.md; update the `description:` field in the linked memory file if needed.
- **REMOVE**: Remove the line from MEMORY.md index; do NOT delete the memory file (archive in place).

Report: "Distilled <N> episode(s) → <M> MEMORY.md change(s)."
