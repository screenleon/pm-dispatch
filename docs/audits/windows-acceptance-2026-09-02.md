# Native Windows acceptance run — 2026-09-02

Recorded evidence for the experimental native-Windows local-use exception
declared in `docs/platform-support.md` (see the decision
`windows-git-bash-experimental-local-use-exception` in `DECISIONS.md`).

## Run

| Field | Value |
|---|---|
| Host | Maintainer's native Windows machine, Git Bash (MSYS2), Developer Mode enabled |
| Date | 2026-09-02 |
| Script | `ops/diagnostics/windows-acceptance.sh` |
| Tree | branch `fix/windows-native-hooks`, recorded in commit `7f37ccd` |
| Result | **10 passed, 0 failed** |

The run covers: both host installs into throwaway config roots, launch of
every wired hook command through the real PowerShell hook runner, the codex
command guard's allow AND deny paths under that launcher, and native-symlink
versus copy-fallback behavior.

## Supplementary on-platform matrices (same run, same machine)

- `tests/shell/test-guards.sh --filter "pm-bash:"` — 84 passed, 0 failed
- On-platform regex matrix mirroring every pm-bash denylist case — 65/65
- Real-hook launch matrix — 61/61

## What the run caught

The first acceptance execution failed its `codex-guard-denies` check and
exposed a real defect: the MSYS `[[ =~ ]]` engine silently ignores `\b`, so
every `\b`-anchored entry in the `guard-pm-bash.sh` denylist was a no-op on
native Windows (destructive commands passed the guard). Fixed in commit
`7f37ccd` by replacing `\b` with explicit POSIX-ERE boundaries; the recorded
10/0 result is from the fixed tree.

## Validity boundary

This is a manual maintainer run, not CI. It attests the recorded tree on one
machine at one point in time; the platform contract in
`docs/platform-support.md` still marks native Windows as experimental and
outside release sign-off. Re-run the script and append a new dated section
(or a new sibling file) whenever the Windows-relevant surfaces change.
