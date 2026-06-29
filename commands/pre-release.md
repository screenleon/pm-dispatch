---
description: Run pre-release audit for a milestone — Layer 1 structural checks, Layer 2 semantic diff coverage, and Layer 3 blind-spot declaration.
argument-hint: "<milestone-id>"
---

Run the pre-release audit via `pmctl pre-release audit <milestone-id>`.
This command covers **Layer 1** (machine-executable structural checks),
**Layer 2** (main-thread semantic diff coverage), and
**Layer 3** (static blind-spot declaration).

**Output is a report — not a GO/NO-GO verdict.** The release decision remains
with the user.

## Step 1 — Locate pmctl

```bash
if [[ -x "${HOME}/.local/bin/pmctl" ]]; then
  PMCTL="${HOME}/.local/bin/pmctl"
else
  CMD_LINK="${HOME}/.claude/commands/pre-release.md"
  CMD_REAL="$(readlink -f "$CMD_LINK" 2>/dev/null || readlink "$CMD_LINK")"
  PMCTL="$(cd "$(dirname "$CMD_REAL")/.." && pwd)/cli/pmctl"
fi
```

## Step 2 — Parse args and run Layer 1 + Layer 3 audit

Parse `$ARGUMENTS` for `<milestone-id>`.

```bash
MILESTONE_ID="${ARGUMENTS%% *}"
MILESTONE_ID="${MILESTONE_ID:-}"

if [[ -z "$MILESTONE_ID" ]]; then
  printf 'Usage: /pre-release <milestone-id>\n' >&2
  exit 1
fi

"$PMCTL" pre-release audit "$MILESTONE_ID"
```

## Step 3 — Layer 2: Semantic coverage (main-thread inline)

After Layer 1 completes, perform Layer 2 analysis inline without dispatching a sub-job.

**3a. Build ticket list**: Read `MILESTONES.md`, locate the `## <milestone-id>` section,
and extract every scoped ticket row that has a `pr:#NNN` reference in the status column.
Collect pairs of `(CC-NNN, PR#)`.

**3b. Per-ticket analysis** (repeat for each ticket in scope):

1. Read the ticket body from `BACKLOG.md` — find `## CC-NNN` section and extract the
   `**Requirement**:` block (stop at the next `##` heading or `**Depends on**` line).
   Summarise requirements in 1–2 sentences maximum.

2. Always fetch the file list first — do not read the full patch dump:
   ```bash
   gh pr view <PR#> --json files --jq '[.files[].filename]'
   ```
   From the file list, identify which files relate to the Requirement.
   Then fetch only those files' diffs:
   ```bash
   gh pr diff <PR#> -- <relevant-file1> <relevant-file2>
   ```
   For simple PRs (1–3 files, all relevant) fetch all at once; for larger
   PRs always scope to the files named in the Requirement. Never load the
   full patch without first scoping.

3. Compare: does the diff address each stated requirement? Record:
   - **Covered**: requirement clearly reflected in the diff
   - **Partial**: diff touches the area but misses stated sub-points
   - **Gap**: no diff evidence for a stated requirement
   - **N/A**: requirement is prose/doc with no code expectation

**3c. Output the Layer 2 table** immediately after the Layer 1 report:

```
### Layer 2 — Semantic coverage

| Ticket | Requirement summary | Diff coverage | Confidence | Flag |
|--------|--------------------|--------------:|-----------|------|
| CC-NNN | <1-sentence summary> | Covered / Partial / Gap / N/A | High / Med / Low | — / ⚠️ |
```

**Confidence** reflects how clearly the diff maps to the requirement:
- **High**: direct match, obvious implementation
- **Med**: indirect evidence or refactor-shaped change
- **Low**: diff too large to read fully, or requirement ambiguous

**Flag** `⚠️` when coverage is Partial or Gap, or confidence is Low.

Do **not** output a GO/NO-GO verdict. The table is informational only.

## Layer 1 checks (machine-executable)

| Check | What it verifies |
|---|---|
| 1.1 Milestone PR refs | Every scope ticket has ✅ in MILESTONES.md with a canonical `pr:#NNN` ref in the status column. BACKLOG body `**See**: pr:#NNN` is validated separately by `lint-backlog`, not by this tool. |
| 1.2 Body residuals | Closed ticket bodies contain no `TODO`/`仍待辦`/`待辦`/`pr:#TBD` markers (code fences excluded) |
| 1.3 CHANGELOG coverage | Each scope ticket (by CC-NNN or PR#) appears in CHANGELOG `[Unreleased]` section |
| 1.4 Index ↔ body status | BACKLOG.md index row status emoji matches the body heading status emoji |

## Layer 2 — Semantic coverage

Main thread reads each scoped ticket's Requirement section from BACKLOG, fetches the
file list first (`gh pr view <PR#> --json files`), then fetches only the relevant file
diffs (`gh pr diff <PR#> -- <file…>`). Analyses coverage per ticket inline, outputting
a per-ticket conclusion table. No sub-job dispatch.

**Layer 2 is informational only and does not produce a GO/NO-GO verdict.**

## Layer 3 — Blind spots (always included in report)

The generated report always appends a static blind-spot declaration covering:
- What the tool can and cannot confirm
- The disclaimer: "No structural issues found ≠ release is safe"
- Remaining gaps not covered by Layer 1 or Layer 2

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Report generated; no structural issues found |
| 1 | Report generated; one or more structural issues found |
| 2 | Tool error (missing files, missing milestone, unknown flag) |
