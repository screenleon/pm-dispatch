---
description: Run the PR-gate via codex (sequential reviewers, low main-thread token cost).
argument-hint: [express|standard|full] [--targeted r1,r2] [context]
---

Run a PR-gate with all reviewer work inside a single codex session.
Main-thread cost: ~5k tokens (dispatch + read result) vs ~40–80k for `/pr-gate`.

**When to use `/codex-pr-gate` vs `/pr-gate`:**
| Situation | Use |
|---|---|
| Routine code / seed / docs changes | `/codex-pr-gate` |
| Re-gate after fixing specific findings | `/codex-pr-gate --targeted qa-tester,risk-reviewer` |
| Auth / payment / migration / sensitive paths | `/pr-gate` (independent parallel reviewers) |
| >1000 lines + sensitive path (Opus candidate) | `/pr-gate` |

**Trade-offs**: reviewers run sequentially and share context — slightly less
independent than parallel `/pr-gate`, but verdict quality is comparable for
non-sensitive changes.

## Step 1 — parse args and detect tier

Run the following bash to detect tier and parse `$ARGUMENTS`:

```bash
RAW_ARGS="$ARGUMENTS"

TIER_OVERRIDE=""
TARGETED_REVIEWERS=""
SCOPE_TOKENS=()
PREV=""
for tok in $RAW_ARGS; do
  case "$tok" in
    express|standard|full)
      [[ "$PREV" != "--targeted" ]] && TIER_OVERRIDE="$tok";;
    --targeted) :;;
    *)
      if [[ "$PREV" == "--targeted" ]]; then
        TARGETED_REVIEWERS="$tok"
      else
        SCOPE_TOKENS+=("$tok")
      fi;;
  esac
  PREV="$tok"
done
SCOPE="${SCOPE_TOKENS[*]:-}"

BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
: "${BASE:=main}"
git diff "$BASE"...HEAD --stat 2>/dev/null || git diff HEAD --stat
```

If `--targeted` was given, skip the tier matrix — those reviewers are used directly.

## Step 2 — locate and call the script

```bash
# Resolve script via the installed command symlink
CMD_REAL="$(readlink -f "${HOME}/.claude/commands/codex-pr-gate.md" 2>/dev/null \
  || readlink "${HOME}/.claude/commands/codex-pr-gate.md")"
GATE_SCRIPT="$(dirname "$CMD_REAL")/../scripts/codex-pr-gate.sh"

# Build arg list
GATE_ARGS=(--cd "$PWD")
[[ -n "${TIER_OVERRIDE:-}"        ]] && GATE_ARGS+=(--tier "$TIER_OVERRIDE")
[[ -n "${TARGETED_REVIEWERS:-}"   ]] && GATE_ARGS+=(--reviewers "$TARGETED_REVIEWERS")
[[ -n "${SCOPE:-}"                ]] && GATE_ARGS+=(--scope "$SCOPE")

bash "$GATE_SCRIPT" "${GATE_ARGS[@]}"
```

The script prints `result: <path>` as its last line.

## Step 3 — read and relay result

After the script exits, extract the result path from the last `result: …` line,
read the file, and relay its contents verbatim to the user.

Prepend one line:
`PR-gate ran in <tier> tier via codex (reviewers: <list>).`

Do not collapse blocks into "looks good". Relay NO-GO findings completely.
