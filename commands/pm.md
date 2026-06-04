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

- `executor: codex` → main-thread Bash to `scripts/codex-dispatch.sh` (primary route)
- `executor: claude` → main-thread `Agent(subagent_type: "claude-executor")` with the pre-written brief file path
- any other value is rejected by the validator before this point

The abstract contract both routes implement is documented in `docs/executor-contract.md`. Always source `scripts/lib/handover-validate.sh`, extract and split the fenced block with the shared handover helpers, validate the full metadata header, confirm the metadata/body `working_dir` match, and write `brief_file` via `mktemp -p /tmp brief-<slug>-XXXXXX.md` or equivalent exclusive-create (mode 0600) — `/tmp` is shared, predictable names invite symlink races.

### Route A — `executor: codex`

```text
Bash(command: "bash ${PM_DISPATCH_REPO}/cli/pmctl dispatch run --adapter codex --cd <safe working_dir> --brief-file <safe brief_file> --model <safe model> --isolation <safe isolation_level> --timeout <safe timeout>", run_in_background: true, description: "Dispatch codex for <slug>")
```

Omit `--model <safe model>` when `model: default`. When the handover block uses the legacy `sandbox:` field instead of `isolation_level:`, pass `--sandbox <safe sandbox> --approval <safe approval>` — pmctl forwards them opaquely to the adapter. New briefs must use `isolation_level:`. Never emit `--skip-git-check`; callers needing that flag must use the `Agent(codex-executor)` fallback. Insert only `handover_safe_argv` output. Keep the command on one physical line; never use `cd <dir> && ...`.

Use `Agent(codex-executor)` only per the fallback allowlist in `docs/dispatch-brief.md` §Fallback.

### Route B — `executor: claude`

```text
Bash(command: "bash ${PM_DISPATCH_REPO}/cli/pmctl dispatch run --adapter claude --cd <safe working_dir> --brief-file <safe brief_file> --model <safe model> --isolation <safe isolation_level> --timeout <safe timeout>", run_in_background: true, description: "Dispatch claude for <slug>")
```

Invokes `adapters/claude/dispatch.sh` → headless `claude --print` as an external CLI subprocess; host-independent (codex-as-PM can drive it). Completion handling is identical to Route A — same Bash footer format, same post-verify flow. Omit `--model` when `model: default`. The adapter translates `isolation_level` to `--permission-mode`; legacy `--sandbox`/`--approval` flags are forwarded as no-ops. Note: step 5 trace cross-check (command_execution grep) applies to codex traces only; for claude traces (`claude --print --output-format json`), skip the JSONL grep and rely on `self_verify` PASS/FAIL from dispatch-post-verify.sh.

Use `Agent(claude-executor)` only when headless `claude --print` is unavailable (e.g. `claude` CLI not in PATH) — per the fallback allowlist in `docs/dispatch-brief.md` §Fallback. See `agents/claude-executor.md` for the Agent fallback contract and `docs/executor-contract.md` for the profile comparison.

### Choosing the route

`executor:` in the handover metadata selects the adapter (`codex` → Route A, `claude` → Route B); both routes share the same Bash dispatch shape and completion handling — the only difference is `--adapter <value>`. Install profile (`./install.sh --profile minimal|full`, auto-detected from `command -v codex` when unset) sets the PM agent's default `executor:`. If fallback to an Agent is needed (CLI unavailable), say why in one sentence before dispatching `Agent(codex-executor)` or `Agent(claude-executor)` per `docs/dispatch-brief.md` §Fallback.

Main-thread completion handling for both routes — codex and claude now share the same Bash dispatch shape (steps 1–3 and 5–7 are tool-call orchestration only the main thread can do; the verification body in step 4 is the shared, tested `scripts/dispatch-post-verify.sh`, not re-implemented prose):

1. Keep a small conversation-state row for `task_id`, slug, `brief_file`, `working_dir`, expected files, and status.
2. When the completion notification arrives, read `BashOutput(bash_id: <id>)`; do not infer completion from `.agent-trace/latest.*` symlinks.
3. Parse the footer lines `trace:`, `last:`, `stderr:`, and `exit:` from the captured output.
4. Run the shared post-verify against the **per-run** footer paths (never `latest.*` — those race across concurrent dispatches), passing the brief so `self_verify:` items are checked:

   ```text
   Bash(command: "bash ${PM_DISPATCH_REPO}/scripts/dispatch-post-verify.sh <safe working_dir> --last <safe last> --stderr <safe stderr> --brief-file <safe brief_file> --base <safe base>", description: "Post-verify <slug>")
   ```

   Pass `--base <base>` using the integration base resolved below (the caller-named branch, else `git merge-base --fork-point origin/main HEAD`, else `origin/main`) so the diff evidence is base-correct for non-`origin/main` targets; omit `--base` only when the base is `origin/main` (the script's default). It tails the final message, prints the **tail (last 20 lines)** of the run's stderr (the post-verify script is executor-agnostic, so it does **not** strip the executor's wrapper start/finish banner lines, e.g. `codex-dispatch starting`/`finished`), prints `git diff --stat <base>...HEAD` (merge-base form, so an advanced integration branch doesn't surface unrelated upstream commits) + `status --short` for `<working_dir>`, processes each `self_verify:` item — executing the structured `- cmd: "<bash>"` form in `<working_dir>` as `PASS`/`FAIL` (exit 0 = PASS; non-zero or timeout = FAIL) and marking every other shape (macros, prose, bare scalars) `SKIP (executor-evaluated)` — and exits `0` (ok) or `1` (partial/failed). Read its output: a non-zero exit, a `FAIL` line, or an unbriefed file — appearing in **either** the `<base>...HEAD` diff stat **or** the `status --short` block (uncommitted edits land only in the latter) and not in the brief's `files:` block — makes the result at least `partial`. For stderr, **discount the wrapper start/finish banner lines** — only stderr content *beyond* those banners is unexpected and downgrades the result to `partial`; if the tail is truncated (more than ~20 stderr lines), open the footer `stderr:` path directly before concluding `ok`.
5. **Cross-check execution evidence.** The script *executes* each structured `- cmd: "<bash>"` self_verify item itself (CC-318), so a `PASS` proves the command exits 0 in the post-verify environment **after** the dispatch — but it does **not** prove the executor ran that work in-band (a check can pass against repo state the executor never produced, or that a later step left behind). So additionally `grep` the footer `trace:` JSONL for a `command_execution` entry corresponding to each `cmd:` item. A `cmd:` item the script reported as `PASS` but with **no** matching `command_execution` evidence in the trace makes the result at least `partial` — this guards against the executor skipping the work while a post-hoc re-run still passes. For `SKIP (executor-evaluated)` items (macros, prose, UI/judgment checks the shell cannot run), the cross-check is the executor's own report: confirm the executor addressed each one before concluding `ok`. (This cross-check stays in `/pm` because only the main thread can read the executor-specific trace.)
6. On footer `exit: 124`, run the foreground diagnostic checklist, then retry exactly once with the same `brief_file` and flags.
7. On any other non-zero footer exit, stop and report the trace, stderr, and footer exit code for main-thread review.

Briefs must follow the schema at `docs/dispatch-brief.md` (working_dir / goal / files / acceptance, plus self_verify required for file-writing briefs and optional only for read-only briefs where every files entry is explicitly tagged `read:`). codex-executor rejects briefs missing the required fields.

Use `base` as the PR integration branch when the caller names one; otherwise resolve it with `git merge-base --fork-point origin/main HEAD` and fall back to `origin/main` if no fork point is available. The handover extraction, validation, safe argv, and footer parsing contract is covered by `scripts/test-dispatch-handover.sh`.

For PR-gate flows, use `/pr-gate` instead — that skill handles reviewer orchestration; do not re-implement it inline here.
