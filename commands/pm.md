---
description: Route a request to the project-pm agent.
argument-hint: <free-form request, e.g. "status of foo", "add /health endpoint to api">
---

Invoke `project-pm` via Agent. Do not force a model — inherit the main-thread model so the user's own session choice applies (see `docs/model-tier-policy.md` §`/pm`). Brief with: request ($ARGUMENTS), current working directory, and relevant prior-turn context the subagent won't otherwise see.

Relay the PM's user-facing summary. Do not do the PM's job yourself.

**Codex dispatch route**: Subagents cannot spawn subagents. If PM returns a `codex_dispatch_handover_v1` block, the **main thread** extracts the brief body, writes it to the declared `brief_file`, and dispatches with direct background Bash as the primary route:

```text
Bash(command: "bash /home/screenleon/github/pm-dispatch/scripts/codex-dispatch.sh --cd '<working_dir>' --sandbox '<sandbox>' --approval '<approval>' --timeout '<timeout>' --brief-file '<brief_file>'", run_in_background: true, description: "Dispatch codex for <slug>")
```

Keep the command on one physical line, use single quotes around path values, and never use `cd <dir> && ...`; that compound shape is part of the stale lifecycle leak described in `[[feedback_codex_dispatch_lifecycle_leak]]`.

Use `Agent(codex-executor)` only as the documented fallback, preserving existing callers that still depend on executor validation. The fallback allowlist is:

| Condition | Rationale |
|---|---|
| Strict pre-flight validation is the primary need. | `codex-executor` hard-rejects malformed briefs before a long dispatch runs. |
| Main-thread context is near-full. | Validation and completion parsing move out of the main thread when context pressure is the limiting factor. |
| Sync workflow must remain serialized. | Some composed flows need foreground sequencing rather than async completion notifications. |
| Direct Bash route is locally unavailable. | Missing script path, unreachable `working_dir`, or no usable Bash tool means the primary route cannot run. |
| User explicitly requests codex-executor validation. | User intent overrides the ergonomic default when safety rules still hold. |

If fallback is selected, say why in one sentence, then dispatch `Agent(codex-executor)` with the pre-written brief file path. Otherwise, record the Bash task id and parse completion using the footer documented in `docs/codex-brief.md`.

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

Briefs must follow the schema at `docs/codex-brief.md` (working_dir / goal / files / acceptance, plus self_verify required for file-writing briefs and optional only for read-only briefs where every files entry is explicitly tagged `read:`). codex-executor rejects briefs missing the required fields.

For PR-gate flows, use `/pr-gate` instead — that skill handles reviewer orchestration; do not re-implement it inline here.
