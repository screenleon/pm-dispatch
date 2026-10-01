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

# A directory holding a `<tool>` stub that appends a line to $log and then runs
# the real tool, so a case can count how many times a tool was started.
# usage: _counting_stub_dir <dir> <log> <tool>...
_counting_stub_dir() {
  local dir="$1" log="$2" tool real
  shift 2
  mkdir -p "$dir"
  : > "$log"
  for tool in "$@"; do
    real="$(command -v "$tool")"
    printf '#!/bin/sh\necho "%s" >> "%s"\nexec "%s" "$@"\n' "$tool" "$log" "$real" > "$dir/$tool"
    chmod +x "$dir/$tool"
  done
}

# Behavior: gate_digest_stream prints the SHA-256 of stdin as 64 lowercase hex
# characters and a newline, however it is called: with a redirect, in a pipe,
# or inside a command substitution (where most gate code calls it); and
# gate_digest_file prints the same for a file.
# Steps: feed the empty string and "abc" (published test vectors, so the
# expectation does not depend on the host's tool) through every call shape.
case_gate_digest_known_vectors_in_every_call_shape() {
  local name="gate-digest-known-vectors-in-every-call-shape"
  should_run "$name" || return 0
  local empty="$TMP_DIR/empty" abc="$TMP_DIR/abc" got
  : > "$empty"
  printf 'abc' > "$abc"
  # shellcheck disable=SC1090
  . "$LIB"
  got="$(gate_digest_stream < "$empty")"
  [[ "$got" == "$EMPTY_SHA" ]] || { fail "$name" "empty via redirect: '$got'"; return; }
  got="$(printf 'abc' | gate_digest_stream)"
  [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "abc via pipe: '$got'"; return; }
  got="$(gate_digest_stream < "$abc")"
  [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "abc via redirect: '$got'"; return; }
  got="$(gate_digest_file "$abc")"
  [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "abc via gate_digest_file: '$got'"; return; }
  # The raw output is one line: the digest and a single newline.
  # The trailing "x" keeps the command substitution from stripping that newline.
  got="$(gate_digest_stream < "$abc"; printf x)"
  [[ "$got" == "${ABC_SHA}"$'\n'x ]] || { fail "$name" "raw output is not exactly <digest> and a newline"; return; }
  pass "$name"
}

# Behavior: the digest equals the host tool's for input that tends to break
# text handling: NUL bytes, a missing trailing newline, CRLF, high bytes, and
# input large enough to span many pipe buffers.
# Steps: build each input as a file, hash it with the independent oracle and
# with gate_digest_stream and gate_digest_file, and compare.
case_gate_digest_matches_oracle_on_awkward_input() {
  local name="gate-digest-matches-oracle-on-awkward-input"
  should_run "$name" || return 0
  local f want got4 got5 label
  # shellcheck disable=SC1090
  . "$LIB"
  printf '\000\001\002\377\n\000' > "$TMP_DIR/binary"
  printf 'no trailing newline' > "$TMP_DIR/no-nl"
  printf 'crlf\r\nline\r\n' > "$TMP_DIR/crlf"
  printf '\n\n\n' > "$TMP_DIR/newlines"
  seq 1 200000 > "$TMP_DIR/big"
  for label in binary no-nl crlf newlines big; do
    f="$TMP_DIR/$label"
    want="$(_oracle < "$f")"
    got4="$(gate_digest_stream < "$f")"
    got5="$(gate_digest_file "$f")"
    [[ "$got4" == "$want" ]] || { fail "$name" "$label: stream '$got4' != oracle '$want'"; return; }
    [[ "$got5" == "$want" ]] || { fail "$name" "$label: file '$got5' != oracle '$want'"; return; }
  done
  pass "$name"
}

# Behavior: gate_digest_file refuses a missing argument or an unreadable file
# with status 2 and prints no digest; it never reports a digest for a path it
# could not read.
# Steps: call it with no argument, an empty argument, a missing file and a
# directory; capture stdout and the status.
case_gate_digest_file_rejects_unreadable_input() {
  local name="gate-digest-file-rejects-unreadable-input"
  should_run "$name" || return 0
  local out rc
  # shellcheck disable=SC1090
  . "$LIB"
  mkdir -p "$TMP_DIR/adir"
  for arg in "" "$TMP_DIR/does-not-exist"; do
    rc=0; out="$(gate_digest_file "$arg" 2>/dev/null)" || rc=$?
    [[ "$rc" -eq 2 && -z "$out" ]] || { fail "$name" "arg '$arg': rc=$rc out='$out'"; return; }
  done
  rc=0; out="$(gate_digest_file 2>/dev/null)" || rc=$?
  [[ "$rc" -eq 2 && -z "$out" ]] || { fail "$name" "no argument: rc=$rc out='$out'"; return; }
  out="$(gate_digest_file "$TMP_DIR/adir" 2>/dev/null || true)"
  [[ "$out" != *[0-9a-f]????????????????????????????????????????????????????????????????* ]] || \
    { fail "$name" "directory produced a digest: '$out'"; return; }
  pass "$name"
}

# Behavior: (CC-611) a digest starts the digest tool exactly once and never
# starts awk. The old code probed the tool on every call (a subshell plus the
# tool) and then piped through awk, four processes where one is needed; a gate
# makes dozens of digests and each process costs ~40 ms on native Windows.
# Steps: put counting stubs for sha256sum and awk first on PATH, source the
# library (which probes once), record the count, then make five digests (three
# stream, two file) and assert exactly five more sha256sum starts and no awk.
case_gate_digest_starts_one_tool_process_per_digest() {
  local name="gate-digest-starts-one-tool-process-per-digest"
  should_run "$name" || return 0
  command -v sha256sum >/dev/null 2>&1 || { pass "$name"; return 0; }
  local stubs="$TMP_DIR/count-stubs" log="$TMP_DIR/count.log" before after awk_n
  _counting_stub_dir "$stubs" "$log" sha256sum awk
  printf 'abc' > "$TMP_DIR/abc"
  (
    PATH="$stubs:$PATH"
    # shellcheck disable=SC1090
    . "$LIB"
    before="$(grep -c '^sha256sum$' "$log" || true)"
    gate_digest_stream < "$TMP_DIR/abc" > /dev/null
    printf 'abc' | gate_digest_stream > /dev/null
    x="$(gate_digest_stream < "$TMP_DIR/abc")"
    gate_digest_file "$TMP_DIR/abc" > /dev/null
    y="$(gate_digest_file "$TMP_DIR/abc")"
    [[ "$x" == "$ABC_SHA" && "$y" == "$ABC_SHA" ]] || exit 3
    after="$(grep -c '^sha256sum$' "$log" || true)"
    awk_n="$(grep -c '^awk$' "$log" || true)"
    printf '%s %s %s\n' "$before" "$after" "$awk_n" > "$TMP_DIR/counts"
  ) || { fail "$name" "digests inside the counting subshell failed"; return; }
  read -r before after awk_n < "$TMP_DIR/counts"
  [[ "$((after - before))" -eq 5 ]] || \
    { fail "$name" "expected 5 sha256sum starts for 5 digests, got $((after - before)) (probe per call?)"; return; }
  [[ "$awk_n" -eq 0 ]] || { fail "$name" "awk was started $awk_n time(s); the digest no longer needs it"; return; }
  pass "$name"
}

# Behavior: when no digest tool is usable the library reports it the same way
# as before: status 2 and the "no sha256sum or shasum" error on stderr, nothing
# on stdout. This holds when the tool disappears after sourcing (PATH changed)
# and when it was never there.
# Steps: source with a normal PATH and then empty PATH; separately source
# with an empty PATH; call gate_digest_stream and gate_digest_file in each.
case_gate_digest_reports_missing_tool() {
  local name="gate-digest-reports-missing-tool"
  should_run "$name" || return 0
  local empty_bin="$TMP_DIR/empty-bin" out err rc mode
  mkdir -p "$empty_bin"
  printf 'abc' > "$TMP_DIR/abc"
  for mode in late-empty never-there; do
    rc=0
    out="$(
      if [[ "$mode" == never-there ]]; then PATH="$empty_bin"; fi
      # shellcheck disable=SC1090
      . "$LIB"
      PATH="$empty_bin"
      gate_digest_stream < "$TMP_DIR/abc" 2> "$TMP_DIR/err"
    )" || rc=$?
    err="$(cat "$TMP_DIR/err")"
    [[ "$rc" -eq 2 && -z "$out" && "$err" == *"no sha256sum or shasum found"* ]] || \
      { fail "$name" "$mode stream: rc=$rc out='$out' err='$err'"; return; }
    rc=0
    out="$(
      if [[ "$mode" == never-there ]]; then PATH="$empty_bin"; fi
      # shellcheck disable=SC1090
      . "$LIB"
      PATH="$empty_bin"
      gate_digest_file "$TMP_DIR/abc" 2> "$TMP_DIR/err"
    )" || rc=$?
    [[ "$rc" -eq 2 && -z "$out" ]] || { fail "$name" "$mode file: rc=$rc out='$out'"; return; }
  done
  pass "$name"
}

# Behavior: a sha256sum that is present but does not work is skipped in favour
# of shasum, as the per-call probe used to do; the digest is still correct.
# Steps: put a sha256sum that always fails and a counting shasum (which runs the
# real tool) first on PATH, source the library, and digest "abc".
case_gate_digest_falls_back_to_shasum_when_sha256sum_is_broken() {
  local name="gate-digest-falls-back-to-shasum-when-sha256sum-is-broken"
  should_run "$name" || return 0
  command -v sha256sum >/dev/null 2>&1 || { pass "$name"; return 0; }
  local stubs="$TMP_DIR/shasum-stubs" log="$TMP_DIR/shasum.log" got real
  real="$(command -v sha256sum)"
  mkdir -p "$stubs"; : > "$log"
  printf '#!/bin/sh\nexit 1\n' > "$stubs/sha256sum"
  # shasum is called as `shasum -a 256`; drop the two flag arguments.
  printf '#!/bin/sh\necho shasum >> "%s"\nshift 2\nexec "%s" "$@"\n' "$log" "$real" > "$stubs/shasum"
  chmod +x "$stubs/sha256sum" "$stubs/shasum"
  got="$(
    PATH="$stubs:$PATH"
    # shellcheck disable=SC1090
    . "$LIB"
    printf 'abc' | gate_digest_stream
  )"
  [[ "$got" == "$ABC_SHA" ]] || { fail "$name" "digest via shasum fallback: '$got'"; return; }
  [[ "$(grep -c '^shasum$' "$log" || true)" -ge 1 ]] || { fail "$name" "shasum stub was never used"; return; }
  pass "$name"
}

# Behavior: sourcing the library has no visible side effect on the caller:
# nothing printed, no shell option changed. It does leave the internal
# _GATE_DIGEST_TOOL variable, and calling the helpers does not overwrite a
# caller's own variables of the common names `line`, `digest` and `file`.
# Steps: snapshot `set +o` and `shopt -p` before and after sourcing, capture
# output, then call the functions with those caller variables set.
case_gate_digest_source_and_calls_are_side_effect_free() {
  local name="gate-digest-source-and-calls-are-side-effect-free"
  should_run "$name" || return 0
  local before after printed line="keep-line" digest="keep-digest" file="keep-file"
  before="$(set +o; shopt -p)"
  printed="$(
    # shellcheck disable=SC1090
    . "$LIB" 2>&1
  )"
  [[ -z "$printed" ]] || { fail "$name" "sourcing printed: '$printed'"; return; }
  # shellcheck disable=SC1090
  . "$LIB"
  after="$(set +o; shopt -p)"
  [[ "$before" == "$after" ]] || { fail "$name" "sourcing changed shell options"; return; }
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
case_gate_digest_reports_missing_tool
case_gate_digest_falls_back_to_shasum_when_sha256sum_is_broken
case_gate_digest_source_and_calls_are_side_effect_free

th_summary
