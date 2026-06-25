#!/usr/bin/env bash
# Single source of truth for pm-dispatch state-store PATH resolution.
#
# These helpers compute WHERE state and run artifacts live for the current
# project partition. They were extracted from state-writer.sh so that
# artifact-relocation callers (dispatch adapters, post-verify, the gate) can
# resolve a run directory through ONE public helper (sw_project_run_dir)
# instead of re-deriving the store-root / project-key layout in each script.
#
# Pure path computation only: nothing here creates, chmods, or locks a
# directory. state-writer.sh owns the mutating side (safety checks, mkdir,
# chmod, JSONL appends) and sources this file for the shared resolvers.

SCRIPT_DIR_SP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project-key hashing needs portable.sh (_portable_canonical_path,
# _portable_sha1). Load it (guarded) so standalone callers work; state-writer.sh
# already loads portable before sourcing this file, so the guard is a no-op
# there. portable.sh sets shell options on source, so preserve the caller's
# flags around the load (mirrors state-writer.sh's portable bootstrap).
if [[ "$(type -t _portable_sha1 2>/dev/null)" != function || "$(type -t _portable_canonical_path 2>/dev/null)" != function ]]; then
  _SP_SHELL_FLAGS="$-"
  _SP_PIPEFAIL=0
  set -o | grep -qE '^pipefail[[:space:]]+on$' && _SP_PIPEFAIL=1
  # shellcheck source=scripts/lib/portable.sh
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR_SP/portable.sh" 2>/dev/null || true
  case "$_SP_SHELL_FLAGS" in *e*) set -e ;; *) set +e ;; esac
  case "$_SP_SHELL_FLAGS" in *u*) set -u ;; *) set +u ;; esac
  case "$_SP_SHELL_FLAGS" in *x*) set -x ;; *) set +x ;; esac
  if [[ "$_SP_PIPEFAIL" -eq 1 ]]; then
    set -o pipefail
  else
    set +o pipefail
  fi
  unset _SP_SHELL_FLAGS _SP_PIPEFAIL
fi

_sw_log_error() {
  {
    local log_dir="${HOME:-}/.claude/logs"
    [[ -n "$log_dir" ]] || return 0
    mkdir -p "$log_dir"
    printf '[%s] %s\n' "$(date -Is 2>/dev/null || date)" "$*" >> "$log_dir/state-writer.err"
  } 2>/dev/null || true
  return 0
}

_sw_store_root() {
  {
    if [[ -n "${PM_DISPATCH_STATE_ROOT:-}" ]]; then
      printf '%s\n' "$PM_DISPATCH_STATE_ROOT"
    elif [[ -n "${XDG_DATA_HOME:-}" ]]; then
      printf '%s\n' "$XDG_DATA_HOME/pm-dispatch/state"
    else
      printf '%s\n' "${HOME:-}/.local/share/pm-dispatch/state"
    fi
  } 2>/dev/null || true
  return 0
}

_sw_project_key() {
  {
    local repo_root project_key
    if [[ -n "${_SW_REPO_ROOT:-}" ]]; then
      # Resolve to git top-level so subdirectory dispatches hash the same key.
      repo_root="$(git -C "${_SW_REPO_ROOT}" rev-parse --show-toplevel 2>/dev/null \
        || printf '%s\n' "${_SW_REPO_ROOT}")"
    elif repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$repo_root" ]]; then
      :
    else
      printf 'global\n'
      return 0
    fi
    # Canonicalize before hashing so the same repo reached via different path
    # spellings (Windows C:/ vs /c/ vs drive-letter case) lands in one partition.
    # POSIX paths are unchanged, so existing keys stay stable.
    repo_root="$(_portable_canonical_path "$repo_root")"
    if ! project_key="$(printf '%s\n' "$repo_root" | _portable_sha1 2>/dev/null)"; then
      _sw_log_error "_sw_project_key: failed to hash repo root; falling back to global: $repo_root"
      project_key=""
    fi
    if [[ -n "$project_key" ]]; then
      printf '%s\n' "$project_key"
    else
      printf 'global\n'
    fi
  } 2>/dev/null || true
  return 0
}

_sw_project_dir() {
  {
    printf '%s/projects/%s/\n' "$(_sw_store_root)" "$(_sw_project_key)"
  } 2>/dev/null || true
  return 0
}

# sw_project_run_dir <run_id>
# Print the absolute run-artifact directory for the current project partition:
#   <store_root>/projects/<project_key>/runs/<run_id>
# (no trailing slash; callers append their own leaf, e.g. /.gate-results).
#
# Pure computation — does NOT create the directory; the mutating layer / caller
# is responsible for mkdir + permissions. This is the seam that later phases
# route gate and dispatch artifacts through, replacing the legacy in-repo
# $WORK_DIR/.agent-trace location. run_id is rejected if it could escape the
# partition (a slash or `..`), so a hostile run id cannot redirect writes.
sw_project_run_dir() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    printf 'state-paths: sw_project_run_dir requires a run_id\n' >&2
    return 1
  fi
  if [[ "$run_id" == */* || "$run_id" == *..* ]]; then
    printf 'state-paths: invalid run_id (no slashes or ".." allowed): %s\n' "$run_id" >&2
    return 1
  fi
  printf '%s/projects/%s/runs/%s\n' "$(_sw_store_root)" "$(_sw_project_key)" "$run_id"
}

# sw_resolve_trace_dir <override> <legacy_default> [work_dir]
# Single source of truth for the dispatch/gate trace-output location and its
# precedence — shared by every adapter and by post-verify so the rule is
# defined and tested ONCE instead of copied per script:
#   explicit <override> (a --trace-dir flag value) > PM_DISPATCH_TRACE_DIR env
#   > <legacy_default> (supplied by the caller; adapters now pass sw_project_run_dir
#     output as the default, so out-of-repo routing is the effective behavior for
#     any installed pm-dispatch; the legacy in-repo path is only reached when
#     sw_project_run_dir is unavailable in the caller).
# An explicit override (flag OR env) MUST be absolute, so the trace location
# never depends on the caller's cwd; a relative explicit value is rejected
# (return 2). The legacy_default argument is emitted verbatim when no override
# or env value is present — callers are responsible for passing the right default.
# Prints the resolved dir.
# When PM_DISPATCH_TRACE_DIR points inside work_dir, a one-time stderr notice
# is emitted to guide migration (guarded by _SW_INREPO_NOTICE_EMITTED).
sw_resolve_trace_dir() {
  local override="${1:-}" legacy_default="${2:-}" work_dir="${3:-}" resolved explicit=0 from_env=0
  if [[ -n "$override" ]]; then
    resolved="$override"; explicit=1
  elif [[ -n "${PM_DISPATCH_TRACE_DIR:-}" ]]; then
    resolved="$PM_DISPATCH_TRACE_DIR"; explicit=1; from_env=1
  else
    resolved="$legacy_default"
  fi
  if [[ "$explicit" -eq 1 && "$resolved" != /* ]]; then
    printf 'state-paths: --trace-dir / PM_DISPATCH_TRACE_DIR must be an absolute path: %s\n' "$resolved" >&2
    return 2
  fi
  # Warn once when PM_DISPATCH_TRACE_DIR points inside the work dir (legacy in-repo pattern)
  if [[ "$from_env" -eq 1 && -n "$work_dir" && "${_SW_INREPO_NOTICE_EMITTED:-0}" -eq 0 ]]; then
    local canonical_work resolved_abs
    canonical_work="$(cd "$work_dir" 2>/dev/null && pwd -P 2>/dev/null || printf '%s' "$work_dir")"
    resolved_abs="$(cd "$(dirname "$resolved")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename "$resolved")" || printf '%s' "$resolved")"
    if [[ -n "$canonical_work" && "$resolved_abs" == "$canonical_work"/* ]]; then
      printf 'pm-dispatch: note: PM_DISPATCH_TRACE_DIR points inside the work dir — artifacts are now routed out-of-repo by default; consider unsetting this variable. See: pmctl artifacts gc --all-repos to clean up in-repo remnants.\n' >&2
      _SW_INREPO_NOTICE_EMITTED=1
    fi
  fi
  printf '%s\n' "$resolved"
}
