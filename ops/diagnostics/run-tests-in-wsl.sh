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
# git-ignored. Use it on checkouts you trust. Each run uses its own scratch tree
# under ~/.cache/pm-dispatch-wsl-tests/ (mode 700), so runs never collide; the
# tree is removed after a passing run and kept after a failing one (it holds the
# logs), with --keep, or with --sync-only, and every tree there older than a day is
# swept at the next start.
#
# Usage:
#   ops/diagnostics/run-tests-in-wsl.sh [--distro NAME] [--timeout SECS] [--keep]
#                                       [--changed [--base REF]] [--sync-only] <suite>...
#
#   <suite>   test-foo, test-foo.sh or tests/shell/test-foo.sh
#   --timeout limit in seconds for each named suite and, separately, for the whole
#             run-tests --changed run (default 280; raise it when that selects many)
#   --distro  WSL distribution (default: the default distribution)
#   --changed also run tests/bin/run-tests.sh for the paths this working tree
#             changed against the merge base with --base (default origin/main when
#             it exists, else HEAD; note that run-tests.sh alone compares with HEAD
#             only), plus untracked files, without deleted paths: the suites it
#             picks for them run in WSL. Ignored with --sync-only. Resolved before
#             any WSL work, so a bad ref or an empty change set costs nothing.
#   --keep    leave the scratch tree after a passing run
#   --sync-only  copy the tree, print where it is, and stop
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
  printf 'usage: %s [--distro NAME] [--timeout SECS] [--keep] [--changed [--base REF]] [--sync-only] <suite>...\n' "$RTW_SELF" >&2
}

# rtw_help: usage line, then this file's header comment.
rtw_help() {
  local line first=1
  printf 'usage: %s [--distro NAME] [--timeout SECS] [--keep] [--changed [--base REF]] [--sync-only] <suite>...\n' "$RTW_SELF"
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

# rtw_changed_paths <repo-root> <base-ref> <out>
# Write the NUL-separated repo-relative paths this working tree changed against
# the merge base with <base-ref> (empty: origin/main when it exists, else HEAD),
# plus untracked files that are not ignored, to <out>. Deleted paths are left out
# and a rename lists only its new name, the same ACMR set tests/bin/run-tests.sh
# builds for itself. Sets RTW_BASE_USED to the ref actually used. Returns 1 with a
# message when git cannot answer.
rtw_changed_paths() {
  local root="$1" base_ref="$2" out="$3" base_commit
  if [[ -z "$base_ref" ]]; then
    if git -C "$root" rev-parse -q --verify origin/main >/dev/null 2>&1; then
      base_ref=origin/main
    else
      base_ref=HEAD
    fi
  fi
  RTW_BASE_USED="$base_ref"
  if ! base_commit="$(git -C "$root" merge-base HEAD "$base_ref" 2>/dev/null)"; then
    printf '%s: no merge base between HEAD and %s (unknown ref, shallow clone, or no commit yet?)\n' "$RTW_SELF" "$base_ref" >&2
    return 1
  fi
  if ! { git -C "$root" diff --name-only -z --diff-filter=ACMR "$base_commit" -- \
         && git -C "$root" ls-files -z --others --exclude-standard; } > "$out"; then
    printf '%s: cannot list the changed paths\n' "$RTW_SELF" >&2
    return 1
  fi
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

# rtw_main <args>: the helper itself. It turns on errexit, nounset and pipefail
# for the calling shell, so run it as a command (as the bottom of this file does),
# not from a shell you want to keep as it is; the pure functions above do not.
rtw_main() {
  set -euo pipefail
  local distro="" timeout_secs=280 sync_only=0 keep=0 changed=0 base_ref="" s
  local -a suites=() normalized=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --distro)
        [[ $# -ge 2 && -n "${2:-}" ]] || { rtw_usage; exit 2; }
        distro="$2"; shift 2 ;;
      --timeout)
        [[ $# -ge 2 && "${2:-}" =~ ^[0-9]+$ && "$2" -gt 0 ]] || { rtw_usage; exit 2; }
        timeout_secs="$((10#$2))"; shift 2 ;;
      --base)
        [[ $# -ge 2 && -n "${2:-}" && "$2" != -* ]] || { rtw_usage; exit 2; }
        base_ref="$2"; shift 2 ;;
      --changed) changed=1; shift ;;
      --keep) keep=1; shift ;;
      --sync-only) sync_only=1; shift ;;
      -h|--help) rtw_help; exit 0 ;;
      -*) rtw_usage; exit 2 ;;
      *) suites+=("$1"); shift ;;
    esac
  done
  [[ "$sync_only" -eq 1 || "$changed" -eq 1 || "${#suites[@]}" -gt 0 ]] || { rtw_usage; exit 2; }
  [[ -z "$base_ref" || "$changed" -eq 1 ]] || { rtw_usage; exit 2; }

  case "${OSTYPE:-}" in
    msys*|cygwin*) ;;
    *) rtw_die "this helper is for native-Windows Git Bash; on Linux or WSL2 run the suites directly" ;;
  esac
  command -v wsl.exe >/dev/null 2>&1 || rtw_die "wsl.exe not found; install WSL2 first"

  # rtw_wsl_run <command...>: run a command in WSL. wsl.exe is a native Windows
  # program, so Git Bash would rewrite an argument that looks like a POSIX path
  # (/home/...) into C:/Program Files/Git/home/... on its way in; the exclusion
  # is set for this one command only (never export it: git is a native program too).
  rtw_wsl_run() {
    if [[ -n "$distro" ]]; then
      MSYS2_ARG_CONV_EXCL='*' wsl.exe -d "$distro" -e "$@"
    else
      MSYS2_ARG_CONV_EXCL='*' wsl.exe -e "$@"
    fi
  }

  for s in ${suites[@]+"${suites[@]}"}; do
    normalized+=("$(rtw_normalize_suite "$s")") || exit 2
  done

  local file_list exec_list changed_list n_changed=0
  file_list="$(mktemp)"
  exec_list="$(mktemp)"
  changed_list="$(mktemp)"
  # shellcheck disable=SC2064  # the paths are fixed here, expand now
  trap "rm -f '$file_list' '$exec_list' '$changed_list'" EXIT
  # --changed is resolved before any WSL work, so a bad ref or an empty change set
  # costs nothing.
  if [[ "$changed" -eq 1 ]]; then
    rtw_changed_paths "$RTW_REPO_ROOT" "$base_ref" "$changed_list" || exit 2
    n_changed="$(tr -cd '\0' < "$changed_list" | wc -c | tr -d ' ')"
    if [[ "$n_changed" -eq 0 ]]; then
      printf '%s: --changed: no changed paths against %s, nothing to select\n' "$RTW_SELF" "$RTW_BASE_USED" >&2
      [[ "$sync_only" -eq 1 || "${#normalized[@]}" -gt 0 ]] || exit 0
    fi
  fi

  local missing home scratch_key scratch
  missing="$(rtw_wsl_run bash -c 'for t in jq git sqlite3 tar timeout; do command -v "$t" >/dev/null 2>&1 || printf "%s " "$t"; done' 2>/dev/null | tr -d '\0')" \
    || rtw_die "cannot start WSL${distro:+ distribution $distro}"
  [[ -z "$missing" ]] || rtw_die "missing in WSL: $missing(install them there, for example apt install jq git sqlite3)"

  home="$(rtw_wsl_run bash -c 'printf "%s" "$HOME"' | tr -d '\0')" || rtw_die "cannot read \$HOME in WSL"
  [[ "$home" == /?* ]] || rtw_die "unexpected \$HOME in WSL: '$home'"
  # One scratch tree per run: the base name, a checksum of the checkout path, and
  # this run's process id and a random number, so neither two checkouts with the
  # same name nor two concurrent runs replace each other's tree. A tree is removed
  # when the run passes; one that failed (its logs are in it), --keep and
  # --sync-only leave it, and every tree there older than a day is swept at the
  # next start (the directory holds only this tool's trees).
  scratch_key="$(basename "$RTW_REPO_ROOT")-$(printf '%s' "$RTW_REPO_ROOT" | cksum | cut -d' ' -f1)"
  scratch="$home/.cache/pm-dispatch-wsl-tests/$scratch_key-$$-$RANDOM"
  [[ "$scratch" == "$home"/.cache/pm-dispatch-wsl-tests/?* && "$scratch" != */../* && "$scratch" != */.. ]] \
    || rtw_die "unexpected scratch path: $scratch"

  local started=$SECONDS
  printf '%s: syncing %s to WSL:%s\n' "$RTW_SELF" "$RTW_REPO_ROOT" "$scratch" >&2
  rtw_build_lists "$RTW_REPO_ROOT" "$file_list" "$exec_list" || rtw_die "sync failed: cannot list the working tree"

  # The path is checked again inside WSL before anything is removed.
  (cd "$RTW_REPO_ROOT" && tar --null -T "$file_list" -cf -) \
    | rtw_wsl_run bash -c 'set -e
        d="$1"; h="$2"; base="$h/.cache/pm-dispatch-wsl-tests"
        case "$d" in "$base"/?*) ;; *) echo "refusing scratch path: $d" >&2; exit 2 ;; esac
        mkdir -p "$base"
        chmod 700 "$base"
        find "$base" -mindepth 1 -maxdepth 1 -type d -mtime +0 -exec rm -rf {} +
        mkdir -p "$d"; tar -x -C "$d"' _ "$scratch" "$home" \
    || rtw_die "sync failed: copying the working tree into WSL"

  # NTFS carries no mode bits, so the archive makes every file executable. Clear
  # them all first, then set only the real ones: the committed modes are part of
  # what some suites and lints check (lint-jq-lf treats mode 100755 as "entry").
  rtw_wsl_run bash -c '[ -n "$1" ] && cd "$1" && find . -type f -not -path "./.git/*" -exec chmod 644 {} +' _ "$scratch" \
    || rtw_die "sync failed: clearing mode bits"
  if [[ -s "$exec_list" ]]; then
    rtw_wsl_run bash -c '[ -n "$1" ] && cd "$1" && xargs -0 chmod 755 --' _ "$scratch" < "$exec_list" \
      || rtw_die "sync failed: restoring executable bits"
  fi
  rtw_wsl_run bash -c '[ -n "$1" ] && cd "$1" && git init -q && git add -A \
    && git -c user.name=pm-dispatch -c user.email=pm-dispatch@localhost -c commit.gpgsign=false -c core.hooksPath=/dev/null \
       commit -q -m "wsl test sync"' _ "$scratch" \
    || rtw_die "sync failed: initializing the scratch repository"
  printf '%s: synced in %ss\n' "$RTW_SELF" "$((SECONDS - started))" >&2
  if [[ "$sync_only" -eq 1 ]]; then
    printf '%s: scratch tree kept: %s\n' "$RTW_SELF" "$scratch" >&2
    exit 0
  fi

  local failures=0 t0 out
  printf '%-36s %5s %6s  %s\n' suite rc secs summary
  for s in ${normalized[@]+"${normalized[@]}"}; do
    t0=$SECONDS
    # The suite's own exit status and its summary lines are reported from inside
    # WSL as marker lines; the full log stays in the scratch tree.
    out="$(rtw_wsl_run bash -c '[ -n "$1" ] && cd "$1" || exit 125
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

  # --changed: let tests/bin/run-tests.sh choose the suites for the paths this
  # working tree changed (against the merge base with --base, default origin/main
  # when it exists, else HEAD) and run them in WSL. The scratch repo has a single
  # commit, so the paths are handed over explicitly instead of through git diff.
  if [[ "$changed" -eq 1 && "$n_changed" -gt 0 ]]; then
    {
      printf '%s: --changed: %s path(s) against %s; suites chosen by tests/bin/run-tests.sh\n' "$RTW_SELF" "$n_changed" "$RTW_BASE_USED" >&2
      rtw_wsl_run bash -c 'case "$1" in "$2"/.cache/pm-dispatch-wsl-tests/?*) cat > "$1/.pmd-wsl-changed" ;; *) exit 2 ;; esac' _ "$scratch" "$home" < "$changed_list" \
        || rtw_die "cannot hand the changed paths to WSL"
      t0=$SECONDS
      out="$(rtw_wsl_run bash -c '[ -n "$1" ] && cd "$1" || exit 125
        export LC_ALL=C.UTF-8
        args=(); while IFS= read -r -d "" p; do args+=(--path "$p"); done < .pmd-wsl-changed
        mkdir -p .pmd-wsl-logs; log=".pmd-wsl-logs/run-tests-changed.log"
        timeout -k 5 "$2" bash tests/bin/run-tests.sh --jobs 4 "${args[@]}" > "$log" 2>&1; rc=$?
        tail -n 30 "$log"
        printf "__log=%s/%s\n" "$PWD" "$log"
        printf "__rc=%s\n" "$rc"' _ "$scratch" "$timeout_secs" | tr -d '\0')" || out="__rc=125"
      rtw_parse_result "$out"
      printf '%s\n' "$out" | grep -v '^__' || true
      if [[ "$RTW_RC" -eq 124 ]]; then
        printf '%-36s %5s %6s  timed out after %ss (raise --timeout)\n' "run-tests --changed" "$RTW_RC" "$((SECONDS - t0))" "$timeout_secs"
      else
        printf '%-36s %5s %6s\n' "run-tests --changed" "$RTW_RC" "$((SECONDS - t0))"
      fi
      [[ "$RTW_RC" -eq 0 ]] || { failures=$((failures + 1)); [[ -z "$RTW_LOG" ]] || printf '  log (inside WSL): %s\n' "$RTW_LOG"; }
    }
  fi

  # Remove the tree after a passing run; keep it when something failed (its logs
  # are in it) or --keep was given.
  if [[ "$failures" -eq 0 && "$keep" -eq 0 ]]; then
    rtw_wsl_run bash -c 'case "$1" in "$2"/.cache/pm-dispatch-wsl-tests/?*) rm -rf "$1" ;; esac' _ "$scratch" "$home" || true
  else
    printf '%s: scratch tree kept: %s\n' "$RTW_SELF" "$scratch" >&2
  fi
  [[ "$failures" -eq 0 ]] || exit 1
}

# Run only when executed; sourcing (the regression suite) defines the functions.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  rtw_main "$@"
fi
