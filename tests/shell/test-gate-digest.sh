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
# status 2 and prints nothing, and never prints a digest for a path it cannot
# read as a file (a directory). What it prints for a directory is not pinned:
# like the code before CC-611 it reports an empty digest with status 0.
# Steps: call it with no argument, an empty argument, a missing file and a
# directory; capture stdout and the status.
case_gate_digest_file_rejects_unreadable_input() {
  local name="gate-digest-file-rejects-unreadable-input"
  should_run "$name" || return 0
  local out rc arg
  _load_lib init
  mkdir -p "$TMP_DIR/adir"
  for arg in "" "$TMP_DIR/does-not-exist"; do
    rc=0; out="$(gate_digest_file "$arg" 2>/dev/null)" || rc=$?
    [[ "$rc" -eq 2 && -z "$out" ]] || { fail "$name" "arg '$arg': rc=$rc out='$out'"; return; }
  done
  rc=0; out="$(gate_digest_file 2>/dev/null)" || rc=$?
  [[ "$rc" -eq 2 && -z "$out" ]] || { fail "$name" "no argument: rc=$rc out='$out'"; return; }
  out="$(gate_digest_file "$TMP_DIR/adir" 2>/dev/null || true)"
  [[ ! "$out" =~ [0-9a-f]{64} ]] || { fail "$name" "directory produced a digest: '$out'"; return; }
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

# Behavior: a digest tool that breaks after gate_digest_init is not noticed: the
# call prints no digest and returns 0, exactly what a tool failing mid-call
# always did (the code before CC-611 ended `tool | awk; return 0`). This pins the
# preserved contract so a change to it is deliberate; it is not an endorsement,
# since an empty digest is a weak failure mode (callers reject it downstream).
# Steps: initialise with the real tool, then put a sha256sum that always fails
# first on PATH and digest "abc" as a stream and as a file.
case_gate_digest_tool_broken_after_init_gives_empty_digest() {
  local name="gate-digest-tool-broken-after-init-gives-empty-digest"
  should_run "$name" || return 0
  local bad_bin="$TMP_DIR/bad-bin" out rc
  mkdir -p "$bad_bin"
  printf '#!/bin/sh\nexit 1\n' > "$bad_bin/sha256sum"
  chmod +x "$bad_bin/sha256sum"
  printf 'abc' > "$TMP_DIR/abc"
  _load_lib init
  rc=0; out="$(PATH="$bad_bin:$PATH" gate_digest_stream < "$TMP_DIR/abc" 2>/dev/null)" || rc=$?
  [[ "$rc" -eq 0 && -z "$out" ]] || { fail "$name" "stream: rc=$rc out='$out'"; return; }
  rc=0; out="$(PATH="$bad_bin:$PATH" gate_digest_file "$TMP_DIR/abc" 2>/dev/null)" || rc=$?
  [[ "$rc" -eq 0 && -z "$out" ]] || { fail "$name" "file: rc=$rc out='$out'"; return; }
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
case_gate_digest_starts_one_tool_process_per_digest
case_gate_digest_sourcing_starts_no_process
case_gate_digest_reports_missing_tool
case_gate_digest_falls_back_to_shasum_when_sha256sum_is_broken
case_gate_digest_tool_broken_after_init_gives_empty_digest
case_gate_digest_source_and_calls_are_side_effect_free

th_summary
