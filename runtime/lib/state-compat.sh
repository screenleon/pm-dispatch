#!/usr/bin/env bash
# Store-layout compatibility surface for the pm-dispatch state store.
#
# Single source of truth for:
#   - the store-layout version this build writes (SW_STORE_LAYOUT_VERSION)
#   - which on-disk layout versions this build can operate on
#   - the migration registry: which layout migration paths actually exist
#
# Naming contract: "store layout version" ($STORE/VERSION, layout.yaml
# store_layout_version) describes the on-disk directory/file layout of the
# whole store. It is distinct from the per-entity "schema_version" fields
# carried by Run/Event/Task/... rows (declared in core/schema/*.schema.json).
# This file owns only the former.

SW_STORE_LAYOUT_VERSION=1
SW_SUPPORTED_LAYOUT_VERSIONS=(1)

# Migration registry: one "from:to" entry per implemented, runnable layout
# migration. Empty until a real migration ships — an empty registry is what
# keeps remediation text honest (no command is recommended unless a runnable
# path exists).
SW_LAYOUT_MIGRATIONS=()

# sw_layout_version_supported <version>
# True when this build can operate on a store with the given layout version.
sw_layout_version_supported() {
  local v="${1:-}" s
  [[ -n "$v" ]] || return 1
  for s in "${SW_SUPPORTED_LAYOUT_VERSIONS[@]}"; do
    [[ "$v" == "$s" ]] && return 0
  done
  return 1
}

# sw_layout_migration_path_exists <from> [to]
# True when the registry contains a runnable migration path from <from> to
# <to> (defaults to the current layout version).
sw_layout_migration_path_exists() {
  local from="${1:-}" to="${2:-$SW_STORE_LAYOUT_VERSION}" m
  [[ -n "$from" ]] || return 1
  for m in ${SW_LAYOUT_MIGRATIONS[@]+"${SW_LAYOUT_MIGRATIONS[@]}"}; do
    [[ "$m" == "$from:$to" ]] && return 0
  done
  return 1
}

# sw_layout_remediation <found_version>
# Print the user-facing remediation for an unsupported store layout version.
# Names a command only when the registry actually has a runnable path.
sw_layout_remediation() {
  local found="${1:-unknown}"
  if sw_layout_migration_path_exists "$found" "$SW_STORE_LAYOUT_VERSION"; then
    printf "run 'pmctl state migrate' to migrate the store from layout version %s to %s\n" \
      "$found" "$SW_STORE_LAYOUT_VERSION"
  else
    printf 'no migration path from store layout version %s to %s exists in this build; inspect with '\''pmctl state status'\'' and use a pm-dispatch build that supports layout version %s\n' \
      "$found" "$SW_STORE_LAYOUT_VERSION" "$found"
  fi
}
