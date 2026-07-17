#!/usr/bin/env bash
# Regression tests for tools/lint/lint-frontmatter.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-frontmatter.sh"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

should_run() {
  if $LIST; then ALL_CASES+=("$1"); return 1; fi
  if [[ "$FILTER" == "unclosed-seq" && "$1" == "lint-frontmatter/unclosed-quote-in-seq" ]]; then
    return 0
  fi
  if [[ "$FILTER" == "mismatched-map" && "$1" == "lint-frontmatter/mismatched-bracket-in-map" ]]; then
    return 0
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

tmp_md() {
  local tmp
  tmp="$(mktemp "$tmp_root/test-lint-fm-XXXXXX.md")"
  printf '%s\n' "$tmp"
}

record_pass() {
  local name="$1"
  pass "$name"
}

record_fail() {
  local name="$1" detail="$2"
  fail "$name" "$detail"
}

run_ok() {
  local name="$1"
  shift
  should_run "$name" || return 0

  local output status
  output="$(cd "$REPO_ROOT" && bash "$LINTER" "$@" 2>&1)"
  status=$?
  if [[ $status -eq 0 ]]; then
    record_pass "$name"
  else
    record_fail "$name" "expected exit 0, got $status; output: $output"
  fi
}

run_fail() {
  local name="$1"
  shift
  should_run "$name" || return 0

  local output status
  output="$(cd "$REPO_ROOT" && bash "$LINTER" "$@" 2>&1)"
  status=$?
  if [[ $status -ne 0 ]]; then
    record_pass "$name"
  else
    record_fail "$name" "expected non-zero exit, got 0; output: $output"
  fi
}

run_exit() {
  local name="$1" expected="$2"
  shift 2
  should_run "$name" || return 0

  local output status
  output="$(cd "$REPO_ROOT" && bash "$LINTER" "$@" 2>&1)"
  status=$?
  if [[ $status -eq $expected ]]; then
    record_pass "$name"
  else
    record_fail "$name" "expected exit $expected, got $status; output: $output"
  fi
}

run_tmp_ok() {
  local name="$1" content="$2"
  should_run "$name" || return 0

  local tmp
  tmp="$(tmp_md)"
  printf '%s' "$content" > "$tmp"
  run_ok "$name" --file "$tmp"
}

run_tmp_fail() {
  local name="$1" content="$2"
  should_run "$name" || return 0

  local tmp
  tmp="$(tmp_md)"
  printf '%s' "$content" > "$tmp"
  run_fail "$name" --file "$tmp"
}

assert_no_modification() {
  local name="$1"
  should_run "$name" || return 0

  local tmp before after output status
  tmp="$(tmp_md)"
  printf -- '---\nkey: [unclosed\n---\n\nbody\n' > "$tmp"
  before="$(md5sum "$tmp")"
  output="$(cd "$REPO_ROOT" && bash "$LINTER" --file "$tmp" 2>&1)"
  status=$?
  after="$(md5sum "$tmp")"

  if [[ $status -ne 0 && "$before" == "$after" ]]; then
    record_pass "$name"
  else
    record_fail "$name" "expected failing lint with unchanged file; status=$status; output: $output"
  fi
}

# -- argument parsing ---------------------------------------------------------

run_ok "lint-frontmatter/help" --help
run_exit "lint-frontmatter/unknown-flag" 2 --unknown
run_exit "lint-frontmatter/file-missing-value" 2 --file

# -- happy path (file mode) ---------------------------------------------------

run_tmp_ok "lint-frontmatter/valid-file" \
  $'---\ndescription: test\n---\n\nbody\n'

# -- happy path: flow sequences -----------------------------------------------

run_tmp_ok "lint-frontmatter/valid-seq-unquoted" \
  $'---\ndescription: [foo, bar]\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-seq-dq" \
  $'---\ndescription: ["foo", "bar"]\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-seq-sq" \
  $'---\ndescription: [\'foo\', \'bar\']\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-seq-dq-escape" \
  $'---\ndescription: ["valid \\n escape"]\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-seq-single-item" \
  $'---\ndescription: ["item"]\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-seq-comma-in-dq" \
  $'---\ndescription: ["foo,,bar","baz"]\n---\n\nbody\n'

# -- happy path: flow mappings ------------------------------------------------

run_tmp_ok "lint-frontmatter/valid-flow-mapping-unquoted" \
  $'---\ndescription: {foo: bar}\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-flow-mapping-dq" \
  $'---\ndescription: {foo: "bar", baz: "qux"}\n---\n\nbody\n'

# -- happy path: list items ---------------------------------------------------

run_tmp_ok "lint-frontmatter/valid-list-item-plain" \
  $'---\ntags:\n  - plain-value\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-list-item-dq" \
  $'---\ntags:\n  - "valid item"\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-list-item-sq" \
  $'---\ntags:\n  - \'valid item\'\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-list-item-seq" \
  $'---\ntags:\n  - [a, b]\n---\n\nbody\n'
run_tmp_ok "lint-frontmatter/valid-list-item-map" \
  $'---\ntags:\n  - {k: v}\n---\n\nbody\n'

# -- warning-not-fail cases ---------------------------------------------------

run_tmp_ok "lint-frontmatter/no-frontmatter-warn" \
  $'description: test\n\nbody\n'

# -- failure cases ------------------------------------------------------------

run_fail "lint-frontmatter/nonexistent-file" --file /nonexistent.md
run_tmp_fail "lint-frontmatter/unterminated-frontmatter" \
  $'---\ndescription: test\n'
run_tmp_fail "lint-frontmatter/malformed-yaml" \
  $'---\nkey: [unclosed\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/unquoted-argument-hint" \
  $'---\ndescription: test\nargument-hint: [a|b|c]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/unterminated-quoted-value" \
  $'---\ndescription: "unterminated\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/nested-yaml-value" \
  $'---\ndescription: foo: bar\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/trailing-after-quote" \
  $'---\ndescription: "foo" "bar"\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/unclosed-flow-mapping" \
  $'---\ndescription: {unterminated\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/unterminated-single-quote" \
  $'---\ndescription: \'unterminated\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/non-string-argument-hint" \
  $'---\ndescription: test\nargument-hint:\n  - a\n  - b\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/invalid-scalar-start-at" \
  $'---\ndescription: @bad\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/invalid-scalar-start-backtick" \
  $'---\ndescription: `bad\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/flow-seq-trailing-content" \
  $'---\ndescription: [foo] bar\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/flow-map-trailing-content" \
  $'---\ndescription: {foo} bar\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/alias-plain-scalar" \
  $'---\ndescription: *missing\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/escaped-terminal-quote" \
  $'---\ndescription: "foo\\"\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/trailing-after-single-quote" \
  $'---\ndescription: \'foo\' \'bar\'\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/unclosed-quote-in-seq" \
  $'---\ndescription: ["unterminated]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/mismatched-bracket-in-map" \
  $'---\ndescription: {foo: [bar}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/anchor-plain-scalar" \
  $'---\ndescription: &anchor foo\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/yaml-tag-double" \
  $'---\ndescription: !!str foo\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/yaml-tag-single" \
  $'---\ndescription: !tag foo\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/nested-seq-in-seq" \
  $'---\ndescription: [[a, b]]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/invalid-dq-escape" \
  $'---\ndescription: "bad \\q escape"\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/sq-in-seq-unclosed" \
  $'---\ndescription: [\'unterminated]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-unclosed-seq" \
  $'---\ntags:\n  - [unclosed\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/invalid-dq-escape-in-seq" \
  $'---\ndescription: ["bad \\q escape"]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/invalid-dq-escape-in-list-item" \
  $'---\ntags:\n  - ["bad \\q escape"]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/invalid-dq-escape-in-flow-mapping" \
  $'---\ndescription: {foo: "bad \\q escape"}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/invalid-dq-escape-in-list-item-flow-mapping" \
  $'---\ntags:\n  - {foo: "bad \\q escape"}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/seq-adjacent-dq" \
  $'---\ndescription: ["foo" "bar"]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/seq-adjacent-sq" \
  $'---\ndescription: [\'foo\' \'bar\']\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/flow-mapping-adjacent-dq" \
  $'---\ndescription: {foo: "bar" "baz"}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/flow-mapping-adjacent-sq" \
  $'---\ndescription: {foo: \'bar\' \'baz\'}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-seq-adjacent-dq" \
  $'---\ntags:\n  - ["foo" "bar"]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-seq-adjacent-sq" \
  $'---\ntags:\n  - [\'foo\' \'bar\']\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-mapping-adjacent-dq" \
  $'---\ntags:\n  - {foo: "bar" "baz"}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-mapping-adjacent-sq" \
  $'---\ntags:\n  - {foo: \'bar\' \'baz\'}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-unclosed-mapping" \
  $'---\ntags:\n  - {unclosed\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-dq-invalid-escape" \
  $'---\ntags:\n  - "bad \\q escape"\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-dq-unclosed" \
  $'---\ntags:\n  - "unterminated\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/tab-indented-list-item" \
  $'---\ndescription: test\ntags:\n\t- bad\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/seq-double-comma" \
  $'---\ndescription: [foo,,bar]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/seq-leading-comma" \
  $'---\ndescription: [,foo]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/map-double-comma" \
  $'---\ndescription: {foo: bar,, baz: qux}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/map-leading-comma" \
  $'---\ndescription: {,foo: bar}\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-seq-double-comma" \
  $'---\ntags:\n  - [foo,,bar]\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/list-item-map-double-comma" \
  $'---\ntags:\n  - {foo: bar,, baz: qux}\n---\n\nbody\n'

# -- repo scan mode -----------------------------------------------------------

run_ok "lint-frontmatter/repo-scan"

# -- skills/ scan coverage (CC-061) -------------------------------------------
# Proves repo-scan mode descends into the nested skills/<name>/SKILL.md layout.
# Without that loop a malformed SKILL.md would slip through (README claims skills/
# is validated). A bad SKILL.md under --repo-root must make the lint fail; a good
# one must pass.
skills_scan_case() {
  local bad_name="lint-frontmatter/skills-scanned-bad-fails"
  local good_name="lint-frontmatter/skills-scanned-good-passes"
  should_run "$bad_name" || { should_run "$good_name" || return 0; }

  local root output status
  root="$(mktemp -d)"
  mkdir -p "$root/skills/sample"

  # 1. malformed SKILL.md → scan must reject (non-zero).
  printf -- '---\nname: [unclosed\n---\n\nbody\n' > "$root/skills/sample/SKILL.md"
  output="$(cd "$REPO_ROOT" && bash "$LINTER" --repo-root "$root" 2>&1)"; status=$?
  if should_run "$bad_name"; then
    if [[ $status -ne 0 ]]; then record_pass "$bad_name"
    else record_fail "$bad_name" "expected non-zero; skills/ not scanned? output: $output"; fi
  fi

  # 2. well-formed SKILL.md → scan must pass.
  printf -- '---\nname: sample\ndescription: a valid sample skill\n---\n\nbody\n' > "$root/skills/sample/SKILL.md"
  output="$(cd "$REPO_ROOT" && bash "$LINTER" --repo-root "$root" 2>&1)"; status=$?
  if should_run "$good_name"; then
    if [[ $status -eq 0 ]]; then record_pass "$good_name"
    else record_fail "$good_name" "expected exit 0, got $status; output: $output"; fi
  fi

  rm -rf "$root"
}
skills_scan_case

# -- side-effect guard --------------------------------------------------------

assert_no_modification "lint-frontmatter/no-modification"

# -- summary ------------------------------------------------------------------

th_summary
