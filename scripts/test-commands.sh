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

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      if [[ $# -lt 2 ]]; then
        echo "error: --filter requires an argument" >&2
        exit 1
      fi
      args+=(--filter "$2")
      shift 2
      ;;
    --list)
      args+=(--list)
      shift
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 1
      ;;
  esac
done
th_init --format=indent-1sp "${args[@]}"

# Helper: assert file does NOT contain pattern
assert_not_contains() {
  local name="$1" file="$2" pattern="$3"
  should_run "$name" || return 0
  if ! grep -qE "$pattern" "$file" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "unexpected pattern present: $pattern; in file: $file"
    return 1
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
    pass "$name"
  else
    fail "$name" "incomplete frontmatter (open=$has_open close=$has_close desc=$has_desc) in $file"
    return 1
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
    pass "$name"
  else
    fail "$name" "expected pattern '$pattern' inside '# ${section}' section in $file"
    return 1
  fi
}

# ── caveman.md contract ──────────────────────────────────────────────────────

CAVEMAN="$COMMANDS_DIR/caveman.md"

assert_frontmatter "caveman: frontmatter valid" "$CAVEMAN"

# All four modes must appear in the mode table
should_run "caveman: mode table has off" && assert_file_matches "caveman: mode table has off" "$CAVEMAN" "^\| \`off\`" && pass "caveman: mode table has off"
should_run "caveman: mode table has lite" && assert_file_matches "caveman: mode table has lite" "$CAVEMAN" "^\| \`lite\`" && pass "caveman: mode table has lite"
should_run "caveman: mode table has full" && assert_file_matches "caveman: mode table has full" "$CAVEMAN" "^\| \`full\`" && pass "caveman: mode table has full"
should_run "caveman: mode table has ultra" && assert_file_matches "caveman: mode table has ultra" "$CAVEMAN" "^\| \`ultra\`" && pass "caveman: mode table has ultra"

# Empty-arg behavior must be explicit and honest
should_run "caveman: empty-arg prints No active mode" && assert_file_matches "caveman: empty-arg prints No active mode" "$CAVEMAN" "No active mode\. Available:" && pass "caveman: empty-arg prints No active mode"
should_run "caveman: no-state-tracking notice" && assert_file_contains "caveman: no-state-tracking notice" "$CAVEMAN" "No session-state tracking" && pass "caveman: no-state-tracking notice"

# Unrecognized arg behavior
should_run "caveman: unrecognized-arg message format" && assert_file_matches "caveman: unrecognized-arg message format" "$CAVEMAN" "Unknown mode:.*Available:" && pass "caveman: unrecognized-arg message format"

# Must stop before Step 2 for both bad-arg cases
should_run "caveman: stop before Step 2 on empty/invalid" && assert_file_contains "caveman: stop before Step 2 on empty/invalid" "$CAVEMAN" "do not proceed to Step 2" && pass "caveman: stop before Step 2 on empty/invalid"

# Must NOT claim to track or report current mode
assert_not_contains "caveman: no false current-mode promise" \
  "$CAVEMAN" "print current mode"

# Step 2 success-path confirmation format
should_run "caveman: valid-mode confirmation format" && assert_file_contains "caveman: valid-mode confirmation format" "$CAVEMAN" "Caveman mode: <MODE>" && pass "caveman: valid-mode confirmation format"

# Each mode must have its own Rules section
should_run "caveman: rules section for off" && assert_file_matches "caveman: rules section for off" "$CAVEMAN" "^### Rules: off" && pass "caveman: rules section for off"
should_run "caveman: rules section for lite" && assert_file_matches "caveman: rules section for lite" "$CAVEMAN" "^### Rules: lite" && pass "caveman: rules section for lite"
should_run "caveman: rules section for full" && assert_file_matches "caveman: rules section for full" "$CAVEMAN" "^### Rules: full" && pass "caveman: rules section for full"
should_run "caveman: rules section for ultra" && assert_file_matches "caveman: rules section for ultra" "$CAVEMAN" "^### Rules: ultra" && pass "caveman: rules section for ultra"

# Per-mode rule content — every documented rule bullet for each mode
# Rules: off
should_run "caveman: Rules: off says no changes" && assert_file_contains "caveman: Rules: off says no changes" "$CAVEMAN" "No changes" && pass "caveman: Rules: off says no changes"
# Rules: lite (5 bullets)
should_run "caveman: Rules: lite — no opening sentence" && assert_file_contains "caveman: Rules: lite — no opening sentence" "$CAVEMAN" "No opening sentence" && pass "caveman: Rules: lite — no opening sentence"
should_run "caveman: Rules: lite — no trailing summary" && assert_file_contains "caveman: Rules: lite — no trailing summary" "$CAVEMAN" "No trailing summary" && pass "caveman: Rules: lite — no trailing summary"
should_run "caveman: Rules: lite — prefer bullets over prose" && assert_file_contains "caveman: Rules: lite — prefer bullets over prose" "$CAVEMAN" "Prefer bullet" && pass "caveman: Rules: lite — prefer bullets over prose"
should_run "caveman: Rules: lite — keep code blocks unchanged" && assert_file_contains "caveman: Rules: lite — keep code blocks unchanged" "$CAVEMAN" "Keep code blocks" && pass "caveman: Rules: lite — keep code blocks unchanged"
should_run "caveman: Rules: lite — tool description one short clause" && assert_file_contains "caveman: Rules: lite — tool description one short clause" "$CAVEMAN" "one short clause" && pass "caveman: Rules: lite — tool description one short clause"
# Rules: full (6 bullets)
should_run "caveman: Rules: full — bullets only" && assert_file_contains "caveman: Rules: full — bullets only" "$CAVEMAN" "Bullets only" && pass "caveman: Rules: full — bullets only"
should_run "caveman: Rules: full — no section headers unless" && assert_file_contains "caveman: Rules: full — no section headers unless" "$CAVEMAN" "No section headers unless" && pass "caveman: Rules: full — no section headers unless"
should_run "caveman: Rules: full — no preamble" && assert_file_contains "caveman: Rules: full — no preamble" "$CAVEMAN" "No preamble" && pass "caveman: Rules: full — no preamble"
should_run "caveman: Rules: full — no closing summary" && assert_file_contains "caveman: Rules: full — no closing summary" "$CAVEMAN" "No closing summary" && pass "caveman: Rules: full — no closing summary"
should_run "caveman: Rules: full — show diff skip explanation" && assert_file_contains "caveman: Rules: full — show diff skip explanation" "$CAVEMAN" "Show the diff or code block" && pass "caveman: Rules: full — show diff skip explanation"
should_run "caveman: Rules: full — tool description 3 words max" && assert_file_contains "caveman: Rules: full — tool description 3 words max" "$CAVEMAN" "3 words max" && pass "caveman: Rules: full — tool description 3 words max"
# Rules: ultra (6 bullets)
should_run "caveman: Rules: ultra — fragment sentences acceptable" && assert_file_contains "caveman: Rules: ultra — fragment sentences acceptable" "$CAVEMAN" "Fragment sentences" && pass "caveman: Rules: ultra — fragment sentences acceptable"
should_run "caveman: Rules: ultra — skip articles" && assert_file_contains "caveman: Rules: ultra — skip articles" "$CAVEMAN" "Skip articles" && pass "caveman: Rules: ultra — skip articles"
should_run "caveman: Rules: ultra — no bullet symbols" && assert_file_contains "caveman: Rules: ultra — no bullet symbols" "$CAVEMAN" "No bullet symbols" && pass "caveman: Rules: ultra — no bullet symbols"
should_run "caveman: Rules: ultra — no headers" && assert_file_contains "caveman: Rules: ultra — no headers" "$CAVEMAN" "No headers" && pass "caveman: Rules: ultra — no headers"
should_run "caveman: Rules: ultra — single-word acknowledgements" && assert_file_contains "caveman: Rules: ultra — single-word acknowledgements" "$CAVEMAN" "Single-word acknowledgements" && pass "caveman: Rules: ultra — single-word acknowledgements"
should_run "caveman: Rules: ultra — tool description omit entirely" && assert_file_contains "caveman: Rules: ultra — tool description omit entirely" "$CAVEMAN" "omit entirely" && pass "caveman: Rules: ultra — tool description omit entirely"

# ── caveman-commit.md contract ───────────────────────────────────────────────

COMMIT="$COMMANDS_DIR/caveman-commit.md"

assert_frontmatter "caveman-commit: frontmatter valid" "$COMMIT"

# Nothing-staged must stop with exact message
should_run "caveman-commit: nothing-staged stop message" && assert_file_matches "caveman-commit: nothing-staged stop message" "$COMMIT" "Nothing staged\. Run git add first" && pass "caveman-commit: nothing-staged stop message"

# Must document all required conventional commit types
should_run "caveman-commit: type feat present" && assert_file_contains "caveman-commit: type feat present" "$COMMIT" "\`feat\`" && pass "caveman-commit: type feat present"
should_run "caveman-commit: type fix present" && assert_file_contains "caveman-commit: type fix present" "$COMMIT" "\`fix\`" && pass "caveman-commit: type fix present"
should_run "caveman-commit: type docs present" && assert_file_contains "caveman-commit: type docs present" "$COMMIT" "\`docs\`" && pass "caveman-commit: type docs present"
should_run "caveman-commit: type chore present" && assert_file_contains "caveman-commit: type chore present" "$COMMIT" "\`chore\`" && pass "caveman-commit: type chore present"
should_run "caveman-commit: type refactor present" && assert_file_contains "caveman-commit: type refactor present" "$COMMIT" "\`refactor\`" && pass "caveman-commit: type refactor present"
should_run "caveman-commit: type test present" && assert_file_contains "caveman-commit: type test present" "$COMMIT" "\`test\`" && pass "caveman-commit: type test present"
should_run "caveman-commit: type ci present" && assert_file_contains "caveman-commit: type ci present" "$COMMIT" "\`ci\`" && pass "caveman-commit: type ci present"

# Scope optional rule
should_run "caveman-commit: scope optional for broad changes" && assert_file_contains "caveman-commit: scope optional for broad changes" "$COMMIT" "omit if change spans" && pass "caveman-commit: scope optional for broad changes"

# Subject contract: imperative, lowercase, ≤ 50 chars, no trailing period
should_run "caveman-commit: subject imperative rule" && assert_file_contains "caveman-commit: subject imperative rule" "$COMMIT" "imperative" && pass "caveman-commit: subject imperative rule"
should_run "caveman-commit: subject lowercase rule" && assert_file_contains "caveman-commit: subject lowercase rule" "$COMMIT" "lowercase" && pass "caveman-commit: subject lowercase rule"
should_run "caveman-commit: subject no-trailing-period rule" && assert_file_contains "caveman-commit: subject no-trailing-period rule" "$COMMIT" "no trailing period" && pass "caveman-commit: subject no-trailing-period rule"
should_run "caveman-commit: subject 50-char cap" && assert_file_contains "caveman-commit: subject 50-char cap" "$COMMIT" "50 char" && pass "caveman-commit: subject 50-char cap"

# Breaking-change rule: must say "append ! to type/scope" (not "prefix subject")
should_run "caveman-commit: breaking-change uses append wording" && assert_file_contains "caveman-commit: breaking-change uses append wording" "$COMMIT" "append \`!\` to the type/scope" && pass "caveman-commit: breaking-change uses append wording"
assert_not_contains "caveman-commit: no stale prefix-subject wording" \
  "$COMMIT" "prefix subject with"

# Both scoped and unscoped examples must be present
should_run "caveman-commit: unscoped breaking-change example" && assert_file_contains "caveman-commit: unscoped breaking-change example" "$COMMIT" "feat!:" && pass "caveman-commit: unscoped breaking-change example"
should_run "caveman-commit: scoped breaking-change example" && assert_file_matches "caveman-commit: scoped breaking-change example" "$COMMIT" "feat\(.*\)!:" && pass "caveman-commit: scoped breaking-change example"

# $ARGUMENTS hint path must be documented
should_run "caveman-commit: arguments hint for subject" && assert_file_matches "caveman-commit: arguments hint for subject" "$COMMIT" "\\\$ARGUMENTS.*hint" && pass "caveman-commit: arguments hint for subject"

# Output must be plain text, no fences
should_run "caveman-commit: no markdown fences in output" && assert_file_contains "caveman-commit: no markdown fences in output" "$COMMIT" "No markdown fences" && pass "caveman-commit: no markdown fences in output"

# Co-Authored-By trailer must not appear (caller adds it separately)
should_run "caveman-commit: no Co-Authored-By trailer" && assert_file_matches "caveman-commit: no Co-Authored-By trailer" "$COMMIT" "No.*Co-Authored-By.*trailer" && pass "caveman-commit: no Co-Authored-By trailer"

# Body is suppressed by default; only allowed for breaking change or non-obvious constraint
should_run "caveman-commit: no body unless breaking change or constraint" && assert_file_contains "caveman-commit: no body unless breaking change or constraint" "$COMMIT" "No body unless" && pass "caveman-commit: no body unless breaking change or constraint"

# BREAKING CHANGE footer format must be documented
should_run "caveman-commit: BREAKING CHANGE footer documented" && assert_file_contains "caveman-commit: BREAKING CHANGE footer documented" "$COMMIT" "BREAKING CHANGE:" && pass "caveman-commit: BREAKING CHANGE footer documented"

# Step 1 staged-diff read commands must be documented
should_run "caveman-commit: reads git diff --cached --stat" && assert_file_contains "caveman-commit: reads git diff --cached --stat" "$COMMIT" "git diff --cached --stat" && pass "caveman-commit: reads git diff --cached --stat"
should_run "caveman-commit: reads git diff --cached" && assert_file_matches "caveman-commit: reads git diff --cached" "$COMMIT" "^git diff --cached$" && pass "caveman-commit: reads git diff --cached"

# Output format shape must be documented
should_run "caveman-commit: output format has type placeholder" && assert_file_contains "caveman-commit: output format has type placeholder" "$COMMIT" "<type>" && pass "caveman-commit: output format has type placeholder"
should_run "caveman-commit: output format has subject placeholder" && assert_file_contains "caveman-commit: output format has subject placeholder" "$COMMIT" "<subject>" && pass "caveman-commit: output format has subject placeholder"

# Breaking-change trigger conditions must be enumerated
should_run "caveman-commit: breaking-change trigger removes public interface" && assert_file_contains "caveman-commit: breaking-change trigger removes public interface" "$COMMIT" "removes a public interface" && pass "caveman-commit: breaking-change trigger removes public interface"
should_run "caveman-commit: breaking-change trigger renames hook script" && assert_file_contains "caveman-commit: breaking-change trigger renames hook script" "$COMMIT" "renames a hook script" && pass "caveman-commit: breaking-change trigger renames hook script"
should_run "caveman-commit: breaking-change trigger changes required schema field" && assert_file_contains "caveman-commit: breaking-change trigger changes required schema field" "$COMMIT" "changes a required schema field" && pass "caveman-commit: breaking-change trigger changes required schema field"

# Non-obvious constraint body exception one-line max
should_run "caveman-commit: non-obvious constraint body exception" && assert_file_contains "caveman-commit: non-obvious constraint body exception" "$COMMIT" "non-obvious constraint" && pass "caveman-commit: non-obvious constraint body exception"

# ── pre-impl.md Q4 contract ──────────────────────────────────────────────────

PRE_IMPL="$COMMANDS_DIR/pre-impl.md"

assert_frontmatter "pre-impl: frontmatter valid" "$PRE_IMPL"
should_run "pre-impl: Q4 heading present" && assert_file_contains "pre-impl: Q4 heading present" "$PRE_IMPL" "Q4" && pass "pre-impl: Q4 heading present"
should_run "pre-impl: Q4 skip condition documented" && assert_file_contains "pre-impl: Q4 skip condition documented" "$PRE_IMPL" "Skip this question if the brief only modifies" && pass "pre-impl: Q4 skip condition documented"
should_run "pre-impl: Q4 enumerates input states" && assert_file_contains "pre-impl: Q4 enumerates input states" "$PRE_IMPL" "input state" && pass "pre-impl: Q4 enumerates input states"
should_run "pre-impl: Q4 enumerates output formats" && assert_file_contains "pre-impl: Q4 enumerates output formats" "$PRE_IMPL" "output format" && pass "pre-impl: Q4 enumerates output formats"
should_run "pre-impl: Q4 enumerates rule sections" && assert_file_contains "pre-impl: Q4 enumerates rule sections" "$PRE_IMPL" "rule section" && pass "pre-impl: Q4 enumerates rule sections"
should_run "pre-impl: Q4 enumerates stop conditions" && assert_file_contains "pre-impl: Q4 enumerates stop conditions" "$PRE_IMPL" "stop condition" && pass "pre-impl: Q4 enumerates stop conditions"

# ── agent output-brevity contract ────────────────────────────────────────────

for agent_file in "$AGENTS_DIR"/*.md; do
  agent_name="$(basename "$agent_file" .md)"
  should_run "agent/$agent_name: has Output brevity section" && assert_file_matches "agent/$agent_name: has Output brevity section" "$agent_file" "^# Output brevity" && pass "agent/$agent_name: has Output brevity section"
  assert_in_section "agent/$agent_name: brevity section says No preamble" \
    "$agent_file" "Output brevity" "No preamble"
  assert_in_section "agent/$agent_name: brevity section says no closing summary" \
    "$agent_file" "Output brevity" "closing summary"
  assert_in_section "agent/$agent_name: brevity section says English only" \
    "$agent_file" "Output brevity" "English only"
done

# ── summary ──────────────────────────────────────────────────────────────────

th_summary
