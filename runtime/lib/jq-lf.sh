#!/usr/bin/env bash
# jq-lf.sh -- keep a native Windows jq from turning LF into CRLF (CC-594).
#
# The jq that `winget install jqlang.jq` installs (the documented Windows setup)
# is a native Windows program whose stdout is in C-runtime text mode: every "\n"
# it writes to a pipe, a file or a command substitution becomes "\r\n". A
# multi-line `$(jq -r ...)` or a `while read` loop then sees a trailing "\r" on
# each value, and `jq -cS . | sha256sum` hashes different bytes than on Linux
# (fdd1d186... instead of 157b4d1b... for {"a":[1,2],"b":1}). `jq -b`
# (--binary, jq >= 1.6, which docs/platform-support.md already requires) turns
# the conversion off.
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
#   - Input too is read in binary mode: `jq -R` (line mode) on stdin keeps the
#     "\r" of a CRLF input line, which text mode used to strip. `-Rs` on stdin
#     keeps it with or without -b; file arguments and --rawfile are read in text
#     mode and lose it.
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
  jq() { command jq -b "$@"; }
fi
unset -f _jq_lf_wanted
