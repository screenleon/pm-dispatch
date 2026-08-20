#!/usr/bin/env bash
# Contract-lint tests for slash commands in commands/.
#
# These are structural tests — they verify that command files are
# internally consistent and contain required sections. They do NOT
# test Claude's runtime behaviour (that's untestable here).
#
# Usage:
#   tests/shell/test-commands.sh           # prints header + summary; VERBOSE=1 prints every case
#   VERBOSE=1 tests/shell/test-commands.sh # print every case
#   tests/shell/test-commands.sh --list

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMANDS_DIR="$REPO_ROOT/commands"
AGENTS_DIR="$REPO_ROOT/agents"

# shellcheck source=tests/lib/test-harness.sh
. "$REPO_ROOT/tests/lib/test-harness.sh"
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
should_run "mem-distill: Step 6 lists priority as required field" && assert_file_contains "mem-distill: Step 6 lists priority as required field" "$MEM_DISTILL" "priority" && pass "mem-distill: Step 6 lists priority as required field"
should_run "mem-distill: Step 6 lists status as required field" && assert_file_contains "mem-distill: Step 6 lists status as required field" "$MEM_DISTILL" "status" && pass "mem-distill: Step 6 lists status as required field"
should_run "mem-distill: Step 6 lists updated_at as required field" && assert_file_contains "mem-distill: Step 6 lists updated_at as required field" "$MEM_DISTILL" "updated_at" && pass "mem-distill: Step 6 lists updated_at as required field"
should_run "mem-distill: Step 6 lists repo_refs as required field" && assert_file_contains "mem-distill: Step 6 lists repo_refs as required field" "$MEM_DISTILL" "repo_refs" && pass "mem-distill: Step 6 lists repo_refs as required field"
# Step 2b shard+summary contract
should_run "mem-distill: Step 2b calls pmctl memory rebuild-summary" && assert_file_contains "mem-distill: Step 2b calls pmctl memory rebuild-summary" "$MEM_DISTILL" "pmctl memory rebuild-summary" && pass "mem-distill: Step 2b calls pmctl memory rebuild-summary"
should_run "mem-distill: Step 2b calls pmctl memory shard" && assert_file_contains "mem-distill: Step 2b calls pmctl memory shard" "$MEM_DISTILL" "pmctl memory shard" && pass "mem-distill: Step 2b calls pmctl memory shard"
should_run "mem-distill: Step 2b shard step falls back on failure" && assert_file_contains "mem-distill: Step 2b shard step falls back on failure" "$MEM_DISTILL" "|| true" && pass "mem-distill: Step 2b shard step falls back on failure"
should_run "mem-distill: Step 2b documents episodes.summary.md" && assert_file_contains "mem-distill: Step 2b documents episodes.summary.md" "$MEM_DISTILL" "episodes.summary.md" && pass "mem-distill: Step 2b documents episodes.summary.md"

# ── mem-log.md contract ──────────────────────────────────────────────────────

MEM_LOG="$COMMANDS_DIR/mem-log.md"

assert_frontmatter "mem-log: frontmatter valid" "$MEM_LOG"
should_run "mem-log: no python3 calls" && assert_not_contains "mem-log: no python3 calls" "$MEM_LOG" "python3"
should_run "mem-log: Step 1 uses strict memory resolve" && assert_file_contains "mem-log: Step 1 uses strict memory resolve" "$MEM_LOG" "pmctl memory resolve" && pass "mem-log: Step 1 uses strict memory resolve"
should_run "mem-log: Step 3 uses canonical append API" && assert_file_contains "mem-log: Step 3 uses canonical append API" "$MEM_LOG" "pmctl memory append-episode" && pass "mem-log: Step 3 uses canonical append API"
should_run "mem-log: Step 3 identifies Claude writer host" && assert_file_contains "mem-log: Step 3 identifies Claude writer host" "$MEM_LOG" "--host claude" && pass "mem-log: Step 3 identifies Claude writer host"
should_run "mem-log: never writes episodes directly" && assert_not_contains "mem-log: never writes episodes directly" "$MEM_LOG" 'ep="$mem/episodes.jsonl"'

# ── mem-recall.md contract ────────────────────────────────────────────────────

MEM_RECALL="$COMMANDS_DIR/mem-recall.md"

assert_frontmatter "mem-recall: frontmatter valid" "$MEM_RECALL"
should_run "mem-recall: no python3 calls" && assert_not_contains "mem-recall: no python3 calls" "$MEM_RECALL" "python3"
should_run "mem-recall: Step 1 uses pmctl memory dir" && assert_file_contains "mem-recall: Step 1 uses pmctl memory dir" "$MEM_RECALL" "pmctl memory dir" && pass "mem-recall: Step 1 uses pmctl memory dir"
should_run "mem-recall: Step 1 derives episodes.jsonl path" && assert_file_contains "mem-recall: Step 1 derives episodes.jsonl path" "$MEM_RECALL" "episodes.jsonl" && pass "mem-recall: Step 1 derives episodes.jsonl path"
should_run "mem-recall: Step 1 guards file existence" && assert_file_contains "mem-recall: Step 1 guards file existence" "$MEM_RECALL" '[[ -f "$ep" ]]' && pass "mem-recall: Step 1 guards file existence"
should_run "mem-recall: Step 1 error message for missing episodes" && assert_file_contains "mem-recall: Step 1 error message for missing episodes" "$MEM_RECALL" "No episodes found for this project" && pass "mem-recall: Step 1 error message for missing episodes"
should_run "mem-recall: Step 2b uses pmctl context query" && assert_file_contains "mem-recall: Step 2b uses pmctl context query" "$MEM_RECALL" "pmctl context query" && pass "mem-recall: Step 2b uses pmctl context query"
should_run "mem-recall: Step 2b queries --source memory" && assert_file_contains "mem-recall: Step 2b queries --source memory" "$MEM_RECALL" "--source memory" && pass "mem-recall: Step 2b queries --source memory"
should_run "mem-recall: Step 2b falls back gracefully on failure" && assert_file_contains "mem-recall: Step 2b falls back gracefully on failure" "$MEM_RECALL" "2>/dev/null" && pass "mem-recall: Step 2b falls back gracefully on failure"
should_run "mem-recall: Step 3 merges recent and relevant" && assert_file_contains "mem-recall: Step 3 merges recent and relevant" "$MEM_RECALL" "relevant" && pass "mem-recall: Step 3 merges recent and relevant"

# ── memory-compress.md contract ───────────────────────────────────────────────

MEMORY_COMPRESS="$COMMANDS_DIR/memory-compress.md"

assert_frontmatter "memory-compress: frontmatter valid" "$MEMORY_COMPRESS"
should_run "memory-compress: no python3 calls" && assert_not_contains "memory-compress: no python3 calls" "$MEMORY_COMPRESS" "python3"
should_run "memory-compress: Step 1 uses pmctl memory dir" && assert_file_contains "memory-compress: Step 1 uses pmctl memory dir" "$MEMORY_COMPRESS" "pmctl memory dir" && pass "memory-compress: Step 1 uses pmctl memory dir"
should_run "memory-compress: Step 1 derives MEMORY.md candidate path" && assert_file_contains "memory-compress: Step 1 derives MEMORY.md candidate path" "$MEMORY_COMPRESS" 'candidate="$mem/MEMORY.md"' && pass "memory-compress: Step 1 derives MEMORY.md candidate path"
should_run "memory-compress: Step 1 guards MEMORY.md existence" && assert_file_contains "memory-compress: Step 1 guards MEMORY.md existence" "$MEMORY_COMPRESS" "No MEMORY.md found for this project" && pass "memory-compress: Step 1 guards MEMORY.md existence"
should_run "memory-compress: Step 1 echoes candidate path" && assert_file_contains "memory-compress: Step 1 echoes candidate path" "$MEMORY_COMPRESS" 'echo "$candidate"' && pass "memory-compress: Step 1 echoes candidate path"
# Step 6 frontmatter enforce contract
should_run "memory-compress: Step 6 blocks write on missing fields" && assert_file_contains "memory-compress: Step 6 blocks write on missing fields" "$MEMORY_COMPRESS" "do NOT write" && pass "memory-compress: Step 6 blocks write on missing fields"
should_run "memory-compress: Step 6 flags missing fields before compression" && assert_file_contains "memory-compress: Step 6 flags missing fields before compression" "$MEMORY_COMPRESS" "missing required frontmatter fields" && pass "memory-compress: Step 6 flags missing fields before compression"
should_run "memory-compress: Step 6 enforce error includes Backfill before compression" && assert_file_contains "memory-compress: Step 6 enforce error includes Backfill before compression" "$MEMORY_COMPRESS" "Backfill before compression" && pass "memory-compress: Step 6 enforce error includes Backfill before compression"
should_run "memory-compress: Step 6 references memory-system.md schema" && assert_file_contains "memory-compress: Step 6 references memory-system.md schema" "$MEMORY_COMPRESS" "docs/memory-system.md" && pass "memory-compress: Step 6 references memory-system.md schema"
should_run "memory-compress: Step 6 lists topics as required field" && assert_file_contains "memory-compress: Step 6 lists topics as required field" "$MEMORY_COMPRESS" "topics" && pass "memory-compress: Step 6 lists topics as required field"
should_run "memory-compress: Step 6 lists priority as required field" && assert_file_contains "memory-compress: Step 6 lists priority as required field" "$MEMORY_COMPRESS" "priority" && pass "memory-compress: Step 6 lists priority as required field"
should_run "memory-compress: Step 6 lists status as required field" && assert_file_contains "memory-compress: Step 6 lists status as required field" "$MEMORY_COMPRESS" "status" && pass "memory-compress: Step 6 lists status as required field"
should_run "memory-compress: Step 6 lists updated_at as required field" && assert_file_contains "memory-compress: Step 6 lists updated_at as required field" "$MEMORY_COMPRESS" "updated_at" && pass "memory-compress: Step 6 lists updated_at as required field"
should_run "memory-compress: Step 6 lists repo_refs as required field" && assert_file_contains "memory-compress: Step 6 lists repo_refs as required field" "$MEMORY_COMPRESS" "repo_refs" && pass "memory-compress: Step 6 lists repo_refs as required field"

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

# ── selected-reviewer JSON contract ──────────────────────────────────────────

for reviewer_name in critic qa-tester architecture-reviewer security-reviewer risk-reviewer; do
  reviewer_file="$AGENTS_DIR/$reviewer_name.md"
  should_run "agent/$reviewer_name: shared protocol replaces legacy format" \
    && assert_file_contains \
      "agent/$reviewer_name: shared protocol replaces legacy format" \
      "$reviewer_file" "fully replaces the legacy format" \
    && pass "agent/$reviewer_name: shared protocol replaces legacy format"
  should_run "agent/$reviewer_name: protocol has exact verdict enum" \
    && assert_file_contains \
      "agent/$reviewer_name: protocol has exact verdict enum" \
      "$reviewer_file" 'approve|advise|block-soft|block' \
    && pass "agent/$reviewer_name: protocol has exact verdict enum"
  should_run "agent/$reviewer_name: role-specific prose is not top-level" \
    && assert_file_contains \
      "agent/$reviewer_name: role-specific prose is not top-level" \
      "$reviewer_file" "top-level keys" \
    && pass "agent/$reviewer_name: role-specific prose is not top-level"
  should_run "agent/$reviewer_name: finding ID uses full reviewer prefix" \
    && assert_file_contains \
      "agent/$reviewer_name: finding ID uses full reviewer prefix" \
      "$reviewer_file" "$reviewer_name-FNNN" \
    && pass "agent/$reviewer_name: finding ID uses full reviewer prefix"
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

# project-pm deterministic knowledge retrieval (numbered On-invocation step)
should_run "project-pm: Retrieve is a numbered On-invocation step before Classify" && assert_file_contains "project-pm: Retrieve is a numbered On-invocation step before Classify" "$PROJECT_PM" "3. **Retrieve**" && pass "project-pm: Retrieve is a numbered On-invocation step before Classify"
should_run "project-pm: Retrieve step queries knowledge domain first" && assert_file_contains "project-pm: Retrieve step queries knowledge domain first" "$PROJECT_PM" "--domain knowledge" && pass "project-pm: Retrieve step queries knowledge domain first"
should_run "project-pm: Retrieve cites injected auto-context instead of re-querying" && assert_file_contains "project-pm: Retrieve cites injected auto-context instead of re-querying" "$PROJECT_PM" "auto-context" && pass "project-pm: Retrieve cites injected auto-context instead of re-querying"
should_run "project-pm: Classify renumbered after Retrieve step" && assert_file_contains "project-pm: Classify renumbered after Retrieve step" "$PROJECT_PM" "4. **Classify**" && pass "project-pm: Classify renumbered after Retrieve step"
should_run "project-pm: consumes canonical memory fields before legacy fallback" && assert_file_contains "project-pm: consumes canonical memory fields before legacy fallback" "$PROJECT_PM" "## Canonical memory ingestion" && assert_file_contains "project-pm: consumes canonical memory fields before legacy fallback" "$PROJECT_PM" "take precedence over the legacy" && pass "project-pm: consumes canonical memory fields before legacy fallback"
should_run "project-pm: rejects unsafe memory pointers" && assert_file_contains "project-pm: rejects unsafe memory pointers" "$PROJECT_PM" "canonical target escapes \`memory_dir\`" && assert_file_contains "project-pm: rejects unsafe memory pointers" "$PROJECT_PM" "silently fall back to a different host-local memory" && pass "project-pm: rejects unsafe memory pointers"

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
should_run "pm-cmd: snapshot preparation uses pmctl pm default cwd" && assert_file_contains "pm-cmd: snapshot preparation uses pmctl pm default cwd" "$PM_CMD" "pm prepare --request" && pass "pm-cmd: snapshot preparation uses pmctl pm default cwd"
should_run "pm-cmd: preparation forwards canonical memory context" && assert_file_contains "pm-cmd: preparation forwards canonical memory context" "$PM_CMD" "memory_resolution.memory_dir" && assert_file_contains "pm-cmd: preparation forwards canonical memory context" "$PM_CMD" "pointer-only \`memory_context\` pack" && pass "pm-cmd: preparation forwards canonical memory context"
should_run "pm-cmd: snapshot preparation reads structured result" && assert_file_contains "pm-cmd: snapshot preparation reads structured result" "$PM_CMD" "snapshot_file // empty" && pass "pm-cmd: snapshot preparation reads structured result"
should_run "pm-cmd: empty preparation result skips jq" && assert_file_contains "pm-cmd: empty preparation result skips jq" "$PM_CMD" '[[ -n "$PM_PREP_JSON" ]]' && pass "pm-cmd: empty preparation result skips jq"
# Behavior: the /pm snapshot preparation shell fence remains parseable Bash.
# Steps: extract the first bash fence from commands/pm.md; run bash -n on its exact contents.
pm_cmd_snapshot_fence_syntax() {
  local name="pm-cmd: snapshot preparation bash fence parses"
  should_run "$name" || return 0
  local snippet="$tmp_root/pm-snapshot-fence.sh"
  awk '
    /^```bash$/ && !inside { inside=1; next }
    inside && /^```$/ { exit }
    inside { print }
  ' "$PM_CMD" > "$snippet"
  if [[ -s "$snippet" ]] && bash -n "$snippet"; then
    pass "$name"
  else
    fail "$name" "first bash fence is empty or has invalid syntax"
  fi
}
pm_cmd_snapshot_fence_syntax
should_run "pm-cmd: uses pmctl dispatch wait for completion" && assert_file_contains "pm-cmd: uses pmctl dispatch wait for completion" "$PM_CMD" "pmctl dispatch wait" && pass "pm-cmd: uses pmctl dispatch wait for completion"
should_run "pm-cmd: reads artifact paths from dispatch record" && assert_file_contains "pm-cmd: reads artifact paths from dispatch record" "$PM_CMD" ".dispatch-results/\$run_id.md" && pass "pm-cmd: reads artifact paths from dispatch record"
should_run "pm-cmd: documents pmctl artifacts list" && assert_file_contains "pm-cmd: documents pmctl artifacts list" "$PM_CMD" "pmctl artifacts list --cd <safe working_dir>" && pass "pm-cmd: documents pmctl artifacts list"
should_run "pm-cmd: documents pmctl artifacts show" && assert_file_contains "pm-cmd: documents pmctl artifacts show" "$PM_CMD" "pmctl artifacts show <run_id> --cd <safe working_dir>" && pass "pm-cmd: documents pmctl artifacts show"
should_run "pm-cmd: documents pmctl artifacts gc" && assert_file_contains "pm-cmd: documents pmctl artifacts gc" "$PM_CMD" "pmctl artifacts gc" && pass "pm-cmd: documents pmctl artifacts gc"
should_run "pm-cmd: documents pmctl artifacts migrate" && assert_file_contains "pm-cmd: documents pmctl artifacts migrate" "$PM_CMD" "pmctl artifacts migrate" && pass "pm-cmd: documents pmctl artifacts migrate"
should_run "pm-cmd: documents codex-watch trace flag" && assert_file_contains "pm-cmd: documents codex-watch trace flag" "$PM_CMD" "ops/diagnostics/codex-watch.sh --trace <abs_jsonl>" && pass "pm-cmd: documents codex-watch trace flag"
should_run "pm-cmd: documents codex-watch run flag" && assert_file_contains "pm-cmd: documents codex-watch run flag" "$PM_CMD" "ops/diagnostics/codex-watch.sh --run <run_id> --cd <safe working_dir>" && pass "pm-cmd: documents codex-watch run flag"

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

# ── pre-release.md contract ───────────────────────────────────────────────────

PRE_RELEASE="$COMMANDS_DIR/pre-release.md"
assert_frontmatter "pre-release: frontmatter valid" "$PRE_RELEASE"
should_run "pre-release: invokes pmctl pre-release audit" && assert_file_contains "pre-release: invokes pmctl pre-release audit" "$PRE_RELEASE" "pmctl pre-release audit" && pass "pre-release: invokes pmctl pre-release audit"
should_run "pre-release: accepts milestone-id argument" && assert_file_contains "pre-release: accepts milestone-id argument" "$PRE_RELEASE" "MILESTONE_ID" && pass "pre-release: accepts milestone-id argument"
should_run "pre-release: output is report not GO/NO-GO" && assert_file_contains "pre-release: output is report not GO/NO-GO" "$PRE_RELEASE" "not a GO/NO-GO" && pass "pre-release: output is report not GO/NO-GO"
should_run "pre-release: documents Layer 1 checks" && assert_file_contains "pre-release: documents Layer 1 checks" "$PRE_RELEASE" "Layer 1" && pass "pre-release: documents Layer 1 checks"
should_run "pre-release: documents Layer 2 semantic coverage" && assert_file_contains "pre-release: documents Layer 2 semantic coverage" "$PRE_RELEASE" "Layer 2" && pass "pre-release: documents Layer 2 semantic coverage"
should_run "pre-release: Layer 2 runs on main thread without dispatch" && assert_file_contains "pre-release: Layer 2 runs on main thread without dispatch" "$PRE_RELEASE" "without dispatching a sub-job" && pass "pre-release: Layer 2 runs on main thread without dispatch"
should_run "pre-release: Layer 2 uses name-only to scope files" && assert_file_contains "pre-release: Layer 2 uses name-only to scope files" "$PRE_RELEASE" "--name-only" && pass "pre-release: Layer 2 uses name-only to scope files"
should_run "pre-release: Layer 2 name-only step is mandatory" && assert_file_contains "pre-release: Layer 2 name-only step is mandatory" "$PRE_RELEASE" "Never skip the" && pass "pre-release: Layer 2 name-only step is mandatory"
should_run "pre-release: Layer 2 fetches per-file patch via API" && assert_file_contains "pre-release: Layer 2 fetches per-file patch via API" "$PRE_RELEASE" "gh api" && pass "pre-release: Layer 2 fetches per-file patch via API"
should_run "pre-release: Layer 2 scopes diff to specific files" && assert_file_contains "pre-release: Layer 2 scopes diff to specific files" "$PRE_RELEASE" "gh pr diff" && pass "pre-release: Layer 2 scopes diff to specific files"
should_run "pre-release: Layer 2 outputs per-ticket table" && assert_file_contains "pre-release: Layer 2 outputs per-ticket table" "$PRE_RELEASE" "Semantic coverage" && pass "pre-release: Layer 2 outputs per-ticket table"
should_run "pre-release: Layer 2 table has Covered status" && assert_file_contains "pre-release: Layer 2 table has Covered status" "$PRE_RELEASE" "Covered" && pass "pre-release: Layer 2 table has Covered status"
should_run "pre-release: Layer 2 table has Partial status" && assert_file_contains "pre-release: Layer 2 table has Partial status" "$PRE_RELEASE" "Partial" && pass "pre-release: Layer 2 table has Partial status"
should_run "pre-release: Layer 2 table has Gap status" && assert_file_contains "pre-release: Layer 2 table has Gap status" "$PRE_RELEASE" "Gap" && pass "pre-release: Layer 2 table has Gap status"
should_run "pre-release: Layer 2 table has N/A status" && assert_file_contains "pre-release: Layer 2 table has N/A status" "$PRE_RELEASE" "N/A" && pass "pre-release: Layer 2 table has N/A status"
should_run "pre-release: Layer 2 table has Confidence column" && assert_file_contains "pre-release: Layer 2 table has Confidence column" "$PRE_RELEASE" "Confidence" && pass "pre-release: Layer 2 table has Confidence column"
should_run "pre-release: Layer 2 confidence values are High Med Low" && assert_file_contains "pre-release: Layer 2 confidence values are High Med Low" "$PRE_RELEASE" "High / Med / Low" && pass "pre-release: Layer 2 confidence values are High Med Low"
should_run "pre-release: Layer 2 Flag column flags Partial or Gap" && assert_file_contains "pre-release: Layer 2 Flag column flags Partial or Gap" "$PRE_RELEASE" "Partial or Gap" && pass "pre-release: Layer 2 Flag column flags Partial or Gap"
should_run "pre-release: Layer 2 Flag column flags low confidence" && assert_file_contains "pre-release: Layer 2 Flag column flags low confidence" "$PRE_RELEASE" "confidence is Low" && pass "pre-release: Layer 2 Flag column flags low confidence"
should_run "pre-release: Layer 2 discovers tickets from MILESTONES.md" && assert_file_contains "pre-release: Layer 2 discovers tickets from MILESTONES.md" "$PRE_RELEASE" "MILESTONES.md" && pass "pre-release: Layer 2 discovers tickets from MILESTONES.md"
should_run "pre-release: Layer 2 extracts pr-ref for ticket discovery" && assert_file_contains "pre-release: Layer 2 extracts pr-ref for ticket discovery" "$PRE_RELEASE" "pr:#NNN" && pass "pre-release: Layer 2 extracts pr-ref for ticket discovery"
should_run "pre-release: Layer 2 reads Requirement section from BACKLOG" && assert_file_contains "pre-release: Layer 2 reads Requirement section from BACKLOG" "$PRE_RELEASE" "Requirement" && pass "pre-release: Layer 2 reads Requirement section from BACKLOG"
should_run "pre-release: Layer 2 Requirement extraction stops at next heading" && assert_file_contains "pre-release: Layer 2 Requirement extraction stops at next heading" "$PRE_RELEASE" "Depends on" && pass "pre-release: Layer 2 Requirement extraction stops at next heading"
should_run "pre-release: Layer 2 handles missing Requirement as N/A" && assert_file_contains "pre-release: Layer 2 handles missing Requirement as N/A" "$PRE_RELEASE" "record N/A and skip" && pass "pre-release: Layer 2 handles missing Requirement as N/A"
should_run "pre-release: Layer 2 reads ticket body from BACKLOG.md" && assert_file_contains "pre-release: Layer 2 reads ticket body from BACKLOG.md" "$PRE_RELEASE" "BACKLOG.md" && pass "pre-release: Layer 2 reads ticket body from BACKLOG.md"
should_run "pre-release: Layer 2 appended after Layer 1 and Layer 3" && assert_file_contains "pre-release: Layer 2 appended after Layer 1 and Layer 3" "$PRE_RELEASE" "appended after the Layer 1 + Layer 3" && pass "pre-release: Layer 2 appended after Layer 1 and Layer 3"
should_run "pre-release: Layer 2 section is informational only" && assert_file_contains "pre-release: Layer 2 section is informational only" "$PRE_RELEASE" "informational only and does not produce a GO/NO-GO" && pass "pre-release: Layer 2 section is informational only"
should_run "pre-release: documents Layer 3 blind spots" && assert_file_contains "pre-release: documents Layer 3 blind spots" "$PRE_RELEASE" "Layer 3" && pass "pre-release: documents Layer 3 blind spots"
should_run "pre-release: documents exit codes" && assert_file_contains "pre-release: documents exit codes" "$PRE_RELEASE" "Exit codes" && pass "pre-release: documents exit codes"

# ── using-git-worktrees.md contract ─────────────────────────────────────────

USING_GIT_WORKTREES="$COMMANDS_DIR/using-git-worktrees.md"

assert_frontmatter "using-git-worktrees: frontmatter valid" "$USING_GIT_WORKTREES"
should_run "using-git-worktrees: states git is a hard prerequisite" && assert_file_contains "using-git-worktrees: states git is a hard prerequisite" "$USING_GIT_WORKTREES" "this requires git" && pass "using-git-worktrees: states git is a hard prerequisite"
should_run "using-git-worktrees: documents create subcommand" && assert_file_contains "using-git-worktrees: documents create subcommand" "$USING_GIT_WORKTREES" "pmctl worktree create" && pass "using-git-worktrees: documents create subcommand"
should_run "using-git-worktrees: documents list subcommand" && assert_file_contains "using-git-worktrees: documents list subcommand" "$USING_GIT_WORKTREES" "pmctl worktree list" && pass "using-git-worktrees: documents list subcommand"
should_run "using-git-worktrees: documents remove subcommand" && assert_file_contains "using-git-worktrees: documents remove subcommand" "$USING_GIT_WORKTREES" "pmctl worktree remove" && pass "using-git-worktrees: documents remove subcommand"
should_run "using-git-worktrees: documents gc subcommand" && assert_file_contains "using-git-worktrees: documents gc subcommand" "$USING_GIT_WORKTREES" "pmctl worktree gc" && pass "using-git-worktrees: documents gc subcommand"
should_run "using-git-worktrees: documents --force is destructive" && assert_file_contains "using-git-worktrees: documents --force is destructive" "$USING_GIT_WORKTREES" "destructive" && pass "using-git-worktrees: documents --force is destructive"
should_run "using-git-worktrees: documents cross-worktree identity guarantee" && assert_file_contains "using-git-worktrees: documents cross-worktree identity guarantee" "$USING_GIT_WORKTREES" "same partition" && pass "using-git-worktrees: documents cross-worktree identity guarantee"
should_run "using-git-worktrees: documents concurrent manifest write safety" && assert_file_contains "using-git-worktrees: documents concurrent manifest write safety" "$USING_GIT_WORKTREES" "serialized under a single lock" && pass "using-git-worktrees: documents concurrent manifest write safety"
should_run "using-git-worktrees: documents orphan recovery via gc" && assert_file_contains "using-git-worktrees: documents orphan recovery via gc" "$USING_GIT_WORKTREES" "git worktree prune" && pass "using-git-worktrees: documents orphan recovery via gc"
should_run "using-git-worktrees: excludes --parallel gate reviewer isolation from scope" && assert_file_contains "using-git-worktrees: excludes --parallel gate reviewer isolation from scope" "$USING_GIT_WORKTREES" "does not touch the \`--parallel\` PR gate" && pass "using-git-worktrees: excludes --parallel gate reviewer isolation from scope"
should_run "using-git-worktrees: no CC ticket references" && assert_not_contains "using-git-worktrees: no CC ticket references" "$USING_GIT_WORKTREES" "CC-"

# ── ship.md contract ─────────────────────────────────────────────────────────

SHIP="$COMMANDS_DIR/ship.md"
PR_GATE="$COMMANDS_DIR/pr-gate.md"

extract_pr_gate_bash_fence() {
  local output="$1"
  awk '
    /^```bash$/ && !inside { inside=1; block=""; next }
    inside && /^```$/ {
      if (block ~ /RAW_ARGS=/) { printf "%s", block; exit }
      inside=0
      next
    }
    inside { block=block $0 ORS }
  ' "$PR_GATE" > "$output"
}

pr_gate_fence_syntax() {
  local name="pr-gate: argument parser bash fence parses"
  should_run "$name" || return 0
  local snippet="$tmp_root/pr-gate-fence-syntax.sh"
  extract_pr_gate_bash_fence "$snippet"
  if [[ -s "$snippet" ]] && bash -n "$snippet"; then
    pass "$name"
  else
    fail "$name" "first bash fence is empty or has invalid syntax"
  fi
}
pr_gate_fence_syntax

pr_gate_fence_executor_model_behavior() {
  local name="pr-gate: executor and model parser behavior"
  should_run "$name" || return 0
  local case_dir="$tmp_root/pr-gate-fence-behavior"
  local snippet="$case_dir/snippet.sh" bin_dir="$case_dir/bin"
  local args_log="$case_dir/args.log" out="$case_dir/out" err="$case_dir/err"
  local valid_status invalid_status missing_executor_status missing_model_status default_status
  mkdir -p "$bin_dir"
  extract_pr_gate_bash_fence "$snippet"
  cat > "$bin_dir/pmctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${PR_GATE_ARGS_LOG:?}"
STUB
  chmod +x "$bin_dir/pmctl"

  ARGUMENTS="--executor claude --model claude-sonnet-5" \
    PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" bash "$snippet" > "$out" 2> "$err"
  valid_status=$?
  rm -f "$args_log"

  ARGUMENTS="--executor invalid" PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" \
    bash "$snippet" > "$out" 2> "$err"
  invalid_status=$?
  ARGUMENTS="--executor" PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" \
    bash "$snippet" > "$out" 2> "$err"
  missing_executor_status=$?
  ARGUMENTS="--executor claude --model" PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" \
    bash "$snippet" > "$out" 2> "$err"
  missing_model_status=$?
  ARGUMENTS="" PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" \
    bash "$snippet" > "$out" 2> "$err"
  default_status=$?

  ARGUMENTS="--executor claude --model claude-sonnet-5" \
    PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" bash "$snippet" > "$out" 2> "$err"
  if [[ "$valid_status" -eq 0 && "$invalid_status" -eq 2 &&
        "$missing_executor_status" -eq 2 && "$missing_model_status" -eq 2 &&
        "$default_status" -eq 2 ]] &&
     grep -qx -- '--executor' "$args_log" && grep -qx 'claude' "$args_log" &&
     grep -qx -- '--model' "$args_log" && grep -qx 'claude-sonnet-5' "$args_log"; then
    pass "$name"
  else
    fail "$name" "statuses valid=$valid_status invalid=$invalid_status missing_executor=$missing_executor_status missing_model=$missing_model_status default=$default_status"
  fi
}
pr_gate_fence_executor_model_behavior

pr_gate_fence_assurance_behavior() {
  local name="pr-gate: assurance argument parser behavior"
  should_run "$name" || return 0
  local case_dir="$tmp_root/pr-gate-fence-assurance"
  local snippet="$case_dir/snippet.sh" bin_dir="$case_dir/bin"
  local args_log="$case_dir/args.log" out="$case_dir/out" err="$case_dir/err"
  local valid_status missing_initial_status initial_only_status conflict_status invalid_mode_status
  mkdir -p "$bin_dir"
  extract_pr_gate_bash_fence "$snippet"
  cat > "$bin_dir/pmctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${PR_GATE_ARGS_LOG:?}"
STUB
  chmod +x "$bin_dir/pmctl"

  ARGUMENTS="--executor claude --targeted critic --initial-result /tmp/initial.md --mode parallel" \
    PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" bash "$snippet" > "$out" 2> "$err"
  valid_status=$?
  if [[ "$valid_status" -ne 0 ]] ||
     ! grep -qx -- '--pass' "$args_log" ||
     ! grep -qx 'targeted' "$args_log" ||
     ! grep -qx -- '--reviewers' "$args_log" ||
     ! grep -qx 'critic' "$args_log" ||
     ! grep -qx -- '--initial-result' "$args_log" ||
     ! grep -qx '/tmp/initial.md' "$args_log" ||
     ! grep -qx -- '--mode' "$args_log" ||
     ! grep -qx 'parallel' "$args_log" ||
     ! grep -qx -- '--policy' "$args_log" ||
     ! grep -qx 'generic' "$args_log" ||
     grep -qx -- '--targeted' "$args_log"; then
    fail "$name" "targeted shorthand was not expanded to canonical coordinates"
    return
  fi

  rm -f "$args_log"
  ARGUMENTS="--executor claude --targeted critic" \
    PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" bash "$snippet" > "$out" 2> "$err"
  missing_initial_status=$?
  ARGUMENTS="--executor claude --initial-result /tmp/initial.md" \
    PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" bash "$snippet" > "$out" 2> "$err"
  initial_only_status=$?
  ARGUMENTS="--executor claude --mode parallel --sequential" \
    PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" bash "$snippet" > "$out" 2> "$err"
  conflict_status=$?
  ARGUMENTS="--executor claude --mode default" \
    PR_GATE_ARGS_LOG="$args_log" PATH="$bin_dir:$PATH" bash "$snippet" > "$out" 2> "$err"
  invalid_mode_status=$?

  if [[ "$missing_initial_status" -eq 2 && "$initial_only_status" -eq 2 &&
        "$conflict_status" -eq 2 && "$invalid_mode_status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "statuses missing_initial=$missing_initial_status initial_only=$initial_only_status conflict=$conflict_status invalid_mode=$invalid_mode_status"
  fi
}
pr_gate_fence_assurance_behavior

assert_frontmatter "ship: frontmatter valid" "$SHIP"
should_run "ship: scoped to a single named ticket per invocation" && assert_file_contains "ship: scoped to a single named ticket per invocation" "$SHIP" "one ticket per invocation" && pass "ship: scoped to a single named ticket per invocation"
should_run "ship: does not batch-scan BACKLOG for candidates" && assert_file_contains "ship: does not batch-scan BACKLOG for candidates" "$SHIP" "Do not scan" && pass "ship: does not batch-scan BACKLOG for candidates"
# Step 0 pre-flight consistency check: the one legal stopping point
should_run "ship: has Step 0 pre-flight consistency check" && assert_file_contains "ship: has Step 0 pre-flight consistency check" "$SHIP" "Step 0" && pass "ship: has Step 0 pre-flight consistency check"
should_run "ship: checks DECISIONS.md Constraints introduced" && assert_file_contains "ship: checks DECISIONS.md Constraints introduced" "$SHIP" "Constraints introduced" && pass "ship: checks DECISIONS.md Constraints introduced"
should_run "ship: checks unmet Dependencies before starting" && assert_file_contains "ship: checks unmet Dependencies before starting" "$SHIP" "Dependencies" && pass "ship: checks unmet Dependencies before starting"
should_run "ship: conflict stops before branching or implementing" && assert_file_contains "ship: conflict stops before branching or implementing" "$SHIP" "Do not create a branch" && pass "ship: conflict stops before branching or implementing"
should_run "ship: keeps DECISIONS.md out of dispatch briefs" && assert_file_contains "ship: keeps DECISIONS.md out of dispatch briefs" "$SHIP" "do not paste it into any dispatch brief" && pass "ship: keeps DECISIONS.md out of dispatch briefs"
# ticket-id validation: empty / malformed / nonexistent must fail fast, distinct from the discussion stop
should_run "ship: validates ticket id before any other step" && assert_file_contains "ship: validates ticket id before any other step" "$SHIP" "Ticket-id validation" && pass "ship: validates ticket id before any other step"
should_run "ship: handles empty argument" && assert_file_contains "ship: handles empty argument" "$SHIP" "stop and report \"empty argument\"" && pass "ship: handles empty argument"
should_run "ship: handles malformed ticket-id shape" && assert_file_contains "ship: handles malformed ticket-id shape" "$SHIP" "does not match this repo's ticket-id shape" && pass "ship: handles malformed ticket-id shape"
should_run "ship: distinguishes already-archived ticket from no-such-ticket" && assert_file_contains "ship: distinguishes already-archived ticket from no-such-ticket" "$SHIP" "the ticket is already terminal" && pass "ship: distinguishes already-archived ticket from no-such-ticket"
should_run "ship: consistency check only ever reads active BACKLOG.md" && assert_file_contains "ship: consistency check only ever reads active BACKLOG.md" "$SHIP" "resolves to an active \`BACKLOG.md\`" && pass "ship: consistency check only ever reads active BACKLOG.md"
should_run "ship: BACKLOG-ARCHIVE.md is error-message-only, never a source to implement from" && assert_file_contains "ship: BACKLOG-ARCHIVE.md is error-message-only, never a source to implement from" "$SHIP" "never as a source to" && pass "ship: BACKLOG-ARCHIVE.md is error-message-only, never a source to implement from"
should_run "ship: distinguishes fail-fast validation from the discussion stop" && assert_file_contains "ship: distinguishes fail-fast validation from the discussion stop" "$SHIP" "not a discussion point" && pass "ship: distinguishes fail-fast validation from the discussion stop"
# dirty-tree precondition is deterministic fail-safe, not a second ask path
should_run "ship: dirty tree aborts fail-fast, does not auto-mutate" && assert_file_contains "ship: dirty tree aborts fail-fast, does not auto-mutate" "$SHIP" "do not stash, commit, or" && pass "ship: dirty tree aborts fail-fast, does not auto-mutate"
should_run "ship: dirty-tree abort is not the negotiated stop" && assert_file_contains "ship: dirty-tree abort is not the negotiated stop" "$SHIP" "not the negotiated stop this command reserves" && pass "ship: dirty-tree abort is not the negotiated stop"
# implementation stays main-thread, not dispatched
should_run "ship: implementation is not dispatched to an executor" && assert_file_contains "ship: implementation is not dispatched to an executor" "$SHIP" "to codex/claude/opencode" && pass "ship: implementation is not dispatched to an executor"
# pre-gate maintainability checkpoint
should_run "ship: has refactor/reuse audit before first gate" && assert_file_contains "ship: has refactor/reuse audit before first gate" "$SHIP" "Step 2.5 — Refactor/reuse audit" && assert_file_contains "ship: has refactor/reuse audit before first gate" "$SHIP" "before the first PR gate" && pass "ship: has refactor/reuse audit before first gate"
if should_run "ship: refactor/reuse audit section precedes gate section"; then
  ship_audit_line=$(grep -n '^## Step 2\.5 — Refactor/reuse audit$' "$SHIP" | cut -d: -f1)
  ship_gate_line=$(grep -n '^## Step 3 — Gate loop$' "$SHIP" | cut -d: -f1)
  if [[ -n "$ship_audit_line" && -n "$ship_gate_line" && "$ship_audit_line" -lt "$ship_gate_line" ]]; then
    pass "ship: refactor/reuse audit section precedes gate section"
  else
    fail "ship: refactor/reuse audit section precedes gate section" "audit_line=$ship_audit_line gate_line=$ship_gate_line"
  fi
fi
should_run "ship: audit inspects actual diff and existing helpers" && assert_file_contains "ship: audit inspects actual diff and existing helpers" "$SHIP" "actual diff" && assert_file_contains "ship: audit inspects actual diff and existing helpers" "$SHIP" "existing helpers" && pass "ship: audit inspects actual diff and existing helpers"
should_run "ship: audit rejects speculative abstraction" && assert_file_contains "ship: audit rejects speculative abstraction" "$SHIP" "do not introduce speculative abstractions" && pass "ship: audit rejects speculative abstraction"
should_run "ship: initial audit records changed or no-change result" && assert_file_contains "ship: initial audit records changed or no-change result" "$SHIP" "CHANGED:" && assert_file_contains "ship: initial audit records changed or no-change result" "$SHIP" "PASS: no warranted refactor/reuse change" && pass "ship: initial audit records changed or no-change result"
should_run "ship: structural gate fixes require re-audit" && assert_file_contains "ship: structural gate fixes require re-audit" "$SHIP" "Re-run the refactor/reuse audit" && assert_file_contains "ship: structural gate fixes require re-audit" "$SHIP" "layer boundary" && pass "ship: structural gate fixes require re-audit"
should_run "ship: localized gate fixes may skip re-audit with reason" && assert_file_contains "ship: localized gate fixes may skip re-audit with reason" "$SHIP" "Skip the re-audit with a recorded reason" && assert_file_contains "ship: localized gate fixes may skip re-audit with reason" "$SHIP" "localized corrections" && pass "ship: localized gate fixes may skip re-audit with reason"
should_run "ship: uses affected tests before first gate" && assert_file_contains "ship: uses affected tests before first gate" "$SHIP" "tests/bin/run-tests.sh --base <base-ref>" && assert_file_contains "ship: uses affected tests before first gate" "$SHIP" 'Do not run `run-all-tests.sh` before the first PR gate' && pass "ship: uses affected tests before first gate"
should_run "ship: runs authoritative full suite only after GO" && assert_file_contains "ship: runs authoritative full suite only after GO" "$SHIP" "Only after PR-gate returns GO" && assert_file_contains "ship: runs authoritative full suite only after GO" "$SHIP" "bash tests/bin/run-all-tests.sh" && pass "ship: runs authoritative full suite only after GO"
should_run "ship: diff-caused full failure returns through targeted review" && assert_file_contains "ship: diff-caused full failure returns through targeted review" "$SHIP" "full suite finds a diff-caused failure" && assert_file_contains "ship: diff-caused full failure returns through targeted review" "$SHIP" "return to the targeted" && pass "ship: diff-caused full failure returns through targeted review"
# gate loop contract
should_run "ship: delegates model selection policy" && assert_file_contains "ship: delegates model selection policy" "$SHIP" "gate model diversity policy" && assert_file_contains "ship: delegates model selection policy" "$SHIP" "actual model identities" && pass "ship: delegates model selection policy"
should_run "pr-gate: delegates model selection policy" && assert_file_contains "pr-gate: delegates model selection policy" "$PR_GATE" "gate model diversity policy" && assert_file_contains "pr-gate: delegates model selection policy" "$PR_GATE" "actual model identities" && pass "pr-gate: delegates model selection policy"
should_run "pr-gate: documents external evidence is non-authorizing" && assert_file_contains "pr-gate: documents external evidence is non-authorizing" "$PR_GATE" "externally supplied result" && assert_file_contains "pr-gate: documents external evidence is non-authorizing" "$PR_GATE" "non-authorizing" && assert_file_contains "pr-gate: documents external evidence is non-authorizing" "$PR_GATE" "OIDC/provenance verifier" && pass "pr-gate: documents external evidence is non-authorizing"
should_run "review-model: selects by model not host or adapter" && assert_file_contains "review-model: selects by model not host or adapter" "$REPO_ROOT/docs/review-model.md" "actual primary" && assert_file_contains "review-model: selects by model not host or adapter" "$REPO_ROOT/docs/review-model.md" "host names are not reliable model" && assert_file_contains "review-model: selects by model not host or adapter" "$REPO_ROOT/docs/review-model.md" "OpenCode can" && pass "review-model: selects by model not host or adapter"
should_run "ship: never invokes pr-gate.sh directly" && assert_file_contains "ship: never invokes pr-gate.sh directly" "$SHIP" "never \`bash runtime/bin/pr-gate.sh\` directly" && pass "ship: never invokes pr-gate.sh directly"
if should_run "ship: every gate invocation uses --lifecycle foreground"; then
  ship_flat=$(tr '\n' ' ' < "$SHIP" | tr -s ' ')
  ship_gate_calls=$(grep -oE 'pmctl gate run --executor <gate_executor>' <<< "$ship_flat" | wc -l)
  ship_foreground_calls=$(grep -oE 'pmctl gate run --executor <gate_executor>[^`]*--lifecycle foreground' <<< "$ship_flat" | wc -l)
  if [[ "$ship_gate_calls" -gt 0 && "$ship_gate_calls" -eq "$ship_foreground_calls" ]]; then
    pass "ship: every gate invocation uses --lifecycle foreground"
  else
    fail "ship: every gate invocation uses --lifecycle foreground" "found $ship_gate_calls occurrence(s) of the gate call but only $ship_foreground_calls paired with --lifecycle foreground in $SHIP"
  fi
fi
if should_run "ship: every gate invocation uses maintainer policy"; then
  ship_flat=$(tr '\n' ' ' < "$SHIP" | tr -s ' ')
  ship_gate_calls=$(grep -oE 'pmctl gate run --executor <gate_executor>' <<< "$ship_flat" | wc -l)
  ship_policy_calls=$(grep -oE 'pmctl gate run --executor <gate_executor> --policy maintainer' <<< "$ship_flat" | wc -l)
  if [[ "$ship_gate_calls" -gt 0 && "$ship_gate_calls" -eq "$ship_policy_calls" ]]; then
    pass "ship: every gate invocation uses maintainer policy"
  else
    fail "ship: every gate invocation uses maintainer policy" "found $ship_gate_calls occurrence(s) of the gate call but only $ship_policy_calls paired with --policy maintainer in $SHIP"
  fi
fi
should_run "ship: explains why detached+wait is unnecessary here" && assert_file_contains "ship: explains why detached+wait is unnecessary here" "$SHIP" "nothing else for the main thread to do while it waits" && pass "ship: explains why detached+wait is unnecessary here"
should_run "ship: reads Final GO/NO-GO verdict" && assert_file_contains "ship: reads Final GO/NO-GO verdict" "$SHIP" "Final:" && pass "ship: reads Final GO/NO-GO verdict"
should_run "ship: NO-GO fixes every finding not only blocking ones" && assert_file_contains "ship: NO-GO fixes every finding not only blocking ones" "$SHIP" "the blocking ones" && pass "ship: NO-GO fixes every finding not only blocking ones"
should_run "ship: a permanent-test remedy is checked and the decision recorded either way" && assert_file_contains "ship: a permanent-test remedy is checked and the decision recorded either way" "$SHIP" "the *form* of the fix is a judgment" && assert_file_contains "ship: a permanent-test remedy is checked and the decision recorded either way" "$SHIP" "Record the decision in the PR body either way" && assert_file_contains "ship: a permanent-test remedy is checked and the decision recorded either way" "$SHIP" "name the criteria it meets" && pass "ship: a permanent-test remedy is checked and the decision recorded either way"
should_run "ship: re-runs gate with explicit targeted coordinates" && assert_file_contains "ship: re-runs gate with explicit targeted coordinates" "$SHIP" "--pass targeted" && assert_file_contains "ship: re-runs gate with explicit targeted coordinates" "$SHIP" "--reviewers <reviewer,...>" && assert_file_contains "ship: re-runs gate with explicit targeted coordinates" "$SHIP" "--initial-result" && pass "ship: re-runs gate with explicit targeted coordinates"
should_run "ship: references project-pm Rules A/B synthesis" && assert_file_contains "ship: references project-pm Rules A/B synthesis" "$SHIP" "Rules A/B" && pass "ship: references project-pm Rules A/B synthesis"
should_run "project-pm: classifies refactor/reuse recheck after gate fixes" && assert_file_contains "project-pm: classifies refactor/reuse recheck after gate fixes" "$PROJECT_PM" "refactor_reuse_recheck: required" && assert_file_contains "project-pm: classifies refactor/reuse recheck after gate fixes" "$PROJECT_PM" "refactor_reuse_recheck: skip" && pass "project-pm: classifies refactor/reuse recheck after gate fixes"
# exactly two stop conditions, no more
should_run "ship: stop condition heading enumerates the loop's halt cases" && assert_file_contains "ship: stop condition heading enumerates the loop's halt cases" "$SHIP" "Stop the loop only when" && pass "ship: stop condition heading enumerates the loop's halt cases"
if should_run "ship: exactly one genuine wait-for-user-direction path"; then
  ship_wait_count=$(grep -c "wait for the user's direction" "$SHIP")
  if [[ "$ship_wait_count" -eq 1 ]]; then
    pass "ship: exactly one genuine wait-for-user-direction path"
  else
    fail "ship: exactly one genuine wait-for-user-direction path" "expected exactly 1 wait-for-user-direction occurrence, found $ship_wait_count in $SHIP"
  fi
fi
if should_run "ship: stop-condition list has exactly two numbered cases"; then
  ship_stop_count=$(awk '/^\*\*Stop the loop only when\*\*:/{in_sec=1; next} in_sec && /^## /{exit} in_sec && /^[0-9]+\. /{c++} END{print c+0}' "$SHIP")
  if [[ "$ship_stop_count" -eq 2 ]]; then
    pass "ship: stop-condition list has exactly two numbered cases"
  else
    fail "ship: stop-condition list has exactly two numbered cases" "expected exactly 2 numbered items in the 'Stop the loop only when' section, found $ship_stop_count in $SHIP"
  fi
fi
should_run "ship: round count alone is not a stop signal" && assert_file_contains "ship: round count alone is not a stop signal" "$SHIP" "this is taking many rounds" && pass "ship: round count alone is not a stop signal"
should_run "ship: any other NO-GO continues without asking" && assert_file_contains "ship: any other NO-GO continues without asking" "$SHIP" "gets fixed and re-gated without asking" && pass "ship: any other NO-GO continues without asking"
# PR template
should_run "ship: opens PR via gh pr create" && assert_file_contains "ship: opens PR via gh pr create" "$SHIP" "gh pr create" && pass "ship: opens PR via gh pr create"
should_run "ship: PR body template records gate rounds and verdict" && assert_file_contains "ship: PR body template records gate rounds and verdict" "$SHIP" "Final verdict" && pass "ship: PR body template records gate rounds and verdict"
should_run "ship: GO is not merge authorization" && assert_file_contains "ship: GO is not merge authorization" "$SHIP" "GO is not merge authorization" && pass "ship: GO is not merge authorization"
should_run "ship: no CC ticket references" && assert_not_contains "ship: no CC ticket references" "$SHIP" "CC-[0-9]"
# git publication path: branch creation and push are the only side effects before PR creation
should_run "ship: creates the feature branch via git checkout -b" && assert_file_contains "ship: creates the feature branch via git checkout -b" "$SHIP" "git checkout -b feat/<ticket-id>" && pass "ship: creates the feature branch via git checkout -b"
should_run "ship: pushes the branch before opening the PR" && assert_file_contains "ship: pushes the branch before opening the PR" "$SHIP" "git push -u origin feat/<ticket-id>" && pass "ship: pushes the branch before opening the PR"
# Step 5 close-out report: pins all four named outcomes so the reporting contract cannot silently erode
should_run "ship: has Step 5 close-out report" && assert_file_contains "ship: has Step 5 close-out report" "$SHIP" "## Step 5 — Close-out report" && pass "ship: has Step 5 close-out report"
should_run "ship: close-out report has exactly four named outcomes" && assert_file_contains "ship: close-out report has exactly four named outcomes" "$SHIP" "Report one of four outcomes" && pass "ship: close-out report has exactly four named outcomes"
should_run "ship: close-out outcome 1 covers invalid ticket id" && assert_file_contains "ship: close-out outcome 1 covers invalid ticket id" "$SHIP" "(1) invalid ticket id" && pass "ship: close-out outcome 1 covers invalid ticket id"
should_run "ship: close-out outcome 2 covers dirty-tree abort" && assert_file_contains "ship: close-out outcome 2 covers dirty-tree abort" "$SHIP" "(2)" && assert_file_contains "ship: close-out outcome 2 covers dirty-tree abort" "$SHIP" "dirty tree — that \`/ship\` aborted" && pass "ship: close-out outcome 2 covers dirty-tree abort"
should_run "ship: close-out outcome 3 covers consistency-check stop" && assert_file_contains "ship: close-out outcome 3 covers consistency-check stop" "$SHIP" "(3) consistency-check" && pass "ship: close-out outcome 3 covers consistency-check stop"
should_run "ship: close-out outcome 4 covers PR opened with URL" && assert_file_contains "ship: close-out outcome 4 covers PR opened with URL" "$SHIP" "or (4) PR opened" && assert_file_contains "ship: close-out outcome 4 covers PR opened with URL" "$SHIP" "the PR URL." && pass "ship: close-out outcome 4 covers PR opened with URL"

# ── summary ──────────────────────────────────────────────────────────────────

th_summary
