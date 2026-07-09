#!/usr/bin/env bash
# Shared reasoning-effort resolution for adapter dispatch scripts.
#
# pm-dispatch exposes a fixed, executor-agnostic effort vocabulary
# (low|medium|high) at the --effort flag surface — NOT a free-form string —
# so an invalid value is rejected before dispatch, not mid-run inside the
# executor subprocess. Codex and claude both accept these three literal
# values natively (claude's own --effort also has xhigh/max, but pm-dispatch
# does not expose them: codex's `model_reasoning_effort` config key is only
# confirmed to accept low/medium/high, and a vocabulary wider than the
# intersection would let a value dispatch fine on one adapter and reject on
# the other).
#
# Provides re_validate_effort and re_resolve_effort. Both are pure functions
# (no globals mutated beyond the documented RE_RESOLVED_EFFORT output var).

RE_VALID_EFFORTS="low medium high"
# shellcheck disable=SC2034  # output variable read by callers after sourcing this lib
RE_RESOLVED_EFFORT=""

# re_validate_effort <value>
# Returns 0 if value is one of low|medium|high, 1 otherwise. Emits no output —
# callers own the error message so wording matches their own flag name (some
# adapters accept --effort, pr-gate.sh may report it as GATE_EFFORT, etc).
re_validate_effort() {
  local value="$1"
  case " $RE_VALID_EFFORTS " in
    *" $value "*) return 0 ;;
    *) return 1 ;;
  esac
}

# re_resolve_effort <flag_value> <alias_effort> [<global_default>]
# Precedence: flag_value (explicit --effort) > alias_effort (the model alias's
# own effort column, when it is itself a valid low/medium/high value — the
# codex alias table currently pins "high", and older/stale alias columns like
# claude's historical "normal" are simply skipped as invalid) > global_default
# (medium unless overridden). Sets RE_RESOLVED_EFFORT and returns 0 on success;
# returns 1 if flag_value is set but not a valid low/medium/high value (the
# caller must fail dispatch, not silently fall through to a default).
re_resolve_effort() {
  local flag_value="${1:-}" alias_effort="${2:-}" global_default="${3:-medium}"
  RE_RESOLVED_EFFORT=""

  if [[ -n "$flag_value" ]]; then
    re_validate_effort "$flag_value" || return 1
    RE_RESOLVED_EFFORT="$flag_value"
    return 0
  fi

  if [[ -n "$alias_effort" ]] && re_validate_effort "$alias_effort"; then
    RE_RESOLVED_EFFORT="$alias_effort"
    return 0
  fi

  # shellcheck disable=SC2034  # output variable read by callers after sourcing this lib
  RE_RESOLVED_EFFORT="$global_default"
  return 0
}
