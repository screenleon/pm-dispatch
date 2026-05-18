#!/usr/bin/env bash
# Contract-lint tests for slash commands in commands/.
#
# These are structural tests — they verify that command files are
# internally consistent and contain required sections. They do NOT
# test Claude's runtime behaviour (that's untestable here).
#
# Usage:
#   scripts/test-commands.sh           # prints header + summary; VERBOSE=1 prints every case
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
    *) echo "error: unknown option: $1" >&2; exit 1 ;;
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

# Helper: assert file has complete YAML frontmatter (opening ---, closing ---, description field)
assert_frontmatter() {
  local name="$1" file="$2"
  should_run "$name" || return 0
  # opening --- on line 1, at least one more --- (closing delimiter), description: field
  local has_open has_close has_desc
  has_open=$(head -1 "$file" | grep -c "^---$" || true)
  has_close=$(awk '/^---$/{c++} c==2{found=1;exit} END{print (found ? 1 : 0)}' "$file")
  has_desc=$(grep -c "^description:" "$file" || true)
  if [[ "$has_open" -ge 1 && "$has_close" -eq 1 && "$has_desc" -ge 1 ]]; then
    PASS=$((PASS+1))
    ${VERBOSE:+echo "  PASS $name"}
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    echo "  FAIL $name — incomplete frontmatter (open=$has_open close=$has_close desc=$has_desc) in $file"
  fi
}

# Helper: assert pattern appears WITHIN a named section (after "# <section>" heading)
assert_in_section() {
  local name="$1" file="$2" section="$3" pattern="$4"
  should_run "$name" || return 0
  # Extract lines from the section heading to the next same-level heading
  local found
  found=$(awk "/^# ${section}/{in_sec=1; next} in_sec && /^# /{exit} in_sec && /${pattern}/{found=1} END{print (found ? 1 : 0)}" "$file")
  if [[ "$found" -eq 1 ]]; then
    PASS=$((PASS+1))
    ${VERBOSE:+echo "  PASS $name"}
  else
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
    echo "  FAIL $name"
    echo "    expected pattern '$pattern' inside '# ${section}' section"
    echo "    in file: $file"
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

# Step 2 success-path confirmation format
assert_contains "caveman: valid-mode confirmation format" \
  "$CAVEMAN" "Caveman mode: <MODE>"

# Each mode must have its own Rules section
assert_contains "caveman: rules section for off"   "$CAVEMAN" "^### Rules: off"
assert_contains "caveman: rules section for lite"  "$CAVEMAN" "^### Rules: lite"
assert_contains "caveman: rules section for full"  "$CAVEMAN" "^### Rules: full"
assert_contains "caveman: rules section for ultra" "$CAVEMAN" "^### Rules: ultra"

# Per-mode rule content — every documented rule bullet for each mode
# Rules: off
assert_contains "caveman: Rules: off says no changes" \
  "$CAVEMAN" "No changes"
# Rules: lite (5 bullets)
assert_contains "caveman: Rules: lite — no opening sentence" \
  "$CAVEMAN" "No opening sentence"
assert_contains "caveman: Rules: lite — no trailing summary" \
  "$CAVEMAN" "No trailing summary"
assert_contains "caveman: Rules: lite — prefer bullets over prose" \
  "$CAVEMAN" "Prefer bullet"
assert_contains "caveman: Rules: lite — keep code blocks unchanged" \
  "$CAVEMAN" "Keep code blocks"
assert_contains "caveman: Rules: lite — tool description one short clause" \
  "$CAVEMAN" "one short clause"
# Rules: full (6 bullets)
assert_contains "caveman: Rules: full — bullets only" \
  "$CAVEMAN" "Bullets only"
assert_contains "caveman: Rules: full — no section headers unless" \
  "$CAVEMAN" "No section headers unless"
assert_contains "caveman: Rules: full — no preamble" \
  "$CAVEMAN" "No preamble"
assert_contains "caveman: Rules: full — no closing summary" \
  "$CAVEMAN" "No closing summary"
assert_contains "caveman: Rules: full — show diff skip explanation" \
  "$CAVEMAN" "Show the diff or code block"
assert_contains "caveman: Rules: full — tool description 3 words max" \
  "$CAVEMAN" "3 words max"
# Rules: ultra (6 bullets)
assert_contains "caveman: Rules: ultra — fragment sentences acceptable" \
  "$CAVEMAN" "Fragment sentences"
assert_contains "caveman: Rules: ultra — skip articles" \
  "$CAVEMAN" "Skip articles"
assert_contains "caveman: Rules: ultra — no bullet symbols" \
  "$CAVEMAN" "No bullet symbols"
assert_contains "caveman: Rules: ultra — no headers" \
  "$CAVEMAN" "No headers"
assert_contains "caveman: Rules: ultra — single-word acknowledgements" \
  "$CAVEMAN" "Single-word acknowledgements"
assert_contains "caveman: Rules: ultra — tool description omit entirely" \
  "$CAVEMAN" "omit entirely"

# ── caveman-commit.md contract ───────────────────────────────────────────────

COMMIT="$COMMANDS_DIR/caveman-commit.md"

assert_frontmatter "caveman-commit: frontmatter valid" "$COMMIT"

# Nothing-staged must stop with exact message
assert_contains "caveman-commit: nothing-staged stop message" \
  "$COMMIT" "Nothing staged\. Run git add first"

# Must document all required conventional commit types
assert_contains "caveman-commit: type feat present"     "$COMMIT" "\`feat\`"
assert_contains "caveman-commit: type fix present"      "$COMMIT" "\`fix\`"
assert_contains "caveman-commit: type docs present"     "$COMMIT" "\`docs\`"
assert_contains "caveman-commit: type chore present"    "$COMMIT" "\`chore\`"
assert_contains "caveman-commit: type refactor present" "$COMMIT" "\`refactor\`"
assert_contains "caveman-commit: type test present"     "$COMMIT" "\`test\`"
assert_contains "caveman-commit: type ci present"       "$COMMIT" "\`ci\`"

# Scope optional rule
assert_contains "caveman-commit: scope optional for broad changes" \
  "$COMMIT" "omit if change spans"

# Subject contract: imperative, lowercase, ≤ 50 chars, no trailing period
assert_contains "caveman-commit: subject imperative rule" "$COMMIT" "imperative"
assert_contains "caveman-commit: subject lowercase rule" "$COMMIT" "lowercase"
assert_contains "caveman-commit: subject no-trailing-period rule" "$COMMIT" "no trailing period"
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

# $ARGUMENTS hint path must be documented
assert_contains "caveman-commit: arguments hint for subject" \
  "$COMMIT" "\\\$ARGUMENTS.*hint"

# Output must be plain text, no fences
assert_contains "caveman-commit: no markdown fences in output" \
  "$COMMIT" "No markdown fences"

# Co-Authored-By trailer must not appear (caller adds it separately)
assert_contains "caveman-commit: no Co-Authored-By trailer" \
  "$COMMIT" "No.*Co-Authored-By.*trailer"

# Body is suppressed by default; only allowed for breaking change or non-obvious constraint
assert_contains "caveman-commit: no body unless breaking change or constraint" \
  "$COMMIT" "No body unless"

# BREAKING CHANGE footer format must be documented
assert_contains "caveman-commit: BREAKING CHANGE footer documented" \
  "$COMMIT" "BREAKING CHANGE:"

# Step 1 staged-diff read commands must be documented
assert_contains "caveman-commit: reads git diff --cached --stat" \
  "$COMMIT" "git diff --cached --stat"
assert_contains "caveman-commit: reads git diff --cached" \
  "$COMMIT" "^git diff --cached$"

# Output format shape must be documented
assert_contains "caveman-commit: output format has type placeholder" \
  "$COMMIT" "<type>"
assert_contains "caveman-commit: output format has subject placeholder" \
  "$COMMIT" "<subject>"

# Breaking-change trigger conditions must be enumerated
assert_contains "caveman-commit: breaking-change trigger removes public interface" \
  "$COMMIT" "removes a public interface"
assert_contains "caveman-commit: breaking-change trigger renames hook script" \
  "$COMMIT" "renames a hook script"
assert_contains "caveman-commit: breaking-change trigger changes required schema field" \
  "$COMMIT" "changes a required schema field"

# Non-obvious constraint body exception one-line max
assert_contains "caveman-commit: non-obvious constraint body exception" \
  "$COMMIT" "non-obvious constraint"

# ── pre-impl.md Q4 contract ──────────────────────────────────────────────────

PRE_IMPL="$COMMANDS_DIR/pre-impl.md"

assert_frontmatter "pre-impl: frontmatter valid" "$PRE_IMPL"
assert_contains "pre-impl: Q4 heading present" \
  "$PRE_IMPL" "Q4"
assert_contains "pre-impl: Q4 skip condition documented" \
  "$PRE_IMPL" "Skip this question if the brief only modifies"
assert_contains "pre-impl: Q4 enumerates input states" \
  "$PRE_IMPL" "input state"
assert_contains "pre-impl: Q4 enumerates output formats" \
  "$PRE_IMPL" "output format"
assert_contains "pre-impl: Q4 enumerates rule sections" \
  "$PRE_IMPL" "rule section"
assert_contains "pre-impl: Q4 enumerates stop conditions" \
  "$PRE_IMPL" "stop condition"

# ── agent output-brevity contract ────────────────────────────────────────────

for agent_file in "$AGENTS_DIR"/*.md; do
  agent_name="$(basename "$agent_file" .md)"
  assert_contains "agent/$agent_name: has Output brevity section" \
    "$agent_file" "^# Output brevity"
  assert_in_section "agent/$agent_name: brevity section says No preamble" \
    "$agent_file" "Output brevity" "No preamble"
  assert_in_section "agent/$agent_name: brevity section says no closing summary" \
    "$agent_file" "Output brevity" "closing summary"
  assert_in_section "agent/$agent_name: brevity section says English only" \
    "$agent_file" "Output brevity" "English only"
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
