#!/usr/bin/env bash
# Sourceable executor routing helpers for adapter dispatch callers.
#
# Routing is DATA-DRIVEN: the dispatch allowlist and per-executor route
# are derived from on-disk adapter manifests (adapters/<name>/adapter.yaml), not a
# hardcoded codex|claude enum. An executor is routable iff its adapter directory
# carries a readable, non-symlink manifest declaring a valid runner_kind. Adding
# an adapter is therefore "drop adapters/<name>/ with a valid manifest" — no edit
# to this file is required.
#
# No shell options are set here; callers own their execution policy.

_EXECUTOR_ROUTER_SELF="${BASH_SOURCE[0]}"
while [[ -L "$_EXECUTOR_ROUTER_SELF" ]]; do
  _EXECUTOR_ROUTER_DIR="$(cd "$(dirname "$_EXECUTOR_ROUTER_SELF")" && pwd)"
  _EXECUTOR_ROUTER_SELF="$(readlink "$_EXECUTOR_ROUTER_SELF")"
  [[ "$_EXECUTOR_ROUTER_SELF" == /* ]] || _EXECUTOR_ROUTER_SELF="$_EXECUTOR_ROUTER_DIR/$_EXECUTOR_ROUTER_SELF"
done
EXECUTOR_ROUTER_LIB_DIR="$(cd "$(dirname "$_EXECUTOR_ROUTER_SELF")" && pwd)"
EXECUTOR_ROUTER_SCRIPT_DIR="$(cd "$EXECUTOR_ROUTER_LIB_DIR/.." && pwd)"

# runner-kind mapping: the single source of truth for deriving dispatch_route /
# write_guard_mode / needs_bash_guard from an adapter's declared runner_kind.
# bash+grep only — no shell-policy side effects, safe to import here.
if ! declare -F runner_kind_resolve_flag >/dev/null 2>&1; then
  # shellcheck source=scripts/lib/runner-kind.sh
  . "$EXECUTOR_ROUTER_LIB_DIR/runner-kind.sh"
fi

# Local helper: avoid importing portable.sh shell policy into caller space.
_er_codex_available() {
  command -v codex >/dev/null 2>&1
}

# _er_strict_name <name> — validate an executor/adapter name as a bare lowercase
# identifier (same rule as pmctl_validate_adapter_name, scripts/lib/pmctl-fs.sh;
# embedded to keep the router free of the pmctl lib dependency). The regex blocks
# path separators, '..', and leading digits/dashes, so a validated name is safe to
# interpolate into adapters/<name>/… without traversal.
_er_strict_name() {
  [[ "${1-}" =~ ^[a-z][a-z0-9_-]*$ ]]
}

# _er_adapter_manifest <name> — print the manifest path for a validated adapter
# name, or fail (2). Fail-closed: an invalid name, a missing/unreadable manifest,
# or a symlinked manifest (trust-boundary escape) all refuse. The authoritative
# exec-path boundary check on adapters/<name>/dispatch.sh lives in
# scripts/lib/pmctl-dispatch.sh; this is the upstream allowlist read.
_er_adapter_manifest() {
  local name=${1-}
  _er_strict_name "$name" || return 2
  local manifest="${EXECUTOR_ROUTER_SCRIPT_DIR%/scripts}/adapters/$name/adapter.yaml"
  [[ -f "$manifest" && ! -L "$manifest" ]] || return 2
  printf '%s\n' "$manifest"
}

# _er_adapter_runner_kind <name> — print an adapter's validated runner_kind, or
# fail (2) when the adapter is not routable or declares an invalid runner_kind.
_er_adapter_runner_kind() {
  local manifest runner_kind
  manifest="$(_er_adapter_manifest "$1")" || return 2
  runner_kind="$(runner_kind_manifest_field "$manifest" runner_kind)" || return 2
  runner_kind_valid "$runner_kind" || return 2
  printf '%s\n' "$runner_kind"
}

detect_executor_auto() {
  if _er_codex_available; then
    printf 'codex\n'
  else
    printf 'claude\n'
  fi
}

resolve_executor() {
  local option=${1-}

  [[ $# -eq 1 ]] || {
    printf 'executor-router: resolve_executor expects exactly one argument\n' >&2
    return 2
  }

  # auto autodetects; a named executor must be a routable adapter (in the
  # manifest-derived dispatch allowlist). The former codex|claude enum is gone.
  if [[ "$option" == auto ]]; then
    detect_executor_auto
    return
  fi
  if dispatch_route_for "$option" >/dev/null 2>&1; then
    printf '%s\n' "$option"
  else
    printf 'executor-router: unknown executor: %s (expected auto or a registered adapter)\n' "$option" >&2
    return 2
  fi
}

# dispatch_route_for <name>
# The dispatch ALLOWLIST gate and route resolver in one. An executor is routable
# iff adapters/<name>/ carries a valid manifest (readable, non-symlink) declaring
# a valid runner_kind; the route is derived from that runner_kind via the single
# runner-kind mapping table (honoring an explicit dispatch_route override in the
# manifest). Fail-closed: any failure → exit 2, which callers (pmctl dispatch run)
# treat as "not in the allowlist".
dispatch_route_for() {
  local executor=${1-}

  [[ $# -eq 1 ]] || {
    printf 'executor-router: dispatch_route_for expects exactly one argument\n' >&2
    return 2
  }

  local manifest runner_kind override
  manifest="$(_er_adapter_manifest "$executor")" || {
    printf 'executor-router: %s is not a routable executor (no valid adapter manifest)\n' "$executor" >&2
    return 2
  }
  runner_kind="$(runner_kind_manifest_field "$manifest" runner_kind)" || return 2
  runner_kind_valid "$runner_kind" || {
    printf 'executor-router: adapter %s declares invalid runner_kind: %s\n' "$executor" "$runner_kind" >&2
    return 2
  }
  override="$(runner_kind_manifest_field "$manifest" dispatch_route)" || return 2
  runner_kind_resolve_flag "$runner_kind" dispatch_route "$override"
}

executor_router_safe_argv() {
  local value=${1-}
  printf '%q' "$value"
}

# dispatch_via <executor> <brief_file> <working_dir> <model> <sandbox> <approval> <timeout> [isolation_level]
# Generic dispatcher: resolves adapters/<executor>/dispatch.sh from the VALIDATED
# executor name and prints a safely-quoted command string. The caller still owns
# when/how to execute it (foreground/background, redirection). Universal flags
# (--cd / --model / --timeout / --brief-file / --isolation) are always forwarded.
# The codex-native --sandbox / --approval flags are forwarded only for
# cli-subprocess runner-kinds (those run the executor as a sandboxed subprocess).
# Both shipped adapters are cli-subprocess; claude accepts but ignores these flags
# as no-ops (it self-governs via --permission-mode). A host-native runner-kind has
# no subprocess sandbox/approval surface and drops them. NOTE: the sandbox/approval
# flag surface is provisional — it will fold into the unified --isolation contract.
dispatch_via() {
  local executor=${1-}
  local brief_file=${2-}
  local working_dir=${3-}
  local model=${4-}
  local sandbox=${5-}
  local approval=${6-}
  local timeout=${7-}
  local isolation_level=${8-}
  local -a cmd
  local arg
  local first=1

  [[ $# -eq 7 || $# -eq 8 ]] || {
    printf 'executor-router: dispatch_via expects executor, brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level]\n' >&2
    return 2
  }

  local runner_kind
  runner_kind="$(_er_adapter_runner_kind "$executor")" || {
    printf 'executor-router: %s is not a routable executor (no valid adapter manifest)\n' "$executor" >&2
    return 2
  }
  # The validated name resolves the adapter path by convention (the real
  # adapter, not the legacy scripts/<name>-dispatch.sh compatibility shim).
  local dispatch_script="${EXECUTOR_ROUTER_SCRIPT_DIR%/scripts}/adapters/$executor/dispatch.sh"

  cmd=(bash "$dispatch_script" --cd "$working_dir")
  [[ -n "$model" && "$model" != "default" ]] && cmd+=(--model "$model")
  if [[ "$runner_kind" == "cli-subprocess" ]]; then
    cmd+=(--sandbox "$sandbox" --approval "$approval")
  fi
  cmd+=(--timeout "$timeout" --brief-file "$brief_file")
  [[ -n "$isolation_level" ]] && cmd+=(--isolation "$isolation_level")

  for arg in "${cmd[@]}"; do
    if [[ "$first" -eq 1 ]]; then
      first=0
    else
      printf ' '
    fi
    executor_router_safe_argv "$arg"
  done
  printf '\n'
}

# dispatch_via_codex / dispatch_via_claude — thin compatibility shims over the
# generic dispatch_via, kept for external callers and existing tests. New call
# sites should prefer `dispatch_via "$executor" …` so a new adapter needs no shim.
dispatch_via_codex() {
  [[ $# -eq 6 || $# -eq 7 ]] || {
    printf 'executor-router: dispatch_via_codex expects brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level]\n' >&2
    return 2
  }
  dispatch_via codex "$@"
}

dispatch_via_claude() {
  [[ $# -eq 6 || $# -eq 7 ]] || {
    printf 'executor-router: dispatch_via_claude expects brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level]\n' >&2
    return 2
  }
  dispatch_via claude "$@"
}

unset _EXECUTOR_ROUTER_SELF _EXECUTOR_ROUTER_DIR

export EXECUTOR_ROUTER_LIB_DIR
export EXECUTOR_ROUTER_SCRIPT_DIR
export -f _er_codex_available
export -f detect_executor_auto
export -f resolve_executor
export -f dispatch_route_for
export -f _er_strict_name
export -f _er_adapter_manifest
export -f _er_adapter_runner_kind
export -f executor_router_safe_argv
export -f dispatch_via
export -f dispatch_via_codex
export -f dispatch_via_claude
