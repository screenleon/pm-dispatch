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
    --filter)
      if [[ $# -lt 2 ]]; then
        echo "error: --filter requires an argument" >&2; exit 1
      fi
      FILTER="$2"; shift 2 ;;
    --list) LIST=true; shift ;;
    *) shift ;;
  esac
done

ALL_CASES=()
FAILED_CASES=()

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
  FAILED_CASES+=("$name")
  echo "  FAIL $name (exit $rc)"
  [[ -n "$out" ]] && echo "$out" | sed 's/^/    /'
}

# Helper: assert file contains pattern (grep -E)
assert_contains() {
  local name="$1" file="$2" pattern="$3"
  should_run "$name" || return 0
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS+1))
    ${VERBOSE:+echo "  PASS $name"}
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    echo "  FAIL $name"
    echo "    expected pattern: $pattern"
    echo "    in file: $file"
  fi
}

# Helper: assert file does NOT contain pattern
assert_not_contains() {
  local name="$1" file="$2" pattern="$3"
  should_run "$name" || return 0
  if ! grep -qE "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS+1))
    ${VERBOSE:+echo "  PASS $name"}
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    echo "  FAIL $name"
    echo "    unexpected pattern present: $pattern"
    echo "    in file: $file"
  fi
}

# Helper: assert file has valid YAML frontmatter (--- block + description field)
assert_frontmatter() {
  local name="$1" file="$2"
  should_run "$name" || return 0
  if head -1 "$file" | grep -q "^---$" && grep -q "^description:" "$file"; then
    PASS=$((PASS+1))
    ${VERBOSE:+echo "  PASS $name"}
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    echo "  FAIL $name — missing or malformed frontmatter in $file"
  fi
}

echo "test-commands.sh"

# ── caveman.md contract ──────────────────────────────────────────────────────

CAVEMAN="$COMMANDS_DIR/caveman.md"

assert_frontmatter "caveman: frontmatter valid" "$CAVEMAN"

# All four modes must appear in the mode table
assert_contains "caveman: mode table has off"   "$CAVEMAN" "^\| \`off\`"
assert_contains "caveman: mode table has lite"  "$CAVEMAN" "^\| \`lite\`"
assert_contains "caveman: mode table has full"  "$CAVEMAN" "^\| \`full\`"
assert_contains "caveman: mode table has ultra" "$CAVEMAN" "^\| \`ultra\`"

# Empty-arg behavior must be explicit and honest
assert_contains "caveman: empty-arg prints No active mode" \
  "$CAVEMAN" "No active mode\. Available:"
assert_contains "caveman: no-state-tracking notice" \
  "$CAVEMAN" "No session-state tracking"

# Unrecognized arg behavior
assert_contains "caveman: unrecognized-arg message format" \
  "$CAVEMAN" "Unknown mode:.*Available:"

# Must stop before Step 2 for both bad-arg cases
assert_contains "caveman: stop before Step 2 on empty/invalid" \
  "$CAVEMAN" "do not proceed to Step 2"

# Must NOT claim to track or report current mode
assert_not_contains "caveman: no false current-mode promise" \
  "$CAVEMAN" "print current mode"

# Each mode must have its own Rules section
assert_contains "caveman: rules section for off"   "$CAVEMAN" "^### Rules: off"
assert_contains "caveman: rules section for lite"  "$CAVEMAN" "^### Rules: lite"
assert_contains "caveman: rules section for full"  "$CAVEMAN" "^### Rules: full"
assert_contains "caveman: rules section for ultra" "$CAVEMAN" "^### Rules: ultra"

# ── caveman-commit.md contract ───────────────────────────────────────────────

COMMIT="$COMMANDS_DIR/caveman-commit.md"

assert_frontmatter "caveman-commit: frontmatter valid" "$COMMIT"

# Nothing-staged must stop with exact message
assert_contains "caveman-commit: nothing-staged stop message" \
  "$COMMIT" "Nothing staged\. Run git add first"

# Must document all required conventional commit types
assert_contains "caveman-commit: type feat present"   "$COMMIT" "\`feat\`"
assert_contains "caveman-commit: type fix present"    "$COMMIT" "\`fix\`"
assert_contains "caveman-commit: type chore present"  "$COMMIT" "\`chore\`"

# Scope optional rule
assert_contains "caveman-commit: scope optional for broad changes" \
  "$COMMIT" "omit if change spans"

# Subject length cap (must reference 50)
assert_contains "caveman-commit: subject 50-char cap" "$COMMIT" "50 char"

# Breaking-change rule: must say "append ! to type/scope" (not "prefix subject")
assert_contains "caveman-commit: breaking-change uses append wording" \
  "$COMMIT" "append \`!\` to the type/scope"
assert_not_contains "caveman-commit: no stale prefix-subject wording" \
  "$COMMIT" "prefix subject with"

# Both scoped and unscoped examples must be present
assert_contains "caveman-commit: unscoped breaking-change example" \
  "$COMMIT" "feat!:"
assert_contains "caveman-commit: scoped breaking-change example" \
  "$COMMIT" "feat\(.*\)!:"

# Output must be plain text, no fences
assert_contains "caveman-commit: no markdown fences in output" \
  "$COMMIT" "No markdown fences"

# ── agent output-brevity contract ────────────────────────────────────────────

for agent_file in "$AGENTS_DIR"/*.md; do
  agent_name="$(basename "$agent_file" .md)"
  assert_contains "agent/$agent_name: has Output brevity section" \
    "$agent_file" "^# Output brevity"
  assert_contains "agent/$agent_name: brevity section says No preamble" \
    "$agent_file" "No preamble"
  assert_contains "agent/$agent_name: brevity section says English only" \
    "$agent_file" "English only"
done

# ── summary ──────────────────────────────────────────────────────────────────

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

# Fail if --filter matched nothing (prevents silent false-green on typos)
if [[ -n "$FILTER" && $((PASS+FAIL)) -eq 0 ]]; then
  printf 'no tests matched filter %q — check --list for available case names\n' \
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
