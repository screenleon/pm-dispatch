#!/usr/bin/env bash
# Generic reader for hosts/<name>/host.yaml (schema v1, docs/host-contract.md).
#
# Consumed by install.sh/uninstall.sh/doctor.sh so target facts and optional
# write-module paths come from the manifest, not host-named core branches.
# Host-specific format judgment remains inside the declared modules; the
# shared dispatcher only selects and invokes them symmetrically.
# Deliberately grep/awk-based (no YAML parser dependency), mirroring the
# block-extraction approach scripts/test-host-manifest.sh and
# doctor-host-claude.sh already use for the same file shape.
#
# Functions:
#   host_manifest_names                      -> one host name per line (dirs under hosts/ with a host.yaml)
#   host_manifest_file <name>                 -> prints hosts/<name>/host.yaml path (may not exist)
#   host_manifest_scalar <file> <key>         -> top-level scalar field value (e.g. host_binary, doctor_module)
#   host_manifest_module_path <repo_root> <host> <key>
#                                             -> validates and prints one declared repo module path
#   host_manifest_install_targets <file>      -> TSV rows: id\tpath\tformat\tmanaged (one per install_targets entry)
#   host_manifest_expand_path <repo_root> <host> <path_template>
#                                             -> delegates expansion to the host-owned resolver

host_manifest_names() {
  local repo_root="$1" dir name
  for dir in "$repo_root"/hosts/*/; do
    [[ -f "${dir}host.yaml" ]] || continue
    name="${dir%/}"
    name="${name##*/}"
    printf '%s\n' "$name"
  done
}

host_manifest_file() {
  local repo_root="$1" name="$2"
  printf '%s/hosts/%s/host.yaml\n' "$repo_root" "$name"
}

# Top-level scalar field only (not list/map fields) — same restriction
# doctor-host-claude.sh's manifest_field helper has for guard_bindings entries.
host_manifest_scalar() {
  local file="$1" key="$2" line value
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$key:"* ]] || continue
    value="${line#"$key:"}"
    value="${value%%#*}"
    while [[ "$value" == [[:space:]]* ]]; do value="${value#?}"; done
    while [[ "$value" == *[[:space:]] ]]; do value="${value%?}"; done
    [[ "$value" == \"* ]] && value="${value#\"}"
    [[ "$value" == *\" ]] && value="${value%\"}"
    printf '%s\n' "$value"
    return 0
  done < "$file"
  return 0
}

# Resolve sourceable/executable repo modules through one fail-closed contract.
# Callers retain ownership of entrypoint validation and invocation semantics.
host_manifest_module_path() {
  local repo_root="$1" host="$2" key="$3" manifest module
  [[ "$host" =~ ^[a-z0-9_-]+$ ]] || {
    printf 'host manifest: unsafe host name: %s\n' "$host" >&2
    return 2
  }
  manifest="$(host_manifest_file "$repo_root" "$host")"
  [[ -f "$manifest" ]] || {
    printf 'host manifest: unknown host: %s\n' "$host" >&2
    return 2
  }
  module="$(host_manifest_scalar "$manifest" "$key")"
  [[ -n "$module" && "$module" != "null" ]] || {
    printf 'host manifest: %s has no %s\n' "$host" "$key" >&2
    return 2
  }
  case "$module" in
    /*|../*|*/../*|*/..)
      printf 'host manifest: unsafe %s path for %s: %s\n' "$key" "$host" "$module" >&2
      return 2
      ;;
  esac
  [[ -f "$repo_root/$module" ]] || {
    printf 'host manifest: %s path for %s does not exist: %s\n' "$key" "$host" "$module" >&2
    return 2
  }
  printf '%s\n' "$repo_root/$module"
}

host_manifest_install_targets() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  awk '
    /^install_targets:/ { insec=1; next }
    insec && /^[a-zA-Z_]+:/ && $0 !~ /^[[:space:]]/ { insec=0 }
    insec && /^[[:space:]]*-[[:space:]]*id:/ {
      if (id != "") printf "%s\t%s\t%s\t%s\n", id, path, fmt, managed
      id=$0; sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", id); sub(/[[:space:]]*#.*$/, "", id)
      path=""; fmt=""; managed=""
      next
    }
    insec && /^[[:space:]]+path:/ {
      v=$0; sub(/^[[:space:]]+path:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v); gsub(/^"|"$/, "", v); path=v; next
    }
    insec && /^[[:space:]]+format:/ {
      v=$0; sub(/^[[:space:]]+format:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v); fmt=v; next
    }
    insec && /^[[:space:]]+managed:/ {
      v=$0; sub(/^[[:space:]]+managed:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v); managed=v; next
    }
    END { if (id != "") printf "%s\t%s\t%s\t%s\n", id, path, fmt, managed }
  ' "$file"
}

# Manifest-driven delegation keeps host environment names, defaults, aliases,
# and conflict rules out of this shared reader. Resolver modules are trusted
# repo files declared by authored manifests; both their path and callable name
# are validated before sourcing/invocation. Manifest data never reaches eval.
host_manifest_expand_path() {
  local repo_root="$1" host="$2" path="$3"
  local manifest module_path resolver
  manifest="$(host_manifest_file "$repo_root" "$host")"
  module_path="$(host_manifest_module_path "$repo_root" "$host" path_resolver_module)" || return $?
  resolver="$(host_manifest_scalar "$manifest" path_resolver_function)"
  [[ "$resolver" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || {
    printf 'host manifest: unsafe path_resolver_function for %s: %s\n' "$host" "$resolver" >&2
    return 2
  }
  # shellcheck disable=SC1090
  . "$module_path"
  declare -F "$resolver" >/dev/null 2>&1 || {
    printf 'host manifest: path resolver function for %s is not defined: %s\n' "$host" "$resolver" >&2
    return 2
  }
  "$resolver" "$path"
}
