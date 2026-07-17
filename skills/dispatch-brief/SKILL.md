---
name: dispatch-brief
description: Use when delegating an implementation task to an executor (codex or claude) and you need to author the dispatch brief / handover block. Covers brief structure, the file-list and context lazy-read discipline, model-alias selection, and the dispatch_handover_v1 contract.
---

# Dispatch brief authoring

A **thin pointer skill** — pm-dispatch already owns the brief contract and the
dispatch runtime; this skill tells you where the load-bearing pieces live and the
few rules that prevent the common failure modes. Do not restate the contract here.

## When to use

You are the PM (or main thread) and you are about to hand an implementation task
to an executor via `pmctl dispatch run` (or `/pm`). You need to produce a brief
the executor can act on without re-asking questions.

## Authoritative sources (read these, don't paraphrase)

- **`docs/dispatch-brief.md`** — the brief contract: `dispatch_handover_v1`
  metadata header, the `files:` block + `context:` **lazy-read** discipline
  (read large files on demand; eager-loading blows the context window), the
  `expected_head_sha` state pin, and the §Model aliases table.
- **`agents/project-pm.md`** — how the PM decomposes work and emits exactly one
  fenced `dispatch_handover_v1` block, plus the model-selection guidance.
- **`runtime/lib/handover-validate.sh`** — the validator the main thread runs
  before constructing argv; your metadata values must pass it.
- **`docs/sandbox-limitations.md`** — executor sandbox constraints and
  workarounds. Read this before writing `self_verify` blocks that use `go
  build`, network calls, Docker, or `git commit` — all of these have sandbox
  limitations with documented workarounds (Patterns 1–5).

## Prior-art scan (before writing `files:` / `context:`)

Run `pmctl context reuse-scan <working_dir> "<task description>"` first (pass
the target repo root as the first argument — omitting it scans pm-dispatch
itself, not the task's target).  Paste at most 5 reviewed candidates into
`context:` — do not paste unfiltered output.
See `docs/context-retrieval.md` for full usage.

## Rules that actually bite

1. **Prefer the `default` model** — omit `--model` and let the executor adapter
   resolve its own pinned default. Model identity is executor-specific (the PM
   does not name a wire model). Use `--model codex-spark` only for known-small,
   single-location codex changes (diff < 50 lines, ≤ 2 adjacent files, no new
   interfaces) — it draws from a separate usage pool.
2. **Lazy-read large files** — list them in `files:` with read-on-demand
   instructions in `context:`; never embed BACKLOG.md / synthesis docs verbatim.
3. **Pin state** — include `expected_head_sha` + a `self_verify` line so a moved
   branch fails loudly before any patch.
4. **One handover block** — the content after the standalone `---` is the brief
   body written to `brief_file`; metadata above it is for the main thread.

## Dispatch

Once the brief is authored, dispatch via `pmctl dispatch run --adapter <X>` (see
`/pm` in `commands/pm.md`). The adapter is thin; pmctl owns brief-validate →
guard → route → invoke → post-verify.
