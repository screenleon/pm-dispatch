# claude-config

Personal Claude Code configuration: subagents, slash commands, skills, and dispatch scripts. Source of truth lives in this repo; entries are symlinked into `~/.claude/` by `install.sh`.

## Layout

```
agents/      → ~/.claude/agents/    subagents callable via the Agent tool
skills/      → ~/.claude/skills/    invocable skills
commands/    → ~/.claude/commands/  /slash commands
scripts/                            hook wrappers (called by absolute path) + usage tracking scripts
             → ~/.claude/scripts/   claude-usage.sh and log-usage.sh are symlinked here by install.sh
pm/          → ~/github/.pm/        cross-repo PM schema, scripts, templates
settings/                           settings fragments to merge into ~/.claude/settings.json by hand
docs/                               policy documents (model-tier-policy.md, codex-brief.md)
```

## pm-schema (`pm/`)

Cross-repo project-management schema and tooling consumed by `project-pm` and BACKLOG.md / DECISIONS.md authoring across the user's repos. `install.sh` symlinks `~/github/.pm/` to this directory so existing path references (e.g., the `rollup.sh --out` default, prose mentions in memory) keep working.

Contents:
- `schema.md` — pm-schema v1 definition.
- `templates/{BACKLOG,DECISIONS}.md` — bootstrap templates.
- `scripts/rollup.sh`, `scripts/validate.sh` — portable shell tooling (pure stdlib).
- `scripts/test/` — fixture-driven test suite for the scripts above.

Runtime artifacts (`.agent-trace/`, `rollup/PORTFOLIO.md`) are gitignored.

## Install

```sh
./install.sh --dry-run   # preview
./install.sh             # apply
```

Idempotent — re-run safely after adding files. Per-file symlinks so other tools' agents in `~/.claude/agents/` are not clobbered. If a destination already exists and is not our symlink, it is skipped with a CONFLICT warning.

## What's here

### Agents

**Orchestration**
- **project-pm** — PM across `~/github/` repos. Triages requests, decomposes work, writes briefs (main thread dispatches), synthesizes PR-gate reviews, maintains per-project memory at `~/.claude/projects/-home-screenleon-github/memory/project_<repo>.md`.
- **codex-executor** — Thin wrapper subagent, dispatched by the main thread. Accepts a complete brief, calls Codex via `scripts/codex-dispatch.sh`, verifies via `git diff`, reports back.

**Reviewers (advisors — PM may override with reasoning)**
- **critic** — Adversarial review of plan / diff. Scope creep, incompleteness, convention drift.
- **architecture-reviewer** — Layer / coupling / abstraction fit. Does the change respect the existing design.

**Reviewers (HARD GATES — only the user can override a `block`)**
- **security-reviewer** — OWASP-style security review for any implementation change. Auth, injection, secrets, deps, deserialization, etc.
- **risk-reviewer** — Blast radius, reversibility, migration safety, fail mode, observability. Distinct from security.
- **qa-tester** — Owns the testing phase. Loads `~/github/qa-testing-rules/AGENT.md` as Tier 1 source of truth for test categories, layer choice, and anti-patterns. Red-line violations are blocking.

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

- [`screenleon/qa-testing-rules`](https://github.com/screenleon/qa-testing-rules) cloned at `~/github/qa-testing-rules/`. Used by `qa-tester`. If missing, qa-tester will stop and ask you to clone it.

### Scripts

- **codex-dispatch.sh** — Invokes `codex exec` with tracing, sandbox/approval flags, timeout (default 1200s, override via `--timeout` or `$CODEX_DISPATCH_TIMEOUT`), `--brief-file <path>` for long briefs, and final-message capture. Writes `.agent-trace/codex-<ts>.{jsonl,last,stderr}` and refreshes `.agent-trace/latest.{jsonl,last,stderr}` symlinks so observers can attach without knowing the timestamp. Exit 124 = hit the timeout (silent codex hang most likely cause).
- **codex-watch.sh** — Tails `.agent-trace/latest.jsonl` and prints a one-line human summary per event (`[turn.started]`, `[cmd] exit=0 …`, `[msg] …`, `[turn.completed] tokens: …`). Run from another terminal during a long dispatch to see real-time progress.
- **hook-pm-write-guard.sh** — `PreToolUse` hook (matcher `Edit|Write`). Blocks `project-pm` from editing/writing outside `~/.claude/projects/-home-screenleon-github/memory/`. Asserts absolute paths and normalizes `..`. No-op for any other agent or the main thread. Bypass (logged): `CLAUDE_HOOK_PM_GUARD=off`. Requires `jq` and `realpath`.
- **hook-codex-bash-guard.sh** — `PreToolUse` hook (matcher `Bash`). Defends against accidental and prompt-injected misuse of `codex-executor`. Layers, in order:
  1. Reject any command containing shell composition / substitution / redirection metacharacters: `; & | $ \` ( ) < > { } \` or `CR` / `LF`. Also reject `"` and `'` (the tokenizer doesn't honor quoting; rejecting them prevents `cat "/etc/passwd"` from skipping path validation). Closes `git status; rm -rf /`, `git $(curl evil)`, `git status >/etc/cron.d/x`, `cat <(...)`, etc.
  2. Allow only one of: the canonical `codex-dispatch.sh` path; one of the read-only verbs `cat ls head tail wc grep pwd realpath dirname basename jq test sleep date echo true false`; or `git`.
  3. For `git`, only `status log diff show rev-parse ls-files describe` (always read-only), plus `branch` and `stash` (gated separately) are accepted as subcommands. `branch` rejects destructive flags (`-d/-D/--delete/-m/-M/--move/-c/-C/--copy/-f/--force/...`). `stash` only allows the explicit subverbs `list` and `show` — bare `git stash` (mutating push) and `drop/pop/clear/push/apply/...` are denied. Any git invocation with `--output*`, `--out-file*`, or `--output-directory*` is denied. Only the forms `git <subcmd>` and `git -C <dir> <subcmd>` are accepted; `git -c key=val` and `git --git-dir=...` are denied. The `<dir>` of `git -C` is itself path-validated against read roots.
  4. Every positional (non-flag) arg goes through path-validation: paths starting with `/` must resolve under one of `$CLAUDE_HOOK_CODEX_READ_ROOTS` (default `$HOME/github:/tmp`); paths starting with `~` are denied outright; any arg containing `..` as a path segment is denied (closes `cat ../etc/passwd`); glob chars (`* ? [ ]`) anywhere are denied. The VALUE part of `--flag=VALUE` forms gets the same validation (closes `grep --file=/etc/shadow x`), and dispatch `--brief-file VALUE` / `--brief-file=VALUE` values are explicitly validated the same way.
  
  Bypass (logged): `CLAUDE_HOOK_CODEX_GUARD=off` (literal "off" only). Requires `jq` and `realpath`.
- **install-hooks.sh / uninstall-hooks.sh** — Idempotent `jq`-based splice into `~/.claude/settings.json`. `--dry-run` shows the diff without applying. Each apply backs up `settings.json` to `settings.json.bak.<timestamp>`.
- **test-hooks.sh** — Regression suite for both hook scripts (~150+ cases: happy paths, boundary, per-metachar isolated coverage, quote / `..` / glob / read-root / git -C / `--flag=path` bypass attempts, destructive git, stash subverbs, audit-log content assertions, env-var bypass, type-confusion). Exit 0 on all pass. `VERBOSE=1` prints every case. Run by `install.sh` and isolates audit logs via `CLAUDE_HOOK_LOG_DIR`.
- **lint-scripts.sh** — Hygiene check for `scripts/*.sh`: executable bit, shebang, `bash -n` parses, has a `set -...` line. Run by `install.sh`.
- **claude-usage.sh** — Rolling 5-hour and today-UTC token usage estimator. Reads `~/.claude/usage-tracker.jsonl`. Symlinked to `~/.claude/scripts/claude-usage.sh` by `install.sh`. Usage: `bash ~/.claude/scripts/claude-usage.sh [--today|--all]`. Once `~/.claude/usage-calibration.json` is calibrated with a known rate-limit token count, shows % used and estimated minutes remaining.
- **log-usage.sh** — Appends one entry to `~/.claude/usage-tracker.jsonl`. Symlinked to `~/.claude/scripts/log-usage.sh` by `install.sh`. Usage: `bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note]`. Call after any significant agent operation; standard types in the script header.
- **usage-weekly.sh** — Weekly Markdown report from `~/.claude/stats-cache.json` (Claude internal cache) and Codex session JSONL files. Read-only. Run manually or from a cron job.

**Dependencies (runtime):** `jq` and `realpath` (coreutils) must be on `$PATH`. Hooks fail closed (`exit 2`) if either is missing — they log to stderr and Claude Code surfaces the message.

**Audit log:** every hook firing that targets the matched subagent appends one line to `$CLAUDE_HOOK_LOG_DIR/hooks.log` (default `~/.claude/logs/hooks.log`). No-ops for other agents are not logged. Format: `<ISO8601> <hook-name> agent=<type> tool=<name> decision=<allow|deny|bypass> reason=<...> target=<path-or-cmd>`. `reason` and `target` are `printf %q`-escaped so the log is safely re-parseable. The `CLAUDE_HOOK_LOG_DIR` env var lets the test suite redirect to a sandbox dir without polluting the live log.

**Rollback:** to disable hooks system-wide, run `scripts/uninstall-hooks.sh` (creates a backup, splices out PreToolUse entries pointing at this repo). To restore a specific prior settings file, copy from `~/.claude/settings.json.bak.<timestamp>`. The hook scripts in this repo are inert without the settings.json wiring.

## Design notes

- **Subagents cannot spawn subagents.** Claude Code intentionally restricts nested `Agent` tool calls regardless of frontmatter declaration ([Agent SDK docs](https://code.claude.com/docs/en/agent-sdk/subagents.md)). The **main thread** orchestrates: it spawns subagents (PM, reviewers, codex-executor) and relays outputs between them. PM produces briefs and synthesizes verdicts; it does not dispatch. Reviewers run in parallel from the main thread, not from PM. Never include `Agent` in any subagent's `tools:` frontmatter — `scripts/lint-agents.sh` enforces this.
- **Hooks enforce hard rules; prose alone leaks.** CLAUDE.md compliance for "never do X" rules sits around 70% in the public research, so structural enforcement matters for invariants. Two `PreToolUse` hooks live in `~/.claude/settings.json`: `hook-pm-write-guard.sh` (project-pm can only Edit/Write inside the memory dir) and `hook-codex-bash-guard.sh` (codex-executor's Bash is restricted to the dispatch script + a read-only verb allowlist, with metacharacter rejection up front). Both no-op for the main thread and other subagents.
  - **Threat model**: defends against accidental misuse and prompt-injected misuse by the targeted subagent. Specifically *not* a defense against the user's main thread, which has full tool access by design.
  - **Failure mode**: fail-closed on missing `jq`/`realpath`, malformed input JSON, or empty/non-absolute paths. Fail-open (no-op) only when the firing agent is not the targeted subagent, or when the bypass env var is the literal string `off` (anything else, including empty string and case variants, does not bypass — bypasses are logged).
  - **Bypass**: `CLAUDE_HOOK_PM_GUARD=off` / `CLAUDE_HOOK_CODEX_GUARD=off`. Each bypass appends a line to `~/.claude/logs/hooks.log`.
  - **Tests**: `scripts/test-hooks.sh` exercises ~150+ cases including per-metacharacter isolation, quoted-path / `..`-traversal / `git -C` / `--flag=PATH` / bundled-short-flag (`-rf/path`, `-n5/path`) bypass attempts, destructive-git forms, and audit-log content assertions. Run by `install.sh` with audit logs sandboxed via `CLAUDE_HOOK_LOG_DIR`.
  - **Known overrestriction**: short-flag-attached values containing `/` after letter/digit chars are treated as paths and validated against read roots — so `grep -ipath/to/regex` is denied even when `path/to/regex` is intended as a regex pattern, not a file. Workaround: pass the pattern as a separate token (`grep -i path/to/regex file`) or use `-e` / positional form. Same for paths with embedded `/` that legitimately need to escape the read root: use the bypass env var.
- **PM thinks, Codex implements.** `project-pm` writes the brief; `codex-executor` is a dispatcher, not a designer. Architecture, scope, and acceptance criteria stay with the PM.
- **Definitions in repo, state on disk.** Agent and command definitions are version-controlled here. Per-project state (memory, traces) lives in `~/.claude/` and stays out of this repo.
- **Decoupled from agent-playbook-template.** The playbook is a methodology framework; this repo is a personal config. They evolve independently.

## Adding new pieces

- New agent: drop a `name.md` (with frontmatter) into `agents/`, re-run `install.sh`. **Don't include `Agent` in `tools:`** — `scripts/lint-agents.sh` will reject the install.
- New command: drop a `name.md` into `commands/`, re-run `install.sh`.
- New hook: drop a `scripts/hook-<name>.sh` and add a corresponding `PreToolUse` entry by re-running `scripts/install-hooks.sh` (extend the splice if it's a new pair); don't hand-edit `settings.json` if it can be avoided. Add test cases to `scripts/test-hooks.sh` — security-relevant scripts ship with regression coverage.
- Settings allowlist additions: edit `~/.claude/settings.json` directly (or use the `update-config` skill); don't try to symlink settings.

## Codex briefs

Schema and reusable self-verify macros: [`docs/codex-brief.md`](docs/codex-brief.md). All briefs dispatched to `codex-executor` must include `working_dir`, `goal`, `files`, and `acceptance`; the executor rejects briefs missing those fields.

### Watching a long dispatch

Codex briefs that touch many files can run 10–30 minutes. The `codex-executor` subagent blocks until codex returns, so the parent agent has no incremental view. Two recovery patterns:

1. **External tail (any session, no Claude Code involvement).** From another terminal:
   ```sh
   ~/github/claude-config/scripts/codex-watch.sh --cd /path/to/project
   ```
   Prints one line per codex event as it streams. Works whether the dispatcher was launched from Claude Code, the CLI, or a CI job.

2. **Background dispatch from main thread.** When you need progress visible *inside* a Claude Code session, skip `codex-executor` and run the wrapper as a background Bash command, then `Monitor` (or periodically `Bash` with `tail -n 5 .agent-trace/latest.jsonl`) the trace file. Invoke `codex-executor` only at the end for `git diff` verification. Trade-off: you lose the executor's pre-dispatch brief validation, so write the brief carefully.

If a dispatch exits 124, codex hit the timeout — almost always a silent startup hang. The wrapper banner + closing line in `.agent-trace/latest.stderr` is the post-mortem: re-dispatching usually clears the hang. Extend `--timeout` (or `$CODEX_DISPATCH_TIMEOUT`) only when codex is genuinely doing more work than the default 20 minutes.
