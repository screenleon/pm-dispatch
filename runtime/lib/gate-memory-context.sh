#!/usr/bin/env bash
# Canonical-memory hydration for shared gate/runtime consumers.
# Source this file; public entrypoint: gate_memory_context_hydrate.

_GATE_MEMORY_LIB_DIR="${BASH_SOURCE[0]%/*}"
[[ "$_GATE_MEMORY_LIB_DIR" == "${BASH_SOURCE[0]}" ]] && _GATE_MEMORY_LIB_DIR=.

if ! declare -F pmctl_memory_resolve >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/pmctl-memory.sh
  # shellcheck disable=SC1091
  . "$_GATE_MEMORY_LIB_DIR/pmctl-memory.sh"
fi
if ! declare -F pmctl_context_pack >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/pmctl-context.sh
  # shellcheck disable=SC1091
  . "$_GATE_MEMORY_LIB_DIR/pmctl-context.sh"
fi

# Resolve and query canonical memory without crossing back through cli/pmctl.
# Globals are reset on every call so a long-lived caller cannot reuse stale
# provenance. Exit 0 covers resolved memory and the expected no-memory state;
# invalid explicit selection and unexpected resolver/query failures are closed.
# shellcheck disable=SC2034 # public sourced-library outputs consumed by pr-gate.sh
gate_memory_context_hydrate() {
  local work_dir="$1" query="${2:-PR gate review}"
  local resolution="" resolution_rc=0 context="" context_rc=0 context_bytes

  GATE_MEMORY_STATUS="unavailable"
  GATE_MEMORY_SOURCE="none"
  GATE_MEMORY_PROJECT_KEY=""
  GATE_MEMORY_CONTEXT_STATUS="unavailable"
  GATE_MEMORY_CONTEXT=""

  if resolution="$(pmctl_memory_resolve --repo-root "$work_dir" --json 2>/dev/null)"; then
    resolution_rc=0
  else
    resolution_rc=$?
  fi
  if [[ -n "$resolution" ]] && ! jq -e 'type == "object"' <<<"$resolution" >/dev/null 2>&1; then
    printf 'gate memory: resolver returned invalid JSON\n' >&2
    return 1
  fi

  # Resolver contract: 0=resolved result (whose status is validated below),
  # 1=expected no-memory result, 3=invalid explicit selection (fail closed),
  # and every other exit is an unexpected failure (also fail closed).
  case "$resolution_rc" in
    0)
      GATE_MEMORY_STATUS="$(jq -r '.status // "resolved"' <<<"$resolution")"
      GATE_MEMORY_SOURCE="$(jq -r '.resolution_source // "none"' <<<"$resolution")"
      GATE_MEMORY_PROJECT_KEY="$(jq -r '.project_key // ""' <<<"$resolution")"
      if [[ "$GATE_MEMORY_STATUS" != "resolved" ]]; then
        printf 'gate memory: resolver succeeded with unexpected status: %s\n' "$GATE_MEMORY_STATUS" >&2
        return 1
      fi
      if context="$(pmctl_context_pack "$work_dir" --task-id pr-gate-review --source memory --query "$query" 2>/dev/null)"; then
        context_rc=0
      else
        context_rc=$?
      fi
      if [[ "$context_rc" -ne 0 ]]; then
        printf 'gate memory: canonical context query failed (exit %s)\n' "$context_rc" >&2
        return 1
      fi
      if ! jq -e 'type == "object"' <<<"$context" >/dev/null 2>&1; then
        printf 'gate memory: context query returned invalid JSON\n' >&2
        return 1
      fi
      context_bytes="$(printf '%s' "$context" | wc -c | tr -d '[:space:]')"
      if [[ "$context_bytes" =~ ^[0-9]+$ ]] && (( context_bytes <= 6000 )); then
        GATE_MEMORY_CONTEXT="$context"
        GATE_MEMORY_CONTEXT_STATUS="hydrated"
      else
        GATE_MEMORY_CONTEXT_STATUS="over-budget"
      fi
      ;;
    1)
      # No configured/discoverable memory is an expected portable state.
      if [[ -n "$resolution" ]]; then
        GATE_MEMORY_STATUS="$(jq -r '.status // "unavailable"' <<<"$resolution")"
        GATE_MEMORY_SOURCE="$(jq -r '.resolution_source // "none"' <<<"$resolution")"
        GATE_MEMORY_PROJECT_KEY="$(jq -r '.project_key // ""' <<<"$resolution")"
      fi
      ;;
    3)
      printf 'gate memory: canonical memory selection is invalid; refusing host-local fallback\n' >&2
      return 3
      ;;
    *)
      printf 'gate memory: canonical memory resolution failed unexpectedly (exit %s)\n' "$resolution_rc" >&2
      return 1
      ;;
  esac
}
