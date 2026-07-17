#!/usr/bin/env bash
# patch-gitignore.sh — idempotently add entries to the nearest .gitignore
#
# Finds the git root from the given working directory and appends any
# missing entries under a single "Claude agent / codex output" header block.
# Safe to call multiple times; never duplicates entries.
#
# Usage:
#   patch-gitignore.sh [--dry-run] <work-dir> <entry> [entry ...]
#
# Exits 0 even if no git repo is found (non-git projects are skipped silently).

set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

WORK_DIR="${1:?Usage: patch-gitignore.sh [--dry-run] <work-dir> <entry> [entry ...]}"
shift
ENTRIES=("$@")

if [[ "${#ENTRIES[@]}" -eq 0 ]]; then
  printf 'patch-gitignore: no entries specified\n' >&2
  exit 1
fi

GIT_ROOT=$(git -C "$WORK_DIR" rev-parse --show-toplevel 2>/dev/null) || {
  # Not a git repo — silently skip
  exit 0
}

GITIGNORE="$GIT_ROOT/.gitignore"
HEADER="# Claude agent / codex output — not for VCS or Docker"

if ! [[ "$GITIGNORE" == "$GIT_ROOT"/* ]]; then
  printf 'patch-gitignore: refusing path outside git root: %s\n' "$GITIGNORE" >&2
  exit 1
fi
if [[ -L "$GITIGNORE" ]]; then
  printf 'patch-gitignore: refusing to operate on symlink: %s\n' "$GITIGNORE" >&2
  exit 1
fi
if [[ -e "$GITIGNORE" && ! -f "$GITIGNORE" ]]; then
  printf 'patch-gitignore: refusing to operate on non-regular file: %s\n' "$GITIGNORE" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  [[ -f "$GITIGNORE" ]] || touch "$GITIGNORE"
fi

ADDED=0
for entry in "${ENTRIES[@]}"; do
  if grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
    continue
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'would add: %s  (%s)\n' "$entry" "$GITIGNORE"
    continue
  fi
  if [[ "$ADDED" -eq 0 ]] && ! grep -qxF "$HEADER" "$GITIGNORE" 2>/dev/null; then
    printf '\n%s\n' "$HEADER" >> "$GITIGNORE"
  fi
  printf '%s\n' "$entry" >> "$GITIGNORE"
  ADDED=$((ADDED + 1))
done
