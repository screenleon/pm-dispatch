#!/usr/bin/env bash
# pmctl validate — handover brief validation front-end (CC-341).
# Wires the handover-validate.sh framework into the pmctl CLI surface.
# No shell options set here; cli/pmctl owns execution policy.

pmctl_validate_brief() {
  local repo_root="${1:-}"
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl validate brief: missing repo root\n' >&2
    return 2
  fi
  shift || true

  local file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --)
        shift
        if [[ $# -gt 0 ]]; then file="$1"; shift; fi
        # Reject leftover arguments after `-- <file>` so the single-file usage
        # contract matches the positional path (which rejects a second argument).
        if [[ $# -gt 0 ]]; then
          printf 'pmctl validate brief: unexpected argument %s\n' "$1" >&2
          return 2
        fi
        break
        ;;
      -*)
        printf 'pmctl validate brief: unknown flag %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [[ -n "$file" ]]; then
          printf 'pmctl validate brief: unexpected argument %s\n' "$1" >&2
          return 2
        fi
        file="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$file" ]]; then
    printf 'pmctl validate brief: file path required\n' >&2
    return 2
  fi

  if [[ ! -f "$file" ]]; then
    printf 'pmctl validate brief: file not found: %s\n' "$file" >&2
    return 2
  fi

  local _lib_dir
  _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=scripts/lib/handover-validate.sh
  # shellcheck disable=SC1091
  . "$_lib_dir/handover-validate.sh"

  local content block metadata
  content="$(<"$file")"

  if ! block="$(handover_extract_block "$content" 2>/dev/null)"; then
    printf 'pmctl validate brief: no dispatch_handover_v1 block found in %s\n' "$file" >&2
    return 1
  fi

  if ! metadata="$(handover_extract_metadata "$block" 2>/dev/null)"; then
    printf 'pmctl validate brief: failed to extract metadata section\n' >&2
    return 1
  fi

  if ! handover_validate_all_metadata "$metadata"; then
    return 1
  fi

  printf 'ok: %s\n' "$file"
  return 0
}
