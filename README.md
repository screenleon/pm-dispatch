# pm-dispatch
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-v0.9.0-blue.svg)](https://github.com/screenleon/pm-dispatch/releases/tag/v0.9.0)

Personal Claude Code configuration for forks: subagents, slash commands, skills, and dispatch scripts with a stable installer.

This repository is designed for a single maintainer working on their own adaptation. It is source-available for reading and forking, while remaining explicitly private-maintainer scoped for this operational track.

## Documentation

**Start here**
- [Getting started](docs/GETTING_STARTED.md) — install, verify, first `/pm` run
- [Core concepts](docs/CONCEPTS.md) — the orchestration model and why it is shaped this way

**Reference**
- [Platform support](docs/platform-support.md) — per-OS install model (symlink / copy mode)
- [Executor contract](docs/executor-contract.md) — `full` / `minimal` profile + PM handoff abstraction
- [Host manifest contract](docs/host-contract.md) — `hosts/<name>/host.yaml` schema v1 (host axis, capability declarations)
- [Dispatch brief schema](docs/dispatch-brief.md) — required brief fields + `self_verify` macros
- [Model tier policy](docs/model-tier-policy.md) — sonnet-default, Opus escalation rules
- [Memory system](docs/memory-system.md) — memory persistence layer: on-disk layout and recall lifecycle
- [Context retrieval](docs/context-retrieval.md) — repo index + prior-art scan before dispatching
- [Task lifecycle](docs/pmctl-task.md) — `pmctl task` subcommands (claim/dispatch/status/review)
- [Review model](docs/review-model.md) — four-layer rigor model (pre-impl → pr-gate → machine verify)
- [pr-gate handover schema](docs/pr-gate-handover-schema.md) — deprecated `pr-gate-handover_v1` block format

## Working language

Primary working language is Mandarin Chinese. Commit messages and code identifiers are
English. Issue threads may be bilingual; non-Mandarin contributors are welcome and should
expect bilingual responses.

## Path placeholders

Examples use `${PM_DISPATCH_REPO}` to refer to your local clone root. If unset, `hosts/claude/bin/install-guards.sh` derives it automatically from the git toplevel with:

`repo_root="${PM_DISPATCH_REPO:-$(cd "$SCRIPT_DIR/../../.." && pwd -P)}"`

Cross-repository operations use `${PM_DISPATCH_REPOS_ROOT}` when set, otherwise the parent directory of `${PM_DISPATCH_REPO}`. Per-command `--repos-root` flags take precedence.

## Layout

```
agents/      → ~/.claude/agents/    subagents callable via the Agent tool
commands/    → ~/.claude/commands/  /slash commands
runtime/                            shared CLI, hooks, state, memory, context, and gate runtime
hosts/<host>/                      host-owned install, doctor, hooks, and configuration adapters
adapters/<name>/                   executor-specific dispatch and model policy
tests/                             registered test harness, suites, and fixtures
tools/                             static lint and authoring helpers
ops/                               maintainer setup, release, diagnostics, backlog, and usage tools
scripts/                           compatibility shims only; no canonical implementation
             → ~/.claude/scripts/   selected stable helper names are installed by install.sh
pm/          → ~/.claude/.pm/       cross-repo PM schema, scripts, templates
settings/                           settings fragments to merge into ~/.claude/settings.json by hand
docs/                               guides, schemas, and policy documents
```

## pm-schema (`pm/`)

Cross-repo project-management schema and tooling consumed by `project-pm` and BACKLOG.md / DECISIONS.md authoring across the user's repos. `install.sh` symlinks `~/.claude/.pm/` to this directory so canonical path references (e.g., the `rollup.sh --out` default, prose mentions in memory) keep working.

Contents:
- `schema.md` — pm-schema v1.2 definition.
- `templates/{BACKLOG,DECISIONS}.md` — bootstrap templates.
- `scripts/rollup.sh`, `scripts/validate.sh` — portable shell tooling (pure stdlib).
- `scripts/test/` — fixture-driven test suite for the scripts above.

Runtime artifacts (`.agent-trace/`, `rollup/PORTFOLIO.md`) are gitignored.

### Cutover (one-time, manual)

The canonical PM path is now `~/.claude/.pm/`, installed as a symlink to `pm-dispatch/pm/`.

1. `bash "${PM_DISPATCH_REPO}/install.sh"`
   — Expected: `link $HOME/.claude/.pm -> .../pm-dispatch/pm`. Exit code 0.
2. `readlink ~/.claude/.pm`
   — Should print the path under `pm-dispatch/pm/`. If it doesn't, stop; do not use rollup.sh / validate.sh until the symlink is confirmed.

Legacy PM directories or symlinks under the old `github` checkout location are not used by the installer. If one is present, `install.sh` leaves it untouched and emits no warning about it; inspect and remove it manually only after confirming all active references use `~/.claude/.pm`.

## Install

**Prerequisite**: `jq` must be on `$PATH`. Install: Linux/WSL2 `sudo apt install jq`, macOS `brew install jq`, Windows `winget install jqlang.jq`.

```sh
./install.sh --dry-run                # preview
./install.sh                          # apply (auto-detect profile)
./install.sh --profile minimal        # skip adapter bash guards
./install.sh --profile full           # wire all hooks (no adapter ships a bash guard today)
./install.sh --enable-host codex      # opt in to the Codex host command guard
./install.sh --enable-host opencode   # opt in to OpenCode /pm + native Bash policy
CLAUDE_CONFIG_DIR=/tmp/sandbox ./install.sh # alternate Claude config root
```

The install destination defaults to `~/.claude`; `CLAUDE_CONFIG_DIR` is the canonical override shared by the Claude runtime, installer, uninstaller, doctor, and guards. `CLAUDE_HOME` remains a backward-compatible installer alias for older sandbox scripts. If both variables are explicitly set they must be identical, otherwise install/uninstall fail before mutation.

Idempotent — re-run safely after adding files. Per-file symlinks so other tools' agents in `~/.claude/agents/` are not clobbered. If a destination already exists and is not our symlink, it is skipped with a CONFLICT warning.

> **Supported platforms (core-development phase):** Linux and WSL2 only (WSL2 is treated as Linux). **Native Windows Git Bash is not officially supported right now** — platform-hardening is deferred until the core stabilizes (CC-370); run under **WSL2** instead. See [`docs/platform-support.md`](docs/platform-support.md).

On platforms without symlink support (e.g. native Windows Git Bash, best-effort only), the installer falls back to **copy mode**: managed directories are created as directory junctions and helper scripts are copied — re-run `install.sh` after `git pull` to refresh changed copies. See [`docs/platform-support.md`](docs/platform-support.md) for the per-platform install model.

`install.sh` also makes the `pmctl` CLI discoverable. On Linux, macOS, and WSL2
it creates a symlink from `${PMCTL_BIN_DIR:-$HOME/.local/bin}/pmctl` to
`cli/pmctl` and prints an `export PATH=...` note if that bin directory is not
already on `$PATH`. On Windows Git Bash it does not copy `pmctl`; add
`<repo>/cli` to `$PATH` manually so `pmctl` runs in place and can resolve its
repo-local libraries.

**Profile**: selects whether to wire adapter bash guards (`adapters/<name>/bash-guard.sh`, manifest-driven via `needs_bash_guard`). No adapter ships a bash guard today (codex's was retired with the codex-executor agent), so `full` and `minimal` currently wire the same hook set; the flag is retained for forward compatibility with future adapters that declare one. Auto-detect runs `command -v codex` — if found, `full`; otherwise `minimal`. See [docs/executor-contract.md](docs/executor-contract.md) for the executor profile model.

**Optional hosts**: `--enable-host codex` and `--enable-host opencode` are explicit because they modify global host configuration. OpenCode wiring refuses to overwrite an existing `permission.bash` policy; integrate such a policy manually instead. Its receipt-based uninstall restores the exact prior config only while managed files remain unchanged. The legacy `--enable-codex-command-guard` flag remains an alias for `--enable-host codex`.

After installing, verify the environment is healthy:

```sh
bash runtime/bin/doctor.sh
```

`doctor.sh` checks that `claude`, `jq`, and `pmctl` are on `$PATH`, hooks are wired into `~/.claude/settings.json`, the memory directory exists, scripts are executable, and frontmatter passes lint — each failing check prints a concrete remediation command.

## Testing

```bash
bash tests/bin/run-tests.sh --base origin/main  # optional direct-impact iteration (not final sign-off)
bash tests/bin/run-tests.sh --base origin/main --list  # explain selected suites without running
bash tests/bin/run-all-tests.sh         # authoritative full suite for this checkout
bash tests/bin/run-all-tests.sh --list  # show registered suites without running
bash tests/bin/run-all-tests.sh --skip test-codex-dispatch  # skip one suite
bash tests/bin/run-tests.sh --verify-full .pm-dispatch/test-results/latest-full.json
```

Requires a complete developer checkout — any registered suite that is missing or
not executable causes the aggregator to exit non-zero. Use `--skip <name>` to
opt out of environment-specific suites (e.g., `test-codex-dispatch` if the Codex
CLI is not installed).

`run-tests.sh` is intentionally iteration-only: it selects direct regression
suites and reports unmapped paths, but does not claim transitive coverage. The
pm-dispatch maintainer workflow may inject it into PR-gate for fast feedback,
then runs and verifies the full suite outside the gate before opening this
project's PR. `release-verify.sh` performs and verifies another fresh full run
as a mandatory pm-dispatch release check. These are this repository's delivery
policies, not requirements imposed on users of the generic gate tool: other
repos may choose tests, a gate, both, or neither. See
[the test runner contract](docs/test-runner-contract.md).

`install.sh --verify` delegates to this script.

## pmctl command index

The CLI is self-documenting: run `pmctl --help`, `pmctl help <area>`, or
`pmctl help <area> <command>`. The machine-readable inventory is available as
`pmctl commands --json`. The block below is mechanically checked against the
router and [`cli/commands.tsv`](cli/commands.tsv).

<!-- pmctl-command-index:start -->
- `adapter generate` — Scaffold an adapter from the canonical adapter manifest. [experimental; JSON: false; mutating: true]
- `backlog view` — Show the active backlog. [experimental; JSON: false; mutating: false]
- `backlog lint` — Validate backlog structure and policy. [experimental; JSON: false; mutating: false]
- `backlog archive` — Archive completed backlog entries. [experimental; JSON: false; mutating: true]
- `guard check` — Evaluate a registered guard policy. [experimental; JSON: false; mutating: false]
- `dispatch run` — Launch an adapter run from a validated brief. [experimental; JSON: false; mutating: true]
- `dispatch wait` — Wait for a detached dispatch run to finish. [experimental; JSON: false; mutating: true]
- `artifacts list` — List managed artifacts. [experimental; JSON: false; mutating: false]
- `artifacts show` — Show one managed artifact. [experimental; JSON: false; mutating: false]
- `artifacts gc` — Remove expired managed artifacts. [experimental; JSON: false; mutating: true]
- `artifacts migrate` — Migrate legacy artifacts into managed storage. [experimental; JSON: false; mutating: true]
- `worktree create` — Create a managed ticket worktree. [experimental; JSON: false; mutating: true]
- `worktree list` — List managed worktrees. [experimental; JSON: true; mutating: false]
- `worktree remove` — Remove a managed worktree. [experimental; JSON: false; mutating: true]
- `worktree gc` — Remove stale managed worktree records. [experimental; JSON: false; mutating: true]
- `ship` — Run the ticket delivery workflow. [experimental; JSON: false; mutating: true]
- `ship prepare` — Prepare a ticket delivery run. [experimental; JSON: false; mutating: true]
- `ship finish` — Finish a prepared ticket delivery run. [experimental; JSON: false; mutating: true]
- `ship --parallel` — Run multiple ticket delivery workflows. [experimental; JSON: false; mutating: true]
- `ship status` — Show and refresh a parallel ship run. [experimental; JSON: true; mutating: true]
- `ship list` — List and refresh completed parallel ship runs. [experimental; JSON: true; mutating: true]
- `trace tail` — Read normalized project events. [experimental; JSON: true; mutating: false]
- `task list` — List tasks. [experimental; JSON: true; mutating: false]
- `task show` — Show one task. [experimental; JSON: true; mutating: false]
- `task create` — Create a task. [experimental; JSON: false; mutating: true]
- `task update` — Update task metadata or state. [experimental; JSON: false; mutating: true]
- `task claim` — Claim an available task. [experimental; JSON: false; mutating: true]
- `task dispatch` — Record task dispatch metadata. [experimental; JSON: false; mutating: true]
- `task status` — Show task lifecycle status. [experimental; JSON: true; mutating: false]
- `task review` — Record a task review result. [experimental; JSON: false; mutating: true]
- `safe bash` — Run a shell command through guard policy. [experimental; JSON: false; mutating: true]
- `validate brief` — Validate a dispatch brief. [experimental; JSON: false; mutating: false]
- `decision add` — Append a structured decision. [experimental; JSON: true; mutating: true]
- `gate run` — Start the pull-request gate. [experimental; JSON: false; mutating: true]
- `gate verify` — Verify a gate result artifact. [experimental; JSON: false; mutating: false]
- `gate wait` — Wait for a detached gate run. [experimental; JSON: false; mutating: true]
- `context index` — Build the repository context index. [experimental; JSON: false; mutating: true]
- `context update` — Update the repository context index. [experimental; JSON: false; mutating: true]
- `context status` — Show context index status. [experimental; JSON: true; mutating: false]
- `context query` — Query indexed project context. [experimental; JSON: false; mutating: true]
- `context pack` — Build a bounded JSON context pack. [experimental; JSON: true; mutating: true]
- `context reuse-scan` — Scan indexed context for prior art. [experimental; JSON: false; mutating: true]
- `context prompt-scan` — Scan a prompt for context references. [experimental; JSON: false; mutating: true]
- `memory dir` — Print the canonical project memory directory. [experimental; JSON: false; mutating: false]
- `memory resolve` — Resolve canonical project memory configuration. [experimental; JSON: true; mutating: false]
- `memory config` — Read or update memory configuration. [experimental; JSON: true; mutating: true]
- `memory append-episode` — Append a canonical memory episode. [experimental; JSON: true; mutating: true]
- `memory doctor` — Diagnose canonical memory configuration; exits 0 healthy, 1 issues found, 2 usage error. [experimental; JSON: true; mutating: false]
- `memory shard` — Build memory retrieval shards. [experimental; JSON: false; mutating: true]
- `memory rebuild-summary` — Rebuild the memory summary index. [experimental; JSON: false; mutating: true]
- `pre-release audit` — Audit a milestone before release. [experimental; JSON: false; mutating: false]
- `pm prepare` — Prepare a bounded PM execution plan. [experimental; JSON: true; mutating: true]
- `pm run` — Run a prepared PM batch. [experimental; JSON: true; mutating: true]
- `commands` — List the canonical command registry. [experimental; JSON: true; mutating: false]
<!-- pmctl-command-index:end -->

## What's here

### Agents

**Orchestration**
- **project-pm** — PM across repos under the configured repositories root. Triages requests, decomposes work, writes briefs (main thread dispatches), synthesizes PR-gate reviews, and maintains canonical per-project memory.

Executors (codex, claude, opencode) are **not** subagents — the main thread dispatches each as an independent CLI subprocess via `pmctl dispatch run --adapter <name>`, then verifies via `git diff` and `dispatch-post-verify.sh`.

**Reviewers (advisors — PM may override with reasoning)**
- **critic** — Adversarial review of plan / diff. Scope creep, incompleteness, convention drift.
- **architecture-reviewer** — Layer / coupling / abstraction fit. Does the change respect the existing design.

**Reviewers (HARD GATES — only the user can override a `block`)**
- **security-reviewer** — OWASP-style security review for any implementation change. Auth, injection, secrets, deps, deserialization, etc.
- **risk-reviewer** — Blast radius, reversibility, migration safety, fail mode, observability. Distinct from security.
- **qa-tester** — Owns the testing phase. Loads `${QA_RULES_DIR}/${QA_RULES_ENTRY:-AGENT.md}` as Tier 1 source of truth for test categories, layer choice, and anti-patterns. Red-line violations are blocking. Any QA rules directory with a Tier 1 entry point works; set `QA_RULES_DIR` and optionally `QA_RULES_ENTRY` to use your own.

> **Project ID** in memory paths is derived from the sanitized absolute path of your working directory. Run `ls ~/.claude/projects/` to find the directory name on your machine.

### Commands

- **/pm `<request>`** — Routes a free-form request to the `project-pm` agent.
- **/pr-gate `[context]`** — Explicitly runs the full review pipeline before opening a PR.

### Model tier policy

All reviewer agent spawns use `model: "sonnet"` by default. Opus is only used
when all three escalation conditions hold (full tier + diff > 1000 lines +
sensitive path). See [`docs/model-tier-policy.md`](docs/model-tier-policy.md)
for the full decision rules, implementation-task guidance, and token tracking
usage.

### External dependencies

- **QA rules directory** (`$QA_RULES_DIR`, default `<repos-root>/qa-testing-rules/`). Any directory with an `AGENT.md` Tier 1 entry point works — the [`qa-testing-rules`](https://github.com/screenleon/qa-testing-rules) repo is the reference implementation, but you can substitute your own. Set `QA_RULES_ENTRY` to override the entry point filename if your rules repo uses a different convention.

### Operational entrypoints

- **cli/pmctl** — Runtime CLI spine. `install.sh` symlinks it into `${PMCTL_BIN_DIR:-$HOME/.local/bin}` on Linux/macOS/WSL; Windows users should add `<repo>/cli` to `$PATH` manually because a copied `pmctl` cannot resolve repo-local libraries. Key sub-commands: `pmctl pm prepare` / `pmctl pm run` (batch-only PM coordinator for non-Claude hosts); `pmctl dispatch run --adapter <codex|claude> --brief-file <path>` (preferred dispatch path); `pmctl task create/show/list/update/claim/dispatch/status/review` (task CRUD + lifecycle; see [`docs/pmctl-task.md`](docs/pmctl-task.md)); `pmctl decision add`; `pmctl trace tail` (reads `events.jsonl` + archives with `--kind/--task/--since/--until/--json` filters); `pmctl context index/update/query/pack/reuse-scan` (repo index + prior-art scan; see [`docs/context-retrieval.md`](docs/context-retrieval.md)); `pmctl validate brief`; `pmctl gate run`; `pmctl guard check --role <pm|executor|reviewer> --runtime <codex|claude>`; `pmctl safe bash`; `pmctl adapter generate <name>` (scaffolds `adapters/<name>/adapter.yaml` and support files). `adapter.yaml` is the source of truth and must stay out of `generated_files`; regenerate only the files listed there.
- **runtime/bin/pm-prep-snapshot.sh** — Captures branch/PR/backlog/tooling state before PM-agent spawn and writes a typed snapshot for PM consumption.
- **ops/diagnostics/codex-watch.sh** — Tails `.agent-trace/latest.jsonl` and prints a one-line human summary per event (`[turn.started]`, `[cmd] exit=0 …`, `[msg] …`, `[turn.completed] tokens: …`). Run from another terminal during a long dispatch to see real-time progress.
- **runtime/hooks/guard-pm-write.sh** — `PreToolUse` hook (matcher `Edit|Write`). Blocks `project-pm` from editing/writing outside `~/.claude/projects/<claude-project-id>/memory/`. Asserts absolute paths and normalizes `..`. No-op for any other agent or the main thread. Bypass (logged): `PM_GUARD_PM_WRITE=off`. Requires `jq` and `realpath`.
- **runtime/hooks/guard-executor-write.sh** — the unified executor write-guard, surfaced via `pmctl guard check --role executor` (cli-only — no live `PreToolUse` hook, since the brief is authored by trusted main-thread code). It derives the runtime from `agent_type` and enforces that runtime's `write_guard_mode`. Bypass (logged): `PM_GUARD_<RUNTIME>_WRITE=off`. Requires `jq` and `realpath`.
- **hosts/claude/hooks/save-rate-limits.sh** — `StatusLine` hook that saves Claude rate-limit payloads to `~/.claude/rate-limits.json` for `token-usage.sh --remaining`. If a previous `statusLine.command` existed during install, it is saved to `~/.claude/statusline-chain.conf` and invoked after the rate-limit file is updated.
- **hosts/claude/bin/install-guards.sh / uninstall-guards.sh** — Idempotent `jq`-based splice into `~/.claude/settings.json`. `--dry-run` shows the diff without applying. Each apply backs up `settings.json` to `settings.json.bak.<timestamp>`.
- **tests/shell/test-guards.sh** — Regression suite for the managed hook scripts (~200+ cases: happy paths, boundary, per-metachar isolated coverage, quote / `..` / glob / read-root / git -C / `--flag=path` bypass attempts, destructive git, stash subverbs, audit-log content assertions, env-var bypass, type-confusion, and StatusLine rate-limit capture). Exit 0 on all pass. `VERBOSE=1` prints every case. Run by `install.sh` and isolates audit logs via `PM_GUARD_LOG_DIR`.
- **tools/lint/lint-scripts.sh** — Local entrypoint hygiene check that also invokes the shared ShellCheck contract. CI uses `--hygiene-only` because its separate `shellcheck` job owns the canonical scan. Run by `install.sh`.
- **tools/lint/lint-shellcheck.sh** — CI/local ShellCheck entrypoint. It discovers `.sh` files from `shellcheck-domains.tsv` across `runtime/`, `tests/`, `tools/`, `ops/`, `hosts/`, and bounded `scripts/` compatibility shims; code-scoped canonical-path exceptions require a reason in `shellcheck-ignores.tsv`. It defaults to two CPU-bound workers; set `PM_DISPATCH_SHELLCHECK_JOBS` to an explicit value from 1 through 8 to tune concurrency.
- **tools/lint/lint-frontmatter.sh** — Validates YAML frontmatter in `agents/`, `commands/`, and `skills/` against PyYAML flow-collection semantics (dq-escape whitelist, adjacent-quote, tab-indent, and empty-entry detection across all four collection paths). Run by CI and `doctor.sh`.
- **tests/bin/run-tests.sh** — pm-dispatch-specific, direct-impact iteration planner. It can be supplied explicitly to generic `pr-gate --test-cmd`; it is not final sign-off evidence.
- **tests/bin/run-all-tests.sh** — Authoritative full-suite entrypoint. `install.sh --verify` uses it; `--list` and `--skip <name>` remain available in full mode.
- **runtime/bin/doctor.sh** — Environment health check: verifies `claude`/`jq`/`pmctl` are on `$PATH`, hooks are wired into `~/.claude/settings.json`, the memory directory exists, scripts are executable, and frontmatter passes lint. `--profile minimal|full|auto` scopes which hook checks apply. Each failing check prints a concrete remediation command.
- **token-usage.sh** — Multi-pool token usage estimator (Claude / Codex / Spark). Reads `~/.claude/usage-tracker.jsonl`. Symlinked to `~/.claude/scripts/token-usage.sh` by `install.sh`. Usage: `bash ~/.claude/scripts/token-usage.sh [--today|--all]`. `--remaining` (no arg) auto-reads `~/.claude/rate-limits.json` if the StatusLine hook is installed; `--remaining N` accepts manual dashboard value.
- **log-usage.sh** — Appends one entry to `~/.claude/usage-tracker.jsonl`. Symlinked to `~/.claude/scripts/log-usage.sh` by `install.sh`. Usage: `bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note]`. Call after any significant agent operation; standard types in the script header.
- **usage-weekly.sh** — Weekly Markdown report from `~/.claude/stats-cache.json` (Claude internal cache) and Codex session JSONL files. Read-only. Run manually or from a cron job.

**Dependencies (runtime):** `jq` and `realpath` (coreutils) must be on `$PATH`. Hooks fail closed (`exit 2`) if either is missing — they log to stderr and Claude Code surfaces the message.

**Audit log:** every hook firing that targets the matched subagent appends one line to `$PM_GUARD_LOG_DIR/hooks.log` (default `~/.claude/logs/hooks.log`). No-ops for other agents are not logged. Format: `<ISO8601> <hook-name> agent=<type> tool=<name> decision=<allow|deny|bypass> reason=<...> target=<path-or-cmd>`. `reason` and `target` are `printf %q`-escaped so the log is safely re-parseable. The `PM_GUARD_LOG_DIR` env var lets the test suite redirect to a sandbox dir without polluting the live log.

**Rollback:** to disable hooks system-wide, run `hosts/claude/bin/uninstall-guards.sh` (creates a backup, splices out PreToolUse entries pointing at this repo). To restore a specific prior settings file, copy from `~/.claude/settings.json.bak.<timestamp>`. The hook scripts in this repo are inert without the settings.json wiring.

## Design notes

- **Subagents cannot spawn subagents.** Claude Code intentionally restricts nested `Agent` tool calls regardless of frontmatter declaration ([Agent SDK docs](https://code.claude.com/docs/en/agent-sdk/subagents.md)). The **main thread** orchestrates: it spawns subagents (PM, reviewers) and relays outputs between them, and dispatches executors as CLI subprocesses. PM produces briefs and synthesizes verdicts; it does not dispatch. Reviewers run in parallel from the main thread, not from PM. Never include `Agent` in any subagent's `tools:` frontmatter — `tools/lint/lint-agents.sh` enforces this.
- **Hooks enforce hard rules; prose alone leaks.** CLAUDE.md compliance for "never do X" rules sits around 70% in the public research, so structural enforcement matters for invariants. The live `PreToolUse` hook in `~/.claude/settings.json` is `guard-pm-write.sh` (project-pm can only Edit/Write inside the memory dir). Executor write policy is enforced by the unified `guard-executor-write.sh` via `pmctl guard check` (cli-only — the brief is authored by trusted main-thread code, so no live write hook is needed). All guards no-op for the main thread and other subagents.
  - **Threat model**: defends against accidental misuse and prompt-injected misuse by the targeted subagent. Specifically *not* a defense against the user's main thread, which has full tool access by design.
  - **Failure mode**: fail-closed on missing `jq`/`realpath`, malformed input JSON, or empty/non-absolute paths. Fail-open (no-op) only when the firing agent is not the targeted subagent, or when the bypass env var is the literal string `off` (anything else, including empty string and case variants, does not bypass — bypasses are logged).
  - **Bypass**: `PM_GUARD_PM_WRITE=off` / `PM_GUARD_<RUNTIME>_WRITE=off` (e.g. `PM_GUARD_CODEX_WRITE=off`). Each bypass appends a line to `~/.claude/logs/hooks.log`.
  - **Tests**: `tests/shell/test-guards.sh` exercises ~150+ cases including per-metacharacter isolation, quoted-path / `..`-traversal / `git -C` / `--flag=PATH` / bundled-short-flag (`-rf/path`, `-n5/path`) bypass attempts, destructive-git forms, and audit-log content assertions. Run by `install.sh` with audit logs sandboxed via `PM_GUARD_LOG_DIR`.
  - **Known overrestriction**: short-flag-attached values containing `/` after letter/digit chars are treated as paths and validated against read roots — so `grep -ipath/to/regex` is denied even when `path/to/regex` is intended as a regex pattern, not a file. Workaround: pass the pattern as a separate token (`grep -i path/to/regex file`) or use `-e` / positional form. Same for paths with embedded `/` that legitimately need to escape the read root: use the bypass env var.
- **PM thinks, Codex implements.** `project-pm` writes the brief; the codex executor (a CLI subprocess) implements it, it does not design. Architecture, scope, and acceptance criteria stay with the PM.
- **Definitions in repo, state on disk.** Agent and command definitions are version-controlled here. Per-project state (memory, traces) lives in `~/.claude/` and stays out of this repo.
- **Decoupled from agent-playbook-template.** The playbook is a methodology framework; this repo is a personal config. They evolve independently.

## License

MIT. See [`LICENSE`](LICENSE).

## Adding new pieces

- New agent: drop a `name.md` (with frontmatter) into `agents/`, re-run `install.sh`. **Don't include `Agent` in `tools:`** — `tools/lint/lint-agents.sh` will reject the install.
- New command: drop a `name.md` into `commands/`, re-run `install.sh`.
- New shared guard: add it under `runtime/hooks/`; a host-specific guard belongs under `hosts/<host>/hooks/`. Add the corresponding manifest/installer binding and re-run `install.sh`; don't hand-edit host settings if it can be avoided. Add test cases under `tests/shell/` — security-relevant scripts ship with regression coverage.
- Settings allowlist additions: edit `~/.claude/settings.json` directly; don't try to symlink settings.

## Dispatch briefs

Schema and reusable self-verify macros: [`docs/dispatch-brief.md`](docs/dispatch-brief.md). All briefs dispatched to executor adapters must include `working_dir`, `goal`, `files`, and `acceptance`; executors reject briefs missing those fields.

- `self_verify` — **required for file-writing briefs** (any brief whose `files:` block contains an entry tagged `write:` or `new:`, or any entry without an explicit `read:` tag; when in doubt, treat as file-writing). Optional only for read-only briefs where *every* `files:` entry is explicitly tagged `read:`. See [`docs/dispatch-brief.md`](docs/dispatch-brief.md) for the canonical definition.

### Watching a long dispatch

Codex briefs that touch many files can run 10–30 minutes. The background dispatch keeps running while you watch its trace. Two patterns:

1. **External tail (any session, no Claude Code involvement).** From another terminal:
   ```sh
   "${PM_DISPATCH_REPO}/ops/diagnostics/codex-watch.sh" --cd /path/to/project
   ```
   Prints one line per codex event as it streams. Works whether the dispatcher was launched from Claude Code, the CLI, or a CI job.

2. **Background dispatch from main thread.** The canonical route already runs `pmctl dispatch run` as a background Bash command (`run_in_background: true`), so the main thread stays responsive. `Monitor` (or periodically `Bash` with `tail -n 5 .agent-trace/latest.jsonl`) the trace file for progress, then check `git diff` and the post-verify verdict when the completion notification arrives.

If a dispatch exits 124, codex hit the timeout — almost always a silent startup hang. The wrapper banner + closing line in `.agent-trace/latest.stderr` is the post-mortem: re-dispatching usually clears the hang. Extend `--timeout` (or `$CODEX_DISPATCH_TIMEOUT`) only when codex is genuinely doing more work than the default 20 minutes.

---

## Disclaimer

Claude Code is a product of [Anthropic](https://www.anthropic.com/). This project is an independent personal configuration for Claude Code and is **not affiliated with, sponsored by, or endorsed by Anthropic**. "Claude" and "Claude Code" are trademarks of Anthropic; references in this repository are descriptive use only.

Similarly, [Codex CLI](https://github.com/openai/codex) is a product of OpenAI; this project integrates with it but is not affiliated with OpenAI.
