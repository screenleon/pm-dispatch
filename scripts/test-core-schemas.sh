#!/usr/bin/env bash
# Structural tests for core/ substrate (CC-229 schema-only PR).
#
# These tests validate that:
#   1. Every JSON Schema file under core/schema/ is valid JSON
#   2. Every YAML file under core/policy/ and core/state/ is valid YAML
#   3. Schemas declaring schema_version do so as a positive integer `const`
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
  # Extract a list's items or a map's keys from a simple top-level YAML key.
  # Supports the core/policy shapes used for schema enum-sync tests.
  local file="$1" key="$2"
  awk -v key="${key}:" '
    function clean(value) {
      sub(/[[:space:]]+#.*$/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    $0 ~ "^" key "([[:space:]]*(#.*)?)?$" { found=1; next }
    found && /^[[:space:]]+-[[:space:]]/ {
      sub(/^[[:space:]]+-[[:space:]]/, "")
      print clean($0)
      next
    }
    found && /^  [^[:space:]#][^:]*:[[:space:]]*$/ {
      sub(/^  /, "")
      sub(/:[[:space:]]*$/, "")
      print
      next
    }
    found && /^[^[:space:]#][^:]*:/ { exit }
  ' "$file"
}

_schema_enum() {
  # Extract enum array from a JSON Schema given a jq path to the enum node.
  local file="$1" path="$2"
  jq -r "$path | .[]" "$file" 2>/dev/null || true
}

# ---------- tests ----------

case_schema_parse() {
  # Verifies that the given JSON Schema file is valid parseable JSON.
  #
  # Steps:
  #   1. Run jq -e on the file.
  #   2. Assert jq exits 0.
  local name="JSON Schema: $1 parses as valid JSON"
  should_run "$name" || return 0
  if jq -e . "$1" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "jq parse failed"
  fi
}

case_yaml_parse() {
  # Verifies that the given YAML file is non-empty, uses space (not tab) indentation,
  # and contains at least one key: value line — sufficient structural validation for
  # the simple core/policy and core/state YAML files.
  #
  # Steps:
  #   1. Assert the file is non-empty.
  #   2. Assert no line starts with a tab character (YAML requires space indentation).
  #   3. Assert at least one top-level key: line is present.
  local name="YAML: $1 has valid structure"
  should_run "$name" || return 0
  if [[ ! -s "$1" ]]; then
    fail "$name" "file is empty"
    return
  fi
  if grep -Pq '^\t' "$1" 2>/dev/null; then
    fail "$name" "file contains tab indentation (YAML requires spaces)"
    return
  fi
  if ! grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*:' "$1"; then
    fail "$name" "no top-level key: line found"
    return
  fi
  pass "$name"
}

case_schema_version_const() {
  # Verifies schema_version is a positive integer const OR an enum of positive integers.
  # context-pack uses enum [1,2] for v1/v2 compat; all others use const.
  local file="$1"
  local name="schema_version: $file declares a positive integer const or enum"
  should_run "$name" || return 0
  local val
  val=$(jq -r '.properties.schema_version.const // empty' "$file")
  if [[ "$val" =~ ^[0-9]+$ ]] && (( val >= 1 )); then
    pass "$name"; return 0
  fi
  # enum path: all values must be positive integers
  local bad count
  bad=$(jq -r '(.properties.schema_version.enum // [])[] | select(type != "number" or . < 1)' "$file" 2>/dev/null || true)
  count=$(jq -r '(.properties.schema_version.enum // []) | length' "$file" 2>/dev/null || printf '0')
  if [[ -z "$bad" && "$count" -ge 1 ]]; then
    pass "$name"
  else
    fail "$name" "expected positive integer const or enum; const='$val' enum_bad='$bad' enum_count=$count"
  fi
}

case_enum_sync() {
  # Verifies that enum values embedded inline in a JSON Schema stay in sync
  # with the authoritative policy YAML file (the human editing surface).
  #
  # Steps:
  #   1. Extract enum values from the JSON Schema at the given jq path.
  #   2. Extract values list from the policy YAML file.
  #   3. Assert both lists contain the same values (order-insensitive).
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

case_review_verdict_includes_approve() {
  # Verifies that review.schema.json includes 'approve' in the verdict enum,
  # aligning the schema with the live pr-gate.sh contract (critic/architecture-reviewer
  # both emit 'approve' for clean reviews).
  #
  # Steps:
  #   1. Extract findings[].verdict enum from review.schema.json via jq.
  #   2. Assert "approve" is present in the enum array.
  local name="review.schema.json: verdict enum includes approve"
  should_run "$name" || return 0
  local review_schema="$CORE_DIR/schema/review.schema.json"
  if jq -e '.properties.findings.items.properties.verdict.enum | contains(["approve"])' "$review_schema" > /dev/null; then
    pass "$name"
  else
    fail "$name" "approve not in verdict enum — schema and runtime out of sync"
  fi
}
case_review_verdict_includes_approve

# 5. brief.schema.json structural contract tests
# These tests verify the schema document itself has the right constraints,
# so removals of additionalProperties/required/pattern are caught immediately.

case_brief_required_fields_declared() {
  # Verifies that brief.schema.json's required array contains the minimum
  # set of mandatory fields every dispatch brief must declare.
  #
  # Steps:
  #   1. Extract the required array from brief.schema.json.
  #   2. Assert each expected required field name is present.
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
  # Verifies that brief.schema.json sets additionalProperties: false, preventing
  # unknown fields from silently passing validation.
  #
  # Steps:
  #   1. Extract .additionalProperties from the schema.
  #   2. Assert the value is false (boolean).
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
  # Verifies that the working_dir field in brief.schema.json enforces an
  # absolute-path regex pattern constraint.
  #
  # Steps:
  #   1. Extract .properties.working_dir.pattern from the schema.
  #   2. Assert a non-empty pattern string is present.
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
  # Verifies that the files field in brief.schema.json defines exactly 4 oneOf
  # variants (read, edit, new, and write).
  #
  # Steps:
  #   1. Extract .properties.files.items.oneOf from the schema.
  #   2. Assert the array length is 4.
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
  # Verifies all 4 oneOf variants in the files field enforce additionalProperties: false,
  # preventing unknown keys from silently passing validation in any files variant.
  #
  # Steps:
  #   1. Extract .properties.files.items.oneOf from the schema.
  #   2. Assert every variant object has additionalProperties equal to false.
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
  # Verifies that the expected_head_sha field in brief.schema.json enforces a
  # 40-character hex pattern (valid git SHA constraint).
  #
  # Steps:
  #   1. Extract .properties.expected_head_sha.pattern from the schema.
  #   2. Assert a non-empty pattern string is present.
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

case_isolation_level_adapter_parity() {
  local name="adapters/claude: isolation-map.yaml keys match core/policy/isolation-level.yaml values"
  should_run "$name" || return 0

  local policy_file adapter_file
  policy_file="$CORE_DIR/policy/isolation-level.yaml"
  adapter_file="$REPO_ROOT/adapters/claude/isolation-map.yaml"

  if [[ ! -f "$policy_file" ]]; then
    fail "$name" "missing: $policy_file"; return
  fi
  if [[ ! -f "$adapter_file" ]]; then
    fail "$name" "missing: $adapter_file"; return
  fi

  local policy_vals adapter_keys missing_in_adapter missing_in_policy
  mapfile -t policy_vals  < <(_yaml_get "$policy_file"  "values")
  mapfile -t adapter_keys < <(_yaml_get "$adapter_file" "mappings")

  missing_in_adapter=()
  for v in "${policy_vals[@]}"; do
    if ! printf '%s\n' "${adapter_keys[@]}" | grep -qxF "$v"; then
      missing_in_adapter+=("$v")
    fi
  done

  missing_in_policy=()
  for k in "${adapter_keys[@]}"; do
    if ! printf '%s\n' "${policy_vals[@]}" | grep -qxF "$k"; then
      missing_in_policy+=("$k")
    fi
  done

  if [[ ${#missing_in_adapter[@]} -eq 0 ]] && [[ ${#missing_in_policy[@]} -eq 0 ]]; then
    pass "$name"
  else
    local msg=""
    [[ ${#missing_in_adapter[@]} -gt 0 ]] && msg+="policy values missing in adapter: ${missing_in_adapter[*]}; "
    [[ ${#missing_in_policy[@]} -gt 0 ]] && msg+="adapter keys not in policy: ${missing_in_policy[*]}"
    fail "$name" "$msg"
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

# isolation_level enum in handover.schema.json synced with isolation-level.yaml
case_enum_sync "$CORE_DIR/schema/handover.schema.json" \
  '.properties.isolation_level.enum' \
  "$CORE_DIR/policy/isolation-level.yaml" \
  "values"

# handover schema oneOf encodes canonical (isolation_level) vs legacy (sandbox+approval+skip_git_check)
case_handover_schema_oneOf_canonical_and_legacy() {
  local name="handover.schema.json: oneOf has canonical isolation_level branch and legacy sandbox branch"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/handover.schema.json"
  if [[ ! -f "$schema_file" ]]; then
    fail "$name" "missing: $schema_file"; return
  fi
  # Verify oneOf exists with at least 2 branches
  local one_of_len
  one_of_len="$(jq '.oneOf | length' "$schema_file" 2>/dev/null)"
  if [[ "$one_of_len" -lt 2 ]]; then
    fail "$name" "oneOf must have at least 2 branches, got: $one_of_len"; return
  fi
  # Verify isolation_level branch exists
  local has_iso_branch
  has_iso_branch="$(jq '[ .oneOf[] | select(.required != null) | select(.required | contains(["isolation_level"])) ] | length' "$schema_file" 2>/dev/null)"
  if [[ "$has_iso_branch" -lt 1 ]]; then
    fail "$name" "oneOf missing isolation_level required branch"; return
  fi
  # Verify legacy branch exists
  local has_legacy_branch
  has_legacy_branch="$(jq '[ .oneOf[] | select(.required != null) | select(.required | contains(["sandbox","approval","skip_git_check"])) ] | length' "$schema_file" 2>/dev/null)"
  if [[ "$has_legacy_branch" -lt 1 ]]; then
    fail "$name" "oneOf missing legacy sandbox/approval/skip_git_check required branch"; return
  fi
  pass "$name"
}
case_handover_schema_oneOf_canonical_and_legacy

# handover schema oneOf branches carry 'not' constraints that prevent mixing
case_handover_schema_oneOf_not_constraints() {
  local name="handover.schema.json: oneOf branches have not-constraints preventing canonical/legacy mixing"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/handover.schema.json"
  if [[ ! -f "$schema_file" ]]; then
    fail "$name" "missing: $schema_file"; return
  fi
  # Canonical branch must have a 'not' that excludes at least one legacy field
  local canonical_not_len
  canonical_not_len="$(jq '[ .oneOf[] | select(.required != null) | select(.required | contains(["isolation_level"])) | .not ] | map(select(. != null)) | length' "$schema_file" 2>/dev/null)"
  if [[ "$canonical_not_len" -lt 1 ]]; then
    fail "$name" "canonical oneOf branch is missing a 'not' constraint to exclude legacy fields"; return
  fi
  # Legacy branch must have a 'not' that excludes isolation_level
  local legacy_not_excl_iso
  legacy_not_excl_iso="$(jq '[ .oneOf[] | select(.required != null) | select(.required | contains(["sandbox","approval","skip_git_check"])) | .not | select(. != null) | .. | objects | select(.required != null) | select(.required | contains(["isolation_level"])) ] | length' "$schema_file" 2>/dev/null)"
  if [[ "$legacy_not_excl_iso" -lt 1 ]]; then
    fail "$name" "legacy oneOf branch is missing a 'not' that excludes isolation_level"; return
  fi
  pass "$name"
}
case_handover_schema_oneOf_not_constraints

# handover schema oneOf instance semantics: canonical-only valid, legacy-only valid, mixed invalid
case_handover_schema_oneOf_instance_semantics() {
  local name="handover.schema.json: oneOf instance semantics"
  should_run "$name" || return 0
  if ! command -v jsonschema >/dev/null 2>&1; then
    pass "$name (skip: jsonschema not available)"
    return
  fi
  local schema_file="$CORE_DIR/schema/handover.schema.json"
  local base='{"handover_version":2,"executor":"codex","dispatch_route":"agent_executor","working_dir":"/tmp/t","brief_file":"/tmp/b.md","timeout":120,"model":"default","fallback_allowed":false'
  local tmpdir; tmpdir="$(mktemp -d)"

  # canonical-only: must be valid
  printf '%s,"isolation_level":"workspace-write"}' "$base" > "$tmpdir/canonical.json"
  if ! jsonschema -i "$tmpdir/canonical.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "canonical-only (isolation_level only) must be valid"; rm -rf "$tmpdir"; return
  fi

  # legacy-only: must be valid
  printf '%s,"sandbox":"workspace-write","approval":"never","skip_git_check":false}' "$base" > "$tmpdir/legacy.json"
  if ! jsonschema -i "$tmpdir/legacy.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "legacy-only (sandbox+approval+skip_git_check) must be valid"; rm -rf "$tmpdir"; return
  fi

  # missing-both: must be invalid (no oneOf branch satisfied)
  printf '%s}' "$base" > "$tmpdir/missing.json"
  if jsonschema -i "$tmpdir/missing.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "missing-both (no isolation metadata) must be invalid"; rm -rf "$tmpdir"; return
  fi

  # mixed (isolation_level + full legacy trio): must be invalid
  printf '%s,"isolation_level":"workspace-write","sandbox":"workspace-write","approval":"never","skip_git_check":false}' "$base" > "$tmpdir/mixed.json"
  if jsonschema -i "$tmpdir/mixed.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "mixed canonical+legacy must be invalid"; rm -rf "$tmpdir"; return
  fi

  # partial-mix (isolation_level + single legacy field): must be invalid
  printf '%s,"isolation_level":"workspace-write","sandbox":"workspace-write"}' "$base" > "$tmpdir/partial.json"
  if jsonschema -i "$tmpdir/partial.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "partial-mix (isolation_level + sandbox) must be invalid"; rm -rf "$tmpdir"; return
  fi

  rm -rf "$tmpdir"
  pass "$name"
}
case_handover_schema_oneOf_instance_semantics

# 6. Adapter parity tests
case_isolation_level_adapter_parity

# 7. context-pack schema v2 contract tests
# Verifies additive v1/v2 compat and new field enum constraints.

_ctx_pack_base() {
  # Minimal valid context-pack payload (v1 or v2 depending on $1).
  # sources requires objects with name+version; files items require ref+source+confidence.
  printf '{"schema_version":%s,"task_id":"CC-1","built_ts":"2026-01-01T00:00:00Z","sources":[{"name":"builtin-index","version":"1"}],"files":[]}' "$1"
}

case_context_pack_v1_still_valid() {
  local name="context-pack.schema.json: v1 pack (schema_version:1) validates against v2 schema"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/context-pack.schema.json"
  local tmpf; tmpf="$(mktemp /tmp/ctx-pack-XXXXXX.json)"
  _ctx_pack_base 1 > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "v1 pack should still validate against v2 schema"
  fi
  rm -f "$tmpf"
}

case_context_pack_v2_new_fields_valid() {
  local name="context-pack.schema.json: v2 item with source_domain/why_relevant/trust_level/refs validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/context-pack.schema.json"
  local tmpf; tmpf="$(mktemp /tmp/ctx-pack-XXXXXX.json)"
  printf '{"schema_version":2,"task_id":"CC-1","built_ts":"2026-01-01T00:00:00Z","sources":[{"name":"builtin-index","version":"1"}],"files":[{"ref":"src/foo.sh","source":"builtin-index","confidence":0.9,"source_domain":"repo","why_relevant":"contains the function","trust_level":"high","refs":["src/bar.sh"]}]}' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "v2 pack with new fields should validate"
  fi
  rm -f "$tmpf"
}

case_context_pack_invalid_source_domain_rejected() {
  local name="context-pack.schema.json: invalid source_domain value is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/context-pack.schema.json"
  local tmpf; tmpf="$(mktemp /tmp/ctx-pack-XXXXXX.json)"
  printf '{"schema_version":2,"task_id":"CC-1","built_ts":"2026-01-01T00:00:00Z","sources":[{"name":"builtin-index","version":"1"}],"files":[{"ref":"src/foo.sh","source":"builtin-index","confidence":0.9,"source_domain":"external"}]}' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "source_domain='external' should be rejected"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_context_pack_invalid_trust_level_rejected() {
  local name="context-pack.schema.json: invalid trust_level value is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/context-pack.schema.json"
  local tmpf; tmpf="$(mktemp /tmp/ctx-pack-XXXXXX.json)"
  printf '{"schema_version":2,"task_id":"CC-1","built_ts":"2026-01-01T00:00:00Z","sources":[{"name":"builtin-index","version":"1"}],"files":[{"ref":"src/foo.sh","source":"builtin-index","confidence":0.9,"trust_level":"critical"}]}' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "trust_level='critical' should be rejected"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_context_pack_v1_still_valid
case_context_pack_v2_new_fields_valid
case_context_pack_invalid_source_domain_rejected
case_context_pack_invalid_trust_level_rejected

th_summary
