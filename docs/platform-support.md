# Platform support

> **Platform contract (core-development phase):** Linux and WSL2 are
> first-class. Native Windows Git Bash is **experimental**: it is supported for
> local Claude and Codex use when Git Bash, jq, and sqlite3 are available, but
> it is not a release-sign-off platform. Windows Developer Mode is required
> only for **native symlinks** (auto-sync after `git pull`); without it the
> installer still works via receipt-owned copy fallback — re-run `install.sh`
> after pulling. macOS and other hosts remain unsupported.
>
> **Evidence boundary:** `windows-native-smoke` in `.github/workflows/lint.yml`
> is configured for every PR and main push on `windows-latest`, using an explicit
> Git for Windows Bash executable and pinned jq 1.8.1 / SQLite 3.50.2 (FTS5).
> The checkout and disposable config roots contain spaces. The bounded job checks
> CLI help, doctor JSON diagnostics, real PowerShell hook launches, destructive
> command denial, native symlink creation when available, forced product copy
> fallback, a private-ACL state event write/read, directory-lock acquire/release,
> and receipt-owned copy install/reinstall/uninstall. The install-guards gate
> permission lifecycle cases cover permission merge, migration, and removal.
> Symlink unavailability is an explicit SKIP; failure logs are uploaded as
> `windows-native-smoke` artifacts.
> Adding the job does not itself constitute a successful hosted-run result;
> inspect the run for the commit being assessed.
>
> This bounded smoke is not a native full-suite or release qualification. Live
> Claude/Codex authentication, AppContainer reviewer launch, parallel reviewer
> sessions, detached Job Object recovery and stale-owner lock reclamation remain
> manual checks. Linux/WSL2 remains the release-sign-off platform. The historical
> 2026-09-02 10/0 acceptance is recorded in
> `docs/audits/windows-acceptance-2026-09-02.md`; later operational findings are
> recorded in `docs/audits/windows-gate-remediation-2026-09-23.md`.

## Support matrix

| Platform                         | Profile support      | Notes |
| -------------------------------- | -------------------- | ----- |
| Linux                            | **First-class**      | Full profile + minimal profile |
| WSL2                             | **First-class**      | Treated as Linux |
| macOS                            | **Not supported**    | Use a Linux host instead |
| Windows Git Bash (`msys2/mingw`) | **Experimental**     | Git Bash, jq, sqlite3, Developer Mode; local Claude/Codex use |
| Other / unrecognized             | **Not supported**    | Use Linux or WSL2 |

---

## Install

> **Repo path:** clone to any location you prefer. Set `PM_DISPATCH_REPO` to that
> path before running the commands below, or substitute it inline.
>
> ```bash
> export PM_DISPATCH_REPO="$HOME/src/pm-dispatch"   # or wherever you cloned it
> export PM_DISPATCH_REPOS_ROOT="$(dirname "$PM_DISPATCH_REPO")" # optional override for cross-repo operations
> ```

### Prerequisites

| Tool | Linux / WSL2 |
|------|--------------|
| bash ≥ 4 | system |
| jq ≥ 1.6 | `apt install jq` |
| git | system |
| sqlite3 (FTS5) | `apt install sqlite3` |
| codex CLI | optional (`full` profile) |
| `jsonschema` CLI (`apt install python3-jsonschema`) | tests only: `tests/shell/test-core-schemas.sh` skips its 64 validation cases without it (the run is then not an authoritative full pass); CI sets `PM_REQUIRE_JSONSCHEMA=1` so a missing CLI fails there |

> **`sqlite3`** is required by `pmctl context` (repo-index + FTS5 retrieval, v0.5.0+).
> Without it, `pmctl context index/query/pack/reuse-scan` exit with an error; the
> rest of pm-dispatch still works.

### Linux / WSL2

```bash
# 1. Clone
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"

# 2. Install managed files and wire Claude Code hooks into ~/.claude/settings.json
# (install.sh calls hosts/claude/bin/install-guards.sh internally; no separate step needed)
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

`install.sh` symlinks managed agents, commands, Adapters, helpers, and schema
assets into `~/.claude/`. It also installs receipt-owned Gate runtime/policy and
Adapter runtime/share/usage bundles needed when symlinks fall back to copies.
On symlink-capable hosts, updates to linked paths are reflected automatically;
re-run the installer when new entries are added.
It also symlinks `cli/pmctl` into `${PMCTL_BIN_DIR:-$HOME/.local/bin}/pmctl`;
if that bin directory is not already on PATH, the installer prints the exact
`export PATH=...` command to add.

### Windows Git Bash (experimental; prefer WSL2 for release sign-off)

> Native Windows Git Bash supports local Claude and Codex use when the
> prerequisites below are present. CI covers only the bounded smoke above;
> use WSL2 for a first-class or release workflow.

> **`pr-gate` and the full test suite on native Windows (not supported for sign-off).**
> A real `pmctl gate run` has completed on native Windows with the care described below, but the
> `pr-gate` test shards and the full suite do not finish in an ordinary session. Run the gate for
> sign-off and the full suite on Linux or WSL2, and say so when you could not:
>
> - **The `pr-gate` test shards do not finish in a normal session.** Every process spawn
>   costs tens of milliseconds on Windows, so each `pr-gate` case takes about 100-190 s
>   (far less on Linux) and the `pr-gate` shards of `tests/bin/run-all-tests.sh` run
>   for roughly 40 minutes. They pass at the default watchdog, but wall-clock time varies
>   by about ±40 %, and several long jobs at once have caused memory pressure that got a
>   background job killed. The rest of the suite (for example `test-pmctl-gate.sh`, whole,
>   in six shards) can be run natively; it takes 20+ minutes.
> - **A real `pmctl gate run` has completed natively, but only with care.** The recorded
>   end-to-end run (2026-10-03) reached GO on its fourth attempt; each earlier failure had a
>   different cause, all since fixed (BACKLOG CC-615 to CC-618). It still needs: a
>   *native* clone of `qa-testing-rules` named by `QA_RULES_DIR` in forward-slash form (a
>   `\\wsl.localhost\...` path is not readable by a reviewer sandbox, and without the
>   variable the `qa-tester` hard-blocks any behavior-changing diff); no drive-letter
>   `--run-dir`; waits of at most 570 s per `pmctl gate wait`; and a small subject, because
>   a diff that touches high-fan-out files can exceed the `qa-tester` helper's time budget.
>   Detached lifecycle also needs the integrated host described in `docs/host-contract.md`.
> - **Latest recorded run (2026-10-23, main `3de39a2`, CC-665).** A full-tier, sequential, codex-executor gate over a
>   four-file gate-library change reached `Final: GO` in about 13 minutes and `pmctl gate verify` passed; one run, so
>   treat it as an existence proof, not a timing guarantee. The gate log now shows
>   `pr-gate: scope manifest built in <N>s (changed paths=<M>)`. In single timed runs on this host the symbol expansion
>   (only `lib/`, `shared/` and shell files are expanded) took about 1 to 1.3 s per changed such file (66 s for 50 files
>   of a 640-file synthetic repository, 162 s for a 179-file diff of this repository); the suites below still cannot
>   run natively.
> - **A large diff can spend minutes in the scope manifest before any reviewer starts (#781).** One report: 127
>   changed paths took 495 s and ended `INCOMPLETE` (search-match and expansion-entry budgets exceeded). Since CC-697 a
>   run without `--accept-scope-truncation` stops scanning at the first exceeded budget and records
>   `truncation.scan_stopped_early` in the manifest, so the `INCOMPLETE` report arrives sooner; its omitted counts are
>   then lower bounds and its expansion list is partial. Rerunning with `--accept-scope-truncation` scans every source
>   again (the earlier manifest is not reused) and accepts whatever that full scan omits. For a diff of roughly 100
>   paths or more, expect that rerun to take 8 minutes or longer on native Windows.
> - **What CI proves on Windows** is only the bounded `windows-native-smoke` job above.
>
> #### Evidence boundary for native Windows
>
> | Shown so far | Not shown |
> |---|---|
> | The bounded `windows-native-smoke` CI job. | The full test suite passing natively (the state-root ACL check blocks most suites; the `pr-gate` shards take about 40 minutes). |
> | Several full-tier gates reaching `Final: GO` and one targeted NO-GO then GO, with `gate verify` passing (2026-10-23). | A gate over a real project's test suite: those runs changed 4 to 5 files with a `bash -n` pre-flight, and the `qa-tester` reviewer cannot run suites in the codex sandbox, so a GO is not a test pass. |
> | `pmctl worktree create --path` and the long-path warning, in unit tests. | `pmctl worktree remove` on a real deep `node_modules` tree through pmctl: the 2026-10-24 dogfood run failed there with `Filename too long` even at `C:\dogfood\w1`. CC-670 passes `core.longpaths=true` to git, which removes such a tree in a direct git reproduction (git 2.42 for Windows); it has not been re-run end to end through pmctl on a real pnpm tree. #720 is not confirmed by its reporter. |
> | Scope-manifest cost measured on a synthetic 640-file repository and on this repository (#621). | The reporter's private monorepo (#621, #620 sizes). |
> | The `printf` write error (#633) mitigated at the wrapper. | That error ever being reproduced, or confirmed gone by its reporter. |
>
> One live run on a public project exists, counted for time and human interventions:
> [`docs/notes/live-dogfood-2026-10-24-create-t3-turbo.md`](notes/live-dogfood-2026-10-24-create-t3-turbo.md)
> (CC-447 Requirement 2; template in
> [`live-dogfood-report-template.md`](notes/live-dogfood-report-template.md)). It reached a verified GO
> on a 141-file repository after 13 interventions and six tickets; it did not run `pmctl ship`, a clean
> install, or a repository of the #621 size.
>
> What to do instead: run `/pr-gate`, the full suite and release sign-off on Linux or WSL2.
> From a native checkout, `bash ops/diagnostics/run-tests-in-wsl.sh <suite>...` runs suites on
> the same working tree in WSL2. Natively, run focused suites one at a time in the foreground
> (`--filter`, with `PM_DISPATCH_TEST_PR_GATE_CASE_TIMEOUT_SECS=540` for `pr-gate` cases).
> When a change was verified without a gate, run the reviewer roles by hand as a *manual reviewer
> pass* ([`docs/review-model.md`](review-model.md#when-the-gate-cannot-run-manual-reviewer-pass)):
> it is a review, not a gate, leaves no gate artifact, and the PR description must say so (no
> gate artifact, no full-suite result, which reviewers ran, whether they were independent) and
> must not imply a gate GO.

```bash
# Prerequisites (run in PowerShell or terminal):
winget install jqlang.jq
winget install Git.Git          # provides Git Bash
winget install SQLite.SQLite
# Settings → Privacy & security → For developers → Developer Mode

# Then in Git Bash:
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"

bash install.sh
# Optional: wire the Codex command guard and memory hook into ~/.codex.
bash install.sh --enable-host codex
```

Add the repo CLI directory to PATH so `pmctl` can run in place:

```bash
export PATH="${PM_DISPATCH_REPO}/cli:$PATH"
```

> **jq line endings:** the `jqlang.jq` that winget installs is a native Windows
> program and writes `\r\n` instead of `\n` whenever its output goes to a pipe, a
> file or a command substitution, which corrupts multi-line values and changes the
> digests the gate computes. `runtime/lib/jq-lf.sh` defines a `jq` shell function
> that adds `jq -b` (`--binary`) on msys/cygwin (override with
> `PM_DISPATCH_JQ_LF=1|0`). `pmctl`, `pr-gate.sh` and the test harness load it;
> every other executable script that can call jq carries the same two lines
> inline (`tools/lint/lint-jq-lf.sh` enforces it). A `jq` run as a program
> (`timeout 5 jq`, `xargs jq`) bypasses it, so write `-b` there. Inside the shim
> `command -v jq` prints the word `jq`; use `type -P jq` for the program path.
> `doctor.sh` checks on native Windows that jq output is exactly LF
> (`jq-line-endings`). To exercise the shim on Linux, run a suite with
> `PM_DISPATCH_TEST_FORCE_JQ_LF=1` (what the `test-jq-lf-forced` CI job does); that
> needs a jq that accepts `-b`, which the Linux jq 1.6 of Ubuntu 22.04 does not.
> A gate artifact written on Windows before this fix can fail a digest check once;
> re-run the gate.

> **Running `pmctl` from PowerShell:** `cli/pmctl` is an extension-less bash
> script. Git Bash runs it directly; PowerShell resolves it with `Get-Command`
> but refuses to execute it (`Cannot run a document in the middle of a
> pipeline`). Invoke Git for Windows Bash explicitly from PowerShell; a bare
> `bash` may resolve to the Windows/WSL launcher. Add a function to your
> PowerShell `$PROFILE` — `@args` forwards
> arguments through PowerShell's own argv without a `cmd.exe` re-parse:
>
> ```powershell
> $env:PM_DISPATCH_REPO = 'C:\path\to\pm-dispatch'
> function pmctl {
>     $previousPath = $env:PATH
>     try {
>         $env:PATH = "C:\Program Files\Git\usr\bin;$env:PM_DISPATCH_REPO\cli;$previousPath"
>         & 'C:\Program Files\Git\bin\bash.exe' --noprofile --norc "$env:PM_DISPATCH_REPO/cli/pmctl" @args
>     } finally {
>         $env:PATH = $previousPath
>     }
> }
> ```
>
> Adjust both Git paths if Git for Windows is installed elsewhere. The temporary
> PATH prefix also lets nested `bash` and `pmctl` calls resolve correctly; the
> function restores the caller's PATH afterward. Use
> the explicit Git Bash executable: `Get-Command bash -All` can resolve the
> Windows/WSL launcher (`C:\Windows\System32\bash.exe`) first, which is a
> different runtime. This function is for the native Windows checkout.
> A `cmd`/batch shim was
> considered and rejected: `%*` forwarding is re-parsed by `cmd.exe`, so an
> argument carrying shell metacharacters could break out of the intended
> invocation. The native smoke tests Bash/PowerShell invocation, not a batch shim.

> **Gate-dispatch briefs on Windows (CC-589):** Codex reviewer and synthesis
> briefs automatically embed a Windows-safe invocation for their mandatory
> pre-write `pmctl guard check`: `& '<absolute-path-to-git-bash.exe>'
> '<path-to-pmctl>'`, pinning a concrete Git Bash executable (resolved from
> `$BASH` via `cygpath -w`) rather than a bare `bash` word, so PowerShell's
> PATH search cannot resolve it to WSL's own `bash` launcher instead (a
> different filesystem namespace that cannot run a Git-Bash-style POSIX
> path). If `$BASH` or `cygpath` is unavailable, it falls back to the bare
> `bash '<path-to-pmctl>'` form. Either way this is safe for Codex's
> non-interactive PowerShell subprocess, which does not load your `$PROFILE`
> and cannot run the extension-less bash script directly — no profile setup
> is needed for that gate-dispatch invocation. The `pmctl` function above
> remains for interactive/manual PowerShell use; it is intentionally a
> separate mechanism.
>
> For Claude reviewers on Windows, a gate run against the same source checkout
> uses `bash cli/pmctl guard check` instead of bare `pmctl`, because Claude's
> headless Bash tool may not inherit the checkout's `cli` PATH entry. The
> reviewer dispatch grants this command only for that session. A gate against
> modified guard-source files fails closed; use the Codex executor or a trusted
> checkout to review those changes.

> **Symlink support:** With Windows Developer Mode enabled, the installer
> automatically invokes Git Bash `ln` with `MSYS=winsymlinks:nativestrict`.
> This creates native Windows symlinks for individual helpers and receipt-owned
> runtime/assets. `install.sh` continues to use `powershell.exe New-Item
> -ItemType Junction` for the managed `agents/`, `commands/`, `skills/`,
> `adapters/`, and `pm-schema` directories so those paths auto-sync after
> pulling. Without Developer Mode, the post-create check fails safely and the
> installer falls back to receipt-owned copies.

> **Copy-mode installs (no dev-mode):** Helpers and runtime/assets are installed
> via copy on Git Bash. Re-run `bash install.sh` after pulling to refresh the
> receipt-owned snapshot — files use content SHA-256 and directories use a
> deterministic logical-tree digest, so only unchanged owned copies are refreshed.
> Legacy untagged directory receipts are refreshed only when their prior tar
> digest can still be verified exactly; otherwise install preserves the copy and
> reports a conflict for manual comparison.
> `install.sh` prints a summary banner listing how many files were installed or refreshed via copy.
> `pmctl` is the exception: it is never copied because a copied `pmctl` treats
> the copy location as its repo root and cannot find `runtime/lib/*.sh`.

#### Running the test suites from a Windows checkout

Every spawned process costs tens of milliseconds on native Windows, so a suite
that takes seconds on Linux takes minutes in Git Bash (`test-doctor.sh` and
`test-guards.sh` do not finish within a typical tool time limit). To verify the
logic of a change, run the suites in WSL2 from the same checkout, uncommitted
edits included:

```bash
bash ops/diagnostics/run-tests-in-wsl.sh test-doctor test-guards
```

The helper copies the working tree into a scratch directory inside WSL, restores
the executable bits NTFS does not carry, makes it a git repository on `main` (one
commit and an `origin/main`, in a directory named like your checkout), and prints one
row per suite with its exit status and time. It needs `jq`, `git`, `sqlite3`,
`tar` and `timeout` inside the WSL distribution, and runs the suites with the
ShellCheck version the repository pins first on `PATH`; install it once with
`bash tools/lint/bootstrap-shellcheck.sh` (a distribution package is usually older and
`test-release-verify` then reports NO-GO). Run that script inside WSL, not in Git
Bash, and the helper prints a reminder when the pinned version is missing. The
scratch repository's `origin` is the scratch repository itself, so a suite that
depends on a real remote proves nothing there. It does not replace native
verification: ACL, PowerShell, Job Object and path-conversion behavior only exist
natively, so those stay with `ops/diagnostics/windows-acceptance.sh` and the
`windows-native-smoke` CI job.

It is a developer aid, not a sandbox: it runs this checkout's own suites inside
your WSL distribution with your privileges and copies untracked files that are not
git-ignored, so use it on checkouts you trust. Each call spends a few seconds
syncing, so the gain is largest for big suites (`test-guards.sh` takes minutes in
Git Bash and about two minutes in WSL2) and modest for small ones. Each run uses its
own scratch tree, so concurrent calls are safe; it is removed after a passing run and
kept after a failing one (a failing suite prints its failed-case line and the path of
its full log inside WSL). `--changed` also runs the suites `tests/bin/run-tests.sh`
chooses for the paths your working tree changed; if one of them is widely used (for
example `tests/lib/test-suite-runner.sh`) it escalates to the whole suite, which does
not fit the default time limit, so raise `--timeout`.

#### Running the CI lints before you push

CI's lint steps are spread over many jobs in `.github/workflows/lint.yml`, and a lint
you did not run locally costs a CI round trip (and, with the PR gate, a new gate run).
One command runs the same steps:

```bash
bash ops/diagnostics/run-ci-lints.sh          # Linux or WSL2
bash ops/diagnostics/run-ci-lints.sh --wsl    # from native Windows: copies the tree into WSL first
```

It reads the steps from the workflow (every `run:` step that calls a script under
`tools/lint/` or the `pm/scripts` validators), so a step added to CI shows up by itself;
steps that only make sense on a runner (the GitHub token, `git fetch`) are listed as
skipped. It runs every step even after one fails, shows the tail of each failing step and
exits 1 if any failed. `--list` shows the steps, `--only TEXT` narrows them. The
regression suites of the linters are not part of it. From native Windows `--wsl` takes
about two to three minutes, almost all of it the ShellCheck lint.

#### Running one suite natively in Git Bash

Some behavior only exists natively, so you will sometimes run a suite there. Two
things to know:

- **A state-writing suite can fail on every case with `state-writer: unsafe state
  root rejected: ... (ACL grants write to a non-owner principal)`.** The check is
  correct: the suite's scratch directory lives under `%TEMP%`, and on some hosts
  `%TEMP%` grants Modify to another account (for example `CodexSandboxUsers`, which
  `[windows] sandbox = "elevated"` in `~/.codex/config.toml` creates), so the state
  root is writable by a principal that is not you. Give the suite a scratch directory
  nobody else can write to and point `TMPDIR` at it:

  ```bash
  mkdir -p "$HOME/pmd-clean-tmp"
  icacls "$(cygpath -w "$HOME/pmd-clean-tmp")" /inheritance:r \
    /grant:r "$USERNAME:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F"
  TMPDIR="$HOME/pmd-clean-tmp" bash tests/shell/test-state-layout-parity.sh
  ```

  (`*S-1-5-18` is SYSTEM and `*S-1-5-32-544` is Administrators, given as SIDs so the
  command also works on a localized Windows; verified in Git Bash. A domain account
  with the same name as a local one needs its SID too.) This is a workaround for the
  safety check, not a change to it. Do not use `PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT=1` to get past it; it turns the
  check off instead of fixing the directory. `pmctl` itself is unaffected: its state
  root is under your profile, not `%TEMP%`.
- **`pmctl gate run` can fail with `state-writer: unsafe state root rejected: ... (ACL grants write to a
  non-owner principal: <principal>, inherited)` on the default state directory.** The check is correct: the
  directory under your profile inherited a write grant for another account (for example `CodexSandboxUsers`,
  which `[windows] sandbox = "elevated"` in `~/.codex/config.toml` creates), so another principal could write
  your run state. The message names the first such principal and whether the grant is inherited or explicit
  (issue #778). Do not edit the ACL of the default directory or its parent unless you know nothing else needs
  that grant: the Codex sandbox may. Give `pmctl` a directory only you can write instead, and point
  `PM_DISPATCH_STATE_ROOT` at it (write it as a POSIX path, `/c/Users/...`):

  ```bash
  mkdir -p "$HOME/.pm-gate-state"
  icacls "$(cygpath -w "$HOME/.pm-gate-state")" /inheritance:r /grant:r "$USERNAME:(OI)(CI)F"
  export PM_DISPATCH_STATE_ROOT="$HOME/.pm-gate-state"
  ```

  `PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT=1` turns the check off; do not use it to get past this.
- **`PM_DISPATCH_STATE_ROOT` (and `XDG_DATA_HOME`) must be written as a POSIX path, `/c/Users/...`,
  not `C:/Users/...`.** The gate's run directory is derived from the state root and its supervisor
  refuses a drive-letter run directory. `pmctl gate run` checks the state root before it starts anything
  and exits 2 with a message that names the variable (issue #779); before that check it printed a gate id
  and the detached supervisor failed less than a second later, with the reason only in
  `supervisor-stdout.log`.
- **Cases that need symlinks, POSIX mode bits, `setsid` or `flock` skip with a
  reason** (`SKIP:` lines). Explicit `skip_platform` exclusions remain visible
  in the full result and are accepted for host-platform sign-off; unclassified
  skips and missing applicable dependencies still prevent an authoritative pass.
  Git Bash's `ln -s` makes a copy, `mkdir -m 700` and `chmod 000` have no effect,
  and those two programs are not installed. (Running as root has the same effect on
  the cases that need an unreadable file.) Those paths are covered in WSL2
  (`ops/diagnostics/run-tests-in-wsl.sh`). Do not `export LC_ALL=C.UTF-8` for a
  native run: Git for Windows' grep and gawk mishandle 4-byte emoji under a UTF-8
  locale (CC-641), and a plain Git Bash does not set it.
- **Run it the way CI does at least once.** The scratch directory above is a long
  `/c/Users/...` path, so it never exercises the spellings CI sees: there `TMPDIR` and
  `HOME` sit under `/tmp`, which is a mount alias of `C:/Users/<NAME>~1/AppData/Local/Temp`
  (an 8.3 short user directory). A change to how paths are compared or stored (manifest
  keys, partition keys, managed-root checks) passed every suite with the long-name
  scratch directory and failed `windows-native-smoke` (CC-642). Re-run with
  `TMPDIR=/tmp` for anything that touches path spelling (for the install lifecycle case,
  `TMPDIR=/tmp bash tests/shell/test-install.sh --filter copy-install-receipt-lifecycle`,
  no `icacls` step was needed; suites that write the pmctl state root still need the
  clean directory above).
- **A repository path that itself contains `[`, `*` or `?` is not supported natively.**
  MSYS only converts a path argument to the native form when it looks like a plain path;
  with a glob character in it `git -C /c/Users/x/repo[1]` reaches git unchanged and fails
  with `cannot change to`. The failure is immediate and nothing is modified (measured,
  CC-641); the state directory may contain such characters (`pmctl worktree` handles
  them), the repository may not.

### Driving WSL2 from a native Windows session

When the repository, `pmctl` and the gate live in WSL2 (the supported setup for release sign-off) and the
session you type in is on Windows, three things go wrong in practice. Each has a standard answer.

- **Do not put multi-line or quoted text inside `wsl.exe -e bash -lc '...'`.** The text passes through the Windows
  command line, Git Bash's argument rewriting and WSL's bash, and does not survive: an apostrophe ends the string
  (`unexpected EOF`), a heredoc loses its backslashes, `\n` becomes a real newline, `$` is expanded by the wrong
  shell. Write the commands to a file and run the file. `ops/diagnostics/wsl-run.sh` does the translation:

  ```bash
  bash ops/diagnostics/wsl-run.sh [--cd <wsl-dir>] script <file> [args...]   # run a file with bash -l, args kept whole
  bash ops/diagnostics/wsl-run.sh [--cd <wsl-dir>] pmctl gate status <id> --cd /home/me/repo   # pmctl, args kept whole
  ```

  The script's Windows path (an 8.3 short one such as `C:\Users\LIENCH~1\...` included) is translated with
  `wslpath`, a script with CRLF line endings is refused by name, and the command's own exit status is the helper's.
  `--pmctl-command <cmd>` runs a different program in `pmctl` mode (a WSL path, or a name on its PATH).
- **Edit files where the repository lives.** A repository cloned inside WSL (under its own home directory) is edited from WSL. A
  Windows tool that edits `\\wsl.localhost\...` must read before it writes and disagrees with WSL's git about what
  is dirty. Use Windows only to send commands and read results; keep the Windows checkout and the WSL checkout in
  step through git, never by editing the same file from both sides.
- **Permission prompts match a command's prefix.** A rule such as `Bash(pmctl:*)` matches only a command that starts
  with `pmctl`; a variable assignment, `command -v`, a subshell or a leading `cd ... &&` makes every call a manual
  approval. Call `pmctl ...` bare, and from native Windows call `bash ops/diagnostics/wsl-run.sh pmctl ...`. Rules
  worth allowing in advance: `Bash(pmctl:*)` and `Bash(bash ops/diagnostics/wsl-run.sh pmctl:*)`. Do not allow
  `wsl-run.sh script` in advance: it runs whatever file it is given.

### The PR gate on native Windows (measured 2026-11-11)

`pmctl gate run` runs to a verdict in native Git Bash. On one machine (Windows 11, Git for Windows 2.42, bash 5.2,
codex-cli 0.165.0, jq 1.8.1 from winget) a `full`-tier, parallel, five-reviewer gate on this repository took about
17 minutes from launch to result, `gate result` and `gate verify` read it, and verify reported all three axes. Five
gate runs on one branch produced three NO-GO reviews with real findings, one refusal before review (a targeted pass
below the policy floor, see [review-model.md](review-model.md)) and one GO whose `subject_current` axis was `pass`.
It remains **experimental**: the native run needs the setup below, and it is not release sign-off.

- A state root only you can write, as a POSIX path: `export PM_DISPATCH_STATE_ROOT="$HOME/.pm-gate-state"` after the
  `icacls` step in the list above. Without it the first command stops with `unsafe state root rejected`.
- Reviewers launched by `--executor codex` use the codex CLI on PATH; the reviewer is never switched. To make that a
  rule rather than a habit, put `gate.reviewer_executor = codex` in `~/.pm-dispatch/config`: a different
  `--executor` is then refused.
- A quota that is used up shows as `executor quota exhausted: <the executor's line, with its reset time>` and the
  gate stops without a retry; rerun it unchanged after the reset.
- `pmctl gate wait` can return `indeterminate: sentinel key absent` (exit 3) when the per-user sentinel key is gone.
  That is a statement about authentication, not about the run: `pmctl gate result <gate-id>` prints the published
  result with the three verify axes, and `pmctl gate verify <result-file> --cd <repo>` decides whether to trust it.
- Before a gate, `pmctl gate mutations --preview` lists the test files the change touches and the mutation classes
  qa-tester asks of each test.

### Native Windows test status (Git Bash, measured 2026-11-11)

Run with a scratch directory only you can write (`TMPDIR`, see above). Of 125 `tests/shell` scripts, 85 passed in
the first full run with a 240 s limit per script; the rest fall into these groups. What is listed as skipped is
skipped with a stated reason, not silently.

- **Skipped on purpose (capability).** Real symlinks, POSIX mode bits and enforced permissions, file names with a
  quote, backslash or newline, and a PATH built from links to the real tools (native Git Bash's `ln -s` copies the
  `.exe` without its DLLs, which then fails to load). The cases use the `th_require_*` probes in
  `tests/lib/test-harness.sh`; they run in WSL2.
- **Slow, not wrong.** Process starts cost tens of milliseconds, so these exceed 240 s and some 600 s here:
  `test-dispatch-cancel`, `test-dispatch-lifecycle`, `test-doctor`, `test-gate-lifecycle` and `test-guards` as whole
  files, `test-host-write-codex`, `test-install`, `test-pmctl-context`, `test-pmctl-dispatch`, `test-pmctl-gate`,
  `test-pmctl-ship`, `test-pmctl-task`, `test-state-store`, the `test-pr-gate*` files and
  `test-script-domain-inventory`. Run them with `ops/diagnostics/run-tests-in-wsl.sh`, or by `--filter` natively.
- **Fixed in this tree.** `grep -Fi` aborts with a core dump in the GNU grep 3.0 of some Git for Windows installs
  (two tests used it); a hook that read its payload from `/dev/stdin` failed on every prompt when a Windows host
  piped it in; several assertions compared the POSIX spelling of a path (`/c/Users/...`) with the `C:/Users/...` form
  the product records.
- **Open (native Windows only; cause not fixed).** `test-pmctl-memory` resolve/config/stats cases (the memory
  directory is reported `unavailable`), `test-pmctl-pm` `prepare` and `run` cases, and two `test-pmctl-ship-finish`
  assessment cases fail natively but pass in WSL2 (measured 2026-11-11), so they are specific to native Windows. The
  likely cause is path spelling (`C:/...` versus `/c/...`) in the tests' expectations or in the project key; that is
  unconfirmed. Treat WSL2 as the reference result for these files.

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

### Linux / WSL2

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

Pull and agents/commands/skills/adapters auto-sync via junction. With Developer
Mode, individual helpers, the Gate shared runtime/policy, and Adapter
bootstrap/share/usage assets are native symlinks and update with the checkout.
Without it, those paths are receipt-owned copies; re-run `install.sh` to refresh
them. Foreign or locally modified load-bearing paths fail closed instead of
being used:

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
bash "${PM_DISPATCH_REPO}/hosts/claude/bin/uninstall-guards.sh"
# or with preview:
bash "${PM_DISPATCH_REPO}/hosts/claude/bin/uninstall-guards.sh" --dry-run
```

### Part 2 — remove managed files from ~/.claude

Removes receipt-owned agents, commands, skills, Adapters, share assets, Gate
and Adapter runtime bundles, usage support, helper scripts, and the `.pm`
schema. It also removes `~/.local/bin/pmctl` only when that path is a symlink to
this checkout's `cli/pmctl`; foreign files or symlinks are preserved. Run after
Part 1.

**Recommended:** Use the manifest-driven uninstaller on Linux/WSL2:

```bash
bash "${PM_DISPATCH_REPO}/uninstall.sh"
# or preview what will be removed:
bash "${PM_DISPATCH_REPO}/uninstall.sh" --dry-run
```

**Legacy alternative: manual removal (Linux/WSL2)**

The list below is only for legacy link-only installs. Current installs also own
`scripts/lib`, `scripts/core/policy`, `runtime/lib`, and `ops/usage` through the
receipt; use `uninstall.sh` so those bundles are hash-checked and empty parent
directories are pruned without deleting foreign content.

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

# pmctl CLI symlink (Linux/WSL2 only)
if [ "$(readlink ~/.local/bin/pmctl 2>/dev/null)" = "${PM_DISPATCH_REPO}/cli/pmctl" ]; then
  rm -f ~/.local/bin/pmctl
fi
```

---

## Quickstarts

### WSL2

```bash
sudo apt update && sudo apt install -y jq
git clone https://github.com/screenleon/pm-dispatch "${PM_DISPATCH_REPO}"
cd "${PM_DISPATCH_REPO}"
bash install.sh
```

---

## Repository references

- `README.md` — overview and quick install
- `CONCEPTS.md` — architecture concepts
- `runtime/lib/portable.sh` — `link_or_copy()` and install manifest
- `hosts/claude/bin/install-guards.sh` — hook wiring
- `hosts/claude/bin/uninstall-guards.sh` — hook removal
- `docs/platform-support.md` (this document)
