#!/usr/bin/env bash
# pmctl safe bash — guard-check a command then execute it.
# Requires pmctl-guard.sh sourced before this lib (guard check is the policy engine).

pmctl_safe_bash_usage() {
  printf 'usage: pmctl safe bash --role <ROLE> --runtime <RUNTIME> [--] <COMMAND>\n' >&2
}

pmctl_safe_bash() {
  local repo_root="${1:-}"
  shift || true
  local role="" runtime="" cmd=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --role)
        [[ $# -lt 2 ]] && { printf 'pmctl safe bash: missing value for --role\n' >&2; return 2; }
        role="$2"; shift 2 ;;
      --runtime)
        [[ $# -lt 2 ]] && { printf 'pmctl safe bash: missing value for --runtime\n' >&2; return 2; }
        runtime="$2"; shift 2 ;;
      --)
        shift; cmd="$*"; break ;;
      -*)
        printf 'pmctl safe bash: unknown flag: %s\n' "$1" >&2
        pmctl_safe_bash_usage; return 2 ;;
      *)
        cmd="$*"; break ;;
    esac
  done

  if [[ -z "$role" ]]; then
    printf 'pmctl safe bash: missing --role\n' >&2
    pmctl_safe_bash_usage; return 2
  fi
  if [[ -z "$runtime" ]]; then
    printf 'pmctl safe bash: missing --runtime\n' >&2
    pmctl_safe_bash_usage; return 2
  fi
  if [[ -z "$cmd" ]]; then
    printf 'pmctl safe bash: missing command\n' >&2
    pmctl_safe_bash_usage; return 2
  fi

  if ! declare -F pmctl_guard_check >/dev/null; then
    printf 'pmctl safe bash: guard check unavailable\n' >&2
    return 2
  fi

  # Guard check: policy runs first; deny exits non-zero and prints the reason.
  if ! pmctl_guard_check "$repo_root" \
       --role "$role" --runtime "$runtime" \
       --event pre-bash --command "$cmd"; then
    return 1
  fi

  bash -c "$cmd"
}
