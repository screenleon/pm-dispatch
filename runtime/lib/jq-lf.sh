#!/usr/bin/env bash
# jq-lf.sh -- keep a native Windows jq from turning LF into CRLF (CC-594).
#
# The jq that `winget install jqlang.jq` installs (the documented Windows setup)
# is a native Windows program whose stdout is in C-runtime text mode: every "\n"
# it writes to a pipe, a file or a command substitution becomes "\r\n". A
# multi-line `$(jq -r ...)` or a `while read` loop then sees a trailing "\r" on
# each value, and `jq -cS . | sha256sum` hashes different bytes than on Linux
# (fdd1d186... instead of 157b4d1b... for {"a":[1,2],"b":1}). `jq -b`
# (--binary) turns the conversion off. The pinned Windows jq accepts it; the Linux
# jq 1.6 that Ubuntu 22.04 ships rejects it ("Unknown option -b"), which is one more
# reason the function is defined only on msys/cygwin or when forced (forcing it
# needs a jq that accepts -b).
#
# Sourcing this file defines a function jq() that adds -b, only where it is
# needed:
#   - OSTYPE is msys* or cygwin* (Git Bash, MSYS2, Cygwin), or
#   - PM_DISPATCH_JQ_LF=1 forces it on (tests, unusual hosts);
#     PM_DISPATCH_JQ_LF=0 forces it off.
# Elsewhere sourcing defines nothing, so jq stays the plain program.
# Sourcing starts no process and changes no shell option.
#
# Limits to know about:
#   - A function reaches only the shell that defines it and its `$(...)`,
#     pipelines and subshells. A script that calls jq must source this file or
#     carry the standalone snippet below; it does not pass through `env -i`.
#   - jq started as a program, not from bash (`timeout 5 jq`, `xargs jq`,
#     `env jq`, `find -exec jq`), bypasses the function: write -b there.
#   - The function is defined only if a jq program is on PATH when this file is
#     sourced. A missing jq therefore still shows up as a missing jq: the many
#     `command -v jq` presence checks keep failing, instead of succeeding on the
#     function and failing later with "jq: command not found". It is not
#     re-checked afterwards: a test that removes jq from PATH after sourcing must
#     `unset -f jq` too.
#   - While the function exists `command -v jq` prints the word jq, not a path;
#     use `type -P jq` for the program path (and for a presence check that must
#     stay true to the PATH).
#   - -b changes how jq reads a CRLF input too (measured with jq 1.8.1 on Windows):
#       `jq -R` and `jq -Rs` on stdin (pipe or redirect): the "\r" is now KEPT
#         (the text-mode stdin used to drop it), which is what Linux jq does;
#       `jq -Rs FILE`, `jq -R FILE`, --rawfile, JSON input: unchanged (the "\r"
#         of a file is dropped either way).
#     A JSON line with a trailing "\r" still parses; a blank CRLF line is not a
#     JSON value and fails `fromjson`, so a line reader of a file that may hold
#     CRLF (a state file an older Windows jq wrote) trims it first:
#     `rtrimstr("\r")` before `select(length > 0)`.
#
# Standalone scripts (hooks that are copied, not linked, and cannot rely on a
# repo-relative source) carry exactly these two lines instead of sourcing. The
# snippet keys off OSTYPE only: it ignores PM_DISPATCH_JQ_LF.
#   # CC-594: native Windows jq writes CRLF to a pipe/file; -b keeps LF (see runtime/lib/jq-lf.sh)
#   case "${OSTYPE:-}" in msys*|cygwin*) if type -P jq >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi ;; esac

_jq_lf_wanted() {
  case "${PM_DISPATCH_JQ_LF:-auto}" in
    1) return 0 ;;
    0) return 1 ;;
  esac
  case "${OSTYPE:-}" in
    msys*|cygwin*) return 0 ;;
  esac
  return 1
}

if _jq_lf_wanted && type -P jq >/dev/null 2>&1; then
  # Besides -b (CC-594), this function keeps path-like STRING values away from the MSYS
  # argument conversion (GitHub issue #590). A native jq is started through the MSYS
  # runtime, which rewrites every argument that looks like a POSIX path: with
  # `jq --arg repo /c/Users/x` the filter sees "C:/Users/x". An artifact field that a schema
  # requires to start with "/" (repo_root, root, git_common_dir, ...) then fails validation,
  # and a comparison against a value that did not go through jq silently differs. A value given
  # to --arg is never a file name to jq, so it must never be converted; this function stops the
  # conversion for the whole call (MSYS2_ARG_CONV_EXCL='*') and converts, itself, the words
  # that ARE file names to the mixed form a native program opens (C:/Users/x), so a call that
  # mixes a path value with a file operand keeps working:
  #   converted: positional input files, the program file after -f/--from-file, the FILE of
  #              --rawfile/--slurpfile;
  #   untouched: the value of --arg/--argjson, positional words after --args/--jsonargs, the
  #              program text, and the number after --indent.
  # A Unix path with no drive letter goes through cygpath -m (one process, roughly 0.15 to
  # 0.25 s on native Windows; a word that starts with /c/ or another drive letter is converted in
  # the shell for free); with no cygpath (Linux, macOS, or a forced test run) a word stays as
  # given. -L / --library-path take the same conversion as a file operand. Not covered:
  # environment variables (MSYS converts those under MSYS2_ENV_CONV_EXCL; no jq program in this
  # repository reads env.*) and /dev/fd/N operands. Everything lives in this one function so that
  # sourcing leaves no helper behind.
  jq() {
    local -a _out=(-b) _conv=()
    local _a _have_prog=0 _from_file=0 _args_mode=0 _end_opts=0 _i _p _q
    while (( $# )); do
      _a="$1"; shift
      if (( _end_opts )) || [[ "$_a" != -* || "$_a" == - ]]; then
        if (( ! _have_prog )); then
          _have_prog=1; _out+=("$_a")
          if (( _from_file )); then _conv+=("$(( ${#_out[@]} - 1 ))"); fi
        else
          _out+=("$_a")
          if (( ! _args_mode )); then _conv+=("$(( ${#_out[@]} - 1 ))"); fi
        fi
        continue
      fi
      case "$_a" in
        --) _end_opts=1; _out+=("$_a") ;;
        --arg|--argjson)
          _out+=("$_a")
          if (( $# )); then _out+=("$1"); shift; fi
          if (( $# )); then _out+=("$1"); shift; fi ;;
        --slurpfile|--rawfile)
          _out+=("$_a")
          if (( $# )); then _out+=("$1"); shift; fi
          if (( $# )); then _out+=("$1"); _conv+=("$(( ${#_out[@]} - 1 ))"); shift; fi ;;
        --indent)
          _out+=("$_a")
          if (( $# )); then _out+=("$1"); shift; fi ;;
        --library-path)
          _out+=("$_a")
          if (( $# )); then _out+=("$1"); _conv+=("$(( ${#_out[@]} - 1 ))"); shift; fi ;;
        --args|--jsonargs) _args_mode=1; _out+=("$_a") ;;
        --from-file) _from_file=1; _out+=("$_a") ;;
        --*) _out+=("$_a") ;;
        -L) # the library directory is a path the native jq opens, so it is converted too
          _out+=("$_a")
          if (( $# )); then _out+=("$1"); _conv+=("$(( ${#_out[@]} - 1 ))"); shift; fi ;;
        -L?*) _out+=(-L "${_a:2}"); _conv+=("$(( ${#_out[@]} - 1 ))") ;;
        # Every short flag of jq except -f is free of the letter f, so a cluster containing an
        # f (-nf, -sRf) names a program file; -L<dir> was handled above.
        *f*) _from_file=1; _out+=("$_a") ;;
        *) _out+=("$_a") ;;
      esac
    done
    if (( ${#_conv[@]} )); then
      for _i in "${_conv[@]}"; do
        _p="${_out[_i]}"
        case "$_p" in
          //*|"") continue ;;
          /*) ;;
          *) continue ;;
        esac
        _q=""
        if [[ "${OSTYPE:-}" == msys* ]]; then
          case "$_p" in
            /[A-Za-z]) _q="${_p:1:1}:/" ;;
            /[A-Za-z]/*) _q="${_p:1:1}:${_p:2}" ;;
          esac
        fi
        if [[ -z "$_q" ]]; then
          if command -v cygpath >/dev/null 2>&1; then
            _q="$(cygpath -m -- "$_p" 2>/dev/null)" || _q=""
          elif [[ "${OSTYPE:-}" == msys* && -x /usr/bin/cygpath ]]; then
            _q="$(/usr/bin/cygpath -m -- "$_p" 2>/dev/null)" || _q=""
          fi
        fi
        if [[ -n "$_q" ]]; then _out[_i]="$_q"; fi
      done
    fi
    MSYS2_ARG_CONV_EXCL='*' command jq "${_out[@]}"
  }
fi
unset -f _jq_lf_wanted
