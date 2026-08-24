# Release verification checklist

Run this **before tagging any release**. It is the single fixed procedure: work
top to bottom, and only tag when every box is checked on **Linux and/or WSL2**
(WSL2 is treated as Linux). Native Windows Git Bash and macOS are **out of scope
for release sign-off** during the core-development phase — see
`docs/platform-support.md` and `DECISIONS.md` (2026-06-13 defer-native-windows-support-during-core-dev).
Platform sign-off returns as a dedicated phase once the core stabilizes.

The goal is that **every feature is actually exercised**, not just unit-tested.
Coverage splits into three layers:

| Layer | What runs it | Covers |
|-------|--------------|--------|
| **Offline automated** | `ops/release/release-verify.sh` (Phases 1–3) | prerequisites, every suite in the canonical test registry, real `pmctl context` smoke + real `sqlite3` |
| **Live E2E automated** | `ops/release/release-verify.sh --e2e` (Phase 4) | real dispatch output contract (Phase B); pr-gate structural validation via codex (Phase C — requires codex on PATH) — spends LLM tokens |
| **Manual** | §2a / §2d below | real install + hooks, `doctor`, Claude Code hook execution — environment-mutating, not automatable |

A release is **full GO** only when `release-verify.sh --e2e` exits 0 (`AUTOMATED VERDICT: GO`) and every §2a / §2d box is ticked. Exit 3 (`PARTIAL GO`) means required phases were skipped and is **not** sufficient for tagging.

Affected-suite feedback and an optional development/PR gate happen before this
release procedure and are not fixed release phases. Do not run them as release
prerequisites or treat their artifacts as substitutes for the fresh full suite
already owned by `release-verify.sh --e2e`.

---

## 0. Pre-flight

- [ ] Working tree clean on the release branch (`git status` empty).
- [ ] `git pull` — branch up to date with `origin`.
- [ ] `README.md` version badge bumped to the target tag (badge label **and**
      the release-tag link, e.g. `version-v0.6.0` → `releases/tag/v0.6.0`). This
      is the repo's sole version marker — no `VERSION` file / installer constant.
- [ ] `CHANGELOG.md`: `## [Unreleased]` section reviewed and renamed to
      `## [x.y.z] — YYYY-MM-DD`; every shipped change is listed.
- [ ] No `TODO(release)` / `XXX` left in changed files: `git grep -nE 'TODO\(release\)|XXX'`.

---

## 1. Automated verification (`release-verify.sh`)

For the one-time v0.9.0 acceptance, CC-501 additionally requires the isolated
v0.8.0 upgrade smoke. Create independent worktrees for tag `v0.8.0` and the
candidate commit, then run:

```bash
bash ops/release/upgrade-smoke-v0.8-v0.9.sh \
  --baseline-dir /path/to/v0.8.0-worktree \
  --candidate-dir /path/to/v0.9-candidate-worktree
```

- [ ] CC-501 prints `CC-501 upgrade smoke: GO`; retain its
      `.gate-results/cc501-*` artifact with the release evidence. A dirty or
      later superseded candidate checkout must be rerun at the final candidate SHA.

Run on **Linux or WSL2** (the supported sign-off platforms). Native Windows Git
Bash is out of scope during core development — `release-verify.sh` refuses to run
there with a "use WSL2" notice.

```bash
# Linux / WSL2 — Phases 1-3 (offline, no tokens)
bash ops/release/release-verify.sh

# Same platform — Phase 4: real dispatch + pr-gate (spends LLM tokens)
bash ops/release/release-verify.sh --e2e
# or with explicit adapter:
bash ops/release/release-verify.sh --e2e --adapter claude
```

- [ ] **Linux / WSL2 (full sign-off)**: `release-verify.sh --e2e` exits 0 and prints `AUTOMATED VERDICT: GO` (all phases including Phase C pass).
- [ ] No suite is silently skipped that you expected to run (the script lists
      every `SKIP`ped suite explicitly — confirm each skip is intentional, e.g.
      `test-codex-dispatch` skips when `codex` is not on PATH).
- [ ] The run covers all suites reported by `tests/bin/run-all-tests.sh --list`;
      do not copy a suite count into release metadata or this checklist.

### Prerequisites the script checks (install before running)

| Tool | Linux/WSL2 | Windows Git Bash |
|------|-----------|------------------|
| bash ≥ 4, git | system / Git for Windows | system / Git for Windows |
| `jq` | `apt install jq` | `winget install jqlang.jq` |
| **`sqlite3`** (FTS5 optional — context uses LIKE fallback when absent) | `apt install sqlite3` | `winget install SQLite.SQLite` |
| **ShellCheck** (exact repository pin) | run the two-step bootstrap in `CONTRIBUTING.md` | use the repository bootstrap from WSL2 |
| `codex` (optional, `full` profile) | `npm i -g @openai/codex` | not supported on Windows |
| `claude` (optional, for real E2E) | per Claude Code install | per Claude Code install |

> **Windows note:** `winget` appends `sqlite3` to the **User PATH**, so open a
> *new* Git Bash window before running (existing windows have a stale PATH).
> Verify with `sqlite3 --version`.

---

## 2. Manual steps (per platform)

**§2b (dispatch) and §2c (pr-gate) are now automated by `release-verify.sh
--e2e`.** Only §2a (install/uninstall) and §2d (hooks) require manual steps
because they mutate the real `~/.claude` environment.

### 2a. Install / health / uninstall

```bash
bash install.sh --verify          # runs preflight suites, then installs
bash hosts/claude/bin/install-guards.sh --repo-root "$PWD" # wire Claude hooks
bash runtime/bin/doctor.sh        # Linux / WSL2: profile auto
bash uninstall.sh                 # confirm clean removal, no leftover managed dirs
```

For upgrades that relocate managed hook targets, run `bash install.sh` immediately
after `git pull` and before starting a new Claude, Codex, or OpenCode session. The
installer refreshes host configuration to canonical owner paths; doctor fails loud
when an older configured command target is missing or no longer executable.

- [ ] `install.sh --verify` completes, managed dirs/symlinks created; `pmctl` resolvable on PATH.
- [ ] Upgrade install was re-run after pulling; a second `install.sh --dry-run`
      reports all selected hosts already wired with no conflicts.
- [ ] `doctor.sh` reports **0 FAIL**.
- [ ] `uninstall.sh` removes everything it installed (no dangling links, no leftover
      `agents/`, `commands/`, `skills/`, `scripts/`, `share/`, or `adapters/` under
      `~/.claude/`).

### 2b. Real dispatch + 2c. pr-gate — automated by `--e2e`

These are now covered by `release-verify.sh --e2e` Phase 4. No manual steps.

**Phase B** exercises real `pmctl dispatch run` output contract (files exist, non-empty).
**Phase C** runs `pmctl gate run` against a tiny synthetic git repo (local bare remote +
feature branch with a one-function diff). **Phase C requires codex on PATH** — if codex
is not available, Phase C is auto-skipped and `release-verify.sh --e2e` exits 3 (`PARTIAL
GO`) instead of 0 (`GO`). A `PARTIAL GO` is **not** sufficient for release sign-off.

> **Coverage note**: on environments without codex (e.g. claude-only setups),
> `release-verify.sh --e2e` exits 3 (`PARTIAL GO`) — it covers dispatch
> (Phase B) + offline suites (Phases 1–3) but NOT pr-gate structural validation (Phase C).
> Full release sign-off requires at least one codex-enabled Linux/WSL2 run where Phase C
> passes and the script exits 0 (`AUTOMATED VERDICT: GO`).

To run them independently:
```bash
bash tests/shell/test-e2e.sh                    # auto-detect adapter
bash tests/shell/test-e2e.sh --adapter claude   # force claude for dispatch (Phase B only)
bash tests/shell/test-e2e.sh --skip-gate        # dispatch only, explicitly skip Phase C
```

- [ ] `test-e2e.sh` (or `release-verify.sh --e2e`) exits 0 (`GO`) **with Phase C PASS** on a codex-enabled Linux/WSL2 machine.
  - If Phase C was SKIP (no codex): script exits 4 / release-verify exits 3 (`PARTIAL GO`) — this does **not** satisfy release sign-off.

### 2d. Claude Code hooks (live)

In a real Claude Code session against an installed checkout, trigger each hook
type once and confirm the output lands in the right place: `~/.pm-dispatch/usage-tracker.jsonl`
or `~/.claude/logs/hooks.log` for hook-level telemetry, project memory `episodes.jsonl`
for session summaries, or the trace/events store for dispatch telemetry.

> **Usage-tracker migration:** installations upgraded from the former
> `~/.claude/usage-tracker.jsonl` default begin a new shared tracker at the
> path above. To retain an existing history in place, set
> `PM_DISPATCH_USAGE_LOG_FILE=~/.claude/usage-tracker.jsonl` for the hook and
> usage commands before upgrading.

```bash
# write-guard: attempt a write outside the allowed path — should be DENIED with exit 2
# (trigger by asking Claude to write to /tmp/test-hook-write.txt in a Claude Code session)

# dispatch telemetry: any dispatch emits Run + Event records via pmctl (the
# machine-written routing_log.md / routing-log hook was retired — events
# now live in the trace store). Run a dispatch, then confirm the event landed:
pmctl trace tail -n 5            # newest events; a dispatch adds run.* rows

# memory-inject: start a new Claude Code session and confirm the MEMORY.md block appears
# in the first UserPromptSubmit hook output
```

- [ ] write-guard hook fires and blocks a write outside the pm share path (exit 2, no file created).
- [ ] dispatch telemetry: a dispatch appends Run/Event records visible via `pmctl trace tail` (replaces the retired routing-log hook).
- [ ] memory-inject hook injects `=== auto-memory: MEMORY.md index ===` in the session context.

---

## 3. Feature coverage matrix

Every shipped capability maps to at least one check above. Tick the row once its
covering check has passed this cycle.

| Feature | Covered by |
|---------|-----------|
| `pmctl context` index / update / query | §1 Phase 2 (`test-pmctl-context`) + §1 Phase 3 (real repo + sqlite3) |
| `pmctl context` pack / reuse-scan | §1 Phase 3 |
| `pmctl task` lifecycle (create/claim/dispatch/status/review) | §1 Phase 2 (`test-pmctl-task`, `test-pmctl-gate`) |
| `pmctl dispatch run` (claude / codex adapters) | §1 Phase 2 (`test-*-dispatch`) + §2b (real) |
| `pmctl trace` / `decision` / `validate` / `safe` | §1 Phase 2 (`test-pmctl-*`) |
| `pmctl backlog` view / lint | §1 Phase 2 (`test-pmctl-backlog`) |
| `pmctl guard check` (write-guard / bash-guard policy) | §1 Phase 2 (`test-pmctl-guard`) + §1 Phase 3b |
| `adapter generate` | §1 Phase 2 (`test-pmctl-adapter-generate`) |
| adapter manifests (`runner_kind`) | §1 Phase 3b |
| isolation policy: `isolation_level:none` rejected for codex (v0.6.0) | §1 Phase 2 (`test-*-handover`) + §1 Phase 3b |
| isolation policy: legacy trio (`sandbox`/`approval`/`skip_git_check`) removed (v0.6.0) | §1 Phase 2 (`test-*-handover`) + §1 Phase 3b |
| install / uninstall / doctor | §1 Phase 2 (`test-install/uninstall/doctor`) + §2a (real) |
| hooks (write-guard, routing, memory, usage…) | §1 Phase 2 (`test-guards`, `test-guard-framework`) + §2d (live) |
| brief-validate + handover contract | §1 Phase 2 (`test-brief-validate`, `test-*-handover`) |
| reviewer fan-out / pr-gate | §1 Phase 2 (`test-pr-gate*`) + §2c (real) |
| commands / skills frontmatter | §1 Phase 2 (`lint-agents`, `lint-frontmatter`, `test-commands*`) |
| state store / schemas | §1 Phase 2 (`test-state-store*`, `test-core-schemas`) |
| `pmctl run-stats` per-adapter outcome distribution | §1 Phase 2 (`test-pmctl-run-stats`) |

- [ ] Every row above is covered by a passing check this cycle.

---

## 4. Platform sign-off

| Platform | `--e2e` result | §2a install/doctor/uninstall | §2d hooks |
|----------|:----------------------------:|:----------------------------:|:---------:|
| Linux / WSL2 (required: exit 0 `GO`) | ☐ | ☐ | ☐ |

> Native Windows Git Bash and macOS are out of scope for release sign-off during
> the core-development phase (see `docs/platform-support.md`). Platform
> sign-off returns as a dedicated phase once the core stabilizes.

---

## 5. Tag & publish

- [ ] (v1.0.0 only, CC-358) `pmctl run-stats` was run at least once against real
      dispatch/gate history during the RC period, and any systematic failure
      pattern it surfaces (`failed`/`nonzero_exit`/`missing_terminal` clustered
      on one adapter) has a stated explanation, not just "no recent crashes."
      Attach the `--json` report to the v1.0.0 release notes as evidence.
- [ ] `CHANGELOG.md` finalized (version + date).
- [ ] Commit the version bump + changelog.
- [ ] `git tag -a vX.Y.Z -m "vX.Y.Z"` and `git push origin vX.Y.Z`.
- [ ] Create the GitHub release from the tag, pasting the changelog section.
- [ ] Post-release: re-open a fresh `## [Unreleased]` in `CHANGELOG.md`.
