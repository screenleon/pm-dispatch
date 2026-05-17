# Platform support

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
| Windows Git Bash (`msys2/mingw`)      | **Minimal only**     | `--profile full` downgrades to minimal |
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
