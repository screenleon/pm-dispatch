#!/usr/bin/env bash
# pmctl gate subcommand — routes gate runs through pmctl instead of directly
# calling scripts/pr-gate.sh.  The gate script remains the implementation;
# this shim adds --cd defaulting and keeps the pmctl surface consistent.

pmctl_gate_run() {
  local repo_root="$1"; shift

  local gate_script="$repo_root/scripts/pr-gate.sh"
  if [[ ! -x "$gate_script" ]]; then
    printf 'pmctl gate run: gate script not found or not executable: %s\n' "$gate_script" >&2
    return 2
  fi

  # If caller omits --cd, default to the current working directory so the
  # gate always has a working directory without forcing callers to spell it out.
  local has_cd=false
  for arg in "$@"; do
    [[ "$arg" == "--cd" ]] && { has_cd=true; break; }
  done

  if [[ "$has_cd" == false ]]; then
    exec "$gate_script" --cd "$PWD" "$@"
  else
    exec "$gate_script" "$@"
  fi
}
