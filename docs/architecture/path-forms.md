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
- The standalone two-line copies of the old shim in copied hooks, `install.sh` and
  `ops/usage/usage-weekly.sh`: they only add `-b`.
- `jq` started as a program rather than from bash (`env jq`, `xargs jq`, `timeout 5 jq`, `find -exec jq`).

### Cost

A word that starts with a drive letter (`/c/...`) is converted in the shell for free. Any other absolute
Unix path (`/tmp/...` when `TMPDIR` is unset) costs one `cygpath -m` process, about 0.15 to 0.25 s on
native Windows, per call that has such an operand; MSYS did this conversion in-process before. Put
temporary files under `$TMPDIR` set to a drive path, or batch the work into fewer `jq` calls, when a hot
loop needs it. The existing `MSYS2_ARG_CONV_EXCL='*' jq ...` prefixes in `runtime/lib/gate-*.sh` and
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
