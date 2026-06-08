#!/usr/bin/env bash
# Shared workspace-root detection for install-hooks.sh / uninstall-hooks.sh.
#
# gate_workspace_root <repo_root> <home>
#   Prints the workspace root used for the reviewer permissions Write glob.
#   Order of precedence:
#     1. PM_DISPATCH_GATE_WORKSPACE — use verbatim (central-checkout installs)
#     2. PM_DISPATCH_GATE_GIT_ROOT — inject git root; empty = simulate git failure (tests)
#     3. git -C <repo_root> rev-parse --show-toplevel → dirname; falls back to <home>
#        if the parent equals <home> or "/" (HOME fallback, non-git tarball installs)
gate_workspace_root() {
  local repo_root="$1"
  local home="$2"
  if [[ -n "${PM_DISPATCH_GATE_WORKSPACE:-}" ]]; then
    printf '%s' "$PM_DISPATCH_GATE_WORKSPACE"
    return
  fi
  local git_root ws
  if [[ -n "${PM_DISPATCH_GATE_GIT_ROOT+x}" ]]; then
    git_root="${PM_DISPATCH_GATE_GIT_ROOT}"
  else
    git_root="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null)" || true
  fi
  if [[ -n "$git_root" ]]; then
    ws="$(dirname "$git_root")"
    if [[ "$ws" == "$home" || "$ws" == "/" ]]; then
      ws="$home"
    fi
  else
    ws="$home"
  fi
  printf '%s' "$ws"
}
