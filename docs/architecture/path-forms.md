# Path forms on native Windows

On Linux a directory has one spelling. On native Windows (Git Bash / MSYS2) the same directory has
several, and a native program, the MSYS runtime and git each prefer a different one. This note says
which form to use where. The decision and its alternatives are in `DECISIONS.md`
(2026-10-12, `path-forms-identity-wire-and-native-process`); the issue that raised it is #590.

## The three forms

| Form | Example | Produced by | Used for |
|---|---|---|---|
| **Identity** | `c:/Users/<name>/repo` | `_portable_canonical_path` (long names, drive letter lower case) | hashing a project key, comparing two paths for "same place". Meant never to be stored; today `pmctl-gate` and `pmctl-dispatch` also pass it on as `work_dir` (see "Where the code is not there yet"). |
| **Wire** | `/c/Users/<name>/repo` | `pwd` (can be a short name; not guaranteed), or `_portable_long_posix_path` from any other spelling | everything serialised: artifact fields, schema-bound fields (`pattern: "^/"`), events, values passed to another process as data. |
| **Native-process** | `C:/Users/<name>/repo` | `cygpath -m`, or the `jq()` shim for its file operands | a path a native Windows program must open. Made at the call, never stored. |

The same directory can also appear as an 8.3 short name (`C:/Users/<NAME>~1/...`) or, under `/tmp`, a
mount alias; `_portable_canonical_path` and `_portable_long_posix_path` resolve both to the long name
(CC-642).

## Rules

1. **Hash or compare in the identity form.** Compare two paths only after both went through the same
   function. `_sw_project_key` does this on the git top-level.
2. **Store and serialise the wire form.** This is the rule for new code (see "Where the code is not
   there yet"). A path that comes out of a native tool is `C:/...`:
   `git rev-parse --show-toplevel`, `git rev-parse --git-common-dir` for a linked worktree, `cygpath -m`.
   Pass it through `_portable_long_posix_path` before it goes into a field that a schema or another host
   reads.
3. **Give a native program the native-process form at the call.** The path argument of `git worktree
   add|list|remove` goes through `_pmctl_worktree_git_path` (`cygpath -m`; a path with `[`, `*` or `?`
   in it is not converted by MSYS on its own; it does not resolve 8.3 short names); `jq` takes it from
   the shim.

## `jq`

`jq` is a native program, so the MSYS runtime rewrites every argument that looks like a POSIX path before
it starts: `jq --arg repo /c/Users/x` used to hand the filter `"C:/Users/x"`. A value given to `--arg` is
never a file name to jq, so it must never be converted.

`runtime/lib/jq-lf.sh` defines `jq()`, which every entry script already has to load (`lint-jq-lf`). It:

- runs the call with `MSYS2_ARG_CONV_EXCL='*'`, so no argument is rewritten;
- leaves alone the value of `--arg` and `--argjson`, the words after `--args` / `--jsonargs`, the program
  text and the number after `--indent`;
- converts the words that name files or directories to the native-process form: input files, the program file after
  `-f` / `--from-file` (also inside a cluster such as `-nf`), and the file of `--rawfile` / `--slurpfile`, and the directory of `-L` / `--library-path` (also `-L<dir>`).
  A word `/X/...` with a one-letter first component becomes `X:/...` in the shell; any other absolute
  Unix path goes through `cygpath -m` once; relative words, `-` and `//server/...` stay as they are.

You do not add anything to a `jq` call for this. Two things to know:

- Do not put `MSYS2_ARG_CONV_EXCL='*'` on a `jq` call yourself: it is already set, and by hand it would
  stop a file operand from being opened if the shim were not loaded.
- A value that must be a native path (for example one a later native program will open) is converted by
  the caller with `cygpath -m` before it is passed.

### What the shim does not cover

- Environment variables (`jq -n 'env.X'`): MSYS rewrites those under `MSYS2_ENV_CONV_EXCL`, and no jq
  program in this repository reads `env.*`.
- `/dev/fd/N` operands (process substitution) and a `-L` given inside a cluster (`-nL dir`).
- The standalone two-line copies of the old shim: they only add `-b`. About 30 scripts that pass no
  path-shaped `--arg` value still carry one (the guard hooks, `ops/`, `tools/`, the supervisors); the
  installers and uninstallers that pass path values (`install.sh`, `uninstall.sh`, `hosts/*/bin/*.sh`)
  source the shim instead. A script that starts passing a path value must source the shim too. A
  library under `runtime/lib/` never defines `jq()` over the shim (`lint-jq-lf`): the only form allowed
  sits directly under `if ! declare -F jq >/dev/null 2>&1; then`, so a library sourced on its own still
  gets `-b` and one sourced after the shim leaves it alone. Where the shim file is not next to an
  installer (a minimal copy a test fixture builds), the installer falls back to the same two-line copy.
- `jq` started as a program rather than from bash (`env jq`, `xargs jq`, `timeout 5 jq`, `find -exec jq`).

### Cost

A word that starts with a drive letter (`/c/...`) is converted in the shell for free, and so is one that
lies under a mount of the mount table other than `/` and the drives (`/tmp` is the user's `%TEMP%`, `/bin`
is Git's `usr/bin`): the shim reads `/proc/mounts` with shell built-ins and replaces the mount point by
its native directory (the longest mount point wins; a mount point counts only at a path boundary).
Measured on native Windows: ten `jq` calls on a file under `/tmp` took 2.7 s through `cygpath` and 1.35 s
this way. Any other absolute Unix path (`/home/...`, `/etc/...`, `/dev/null`) still costs one `cygpath -m`
process, about 0.15 s, per call. So does a word that `cygpath` would normalise or map: one with a `.` or
`..` segment (also across a mount, where a string rewrite would name another file), a doubled slash, or a
character NTFS cannot hold in a name (`: * ? " < > | \`). A table line counts only when its first field is a
native directory (`X:...` or `//...`); anything else, an unreadable table, and every shell that is not
`OSTYPE=msys*` use `cygpath` (or leave the word). A path under `/bin` is not given the `.exe` suffix
`cygpath` adds to an executable's name (no `jq` operand is one). The table is read again for each operand
because sourcing the shim must leave nothing but the `jq` function. `PM_DISPATCH_JQ_LF_MOUNTS` names another
table file (a test seam). The existing `MSYS2_ARG_CONV_EXCL='*' jq ...` prefixes in `runtime/lib/gate-*.sh` and
`pmctl-gate.sh` are now redundant (none of those calls has a file operand); they are harmless.

## Where the code is not there yet

- `pmctl-gate.sh` (`--cd`, default working directory) and `pmctl-dispatch.sh` turn the working directory
  into the identity form with `_portable_canonical_path` and carry it as `work_dir`. That is the cause
  of the `--cd defaults to CWD git toplevel` failure still open in CC-643 item 16.
- `_portable_long_posix_path` is used by the install-manifest key only; the artifact writers do not call
  it yet. The wire-form rule is enforced by the `^/` schemas, not by a helper.

## Testing

`tests/shell/test-jq-lf.sh` checks the argument handling on any platform with a stub `jq` and a stub
`cygpath`, and checks the real `jq` (path values come back byte for byte, every way of naming a file
still opens it) where one exists. A native run is the one that proves the MSYS behaviour.
`tests/shell/test-pmctl-gate.sh` builds assurance fixtures through the same shim, so a path-shaped value
that leaked into a `^/` field fails there.
