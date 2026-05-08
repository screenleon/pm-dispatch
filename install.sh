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
  HOME="${CLAUDE_CONFIG_TEST_PREFLIGHT_HOME:-$HOME}" "$REPO_ROOT/scripts/test-hooks.sh"
  echo
fi

# Pre-flight: installer regression suite (symlink/conflict behavior)
if [[ -x "$REPO_ROOT/scripts/test-install.sh" && "${CLAUDE_CONFIG_TEST_INSTALL_RUNNING:-0}" != "1" ]]; then
  echo "==> test install"
  CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 bash "$REPO_ROOT/scripts/test-install.sh"
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

# Pre-flight: pm schema scripts regression suite
if [[ -x "$REPO_ROOT/pm/scripts/test/run-tests.sh" ]]; then
  echo "==> test pm scripts"
  bash "$REPO_ROOT/pm/scripts/test/run-tests.sh"
  echo
fi

# Pre-flight: codex-pr-gate regression suite
if [[ -x "$REPO_ROOT/scripts/test-codex-pr-gate.sh" ]]; then
  echo "==> test codex-pr-gate"
  "$REPO_ROOT/scripts/test-codex-pr-gate.sh"
  echo
fi

# Pre-flight: setup-project regression suite
if [[ -x "$REPO_ROOT/scripts/test-setup-project.sh" ]]; then
  echo "==> test setup-project"
  "$REPO_ROOT/scripts/test-setup-project.sh"
  echo
fi

install_dir agents
install_dir skills
install_dir commands

# Helper scripts — symlinked into ~/.claude/scripts/ so the user can
# call them as `bash ~/.claude/scripts/<script>` regardless of where
# this repo is cloned.
echo "==> helper scripts"
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
# Allowlist: user-facing scripts only. Excluded intentionally:
#   test-*.sh   — run as install preflights above, not user tools
#   hook-*.sh   — wired by install-hooks.sh, not standalone user tools
#   lint-*.sh   — internal CI helpers
for script in claude-usage.sh log-usage.sh codex-pr-gate.sh codex-dispatch.sh setup-project.sh; do
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
PM_SRC="$REPO_ROOT/pm"
PM_DEST="$HOME/github/.pm"
if [[ -d "$PM_SRC" ]]; then
  echo "==> pm-schema"
  if [[ ! -d "$HOME/github" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would mkdir $HOME/github"
    else
      mkdir -p "$HOME/github"
      echo "  mkdir  $HOME/github"
    fi
  fi
  pm_conflicts=0
  link "$PM_SRC" "$PM_DEST" || pm_conflicts=$((pm_conflicts + 1))
  echo "  (1 attempted, $pm_conflicts conflicts)"
  if [[ "$pm_conflicts" -gt 0 ]]; then
    echo "install.sh: pm-schema symlink failed — resolve conflict before continuing" >&2
    exit 1
  fi
else
  echo "skip pm-schema (no source)"
fi

echo
echo "==> hooks"
if [[ -f "$CLAUDE_HOME/settings.json" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    bash "$REPO_ROOT/scripts/install-hooks.sh" --dry-run
  else
    bash "$REPO_ROOT/scripts/install-hooks.sh"
  fi
else
  echo "  skipped — $CLAUDE_HOME/settings.json not found (create it first, then re-run install.sh)"
fi
echo

echo "Done."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(no changes made — re-run without --dry-run to apply)"
fi
