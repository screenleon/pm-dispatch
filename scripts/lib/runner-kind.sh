#!/usr/bin/env bash
# Sourceable runner-kind derivation helpers.
#
# An adapter's runner-kind is the single declared primitive that classifies how
# pm-dispatch reaches the executor. Three execution-topology flags are derived
# from it:
#
#   dispatch_route    how the dispatch flow invokes the adapter
#   write_guard_mode  whether the brief-write guard is a live PreToolUse hook or
#                     a CLI-only check backing `pmctl guard check`
#   needs_bash_guard  whether a bash-command guard wraps the executor
#
# Source of truth for the mapping lives ONLY here, so router (dispatch side),
# guard wrappers, and install wiring read one table instead of re-encoding the
# topology three times.
#
# This file declares the mapping and a resolver; it does NOT change any router
# or guard behavior — consumers are wired separately. Adding a runner-kind is a
# single edit to runner_kind_valid + the two derivation case statements.
#
# Runner-kinds:
#   cli-subprocess  thin dispatch into a subprocess executor; the dispatcher
#                   runs on the main thread and is hook-gated (e.g. codex).
#   host-native     the executor IS the running host and self-executes its own
#                   edits, gated by the host harness (e.g. claude-as-host).
#
# Per-flag override: a manifest may set dispatch_route / write_guard_mode /
# needs_bash_guard explicitly to deviate from its runner-kind default. The
# resolver honors a non-empty override over the default. This is the seam that
# keeps genuine asymmetries declarable rather than inferred — e.g. a future
# cli-subprocess adapter that does not need the bash guard declares
# needs_bash_guard: false without any core edit.

runner_kind_valid() {
  case "${1-}" in
    cli-subprocess|host-native) return 0 ;;
    *) return 1 ;;
  esac
}

# runner_kind_default_flag <runner_kind> <flag>
# Prints the runner-kind default for one derived flag. The ONLY place the
# topology mapping is encoded. Exit 2 on an unknown runner-kind or flag.
runner_kind_default_flag() {
  local runner_kind=${1-} flag=${2-}

  [[ $# -eq 2 ]] || {
    printf 'runner-kind: runner_kind_default_flag expects <runner_kind> <flag>\n' >&2
    return 2
  }
  runner_kind_valid "$runner_kind" || {
    printf 'runner-kind: unknown runner_kind: %s (expected cli-subprocess or host-native)\n' "$runner_kind" >&2
    return 2
  }

  case "$flag" in
    dispatch_route)
      case "$runner_kind" in
        cli-subprocess) printf 'main_thread_bash_background\n' ;;
        host-native)    printf 'agent_executor\n' ;;
      esac
      ;;
    write_guard_mode)
      case "$runner_kind" in
        cli-subprocess) printf 'hook\n' ;;
        host-native)    printf 'cli-only\n' ;;
      esac
      ;;
    needs_bash_guard)
      case "$runner_kind" in
        cli-subprocess) printf 'true\n' ;;
        host-native)    printf 'false\n' ;;
      esac
      ;;
    *)
      printf 'runner-kind: unknown derived flag: %s (expected dispatch_route, write_guard_mode, or needs_bash_guard)\n' "$flag" >&2
      return 2
      ;;
  esac
}

# runner_kind_resolve_flag <runner_kind> <flag> [override]
# Prints the effective flag value: the override when non-empty, else the
# runner-kind default. An override must be empty or a valid value for that flag;
# an invalid non-empty override is rejected (exit 2).
runner_kind_resolve_flag() {
  local runner_kind=${1-} flag=${2-} override=${3-}

  [[ $# -eq 2 || $# -eq 3 ]] || {
    printf 'runner-kind: runner_kind_resolve_flag expects <runner_kind> <flag> [override]\n' >&2
    return 2
  }

  if [[ -z "$override" ]]; then
    runner_kind_default_flag "$runner_kind" "$flag"
    return
  fi

  # Validate the override against the flag's value domain.
  case "$flag" in
    dispatch_route)
      case "$override" in
        main_thread_bash_background|agent_executor) : ;;
        *)
          printf 'runner-kind: invalid dispatch_route override: %s\n' "$override" >&2
          return 2
          ;;
      esac
      ;;
    write_guard_mode)
      case "$override" in
        hook|cli-only) : ;;
        *)
          printf 'runner-kind: invalid write_guard_mode override: %s\n' "$override" >&2
          return 2
          ;;
      esac
      ;;
    needs_bash_guard)
      case "$override" in
        true|false) : ;;
        *)
          printf 'runner-kind: invalid needs_bash_guard override: %s\n' "$override" >&2
          return 2
          ;;
      esac
      ;;
    *)
      printf 'runner-kind: unknown derived flag: %s\n' "$flag" >&2
      return 2
      ;;
  esac

  printf '%s\n' "$override"
}

# runner_kind_detach_eligible <runner_kind>
# Decides whether an adapter of this runner-kind may run under a detached
# supervisor (CC-391 lifecycle axis). DERIVED from the declared runner-kind, not
# a manifest field: a cli-subprocess executor is a Model B subprocess pmctl can
# reparent under a supervisor; a host-native executor IS the running host and
# cannot be handed to an external supervisor. Returns 0 (eligible), 1 (not
# eligible), or 2 (unknown runner-kind — caller should fail closed).
runner_kind_detach_eligible() {
  case "${1-}" in
    cli-subprocess) return 0 ;;
    host-native)    return 1 ;;
    *)              return 2 ;;
  esac
}

# runner_kind_manifest_field <adapter.yaml> <key>
# Reads one top-level flat scalar from an adapter manifest. Tolerant of inline
# `# comments` and surrounding quotes; prints nothing (exit 0) when the key is
# absent so callers can fall back to a derived default. Bash+grep only — no YAML
# parser dependency (manifests are flat key: value, matching pmctl-policy.sh's
# list-only constraint).
runner_kind_manifest_field() {
  local file=${1-} key=${2-} line value

  [[ $# -eq 2 ]] || {
    printf 'runner-kind: runner_kind_manifest_field expects <file> <key>\n' >&2
    return 2
  }
  [[ -r "$file" ]] || {
    printf 'runner-kind: cannot read manifest: %s\n' "$file" >&2
    return 2
  }

  line="$(grep -m1 -E "^${key}:[[:space:]]" "$file" 2>/dev/null || true)"
  [[ -n "$line" ]] || return 0

  value="${line#"${key}":}"
  value="${value%%#*}"                       # strip inline comment
  value="${value#"${value%%[![:space:]]*}"}" # ltrim
  value="${value%"${value##*[![:space:]]}"}" # rtrim
  value="${value#\"}"; value="${value%\"}"   # strip double quotes
  value="${value#\'}"; value="${value%\'}"   # strip single quotes
  printf '%s\n' "$value"
}

export -f runner_kind_valid
export -f runner_kind_default_flag
export -f runner_kind_resolve_flag
export -f runner_kind_detach_eligible
export -f runner_kind_manifest_field
