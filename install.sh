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

# Pre-flight: scripts/*.sh hygiene (executable bit, shebang, parses, set line)
if [[ -x "$REPO_ROOT/scripts/lint-scripts.sh" ]]; then
  echo "==> lint scripts"
  "$REPO_ROOT/scripts/lint-scripts.sh"
  echo
fi

# Pre-flight: hook regression suite (security-relevant; must be green to install)
if [[ -x "$REPO_ROOT/scripts/test-hooks.sh" ]]; then
  echo "==> test hooks"
  "$REPO_ROOT/scripts/test-hooks.sh"
  echo
fi

# Pre-flight: usage report regression suite (read-only fixture coverage)
if [[ -x "$REPO_ROOT/scripts/test-usage-weekly.sh" ]]; then
  echo "==> test usage weekly"
  "$REPO_ROOT/scripts/test-usage-weekly.sh"
  echo
fi

# Pre-flight: usage tracker regression suite (log-usage.sh + claude-usage.sh)
if [[ -x "$REPO_ROOT/scripts/test-usage-tracker.sh" ]]; then
  echo "==> test usage tracker"
  "$REPO_ROOT/scripts/test-usage-tracker.sh"
  echo
fi

install_dir agents
install_dir skills
install_dir commands

# Usage tracking scripts — symlinked into ~/.claude/scripts/ so the user can
# call them as `bash ~/.claude/scripts/claude-usage.sh` regardless of where
# this repo is cloned.
echo "==> usage scripts"
SCRIPTS_DEST="$CLAUDE_HOME/scripts"
if [[ ! -d "$SCRIPTS_DEST" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would mkdir $SCRIPTS_DEST"
  else
    mkdir -p "$SCRIPTS_DEST"
    echo "  mkdir  $SCRIPTS_DEST"
  fi
fi
us_count=0; us_conflicts=0
for script in claude-usage.sh log-usage.sh; do
  if link "$REPO_ROOT/scripts/$script" "$SCRIPTS_DEST/$script"; then
    us_count=$((us_count + 1))
  else
    us_conflicts=$((us_conflicts + 1))
  fi
done
echo "  ($us_count linked, $us_conflicts conflicts)"

echo

# pm-schema: symlink ~/github/.pm -> claude-config/pm so cross-repo
# path references (rollup.sh default out, memory prose, schema.md
# consumers) keep working.
echo "==> pm-schema"
PM_SRC="$REPO_ROOT/pm"
PM_DEST="$HOME/github/.pm"
if [[ -d "$PM_SRC" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would  $PM_DEST -> $PM_SRC"
  elif [[ -L "$PM_DEST" ]]; then
    if [[ "$(readlink "$PM_DEST")" == "$PM_SRC" ]]; then
      echo "  ok    $PM_DEST"
    else
      echo "  CONFLICT $PM_DEST -> $(readlink "$PM_DEST") (expected $PM_SRC)" >&2
    fi
  elif [[ -e "$PM_DEST" ]]; then
    echo "  CONFLICT $PM_DEST exists and is not a symlink — skipping" >&2
  else
    ln -s "$PM_SRC" "$PM_DEST"
    echo "  link   $PM_DEST -> $PM_SRC"
  fi
fi

echo
echo "Done."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(no changes made — re-run without --dry-run to apply)"
else
  echo "Hooks: run scripts/install-hooks.sh to wire PreToolUse guards into ~/.claude/settings.json (idempotent)."
fi
