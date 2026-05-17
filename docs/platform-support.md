# Platform support

> **Status (2026-05-17, v0.1.0)**: a first-Windows-user dogfood run uncovered
> several blockers that downgrade Windows from "minimal-supported" to
> **experimental**. Known issues are tracked as CC-104c..CC-104i in `BACKLOG.md`.
> If you are on Windows, prefer **WSL2** (treated as Linux, first-class) until
> CC-104c (install.sh symlink → copy fallback) lands. Native Windows Git Bash
> currently fails at install — `ln -s` silently copies files instead of
> creating symlinks without Developer Mode + `MSYS=winsymlinks:nativestrict`.

## Summary

`pm-dispatch` ships one script installer and multiple hook wrappers.
Most behavior remains the same on Linux, macOS, and WSL2.
Windows users are supported in a reduced profile while preserving the same
core safe-guard behavior.

## Support matrix

| Platform                              | Profile support      | Notes |
| ------------------------------------- | -------------------- | ----- |
| Linux                                 | **First-class**      | Full profile + minimal profile |
| macOS                                 | **First-class**      | Requires GNU `realpath` (`coreutils`) |
| WSL2                                  | **First-class**      | Treated as Linux |
| Windows Git Bash (`msys2/mingw`)      | **Experimental** (see CC-104c..CC-104i) | Install currently broken: `ln -s` falls back to file copy without Developer Mode + `MSYS=winsymlinks:nativestrict`; prefer WSL2 |
| Other/unrecognized platforms           | Best effort          | Install may succeed or fail depending on tool availability |

## Windows quickstart (minimal profile)

1. Install Git for Windows (Git Bash, coreutils, `readlink`, etc.).
2. Install jq:

```bash
winget install jqlang.jq
```

3. Optional shell tooling:

```bash
winget install Microsoft.PowerShell
```

4. Install hooks with minimal profile (or rely on default auto-detection):

```bash
./scripts/install-hooks.sh --profile minimal --platform windows
# or
./scripts/install-hooks.sh --platform windows
```

## macOS quickstart

```bash
brew install jq coreutils
./scripts/install-hooks.sh
```

Coreutils provides GNU `realpath` with `-m`, which is required for Linux-like
path normalization behavior.

## Codex availability note

`codex` hooks are not wired on Windows in this phase.
On Windows, `--profile full` is treated as:

```text
install-hooks: platform=windows, --profile full requested; codex hooks unsupported on Windows yet, falling back to minimal
```

Windows users get a stable minimal profile that includes PM/Codex safe-guards that
do not require Windows-incompatible codex integrations.

## Known limitations on Windows Git Bash

- `flock` is not available; `hook-routing-log.sh` uses a directory-based lock shim.
- GNU `realpath -m` is not guaranteed; shimmed `realpath_m` provides equivalent
  behavior.
- Filesystem is case-insensitive; avoid hook paths that differ only by case.
- Routing-log hook is gated if `jq` is unavailable on PATH.
- Keep shell scripts UTF-8 and avoid non-ASCII paths where possible.

## Repository references

- `README.md`
- `CONCEPTS.md`
- `scripts/lib/portable.sh`
- `scripts/install-hooks.sh`
- `docs/platform-support.md` (this document)
