#!/usr/bin/env bash
# Regression suite for migrate-routing-to-events.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATOR="$SCRIPT_DIR/migrate-routing-to-events.sh"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

write_routing_log() {
  local path="$1" rows="$2"
  mkdir -p "$(dirname "$path")"
  {
    printf '%s\n' '---'
    printf '%s\n' 'name: routing_log'
    printf '%s\n' 'type: log'
    printf '%s\n' '---'
    printf '\n'
    printf '%s\n' '<!-- routing-log:auto-block:start -->'
    printf '%s\n' "$rows"
    printf '%s\n' '<!-- routing-log:auto-block:end -->'
  } > "$path"
}

events_file_for_store() {
  local store="$1"
  find "$store" -name events.jsonl -type f 2>/dev/null | head -1
}

event_count() {
  local store="$1" file
  file="$(events_file_for_store "$store")"
  [[ -n "$file" && -f "$file" ]] || { printf '0\n'; return 0; }
  wc -l < "$file" | tr -d '[:space:]'
}

events_jq() {
  local store="$1" expr="$2" file
  file="$(events_file_for_store "$store")"
  [[ -n "$file" && -f "$file" ]] || return 1
  jq -e "$expr" "$file" >/dev/null
}

events_all_jq() {
  local store="$1" expr="$2" file
  file="$(events_file_for_store "$store")"
  [[ -n "$file" && -f "$file" ]] || return 1
  jq -s -e "$expr" "$file" >/dev/null
}

run_migrator() {
  local routing_path="$1" store="$2"
  CLAUDE_ROUTING_LOG_PATH="$routing_path" PM_DISPATCH_STATE_ROOT="$store" "$MIGRATOR" --cwd "$REPO_ROOT"
}

fixture_two_rows() {
  cat <<'EOF'
{"ts":"2026-06-05T01:02:03Z","session_id":"abcdef12-3456-7890-abcd-ef1234567890","kind":"bash-dispatch","subagent_type":null,"brief_file":"/tmp/brief.md","goal_excerpt":"ship it","q_hit":null,"second_thoughts":null}
{"ts":"2026-06-05T01:03:04+0900","session_id":"12345678-3456-7890-abcd-ef1234567890","kind":"agent-dispatch","subagent_type":"codex-executor","brief_file":null,"goal_excerpt":null,"q_hit":null,"second_thoughts":null}
EOF
}

# Behavior: Migration converts bash-dispatch and agent-dispatch routing rows to run.dispatched events.
# Steps:
#   1. Prepare routing_log.md with two JSONL rows.
#   2. Run the migrator against an isolated state store.
#   3. Verify two schema-shaped events are appended to events.jsonl.
test_happy_path() {
  local name="migrate-to-events: happy path writes two run.dispatched events"
  should_run "$name" || return 0
  local dir path store out
  dir="$tmp_root/happy"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" "$(fixture_two_rows)"
  out="$(run_migrator "$path" "$store" 2>&1)"
  if [[ "$(event_count "$store")" == "2" ]] &&
     events_jq "$store" 'select(.kind == "run.dispatched" and .subject_type == "run" and (.payload.run_id == .subject_id) and .payload.state == "dispatched" and .payload.from_state == "pending" and .payload.to_state == "dispatched")' &&
     [[ "$out" == *"migrated 2 event(s)"* ]]; then
    pass "$name"
  else
    fail "$name" "$out"
  fi
}

# Behavior: Re-running migration over identical routing rows does not duplicate events.
# Steps:
#   1. Prepare routing_log.md with two JSONL rows.
#   2. Run the migrator twice against the same isolated state store.
#   3. Verify events.jsonl still has exactly two rows and deterministic IDs.
test_idempotent() {
  local name="migrate-to-events: second run skips duplicate derived ids"
  should_run "$name" || return 0
  local dir path store file ids_before ids_after
  dir="$tmp_root/idempotent"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" "$(fixture_two_rows)"
  run_migrator "$path" "$store" >/dev/null 2>&1
  file="$(events_file_for_store "$store")"
  ids_before="$(jq -r '.id' "$file")"
  run_migrator "$path" "$store" >/dev/null 2>&1
  ids_after="$(jq -r '.id' "$file")"
  if [[ "$(event_count "$store")" == "2" ]] && [[ "$ids_before" == "$ids_after" ]]; then
    pass "$name"
  else
    fail "$name" "ids_before=$ids_before ids_after=$ids_after"
  fi
}

# Behavior: Unknown routing kinds are skipped with a warning while the command exits zero.
# Steps:
#   1. Prepare routing_log.md with one unknown kind row.
#   2. Run the migrator against an isolated state store.
#   3. Verify no events are written and stderr contains the unknown kind.
test_unknown_kind_skips() {
  local name="migrate-to-events: unknown kind skips with warning"
  should_run "$name" || return 0
  local dir path store out status
  dir="$tmp_root/unknown"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" '{"ts":"2026-06-05T01:02:03Z","session_id":"abcdef12-3456-7890-abcd-ef1234567890","kind":"unknown-kind"}'
  out="$(run_migrator "$path" "$store" 2>&1)" && status=$? || status=$?
  if [[ "$status" == "0" ]] && [[ "$(event_count "$store")" == "0" ]] && [[ "$out" == *"skipping unknown kind: unknown-kind"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: Empty auto-blocks are a no-op and leave events.jsonl absent.
# Steps:
#   1. Prepare routing_log.md with an empty JSONL auto-block.
#   2. Run the migrator against an isolated state store.
#   3. Verify the command exits zero and no events are appended.
test_no_rows() {
  local name="migrate-to-events: empty auto-block leaves events unchanged"
  should_run "$name" || return 0
  local dir path store out status
  dir="$tmp_root/no-rows"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" ""
  out="$(run_migrator "$path" "$store" 2>&1)" && status=$? || status=$?
  if [[ "$status" == "0" ]] && [[ "$(event_count "$store")" == "0" ]] && [[ "$out" == *"no routing rows found"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: Missing routing_log.md exits zero with an informational message.
# Steps:
#   1. Point the migrator at a missing routing_log.md path.
#   2. Run the migrator against an isolated state store.
#   3. Verify exit zero and no event file is created.
test_missing_file() {
  local name="migrate-to-events: missing routing_log exits zero"
  should_run "$name" || return 0
  local dir path store out status
  dir="$tmp_root/missing"
  path="$dir/routing_log.md"
  store="$dir/state"
  out="$(run_migrator "$path" "$store" 2>&1)" && status=$? || status=$?
  if [[ "$status" == "0" ]] && [[ "$(event_count "$store")" == "0" ]] && [[ "$out" == *"routing_log.md not found"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: Derived event IDs match the schema pattern and use the row timestamp/session prefix.
# Steps:
#   1. Migrate a single routing row with a UTC timestamp and hex session prefix.
#   2. Read the generated event from events.jsonl.
#   3. Verify the deterministic event id and subject id.
test_event_id_format() {
  local name="migrate-to-events: event id format is deterministic"
  should_run "$name" || return 0
  local dir path store
  dir="$tmp_root/id-format"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" '{"ts":"2026-06-05T01:02:03Z","session_id":"abcdef12-3456-7890-abcd-ef1234567890","kind":"bash-dispatch"}'
  run_migrator "$path" "$store" >/dev/null 2>&1
  if events_jq "$store" '(.id | test("^evt-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}-[a-f0-9]{8}$")) and (.subject_id | test("^run-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}-[a-f0-9]{8}$"))'; then
    pass "$name"
  else
    fail "$name"
  fi
}

# Behavior: Every migrated run event includes the required run payload contract.
# Steps:
#   1. Migrate the two-row routing fixture.
#   2. Read all generated events from events.jsonl.
#   3. Verify required run payload fields are present on every event.
test_payload_contract() {
  local name="migrate-to-events: payload contains run transition contract"
  should_run "$name" || return 0
  local dir path store
  dir="$tmp_root/payload"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" "$(fixture_two_rows)"
  run_migrator "$path" "$store" >/dev/null 2>&1
  if events_all_jq "$store" 'length == 2 and all(.[]; .payload.run_id and .payload.state and .payload.from_state and .payload.to_state)'; then
    pass "$name"
  else
    fail "$name"
  fi
}


# Behavior: Two distinct routing rows with the same session and same second each
# produce a unique event, because the ID includes a content hash component.
# Steps:
#   1. Prepare routing_log.md with two rows sharing session and timestamp-second
#      but differing in kind/fields.
#   2. Run the migrator.
#   3. Verify both rows become distinct events in events.jsonl.
test_same_second_distinct_rows() {
  local name="migrate-to-events: same-second distinct rows both migrate"
  should_run "$name" || return 0
  local dir path store
  dir="$tmp_root/same-second"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" "$(cat <<'ROWS'
{"ts":"2026-06-05T01:02:03Z","session_id":"abcdef12-3456-7890-abcd-ef1234567890","kind":"bash-dispatch","goal_excerpt":"task A"}
{"ts":"2026-06-05T01:02:03Z","session_id":"abcdef12-3456-7890-abcd-ef1234567890","kind":"bash-dispatch","goal_excerpt":"task B"}
ROWS
)"
  run_migrator "$path" "$store" >/dev/null 2>&1
  local count
  count="$(event_count "$store")"
  if [[ "$count" == "2" ]]; then
    pass "$name"
  else
    fail "$name" "expected 2 events, got $count"
  fi
}

# Behavior: Re-running after same-second distinct rows are already migrated stays idempotent.
# Steps:
#   1. Run the migrator twice on the same same-second fixture.
#   2. Verify still exactly 2 events after second run.
test_same_second_idempotent() {
  local name="migrate-to-events: same-second rows stay idempotent on rerun"
  should_run "$name" || return 0
  local dir path store
  dir="$tmp_root/same-second-idempotent"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" "$(cat <<'ROWS'
{"ts":"2026-06-05T01:02:03Z","session_id":"abcdef12-3456-7890-abcd-ef1234567890","kind":"bash-dispatch","goal_excerpt":"task A"}
{"ts":"2026-06-05T01:02:03Z","session_id":"abcdef12-3456-7890-abcd-ef1234567890","kind":"bash-dispatch","goal_excerpt":"task B"}
ROWS
)"
  run_migrator "$path" "$store" >/dev/null 2>&1
  run_migrator "$path" "$store" >/dev/null 2>&1
  local count
  count="$(event_count "$store")"
  if [[ "$count" == "2" ]]; then
    pass "$name"
  else
    fail "$name" "expected 2 events after rerun, got $count"
  fi
}

# Behavior: Malformed JSON rows are skipped with a warning and the migrator exits zero.
test_malformed_json_skips() {
  local name="migrate-to-events: malformed JSON row skips with warning"
  should_run "$name" || return 0
  local dir path store out status
  dir="$tmp_root/malformed"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" '{"broken json'
  out="$(run_migrator "$path" "$store" 2>&1)" && status=$? || status=$?
  if [[ "$status" == "0" ]] && [[ "$(event_count "$store")" == "0" ]] && [[ "$out" == *"skipping malformed JSON row"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out count=$(event_count "$store")"
  fi
}

# Behavior: A row with an invalid timestamp is skipped with a warning and the migrator exits zero.
test_invalid_timestamp_skips() {
  local name="migrate-to-events: invalid timestamp row skips with warning"
  should_run "$name" || return 0
  local dir path store out status
  dir="$tmp_root/bad-ts"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" '{"ts":"not-a-timestamp","session_id":"abcdef12-3456-7890-abcd-ef1234567890","kind":"bash-dispatch"}'
  out="$(run_migrator "$path" "$store" 2>&1)" && status=$? || status=$?
  if [[ "$status" == "0" ]] && [[ "$(event_count "$store")" == "0" ]] && [[ "$out" == *"skipping row with invalid ts"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out count=$(event_count "$store")"
  fi
}

# Behavior: A row with a non-hex session_id prefix is skipped with a warning and the migrator exits zero.
test_invalid_session_prefix_skips() {
  local name="migrate-to-events: invalid session_id prefix row skips with warning"
  should_run "$name" || return 0
  local dir path store out status
  dir="$tmp_root/bad-session"
  path="$dir/routing_log.md"
  store="$dir/state"
  write_routing_log "$path" '{"ts":"2026-06-05T01:02:03Z","session_id":"XXXXXX-invalid-session","kind":"bash-dispatch"}'
  out="$(run_migrator "$path" "$store" 2>&1)" && status=$? || status=$?
  if [[ "$status" == "0" ]] && [[ "$(event_count "$store")" == "0" ]] && [[ "$out" == *"skipping row with invalid session_id prefix"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out count=$(event_count "$store")"
  fi
}

test_happy_path
test_idempotent
test_unknown_kind_skips
test_no_rows
test_missing_file
test_event_id_format
test_payload_contract
test_same_second_distinct_rows
test_same_second_idempotent
test_malformed_json_skips
test_invalid_timestamp_skips
test_invalid_session_prefix_skips

th_summary
