# Platform support

> **Platform contract (core-development phase):** pm-dispatch officially targets
> **Linux and WSL2** (WSL2 is treated as Linux, first-class). **Native Windows
> Git Bash (msys2/mingw) is not officially supported** right now — CI runs Linux
> only, and platform-hardening work is **deferred to a dedicated phase after the
> core feature set stabilizes** (v0.5.0+) so it does not divert effort from core
> features. **Windows users should run pm-dispatch under WSL2**, which avoids the
> MSYS path / symlink / permission edge cases entirely. macOS is documented but
> untested. Native Windows may be reassessed once the core stabilizes — see
> `DECISIONS.md` (2026-06-13 defer-native-windows-support-during-core-dev).
>
> Already-shipped portability code still runs on native Windows on a best-effort
> basis (hooks are pure bash+jq, no python3; `install.sh` uses directory junctions
> for managed dirs and copies helper scripts — re-run `bash install.sh` after
> pulling; `pmctl` is not copied, add `<repo>/cli` to PATH), but it is **not
> verified by CI or release sign-off** and may regress without notice.

## Support matrix

| Platform                         | Profile support      | Notes |
| -------------------------------- | -------------------- | ----- |
| Linux                            | **First-class**      | Full profile + minimal profile |
| WSL2                             | **First-class**      | Treated as Linux |
| macOS                            | **Documented, untested** | Code path same as Linux; requires GNU `realpath` (`brew install coreutils`). No dogfood run confirmed yet — report issues if you hit problems. |
| Windows Git Bash (`msys2/mingw`) | **Not supported (use WSL2)** | Platform work deferred during core development. Shipped portability code runs best-effort but is unverified by CI/sign-off; run under WSL2 instead |
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
| sqlite3 (FTS5) | `apt install sqlite3` / `brew install sqlite` | `winget install SQLite.SQLite` | `apt install sqlite3` |
| codex CLI | optional (`full` profile) | not supported | optional |

> **`sqlite3`** is required by `pmctl context` (repo-index + FTS5 retrieval, v0.5.0+).
> Without it, `pmctl context index/query/pack/reuse-scan` exit with an error; the
> rest of pm-dispatch still works. On Windows the `winget` install appends `sqlite3`
> to the **User PATH** — open a new Git Bash window so the PATH refresh takes effect.

### All platforms (Linux / macOS / WSL2)

```bash
# 1. Clone
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"

# 2. Install managed files and wire Claude Code hooks into ~/.claude/settings.json
# (install.sh calls scripts/install-guards.sh internally; no separate step needed)
bash install.sh
```

Optional PM-host wiring is explicit because it modifies each host's global
configuration:

```bash
bash install.sh --enable-host codex
bash install.sh --enable-host opencode
```

OpenCode uses `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json` and
refuses to overwrite an existing `permission.bash` policy.

`install.sh` symlinks each file individually into `~/.claude/agents/`,
`~/.claude/commands/`, `~/.claude/scripts/`, and `~/.claude/.pm/` so that
updates to this repo are automatically reflected without re-running the installer.
It also symlinks `cli/pmctl` into `${PMCTL_BIN_DIR:-$HOME/.local/bin}/pmctl`;
if that bin directory is not already on PATH, the installer prints the exact
`export PATH=...` command to add.

### Windows Git Bash (best-effort, not officially supported — prefer WSL2)

> This walkthrough is retained for the best-effort native-Windows path, but
> native Windows Git Bash is **not officially supported** during core development
> (see the contract at the top of this page). It is not verified by CI or release
> sign-off and may regress. **Run under WSL2 instead** for a supported setup.

```bash
# Prerequisites (run in PowerShell or terminal):
winget install jqlang.jq
winget install Git.Git          # provides Git Bash

# Then in Git Bash:
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"

bash install.sh
```

Add the repo CLI directory to PATH so `pmctl` can run in place:

```bash
export PATH="${PM_DISPATCH_REPO}/cli:$PATH"
```

> **Symlink support:** On Git Bash, `ln -s` does not create real
> symlinks. `install.sh` uses `powershell.exe New-Item -ItemType Junction`
> for `agents/`, `commands/`, `skills/`, `adapters/`, and `pm-schema` directories
> so those paths auto-sync after pulling. Individual helper scripts are still
> copied. See *Update* below.

> **Copy-mode installs (no dev-mode):** Individual helper scripts are
> always installed via copy on Git Bash. Re-run `bash install.sh` after pulling to
> refresh copied files — the installer compares source vs installed sha256 and
> re-copies only files whose source has changed.
> `install.sh` prints a summary banner listing how many files were installed or refreshed via copy.
> `pmctl` is the exception: it is never copied because a copied `pmctl` treats
> the copy location as its repo root and cannot find `runtime/lib/*.sh`.

---

## Verify the install

Run the built-in health check after installing on any platform:

```bash
bash "${PM_DISPATCH_REPO}/runtime/bin/doctor.sh"
```

`doctor.sh` checks that `claude`, `jq`, and `pmctl` are on PATH, hooks are wired,
memory directory is present, scripts are executable, and frontmatter passes lint.
Each failing check prints a concrete remediation command.

Pass `--profile minimal` when the install used the minimal profile:

```bash
bash "${PM_DISPATCH_REPO}/runtime/bin/doctor.sh" --profile minimal
```

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

Pull and agents/commands/skills auto-sync via junction. Individual helper scripts
(`scripts/*.sh`) are installed via copy. Re-run `install.sh` to refresh stale copies
— the installer compares `sha256(src)` vs `sha256(dst)` and re-copies only changed files:

```bash
cd "${PM_DISPATCH_REPO}"
git pull
bash install.sh        # refreshes changed copies; creates symlinks for new files
```

Keep `${PM_DISPATCH_REPO}/cli` on PATH for `pmctl`; do not copy `cli/pmctl` into
another bin directory.

---

## Uninstall

Uninstalling has two independent parts:

### Part 1 — remove Claude Code hooks

Removes pm-dispatch hooks from `~/.claude/settings.json`. Safe to run at any time;
leaves all other settings untouched.

```bash
bash "${PM_DISPATCH_REPO}/scripts/uninstall-guards.sh"
# or with preview:
bash "${PM_DISPATCH_REPO}/scripts/uninstall-guards.sh" --dry-run
```

### Part 2 — remove managed files from ~/.claude

Removes the symlinks, junctions, or copies for agents, commands, scripts, and
the .pm schema. It also removes `~/.local/bin/pmctl` only when that path is a
symlink to this checkout's `cli/pmctl`; foreign files or symlinks are preserved.
Run after Part 1.

**Recommended (all platforms):** Use the manifest-driven uninstaller — it handles
symlinks, Windows directory junctions, and copies safely:

```bash
bash "${PM_DISPATCH_REPO}/uninstall.sh"
# or preview what will be removed:
bash "${PM_DISPATCH_REPO}/uninstall.sh" --dry-run
```

**Alternative: manual removal (Linux/macOS, copy or symlink installs only)**

> **Warning (Windows Git Bash / junction installs):** Do NOT use the `rm -f`
> commands below on `~/.claude/agents`, `~/.claude/commands`, or `~/.claude/skills`
> if those directories were installed as Windows directory junctions. Running
> `rm -f ~/.claude/agents/critic.md` inside a junction will delete the source file
> from the pm-dispatch repository, not the link.
> Use `bash "${PM_DISPATCH_REPO}/uninstall.sh"` or `rmdir ~/.claude/agents ~/.claude/commands ~/.claude/skills`
> to remove junctions without following them.

```bash
# Agents
rm -f ~/.claude/agents/architecture-reviewer.md
rm -f ~/.claude/agents/critic.md
rm -f ~/.claude/agents/project-pm.md
rm -f ~/.claude/agents/qa-tester.md
rm -f ~/.claude/agents/risk-reviewer.md
rm -f ~/.claude/agents/security-reviewer.md
rm -f ~/.claude/agents/spike.md

# Commands  (remove only pm-dispatch commands; keep any you added manually)
rm -f ~/.claude/commands/discover.md
rm -f ~/.claude/commands/mem-distill.md
rm -f ~/.claude/commands/mem-log.md
rm -f ~/.claude/commands/mem-recall.md
rm -f ~/.claude/commands/mem-search.md
rm -f ~/.claude/commands/memory-compress.md
rm -f ~/.claude/commands/pm.md
rm -f ~/.claude/commands/pr-gate.md
rm -f ~/.claude/commands/pre-impl.md
rm -f ~/.claude/commands/pre-release.md
rm -f ~/.claude/commands/research.md
rm -f ~/.claude/commands/skill-refine.md
rm -f ~/.claude/commands/spike.md

# Adapters (manifest-driven executor definitions)
rm -rf ~/.claude/adapters

# Helper scripts
rm -f ~/.claude/scripts/token-usage.sh
rm -f ~/.claude/scripts/log-usage.sh
rm -f ~/.claude/scripts/pr-gate.sh
rm -f ~/.claude/scripts/setup-project.sh
rm -f ~/.claude/scripts/patch-gitignore.sh
rm -f ~/.claude/scripts/doctor.sh

# Share assets (model alias tables)
rm -rf ~/.claude/share

# .pm schema
rm -rf ~/.claude/.pm       # symlink or directory; safe to remove entirely

# pmctl CLI symlink (Linux/macOS/WSL only)
if [ "$(readlink ~/.local/bin/pmctl 2>/dev/null)" = "${PM_DISPATCH_REPO}/cli/pmctl" ]; then
  rm -f ~/.local/bin/pmctl
fi
```

> **Tip:** If pm-dispatch is the **only** source of agents and commands in
> `~/.claude/`, you can remove the directories entirely:
> ```bash
> rm -rf ~/.claude/agents ~/.claude/commands ~/.claude/scripts ~/.claude/.pm
> ```
> Only do this if you have not added other agents or commands from other sources.
> On Windows junction installs, prefer `bash "${PM_DISPATCH_REPO}/uninstall.sh"` to avoid data loss.

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
bash install.sh
```

### Windows Git Bash minimal

```bash
# In PowerShell first:
winget install jqlang.jq Git.Git

# Then in Git Bash:
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"
bash install.sh --profile minimal
```

### WSL2

```bash
sudo apt update && sudo apt install -y jq
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"
bash install.sh
```

---

## Known limitations on Windows Git Bash

- GNU `realpath -m` not guaranteed → shimmed `realpath_m` provides equivalent behavior.
- Filesystem case-insensitive → avoid hook paths differing only by case.
- `codex` CLI hooks unsupported on Windows; `--profile full` falls back to `minimal`.
- Symlinks require Developer Mode or `MSYS=winsymlinks:nativestrict`; on Git Bash, install uses directory junctions for managed directories and copies individual helper scripts.

## Repository references

- `README.md` — overview and quick install
- `CONCEPTS.md` — architecture concepts
- `runtime/lib/portable.sh` — `link_or_copy()` and install manifest
- `scripts/install-guards.sh` — hook wiring
- `scripts/uninstall-guards.sh` — hook removal
- `docs/platform-support.md` (this document)
