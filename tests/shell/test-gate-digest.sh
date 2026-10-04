#!/usr/bin/env bash
# Unit tests for runtime/lib/gate-digest.sh (CC-611).

# Several cases change PATH on purpose inside a subshell (to hide or stub a
# digest tool) and never expect the change to reach the parent shell.
# shellcheck disable=SC2030,SC2031
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB="$REPO_ROOT/runtime/lib/gate-digest.sh"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

EMPTY_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
ABC_SHA="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Independent oracle: the host's own tool, not the library under test.
_oracle() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

# Source the library afresh (which resets its state) and, in "init" mode, choose
# the digest tool as pr-gate.sh does.  "no-init" is the slow path every other
# caller of the library takes.
# usage: _load_lib <init|no-init>
_load_lib() {
  # shellcheck disable=SC1090
  . "$LIB"
  if [[ "$1" == init ]]; then
    gate_digest_init
  fi
}

# A directory holding a `<tool>` stub that appends "<tool> <args>" to $log and
# then runs the real tool, so a case can count how many times a tool was started.
# usage: _counting_stub_dir <dir> <log> <tool>...
_counting_stub_dir() {
  local dir="$1" log="$2" tool real
  shift 2
  mkdir -p "$dir"
  : > "$log"
  for tool in "$@"; do
    real="$(command -v "$tool" || true)"
    [[ -n "$real" ]] || continue
    printf '#!/bin/sh\necho "%s $*" >> "%s"\nexec "%s" "$@"\n' "$tool" "$log" "$real" > "$dir/$tool"
    chmod +x "$dir/$tool"
  done
}

# Behavior: gate_digest_stream prints the SHA-256 of stdin as 64 lowercase hex
# characters and a newline, however it is called: with a redirect, in a pipe,
# or inside a command substitution (where most gate code calls it); and
# gate_digest_file prints the same for a file. This holds both after
# gate_digest_init and without it (the slow path other callers take).
# Steps: feed the empty string and "abc" (published test vectors, so the
# expectation does not depend on the host's tool) through every call shape, in
# both modes.
case_gate_digest_known_vectors_in_every_call_shape() {
  local name="gate-digest-known-vectors-in-every-call-shape"
  should_run "$name" || return 0
  local empty="$TMP_DIR/empty" abc="$TMP_DIR/abc" got mode
  : > "$empty"
  printf 'abc' > "$abc"
  for mode in init no-init; do
    _load_lib "$mode"
    got="$(gate_digest_stream < "$empty")"
    [[ "$got" == "$EMPTY_SHA" ]] || { fail "$name" "$mode: empty via redirect: '$got'"; return; }
    got="$(printf 'abc' | gate_digest_stream)"
    [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "$mode: abc via pipe: '$got'"; return; }
    got="$(gate_digest_stream < "$abc")"
    [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "$mode: abc via redirect: '$got'"; return; }
    got="$(gate_digest_file "$abc")"
    [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "$mode: abc via gate_digest_file: '$got'"; return; }
    # The raw output is one line: the digest and a single newline.  The trailing
    # "x" keeps the command substitution from stripping that newline.
    got="$(gate_digest_stream < "$abc"; printf x)"
    [[ "$got" == "${ABC_SHA}"$'\n'x ]] || { fail "$name" "$mode: raw output is not exactly <digest> and a newline"; return; }
  done
  pass "$name"
}

# Behavior: the digest equals the host tool's for input that tends to break
# text handling: NUL bytes, a missing trailing newline, CRLF, high bytes, and
# input large enough to span many pipe buffers.
# Steps: build each input as a file, hash it with the independent oracle and
# with gate_digest_stream and gate_digest_file in both modes, and compare.
case_gate_digest_matches_oracle_on_awkward_input() {
  local name="gate-digest-matches-oracle-on-awkward-input"
  should_run "$name" || return 0
  local f want got4 got5 label mode
  printf '\000\001\002\377\n\000' > "$TMP_DIR/binary"
  printf 'no trailing newline' > "$TMP_DIR/no-nl"
  printf 'crlf\r\nline\r\n' > "$TMP_DIR/crlf"
  printf '\n\n\n' > "$TMP_DIR/newlines"
  seq 1 200000 > "$TMP_DIR/big"
  for mode in init no-init; do
    _load_lib "$mode"
    for label in binary no-nl crlf newlines big; do
      f="$TMP_DIR/$label"
      want="$(_oracle < "$f")"
      got4="$(gate_digest_stream < "$f")"
      got5="$(gate_digest_file "$f")"
      [[ "$got4" == "$want" ]] || { fail "$name" "$mode $label: stream '$got4' != oracle '$want'"; return; }
      [[ "$got5" == "$want" ]] || { fail "$name" "$mode $label: file '$got5' != oracle '$want'"; return; }
    done
  done
  pass "$name"
}

# Behavior: gate_digest_file refuses a missing argument or a missing file with
# status 2 and prints nothing, with or without gate_digest_init. (What it prints
# for a directory depends on the digest tool and is not pinned.)
# Steps: call it with no argument, an empty argument and a missing file in both
# modes; capture stdout and the status.
case_gate_digest_file_rejects_unreadable_input() {
  local name="gate-digest-file-rejects-unreadable-input"
  should_run "$name" || return 0
  local out rc arg mode
  for mode in init no-init; do
    _load_lib "$mode"
    for arg in "" "$TMP_DIR/does-not-exist"; do
      rc=0; out="$(gate_digest_file "$arg" 2>/dev/null)" || rc=$?
      [[ "$rc" -eq 2 && -z "$out" ]] || { fail "$name" "$mode arg '$arg': rc=$rc out='$out'"; return; }
    done
    rc=0; out="$(gate_digest_file 2>/dev/null)" || rc=$?
    [[ "$rc" -eq 2 && -z "$out" ]] || { fail "$name" "$mode no argument: rc=$rc out='$out'"; return; }
  done
  pass "$name"
}

# Behavior: after gate_digest_init a closed stdout does not change the status:
# gate_digest_stream still returns 0, as the old `tool | awk; return 0` did when
# awk only warned, so a `set -e` caller is not stopped by the failed write. (The
# original path, taken without gate_digest_init, is the old `tool | awk` and
# keeps whatever awk's exit status does under `set -e` + `pipefail`; it is not
# asserted here.)
# Steps: in a `set -e` subshell digest "abc" directly (not in an `||` list, where
# `set -e` is ignored) with stdout closed (`>&-`) and require that the next
# command still runs.
case_gate_digest_stream_status_ignores_a_closed_stdout() {
  local name="gate-digest-stream-status-ignores-a-closed-stdout"
  should_run "$name" || return 0
  local out
  printf 'abc' > "$TMP_DIR/abc"
  out="$(
    set -e
    _load_lib init
    gate_digest_stream < "$TMP_DIR/abc" >&- 2>/dev/null
    echo survived
  )"
  [[ "$out" == survived ]] || { fail "$name" "a closed stdout stopped a set -e caller: '$out'"; return; }
  pass "$name"
}

# Behavior: (CC-611) after gate_digest_init a digest starts the digest tool
# exactly once and never starts awk. The old code probed the tool on every call
# (a subshell plus the tool) and then piped through awk, four processes where
# one is needed; a gate makes dozens of digests and each process costs ~40 ms on
# native Windows.
# Steps: put counting stubs for sha256sum and awk first on PATH, source the
# library and call gate_digest_init, record the count, then make five digests
# (three stream, two file) and assert exactly five more sha256sum starts and no
# awk.
case_gate_digest_starts_one_tool_process_per_digest() {
  local name="gate-digest-starts-one-tool-process-per-digest"
  should_run "$name" || return 0
  command -v sha256sum >/dev/null 2>&1 || { skip "$name" "host has no sha256sum"; return 0; }
  local stubs="$TMP_DIR/count-stubs" log="$TMP_DIR/count.log" before after awk_n
  _counting_stub_dir "$stubs" "$log" sha256sum awk
  printf 'abc' > "$TMP_DIR/abc"
  (
    PATH="$stubs:$PATH"
    _load_lib init
    before="$(grep -c '^sha256sum ' "$log" || true)"
    gate_digest_stream < "$TMP_DIR/abc" > /dev/null
    printf 'abc' | gate_digest_stream > /dev/null
    x="$(gate_digest_stream < "$TMP_DIR/abc")"
    gate_digest_file "$TMP_DIR/abc" > /dev/null
    y="$(gate_digest_file "$TMP_DIR/abc")"
    [[ "$x" == "$ABC_SHA" && "$y" == "$ABC_SHA" ]] || exit 3
    after="$(grep -c '^sha256sum ' "$log" || true)"
    awk_n="$(grep -c '^awk ' "$log" || true)"
    printf '%s %s %s\n' "$before" "$after" "$awk_n" > "$TMP_DIR/counts"
  ) || { fail "$name" "digests inside the counting subshell failed"; return; }
  read -r before after awk_n < "$TMP_DIR/counts"
  [[ "$((after - before))" -eq 5 ]] || \
    { fail "$name" "expected 5 sha256sum starts for 5 digests, got $((after - before)) (probe per call?)"; return; }
  [[ "$awk_n" -eq 0 ]] || { fail "$name" "awk was started $awk_n time(s); the digest no longer needs it"; return; }
  pass "$name"
}

# Behavior: (CC-611) sourcing the library starts no process at all; only
# gate_digest_init probes. Every pmctl command loads the gate libraries, most of
# them never digest, and each process costs ~40 ms on native Windows.
# Steps: put counting stubs for sha256sum, shasum and awk first on PATH, source
# the library and assert no tool was started, then call gate_digest_init and
# assert that it did start one (so the stubs are live and the zero above is real).
case_gate_digest_sourcing_starts_no_process() {
  local name="gate-digest-sourcing-starts-no-process"
  should_run "$name" || return 0
  command -v sha256sum >/dev/null 2>&1 || { skip "$name" "host has no sha256sum"; return 0; }
  local stubs="$TMP_DIR/source-stubs" log="$TMP_DIR/source.log" sourced init_n
  _counting_stub_dir "$stubs" "$log" sha256sum shasum awk
  (
    PATH="$stubs:$PATH"
    # shellcheck disable=SC1090
    . "$LIB"
    sourced="$(wc -l < "$log")"
    gate_digest_init
    init_n="$(wc -l < "$log")"
    printf '%s %s\n' "$sourced" "$init_n" > "$TMP_DIR/source-counts"
  ) || { fail "$name" "sourcing or initialising inside the subshell failed"; return; }
  read -r sourced init_n < "$TMP_DIR/source-counts"
  [[ "$((sourced + 0))" -eq 0 ]] || \
    { fail "$name" "sourcing started $((sourced + 0)) tool process(es); it must start none"; return; }
  [[ "$((init_n + 0))" -ge 1 ]] || { fail "$name" "gate_digest_init started no tool, so the stubs are not live"; return; }
  pass "$name"
}

# Behavior: when no digest tool is usable the library reports it the same way
# as before: status 2 and the "no sha256sum or shasum" error on stderr, nothing
# on stdout. This holds when the tool disappears after initialisation (PATH
# changed) and when it was never there, with or without gate_digest_init.
# Steps: for each mode, source with a normal PATH and then empty PATH; separately
# source with an empty PATH; call gate_digest_stream and gate_digest_file.
case_gate_digest_reports_missing_tool() {
  local name="gate-digest-reports-missing-tool"
  should_run "$name" || return 0
  local empty_bin="$TMP_DIR/empty-bin" out err rc mode when
  mkdir -p "$empty_bin"
  printf 'abc' > "$TMP_DIR/abc"
  for mode in init no-init; do
    for when in late-empty never-there; do
      rc=0
      out="$(
        if [[ "$when" == never-there ]]; then PATH="$empty_bin"; fi
        _load_lib "$mode"
        PATH="$empty_bin"
        gate_digest_stream < "$TMP_DIR/abc" 2> "$TMP_DIR/err"
      )" || rc=$?
      err="$(cat "$TMP_DIR/err")"
      [[ "$rc" -eq 2 && -z "$out" && "$err" == *"no sha256sum or shasum found"* ]] || \
        { fail "$name" "$mode $when stream: rc=$rc out='$out' err='$err'"; return; }
      rc=0
      out="$(
        if [[ "$when" == never-there ]]; then PATH="$empty_bin"; fi
        _load_lib "$mode"
        PATH="$empty_bin"
        gate_digest_file "$TMP_DIR/abc" 2> "$TMP_DIR/err"
      )" || rc=$?
      err="$(cat "$TMP_DIR/err")"
      [[ "$rc" -eq 2 && -z "$out" && "$err" == *"no sha256sum or shasum found"* ]] || \
        { fail "$name" "$mode $when file: rc=$rc out='$out' err='$err'"; return; }
    done
  done
  pass "$name"
}

# Behavior: a sha256sum that is present but does not work is skipped in favour
# of shasum, as the per-call probe used to do, and with shasum remembered each
# digest is again one process and always runs `shasum -a 256`.
# Steps: put a sha256sum that always fails and a counting shasum (which runs the
# real tool) first on PATH, source the library and call gate_digest_init, then
# make three digests and check the values, the number of shasum starts, and that
# every start carried "-a 256".
case_gate_digest_falls_back_to_shasum_when_sha256sum_is_broken() {
  local name="gate-digest-falls-back-to-shasum-when-sha256sum-is-broken"
  should_run "$name" || return 0
  command -v sha256sum >/dev/null 2>&1 || { skip "$name" "host has no sha256sum to back the shasum stub"; return 0; }
  local stubs="$TMP_DIR/shasum-stubs" log="$TMP_DIR/shasum.log" real got before after bad
  real="$(command -v sha256sum)"
  mkdir -p "$stubs"; : > "$log"
  printf 'abc' > "$TMP_DIR/abc"
  printf '#!/bin/sh\nexit 1\n' > "$stubs/sha256sum"
  # shasum is called as `shasum -a 256`; log the arguments, then drop those two.
  printf '#!/bin/sh\necho "shasum $*" >> "%s"\nshift 2\nexec "%s" "$@"\n' "$log" "$real" > "$stubs/shasum"
  chmod +x "$stubs/sha256sum" "$stubs/shasum"
  got="$(
    PATH="$stubs:$PATH"
    _load_lib init
    wc -l < "$log" > "$TMP_DIR/shasum-before"
    printf 'abc' | gate_digest_stream
    x="$(gate_digest_stream < "$TMP_DIR/abc")"
    y="$(gate_digest_file "$TMP_DIR/abc")"
    printf '%s\n%s\n' "$x" "$y"
  )"
  before="$(($(cat "$TMP_DIR/shasum-before")))"
  after="$(wc -l < "$log")"
  [[ "$got" == "$ABC_SHA"$'\n'"$ABC_SHA"$'\n'"$ABC_SHA" ]] || { fail "$name" "digests via the shasum fallback: '$got'"; return; }
  [[ "$((after - before))" -eq 3 ]] || { fail "$name" "expected 3 shasum starts for 3 digests, got $((after - before))"; return; }
  bad="$(grep -vc '^shasum -a 256$' "$log" || true)"
  [[ "$bad" -eq 0 ]] || { fail "$name" "a shasum start did not carry '-a 256': $(cat "$log")"; return; }
  pass "$name"
}

# Behavior: (CC-629 c) a digest tool that fails is a failure, not an empty digest. A tool that breaks
# after gate_digest_init, one that fails only on real input (it still passes the probe of an empty
# stream), and one that prints something that is not a digest must make gate_digest_stream and
# gate_digest_file print NOTHING and return 2, in both modes (after init and the original slow path).
# Before CC-629 they printed nothing (or just a newline) and returned 0, which the callers written as
# `digest="$(...)" || return` could not see. (CC-611 had pinned that old behaviour as "not an
# endorsement, a change must be deliberate"; this is the deliberate change.)
# Steps: for each mode and each of three stubs first on PATH (always exits 1; exits 1 on non-empty
# input; prints "not-a-digest" and exits 0) digest "abc" as a stream and as a file and require status 2
# with no output; then require that under `set -eo pipefail` a failing stream stage in a pipeline stops
# the shell (a failed digest must not be skipped silently).
case_gate_digest_tool_failure_is_a_failure_in_both_modes() {
  local name="gate-digest-tool-failure-is-a-failure-in-both-modes"
  should_run "$name" || return 0
  command -v sha256sum >/dev/null 2>&1 || { skip "$name" "host has no sha256sum"; return 0; }
  local real bad_bin out rc mode stub
  real="$(command -v sha256sum)"
  printf 'abc' > "$TMP_DIR/abc"
  for stub in always-fails fails-on-input not-a-digest; do
    bad_bin="$TMP_DIR/bad-bin-$stub"
    mkdir -p "$bad_bin"
    case "$stub" in
      always-fails)
        printf '#!/bin/sh\nexit 1\n' > "$bad_bin/sha256sum" ;;
      fails-on-input)
        # passes the probe (`printf '' | sha256sum`) and fails on any real input
        printf '#!/bin/sh\ncat > "%s/in.$$"\nif [ -s "%s/in.$$" ]; then rm -f "%s/in.$$"; exit 1; fi\nrm -f "%s/in.$$"\nexec "%s" < /dev/null\n' \
          "$TMP_DIR" "$TMP_DIR" "$TMP_DIR" "$TMP_DIR" "$real" > "$bad_bin/sha256sum" ;;
      not-a-digest)
        # passes the probe and prints garbage for real input
        printf '#!/bin/sh\ncat > "%s/in.$$"\nif [ -s "%s/in.$$" ]; then rm -f "%s/in.$$"; echo "not-a-digest  -"; exit 0; fi\nrm -f "%s/in.$$"\nexec "%s" < /dev/null\n' \
          "$TMP_DIR" "$TMP_DIR" "$TMP_DIR" "$TMP_DIR" "$real" > "$bad_bin/sha256sum" ;;
    esac
    chmod +x "$bad_bin/sha256sum"
    for mode in init no-init; do
      if [[ "$stub" == always-fails && "$mode" == no-init ]]; then
        continue  # a tool that fails the probe is skipped, not used (covered by the shasum fallback case)
      fi
      # the probe (init) runs with the working tool; the breakage comes after it, as in a real run
      _load_lib "$mode"
      out="$(PATH="$bad_bin:$PATH" gate_digest_stream < "$TMP_DIR/abc" 2>/dev/null; printf x)"
      [[ "$out" == x ]] || { fail "$name" "$stub/$mode stream: expected no output, got '$out'"; return; }
      rc=0; PATH="$bad_bin:$PATH" gate_digest_stream < "$TMP_DIR/abc" >/dev/null 2>&1 || rc=$?
      [[ "$rc" -eq 2 ]] || { fail "$name" "$stub/$mode stream: expected status 2, got $rc"; return; }
      out="$(PATH="$bad_bin:$PATH" gate_digest_file "$TMP_DIR/abc" 2>/dev/null; printf x)"
      [[ "$out" == x ]] || { fail "$name" "$stub/$mode file: expected no output, got '$out'"; return; }
      rc=0; PATH="$bad_bin:$PATH" gate_digest_file "$TMP_DIR/abc" >/dev/null 2>&1 || rc=$?
      [[ "$rc" -eq 2 ]] || { fail "$name" "$stub/$mode file: expected status 2, got $rc"; return; }
    done
  done
  # a failed digest in a pipeline stage stops a `set -eo pipefail` shell: it is no longer skipped
  # (run in a child bash: inside an `||` list errexit would be ignored and the case would prove nothing)
  bad_bin="$TMP_DIR/bad-bin-always-fails"
  out="$(bash -c '
    set -eo pipefail
    . "$1"
    gate_digest_init
    PATH="$3:$PATH"
    gate_digest_stream < "$2" 2>/dev/null | cat
    echo after
  ' _ "$LIB" "$TMP_DIR/abc" "$bad_bin" 2>/dev/null)" || true
  [[ -z "$out" ]] || { fail "$name" "the shell went on after a failed digest: '$out'"; return; }
  pass "$name"
}

# Behavior: a fresh process that sources the library and never calls
# gate_digest_init works under `set -u` (the state variable exists after
# sourcing alone), and still digests correctly through the original path.
# Steps: run `bash -c` with nounset, source, digest "abc" from a pipe, and
# compare with the known vector.
case_gate_digest_fresh_process_without_init_works_under_set_u() {
  local name="gate-digest-fresh-process-without-init-works-under-set-u"
  should_run "$name" || return 0
  local got
  got="$(printf 'abc' | bash -c 'set -u; . "$1"; gate_digest_stream' _ "$LIB" 2>&1)"
  [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "got '$got'"; return; }
  pass "$name"
}

# Behavior: without gate_digest_init and with a broken sha256sum the original
# path still falls back to shasum and always runs `shasum -a 256` (a bare
# `shasum` would silently produce SHA-1).
# Steps: put a failing sha256sum and a logging shasum first on PATH, source the
# library without initialising, digest "abc", and check the value and the log.
case_gate_digest_original_path_falls_back_to_shasum_with_algorithm_flag() {
  local name="gate-digest-original-path-falls-back-to-shasum-with-algorithm-flag"
  should_run "$name" || return 0
  command -v sha256sum >/dev/null 2>&1 || { skip "$name" "host has no sha256sum to back the shasum stub"; return 0; }
  local stubs="$TMP_DIR/orig-stubs" log="$TMP_DIR/orig.log" real got bad
  real="$(command -v sha256sum)"
  mkdir -p "$stubs"; : > "$log"
  printf '#!/bin/sh\nexit 1\n' > "$stubs/sha256sum"
  printf '#!/bin/sh\necho "shasum $*" >> "%s"\nshift 2\nexec "%s" "$@"\n' "$log" "$real" > "$stubs/shasum"
  chmod +x "$stubs/sha256sum" "$stubs/shasum"
  got="$(
    PATH="$stubs:$PATH"
    _load_lib no-init
    printf 'abc' | gate_digest_stream
  )"
  [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "digest via the original shasum path: '$got'"; return; }
  bad="$(grep -vc '^shasum -a 256$' "$log" || true)"
  [[ -s "$log" && "$bad" -eq 0 ]] || { fail "$name" "shasum was not always run with -a 256: $(cat "$log")"; return; }
  pass "$name"
}

# Behavior: (CC-611) pr-gate.sh calls gate_digest_init, so a gate gets the
# one-process digests. Deleting that call would silently drop the whole speed-up
# and every other test would still pass.
# Steps: run pr-gate.sh with an unknown option, which it rejects after the
# bootstrap and before any digest, with a counting sha256sum first on PATH, and
# assert the single start is the probe that gate_digest_init makes.
case_gate_digest_pr_gate_initialises_the_digest_tool() {
  local name="gate-digest-pr-gate-initialises-the-digest-tool"
  should_run "$name" || return 0
  command -v sha256sum >/dev/null 2>&1 || { skip "$name" "host has no sha256sum"; return 0; }
  local stubs="$TMP_DIR/prgate-stubs" log="$TMP_DIR/prgate.log" repo="$TMP_DIR/prgate-repo" rc=0 starts
  _counting_stub_dir "$stubs" "$log" sha256sum
  git init -q "$repo"
  PATH="$stubs:$PATH" bash "$REPO_ROOT/runtime/bin/pr-gate.sh" --cd "$repo" --no-such-option \
    > "$TMP_DIR/prgate.out" 2> "$TMP_DIR/prgate.err" || rc=$?
  [[ "$rc" -eq 2 ]] || { fail "$name" "expected the unknown option to exit 2, got $rc: $(head -c 300 "$TMP_DIR/prgate.err")"; return; }
  starts="$(grep -c '^sha256sum ' "$log" || true)"
  [[ "$starts" -eq 1 ]] || { fail "$name" "expected exactly 1 sha256sum start (gate_digest_init's probe), got $starts"; return; }
  pass "$name"
}

# Behavior: sourcing the library and calling its functions have no visible side
# effect on the caller: nothing printed, no shell option changed, and the
# caller's own variables named `line`, `digest` and `file` survive.
# Steps: snapshot `set +o` and `shopt -p` before and after sourcing and after
# gate_digest_init, capture output, then call the functions with those caller
# variables set.
case_gate_digest_source_and_calls_are_side_effect_free() {
  local name="gate-digest-source-and-calls-are-side-effect-free"
  should_run "$name" || return 0
  local before after printed line="keep-line" digest="keep-digest" file="keep-file"
  before="$(set +o; shopt -p)"
  printed="$(
    # shellcheck disable=SC1090
    . "$LIB" 2>&1
    gate_digest_init 2>&1
  )"
  [[ -z "$printed" ]] || { fail "$name" "sourcing or initialising printed: '$printed'"; return; }
  _load_lib init
  after="$(set +o; shopt -p)"
  [[ "$before" == "$after" ]] || { fail "$name" "sourcing or initialising changed shell options"; return; }
  printf 'abc' > "$TMP_DIR/abc"
  gate_digest_file "$TMP_DIR/abc" > /dev/null
  gate_digest_stream < "$TMP_DIR/abc" > /dev/null
  [[ "$line" == keep-line && "$digest" == keep-digest && "$file" == keep-file ]] || \
    { fail "$name" "a caller variable was overwritten: line='$line' digest='$digest' file='$file'"; return; }
  pass "$name"
}

case_gate_digest_known_vectors_in_every_call_shape
case_gate_digest_matches_oracle_on_awkward_input
case_gate_digest_file_rejects_unreadable_input
case_gate_digest_stream_status_ignores_a_closed_stdout
case_gate_digest_starts_one_tool_process_per_digest
case_gate_digest_sourcing_starts_no_process
case_gate_digest_reports_missing_tool
case_gate_digest_falls_back_to_shasum_when_sha256sum_is_broken
case_gate_digest_tool_failure_is_a_failure_in_both_modes
case_gate_digest_fresh_process_without_init_works_under_set_u
case_gate_digest_original_path_falls_back_to_shasum_with_algorithm_flag
case_gate_digest_pr_gate_initialises_the_digest_tool
case_gate_digest_source_and_calls_are_side_effect_free

th_summary
