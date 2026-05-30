#!/usr/bin/env bash

# Executor-agnostic guard-check front-end (CC-288).
#
# `pmctl guard check` lets ANY host — not just Claude's PreToolUse auto-hooks —
# enforce the identical guard policy. The guard LOGIC is unchanged: this surface
# synthesizes the canonical PreToolUse stdin JSON for a (profile, event) cell and
# drives the existing, battle-tested guard hook scripts. Reusing the proven hooks
# verbatim makes the CLI surface equivalent-by-construction (architecture R2: the
# engine is the same code path the test-hooks.sh suite already covers).
#
# Trigger asymmetry is inherent, not a flaw: Claude fires the guard automatically
# via PreToolUse; a non-Claude host (e.g. codex-as-PM) must call `pmctl guard
# check` explicitly before the action. Both paths run the same policy.
#
# Profile dimension: the existing hooks key on `agent_type`, and pm vs codex have
# DIFFERENT allow-lists (pm pre-write → memory dir only; codex pre-write →
# /tmp/brief-*.md only). `--event` alone is therefore ambiguous, so this surface
# requires `--profile <pm|codex|claude>` to select the policy.
#
# Fail-closed: a guard must never report success without evaluating a policy.
# Any recognized (profile, event) cell that has no registered policy — e.g.
# `pm/pre-bash` (project-pm never runs Bash) or the reserved-but-unimplemented
# `post-task` event — returns a non-zero deny, NOT a silent allow. A success exit
# from this surface always means "a policy ran and permitted the action".
#
# Exit-code contract:
#   0 — a registered policy ran and ALLOWED the action
#   2 — usage error (bad/missing flags), or a registered policy DENIED the action
#       (the underlying hook's own exit 2 is propagated verbatim)
#   3 — fail-closed: the request is recognized but NO policy is registered to
#       evaluate it (pm/pre-bash, post-task). Distinct from 2 so a caller can tell
#       "I cannot enforce this" apart from "this was denied".

pmctl_guard_check() {
  local repo_root event="" profile="" file="" cmd_arg=""
  local file_set=0 command_set=0

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
      --profile)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl guard check: missing value for --profile\n' >&2
          return 2
        fi
        profile="$2"
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

  if [[ -z "$event" ]]; then
    printf 'pmctl guard check: missing --event (want pre-write|pre-bash|post-task)\n' >&2
    return 2
  fi
  if [[ -z "$profile" ]]; then
    printf 'pmctl guard check: missing --profile (want pm|codex|claude)\n' >&2
    return 2
  fi

  # Map profile → the agent_type identity the hooks key on.
  local agent_type
  case "$profile" in
    pm)     agent_type="project-pm" ;;
    codex)  agent_type="codex-executor" ;;
    claude) agent_type="claude-executor" ;;
    *)
      printf 'pmctl guard check: unknown profile: %s (want pm|codex|claude)\n' "$profile" >&2
      return 2
      ;;
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

  # Resolve the guard hook for the (profile, event) cell.
  local hook=""
  case "$profile/$event" in
    pm/pre-write)     hook="hook-pm-write-guard.sh" ;;
    codex/pre-write)  hook="hook-codex-write-guard.sh" ;;
    codex/pre-bash)   hook="hook-codex-bash-guard.sh" ;;
    claude/pre-write) hook="hook-claude-write-guard.sh" ;;
    pm/pre-bash)
      # No PM bash guard exists: project-pm is a planner that never runs Bash.
      # No policy to evaluate → fail closed (deny), never silently allow.
      printf 'pmctl guard check: no guard policy registered for profile=pm event=pre-bash — denying\n' >&2
      return 3
      ;;
    claude/pre-bash)
      # claude-executor self-executes under harness permission prompts (and the
      # CLI subprocess under --permission-mode); the dispatch flow guards only the
      # brief-file pre-write. No pre-bash policy is registered here → fail closed.
      printf 'pmctl guard check: no guard policy registered for profile=claude event=pre-bash — denying\n' >&2
      return 3
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
