#!/usr/bin/env bash
# uninstall.sh — remove pm-dispatch symlinks/copies from ~/.claude/
#
# Idempotent: safe to re-run.
#
# Usage:
#   ./uninstall.sh [--dry-run]

set -euo pipefail

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "uninstall: unknown flag $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="$HOME/.claude"

# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/portable.sh"

MANIFEST="$CLAUDE_HOME/.pm-dispatch/install-manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "uninstall: no manifest found at $MANIFEST — nothing to do"
  exit 0
fi

removed=0
skipped=0

is_manifest_symlink_target() {
  local src="$1"
  local dst="$2"
  local link_target="$3"
  local normalized_target

  if [[ "$link_target" == "$src" ]]; then
    return 0
  fi

  case "$link_target" in
    /*|[A-Za-z]:/*)
      normalized_target="$(_portable_normalize_path "$link_target")"
      ;;
    *)
      normalized_target="$(_portable_normalize_path "$(dirname "$dst")/$link_target")"
      ;;
  esac

  [[ "$normalized_target" == "$src" ]]
}

remove_item() {
  local dst="$1"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would remove $dst"
  else
    if [[ -d "$dst" && ! -L "$dst" ]]; then
      rm -rf "$dst"
    else
      rm "$dst"
    fi
    echo "  remove $dst"
  fi
  removed=$((removed + 1))
}

is_under_managed_root() {
  local path="$1"
  local parent
  local base
  local managed_root
  local resolved
  parent="$(dirname "$path")"
  base="$(basename "$path")"
  # Resolve the parent without requiring it to exist (-m for missing), but do
  # not follow the final symlink because installed dst symlinks point at repo files.
  managed_root="$(realpath -m -- "$CLAUDE_HOME" 2>/dev/null || printf '%s' "$CLAUDE_HOME")"
  resolved="$(realpath -m -- "$parent" 2>/dev/null || printf '%s' "$parent")/$base"
  # Accept paths that are under $CLAUDE_HOME
  case "$resolved" in
    "$managed_root"/*|"$managed_root")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

echo "pm-dispatch uninstaller"
echo "  repo:     $REPO_ROOT"
echo "  manifest: $MANIFEST"
if [[ "$DRY_RUN" -eq 1 ]]; then echo "  mode:     DRY RUN"; fi
echo

echo "==> manifest entries"
while IFS= read -r line; do
  [[ "$line" == *'"src"'* ]] || continue
  [[ "$line" == *'"dst"'* ]] || continue

  src="$(_portable_json_unescape "$(_portable_extract_json_field "$line" "src")")"
  dst="$(_portable_json_unescape "$(_portable_extract_json_field "$line" "dst")")"
  mode="$(_portable_json_unescape "$(_portable_extract_json_field "$line" "mode")")"
  sha256="$(_portable_json_unescape "$(_portable_extract_json_field "$line" "sha256")")"

  if [[ -z "$dst" ]]; then
    skipped=$((skipped + 1))
    echo "  skip <empty dst> (invalid manifest entry)"
    continue
  fi

  case "$mode" in
    symlink)
      if ! is_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      if [[ -L "$dst" ]]; then
        link_target="$(readlink "$dst")"
        if is_manifest_symlink_target "$src" "$dst" "$link_target"; then
          remove_item "$dst"
        else
          skipped=$((skipped + 1))
          echo "  skip $dst (not our symlink — skipping)"
        fi
      else
        skipped=$((skipped + 1))
        echo "  skip $dst (not our symlink — skipping)"
      fi
      ;;
    copy)
      if ! is_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      if [[ -f "$dst" || ( -d "$dst" && ! -L "$dst" ) ]]; then
        curr_sha="$(_portable_sha256_path "$dst")"
        if [[ "$curr_sha" == "$sha256" ]]; then
          remove_item "$dst"
        else
          skipped=$((skipped + 1))
          echo "  skip $dst (modified since install — skipping)"
        fi
      else
        skipped=$((skipped + 1))
        echo "  skip $dst (already gone)"
      fi
      ;;
    *)
      if ! is_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      skipped=$((skipped + 1))
      echo "  skip $dst (unknown mode: $mode)"
      ;;
  esac
done < <(grep '"src"' "$MANIFEST" | grep '"dst"' || true)

echo
echo "==> hooks"
if [[ "$DRY_RUN" -eq 1 ]]; then
  bash "$REPO_ROOT/scripts/uninstall-hooks.sh" --dry-run
else
  bash "$REPO_ROOT/scripts/uninstall-hooks.sh"
fi

if [[ "$DRY_RUN" -ne 1 ]]; then
  if [[ "$skipped" -eq 0 ]]; then
    rm -rf "$HOME/.claude/.pm-dispatch"
  else
    echo "  note: $skipped item(s) could not be removed — manifest preserved for re-run"
    echo "  resolve conflicts manually, then re-run uninstall.sh"
  fi
  for d in "$HOME/.claude/agents" "$HOME/.claude/commands" "$HOME/.claude/skills" "$HOME/.claude/scripts"; do
    rmdir "$d" 2>/dev/null || true
  done
fi

echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Done. (no changes made — re-run without --dry-run to apply)"
else
  echo "Done. Removed $removed items, skipped $skipped items."
fi
