# Changelog

All notable changes to pm-dispatch are documented here.
Format inspired by [Keep a Changelog](https://keepachangelog.com/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added
- **`commands/skill-refine.md`** — added Prerequisites section documenting `CLAUDE_MEMORY_DIR` requirement and export example (CC-025b).
- **`scripts/test-skill-refine.sh`** — added `case_no_args_exits_2_with_usage` and `case_multi_args_exits_2_with_usage` guard tests (CC-025b).
- **`scripts/test-commands.sh`** — new contract-lint script asserting `/caveman` and `/caveman-commit` behavioral contracts; wired into CI (`lint.yml`).
- **`.github/workflows/lint.yml`** — added `test-commands` CI job.

### Changed
- **`agents/project-pm.md`** Rule B — added point 5 (next-layer sweep) to the NO-GO fix-loop protocol; added new contract test script rule to the brief-writing section (CC-039).
- **`commands/pre-impl.md`** — added Q4 (contract test completeness) to Step 2; updated heading to reflect Q1–Q4 (CC-039).

## [0.1.0] — 2026-05-17

First public release. The repo was made source-available (public read/fork; external PRs not accepted at this time). This release bundles the **CC-OSS** epic that prepared the codebase for that transition.

### Added
- **`agents/claude-executor.md`** — second concrete executor (alongside `codex-executor`) so the repo runs without the Codex CLI. The five reviewer agents (critic / qa-tester / architecture-reviewer / security-reviewer / risk-reviewer) were always Claude-native; codex was only the runner wrapper.
- **`install.sh --profile minimal|full`** — install profile flag. `minimal` skips the codex-only guard hooks; `full` wires every hook. Auto-detect when unset: `command -v codex` present → `full`, else `minimal`.
- **`scripts/lib/portable.sh`** — cross-platform shim: `realpath_m()` / `safe_tmpdir()` / `mkdir_lock()` (replaces `flock`) / `detect_platform()` / `file_size_bytes()` (GNU/BSD/`wc -c` fallback). Makes Windows Git Bash + macOS + Linux uniform.
- **`scripts/codex-dispatch.sh` `--model` alias mapping** — PM-facing short alias `codex-spark` resolves to wire-format `gpt-5.3-codex-spark` + reasoning effort `high`; unknown aliases fall through unchanged.
- **`/pr-gate` `--executor codex|claude|auto`** — gate orchestration mirrors the `/pm` executor split; minimal-profile users can run the gate via main-thread `Agent()` calls. New `pr-gate-handover_v1` fenced schema for claude-mode reviewer fan-out.
- **`docs/executor-contract.md`** — abstract executor interface (input / output / profiles / forward-compat).
- **`docs/pr-gate-handover-schema.md`** — handover schema for the `/pr-gate` claude path.
- **`docs/platform-support.md`** — Linux/macOS/WSL2 first-class; Windows Git Bash + minimal profile supported; install dependency table.
- **`docs/GETTING_STARTED.md`** — clone → install → first `/pm` walkthrough for new readers.
- **`docs/CONCEPTS.md`** — explains the four Claude Code extensibility surfaces (hooks-as-policy / slash commands / subagents / memory tiers) with a worked `/pm` example.
- **`docs/memory-system.md`** — memory dir layout + four tiers + bootstrap-empty pattern.
- **`CONTRIBUTING.md`** + **`CODE_OF_CONDUCT.md`** — source-available stance + Contributor Covenant 2.1.
- **`commands/skill-refine.md`** (CC-025) — `/skill-refine <skill-name>` slash command wraps `scripts/skill-refine.sh` feedback-signal bundler.
- **`commands/*.md`** — `## What / ## When to use / ## Example` sections on 7 commands (mem-distill / mem-log / mem-recall / mem-search / memory-compress / pre-impl / skill-refine).

### Changed
- All hardcoded `/home/<user>/github/pm-dispatch` paths in production docs/agents/commands replaced with `${PM_DISPATCH_REPO}` placeholder; `install-hooks.sh` auto-derives it from `git rev-parse --show-toplevel` when unset.
- README intro reframed for first-time public readers (source-available stance + top-of-file links to `GETTING_STARTED.md` and `CONCEPTS.md`).
- `scripts/codex-pr-gate.sh` renamed to `scripts/pr-gate.sh`; `scripts/test-codex-pr-gate.sh` renamed to `scripts/test-pr-gate.sh`.
- `commands/codex-pr-gate.md` and `commands/pr-gate.md` merged into a single `commands/pr-gate.md` that invokes `scripts/pr-gate.sh`; the old Agent-subagent approach is replaced by the script's `--parallel` mode.
- `scripts/lib/handover-validate.sh` `executor` enum opens from `{codex}` to `{codex, claude}`; codex-only metadata fields (`sandbox`/`approval`/`skip_git_check`) remain required for schema stability but are accepted-as-no-op by `claude`.
- `scripts/hook-routing-log.sh` `flock` + fd9 pattern replaced by `mkdir_lock`; audit message strings preserved verbatim for log compatibility.

### Fixed
- `scripts/hook-routing-log.sh` rotation: `stat -c %s` was Linux-only and silently no-op'd on macOS/BSD (rotation never triggered). Now uses `file_size_bytes()` shim (GNU stat → BSD stat → `wc -c` fallback).

### Known limitations
- Codex CLI not validated on Windows; `--profile full` falls back to `minimal` automatically on Windows with a stderr warning.
- External PRs are not accepted at this time. Issues are welcome but have no SLA. See `CONTRIBUTING.md`.
- `CC-200..CC-204` are surfaced architectural reuse-debt items deferred to post-release: shared executor-router, profile-detect shim, handover validator framework, test-harness shared lib, hook framework.

### Test coverage
- 299 hook regression cases
- 16 codex-dispatch cases (CC-047 model alias mapping)
- 63 dispatch-handover schema cases
- 43 install / profile cases
- 4 claude-executor cases
- 15 portable shim cases
- 41 pr-gate cases
- 9 pr-gate-profile (executor split) cases
- **Total: 490 cases**, plus `lint-scripts` (37 files) and `lint-agents` (8 agents).

### Added
- `scripts/hook-routing-log.sh` (CC-028): PostToolUse hook that auto-appends one
  JSONL row per Brief/Dispatch routing decision to the active project's
  `routing_log.md` (inside a marker-fenced auto-block); triggers on Bash
  `codex-dispatch.sh` invocations and Agent dispatches whose `subagent_type` is
  `codex-executor` (or aliases). Mirrors CC-027's `hook-tool-trace.sh` design
  family — metadata-only, non-blocking, multi-path JSON hedge, single-archive
  1 MiB rotation. `q_hit` / `second_thoughts` fields stay null at hook time;
  post-classification deferred to a future `/routing-distill`.
- `scripts/migrate-routing-log.sh` (CC-028): one-time migrator invoked by
  `install-hooks.sh` on first wire-in; converts existing free-form bullet
  sections in `routing_log.md` into JSONL rows inside the new auto-block,
  preserves the legacy markdown table byte-for-byte, writes a
  `routing_log.md.bak` atomic backup before any modification.
- `scripts/pr-gate.sh`: **parallel mode** (`--parallel`) — one independent
  codex session per reviewer followed by a project-pm synthesis session; avoids
  shared-context anchoring and token pressure between reviewers. Default remains
  sequential (one combined session); use `--parallel` when reviewer independence
  matters (auth/payment/sensitive paths) or when token budget allows it.
- `scripts/pr-gate.sh`: **adjacent test file auto-detection** — for each
  changed `.go` source file the companion `*_test.go` is automatically appended
  to the reviewer brief; for `.ts`/`.tsx` sources the `__tests__/<name>.test.ts(x)`
  and sibling `<name>.test.ts(x)` are appended. Files already in the diff are
  de-duplicated. This gives reviewers visibility into coverage gaps in unchanged
  test files.
- `agents/qa-tester.md`: **Step 0 pre-flight coverage enumeration** added to
  Mode C — the reviewer must enumerate every new behavioral unit (function,
  param, field, handler) from the diff and verify adjacent test coverage before
  proceeding to the audit; missing coverage is a blocking finding.
