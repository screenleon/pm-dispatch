#!/usr/bin/env bash
# Canonical Gate deployment-layout resolver.
#
# This is intentionally source-safe: sourcing it defines functions only. The
# entrypoint calls gate_layout_resolve once, before loading any other Gate
# library, and all later library/policy paths come from the resulting roots.

gate_layout_resolve() {
  local entrypoint="${1:-}"
  local physical_entrypoint script_dir parent_dir

  [[ -n "$entrypoint" ]] || return 2
  physical_entrypoint="$entrypoint"
  while [[ -L "$physical_entrypoint" ]]; do
    local link_dir link_target
    link_dir="$(cd "$(dirname "$physical_entrypoint")" && pwd)" || return 2
    link_target="$(readlink "$physical_entrypoint")" || return 2
    [[ "$link_target" == /* ]] || link_target="$link_dir/$link_target"
    physical_entrypoint="$link_target"
  done
  script_dir="$(cd "$(dirname "$physical_entrypoint")" && pwd -P)" || return 2

  PR_GATE_SCRIPT_DIR="$script_dir"
  PR_GATE_LAYOUT="standalone-copy"
  PR_GATE_BUNDLE_ROOT="$script_dir"
  PR_GATE_EXECUTOR_ROOT="$script_dir"
  PR_GATE_LIB_DIR="$script_dir/lib"
  PR_GATE_POLICY_DIR="$script_dir/core/policy"
  PR_GATE_INSTALLED_COPY_ROOT=""

  if [[ "${script_dir##*/}" == scripts ]]; then
    PR_GATE_LAYOUT="installed-copy"
    parent_dir="$(cd "$script_dir/.." && pwd -P)" || return 2
    PR_GATE_INSTALLED_COPY_ROOT="$parent_dir"
    PR_GATE_BUNDLE_ROOT="$parent_dir"
    PR_GATE_EXECUTOR_ROOT="$parent_dir"
    PR_GATE_LIB_DIR="$script_dir/lib"
    PR_GATE_POLICY_DIR="$script_dir/core/policy"
  elif [[ "${script_dir##*/}" == bin \
      && "${script_dir%/*}" != "$script_dir" \
      && "${script_dir%/*}" == */runtime ]]; then
    PR_GATE_LAYOUT="repo"
    PR_GATE_BUNDLE_ROOT="$(cd "$script_dir/../.." && pwd -P)" || return 2
    PR_GATE_EXECUTOR_ROOT="$PR_GATE_BUNDLE_ROOT"
    PR_GATE_LIB_DIR="$script_dir/../lib"
    PR_GATE_POLICY_DIR="$PR_GATE_BUNDLE_ROOT/core/policy"
  fi

  export PR_GATE_SCRIPT_DIR PR_GATE_LAYOUT PR_GATE_BUNDLE_ROOT
  export PR_GATE_EXECUTOR_ROOT PR_GATE_LIB_DIR PR_GATE_POLICY_DIR
  export PR_GATE_INSTALLED_COPY_ROOT
}

gate_layout_policy_file() {
  local filename="${1:-}"
  [[ -n "$filename" ]] || return 2
  printf '%s/%s\n' "${PR_GATE_POLICY_DIR:?}" "$filename"
}
