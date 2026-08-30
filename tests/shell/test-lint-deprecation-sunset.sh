#!/usr/bin/env bash
# Regression tests for tools/lint/lint-deprecation-sunset.sh -- every rejection
# class gets a mutation-sensitive fixture.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-deprecation-sunset.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# fixture <slug> -- minimal tree the lint accepts; prints the root.
# Callers then add/replace docs, schema, commands.tsv, allowlist rows.
fixture() {
  # shellcheck disable=SC2154  # tmp_root from th_init
  local root="$tmp_root/$1"
  mkdir -p "$root/docs" "$root/docs/architecture" "$root/core/schema" \
    "$root/cli" "$root/tools/lint"
  printf 'path\treason\n' > "$root/tools/lint/deprecation-sunset-allowlist.tsv"
  printf 'path\tsummary\tusage\tstability\tjson\tmutating\toptions\texample\n' \
    > "$root/cli/commands.tsv"
  printf '%s\n' "$root"
}

run_linter() { bash "$LINTER" --repo-root "$1" 2>&1; }

want_pass() {
  local name="$1" root="$2" out rc=0
  out="$(run_linter "$root")" || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "expected exit 0, got $rc :: $out"; fi
}
want_fail() {
  local name="$1" root="$2" needle="$3" out rc=0
  out="$(run_linter "$root")" || rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"$needle"* ]]; then pass "$name"
  else fail "$name" "expected non-zero + '$needle', got rc=$rc :: $out"; fi
}

# --- the real tree ---------------------------------------------------------
test_clean_repo_passes() {
  local name="clean repo tree passes"
  should_run "$name" || return 0
  want_pass "$name" "$REPO_ROOT"
}

# --- surface 1: docs banners --------------------------------------------------
test_unversioned_banner_fails() {
  local name="an unversioned DEPRECATED banner fails, naming the file"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# X\n\n> **DEPRECATED.** use the new thing.\n' > "$root/docs/thing.md"
  want_fail "$name" "$root" "docs/thing.md"
}

test_versioned_banner_passes() {
  local name="a banner naming a removal version passes"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# X\n\n> **DEPRECATED.** removed in v9.9.0; use the new thing.\n' > "$root/docs/thing.md"
  want_pass "$name" "$root"
}

test_retired_banner_needs_version_too() {
  local name="a RETIRED banner without a version also fails"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# X\n\n> **RETIRED.** the fan-out path is gone.\n' > "$root/docs/architecture/old.md"
  want_fail "$name" "$root" "docs/architecture/old.md"
}

# --- allowlist behaviour ---------------------------------------------------
test_allowlisted_unversioned_banner_passes() {
  local name="an unversioned banner listed in the allowlist passes"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# X\n\n> **DEPRECATED.** kept forever for compat.\n' > "$root/docs/legacy.md"
  printf 'docs/legacy.md\tinternal-schema compat, no removal planned\n' \
    >> "$root/tools/lint/deprecation-sunset-allowlist.tsv"
  want_pass "$name" "$root"
}

test_allowlist_for_versioned_surface_fails() {
  local name="an allowlist entry for an already-versioned surface is rejected"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# X\n\n> **DEPRECATED.** removed in v9.9.0.\n' > "$root/docs/thing.md"
  printf 'docs/thing.md\tredundant\n' \
    >> "$root/tools/lint/deprecation-sunset-allowlist.tsv"
  want_fail "$name" "$root" "unnecessary"
}

test_allowlist_for_unmarked_surface_fails() {
  local name="an allowlist entry for a file with no marker is rejected"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# X\n\nnothing deprecated here.\n' > "$root/docs/plain.md"
  printf 'docs/plain.md\tstale entry\n' \
    >> "$root/tools/lint/deprecation-sunset-allowlist.tsv"
  want_fail "$name" "$root" "names no deprecated surface"
}

test_malformed_allowlist_row_fails() {
  local name="a one-field allowlist row is rejected"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf 'docs/whatever.md\n' >> "$root/tools/lint/deprecation-sunset-allowlist.tsv"
  want_fail "$name" "$root" "malformed allowlist row"
}

test_missing_allowlist_file_fails() {
  local name="a missing allowlist file is a hard error"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  rm -f "$root/tools/lint/deprecation-sunset-allowlist.tsv"
  want_fail "$name" "$root" "missing"
}

# --- surface 2: JSON Schema ------------------------------------------------
test_schema_deprecated_without_version_fails() {
  local name="a schema field marked deprecated with no nearby version fails"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '{\n  "properties": {\n    "old": { "type": "string", "deprecated": true }\n  }\n}\n' \
    > "$root/core/schema/thing.schema.json"
  want_fail "$name" "$root" "core/schema/thing.schema.json"
}

test_schema_deprecated_with_version_passes() {
  local name="a schema deprecated field with a version in its description passes"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '{\n  "properties": {\n    "old": {\n      "type": "string",\n      "deprecated": true,\n      "description": "removed in v9.9.0"\n    }\n  }\n}\n' \
    > "$root/core/schema/thing.schema.json"
  want_pass "$name" "$root"
}

test_schema_mixed_dated_and_undated_fails() {
  local name="a dated deprecated field does not mask an undated sibling in the same schema"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '{\n  "properties": {\n    "a": { "deprecated": true, "description": "removed in v9.9.0" },\n    "b": { "deprecated": true }\n  }\n}\n' \
    > "$root/core/schema/mixed.schema.json"
  want_fail "$name" "$root" "core/schema/mixed.schema.json"
}

test_schema_deprecated_false_is_not_a_marker() {
  local name="a schema with only \"deprecated\": false and no version passes"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '{\n  "properties": {\n    "a": { "deprecated": false }\n  }\n}\n' \
    > "$root/core/schema/notdep.schema.json"
  want_pass "$name" "$root"
}

# --- surface 3: cli/commands.tsv ----------------------------------------------
test_commands_deprecated_without_version_fails() {
  local name="a stability=deprecated command row with no version fails"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf 'old cmd\tOld command.\tpmctl old cmd\tdeprecated\tfalse\tfalse\tnone\tpmctl old cmd\n' \
    >> "$root/cli/commands.tsv"
  want_fail "$name" "$root" "stability=deprecated"
}

test_commands_deprecated_with_version_passes() {
  local name="a stability=deprecated command row naming a version passes"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf 'old cmd\tOld command; removed in v9.9.0.\tpmctl old cmd\tdeprecated\tfalse\tfalse\tnone\tpmctl old cmd\n' \
    >> "$root/cli/commands.tsv"
  want_pass "$name" "$root"
}

test_commands_mixed_dated_and_undated_fails() {
  local name="a dated deprecated command row does not mask an undated one"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf 'old one\tGone; removed in v9.9.0.\tpmctl old one\tdeprecated\tfalse\tfalse\tnone\tpmctl old one\n' \
    >> "$root/cli/commands.tsv"
  printf 'old two\tAlso gone.\tpmctl old two\tdeprecated\tfalse\tfalse\tnone\tpmctl old two\n' \
    >> "$root/cli/commands.tsv"
  want_fail "$name" "$root" "'old two' is stability=deprecated with no version"
}

# --- usage ---------------------------------------------------------------
test_bad_flag_is_usage_error() {
  local name="an unknown flag exits 2"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$LINTER" --nonsense 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "expected exit 2, got $rc :: $out"; fi
}

test_clean_repo_passes
test_unversioned_banner_fails
test_versioned_banner_passes
test_retired_banner_needs_version_too
test_allowlisted_unversioned_banner_passes
test_allowlist_for_versioned_surface_fails
test_allowlist_for_unmarked_surface_fails
test_malformed_allowlist_row_fails
test_missing_allowlist_file_fails
test_schema_deprecated_without_version_fails
test_schema_deprecated_with_version_passes
test_schema_mixed_dated_and_undated_fails
test_schema_deprecated_false_is_not_a_marker
test_commands_deprecated_without_version_fails
test_commands_deprecated_with_version_passes
test_commands_mixed_dated_and_undated_fails
test_bad_flag_is_usage_error

th_summary
