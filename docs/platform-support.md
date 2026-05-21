# Platform support

> **Status (2026-05-20, v0.2.0)**: CC-104t (python→jq hook rewrite) has landed —
> hooks are now functional on Windows Git Bash without requiring python3.
> Windows is **experimental**: install succeeds and all hooks run, but
> `install.sh` uses directory junctions for managed directories on Git Bash
> so agents, commands, skills, and the pm schema auto-sync after updates.
> Individual helper script files are still copied; re-run `bash install.sh`
> after pulling when scripts change. Tracked as CC-207.
> **WSL2 remains the recommended Windows path** (treated as Linux, first-class).

## Support matrix

| Platform                         | Profile support      | Notes |
| -------------------------------- | -------------------- | ----- |
| Linux                            | **First-class**      | Full profile + minimal profile |
| macOS                            | **Documented, untested** | Code path same as Linux; requires GNU `realpath` (`brew install coreutils`). No dogfood run confirmed yet — report issues if you hit problems. |
| WSL2                             | **First-class**      | Treated as Linux |
| Windows Git Bash (`msys2/mingw`) | **Experimental**     | Hooks functional; directory junctions restore auto-sync for managed directories; re-run `bash install.sh` after script updates |
| Other / unrecognized             | Best effort          | Install may succeed or fail depending on tool availability |

---

## Install

> **Repo path:** clone to any location you prefer. Set `PM_DISPATCH_REPO` to that
> path before running the commands below, or substitute it inline.
>
> ```bash
> export PM_DISPATCH_REPO="$HOME/github/pm-dispatch"   # or wherever you cloned it
> ```

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
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"

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
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"

bash install.sh
bash scripts/install-hooks.sh
```

> **Symlink support (CC-207):** On Git Bash, `ln -s` does not create real
> symlinks. `install.sh` uses `powershell.exe New-Item -ItemType Junction`
> for `agents/`, `commands/`, `skills/`, and `pm-schema` directories so those
> paths auto-sync after pulling. Individual helper scripts are still copied.
> See *Update* below.

---

## Update

### Linux / macOS / WSL2

**Changes to existing files** take effect immediately because `~/.claude/agents/`,
`~/.claude/commands/`, etc. contain per-file symlinks pointing into the repo.

**New files** (e.g. a newly added agent or command) do **not** appear automatically —
`install.sh` creates one symlink per file at install time and cannot know about
files added later. Re-run `bash install.sh` after pulling to pick up new entries:

```bash
cd "${PM_DISPATCH_REPO}"
git pull
bash install.sh    # creates symlinks for any new files
```

### Windows Git Bash

Pull and agents/commands/skills auto-sync via junction; only individual script
files (`scripts/*.sh`) need re-run after updates:

```bash
cd "${PM_DISPATCH_REPO}"
git pull
bash install.sh        # re-sync copied helper scripts when they change
```

Re-running `install.sh` is idempotent; it refreshes copied helper scripts with
the latest versions and is safe to run at any time.

---

## Uninstall

Uninstalling has two independent parts:

### Part 1 — remove Claude Code hooks

Removes pm-dispatch hooks from `~/.claude/settings.json`. Safe to run at any time;
leaves all other settings untouched.

```bash
bash "${PM_DISPATCH_REPO}/scripts/uninstall-hooks.sh"
# or with preview:
bash "${PM_DISPATCH_REPO}/scripts/uninstall-hooks.sh" --dry-run
```

### Part 2 — remove managed files from ~/.claude

Removes the symlinks, junctions, or copies for agents, commands, scripts, and
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
rm -f ~/.claude/scripts/pr-gate.sh
rm -f ~/.claude/scripts/codex-dispatch.sh
rm -f ~/.claude/scripts/setup-project.sh
rm -f ~/.claude/scripts/patch-gitignore.sh

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

> **Note:** macOS install steps follow the same code path as Linux and are
> documented based on that, but have not been verified by a dogfood run.
> Please report any issues you encounter.

```bash
brew install jq coreutils
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"
bash install.sh && bash scripts/install-hooks.sh
```

### Windows Git Bash minimal

```bash
# In PowerShell first:
winget install jqlang.jq Git.Git

# Then in Git Bash:
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"
bash install.sh
bash scripts/install-hooks.sh --profile minimal
```

### WSL2

```bash
sudo apt update && sudo apt install -y jq
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"
bash install.sh && bash scripts/install-hooks.sh
```

---

## Known limitations on Windows Git Bash

- `flock` unavailable → `hook-routing-log.sh` uses a directory-lock shim.
- GNU `realpath -m` not guaranteed → shimmed `realpath_m` provides equivalent behavior.
- Filesystem case-insensitive → avoid hook paths differing only by case.
- `codex` CLI hooks unsupported on Windows; `--profile full` falls back to `minimal`.
- Symlinks require Developer Mode or `MSYS=winsymlinks:nativestrict`; on Git Bash, install uses directory junctions for managed directories and copies individual helper scripts (CC-207).

## Repository references

- `README.md` — overview and quick install
- `CONCEPTS.md` — architecture concepts
- `scripts/lib/portable.sh` — `link_or_copy()` and install manifest
- `scripts/install-hooks.sh` — hook wiring
- `scripts/uninstall-hooks.sh` — hook removal
- `docs/platform-support.md` (this document)
