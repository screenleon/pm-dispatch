# CC-377 spike — Antigravity (`agy`) headless feasibility

**Date**: 2026-06-16
**Verdict**: **DEFERRED — wait for a more mature `agy` release.** `agy` 1.0.8 has free
quota (Gemini 3.x / Claude Sonnet+Opus 4.6 / GPT-OSS via the OAuth token — cost is
*not* the blocker), but its headless `--print` mode is **not yet mature enough**:
no machine-output contract and unreliable non-interactive behavior. CC-377 is
deferred until a future `agy` version ships a usable headless structured mode.
N≥2 abstraction proof not yet achieved by agy; opencode (CC-376) remains the sole
independent third-party adapter.

## Why this spike

CC-377 = second real third-party adapter, intended to prove the v0.6.0 executor
abstraction holds at **N≥2** (not a lucky fit on opencode alone). The pm-dispatch
executor contract (CC-389) requires each adapter to expose: a single output
contract (`.agent-trace/latest.last`), an exit code, and a **per-adapter semantic
terminal event** so `pmctl` post-verify can fail-closed. The gating question:
does `agy` headless mode expose a machine-parseable output the contract can rest
on?

## Environment

- `agy` version **1.0.8** (`~/.local/bin/agy`)
- Auth present: `~/.gemini/antigravity-cli/antigravity-oauth-token` (not the blocker)
- `agy models` works (Gemini 3.x, Claude Sonnet/Opus 4.6, GPT-OSS 120B)

## What was tested (all empirical, on 1.0.8)

| Probe | Result |
|-------|--------|
| `agy -p "<prompt>"` (no stdin redirect) | hangs; killed at 120s, 0B output |
| `agy -p "<prompt>" </dev/null` | runs, but emits **plain-text prose narration**, not JSON; auto-explores workspace; timed out 90s/120s/280s on 3 trivial prompts |
| `--output-format json` / `-o json` | ❌ `flags provided but not defined: -output-format` / `-o` |
| `--format json` | ❌ `flags provided but not defined: -format` |
| `--log-level debug` | ❌ `flags provided but not defined: -log-level` |
| `--stream-format plain` | ❌ `flags provided but not defined: -stream-format` |
| `agy run "<prompt>"` | ❌ no `run` subcommand (opens TTY / bubbletea TUI path) |
| SSE `event:` / `data:` stream | ❌ not observed — output is prose, no `data:` lines |

`agy --help` flag surface is minimal: `--add-dir --continue --conversation
--dangerously-skip-permissions --prompt-interactive --log-file --model --print
--print-timeout --sandbox`. Subcommands: `changelog help install models plugin
update`. No structured-output flag exists in 1.0.8.

## Behavioral findings (1.0.8 `--print` mode)

1. **No machine contract**: output is human-readable agent narration ("I will
   view README.md…"), not JSON/JSONL/SSE. No `--output-last-message` equivalent;
   no terminal event for post-verify to assert on.
2. **Needs stdin closed** (`</dev/null`) or it blocks waiting for stdin EOF.
3. **Unboundedly agentic**: auto-explores the filesystem (ls, git status, file
   reads, home-dir search) even when told "do not use tools".
4. **Unreliable termination**: 3/3 trivial-prompt probes ended in timeout; agy
   itself emitted `Error: timed out waiting for response`.

## Why this blocks a clean adapter

A pm-dispatch adapter mirroring opencode/codex needs structured JSONL + a semantic
terminal event so post-verify can fail-closed. With 1.0.8:

- a text-only adapter would make post-verify a weak heuristic (exit code + non-empty
  prose), which **compromises fail-closed integrity** — a timed-out agy run emits
  prose then an error string; distinguishing success from partial work is fragile.
- forcing a fit by changing the executor contract for prose/no-event executors is a
  **core change**, which by CC-377's own acceptance ("零核心改動即可落地") means the
  abstraction is *not* proven — the opposite of the spike's goal.

## External research vs. ground truth

Community/AI sources claimed `--output-format text|json|stream-json`,
`--format=json --log-level=debug`, `agy run`, and SSE `event:`/`data:` output.
**None exist in 1.0.8** (verified above). They likely describe a newer/different
`agy` build. One cited DEV article reports the same `flags provided but not
defined: -output-format` error, consistent with this finding.

## Recommendation / resume triggers

Defer CC-377 and **wait for a more mature `agy` release** — the tool has free quota,
so it stays the preferred second-adapter candidate once the CLI matures. Re-evaluate
when **either**:

1. A newer `agy` ships a real, stable headless structured-output mode
   (`--output-format stream-json` or equivalent). Resume = re-run the probes above;
   if JSONL + a terminal event appear, build `adapters/antigravity/` mirroring
   `adapters/opencode/`. **This is the primary, expected path.**
2. (Only if agy stalls) The N≥2 proof is reassigned to a different second adapter
   that already exposes a machine contract — though the free-tier CLI pool is
   currently dry (2026-06), so option 1 is favored.

**N≥2 status**: not met by agy. opencode (CC-376) is the lone independent
third-party adapter. Phase 7 lifecycle work was red-lined to start *after* N≥2 —
this gap is an open milestone-sequencing question for the maintainer.
