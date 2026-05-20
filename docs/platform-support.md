# Platform support

> **Status (2026-05-20, v0.2.0)**: CC-104t (python→jq hook rewrite) has landed —
> hooks are now functional on Windows Git Bash without requiring python3.
> Windows is **experimental**: install succeeds and all hooks run, but
> `install.sh` copies files instead of symlinking on Git Bash (no auto-sync
> after updates; re-run `bash install.sh` after pulling). Tracked as CC-207.
> **WSL2 remains the recommended Windows path** (treated as Linux, first-class).

## Support matrix

| Platform                         | Profile support      | Notes |
| -------------------------------- | -------------------- | ----- |
| Linux                            | **First-class**      | Full profile + minimal profile |
| macOS                            | **First-class**      | Requires GNU `realpath` (`brew install coreutils`) |
| WSL2                             | **First-class**      | Treated as Linux |
| Windows Git Bash (`msys2/mingw`) | **Experimental**     | Hooks functional; install copies rather than symlinks (CC-207); re-run `bash install.sh` after updates |
| Other / unrecognized             | Best effort          | Install may succeed or fail depending on tool availability |

---

## Install

### Prerequisites

| Tool | Linux/macOS | Windows (Git Bash) | WSL2 |
|------|-------------|-------------------|------|
| bash ≥ 4 | system | Git for Windows | system |
| jq ≥ 1.6 | `apt install jq` / `brew install jq` | `winget install jqlang.jq` | `apt install jq` |
| git | system | Git for Windows | system |
| codex CLI | optional (`full` profile) | not supported | optional |

### All platforms (Linux / macOS / WSL2)

```bash
# 1. Clone
git clone https://github.com/screenleon/pm-dispatch ~/github/pm-dispatch
cd ~/github/pm-dispatch

# 2. Install managed files (agents, commands, scripts, .pm schema)
bash install.sh

# 3. Wire Claude Code hooks into ~/.claude/settings.json
bash scripts/install-hooks.sh
```

`install.sh` symlinks each file individually into `~/.claude/agents/`,
`~/.claude/commands/`, `~/.claude/scripts/`, and `~/.claude/.pm/` so that
updates to this repo are automatically reflected without re-running the installer.

### Windows Git Bash

```bash
# Prerequisites (run in PowerShell or terminal):
winget install jqlang.jq
winget install Git.Git          # provides Git Bash

# Then in Git Bash:
git clone https://github.com/screenleon/pm-dispatch ~/github/pm-dispatch
cd ~/github/pm-dispatch

bash install.sh
bash scripts/install-hooks.sh
```

> **Known limitation (CC-207):** On Git Bash, `ln -s` does not create real
> symlinks, so `install.sh` falls back to **copying files**. After pulling
> pm-dispatch updates you must re-run `bash install.sh` to sync the copies.
> See *Update* below.

---

## Update

### Linux / macOS / WSL2

Because files are symlinked, a `git pull` is all that is needed:

```bash
cd ~/github/pm-dispatch
git pull
```

New agents, commands, or scripts added to the repo appear in `~/.claude/`
immediately — no installer re-run required. If the install manifest itself
changes (new directories, new top-level entries), re-run `bash install.sh`
once to create any missing symlinks.

### Windows Git Bash

Because files are copied rather than symlinked:

```bash
cd ~/github/pm-dispatch
git pull
bash install.sh        # re-sync all copies
```

Re-running `install.sh` is idempotent; it overwrites copies with the latest
versions and is safe to run at any time.

---

## Uninstall

Uninstalling has two independent parts:

### Part 1 — remove Claude Code hooks

Removes pm-dispatch hooks from `~/.claude/settings.json`. Safe to run at any time;
leaves all other settings untouched.

```bash
bash ~/github/pm-dispatch/scripts/uninstall-hooks.sh
# or with preview:
bash ~/github/pm-dispatch/scripts/uninstall-hooks.sh --dry-run
```

### Part 2 — remove managed files from ~/.claude

Removes the symlinks (or copies on Windows) for agents, commands, scripts, and
the .pm schema. Run after Part 1.

```bash
# Agents
rm -f ~/.claude/agents/architecture-reviewer.md
rm -f ~/.claude/agents/claude-executor.md
rm -f ~/.claude/agents/codex-executor.md
rm -f ~/.claude/agents/critic.md
rm -f ~/.claude/agents/project-pm.md
rm -f ~/.claude/agents/qa-tester.md
rm -f ~/.claude/agents/risk-reviewer.md
rm -f ~/.claude/agents/security-reviewer.md

# Commands  (remove only pm-dispatch commands; keep any you added manually)
rm -f ~/.claude/commands/mem-log.md
rm -f ~/.claude/commands/mem-recall.md
rm -f ~/.claude/commands/pm.md
rm -f ~/.claude/commands/pr-gate.md

# Helper scripts
rm -f ~/.claude/scripts/token-usage.sh
rm -f ~/.claude/scripts/log-usage.sh

# .pm schema
rm -rf ~/.claude/.pm       # symlink or directory; safe to remove entirely
```

> **Tip:** If pm-dispatch is the **only** source of agents and commands in
> `~/.claude/`, you can remove the directories entirely:
> ```bash
> rm -rf ~/.claude/agents ~/.claude/commands ~/.claude/scripts ~/.claude/.pm
> ```
> Only do this if you have not added other agents or commands from other sources.

---

## Quickstarts

### macOS

```bash
brew install jq coreutils
git clone https://github.com/screenleon/pm-dispatch ~/github/pm-dispatch
cd ~/github/pm-dispatch
bash install.sh && bash scripts/install-hooks.sh
```

### Windows Git Bash minimal

```bash
# In PowerShell first:
winget install jqlang.jq Git.Git

# Then in Git Bash:
git clone https://github.com/screenleon/pm-dispatch ~/github/pm-dispatch
cd ~/github/pm-dispatch
bash install.sh
bash scripts/install-hooks.sh --profile minimal
```

### WSL2

```bash
sudo apt update && sudo apt install -y jq
git clone https://github.com/screenleon/pm-dispatch ~/github/pm-dispatch
cd ~/github/pm-dispatch
bash install.sh && bash scripts/install-hooks.sh
```

---

## Known limitations on Windows Git Bash

- `flock` unavailable → `hook-routing-log.sh` uses a directory-lock shim.
- GNU `realpath -m` not guaranteed → shimmed `realpath_m` provides equivalent behavior.
- Filesystem case-insensitive → avoid hook paths differing only by case.
- `codex` CLI hooks unsupported on Windows; `--profile full` falls back to `minimal`.
- Symlinks require Developer Mode or `MSYS=winsymlinks:nativestrict` → install falls back to file copy (CC-207).

## Repository references

- `README.md` — overview and quick install
- `CONCEPTS.md` — architecture concepts
- `scripts/lib/portable.sh` — `link_or_copy()` and install manifest
- `scripts/install-hooks.sh` — hook wiring
- `scripts/uninstall-hooks.sh` — hook removal
- `docs/platform-support.md` (this document)
