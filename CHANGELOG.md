# Changelog

All notable changes to pm-dispatch are documented here.
Format inspired by [Keep a Changelog](https://keepachangelog.com/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added

- **`scripts/lib/pmctl-config.sh`** — shared config loader; `pmctl dispatch run` now owns config resolution (CC-293, PR #216). `pmctl_dispatch_run` calls `pm_config_load` and exports `PM_CFG_TIMEOUT` + `PM_CFG_DEFAULT_MODEL` to the adapter subprocess — adapters receive config values via env and drop all config-loading code. Precedence: adapter-specific env vars (`CODEX_DISPATCH_TIMEOUT`, `CLAUDE_DISPATCH_TIMEOUT`) > pmctl-exported config > adapter built-in default (1200 / `default` alias). Removes ~50 LOC of duplicated config-parsing from `adapters/codex/dispatch.sh` and `adapters/claude/dispatch.sh`.
- **`skills/` starter SKILL.md files** — `skills/dispatch-brief/SKILL.md` and `skills/pr-gate-review/SKILL.md` (CC-061), the first concrete Agent Skills, aligned to the Anthropic layout (`skills/<name>/SKILL.md` with `name` + `description` frontmatter). Both are **thin** pointer skills — they route to the existing contract/runtime (`docs/dispatch-brief.md`, `agents/project-pm.md`, `/pr-gate`, `scripts/pr-gate.sh`) rather than duplicating logic — giving CC-014/015/026 the directory base they were waiting on. `scripts/lint-frontmatter.sh` now also scans `skills/<name>/SKILL.md` (closing a doc-drift where the README claimed skills/ was linted but the scanner only covered `agents/` + `commands/`); +2 `test-lint-frontmatter.sh` cases lock in the skills/ scan.
- **`scripts/test-layer-boundaries.sh`** — the executable layer-boundary enforcer (CC-233), the last M3 spine ticket. Keeps `core/` declarative + CLI-agnostic (no shell/executables; only `.yaml`/`.json`/`.md`; no CLI-product-named files/dirs; no CLI name as a field-name **key** — enum *values* and prose are allowed) and keeps thin adapters from re-absorbing the shared flow (`adapters/**/*.sh` non-comment lines must not call `brief-validate` / guard / route / `dispatch-post-verify` / pmctl; executor-specific invocation + output glue + state/usage logging are allowed). 12 cases: 5 real-repo enforcement checks + 7 self-tests that plant violations. Dedicated CI job (CC-233).
- **`adapters/claude/dispatch.sh`** — thin claude executor adapter (CC-266), symmetric to the codex adapter. Invokes headless `claude --print --output-format json` as the canonical, **host-independent** claude executor (a CLI subprocess driven by `pmctl dispatch run --adapter claude`), so codex-as-PM can drive claude-as-executor — completing the 4-cell PM×executor matrix. `agents/claude-executor.md` (Agent-spawn) is retained as the same-host optimization when Claude is the PM. Self-snapshot crash-safety; extracts JSON `.result` → `.agent-trace/latest.last` (the only pmctl-facing artifact); best-effort state-store row (`executor:"claude"`) + `claude`-pool usage logging. 14-case suite in `scripts/test-claude-dispatch.sh` (fake claude on PATH).
- **`scripts/hook-claude-write-guard.sh` + `claude` guard profile** — closes the guard gap so `pmctl dispatch run --adapter claude` is validated AND guarded (fail-closed preserved). The brief-file pre-write policy mirrors codex (`/tmp/brief-*.md`); the hook is NOT wired as a PreToolUse hook (claude-executor self-executes under harness/`--permission-mode`, so a `/tmp`-only PreToolUse guard would block its legitimate work-dir edits). `pmctl-guard.sh` now accepts `--profile pm|codex|claude` (CC-266).
- **`scripts/lib/pmctl-dispatch.sh` + `pmctl dispatch run`** — executor-agnostic dispatch orchestrator (CC-289, approach B). pmctl OWNS the shared flow: resolve adapter by convention (`adapters/<name>/dispatch.sh`) → route → `brief-validate` → `pmctl guard check` (per-profile policy) → invoke adapter subprocess → read the `.agent-trace/latest.last` output contract → `dispatch-post-verify`. The only data read back from an adapter is `latest.last` + exit code; no executor-specific tokens live in pmctl. Replaces the prior `dispatch run` stub. **Policy invariants (no bypass door):** `--brief-file` is required and the inline `--` form is refused (every dispatch is validated + guarded); `--adapter` must be a bare identifier `^[a-z][a-z0-9_-]*$` (no path traversal); the resolved `dispatch.sh` must be a regular file whose physical path stays inside `adapters/` (symlink/boundary-escape rejected); routing is a mandatory allowlist and an unavailable router/guard fails closed.
- **`adapters/codex/dispatch.sh`** — the codex adapter, relocated from `scripts/codex-dispatch.sh` (now a compatibility **symlink shim** so existing callers keep working; to be removed in a later cleanup). Stays thin: executor invocation + output-contract glue only. Self-snapshot crash-safety preserved; repo-root resolution now follows the shim symlink (CC-289).
- **`scripts/test-pmctl-dispatch.sh`** — 17-case suite for the orchestrator: missing/unknown adapter, invalid adapter name, symlinked-adapter rejection, adapter-by-convention resolution + route trace, non-core arg passthrough, brief-validation block, guard deny, inline-form refusal, fail-closed router/guard branches, missing `--cd`/`--brief-file`, happy-path post-verify, adapter exit-code passthrough, and post-verify failure (CC-289).
- **`scripts/dispatch-post-verify.sh`** — executor-agnostic Phase 3 post-verify pipeline: reads `.agent-trace/latest.last`, enforces exact `cmd: pass` whole-line self-verify match, validates symlink targets stay inside `.agent-trace/`, and rejects `failed`/`partial`/`blocked` executor status. 21 fixture-based test cases in `scripts/test-dispatch-post-verify.sh` (CC-264 PR B).
- **`scripts/test-dispatch-post-verify.sh`** — 21-case fixture suite covering happy path, boundary, negative inputs, symlink safety, and the exact executor output contract (CC-264 PR B).
- **`scripts/test-claude-executor.sh`** — 5 regression cases for the claude-executor trace-write and self-verify contract (CC-264b).
- **`core/policy/isolation-level.yaml`** — new policy enum: `none | read-only | workspace-write | sandboxed`; adapters translate these intent values to executor-native flags (CC-262 M1).
- **`adapters/claude/isolation-map.yaml`** — no-op translation table for claude-executor; all four isolation levels map to empty native-flags (CC-262 M1).
- **`scripts/lib/portable.sh` `_portable_sha1()`** — cross-platform SHA-1 helper: tries `sha1sum` (GNU/Linux), falls back to `shasum -a 1` (macOS/BSD), returns 1 with a logged warning if both are missing. `FAKE_SHA1_MISSING=1` test shim included (CC-263).

### Fixed

- **`scripts/lib/pmctl-dispatch.sh` + `adapters/codex/dispatch.sh` + `adapters/claude/dispatch.sh`** — fix concurrent dispatch race on `latest.*` symlinks (CC-305, PR #216). `pmctl dispatch run` now tees adapter stdout to a temp file, parses the per-run `last:`/`stderr:` footer paths, and passes them as `--last`/`--stderr` flags to `dispatch-post-verify.sh`. Post-verify uses explicit per-run artifact paths rather than `latest.*` symlinks, eliminating the race where a concurrent second dispatch overwrites `latest.*` before the first run's post-verify reads it. `latest.*` symlinks remain updated by adapters for human observation only. Regression: stale `latest.last` avoidance case + tee `PIPESTATUS` propagation case added to `scripts/test-pmctl-dispatch.sh`.
- **`install.sh` / `uninstall.sh` / `scripts/install-hooks.sh` / `scripts/uninstall-hooks.sh`** — honor an explicit `CLAUDE_HOME` env override so install/uninstall can target an alternate directory (sandbox / rehearsal) without overriding the whole `$HOME`. Previously `CLAUDE_HOME` was hardcoded to `$HOME/.claude`, and bare `$HOME/.claude` references (`.pm` dest + install manifest in install.sh; the hook `settings.json` + `statusline-chain.conf` in both install-hooks.sh and uninstall-hooks.sh; the `.pm-dispatch` removal in uninstall.sh) bypassed it — so there was no safe way to test an install without touching the real config. All destinations now derive from `CLAUDE_HOME`, passed per-call to the hook (un)install sub-scripts (not exported, so it does not leak into the `--verify` preflight's nested test installs). New `test-install.sh` cases assert an override redirects both install and uninstall, removes the override's hook wiring, and leaves a sentinel `$HOME/.claude` config untouched (CC-294).
- **`scripts/pr-gate.sh`** — pre-create gate output file (`touch "$OUTPUT_FILE"`) before emitting the `pr-gate-handover_v1` handover block; fixes silent result loss when a background `claude-executor` subagent cannot `Write` to a new file path (CC-267).
- **`scripts/pr-gate.sh`** — escape literal `$` in unquoted heredoc templates (`\$)`, `\$'`) in the brief escalation regex and self-verify grep pattern to prevent sporadic bash parse errors (CC-257 residual).
- **`adapters/codex/dispatch.sh`** — dispatch now pins pm-dispatch's own default model (the `default` alias → `gpt-5.5` via `share/model-aliases.tsv`; `gpt-5.4` fallback) instead of letting omitted `--model` inherit the host's `~/.codex/config.toml` default. Previously, hosts whose interactive codex default was `gpt-5.3-codex-spark` silently ran **pr-gate and `/pm` dispatch on the spark model** (lower context ceiling, separate usage pool) — wrong for analysis-heavy work. The reserved `dispatch.default_model` config key is now wired (precedence: `--model` flag > config > built-in `default` alias). `share/model-aliases.tsv` gains a data-backed `default → gpt-5.5` alias (the adapter references the alias, so the wire id lives in the TSV alone) plus `gpt-5.5`/`gpt-5.4` rows; `scripts/lib/handover-validate.sh` now accepts dotted wire ids so every alias is a valid handover `model:` value. `codex-spark` stays opt-in (CC-292).

### Changed

- **`commands/pm.md` + `scripts/dispatch-post-verify.sh`** — thin-`/pm` post-verify reuse (CC-059, M4's last ticket; reshaped from the obsolete "move runtime into `pm-dispatch-runner.sh`" — M0–M3 already extracted that into `scripts/lib/`, and `pm.md`'s remaining steps are main-thread tool-call orchestration that cannot live in shell). The Bash-route completion steps 4–8 (`<last>` read, stderr surface, git diff/status, `self_verify:` match) were duplicated as prose in `pm.md` while `scripts/dispatch-post-verify.sh` (CC-264b) already implemented the same logic **with tests**. `dispatch-post-verify.sh` now accepts optional `--last`/`--stderr`/`--brief-file` flags so `/pm` can post-verify the **per-run** paths parsed from the dispatch footer (race-safe; `latest.*` symlinks race across concurrent dispatches), plus `--base <ref>` so the diff evidence honors the caller-selected integration base via **merge-base (`<base>...HEAD`)** semantics — preserving `/pm`'s base-aware verification for non-`origin/main` targets and not surfacing unrelated upstream commits when the integration branch has advanced; absent flags it falls back to `latest.*` + `origin/main`, leaving the positional `<work_dir> [brief_file]` contract used by `pmctl dispatch run` + codex-executor unchanged. The `.agent-trace/` symlink-containment guard now covers flag-supplied paths too, and a flag-supplied `--stderr` is **fail-closed** (a missing supplied artifact → FAILED, signaling a broken footer parse / lost artifact) while the positional `latest.stderr` path stays optional for `pmctl dispatch run` + codex-executor. `pm.md`'s verification body collapses to one tested `dispatch-post-verify.sh` call; the JSONL `command_execution` evidence cross-check (proving each `self_verify:` item actually ran, vs. the script's final-message `cmd: pass` claim) is **retained** as an explicit main-thread step the executor-agnostic script cannot do. The flag parser also guards value-taking flags against a missing/flag-shaped value (`--last --stderr X` fails as usage, not a confusing not-found). `test-dispatch-post-verify.sh` +17 cases (override happy-path, containment rejection for `--last`/`--stderr`, nonexistent-path stop, stderr fallback, supplied-`--stderr` fail-closed, `--brief-file`, ambiguous brief, unknown flag, missing-value, flag-as-value, the full `/pm` flag-combo shape, `--base` integration-base diff with base-dependent content assertion, `--base` merge-base exclusion of an advanced upstream, `--base` HEAD fallback, and the `--` positional sentinel); 21→38, all green.
- **`docs/architecture/v0.3.0-synthesis.md` + `MILESTONES.md`** — reconciled the architecture blueprint with the as-built code after a read-only audit (CC-295). Added a **Conformance status (as-built)** section: (A) deliberate divergences now adopted as canonical — `runtime/` realized as `cli/pmctl` + `scripts/lib/*`, symmetric codex+claude adapters in v0.3.0, `pmctl` ships backlog/guard/dispatch (rest → v0.4.0), live numbering M0–M6; (B) known-open divergences documented as pending a scope decision — state single-writer rule unmet, `routing_log.md` still machine-written, `Event`/`Review`/`Decision` schema-only, `pm/` not folded into `core/`, no `mcp/README.md` / `pmctl --json`. Inline `AS-BUILT` notes added to §5.1/§6/§7. No code change.
- **`agents/claude-executor.md`** — self-verify format hardened: exact whole-line `cmd: pass` / `cmd: fail: <reason>` matching; `status:blocked` check; portable `realpath`; trace-dir symlink guard; `OK-NOBRIEF` mode for briefless runs (CC-264b).
- **`docs/executor-contract.md`** — updated with filesystem output contract details and executor `latest.last` symlink timestamp format (CC-264b).
- **`scripts/hook-save-rate-limits.sh`** — added `CLAUDE_STATUSLINE_CHAIN_ACTIVE` / `CAS_STATUSLINE_CHAIN_ACTIVE` guard to prevent infinite loop when a chain script calls back into the same hook.
- **`scripts/run-all-tests.sh`** — registered `test-dispatch-post-verify.sh` and `test-claude-executor.sh` suites (CC-264 PR B). Registered `test-pmctl-dispatch.sh`; mirrored the new suite into `test-run-all-tests.sh` (count 37→38) (CC-289).
- **`cli/pmctl`** — `dispatch run` now sources `executor-router` + `pmctl-dispatch` and routes to `pmctl_dispatch_run`; the legacy stub is removed (CC-289).
- **`scripts/lib/executor-router.sh`** — `dispatch_via_codex` now emits the canonical `adapters/codex/dispatch.sh` path instead of the legacy `scripts/codex-dispatch.sh` shim, so internal callers depend on the real adapter and shim removal touches no internal call sites (CC-289).
- **`adapters/claude/isolation-map.yaml`** — filled the previously no-op map with a real claude schema: `isolation_level → claude --permission-mode` (none→bypassPermissions, read-only→default, workspace-write/network/sandboxed→acceptEdits). Verified empirically that headless `claude -p` honors these (acceptEdits edits; default denies writes with no approver) (CC-266).
- **`scripts/run-all-tests.sh` + `scripts/test-run-all-tests.sh` + `.github/workflows/lint.yml`** — registered `test-claude-dispatch.sh` (suite count 38→39; dedicated CI job; added to shellcheck `ignore_names` as a sourcing test) (CC-266).
- **`scripts/run-all-tests.sh` + `scripts/test-run-all-tests.sh` + `.github/workflows/lint.yml`** — registered `test-layer-boundaries.sh` (suite count 39→40; dedicated CI job; shellcheck `ignore_names`) (CC-233).
- **`scripts/lib/state-writer.sh` `sw_append_dispatch_run`** — new shared run-row builder (CC-305, PR #216). Centralizes state-store dispatch run-row construction (schema_version, executor, task_id, model, timestamps, paths); `adapters/codex/dispatch.sh` and `adapters/claude/dispatch.sh` each replace ~50 LOC of duplicated jq blocks with a single `sw_append_dispatch_run` call. `sw_extract_task_id` helper added alongside it.
- **`scripts/lib/pmctl-fs.sh` `pmctl_validate_adapter_name`** — adapter name regex aligned to `^[a-z][a-z0-9_-]*$` (was `^[a-z][a-z0-9-]*$`, missing underscore; now matches docs and `docs/spikes/cc215-adapter-generate-codex-plan.md`) (CC-305, PR #216).
- **`scripts/test-claude-dispatch.sh`** — 3 new cases: `dispatch.default_timeout` config precedence, `CLAUDE_DISPATCH_TIMEOUT` env override, state-store `executor:"claude"` + task_id row verification (CC-305, PR #216).
- **`pmctl adapter generate`** — now scaffolds an executable `dispatch.sh` stub (added to `generated_files`) alongside `run.sh`, so a generated adapter is reachable through `pmctl dispatch run` and fails loudly until wired rather than tripping "unknown adapter"; generated README documents the two-script structure + allowlist registration (CC-289, addressing gate feedback).
- **`adapters/codex/dispatch.sh`** — alias/isolation-map fallbacks gained a repo-source-layout (`../../`) tier so resolution holds if the self-snapshot bootstrap is bypassed in the relocated path (CC-289).
- **`scripts/test-pmctl-adapter-generate.sh`** — fixture now carries the dispatch orchestrator libs; the "reaches dispatch route" case asserts the real orchestrator is reached rather than the old stub message (CC-289).
- **`scripts/lib/state-writer.sh` `_sw_project_key()`** — replaces raw `sha1sum` call with `_portable_sha1()`; hash failures now log via `_sw_log_error` and fall back to `global` partition (CC-263).
- **`core/README.md`** and **`agents/project-pm.md`** — removed v0.3.x forward-reference language now that M1 is shipped; prose updated to present tense (CC-261).
- **`scripts/test-test-harness.sh`** — removed dead `assert_contains()` definition (never called; file uses own `pass_case`/`fail_case` framework for cyclic-test-vs-SUT reasons). Added header comment documenting the framework choice (CC-256).
- **`scripts/test-run-all-tests.sh`** — added comment above local `assert_contains()` explaining why it stays local: orchestrator uses `pass_case`/`fail_case`, not the unified harness counters (CC-256).
- **BACKLOG** — closed CC-254 (harness assert_* no auto-pass; shipped PR #149) and CC-256 (3-file assert_* migration audit; completed).

### Deprecated

> Sunset target: **v0.5.0** — these are kept through v0.3.0 + v0.4.0 (two official releases) then removed. Tracked by **CC-296**.

- **`pmctl guard check --profile <pm|codex|claude>`** — superseded by `--role <pm|executor>` + `--runtime <codex|claude>` (CC-291). Still accepted as a back-compat alias that maps onto `(role, runtime)` and prints a one-line stderr deprecation warning. Migrate callers to `--role`/`--runtime`.
- **`scripts/codex-dispatch.sh` compatibility symlink shim** — the real adapter is `adapters/codex/dispatch.sh` (CC-289). The shim keeps external callers working; internal callers already use the canonical path. Remove once external references are migrated.

### Removed

- **`/caveman` slash command (`commands/caveman.md`)** -- token-compression skill removed; text compression causes information loss in design/architecture discussions where omitted constraints lead to misunderstandings (CC-265).
- **`/caveman-commit` slash command (`commands/caveman-commit.md`)** -- removed alongside `/caveman` (CC-265).

### Test coverage

- `test-dispatch-post-verify.sh` — 38 cases (21 from CC-264 PR B; +17 from CC-059 flag/base coverage); see `scripts/test-dispatch-post-verify.sh`.
- `test-claude-executor.sh` — 5 cases (CC-264b); see `scripts/test-claude-executor.sh`.
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
