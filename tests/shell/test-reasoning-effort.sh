#!/usr/bin/env bash
# Unit tests for runtime/lib/reasoning-effort.sh — re_validate_effort and
# re_resolve_effort (the --effort flag > alias effort > global default
# precedence).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/reasoning-effort.sh"

# ── re_validate_effort ────────────────────────────────────────────────────────

case_re_validate_effort_accepts_low_medium_high() {
  local name="re_validate_effort: accepts low/medium/high"
  should_run "$name" || return 0
  local ok=1
  for v in low medium high; do
    re_validate_effort "$v" || ok=0
  done
  if [[ "$ok" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "expected low/medium/high to all validate"
  fi
}

case_re_validate_effort_rejects_unknown() {
  local name="re_validate_effort: rejects xhigh/max/normal/empty"
  should_run "$name" || return 0
  local ok=1
  for v in xhigh max normal "" bogus; do
    if re_validate_effort "$v"; then ok=0; fi
  done
  if [[ "$ok" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "expected xhigh/max/normal/empty/bogus to all be rejected"
  fi
}

# ── re_resolve_effort precedence ─────────────────────────────────────────────

case_re_resolve_effort_flag_wins() {
  local name="re_resolve_effort: --effort flag overrides alias effort"
  should_run "$name" || return 0
  re_resolve_effort "high" "low"
  if [[ "$RE_RESOLVED_EFFORT" == "high" ]]; then
    pass "$name"
  else
    fail "$name" "expected high, got $RE_RESOLVED_EFFORT"
  fi
}

case_re_resolve_effort_alias_used_when_no_flag() {
  local name="re_resolve_effort: no flag falls back to valid alias effort"
  should_run "$name" || return 0
  re_resolve_effort "" "low"
  if [[ "$RE_RESOLVED_EFFORT" == "low" ]]; then
    pass "$name"
  else
    fail "$name" "expected low, got $RE_RESOLVED_EFFORT"
  fi
}

case_re_resolve_effort_global_default_when_neither() {
  local name="re_resolve_effort: no flag, no alias effort → global default medium"
  should_run "$name" || return 0
  re_resolve_effort "" ""
  if [[ "$RE_RESOLVED_EFFORT" == "medium" ]]; then
    pass "$name"
  else
    fail "$name" "expected medium, got $RE_RESOLVED_EFFORT"
  fi
}

case_re_resolve_effort_invalid_alias_falls_through_to_default() {
  local name="re_resolve_effort: stale/invalid alias effort (e.g. legacy 'normal') falls through to global default"
  should_run "$name" || return 0
  re_resolve_effort "" "normal"
  if [[ "$RE_RESOLVED_EFFORT" == "medium" ]]; then
    pass "$name"
  else
    fail "$name" "expected medium (invalid alias effort ignored), got $RE_RESOLVED_EFFORT"
  fi
}

case_re_resolve_effort_custom_global_default() {
  local name="re_resolve_effort: honors a caller-supplied global default"
  should_run "$name" || return 0
  re_resolve_effort "" "" "high"
  if [[ "$RE_RESOLVED_EFFORT" == "high" ]]; then
    pass "$name"
  else
    fail "$name" "expected high, got $RE_RESOLVED_EFFORT"
  fi
}

case_re_resolve_effort_invalid_flag_fails() {
  local name="re_resolve_effort: invalid --effort flag value returns non-zero"
  should_run "$name" || return 0
  local rc=0
  re_resolve_effort "bogus" "low" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero rc for invalid flag value, got rc=0 RE_RESOLVED_EFFORT=$RE_RESOLVED_EFFORT"
  fi
}

# ── run all ──────────────────────────────────────────────────────────────────

case_re_validate_effort_accepts_low_medium_high
case_re_validate_effort_rejects_unknown
case_re_resolve_effort_flag_wins
case_re_resolve_effort_alias_used_when_no_flag
case_re_resolve_effort_global_default_when_neither
case_re_resolve_effort_invalid_alias_falls_through_to_default
case_re_resolve_effort_custom_global_default
case_re_resolve_effort_invalid_flag_fails

th_summary
