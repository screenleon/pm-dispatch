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

  # Compute an out-of-repo run dir via sw_project_run_dir (state-paths seam).
  # Guarded source: load only if sw_project_run_dir is not already declared.
  local gate_run_dir=""
  local _sp_lib="$repo_root/scripts/lib/state-paths.sh"
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function && -r "$_sp_lib" ]]; then
    # shellcheck disable=SC1090,SC1091
    . "$_sp_lib" 2>/dev/null || true
  fi
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]]; then
    local _gate_ts; _gate_ts="$(date +%Y%m%d-%H%M%S)"
    local _gate_run_id="gate-${_gate_ts}-$$"
    gate_run_dir="$(sw_project_run_dir "$_gate_run_id" 2>/dev/null)" || gate_run_dir=""
  fi

  local run_dir_args=()
  if [[ -n "$gate_run_dir" ]]; then
    run_dir_args=(--run-dir "$gate_run_dir")
  fi

  if [[ "$has_cd" == false ]]; then
    exec "$gate_script" "${run_dir_args[@]}" --cd "$PWD" "$@"
  else
    exec "$gate_script" "${run_dir_args[@]}" "$@"
  fi
}

# pmctl gate verify <result_file>
# Confirm a gate result file is structurally complete using the SAME contract
# the synchronous gate route enforces in-process (gate_result_verify). This is
# how an out-of-process gate result -- one written outside pr-gate.sh's own
# in-process check -- becomes confirmable/trackable via pmctl, symmetric to the
# codex route's built-in post-dispatch check. Exit 0 = valid; 1 = invalid (diagnostic on stderr);
# 2 = usage/library error.
pmctl_gate_verify() {
  local repo_root="$1"; shift

  if [[ $# -ne 1 || -z "${1:-}" ]]; then
    printf 'pmctl gate verify: usage: pmctl gate verify <result_file>\n' >&2
    return 2
  fi
  local result_file="$1"

  if ! declare -F gate_result_verify >/dev/null; then
    local lib="$repo_root/scripts/lib/gate-result-verify.sh"
    if [[ ! -r "$lib" ]]; then
      printf 'pmctl gate verify: required library not found: %s\n' "$lib" >&2
      return 2
    fi
    # shellcheck source=scripts/lib/gate-result-verify.sh
    . "$lib"
  fi

  if gate_result_verify "$result_file"; then
    printf 'gate result OK: %s\n' "$result_file"
    return 0
  fi
  return 1
}
