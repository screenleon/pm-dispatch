#!/usr/bin/env bash
# Regression suite for migrate-routing-log.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MIGRATOR="$SCRIPT_DIR/migrate-routing-log.sh"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"
# shellcheck source=scripts/lib/test-memory-config-fixtures.sh
. "$SCRIPT_DIR/lib/test-memory-config-fixtures.sh"

# Migrator fixtures must not inherit the operator's project memory config.
export PM_DISPATCH_CONFIG_FILE="$tmp_root/no-operator-config"
unset PM_MEMORY_DIR PM_CFG_MEMORY_DIR PM_CFG_MEMORY_DIR_INVALID PM_CFG_MEMORY_CONFIG_STATUS

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
  local name="migrate: fresh file writes backup markers and 5 rows"
  should_run "$name" || return 0
  local path out
  path="$tmp_root/m1/routing_log.md"
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
  local name="migrate: second invocation no-op preserves file and bak"
  should_run "$name" || return 0
  local path out
  path="$tmp_root/m2/routing_log.md"
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
  local name="migrate: existing backup aborts without touching file"
  should_run "$name" || return 0
  local path out status
  path="$tmp_root/m3/routing_log.md"
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
  local name="migrate: malformed bullet skips one row and audits"
  should_run "$name" || return 0
  local path out
  path="$tmp_root/m4/routing_log.md"
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
  local name="migrate: legacy table region byte-for-byte unchanged"
  should_run "$name" || return 0
  local path
  path="$tmp_root/m5/routing_log.md"
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

# Behavior: CLAUDE_ROUTING_LOG_DIR env var overrides project-memory directory discovery.
# Steps:
#   1. Write a fixture to $tmp_root/m6/routing_log.md.
#   2. Run migrator without CLAUDE_ROUTING_LOG_PATH, with CLAUDE_ROUTING_LOG_DIR pointing
#      to $tmp_root/m6, and with --cwd set to a path that has no .claude memory dir.
#   3. Verify exit 0 — the override was respected and migration succeeded.
test_routing_log_dir_override() {
  local name="migrate: CLAUDE_ROUTING_LOG_DIR overrides memory discovery"
  local path dir
  should_run "$name" || return 0
  dir="$tmp_root/m6"
  path="$dir/routing_log.md"
  write_fixture "$path"
  if CLAUDE_ROUTING_LOG_DIR="$dir" "$MIGRATOR" --cwd /tmp/no-such-cwd-cc104t 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "CLAUDE_ROUTING_LOG_DIR override not respected by find_memory_dir"
  fi
}

# Behavior: PM_MEMORY_DIR env var overrides project-memory directory discovery
# (cross-tool memory-dir seam), same as CLAUDE_ROUTING_LOG_DIR does today.
# Steps:
#   1. Write a fixture to $tmp_root/m7/routing_log.md.
#   2. Run migrator with PM_MEMORY_DIR pointing to $tmp_root/m7 and --cwd set
#      to a path with no .claude memory dir.
#   3. Verify exit 0 — the override was respected and migration succeeded.
test_pm_memory_dir_override() {
  local name="migrate: PM_MEMORY_DIR overrides memory discovery"
  local path dir
  should_run "$name" || return 0
  dir="$tmp_root/m7"
  path="$dir/routing_log.md"
  write_fixture "$path"
  if PM_MEMORY_DIR="$dir" "$MIGRATOR" --cwd /tmp/no-such-cwd-pmmem-a 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "PM_MEMORY_DIR override not respected by find_memory_dir"
  fi
}

# Behavior: PM_MEMORY_DIR outranks CLAUDE_ROUTING_LOG_DIR when both are set
# (design decision: the new cross-tool seam supersedes the legacy,
# installer-only override).
# Steps:
#   1. Write a valid fixture to $tmp_root/m8-win/routing_log.md (PM_MEMORY_DIR
#      target) and a decoy fixture with no routing_log.md at
#      $tmp_root/m8-lose (CLAUDE_ROUTING_LOG_DIR target).
#   2. Run migrator with both env vars set.
#   3. Verify exit 0 — resolution used PM_MEMORY_DIR (the only one with a
#      migratable routing_log.md), not CLAUDE_ROUTING_LOG_DIR.
test_pm_memory_dir_outranks_routing_log_dir() {
  local name="migrate: PM_MEMORY_DIR outranks CLAUDE_ROUTING_LOG_DIR"
  local win_dir lose_dir
  should_run "$name" || return 0
  win_dir="$tmp_root/m8-win"
  lose_dir="$tmp_root/m8-lose"
  mkdir -p "$lose_dir"
  write_fixture "$win_dir/routing_log.md"
  if PM_MEMORY_DIR="$win_dir" CLAUDE_ROUTING_LOG_DIR="$lose_dir" \
      "$MIGRATOR" --cwd /tmp/no-such-cwd-pmmem-b 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected PM_MEMORY_DIR to win over CLAUDE_ROUTING_LOG_DIR"
  fi
}

# Behavior: An unavailable project-scoped memory selection prevents migration
# from falling back to a populated legacy Claude memory directory.
# Steps:
#   1. Populate a legacy routing_log.md for an isolated project path.
#   2. Configure that project to use a missing project-scoped memory directory.
#   3. Verify migration fails and leaves the legacy file and backup state untouched.
test_invalid_project_memory_does_not_fallback() {
  local name="migrate: invalid project memory does not fall back to legacy"
  should_run "$name" || return 0
  local repo="$tmp_root/m9-repo" home="$tmp_root/m9-home" config="$tmp_root/m9.config"
  local missing="$tmp_root/m9-missing" legacy encoded out status=0
  mkdir -p "$repo"
  encoded="-$(printf '%s' "${repo#/}" | tr '/' '-')"
  legacy="$home/.claude/projects/$encoded/memory/routing_log.md"
  write_fixture "$legacy"
  cp "$legacy" "$legacy.before"
  write_project_memory_config "$config" "$repo" "$missing"

  out="$(PM_DISPATCH_CONFIG_FILE="$config" HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" \
    "$MIGRATOR" --cwd "$repo" 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$out" == *"failed to discover"* ]] \
      && cmp -s "$legacy" "$legacy.before" && [[ ! -e "$legacy.bak" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_fresh_migrates
test_idempotent
test_existing_backup_aborts
test_malformed_skips
test_legacy_integrity
test_routing_log_dir_override
test_pm_memory_dir_override
test_pm_memory_dir_outranks_routing_log_dir
test_invalid_project_memory_does_not_fallback

th_summary
