---
description: Route a request to the project-pm agent.
argument-hint: "<free-form request, e.g. \"status of foo\", \"add /health endpoint to api\">"
---

**Before invoking the agent, capture a state snapshot.** From within the target repo's working directory, run the snapshot script and capture its stdout (which echoes the output path):

```bash
SNAPSHOT_FILE="$(bash ${PM_DISPATCH_REPO}/scripts/pm-prep-snapshot.sh [--focus CC-N,CC-M])"
```

Extract any `CC-\d+` ticket IDs from `$ARGUMENTS` and pass them as `--focus`. If the script errors (e.g. the target repo has no `BACKLOG.md` — common outside pm-dispatch), `$SNAPSHOT_FILE` will be empty; skip the snapshot but proceed with the dispatch — do not block. Rationale: solves the "PM spends its first phase re-verifying caller-claimed branch/ticket state" failure mode documented in `[[project_memory_architecture]]`.

Invoke `project-pm` via Agent with `run_in_background: true` (default). PM tasks routinely take 30–120s and burn 30–80K tokens; foregrounding holds the main thread idle while the user can't interject. Foreground only when PM's verdict is the sole input to the immediate next tool call AND no parallel main-thread prep work exists (rare). Do not force a model — inherit the main-thread model so the user's own session choice applies (see `docs/model-tier-policy.md` §`/pm`). Brief with: request ($ARGUMENTS), current working directory, **`snapshot_file: <abs-path>` when the snapshot was captured above** (PM agent uses the snapshot for orientation; see `agents/project-pm.md` `## Snapshot ingestion` for the git re-derivation rules that apply before trusting any snapshot field), and relevant prior-turn context the subagent won't otherwise see.

Relay the PM's user-facing summary. Do not do the PM's job yourself.

**Dispatch route**: Subagents cannot spawn subagents. If PM returns a `dispatch_handover_v1` block, the **main thread** extracts the brief body, writes it to the declared `brief_file`, reads `executor`, validates metadata with `handover_validate_all_metadata`, and then routes by `executor` value:

- `executor: codex` → main-thread Bash to `pmctl dispatch run --adapter codex`
- `executor: claude` → main-thread Bash to `pmctl dispatch run --adapter claude`
- any other value is rejected by the validator before this point

The abstract contract both routes implement is documented in `docs/executor-contract.md`. Always source `scripts/lib/handover-validate.sh`, extract and split the fenced block with the shared handover helpers, validate the full metadata header, confirm the metadata/body `working_dir` match, and write `brief_file` via `mktemp -p /tmp brief-<slug>-XXXXXX.md` or equivalent exclusive-create (mode 0600) — `/tmp` is shared, predictable names invite symlink races.

### Route A — `executor: codex`

**Step A1 — launch (inline, returns immediately):**

```text
Bash(command: "bash ${PM_DISPATCH_REPO}/cli/pmctl dispatch run --adapter codex --lifecycle detached --cd <safe working_dir> --brief-file <safe brief_file> --model <safe model> --isolation <safe isolation_level> --timeout <safe timeout>", description: "Dispatch codex for <slug>")
```

`--lifecycle detached` launches the adapter under `nohup/setsid` so the process is fully OS-decoupled from the harness — a session interrupt cannot kill it or corrupt its exit-code reporting. The command returns immediately and prints a single line: the `run_id`. Parse that line and store it. Omit `--model <safe model>` when `model: default`. `isolation_level:` is required in every handover block; the legacy `sandbox`/`approval`/`skip_git_check` fields were removed and a brief carrying any of them is rejected at validation, so never construct `--sandbox`/`--approval`/`--skip-git-check`. `isolation_level: none` (full machine access) is opencode-only; codex and claude reject it (their max isolation is `workspace-write`) — there is no full-access route for them. Insert only `handover_safe_argv` output. Keep the command on one physical line; never use `cd <dir> && ...`.

**Step A2 — wait (background, polls sentinel):**

```text
Bash(command: "bash ${PM_DISPATCH_REPO}/cli/pmctl dispatch wait <run_id> --cd <safe working_dir> --timeout <safe timeout>", run_in_background: true, description: "Wait for codex <slug>")
```

Polls for the supervisor's nonce-authenticated sentinel. The harness background-task notification fires when the wait exits. The wait exit code is the sentinel's (authoritative) exit code — 0 = ok/partial, 124 = timed out, other non-zero = adapter failed.

### Route B — `executor: claude`

Same two-step pattern as Route A with `--adapter claude`. Step A1 (inline, `--lifecycle detached`) returns the `run_id`; Step A2 (background, `pmctl dispatch wait`) polls for completion. Completion handling is identical — both adapters write the same dispatch record and sentinel. Omit `--model` when `model: default`. The adapter translates `isolation_level` to `--permission-mode`. Note: step 5 trace cross-check (command_execution grep) applies to codex traces only; for claude traces (`claude --print --output-format json`), skip the JSONL grep and rely on `self_verify` PASS/FAIL already recorded in `verify_summary`.

### Choosing the route

`executor:` in the handover metadata selects the adapter (`codex` → Route A, `claude` → Route B); both routes share the same two-step dispatch shape and completion handling — the only difference is `--adapter <value>`. Install profile (`./install.sh --profile minimal|full`, auto-detected from `command -v codex` when unset) sets the PM agent's default `executor:`. There is no Agent executor fallback — every executor dispatches via the main-thread `pmctl dispatch run` Bash route.

Main-thread completion handling for both routes — the supervisor runs `pmctl_dispatch_execute_tail` (including post-verify and `self_verify` checks) and writes a durable dispatch record; the main thread's job is to authenticate the result via the sentinel (step 2), read artifact paths from the record (step 3), surface the supervisor's verify summary (step 4), and cross-check execution evidence in the trace (step 5):

1. Keep a small conversation-state row for `run_id`, slug, `brief_file`, `working_dir`, expected files, and status.
2. When the wait notification arrives, check the wait exit code: 0 = ok (check dispatch record to confirm state), 124 = timed out, other non-zero = adapter failed. Do **not** infer completion from `.agent-trace/latest.*` symlinks — those race across concurrent dispatches.
3. Read artifact paths from the dispatch record (`$working_dir/.dispatch-results/$run_id.md`):
   ```bash
   grep -E '^(last_path|trace_path|stderr_path):' "$working_dir/.dispatch-results/$run_id.md" | sed 's/^[^:]*:[[:space:]]*//;s/^"//;s/"$//'
   ```
   For live observation during the wait, use `scripts/codex-watch.sh --trace <abs_jsonl>` when the trace path is known (readable from `trace_path:` in the dispatch record after the run starts), or `scripts/codex-watch.sh --run <run_id> --cd <safe working_dir>` when only the run id is known. For post-run artifact discovery, use `pmctl artifacts list --cd <safe working_dir>` to enumerate relocated run dirs and `pmctl artifacts show <run_id> --cd <safe working_dir>` to inspect artifact files and sizes.
4. The supervisor's `execute_tail` already ran `dispatch-post-verify.sh` (including all `self_verify:` cmd checks) and stored the result in `verify_summary`. Read it from the dispatch record and evaluate: a `FAIL` line makes the result at least `partial`. For stderr, open the `stderr_path` file and discount the adapter's start/finish banner lines — only content beyond those banners is unexpected and downgrades the result to `partial`.
5. **Cross-check execution evidence.** `verify_summary` shows each `cmd:` item as PASS/FAIL/SKIP, but a PASS only proves the command exits 0 in the post-verify environment — not that the executor ran the work in-band. So additionally `grep` the `trace_path` JSONL for a `command_execution` entry corresponding to each `cmd:` item. A `cmd:` item whose verify_summary shows PASS but has **no** matching `command_execution` evidence in the trace makes the result at least `partial`. For `SKIP (executor-evaluated)` items (macros, prose, UI/judgment checks the shell cannot run), the cross-check is the executor's own report in `last_path`: confirm the executor addressed each one. (This cross-check stays in `/pm` because only the main thread can read the executor-specific trace.)
6. On wait exit 124 (sentinel not yet written within the timeout), the supervisor may still be running — do **not** re-dispatch. Retry `pmctl dispatch wait <run_id>` exactly once with the same `run_id`. If it times out again, stop and use `pmctl artifacts show <run_id> --cd <working_dir>` to locate the supervisor log path, then open that file for the user.
7. On any other non-zero wait exit, read the dispatch record for final state and report `trace_path`, `stderr_path`, and `verify_summary` for main-thread review.

Briefs must follow the schema at `docs/dispatch-brief.md` (working_dir / goal / files / acceptance, plus self_verify required for file-writing briefs and optional only for read-only briefs where every files entry is explicitly tagged `read:`). The `pmctl dispatch run` pre-flight (`brief-validate`) rejects briefs missing the required fields.

Use `base` as the PR integration branch when the caller names one; otherwise resolve it with `git merge-base --fork-point origin/main HEAD` and fall back to `origin/main` if no fork point is available. The handover extraction, validation, safe argv, and footer parsing contract is covered by `scripts/test-dispatch-handover.sh`.

**Discovery route**: Subagents cannot spawn subagents, so when PM classifies a request as Discovery / "what's next" it returns a `next_step_route` block instead of answering from a backlog skim (see `agents/project-pm.md` → *Uncertainty routing*). The **main thread** then orchestrates:

1. If `active_scope` is a named ticket/PR/bug (`run_discover: false`), there is no fan-out — relay PM's tactical answer directly. Do **not** auto-run `/discover` for tactical, already-scoped requests.
2. If `run_discover: true`, run `/discover <theme>` (passing `theme` when present). `/discover` is read-only and non-committal — no confirmation needed.
3. Feed the `/discover` report back to `project-pm` (re-invoke via Agent with the report as context) so PM produces the final recommendation — citing the discover output and stating, per pick, the next route: `pm` (scoped enough to brief), `spike` (needs a committed decision first), `research` (needs an external method), or `defer`.
4. `/research` is **auto-offered, not auto-fired**: only run it when PM's recommendation flags an external-method gap on a *selected* candidate, and only after `/research`'s own directioning question is answered (it owns the topic-narrowing — do not invent a topic here). For a candidate blocked by a durable decision, route to `/spike <ticket-id>` instead.

Relay PM's final recommendation. Do not open tickets, dispatch, or modify files from a discovery flow without explicit user confirmation.

For PR-gate flows, use `/pr-gate` instead — that skill handles reviewer orchestration; do not re-implement it inline here.

## Artifact garbage collection

Run artifacts accumulate in the out-of-repo state store (`~/.local/share/pm-dispatch/state/projects/<key>/runs/`). Use `pmctl artifacts gc` to reclaim space:

```bash
pmctl artifacts gc [--dry-run] [--keep-last N] [--max-age-days D] [--cd <work_dir>]
pmctl artifacts gc --all-repos [--repos-root <dir>] [--dry-run]
pmctl artifacts migrate [--cd <work_dir>]
```

- `--dry-run`: list what would be deleted without removing anything.
- `--keep-last N` (default 10): always retain the N newest runs per partition.
- `--max-age-days D` (default 30): delete runs older than D days (0 disables the age filter — only keep-last applies).
- `--all-repos`: scan `~/github/*/` (or `--repos-root <dir>`) for in-repo remnant directories (`.agent-trace`, `.gate-briefs`, `.gate-results`) and remove them. Never touches `.pm-dispatch/`. **Run only when no dispatch or gate is active** — an in-progress run may still be writing to its in-repo artifact directory.
- `pmctl artifacts migrate --cd <work_dir>`: copy any remaining in-repo artifact leaves into the out-of-repo partition (idempotent; originals preserved for manual removal after verification).

Overridable via env: `PM_DISPATCH_GC_KEEP_LAST`, `PM_DISPATCH_GC_MAX_AGE_DAYS`. Flag values always win over env.
