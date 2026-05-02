#!/usr/bin/env bash
# install.sh — symlink claude-config contents into ~/.claude/
#
# Idempotent: re-running is safe.
# Per-file symlinks: ~/.claude/agents/ may contain agents from other sources alongside.
#
# Usage:
#   ./install.sh [--dry-run]

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="$HOME/.claude"

link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      echo "  ok    $dest"
      return 0
    fi
    echo "  CONFLICT $dest -> $current (expected $src)" >&2
    return 1
  fi
  if [[ -e "$dest" ]]; then
    echo "  CONFLICT $dest exists and is not a symlink — skipping" >&2
    return 1
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would  $dest -> $src"
  else
    ln -s "$src" "$dest"
    echo "  link   $dest -> $src"
  fi
}

install_dir() {
  local subdir="$1"
  local src_dir="$REPO_ROOT/$subdir"
  local dest_dir="$CLAUDE_HOME/$subdir"

  [[ -d "$src_dir" ]] || { echo "skip $subdir (no source)"; return 0; }

  echo "==> $subdir"
  if [[ ! -d "$dest_dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would mkdir $dest_dir"
    else
      mkdir -p "$dest_dir"
      echo "  mkdir  $dest_dir"
    fi
  fi

  shopt -s nullglob
  local count=0 conflicts=0
  for src in "$src_dir"/*; do
    [[ -e "$src" ]] || continue
    local name
    name="$(basename "$src")"
    if link "$src" "$dest_dir/$name"; then
      count=$((count + 1))
    else
      conflicts=$((conflicts + 1))
    fi
  done
  shopt -u nullglob
  echo "  ($count linked, $conflicts conflicts)"
}

echo "claude-config installer"
echo "  repo:        $REPO_ROOT"
echo "  claude home: $CLAUDE_HOME"
if [[ "$DRY_RUN" -eq 1 ]]; then echo "  mode:        DRY RUN"; fi
echo

# Pre-flight: agent frontmatter must not declare Agent (subagents can't spawn subagents)
if [[ -x "$REPO_ROOT/scripts/lint-agents.sh" ]]; then
  echo "==> lint agents"
  "$REPO_ROOT/scripts/lint-agents.sh"
  echo
fi

install_dir agents
install_dir skills
install_dir commands

echo
echo "Done."
if [[ "$DRY_RUN" -eq 1 ]]; then echo "(no changes made — re-run without --dry-run to apply)"; fi
