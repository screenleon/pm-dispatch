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

# Behavior: with the shim on, an existence check still works and the program path
# is still reachable; `command -v jq` returns the function name, so callers that
# need a path use `type -P jq` (documented in the library header).
# Steps: force the shim on, run `command -v jq` quietly, print `type -P jq`, and
# check it is an absolute path to an executable that is not the bare word jq.
case_jq_lf_existence_checks_and_program_path() {
  local name="jq-lf-existence-checks-and-program-path"
  should_run "$name" || return 0
  local path
  (
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    # shellcheck disable=SC1090
    . "$LIB"
    command -v jq >/dev/null 2>&1
  ) || { fail "$name" "command -v jq failed with the shim on"; return; }
  path="$(
    unset -f jq
    export PM_DISPATCH_JQ_LF=1
    # shellcheck disable=SC1090
    . "$LIB"
    type -P jq
  )"
  [[ "$path" != jq && -x "$path" ]] || { fail "$name" "type -P jq returned '$path'"; return; }
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
# Steps: run a clean bash that sets OSTYPE, sources the harness, calls th_init, and
# check whether a jq function exists: yes for msys, no for linux-gnu.
case_jq_lf_is_loaded_by_th_init() {
  local name="jq-lf-is-loaded-by-th-init"
  should_run "$name" || return 0
  local ostype want got
  for ostype in msys linux-gnu; do
    want=no; [[ "$ostype" == msys ]] && want=yes
    got="$(bash -c 'OSTYPE="$1"; . "$2/tests/lib/test-harness.sh"; th_init; if declare -F jq >/dev/null; then echo yes; else echo no; fi' _ "$ostype" "$REPO_ROOT" 2>&1 | tail -n 1)"
    [[ "$got" == "$want" ]] || { fail "$name" "OSTYPE=$ostype: expected $want, got '$got'"; return; }
  done
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
  grep -qE '^\++ \. .*jq-lf\.sh' <<<"$trace" || { fail "$name" "cli/pmctl did not source jq-lf.sh"; return; }
  git init -q "$repo"
  trace="$(bash -x "$REPO_ROOT/runtime/bin/pr-gate.sh" --cd "$repo" --no-such-option 2>&1 || true)"
  grep -qE '^\++ \. .*jq-lf\.sh' <<<"$trace" || { fail "$name" "runtime/bin/pr-gate.sh did not source jq-lf.sh"; return; }
  pass "$name"
}

case_jq_lf_defines_the_function_only_where_needed
case_jq_lf_adds_binary_flag_and_preserves_arguments
case_jq_lf_sourcing_is_free_and_leaves_options_alone
case_jq_lf_is_not_defined_when_jq_is_missing
case_jq_lf_existence_checks_and_program_path
case_jq_lf_is_loaded_by_th_init
case_jq_lf_is_sourced_by_pmctl_and_pr_gate
case_jq_lf_real_jq_writes_lf_and_matches_the_linux_digest

th_summary
