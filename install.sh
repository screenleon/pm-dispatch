#!/usr/bin/env bash
# install.sh — symlink pm-dispatch contents into ~/.claude/
#
# Idempotent: re-running is safe.
# Per-file symlinks: ~/.claude/agents/ may contain agents from other sources alongside.
#
# Usage:
#   ./install.sh [--dry-run] [--profile minimal|full] [--verify]
#
# --profile selects the hook set:
#   full     wire all hooks including codex-* guards (use when you run codex CLI)
#   minimal  skip codex-* guards (claude-only setup)
#   (omit)   auto-detect: codex on PATH → full, else minimal
#
# --verify runs all preflight test suites before installing.
#   Skipped by default; recommended when contributing or after updating.

set -euo pipefail

DRY_RUN=0
VERIFY=0
PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --verify) VERIFY=1; shift ;;
    --profile)
      [[ $# -ge 2 ]] || { echo "install: --profile requires a value" >&2; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    *) echo "install: unknown flag $1" >&2; exit 2 ;;
  esac
done

case "$PROFILE" in
  ""|minimal|full) ;;
  *) echo "install: --profile must be minimal or full (got: $PROFILE)" >&2; exit 2 ;;
esac

# jq is required by hooks and install-hooks.sh; fail early with actionable hint.
if ! command -v jq >/dev/null 2>&1; then
  echo "install: jq not found — install it first:" >&2
  echo "  Linux/WSL2: sudo apt install jq" >&2
  echo "  macOS:      brew install jq" >&2
  echo "  Windows:    winget install jqlang.jq" >&2
  echo "  See docs/platform-support.md for details." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="$HOME/.claude"
_COPY_FALLBACK_COUNT=0

# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/portable.sh"

_INSTALL_PLATFORM="$(detect_platform)"

link() {
  local src="$1" dest="$2"
  local rc
  link_or_copy "$src" "$dest"
  rc=$?
  case "$rc" in
    0) return 0 ;;
    1) _COPY_FALLBACK_COUNT=$((_COPY_FALLBACK_COUNT + 1)); return 0 ;;
    2|3) return 1 ;;
    *) return 1 ;;
  esac
}

remove_legacy_symlink() {
  local path="$1" old_target="$2"
  [[ -L "$path" ]] || return 0
  local current
  current="$(readlink "$path")"
  [[ "$current" == "$old_target" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would remove (legacy) $path"
  else
    rm "$path"
    echo "  remove (legacy) $path"
  fi
}

install_dir_junction() {
  local subdir="$1"
  local src_dir="$REPO_ROOT/$subdir"
  local dest_dir="$CLAUDE_HOME/$subdir"

  [[ -d "$src_dir" ]] || { echo "skip $subdir (no source)"; return 0; }

  echo "==> $subdir (windows junction)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would junction $dest_dir -> $src_dir"
    manifest_record "$src_dir" "$dest_dir" junction || true
    return 0
  fi

  # If dest is already a junction pointing to our src, treat as idempotent.
  if [[ -d "$dest_dir" && -L "$dest_dir" ]]; then
    local existing_target
    existing_target="$(readlink "$dest_dir" 2>/dev/null || true)"
    if [[ "$existing_target" == "$src_dir" ]]; then
      echo "  ok    $dest_dir (junction already correct)"
      manifest_record "$src_dir" "$dest_dir" junction || true
      return 0
    fi
  fi

  # If dest exists as a non-junction real directory, fall back to per-file copy
  # to preserve any unrelated entries (e.g. agents from other tools).
  if [[ -d "$dest_dir" && ! -L "$dest_dir" ]]; then
    printf 'install: %s is an existing real directory — per-file copy to preserve coexistence\n' "$subdir" >&2
    install_dir "$subdir"
    return
  fi

  if [[ ! -d "$CLAUDE_HOME" ]]; then
    mkdir -p "$CLAUDE_HOME"
  fi

  # Attempt junction creation.
  if make_junction_windows "$src_dir" "$dest_dir"; then
    echo "  junction $dest_dir -> $src_dir"
    manifest_record "$src_dir" "$dest_dir" junction || return 1
    return 0
  fi

  # Junction failed - fall back to per-file copy via install_dir().
  printf 'install: junction failed for %s - falling back to per-file copy\n' "$subdir" >&2
  install_dir "$subdir"
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

echo "pm-dispatch installer"
echo "  repo:        $REPO_ROOT"
echo "  claude home: $CLAUDE_HOME"
if [[ "$DRY_RUN" -eq 1 ]]; then echo "  mode:        DRY RUN"; fi
echo

# Preflight tests run only when explicitly requested with --verify.
# Skipped when called from test-install.sh (CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1).
if [[ "${CLAUDE_CONFIG_TEST_INSTALL_RUNNING:-0}" == "1" ]]; then
  _SKIP_PREFLIGHT=1
  echo "  [preflight skipped: CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1]"
  echo
elif [[ "$VERIFY" -eq 1 ]]; then
  _SKIP_PREFLIGHT=0
else
  _SKIP_PREFLIGHT=1
  echo "  [preflight tests skipped — pass --verify to run them]"
  echo
fi

if [[ "$VERIFY" -eq 1 ]] && [[ "$_SKIP_PREFLIGHT" != "1" ]]; then
  echo "==> preflight tests"
  bash "$REPO_ROOT/scripts/run-all-tests.sh"
  echo
fi

if [[ "$_INSTALL_PLATFORM" == "windows" ]]; then
  install_dir_junction agents
  install_dir_junction skills
  install_dir_junction commands
else
  install_dir agents
  install_dir skills
  install_dir commands
fi

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

echo "==> legacy cleanup"
remove_legacy_symlink "$SCRIPTS_DEST/codex-pr-gate.sh" "$REPO_ROOT/scripts/codex-pr-gate.sh"
remove_legacy_symlink "$CLAUDE_HOME/commands/codex-pr-gate.md" "$REPO_ROOT/commands/codex-pr-gate.md"
remove_legacy_symlink "$SCRIPTS_DEST/claude-usage.sh" "$REPO_ROOT/scripts/claude-usage.sh"

us_count=0; us_conflicts=0
# Allowlist: user-facing scripts only. Excluded intentionally:
#   test-*.sh   — run as install preflights above, not user tools
#   hook-*.sh   — wired by install-hooks.sh, not standalone user tools
#   lint-*.sh   — internal CI helpers
for script in token-usage.sh log-usage.sh pr-gate.sh codex-dispatch.sh setup-project.sh patch-gitignore.sh; do
  if link "$REPO_ROOT/scripts/$script" "$SCRIPTS_DEST/$script"; then
    us_count=$((us_count + 1))
  else
    us_conflicts=$((us_conflicts + 1))
  fi
done
echo "  ($us_count linked, $us_conflicts conflicts)"

echo

# pm-schema: symlink ~/.claude/.pm -> pm-dispatch/pm so cross-repo
# path references (rollup.sh default out, memory prose, schema.md
# consumers) keep working.
PM_SRC="$REPO_ROOT/pm"
PM_DEST="$HOME/.claude/.pm"
if [[ -d "$PM_SRC" ]]; then
  echo "==> pm-schema"
  pm_conflicts=0
  if [[ "$_INSTALL_PLATFORM" == "windows" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would junction $PM_DEST -> $PM_SRC"
      manifest_record "$PM_SRC" "$PM_DEST" junction || pm_conflicts=$((pm_conflicts + 1))
    elif ! make_junction_windows "$PM_SRC" "$PM_DEST"; then
      link "$PM_SRC" "$PM_DEST" || pm_conflicts=$((pm_conflicts + 1))
    else
      echo "  junction $PM_DEST -> $PM_SRC"
      manifest_record "$PM_SRC" "$PM_DEST" junction || pm_conflicts=$((pm_conflicts + 1))
    fi
  else
    link "$PM_SRC" "$PM_DEST" || pm_conflicts=$((pm_conflicts + 1))
  fi
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
if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ ! -f "$CLAUDE_HOME/settings.json" ]]; then
    echo "  would create $CLAUDE_HOME/settings.json (minimal, for hook wiring)"
    echo "  (hook wiring dry-run skipped — settings.json would be created first)"
  else
    if [[ -n "$PROFILE" ]]; then
      bash "$REPO_ROOT/scripts/install-hooks.sh" --dry-run --profile "$PROFILE"
    else
      bash "$REPO_ROOT/scripts/install-hooks.sh" --dry-run
    fi
  fi
else
  if [[ ! -f "$CLAUDE_HOME/settings.json" ]]; then
    mkdir -p "$CLAUDE_HOME"
    printf '{}\n' > "$CLAUDE_HOME/settings.json"
    echo "  created $CLAUDE_HOME/settings.json (minimal, for hook wiring)"
  fi
  if [[ -n "$PROFILE" ]]; then
    bash "$REPO_ROOT/scripts/install-hooks.sh" --profile "$PROFILE"
  else
    bash "$REPO_ROOT/scripts/install-hooks.sh"
  fi
fi
echo

if [[ "$_COPY_FALLBACK_COUNT" -gt 0 && "$DRY_RUN" -eq 0 ]]; then
  echo
  echo "Note: $_COPY_FALLBACK_COUNT file(s) installed via copy (symlink unavailable)."
  echo "      Copied files do not auto-sync with source changes."
  echo "      To pick up updates: bash uninstall.sh && bash install.sh"
fi

echo "Done."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(no changes made — re-run without --dry-run to apply)"
fi

if ! manifest_flush "$HOME/.claude/.pm-dispatch/install-manifest.json" "$REPO_ROOT"; then
  echo "install: manifest write failed" >&2
  exit 3
fi
