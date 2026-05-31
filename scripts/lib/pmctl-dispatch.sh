#!/usr/bin/env bash

# Executor-agnostic dispatch orchestrator (CC-289, approach B).
#
# `pmctl dispatch run --adapter <name> --cd <dir> --brief-file <path>` OWNS the
# shared dispatch flow and composes the M2-extracted pieces; the adapter under
# `adapters/<name>/dispatch.sh` stays thin (executor invocation + the
# `.agent-trace/latest.last` output-contract glue only).
#
# Flow (each step is executor-agnostic except step 5):
#   1. validate adapter name (strict identifier) + resolve by convention
#   2. route + allowlist             executor-router: MANDATORY, fail-closed
#   3. brief-validate                scripts/brief-validate.sh
#   4. guard                         pmctl guard check (shared policy, MANDATORY)
#   5. invoke adapter subprocess     the ONLY executor-specific step
#   6. read output contract          .agent-trace/latest.last (read-only)
#   7. post-verify                   scripts/dispatch-post-verify.sh
#
# The validate+guard invariant covers every dispatch that reaches an executor:
# an adapter that resolves AND routes is always brief-validated and guarded
# before invocation. Pre-flight rejections (invalid name, unknown adapter,
# non-routable executor) fail fast BEFORE brief work — intentionally, since there
# is no executor to guard for and no point validating a brief for a dispatch that
# cannot run.
#
# Policy invariants (every dispatch through pmctl is validated AND guarded —
# there is no bypass door):
#   - `--brief-file` is REQUIRED; the inline `-- <brief>` form is rejected, so no
#     execution can skip brief-validate + guard. (The adapter still accepts inline
#     form for direct smoke checks, but the policy surface — pmctl — does not.)
#   - `--adapter` MUST be a bare identifier `^[a-z][a-z0-9_-]*$`; it is never a
#     path, so a crafted value cannot traverse out of `adapters/` to execute an
#     arbitrary `dispatch.sh`.
#   - Routing is the allowlist: the executor MUST resolve to a registered route.
#     If the routing registry (executor-router) or the guard (pmctl-guard) is not
#     available, the dispatch is REFUSED — the allowlist/guard is never skipped.
#   - The ONLY data read back from an adapter is the output contract
#     (latest.last + exit code) — never the executor-internal trace format.
#   - No executor-specific invocation tokens live here; the only executor identity
#     used is the adapter NAME string (path resolution + guard --profile).
#
# Exit-code contract:
#   0  — adapter succeeded and post-verify passed (or was skipped on dry-run)
#   2  — usage error, invalid/unknown/non-routable adapter, brief rejected,
#        guard denied, or a required dependency (router/guard) unavailable
#   1  — post-verify failed after a successful adapter run
#   *  — any other non-zero adapter exit is propagated verbatim

pmctl_dispatch_run() {
  local repo_root="${1:-}"
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl dispatch run: missing repo root\n' >&2
    return 2
  fi
  shift || true

  local adapter="" work_dir="" brief_file="" print_cmd=0
  local -a forward=()

  # Peek at the flags the shared steps need (--adapter is consumed; --cd and
  # --brief-file are peeked AND forwarded). Everything else passes through to the
  # adapter opaquely so pmctl never needs to know executor-specific flags.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --adapter)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch run: missing value for --adapter\n' >&2
          return 2
        fi
        adapter="$2"
        shift 2
        ;;
      --cd)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch run: missing value for --cd\n' >&2
          return 2
        fi
        work_dir="$2"
        forward+=(--cd "$2")
        shift 2
        ;;
      --brief-file)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl dispatch run: missing value for --brief-file\n' >&2
          return 2
        fi
        brief_file="$2"
        forward+=(--brief-file "$2")
        shift 2
        ;;
      --print-cmd)
        print_cmd=1
        forward+=(--print-cmd)
        shift
        ;;
      --)
        # Inline brief form skips brief-validate + guard, so it is a policy
        # bypass. Refuse it at the orchestrator (the policy surface); briefs must
        # be written to a file and passed via --brief-file.
        printf 'pmctl dispatch run: inline brief form (--) is not supported; write the brief to a file and pass --brief-file so policy checks (brief-validate + guard) can run\n' >&2
        return 2
        ;;
      *)
        forward+=("$1")
        shift
        ;;
    esac
  done

  # ── Required, validated inputs ───────────────────────────────────────────
  if [[ -z "$adapter" ]]; then
    printf 'pmctl dispatch run: --adapter <name> is required\n' >&2
    return 2
  fi
  # Strict identifier: a bare adapter name, never a path. Blocks `../` traversal
  # and any value that could resolve a dispatch.sh outside adapters/<name>/.
  if ! [[ "$adapter" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    printf 'pmctl dispatch run: invalid adapter name %q (must be a bare lowercase identifier: a letter, then letters/digits/hyphen/underscore — no path separators)\n' "$adapter" >&2
    return 2
  fi
  if [[ -z "$work_dir" ]]; then
    printf 'pmctl dispatch run: --cd <dir> is required\n' >&2
    return 2
  fi
  if [[ -z "$brief_file" ]]; then
    printf 'pmctl dispatch run: --brief-file <path> is required (every dispatch must carry a validatable brief)\n' >&2
    return 2
  fi

  # 1. Resolve adapter by convention — the name is now a validated bare identifier.
  local adapter_path="$repo_root/adapters/$adapter/dispatch.sh"
  if [[ ! -f "$adapter_path" ]]; then
    printf 'pmctl dispatch run: unknown adapter %q (no %s). An adapter must provide adapters/<name>/dispatch.sh; run pmctl adapter generate to scaffold it.\n' "$adapter" "$adapter_path" >&2
    return 2
  fi

  # Containment: the adapter script must be a regular file (not a symlink) whose
  # physical directory stays within repo_root/adapters/. Name validation already
  # blocks `../` in the token; this additionally blocks a symlinked dispatch.sh
  # (or symlinked adapter dir) from escaping the trust boundary to execute an
  # arbitrary script outside the repo.
  if [[ -L "$adapter_path" ]]; then
    printf 'pmctl dispatch run: adapter dispatch script must not be a symlink: %s\n' "$adapter_path" >&2
    return 2
  fi
  local _adapters_base _adapter_dir_real
  if ! _adapters_base="$(cd -P -- "$repo_root/adapters" 2>/dev/null && pwd -P)"; then
    printf 'pmctl dispatch run: adapters directory not found under %s\n' "$repo_root" >&2
    return 2
  fi
  if ! _adapter_dir_real="$(cd -P -- "$(dirname "$adapter_path")" 2>/dev/null && pwd -P)"; then
    printf 'pmctl dispatch run: cannot resolve adapter directory for %q\n' "$adapter" >&2
    return 2
  fi
  case "$_adapter_dir_real" in
    "$_adapters_base"/?*) : ;;
    *)
      printf 'pmctl dispatch run: adapter path escapes the adapters/ boundary: %s\n' "$_adapter_dir_real" >&2
      return 2
      ;;
  esac

  # 2. Route — the dispatch ALLOWLIST. Fail closed: a missing routing registry
  #    must refuse the dispatch, never silently skip the allowlist.
  if ! declare -F dispatch_route_for >/dev/null; then
    printf 'pmctl dispatch run: routing registry unavailable (executor-router not sourced) — refusing to dispatch without allowlist enforcement\n' >&2
    return 2
  fi
  local route
  if ! route="$(dispatch_route_for "$adapter" 2>/dev/null)"; then
    printf 'pmctl dispatch run: %q is not a routable executor (not in the dispatch allowlist)\n' "$adapter" >&2
    return 2
  fi
  printf 'pmctl dispatch run: adapter=%s route=%s\n' "$adapter" "$route" >&2

  # 3. Brief-validate (shared) — always runs; there is no brief-less path.
  local brief_result=0
  local brief_msg
  brief_msg="$(bash "$repo_root/scripts/brief-validate.sh" "$brief_file" 2>&1)" || brief_result=$?
  if [[ "$brief_result" -ne 0 ]]; then
    printf 'pmctl dispatch run: brief failed validation: %s\n%s\n' "$brief_file" "$brief_msg" >&2
    return 2
  fi

  # 4. Guard (shared policy) — MANDATORY. Fail closed if the guard is unavailable.
  #    Gates the executor's brief-file write for this runtime via the same code
  #    path the PreToolUse hooks enforce. The dispatch adapter IS the runtime
  #    axis (CC-291); the role is always `executor` here.
  if ! declare -F pmctl_guard_check >/dev/null; then
    printf 'pmctl dispatch run: guard unavailable (pmctl-guard not sourced) — refusing to dispatch without policy enforcement\n' >&2
    return 2
  fi
  if ! pmctl_guard_check "$repo_root" --event pre-write --role executor --runtime "$adapter" --file "$brief_file"; then
    printf 'pmctl dispatch run: guard denied dispatch for adapter %q\n' "$adapter" >&2
    return 2
  fi

  # 5. Invoke the adapter subprocess — the ONLY executor-specific step.
  local exit_code=0
  bash "$adapter_path" "${forward[@]}" || exit_code=$?

  # Dry-run (--print-cmd): the adapter printed its command and wrote no trace;
  # there is no output contract to read and nothing to post-verify.
  if [[ "$print_cmd" -eq 1 ]]; then
    return "$exit_code"
  fi

  # 6. A failed adapter run short-circuits: propagate its exit verbatim. The
  #    adapter already wrote forensic trace/stderr for post-mortem.
  if [[ "$exit_code" -ne 0 ]]; then
    return "$exit_code"
  fi

  # 7. Post-verify (shared) reads the output contract (latest.last) and validates
  #    the run against the work dir + brief. Only runs after a clean adapter exit.
  if ! bash "$repo_root/scripts/dispatch-post-verify.sh" "$work_dir" "$brief_file"; then
    printf 'pmctl dispatch run: post-verify failed\n' >&2
    return 1
  fi

  return "$exit_code"
}
