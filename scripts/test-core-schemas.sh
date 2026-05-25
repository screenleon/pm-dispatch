#!/usr/bin/env bash
# Structural tests for core/ substrate (CC-229 schema-only PR).
#
# These tests validate that:
#   1. Every JSON Schema file under core/schema/ is valid JSON
#   2. Every YAML file under core/policy/ and core/state/ is valid YAML
#   3. Schemas declaring schema_version do so as `const: 1`
#   4. Enum values referenced inline in schemas stay in sync with the
#      corresponding policy YAML files (the documented editing source).
#
# Per docs/spikes/CC-229-substrate-synthesis.md §E Q1: JSON Schema is the
# ajv-compliant source-of-truth; policy YAML is the human editing surface.
# This test enforces the sync that comment-level documentation requests.
#
# Runs via: scripts/test-core-schemas.sh
# Filter:   scripts/test-core-schemas.sh --filter <pattern>
# List:     scripts/test-core-schemas.sh --list

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/test-harness.sh
. "$REPO_ROOT/scripts/lib/test-harness.sh"
th_init "$@"

CORE_DIR="$REPO_ROOT/core"

# ---------- helpers ----------

_yaml_get() {
  # Extract a value from a YAML file by dotted key path.
  # If value is a list: print each element on its own line.
  # If value is a dict: print each key on its own line.
  # If value is a scalar: print it.
  local file="$1" key="$2"
  python3 -c "
import sys, yaml
with open('$file') as f:
    data = yaml.safe_load(f)
keys = '$key'.split('.')
for k in keys:
    if data is None:
        sys.exit(1)
    data = data.get(k) if isinstance(data, dict) else None
if data is None:
    sys.exit(1)
if isinstance(data, list):
    for item in data:
        print(item)
elif isinstance(data, dict):
    for k in data.keys():
        print(k)
else:
    print(data)
"
}

_schema_enum() {
  # Extract enum array from a JSON Schema given a jq path to the enum node.
  local file="$1" path="$2"
  jq -r "$path | .[]" "$file" 2>/dev/null || true
}

# ---------- tests ----------

case_schema_parse() {
  local name="JSON Schema: $1 parses as valid JSON"
  should_run "$name" || return 0
  if jq -e . "$1" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "jq parse failed"
  fi
}

case_yaml_parse() {
  local name="YAML: $1 parses as valid YAML"
  should_run "$name" || return 0
  if python3 -c "import yaml; yaml.safe_load(open('$1'))" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "yaml.safe_load failed"
  fi
}

case_schema_version_const() {
  local file="$1"
  local name="schema_version: $file declares const: 1"
  should_run "$name" || return 0
  local val
  val=$(jq -r '.properties.schema_version.const // empty' "$file")
  if [[ "$val" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "expected const: 1, got '$val'"
  fi
}

case_enum_sync() {
  # Compare an inline schema enum against the policy YAML it documents.
  # args: <schema_file> <jq path to enum> <yaml_file> <yaml key>
  local schema_file="$1" jq_path="$2" yaml_file="$3" yaml_key="$4"
  local name
  name="enum-sync: $(basename "$schema_file") $jq_path == $(basename "$yaml_file") #/$yaml_key"
  should_run "$name" || return 0

  local schema_vals yaml_vals
  schema_vals=$(_schema_enum "$schema_file" "$jq_path" | sort)
  yaml_vals=$(_yaml_get "$yaml_file" "$yaml_key" | sort)

  if [[ "$schema_vals" == "$yaml_vals" ]]; then
    pass "$name"
  else
    local detail
    detail="schema enum: $(echo "$schema_vals" | tr '\n' ',' | sed 's/,$//'); yaml values: $(echo "$yaml_vals" | tr '\n' ',' | sed 's/,$//')"
    fail "$name" "$detail"
  fi
}

# ---------- run ----------

# 1. JSON Schema parse
for f in "$CORE_DIR"/schema/*.schema.json; do
  case_schema_parse "$f"
done

# 2. YAML parse
for f in "$CORE_DIR"/policy/*.yaml "$CORE_DIR"/state/layout.yaml; do
  case_yaml_parse "$f"
done

# 3. schema_version: const 1 on every payload schema that declares it
for f in "$CORE_DIR"/schema/*.schema.json; do
  # Skip schemas that intentionally omit schema_version (none in M1)
  if jq -e '.properties.schema_version' "$f" >/dev/null 2>&1; then
    case_schema_version_const "$f"
  fi
done

# 4. Enum-sync: schema inline enums vs policy YAML source-of-truth
# Format: case_enum_sync <schema> <jq_path> <yaml> <yaml_key>

# executor enum (used by run + handover)
case_enum_sync "$CORE_DIR/schema/run.schema.json" \
  '.properties.executor.enum' \
  "$CORE_DIR/policy/executor-enum.yaml" \
  "values"

case_enum_sync "$CORE_DIR/schema/handover.schema.json" \
  '.properties.executor.enum' \
  "$CORE_DIR/policy/executor-enum.yaml" \
  "values"

# dispatch_route enum
case_enum_sync "$CORE_DIR/schema/run.schema.json" \
  '.properties.dispatch_route.enum' \
  "$CORE_DIR/policy/dispatch-routes.yaml" \
  "values"

case_enum_sync "$CORE_DIR/schema/handover.schema.json" \
  '.properties.dispatch_route.enum' \
  "$CORE_DIR/policy/dispatch-routes.yaml" \
  "values"

# task-states
case_enum_sync "$CORE_DIR/schema/task.schema.json" \
  '.properties.state.enum' \
  "$CORE_DIR/policy/task-states.yaml" \
  "states"

# run-states
case_enum_sync "$CORE_DIR/schema/run.schema.json" \
  '.properties.state.enum' \
  "$CORE_DIR/policy/run-states.yaml" \
  "states"

# reviewer + verdict (in review.schema.json findings[])
case_enum_sync "$CORE_DIR/schema/review.schema.json" \
  '.properties.findings.items.properties.reviewer.enum' \
  "$CORE_DIR/policy/reviewer-policy.yaml" \
  "reviewers"

# verdicts are reviewer-policy.yaml's verdicts list
case_enum_sync "$CORE_DIR/schema/review.schema.json" \
  '.properties.findings.items.properties.verdict.enum' \
  "$CORE_DIR/policy/reviewer-policy.yaml" \
  "verdicts"

# 5. brief.schema.json structural contract tests
# These tests verify the schema document itself has the right constraints,
# so removals of additionalProperties/required/pattern are caught immediately.

case_brief_required_fields_declared() {
  local name="brief.schema.json: required fields declared"
  should_run "$name" || return 0
  local required
  required=$(jq -r '.required[]' "$BRIEF_SCHEMA" 2>/dev/null | sort | tr '\n' ',')
  if [[ "$required" == *"acceptance"* && "$required" == *"files"* && \
        "$required" == *"goal"* && "$required" == *"schema_version"* && \
        "$required" == *"working_dir"* ]]; then
    pass "$name"
  else
    fail "$name" "required: $required"
  fi
}

case_brief_additional_properties_false() {
  local name="brief.schema.json: additionalProperties is false"
  should_run "$name" || return 0
  local val
  val=$(jq -r '.additionalProperties' "$BRIEF_SCHEMA")
  if [[ "$val" == "false" ]]; then
    pass "$name"
  else
    fail "$name" "additionalProperties=$val"
  fi
}

case_brief_working_dir_has_pattern() {
  local name="brief.schema.json: working_dir has pattern constraint"
  should_run "$name" || return 0
  local pat
  pat=$(jq -r '.properties.working_dir.pattern // empty' "$BRIEF_SCHEMA")
  if [[ -n "$pat" ]]; then
    pass "$name"
  else
    fail "$name" "no pattern on working_dir"
  fi
}

case_brief_files_oneOf_has_four_variants() {
  local name="brief.schema.json: files.items.oneOf has 4 variants"
  should_run "$name" || return 0
  local count
  count=$(jq '.properties.files.items.oneOf | length' "$BRIEF_SCHEMA")
  if [[ "$count" -eq 4 ]]; then
    pass "$name"
  else
    fail "$name" "expected 4 oneOf variants, got $count"
  fi
}

case_brief_files_oneOf_all_have_additional_properties_false() {
  local name="brief.schema.json: all files oneOf variants have additionalProperties:false"
  should_run "$name" || return 0
  local count_without
  count_without=$(jq '[.properties.files.items.oneOf[] | select(.additionalProperties != false)] | length' "$BRIEF_SCHEMA")
  if [[ "$count_without" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "$count_without variants missing additionalProperties:false"
  fi
}

case_brief_sha_field_has_pattern() {
  local name="brief.schema.json: expected_head_sha has sha40 pattern"
  should_run "$name" || return 0
  local pat
  pat=$(jq -r '.properties.expected_head_sha.pattern // empty' "$BRIEF_SCHEMA")
  if [[ "$pat" == *"[a-f0-9]"* ]]; then
    pass "$name"
  else
    fail "$name" "no sha40 pattern on expected_head_sha"
  fi
}

# 5. brief.schema.json structural contract tests
BRIEF_SCHEMA="$CORE_DIR/schema/brief.schema.json"
case_brief_required_fields_declared
case_brief_additional_properties_false
case_brief_working_dir_has_pattern
case_brief_files_oneOf_has_four_variants
case_brief_files_oneOf_all_have_additional_properties_false
case_brief_sha_field_has_pattern

th_summary
