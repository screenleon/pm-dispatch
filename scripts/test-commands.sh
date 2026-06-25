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
should_run "mem-distill: documents task.blocked anomaly kind" && assert_file_contains "mem-distill: documents task.blocked anomaly kind" "$MEM_DISTILL" "task.blocked" && pass "mem-distill: documents task.blocked anomaly kind"
should_run "mem-distill: defines exit_code 124 as timeout" && assert_file_contains "mem-distill: defines exit_code 124 as timeout" "$MEM_DISTILL" "exit_code == 124" && pass "mem-distill: defines exit_code 124 as timeout"
should_run "mem-distill: report includes anomaly count" && assert_file_contains "mem-distill: report includes anomaly count" "$MEM_DISTILL" "anomaly group" && pass "mem-distill: report includes anomaly count"
should_run "mem-distill: no python3 calls" && assert_not_contains "mem-distill: no python3 calls" "$MEM_DISTILL" "python3"
should_run "mem-distill: Step 2b uses pmctl trace tail" && assert_file_contains "mem-distill: Step 2b uses pmctl trace tail" "$MEM_DISTILL" "pmctl trace tail" && pass "mem-distill: Step 2b uses pmctl trace tail"
# Step 1 shell lookup contract
should_run "mem-distill: Step 1 references CLAUDE_CONFIG_DIR" && assert_file_contains "mem-distill: Step 1 references CLAUDE_CONFIG_DIR" "$MEM_DISTILL" "CLAUDE_CONFIG_DIR" && pass "mem-distill: Step 1 references CLAUDE_CONFIG_DIR"
should_run "mem-distill: Step 1 walks parent directories" && assert_file_contains "mem-distill: Step 1 walks parent directories" "$MEM_DISTILL" "dirname" && pass "mem-distill: Step 1 walks parent directories"
# Step 3b anomaly policy rules
should_run "mem-distill: Step 3b defines 60-day age cutoff" && assert_file_contains "mem-distill: Step 3b defines 60-day age cutoff" "$MEM_DISTILL" "60 days" && pass "mem-distill: Step 3b defines 60-day age cutoff"
should_run "mem-distill: Step 3b defines recurrence threshold" && assert_file_contains "mem-distill: Step 3b defines recurrence threshold" "$MEM_DISTILL" "2 occurrences" && pass "mem-distill: Step 3b defines recurrence threshold"
should_run "mem-distill: Step 3b defines guard.denied prefix grouping" && assert_file_contains "mem-distill: Step 3b defines guard.denied prefix grouping" "$MEM_DISTILL" "denied path prefix" && pass "mem-distill: Step 3b defines guard.denied prefix grouping"
should_run "mem-distill: Step 3b defines resolved-run skip rule" && assert_file_contains "mem-distill: Step 3b defines resolved-run skip rule" "$MEM_DISTILL" "followed by a successful run" && pass "mem-distill: Step 3b defines resolved-run skip rule"
should_run "mem-distill: Step 2b captures event id field" && assert_file_contains "mem-distill: Step 2b captures event id field" "$MEM_DISTILL" "evt-" && pass "mem-distill: Step 2b captures event id field"
should_run "mem-distill: Step 2b documents exit_code 0 as ok" && assert_file_contains "mem-distill: Step 2b documents exit_code 0 as ok" "$MEM_DISTILL" "exit_code == 0" && pass "mem-distill: Step 2b documents exit_code 0 as ok"
should_run "mem-distill: Step 2b documents non-zero failure class" && assert_file_contains "mem-distill: Step 2b documents non-zero failure class" "$MEM_DISTILL" "non-zero" && pass "mem-distill: Step 2b documents non-zero failure class"
should_run "mem-distill: Step 2b documents no-output skip" && assert_file_contains "mem-distill: Step 2b documents no-output skip" "$MEM_DISTILL" "no output" && pass "mem-distill: Step 2b documents no-output skip"
should_run "mem-distill: Step 3b cites event id in proposals" && assert_file_contains "mem-distill: Step 3b cites event id in proposals" "$MEM_DISTILL" "cite the event" && pass "mem-distill: Step 3b cites event id in proposals"
should_run "mem-distill: Step 3b defines guard.denied path field" && assert_file_contains "mem-distill: Step 3b defines guard.denied path field" "$MEM_DISTILL" "payload.path" && pass "mem-distill: Step 3b defines guard.denied path field"
# kind-specific payload contract — guard/task anomalies must not be forced through run-only fields
should_run "mem-distill: kind-specific payload table documented" && assert_file_contains "mem-distill: kind-specific payload table documented" "$MEM_DISTILL" "Payload fields differ by kind" && pass "mem-distill: kind-specific payload table documented"
should_run "mem-distill: task.blocked uses from_state field" && assert_file_contains "mem-distill: task.blocked uses from_state field" "$MEM_DISTILL" "from_state" && pass "mem-distill: task.blocked uses from_state field"
should_run "mem-distill: task.blocked grouped by state transition" && assert_file_contains "mem-distill: task.blocked grouped by state transition" "$MEM_DISTILL" "from_state, to_state" && pass "mem-distill: task.blocked grouped by state transition"
# gate block / blocked review verdict contract
should_run "mem-distill: documents review.verdict event kind" && assert_file_contains "mem-distill: documents review.verdict event kind" "$MEM_DISTILL" "review.verdict" && pass "mem-distill: documents review.verdict event kind"
should_run "mem-distill: review.verdict payload.verdict documented" && assert_file_contains "mem-distill: review.verdict payload.verdict documented" "$MEM_DISTILL" "payload.verdict" && pass "mem-distill: review.verdict payload.verdict documented"
should_run "mem-distill: gate block fallback to gate-results documented" && assert_file_contains "mem-distill: gate block fallback to gate-results documented" "$MEM_DISTILL" ".gate-results" && pass "mem-distill: gate block fallback to gate-results documented"
# Step 6 frontmatter enforce contract
should_run "mem-distill: Step 6 ADD blocks write on missing fields" && assert_file_contains "mem-distill: Step 6 ADD blocks write on missing fields" "$MEM_DISTILL" "do NOT write the file" && pass "mem-distill: Step 6 ADD blocks write on missing fields"
should_run "mem-distill: Step 6 ADD names missing fields in error" && assert_file_contains "mem-distill: Step 6 ADD names missing fields in error" "$MEM_DISTILL" "missing required frontmatter fields" && pass "mem-distill: Step 6 ADD names missing fields in error"
should_run "mem-distill: Step 6 ADD error includes Cannot write prefix" && assert_file_contains "mem-distill: Step 6 ADD error includes Cannot write prefix" "$MEM_DISTILL" "Cannot write" && pass "mem-distill: Step 6 ADD error includes Cannot write prefix"
should_run "mem-distill: Step 6 references memory-system.md schema" && assert_file_contains "mem-distill: Step 6 references memory-system.md schema" "$MEM_DISTILL" "docs/memory-system.md" && pass "mem-distill: Step 6 references memory-system.md schema"
should_run "mem-distill: Step 6 lists topics as required field" && assert_file_contains "mem-distill: Step 6 lists topics as required field" "$MEM_DISTILL" "topics" && pass "mem-distill: Step 6 lists topics as required field"
should_run "mem-distill: Step 6 lists repo_refs as required field" && assert_file_contains "mem-distill: Step 6 lists repo_refs as required field" "$MEM_DISTILL" "repo_refs" && pass "mem-distill: Step 6 lists repo_refs as required field"

# ── mem-log.md contract ──────────────────────────────────────────────────────

MEM_LOG="$COMMANDS_DIR/mem-log.md"

assert_frontmatter "mem-log: frontmatter valid" "$MEM_LOG"
should_run "mem-log: no python3 calls" && assert_not_contains "mem-log: no python3 calls" "$MEM_LOG" "python3"
should_run "mem-log: Step 1 uses pmctl memory dir" && assert_file_contains "mem-log: Step 1 uses pmctl memory dir" "$MEM_LOG" "pmctl memory dir" && pass "mem-log: Step 1 uses pmctl memory dir"
should_run "mem-log: Step 1 derives episodes.jsonl path" && assert_file_contains "mem-log: Step 1 derives episodes.jsonl path" "$MEM_LOG" "episodes.jsonl" && pass "mem-log: Step 1 derives episodes.jsonl path"
should_run "mem-log: Step 1 handles no memory dir error" && assert_file_contains "mem-log: Step 1 handles no memory dir error" "$MEM_LOG" "No memory directory found for this project" && pass "mem-log: Step 1 handles no memory dir error"
should_run "mem-log: Step 1 allows missing file on first log" && assert_file_contains "mem-log: Step 1 allows missing file on first log" "$MEM_LOG" "may not exist" && pass "mem-log: Step 1 allows missing file on first log"

# ── mem-recall.md contract ────────────────────────────────────────────────────

MEM_RECALL="$COMMANDS_DIR/mem-recall.md"

assert_frontmatter "mem-recall: frontmatter valid" "$MEM_RECALL"
should_run "mem-recall: no python3 calls" && assert_not_contains "mem-recall: no python3 calls" "$MEM_RECALL" "python3"
should_run "mem-recall: Step 1 uses pmctl memory dir" && assert_file_contains "mem-recall: Step 1 uses pmctl memory dir" "$MEM_RECALL" "pmctl memory dir" && pass "mem-recall: Step 1 uses pmctl memory dir"
should_run "mem-recall: Step 1 derives episodes.jsonl path" && assert_file_contains "mem-recall: Step 1 derives episodes.jsonl path" "$MEM_RECALL" "episodes.jsonl" && pass "mem-recall: Step 1 derives episodes.jsonl path"
should_run "mem-recall: Step 1 guards file existence" && assert_file_contains "mem-recall: Step 1 guards file existence" "$MEM_RECALL" '[[ -f "$ep" ]]' && pass "mem-recall: Step 1 guards file existence"
should_run "mem-recall: Step 1 error message for missing episodes" && assert_file_contains "mem-recall: Step 1 error message for missing episodes" "$MEM_RECALL" "No episodes found for this project" && pass "mem-recall: Step 1 error message for missing episodes"

# ── memory-compress.md contract ───────────────────────────────────────────────

MEMORY_COMPRESS="$COMMANDS_DIR/memory-compress.md"

assert_frontmatter "memory-compress: frontmatter valid" "$MEMORY_COMPRESS"
should_run "memory-compress: no python3 calls" && assert_not_contains "memory-compress: no python3 calls" "$MEMORY_COMPRESS" "python3"
should_run "memory-compress: Step 1 uses pmctl memory dir" && assert_file_contains "memory-compress: Step 1 uses pmctl memory dir" "$MEMORY_COMPRESS" "pmctl memory dir" && pass "memory-compress: Step 1 uses pmctl memory dir"
should_run "memory-compress: Step 1 derives MEMORY.md candidate path" && assert_file_contains "memory-compress: Step 1 derives MEMORY.md candidate path" "$MEMORY_COMPRESS" 'candidate="$mem/MEMORY.md"' && pass "memory-compress: Step 1 derives MEMORY.md candidate path"
should_run "memory-compress: Step 1 guards MEMORY.md existence" && assert_file_contains "memory-compress: Step 1 guards MEMORY.md existence" "$MEMORY_COMPRESS" "No MEMORY.md found for this project" && pass "memory-compress: Step 1 guards MEMORY.md existence"
should_run "memory-compress: Step 1 echoes candidate path" && assert_file_contains "memory-compress: Step 1 echoes candidate path" "$MEMORY_COMPRESS" 'echo "$candidate"' && pass "memory-compress: Step 1 echoes candidate path"
# Step 6 frontmatter enforce contract
should_run "memory-compress: Step 6 flags missing fields before compression" && assert_file_contains "memory-compress: Step 6 flags missing fields before compression" "$MEMORY_COMPRESS" "missing required frontmatter fields" && pass "memory-compress: Step 6 flags missing fields before compression"
should_run "memory-compress: Step 6 enforce error includes Backfill before compression" && assert_file_contains "memory-compress: Step 6 enforce error includes Backfill before compression" "$MEMORY_COMPRESS" "Backfill before compression" && pass "memory-compress: Step 6 enforce error includes Backfill before compression"
should_run "memory-compress: Step 6 references memory-system.md schema" && assert_file_contains "memory-compress: Step 6 references memory-system.md schema" "$MEMORY_COMPRESS" "docs/memory-system.md" && pass "memory-compress: Step 6 references memory-system.md schema"
should_run "memory-compress: Step 6 lists topics as required field" && assert_file_contains "memory-compress: Step 6 lists topics as required field" "$MEMORY_COMPRESS" "topics" && pass "memory-compress: Step 6 lists topics as required field"

# ── mem-search.md contract ───────────────────────────────────────────────────

MEM_SEARCH="$COMMANDS_DIR/mem-search.md"

assert_frontmatter "mem-search: frontmatter valid" "$MEM_SEARCH"
should_run "mem-search: no python3 calls" && assert_not_contains "mem-search: no python3 calls" "$MEM_SEARCH" "python3"
should_run "mem-search: has Step 1 (memory dir)" && assert_file_contains "mem-search: has Step 1 (memory dir)" "$MEM_SEARCH" "Step 1" && pass "mem-search: has Step 1 (memory dir)"
should_run "mem-search: Step 1 uses pmctl memory dir" && assert_file_contains "mem-search: Step 1 uses pmctl memory dir" "$MEM_SEARCH" "pmctl memory dir" && pass "mem-search: Step 1 uses pmctl memory dir"
should_run "mem-search: has Step 2 (pmctl context query)" && assert_file_contains "mem-search: has Step 2 (pmctl context query)" "$MEM_SEARCH" "Step 2" && pass "mem-search: has Step 2 (pmctl context query)"
should_run "mem-search: Step 2 uses pmctl context query" && assert_file_contains "mem-search: Step 2 uses pmctl context query" "$MEM_SEARCH" "pmctl context query" && pass "mem-search: Step 2 uses pmctl context query"
should_run "mem-search: Step 2 uses --source memory flag" && assert_file_contains "mem-search: Step 2 uses --source memory flag" "$MEM_SEARCH" "--source" && pass "mem-search: Step 2 uses --source memory flag"
should_run "mem-search: Step 2 uses -- separator before query" && assert_file_contains "mem-search: Step 2 uses -- separator before query" "$MEM_SEARCH" '-- "$query"' && pass "mem-search: Step 2 uses -- separator before query"
should_run "mem-search: Step 2 captures pmctl exit code" && assert_file_contains "mem-search: Step 2 captures pmctl exit code" "$MEM_SEARCH" "pmctl_exit" && pass "mem-search: Step 2 captures pmctl exit code"
should_run "mem-search: Step 2 success path skips fallback steps" && assert_file_contains "mem-search: Step 2 success path skips fallback steps" "$MEM_SEARCH" "skip Steps 3 and 4" && pass "mem-search: Step 2 success path skips fallback steps"
should_run "mem-search: Step 2 parses ref lines" && assert_file_contains "mem-search: Step 2 parses ref lines" "$MEM_SEARCH" "- ref: " && pass "mem-search: Step 2 parses ref lines"
should_run "mem-search: Step 2 handles nonzero exit" && assert_file_contains "mem-search: Step 2 handles nonzero exit" "$MEM_SEARCH" "nonzero exit" && pass "mem-search: Step 2 handles nonzero exit"
should_run "mem-search: Step 2 documents no-hits fallback path" && assert_file_contains "mem-search: Step 2 documents no-hits fallback path" "$MEM_SEARCH" "no hits" && pass "mem-search: Step 2 documents no-hits fallback path"
should_run "mem-search: Step 2 documents query-failure fallback path" && assert_file_contains "mem-search: Step 2 documents query-failure fallback path" "$MEM_SEARCH" "query failure" && pass "mem-search: Step 2 documents query-failure fallback path"
should_run "mem-search: has Step 3 (rg/grep fallback)" && assert_file_contains "mem-search: has Step 3 (rg/grep fallback)" "$MEM_SEARCH" "Step 3" && pass "mem-search: has Step 3 (rg/grep fallback)"
should_run "mem-search: Step 3 is rg/grep fallback" && assert_file_contains "mem-search: Step 3 is rg/grep fallback" "$MEM_SEARCH" "fallback" && pass "mem-search: Step 3 is rg/grep fallback"
should_run "mem-search: Step 3 uses find for file list" && assert_file_contains "mem-search: Step 3 uses find for file list" "$MEM_SEARCH" "find " && pass "mem-search: Step 3 uses find for file list"
should_run "mem-search: Step 3 uses fixed-string search flag" && assert_file_contains "mem-search: Step 3 uses fixed-string search flag" "$MEM_SEARCH" "-ilF" && pass "mem-search: Step 3 uses fixed-string search flag"
should_run "mem-search: Step 3 selects episodes.jsonl in file list" && assert_file_contains "mem-search: Step 3 selects episodes.jsonl in file list" "$MEM_SEARCH" "episodes.jsonl" && pass "mem-search: Step 3 selects episodes.jsonl in file list"
should_run "mem-search: has semantic search step" && assert_file_contains "mem-search: has semantic search step" "$MEM_SEARCH" "Semantic" && pass "mem-search: has semantic search step"

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

# ── next-step uncertainty router contract (discover/research/spike family) ────

DISCOVER="$COMMANDS_DIR/discover.md"
RESEARCH="$COMMANDS_DIR/research.md"
SPIKE_CMD="$COMMANDS_DIR/spike.md"
SPIKE_AGENT="$AGENTS_DIR/spike.md"
PROJECT_PM="$AGENTS_DIR/project-pm.md"
PM_CMD="$COMMANDS_DIR/pm.md"

# /discover output is a routing input, not just a human menu
assert_frontmatter "discover: frontmatter valid" "$DISCOVER"
should_run "discover: output table has Next column" && assert_file_contains "discover: output table has Next column" "$DISCOVER" "| Next | Refs |" && pass "discover: output table has Next column"
should_run "discover: documents why-not-direct-brief line" && assert_file_contains "discover: documents why-not-direct-brief line" "$DISCOVER" "**Why not a direct brief**" && pass "discover: documents why-not-direct-brief line"
should_run "discover: Next column is a route label only" && assert_file_contains "discover: Next column is a route label only" "$DISCOVER" "route label only" && pass "discover: Next column is a route label only"
should_run "discover: documents defer route" && assert_file_contains "discover: documents defer route" "$DISCOVER" "real but not timely" && pass "discover: documents defer route"

# /research grounded-pipeline contract
assert_frontmatter "research: frontmatter valid" "$RESEARCH"
should_run "research: internal anchoring is mandatory before search" && assert_file_contains "research: internal anchoring is mandatory before search" "$RESEARCH" "Internal anchoring (mandatory" && pass "research: internal anchoring is mandatory before search"
should_run "research: mandatory directioning question step" && assert_file_contains "research: mandatory directioning question step" "$RESEARCH" "Directioning question" && pass "research: mandatory directioning question step"
should_run "research: directioning is a stop-before-search guard" && assert_file_contains "research: directioning is a stop-before-search guard" "$RESEARCH" "Wait for the answer. Do not invent a topic or skip this step" && pass "research: directioning is a stop-before-search guard"
should_run "research: anchoring has retrieval swap-point" && assert_file_contains "research: anchoring has retrieval swap-point" "$RESEARCH" "swap-point" && pass "research: anchoring has retrieval swap-point"
should_run "research: dispatches a WebSearch-capable agent" && assert_file_contains "research: dispatches a WebSearch-capable agent" "$RESEARCH" "WebSearch-capable agent" && pass "research: dispatches a WebSearch-capable agent"
should_run "research: does not auto-open tickets" && assert_file_contains "research: does not auto-open tickets" "$RESEARCH" "does not auto-open tickets" && pass "research: does not auto-open tickets"
should_run "research: mandatory persistence prompt" && assert_file_contains "research: mandatory persistence prompt" "$RESEARCH" "Persistence prompt (mandatory" && pass "research: mandatory persistence prompt"

# /spike orchestrator + spike planner agent
assert_frontmatter "spike-cmd: frontmatter valid" "$SPIKE_CMD"
should_run "spike-cmd: main thread fans out one agent per angle" && assert_file_contains "spike-cmd: main thread fans out one agent per angle" "$SPIKE_CMD" "fans out one agent per angle" && pass "spike-cmd: main thread fans out one agent per angle"
should_run "spike-cmd: consumes spike_plan_v1 block" && assert_file_contains "spike-cmd: consumes spike_plan_v1 block" "$SPIKE_CMD" "spike_plan_v1" && pass "spike-cmd: consumes spike_plan_v1 block"
should_run "spike-cmd: result committed to docs/spikes" && assert_file_contains "spike-cmd: result committed to docs/spikes" "$SPIKE_CMD" "docs/spikes/<ticket-id>.md" && pass "spike-cmd: result committed to docs/spikes"
# ticket-resolution validation: non-spike ticket / missing spike structure must stop
should_run "spike-cmd: rejects non-spike ticket (stop and report)" && assert_file_contains "spike-cmd: rejects non-spike ticket (stop and report)" "$SPIKE_CMD" "carries the \`spike\` epic. If not, stop and report" && pass "spike-cmd: rejects non-spike ticket (stop and report)"
should_run "spike-cmd: handles missing spike structure" && assert_file_contains "spike-cmd: handles missing spike structure" "$SPIKE_CMD" "missing the spike structure" && pass "spike-cmd: handles missing spike structure"
should_run "spike-agent: returns spike_plan_v1" && assert_file_contains "spike-agent: returns spike_plan_v1" "$SPIKE_AGENT" "spike_plan_v1" && pass "spike-agent: returns spike_plan_v1"
should_run "spike-agent: cannot spawn subagents (planner only)" && assert_file_contains "spike-agent: cannot spawn subagents (planner only)" "$SPIKE_AGENT" "You cannot spawn subagents." && pass "spike-agent: cannot spawn subagents (planner only)"
should_run "spike-agent: has a synthesis pass" && assert_file_contains "spike-agent: has a synthesis pass" "$SPIKE_AGENT" "# Synthesis pass" && pass "spike-agent: has a synthesis pass"

# project-pm uncertainty routing + load-bearing active-scope guard
should_run "project-pm: has Uncertainty routing section" && assert_file_contains "project-pm: has Uncertainty routing section" "$PROJECT_PM" "## Uncertainty routing" && pass "project-pm: has Uncertainty routing section"
should_run "project-pm: documents load-bearing active-scope guard" && assert_file_contains "project-pm: documents load-bearing active-scope guard" "$PROJECT_PM" "Active-scope guard (load-bearing)" && pass "project-pm: documents load-bearing active-scope guard"
should_run "project-pm: emits next_step_route block" && assert_file_contains "project-pm: emits next_step_route block" "$PROJECT_PM" "next_step_route:" && pass "project-pm: emits next_step_route block"
should_run "project-pm: discover auto-fired, research auto-offered" && assert_file_contains "project-pm: discover auto-fired, research auto-offered" "$PROJECT_PM" "Automation asymmetry" && pass "project-pm: discover auto-fired, research auto-offered"

# /pm main-thread discovery orchestration
should_run "pm-cmd: has Discovery route orchestration" && assert_file_contains "pm-cmd: has Discovery route orchestration" "$PM_CMD" "**Discovery route**" && pass "pm-cmd: has Discovery route orchestration"
should_run "pm-cmd: gates discover on run_discover flag" && assert_file_contains "pm-cmd: gates discover on run_discover flag" "$PM_CMD" "run_discover: true" && pass "pm-cmd: gates discover on run_discover flag"
should_run "pm-cmd: research auto-offered not auto-fired" && assert_file_contains "pm-cmd: research auto-offered not auto-fired" "$PM_CMD" "auto-offered, not auto-fired" && pass "pm-cmd: research auto-offered not auto-fired"

# active-scope guard — the TACTICAL FALSE PATH (named scope must NOT auto-fire discovery)
should_run "project-pm: tactical named scope never auto-routes to Discovery" && assert_file_contains "project-pm: tactical named scope never auto-routes to Discovery" "$PROJECT_PM" "never auto-route to Discovery" && pass "project-pm: tactical named scope never auto-routes to Discovery"
should_run "project-pm: tactical request does not auto-fire an uncertainty mode" && assert_file_contains "project-pm: tactical request does not auto-fire an uncertainty mode" "$PROJECT_PM" "do **not** auto-fire an uncertainty mode" && pass "project-pm: tactical request does not auto-fire an uncertainty mode"
should_run "pm-cmd: named scope sets run_discover false (no fan-out)" && assert_file_contains "pm-cmd: named scope sets run_discover false (no fan-out)" "$PM_CMD" "run_discover: false" && pass "pm-cmd: named scope sets run_discover false (no fan-out)"
should_run "pm-cmd: tactical request does not auto-run discover" && assert_file_contains "pm-cmd: tactical request does not auto-run discover" "$PM_CMD" "Do **not** auto-run \`/discover\` for tactical" && pass "pm-cmd: tactical request does not auto-run discover"
should_run "pm-cmd: dispatch uses detached lifecycle" && assert_file_contains "pm-cmd: dispatch uses detached lifecycle" "$PM_CMD" "--lifecycle detached" && pass "pm-cmd: dispatch uses detached lifecycle"
should_run "pm-cmd: uses pmctl dispatch wait for completion" && assert_file_contains "pm-cmd: uses pmctl dispatch wait for completion" "$PM_CMD" "pmctl dispatch wait" && pass "pm-cmd: uses pmctl dispatch wait for completion"
should_run "pm-cmd: reads artifact paths from dispatch record" && assert_file_contains "pm-cmd: reads artifact paths from dispatch record" "$PM_CMD" ".dispatch-results/\$run_id.md" && pass "pm-cmd: reads artifact paths from dispatch record"
should_run "pm-cmd: documents pmctl artifacts list" && assert_file_contains "pm-cmd: documents pmctl artifacts list" "$PM_CMD" "pmctl artifacts list --cd <safe working_dir>" && pass "pm-cmd: documents pmctl artifacts list"
should_run "pm-cmd: documents pmctl artifacts show" && assert_file_contains "pm-cmd: documents pmctl artifacts show" "$PM_CMD" "pmctl artifacts show <run_id> --cd <safe working_dir>" && pass "pm-cmd: documents pmctl artifacts show"
should_run "pm-cmd: documents pmctl artifacts gc" && assert_file_contains "pm-cmd: documents pmctl artifacts gc" "$PM_CMD" "pmctl artifacts gc" && pass "pm-cmd: documents pmctl artifacts gc"
should_run "pm-cmd: documents pmctl artifacts migrate" && assert_file_contains "pm-cmd: documents pmctl artifacts migrate" "$PM_CMD" "pmctl artifacts migrate" && pass "pm-cmd: documents pmctl artifacts migrate"
should_run "pm-cmd: documents codex-watch trace flag" && assert_file_contains "pm-cmd: documents codex-watch trace flag" "$PM_CMD" "scripts/codex-watch.sh --trace <abs_jsonl>" && pass "pm-cmd: documents codex-watch trace flag"
should_run "pm-cmd: documents codex-watch run flag" && assert_file_contains "pm-cmd: documents codex-watch run flag" "$PM_CMD" "scripts/codex-watch.sh --run <run_id> --cd <safe working_dir>" && pass "pm-cmd: documents codex-watch run flag"

# /discover per-pick routing contract: Next carries the per-pick route, why-not-direct-brief is the top-pick global line
should_run "discover: per-pick route chosen one per row" && assert_file_contains "discover: per-pick route chosen one per row" "$DISCOVER" "Pick one per row" && pass "discover: per-pick route chosen one per row"
should_run "discover: research route means external method gap" && assert_file_contains "discover: research route means external method gap" "$DISCOVER" "needs an external method" && pass "discover: research route means external method gap"

# /spike verdict validation: local-env failure -> AMBER, mandatory main-thread sanity-check
should_run "spike-cmd: has main-thread verdict validation step" && assert_file_contains "spike-cmd: has main-thread verdict validation step" "$SPIKE_CMD" "Main-thread validation" && pass "spike-cmd: has main-thread verdict validation step"
should_run "spike-cmd: local-env failure classifies AMBER not RED" && assert_file_contains "spike-cmd: local-env failure classifies AMBER not RED" "$SPIKE_CMD" "local-env" && pass "spike-cmd: local-env failure classifies AMBER not RED"
should_run "spike-cmd: documents AMBER verdict" && assert_file_contains "spike-cmd: documents AMBER verdict" "$SPIKE_CMD" "AMBER" && pass "spike-cmd: documents AMBER verdict"
# codex fan-out must be synchronous (detached default would return only a run_id, not findings)
should_run "spike-cmd: codex angle dispatch uses foreground lifecycle" && assert_file_contains "spike-cmd: codex angle dispatch uses foreground lifecycle" "$SPIKE_CMD" "--lifecycle foreground" && pass "spike-cmd: codex angle dispatch uses foreground lifecycle"
should_run "spike-cmd: detached angle resolved via dispatch wait" && assert_file_contains "spike-cmd: detached angle resolved via dispatch wait" "$SPIKE_CMD" "pmctl dispatch wait" && pass "spike-cmd: detached angle resolved via dispatch wait"
# codex angle brief must use exclusive-create temp file (no predictable shared /tmp name — symlink race)
should_run "spike-cmd: codex angle brief uses mktemp exclusive-create" && assert_file_contains "spike-cmd: codex angle brief uses mktemp exclusive-create" "$SPIKE_CMD" "mktemp -p /tmp brief-spike-XXXXXX.md" && pass "spike-cmd: codex angle brief uses mktemp exclusive-create"
should_run "spike-cmd: codex angle brief avoids predictable shared path" && assert_not_contains "spike-cmd: codex angle brief avoids predictable shared path" "$SPIKE_CMD" "/tmp/brief-spike-<ticket-id>-<angle>.md"

# /research constraint-filtering output contract
should_run "research: filters external methods against internal constraints" && assert_file_contains "research: filters external methods against internal constraints" "$RESEARCH" "Filter against internal constraints" && pass "research: filters external methods against internal constraints"
should_run "research: output carries maps-to / conflicts-with verdict field" && assert_file_contains "research: output carries maps-to / conflicts-with verdict field" "$RESEARCH" "Maps to / conflicts with" && pass "research: output carries maps-to / conflicts-with verdict field"
should_run "research: marks methods adoptable" && assert_file_contains "research: marks methods adoptable" "$RESEARCH" "adoptable" && pass "research: marks methods adoptable"

# ── summary ──────────────────────────────────────────────────────────────────

th_summary
