#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/timeout-resolve.sh"
th_init "$@"

assert_timeout() {
  local name="$1" expected="$2"
  if [[ "$TR_RESOLVED_TIMEOUT" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "expected=$expected actual=$TR_RESOLVED_TIMEOUT"
  fi
}

# case: flag_val non-empty wins over everything
if should_run "flag_val_wins"; then
  PM_CFG_TIMEOUT="900" MYENV="800" tr_resolve_timeout "42" "MYENV" "PM_CFG_TIMEOUT" "1200"
  assert_timeout "flag_val_wins" "42"
fi

# case: flag_val empty, env var set → env var wins
if should_run "env_var_wins"; then
  unset PM_CFG_TIMEOUT || true
  CDENV="600" tr_resolve_timeout "" "CDENV" "PM_CFG_TIMEOUT" "1200"
  assert_timeout "env_var_wins" "600"
fi

# case: flag empty, env unset, config key set → config wins
if should_run "config_key_wins"; then
  unset NOPE || true
  PM_CFG_TIMEOUT="300" tr_resolve_timeout "" "NOPE" "PM_CFG_TIMEOUT" "1200"
  assert_timeout "config_key_wins" "300"
fi

# case: all empty/unset → default
if should_run "default_wins"; then
  unset NOPE PM_CFG_TIMEOUT || true
  tr_resolve_timeout "" "NOPE" "PM_CFG_TIMEOUT" "1200"
  assert_timeout "default_wins" "1200"
fi

# case: config_key="" skips config layer even when PM_CFG_TIMEOUT is set
if should_run "empty_config_key_skips_config"; then
  unset NOPE || true
  PM_CFG_TIMEOUT="900" tr_resolve_timeout "" "NOPE" "" "300"
  assert_timeout "empty_config_key_skips_config" "300"
fi

# case: flag_val empty string (not unset) still treated as empty
if should_run "flag_empty_string_falls_through"; then
  unset PM_CFG_TIMEOUT || true
  MYENV2="750" tr_resolve_timeout "" "MYENV2" "" "1200"
  assert_timeout "flag_empty_string_falls_through" "750"
fi

th_summary
