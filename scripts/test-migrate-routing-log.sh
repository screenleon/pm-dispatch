#!/usr/bin/env bash
# Regression suite for migrate-routing-log.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MIGRATOR="$SCRIPT_DIR/migrate-routing-log.sh"

PASS=0
FAIL=0
FAILED_CASES=()
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass() {
  PASS=$((PASS+1))
  [[ "${VERBOSE:-}" ]] && printf '  PASS  %s\n' "$1"
}

fail() {
  FAIL=$((FAIL+1))
  FAILED_CASES+=("$1")
  printf '  FAIL  %s%s\n' "$1" "${2:+ — $2}"
}

write_fixture() {
  local path="$1" malformed="${2:-0}"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
---
name: routing_log
type: log
---
Append one row per Brief or Dispatch decision.

| date | task | routed to | Q hit | second-thoughts |
|------|------|-----------|-------|-----------------|
| 2026-05-15 | legacy alpha | Codex | Q1 | no |
| 2026-05-15 | legacy beta | Claude | Q2 | yes |

## 2026-05-15 — one
- Task: apply exact patch one
- Routed to: Codex (executor)
- Q1/Q2/Q3 hit: Q1 yes
- Second thoughts: none

## 2026-05-15 — two
- Task: judgment review two
- Routed to: Claude (main thread)
- Q1/Q2/Q3 hit: Q1 no
- Second thoughts: none

## 2026-05-15 — three
EOF
  if [[ "$malformed" != "1" ]]; then
    printf '%s\n' '- Task: apply exact patch three' >> "$path"
  fi
  cat >> "$path" <<'EOF'
- Routed to: Codex (executor subagent)
- Q1/Q2/Q3 hit: Q1 yes
- Second thoughts: none

## 2026-05-15 — four
- Task: direct bootstrap four
- Routed to: main-thread direct
- Q1/Q2/Q3 hit: bootstrap
- Second thoughts: skip

## 2026-05-16 — five
- Task: apply exact patch five
- Routed to: Codex
- Q1/Q2/Q3 hit: Q1 yes
- Second thoughts: none

## 2026-05-17 — six
- Task: apply exact patch six
- Routed to: Codex
- Q1/Q2/Q3 hit: Q1 yes
- Second thoughts: none
EOF
}

row_count() {
  awk '/<!-- routing-log:auto-block:start -->/{in_block=1; next} /<!-- routing-log:auto-block:end -->/{in_block=0} in_block && /^\{/' "$1" | wc -l
}

legacy_region() {
  awk '
    /^\| date \| task \| routed to \| Q hit \| second-thoughts \|/ { in_table=1 }
    in_table { print }
    in_table && /^$/ { exit }
  ' "$1"
}

assert_schema() {
  local path="$1"
  awk '/<!-- routing-log:auto-block:start -->/{in_block=1; next} /<!-- routing-log:auto-block:end -->/{in_block=0} in_block && /^\{/' "$path" |
    jq -e '.ts and (.kind | IN("bash-dispatch","agent-dispatch")) and has("subagent_type") and has("brief_file") and has("goal_excerpt") and has("q_hit") and has("second_thoughts")' >/dev/null
}

# Behavior: Fresh legacy routing_log.md migration writes a backup, auto-block markers, and five JSONL rows.
# Steps:
#   1. Prepare a legacy routing_log.md fixture without an auto-block.
#   2. Trigger migrate-routing-log.sh against that fixture.
#   3. Verify backup creation, marker insertion, row count, legacy bullet removal, and JSON schema.
test_fresh_migrates() {
  local name="migrate: fresh file writes backup markers and 5 rows" path out
  path="$TMP_ROOT/m1/routing_log.md"
  write_fixture "$path"
  out="$(CLAUDE_ROUTING_LOG_PATH="$path" "$MIGRATOR" 2>&1)"
  if [[ -f "$path.bak" ]] && grep -q '<!-- routing-log:auto-block:start -->' "$path" && [[ "$(row_count "$path")" == "5" ]] && ! grep -q '^## 2026-05' "$path" && assert_schema "$path"; then
    pass "$name"
  else
    fail "$name" "$out"
  fi
}

# Behavior: Re-running migration on an already migrated routing_log.md is a no-op.
# Steps:
#   1. Prepare and migrate a legacy routing_log.md fixture once.
#   2. Trigger migrate-routing-log.sh against the migrated fixture again.
#   3. Verify the output reports no-op, file bytes are preserved, and the backup remains.
test_idempotent() {
  local name="migrate: second invocation no-op preserves file and bak" path out
  path="$TMP_ROOT/m2/routing_log.md"
  write_fixture "$path"
  CLAUDE_ROUTING_LOG_PATH="$path" "$MIGRATOR" >/dev/null 2>&1
  cp "$path" "$path.after1"
  out="$(CLAUDE_ROUTING_LOG_PATH="$path" "$MIGRATOR" 2>&1)"
  if [[ "$out" == "migrate-routing-log: already migrated, nothing to do" ]] && cmp -s "$path" "$path.after1" && [[ -f "$path.bak" ]]; then
    pass "$name"
  else
    fail "$name" "$out"
  fi
}

# Behavior: Migration aborts without touching routing_log.md when a backup already exists.
# Steps:
#   1. Prepare a legacy routing_log.md fixture and a pre-existing .bak file.
#   2. Trigger migrate-routing-log.sh against that fixture.
#   3. Verify the command exits non-zero, reports the backup conflict, and preserves the original file.
test_existing_backup_aborts() {
  local name="migrate: existing backup aborts without touching file" path out status
  path="$TMP_ROOT/m3/routing_log.md"
  write_fixture "$path"
  cp "$path" "$path.before"
  printf 'old backup\n' > "$path.bak"
  out="$(CLAUDE_ROUTING_LOG_PATH="$path" "$MIGRATOR" 2>&1)" && status=$? || status=$?
  if [[ "$status" -ne 0 ]] && [[ "$out" == *"already exists"* ]] && cmp -s "$path" "$path.before"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: Migration skips malformed legacy bullets while migrating valid rows and auditing the skip.
# Steps:
#   1. Prepare a legacy routing_log.md fixture with one malformed bullet.
#   2. Trigger migrate-routing-log.sh against that fixture.
#   3. Verify only valid rows are migrated and the missing Task line is reported.
test_malformed_skips() {
  local name="migrate: malformed bullet skips one row and audits" path out
  path="$TMP_ROOT/m4/routing_log.md"
  write_fixture "$path" 1
  out="$(CLAUDE_ROUTING_LOG_PATH="$path" "$MIGRATOR" 2>&1)"
  if [[ "$(row_count "$path")" == "4" ]] && [[ "$out" == *"missing Task line"* ]]; then
    pass "$name"
  else
    fail "$name" "$out"
  fi
}

# Behavior: Migration preserves the legacy markdown table region byte-for-byte.
# Steps:
#   1. Prepare a legacy routing_log.md fixture and save its table region.
#   2. Trigger migrate-routing-log.sh against that fixture.
#   3. Verify the table region after migration matches the saved copy.
test_legacy_integrity() {
  local name="migrate: legacy table region byte-for-byte unchanged" path
  path="$TMP_ROOT/m5/routing_log.md"
  write_fixture "$path"
  legacy_region "$path" > "$path.legacy.before"
  CLAUDE_ROUTING_LOG_PATH="$path" "$MIGRATOR" >/dev/null 2>&1
  legacy_region "$path" > "$path.legacy.after"
  if diff -u "$path.legacy.before" "$path.legacy.after" >/dev/null; then
    pass "$name"
  else
    fail "$name"
  fi
}

echo "== migrate-routing-log =="
test_fresh_migrates
test_idempotent
test_existing_backup_aborts
test_malformed_skips
test_legacy_integrity

echo
echo "----"
echo "$PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
