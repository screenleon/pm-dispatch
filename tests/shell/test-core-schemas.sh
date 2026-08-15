#!/usr/bin/env bash
# Structural tests for core/ substrate (CC-229 schema-only PR).
#
# These tests validate that:
#   1. Every JSON Schema file under core/schema/ is valid JSON
#   2. Every YAML/TSV file under core/policy/ and core/state/ has valid structure
#   3. Schemas declaring schema_version do so as a positive integer `const`
#   4. Enum values referenced inline in schemas stay in sync with the
#      corresponding declarative policy files (the documented editing source).
#
# Per docs/spikes/CC-229-substrate-synthesis.md §E Q1: JSON Schema is the
# ajv-compliant source-of-truth; policy YAML/TSV is the human editing surface.
# This test enforces the sync that comment-level documentation requests.
#
# Runs via: tests/shell/test-core-schemas.sh
# Filter:   tests/shell/test-core-schemas.sh --filter <pattern>
# List:     tests/shell/test-core-schemas.sh --list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

CORE_DIR="$REPO_ROOT/core"
# shellcheck source=runtime/lib/gate-structural-verify.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/gate-structural-verify.sh"
# shellcheck source=runtime/lib/gate-closure.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/gate-closure.sh"

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
  ' "$file" | tr -d '\r'
}

_schema_enum() {
  # Extract enum array from a JSON Schema given a jq path to the enum node.
  local file="$1" path="$2"
  jq -r "$path | .[]" "$file" 2>/dev/null || true
}

_tsv_column() {
  # Extract a named column from a headered TSV, excluding comments/blank lines.
  local file="$1" column="$2"
  awk -F '\t' -v wanted="$column" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    !header_seen {
      header_seen=1
      width=NF
      for (i=1; i<=NF; i++) {
        sub(/\r$/, "", $i)
        if ($i == wanted) column_index=i
      }
      if (!column_index) exit 2
      next
    }
    {
      sub(/\r$/, "", $NF)
      if (NF != width || $(column_index) == "") exit 2
      print $(column_index)
    }
  ' "$file"
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

case_tsv_parse() {
  # Verifies that a policy TSV has a header, at least one row, consistent
  # tab-separated width, and no empty cells.
  local file="$1"
  local name="TSV: $file has valid structure"
  should_run "$name" || return 0
  if awk -F '\t' '
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      !header_seen {
        header_seen=1
        width=NF
        for (i=1; i<=NF; i++) if ($i == "") exit 2
        next
      }
      {
        rows++
        if (NF != width) exit 2
        for (i=1; i<=NF; i++) if ($i == "") exit 2
      }
      END {
        if (!header_seen || width < 2 || rows < 1) exit 2
      }
    ' "$file"; then
    pass "$name"
  else
    fail "$name" "invalid header or row structure"
  fi
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

case_review_tier_policy_compatibility() {
  # Verify current Review tiers match the canonical TSV while schema_version 1
  # retains only `targeted` as its documented legacy compatibility value.
  local schema_file="$CORE_DIR/schema/review.schema.json"
  local tsv_file="$CORE_DIR/policy/gate-tiers.tsv"
  local name="enum-sync: review tiers == gate-tiers.tsv plus legacy targeted"
  should_run "$name" || return 0

  local current_schema_vals tsv_vals legacy_count
  current_schema_vals=$(_schema_enum "$schema_file" '.properties.tier.enum' \
    | grep -vx 'targeted' | sort)
  tsv_vals=$(_tsv_column "$tsv_file" "tier" | sort)
  legacy_count=$(_schema_enum "$schema_file" '.properties.tier.enum' \
    | grep -cx 'targeted' || true)

  if [[ "$current_schema_vals" == "$tsv_vals" && "$legacy_count" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "current tiers differ from TSV or legacy targeted is not unique"
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

# 2b. TSV parse
for f in "$CORE_DIR"/policy/*.tsv; do
  case_tsv_parse "$f"
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

case_enum_sync "$CORE_DIR/schema/gate-reviewer-result.schema.json" \
  '.properties.reviewer.enum' \
  "$CORE_DIR/policy/reviewer-policy.yaml" \
  "reviewers"

case_enum_sync "$CORE_DIR/schema/gate-synthesis-result.schema.json" \
  '.definitions.reviewer.enum' \
  "$CORE_DIR/policy/reviewer-policy.yaml" \
  "reviewers"

# verdicts are reviewer-policy.yaml's verdicts list
case_enum_sync "$CORE_DIR/schema/review.schema.json" \
  '.properties.findings.items.properties.verdict.enum' \
  "$CORE_DIR/policy/reviewer-policy.yaml" \
  "verdicts"

# Gate rigor tiers: new producers use the TSV; Review schema v1 still accepts
# its historical targeted value so old state remains structurally valid.
case_review_tier_policy_compatibility

case_enum_sync_crlf_input() {
  # A YAML file checked out with CRLF endings (Windows core.autocrlf re-applying
  # despite .gitattributes, or a non-git copy) must not produce a false enum-sync
  # mismatch: _yaml_get pipes its awk output through `tr -d '\r'` so extracted
  # values are CR-free for both the list and map-key branches.
  #
  # NOTE on mutation-resistance: GNU awk's [[:space:]] already strips a trailing
  # CR inside _yaml_get's existing subs, so on a gawk host the tr stage is
  # belt-and-suspenders and removing it would not change this result. The bug this
  # fix targets occurs on awks whose [[:space:]] does not cover CR (some Windows
  # MSYS/busybox builds); there this assertion fails without the tr stage. The
  # check still guards the CR-free extraction contract on every platform.
  #
  # Steps:
  #   1. Write a YAML fixture with CRLF line endings for a list and a map.
  #   2. Extract both via _yaml_get.
  #   3. Assert the values equal their LF form and contain no CR byte.
  local name="enum-sync: CRLF YAML extracts CR-free values"
  should_run "$name" || return 0
  local tmp_yaml list_vals map_vals
  tmp_yaml="$(mktemp)"
  printf 'executors:\r\n  - claude\r\n  - codex\r\nstates:\r\n  pending:\r\n  done:\r\n' > "$tmp_yaml"
  list_vals="$(_yaml_get "$tmp_yaml" "executors")"
  map_vals="$(_yaml_get "$tmp_yaml" "states")"
  rm -f "$tmp_yaml"
  if [[ "$list_vals" == "$(printf 'claude\ncodex')" \
        && "$map_vals" == "$(printf 'pending\ndone')" \
        && "$list_vals" != *$'\r'* \
        && "$map_vals" != *$'\r'* ]]; then
    pass "$name"
  else
    fail "$name" "list=[$(printf '%s' "$list_vals" | cat -v)] map=[$(printf '%s' "$map_vals" | cat -v)]"
  fi
}
case_enum_sync_crlf_input

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

# handover schema requires isolation_level and no longer declares the legacy trio
# (removed in v0.6.0). additionalProperties:false rejects any carried legacy field.
case_handover_schema_requires_isolation_level() {
  local name="handover.schema.json: isolation_level required, legacy trio removed"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/handover.schema.json"
  if [[ ! -f "$schema_file" ]]; then
    fail "$name" "missing: $schema_file"; return
  fi
  # isolation_level must be in the top-level required array
  local iso_required
  iso_required="$(jq '[ .required[] | select(. == "isolation_level") ] | length' "$schema_file" 2>/dev/null)"
  if [[ "$iso_required" -lt 1 ]]; then
    fail "$name" "isolation_level must be in the required array"; return
  fi
  # No oneOf legacy/canonical split remains
  local has_one_of
  has_one_of="$(jq 'has("oneOf")' "$schema_file" 2>/dev/null)"
  if [[ "$has_one_of" != "false" ]]; then
    fail "$name" "oneOf must be removed (isolation_level is now unconditionally required)"; return
  fi
  # The legacy trio properties must be gone, and additionalProperties must be false
  # so a brief carrying them is rejected.
  local legacy_props add_props
  legacy_props="$(jq '[ .properties | keys[] | select(. == "sandbox" or . == "approval" or . == "skip_git_check") ] | length' "$schema_file" 2>/dev/null)"
  add_props="$(jq '.additionalProperties' "$schema_file" 2>/dev/null)"
  if [[ "$legacy_props" -ne 0 ]]; then
    fail "$name" "legacy sandbox/approval/skip_git_check properties must be removed, found: $legacy_props"; return
  fi
  if [[ "$add_props" != "false" ]]; then
    fail "$name" "additionalProperties must be false so legacy fields are rejected"; return
  fi
  pass "$name"
}
case_handover_schema_requires_isolation_level

# handover schema instance semantics: isolation_level required; legacy trio rejected.
case_handover_schema_instance_semantics() {
  local name="handover.schema.json: instance semantics (isolation_level required, legacy rejected)"
  should_run "$name" || return 0
  if ! command -v jsonschema >/dev/null 2>&1; then
    pass "$name (skip: jsonschema not available)"
    return
  fi
  local schema_file="$CORE_DIR/schema/handover.schema.json"
  local base='{"handover_version":4,"executor":"codex","dispatch_route":"agent_executor","working_dir":"/tmp/t","brief_file":"/tmp/b.md","timeout":120,"model":"default","fallback_allowed":false'
  local tmpdir; tmpdir="$(mktemp -d)"

  # canonical (isolation_level only): must be valid
  printf '%s,"isolation_level":"workspace-write"}' "$base" > "$tmpdir/canonical.json"
  if ! jsonschema -i "$tmpdir/canonical.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "canonical (isolation_level only) must be valid"; rm -rf "$tmpdir"; return
  fi

  # legacy-only: must now be INVALID (additionalProperties:false + missing isolation_level)
  printf '%s,"sandbox":"workspace-write","approval":"never","skip_git_check":false}' "$base" > "$tmpdir/legacy.json"
  if jsonschema -i "$tmpdir/legacy.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "legacy-only (sandbox+approval+skip_git_check) must be invalid"; rm -rf "$tmpdir"; return
  fi

  # missing isolation_level: must be invalid
  printf '%s}' "$base" > "$tmpdir/missing.json"
  if jsonschema -i "$tmpdir/missing.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "missing isolation_level must be invalid"; rm -rf "$tmpdir"; return
  fi

  # isolation_level + a carried legacy field: must be invalid (additionalProperties:false)
  printf '%s,"isolation_level":"workspace-write","sandbox":"workspace-write"}' "$base" > "$tmpdir/carried.json"
  if jsonschema -i "$tmpdir/carried.json" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "isolation_level + carried legacy field must be invalid"; rm -rf "$tmpdir"; return
  fi

  rm -rf "$tmpdir"
  pass "$name"
}
case_handover_schema_instance_semantics

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

case_context_pack_memory_source_domain_valid() {
  local name="context-pack.schema.json: memories[] item with source_domain memory validates (CC-403)"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/context-pack.schema.json"
  local tmpf; tmpf="$(mktemp /tmp/ctx-pack-XXXXXX.json)"
  printf '{"schema_version":2,"task_id":"CC-403","built_ts":"2026-01-01T00:00:00Z","sources":[{"name":"builtin-index","version":"1"}],"files":[],"memories":[{"ref":"feedback_gate_executor.md:1","source":"builtin-index","confidence":0.75,"source_domain":"memory","why_relevant":"memory match","trust_level":"high"}]}' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "source_domain='memory' in memories[] should validate"
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

case_preflight_basic_evidence_needs_no_git_provenance() {
  # Verifies the portable basic-result contract stays usable by an ordinary
  # command producer with no repository, base, head, or planner metadata.
  # Steps:
  #   1. Build a complete opaque/advisory instance with an unbound subject.
  #   2. Omit provenance entirely.
  #   3. Assert the JSON Schema accepts the instance.
  local name="preflight-evidence: basic opaque result needs no Git provenance"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/preflight-evidence.schema.json" tmpf
  tmpf="$(mktemp /tmp/preflight-basic-XXXXXX.json)"
  jq -n '{kind:"pr_gate_preflight_v1",schema_version:1,
    command_identity:("sha256:" + ("a" * 64)),status:"pass",exit_status:0,
    outcome:{execution:"pass",test_verdict:"pass",evidence_richness:"opaque",authorization:"eligible"},timeout_seconds:60,
    started_at:"2026-01-01T00:00:00Z",finished_at:"2026-01-01T00:00:01Z",
    subject:{kind:"unbound",reusable:false},
    log:{path:"/tmp/test.log",sha256:("b" * 64)},
    coverage:{type:"opaque",reuse_policy:"advisory"}}' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a basic result without Git provenance"
  fi
  rm -f "$tmpf"
}

case_preflight_reusable_evidence_requires_fingerprint() {
  # Verifies reusable evidence cannot claim freshness without identifying the
  # tested subject, while basic unbound evidence remains a separate valid form.
  # Steps:
  #   1. Build an otherwise complete result with reusable:true.
  #   2. Omit both subject fingerprints.
  #   3. Assert the JSON Schema rejects the instance.
  local name="preflight-evidence: reusable result requires subject fingerprints"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/preflight-evidence.schema.json" tmpf
  tmpf="$(mktemp /tmp/preflight-reusable-XXXXXX.json)"
  jq -n '{kind:"pr_gate_preflight_v1",schema_version:1,
    command_identity:("sha256:" + ("a" * 64)),status:"pass",exit_status:0,
    outcome:{execution:"pass",test_verdict:"pass",evidence_richness:"opaque",authorization:"eligible"},timeout_seconds:60,
    started_at:"2026-01-01T00:00:00Z",finished_at:"2026-01-01T00:00:01Z",
    subject:{kind:"workspace",reusable:true},
    log:{path:"/tmp/test.log",sha256:("b" * 64)},
    coverage:{type:"opaque",reuse_policy:"advisory"}}' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted reusable evidence without fingerprints"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_preflight_legacy_status_without_outcome_accepted() {
  # Verifies a pre-CC-522 legacy artifact (status pass/fail, no `outcome`
  # field at all) remains schema-valid for backward compatibility with
  # evidence recorded by an older producer.
  local name="preflight-evidence: legacy pass/fail status without outcome is accepted"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/preflight-evidence.schema.json" tmpf status
  for status in pass fail; do
    tmpf="$(mktemp /tmp/preflight-legacy-XXXXXX.json)"
    jq -n --arg status "$status" '{kind:"pr_gate_preflight_v1",schema_version:1,
      command_identity:("sha256:" + ("a" * 64)),status:$status,exit_status:0,timeout_seconds:60,
      started_at:"2026-01-01T00:00:00Z",finished_at:"2026-01-01T00:00:01Z",
      subject:{kind:"unbound",reusable:false},
      log:{path:"/tmp/test.log",sha256:("b" * 64)},
      coverage:{type:"opaque",reuse_policy:"advisory"}}' > "$tmpf"
    if ! jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
      fail "$name" "schema rejected legacy status=$status without outcome"
      rm -f "$tmpf"
      return
    fi
    rm -f "$tmpf"
  done
  pass "$name"
}

case_preflight_new_status_without_outcome_rejected() {
  # Verifies the current producer vocabulary (test-fail, timeout, ...) still
  # requires the structured `outcome` object -- only the legacy pass/fail
  # status values are exempt.
  local name="preflight-evidence: new-vocabulary status without outcome is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/preflight-evidence.schema.json" tmpf
  tmpf="$(mktemp /tmp/preflight-new-status-XXXXXX.json)"
  jq -n '{kind:"pr_gate_preflight_v1",schema_version:1,
    command_identity:("sha256:" + ("a" * 64)),status:"test-fail",exit_status:1,timeout_seconds:60,
    started_at:"2026-01-01T00:00:00Z",finished_at:"2026-01-01T00:00:01Z",
    subject:{kind:"unbound",reusable:false},
    log:{path:"/tmp/test.log",sha256:("b" * 64)},
    coverage:{type:"opaque",reuse_policy:"advisory"}}' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted status=test-fail without outcome"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

_gate_scope_manifest_valid_instance() {
  jq -n '{
    kind:"gate_scope_manifest_v1",
    schema_version:1,
    status:"complete",
    subject:{
      repository_key:("a" * 64),
      base_commit:("b" * 40),
      head_commit:("c" * 40),
      tree_fingerprint:("d" * 64),
      subject_kind:"committed_head"
    },
    selection:{
      diff_kind:"committed",
      base_ref:"main",
      head_ref:"HEAD",
      include_untracked:false
    },
    changes:{
      entries:[{
        status:"modified",
        old_path:null,
        new_path:"runtime/bin/example.sh",
        similarity:null
      }],
      changed_paths:["runtime/bin/example.sh"],
      renamed_paths:[],
      untracked_paths:[]
    },
    diff:{
      hunks:[{
        path:"runtime/bin/example.sh",
        source:"tracked",
        old_start:10,
        old_lines:1,
        new_start:10,
        new_lines:2,
        header:"@@ -10 +10,2 @@"
      }],
      binary_or_special_paths:[]
    },
    paired_tests:[{
      source_path:"runtime/bin/example.sh",
      test_path:"tests/shell/test-example.sh",
      reason:"language-convention"
    }],
    sensitive_signals:[{
      id:"public-contract",
      source:"path-regex",
      matches:["runtime/bin/example.sh"],
      minimum_tier:"standard",
      required_reviewers:["architecture-reviewer"],
      recommended_mode:"parallel"
    }],
    flags:{
      public_interface:{matched:false,paths:[]},
      schema:{matched:false,paths:[]},
      config:{matched:false,paths:[]},
      install:{matched:false,paths:[]},
      ci:{matched:false,paths:[]},
      release:{matched:false,paths:[]},
      migration:{matched:false,paths:[]}
    },
    expansion:{
      claim:"bounded-hints-not-complete-call-graph",
      entries:[{
        path:"tests/shell/test-example.sh",
        reason:"same-stem-peer",
        source:"runtime/bin/example.sh",
        evidence:"peer-convention",
        limit:{kind:"per-source",maximum:64}
      }],
      included_paths:["tests/shell/test-example.sh"]
    },
    reference_index:{
      claim:"declared-review-reference-set",
      entries:[
        {
          path:"runtime/bin/example.sh",
          snapshot:"subject",
          line_count:40,
          sha256:("f" * 64)
        },
        {
          path:"tests/shell/test-example.sh",
          snapshot:"subject",
          line_count:80,
          sha256:("0" * 64)
        }
      ]
    },
    truncation:{
      occurred:false,
      budgets:{
        diff_hunks:512,
        expansion_source_paths:256,
        symbols_per_source:1024,
        matches_per_query:64,
        contract_consumers_per_source:128,
        expansion_entries:512
      },
      omitted:{
        diff_hunks:0,
        expansion_source_paths:0,
        symbols_per_source:0,
        matches_per_query:0,
        contract_consumers_per_source:0,
        expansion_entries:0
      },
      reasons:[],
      acceptance:{required:false,accepted:false,source:null}
    },
    content:{
      digest_algorithm:"sha256-canonical-json-without-content-digest",
      digest:("e" * 64)
    }
  }'
}

case_gate_scope_manifest_valid_complete() {
  # Behavior: a complete canonical scope manifest passes the schema.
  # Steps:
  #   1. Build a manifest with subject, changes, review hints, and zero omissions.
  #   2. Validate it against the public schema.
  local name="gate-scope-manifest: complete canonical instance validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-scope-manifest.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-scope-valid-XXXXXX.json)"
  _gate_scope_manifest_valid_instance > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a canonical complete scope manifest"
  fi
  rm -f "$tmpf"
}

case_gate_scope_manifest_valid_accepted_truncation() {
  # Behavior: a bounded omission is representable only with explicit acceptance.
  # Steps:
  #   1. Convert the canonical instance to accepted_truncation.
  #   2. Record the omitted count, reason, and CLI acceptance source.
  #   3. Assert the schema accepts the coherent state.
  local name="gate-scope-manifest: explicit accepted truncation validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-scope-manifest.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-scope-accepted-XXXXXX.json)"
  _gate_scope_manifest_valid_instance |
    jq '
      .status = "accepted_truncation" |
      .truncation.occurred = true |
      .truncation.omitted.diff_hunks = 1 |
      .truncation.reasons = ["diff-hunk-budget"] |
      .truncation.acceptance = {
        required:true,
        accepted:true,
        source:"--accept-scope-truncation"
      }
    ' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected coherent accepted truncation"
  fi
  rm -f "$tmpf"
}

case_gate_scope_manifest_inconsistent_status_rejected() {
  # Behavior: complete status cannot conceal truncation acceptance.
  # Steps:
  #   1. Keep status complete but claim a truncation occurred and was accepted.
  #   2. Assert the conditional schema rejects the contradictory state.
  local name="gate-scope-manifest: complete status rejects hidden truncation"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-scope-manifest.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-scope-inconsistent-XXXXXX.json)"
  _gate_scope_manifest_valid_instance |
    jq '
      .truncation.occurred = true |
      .truncation.omitted.diff_hunks = 1 |
      .truncation.reasons = ["diff-hunk-budget"] |
      .truncation.acceptance = {
        required:true,
        accepted:true,
        source:"--accept-scope-truncation"
      }
    ' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted contradictory complete/truncated state"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_scope_manifest_subject_selection_rejected() {
  # Behavior: the declared diff selection must agree with the subject kind.
  # Steps:
  #   1. Change a committed-head fixture to fixed_ref without changing its
  #      committed diff kind.
  #   2. Assert the conditional schema rejects the inconsistent binding.
  local name="gate-scope-manifest: subject kind and diff selection must agree"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-scope-manifest.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-scope-selection-XXXXXX.json)"
  _gate_scope_manifest_valid_instance |
    jq '.subject.subject_kind = "fixed_ref"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted fixed_ref with committed diff selection"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_scope_manifest_escaping_path_rejected() {
  # Behavior: manifest paths stay repository relative.
  # Steps:
  #   1. Replace a changed path with an escaping path.
  #   2. Assert the schema rejects it.
  local name="gate-scope-manifest: escaping repository path is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-scope-manifest.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-scope-path-XXXXXX.json)"
  _gate_scope_manifest_valid_instance |
    jq '.changes.entries[0].new_path = "../outside.sh"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an escaping repository path"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_scope_manifest_change_entry_status_shape_rejected() {
  # Behavior: each change status has the same old/new path and similarity
  # contract in the public schema as in the runtime verifier.
  # Steps:
  #   1. Mutate the canonical entry into invalid modified, renamed, and deleted
  #      status-specific shapes.
  #   2. Validate each independently against the public schema.
  #   3. Assert every contradictory shape is rejected.
  local name="gate-scope-manifest: change status controls path shape"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-scope-manifest.schema.json"
  local tmpf mutation
  while IFS= read -r mutation; do
    tmpf="$(mktemp /tmp/gate-scope-change-shape-XXXXXX.json)"
    case "$mutation" in
      modified-old-path)
        _gate_scope_manifest_valid_instance |
          jq '.changes.entries[0].old_path = "runtime/bin/example.sh"' > "$tmpf"
        ;;
      renamed-without-similarity)
        _gate_scope_manifest_valid_instance |
          jq '
            .changes.entries[0].status = "renamed" |
            .changes.entries[0].old_path = "runtime/bin/old-example.sh"
          ' > "$tmpf"
        ;;
      deleted-with-new-path)
        _gate_scope_manifest_valid_instance |
          jq '
            .changes.entries[0].status = "deleted" |
            .changes.entries[0].old_path = "runtime/bin/example.sh"
          ' > "$tmpf"
        ;;
    esac
    if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
      rm -f "$tmpf"
      fail "$name" "schema accepted invalid $mutation entry"
      return
    fi
    rm -f "$tmpf"
  done <<'CASES'
modified-old-path
renamed-without-similarity
deleted-with-new-path
CASES
  pass "$name"
}

_gate_assurance_valid_instance() {
  jq -n '{
    kind:"gate_assurance_v2",
    schema_version:2,
    result:{final:"GO"},
    bindings:{
      result_sha256:("a" * 64),
      repo_root:"/tmp/repo",
      repo_identity:("b" * 64),
      base_commit:("c" * 40),
      head_commit:("d" * 40),
      subject_fingerprint:("e" * 64)
    },
    coordinates:{
      tier:{requested:"standard",resolved:"standard",evidence_floor:"critic plus QA"},
      mode:{
        requested:"sequential",
        resolved:"sequential",
        topology:"combined-session",
        synthesis:"inline"
      },
      pass:{
        requested:"initial",
        resolved:"initial",
        scope:"comprehensive",
        initial_result:null
      },
      coverage:{
        requested:null,
        selected:["critic","qa-tester","architecture-reviewer"],
        skipped:["security"],
        vocabulary:["critic","qa-tester","architecture-reviewer","security"]
      },
      independence:{
        implementation_context_isolated:null,
        reviewer_topology:"combined-session",
        per_reviewer_independent:null,
        evidence_status:"unavailable"
      }
    },
    policy:{
      kind:"gate_policy_resolution_v1",
      schema_version:1,
      consumer_policy:"generic",
      policy_source:"canonical",
      scope_fingerprint:("f" * 64),
      request:{
        tier:"standard",
        mode:"sequential",
        pass_kind:"initial",
        reviewers:null
      },
      classification:{
        architecture_impact:"unknown",
        line_changes:120,
        binary_or_unknown_count:0,
        layer_roots:["runtime"]
      },
      resolution:{
        minimum_tier:"standard",
        required_reviewers:["critic","qa-tester","architecture-reviewer"],
        recommended_mode:"parallel",
        mode_selection_source:"user",
        mode_recommendation_overridden:true,
        downgrade_requested:false,
        downgrade_allowed:false
      },
      matched_signals:[
        {
          id:"consumer-policy",
          source:"consumer-policy",
          matches:["generic:initial"],
          minimum_tier:"express",
          required_reviewers:["critic","qa-tester"],
          recommended_mode:"sequential"
        },
        {
          id:"medium-change",
          source:"classification",
          matches:["changed-lines:120"],
          minimum_tier:"standard",
          required_reviewers:["architecture-reviewer"],
          recommended_mode:"parallel"
        }
      ],
      resolved:{
        tier:"standard",
        mode:"sequential",
        reviewers:["critic","qa-tester","architecture-reviewer"]
      },
      enforcement:{status:"pass",violations:[]},
      override:{
        status:"not_provided",
        source:null,
        sha256:null,
        reason:null,
        approver:null
      },
      reviewer_override:{status:"not_provided",source:null,sha256:null}
    },
    dispatch:{
      outcomes:[{
        role:"combined",
        reviewer:null,
        status:"passed",
        run_id:null,
        evidence_status:"unavailable"
      }]
    },
    provenance:{producer:"pr-gate.sh",policy_source:"canonical",attestation:null}
  }'
}

_gate_assurance_v3_valid_instance() {
  _gate_assurance_valid_instance |
    jq '
      .kind = "gate_assurance_v3" |
      .schema_version = 3 |
      .coordinates.tier.selection_basis = "explicit" |
      .coordinates.coverage.selection_basis = "policy-default" |
      .subject = {
        kind:"gate_subject_v1",
        schema_version:1,
        repository:{
          key:("b" * 64),
          git_common_dir_identity:("1" * 64),
          remote_identity:null
        },
        observed:{root:"/tmp/repo",git_common_dir:"/tmp/repo/.git"},
        base:{ref:"main",commit:("c" * 40)},
        head:{ref:"HEAD",commit:("d" * 40)},
        tree_fingerprint:("e" * 64),
        subject_kind:"committed_head",
        dirty_policy:"require_clean",
        created_at:"2026-07-28T00:00:00Z",
        finished_at:"2026-07-28T00:01:00Z",
        observed_at_finish:{
          repository_key:("b" * 64),
          base_commit:("c" * 40),
          head_commit:("d" * 40),
          tree_fingerprint:("e" * 64)
        }
      } |
      .evidence = {
        preflight:{
          status:"linked",
          outcome:"pass",
          artifact:"preflight-evidence-20260728-000000.json",
          sha256:("2" * 64),
          subject_fingerprint:("e" * 64)
        },
        scope_manifest:{
          status:"unavailable",
          artifact:null,
          sha256:null,
          subject_fingerprint:null
        },
        closure:{
          status:"unavailable",
          artifact:null,
          sha256:null,
          subject_fingerprint:null
        }
      }
    '
}

_gate_verification_valid_instance() {
  jq -n '{
    kind:"gate_verification_v1",
    schema_version:1,
    result_file:"/tmp/result.md",
    verdict:"GO",
    assurance:{
      status:"verified",
      kind:"gate_assurance_v3",
      file:"/tmp/result.md.assurance.json"
    },
    consumer:"maintainer",
    axes:{
      artifact_valid:{status:"pass",reason_codes:[]},
      subject_current:{
        status:"pass",
        reason_codes:[],
        current:{
          repository_key:("a" * 64),
          base_commit:("b" * 40),
          head_commit:("c" * 40),
          tree_fingerprint:("d" * 64),
          observed_root:"/tmp/repo"
        }
      },
      policy_applicable:{
        status:"pass",
        reason_codes:[],
        consumer:"maintainer",
        required_policy:"maintainer",
        preferred_policy:"maintainer",
        embedded_policy:"maintainer",
        policy_satisfaction:"preferred"
      }
    }
  }'
}

case_gate_assurance_valid_instance() {
  local name="gate-assurance: canonical sequential envelope validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-assurance.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-assurance-valid-XXXXXX.json)"
  _gate_assurance_valid_instance > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a canonical sequential assurance envelope"
  fi
  rm -f "$tmpf"
}

case_gate_assurance_v3_valid_instance() {
  local name="gate-assurance: v3 subject and evidence envelope validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-assurance.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-assurance-v3-valid-XXXXXX.json)"
  _gate_assurance_v3_valid_instance > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a canonical v3 assurance envelope"
  fi
  rm -f "$tmpf"
}

case_gate_assurance_v2_rejects_v3_fields() {
  local name="gate-assurance: v2 cannot carry unversioned v3 subject fields"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-assurance.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-assurance-v2-v3-fields-XXXXXX.json)"
  _gate_assurance_v3_valid_instance |
    jq '.kind = "gate_assurance_v2" | .schema_version = 2' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted v3 subject/evidence fields under v2"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_assurance_v3_invalid_dirty_pair_rejected() {
  local name="gate-assurance: subject kind and dirty policy must agree"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-assurance.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-assurance-v3-dirty-pair-XXXXXX.json)"
  _gate_assurance_v3_valid_instance |
    jq '.subject.dirty_policy = "ignore_working_tree"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted committed_head with ignore_working_tree"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_assurance_v3_evidence_path_rejected() {
  local name="gate-assurance: linked evidence artifact must be a basename"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-assurance.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-assurance-v3-evidence-path-XXXXXX.json)"
  _gate_assurance_v3_valid_instance |
    jq '
      .evidence.scope_manifest = {
        status:"verified",
        artifact:"../scope.json",
        sha256:("3" * 64),
        subject_fingerprint:("e" * 64)
      }
    ' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted escaping linked-evidence path"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_assurance_selection_basis_rejected() {
  local name="gate-assurance: unknown coordinate selection basis is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-assurance.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-assurance-selection-basis-XXXXXX.json)"
  for mutation in \
    'del(.coordinates.tier.selection_basis)' \
    'del(.coordinates.coverage.selection_basis)' \
    '.coordinates.tier.selection_basis = "unknown"' \
    '.coordinates.coverage.selection_basis = "tier-implies-coverage"' \
    '.coordinates.tier.selection_basis = "policy"' \
    '.coordinates.coverage.selection_basis = "explicit"' \
    '.coordinates.coverage.requested = ["critic"] | .coordinates.coverage.selection_basis = "policy-default"'
  do
    _gate_assurance_v3_valid_instance | jq "$mutation" > "$tmpf"
    if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
      fail "$name" "schema accepted invalid v3 selection-basis mutation: $mutation"
      rm -f "$tmpf"
      return
    fi
  done
  _gate_assurance_v3_valid_instance |
    jq 'del(.coordinates.tier.selection_basis, .coordinates.coverage.selection_basis)' > "$tmpf"
  if ! jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema rejected a complete historical v3 selection-basis omission"
    rm -f "$tmpf"
    return
  fi
  _gate_assurance_valid_instance |
    jq '.coordinates.tier.selection_basis = "policy"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a v3-only selection basis on v2"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_verification_valid_instance() {
  local name="gate-verification: canonical three-axis report validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-verification.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-verification-valid-XXXXXX.json)"
  _gate_verification_valid_instance > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a canonical three-axis report"
  fi
  rm -f "$tmpf"
}

case_gate_verification_duplicate_reason_rejected() {
  local name="gate-verification: duplicate reason codes are rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-verification.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-verification-duplicate-reason-XXXXXX.json)"
  _gate_verification_valid_instance |
    jq '.axes.subject_current.reason_codes = ["tree_drift","tree_drift"]' \
      > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted duplicate reason codes"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_verification_invalid_consumer_rejected() {
  local name="gate-verification: unknown policy consumer is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-verification.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-verification-consumer-XXXXXX.json)"
  _gate_verification_valid_instance |
    jq '.axes.policy_applicable.consumer = "deployment"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a policy consumer outside the contract"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

# Behavior: gate verification rejects out-of-contract policy preference and
# satisfaction values.
# Steps: mutate each new enum field in the canonical fixture, validate it
# against the schema, and require both invalid instances to be rejected.
case_gate_verification_invalid_policy_satisfaction_fields_rejected() {
  local name="gate-verification: policy preference and satisfaction enums are enforced"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-verification.schema.json"
  local field tmpf accepted=()
  for field in preferred_policy policy_satisfaction; do
    tmpf="$(mktemp "/tmp/gate-verification-${field}-XXXXXX.json")"
    _gate_verification_valid_instance |
      jq --arg field "$field" \
        '.axes.policy_applicable[$field] = "outside-contract"' > "$tmpf"
    if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
      accepted+=("$field")
    fi
    rm -f "$tmpf"
  done
  if [[ "${#accepted[@]}" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "schema accepted invalid values for: ${accepted[*]}"
  fi
}

case_gate_assurance_invalid_outcome_rejected() {
  local name="gate-assurance: unknown dispatch status is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-assurance.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-assurance-invalid-XXXXXX.json)"
  _gate_assurance_valid_instance |
    jq '.dispatch.outcomes[0].status = "timed-out"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an outcome status outside the contract"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_assurance_non_user_policy_approver_rejected() {
  local name="gate-assurance: non-user policy approver is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-assurance.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-assurance-policy-approver-XXXXXX.json)"
  _gate_assurance_valid_instance |
    jq '.policy.override.approver = {
      kind:"project-pm",identity:"fixture-pm",approval_ref:"self:approval"
    }' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a project-PM policy self-approval"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

_gate_reviewer_result_valid_instance() {
  jq -n '
    ["changed_files","paired_tests","sensitive_signals","public_interface",
      "schema","config","install","ci","release","migration",
      "bounded_expansion"] as $surfaces |
    {
      kind:"gate_reviewer_result_v1",
      schema_version:1,
      reviewer:"critic",
      scope_manifest_sha256:("a" * 64),
      coverage_claim:"declared-scope-checklist-not-review-completeness",
      coverage:($surfaces | map({
        surface:.,
        status:"examined",
        evidence_refs:[{path:"runtime/bin/example.sh",line:42,symbol:null}],
        reason:"The reviewer examined this declared surface."
      })),
      findings:[{
        id:"critic-F001",
        reviewer:"critic",
        severity:"high",
        hard_gate_class:"soft_block",
        origin:"diff_caused",
        source:{path:"runtime/bin/example.sh",line:42,symbol:null},
        affected_behavior:"The changed command can emit an incomplete result.",
        why_it_matters:"Consumers could accept evidence that was not reviewed.",
        failure_mode:"The incomplete artifact reaches a publish decision.",
        minimum_fix_boundary:"Reject the malformed reviewer result before synthesis.",
        verification_expectation:"Run the malformed-protocol fixture."
      }],
      test_gaps:[{
        id:"critic-TG001",
        reviewer:"critic",
        status:"gap",
        affected_behavior:"Malformed reviewer output lacks negative-path coverage.",
        contract:"Malformed output fails closed and is retried once.",
        existing_evidence:[{path:"runtime/bin/example.sh",line:42,symbol:null}],
        coverage_dimensions:["negative","regression"],
        missing_layer:"integration",
        scenario:"The first reviewer result is malformed and the second is valid.",
        oracle:"Only the failed reviewer is retried.",
        failure_signal:"A valid reviewer is dispatched again.",
        suggested_command:"bash tests/bin/run-tests.sh --path tests/shell/test-pr-gate.sh"
      }],
      verdict:"block-soft",
      rationale:"Every declared surface was completed after recording the blocker."
    }
  '
}

case_gate_reviewer_result_valid_instance() {
  local name="gate-reviewer-result: canonical blocker with complete coverage validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-valid-XXXXXX.json)"
  _gate_reviewer_result_valid_instance > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a canonical reviewer result"
  fi
  rm -f "$tmpf"
}

case_gate_reviewer_result_missing_surface_rejected() {
  local name="gate-reviewer-result: missing coverage surface is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-missing-surface-XXXXXX.json)"
  _gate_reviewer_result_valid_instance |
    jq '.coverage = .coverage[:-1]' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an incomplete reviewer coverage checklist"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_reviewer_result_invalid_stable_id_rejected() {
  local name="gate-reviewer-result: invalid stable finding ID is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-invalid-id-XXXXXX.json)"
  _gate_reviewer_result_valid_instance |
    jq '.findings[0].id = "finding-one"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an unstable finding ID"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_reviewer_result_evidence_less_blocker_rejected() {
  local name="gate-reviewer-result: evidence-less blocker is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-no-source-XXXXXX.json)"
  _gate_reviewer_result_valid_instance |
    jq '.findings[0].source = {path:"",line:null,symbol:null}' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a blocker without source evidence"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_reviewer_result_preexisting_blocker_rejected() {
  local name="gate-reviewer-result: pre-existing issue cannot be a blocker"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-preexisting-block-XXXXXX.json)"
  _gate_reviewer_result_valid_instance |
    jq '.findings[0].origin = "pre_existing"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a pre-existing blocker"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_reviewer_result_omitted_unused_symbol_valid() {
  local name="gate-reviewer-result: evidence ref may omit unused symbol"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-omitted-symbol-XXXXXX.json)"
  _gate_reviewer_result_valid_instance |
    jq 'del(.coverage[0].evidence_refs[0].symbol)' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected an evidence ref with path and line"
  fi
  rm -f "$tmpf"
}

case_gate_reviewer_result_missing_line_and_symbol_rejected() {
  local name="gate-reviewer-result: evidence ref needs line or symbol"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-no-location-XXXXXX.json)"
  _gate_reviewer_result_valid_instance |
    jq 'del(.coverage[0].evidence_refs[0].line,
      .coverage[0].evidence_refs[0].symbol)' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an evidence ref without line or symbol"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_reviewer_result_abbreviated_reviewer_id_rejected() {
  local name="gate-reviewer-result: abbreviated reviewer finding ID is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-short-id-XXXXXX.json)"
  _gate_reviewer_result_valid_instance |
    jq '.reviewer = "risk-reviewer" |
      .findings[0].reviewer = "risk-reviewer" |
      .findings[0].id = "risk-F001"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an abbreviated reviewer finding ID"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_reviewer_result_malformed_test_gap_rejected() {
  local name="gate-reviewer-result: malformed test-gap row is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-reviewer-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-reviewer-result-test-gap-XXXXXX.json)"
  _gate_reviewer_result_valid_instance |
    jq '.test_gaps[0].coverage_dimensions = []' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an empty test-gap coverage dimension set"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

_gate_synthesis_result_valid_instance() {
  jq -n '
    {
      kind:"gate_synthesis_result_v1",
      schema_version:1,
      scope_manifest_sha256:("a" * 64),
      selected_reviewers:["critic"],
      not_reviewed_dimensions:[
        "qa-tester",
        "architecture-reviewer",
        "security-reviewer",
        "risk-reviewer"
      ],
      coverage_matrix:[{
        reviewer:"critic",
        surface:"changed_files",
        status:"examined",
        evidence_refs:[{path:"src/example.sh",line:1,symbol:null}],
        reason:"The fixture examined the changed file."
      }],
      reviewer_finding_inventory:[{
        id:"critic-F001",
        reviewer:"critic",
        severity:"low",
        hard_gate_class:"none",
        origin:"caution",
        verification_expectation:"Run the focused fixture check."
      }],
      findings_union:[{
        id:"critic-F001",
        reviewer:"critic",
        severity:"low",
        hard_gate_class:"none",
        origin:"caution",
        source:{path:"src/example.sh",line:1,symbol:null},
        affected_behavior:"The fixture behavior remains advisory.",
        why_it_matters:"Lower-severity evidence must survive synthesis.",
        failure_mode:"Synthesis silently discards the caution.",
        minimum_fix_boundary:"Preserve the original stable finding.",
        verification_expectation:"Run the focused fixture check.",
        root_cause_group_id:"RCG-001",
        disposition:"pending"
      }],
      root_cause_groups:[{
        id:"RCG-001",
        summary:"One advisory fixture root cause.",
        finding_ids:["critic-F001"]
      }],
      disagreements:[],
      uncertainties:{finding_ids:[],coverage_cells:[]},
      cautions:["critic-F001"],
      test_gap_matrix:[{
        id:"critic-TG001",reviewer:"critic",status:"gap",
        affected_behavior:"Malformed reviewer output lacks negative-path coverage.",
        contract:"Malformed output fails closed and is retried once.",
        existing_evidence:[{path:"src/example.sh",line:1,symbol:null}],
        coverage_dimensions:["negative","regression"],
        missing_layer:"integration",
        scenario:"The first reviewer result is malformed and the second is valid.",
        oracle:"Only the failed reviewer is retried.",
        failure_signal:"A valid reviewer is dispatched again.",
        suggested_command:"bash tests/bin/run-tests.sh --path tests/shell/test-pr-gate.sh"
      }],
      operational_cautions:[],
      user_cautions:[],
      verification_plan:{
        focused:["bash tests/bin/run-tests.sh --path tests/shell/test-pr-gate.sh"],
        manual:[],
        full:["bash tests/bin/run-tests.sh"]
      },
      remediation_seed:{
        kind:"remediation_closure_v1",
        schema_version:1,
        state:"seed",
        scope_manifest_sha256:("a" * 64),
        entries:[{
          finding_id:"critic-F001",
          reviewer:"critic",
          root_cause_group_id:"RCG-001",
          disposition:"pending",
          verification_expectation:"Run the focused fixture check."
        }]
      }
    }
  '
}

_gate_remediation_closure_valid_instance() {
  jq -n '
    {
      kind:"remediation_closure_v1",
      schema_version:1,
      state:"closed",
      scope_manifest_sha256:("a" * 64),
      primary:{
        gate_result:{
          artifact:"primary-result.md",
          sha256:("b" * 64),
          subject_fingerprint:("d" * 64)
        },
        verdict:"NO-GO",
        status:"verified",
        subject:{
          repository_key:("c" * 64),
          base_commit:("1" * 40),
          head_commit:("2" * 40),
          tree_fingerprint:("d" * 64),
          subject_kind:"committed_head"
        }
      },
      final_subject:{
        repository_key:("c" * 64),
        base_commit:("1" * 40),
        head_commit:("2" * 40),
        tree_fingerprint:("d" * 64),
        subject_kind:"committed_head"
      },
      findings:[{
        finding_id:"critic-F001",
        origin:"diff_caused",
        disposition:"closed",
        classification:"local",
        changed_paths:["runtime/lib/gate-closure.sh"],
        evidence_refs:[{path:"runtime/lib/gate-closure.sh",line:1,symbol:null}],
        affected_test_ids:["closure-schema"],
        verification_status:"pass"
      }],
      changed_files:["runtime/lib/gate-closure.sh"],
      affected_tests:[{
        id:"closure-schema",
        kind:"focused",
        command:"bash tests/shell/test-core-schemas.sh",
        status:"pass",
        subject_fingerprint:("d" * 64),
        artifact:null,
        artifact_sha256:null
      },{
        id:"closure-full",
        kind:"full",
        command:"bash tests/bin/run-all-tests.sh",
        status:"pass",
        subject_fingerprint:("d" * 64),
        artifact:"latest-full.json",
        artifact_sha256:("e" * 64)
      }],
      targeted_confirmation:{
        status:"not_required",
        reviewers:[],
        delta_only:true,
        evidence:null
      },
      unresolved_counts:{total:0,blocking:0,advisory:0},
      final_assessment:{
        remediation_status:"closed",
        affected_tests_status:"pass",
        full_suite_status:"pass",
        subject_fingerprint:("d" * 64),
        publish_authorized:true
      }
    }
  '
}

case_gate_remediation_closure_valid_instance() {
  local name="remediation-closure: canonical closed artifact validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-remediation-closure.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-remediation-closure-valid-XXXXXX.json)"
  _gate_remediation_closure_valid_instance > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a canonical remediation closure"
  fi
  rm -f "$tmpf"
}

case_gate_remediation_closure_invalid_finding_rejected() {
  local name="remediation-closure: cross-field finding rules stay runtime-owned"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-remediation-closure.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-remediation-closure-invalid-XXXXXX.json)"
  _gate_remediation_closure_valid_instance |
    jq '.findings[0].disposition = "tracked"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    # The cross-field rule is intentionally runtime-owned; the structural
    # schema still accepts the enum combination for historical inspection.
    pass "$name"
  else
    fail "$name" "schema rejected a structurally valid finding row"
  fi
  rm -f "$tmpf"
}

case_gate_remediation_closure_runtime_claims() {
  local name="remediation-closure: runtime verifier enforces finding classification"
  should_run "$name" || return 0
  local valid invalid
  valid="$(mktemp /tmp/gate-remediation-closure-runtime-XXXXXX.json)"
  invalid="${valid}.invalid"
  _gate_remediation_closure_valid_instance > "$valid"
  _gate_remediation_closure_valid_instance |
    jq '.findings[0].disposition = "tracked"' > "$invalid"
  if ! gate_remediation_closure_verify "$valid" \
      "$(printf 'd%.0s' {1..64})" "$(printf 'a%.0s' {1..64})"; then
    fail "$name" "canonical closure was rejected"
    rm -f "$valid" "$invalid"
    return
  fi
  if gate_remediation_closure_verify "$invalid" \
      "$(printf 'd%.0s' {1..64})" "$(printf 'a%.0s' {1..64})" >/dev/null 2>&1; then
    fail "$name" "invalid finding classification was accepted"
  else
    pass "$name"
  fi
  rm -f "$valid" "$invalid"
}

case_gate_remediation_closure_publish_is_no_replace() {
  local name="remediation-closure: existing artifact is immutable and preserved"
  should_run "$name" || return 0
  local dir result assurance scope closure subject scope_sha before after
  dir="$(mktemp -d /tmp/gate-remediation-closure-publish-XXXXXX)"
  result="$dir/result.md"
  assurance="$result.assurance.json"
  scope="$dir/scope.json"
  closure="$dir/closure.json"
  subject="$(printf 'd%.0s' {1..64})"
  scope_sha="$(printf 'a%.0s' {1..64})"

  printf 'Final: GO\n' > "$result"
  jq -n --arg subject "$subject" --arg scope_sha "$scope_sha" '{
    subject:{
      repository_key:("c" * 64),
      base_commit:("1" * 40),
      head_commit:("2" * 40),
      tree_fingerprint:$subject,
      subject_kind:"committed_head"
    },
    evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}
  }' > "$assurance"
  jq -n '{
    changes:{changed_paths:["runtime/lib/gate-closure.sh"],renamed_paths:[],untracked_paths:[]},
    diff:{binary_or_special_paths:[]}
  }' > "$scope"

  if ! gate_remediation_closure_publish "$result" "$assurance" "$closure" >/dev/null; then
    fail "$name" "initial closure publication failed"
    rm -rf "$dir"
    return
  fi
  before="$(gate_digest_file "$closure")"
  if gate_remediation_closure_publish "$result" "$assurance" "$closure" >/dev/null 2>&1; then
    fail "$name" "republish unexpectedly replaced an existing closure"
    rm -rf "$dir"
    return
  fi
  after="$(gate_digest_file "$closure")"
  if [[ "$before" != "$after" ]] || ! jq -e '.kind == "remediation_closure_v1"' "$closure" >/dev/null 2>&1; then
    fail "$name" "existing closure bytes were not preserved"
  else
    pass "$name"
  fi
  rm -rf "$dir"
}

# Behavior: a complete synthesis parity document must satisfy its JSON schema.
# Steps:
#   1. Generate the canonical synthesis fixture.
#   2. Validate it against gate-synthesis-result.schema.json.
#   3. Assert schema validation succeeds.
case_gate_synthesis_result_valid_instance() {
  local name="gate-synthesis-result: canonical parity seed validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-synthesis-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-synthesis-result-valid-XXXXXX.json)"
  _gate_synthesis_result_valid_instance > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a canonical synthesis result"
  fi
  rm -f "$tmpf"
}

# Behavior: a remediation seed without verification expectation must fail
# schema validation.
# Steps:
#   1. Remove verification_expectation from the canonical fixture.
#   2. Validate the mutated document against the synthesis schema.
#   3. Assert schema validation rejects the mutation.
case_gate_synthesis_result_missing_verification_rejected() {
  local name="gate-synthesis-result: missing verification expectation is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-synthesis-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-synthesis-result-no-verification-XXXXXX.json)"
  _gate_synthesis_result_valid_instance |
    jq 'del(.remediation_seed.entries[0].verification_expectation)' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a seed without verification expectation"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

# Behavior: a remediation seed cannot claim closure before verification.
# Steps:
#   1. Change the canonical seed state to closed.
#   2. Validate the mutated document against the synthesis schema.
#   3. Assert schema validation rejects the premature closure.
case_gate_synthesis_result_closed_seed_rejected() {
  local name="gate-synthesis-result: seed cannot claim closure"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-synthesis-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-synthesis-result-closed-seed-XXXXXX.json)"
  _gate_synthesis_result_valid_instance |
    jq '.remediation_seed.state = "closed"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a remediation seed claiming closure"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_synthesis_result_invalid_verification_plan_rejected() {
  local name="gate-synthesis-result: full verification plan cannot be empty"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-synthesis-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-synthesis-result-plan-XXXXXX.json)"
  _gate_synthesis_result_valid_instance |
    jq '.verification_plan.full = []' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an empty full verification plan"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_synthesis_result_contradictory_no_gap_rejected() {
  local name="gate-synthesis-result: no-gap row rejects gap-only fields"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-synthesis-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-synthesis-result-no-gap-shape-XXXXXX.json)"
  _gate_synthesis_result_valid_instance |
    jq '.test_gap_matrix[0].status = "no_gap"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a no-gap row with a missing layer and gap-only fields"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_synthesis_result_incomplete_gap_rejected() {
  local name="gate-synthesis-result: gap row requires a missing layer and execution details"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-synthesis-result.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-synthesis-result-gap-shape-XXXXXX.json)"
  _gate_synthesis_result_valid_instance |
    jq '.test_gap_matrix[0].missing_layer = "none" |
      .test_gap_matrix[0].scenario = null |
      .test_gap_matrix[0].oracle = null |
      .test_gap_matrix[0].failure_signal = null |
      .test_gap_matrix[0].suggested_command = null' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a gap row without a missing layer or execution details"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

_gate_policy_override_valid_instance() {
  jq -n '{
    kind:"gate_policy_override_v1",
    schema_version:1,
    scope_fingerprint:("a" * 64),
    allow:{
      tier:"express",
      omit_reviewers:["security-reviewer"]
    },
    reason:"User accepted this exact bounded downgrade.",
    approver:{
      kind:"user",
      identity:"fixture-user",
      approval_ref:"conversation:fixture"
    }
  }'
}

case_gate_policy_override_valid_instance() {
  local name="gate-policy-override: canonical user approval validates"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-policy-override.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-policy-override-valid-XXXXXX.json)"
  _gate_policy_override_valid_instance > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "schema rejected a canonical user-approved override"
  fi
  rm -f "$tmpf"
}

case_gate_policy_override_non_user_approver_rejected() {
  local name="gate-policy-override: project-PM self-approval is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-policy-override.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-policy-override-invalid-XXXXXX.json)"
  _gate_policy_override_valid_instance |
    jq '.approver.kind = "project-pm"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted a project-PM policy self-approval"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_policy_override_extra_key_rejected() {
  local name="gate-policy-override: extra contract key is rejected"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-policy-override.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-policy-override-extra-key-XXXXXX.json)"
  _gate_policy_override_valid_instance |
    jq '.unexpected = true' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted an undeclared top-level override key"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_policy_override_mode_key_rejected() {
  local name="gate-policy-override: mode is user choice, not a downgrade key"
  should_run "$name" || return 0
  local schema_file="$CORE_DIR/schema/gate-policy-override.schema.json" tmpf
  tmpf="$(mktemp /tmp/gate-policy-override-mode-key-XXXXXX.json)"
  _gate_policy_override_valid_instance |
    jq '.allow.mode = "sequential"' > "$tmpf"
  if jsonschema -i "$tmpf" "$schema_file" >/dev/null 2>&1; then
    fail "$name" "schema accepted mode as a policy downgrade allowance"
  else
    pass "$name"
  fi
  rm -f "$tmpf"
}

case_gate_structural_generated_bundle_current() {
  local name="Gate structural schema bundle is fresh"
  should_run "$name" || return 0
  if "$REPO_ROOT/tools/generate/gate-structural-validator.sh" --check; then
    pass "$name"
  else
    fail "$name" "generated bundle is stale"
  fi
}

case_gate_structural_valid_instances() {
  local name="schema-derived Gate validator accepts canonical instances"
  local tmpf
  should_run "$name" || return 0
  tmpf="$(mktemp "${TMPDIR:-/tmp}/gate-structural-valid.XXXXXX")"
  local ok=true schema instance
  for schema in gate-scope-manifest gate-assurance gate-verification \
      gate-reviewer-result gate-synthesis-result gate-policy-override \
      gate-remediation-closure; do
    case "$schema" in
      gate-scope-manifest) instance="$(_gate_scope_manifest_valid_instance)" ;;
      gate-assurance) instance="$(_gate_assurance_valid_instance)" ;;
      gate-verification) instance="$(_gate_verification_valid_instance)" ;;
      gate-reviewer-result) instance="$(_gate_reviewer_result_valid_instance)" ;;
      gate-synthesis-result) instance="$(_gate_synthesis_result_valid_instance)" ;;
      gate-policy-override) instance="$(_gate_policy_override_valid_instance)" ;;
      gate-remediation-closure) instance="$(_gate_remediation_closure_valid_instance)" ;;
    esac
    printf '%s\n' "$instance" > "$tmpf"
    if ! gate_structural_schema_verify "$schema" "$tmpf" "$name ($schema)"; then
      ok=false
    fi
  done
  _gate_assurance_v3_valid_instance > "$tmpf"
  if ! gate_structural_schema_verify gate-assurance "$tmpf" \
      "$name (gate-assurance v3)"; then
    ok=false
  fi
  rm -f -- "$tmpf"
  if [[ "$ok" == true ]]; then pass "$name"; else fail "$name" "canonical instance rejected"; fi
}

case_gate_structural_rejects_extra_key() {
  local name="schema-derived Gate validator rejects extra keys" tmpf
  should_run "$name" || return 0
  tmpf="$(mktemp "${TMPDIR:-/tmp}/gate-structural-invalid.XXXXXX")"
  _gate_policy_override_valid_instance | jq '.unexpected = true' > "$tmpf"
  if gate_structural_schema_verify gate-policy-override "$tmpf" "$name"; then
    rm -f -- "$tmpf"
    fail "$name" "extra key was accepted"
  else
    rm -f -- "$tmpf"
    pass "$name"
  fi
}

case_context_pack_v1_still_valid
case_context_pack_v2_new_fields_valid
case_context_pack_memory_source_domain_valid
case_context_pack_invalid_source_domain_rejected
case_context_pack_invalid_trust_level_rejected
case_preflight_basic_evidence_needs_no_git_provenance
case_preflight_reusable_evidence_requires_fingerprint
case_preflight_legacy_status_without_outcome_accepted
case_preflight_new_status_without_outcome_rejected
case_gate_scope_manifest_valid_complete
case_gate_scope_manifest_valid_accepted_truncation
case_gate_scope_manifest_inconsistent_status_rejected
case_gate_scope_manifest_subject_selection_rejected
case_gate_scope_manifest_escaping_path_rejected
case_gate_scope_manifest_change_entry_status_shape_rejected
case_gate_assurance_valid_instance
case_gate_assurance_v3_valid_instance
case_gate_assurance_v2_rejects_v3_fields
case_gate_assurance_v3_invalid_dirty_pair_rejected
case_gate_assurance_v3_evidence_path_rejected
case_gate_assurance_selection_basis_rejected
case_gate_verification_valid_instance
case_gate_verification_duplicate_reason_rejected
case_gate_verification_invalid_consumer_rejected
case_gate_verification_invalid_policy_satisfaction_fields_rejected
case_gate_assurance_invalid_outcome_rejected
case_gate_assurance_non_user_policy_approver_rejected
case_gate_reviewer_result_valid_instance
case_gate_reviewer_result_missing_surface_rejected
case_gate_reviewer_result_invalid_stable_id_rejected
case_gate_reviewer_result_evidence_less_blocker_rejected
case_gate_reviewer_result_preexisting_blocker_rejected
case_gate_reviewer_result_omitted_unused_symbol_valid
case_gate_reviewer_result_missing_line_and_symbol_rejected
case_gate_reviewer_result_abbreviated_reviewer_id_rejected
case_gate_reviewer_result_malformed_test_gap_rejected
case_gate_synthesis_result_valid_instance
case_gate_synthesis_result_missing_verification_rejected
case_gate_synthesis_result_closed_seed_rejected
case_gate_remediation_closure_valid_instance
case_gate_remediation_closure_invalid_finding_rejected
case_gate_remediation_closure_runtime_claims
case_gate_remediation_closure_publish_is_no_replace
case_gate_synthesis_result_invalid_verification_plan_rejected
case_gate_synthesis_result_contradictory_no_gap_rejected
case_gate_synthesis_result_incomplete_gap_rejected
case_gate_policy_override_valid_instance
case_gate_policy_override_non_user_approver_rejected
case_gate_policy_override_extra_key_rejected
case_gate_policy_override_mode_key_rejected
case_gate_structural_generated_bundle_current
case_gate_structural_valid_instances
case_gate_structural_rejects_extra_key

th_summary
