#!/usr/bin/env bash
# Sourceable executor routing helpers for adapter dispatch callers.
#
# Routing is DATA-DRIVEN: the dispatch allowlist and per-executor route
# are derived from on-disk adapter manifests (adapters/<name>/adapter.yaml), not a
# hardcoded codex|claude enum. An executor is routable iff its adapter directory
# carries a valid manifest whose dispatch_entrypoint resolves to a safe,
# executable target. Adding an adapter is therefore "drop adapters/<name>/ with
# a valid manifest" — no edit to this file is required.
#
# No shell options are set here; callers own their execution policy.

# Importing a library must not fork `dirname`, `readlink`, or `pwd`.  The
# runtime loader supplies a lexical path rooted in the deployed layout; all
# routing paths below are relative to that same layout. Executable entrypoints
# perform symlink canonicalization before they source runtime libraries.
EXECUTOR_ROUTER_LIB_DIR="${BASH_SOURCE[0]%/*}"
[[ "$EXECUTOR_ROUTER_LIB_DIR" == "${BASH_SOURCE[0]}" ]] && EXECUTOR_ROUTER_LIB_DIR=.
case "$EXECUTOR_ROUTER_LIB_DIR" in
  */runtime/lib) EXECUTOR_ROUTER_REPO_ROOT="${EXECUTOR_ROUTER_LIB_DIR%/runtime/lib}" ;;
  runtime/lib) EXECUTOR_ROUTER_REPO_ROOT=. ;;
  *) EXECUTOR_ROUTER_REPO_ROOT="${EXECUTOR_ROUTER_LIB_DIR%/lib}" ;;
esac

_er_source_required() {
  local required="$1"
  if [[ ! -r "$required" ]]; then
    printf 'executor-router: required library unavailable: %s\n' "$required" >&2
    return 2
  fi
  # Never trust an exported function with the same name. Loading each
  # dependency from this router's classified lib root overwrites inherited
  # definitions and makes missing receipt-owned bytes a hard failure.
  # shellcheck disable=SC1090
  . "$required" || {
    printf 'executor-router: required library unavailable: %s\n' "$required" >&2
    return 2
  }
}

# These libraries are source-safe and are intentionally loaded unconditionally
# in dependency order. adapter-manifest may reuse the first two only after this
# router has established their canonical definitions from the same lib root.
_er_source_required "$EXECUTOR_ROUTER_LIB_DIR/identifier-policy.sh" || return 2
_er_source_required "$EXECUTOR_ROUTER_LIB_DIR/runner-kind.sh" || return 2
_er_source_required "$EXECUTOR_ROUTER_LIB_DIR/adapter-manifest.sh" || return 2
unset -f _er_source_required

# Local helper: avoid importing portable.sh shell policy into caller space.
_er_codex_available() {
  command -v codex >/dev/null 2>&1
}

# _er_strict_name <name> — validate an executor/adapter name as a bare lowercase
# identifier (same rule as pmctl_validate_adapter_name, runtime/lib/pmctl-fs.sh;
# embedded to keep the router free of the pmctl lib dependency). The regex blocks
# path separators, '..', and leading digits/dashes, so a validated name is safe to
# interpolate into adapters/<name>/… without traversal.
_er_strict_name() {
  pm_identifier_adapter_is_valid "$@"
}

# _er_adapter_manifest_at <repo-root> <name> — compatibility wrapper over the
# canonical reader for callers that select a deployment root explicitly.
_er_adapter_manifest_at() {
  local repo_root=${1-} name=${2-}
  [[ $# -eq 2 ]] || return 2
  adapter_manifest_file "$repo_root" "$name"
}

# _er_adapter_manifest <name> — compatibility wrapper using the source-layout
# default. New layout-aware callers should use the explicit-root APIs below.
_er_adapter_manifest() {
  local name=${1-}
  _er_adapter_manifest_at "$EXECUTOR_ROUTER_REPO_ROOT" "$name"
}

# _er_adapter_runner_kind_at <repo-root> <name> — print an adapter's validated
# runner_kind, or fail (2) when the adapter is not routable or declares an
# invalid runner_kind.
_er_adapter_runner_kind_at() {
  local repo_root=${1-} name=${2-}
  [[ $# -eq 2 ]] || return 2
  adapter_manifest_runner_kind "$repo_root" "$name"
}

# _er_adapter_runner_kind <name> — source-layout compatibility wrapper.
_er_adapter_runner_kind() {
  _er_adapter_runner_kind_at "$EXECUTOR_ROUTER_REPO_ROOT" "$1"
}

detect_executor_auto() {
  if _er_codex_available; then
    printf 'codex\n'
  else
    printf 'claude\n'
  fi
}

resolve_executor_at() {
  local repo_root=${1-} option=${2-} resolved

  [[ $# -eq 2 ]] || {
    printf 'executor-router: resolve_executor_at expects repo root and executor option\n' >&2
    return 2
  }

  # Auto detection chooses a candidate, then passes through the exact same
  # manifest-derived dispatch allowlist as an explicit executor. This keeps
  # repo, installed-copy, and standalone-copy semantics identical and prevents
  # a PATH binary from selecting an adapter missing from the trusted root.
  resolved=$option
  if [[ "$option" == auto ]]; then
    resolved="$(detect_executor_auto)" || return 2
  fi
  if dispatch_route_for_at "$repo_root" "$resolved" >/dev/null 2>&1; then
    printf '%s\n' "$resolved"
  else
    if [[ "$option" == auto ]]; then
      printf 'executor-router: auto-detected executor is not registered or routable: %s\n' "$resolved" >&2
    else
      printf 'executor-router: unknown executor: %s (expected auto or a registered adapter)\n' "$option" >&2
    fi
    return 2
  fi
}

resolve_executor() {
  [[ $# -eq 1 ]] || {
    printf 'executor-router: resolve_executor expects exactly one argument\n' >&2
    return 2
  }
  resolve_executor_at "$EXECUTOR_ROUTER_REPO_ROOT" "$1"
}

# dispatch_route_for <name>
# The dispatch ALLOWLIST gate and route resolver in one. An executor is routable
# iff adapters/<name>/ carries a complete, dispatchable manifest; the route is
# derived from runner_kind via the single mapping table (honoring a valid
# dispatch_route override). A shell dispatch entrypoint is valid only for the
# main-thread subprocess route. Fail-closed: any failure -> exit 2.
dispatch_route_for_at() {
  local repo_root=${1-} executor=${2-}

  [[ $# -eq 2 ]] || {
    printf 'executor-router: dispatch_route_for_at expects repo root and executor\n' >&2
    return 2
  }

  local route
  if ! adapter_manifest_dispatch_path "$repo_root" "$executor" >/dev/null; then
    printf 'executor-router: %s is not a routable executor (no valid adapter manifest)\n' "$executor" >&2
    return 2
  fi
  route="$(adapter_manifest_effective_route "$repo_root" "$executor")" || return 2
  printf '%s\n' "$route"
}

dispatch_route_for() {
  [[ $# -eq 1 ]] || {
    printf 'executor-router: dispatch_route_for expects exactly one argument\n' >&2
    return 2
  }
  dispatch_route_for_at "$EXECUTOR_ROUTER_REPO_ROOT" "$1"
}

executor_router_safe_argv() {
  local value=${1-}
  printf '%q' "$value"
}

# dispatch_via_at <repo-root> <executor> <brief_file> <working_dir> <model>
#   <sandbox> <approval> <timeout> [isolation_level] [effort]
# Generic dispatcher: resolves the manifest-declared dispatch_entrypoint and
# prints a safely-quoted command string. The caller still owns
# when/how to execute it (foreground/background, redirection). Universal flags
# (--cd / --model / --timeout / --brief-file / --isolation / --effort) are always
# forwarded — every adapter accepts --effort (opencode no-ops it; see
# runtime/lib/reasoning-effort.sh for the shared low/medium/high vocabulary).
# The codex-native --sandbox / --approval flags are forwarded only for
# cli-subprocess runner-kinds (those run the executor as a sandboxed subprocess).
# Both shipped adapters are cli-subprocess; claude accepts but ignores these flags
# as no-ops (it self-governs via --permission-mode). A host-native runner-kind has
# no subprocess sandbox/approval surface and drops them. NOTE: the sandbox/approval
# flag surface is provisional — it will fold into the unified --isolation contract.
dispatch_via_at() {
  local repo_root=${1-}
  local executor=${2-}
  local brief_file=${3-}
  local working_dir=${4-}
  local model=${5-}
  local sandbox=${6-}
  local approval=${7-}
  local timeout=${8-}
  local isolation_level=${9-}
  local effort=${10-}
  local -a cmd
  local arg
  local first=1

  [[ $# -ge 8 && $# -le 10 ]] || {
    printf 'executor-router: dispatch_via_at expects repo root, executor, brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level[, effort]]\n' >&2
    return 2
  }

  local runner_kind
  runner_kind="$(_er_adapter_runner_kind_at "$repo_root" "$executor")" || {
    printf 'executor-router: %s is not a routable executor (no valid adapter manifest)\n' "$executor" >&2
    return 2
  }
  local dispatch_script
  dispatch_script="$(adapter_manifest_dispatch_path "$repo_root" "$executor")" || {
    printf 'executor-router: %s has no valid manifest dispatch entrypoint\n' "$executor" >&2
    return 2
  }

  cmd=(bash "$dispatch_script" --cd "$working_dir")
  [[ -n "$model" && "$model" != "default" ]] && cmd+=(--model "$model")
  if [[ "$runner_kind" == "cli-subprocess" ]]; then
    cmd+=(--sandbox "$sandbox" --approval "$approval")
  fi
  cmd+=(--timeout "$timeout" --brief-file "$brief_file")
  [[ -n "$isolation_level" ]] && cmd+=(--isolation "$isolation_level")
  [[ -n "$effort" ]] && cmd+=(--effort "$effort")
  # Forward the trace-dir seam EXPLICITLY when set, so the printed command is
  # self-documenting and the adapter's trace location does not silently depend
  # on inherited env. Default (env unset) appends nothing — behavior unchanged,
  # trace stays in-repo. Precedence at the adapter is flag > env, and the value
  # here IS the env, so forwarding it as a flag is consistent either way.
  [[ -n "${PM_DISPATCH_TRACE_DIR:-}" ]] && cmd+=(--trace-dir "$PM_DISPATCH_TRACE_DIR")

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

# dispatch_via <executor> <brief_file> <working_dir> <model> <sandbox>
#   <approval> <timeout> [isolation_level] [effort]
# Source-layout compatibility wrapper. Layout-aware consumers should call
# dispatch_via_at so sourcing the library never dictates their Adapter root.
dispatch_via() {
  [[ $# -ge 7 && $# -le 9 ]] || {
    printf 'executor-router: dispatch_via expects executor, brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level[, effort]]\n' >&2
    return 2
  }
  dispatch_via_at "$EXECUTOR_ROUTER_REPO_ROOT" "$@"
}

# dispatch_via_codex / dispatch_via_claude — thin compatibility shims over the
# generic dispatch_via, kept for external callers and existing tests. New call
# sites should prefer `dispatch_via "$executor" …` so a new adapter needs no shim.
dispatch_via_codex() {
  [[ $# -ge 6 && $# -le 8 ]] || {
    printf 'executor-router: dispatch_via_codex expects brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level[, effort]]\n' >&2
    return 2
  }
  dispatch_via codex "$@"
}

dispatch_via_claude() {
  [[ $# -ge 6 && $# -le 8 ]] || {
    printf 'executor-router: dispatch_via_claude expects brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level[, effort]]\n' >&2
    return 2
  }
  dispatch_via claude "$@"
}

unset _EXECUTOR_ROUTER_SELF _EXECUTOR_ROUTER_DIR

export EXECUTOR_ROUTER_LIB_DIR
export EXECUTOR_ROUTER_REPO_ROOT
export -f _er_codex_available
export -f detect_executor_auto
export -f resolve_executor
export -f resolve_executor_at
export -f dispatch_route_for
export -f dispatch_route_for_at
export -f _er_strict_name
export -f _er_adapter_manifest
export -f _er_adapter_manifest_at
export -f _er_adapter_runner_kind
export -f _er_adapter_runner_kind_at
export -f executor_router_safe_argv
export -f dispatch_via
export -f dispatch_via_at
export -f dispatch_via_codex
export -f dispatch_via_claude
