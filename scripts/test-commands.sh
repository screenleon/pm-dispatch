#!/usr/bin/env bash
# Contract-lint tests for slash commands in commands/.
#
# These are structural tests — they verify that command files are
# internally consistent and contain required sections. They do NOT
# test Claude's runtime behaviour (that's untestable here).
#
# Usage:
#   scripts/test-commands.sh           # silent unless failures
#   VERBOSE=1 scripts/test-commands.sh # print every case
#   scripts/test-commands.sh --filter caveman
#   scripts/test-commands.sh --list

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMANDS_DIR="$REPO_ROOT/commands"
AGENTS_DIR="$REPO_ROOT/agents"

FILTER=""
LIST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter) FILTER="${2:-}"; shift 2 ;;
    --list)   LIST=true; shift ;;
    *) shift ;;
  esac
done

ALL_CASES=()
should_run() {
  if $LIST; then ALL_CASES+=("$1"); return 1; fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

PASS=0
FAIL=0

run_case() {
  local name="$1" expect="$2"; shift 2
  should_run "$name" || return 0
  local out
  out=$("$@" 2>&1); local rc=$?
  if [[ "$expect" == "0" && "$rc" -eq 0 ]] || [[ "$expect" != "0" && "$rc" -ne 0 ]]; then
    PASS=$((PASS+1))
    ${VERBOSE:+echo "  PASS $name"}
    return 0
  fi
  FAIL=$((FAIL+1))
  echo "  FAIL $name (exit $rc)"
  [[ -n "$out" ]] && echo "$out" | sed 's/^/    /'
}

# Helper: assert file contains string
assert_contains() {
  local name="$1" file="$2" pattern="$3"
  should_run "$name" || return 0
  if grep -q "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS+1))
    ${VERBOSE:+echo "  PASS $name"}
  else
    FAIL=$((FAIL+1))
    echo "  FAIL $name"
    echo "    expected pattern: $pattern"
    echo "    in file: $file"
  fi
}

# Helper: assert file has valid YAML frontmatter (--- block)
assert_frontmatter() {
  local name="$1" file="$2"
  should_run "$name" || return 0
  if head -1 "$file" | grep -q "^---$" && grep -q "^description:" "$file"; then
    PASS=$((PASS+1))
    ${VERBOSE:+echo "  PASS $name"}
  else
    FAIL=$((FAIL+1))
    echo "  FAIL $name — missing or malformed frontmatter in $file"
  fi
}

echo "test-commands.sh"

# ── caveman.md contract ──────────────────────────────────────────────────────

CAVEMAN="$COMMANDS_DIR/caveman.md"

assert_frontmatter "caveman: frontmatter valid" "$CAVEMAN"

assert_contains "caveman: lists all four modes" "$CAVEMAN" "off.*lite.*full.*ultra"

assert_contains "caveman: documents empty-arg stop" "$CAVEMAN" "No active mode"

assert_contains "caveman: documents unrecognized-arg stop" "$CAVEMAN" "Unknown mode"

assert_contains "caveman: no-state-tracking notice" "$CAVEMAN" "No session-state tracking"

assert_contains "caveman: off rules present" "$CAVEMAN" "Rules: off"

assert_contains "caveman: lite rules present" "$CAVEMAN" "Rules: lite"

assert_contains "caveman: full rules present" "$CAVEMAN" "Rules: full"

assert_contains "caveman: ultra rules present" "$CAVEMAN" "Rules: ultra"

assert_contains "caveman: confirms stop before Step 2 on empty/invalid" "$CAVEMAN" "do not proceed to Step 2"

# ── caveman-commit.md contract ───────────────────────────────────────────────

COMMIT="$COMMANDS_DIR/caveman-commit.md"

assert_frontmatter "caveman-commit: frontmatter valid" "$COMMIT"

assert_contains "caveman-commit: nothing-staged stop message" "$COMMIT" "Nothing staged"

assert_contains "caveman-commit: conventional commit type list" "$COMMIT" "feat.*fix.*docs.*chore"

assert_contains "caveman-commit: scope optional rule" "$COMMIT" "omit if change spans"

assert_contains "caveman-commit: subject length cap" "$COMMIT" "50 char"

assert_contains "caveman-commit: breaking-change append rule" "$COMMIT" "append \`!\` to the type/scope"

assert_contains "caveman-commit: unscoped breaking-change example" "$COMMIT" "feat!:"

assert_contains "caveman-commit: scoped breaking-change example" "$COMMIT" "feat(.*)\!:"

assert_contains "caveman-commit: no markdown fences in output" "$COMMIT" "No markdown fences"

# ── agent output-brevity contract ────────────────────────────────────────────

for agent_file in "$AGENTS_DIR"/*.md; do
  agent_name="$(basename "$agent_file" .md)"
  assert_contains "agent/$agent_name: has Output brevity section" \
    "$agent_file" "# Output brevity"
done

# ── summary ──────────────────────────────────────────────────────────────────

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

TOTAL=$((PASS+FAIL))
echo "$PASS passed, $FAIL failed (total $TOTAL)"
[[ $FAIL -eq 0 ]]
