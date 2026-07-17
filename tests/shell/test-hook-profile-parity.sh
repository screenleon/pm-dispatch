#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Doctor's claude-host module owns the hooks=() inventory (doctor.sh core is
# host-agnostic and dispatches into lib/doctor-host-*.sh modules).
DOCTOR_HOST_CLAUDE="$REPO_ROOT/hosts/claude/lib/doctor.sh"
INSTALL_GUARDS_CLAUDE="$REPO_ROOT/hosts/claude/bin/install-guards.sh"

# Extract minimal hook set from the claude-host module's hooks=() array
# (POSIX awk, no GNU extensions)
_doctor_hooks() {
  awk '/local -a hooks=\(/{f=1} f{if(/^[[:space:]]*\)/) f=0; else print}' \
    "$DOCTOR_HOST_CLAUDE" | grep -oE '(guard-[a-z-]+|log-usage|save-rate-limits)\.sh' | sort
}

# Extract minimal hook set from install-guards.sh *_cmd= variables
# (excludes old_stop_cmd which references the retired hooks/ path)
_install_hooks() {
  grep -E '^(pm_cmd|stop_cmd|session_path|inject_cmd|ctx_inject_cmd|statusline_cmd)=' \
    "$INSTALL_GUARDS_CLAUDE" | grep -oE '(guard-[a-z-]+|log-usage|save-rate-limits)\.sh' | sort
}

# Simulates doctor.sh check_hooks(): adapter names from manifests where
# needs_bash_guard resolves to true (manifest-only check, no file existence).
_doctor_full_guards() {
  # shellcheck source=runtime/lib/runner-kind.sh
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/runner-kind.sh"
  local _manifest _adapter_name _rk _nbg_override _nbg
  for _manifest in "$REPO_ROOT"/adapters/*/adapter.yaml; do
    [[ -f "$_manifest" ]] || continue
    _adapter_name="$(basename "$(dirname "$_manifest")")"
    _rk="$(runner_kind_manifest_field "$_manifest" runner_kind)"
    [[ -n "$_rk" ]] || continue
    _nbg_override="$(runner_kind_manifest_field "$_manifest" needs_bash_guard)"
    _nbg="$(runner_kind_resolve_flag "$_rk" needs_bash_guard "$_nbg_override")"
    if [[ "$_nbg" == "true" ]]; then printf '%s\n' "$_adapter_name"; fi
  done | sort
}

# Simulates install-guards.sh: adapter names where needs_bash_guard=true AND
# bash-guard.sh exists and is executable in the adapter directory.
_install_full_guards() {
  # shellcheck source=runtime/lib/runner-kind.sh
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/runner-kind.sh"
  local _manifest _adapter_dir _adapter_name _rk _nbg_override _nbg _guard_file
  for _manifest in "$REPO_ROOT"/adapters/*/adapter.yaml; do
    [[ -f "$_manifest" ]] || continue
    _adapter_dir="$(dirname "$_manifest")"
    _adapter_name="$(basename "$_adapter_dir")"
    _rk="$(runner_kind_manifest_field "$_manifest" runner_kind)"
    [[ -n "$_rk" ]] || continue
    _nbg_override="$(runner_kind_manifest_field "$_manifest" needs_bash_guard)"
    _nbg="$(runner_kind_resolve_flag "$_rk" needs_bash_guard "$_nbg_override")"
    if [[ "$_nbg" == "true" ]]; then
      _guard_file="$_adapter_dir/bash-guard.sh"
      if [[ -x "$_guard_file" ]]; then printf '%s\n' "$_adapter_name"; fi
    fi
  done | sort
}

# Behavior: doctor's claude-host module declares a non-empty minimal hook list.
# Steps:
#   1. Parse the hooks=() array in lib/doctor-host-claude.sh via POSIX awk + grep.
#   2. Count extracted guard-*.sh basenames.
#   3. Assert count >= 5.
should_run "doctor-hook-list-nonempty"
{
  count=$( (_doctor_hooks) | wc -l | tr -d ' ')
  if [[ "$count" -ge 5 ]]; then
    pass "doctor-hook-list-nonempty" "found $count hooks in doctor-host-claude.sh"
  else
    fail "doctor-hook-list-nonempty" "expected >=5 hooks in doctor-host-claude.sh, got $count"
  fi
}

# Behavior: install-guards.sh declares a non-empty minimal hook list.
# Steps:
#   1. Parse *_cmd= lines referencing scripts/guard-*.sh in install-guards.sh.
#   2. Count extracted guard-*.sh basenames.
#   3. Assert count >= 5.
should_run "install-guards-hook-list-nonempty"
{
  count=$( (_install_hooks) | wc -l | tr -d ' ')
  if [[ "$count" -ge 5 ]]; then
    pass "install-guards-hook-list-nonempty" "found $count hooks in install-guards.sh"
  else
    fail "install-guards-hook-list-nonempty" "expected >=5 hooks in install-guards.sh, got $count"
  fi
}

# Behavior: the minimal hook sets in doctor's claude-host module and
# install-guards.sh are identical.
# Steps:
#   1. Extract sorted hook lists from both files.
#   2. Diff the two lists.
#   3. Assert no diff output (sets are equal).
should_run "hook-sets-match"
{
  doctor_list=$(_doctor_hooks)
  install_list=$(_install_hooks)
  diff_out=$(diff <(echo "$doctor_list") <(echo "$install_list") || true)
  if [[ -z "$diff_out" ]]; then
    pass "hook-sets-match" "doctor-host-claude.sh and install-guards.sh hook sets are identical"
  else
    fail "hook-sets-match" "hook sets differ:
$diff_out"
  fi
}

# Behavior: both doctor's claude-host module and install-guards.sh derive the
# full-profile bash-guard list from adapter manifests (needs_bash_guard), not
# from hardcoded lists.
# Steps:
#   1. Assert lib/doctor-host-claude.sh contains the needs_bash_guard manifest-scan pattern.
#   2. Assert install-guards.sh contains the needs_bash_guard manifest-scan pattern.
should_run "full-profile-uses-manifest-scan"
{
  status=0
  if ! grep -q 'needs_bash_guard' "$DOCTOR_HOST_CLAUDE"; then
    fail "full-profile-uses-manifest-scan" "doctor-host-claude.sh no longer contains needs_bash_guard manifest scan"
    status=1
  fi
  if ! grep -q 'needs_bash_guard' "$INSTALL_GUARDS_CLAUDE"; then
    fail "full-profile-uses-manifest-scan" "install-guards.sh no longer contains needs_bash_guard manifest scan"
    status=1
  fi
  if [[ "$status" -eq 0 ]]; then
    pass "full-profile-uses-manifest-scan" \
      "both files derive full-profile bash-guard list from adapter manifests"
  fi
}

# Behavior: doctor.sh's manifest-derived full-profile adapter set matches
# install-guards.sh's set (adapters with needs_bash_guard=true must also have
# bash-guard.sh present, otherwise doctor and installer disagree on the full profile).
# Steps:
#   1. Extract doctor.sh's set: adapter names where needs_bash_guard=true (manifest only).
#   2. Extract install-guards.sh's set: adapter names where needs_bash_guard=true AND
#      bash-guard.sh exists and is executable in the adapter directory.
#   3. Diff the two sets; assert no diff (catches missing bash-guard.sh files).
should_run "full-profile-bash-guard-sets-match"
{
  doctor_full=$(_doctor_full_guards)
  install_full=$(_install_full_guards)
  diff_out=$(diff <(echo "$doctor_full") <(echo "$install_full") || true)
  if [[ -z "$diff_out" ]]; then
    count=$(printf '%s' "$doctor_full" | wc -l | tr -d ' ')
    pass "full-profile-bash-guard-sets-match" \
      "doctor and install-guards agree on full-profile bash guards ($count adapter(s))"
  else
    fail "full-profile-bash-guard-sets-match" \
      "doctor/install-guards full-profile sets differ (missing bash-guard.sh?):
$diff_out"
  fi
}

th_summary
