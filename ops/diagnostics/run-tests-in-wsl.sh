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
# suites need one, but it has no history), clears the mode bits NTFS fakes and
# restores the real executable bits, then runs each named suite with a time limit
# and prints one row per suite. Each call also pays a sync of a few seconds.
#
# It does NOT replace native-Windows verification: ACL, PowerShell, Job Object
# and path-conversion behavior only exist natively. Use it for the logic of a
# change, and keep the native smoke (ops/diagnostics/windows-acceptance.sh and
# the windows-native-smoke CI job) for the Windows-specific part.
#
# It is not a sandbox: it runs this checkout's own test suites inside your WSL
# distribution with your privileges, and it copies untracked files that are not
# git-ignored. Use it on checkouts you trust. The scratch tree stays in
# ~/.cache/pm-dispatch-wsl-tests/ (mode 700) until the next sync replaces it.
# One run per checkout at a time.
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
# Rows: suite, exit status, seconds, the suite's summary line. A failing suite
# also prints its failed-case line and the path of its full log inside WSL.
# A suite that exits 0 but prints no summary line (some suites do not) is shown
# as such and still counts as passed: the exit status is what decides.
#
# Exit: 0 every suite passed, 1 a suite failed or timed out, 2 usage or
# environment error.

# shellcheck disable=SC2016  # the bash -c programs run inside WSL, where $1 and friends expand

# Path of this file and of the checkout it belongs to; the functions below use
# them so the file can also be sourced (the regression suite does that).
RTW_SELF="$(basename "${BASH_SOURCE[0]}")"
RTW_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rtw_usage() {
  printf 'usage: %s [--distro NAME] [--timeout SECS] [--sync-only] <suite>...\n' "$RTW_SELF" >&2
}

# rtw_help: usage line, then this file's header comment.
rtw_help() {
  local line first=1
  printf 'usage: %s [--distro NAME] [--timeout SECS] [--sync-only] <suite>...\n' "$RTW_SELF"
  while IFS= read -r line; do
    if [[ "$first" -eq 1 ]]; then first=0; continue; fi
    [[ "$line" == '#'* ]] || break
    line="${line#\#}"
    printf '%s\n' "${line# }"
  done < "${BASH_SOURCE[0]}"
}

rtw_die() {
  printf '%s: %s\n' "$RTW_SELF" "$1" >&2
  exit 2
}

# rtw_normalize_suite <name>: print the suite stem (test-foo) or say why not and
# return 1. Suite names become paths inside WSL, so only plain file stems pass.
rtw_normalize_suite() {
  local s="$1"
  s="${s#tests/shell/}"
  s="${s%.sh}"
  if [[ ! "$s" =~ ^test-[A-Za-z0-9._-]+$ ]]; then
    printf '%s: not a test suite name: %s\n' "$RTW_SELF" "$1" >&2
    return 1
  fi
  if [[ ! -f "$RTW_REPO_ROOT/tests/shell/$s.sh" ]]; then
    printf '%s: no such suite: tests/shell/%s.sh\n' "$RTW_SELF" "$s" >&2
    return 1
  fi
  printf '%s\n' "$s"
}

# rtw_build_lists <repo-root> <file-list-out> <exec-list-out>
# Write two NUL-separated lists of repo-relative paths: the files to copy (tracked
# and untracked-but-not-ignored, minus files deleted from the working tree) and
# the subset that must be executable (the index mode for tracked files, the
# shebang for untracked ones; a file staged with mode 100644 stays 100644, as git
# itself would commit it). One git call for the modes, never one per file: a
# process spawn costs tens of milliseconds on native Windows.
rtw_build_lists() {
  local root="$1" file_list="$2" exec_list="$3"
  (
    cd "$root" || exit 1
    declare -A index_mode=()
    local rec f mode first
    while IFS= read -r -d '' rec; do
      index_mode["${rec#*$'\t'}"]="${rec%% *}"
    done < <(git ls-files -s -z)
    while IFS= read -r -d '' f; do
      [[ -e "$f" ]] || continue
      printf '%s\0' "$f" >&3
      if [[ -f "$f" && ! -L "$f" ]]; then
        mode="${index_mode[$f]:-}"
        if [[ "$mode" == 100755 ]]; then
          printf '%s\0' "$f" >&4
        elif [[ -z "$mode" ]]; then
          first=""
          IFS= read -r first < "$f" 2>/dev/null || true
          if [[ "$first" == '#!'* ]]; then printf '%s\0' "$f" >&4; fi
        fi
      fi
    done < <(git ls-files -z --cached --others --exclude-standard)
  ) 3> "$file_list" 4> "$exec_list"
}

# rtw_parse_result <text>: read the marker lines the WSL program prints
# (__rc=, __summary=, __failed=, __log=; a marker counts only at the start of a
# line, the last one wins) into RTW_RC, RTW_SUMMARY, RTW_FAILED and RTW_LOG.
# No __rc marker, or a non-numeric one, is 125: WSL itself failed.
rtw_parse_result() {
  local line
  RTW_RC=""; RTW_SUMMARY=""; RTW_FAILED=""; RTW_LOG=""
  while IFS= read -r line; do
    case "$line" in
      __rc=*) RTW_RC="${line#__rc=}" ;;
      __summary=*) RTW_SUMMARY="${line#__summary=}" ;;
      __failed=*) RTW_FAILED="${line#__failed=}" ;;
      __log=*) RTW_LOG="${line#__log=}" ;;
    esac
  done <<< "$1"
  RTW_RC="${RTW_RC//[^0-9]/}"
  [[ -n "$RTW_RC" ]] || RTW_RC=125
}

rtw_main() {
  set -euo pipefail
  local distro="" timeout_secs=280 sync_only=0 s
  local -a suites=() normalized=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --distro)
        [[ $# -ge 2 && -n "${2:-}" ]] || { rtw_usage; exit 2; }
        distro="$2"; shift 2 ;;
      --timeout)
        [[ $# -ge 2 && "${2:-}" =~ ^[0-9]+$ && "$2" -gt 0 ]] || { rtw_usage; exit 2; }
        timeout_secs="$((10#$2))"; shift 2 ;;
      --sync-only) sync_only=1; shift ;;
      -h|--help) rtw_help; exit 0 ;;
      -*) rtw_usage; exit 2 ;;
      *) suites+=("$1"); shift ;;
    esac
  done
  [[ "$sync_only" -eq 1 || "${#suites[@]}" -gt 0 ]] || { rtw_usage; exit 2; }

  case "${OSTYPE:-}" in
    msys*|cygwin*) ;;
    *) rtw_die "this helper is for native-Windows Git Bash; on Linux or WSL2 run the suites directly" ;;
  esac
  command -v wsl.exe >/dev/null 2>&1 || rtw_die "wsl.exe not found; install WSL2 first"

  # wsl_run <command...>: run a command in WSL. wsl.exe is a native Windows
  # program, so Git Bash would rewrite an argument that looks like a POSIX path
  # (/home/...) into C:/Program Files/Git/home/... on its way in; the exclusion
  # is set for this one command only (never export it: git is a native program too).
  wsl_run() {
    if [[ -n "$distro" ]]; then
      MSYS2_ARG_CONV_EXCL='*' wsl.exe -d "$distro" -e "$@"
    else
      MSYS2_ARG_CONV_EXCL='*' wsl.exe -e "$@"
    fi
  }

  for s in ${suites[@]+"${suites[@]}"}; do
    normalized+=("$(rtw_normalize_suite "$s")") || exit 2
  done

  local missing home scratch_key scratch
  missing="$(wsl_run bash -c 'for t in jq git sqlite3 tar timeout; do command -v "$t" >/dev/null 2>&1 || printf "%s " "$t"; done' 2>/dev/null | tr -d '\0')" \
    || rtw_die "cannot start WSL${distro:+ distribution $distro}"
  [[ -z "$missing" ]] || rtw_die "missing in WSL: $missing(install them there, for example apt install jq git sqlite3)"

  home="$(wsl_run bash -c 'printf "%s" "$HOME"' | tr -d '\0')" || rtw_die "cannot read \$HOME in WSL"
  [[ "$home" == /?* ]] || rtw_die "unexpected \$HOME in WSL: '$home'"
  # One scratch tree per checkout: the base name plus a checksum of the path, so
  # two checkouts with the same name do not replace each other's tree.
  scratch_key="$(basename "$RTW_REPO_ROOT")-$(printf '%s' "$RTW_REPO_ROOT" | cksum | cut -d' ' -f1)"
  scratch="$home/.cache/pm-dispatch-wsl-tests/$scratch_key"
  [[ "$scratch" == "$home"/.cache/pm-dispatch-wsl-tests/?* && "$scratch" != *..* ]] \
    || rtw_die "unexpected scratch path: $scratch"

  local started=$SECONDS file_list exec_list
  printf '%s: syncing %s to WSL:%s\n' "$RTW_SELF" "$RTW_REPO_ROOT" "$scratch" >&2
  file_list="$(mktemp)"
  exec_list="$(mktemp)"
  # shellcheck disable=SC2064  # the two paths are fixed here, expand now
  trap "rm -f '$file_list' '$exec_list'" EXIT
  rtw_build_lists "$RTW_REPO_ROOT" "$file_list" "$exec_list" || rtw_die "sync failed: cannot list the working tree"

  # The path is checked again inside WSL before anything is removed.
  (cd "$RTW_REPO_ROOT" && tar --null -T "$file_list" -cf -) \
    | wsl_run bash -c 'set -e
        d="$1"; h="$2"
        case "$d" in "$h"/.cache/pm-dispatch-wsl-tests/?*) ;; *) echo "refusing scratch path: $d" >&2; exit 2 ;; esac
        mkdir -p "$h/.cache/pm-dispatch-wsl-tests"
        chmod 700 "$h/.cache/pm-dispatch-wsl-tests"
        rm -rf "$d"; mkdir -p "$d"; tar -x -C "$d"' _ "$scratch" "$home" \
    || rtw_die "sync failed: copying the working tree into WSL"

  # NTFS carries no mode bits, so the archive makes every file executable. Clear
  # them all first, then set only the real ones: the committed modes are part of
  # what some suites and lints check (lint-jq-lf treats mode 100755 as "entry").
  wsl_run bash -c '[ -n "$1" ] && cd "$1" && find . -type f -not -path "./.git/*" -exec chmod 644 {} +' _ "$scratch" \
    || rtw_die "sync failed: clearing mode bits"
  if [[ -s "$exec_list" ]]; then
    wsl_run bash -c '[ -n "$1" ] && cd "$1" && xargs -0 chmod 755 --' _ "$scratch" < "$exec_list" \
      || rtw_die "sync failed: restoring executable bits"
  fi
  wsl_run bash -c '[ -n "$1" ] && cd "$1" && git init -q && git add -A \
    && git -c user.name=pm-dispatch -c user.email=pm-dispatch@localhost -c commit.gpgsign=false -c core.hooksPath=/dev/null \
       commit -q -m "wsl test sync"' _ "$scratch" \
    || rtw_die "sync failed: initializing the scratch repository"
  printf '%s: synced in %ss\n' "$RTW_SELF" "$((SECONDS - started))" >&2
  [[ "$sync_only" -eq 0 ]] || exit 0

  local failures=0 t0 out
  printf '%-36s %5s %6s  %s\n' suite rc secs summary
  for s in "${normalized[@]}"; do
    t0=$SECONDS
    # The suite's own exit status and its summary lines are reported from inside
    # WSL as marker lines; the full log stays in the scratch tree.
    out="$(wsl_run bash -c '[ -n "$1" ] && cd "$1" || exit 125
      export LC_ALL=C.UTF-8
      mkdir -p .pmd-wsl-logs; log=".pmd-wsl-logs/$2.log"
      timeout -k 5 "$3" bash "tests/shell/$2.sh" > "$log" 2>&1; rc=$?
      printf "__summary=%s\n" "$(grep -E "^[0-9]+ passed, [0-9]+ failed" "$log" | tail -n 1)"
      printf "__failed=%s\n" "$(grep -E "^failed cases:" "$log" | tail -n 1)"
      printf "__log=%s/%s\n" "$PWD" "$log"
      printf "__rc=%s\n" "$rc"' _ "$scratch" "$s" "$timeout_secs" | tr -d '\0')" || out="__rc=125"
    rtw_parse_result "$out"
    local note="$RTW_SUMMARY"
    if [[ "$RTW_RC" -eq 124 ]]; then
      note="timed out after ${timeout_secs}s"
    elif [[ -z "$note" && "$RTW_RC" -eq 0 ]]; then
      note="(this suite prints no summary line; exit status 0)"
    elif [[ -z "$note" ]]; then
      note="no summary line; see the log"
    fi
    [[ "$RTW_RC" -eq 0 ]] || failures=$((failures + 1))
    printf '%-36s %5s %6s  %s\n' "$s" "$RTW_RC" "$((SECONDS - t0))" "$note"
    if [[ "$RTW_RC" -ne 0 ]]; then
      [[ -z "$RTW_FAILED" ]] || printf '  %s\n' "$RTW_FAILED"
      [[ -z "$RTW_LOG" ]] || printf '  log (inside WSL): %s\n' "$RTW_LOG"
    fi
  done
  [[ "$failures" -eq 0 ]] || exit 1
}

# Run only when executed; sourcing (the regression suite) defines the functions.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  rtw_main "$@"
fi
