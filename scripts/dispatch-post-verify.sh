#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/portable.sh
source "$SCRIPT_DIR/lib/portable.sh"

usage() {
  printf 'usage: %s <work_dir> [brief_file]\n' "$0" >&2
}

WORK_DIR="${1:-}"
BRIEF_FILE="${2:-}"

if [[ $# -gt 2 || -z "$WORK_DIR" ]]; then
  usage
  exit 2
fi

if [[ -n "$BRIEF_FILE" && ! -f "$BRIEF_FILE" ]]; then
  printf 'ERROR: brief file not found: %s\n' "$BRIEF_FILE" >&2
  exit 1
fi

TRACE_DIR="$WORK_DIR/.agent-trace"
LATEST_LAST="$TRACE_DIR/latest.last"
LATEST_STDERR="$TRACE_DIR/latest.stderr"

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

if [[ -L "$LATEST_LAST" ]]; then
  LAST_RESOLVED="$(realpath_m "$LATEST_LAST" 2>/dev/null || true)"
  if [[ -z "$LAST_RESOLVED" || "${LAST_RESOLVED#"$TRACE_ABS/"}" == "$LAST_RESOLVED" ]]; then
    printf 'FAILED: latest.last symlink target is outside .agent-trace: %s\n' "$LAST_RESOLVED"
    exit 1
  fi
fi

printf '=== Agent trace (latest.last) ===\n'
tail -50 "$LATEST_LAST"
printf '\n'

if [[ -L "$LATEST_STDERR" ]]; then
  STDERR_RESOLVED="$(realpath_m "$LATEST_STDERR" 2>/dev/null || true)"
  if [[ -z "$STDERR_RESOLVED" || "${STDERR_RESOLVED#"$TRACE_ABS/"}" == "$STDERR_RESOLVED" ]]; then
    printf 'FAILED: latest.stderr symlink target is outside .agent-trace: %s\n' "$STDERR_RESOLVED"
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
    if grep -qF "${cmd}: pass" "$LATEST_LAST"; then
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
  printf 'OK\n'
  exit 0
fi

printf 'FAILED: one or more self_verify commands not found in latest.last\n'
exit 1
