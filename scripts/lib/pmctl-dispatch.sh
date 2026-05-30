#!/usr/bin/env bash

# Executor-agnostic dispatch orchestrator (CC-289, approach B).
#
# `pmctl dispatch run --adapter <name> [args]` OWNS the shared dispatch flow and
# composes the M2-extracted pieces; the adapter under `adapters/<name>/dispatch.sh`
# stays thin (executor invocation + `.agent-trace/latest.last` output-contract
# glue only). This is the structure that lets switching executors change ONLY the
# adapter — all surrounding logic is shared here.
#
# Flow (each step is executor-agnostic except step 5):
#   1. resolve adapter by convention   adapters/<name>/dispatch.sh
#   2. route                            executor-router: known executor + route
#   3. brief-validate                   scripts/brief-validate.sh (when --brief-file)
#   4. guard                            pmctl guard check (shared policy, per-profile)
#   5. invoke adapter subprocess        the ONLY executor-specific step
#   6. read output contract             .agent-trace/latest.last (read-only)
#   7. post-verify                      scripts/dispatch-post-verify.sh
#
# Boundary rules this surface MUST honour:
#   - No executor-specific invocation tokens here (`codex exec`, isolation-map,
#     model-alias). Those live in the adapter. The only executor identity used is
#     the adapter NAME string (path resolution + guard --profile).
#   - The ONLY data read back from an adapter is the output contract
#     (latest.last + exit code) — never the executor-internal trace format.
#
# Exit-code contract:
#   0  — adapter succeeded and post-verify passed (or was skipped on dry-run)
#   2  — usage error, unknown adapter, brief rejected, or guard denied
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
        # Inline brief form: forward the separator and ALL remaining words
        # verbatim without parsing them as flags.
        forward+=("$1")
        shift
        forward+=("$@")
        break
        ;;
      *)
        forward+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "$adapter" ]]; then
    printf 'pmctl dispatch run: --adapter <name> is required\n' >&2
    return 2
  fi

  # 1. Resolve adapter by convention — no per-executor branch. Adding an executor
  #    means adding adapters/<name>/dispatch.sh, with zero edits to this surface.
  local adapter_path="$repo_root/adapters/$adapter/dispatch.sh"
  if [[ ! -f "$adapter_path" ]]; then
    printf 'pmctl dispatch run: unknown adapter %q (no %s)\n' "$adapter" "$adapter_path" >&2
    return 2
  fi

  # 2. Route — confirm the adapter names a known executor and resolve its route.
  if declare -F dispatch_route_for >/dev/null; then
    local route
    if ! route="$(dispatch_route_for "$adapter" 2>/dev/null)"; then
      printf 'pmctl dispatch run: %q is not a routable executor\n' "$adapter" >&2
      return 2
    fi
    printf 'pmctl dispatch run: adapter=%s route=%s\n' "$adapter" "$route" >&2
  fi

  # 3. Brief-validate (shared) — only when a brief file is supplied.
  if [[ -n "$brief_file" ]]; then
    local brief_result=0
    local brief_msg
    brief_msg="$(bash "$repo_root/scripts/brief-validate.sh" "$brief_file" 2>&1)" || brief_result=$?
    if [[ "$brief_result" -ne 0 ]]; then
      printf 'pmctl dispatch run: brief failed validation: %s\n%s\n' "$brief_file" "$brief_msg" >&2
      return 2
    fi
  fi

  # 4. Guard (shared policy) — gate the executor's brief-file write for this
  #    profile before invoking it. Same code path the PreToolUse hooks enforce.
  if [[ -n "$brief_file" ]] && declare -F pmctl_guard_check >/dev/null; then
    if ! pmctl_guard_check "$repo_root" --event pre-write --profile "$adapter" --file "$brief_file"; then
      printf 'pmctl dispatch run: guard denied dispatch for adapter %q\n' "$adapter" >&2
      return 2
    fi
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
  if [[ -n "$work_dir" ]]; then
    if [[ -n "$brief_file" ]]; then
      if ! bash "$repo_root/scripts/dispatch-post-verify.sh" "$work_dir" "$brief_file"; then
        printf 'pmctl dispatch run: post-verify failed\n' >&2
        return 1
      fi
    else
      if ! bash "$repo_root/scripts/dispatch-post-verify.sh" "$work_dir"; then
        printf 'pmctl dispatch run: post-verify failed\n' >&2
        return 1
      fi
    fi
  fi

  return "$exit_code"
}
