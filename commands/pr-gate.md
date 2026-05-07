---
description: Run the tiered pre-PR review pipeline on the current branch.
argument-hint: [express|standard|full] [optional context]
---

Run the PR gate. Subagents cannot spawn subagents in Claude Code, so the **main thread** orchestrates reviewers; `project-pm` is invoked once at the end to synthesize.

## Tier matrix

PR-gate auto-detects the review tier from the diff. The first slash-command argument can override detection:

- `/pr-gate express` — force the smallest reviewer set.
- `/pr-gate standard` — force the mid-size reviewer set.
- `/pr-gate full` — force the full reviewer set.
- No tier argument — auto-detect from the current branch diff.

Auto-detection rules:

- Docs-only changes (`.md`, `.jsonl`, `.txt`, `.gitignore`, `audits/`, `docs/`) run `express`.
- Sensitive paths or filenames run `full`: auth, secrets, migrations, GitHub workflows, payments, credentials, CORS/CSRF/JWT/session/OAuth, SSH/sudo, or webhooks.
- Diffs over 500 changed lines run `full`.
- Non-sensitive code diffs under 100 changed lines run `express`.
- Other non-sensitive code diffs run `standard`.

| Tier | Use case | Reviewers |
| --- | --- | --- |
| `express` | Small, low-risk, or docs-only changes | `critic`, `qa-tester` |
| `standard` | Mid-size code changes without sensitive paths | `critic`, `qa-tester`, `architecture-reviewer` |
| `full` | Large or sensitive changes | `critic`, `qa-tester`, `architecture-reviewer`, `security-reviewer`, `risk-reviewer` |

## Step 1 — detect the tier (main thread, no PM hop)

Detect the integration branch, check the diff, and apply the tier heuristic. The first whitespace-separated token of `$ARGUMENTS` (if it matches `express|standard|full`) overrides auto-detection; the rest of `$ARGUMENTS` flows to reviewers as scope context:

```bash
# Parse first token of $ARGUMENTS (Claude slash-command arg string) as tier override.
# Anything that isn't express/standard/full falls through to auto-detect, preserving
# the prior contract where the slash arg was free-form context.
REQUESTED_TIER=$(printf '%s' "$ARGUMENTS" | awk '{print $1}')
case "$REQUESTED_TIER" in
  express|standard|full) TIER_OVERRIDE="$REQUESTED_TIER" ;;
  *) TIER_OVERRIDE="" ;;
esac
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
: "${BASE:=main}"
git diff "$BASE"...HEAD --stat

DIFF_FILES=$(git diff "$BASE"...HEAD --name-only)
NON_DOCS=$(echo "$DIFF_FILES" | grep -vE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true)
LINES=$(git diff "$BASE"...HEAD --shortstat | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | awk '{s+=$1} END{print s+0}')
# Path-anchored sensitive matching: keyword must be at a path-segment boundary
# (start, /, _, ., -) on at least one side. Reduces false-positives like
# authoring.ts, tokenizer.ts, Discourse.md while keeping auth.ts, /oauth/,
# session-store.ts, /payment.go, design-tokens.css matching correctly.
SENSITIVE_HIT=$(echo "$DIFF_FILES" | grep -iE '(^|[/_.-])(auth|oauth|jwt|session|secret|password|token|credential|cors|csrf|webhook|sudo|ssh|payment|billing)([/_.-]|$)|(^|/)migrations?/|^\.github/' | wc -l)

if [ -n "$TIER_OVERRIDE" ]; then
  TIER="$TIER_OVERRIDE"
elif [ -z "$NON_DOCS" ]; then
  TIER=express
elif [ "$SENSITIVE_HIT" -gt 0 ] || [ "$LINES" -gt 500 ]; then
  TIER=full
elif [ "$LINES" -lt 100 ]; then
  TIER=express
else
  TIER=standard
fi

case "$TIER" in
  express)
    REVIEWERS_RUN="critic, qa-tester"
    ;;
  standard)
    REVIEWERS_RUN="critic, qa-tester, architecture-reviewer"
    ;;
  full)
    REVIEWERS_RUN="critic, qa-tester, architecture-reviewer, security-reviewer, risk-reviewer"
    ;;
esac

printf 'PR-gate tier: %s\nReviewers: %s\n' "$TIER" "$REVIEWERS_RUN"
```

Do not invoke PM at this step. PM's role is synthesis only.

## Step 2 — spawn reviewers in parallel from main thread

In a single message, make N parallel Agent tool calls — one per applicable reviewer. Pseudocode (illustrative, not literal call syntax):

```
# pseudocode — emit each as a real Agent tool call in one message
# Model: always "sonnet" unless Opus escalation condition is met (see below).
Agent(subagent_type: "critic",                model: "sonnet", ...)
Agent(subagent_type: "qa-tester",             model: "sonnet", ...)

if TIER == "standard" or TIER == "full":
  Agent(subagent_type: "architecture-reviewer", model: "sonnet", ...)

if TIER == "full":
  Agent(subagent_type: "security-reviewer", model: "sonnet", ...)
  Agent(subagent_type: "risk-reviewer",     model: "sonnet", ...)
```

**Opus escalation** — only when ALL THREE hold: tier is `full`, diff > 1000 changed
lines, AND a sensitive path triggered `full`. Notify the user and wait for
acknowledgement before switching to `model: "opus"`. See
`docs/model-tier-policy.md` for the full policy.

Each reviewer brief should include: working dir, branch name vs integration branch, tier, reviewers run, diff summary, scope hints from $ARGUMENTS.

## Step 3 — synthesize via project-pm (single hop)

After all reviewers return, invoke `project-pm` once with the tier, reviewers run, skipped review dimensions, and reviewer verbatim outputs. Ask it to:

- Compose the final gate summary (each reviewer's verdict, any blocks with override paths, final go/no-go).
- Explicitly state which dimensions were not reviewed in slimmer tiers, for example: `express tier — security/risk/architecture not reviewed`.
- Record `block-soft` overrides or trade-off advisories into project memory.

## Step 4 — relay to user

Prepend the tier and reviewers run, then relay PM's gate summary verbatim:

`PR-gate ran in <tier> tier (reviewers: <reviewers run>).`

Do not collapse blocks into "looks good".
