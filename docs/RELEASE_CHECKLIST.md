# Release verification checklist

Run this **before tagging any release**. It is the single fixed procedure: work
top to bottom, and only tag when every box is checked on **both Linux and
Windows Git Bash** (macOS is out of scope — see `docs/platform-support.md`).

The goal is that **every feature is actually exercised**, not just unit-tested.
Coverage splits into three layers:

| Layer | What runs it | Covers |
|-------|--------------|--------|
| **Offline automated** | `scripts/release-verify.sh` (Phases 1–3) | prerequisites, all 51 test suites, real `pmctl context` smoke + real `sqlite3` |
| **Live E2E automated** | `scripts/release-verify.sh --e2e` (Phase 4) | real dispatch output contract, real pr-gate structural validation — spends LLM tokens |
| **Manual** | §2a / §2d below | real install + hooks, `doctor`, Claude Code hook execution — environment-mutating, not automatable |

A release is **GO** only when `release-verify.sh --e2e` prints `GO` and every §2a / §2d box is ticked.

---

## 0. Pre-flight

- [ ] Working tree clean on the release branch (`git status` empty).
- [ ] `git pull` — branch up to date with `origin`.
- [ ] `VERSION` / installer version bumped to the target (e.g. `0.5.0`).
- [ ] `CHANGELOG.md`: `## [Unreleased]` section reviewed and renamed to
      `## [x.y.z] — YYYY-MM-DD`; every shipped change is listed.
- [ ] No `TODO(release)` / `XXX` left in changed files: `git grep -nE 'TODO\(release\)|XXX'`.

---

## 1. Automated verification (`release-verify.sh`)

Run on **each** platform you ship to.

```bash
# Linux / WSL2 — Phases 1-3 (offline, no tokens)
bash scripts/release-verify.sh

# Same platform — Phase 4: real dispatch + pr-gate (spends LLM tokens)
bash scripts/release-verify.sh --e2e
# or with explicit adapter:
bash scripts/release-verify.sh --e2e --adapter claude

# Windows Git Bash (ensure sqlite3 is installed first — see §Prerequisites below)
bash scripts/release-verify.sh --e2e
```

Note: Phase 3 indexes the whole repo and is slow on Windows Git Bash (minutes)
— this is expected (MSYS subprocess overhead).

- [ ] **Linux**: `release-verify.sh --e2e` final line prints `AUTOMATED VERDICT: GO`.
- [ ] **Windows Git Bash**: `release-verify.sh --e2e` final line prints `AUTOMATED VERDICT: GO`.
- [ ] No suite is silently skipped that you expected to run (the script lists
      every `SKIP`ped suite explicitly — confirm each skip is intentional, e.g.
      `test-codex-dispatch` skips when `codex` is not on PATH).

### Prerequisites the script checks (install before running)

| Tool | Linux/WSL2 | Windows Git Bash |
|------|-----------|------------------|
| bash ≥ 4, git | system / Git for Windows | system / Git for Windows |
| `jq` | `apt install jq` | `winget install jqlang.jq` |
| **`sqlite3` (with FTS5)** | `apt install sqlite3` | `winget install SQLite.SQLite` |
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
bash scripts/install-hooks.sh     # wire hooks into ~/.claude/settings.json
bash scripts/doctor.sh            # Linux: profile auto
bash scripts/doctor.sh --profile minimal   # Windows Git Bash (auto false-FAILs if codex CLI present)
bash uninstall.sh                 # confirm clean removal, no leftover share/ dir
```

- [ ] `install.sh --verify` completes, managed dirs/symlinks (or junctions on
      Windows) created; `pmctl` resolvable on PATH.
- [ ] `doctor.sh` reports **0 FAIL** (use `--profile minimal` on Windows).
- [ ] `uninstall.sh` removes everything it installed (no dangling links, no empty
      `share/`).

### 2b. Real dispatch + 2c. pr-gate — automated by `--e2e`

These are now covered by `release-verify.sh --e2e` Phase 4. No manual steps.

To run them independently:
```bash
bash scripts/test-e2e.sh                   # auto-detect adapter
bash scripts/test-e2e.sh --adapter claude  # force claude
bash scripts/test-e2e.sh --skip-gate       # dispatch only, skip gate
```

- [ ] `test-e2e.sh` (or `release-verify.sh --e2e`) prints `GO` on this platform.

### 2d. Claude Code hooks (live)

In a real Claude Code session against an installed checkout, trigger each hook
type once and confirm the output lands in `share/` or the trace store.

```bash
# write-guard: attempt a write outside the allowed path — should be DENIED with exit 2
# (trigger by asking Claude to write to /tmp/test-hook-write.txt in a Claude Code session)

# routing-log: any dispatch emits a routing event; check the log file grew
tail -f ~/.claude/.pm/share/routing.log   # open in another terminal, then run a dispatch

# memory-inject: start a new Claude Code session and confirm the MEMORY.md block appears
# in the first UserPromptSubmit hook output
```

- [ ] write-guard hook fires and blocks a write outside the pm share path (exit 2, no file created).
- [ ] routing-log hook appends a JSON line to `share/routing.log` after a dispatch.
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
| `pmctl guard check` (write-guard / bash-guard policy) | §1 Phase 2 (`test-pmctl-guard`) |
| `adapter generate` | §1 Phase 2 (`test-pmctl-adapter-generate`) |
| install / uninstall / doctor | §1 Phase 2 (`test-install/uninstall/doctor`) + §2a (real) |
| hooks (write-guard, routing, memory, usage…) | §1 Phase 2 (`test-hooks`, `test-hook-framework`) + §2d (live) |
| brief-validate + handover contract | §1 Phase 2 (`test-brief-validate`, `test-*-handover`) |
| reviewer fan-out / pr-gate | §1 Phase 2 (`test-pr-gate*`) + §2c (real) |
| commands / skills frontmatter | §1 Phase 2 (`lint-agents`, `lint-frontmatter`, `test-commands*`) |
| state store / schemas | §1 Phase 2 (`test-state-store*`, `test-core-schemas`) |

- [ ] Every row above is covered by a passing check this cycle.

---

## 4. Platform sign-off

| Platform | `--e2e` GO | §2a install/doctor/uninstall | §2d hooks |
|----------|:----------:|:----------------------------:|:---------:|
| Linux / WSL2 | ☐ | ☐ | ☐ |
| Windows Git Bash | ☐ | ☐ | ☐ |

---

## 5. Tag & publish

- [ ] `CHANGELOG.md` finalized (version + date).
- [ ] Commit the version bump + changelog.
- [ ] `git tag -a vX.Y.Z -m "vX.Y.Z"` and `git push origin vX.Y.Z`.
- [ ] Create the GitHub release from the tag, pasting the changelog section.
- [ ] Post-release: re-open a fresh `## [Unreleased]` in `CHANGELOG.md`.
