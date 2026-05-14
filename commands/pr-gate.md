---
description: Run the tiered pre-PR review pipeline on the current branch.
argument-hint: [express|standard|full] [--targeted r1,r2] [--scope context] [--parallel]
---

Run the PR gate via `scripts/pr-gate.sh`.

**Sequential mode (default)**: all reviewers run in order inside one combined codex session.
Low main-thread token cost (~5k dispatch + read result).

**Parallel mode (`--parallel`)**: each reviewer runs in its own independent codex session
followed by a PM synthesis session. Eliminates shared-context anchoring bias.
Higher token cost — use for auth/payment/migration paths or when reviewer independence matters.

| Situation | Args |
|---|---|
| Routine code / seed / docs changes | _(none)_ |
| Re-gate after fixing specific findings | `--targeted qa-tester,risk-reviewer` |
| Auth / payment / migration / sensitive paths | `--parallel` |
| Force a specific tier | `express` / `standard` / `full` |

## Step 1 - Locate the launcher

Resolve the installed command symlink and derive the script path:

```bash
CMD_LINK="${HOME}/.claude/commands/pr-gate.md"
CMD_REAL="$(readlink -f "$CMD_LINK" 2>/dev/null || readlink "$CMD_LINK")"
GATE_SCRIPT="$(cd "$(dirname "$CMD_REAL")/.." && pwd)/scripts/pr-gate.sh"
```

## Step 2 - Parse args and launch in background

Parse `$ARGUMENTS`, build the gate args, then **fire the gate script via the
Bash tool with the tool parameter `run_in_background: true`** so the main
thread is free while codex runs the reviewers (~3-5 min). The gate script
owns tier detection, changed-file analysis, reviewer selection, brief
generation, and dispatch.

> **CRITICAL — `run_in_background: true` is a Bash TOOL PARAMETER, not a
> shell flag.** When you invoke the Bash tool to run the gate script, set
> `run_in_background: true` as a sibling of `command:` in the tool call,
> NOT as a flag inside the command string. Shape:
>
> ```
> Bash(
>   command: 'bash "$GATE_SCRIPT" "${GATE_ARGS[@]}" 2>&1',
>   run_in_background: true   ← TOOL PARAMETER (not inside the command)
> )
> ```
>
> The shell snippet shown in the code block below is just the contents of
> the `command:` field. The background-mode signal lives at the tool-call
> level, one layer above the shell.

> **Why background mode here is safe — and required.** The gate script's
> internal `codex-dispatch.sh` is still foreground-only (enforced by
> `hook-codex-bash-guard.sh` on the codex-executor subagent), but **this
> skill is running from the main thread, not from a subagent**. The main
> thread is not killed when its Bash call returns, so backgrounding the
> outer gate-script invocation correctly frees the user to continue while
> codex churns. The harness sends a completion notification when the
> backgrounded Bash exits.

```bash
RAW_ARGS="${ARGUMENTS:-}"
TIER_OVERRIDE=""
TARGETED_REVIEWERS=""
SCOPE_TOKENS=()
PARALLEL=false

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
    --parallel)
      PARALLEL=true
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
[[ "$PARALLEL" == "true" ]] && GATE_ARGS+=(--parallel)

# Fire with run_in_background: true. The harness captures stdout/stderr and
# emits a completion notification when the gate script exits.
bash "$GATE_SCRIPT" "${GATE_ARGS[@]}" 2>&1
```

After firing, end the turn with one short status line, e.g.:

> `PR-gate launched in background (tier <T>, ~3-5 min). Main thread free; I'll relay the verdict when it finishes.`

Do NOT poll, sleep, or call `BashOutput` immediately. The harness will notify.

## Step 3 - Receive completion and relay the result

When the background-Bash completion notification arrives:

1. Fetch the full stdout via `BashOutput(bash_id: <id from notification>)`.
2. Parse the result file path from the captured stdout:
   `awk -F'result: ' '/^result: /{path=$2} END{print path}'`
3. If the bash exit was non-zero, surface a brief failure summary (exit code +
   last ~20 lines of stdout) instead of pretending success.
4. On exit 0, read the result file at the parsed path.
5. Prepend one line: `PR-gate complete.`
6. Relay the result file contents verbatim.

Do not collapse blocks into "looks good". Relay NO-GO findings completely.

## Local verification after gate findings

After fixing a NO-GO finding, run only the affected tests before re-gating:

```bash
# List all available case names to find the right filter pattern
bash scripts/test-hooks.sh --list
bash scripts/test-install.sh --list

# Run only tests matching the changed area (substring match)
bash scripts/test-hooks.sh --filter "session-hook"
bash scripts/test-install.sh --filter "session-stop"
bash scripts/test-hooks.sh --filter "inject-hook/episode"

# Full suites must still pass before re-gating
bash scripts/test-hooks.sh && bash scripts/test-install.sh
```

`--filter <pattern>` runs only cases whose name contains `<pattern>`.  
`--list` prints all case names and exits 0 — useful for finding the right pattern.  
Full suites are still required in the gate; `--filter` is for local iteration speed only.
