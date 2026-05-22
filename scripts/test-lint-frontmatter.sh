#!/usr/bin/env bash
# Regression tests for scripts/lint-frontmatter.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINTER="$REPO_ROOT/scripts/lint-frontmatter.sh"

FILTER=""
LIST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      if [[ $# -lt 2 ]]; then
        echo "error: --filter requires an argument" >&2; exit 1
      fi
      FILTER="$2"; shift 2 ;;
    --list) LIST=true; shift ;;
    *) echo "error: unknown option: $1" >&2; exit 1 ;;
  esac
done

ALL_CASES=()
FAILED_CASES=()
TMP_FILES=()

cleanup() {
  if [[ ${#TMP_FILES[@]} -gt 0 ]]; then
    rm -f "${TMP_FILES[@]}"
  fi
}
trap cleanup EXIT

should_run() {
  if $LIST; then ALL_CASES+=("$1"); return 1; fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

PASS=0
FAIL=0

tmp_md() {
  local tmp
  tmp="$(mktemp /tmp/test-lint-fm-XXXXXX.md)"
  TMP_FILES+=("$tmp")
  printf '%s\n' "$tmp"
}

record_pass() {
  local name="$1"
  PASS=$((PASS+1))
  ${VERBOSE:+echo "  PASS $name"}
}

record_fail() {
  local name="$1" detail="$2"
  FAIL=$((FAIL+1))
  FAILED_CASES+=("$name")
  echo "  FAIL $name"
  echo "    $detail"
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

$LIST || echo "test-lint-frontmatter.sh"

# -- argument parsing ---------------------------------------------------------

run_ok "lint-frontmatter/help" --help
run_exit "lint-frontmatter/unknown-flag" 2 --unknown
run_exit "lint-frontmatter/file-missing-value" 2 --file

# -- happy path (file mode) ---------------------------------------------------

run_tmp_ok "lint-frontmatter/valid-file" \
  $'---\ndescription: test\n---\n\nbody\n'

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
run_tmp_fail "lint-frontmatter/unclosed-flow-mapping" \
  $'---\ndescription: {unterminated\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/unterminated-single-quote" \
  $'---\ndescription: \'unterminated\n---\n\nbody\n'
run_tmp_fail "lint-frontmatter/non-string-argument-hint" \
  $'---\ndescription: test\nargument-hint:\n  - a\n  - b\n---\n\nbody\n'

# -- repo scan mode -----------------------------------------------------------

run_ok "lint-frontmatter/repo-scan"

# -- side-effect guard --------------------------------------------------------

assert_no_modification "lint-frontmatter/no-modification"

# -- summary ------------------------------------------------------------------

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

# Fail if --filter matched nothing (prevents silent false-green on typos)
if [[ -n "$FILTER" && $((PASS+FAIL)) -eq 0 ]]; then
  printf 'no tests matched filter %q - check --list for available case names\n' \
    "$FILTER" >&2
  exit 1
fi

echo ""
echo "----"
echo "$PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo "failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
