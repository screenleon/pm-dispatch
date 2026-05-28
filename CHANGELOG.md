# Changelog

All notable changes to pm-dispatch are documented here.
Format inspired by [Keep a Changelog](https://keepachangelog.com/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added

- **`core/policy/isolation-level.yaml`** — new policy enum: `none | read-only | workspace-write | sandboxed`; adapters translate these intent values to executor-native flags (CC-262 M1).
- **`adapters/claude/isolation-map.yaml`** — no-op translation table for claude-executor; all four isolation levels map to empty native-flags (CC-262 M1).
- **`scripts/lib/portable.sh` `_portable_sha1()`** — cross-platform SHA-1 helper: tries `sha1sum` (GNU/Linux), falls back to `shasum -a 1` (macOS/BSD), returns 1 with a logged warning if both are missing. `FAKE_SHA1_MISSING=1` test shim included (CC-263).

### Changed

- **`scripts/lib/state-writer.sh` `_sw_project_key()`** — replaces raw `sha1sum` call with `_portable_sha1()`; hash failures now log via `_sw_log_error` and fall back to `global` partition (CC-263).
- **`core/README.md`** and **`agents/project-pm.md`** — removed v0.3.x forward-reference language now that M1 is shipped; prose updated to present tense (CC-261).
- **`scripts/test-test-harness.sh`** — removed dead `assert_contains()` definition (never called; file uses own `pass_case`/`fail_case` framework for cyclic-test-vs-SUT reasons). Added header comment documenting the framework choice (CC-256).
- **`scripts/test-run-all-tests.sh`** — added comment above local `assert_contains()` explaining why it stays local: orchestrator uses `pass_case`/`fail_case`, not the unified harness counters (CC-256).
- **BACKLOG** — closed CC-254 (harness assert_* no auto-pass; shipped PR #149) and CC-256 (3-file assert_* migration audit; completed).

### Removed

- **`/caveman` slash command (`commands/caveman.md`)** -- token-compression skill removed; text compression causes information loss in design/architecture discussions where omitted constraints lead to misunderstandings (CC-265).
- **`/caveman-commit` slash command (`commands/caveman-commit.md`)** -- removed alongside `/caveman` (CC-265).

### Test coverage

- `test-state-store.sh case_project_key_no_sha1sum` — stubs both sha1sum and shasum, asserts _sw_project_key returns `global` non-fatally (CC-263).

## [0.2.0] — 2026-05-22

**Theme**: Cross-platform operations, environment health tooling, and schema improvements.

### Added

- **`scripts/doctor.sh`** — install environment health check: verifies `claude`/`jq` on PATH, hooks wired in `settings.json`, memory dir present, scripts executable, frontmatter lint clean. Accepts `--profile minimal|full|auto`; each failing check prints a concrete remediation step. Wired into `install.sh` post-install and `scripts/run-all-tests.sh` (CC-058).
- **`scripts/run-all-tests.sh`** — standalone test aggregator that runs all per-subsystem suites and produces a single pass/fail summary; replaces `install.sh --verify` as the canonical health check tool (CC-104n).
- **`scripts/lib/portable.sh` `serialize_with_lock()`** — cross-platform locking shim: prefers `flock` when available, falls back to `mkdir_lock`. Eliminates `flock` hard-dependency on Windows Git Bash (CC-104p).
- **`uninstall.sh`** — manifest-driven uninstall removes only files recorded in the install manifest; safety guard rejects dst not strictly under the managed root.
- **`install.sh` copy-mode refresh semantics** — re-running `install.sh` now compares `sha256(src)` vs `sha256(dst)` directly; only changed files are re-copied (CC-221).
- **`install.sh` jq prerequisite check** — jq is checked at the top of the installer before any tests run; error includes a platform-aware install hint (CC-104l).
- **`install.sh` copy-mode banner** — when files were installed via copy fallback, a summary banner at the end reminds the user to re-run after source edits (CC-104v).
- **pm-schema v1.1** — BACKLOG index table adds `Priority` (P1/P2/P3) and `Epic` columns; `pm/scripts/validate.sh` and `pm/scripts/rollup.sh` updated (CC-052).
- **pm-schema v1.2** — adds `design` and `spike` epic enum values; validator and rollup updated (CC-104/CC-205).
- **`DECISIONS.md`** — repo-level architectural decision log; `validate.sh` guards that referenced IDs exist (CC-067).
- **`CONTRIBUTING.md`** + **`CODE_OF_CONDUCT.md`** — source-available contributor guidelines + Contributor Covenant 2.1 (CC-031).
- **`commands/skill-refine.md`** Prerequisites section documenting `CLAUDE_MEMORY_DIR` requirement (CC-025b).
- **`scripts/test-commands.sh`** — contract-lint CI test for `pre-impl.md` Q4 contract and agent output-brevity contract; wired into `lint.yml` `test-commands` job (CC-039/CC-053). `/caveman` and `/caveman-commit` contracts were removed in CC-265.

### Changed

- **`scripts/lint-frontmatter.sh`** — complete YAML flow-collection validation matching PyYAML semantics: dq escape whitelist, adjacent-quote detection, tab-indented list item rejection, and empty-entry check (`[foo,,bar]`). Covers all four collection paths (key-level `[...]` / `{...}`, list-item `[...]` / `{...}`). Regression suite expanded from 35 to 68 test cases (CC-056/CC-058).
- **Hook scripts** — rewrote `hook-log-claude-usage.sh`, `hook-inject-memory.sh`, `hook-session-summary.sh`, and `hook-save-rate-limits.sh` from python3 to jq. Eliminates python3 as a runtime dependency; fixes Windows Git Bash failures caused by the Microsoft Store python3 stub (CC-104t).
- **`install.sh`** — `link_or_copy()` now detects real-directory dst conflict before attempting `ln -s` (CC-104u); on Windows Git Bash, managed directories (`agents/`, `commands/`, etc.) are created as PowerShell directory junctions so they auto-sync after `git pull` (CC-207).
- **`hook-routing-log.sh`** — replaced `flock`/fd9 pattern with `serialize_with_lock()` portable shim (CC-104p).
- **`pm/scripts/validate.sh`** — bidirectional Index ↔ Section consistency check; CHANGELOG drift detection (CC-030/CC-046).
- **`agents/project-pm.md`** Rule B — added point 5 (next-layer sweep) to NO-GO fix-loop protocol; added contract-test rule to brief-writing section (CC-039).
- **`commands/pre-impl.md`** — added Q4 (contract test completeness) to Step 2 (CC-039).

### Fixed

- `hook-routing-log.sh` row-loss on Windows: `flock` is Linux-only; `serialize_with_lock()` shim restores concurrent-safe appends on Git Bash (CC-104p).
- `install.sh` copy-mode idempotency: stale copies were not refreshed on re-install because sha comparison used the old manifest hash instead of comparing src vs dst directly (CC-221).

### Known limitations

- macOS is documented but not dogfood-tested. Install code path is the same as Linux; report issues via GitHub Issues.
- Windows Git Bash: individual `scripts/*.sh` helper files are still installed via copy (not junction); re-run `bash install.sh` after pulling to refresh changed copies.
- `CC-200..CC-204` reuse-debt items deferred: shared executor-router, profile-detect shim, handover validator framework, test-harness lib, hook framework.

### Test coverage

Added since v0.1.0:
- 68 lint-frontmatter regression cases (was 35)
- 32 doctor health-check cases
- 23 run-all-tests aggregator cases
- Additional install/uninstall/portable cases

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
