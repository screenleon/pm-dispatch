---
description: Switch response compression mode to reduce token usage in long sessions. Modes: off / lite / full / ultra.
argument-hint: "[off|lite|full|ultra]"
---

Set response compression mode for this session. If no argument is given, print current mode and available options.

> **Note:** Agent-to-agent communication (briefs, reviewer findings, handover blocks) is already compact by default — that's baked into the agent instruction files. `/caveman` only affects responses Claude sends *to you* in the main session. Use it when you personally want shorter replies, not to save inter-agent tokens.

## What

`/caveman` trades response verbosity for token efficiency in the main conversation.

| Mode | Style | Typical reduction |
|------|-------|-------------------|
| `off` | Default — full prose, explanations, trailing summaries | baseline |
| `lite` | Cut filler; keep structure. Bullets over prose. No trailing summaries. | ~25% |
| `full` | Bullets only. No intros or summaries. Code over prose. | ~50% |
| `ultra` | Absolute minimum. Fragment sentences OK. Max signal/token. | ~70% |

## When to use

- `lite` — Long interactive sessions where you want quicker scans
- `full` — Bulk diff review, you just want the facts
- `ultra` — Context-window emergency; approaching token limit

## Example

```sh
/caveman lite       # set lite mode for this session
/caveman full       # escalate mid-session
/caveman off        # restore normal verbosity
/caveman            # show current mode
```

## Step 1 — Parse argument

Read `$ARGUMENTS` (trimmed). Valid values: `off`, `lite`, `full`, `ultra`.

If empty or unrecognized, print:

```
Caveman mode: off (default)
Available: off | lite | full | ultra
```

Then stop — do not proceed to Step 2.

## Step 2 — Confirm and apply

Print exactly one line: `Caveman mode: <MODE>` — nothing else.

Apply the rules below for **all subsequent responses in this session**.

---

### Rules: off

No changes. Respond normally.

---

### Rules: lite

- No opening sentence that restates the user's question
- No trailing summary ("What changed and what's next" style)
- Prefer bullet lists over prose paragraphs
- Keep code blocks and tables unchanged
- Tool call `description` field: one short clause

---

### Rules: full

- Bullets only — no prose paragraphs
- No section headers unless the response has 4+ distinct topics
- No preamble ("Let me…", "I'll now…", "Here's what…")
- No closing summary
- Show the diff or code block; skip the surrounding explanation
- Tool call `description` field: 3 words max

---

### Rules: ultra

- Fragment sentences acceptable: "Fixed. Pushed. Done."
- Skip articles where unambiguous: "File updated" not "The file was updated"
- No bullet symbols — plain lines only
- No headers
- Single-word acknowledgements: "Done", "OK", "Fixed"
- Tool call `description` field: omit entirely if obvious from tool name
