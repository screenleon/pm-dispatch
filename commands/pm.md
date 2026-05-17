---
description: Route a request to the project-pm agent.
argument-hint: <free-form request, e.g. "status of foo", "add /health endpoint to api">
---

Invoke `project-pm` via Agent. Do not force a model — inherit the main-thread model so the user's own session choice applies (see `docs/model-tier-policy.md` §`/pm`). Brief with: request ($ARGUMENTS), current working directory, and relevant prior-turn context the subagent won't otherwise see.

Relay the PM's user-facing summary. Do not do the PM's job yourself.

**Dispatch route**: Subagents cannot spawn subagents. If PM returns a `dispatch_handover_v1` block, the **main thread** extracts the brief body, writes it to the declared `brief_file`, reads `executor`, validates metadata with `handover_validate_all_metadata`, and then routes by `executor` value:

- `executor: codex` → main-thread Bash to `scripts/codex-dispatch.sh` (primary route)
- `executor: claude-main` → main-thread `Agent(subagent_type: "claude-executor")` with the pre-written brief file path
- any other value is rejected by the validator before this point

The abstract contract both routes implement is documented in `docs/executor-contract.md`. Always source `scripts/lib/handover-validate.sh`, extract and split the fenced block with the shared handover helpers, validate the full metadata header, confirm the metadata/body `working_dir` match, and write `brief_file` via `mktemp -p /tmp brief-<slug>-XXXXXX.md` or equivalent exclusive-create (mode 0600) — `/tmp` is shared, predictable names invite symlink races.

### Route A — `executor: codex`

```text
Bash(command: "bash ${PM_DISPATCH_REPO}/scripts/codex-dispatch.sh --cd <safe working_dir> --model <safe model> --sandbox <safe sandbox> --approval <safe approval> --timeout <safe timeout> --brief-file <safe brief_file>", run_in_background: true, description: "Dispatch codex for <slug>")
```

The template above shows the default-safe stable argument order; omit `--model <safe model>` only when `model: default`. The bash route never emits `--skip-git-check`: validator hard-rejects `skip_git_check: true`, so callers needing that flag must take the `Agent(codex-executor)` fallback instead. Insert only `handover_safe_argv` output into the Bash command. Keep the command on one physical line and never use `cd <dir> && ...`; that compound shape is part of the stale lifecycle leak described in `[[feedback_codex_dispatch_lifecycle_leak]]`.

Use `Agent(codex-executor)` only per the fallback allowlist in `docs/dispatch-brief.md` §Fallback, preserving existing callers that still depend on executor validation.

### Route B — `executor: claude-main`

```text
Agent(subagent_type: "claude-executor", prompt: "<safe brief_file abs path>", run_in_background: true, description: "Run claude-executor for <slug>")
```

The `claude-executor` agent self-executes the brief using its own tool surface (`Read`/`Edit`/`Write`/`Bash`/`Glob`/`Grep`) and returns one structured report. No external dispatch script is involved. Codex-only metadata fields (`sandbox`, `approval`, `skip_git_check`) are still **required by the validator** for schema stability and should be set to canonical no-op values (`workspace-write`, `never`, `false`); the agent itself ignores them. See `agents/claude-executor.md` for the agent's contract and `docs/executor-contract.md` for the profile comparison.

### Choosing the route

Install profile (`./install.sh --profile minimal|full`, auto-detected from `command -v codex` when unset) determines the default. PM may override per-brief by setting `executor:` in the handover metadata. If fallback is selected for codex, say why in one sentence, then dispatch `Agent(codex-executor)` with the pre-written brief file path. Otherwise, record the Bash task id (route A) or Agent task id (route B) and parse completion using the footer documented in `docs/dispatch-brief.md`.

Main-thread completion handling for the Bash route:

1. Keep a small conversation-state row for `task_id`, slug, `brief_file`, `working_dir`, expected files, and status.
2. When the completion notification arrives, read `BashOutput(bash_id: <id>)`; do not infer completion from `.agent-trace/latest.*` symlinks.
3. Parse the footer lines `trace:`, `last:`, `stderr:`, and `exit:` from the captured output.
4. Read `<last>` for the final Codex message; if empty, inspect the JSONL trace for the last `agent_message`.
5. Read `<stderr>` even on exit 0 and surface any content beyond the standard wrapper start/finish banners.
6. Verify `git -C <working_dir> status --short` and `git -C <working_dir> diff --stat <base>...HEAD` against the brief's `files:` block.
7. Check the JSONL trace for `command_execution` evidence matching every `self_verify:` item.
8. Report `ok`, `partial`, or `failed`; skipped verification, unbriefed files, or unexpected stderr make the result at least `partial`.
9. On exit 124, run the foreground diagnostic checklist, then retry exactly once with the same `brief_file` and flags.
10. On any other non-zero exit, stop and report the trace, stderr, and footer exit code for main-thread review.

Briefs must follow the schema at `docs/dispatch-brief.md` (working_dir / goal / files / acceptance, plus self_verify required for file-writing briefs and optional only for read-only briefs where every files entry is explicitly tagged `read:`). codex-executor rejects briefs missing the required fields.

Use `base` as the PR integration branch when the caller names one; otherwise resolve it with `git merge-base --fork-point origin/main HEAD` and fall back to `origin/main` if no fork point is available. The handover extraction, validation, safe argv, and footer parsing contract is covered by `scripts/test-dispatch-handover.sh`.

For PR-gate flows, use `/pr-gate` instead — that skill handles reviewer orchestration; do not re-implement it inline here.
