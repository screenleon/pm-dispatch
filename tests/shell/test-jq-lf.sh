#!/usr/bin/env bash
# Unit tests for runtime/lib/jq-lf.sh (CC-594).

# Cases define and remove a jq() function and change PATH on purpose inside
# subshells; none of that is meant to reach the parent shell.
# shellcheck disable=SC2030,SC2031
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB="$REPO_ROOT/runtime/lib/jq-lf.sh"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# sha256 of {"a":[1,2],"b":1} followed by one LF, i.e. what Linux computes for
# `jq -cS .` of that document.
LINUX_JSON_SHA="157b4d1b1fc0312fe1057848da29a15cb8ca4974a456c50c5d59223812180f2e"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

_sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

# Run a snippet in a clean bash with the library sourced under the given
# OSTYPE / PM_DISPATCH_JQ_LF ("unset" leaves the variable out), print whether a
# jq function exists afterwards.
# usage: _defines <ostype> <knob-or-unset>
_defines() {
  local ostype="$1" knob="$2"
  (
    unset -f jq
    OSTYPE="$ostype"
    if [[ "$knob" == unset ]]; then unset PM_DISPATCH_JQ_LF; else export PM_DISPATCH_JQ_LF="$knob"; fi
    # shellcheck disable=SC1090
    . "$LIB"
    if declare -F jq >/dev/null; then echo yes; else echo no; fi
  )
}

# Behavior: sourcing the library defines a jq() function only where it is needed:
# for an msys or cygwin OSTYPE, or when PM_DISPATCH_JQ_LF=1 forces it; never for
# linux or macOS by default, and never when PM_DISPATCH_JQ_LF=0 forces it off.
# Steps: source it in a clean subshell for each OSTYPE / knob combination and
# check `declare -F jq`.
case_jq_lf_defines_the_function_only_where_needed() {
  local name="jq-lf-defines-the-function-only-where-needed"
  should_run "$name" || return 0
  type -P jq >/dev/null 2>&1 || { skip "$name" "host has no jq (the shim is only defined when jq exists)"; return 0; }
  local row=0 ostype knob want got
  while IFS='|' read -r ostype knob want; do
    got="$(_defines "$ostype" "$knob")"
    [[ "$got" == "$want" ]] || { fail "$name" "OSTYPE='$ostype' PM_DISPATCH_JQ_LF=$knob: expected $want, got $got"; return; }
    row=$((${row:-0} + 1))
  done <<'TABLE'
msys|unset|yes
msys-2|unset|yes
cygwin|unset|yes
linux-gnu|unset|no
darwin23.0|unset|no
freebsd14|unset|no
|unset|no
linux-gnu|1|yes
darwin23.0|1|yes
msys|0|no
cygwin|0|no
msys|auto|yes
linux-gnu|auto|no
TABLE
  [[ "$row" -eq 13 ]] || { fail "$name" "expected 13 table rows to be checked, checked ${row:-0}"; return; }
  pass "$name"
}

# Behavior: the function adds -b as the first argument and passes every other
# argument through untouched (spaces, quotes, an empty string), the same stdin,
# and the program's exit status.
# Steps: put a stub jq that logs its arguments one per line and echoes stdin first
# on PATH, force the shim on, call jq with awkward arguments and a nonzero exit
# status, and compare the log, the output and the status.
case_jq_lf_adds_binary_flag_and_preserves_arguments() {
  local name="jq-lf-adds-binary-flag-and-preserves-arguments"
  should_run "$name" || return 0
  local stubs="$TMP_DIR/stubs" log="$TMP_DIR/args.log" out rc want
  mkdir -p "$stubs"
  cat > "$stubs/jq" <<'STUB'
#!/bin/sh
for a in "$@"; do printf '%s\n' "$a"; done > "__LOG__"
cat
exit "${STUB_RC:-0}"
STUB
  sed -i "s#__LOG__#$log#" "$stubs/jq"
  chmod +x "$stubs/jq"
  rc=0
  out="$(
    unset -f jq
    PATH="$stubs:$PATH"
    export PM_DISPATCH_JQ_LF=1 STUB_RC=5
    # shellcheck disable=SC1090
    . "$LIB"
    printf 'stdin-line' | jq --arg v 'a b "c"' '' -e '.x | "q"'
  )" || rc=$?
  [[ "$rc" -eq 5 ]] || { fail "$name" "exit status not passed through: $rc"; return; }
  [[ "$out" == stdin-line ]] || { fail "$name" "stdin not passed through: '$out'"; return; }
  want=$'-b\n--arg\nv\na b "c"\n\n-e\n.x | "q"'
  [[ "$(cat "$log")" == "$want" ]] || { fail "$name" "arguments changed: $(tr '\n' '|' < "$log")"; return; }
  pass "$name"
}

# Behavior: sourcing starts no process (jq is never run), prints nothing and
# changes no shell option; the jq function is the only trace it leaves (no helper
# function stays behind).
# Steps: put a counting stub jq first on PATH, snapshot `set +o`, `shopt -p` and
# the function names, source the library with the shim forced on, and compare.
case_jq_lf_sourcing_is_free_and_leaves_options_alone() {
  local name="jq-lf-sourcing-is-free-and-leaves-options-alone"
  should_run "$name" || return 0
  local stubs="$TMP_DIR/count-stubs" log="$TMP_DIR/count.log" printed new_fns
  mkdir -p "$stubs"; : > "$log"
  printf '#!/bin/sh\necho started >> "%s"\n' "$log" > "$stubs/jq"
  chmod +x "$stubs/jq"
  # Measured in a fresh bash process, not a subshell: th_init has already loaded
  # the library into this shell, so any option it changed, and any helper it left,
  # would already be part of the "before" state of a subshell and go unseen.
  printed="$(
    PATH="$stubs:$PATH" PM_DISPATCH_JQ_LF=1 TMP="$TMP_DIR" bash -c '
      { set +o; shopt -p; } > "$TMP/opts.before"
      compgen -A function | sort > "$TMP/fns.before"
      . "$1" 2>&1
      { set +o; shopt -p; } > "$TMP/opts.after"
      compgen -A function | sort > "$TMP/fns.after"
    ' _ "$LIB"
  )"
  [[ -z "$printed" ]] || { fail "$name" "sourcing printed: '$printed'"; return; }
  [[ ! -s "$log" ]] || { fail "$name" "sourcing started jq"; return; }
  cmp -s "$TMP_DIR/opts.before" "$TMP_DIR/opts.after" || \
    { fail "$name" "sourcing changed shell options: $(diff "$TMP_DIR/opts.before" "$TMP_DIR/opts.after" | tr '\n' ' ')"; return; }
  new_fns="$(comm -13 "$TMP_DIR/fns.before" "$TMP_DIR/fns.after" | tr '\n' ' ')"
  [[ "$new_fns" == "jq " ]] || { fail "$name" "sourcing left these functions defined: '$new_fns' (only jq expected)"; return; }
  pass "$name"
}

# Behavior: the function is defined only if a jq program is on PATH when the
# library is sourced, even when forced on: otherwise `command -v jq` would keep
# succeeding on the function and every "jq is required" preflight in pmctl and
# pr-gate would be bypassed on Windows, failing later with exit 127.
# Steps: source the library with an empty directory as PATH, with the shim forced
# on and OSTYPE=msys, and check there is no jq function and `command -v jq` fails;
# then with a stub jq on PATH check the function exists.
case_jq_lf_is_not_defined_when_jq_is_missing() {
  local name="jq-lf-is-not-defined-when-jq-is-missing"
  should_run "$name" || return 0
  local empty_bin="$TMP_DIR/no-jq-bin" with_jq="$TMP_DIR/with-jq-bin" got
  mkdir -p "$empty_bin" "$with_jq"
  printf '#!/bin/sh\nexit 0\n' > "$with_jq/jq"; chmod +x "$with_jq/jq"
  got="$(
    unset -f jq
    OSTYPE=msys
    export PM_DISPATCH_JQ_LF=1
    PATH="$empty_bin"
    # shellcheck disable=SC1090
    . "$LIB"
    if declare -F jq >/dev/null; then echo "function-defined"; fi
    if command -v jq >/dev/null 2>&1; then echo "command-v-succeeds"; fi
    echo finished
  )"
  [[ "$got" == finished ]] || { fail "$name" "with no jq on PATH: $(printf '%s' "$got" | tr '\n' ' ')"; return; }
  got="$(
    unset -f jq
    OSTYPE=msys
    PATH="$with_jq:$PATH"
    # shellcheck disable=SC1090
    . "$LIB"
    if declare -F jq >/dev/null; then echo yes; else echo no; fi
  )"
  [[ "$got" == yes ]] || { fail "$name" "with a jq on PATH the function was not defined"; return; }
  pass "$name"
}

# Behavior: end to end with the real jq, the shim yields LF-only output in every
# shape the gate uses (pipe, command substitution, file redirect), and the digest
# of `jq -cS .` output equals the one Linux computes. On a host whose jq already
# writes LF this passes trivially; on native Windows it is the regression pin for
# the CRLF problem.
# Steps: with the shim forced on, run the real jq for multi-line raw output through
# a pipe, a command substitution and a file, check no carriage return appears, and
# compare the sha256 of a canonicalised JSON line with the Linux value.
case_jq_lf_real_jq_writes_lf_and_matches_the_linux_digest() {
  local name="jq-lf-real-jq-writes-lf-and-matches-the-linux-digest"
  should_run "$name" || return 0
  command -v jq >/dev/null 2>&1 || { skip "$name" "host has no jq"; return 0; }
  # The case forces the shim on, so the real jq receives -b. A Linux jq 1.6
  # (Ubuntu 22.04 ships it) rejects it, and there the shim never exists, so skip.
  # On Windows the shim is the product: a jq that rejects -b there is a failure.
  if ! jq -b -n 1 >/dev/null 2>&1; then
    case "${OSTYPE:-}" in
      msys*|cygwin*) fail "$name" "this Windows jq rejects -b, so the shim cannot work"; return ;;
    esac
    skip "$name" "this jq does not accept -b (for example Linux jq 1.6)"
    return 0
  fi
  local cr=$'\r' piped subst filed digest
  piped="$(
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    # shellcheck disable=SC1090
    . "$LIB"
    jq -n -r '"a","b"' | cat
  )"
  subst="$(
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    # shellcheck disable=SC1090
    . "$LIB"
    x="$(jq -n -r '"a","b"')"
    printf '%s' "$x"
  )"
  (
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    # shellcheck disable=SC1090
    . "$LIB"
    jq -n -r '"a","b"' > "$TMP_DIR/out.txt"
  )
  filed="$(cat "$TMP_DIR/out.txt")"
  for v in "$piped" "$subst" "$filed"; do
    [[ "$v" != *"$cr"* ]] || { fail "$name" "carriage return in jq output: $(printf '%s' "$v" | od -An -c | tr -s ' ')"; return; }
  done
  digest="$(
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    # shellcheck disable=SC1090
    . "$LIB"
    printf '{"b":1,"a":[1,2]}' | jq -cS . | _sha
  )"
  [[ "$digest" == "$LINUX_JSON_SHA" ]] || { fail "$name" "digest of jq -cS output is $digest, Linux computes $LINUX_JSON_SHA"; return; }
  pass "$name"
}

# Behavior: tests/lib/test-harness.sh th_init loads the library, so every suite that
# calls th_init gets the shim on native Windows (and none elsewhere). The library
# test above sources $LIB itself, so it cannot notice the harness losing the call.
# It also loads it after the environment scrub, so a caller's PM_DISPATCH_JQ_LF
# cannot leak into a suite (the inventory marks it fixture_scrub=yes).
# Steps: run a clean bash that sets OSTYPE, sources the harness, calls th_init, and
# check whether a jq function exists: yes for msys, no for linux-gnu. Every run has
# PM_DISPATCH_JQ_LF=1 in the environment, which would force the shim on for
# linux-gnu if th_init loaded the library before scrubbing it.
case_jq_lf_is_loaded_by_th_init() {
  local name="jq-lf-is-loaded-by-th-init"
  should_run "$name" || return 0
  type -P jq >/dev/null 2>&1 || { skip "$name" "host has no jq (the shim is only defined when jq exists)"; return 0; }
  local ostype want got
  for ostype in msys linux-gnu; do
    want=no; [[ "$ostype" == msys ]] && want=yes
    # shellcheck disable=SC2016 # the probe is a script for the child bash, expanded there
    got="$(env -u PM_DISPATCH_TEST_FORCE_JQ_LF PM_DISPATCH_JQ_LF=1 bash -c 'OSTYPE="$1"; . "$2/tests/lib/test-harness.sh"; th_init; if declare -F jq >/dev/null; then echo yes; else echo no; fi' _ "$ostype" "$REPO_ROOT" 2>&1 | tail -n 1)"
    [[ "$got" == "$want" ]] || { fail "$name" "OSTYPE=$ostype with PM_DISPATCH_JQ_LF=1 in the environment: expected $want, got '$got'"; return; }
  done
  pass "$name"
}

# Behavior: PM_DISPATCH_TEST_FORCE_JQ_LF=1 makes th_init turn the shim on even where
# the platform would not (the Linux CI leg), and export the knob so a launched
# pmctl or pr-gate follows; without it nothing changes, and a caller's own
# PM_DISPATCH_JQ_LF is still scrubbed.
# Steps: in clean bash processes with OSTYPE=linux-gnu, call th_init with and
# without the force variable and check for the jq function and the exported knob.
case_jq_lf_test_force_knob_enables_the_shim() {
  local name="jq-lf-test-force-knob-enables-the-shim"
  should_run "$name" || return 0
  type -P jq >/dev/null 2>&1 || { skip "$name" "host has no jq (the shim is only defined when jq exists)"; return 0; }
  # shellcheck disable=SC2016 # the probe is a script for the child bash, expanded there
  # The last field is read by a child bash: only an EXPORTED knob reaches the pmctl
  # and pr-gate a suite launches, which is the point of the force variable.
  local probe='OSTYPE=linux-gnu; . "$1/tests/lib/test-harness.sh"; th_init; if declare -F jq >/dev/null; then f=yes; else f=no; fi; echo "$f ${PM_DISPATCH_JQ_LF:-unset} $(bash -c '"'"'echo ${PM_DISPATCH_JQ_LF:-unset}'"'"')"'
  local forced plain scrubbed
  # The CI leg exports the force knob for the whole job, so every arm sets or removes
  # it explicitly.
  forced="$(env PM_DISPATCH_TEST_FORCE_JQ_LF=1 bash -c "$probe" _ "$REPO_ROOT" 2>&1 | tail -n 1)"
  plain="$(env -u PM_DISPATCH_TEST_FORCE_JQ_LF bash -c "$probe" _ "$REPO_ROOT" 2>&1 | tail -n 1)"
  scrubbed="$(env -u PM_DISPATCH_TEST_FORCE_JQ_LF PM_DISPATCH_JQ_LF=1 bash -c "$probe" _ "$REPO_ROOT" 2>&1 | tail -n 1)"
  [[ "$forced" == "yes 1 1" ]] || { fail "$name" "with the force knob: expected 'yes 1 1' (function, knob, knob in a child), got '$forced'"; return; }
  [[ "$plain" == "no unset unset" ]] || { fail "$name" "without it: expected 'no unset unset', got '$plain'"; return; }
  [[ "$scrubbed" == "no unset unset" ]] || { fail "$name" "a caller's PM_DISPATCH_JQ_LF must still be scrubbed: expected 'no unset unset', got '$scrubbed'"; return; }
  pass "$name"
}

# Behavior: cli/pmctl and runtime/bin/pr-gate.sh source the library when they
# start, so a gate or a pmctl command on native Windows gets LF from jq. Nothing
# else would notice one of them dropping the line.
# Steps: run each with bash -x and an invocation that exits early (pmctl --help,
# pr-gate with an unknown option) and look for the traced `. .../jq-lf.sh`.
case_jq_lf_is_sourced_by_pmctl_and_pr_gate() {
  local name="jq-lf-is-sourced-by-pmctl-and-pr-gate"
  should_run "$name" || return 0
  local trace repo="$TMP_DIR/wiring-repo"
  trace="$(bash -x "$REPO_ROOT/cli/pmctl" --help 2>&1 >/dev/null || true)"
  # A single leading "+" is the main shell: a source inside a subshell traces with
  # "++" and would not make the function visible to the rest of the script.
  grep -qE '^\+ \. .*jq-lf\.sh' <<<"$trace" || { fail "$name" "cli/pmctl did not source jq-lf.sh in its main shell"; return; }
  git init -q "$repo"
  trace="$(bash -x "$REPO_ROOT/runtime/bin/pr-gate.sh" --cd "$repo" --no-such-option 2>&1 || true)"
  grep -qE '^\+ \. .*jq-lf\.sh' <<<"$trace" || { fail "$name" "runtime/bin/pr-gate.sh did not source jq-lf.sh in its main shell"; return; }
  pass "$name"
}

# _jq_argv_for <ostype> <jq-args...>: run the shim against a stub jq that records its argv and the
# MSYS2_ARG_CONV_EXCL it was started with, and a stub cygpath that prefixes M: (so a converted word
# is visible and a call is countable). Prints "<args joined by |> EXCL=<value>" and appends one line
# per cygpath call to $TMP_DIR/cygpath.calls.
_jq_argv_for() {
  local ostype="$1"; shift
  local stubs="$TMP_DIR/argv-stubs"
  mkdir -p "$stubs"
  cat > "$stubs/jq" <<EOF
#!/bin/sh
out=""
for a in "\$@"; do out="\$out|\$a"; done
printf '%s EXCL=%s\n' "\$out" "\${MSYS2_ARG_CONV_EXCL-unset}"
EOF
  cat > "$stubs/cygpath" <<EOF
#!/bin/sh
echo "\$*" >> "$TMP_DIR/cygpath.calls"
shift 2
printf 'M:%s\n' "\$1"
EOF
  chmod +x "$stubs/jq" "$stubs/cygpath"
  (
    unset -f jq
    PATH="$stubs:$PATH"
    export PM_DISPATCH_JQ_LF=1
    # No mount table unless the caller names one: such words go to the stub cygpath.
    export PM_DISPATCH_JQ_LF_MOUNTS="${JQ_TEST_MOUNTS:-$TMP_DIR/no-such-mount-table}"
    OSTYPE="$ostype"
    # shellcheck disable=SC1090
    . "$LIB"
    jq "$@"
  )
}

# Behavior (GitHub issue #590): the jq() shim leaves every string value alone and turns only the
# words that are file names into a form a native program can open. A value given to --arg or
# --argjson, a word after --args, the program text and the number after --indent stay exactly as
# given; the input files, the program file after -f / -nf, and the FILE of --rawfile / --slurpfile
# are converted; the whole call runs with MSYS2_ARG_CONV_EXCL='*'.
# Steps: with the shim forced on, OSTYPE=linux (so the drive-letter shortcut is off) and a stub
# cygpath that prefixes M:, call it with each kind of word and compare the argv the stub jq saw.
# shellcheck disable=SC2016  # '$x' and '$ARGS.positional' are jq variables inside single quotes, not shell expansions
case_jq_lf_keeps_string_values_and_converts_file_operands() {
  local name="jq-lf-keeps-string-values-and-converts-file-operands"
  should_run "$name" || return 0
  local got want
  : > "$TMP_DIR/cygpath.calls"
  got="$(_jq_argv_for linux -n --arg repo /c/r --argjson j '"/c/j"' --rawfile raw /c/f/raw.txt \
    --slurpfile sl /c/f/s.json -c '$x' /c/f/in.json rel.json -)"
  want='|-b|-n|--arg|repo|/c/r|--argjson|j|"/c/j"|--rawfile|raw|M:/c/f/raw.txt|--slurpfile|sl|M:/c/f/s.json|-c|$x|M:/c/f/in.json|rel.json|- EXCL=*'
  [[ "$got" == "$want" ]] || { fail "$name" "values/files: got [$got] want [$want]"; return; }

  got="$(_jq_argv_for linux -f /c/p.jq /c/in.json)"
  [[ "$got" == '|-b|-f|M:/c/p.jq|M:/c/in.json EXCL=*' ]] || { fail "$name" "-f: got [$got]"; return; }
  got="$(_jq_argv_for linux -nf /c/p.jq)"
  [[ "$got" == '|-b|-nf|M:/c/p.jq EXCL=*' ]] || { fail "$name" "-nf cluster: got [$got]"; return; }
  got="$(_jq_argv_for linux --from-file /c/p.jq)"
  [[ "$got" == '|-b|--from-file|M:/c/p.jq EXCL=*' ]] || { fail "$name" "--from-file: got [$got]"; return; }
  got="$(_jq_argv_for linux -n '$ARGS.positional' --args /c/a /tmp/b)"
  [[ "$got" == '|-b|-n|$ARGS.positional|--args|/c/a|/tmp/b EXCL=*' ]] || { fail "$name" "--args: got [$got]"; return; }
  got="$(_jq_argv_for linux -n -- '.x' /c/file)"
  [[ "$got" == '|-b|-n|--|.x|M:/c/file EXCL=*' ]] || { fail "$name" "--: got [$got]"; return; }
  got="$(_jq_argv_for linux --indent 2 -c '/c/looks/like/a/path' //server/share/f)"
  [[ "$got" == '|-b|--indent|2|-c|/c/looks/like/a/path|//server/share/f EXCL=*' ]] || { fail "$name" "program/UNC/indent: got [$got]"; return; }
  # A value and a file operand under the same directory: only the file is converted.
  got="$(_jq_argv_for linux --arg repo /c/repo -c '.' /c/repo/data.json)"
  [[ "$got" == '|-b|--arg|repo|/c/repo|-c|.|M:/c/repo/data.json EXCL=*' ]] || { fail "$name" "same-dir: got [$got]"; return; }
  # Missing operands are passed through for jq to report, not swallowed or looped on.
  got="$(_jq_argv_for linux --arg onlyname)"
  [[ "$got" == '|-b|--arg|onlyname EXCL=*' ]] || { fail "$name" "missing operand: got [$got]"; return; }
  # After `--` a word that looks like a flag is a program / file, not a flag: --arg is not consumed.
  got="$(_jq_argv_for linux -n -- --arg /c/v)"
  [[ "$got" == '|-b|-n|--|--arg|M:/c/v EXCL=*' ]] || { fail "$name" "-- then flag-like word: got [$got]"; return; }
  got="$(_jq_argv_for linux -n '$ARGS.positional' --jsonargs 1 /c/a)"
  [[ "$got" == '|-b|-n|$ARGS.positional|--jsonargs|1|/c/a EXCL=*' ]] || { fail "$name" "--jsonargs: got [$got]"; return; }
  got="$(_jq_argv_for linux -sRf /c/p.jq /c/in.txt)"
  [[ "$got" == '|-b|-sRf|M:/c/p.jq|M:/c/in.txt EXCL=*' ]] || { fail "$name" "-sRf cluster: got [$got]"; return; }
  # -L / --library-path name a directory the native jq opens: converted, in all three spellings,
  # and an attached -L<dir> containing an f does not turn the first positional into a program file.
  got="$(_jq_argv_for linux -n -L /c/lib --library-path /c/lib2 'include "m"; f')"
  [[ "$got" == '|-b|-n|-L|M:/c/lib|--library-path|M:/c/lib2|include "m"; f EXCL=*' ]] || { fail "$name" "-L separate: got [$got]"; return; }
  got="$(_jq_argv_for linux -n -L/c/foo '/c/x' /c/in.json)"
  [[ "$got" == '|-b|-n|-L|M:/c/foo|/c/x|M:/c/in.json EXCL=*' ]] || { fail "$name" "-L attached: got [$got]"; return; }
  pass "$name"
}

# Behavior: under an msys / cygwin OSTYPE a word of the form /X or /X/... (one letter, the drive
# mount) becomes X:/... in the shell itself, without starting cygpath; any other absolute Unix path
# goes through cygpath -m once; a relative word and a UNC word are left alone.
# Steps: force the shim on with OSTYPE=msys and the stub cygpath, call it with a drive path, the bare
# drive, /tmp and a relative word, and count the stub's calls.
case_jq_lf_converts_drive_paths_without_starting_cygpath() {
  local name="jq-lf-converts-drive-paths-without-starting-cygpath"
  should_run "$name" || return 0
  local got calls
  : > "$TMP_DIR/cygpath.calls"
  got="$(_jq_argv_for msys -c . /c/Users/x/in.json /d /tmp/y rel/z)"
  calls="$(wc -l < "$TMP_DIR/cygpath.calls" | tr -d ' ')"
  [[ "$got" == '|-b|-c|.|c:/Users/x/in.json|d:/|M:/tmp/y|rel/z EXCL=*' || "$got" == '|-b|-c|.|C:/Users/x/in.json|D:/|M:/tmp/y|rel/z EXCL=*' ]] \
    || { fail "$name" "got [$got]"; return; }
  [[ "$calls" == 1 ]] || { fail "$name" "expected one cygpath call (for /tmp/y), saw $calls: $(tr '\n' ';' < "$TMP_DIR/cygpath.calls")"; return; }
  # Cygwin mounts drives under /cygdrive, so /c/x there is an ordinary directory: it goes to cygpath.
  got="$(_jq_argv_for cygwin -c . /c/Users/x/in.json)"
  [[ "$got" == '|-b|-c|.|M:/c/Users/x/in.json EXCL=*' ]] || { fail "$name" "cygwin: got [$got]"; return; }
  pass "$name"
}

# Behavior: under an msys OSTYPE a word that lies under a mount other than / and the drives (/tmp is
# the user's %TEMP%, /bin the Git usr/bin) is converted from the mount table in the shell, without
# starting cygpath: the longest mount point wins, a mount point only counts at a path boundary, a
# native directory with spaces is kept whole, and the root mount, a missing table, any path under
# no mount, a word with dot segments / a doubled slash / a character NTFS cannot hold, a table line
# whose source is not a native directory, and any non-msys shell fall back to cygpath -m.
# Steps: write a mount table in the /proc/mounts layout, point PM_DISPATCH_JQ_LF_MOUNTS at it, call the
# shim with words under each kind of mount, and count the stub cygpath's calls.
case_jq_lf_converts_mount_paths_without_starting_cygpath() {
  local name="jq-lf-converts-mount-paths-without-starting-cygpath"
  should_run "$name" || return 0
  local table="$TMP_DIR/mounts.table" got calls
  cat > "$table" <<'TABLE'
C:/Program Files/Git / ntfs binary,noacl,auto 1 1
C:/Program Files/Git/usr/bin /bin ntfs binary,noacl,auto 1 1
C:/Users/me/AppData/Local/Temp /tmp ntfs binary,noacl,posix=0,usertemp 1 1
D:/scratch/deep /tmp/deep ntfs binary 1 1
C: /c ntfs binary,noacl,posix=0,user,noumount,auto 1 1
TABLE
  : > "$TMP_DIR/cygpath.calls"
  got="$(JQ_TEST_MOUNTS="$table" _jq_argv_for msys -c . /tmp/a.json /tmp /tmp/deep/b.json /bin/sh /tmpx/z /home/u/f)"
  calls="$(wc -l < "$TMP_DIR/cygpath.calls" | tr -d ' ')"
  [[ "$got" == '|-b|-c|.|C:/Users/me/AppData/Local/Temp/a.json|C:/Users/me/AppData/Local/Temp|D:/scratch/deep/b.json|C:/Program Files/Git/usr/bin/sh|M:/tmpx/z|M:/home/u/f EXCL=*' ]] \
    || { fail "$name" "got [$got]"; return; }
  [[ "$calls" == 2 ]] || { fail "$name" "expected cygpath for /tmpx/z and /home/u/f only, saw $calls: $(tr '\n' ';' < "$TMP_DIR/cygpath.calls")"; return; }
  # The longest mount point wins whichever line comes first.
  cat > "$table.reversed" <<'TABLE'
D:/scratch/deep /tmp/deep ntfs binary 1 1
C:/Users/me/AppData/Local/Temp /tmp ntfs binary,noacl,posix=0,usertemp 1 1
TABLE
  got="$(JQ_TEST_MOUNTS="$table.reversed" _jq_argv_for msys -c . /tmp/deep/b.json /tmp/a.json)"
  [[ "$got" == '|-b|-c|.|D:/scratch/deep/b.json|C:/Users/me/AppData/Local/Temp/a.json EXCL=*' ]]     || { fail "$name" "reversed table: got [$got]"; return; }
  # Words cygpath would normalise or map stay with cygpath: dot segments (also across a mount, where a
  # string rewrite would give another file), a doubled slash, characters NTFS cannot hold in a name.
  : > "$TMP_DIR/cygpath.calls"
  got="$(JQ_TEST_MOUNTS="$table" _jq_argv_for msys -c . /tmp/../etc/x /bin/../etc/x /tmp/./x /tmp/. /tmp/.. /tmp//x /tmp/a:b '/tmp/a*b' '/tmp/a?b' /tmp/ok)"
  [[ "$got" == '|-b|-c|.|M:/tmp/../etc/x|M:/bin/../etc/x|M:/tmp/./x|M:/tmp/.|M:/tmp/..|M:/tmp//x|M:/tmp/a:b|M:/tmp/a*b|M:/tmp/a?b|C:/Users/me/AppData/Local/Temp/ok EXCL=*' ]] \
    || { fail "$name" "normalised/mapped words: got [$got]"; return; }
  # Table layouts: CRLF line ends, no newline after the last line, a native directory with a trailing
  # slash, a source that is not a native directory, a line with too few fields, a leading space, blank.
  printf 'C:/Program Files/Git / ntfs binary 1 1\r\nC:/T/ /mm ntfs binary 1 1\r\nnone /cygdrive cygdrive binary 0 0\r\n/tmp\r\n /bad ntfs b 1 1\r\n\r\nD:/last /last ntfs binary 1 1' > "$table.layouts"
  got="$(JQ_TEST_MOUNTS="$table.layouts" _jq_argv_for msys -c . /mm/x /cygdrive/c/x /tmp/x /bad/x /last/y)"
  [[ "$got" == '|-b|-c|.|C:/T/x|M:/cygdrive/c/x|M:/tmp/x|M:/bad/x|D:/last/y EXCL=*' ]] \
    || { fail "$name" "table layouts: got [$got]"; return; }
  # Only an msys shell reads the table: elsewhere /tmp is an ordinary directory.
  got="$(JQ_TEST_MOUNTS="$table" _jq_argv_for linux -c . /tmp/a.json)"
  [[ "$got" == '|-b|-c|.|M:/tmp/a.json EXCL=*' ]] || { fail "$name" "linux read the table: got [$got]"; return; }
  got="$(JQ_TEST_MOUNTS="$table" _jq_argv_for cygwin -c . /tmp/a.json)"
  [[ "$got" == '|-b|-c|.|M:/tmp/a.json EXCL=*' ]] || { fail "$name" "cygwin read the table: got [$got]"; return; }
  # No table at all: every non-drive word goes to cygpath.
  : > "$TMP_DIR/cygpath.calls"
  got="$(JQ_TEST_MOUNTS="$TMP_DIR/absent" _jq_argv_for msys -c . /tmp/a.json)"
  [[ "$got" == '|-b|-c|.|M:/tmp/a.json EXCL=*' ]] || { fail "$name" "no table: got [$got]"; return; }
  pass "$name"
}

# Behavior (the point of the change, meaningful on a native Windows jq): a file under /tmp opens with the
# real jq without starting cygpath, and a file under no mount still opens through cygpath.
# Steps: put a counting cygpath first on PATH, run the real jq on a file under /tmp, and compare the count.
case_jq_lf_real_jq_opens_tmp_file_without_cygpath() {
  local name="jq-lf-real-jq-opens-tmp-file-without-cygpath"
  should_run "$name" || return 0
  if [[ "${OSTYPE:-}" != msys* ]]; then
    skip "$name" "only native Git Bash maps /tmp to a Windows directory through the mount table"
    return 0
  fi
  command -v jq >/dev/null 2>&1 || { skip "$name" "host has no jq"; return 0; }
  local f got calls stubs="$TMP_DIR/count-cygpath"
  f="$(mktemp /tmp/jqlf-real.XXXXXX)"
  printf '{"a":7}\n' > "$f"
  mkdir -p "$stubs"
  cat > "$stubs/cygpath" <<EOF
#!/bin/sh
echo x >> "$TMP_DIR/real-cygpath.calls"
exec "$(command -v cygpath)" "\$@"
EOF
  chmod +x "$stubs/cygpath"
  : > "$TMP_DIR/real-cygpath.calls"
  got="$(
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    PATH="$stubs:$PATH"
    # shellcheck disable=SC1090
    . "$LIB"
    jq -c .a "$f" | tr -d '\r'
  )"
  calls="$(wc -l < "$TMP_DIR/real-cygpath.calls" | tr -d ' ')"
  rm -f "$f"
  [[ "$got" == 7 ]] || { fail "$name" "the file under /tmp did not open: [$got]"; return; }
  [[ "$calls" == 0 ]] || { fail "$name" "cygpath was started $calls time(s) for a file under /tmp"; return; }
  # Positive control: a file under no mount still goes through cygpath once, so a count of 0 above
  # really means "not started" and not "the counting wrapper was never reached".
  : > "$TMP_DIR/real-cygpath.calls"
  got="$(
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    PATH="$stubs:$PATH"
    # shellcheck disable=SC1090
    . "$LIB"
    jq -R -n -c '[inputs] | length > 0' /etc/profile | tr -d '\r'
  )"
  calls="$(wc -l < "$TMP_DIR/real-cygpath.calls" | tr -d ' ')"
  [[ "$got" == true ]] || { fail "$name" "a file under no mount did not open: [$got]"; return; }
  [[ "$calls" == 1 ]] || { fail "$name" "expected one cygpath for a file under no mount, saw $calls"; return; }
  pass "$name"
}

# Behavior (the point of #590, meaningful on a native Windows jq): with the real jq, a path-shaped
# --arg / --argjson / --args value comes back byte for byte, while every way of naming a file --
# an input file, -f, -nf, --rawfile, --slurpfile -- still opens it, including in one call that also
# carries a path value from the same directory. On Linux nothing is converted either way, so the
# same assertions hold there.
# Steps: write small files under a temp directory, run each form against the real jq, compare.
case_jq_lf_real_jq_keeps_path_values_and_opens_files() {
  local name="jq-lf-real-jq-keeps-path-values-and-opens-files"
  should_run "$name" || return 0
  command -v jq >/dev/null 2>&1 || { skip "$name" "host has no jq"; return 0; }
  if ! jq -b -n 1 >/dev/null 2>&1; then
    if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
      fail "$name" "this jq rejects -b"; return
    fi
    skip "$name" "this jq rejects -b (Linux jq 1.6); the shim is not defined here"; return 0
  fi
  local d="$TMP_DIR/real-jq-files" got
  mkdir -p "$d"
  printf '{"a":1}\n' > "$d/in.json"
  printf '.a + 41\n' > "$d/prog.jq"
  printf 'raw text\n' > "$d/raw.txt"
  printf '{"s":2}\n' > "$d/slurp.json"
  (
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    # shellcheck disable=SC1090
    . "$LIB"
    got="$(jq -n --arg p "$d" '$p' | tr -d '\r')"
    [[ "$got" == "\"$d\"" ]] || { echo "--arg value changed: got [$got] want [\"$d\"]"; exit 1; }
    got="$(jq -n --arg p /c/Users/x '$p' | tr -d '\r')"
    [[ "$got" == '"/c/Users/x"' ]] || { echo "--arg /c value changed: [$got]"; exit 1; }
    got="$(jq -n --arg p /tmp/x '$p' | tr -d '\r')"
    [[ "$got" == '"/tmp/x"' ]] || { echo "--arg /tmp value changed: [$got]"; exit 1; }
    got="$(jq -nc --argjson v '"/c/a"' '$v' | tr -d '\r')"
    [[ "$got" == '"/c/a"' ]] || { echo "--argjson value changed: [$got]"; exit 1; }
    got="$(jq -nc '$ARGS.positional' --args /c/a /tmp/b | tr -d '\r')"
    [[ "$got" == '["/c/a","/tmp/b"]' ]] || { echo "--args values changed: [$got]"; exit 1; }
    got="$(jq -c . "$d/in.json" | tr -d '\r')"
    [[ "$got" == '{"a":1}' ]] || { echo "input file did not open: [$got]"; exit 1; }
    got="$(jq -f "$d/prog.jq" "$d/in.json" | tr -d '\r')"
    [[ "$got" == 42 ]] || { echo "-f program file: [$got]"; exit 1; }
    got="$(jq -nf "$d/prog.jq" | tr -d '\r')"
    [[ "$got" == 41 ]] || { echo "-nf program file: [$got]"; exit 1; }
    got="$(jq -nc --rawfile r "$d/raw.txt" '$r' | tr -d '\r')"
    [[ "$got" == '"raw text\n"' ]] || { echo "--rawfile: [$got]"; exit 1; }
    got="$(jq -nc --slurpfile s "$d/slurp.json" '$s' | tr -d '\r')"
    [[ "$got" == '[{"s":2}]' ]] || { echo "--slurpfile: [$got]"; exit 1; }
    got="$(jq --arg repo "$d" -c '[$repo,.a]' "$d/in.json" | tr -d '\r')"
    [[ "$got" == "[\"$d\",1]" ]] || { echo "value + file in one call: [$got]"; exit 1; }
    mkdir -p "$d/lib"; printf 'def libf: 5;\n' > "$d/lib/m.jq"
    got="$(jq -n -L "$d/lib" 'include "m"; libf' | tr -d '\r')"
    [[ "$got" == 5 ]] || { echo "-L library dir: [$got]"; exit 1; }
    got="$(printf '{"x":3}' | jq -c . | tr -d '\r')"
    [[ "$got" == '{"x":3}' ]] || { echo "stdin: [$got]"; exit 1; }
  ) > "$TMP_DIR/real-jq.out" 2>&1 || { fail "$name" "$(<"$TMP_DIR/real-jq.out")"; return; }
  pass "$name"
}

case_jq_lf_defines_the_function_only_where_needed
case_jq_lf_adds_binary_flag_and_preserves_arguments
case_jq_lf_sourcing_is_free_and_leaves_options_alone
case_jq_lf_is_not_defined_when_jq_is_missing
case_jq_lf_is_loaded_by_th_init
case_jq_lf_test_force_knob_enables_the_shim
case_jq_lf_is_sourced_by_pmctl_and_pr_gate
case_jq_lf_real_jq_writes_lf_and_matches_the_linux_digest
case_jq_lf_keeps_string_values_and_converts_file_operands
case_jq_lf_converts_drive_paths_without_starting_cygpath
case_jq_lf_converts_mount_paths_without_starting_cygpath
case_jq_lf_real_jq_opens_tmp_file_without_cygpath
case_jq_lf_real_jq_keeps_path_values_and_opens_files

th_summary
