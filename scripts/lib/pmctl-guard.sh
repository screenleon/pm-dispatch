#!/usr/bin/env bash

# Executor-agnostic guard-check front-end (CC-288; role×runtime keying CC-291).
#
# `pmctl guard check` lets ANY host — not just Claude's PreToolUse auto-hooks —
# enforce the identical guard policy. The guard LOGIC is unchanged: this surface
# synthesizes the canonical PreToolUse stdin JSON for a (role, runtime, event)
# cell and drives the existing, battle-tested guard hook scripts. Reusing the
# proven hooks verbatim makes the CLI surface equivalent-by-construction
# (architecture R2: the engine is the same code path the test-hooks.sh suite
# already covers).
#
# Trigger asymmetry is inherent, not a flaw: Claude fires the guard automatically
# via PreToolUse; a non-Claude host (e.g. codex-as-PM) must call `pmctl guard
# check` explicitly before the action. Both paths run the same policy.
#
# Two orthogonal axes (CC-291) — keep them distinct:
#   * ROLE (`--role pm|executor|…`) — what the agent IS. guard cares about role.
#     `pm` is runtime-agnostic (codex-as-PM and claude-as-PM share one policy).
#     `executor` is the role shared by codex-executor and claude-executor.
#   * RUNTIME (`--runtime codex|claude`) — which CLI executes the role. dispatch
#     cares about runtime (it is the `--adapter`). guard only consults runtime
#     where a role's policy genuinely differs by runtime (see the registry).
# Adding a new RUNTIME is an adapter concern and must NOT touch this file. Adding
# a new ROLE (spike / reviewer / doc-writer …) adds exactly one role branch to
# the agent_type map + the registry below — role-keyed, not per-(role,runtime).
#
# `--profile pm|codex|claude` is a DEPRECATED back-compat alias (CC-291): it maps
# to the (role, runtime) pair and emits one stderr warning. It conflated the two
# axes (`pm` was a role name, `codex`/`claude` were runtime names). Prefer
# `--role`/`--runtime`. `--profile` carries both axes, so it is mutually
# exclusive with `--role` AND `--runtime`.
#
# Fail-closed: a guard must never report success without evaluating a policy.
# Any recognized cell that has no registered policy — e.g. `pm/pre-bash`
# (project-pm never runs Bash), `executor(claude)/pre-bash` (claude-executor
# self-executes under harness perms), or the reserved-but-unimplemented
# `post-task` event — returns a non-zero deny, NOT a silent allow. A success exit
# from this surface always means "a policy ran and permitted the action".
#
# Exit-code contract:
#   0 — a registered policy ran and ALLOWED the action
#   2 — usage error (bad/missing flags), or a registered policy DENIED the action
#       (the underlying hook's own exit 2 is propagated verbatim)
#   3 — fail-closed: the request is recognized but NO policy is registered to
#       evaluate it (pm/pre-bash, executor(claude)/pre-bash, post-task). Distinct
#       from 2 so a caller can tell "I cannot enforce this" apart from "denied".

pmctl_guard_check() {
  local repo_root event="" role="" runtime="" profile="" file="" cmd_arg=""
  local file_set=0 command_set=0 role_set=0 runtime_set=0 profile_set=0

  repo_root="${1:-}"
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl guard check: missing repo root\n' >&2
    return 2
  fi
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --event)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl guard check: missing value for --event\n' >&2
          return 2
        fi
        event="$2"
        shift 2
        ;;
      --role)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl guard check: missing value for --role\n' >&2
          return 2
        fi
        role="$2"
        role_set=1
        shift 2
        ;;
      --runtime)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl guard check: missing value for --runtime\n' >&2
          return 2
        fi
        runtime="$2"
        runtime_set=1
        shift 2
        ;;
      --profile)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl guard check: missing value for --profile\n' >&2
          return 2
        fi
        profile="$2"
        profile_set=1
        shift 2
        ;;
      --file)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl guard check: missing value for --file\n' >&2
          return 2
        fi
        file="$2"
        file_set=1
        shift 2
        ;;
      --command)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl guard check: missing value for --command\n' >&2
          return 2
        fi
        cmd_arg="$2"
        command_set=1
        shift 2
        ;;
      *)
        printf 'pmctl guard check: unknown flag: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done

  # --profile is the deprecated alias; it carries BOTH axes itself, so it is
  # mutually exclusive with --role AND --runtime. Allowing e.g.
  # `--profile codex --runtime claude` would silently let the profile win — an
  # ambiguous shape — so reject it rather than pick a precedence.
  if [[ "$profile_set" -eq 1 && ( "$role_set" -eq 1 || "$runtime_set" -eq 1 ) ]]; then
    printf 'pmctl guard check: --profile is mutually exclusive with --role/--runtime (--profile is deprecated; use --role/--runtime)\n' >&2
    return 2
  fi

  # Normalize the deprecated --profile onto the (role, runtime) axes, then warn
  # once. Everything downstream operates on role/runtime only.
  if [[ "$profile_set" -eq 1 ]]; then
    case "$profile" in
      pm)     role="pm"; runtime="claude"; runtime_set=1 ;;
      codex)  role="executor"; runtime="codex"; runtime_set=1 ;;
      claude) role="executor"; runtime="claude"; runtime_set=1 ;;
      *)
        printf 'pmctl guard check: unknown profile: %s (want pm|codex|claude)\n' "$profile" >&2
        return 2
        ;;
    esac
    role_set=1
    printf 'pmctl guard check: --profile is deprecated; use --role <pm|executor|reviewer> --runtime <codex|claude>\n' >&2
  fi

  if [[ -z "$event" ]]; then
    printf 'pmctl guard check: missing --event (want pre-write|pre-bash|post-task)\n' >&2
    return 2
  fi
  if [[ "$role_set" -ne 1 ]]; then
    printf 'pmctl guard check: missing --role (want pm|executor|reviewer) with --runtime\n' >&2
    return 2
  fi

  # Validate role, then resolve the runtime requirement.
  # `pm` is runtime-agnostic (project-pm only ever runs on claude; no codex-as-pm).
  # `executor` REQUIRES a runtime — it runs on both codex AND claude, and its
  # pre-bash policy genuinely differs by runtime (see registry).
  # `reviewer` REQUIRES a runtime — it runs on both codex (reviewer brief in
  # codex session) AND claude (reviewer agent subagent). The .gate-results/-only
  # rule is identical across runtimes (CC-297: one role, one fixed rule). Both
  # routes enforce the guard via explicit pmctl guard check in the reviewer brief
  # (not auto PreToolUse); requiring --runtime preserves the role×runtime two-axis
  # design (CC-291) and keeps reviewer symmetric with executor — not collapsed like pm.
  # All roles require --runtime for consistent two-axis CLI semantics (CC-291/CC-297).
  # Even pm (currently claude-only) is explicit — this prevents silent
  # runtime assumption and keeps the door open for non-Claude pm variants.
  case "$role" in
    pm|reviewer|executor)
      if [[ "$runtime_set" -ne 1 ]]; then
        printf 'pmctl guard check: --runtime required for role %s (want codex|claude)\n' "$role" >&2
        return 2
      fi
      ;;
    *)
      printf 'pmctl guard check: unknown role: %s (want pm|executor|reviewer)\n' "$role" >&2
      return 2
      ;;
  esac

  # Runtime validation differs by role:
  #   executor — open-ended bare identifier: adding a runtime is an adapter concern
  #     (drop in adapters/<runtime>/ + hook-<runtime>-write-guard.sh); an unregistered
  #     but valid runtime fails closed at the hook -x check, so we don't allowlist here.
  #   pm / reviewer — fixed hook (runtime does not select a hook); validate against the
  #     known enum so bogus values are rejected at the CLI boundary rather than silently
  #     accepted. A future non-codex/claude runtime must be explicitly added here.
  case "$role" in
    executor)
      if ! [[ "$runtime" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        printf 'pmctl guard check: invalid runtime: %s (want a bare identifier ^[a-z][a-z0-9_-]*$)\n' "$runtime" >&2
        return 2
      fi
      ;;
    pm|reviewer)
      case "$runtime" in
        codex|claude) ;;
        *) printf 'pmctl guard check: unknown runtime for role %s: %s (want codex|claude)\n' "$role" "$runtime" >&2
           return 2 ;;
      esac
      ;;
  esac

  # Reconstruct the agent_type identity the hooks key on. `pm` is role-based
  # (runtime-agnostic); `executor` derives it BY CONVENTION from the runtime
  # (<runtime>-executor), so adding a runtime needs no edit here; `reviewer`
  # uses the synthetic identity "reviewer" — the hook recognises this alongside
  # the five named reviewer agent types (CC-297).
  # CRITICAL (CC-291): each hook self-gates on HK_AGENT_TYPE and no-ops (exit 0 =
  # ALLOW) for any other identity. Because agent_type AND the physical pre-write
  # hook below are BOTH derived from $role/$runtime, they cannot drift — a
  # fail-OPEN from an identity/hook mismatch is impossible by construction.
  # agent_type: the identity the hook self-gates on.
  # pm and reviewer have fixed agent_type (runtime-independent policy today);
  # executor derives it from runtime by convention.
  local agent_type
  case "$role" in
    pm)       agent_type="project-pm" ;;
    reviewer) agent_type="reviewer" ;;
    executor) agent_type="${runtime}-executor" ;;
  esac

  case "$event" in
    pre-write|pre-bash|post-task) ;;
    *)
      printf 'pmctl guard check: unknown event: %s (want pre-write|pre-bash|post-task)\n' "$event" >&2
      return 2
      ;;
  esac

  # post-task: a recognized event name (reserved for a future PostToolUse check)
  # but no policy is implemented yet. Fail closed — refuse rather than silently
  # pass, so callers cannot mistake "unimplemented" for "enforced and allowed".
  if [[ "$event" == "post-task" ]]; then
    printf 'pmctl guard check: event post-task is reserved but not yet implemented (no policy) — denying\n' >&2
    return 3
  fi

  # Role-keyed guard registry, tagged by LAYER (CC-291) — the tags are the design
  # contract, not decoration:
  #
  #   [role-based]       runtime-agnostic dispatch-guard — brief landing. The
  #                      POLICY is one-per-role; the physical pre-write hook is
  #                      selected by runtime CONVENTION (hook-<runtime>-write-
  #                      guard.sh) so it stays identity-matched to agent_type (no
  #                      fail-OPEN) AND a new runtime needs no edit here.
  #   [runtime-specific] genuinely differs by runtime and may NOT be collapsed —
  #                      codex-executor (thin dispatcher) has a pre-bash policy;
  #                      other executor runtimes self-execute under harness perms
  #                      and register none. Adding a bash policy for a new runtime
  #                      IS a guard decision (a new role-policy cell), not an
  #                      adapter concern — so this stays an explicit registry.
  local hook=""
  case "$event" in
    pre-write)
      case "$role" in
        pm)
          # [role-based] pm policy is fixed regardless of runtime (currently claude-only).
          hook="hook-pm-write-guard.sh"
          ;;
        reviewer)
          # [role-based] CC-297: one fixed rule (.gate-results/) across runtimes.
          hook="hook-reviewer-write-guard.sh"
          ;;
        executor)
          # [role-based] runtime-matched by convention: adding a runtime only requires
          # dropping in adapters/<runtime>/ + hook-<runtime>-write-guard.sh.
          hook="hook-${runtime}-write-guard.sh"
          ;;
      esac
      ;;
    pre-bash)
      case "$role" in
        executor)
          case "$runtime" in
            codex) hook="hook-codex-bash-guard.sh" ;;  # [runtime-specific]
            *)
              printf 'pmctl guard check: no guard policy registered for role=executor runtime=%s event=pre-bash — denying\n' "$runtime" >&2
              return 3
              ;;
          esac
          ;;
        pm)
          # project-pm is a planner that never runs Bash → fail closed.
          printf 'pmctl guard check: no guard policy registered for role=pm event=pre-bash — denying\n' >&2
          return 3
          ;;
        reviewer)
          # Reviewers read diff and write findings — no arbitrary bash policy.
          printf 'pmctl guard check: no guard policy registered for role=reviewer event=pre-bash — denying\n' >&2
          return 3
          ;;
      esac
      ;;
  esac

  local hook_path="$repo_root/scripts/$hook"
  if [[ ! -x "$hook_path" ]]; then
    printf 'pmctl guard check: guard hook not executable: %s\n' "$hook_path" >&2
    return 2
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf 'pmctl guard check: jq missing on PATH — install jq\n' >&2
    return 2
  fi

  # Build the canonical PreToolUse stdin JSON for the resolved cell, then drive
  # the hook. An empty --file/--command value is passed THROUGH (not pre-rejected)
  # so the hook produces its own deny — preserving equivalence with the hook's
  # native empty-input handling.
  # Each event takes exactly one artifact flag; the other is rejected (not
  # silently ignored) so a caller cannot mis-specify the wrong artifact and still
  # appear to pass.
  local json
  if [[ "$event" == "pre-write" ]]; then
    if [[ "$file_set" -ne 1 ]]; then
      printf 'pmctl guard check: --file required for event pre-write\n' >&2
      return 2
    fi
    if [[ "$command_set" -eq 1 ]]; then
      printf 'pmctl guard check: --command is not valid for event pre-write (use --file)\n' >&2
      return 2
    fi
    json="$(jq -nc --arg at "$agent_type" --arg fp "$file" \
      '{agent_type:$at,tool_name:"Write",tool_input:{file_path:$fp}}')" || {
      printf 'pmctl guard check: failed to build guard input JSON\n' >&2
      return 2
    }
  else # pre-bash
    if [[ "$command_set" -ne 1 ]]; then
      printf 'pmctl guard check: --command required for event pre-bash\n' >&2
      return 2
    fi
    if [[ "$file_set" -eq 1 ]]; then
      printf 'pmctl guard check: --file is not valid for event pre-bash (use --command)\n' >&2
      return 2
    fi
    json="$(jq -nc --arg at "$agent_type" --arg cmd "$cmd_arg" \
      '{agent_type:$at,tool_name:"Bash",tool_input:{command:$cmd}}')" || {
      printf 'pmctl guard check: failed to build guard input JSON\n' >&2
      return 2
    }
  fi

  printf '%s' "$json" | "$hook_path"
}
