#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/portable.sh
source "$SCRIPT_DIR/lib/portable.sh"

usage() {
  printf 'usage: %s <work_dir> [brief_file] [--last <path>] [--stderr <path>] [--brief-file <path>]\n' "$0" >&2
}

# Path resolution is the only thing the flags change: --last/--stderr override
# the default latest.* symlinks with per-run explicit paths (e.g. parsed from the
# dispatch footer by the /pm main-thread route, where latest.* would race across
# concurrent dispatches). Absent flags, behavior is identical to the positional
# <work_dir> [brief_file] form used by `pmctl dispatch run` and codex-executor.
BRIEF_FILE=""
LAST_OVERRIDE=""
STDERR_OVERRIDE=""
positional=()

# A value-taking flag must be followed by a real value — not end-of-args and not
# another flag. Without this, `--last --stderr X` would silently treat `--stderr`
# as the --last path and fail later as a confusing not-found, instead of usage.
need_val() {
  local flag="$1" val="$2"
  if [[ -z "$val" || "$val" == -* ]]; then
    printf 'ERROR: %s requires a value\n' "$flag" >&2
    usage
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --last)       need_val --last "${2:-}";       LAST_OVERRIDE="$2";   shift 2 ;;
    --stderr)     need_val --stderr "${2:-}";     STDERR_OVERRIDE="$2"; shift 2 ;;
    --brief-file) need_val --brief-file "${2:-}"; BRIEF_FILE="$2";      shift 2 ;;
    --)           shift; while [[ $# -gt 0 ]]; do positional+=("$1"); shift; done ;;
    -*)           usage; exit 2 ;;
    *)            positional+=("$1"); shift ;;
  esac
done

WORK_DIR="${positional[0]:-}"
# Second positional is brief_file, but only when --brief-file was not supplied
# (supplying both is ambiguous and rejected).
if [[ -z "$BRIEF_FILE" ]]; then
  BRIEF_FILE="${positional[1]:-}"
  POSITIONAL_MAX=2
else
  POSITIONAL_MAX=1
fi

if [[ ${#positional[@]} -gt $POSITIONAL_MAX || -z "$WORK_DIR" ]]; then
  usage
  exit 2
fi

if [[ -n "$BRIEF_FILE" && ! -f "$BRIEF_FILE" ]]; then
  printf 'ERROR: brief file not found: %s\n' "$BRIEF_FILE" >&2
  exit 1
fi

TRACE_DIR="$WORK_DIR/.agent-trace"
LATEST_LAST="${LAST_OVERRIDE:-$TRACE_DIR/latest.last}"
LATEST_STDERR="${STDERR_OVERRIDE:-$TRACE_DIR/latest.stderr}"

if [[ ! -d "$TRACE_DIR" ]]; then
  printf 'FAILED: .agent-trace dir not found: %s\n' "$TRACE_DIR"
  exit 1
fi

if [[ -L "$TRACE_DIR" ]]; then
  TRACE_DIR_RESOLVED="$(realpath_m "$TRACE_DIR" 2>/dev/null || true)"
  WORK_ABS="$(realpath_m "$WORK_DIR" 2>/dev/null || echo "$WORK_DIR")"
  if [[ -z "$TRACE_DIR_RESOLVED" || "${TRACE_DIR_RESOLVED#"$WORK_ABS/"}" == "$TRACE_DIR_RESOLVED" ]]; then
    printf 'FAILED: .agent-trace symlink target is outside work dir: %s\n' "$TRACE_DIR_RESOLVED"
    exit 1
  fi
fi

TRACE_ABS="$(realpath_m "$TRACE_DIR" 2>/dev/null || echo "$TRACE_DIR")"

if [[ ! -e "$LATEST_LAST" && ! -L "$LATEST_LAST" ]]; then
  printf 'FAILED: latest.last not found: %s\n' "$LATEST_LAST"
  exit 1
fi

if [[ ! -s "$LATEST_LAST" ]]; then
  printf 'FAILED: latest.last is empty: %s\n' "$LATEST_LAST"
  exit 1
fi

# A flag-supplied --last gets the same containment guard as a latest.last
# symlink: its real path must stay inside this run's .agent-trace.
if [[ -L "$LATEST_LAST" || -n "$LAST_OVERRIDE" ]]; then
  LAST_RESOLVED="$(realpath_m "$LATEST_LAST" 2>/dev/null || true)"
  if [[ -z "$LAST_RESOLVED" || "${LAST_RESOLVED#"$TRACE_ABS/"}" == "$LAST_RESOLVED" ]]; then
    printf 'FAILED: latest.last path is outside .agent-trace: %s\n' "$LAST_RESOLVED"
    exit 1
  fi
fi

printf '=== Agent trace (latest.last) ===\n'
tail -50 "$LATEST_LAST"
printf '\n'

# Same containment guard for a flag-supplied --stderr (only when it exists;
# stderr is optional, so a missing one is tolerated below, not rejected here).
if [[ -L "$LATEST_STDERR" ]] || [[ -n "$STDERR_OVERRIDE" && -e "$LATEST_STDERR" ]]; then
  STDERR_RESOLVED="$(realpath_m "$LATEST_STDERR" 2>/dev/null || true)"
  if [[ -z "$STDERR_RESOLVED" || "${STDERR_RESOLVED#"$TRACE_ABS/"}" == "$STDERR_RESOLVED" ]]; then
    printf 'FAILED: latest.stderr path is outside .agent-trace: %s\n' "$STDERR_RESOLVED"
    exit 1
  fi
fi

if [[ -s "$LATEST_STDERR" ]]; then
  printf '=== Stderr (latest.stderr) ===\n'
  tail -20 "$LATEST_STDERR"
  printf '\n'
fi

printf '=== Git diff --stat ===\n'
if git -C "$WORK_DIR" diff --stat origin/main 2>/dev/null; then
  printf '(base: origin/main)\n'
elif git -C "$WORK_DIR" diff --stat HEAD 2>/dev/null; then
  printf '(base: HEAD — origin/main unavailable)\n'
else
  printf '(no git repo or no commits)\n'
fi
printf '\n'

printf '=== Untracked / modified files ===\n'
git -C "$WORK_DIR" status --short 2>/dev/null || echo '(no git repo)'
printf '\n'

FAILED=0

EXECUTOR_STATUS="$(grep -iE '^status: (failed|partial|blocked)' "$LATEST_LAST" || true)"
if [[ -n "$EXECUTOR_STATUS" ]]; then
  while IFS= read -r status_line; do
    printf 'FAILED: executor reported non-success outcome: %s\n' "$status_line"
  done <<< "$EXECUTOR_STATUS"
  FAILED=1
fi

if [[ -n "$BRIEF_FILE" ]]; then
  printf '=== Self-verify checks ===\n'
  while IFS= read -r cmd; do
    if grep -qxF "${cmd}: pass" "$LATEST_LAST"; then
      printf '  FOUND: %s\n' "$cmd"
    else
      printf '  MISSING: %s\n' "$cmd"
      FAILED=1
    fi
  done < <(
    awk '/^self_verify:/{in_sec=1; next} /^[a-z_]+:/{in_sec=0} in_sec && /^[[:space:]]*-[[:space:]]/{sub(/^[[:space:]]*-[[:space:]]*/,""); print}' "$BRIEF_FILE"
  )
  printf '\n'
fi

if [[ "$FAILED" -eq 0 ]]; then
  if [[ -z "$BRIEF_FILE" ]]; then
    printf 'OK-NOBRIEF: self_verify checks skipped\n'
  else
    printf 'OK\n'
  fi
  exit 0
fi

printf 'FAILED: one or more self_verify commands not found in latest.last\n'
exit 1
