#!/usr/bin/env bash
# Manifest-driven dispatcher for independently opt-in host write modules.
# Core callers select a host; module paths and lifecycle symmetry come only
# from hosts/<name>/host.yaml.

_host_write_module() {
  local repo_root="$1" host="$2" key="$3"
  case "$repo_root" in
    /*) ;;
    *) printf 'host write: repo root must be absolute: %s\n' "$repo_root" >&2; return 2 ;;
  esac
  repo_root="$(cd "$repo_root" 2>/dev/null && pwd -P)" || {
    printf 'host write: repo root does not exist: %s\n' "$repo_root" >&2
    return 2
  }
  host_manifest_module_path "$repo_root" "$host" "$key"
}

host_write_install() {
  local repo_root="$1" host="$2" dry_run="${3:-0}" module
  module="$(_host_write_module "$repo_root" "$host" install_module)" || return $?
  if [[ "$dry_run" -eq 1 ]]; then
    bash "$module" --repo-root "$repo_root" --dry-run
  else
    bash "$module" --repo-root "$repo_root"
  fi
}

host_write_uninstall_all() {
  local repo_root="$1" dry_run="${2:-0}" host manifest install_module module
  while IFS= read -r host; do
    manifest="$(host_manifest_file "$repo_root" "$host")"
    install_module="$(host_manifest_scalar "$manifest" install_module)"
    [[ -n "$install_module" && "$install_module" != "null" ]] || continue
    module="$(_host_write_module "$repo_root" "$host" uninstall_module)" || return $?
    if [[ "$dry_run" -eq 1 ]]; then
      bash "$module" --repo-root "$repo_root" --dry-run
    else
      bash "$module" --repo-root "$repo_root"
    fi
  done < <(host_manifest_names "$repo_root")
}
