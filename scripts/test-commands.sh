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

# ── mem-distill.md anomaly-slice contract ────────────────────────────────────

MEM_DISTILL="$COMMANDS_DIR/mem-distill.md"

assert_frontmatter "mem-distill: frontmatter valid" "$MEM_DISTILL"
should_run "mem-distill: has Step 2b" && assert_file_contains "mem-distill: has Step 2b" "$MEM_DISTILL" "Step 2b" && pass "mem-distill: has Step 2b"
should_run "mem-distill: documents run.failed anomaly kind" && assert_file_contains "mem-distill: documents run.failed anomaly kind" "$MEM_DISTILL" "run.failed" && pass "mem-distill: documents run.failed anomaly kind"
should_run "mem-distill: documents guard.denied anomaly kind" && assert_file_contains "mem-distill: documents guard.denied anomaly kind" "$MEM_DISTILL" "guard.denied" && pass "mem-distill: documents guard.denied anomaly kind"
should_run "mem-distill: defines timeout exit class" && assert_file_contains "mem-distill: defines timeout exit class" "$MEM_DISTILL" "timeout" && pass "mem-distill: defines timeout exit class"
should_run "mem-distill: report includes anomaly count" && assert_file_contains "mem-distill: report includes anomaly count" "$MEM_DISTILL" "anomaly group" && pass "mem-distill: report includes anomaly count"
should_run "mem-distill: no python3 calls" && assert_not_contains "mem-distill: no python3 calls" "$MEM_DISTILL" "python3"
should_run "mem-distill: Step 2b uses pmctl trace tail" && assert_file_contains "mem-distill: Step 2b uses pmctl trace tail" "$MEM_DISTILL" "pmctl trace tail" && pass "mem-distill: Step 2b uses pmctl trace tail"

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
