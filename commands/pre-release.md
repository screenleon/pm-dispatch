---
description: Run Layer 1 structural audit for a milestone release — checks PR refs, body residuals, CHANGELOG coverage, and index/body status consistency.
argument-hint: "<milestone-id> [--base-ref <git-ref>]"
---

Run the pre-release audit via `pmctl pre-release audit <milestone-id>`.
This command covers **Layer 1** (machine-executable structural checks) and
**Layer 3** (static blind-spot declaration). Layer 2 (semantic diff coverage)
is not yet implemented.

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

## Step 2 — Parse args and run audit

Parse `$ARGUMENTS` for `<milestone-id>` and optional `--base-ref <ref>`.

```bash
RAW_ARGS="${ARGUMENTS:-}"
MILESTONE_ID=""
BASE_REF=""

read -r -a TOKENS <<< "$RAW_ARGS"
idx=0
while [[ "$idx" -lt "${#TOKENS[@]}" ]]; do
  tok="${TOKENS[$idx]}"
  case "$tok" in
    --base-ref)
      idx=$((idx + 1))
      BASE_REF="${TOKENS[$idx]:-}"
      if [[ -z "$BASE_REF" || "$BASE_REF" == --* ]]; then
        printf 'Error: --base-ref requires a value\n' >&2
        exit 1
      fi
      ;;
    *)
      [[ -z "$MILESTONE_ID" ]] && MILESTONE_ID="$tok"
      ;;
  esac
  idx=$((idx + 1))
done

if [[ -z "$MILESTONE_ID" ]]; then
  printf 'Usage: /pre-release <milestone-id> [--base-ref <git-ref>]\n' >&2
  exit 1
fi

AUDIT_ARGS=("$MILESTONE_ID")
[[ -n "$BASE_REF" ]] && AUDIT_ARGS+=(--base-ref "$BASE_REF")

"$PMCTL" pre-release audit "${AUDIT_ARGS[@]}"
```

## Layer 1 checks (machine-executable)

| Check | What it verifies |
|---|---|
| 1.1 Milestone PR refs | Every scope ticket has ✅ in MILESTONES.md with a canonical `pr:#NNN` ref |
| 1.2 Body residuals | Closed ticket bodies contain no `TODO`/`仍待辦`/`待辦`/`pr:#TBD` markers (code fences excluded) |
| 1.3 CHANGELOG coverage | Each scope ticket (by CC-NNN or PR#) appears in CHANGELOG `[Unreleased]` section |
| 1.4 Index ↔ body status | BACKLOG.md index row status emoji matches the body heading status emoji |

## Layer 2 — Semantic coverage (not yet implemented)

Layer 2 fan-out semantics: group scope tickets by change type (≤4 groups),
dispatch one `claude` job per group with the ticket's Requirement section +
the PR diff summary, PM synthesises per-ticket conclusions. Planned for Phase B.

## Layer 3 — Blind spots (always included in report)

The generated report always appends a static blind-spot declaration covering:
- What the tool can and cannot confirm
- The disclaimer: "No structural issues found ≠ release is safe"
- The Layer 2 gap (semantic drift not yet checked)

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Report generated; no structural issues found |
| 1 | Report generated; one or more structural issues found |
| 2 | Tool error (missing files, missing milestone, unknown flag) |
