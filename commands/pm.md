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
Bash(command: "bash ${PM_DISPATCH_REPO}/scripts/codex-dispatch.sh --cd <safe working_dir> --model <safe model> --isolation <safe isolation_level> --timeout <safe timeout> --brief-file <safe brief_file>", run_in_background: true, description: "Dispatch codex for <slug>")
```

The template above shows the default-safe stable argument order; omit `--model <safe model>` only when `model: default`. When the handover block uses the legacy `sandbox:` field instead of `isolation_level:`, use `--sandbox <safe sandbox> --approval <safe approval>` in place of `--isolation <safe isolation_level>`. New briefs must use `isolation_level:`. The bash route never emits `--skip-git-check`: validator hard-rejects `skip_git_check: true`, so callers needing that flag must take the `Agent(codex-executor)` fallback instead. Insert only `handover_safe_argv` output into the Bash command. Keep the command on one physical line and never use `cd <dir> && ...`; that compound shape is part of the stale lifecycle leak described in `[[feedback_codex_dispatch_lifecycle_leak]]`.

Use `Agent(codex-executor)` only per the fallback allowlist in `docs/dispatch-brief.md` §Fallback, preserving existing callers that still depend on executor validation.

### Route B — `executor: claude`

```text
Agent(subagent_type: "claude-executor", prompt: "<safe brief_file abs path>", run_in_background: true, description: "Run claude-executor for <slug>")
```

The `claude-executor` agent self-executes the brief using its own tool surface (`Read`/`Edit`/`Write`/`Bash`/`Glob`/`Grep`) and returns one structured report. No external dispatch script is involved. Use `isolation_level: workspace-write` (or appropriate level) in the metadata; the legacy fields (`sandbox`, `approval`, `skip_git_check`) are accepted for backward compatibility but new briefs must use `isolation_level:`. The agent itself ignores isolation metadata. See `agents/claude-executor.md` for the agent's contract and `docs/executor-contract.md` for the profile comparison.

### Choosing the route

Install profile (`./install.sh --profile minimal|full`, auto-detected from `command -v codex` when unset) determines the default. PM may override per-brief by setting `executor:` in the handover metadata. If fallback is selected for codex, say why in one sentence, then dispatch `Agent(codex-executor)` with the pre-written brief file path. Otherwise, record the Bash task id (route A) or Agent task id (route B) and parse completion using the footer documented in `docs/dispatch-brief.md`.

Main-thread completion handling for the Bash route (steps 1–3 and 5–7 are tool-call orchestration only the main thread can do; the verification body in step 4 is the shared, tested `scripts/dispatch-post-verify.sh`, not re-implemented prose):

1. Keep a small conversation-state row for `task_id`, slug, `brief_file`, `working_dir`, expected files, and status.
2. When the completion notification arrives, read `BashOutput(bash_id: <id>)`; do not infer completion from `.agent-trace/latest.*` symlinks.
3. Parse the footer lines `trace:`, `last:`, `stderr:`, and `exit:` from the captured output.
4. Run the shared post-verify against the **per-run** footer paths (never `latest.*` — those race across concurrent dispatches), passing the brief so `self_verify:` items are checked:

   ```text
   Bash(command: "bash ${PM_DISPATCH_REPO}/scripts/dispatch-post-verify.sh <safe working_dir> --last <safe last> --stderr <safe stderr> --brief-file <safe brief_file> --base <safe base>", description: "Post-verify <slug>")
   ```

   Pass `--base <base>` using the integration base resolved below (the caller-named branch, else `git merge-base --fork-point origin/main HEAD`, else `origin/main`) so the diff evidence is base-correct for non-`origin/main` targets; omit `--base` only when the base is `origin/main` (the script's default). It tails the final message, prints the **tail (last 20 lines)** of the run's stderr (the post-verify script is executor-agnostic, so it does **not** strip the executor's wrapper start/finish banner lines, e.g. `codex-dispatch starting`/`finished`), prints `git diff --stat <base>...HEAD` (merge-base form, so an advanced integration branch doesn't surface unrelated upstream commits) + `status --short` for `<working_dir>`, emits a `FOUND`/`MISSING` line per `self_verify:` item, and exits `0` (ok) or `1` (partial/failed). Read its output: a non-zero exit, a `MISSING` line, or an unbriefed file — appearing in **either** the `<base>...HEAD` diff stat **or** the `status --short` block (uncommitted edits land only in the latter) and not in the brief's `files:` block — makes the result at least `partial`. For stderr, **discount the wrapper start/finish banner lines** — only stderr content *beyond* those banners is unexpected and downgrades the result to `partial`; if the tail is truncated (more than ~20 stderr lines), open the footer `stderr:` path directly before concluding `ok`.
5. **Cross-check execution evidence.** The script's `self_verify:` check confirms the executor *claimed* `cmd: pass` in its final message; it does **not** prove the command ran (the script is executor-agnostic and never parses the codex JSONL). So additionally `grep` the footer `trace:` JSONL for a `command_execution` entry corresponding to each `self_verify:` item. A `self_verify:` item the script reported as `FOUND` but with **no** matching `command_execution` evidence in the trace makes the result at least `partial` — this guards against a fabricated or skipped pass line. (This is the cross-check the previous inline prose performed; it stays in `/pm` because only the main thread can read the executor-specific trace.)
6. On footer `exit: 124`, run the foreground diagnostic checklist, then retry exactly once with the same `brief_file` and flags.
7. On any other non-zero footer exit, stop and report the trace, stderr, and footer exit code for main-thread review.

Briefs must follow the schema at `docs/dispatch-brief.md` (working_dir / goal / files / acceptance, plus self_verify required for file-writing briefs and optional only for read-only briefs where every files entry is explicitly tagged `read:`). codex-executor rejects briefs missing the required fields.

Use `base` as the PR integration branch when the caller names one; otherwise resolve it with `git merge-base --fork-point origin/main HEAD` and fall back to `origin/main` if no fork point is available. The handover extraction, validation, safe argv, and footer parsing contract is covered by `scripts/test-dispatch-handover.sh`.

For PR-gate flows, use `/pr-gate` instead — that skill handles reviewer orchestration; do not re-implement it inline here.
