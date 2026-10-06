#!/usr/bin/env bash
# Run test suites inside WSL2 from a native-Windows Git Bash checkout.
#
# Why: on native Windows every spawned process costs tens of milliseconds, so a
# suite that takes seconds on Linux takes minutes here (test-doctor.sh and
# test-guards.sh do not finish in a tool's time limit). WSL2 is the project's
# release-sign-off platform (docs/platform-support.md), and it gives the Linux
# result for the same working tree, uncommitted edits included.
#
# What it does: copies the tracked and untracked-but-not-ignored files of this
# checkout into a scratch directory in WSL, makes it a git repository (several
# suites need one), restores the executable bits that NTFS does not carry, then
# runs each named suite with a time limit and prints one row per suite.
#
# It does NOT replace native-Windows verification: ACL, PowerShell, Job Object
# and path-conversion behavior only exist natively. Use it for the logic of a
# change, and keep the native smoke (ops/diagnostics/windows-acceptance.sh and
# the windows-native-smoke CI job) for the Windows-specific part.
#
# Usage:
#   ops/diagnostics/run-tests-in-wsl.sh [--distro NAME] [--timeout SECS]
#                                       [--sync-only] <suite>...
#
#   <suite>   test-foo, test-foo.sh or tests/shell/test-foo.sh
#   --timeout per-suite limit in seconds (default 280)
#   --distro  WSL distribution (default: the default distribution)
#   --sync-only  copy the tree and stop
#
# Exit: 0 every suite passed, 1 a suite failed or timed out, 2 usage or
# environment error.
# shellcheck disable=SC2016  # the bash -c programs run inside WSL, where $1 and friends expand
set -euo pipefail

self="$(basename "$0")"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

usage() {
  printf 'usage: %s [--distro NAME] [--timeout SECS] [--sync-only] <suite>...\n' "$self" >&2
}

die() {
  printf '%s: %s\n' "$self" "$1" >&2
  exit 2
}

distro=""
timeout_secs=280
sync_only=0
suites=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --distro)
      [[ $# -ge 2 && -n "${2:-}" ]] || { usage; exit 2; }
      distro="$2"; shift 2 ;;
    --timeout)
      [[ $# -ge 2 && "${2:-}" =~ ^[0-9]+$ && "$2" -gt 0 ]] || { usage; exit 2; }
      timeout_secs="$2"; shift 2 ;;
    --sync-only) sync_only=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; exit 2 ;;
    *) suites+=("$1"); shift ;;
  esac
done
[[ "$sync_only" -eq 1 || "${#suites[@]}" -gt 0 ]] || { usage; exit 2; }

case "${OSTYPE:-}" in
  msys*|cygwin*) ;;
  *) die "this helper is for native-Windows Git Bash; on Linux or WSL2 run the suites directly" ;;
esac
command -v wsl.exe >/dev/null 2>&1 || die "wsl.exe not found; install WSL2 first"

# wsl_run <command...>: run a command in WSL. wsl.exe is a native Windows
# program, so Git Bash would rewrite an argument that looks like a POSIX path
# (/home/...) into C:/Program Files/Git/home/... on its way in; the exclusion is
# set for this one command only (never export it: git is a native program too).
wsl_run() {
  if [[ -n "$distro" ]]; then
    MSYS2_ARG_CONV_EXCL='*' wsl.exe -d "$distro" -e "$@"
  else
    MSYS2_ARG_CONV_EXCL='*' wsl.exe -e "$@"
  fi
}

# Suite names become paths inside WSL: accept only plain file stems.
normalize_suite() {
  local s="$1"
  s="${s#tests/shell/}"
  s="${s%.sh}"
  [[ "$s" =~ ^test-[A-Za-z0-9._-]+$ ]] || die "not a test suite name: $1"
  [[ -f "$repo_root/tests/shell/$s.sh" ]] || die "no such suite: tests/shell/$s.sh"
  printf '%s\n' "$s"
}
normalized=()
for s in ${suites[@]+"${suites[@]}"}; do
  normalized+=("$(normalize_suite "$s")")
done

missing="$(wsl_run bash -c 'for t in jq git sqlite3 tar timeout; do command -v "$t" >/dev/null 2>&1 || printf "%s " "$t"; done' 2>/dev/null | tr -d '\0')" \
  || die "cannot start WSL${distro:+ distribution $distro}"
[[ -z "$missing" ]] || die "missing in WSL: $missing(install them there, for example apt install jq git sqlite3)"

scratch_name="pm-dispatch-wsl-tests/$(basename "$repo_root")"
scratch="$(wsl_run bash -c 'printf "%s" "$HOME"' | tr -d '\0')/.cache/$scratch_name"
[[ "$scratch" == /* && "$scratch" == */.cache/pm-dispatch-wsl-tests/* ]] || die "unexpected scratch path: $scratch"

started=$SECONDS
printf '%s: syncing %s to WSL:%s\n' "$self" "$repo_root" "$scratch" >&2

# Files that exist in the working tree: tracked (minus deleted) plus untracked
# and not ignored.
file_list="$(mktemp)"
exec_list="$(mktemp)"
trap 'rm -f "$file_list" "$exec_list"' EXIT
(
  cd "$repo_root"
  # One git call for the index modes, never one per file: a process spawn costs
  # tens of milliseconds on native Windows.
  declare -A index_mode=()
  while IFS= read -r -d '' rec; do
    index_mode["${rec#*$'\t'}"]="${rec%% *}"
  done < <(git ls-files -s -z)
  while IFS= read -r -d '' f; do
    [[ -e "$f" ]] || continue
    printf '%s\0' "$f" >&3
    if [[ -f "$f" && ! -L "$f" ]]; then
      mode="${index_mode[$f]:-}"
      if [[ "$mode" == 100755 ]]; then
        printf '%s\n' "$f" >&4
      elif [[ -z "$mode" ]]; then
        first=""
        IFS= read -r first < "$f" || true
        [[ "$first" == '#!'* ]] && printf '%s\n' "$f" >&4
      fi
    fi
  done < <(git ls-files -z --cached --others --exclude-standard)
) 3> "$file_list" 4> "$exec_list"

(cd "$repo_root" && tar --null -T "$file_list" -cf -) \
  | wsl_run bash -c 'set -e; d="$1"; rm -rf "$d"; mkdir -p "$d"; tar -x -C "$d"' _ "$scratch"

# NTFS carries no mode bits, so the archive makes every file executable. Clear
# them all first, then set only the real ones: the committed modes are part of
# what some suites and lints check (lint-jq-lf treats mode 100755 as "entry").
wsl_run bash -c 'cd "$1" && find . -type f -not -path "./.git/*" -exec chmod 644 {} +' _ "$scratch"
if [[ -s "$exec_list" ]]; then
  wsl_run bash -c 'cd "$1" && xargs -d "\n" chmod 755' _ "$scratch" < "$exec_list"
fi
wsl_run bash -c 'cd "$1" && git init -q && git add -A \
  && git -c user.name=pm-dispatch -c user.email=pm-dispatch@localhost commit -q -m "wsl test sync"' _ "$scratch"
printf '%s: synced in %ss\n' "$self" "$((SECONDS - started))" >&2
[[ "$sync_only" -eq 0 ]] || exit 0

failures=0
printf '%-36s %5s %6s  %s\n' suite rc secs summary
for s in "${normalized[@]}"; do
  t0=$SECONDS
  # The suite's own exit status is reported from inside WSL on a marker line,
  # because the pipe through tail would otherwise hide it.
  out="$(wsl_run bash -c 'cd "$1" && export LC_ALL=C.UTF-8
    log="$(mktemp)"; timeout "$3" bash "tests/shell/$2.sh" > "$log" 2>&1; rc=$?
    tail -n 3 "$log"; rm -f "$log"; printf "__rc=%s\n" "$rc"' _ "$scratch" "$s" "$timeout_secs" \
    | tr -d '\0')" || out="__rc=125"
  rc="${out##*__rc=}"
  rc="${rc//[^0-9]/}"
  [[ -n "$rc" ]] || rc=125
  last="$(printf '%s\n' "$out" | grep -E '[0-9]+ passed, [0-9]+ failed' | tail -n 1 || true)"
  if [[ "$rc" -eq 124 ]]; then
    last="timed out after ${timeout_secs}s"
  elif [[ -z "$last" ]]; then
    last="no summary line (suite crashed or WSL failed)"
  fi
  [[ "$rc" -eq 0 ]] || failures=$((failures + 1))
  printf '%-36s %5s %6s  %s\n' "$s" "$rc" "$((SECONDS - t0))" "$last"
done
[[ "$failures" -eq 0 ]] || exit 1
