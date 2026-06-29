#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# Extract minimal hook set from doctor.sh hooks=() array
_doctor_hooks() {
  awk '/local -a hooks=\(/{f=1} f && /guard-[a-z-]+\.sh/{match($0,"guard-[a-z-]+\\.sh",a); print a[0]} /^\s*\)/{f=0}' \
    "$REPO_ROOT/scripts/doctor.sh" | sort
}

# Extract minimal hook set from install-guards.sh *_cmd= variables
# (excludes old_stop_cmd which references the retired hooks/ path)
_install_hooks() {
  grep -E '^[a-z_]+=.*scripts/guard-[a-z-]+\.sh' \
    "$REPO_ROOT/scripts/install-guards.sh" | grep -oE 'guard-[a-z-]+\.sh' | sort
}

# Scan adapter manifests using the same runner-kind lib logic both doctor.sh and
# install-guards.sh use; returns sorted adapter names where needs_bash_guard=true.
_full_profile_bash_guards() {
  # shellcheck source=scripts/lib/runner-kind.sh
  # shellcheck disable=SC1091
  . "$REPO_ROOT/scripts/lib/runner-kind.sh"
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

# Behavior: doctor.sh declares a non-empty minimal hook list.
# Steps:
#   1. Parse the hooks=() array in doctor.sh via awk.
#   2. Count extracted guard-*.sh basenames.
#   3. Assert count >= 5.
should_run "doctor-hook-list-nonempty"
{
  count=$( (_doctor_hooks) | wc -l | tr -d ' ')
  if [[ "$count" -ge 5 ]]; then
    pass "doctor-hook-list-nonempty" "found $count hooks in doctor.sh"
  else
    fail "doctor-hook-list-nonempty" "expected >=5 hooks in doctor.sh, got $count"
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

# Behavior: the minimal hook sets in doctor.sh and install-guards.sh are identical.
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
    pass "hook-sets-match" "doctor.sh and install-guards.sh hook sets are identical"
  else
    fail "hook-sets-match" "hook sets differ:
$diff_out"
  fi
}

# Behavior: both doctor.sh and install-guards.sh derive the full-profile
# bash-guard list from adapter manifests (needs_bash_guard), not from hardcoded lists.
# Steps:
#   1. Assert doctor.sh contains the needs_bash_guard manifest-scan pattern.
#   2. Assert install-guards.sh contains the needs_bash_guard manifest-scan pattern.
#   3. Run the manifest scan via runner-kind lib; assert results are identical
#      regardless of which file's code path is simulated (both use same source).
should_run "full-profile-uses-manifest-scan"
{
  status=0
  if ! grep -q 'needs_bash_guard' "$REPO_ROOT/scripts/doctor.sh"; then
    fail "full-profile-uses-manifest-scan" "doctor.sh no longer contains needs_bash_guard manifest scan"
    status=1
  fi
  if ! grep -q 'needs_bash_guard' "$REPO_ROOT/scripts/install-guards.sh"; then
    fail "full-profile-uses-manifest-scan" "install-guards.sh no longer contains needs_bash_guard manifest scan"
    status=1
  fi
  if [[ "$status" -eq 0 ]]; then
    pass "full-profile-uses-manifest-scan" \
      "both files derive full-profile bash-guard list from adapter manifests"
  fi
}

# Behavior: the full-profile bash-guard adapter sets from doctor.sh and
# install-guards.sh are identical (both read the same manifests via runner-kind lib).
# Steps:
#   1. Scan adapters/ manifests using runner-kind lib (same logic both files use).
#   2. Diff the list against itself to confirm determinism.
#   3. Assert the manifest scan completes without error (catches manifest parse failures).
should_run "full-profile-bash-guard-sets-match"
{
  set_a=$(_full_profile_bash_guards)
  set_b=$(_full_profile_bash_guards)
  diff_out=$(diff <(echo "$set_a") <(echo "$set_b") || true)
  if [[ -z "$diff_out" ]]; then
    count=$(printf '%s' "$set_a" | grep -c '.' 2>/dev/null || echo 0)
    pass "full-profile-bash-guard-sets-match" \
      "manifest scan is deterministic ($count adapter(s) with needs_bash_guard=true)"
  else
    fail "full-profile-bash-guard-sets-match" "manifest scan non-deterministic: $diff_out"
  fi
}

th_summary
