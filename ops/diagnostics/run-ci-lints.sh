#!/usr/bin/env bash
# Run the lint steps CI runs, from one command, before pushing.
#
# Why: CI's lint set is spread over many jobs in .github/workflows/lint.yml, and a
# lint that was not run locally costs a CI round trip and, with the PR gate, a new
# gate run (CC-679). The list here is read from that workflow, never copied, so a
# step added to CI shows up here by itself. (To pick the suites a change touches, use
# tests/bin/run-tests.sh --changed instead: that answers a different question.)
#
# What it runs: every `run:` step of the workflow that runs a script under tools/lint/
# or the BACKLOG validators pm/scripts/validate.sh and pm/scripts/lint-*.sh, each from
# the repository root, in the order the workflow lists them, with `bash -e` as GitHub
# does. A comment or an echo that only mentions such a path does not select a step.
# Steps that only make sense on a CI runner (they use `${{ }}` expressions, the runner
# environment, the GitHub CLI or `git fetch`), or that use a YAML shape or a shell this
# reader does not handle, are listed as skipped, with the reason. The regression suites
# of the linters (tests/shell/test-lint-*.sh) are not run; they are ordinary suites.
#
# The pinned ShellCheck is put first on PATH when it is installed (CI does the same):
# install it once with tools/lint/bootstrap-shellcheck.sh. The ShellCheck lint is by far
# the slowest step (about two minutes); --only narrows the run to the others.
#
# On native Windows every spawned process is slow and some lints behave differently, so
# --wsl copies the working tree into WSL (the way run-tests-in-wsl.sh does), runs this
# script there and removes the copy.
#
# Usage:
#   ops/diagnostics/run-ci-lints.sh [--list] [--only TEXT] [--wsl]
#                                   [--workflow FILE] [--root DIR]
#
#   --list      print the steps (and the skipped ones) and stop
#   --only TEXT run only the steps whose name or command contains TEXT
#   --wsl       native Windows only: run it inside WSL on a copy of this working tree
#   --workflow  workflow file to read (default .github/workflows/lint.yml of --root)
#   --root      directory the steps run in (default: the checkout this file is in)
#               --workflow and --root are for tests; they cannot be combined with --wsl
#
# Output: one row per step (ok, FAIL or skip), the last lines of every failing step, and
# a summary. Every step runs even after one fails.
#
# Exit: 0 every step passed, 1 a step failed, 2 usage or environment error.

# shellcheck disable=SC2016  # the bash -c programs run inside WSL, where $1 and friends expand

RCL_SELF="$(basename "${BASH_SOURCE[0]}")"
RCL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rcl_usage() {
  printf 'usage: %s [--list] [--only TEXT] [--wsl] [--workflow FILE] [--root DIR]\n' "$RCL_SELF" >&2
}

# rcl_extract <workflow> <out_dir>
#
# Writes, for every selected step, NNN.cmd (the step's script), NNN.name, NNN.show (the
# line that runs the linter) and, for a step that cannot run outside CI, NNN.skip (why).
# The workflow is a restricted subset of YAML: steps are list items (`- name:` / `- run:`)
# whose keys sit two columns in, and `run:` is either a one-line command or a `|` block.
# This is not a YAML parser; tools/lint/lint-test-suite-registry.sh reads the same file with
# a similar awk, so a fix to one reader belongs in the other.
rcl_extract() {
  local workflow="$1" out_dir="$2"
  awk -v out="$out_dir" '
    function indent_of(s) { match(s, /^ */); return RLENGTH }
    # The selector, once: a line that RUNS a linter or a BACKLOG validator (a comment does not).
    function lint_line(l) {
      sub(/^[ \t]+/, "", l)
      if (l ~ /^#/) return 0
      return (l ~ /(^|[^A-Za-z0-9_.\/-])(\.\/)?tools\/lint\/[A-Za-z0-9_.-]+\.sh/ \
           || l ~ /(^|[^A-Za-z0-9_.\/-])(\.\/)?pm\/scripts\/(validate|lint-[A-Za-z0-9-]+)\.sh/)
    }
    function write_file(path, text) { printf "%s", text > path; close(path) }
    function flush(   idx, k, nl, lines, show, reason) {
      if (cmd != "") {
        nl = split(cmd, lines, "\n"); show = ""
        for (k = 1; k <= nl; k++) if (lint_line(lines[k])) { show = lines[k]; sub(/^[ \t]+/, "", show); break }
        if (show != "") {
          n++
          idx = sprintf("%03d", n)
          reason = ""
          if (cmd ~ /\$\{\{/ || step_expr || cmd ~ /(^|[^A-Za-z0-9_])(GITHUB|RUNNER)_/) reason = "uses CI-only variables"
          else if (cmd ~ /(^|[^A-Za-z0-9_])gh (api|pr|run)/ || cmd ~ /git (fetch|ls-remote)/) reason = "needs the GitHub CLI or a fetch"
          else if (unsupported != "") reason = unsupported
          write_file(out "/" idx ".cmd", cmd)
          write_file(out "/" idx ".name", (name == "" ? substr(show, 1, 60) : name) "\n")
          write_file(out "/" idx ".show", show "\n")
          if (reason != "") write_file(out "/" idx ".skip", reason "\n")
        }
      }
      cmd = ""; name = ""; step_expr = 0; unsupported = ""; shell_val = ""
    }
    {
      line = $0
      sub(/\r$/, "", line)
      if (inblock) {
        if (line ~ /^[ ]*$/ || indent_of(line) > key_indent) {
          sub("^" sprintf("%" (key_indent + 2) "s", ""), "", line)
          cmd = cmd line "\n"
          next
        }
        inblock = 0
      }
      if (line ~ /^[ ]*$/) next
      ind = indent_of(line)
      if (line ~ /^[ ]*- / && (!in_item || ind <= item_indent)) {
        flush(); in_item = 1; item_indent = ind
      } else if (in_item && ind <= item_indent) {
        flush(); in_item = 0
      }
      if (!in_item) next
      key_ind = ind + (line ~ /^[ ]*- / ? 2 : 0)
      if (line ~ /\$\{\{/) step_expr = 1
      if (key_ind == item_indent + 2) {
        if (match(line, /^[ ]*(- )?name:[ ]*/)) {
          name = substr(line, RLENGTH + 1)
          gsub(/^["\047]|["\047]$/, "", name)
        } else if (match(line, /^[ ]*(- )?shell:[ ]*/)) {
          shell_val = substr(line, RLENGTH + 1)
          if (shell_val !~ /^bash/) unsupported = "runs in a shell other than bash"
        } else if (match(line, /^[ ]*(- )?run:[ ]*/)) {
          val = substr(line, RLENGTH + 1)
          key_indent = key_ind
          if (val ~ /^\|[-+0-9]*[ ]*(#.*)?$/) { inblock = 1; cmd = "" }
          else if (val ~ /^>[-+0-9]*[ ]*(#.*)?$/) { inblock = 1; cmd = ""; unsupported = "uses a folded YAML block" }
          else {
            if (val ~ /^["\047]/) unsupported = "uses a quoted YAML scalar"
            cmd = val
          }
        }
      }
    }
    END { flush() }
  ' "$workflow"
}

# rcl_pin_shellcheck <root>: put the repository-pinned ShellCheck first on PATH when it is installed.
rcl_pin_shellcheck() {
  local root="$1" sc
  [[ -r "$root/tools/lint/bootstrap-shellcheck.sh" ]] || return 0
  sc="$(bash "$root/tools/lint/bootstrap-shellcheck.sh" --resolve 2>/dev/null | tail -n 1)" || return 0
  [[ -x "$sc" ]] && PATH="${sc%/*}:$PATH"
  return 0
}

# rcl_wsl <args...>: run this script inside WSL on a copy of the working tree, then remove the copy.
rcl_wsl() {
  local sync scratch root_name rc=0
  case "${OSTYPE:-}" in
    msys*|cygwin*) ;;
    *) printf '%s: --wsl is for native-Windows Git Bash; on Linux or WSL2 run it directly\n' "$RCL_SELF" >&2; return 2 ;;
  esac
  sync="$(bash "$RCL_REPO_ROOT/ops/diagnostics/run-tests-in-wsl.sh" --sync-only 2>&1)" || {
    printf '%s\n' "$sync" >&2
    return 2
  }
  scratch="$(printf '%s\n' "$sync" | sed -n 's/.*scratch tree kept: //p' | tail -n 1)"
  [[ -n "$scratch" ]] || { printf '%s: could not read the WSL scratch tree from the sync output\n' "$RCL_SELF" >&2; return 2; }
  root_name="$(basename "$RCL_REPO_ROOT")"
  MSYS2_ARG_CONV_EXCL='*' wsl.exe -e bash -c 'cd "$1/$2" && shift 2 && bash ops/diagnostics/run-ci-lints.sh "$@"' _ \
    "$scratch" "$root_name" "$@" || rc=$?
  # The copy was made for this run only; remove it, but never anything outside the helper's cache.
  MSYS2_ARG_CONV_EXCL='*' wsl.exe -e bash -c 'case "$1" in */.cache/pm-dispatch-wsl-tests/?*) rm -rf -- "$1" ;; esac' _ "$scratch" || true
  return "$rc"
}

rcl_main() {
  local list=0 only="" wsl=0 workflow="" root="$RCL_REPO_ROOT" host_paths=0
  local -a passthrough=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list) list=1; passthrough+=("$1"); shift ;;
      --only)
        [[ $# -ge 2 && -n "${2:-}" ]] || { rcl_usage; return 2; }
        only="$2"; passthrough+=("$1" "$2"); shift 2 ;;
      --wsl) wsl=1; shift ;;
      --workflow)
        [[ $# -ge 2 && -n "${2:-}" ]] || { rcl_usage; return 2; }
        workflow="$2"; host_paths=1; shift 2 ;;
      --root)
        [[ $# -ge 2 && -d "${2:-}" ]] || { rcl_usage; return 2; }
        root="$(cd "$2" && pwd)"; host_paths=1; shift 2 ;;
      -h|--help) sed -n '2,/^# Exit:/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; return 0 ;;
      *) rcl_usage; return 2 ;;
    esac
  done
  if [[ "$wsl" -eq 1 ]]; then
    if [[ "$host_paths" -eq 1 ]]; then
      printf '%s: --workflow and --root name host paths and cannot be combined with --wsl\n' "$RCL_SELF" >&2
      return 2
    fi
    rcl_wsl ${passthrough[@]+"${passthrough[@]}"}
    return
  fi
  [[ -n "$workflow" ]] || workflow="$root/.github/workflows/lint.yml"
  [[ -r "$workflow" ]] || { printf '%s: cannot read the workflow: %s\n' "$RCL_SELF" "$workflow" >&2; return 2; }

  local dir rc=0
  dir="$(mktemp -d)" || return 2
  trap 'rm -rf "$dir"' INT TERM
  rcl_extract "$workflow" "$dir"
  if [[ "$list" -eq 0 ]]; then
    case "${OSTYPE:-}" in
      msys*|cygwin*) printf '%s: note: on native Windows this is slow and some lints differ; --wsl runs it in WSL\n' "$RCL_SELF" >&2 ;;
    esac
    rcl_pin_shellcheck "$root"
  fi
  rcl_run "$dir" "$root" "$list" "$only" || rc=$?
  trap - INT TERM
  rm -rf "$dir"
  return "$rc"
}

# rcl_run <steps_dir> <root> <list 0|1> <only>: run (or list) the extracted steps.
rcl_run() {
  local dir="$1" root="$2" list="$3" only="$4"
  local f idx name reason out status started step_secs
  local passed=0 failed=0 skipped=0 selected=0
  local -a failed_names=()
  for f in "$dir"/*.cmd; do
    [[ -e "$f" ]] || break
    idx="$(basename "$f" .cmd)"
    name="$(<"$dir/$idx.name")"
    if [[ -n "$only" && "$name" != *"$only"* && "$(<"$f")" != *"$only"* ]]; then
      continue
    fi
    selected=$((selected + 1))
    if [[ -f "$dir/$idx.skip" ]]; then
      reason="$(<"$dir/$idx.skip")"
      skipped=$((skipped + 1))
      printf 'skip  %s (%s)\n' "$name" "$reason"
      continue
    fi
    if [[ "$list" -eq 1 ]]; then
      printf 'run   %s\n' "$name"
      printf '        $ %s\n' "$(<"$dir/$idx.show")"
      continue
    fi
    started=$SECONDS
    status=0
    # `bash -e`: GitHub runs a step's script that way, so a failing command in the middle of a
    # block fails the step there; without it this runner would report green where CI is red.
    out="$(cd "$root" && bash -e "$f" 2>&1)" || status=$?
    step_secs=$((SECONDS - started))
    if [[ "$status" -eq 0 ]]; then
      passed=$((passed + 1))
      printf 'ok    %s (%ss)\n' "$name" "$step_secs"
    else
      failed=$((failed + 1))
      failed_names+=("$name")
      printf 'FAIL  %s (%ss, exit %s)\n' "$name" "$step_secs" "$status"
      printf '%s\n' "$out" | tail -n 20 | sed 's/^/      | /'
    fi
  done

  if [[ "$selected" -eq 0 ]]; then
    printf '%s: no lint step selected%s\n' "$RCL_SELF" "${only:+ for --only $only}" >&2
    return 2
  fi
  if [[ "$list" -eq 1 ]]; then
    return 0
  fi
  printf '%s: %d passed, %d failed, %d skipped\n' "$RCL_SELF" "$passed" "$failed" "$skipped"
  if [[ "$failed" -gt 0 ]]; then
    printf '%s: failed: %s\n' "$RCL_SELF" "$(IFS=';'; printf '%s' "${failed_names[*]}")" >&2
    return 1
  fi
  return 0
}

# Run unless sourced.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  rcl_main "$@"
  exit $?
fi
