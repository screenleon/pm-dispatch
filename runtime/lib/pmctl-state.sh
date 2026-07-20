#!/usr/bin/env bash
# pmctl state subcommands: read-only state-store compatibility introspection.
#
# `pmctl state status` observes the store without mutating it — no mkdir,
# chmod, or VERSION write happens on this path, even against an empty or
# future-version store. Mutation stays with state-writer.sh's init path.

pmctl_state_usage() {
  printf 'usage: pmctl state status [--json] [--cd <work_dir>]\n' >&2
  printf '\n' >&2
  printf 'Reports store root, store layout version vs supported versions, project key,\n' >&2
  printf 'entity schema versions, root safety/writability, and migration availability.\n' >&2
  printf 'Read-only: never creates or repairs the store.\n' >&2
  printf 'Exit codes: 0 = compatible or uninitialized, 3 = incompatible store, 2 = usage error.\n' >&2
}

# Entity schemas whose schema_version participates in the status report.
# Mirrors the schema files layout.yaml binds to store entities.
_PMCTL_STATE_ENTITIES=(run event task review decision context-pack)

_pmctl_state_ensure_libs() {
  local repo_root="${1:-}" lib
  for lib in state-paths state-compat state-writer; do
    if [[ -r "$repo_root/runtime/lib/$lib.sh" ]]; then
      # shellcheck disable=SC1090  # dynamic repo-root path.
      . "$repo_root/runtime/lib/$lib.sh" 2>/dev/null || true
    fi
  done
  if [[ "$(type -t _sw_store_root 2>/dev/null)" != function \
     || "$(type -t sw_layout_version_supported 2>/dev/null)" != function \
     || "$(type -t _sw_store_root_leaf 2>/dev/null)" != function \
     || "$(type -t _sw_store_root_mode_allows_write 2>/dev/null)" != function ]]; then
    printf 'pmctl state: state libraries unavailable (state-paths/state-compat/state-writer)\n' >&2
    return 2
  fi
  return 0
}

# _pmctl_state_root_safety <store_root>
# Read-only variant of the writer's root-safety policy: reports instead of
# repairing. Sets _PMCTL_STATE_SAFE (0/1) and _PMCTL_STATE_SAFE_REASONS.
_pmctl_state_root_safety() {
  local store_root="$1" root_leaf
  _PMCTL_STATE_SAFE=1
  _PMCTL_STATE_SAFE_REASONS=()
  root_leaf="$(_sw_store_root_leaf "$store_root")"
  if [[ -L "$root_leaf" ]]; then
    _PMCTL_STATE_SAFE=0
    _PMCTL_STATE_SAFE_REASONS+=("leaf is a symlink")
  fi
  if [[ -e "$root_leaf" && ! -O "$root_leaf" ]]; then
    _PMCTL_STATE_SAFE=0
    _PMCTL_STATE_SAFE_REASONS+=("not owned by effective user")
  fi
  if [[ -d "$store_root" ]] && _sw_store_root_mode_allows_write "$store_root"; then
    _PMCTL_STATE_SAFE=0
    _PMCTL_STATE_SAFE_REASONS+=("group/world writable")
  fi
  return 0
}

pmctl_state_status() {
  local repo_root="${1:-}"
  shift || true
  local json=0 work_dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json=1; shift ;;
      --cd)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl state: --cd requires a work dir\n' >&2
          return 2
        fi
        work_dir="$2"; shift 2
        ;;
      -h|--help) pmctl_state_usage; return 0 ;;
      *)
        printf 'pmctl state: unknown argument: %s\n' "$1" >&2
        pmctl_state_usage
        return 2
        ;;
    esac
  done
  command -v jq >/dev/null 2>&1 || { printf 'pmctl state: jq is required\n' >&2; return 2; }
  _pmctl_state_ensure_libs "$repo_root" || return 2
  if [[ -n "$work_dir" && ! -d "$work_dir" ]]; then
    printf 'pmctl state: --cd dir not found: %s\n' "$work_dir" >&2
    return 2
  fi

  local store_root version_file store_state observed_version="" project_key
  store_root="$(_sw_store_root)"
  version_file="$store_root/VERSION"
  if [[ ! -e "$store_root" ]]; then
    store_state="uninitialized"
  elif [[ ! -f "$version_file" ]]; then
    # Store dir exists but VERSION was never published — writer treats this as
    # first-time init territory, so status reports it the same way.
    store_state="uninitialized"
  elif ! observed_version="$(<"$version_file")" 2>/dev/null; then
    store_state="unreadable"
  else
    observed_version="${observed_version//[$'\r\n']/}"
    if sw_layout_version_supported "$observed_version"; then
      store_state="compatible"
    else
      store_state="incompatible"
    fi
  fi

  if [[ -n "$work_dir" ]]; then
    project_key="$(_SW_REPO_ROOT="$work_dir" _sw_project_key)"
  else
    project_key="$(_sw_project_key)"
  fi

  _pmctl_state_root_safety "$store_root"
  local writable=0
  [[ -d "$store_root" && -w "$store_root" ]] && writable=1

  # Entity schema versions come from core/schema/*.schema.json — no parallel
  # table here; a schema bump is reflected without touching this file.
  local entity_versions_json entity schema_file
  entity_versions_json="{}"
  for entity in "${_PMCTL_STATE_ENTITIES[@]}"; do
    schema_file="$repo_root/core/schema/$entity.schema.json"
    if [[ -r "$schema_file" ]]; then
      entity_versions_json="$(jq --arg k "$entity" --slurpfile s "$schema_file" \
        '. + {($k): ($s[0].properties.schema_version | if has("const") then [.const] else (.enum // []) end)}' \
        <<< "$entity_versions_json")" || return 2
    else
      entity_versions_json="$(jq --arg k "$entity" '. + {($k): null}' <<< "$entity_versions_json")" || return 2
    fi
  done

  local migration_available=false migration_reason
  case "$store_state" in
    compatible)
      migration_reason="store already at a supported layout version"
      ;;
    uninitialized)
      migration_reason="store not initialized; first write publishes layout version $SW_STORE_LAYOUT_VERSION"
      ;;
    *)
      if [[ -n "$observed_version" ]] && sw_layout_migration_path_exists "$observed_version" "$SW_STORE_LAYOUT_VERSION"; then
        migration_available=true
        migration_reason="migration path $observed_version -> $SW_STORE_LAYOUT_VERSION is available"
      else
        migration_reason="no migration path from layout version ${observed_version:-unknown} to $SW_STORE_LAYOUT_VERSION exists in this build"
      fi
      ;;
  esac

  local supported_json safe_reasons_json
  supported_json="$(printf '%s\n' "${SW_SUPPORTED_LAYOUT_VERSIONS[@]}" | jq -R . | jq -s 'map(tonumber? // .)')"
  if [[ "${#_PMCTL_STATE_SAFE_REASONS[@]}" -gt 0 ]]; then
    safe_reasons_json="$(printf '%s\n' "${_PMCTL_STATE_SAFE_REASONS[@]}" | jq -R . | jq -s .)"
  else
    safe_reasons_json="[]"
  fi

  local report
  report="$(jq -n \
    --arg store_root "$store_root" \
    --arg store_state "$store_state" \
    --arg observed "$observed_version" \
    --argjson supported "$supported_json" \
    --arg current "$SW_STORE_LAYOUT_VERSION" \
    --arg project_key "$project_key" \
    --argjson entities "$entity_versions_json" \
    --argjson writable "$([[ "$writable" -eq 1 ]] && printf 'true' || printf 'false')" \
    --argjson safe_root "$([[ "$_PMCTL_STATE_SAFE" -eq 1 ]] && printf 'true' || printf 'false')" \
    --argjson safe_root_reasons "$safe_reasons_json" \
    --argjson migration_available "$migration_available" \
    --arg migration_reason "$migration_reason" \
    '{
      store_root: $store_root,
      store_state: $store_state,
      store_layout_version: ($observed | if . == "" then null else (tonumber? // .) end),
      supported_layout_versions: $supported,
      current_layout_version: ($current | tonumber),
      project_key: (if $project_key == "global" or $project_key == "" then null else $project_key end),
      entity_schema_versions: $entities,
      writable: $writable,
      safe_root: $safe_root,
      safe_root_reasons: $safe_root_reasons,
      migration: {
        available: $migration_available,
        from: ($observed | if . == "" then null else (tonumber? // .) end),
        to: ($current | tonumber),
        reason: $migration_reason
      }
    }')" || return 2

  if [[ "$json" -eq 1 ]]; then
    printf '%s\n' "$report"
  else
    jq -r '
      "store root:                 \(.store_root)",
      "store state:                \(.store_state)",
      "store layout version:       \(.store_layout_version // "(none)")",
      "supported layout versions:  \(.supported_layout_versions | join(", "))",
      "project key:                \(.project_key // "(not in a git repository)")",
      "entity schema versions:     \(.entity_schema_versions | to_entries | map("\(.key)=\(.value | if . == null then "?" else join(",") end)") | join(" "))",
      "writable:                   \(.writable)",
      "safe root:                  \(.safe_root)\(if (.safe_root_reasons | length) > 0 then " (" + (.safe_root_reasons | join("; ")) + ")" else "" end)",
      "migration available:        \(.migration.available) — \(.migration.reason)"
    ' <<< "$report"
  fi

  [[ "$store_state" == "incompatible" || "$store_state" == "unreadable" ]] && return 3
  return 0
}
