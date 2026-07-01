---
description: Run the tiered pre-PR review pipeline on the current branch.
argument-hint: "[express|standard|full] [--targeted r1,r2] [--scope context] [--parallel]"
---

Run the PR gate via `pmctl gate run`. The `scripts/pr-gate.sh` script is the
internal implementation; `pmctl gate run` is the preferred invocation surface.

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

## Step 1 - Locate pmctl

Resolve the installed `pmctl` binary. `~/.local/bin/pmctl` is the installed
symlink; fall back to the repo-relative path when the install is absent.
**This resolution is a one-liner repeated verbatim at the top of every Bash
call in this skill that invokes `pmctl`** (Step 2's launch call and the wait
call below) — never assume `$PMCTL` set in one Bash call is visible in
another; each call is its own subprocess:

```bash
PMCTL="${HOME}/.local/bin/pmctl"; [[ -x "$PMCTL" ]] || PMCTL="$(cd "$(dirname "$(readlink -f "${HOME}/.claude/commands/pr-gate.md" 2>/dev/null || readlink "${HOME}/.claude/commands/pr-gate.md")")/.." && pwd)/cli/pmctl"
```

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

This command should pass exactly one of these explicit modes when known:

- `--executor codex` for codex route (or when `command -v codex` is true and user explicitly requested)
- `--executor claude` for claude-only path
- `--executor auto` for default behavior (`command -v codex` decides)

`--executor auto` is the default; keep that shape here for parity with existing
`/pm` profile defaults and `scripts/install-guards.sh` auto-detect.

```bash
PMCTL="${HOME}/.local/bin/pmctl"; [[ -x "$PMCTL" ]] || PMCTL="$(cd "$(dirname "$(readlink -f "${HOME}/.claude/commands/pr-gate.md" 2>/dev/null || readlink "${HOME}/.claude/commands/pr-gate.md")")/.." && pwd)/cli/pmctl"
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
# --cd defaults to $PWD inside pmctl gate run when omitted; pass explicitly
# so the intent is clear and portable across invocation contexts.
GATE_ARGS=(--cd "$PWD" --executor auto)
[[ -n "$TIER_OVERRIDE" ]] && GATE_ARGS+=(--tier "$TIER_OVERRIDE")
[[ -n "$TARGETED_REVIEWERS" ]] && GATE_ARGS+=(--reviewers "$TARGETED_REVIEWERS")
[[ -n "$SCOPE" ]] && GATE_ARGS+=(--scope "$SCOPE")
[[ "$PARALLEL" == "true" ]] && GATE_ARGS+=(--parallel)

# Launch detached: this call is inline (NOT run_in_background) and returns in
# well under a second once the supervisor is forked -- it prints exactly one
# line, the gate_id, and nothing else on success.
"$PMCTL" gate run "${GATE_ARGS[@]}" --lifecycle detached
```

Read the printed `gate_id` from this call's stdout, then launch the wait as a
**separate Bash tool call** with `run_in_background: true` so the main thread
is free while the gate runs. This is a genuinely independent subprocess, so
it re-resolves `pmctl` itself (Step 1's one-liner, repeated -- never `$PMCTL`
from an earlier call) and receives `gate_id` only as a substituted literal
value, never a shell variable from the block above:

```bash
PMCTL="${HOME}/.local/bin/pmctl"; [[ -x "$PMCTL" ]] || PMCTL="$(cd "$(dirname "$(readlink -f "${HOME}/.claude/commands/pr-gate.md" 2>/dev/null || readlink "${HOME}/.claude/commands/pr-gate.md")")/.." && pwd)/cli/pmctl"
"$PMCTL" gate wait <gate_id> --cd "$PWD"
```

After firing the wait, reply with one short status line, e.g.:

> `PR-gate launched (gate_id <id>, tier <T>, ~3-5 min). Main thread free; I'll relay the verdict when it finishes.`

Do not poll, sleep, or call `BashOutput` immediately. If the session is
interrupted before the wait notification arrives, the gate keeps running
detached; note the `gate_id` before the interrupt (or recover it via
`pmctl artifacts list --cd "$PWD"`) and reattach with
`pmctl gate wait <gate_id> --cd "$PWD"` in a new session -- a fresh `/pr-gate`
invocation starts a NEW gate and does NOT reattach to the interrupted one.
(gate wait exit 3 means the sentinel was already consumed by a prior wait —
check `pmctl artifacts show <gate_id> --cd <work_dir>` for the durable result
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

`scripts/pr-gate.sh` owns dispatch + result verification for both; the calling
skill does not fan out reviewers or parse any handover block.

## Step 3 - Receive completion and relay the result

When the `pmctl gate wait` background Bash completion notification arrives:

1. Fetch full stdout via `BashOutput(bash_id: <id>)`. It contains
   `gate: <gate_id>  state: <GO|NO-GO|failed>  exit: <N>` and, when a result was
   written, `result: <path>` on the next line.
2. Parse the result file path from stdout:
   `awk -F'result: ' '/^result: /{path=$2} END{print path}'`
3. Exit code meaning: 0 = GO, 1 = NO-GO, 124 = wait timed out (gate may still be
   running detached -- retry `pmctl gate wait <gate_id> --cd "$PWD"` once with
   the same `gate_id` before treating it as stuck), 3 = indeterminate (sentinel
   already consumed by a prior wait; use `pmctl artifacts show <gate_id> --cd "$PWD"`
   to locate the durable result instead), other non-zero = gate failed (surface a
   brief failure summary: exit code + last ~20 lines of the supervisor log at
   `pmctl artifacts show <gate_id> --cd "$PWD"`).
4. Read `result_file` directly (both executor routes write it in-process). To
   re-confirm out of band, run `pmctl gate verify "$result_file"` (exit 0 = valid).
5. Prepend `PR-gate complete.` to completion relay and include the full gate
   result (including `Final: GO` / `Final: NO-GO`) unchanged.
6. On failure, avoid collapsing findings; relay the actual stderr summary and
   exit 0 from `/pm` only if needed by the conversation protocol.

## Local verification after gate findings

After fixing a NO-GO finding, run only the affected tests before re-gating:

```bash
# List all available case names to find the right filter pattern
bash scripts/test-guards.sh --list
bash scripts/test-install.sh --list

# Run only tests matching the changed area (substring match)
bash scripts/test-guards.sh --filter "session-hook"
bash scripts/test-install.sh --filter "session-stop"
bash scripts/test-guards.sh --filter "inject-hook/episode"

# Full suites must still pass before re-gating
bash scripts/test-guards.sh && bash scripts/test-install.sh
```

`--filter <pattern>` runs only cases whose name contains `<pattern>`.
`--list` prints all case names and exits 0.
Full suites are still required in the gate; `--filter` is for local iteration speed.

**Warning**: if the pattern matches zero cases, the harness exits nonzero and prints
`no tests matched filter <pattern>`. A typo in the filter produces a hard failure,
not a false green. Use `--list` first to confirm the case name before running
`--filter`.
