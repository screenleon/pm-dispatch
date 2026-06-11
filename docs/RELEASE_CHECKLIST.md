# Release verification checklist

Run this **before tagging any release**. It is the single fixed procedure: work
top to bottom, and only tag when every box is checked on **both Linux and
Windows Git Bash** (macOS is out of scope — see `docs/platform-support.md`).

The goal is that **every feature is actually exercised**, not just unit-tested.
Coverage splits into two layers:

| Layer | What runs it | Covers |
|-------|--------------|--------|
| **Automated** | `scripts/release-verify.sh` | prerequisites, all 49 test suites, real `pmctl context` smoke against this repo + real `sqlite3` |
| **Manual E2E** | the steps in §2 below | real install + hooks, real dispatch on each executor, reviewer fan-out — things that mutate the environment or spend LLM tokens |

A release is **GO** only when §1 prints `GO` and every §2 / §3 / §4 box is ticked.

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

Run on **each** platform you ship to. Note: Phase 3 indexes the whole repo and is
slow on Windows Git Bash (minutes) — this is expected (MSYS subprocess overhead).

```bash
# Linux / WSL2
bash scripts/release-verify.sh

# Windows Git Bash (ensure sqlite3 is installed first — see §Prerequisites below)
bash scripts/release-verify.sh
```

- [ ] **Linux**: final line prints `AUTOMATED VERDICT: GO`.
- [ ] **Windows Git Bash**: final line prints `AUTOMATED VERDICT: GO`.
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

## 2. Manual end-to-end (per platform)

These touch the real environment and/or spend LLM tokens, so they are not in the
automated script. Do them in a throwaway/dev `~/.claude`, not your production one
if you want to be safe.

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

### 2b. Real dispatch — one per supported executor

Write a minimal valid brief to a file (see `docs/dispatch-brief.md` for the
schema), then dispatch. The dispatch OWNS brief-validate + guard preflight.

```bash
# claude executor (supported on Linux AND Windows Git Bash)
pmctl dispatch run --adapter claude --cd <workdir> --brief-file <brief.md>

# codex executor (Linux / WSL2 only; needs `codex login` — see platform notes)
pmctl dispatch run --adapter codex  --cd <workdir> --brief-file <brief.md>
```

- [ ] **claude** dispatch exits 0, produces the expected artifact, and writes a
      run footer + `trace`/`.jsonl` capture (and `latest.*` pointer).
- [ ] **codex** dispatch (Linux) exits 0 with the same evidence.
- [ ] A **malformed brief** (e.g. missing `schema_version`) is `REJECT`ed with no
      executor spawned and no target file read.

### 2c. Reviewer fan-out (PR gate)

```bash
bash scripts/pr-gate.sh --executor claude
```

- [ ] Gate runs the reviewer tiers and emits a GO / NO-GO synthesis; piped stdout
      is non-empty and exit code matches the verdict (no 0-byte / false-success).

### 2d. Claude Code hooks (live)

- [ ] In a real Claude Code session against an installed checkout, confirm the
      write-guard / routing-log / memory-inject hooks fire (trigger one of each
      and check `share/`/trace output).

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
| `pmctl trace` / `decision` / `backlog` / `validate` / `safe` / `guard` | §1 Phase 2 (`test-pmctl-*`) |
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

| Platform | §1 GO | §2a install/doctor/uninstall | §2b dispatch | §2c pr-gate | §2d hooks |
|----------|:-----:|:----------------------------:|:------------:|:-----------:|:---------:|
| Linux / WSL2 | ☐ | ☐ | ☐ (claude+codex) | ☐ | ☐ |
| Windows Git Bash | ☐ | ☐ | ☐ (claude only) | ☐ | ☐ |

---

## 5. Tag & publish

- [ ] `CHANGELOG.md` finalized (version + date).
- [ ] Commit the version bump + changelog.
- [ ] `git tag -a vX.Y.Z -m "vX.Y.Z"` and `git push origin vX.Y.Z`.
- [ ] Create the GitHub release from the tag, pasting the changelog section.
- [ ] Post-release: re-open a fresh `## [Unreleased]` in `CHANGELOG.md`.
