#!/usr/bin/env bash
# Run a script file, or a pmctl command, inside WSL2 from a native-Windows Git Bash or PowerShell session.
#
# Why: `wsl.exe -e bash -lc '<text>'` passes the text through the Windows command line, the Git Bash argument
# rewriting and WSL's bash, and the text does not survive it: an apostrophe ends the string, a heredoc loses its
# backslashes, `\n` becomes a real newline, `$` is expanded by the wrong shell. Anything longer than one plain
# command is safer as a file, and a file is what this helper runs: it translates the Windows path of the script to
# the WSL path (`/mnt/c/...`, short 8.3 names such as C:\Users\LIENCH~1 included) and runs it with bash, so the
# text is never re-quoted.
#
# Usage:
#   ops/diagnostics/wsl-run.sh [--distro NAME] [--cd <wsl-dir>] script <file> [args...]
#   ops/diagnostics/wsl-run.sh [--distro NAME] [--cd <wsl-dir>] pmctl <pmctl args...>
#
#   script <file>   run <file> (a Windows or POSIX path of a file on this machine) with `bash -l`
#   pmctl <args>    run the pmctl on the WSL PATH, with plain arguments (no shell text; each is passed as is)
#   --cd <dir>      working directory inside WSL (default: the WSL home directory)
#   --distro NAME   WSL distribution (default: the default one)
#
# Edit files where the repository lives. A repository cloned in WSL (~/github/...) is edited from WSL; a Windows
# tool editing \\wsl.localhost\... has to read before it writes and disagrees with WSL's git about the state. Use
# this helper to send commands and read results, not to edit across the boundary.
#
# Exit status: the script's or pmctl's own, or 2 for a usage error, 3 when WSL cannot be reached.
set -euo pipefail

die() { printf 'wsl-run: %s\n' "$*" >&2; exit "${2:-2}"; }

distro="" wdir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --distro) [[ $# -ge 2 && -n "$2" ]] || die "--distro needs a name"; distro="$2"; shift 2 ;;
    --cd)     [[ $# -ge 2 && -n "$2" ]] || die "--cd needs a WSL directory"; wdir="$2"; shift 2 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) break ;;
  esac
done
[[ $# -ge 1 ]] || die "usage: wsl-run.sh [--distro NAME] [--cd <wsl-dir>] script <file> [args...] | pmctl <args...>"
mode="$1"; shift
# Usage errors and unreadable input come first, so they are reported the same on a host without WSL.
need_wsl() { command -v wsl.exe >/dev/null 2>&1 || die "wsl.exe not found; install WSL2 first" 3; }

# MSYS rewrites anything that looks like a path in a native program's argument; turn that off for wsl.exe.
wsl() {
  if [[ -n "$distro" ]]; then
    MSYS2_ARG_CONV_EXCL='*' wsl.exe -d "$distro" "$@"
  else
    MSYS2_ARG_CONV_EXCL='*' wsl.exe "$@"
  fi
}

# `--cd` goes to wsl.exe itself: it changes directory before starting the command, with no shell text involved.
cd_args=()
[[ -z "$wdir" ]] || cd_args=(--cd "$wdir")

case "$mode" in
  script)
    [[ $# -ge 1 ]] || die "script needs a file"
    file="$1"; shift
    [[ -f "$file" ]] || die "no such file: $file"
    # The file's own bytes are what runs; a CRLF copy of a script (autocrlf) would not, so refuse it by name.
    # (grep is no test for this: Git Bash's grep drops a line's trailing CR before it matches.)
    if ! tr -d '\r' < "$file" | cmp -s - "$file"; then
      die "$file has CRLF line endings; bash would read them as part of the commands (write it with LF)"
    fi
    need_wsl
    if command -v cygpath >/dev/null 2>&1; then
      win_path="$(cygpath -w "$file")"
    else
      win_path="$file"
    fi
    wsl_path="$(wsl -e wslpath -a -u "$win_path" | tr -d '\r')" || die "wslpath could not translate $win_path" 3
    [[ -n "$wsl_path" ]] || die "wslpath returned nothing for $win_path" 3
    wsl "${cd_args[@]}" -e bash -l "$wsl_path" "$@"
    ;;
  pmctl)
    [[ $# -ge 1 ]] || die "pmctl needs arguments"
    need_wsl
    # `bash -lc 'pmctl "$@"' _ args...` keeps each argument whole; the only shell text is this fixed line.
    wsl "${cd_args[@]}" -e bash -lc 'pmctl "$@"' _ "$@"
    ;;
  *) die "unknown mode: $mode (expected script or pmctl)" ;;
esac
