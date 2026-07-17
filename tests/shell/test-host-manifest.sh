#!/usr/bin/env bash
# Structural tests for hosts/*/host.yaml manifests and docs/host-contract.md.
#
# Validates every host manifest against the schema v1 contract: required
# top-level keys, per-entry fields and closed enum values for install_targets
# and guard_bindings, hook_surface shape, permissions_surface referential
# integrity, and the unsupported-capability consistency rule. Negative cases
# mutate a copy of a real manifest and assert the validator rejects each
# plausible invalid shape, so the contract cannot silently loosen. Also
# asserts the contract doc keeps its load-bearing clauses and that the
# capability tuple stays field-aligned with doctor.sh's emit_capability.
#
# Runs via: tests/shell/test-host-manifest.sh
# Filter:   tests/shell/test-host-manifest.sh --filter <pattern>
# List:     tests/shell/test-host-manifest.sh --list

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
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
  path_resolver_module
  path_resolver_function
  uninstall_module
)

# Capability object fields that must ride on every guard_bindings entry,
# aligned verbatim with doctor.sh emit_capability's tuple.
CAPABILITY_FIELDS=(provider enforcement coverage stability confidence)

# Closed enums (docs/host-contract.md). Space-separated membership strings.
ENUM_FORMAT="claude-settings-json codex-hooks-json codex-config-toml codex-agents-md opencode-config-json markdown-managed-block symlink-tree copy-tree"
ENUM_CAPABILITY="command_guard file_guard session_lifecycle pm_command_interface statusline"
ENUM_BINDING_FORM="hook-script config-fragment none"
ENUM_PROVIDER="host_hook host_policy host_native cli_wrapper doc_instruction none"
ENUM_ENFORCEMENT="blocking approval advisory none"
ENUM_COVERAGE="full partial none"
ENUM_STABILITY="stable evolving"
ENUM_CONFIDENCE="observed probed declared assumed"
ENUM_PAYLOAD_FIELD="command cwd file_path"
# Schema versions this validator knows how to check.
KNOWN_SCHEMA_VERSIONS="1"

in_enum() {
  # in_enum <value> <space-separated allowed values>
  local v="$1" allowed=" $2 "
  [[ "$allowed" == *" $v "* ]]
}

section() {
  # section <file> <top-level key>: print the key's line and its indented block.
  awk -v key="$2" '
    $0 ~ "^" key ":" { found=1; print; next }
    found && /^[a-z_]/ { exit }
    found { print }
  ' "$1"
}

key_value() {
  # key_value <text-on-stdin?> — helper via args: key_value <file-fragment-var> <key>
  # Extract the first "key: value" at any indent from the given text.
  printf '%s\n' "$1" | grep -E "^[[:space:]]*(- )?$2:" | head -1 \
    | sed -E "s/^[[:space:]]*(- )?$2:[[:space:]]*//;s/[[:space:]]*#.*$//;s/^\"//;s/\"$//"
}

count_in() {
  # count_in <text> <key>: occurrences of "key:" at list-item or nested depth.
  printf '%s\n' "$1" | grep -cE "^[[:space:]]*(- )?$2:" || true
}

# validate_manifest <file> <expected host_name>
# Prints one violation per line; prints nothing for a valid manifest.
validate_manifest() {
  local manifest="$1" host_dir="$2"

  [[ -s "$manifest" ]] || { echo "empty manifest"; return; }
  if grep -Pq '^\t' "$manifest"; then
    echo "tab indentation (YAML requires spaces)"
  fi

  local key
  for key in "${REQUIRED_KEYS[@]}"; do
    grep -qE "^$key:" "$manifest" || echo "missing top-level key: $key"
  done

  grep -qE '^schema_version:[[:space:]]*[1-9][0-9]*[[:space:]]*(#.*)?$' "$manifest" \
    || echo "schema_version is not a bare positive integer"
  local sv
  sv="$(grep -E '^schema_version:' "$manifest" | head -1 | sed 's/^schema_version:[[:space:]]*//;s/[[:space:]]*#.*$//')"
  if [[ -n "$sv" ]] && ! in_enum "$sv" "$KNOWN_SCHEMA_VERSIONS"; then
    echo "schema_version '$sv' is not a known version (validator supports: $KNOWN_SCHEMA_VERSIONS)"
  fi

  local host_name
  host_name="$(grep -E '^host_name:' "$manifest" | head -1 | sed 's/^host_name:[[:space:]]*//;s/[[:space:]]*#.*$//')"
  [[ "$host_name" == "$host_dir" ]] || echo "host_name '$host_name' != directory '$host_dir'"

  local host_binary
  host_binary="$(grep -E '^host_binary:' "$manifest" | head -1 | sed 's/^host_binary:[[:space:]]*//;s/[[:space:]]*#.*$//')"
  [[ -n "$host_binary" ]] || echo "host_binary is empty"

  # --- install_targets: per-entry fields + closed format enum ---------------
  local targets id_count f_count
  targets="$(section "$manifest" install_targets)"
  id_count="$(count_in "$targets" id)"
  if [[ "$id_count" -lt 1 ]]; then
    echo "install_targets has no entries with id:"
  fi
  for key in path format managed; do
    f_count="$(count_in "$targets" "$key")"
    [[ "$f_count" -eq "$id_count" ]] \
      || echo "install_targets: $key count ($f_count) != id count ($id_count)"
  done
  local v
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    in_enum "$v" "$ENUM_FORMAT" || echo "install_targets: format '$v' not in closed enum"
  done < <(printf '%s\n' "$targets" | grep -E '^[[:space:]]*(- )?format:' | sed -E 's/^[[:space:]]*(- )?format:[[:space:]]*//;s/[[:space:]]*#.*$//')
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    [[ "$v" == "true" || "$v" == "false" ]] || echo "install_targets: managed '$v' is not a boolean"
  done < <(printf '%s\n' "$targets" | grep -E '^[[:space:]]*(- )?managed:' | sed -E 's/^[[:space:]]*(- )?managed:[[:space:]]*//;s/[[:space:]]*#.*$//')
  # ids must be unique: permissions_surface.config_target (and any future
  # cross-reference) resolves by id, so a duplicate is ambiguous.
  local dup_ids
  dup_ids="$(printf '%s\n' "$targets" | grep -E '^[[:space:]]*(- )?id:' | sed -E 's/^[[:space:]]*(- )?id:[[:space:]]*//;s/[[:space:]]*#.*$//' | sort | uniq -d | tr '\n' ' ')"
  [[ -z "${dup_ids// /}" ]] || echo "install_targets: duplicate id: $dup_ids"
  # Paths must be anchored to the host's home env var, never a hard-coded
  # user directory (contract design rule: no maintainer-local layout).
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    [[ "$v" == \$* ]] || echo "install_targets: path '$v' is not anchored to a host home env var"
  done < <(printf '%s\n' "$targets" | grep -E '^[[:space:]]*(- )?path:' | sed -E 's/^[[:space:]]*(- )?path:[[:space:]]*//;s/[[:space:]]*#.*$//;s/^"//;s/"$//')

  # --- hook_surface: empty map, or config_format + events required ----------
  local hooks
  hooks="$(section "$manifest" hook_surface)"
  if ! printf '%s\n' "$hooks" | head -1 | grep -qE '^hook_surface:[[:space:]]*\{\}[[:space:]]*(#.*)?$'; then
    printf '%s\n' "$hooks" | grep -qE '^[[:space:]]+config_format:' \
      || echo "hook_surface: non-empty but missing config_format"
    printf '%s\n' "$hooks" | grep -qE '^[[:space:]]+events:' \
      || echo "hook_surface: non-empty but missing events"
    v="$(key_value "$hooks" config_format)"
    if [[ -n "$v" ]]; then
      in_enum "$v" "$ENUM_FORMAT" || echo "hook_surface: config_format '$v' not in closed enum"
    fi
    # headless_required_flags entries, when declared, must be CLI flags —
    # dispatch paths pass them verbatim to the host binary.
    while IFS= read -r v; do
      [[ -z "$v" ]] && continue
      [[ "$v" == -* ]] || echo "hook_surface: headless_required_flags entry '$v' is not a flag"
    done < <(printf '%s\n' "$hooks" | awk '
      /^[[:space:]]*headless_required_flags:/ { f=1; next }
      f && /^[[:space:]]*- /   { sub(/^[[:space:]]*- /, ""); sub(/[[:space:]]*#.*$/, ""); print; next }
      f && /[^[:space:]]/ && !/^[[:space:]]*#/ { f=0 }
    ')
  fi

  # --- guard_bindings: tuple completeness + closed enums + none rule --------
  local bindings cap_count
  bindings="$(section "$manifest" guard_bindings)"
  cap_count="$(count_in "$bindings" capability)"
  [[ "$cap_count" -ge 1 ]] || echo "guard_bindings has no capability entries"
  # Full-enumeration rule: every capability in the closed enum must appear
  # exactly once; an omission is a validation error, never a semantic
  # statement, and a duplicate is a validation error, never a refinement.
  local cap cap_n
  for cap in $ENUM_CAPABILITY; do
    cap_n="$(printf '%s\n' "$bindings" | grep -cE "^[[:space:]]*-[[:space:]]*capability:[[:space:]]*$cap([[:space:]]|#|$)" || true)"
    if [[ "$cap_n" -eq 0 ]]; then
      echo "guard_bindings: capability $cap missing (full enumeration required)"
    elif [[ "$cap_n" -gt 1 ]]; then
      echo "guard_bindings: capability $cap declared $cap_n times (exactly once required)"
    fi
  done
  for key in binding_form "${CAPABILITY_FIELDS[@]}"; do
    f_count="$(count_in "$bindings" "$key")"
    [[ "$f_count" -eq "$cap_count" ]] \
      || echo "guard_bindings: $key count ($f_count) != capability count ($cap_count)"
  done
  local field allowed
  for field in capability binding_form "${CAPABILITY_FIELDS[@]}"; do
    case "$field" in
      capability)   allowed="$ENUM_CAPABILITY" ;;
      binding_form) allowed="$ENUM_BINDING_FORM" ;;
      provider)     allowed="$ENUM_PROVIDER" ;;
      enforcement)  allowed="$ENUM_ENFORCEMENT" ;;
      coverage)     allowed="$ENUM_COVERAGE" ;;
      stability)    allowed="$ENUM_STABILITY" ;;
      confidence)   allowed="$ENUM_CONFIDENCE" ;;
    esac
    while IFS= read -r v; do
      [[ -z "$v" ]] && continue
      in_enum "$v" "$allowed" || echo "guard_bindings: $field '$v' not in closed enum"
    done < <(printf '%s\n' "$bindings" | grep -E "^[[:space:]]*(- )?$field:" | sed -E "s/^[[:space:]]*(- )?$field:[[:space:]]*//;s/[[:space:]]*#.*$//")
  done
  # Per-entry consistency rules:
  #   provider none => enforcement none AND coverage none (unsupported rule);
  #   binding_form none => provider none or cli_wrapper (no installed host artifact).
  printf '%s\n' "$bindings" | sed -E 's/[[:space:]]+#.*$//' | awk '
    function flush() {
      if (cap == "") return
      if (prov == "none" && (enf != "none" || cov != "none"))
        print "guard_bindings: capability " cap " declares provider none but enforcement/coverage not none"
      if (bf == "none" && prov != "none" && prov != "cli_wrapper")
        print "guard_bindings: capability " cap " declares binding_form none but provider is neither none nor cli_wrapper"
    }
    /^[[:space:]]*- capability:/ { flush(); cap=$NF; bf=""; prov=""; enf=""; cov="" }
    /^[[:space:]]*(- )?binding_form:/ { bf=$NF }
    /^[[:space:]]*(- )?provider:/     { prov=$NF }
    /^[[:space:]]*(- )?enforcement:/  { enf=$NF }
    /^[[:space:]]*(- )?coverage:/     { cov=$NF }
    END { flush() }
  '

  # --- guard_bindings: payload_fields keys are a closed set ------------------
  # payload_fields maps guard-check inputs to host payload paths; an unknown
  # key would silently declare an input pmctl guard check cannot consume.
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    in_enum "$v" "$ENUM_PAYLOAD_FIELD" || echo "guard_bindings: payload_fields key '$v' not in closed enum"
  done < <(printf '%s\n' "$bindings" | awk '
    function ind(s) { match(s, /[^ ]/); return RSTART }
    /^[[:space:]]*payload_fields:/ { f=1; base=ind($0); next }
    f {
      if ($0 !~ /[^[:space:]]/ || ind($0) <= base) { f=0 }
      else if ($0 !~ /^[[:space:]]*#/) { k=$1; sub(/:.*/, "", k); print k }
    }
  ')

  # --- permissions_surface: config_target reference + managed boolean --------
  local perms target
  perms="$(section "$manifest" permissions_surface)"
  target="$(key_value "$perms" config_target)"
  if [[ -n "$target" ]]; then
    printf '%s\n' "$targets" | grep -qE "^[[:space:]]*(- )?id:[[:space:]]*$target([[:space:]]|#|$)" \
      || echo "permissions_surface: config_target '$target' does not reference an install_targets id"
  fi
  v="$(key_value "$perms" managed)"
  if [[ -z "$v" ]]; then
    echo "permissions_surface: managed is missing"
  elif [[ "$v" != "true" && "$v" != "false" ]]; then
    echo "permissions_surface: managed '$v' is not a boolean"
  fi

  # --- doctor_module must exist ----------------------------------------------
  local module
  module="$(grep -E '^doctor_module:' "$manifest" | head -1 | sed 's/^doctor_module:[[:space:]]*//;s/[[:space:]]*#.*$//')"
  if [[ -z "$module" ]]; then
    echo "doctor_module is empty"
  elif [[ ! -f "$REPO_ROOT/$module" ]]; then
    echo "doctor_module '$module' not found under repo root"
  fi

  # --- path resolver module/function must be safe and callable ---------------
  module="$(grep -E '^path_resolver_module:' "$manifest" | head -1 | sed 's/^path_resolver_module:[[:space:]]*//;s/[[:space:]]*#.*$//')"
  local resolver
  resolver="$(grep -E '^path_resolver_function:' "$manifest" | head -1 | sed 's/^path_resolver_function:[[:space:]]*//;s/[[:space:]]*#.*$//')"
  if [[ -z "$module" ]]; then
    echo "path_resolver_module is empty"
  elif [[ "$module" == /* || "$module" == ../* || "$module" == */../* || "$module" == */.. ]]; then
    echo "path_resolver_module '$module' is not a safe repo-relative path"
  elif [[ ! -f "$REPO_ROOT/$module" ]]; then
    echo "path_resolver_module '$module' not found under repo root"
  fi
  if [[ ! "$resolver" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "path_resolver_function '$resolver' is not a safe shell function identifier"
  elif [[ -f "$REPO_ROOT/$module" ]]; then
    # shellcheck disable=SC1090
    . "$REPO_ROOT/$module"
    declare -F "$resolver" >/dev/null 2>&1 \
      || echo "path_resolver_function '$resolver' not found in '$module'"
  fi

  # --- write modules must be null or existing repo-relative files ------------
  local module_key
  for module_key in install_module uninstall_module; do
    module="$(grep -E "^$module_key:" "$manifest" | head -1 | sed "s/^$module_key:[[:space:]]*//;s/[[:space:]]*#.*$//")"
    if [[ -z "$module" ]]; then
      echo "$module_key is empty (must be null or an existing repo-relative path)"
    elif [[ "$module" != "null" && ! -f "$REPO_ROOT/$module" ]]; then
      echo "$module_key '$module' not found under repo root (must be null or an existing repo-relative path)"
    fi
  done
  module="$(grep -E '^memory_update_module:' "$manifest" | head -1 | sed 's/^memory_update_module:[[:space:]]*//;s/[[:space:]]*#.*$//' || true)"
  if [[ -n "$module" && "$module" != "null" && ! -f "$REPO_ROOT/$module" ]]; then
    echo "memory_update_module '$module' not found under repo root"
  fi

  # --- operational files carry no ticket references ---------------------------
  if grep -qE 'CC-[0-9]+' "$manifest"; then
    echo "manifest contains ticket references"
  fi
}

# --- positive cases: every real manifest validates cleanly -------------------

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
  [[ -f "$manifest" ]] || continue
  host_dir="$(basename "$(dirname "$manifest")")"
  name="hosts/$host_dir: manifest validates against schema v1 contract"
  should_run "$name" || continue
  violations="$(validate_manifest "$manifest" "$host_dir")"
  if [[ -z "$violations" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '%s' "$violations" | tr '\n' '; ')"
  fi
done

# --- negative cases: plausible invalid mutations must be rejected ------------
# Each case: <case name> | <sed mutation applied to a copy of the codex
# manifest> | <substring the validator must report>.

REF_MANIFEST="$REPO_ROOT/hosts/codex/host.yaml"
tmp_root="$(mktemp -d /tmp/test-host-manifest-XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

run_negative_case() {
  local case_name="$1" mutation="$2" expected="$3"
  local name="negative: $case_name is rejected"
  should_run "$name" || return 0
  local mutated="$tmp_root/host.yaml"
  sed -E "$mutation" "$REF_MANIFEST" > "$mutated"
  if cmp -s "$REF_MANIFEST" "$mutated"; then
    fail "$name" "mutation did not change the fixture (sed: $mutation)"
    return 0
  fi
  local violations
  violations="$(validate_manifest "$mutated" codex)"
  if [[ "$violations" == *"$expected"* ]]; then
    pass "$name"
  else
    fail "$name" "expected violation containing '$expected', got: $(printf '%s' "$violations" | tr '\n' '; ')"
  fi
}

# run_negative_case_on <ref_manifest> <host_dir> <case_name> <sed_mutation> <expected_substring>
# Same shape as run_negative_case, but against an arbitrary manifest/host_dir
# pair — used to exercise field combinations unique to a specific host (e.g.
# claude's symlink-tree install targets, host_native/config-fragment
# pm_command_interface binding, non-null uninstall_module) rather than
# re-mutating the codex fixture for every enum.
run_negative_case_on() {
  local ref_manifest="$1" host_dir="$2" case_name="$3" mutation="$4" expected="$5"
  local name="negative ($host_dir): $case_name is rejected"
  should_run "$name" || return 0
  local mutated="$tmp_root/host-$host_dir.yaml"
  sed -E "$mutation" "$ref_manifest" > "$mutated"
  if cmp -s "$ref_manifest" "$mutated"; then
    fail "$name" "mutation did not change the fixture (sed: $mutation)"
    return 0
  fi
  local violations
  violations="$(validate_manifest "$mutated" "$host_dir")"
  if [[ "$violations" == *"$expected"* ]]; then
    pass "$name"
  else
    fail "$name" "expected violation containing '$expected', got: $(printf '%s' "$violations" | tr '\n' '; ')"
  fi
}

run_negative_case "missing top-level guard_bindings" \
  's/^guard_bindings:/guard_bindingz:/' \
  "missing top-level key: guard_bindings"
run_negative_case "non-integer schema_version" \
  's/^schema_version:.*/schema_version: one/' \
  "schema_version is not a bare positive integer"
run_negative_case "host_name mismatch" \
  's/^host_name:.*/host_name: kodex/' \
  "host_name 'kodex' != directory 'codex'"
run_negative_case "install target missing managed field" \
  's/^([[:space:]]+)managed: true.*/\1managet: true/' \
  "install_targets: managed count"
run_negative_case "install target format outside closed enum" \
  's/format: codex-hooks-json/format: codex-hooks-yaml/' \
  "format 'codex-hooks-yaml' not in closed enum"
run_negative_case "install target managed not boolean" \
  's/managed: true([[:space:]]*#.*)?$/managed: yes/' \
  "managed 'yes' is not a boolean"
run_negative_case "hook_surface missing events" \
  's/^([[:space:]]+)events:/\1eventz:/' \
  "hook_surface: non-empty but missing events"
run_negative_case "hook_surface config_format outside closed enum" \
  's/config_format: codex-hooks-json/config_format: codex-toml/' \
  "config_format 'codex-toml' not in closed enum"
run_negative_case "guard binding missing confidence" \
  's/^([[:space:]]+)confidence:/\1confidenze:/' \
  "guard_bindings: confidence count"
run_negative_case "guard binding capability outside closed enum" \
  's/capability: file_guard/capability: write_guard/' \
  "capability 'write_guard' not in closed enum"
run_negative_case "guard binding binding_form outside closed enum" \
  's/binding_form: hook-script/binding_form: hook-json/g' \
  "binding_form 'hook-json' not in closed enum"
run_negative_case "guard binding provider outside closed enum" \
  's/provider: host_hook/provider: native_hook/' \
  "provider 'native_hook' not in closed enum"
run_negative_case "guard binding enforcement outside closed enum" \
  's/enforcement: blocking/enforcement: block/' \
  "enforcement 'block' not in closed enum"
run_negative_case "guard binding coverage outside closed enum" \
  's/coverage: full/coverage: complete/' \
  "coverage 'complete' not in closed enum"
run_negative_case "guard binding stability outside closed enum" \
  's/stability: evolving/stability: beta/g' \
  "stability 'beta' not in closed enum"
run_negative_case "guard binding confidence outside closed enum" \
  's/confidence: probed/confidence: guessed/g' \
  "confidence 'guessed' not in closed enum"
run_negative_case "capability missing from full enumeration" \
  's/capability: statusline/capability: command_guard/' \
  "capability statusline missing (full enumeration required)"
run_negative_case "binding_form none with non-none provider" \
  's/^([[:space:]]+)provider: none/\1provider: host_hook/' \
  "declares binding_form none but provider is neither none nor cli_wrapper"
run_negative_case "provider none with non-none coverage" \
  's/^([[:space:]]+)coverage: none/\1coverage: partial/' \
  "declares provider none but enforcement/coverage not none"
run_negative_case "permissions config_target referencing unknown id" \
  's/config_target: config/config_target: settings/' \
  "config_target 'settings' does not reference an install_targets id"
run_negative_case "doctor_module pointing at missing file" \
  's|^doctor_module:.*|doctor_module: scripts/lib/doctor-host-missing.sh|' \
  "doctor_module 'scripts/lib/doctor-host-missing.sh' not found"
run_negative_case "path_resolver_module pointing at missing file" \
  's|^path_resolver_module:.*|path_resolver_module: hosts/codex/lib/missing-resolver.sh|' \
  "path_resolver_module 'hosts/codex/lib/missing-resolver.sh' not found"
run_negative_case "path_resolver_function unsafe identifier" \
  's|^path_resolver_function:.*|path_resolver_function: codex-resolve;touch|' \
  "path_resolver_function 'codex-resolve;touch' is not a safe shell function identifier"
run_negative_case "uninstall_module non-null pointing at missing file" \
  's|^uninstall_module:.*|uninstall_module: scripts/lib/uninstall-host-missing.sh|' \
  "uninstall_module 'scripts/lib/uninstall-host-missing.sh' not found"
run_negative_case "unknown schema_version" \
  's/^schema_version:.*/schema_version: 2/' \
  "schema_version '2' is not a known version"
run_negative_case "empty host_binary" \
  's/^host_binary:.*/host_binary:/' \
  "host_binary is empty"
run_negative_case "duplicate install_targets id" \
  's/^([[:space:]]+- )id: config/\1id: hooks/' \
  "install_targets: duplicate id: hooks"
# shellcheck disable=SC2016  # sed pattern matches the literal $CODEX_HOME token in the manifest, no expansion wanted
run_negative_case "install target path not env-var anchored" \
  's|path: "\$CODEX_HOME/hooks.json"|path: "/home/user/.codex/hooks.json"|' \
  "path '/home/user/.codex/hooks.json' is not anchored to a host home env var"
run_negative_case "headless_required_flags entry not a flag" \
  's/- --dangerously-bypass-hook-trust/- dangerously-bypass-hook-trust/' \
  "headless_required_flags entry 'dangerously-bypass-hook-trust' is not a flag"
run_negative_case "payload_fields key outside closed set" \
  's/^([[:space:]]+)command: tool_input.command/\1kommand: tool_input.command/' \
  "payload_fields key 'kommand' not in closed enum"
run_negative_case "permissions_surface missing managed" \
  's/^([[:space:]]+)managed: false$/\1managet: false/' \
  "permissions_surface: managed is missing"
run_negative_case "permissions_surface managed not boolean" \
  's/^([[:space:]]+)managed: false$/\1managed: nope/' \
  "permissions_surface: managed 'nope' is not a boolean"
run_negative_case "empty doctor_module" \
  's|^doctor_module:.*|doctor_module:|' \
  "doctor_module is empty"
run_negative_case "empty uninstall_module" \
  's|^uninstall_module:.*|uninstall_module:|' \
  "uninstall_module is empty"
run_negative_case "ticket reference in manifest" \
  's/^host_binary: codex/host_binary: codex # CC-999/' \
  "manifest contains ticket references"

# --- claude-specific field-combination negative cases -----------------------
# Claude carries the symlink-tree targets and host_native/config-fragment PM
# binding; mutate those unique combinations directly.

REF_MANIFEST_CLAUDE="$REPO_ROOT/hosts/claude/host.yaml"

run_negative_case_on "$REF_MANIFEST_CLAUDE" claude \
  "install target format symlink-tree outside closed enum" \
  's/format: symlink-tree/format: file-tree/' \
  "format 'file-tree' not in closed enum"
run_negative_case_on "$REF_MANIFEST_CLAUDE" claude \
  "pm_command_interface provider host_native outside closed enum" \
  's/provider: host_native/provider: host_original/' \
  "provider 'host_original' not in closed enum"
run_negative_case_on "$REF_MANIFEST_CLAUDE" claude \
  "permissions_surface config_target referencing unknown id" \
  's/config_target: settings/config_target: config/' \
  "config_target 'config' does not reference an install_targets id"
run_negative_case_on "$REF_MANIFEST_CLAUDE" claude \
  "non-null install_module pointing at missing file" \
  's|^install_module:.*|install_module: install-missing.sh|' \
  "install_module 'install-missing.sh' not found"

# Duplicate-capability case: all five capabilities stay present and every
# entry keeps a complete field tuple, so the ONLY violation is the
# exactly-once rule. A sed one-liner cannot insert a full entry block, hence
# the bespoke awk mutation instead of run_negative_case.
name="negative: duplicate capability entry is rejected"
if should_run "$name"; then
  mutated="$tmp_root/host-dup.yaml"
  awk '
    /^permissions_surface:/ && !done {
      print "  - capability: statusline"
      print "    binding_form: none"
      print "    provider: none"
      print "    enforcement: none"
      print "    coverage: none"
      print "    stability: evolving"
      print "    confidence: assumed"
      done=1
    }
    { print }
  ' "$REF_MANIFEST" > "$mutated"
  violations="$(validate_manifest "$mutated" codex)"
  if [[ "$violations" != *"capability statusline declared 2 times (exactly once required)"* ]]; then
    fail "$name" "expected duplicate-capability violation, got: $(printf '%s' "$violations" | tr '\n' '; ')"
  elif [[ "$(printf '%s\n' "$violations" | grep -c .)" -ne 1 ]]; then
    fail "$name" "expected the duplicate violation to be the only finding, got: $(printf '%s' "$violations" | tr '\n' '; ')"
  else
    pass "$name"
  fi
fi

# --- contract doc -------------------------------------------------------------

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

# Every closed-enum value the validator enforces must be documented in the
# contract doc, so the doc and the test cannot drift apart silently.
for enum_list in "$ENUM_FORMAT" "$ENUM_CAPABILITY" "$ENUM_BINDING_FORM" "$ENUM_PROVIDER" "$ENUM_ENFORCEMENT" "$ENUM_COVERAGE" "$ENUM_STABILITY" "$ENUM_CONFIDENCE" "$ENUM_PAYLOAD_FIELD"; do
  for v in $enum_list; do
    name="host-contract.md: documents enum value '$v'"
    should_run "$name" || continue
    if grep -qF "$v" "$CONTRACT_DOC"; then
      pass "$name"
    else
      fail "$name" "enum value '$v' enforced by the validator but absent from the contract doc"
    fi
  done
done

# The capability tuple documented in the contract must match emit_capability's
# positional signature in doctor.sh (declared and probed layers stay aligned).
name="host-contract.md: capability tuple matches doctor emit_capability signature"
if should_run "$name"; then
  tuple_ok=1
  grep -qE '<provider> <enforcement> <coverage> <stability> <confidence>' "$REPO_ROOT/runtime/bin/doctor.sh" || tuple_ok=0
  for f in "${CAPABILITY_FIELDS[@]}"; do
    grep -qE "\`$f\`" "$CONTRACT_DOC" || tuple_ok=0
  done
  if [[ "$tuple_ok" -eq 1 ]]; then
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
