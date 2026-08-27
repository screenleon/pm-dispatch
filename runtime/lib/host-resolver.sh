#!/usr/bin/env bash
# Parameterised config-root resolver for hosts whose rule is the single
# "primary env var, else $HOME/<subdir>" shape.
#
# Extracted from the byte-identical bodies of codex/grok/opencode
# *_host_config_root. The host name only ever arrives as a caller-supplied
# literal label used for the diagnostic message — this file never branches on
# it. Hosts with a genuinely different rule (Claude: canonical/legacy dual var
# with a disagreement error) keep their own resolver and do not call this.
#
# Functions:
#   host_simple_config_root <label> <primary_env_name> <default_subdir>
#     -> prints the resolved root, or exits 2 with a labelled diagnostic when
#        the primary env var is unset/empty and HOME is also unavailable.

host_simple_config_root() {
  local label="$1" primary_env_name="$2" default_subdir="$3"
  local root="${!primary_env_name:-}"

  if [[ -z "$root" ]]; then
    if [[ -n "${HOME:-}" ]]; then
      root="$HOME/$default_subdir"
    else
      printf '%s path resolver: HOME is required when %s is unset or empty\n' \
        "$label" "$primary_env_name" >&2
      return 2
    fi
  fi

  printf '%s\n' "$root"
}
