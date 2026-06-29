#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/test-harness.sh
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

# Behavior: doctor.sh declares a non-empty minimal hook list.
# Steps:
#   1. Parse the hooks=() array in doctor.sh via awk.
#   2. Count extracted guard-*.sh basenames.
#   3. Assert count >= 5.
should_run "doctor-hook-list-nonempty"
{
  count=$((_doctor_hooks) | wc -l | tr -d ' ')
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
  count=$((_install_hooks) | wc -l | tr -d ' ')
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

th_summary
