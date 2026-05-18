---
description: Run the tiered pre-PR review pipeline on the current branch.
argument-hint: "[express|standard|full] [--targeted r1,r2] [--scope context] [--parallel]"
---

Run the PR gate via `scripts/pr-gate.sh`.

**Sequential mode (default):** all reviewers run in one combined session.
Low main-thread token cost (~5k dispatch + read result).

**Parallel mode (`--parallel`):** each reviewer runs in its own independent session
followed by a PM synthesis session. Higher token cost — use for auth/payment/migration
paths or when reviewer independence matters.

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

Parse `$ARGUMENTS`, build the gate args, then launch via `run_in_background: true`
so the main thread is free while `/pr-gate` runs.

### Executor routing is passed by flag only

This command should pass exactly one of these explicit modes when known:

- `--executor codex` for codex route (or when `command -v codex` is true and user explicitly requested)
- `--executor claude` for claude-only path
- `--executor auto` for default behavior (`command -v codex` decides)

`--executor auto` is the default; keep that shape here for parity with existing
`/pm` profile defaults and `scripts/install-hooks.sh` auto-detect.

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
GATE_ARGS=(--cd "$PWD" --executor auto)
[[ -n "$TIER_OVERRIDE" ]] && GATE_ARGS+=(--tier "$TIER_OVERRIDE")
[[ -n "$TARGETED_REVIEWERS" ]] && GATE_ARGS+=(--reviewers "$TARGETED_REVIEWERS")
[[ -n "$SCOPE" ]] && GATE_ARGS+=(--scope "$SCOPE")
[[ "$PARALLEL" == "true" ]] && GATE_ARGS+=(--parallel)

# Fire with run_in_background: true. The harness captures stdout/stderr and
# emits a completion notification when this Bash call exits.
bash "$GATE_SCRIPT" "${GATE_ARGS[@]}" 2>&1
```

After firing, reply with one short status line, e.g.:

> `PR-gate launched in background (tier <T>, ~3-5 min). Main thread free; I'll relay the verdict when it finishes.`

Do not poll, sleep, or call `BashOutput` immediately.

## Route A — `executor: codex` (default for full profile)

This is the current codex-dispatch primary path. Gate writes one brief per dispatch,
invokes `scripts/codex-dispatch.sh`, and waits for `result: <path>` in stdout.

- Dispatch shape: one Bash route per codex session.
- Completion handling: open the result file directly from the footer path.
- Failure surface: codex session exit non-zero or result validation failure.

The command shape is stable and already implemented by `scripts/pr-gate.sh`.

## Route B — `executor: claude` (main-thread fan-out path)

This route does **not** invoke `scripts/codex-dispatch.sh` at any point.

- Dispatch shape: `scripts/pr-gate.sh` writes a `pr-gate-handover_v1` fenced block
  listing reviewer briefs and output files.
- Completion handling: this skill parses that block and fans out `Agent(subagent_type:
  "claude-executor")` for each `role: reviewer` entry, then one final fan-out
  for the synthesis entry when present.
- Failure surface: block parser failure, malformed entry, or a missing `output_file`
  path; treat as partial/fail and stop fan-out.

`scripts/pr-gate.sh` does not mutate working tree directly on this path; the
calling skill owns execution orchestration.

## Step 3 - Receive completion and relay the result

When the background Bash completion notification arrives:

1. Fetch full stdout via `BashOutput(bash_id: <id>)`.
2. Parse the result file path from stdout:
   `awk -F'result: ' '/^result: /{path=$2} END{print path}'`
3. If exit code is non-zero, surface a brief failure summary (exit code + last ~20
   lines of stdout).
4. If stdout contains a `pr-gate-handover_v1` block, follow the claude fan-out path:
   - Parse the block entries with the parser used for handover metadata.
   - For each `role: reviewer` entry:
     - run `Agent(subagent_type: "claude-executor", prompt: "<brief_file>")` in parallel.
     - read `<output_file>` after each fan-out.
   - If a synthesis entry exists, run one final `Agent(subagent_type: "claude-executor")`.
   - Read `result_file` from the same path and relay it.
5. If no handover block is present, this is Route A: read `result_file` directly.
6. Prepend `PR-gate complete.` to completion relay and include the full gate
   result (including `Final: GO` / `Final: NO-GO`) unchanged.
7. On failure, avoid collapsing findings; relay the actual stderr summary and
   exit 0 from `/pm` only if needed by the conversation protocol.

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
`--list` prints all case names and exits 0.
Full suites are still required in the gate; `--filter` is for local iteration speed.

**Warning**: if the pattern matches zero cases, the harness exits nonzero and prints
`no tests matched filter <pattern>`. A typo in the filter produces a hard failure,
not a false green. Use `--list` first to confirm the case name before running
`--filter`.
