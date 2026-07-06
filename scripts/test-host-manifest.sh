#!/usr/bin/env bash
# Structural tests for hosts/*/host.yaml manifests and docs/host-contract.md.
#
# Asserts every host manifest carries the schema v1 required fields, that the
# guard_bindings capability tuple stays field-aligned with doctor.sh's
# emit_capability signature, that declared module paths exist, and that the
# contract doc documents the load-bearing clauses the manifests rely on.
#
# Runs via: scripts/test-host-manifest.sh
# Filter:   scripts/test-host-manifest.sh --filter <pattern>
# List:     scripts/test-host-manifest.sh --list

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-host-manifest" "$@"

CONTRACT_DOC="$REPO_ROOT/docs/host-contract.md"

# Schema v1 required top-level keys (docs/host-contract.md "Top-level fields").
REQUIRED_KEYS=(
  schema_version
  host_name
  host_binary
  install_targets
  hook_surface
  guard_bindings
  permissions_surface
  doctor_module
  uninstall_module
)

# Capability object fields that must ride on every guard_bindings entry,
# aligned verbatim with doctor.sh emit_capability's tuple.
CAPABILITY_FIELDS=(provider enforcement coverage stability confidence)

# count_key <file> <key>: occurrences of "key:" at list-item or nested depth.
count_key() {
  grep -cE "^[[:space:]]*(- )?$2:" "$1" || true
}

check_manifest() {
  local manifest="$1"
  local host_dir host_name
  host_dir="$(basename "$(dirname "$manifest")")"

  local name="hosts/$host_dir: manifest is non-empty, space-indented YAML"
  if should_run "$name"; then
    if [[ -s "$manifest" ]] && ! grep -Pq '^\t' "$manifest"; then
      pass "$name"
    else
      fail "$name" "empty file or tab indentation in $manifest"
    fi
  fi

  for key in "${REQUIRED_KEYS[@]}"; do
    name="hosts/$host_dir: declares top-level $key"
    should_run "$name" || continue
    if grep -qE "^$key:" "$manifest"; then
      pass "$name"
    else
      fail "$name" "missing required top-level key: $key"
    fi
  done

  name="hosts/$host_dir: schema_version is a positive integer"
  if should_run "$name"; then
    if grep -qE '^schema_version:[[:space:]]*[1-9][0-9]*[[:space:]]*(#.*)?$' "$manifest"; then
      pass "$name"
    else
      fail "$name" "schema_version must be a bare positive integer"
    fi
  fi

  name="hosts/$host_dir: host_name matches directory name"
  if should_run "$name"; then
    host_name="$(grep -E '^host_name:' "$manifest" | head -1 | sed 's/^host_name:[[:space:]]*//;s/[[:space:]]*#.*$//')"
    if [[ "$host_name" == "$host_dir" ]]; then
      pass "$name"
    else
      fail "$name" "host_name='$host_name' != directory '$host_dir'"
    fi
  fi

  # Every guard_bindings entry must carry the full capability tuple plus
  # binding_form: the count of each field must equal the count of capability:.
  local cap_count field_count
  cap_count="$(count_key "$manifest" capability)"
  name="hosts/$host_dir: guard_bindings has at least one capability entry"
  if should_run "$name"; then
    if [[ "$cap_count" -ge 1 ]]; then
      pass "$name"
    else
      fail "$name" "no capability: entries under guard_bindings"
    fi
  fi
  for field in binding_form "${CAPABILITY_FIELDS[@]}"; do
    name="hosts/$host_dir: every guard binding declares $field"
    should_run "$name" || continue
    field_count="$(count_key "$manifest" "$field")"
    if [[ "$field_count" -eq "$cap_count" ]]; then
      pass "$name"
    else
      fail "$name" "$field count ($field_count) != capability count ($cap_count)"
    fi
  done

  name="hosts/$host_dir: declared doctor_module exists"
  if should_run "$name"; then
    local module
    module="$(grep -E '^doctor_module:' "$manifest" | head -1 | sed 's/^doctor_module:[[:space:]]*//;s/[[:space:]]*#.*$//')"
    if [[ -n "$module" && -f "$REPO_ROOT/$module" ]]; then
      pass "$name"
    else
      fail "$name" "doctor_module '$module' not found under repo root"
    fi
  fi

  name="hosts/$host_dir: manifest carries no ticket references"
  if should_run "$name"; then
    if grep -qE 'CC-[0-9]+' "$manifest"; then
      fail "$name" "ticket IDs belong in BACKLOG/DECISIONS, not operational files"
    else
      pass "$name"
    fi
  fi
}

manifests=("$REPO_ROOT"/hosts/*/host.yaml)
name="hosts/: at least one host manifest exists"
if should_run "$name"; then
  if [[ -f "${manifests[0]}" ]]; then
    pass "$name"
  else
    fail "$name" "no hosts/*/host.yaml found"
  fi
fi
for manifest in "${manifests[@]}"; do
  [[ -f "$manifest" ]] && check_manifest "$manifest"
done

# --- contract doc ------------------------------------------------------------

name="host-contract.md: exists and is non-empty"
if should_run "$name"; then
  if [[ -s "$CONTRACT_DOC" ]]; then
    pass "$name"
  else
    fail "$name" "missing $CONTRACT_DOC"
  fi
fi

for needle in \
  "Closure-of-all-paths" \
  "binding_form" \
  "Hook trust in headless runs" \
  "sister structure" \
  "config-fragment" \
  "hook-script"; do
  name="host-contract.md: documents '$needle'"
  should_run "$name" || continue
  if grep -qiF "$needle" "$CONTRACT_DOC"; then
    pass "$name"
  else
    fail "$name" "contract doc lost its '$needle' section"
  fi
done

# The capability tuple documented in the contract must match emit_capability's
# positional signature in doctor.sh (declared and probed layers stay aligned).
name="host-contract.md: capability tuple matches doctor emit_capability signature"
if should_run "$name"; then
  if grep -qE '<provider> <enforcement> <coverage> <stability> <confidence>' "$REPO_ROOT/scripts/doctor.sh" \
    && printf '%s\n' "${CAPABILITY_FIELDS[@]}" | while read -r f; do grep -qE "\`$f\`" "$CONTRACT_DOC" || exit 1; done; then
    pass "$name"
  else
    fail "$name" "capability tuple drifted between doctor.sh and host-contract.md"
  fi
fi

name="host-contract.md: carries no ticket references"
if should_run "$name"; then
  if grep -qE 'CC-[0-9]+' "$CONTRACT_DOC"; then
    fail "$name" "ticket IDs belong in BACKLOG/DECISIONS, not docs"
  else
    pass "$name"
  fi
fi

th_summary
