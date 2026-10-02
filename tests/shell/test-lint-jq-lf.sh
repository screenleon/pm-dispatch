#!/usr/bin/env bash
# Regression tests for tools/lint/lint-jq-lf.sh (CC-594 slice 2): every executable
# shell entry that can call jq must load the jq LF shim, by sourcing
# runtime/lib/jq-lf.sh or by carrying the standalone snippet from its header.

# Cases change PATH and define a jq() function on purpose inside subshells, and
# the fixture scripts they write contain literal $ in single quotes (SC2016).
# shellcheck disable=SC2030,SC2031,SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-jq-lf.sh"
LIB="$REPO_ROOT/runtime/lib/jq-lf.sh"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# The two standalone-snippet lines, exactly as the library's header shows them.
SNIP1="$(grep -m1 '^#   # CC-594:' "$LIB" | cut -c5-)"
SNIP2="$(grep -m1 '^#   case "\${OSTYPE:-}" in msys' "$LIB" | cut -c5-)"

# make_fixture <name>: a tiny git repo with the library and the linter in place.
make_fixture() {
  local root="$TMP_DIR/$1"
  mkdir -p "$root/runtime/lib" "$root/tools/lint"
  cp "$LIB" "$root/runtime/lib/jq-lf.sh"
  cp "$LINTER" "$root/tools/lint/lint-jq-lf.sh"
  git init -q "$root"
  git -C "$root" config core.autocrlf false
  git -C "$root" add -A
  printf '%s\n' "$root"
}

# put <root> <path> <exec|lib> <content...>: write a tracked file, executable or not.
put() {
  local root="$1" path="$2" kind="$3"
  shift 3
  mkdir -p "$root/$(dirname "$path")"
  printf '%s\n' "$@" > "$root/$path"
  if [[ "$kind" == exec ]]; then
    git -C "$root" update-index --add --chmod=+x -- "$path" 2>/dev/null || { git -C "$root" add -- "$path"; git -C "$root" update-index --chmod=+x -- "$path"; }
  else
    git -C "$root" add -- "$path"
  fi
}

# lint <root>: run the fixture's linter, leaving the output in OUT and status in RC.
OUT=""; RC=0
lint() {
  RC=0
  OUT="$(bash "$1/tools/lint/lint-jq-lf.sh" --repo-root "$1" 2>&1)" || RC=$?
}

# Behavior: a repository whose entries never call jq passes, and words that merely
# mention jq (an existence check, a message) are not calls.
# Steps: an executable that only checks `command -v jq` and prints a hint passes.
case_lint_jq_lf_mentions_are_not_calls() {
  local name="lint-jq-lf-mentions-are-not-calls"
  should_run "$name" || return 0
  local root; root="$(make_fixture mentions)"
  put "$root" tools/check.sh exec '#!/usr/bin/env bash' 'if ! command -v jq >/dev/null 2>&1; then echo "jq is required"; fi' 'type -P jq >/dev/null'
  lint "$root"
  [[ "$RC" -eq 0 && "$OUT" == *"OK"* ]] || { fail "$name" "rc=$RC out=$OUT"; return; }
  pass "$name"
}

# Behavior: an executable entry that calls jq without loading the shim fails, and
# the message names the file.
# Steps: an executable with `jq -r ...` and no shim; assert rc 1 and the path.
case_lint_jq_lf_flags_an_entry_that_calls_jq() {
  local name="lint-jq-lf-flags-an-entry-that-calls-jq"
  should_run "$name" || return 0
  local root; root="$(make_fixture flagged)"
  put "$root" hooks/a.sh exec '#!/usr/bin/env bash' 'x="$(printf "{}" | jq -r .a)"'
  lint "$root"
  [[ "$RC" -eq 1 && "$OUT" == *"hooks/a.sh"* && "$OUT" == *"calls jq"* ]] || { fail "$name" "rc=$RC out=$OUT"; return; }
  pass "$name"
}

# Behavior: the same entry passes once it carries the canonical snippet, or sources
# runtime/lib/jq-lf.sh, or (a test) calls th_init.
# Steps: three variants of the failing entry.
case_lint_jq_lf_accepts_each_way_of_loading_the_shim() {
  local name="lint-jq-lf-accepts-each-way-of-loading-the-shim"
  should_run "$name" || return 0
  local root; root="$(make_fixture accepted)"
  put "$root" hooks/snippet.sh exec '#!/usr/bin/env bash' "$SNIP1" "$SNIP2" 'jq -n 1'
  put "$root" hooks/sourced.sh exec '#!/usr/bin/env bash' '. "$(dirname "$0")/../runtime/lib/jq-lf.sh"' 'jq -n 1'
  put "$root" tests/shell/test-x.sh exec '#!/usr/bin/env bash' 'th_init "$@"' 'jq -n 1'
  lint "$root"
  [[ "$RC" -eq 0 ]] || { fail "$name" "rc=$RC out=$OUT"; return; }
  pass "$name"
}

# Behavior: a library (not executable) that calls jq is not flagged itself; an
# executable entry that sources it by name inherits the requirement and fails
# until it loads the shim.
# Steps: lib calls jq; entry sources it; lint fails naming the entry and the lib;
# add the snippet to the entry; lint passes.
case_lint_jq_lf_follows_the_source_closure() {
  local name="lint-jq-lf-follows-the-source-closure"
  should_run "$name" || return 0
  local root; root="$(make_fixture closure)"
  put "$root" lib/helper.sh lib 'helper() { jq -n 1; }'
  put "$root" bin/run.sh exec '#!/usr/bin/env bash' '. "$(dirname "$0")/../lib/helper.sh"' 'helper'
  lint "$root"
  [[ "$RC" -eq 1 && "$OUT" == *"bin/run.sh"* && "$OUT" == *"through lib/helper.sh"* && "$OUT" != *"lib/helper.sh: "* ]] || { fail "$name" "before: rc=$RC out=$OUT"; return; }
  put "$root" bin/run.sh exec '#!/usr/bin/env bash' "$SNIP1" "$SNIP2" '. "$(dirname "$0")/../lib/helper.sh"' 'helper'
  lint "$root"
  [[ "$RC" -eq 0 ]] || { fail "$name" "after: rc=$RC out=$OUT"; return; }
  pass "$name"
}

# Behavior: a copy of the snippet that is not exactly the library's text fails, so
# the copies cannot drift: one changed character, or only one of the two lines.
# Steps: an entry with a near-copy; an entry with only the second line.
case_lint_jq_lf_rejects_a_drifted_snippet() {
  local name="lint-jq-lf-rejects-a-drifted-snippet"
  should_run "$name" || return 0
  local root; root="$(make_fixture drift)"
  put "$root" hooks/drift.sh exec '#!/usr/bin/env bash' "$SNIP1" "${SNIP2/-b/-B}" 'jq -n 1'
  lint "$root"
  [[ "$RC" -eq 1 && "$OUT" == *"hooks/drift.sh"* && "$OUT" == *"differs"* ]] || { fail "$name" "near-copy: rc=$RC out=$OUT"; return; }
  root="$(make_fixture half)"
  put "$root" hooks/half.sh exec '#!/usr/bin/env bash' "$SNIP2" 'jq -n 1'
  lint "$root"
  [[ "$RC" -eq 1 && "$OUT" == *"hooks/half.sh"* && "$OUT" == *"differs"* ]] || { fail "$name" "one line: rc=$RC out=$OUT"; return; }
  pass "$name"
}

# Behavior: an entry outside tests/ with a non-literal `source` has a closure the
# lint cannot know, so it must load the shim, unless the line is annotated with
# `# jq-lf: dynamic-ok: <reason>` (the reason is mandatory).
# Steps: a dynamic source fails; with an annotation it passes; with an annotation
# that has no reason it still fails.
case_lint_jq_lf_handles_dynamic_sources() {
  local name="lint-jq-lf-handles-dynamic-sources"
  should_run "$name" || return 0
  local root; root="$(make_fixture dynamic)"
  put "$root" bin/dyn.sh exec '#!/usr/bin/env bash' '. "$1"'
  lint "$root"
  [[ "$RC" -eq 1 && "$OUT" == *"bin/dyn.sh"* && "$OUT" == *"dynamic source"* ]] || { fail "$name" "plain: rc=$RC out=$OUT"; return; }
  put "$root" bin/dyn.sh exec '#!/usr/bin/env bash' '# jq-lf: dynamic-ok: loads a config file that never runs jq' '. "$1"'
  lint "$root"
  [[ "$RC" -eq 0 ]] || { fail "$name" "annotated: rc=$RC out=$OUT"; return; }
  put "$root" bin/dyn.sh exec '#!/usr/bin/env bash' '# jq-lf: dynamic-ok:' '. "$1"'
  lint "$root"
  [[ "$RC" -eq 1 ]] || { fail "$name" "annotation without a reason was accepted: rc=$RC out=$OUT"; return; }
  pass "$name"
}

# Behavior: tools/lint/jq-lf-exemptions.tsv exempts an entry that legitimately does
# not load the shim, and a row that is no longer needed fails, so the list cannot rot.
# Steps: an exempted entry passes; an exemption for a file that now loads the shim
# fails; an exemption for a file that does not exist fails.
case_lint_jq_lf_exemptions_must_stay_needed() {
  local name="lint-jq-lf-exemptions-must-stay-needed"
  should_run "$name" || return 0
  local root; root="$(make_fixture exempt)"
  put "$root" bin/odd.sh exec '#!/usr/bin/env bash' 'jq -n 1'
  printf 'bin/odd.sh\tmanaged elsewhere\n' > "$root/tools/lint/jq-lf-exemptions.tsv"
  lint "$root"
  [[ "$RC" -eq 0 && "$OUT" == *"1 exempt"* ]] || { fail "$name" "exempt: rc=$RC out=$OUT"; return; }
  put "$root" bin/odd.sh exec '#!/usr/bin/env bash' "$SNIP1" "$SNIP2" 'jq -n 1'
  lint "$root"
  [[ "$RC" -eq 1 && "$OUT" == *"remove the row"* ]] || { fail "$name" "stale (loads it): rc=$RC out=$OUT"; return; }
  printf 'bin/gone.sh\tgone\n' > "$root/tools/lint/jq-lf-exemptions.tsv"
  lint "$root"
  [[ "$RC" -eq 1 && "$OUT" == *"bin/gone.sh"* ]] || { fail "$name" "missing file: rc=$RC out=$OUT"; return; }
  pass "$name"
}

# Behavior: the standalone snippet and the library define jq under the same
# conditions and add -b the same way, so a script that carries the snippet behaves
# like one that sources the library.
# Steps: with a stub jq that records its arguments on PATH, load each in a fresh
# bash under OSTYPE msys, cygwin and linux-gnu and with no jq on PATH; compare
# whether a jq function exists and the first argument the stub receives.
case_lint_jq_lf_snippet_matches_the_library() {
  local name="lint-jq-lf-snippet-matches-the-library"
  should_run "$name" || return 0
  local stubs="$TMP_DIR/eq-stubs" empty="$TMP_DIR/eq-empty" log="$TMP_DIR/eq.log" ostype with how lib_out snip_out
  mkdir -p "$stubs" "$empty"
  printf '#!/bin/sh\nprintf "%%s\\n" "$1" > "%s"\n' "$log" > "$stubs/jq"
  chmod +x "$stubs/jq"
  printf '%s\n%s\n' "$SNIP1" "$SNIP2" > "$TMP_DIR/snippet.sh"
  for ostype in msys cygwin linux-gnu; do
    for with in jq nojq; do
      for how in lib snip; do
        : > "$log"
        local pathv="$stubs:$PATH"; [[ "$with" == nojq ]] && pathv="$empty"
        local src="$LIB"; [[ "$how" == snip ]] && src="$TMP_DIR/snippet.sh"
        local got
        got="$(OSTYPE="$ostype" PATH="$pathv" "$BASH" -c 'OSTYPE="$1"; unset PM_DISPATCH_JQ_LF; . "$2"; if declare -F jq >/dev/null; then jq -n 1 </dev/null; echo "fn:$(head -n1 "$3" 2>/dev/null)"; else echo fn:none; fi' _ "$ostype" "$src" "$log" 2>&1 | tail -n 1)"
        if [[ "$how" == lib ]]; then lib_out="$got"; else snip_out="$got"; fi
      done
      [[ "$lib_out" == "$snip_out" ]] || { fail "$name" "OSTYPE=$ostype $with: library gives '$lib_out', snippet '$snip_out'"; return; }
      case "$ostype/$with" in
        msys/jq|cygwin/jq) [[ "$lib_out" == "fn:-b" ]] || { fail "$name" "OSTYPE=$ostype with jq: expected 'fn:-b', got '$lib_out'"; return; } ;;
        *) [[ "$lib_out" == "fn:none" ]] || { fail "$name" "OSTYPE=$ostype $with: expected no function, got '$lib_out'"; return; } ;;
      esac
    done
  done
  pass "$name"
}

# Behavior: the repository itself satisfies the lint, so a new jq-calling entry
# that forgets the shim fails CI on Linux, where the CRLF problem never shows.
# Steps: run the linter on the checkout.
case_lint_jq_lf_the_repository_passes() {
  local name="lint-jq-lf-the-repository-passes"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$LINTER" 2>&1)" || rc=$?
  [[ "$rc" -eq 0 ]] || { fail "$name" "rc=$rc: $(printf '%s' "$out" | head -n 5)"; return; }
  pass "$name"
}

case_lint_jq_lf_mentions_are_not_calls
case_lint_jq_lf_flags_an_entry_that_calls_jq
case_lint_jq_lf_accepts_each_way_of_loading_the_shim
case_lint_jq_lf_follows_the_source_closure
case_lint_jq_lf_rejects_a_drifted_snippet
case_lint_jq_lf_handles_dynamic_sources
case_lint_jq_lf_exemptions_must_stay_needed
case_lint_jq_lf_snippet_matches_the_library
case_lint_jq_lf_the_repository_passes

th_summary
