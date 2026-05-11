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

# Use --name-status so renames expose BOTH old and new paths for sensitive matching
# (e.g. auth.ts → login.ts still triggers full tier on the old name).
# Use --numstat to detect binary files (shown as -\t-\t<file>).
DIFF_FILES=$(git diff "$BASE"...HEAD --name-status | awk '
  /^R/ { print $2; print $3; next }
  /^[AMDCT]/ { print $2 }
')
NON_DOCS=$(echo "$DIFF_FILES" | grep -vE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true)
BINARY_HIT=$(git diff "$BASE"...HEAD --numstat | { grep -c $'^-\t-\t' || true; })
LINES=$(git diff "$BASE"...HEAD --numstat | awk '/^-\t-\t/{next} {s+=$1+$2} END{print s+0}')
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
elif [ "$LINES" -lt 100 ] && [ "${BINARY_HIT:-0}" -eq 0 ]; then
  # Binary files have no line count but represent real changes — treat as standard+
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

## Step 2 — spawn reviewers in background from main thread

In a single message, make N parallel Agent tool calls — one per applicable
reviewer — **with `run_in_background: true` on every call**. Background mode
frees the main thread to accept new user input while reviewers run (each
reviewer is ~30s-2min). The harness sends a completion notification per
reviewer; Step 3 waits for all N before synthesizing.

Pseudocode (illustrative, not literal call syntax):

```
# pseudocode — emit each as a real Agent tool call in one message.
# Model: always "sonnet" unless Opus escalation condition is met (see below).
# run_in_background: true on EVERY reviewer call — main thread must not block.
Agent(subagent_type: "critic",                model: "sonnet", run_in_background: true, ...)
Agent(subagent_type: "qa-tester",             model: "sonnet", run_in_background: true, ...)

if TIER == "standard" or TIER == "full":
  Agent(subagent_type: "architecture-reviewer", model: "sonnet", run_in_background: true, ...)

if TIER == "full":
  Agent(subagent_type: "security-reviewer", model: "sonnet", run_in_background: true, ...)
  Agent(subagent_type: "risk-reviewer",     model: "sonnet", run_in_background: true, ...)
```

After firing, end the turn with one short status line, e.g.:

> `PR-gate launched in background (<tier>, N reviewers). Main thread free; I'll synthesize via PM when all reviewers return.`

Do NOT poll for completion. The harness will notify the main thread per
reviewer; the next step proceeds when ALL N notifications have arrived.

**Opus escalation** — only when ALL THREE hold: tier is `full`, diff > 1000 changed
lines, AND a sensitive path triggered `full`. Notify the user and wait for
acknowledgement before switching to `model: "opus"`. See
`docs/model-tier-policy.md` for the full policy.

Each reviewer brief should include: working dir, branch name vs integration branch, tier, reviewers run, diff summary, scope hints from $ARGUMENTS.

## Step 3 — synthesize via project-pm (after all reviewers return)

Only proceed once **all N background reviewers have sent completion
notifications** to the main thread. Accumulate each reviewer's verbatim output
as their notification arrives; do not call PM until the last one is in.

Then invoke `project-pm` with `model: "sonnet"` — this
is a bounded synthesis task within the review pipeline, so Sonnet applies here
regardless of what the `/pm` command uses. PM may also be dispatched with
`run_in_background: true` if the user is still mid-conversation; otherwise
foreground is fine since PM synthesis is fast (~10-30s). Never omit the model
param in this step. Pass the tier, reviewers run, skipped review dimensions,
and reviewer verbatim outputs. Ask it to:

- Compose the final gate summary (each reviewer's verdict, any blocks with override paths, final go/no-go).
- Explicitly state which dimensions were not reviewed in slimmer tiers, for example: `express tier — security/risk/architecture not reviewed`.
- Record `block-soft` overrides or trade-off advisories into project memory.

## Step 4 — relay to user

Prepend the tier and reviewers run, then relay PM's gate summary verbatim:

`PR-gate ran in <tier> tier (reviewers: <reviewers run>).`

Do not collapse blocks into "looks good".
