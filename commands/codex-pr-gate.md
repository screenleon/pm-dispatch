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

## Step 2 - Parse args and run

Parse `$ARGUMENTS`, then call the script. The script owns tier detection,
changed-file analysis, reviewer selection, brief generation, and dispatch.

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

GATE_STDOUT="$(mktemp)"
bash "$GATE_SCRIPT" "${GATE_ARGS[@]}" | tee "$GATE_STDOUT"
RESULT_PATH="$(awk -F'result: ' '/^result: /{path=$2} END{print path}' "$GATE_STDOUT")"
rm -f "$GATE_STDOUT"
```

## Step 3 - Relay the result

Read `RESULT_PATH` from Step 2, then relay that file's contents verbatim to the
user. Prepend one line:

`PR-gate ran via codex.`

Do not collapse blocks into "looks good". Relay NO-GO findings completely.
