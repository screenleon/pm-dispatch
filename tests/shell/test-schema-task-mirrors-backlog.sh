#!/usr/bin/env bash
# Verifies that BACKLOG.md row IDs are compatible with task.schema.json id pattern,
# including sub-letter variants like CC-025b. Planned in CC-229 substrate synthesis.
set -euo pipefail

# shellcheck source=tests/lib/test-harness.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

CORE_DIR="$REPO_ROOT/core"
TASK_SCHEMA="$CORE_DIR/schema/task.schema.json"
BACKLOG="$REPO_ROOT/BACKLOG.md"

case_task_id_pattern_accepts_backlog_ids() {
  # Verifies that the task.schema.json id regex accepts all CC-NNN and CC-NNNb style
  # IDs found in BACKLOG.md, ensuring the locked schema does not reject existing rows.
  #
  # Steps:
  #   1. Extract the id pattern from task.schema.json via jq.
  #   2. Collect all unique BACKLOG IDs (including sub-letter forms) via grep.
  #   3. Assert each ID matches the extracted pattern.
  local name="task.schema.json: id pattern accepts all BACKLOG ids"
  should_run "$name" || return 0
  local pattern
  pattern="$(jq -r '.properties.id.pattern' "$TASK_SCHEMA")"
  local bad_id=""
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if ! printf '%s\n' "$id" | grep -qE "$pattern"; then
      bad_id="$id"
      break
    fi
  done < <(grep -oE '\b[A-Z]{1,4}-[0-9]+[a-z]?\b' "$BACKLOG" | sort -u)
  if [[ -n "$bad_id" ]]; then
    fail "$name" "BACKLOG id '$bad_id' does not match task.schema.json pattern '$pattern'"
  else
    pass "$name"
  fi
}

case_task_id_pattern_rejects_invalid() {
  # Verifies that the task.schema.json id pattern rejects malformed or invalid ID forms
  # such as lowercase prefixes, missing numbers, double suffixes, and over-long prefixes.
  #
  # Steps:
  #   1. Extract the id pattern from task.schema.json via jq.
  #   2. Assert that known-invalid forms do not match the pattern.
  local name="task.schema.json: id pattern rejects invalid ids"
  should_run "$name" || return 0
  local pattern
  pattern="$(jq -r '.properties.id.pattern' "$TASK_SCHEMA")"
  local -a invalid_ids=("cc-025" "CC-" "CC-025bb" "CC-025-b" "TOOLONG-025" "123" "CC-025 " " CC-025")
  local bad=""
  for id in "${invalid_ids[@]}"; do
    if printf '%s\n' "$id" | grep -qE "$pattern"; then
      bad="$id"
      break
    fi
  done
  if [[ -n "$bad" ]]; then
    fail "$name" "task.schema.json pattern '$pattern' incorrectly accepts invalid id '$bad'"
  else
    pass "$name"
  fi
}

case_task_id_pattern_accepts_backlog_ids
case_task_id_pattern_rejects_invalid

th_summary
