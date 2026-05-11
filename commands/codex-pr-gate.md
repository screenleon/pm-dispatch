---
description: Run the PR-gate via codex (sequential reviewers, low main-thread token cost).
argument-hint: [express|standard|full] [--targeted r1,r2] [--scope context]
---

Run a PR-gate with all reviewer work inside a single codex session.
Main-thread cost: ~5k tokens (dispatch + read result) vs ~40-80k for `/pr-gate`.

**When to use `/codex-pr-gate` vs `/pr-gate`:**
| Situation | Use |
|---|---|
| Routine code / seed / docs changes | `/codex-pr-gate` |
| Re-gate after fixing specific findings | `/codex-pr-gate --targeted qa-tester,risk-reviewer` |
| Auth / payment / migration / sensitive paths | `/pr-gate` (independent parallel reviewers) |
| >1000 lines + sensitive path (Opus candidate) | `/pr-gate` |

**Trade-offs**: reviewers run sequentially and share context, so they are
slightly less independent than parallel `/pr-gate`, but the verdict quality is
comparable for non-sensitive changes.

## Step 1 - Locate the launcher

Resolve the installed command symlink and derive the script path:

```bash
CMD_LINK="${HOME}/.claude/commands/codex-pr-gate.md"
CMD_REAL="$(readlink -f "$CMD_LINK" 2>/dev/null || readlink "$CMD_LINK")"
GATE_SCRIPT="$(cd "$(dirname "$CMD_REAL")/.." && pwd)/scripts/codex-pr-gate.sh"
```

## Step 2 - Parse args and launch in background

Parse `$ARGUMENTS`, build the gate args, then **fire the script with
`run_in_background: true`** so the main thread is free while codex runs the
reviewers (~3-5 min). The script owns tier detection, changed-file analysis,
reviewer selection, brief generation, and dispatch.

> **CRITICAL — `run_in_background: true` on the OUTER Bash call (from this
> skill).** The script's internal `codex-dispatch.sh` is still foreground-only
> (enforced by `hook-codex-bash-guard.sh` on the codex-executor subagent), but
> the skill is running from the **main thread**, not from a subagent. The main
> thread is not killed when its Bash call returns, so backgrounding here
> correctly frees the user to continue while codex churns.

```bash
RAW_ARGS="${ARGUMENTS:-}"
TIER_OVERRIDE=""
TARGETED_REVIEWERS=""
SCOPE_TOKENS=()

if [[ -n "$RAW_ARGS" ]]; then
  read -r -a TOKENS <<< "$RAW_ARGS"
else
  TOKENS=()
fi

idx=0
if [[ "${#TOKENS[@]}" -gt 0 ]]; then
  case "${TOKENS[0]}" in
    express|standard|full)
      TIER_OVERRIDE="${TOKENS[0]}"
      idx=1
      ;;
  esac
fi

while [[ "$idx" -lt "${#TOKENS[@]}" ]]; do
  tok="${TOKENS[$idx]}"
  case "$tok" in
    --targeted)
      idx=$((idx + 1))
      TARGETED_REVIEWERS="${TOKENS[$idx]:-}"
      ;;
    --scope)
      idx=$((idx + 1))
      [[ -n "${TOKENS[$idx]:-}" ]] && SCOPE_TOKENS+=("${TOKENS[$idx]}")
      ;;
    *)
      SCOPE_TOKENS+=("$tok")
      ;;
  esac
  idx=$((idx + 1))
done

SCOPE="${SCOPE_TOKENS[*]:-}"
GATE_ARGS=(--cd "$PWD")
[[ -n "$TIER_OVERRIDE" ]] && GATE_ARGS+=(--tier "$TIER_OVERRIDE")
[[ -n "$TARGETED_REVIEWERS" ]] && GATE_ARGS+=(--reviewers "$TARGETED_REVIEWERS")
[[ -n "$SCOPE" ]] && GATE_ARGS+=(--scope "$SCOPE")

# Fire with run_in_background: true. The harness captures stdout/stderr and
# emits a completion notification when the gate script exits.
bash "$GATE_SCRIPT" "${GATE_ARGS[@]}" 2>&1
```

After firing, end the turn with one short status line, e.g.:

> `PR-gate launched in background (codex tier <T>, ~3-5 min). Main thread free; I'll relay the verdict when it finishes.`

Do NOT poll, sleep, or call `BashOutput` immediately. The harness will notify.

## Step 3 - Receive completion and relay the result

When the background-Bash completion notification arrives:

1. Fetch the full stdout via `BashOutput(bash_id: <id from notification>)`.
2. Parse the result file path from the captured stdout:
   `awk -F'result: ' '/^result: /{path=$2} END{print path}'`
3. If the bash exit was non-zero, surface a brief failure summary (exit code +
   last ~20 lines of stdout) instead of pretending success.
4. On exit 0, read the result file at the parsed path.
5. Prepend one line: `PR-gate ran via codex.`
6. Relay the result file contents verbatim.

Do not collapse blocks into "looks good". Relay NO-GO findings completely.
