---
description: Run the tiered pre-PR review pipeline on the current branch.
argument-hint: "[express|standard|full] [--targeted r1,r2 --initial-result path] [--scope context] [--mode sequential|parallel]"
---

Run the PR gate via `pmctl gate run`. The `runtime/bin/pr-gate.sh` script is the
internal implementation; `pmctl gate run` is the preferred invocation surface.

**Sequential mode (default):** all reviewers run in one combined session.
Low main-thread token cost (~5k dispatch + read result).

**Parallel mode (`--mode parallel`; `--parallel` is compatible):** each reviewer runs in its own independent session
followed by a PM synthesis session. Higher token cost — use for auth/payment/migration
paths or when reviewer independence matters.

| Situation | Args |
|---|---|
| Routine code / seed / docs changes | _(none)_ |
| Re-gate after fixing specific findings | `--targeted qa-tester,risk-reviewer --initial-result <path>` |
| Auth / payment / migration / sensitive paths | `--mode parallel` |
| Force a specific tier | `express` / `standard` / `full` |

## Step 1 - Invoke pmctl directly

Call the bare `pmctl` command with no resolution preamble — an installed
setup has it on PATH, and a literal `pmctl ...` invocation is what matches
allowlisted `Bash(pmctl:*)`-style permission rules; anything prefixed onto
the command (a variable assignment, a `command -v` check, a subshell) does
not match that prefix and forces a manual approval every time.

Only if a bare `pmctl` call actually fails with a command-not-found error
(exit 127, or stderr naming `pmctl: command not found`) — meaning `pmctl` is
not on PATH, e.g. a fresh checkout before `install.sh` has run — retry that
**same** step with the resolved repo-relative path instead:

```bash
"$(cd "$(dirname "$(readlink -f "${HOME}/.claude/commands/pr-gate.md" 2>/dev/null || readlink "${HOME}/.claude/commands/pr-gate.md")")/.." && pwd)/cli/pmctl" gate run ...
```

This fallback form only ever runs once, on the rare not-installed path, and
naturally needs one manual approval when it does — it does not become the
default shape of every gate call.

## Step 2 - Parse args and launch detached

Parse `$ARGUMENTS`, build the gate args, then launch with `--lifecycle detached`
(inline, not `run_in_background`) so the harness sees the launch return fast with
a `gate_id`. The gate itself keeps running under `setsid`/`nohup`, fully
OS-decoupled from this session — a session interrupt cannot kill it or corrupt
its exit-code reporting.

**The run call and the wait call below are two SEPARATE Bash tool
invocations** — each Bash call is its own subprocess, so a shell variable
assigned in one does NOT survive into the next. Read the `gate_id` this call
prints to stdout and substitute that literal value into the wait command's
argv (the same `<run_id>` pattern `commands/pm.md`'s dispatch routes use) —
do not write a second Bash call that assumes a variable set by the first
call is still available.

### Executor routing is passed by flag only

Choose the gate executor/model using the authoritative
[gate model diversity policy](../docs/review-model.md#gate-model-diversity).
Resolve actual model identities rather than inferring them from host or adapter
names. Replace `<gate_executor>` below with the selected literal value and pass
`--model <gate_model>` when the route default is not the selected model.

This command should pass exactly one of these explicit modes when known:

- `--executor codex` for codex route (or when `command -v codex` is true and user explicitly requested)
- `--executor claude` for claude-only path
- `--executor auto` for default behavior (`command -v codex` decides)

`--executor auto` remains the compatibility fallback only when the
implementation model or alternate executor availability cannot be determined.

```bash
RAW_ARGS="${ARGUMENTS:-}"
TIER_OVERRIDE=""
TARGETED_REVIEWERS=""
INITIAL_RESULT=""
SCOPE_TOKENS=()
GATE_MODE=""
GATE_EXECUTOR="<gate_executor>"
GATE_MODEL=""

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
      [[ -n "$TARGETED_REVIEWERS" ]] || { echo "error: --targeted requires a reviewer list" >&2; exit 2; }
      ;;
    --initial-result)
      idx=$((idx + 1))
      INITIAL_RESULT="${TOKENS[$idx]:-}"
      [[ -n "$INITIAL_RESULT" ]] || { echo "error: --initial-result requires a path" >&2; exit 2; }
      ;;
    --scope)
      idx=$((idx + 1))
      [[ -n "${TOKENS[$idx]:-}" ]] && SCOPE_TOKENS+=("${TOKENS[$idx]}")
      ;;
    --mode)
      idx=$((idx + 1))
      requested_mode="${TOKENS[$idx]:-}"
      case "$requested_mode" in
        sequential|parallel) ;;
        *) echo "error: --mode requires sequential or parallel" >&2; exit 2 ;;
      esac
      if [[ -n "$GATE_MODE" && "$GATE_MODE" != "$requested_mode" ]]; then
        echo "error: conflicting gate mode options" >&2
        exit 2
      fi
      GATE_MODE="$requested_mode"
      ;;
    --parallel|--sequential)
      requested_mode="${tok#--}"
      if [[ -n "$GATE_MODE" && "$GATE_MODE" != "$requested_mode" ]]; then
        echo "error: conflicting gate mode options" >&2
        exit 2
      fi
      GATE_MODE="$requested_mode"
      ;;
    --executor)
      idx=$((idx + 1))
      GATE_EXECUTOR="${TOKENS[$idx]:-}"
      ;;
    --model)
      idx=$((idx + 1))
      GATE_MODEL="${TOKENS[$idx]:-}"
      [[ -n "$GATE_MODEL" ]] || { echo "error: --model requires a value" >&2; exit 2; }
      ;;
    *)
      SCOPE_TOKENS+=("$tok")
      ;;
  esac
  idx=$((idx + 1))
done

if [[ -n "$TARGETED_REVIEWERS" && -z "$INITIAL_RESULT" ]]; then
  echo "error: --targeted requires --initial-result <path>" >&2
  exit 2
fi
if [[ -z "$TARGETED_REVIEWERS" && -n "$INITIAL_RESULT" ]]; then
  echo "error: --initial-result is only valid with --targeted" >&2
  exit 2
fi

# Validate after parsing so this also rejects a missing substitution of the
# <gate_executor> default, not only an invalid explicit --executor value.
case "$GATE_EXECUTOR" in
  codex|claude|auto) ;;
  *) echo "error: gate executor must resolve to codex, claude, or auto" >&2; exit 2 ;;
esac

SCOPE="${SCOPE_TOKENS[*]:-}"
# --cd's value below, "<work_dir>", is a placeholder to replace with the
# actual working directory (already known from context) as a literal quoted
# string before running this block -- e.g. "/home/user/repo" -- NOT "$PWD".
# A "$PWD" expansion makes the whole command unanalyzable statically (see
# note below the launch call) and forces a manual approval regardless of the
# `pmctl:*` prefix match. The quotes around the placeholder keep this block
# valid, executable Bash even before that substitution (bare, unquoted
# `<work_dir>` would be parsed as I/O redirection and fail to parse).
GATE_ARGS=(--cd "<work_dir>" --executor "$GATE_EXECUTOR")
[[ -n "$GATE_MODEL" ]] && GATE_ARGS+=(--model "$GATE_MODEL")
[[ -n "$TIER_OVERRIDE" ]] && GATE_ARGS+=(--tier "$TIER_OVERRIDE")
[[ -n "$TARGETED_REVIEWERS" ]] && GATE_ARGS+=(--targeted "$TARGETED_REVIEWERS" --initial-result "$INITIAL_RESULT")
[[ -n "$SCOPE" ]] && GATE_ARGS+=(--scope "$SCOPE")
[[ -n "$GATE_MODE" ]] && GATE_ARGS+=(--mode "$GATE_MODE")

# Launch detached: this call is inline (NOT run_in_background) and returns in
# well under a second once the supervisor is forked -- stdout prints exactly
# one line, the gate_id; stderr prints a ready-to-paste `pmctl gate wait ...`
# command with the id and --cd already filled in.
pmctl gate run "${GATE_ARGS[@]}" --lifecycle detached
```

If this fails with `pmctl: command not found` (exit 127), `pmctl` is not on
PATH — retry with the resolved fallback path instead:
`"$(cd "$(dirname "$(readlink -f "${HOME}/.claude/commands/pr-gate.md" 2>/dev/null || readlink "${HOME}/.claude/commands/pr-gate.md")")/.." && pwd)/cli/pmctl" gate run "${GATE_ARGS[@]}" --lifecycle detached`
(re-run the full arg-parsing block above first — `GATE_ARGS` does not
survive across Bash calls).

Read the printed `gate_id` from this call's stdout, then launch the wait as a
**separate Bash tool call** with `run_in_background: true` so the main thread
is free while the gate runs. This is a genuinely independent subprocess, so
it does not depend on any variable from the block above — call `pmctl`
bare (no resolution preamble; see Step 1) and receive `gate_id` and
`<work_dir>` only as substituted literal values, never shell variables (a
`"$PWD"` expansion here defeats the whole point of calling `pmctl` bare: it
makes the command unanalyzable statically, so it needs a manual approval
every time regardless of the `pmctl:*` prefix match):

```bash
pmctl gate wait <gate_id> --cd "<work_dir>"
```

The run call's stderr already printed this exact command with both values
filled in — copy it verbatim instead of assembling id + `--cd` by hand.
`--cd` is optional when the wait runs from inside the target repo (it
defaults to the CWD git toplevel, the same derivation `gate run` uses);
keep it explicit when waiting from anywhere else.

If this fails with `pmctl: command not found`, fall back per Step 1 (retry
with the resolved absolute `cli/pmctl` path).

After firing the wait, reply with one short status line, e.g.:

> `PR-gate launched (gate_id <id>, tier <T>, ~3-5 min). Main thread free; I'll relay the verdict when it finishes.`

Do not poll, sleep, or call `BashOutput` immediately. If the session is
interrupted before the wait notification arrives, the gate keeps running
detached; note the `gate_id` before the interrupt (or recover it via
`pmctl artifacts list --cd "<work_dir>"`) and reattach with
`pmctl gate wait <gate_id> --cd "<work_dir>"` in a new session -- a fresh
`/pr-gate` invocation starts a NEW gate and does NOT reattach to the
interrupted one.
(gate wait exit 3 means the sentinel was already consumed by a prior wait —
check `pmctl artifacts show <gate_id> --cd "<work_dir>"` for the durable result
file in that case).

## Executor routes — both dispatch an independent subprocess

Both `--executor codex` and `--executor claude` dispatch an INDEPENDENT executor
subprocess, integrity-check the result in-process, and print `result: <path>`.
There is no handover/fan-out path — the skill just reads the result file.

- **`executor: codex`** (default for full profile when codex is on PATH): gate
  writes one brief per dispatch and invokes the codex adapter (`codex exec`).
- **`executor: claude`**: identical flow, dispatching the headless claude adapter
  (`claude --print`, an independent process) instead. Default model is the claude
  adapter's pinned default (sonnet); override with `--model <id>`.

Reasoning effort defaults to `medium` regardless of executor (`--effort low|medium|high`,
independent of `--model`); only raise it to `high` for a genuinely hard diagnosis or
after repeated NO-GO rounds on the same finding.

`runtime/bin/pr-gate.sh` owns dispatch + result verification for both; the calling
skill does not fan out reviewers or parse any handover block.

## Step 3 - Receive completion and relay the result

When the `pmctl gate wait` background Bash completion notification arrives:

1. Fetch full stdout via `BashOutput(bash_id: <id>)`. It contains
   `gate: <gate_id>  state: <GO|NO-GO|failed>  exit: <N>`, then `result: <path>`
   when a result was written, then the result file's own `Final: GO` /
   `Final: NO-GO` line once integrity checks pass — that `Final:` line is the
   verdict source of truth.
2. Parse the result file path from stdout:
   `awk -F'result: ' '/^result: /{path=$2} END{print path}'`
3. Exit code meaning: 0 = GO, 1 = NO-GO (a gate verdict — the background
   harness renders it as a failed command, but it is NOT an execution
   error), 124 = wait timed out (gate may still be
   running detached -- retry `pmctl gate wait <gate_id> --cd "<work_dir>"` once with
   the same `gate_id` before treating it as stuck), 3 = indeterminate (sentinel
   already consumed by a prior wait; use `pmctl artifacts show <gate_id> --cd "<work_dir>"`
   to locate the durable result instead), other non-zero = gate failed (surface a
   brief failure summary: exit code + last ~20 lines of the supervisor log at
   `pmctl artifacts show <gate_id> --cd "<work_dir>"`).
4. Read `result_file` directly (both executor routes write it in-process). To
   re-confirm out of band, run `pmctl gate verify <result_file_path>` (the
   literal path parsed in step 2, not a shell variable; exit 0 = valid).
5. Prepend `PR-gate complete.` to completion relay and include the full gate
   result (including `Final: GO` / `Final: NO-GO`) unchanged.
6. On failure, avoid collapsing findings; relay the actual stderr summary and
   exit 0 from `/pm` only if needed by the conversation protocol.

## Local verification after gate findings

After fixing a NO-GO finding, run only the affected tests before re-gating:

```bash
# List all available case names to find the right filter pattern
bash tests/shell/test-guards.sh --list
bash tests/shell/test-install.sh --list

# Run only tests matching the changed area (substring match)
bash tests/shell/test-guards.sh --filter "session-hook"
bash tests/shell/test-install.sh --filter "session-stop"
bash tests/shell/test-guards.sh --filter "inject-hook/episode"

# Broader affected suites should pass before re-gating
bash tests/shell/test-guards.sh && bash tests/shell/test-install.sh
```

`--filter <pattern>` runs only cases whose name contains `<pattern>`.
`--list` prints all case names and exits 0.
The target repo may explicitly supply a bounded iteration runner through
`pmctl gate run --test-cmd '<repo-owned command>'`; `/pr-gate` never auto-detects
or hardcodes one. Run a repository's authoritative full suite separately before
final delivery so a long test process cannot consume the gate lifecycle timeout.

**Warning**: if the pattern matches zero cases, the harness exits nonzero and prints
`no tests matched filter <pattern>`. A typo in the filter produces a hard failure,
not a false green. Use `--list` first to confirm the case name before running
`--filter`.
