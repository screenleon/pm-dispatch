#!/usr/bin/env bash
# Run the lint steps CI runs, from one command, before pushing.
#
# Why: CI's lint set is spread over many jobs in .github/workflows/lint.yml, and a
# lint that was not run locally costs a CI round trip and, with the PR gate, a new
# gate run (CC-679). The list here is read from that workflow, never copied, so a
# step added to CI shows up here by itself.
#
# What it runs: every `run:` step of the workflow whose command calls a script under
# tools/lint/ or to pm/scripts/validate.sh or pm/scripts/lint-*.sh (the linters and the BACKLOG validators), each from the
# repository root, in the order the workflow lists them. Steps that only make sense on
# a CI runner (they use the GitHub token, the runner temp directory or `git fetch`) are
# listed as skipped, with the reason. The regression suites of the linters (tests/shell/
# test-lint-*.sh) are not run; they are ordinary suites.
#
# The pinned ShellCheck is put first on PATH when it is installed (CI does the same):
# install it once with tools/lint/bootstrap-shellcheck.sh.
#
# On native Windows every spawned process is slow and some lints behave differently, so
# --wsl copies the working tree into WSL (the way run-tests-in-wsl.sh does) and runs
# this script there.
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
#
# Output: one row per step (ok, FAIL or skip), the last lines of every failing step, and
# a summary. Every step runs even after one fails.
#
# Exit: 0 every step passed, 1 a step failed, 2 usage or environment error.

# shellcheck disable=SC2016  # the bash -c program runs inside WSL, where $1 and friends expand

RCL_SELF="$(basename "${BASH_SOURCE[0]}")"
RCL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rcl_usage() {
  printf 'usage: %s [--list] [--only TEXT] [--wsl] [--workflow FILE] [--root DIR]\n' "$RCL_SELF" >&2
}

# rcl_extract <workflow> <out_dir>
#
# Writes one pair of files per selected step: NNN.cmd (the step's script) and NNN.name,
# or NNN.skip (the reason) for a step that cannot run outside CI. Selected means the
# command runs something under tools/lint/ or the pm/scripts validate/lint scripts. Both `run: cmd` and `run: |` blocks are
# read. The workflow is a restricted subset of YAML (steps are list items, `run:` is a
# key of the item), which is all this needs; it is not a YAML parser.
rcl_extract() {
  local workflow="$1" out_dir="$2"
  awk -v out="$out_dir" '
    function indent_of(s,   m) { match(s, /^ */); return RLENGTH }
    function flush(   idx, fname, ci, reason) {
      if (cmd == "") return
      if (cmd !~ /tools\/lint\// && cmd !~ /pm\/scripts\/(validate|lint-[a-z-]+)\.sh/) { cmd = ""; return }
      n++
      idx = sprintf("%03d", n)
      reason = ""
      if (cmd ~ /\$\{\{/ || cmd ~ /GITHUB_/ || cmd ~ /RUNNER_/) reason = "uses CI-only variables"
      else if (cmd ~ /gh api/ || cmd ~ /git fetch/) reason = "needs the GitHub API or a fetch"
      printf "%s", cmd > (out "/" idx ".cmd")
      close(out "/" idx ".cmd")
      printf "%s\n", (name == "" ? substr(cmd, 1, 60) : name) > (out "/" idx ".name")
      close(out "/" idx ".name")
      if (reason != "") { printf "%s\n", reason > (out "/" idx ".skip"); close(out "/" idx ".skip") }
      cmd = ""
    }
    {
      line = $0
      sub(/\r$/, "", line)
      if (inblock) {
        if (line ~ /^[ ]*$/ || indent_of(line) > block_indent) {
          sub("^" sprintf("%" (block_indent + 2) "s", ""), "", line)
          cmd = cmd line "\n"
          next
        }
        inblock = 0
        flush()
      }
      if (line ~ /^[ ]*- /) { flush(); name = "" }
      if (match(line, /^[ ]*(- )?name:[ ]*/)) {
        name = substr(line, RLENGTH + 1)
        gsub(/^["\047]|["\047]$/, "", name)
      }
      if (match(line, /^[ ]*(- )?run:[ ]*/)) {
        val = substr(line, RLENGTH + 1)
        block_indent = indent_of(line) + (line ~ /^[ ]*- run:/ ? 2 : 0)
        if (val ~ /^[|>][-+]?[ ]*$/) { inblock = 1; cmd = ""; next }
        cmd = val
        flush()
      }
    }
    END { if (inblock) flush() }
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

# rcl_wsl: run this script inside WSL on a copy of the working tree.
rcl_wsl() {
  local -a passthrough=("$@")
  local sync scratch root_name
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
    "$scratch" "$root_name" ${passthrough[@]+"${passthrough[@]}"}
}

rcl_main() {
  local list=0 only="" wsl=0 workflow="" root="$RCL_REPO_ROOT"
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
        workflow="$2"; passthrough+=("$1" "$2"); shift 2 ;;
      --root)
        [[ $# -ge 2 && -d "${2:-}" ]] || { rcl_usage; return 2; }
        root="$(cd "$2" && pwd)"; passthrough+=("$1" "$2"); shift 2 ;;
      -h|--help) sed -n '2,/^# Exit:/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; return 0 ;;
      *) rcl_usage; return 2 ;;
    esac
  done
  if [[ "$wsl" -eq 1 ]]; then
    rcl_wsl ${passthrough[@]+"${passthrough[@]}"}
    return
  fi
  [[ -n "$workflow" ]] || workflow="$root/.github/workflows/lint.yml"
  [[ -r "$workflow" ]] || { printf '%s: cannot read the workflow: %s\n' "$RCL_SELF" "$workflow" >&2; return 2; }

  local dir rc=0
  dir="$(mktemp -d)" || return 2
  rcl_extract "$workflow" "$dir"
  rcl_run "$dir" "$root" "$list" "$only" || rc=$?
  rm -rf "$dir"
  return "$rc"
}

# rcl_run <steps_dir> <root> <list 0|1> <only>: run (or list) the extracted steps.
rcl_run() {
  local dir="$1" root="$2" list="$3" only="$4"
  local f idx name reason out status started step_secs
  local passed=0 failed=0 skipped=0 selected=0
  local -a failed_names=()
  if [[ "$list" -eq 0 ]]; then
    case "${OSTYPE:-}" in
      msys*|cygwin*) printf '%s: note: on native Windows this is slow and some lints differ; --wsl runs it in WSL\n' "$RCL_SELF" >&2 ;;
    esac
    rcl_pin_shellcheck "$root"
  fi

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
      printf '        $ %s\n' "$(grep -m1 -E 'tools/lint/|pm/scripts/(validate|lint-[a-z-]+)\.sh' "$f" | sed 's/^[[:space:]]*//')"
      continue
    fi
    started=$SECONDS
    status=0
    out="$(cd "$root" && bash "$f" 2>&1)" || status=$?
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

# Run unless sourced (the regression suite sources this file for rcl_extract).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  rcl_main "$@"
  exit $?
fi
