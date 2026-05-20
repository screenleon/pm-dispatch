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
safety_skipped=0

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
  local normalized resolved real_claude_home parent real_parent

  # Handle relative paths: prepend PWD if not absolute.
  case "$path" in
    /*) ;;
    *) path="$PWD/$path" ;;
  esac

  # Step 1: lexical normalization (resolves .. without requiring existence or symlink follow)
  normalized="$(_portable_normalize_path "$path" 2>/dev/null)"
  if [[ -z "$normalized" ]]; then
    return 1
  fi

  # Step 2: symlink resolution — physically resolve to prevent symlinked-parent traversal.
  # A dst such as $HOME/.claude/linkdir/file passes the lexical check but resolves
  # outside the managed root when linkdir is a symlink to an outside directory.
  if resolved="$(realpath -- "$normalized" 2>/dev/null)" && [[ -n "$resolved" ]]; then
    # realpath succeeded: use the physically-resolved location
    normalized="$resolved"
  elif [[ -e "$normalized" ]]; then
    # Path EXISTS on the filesystem but realpath failed or is unavailable.
    # We cannot safely verify ownership without physical resolution — fail closed.
    return 1
  else
    # Path does NOT exist (e.g. already removed in a prior run).
    # Attempt to resolve the nearest existing parent to catch symlinked ancestor dirs.
    parent="$(dirname "$normalized")"
    if real_parent="$(realpath -- "$parent" 2>/dev/null)" && [[ -n "$real_parent" ]]; then
      normalized="$real_parent/$(basename "$normalized")"
    fi
    # If parent is also unresolvable: path truly does not exist yet, so there is no
    # symlinked directory to traverse through — lexical normalization is safe.
  fi

  # Resolve CLAUDE_HOME itself in case ~/.claude is a symlink
  real_claude_home="$(realpath -- "$CLAUDE_HOME" 2>/dev/null || printf '%s' "$CLAUDE_HOME")"

  # Fail closed: if normalization yields empty after resolution, deny
  if [[ -z "$normalized" ]]; then
    return 1
  fi

  case "$normalized" in
    "$real_claude_home"/*|"$real_claude_home")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_symlink_dst_under_managed_root() {
  local dst="$1"
  local parent basename

  parent="$(dirname "$dst")"
  basename="$(basename "$dst")"

  # For symlink entries, the final path may itself be a legitimate symlink to
  # repo content outside ~/.claude. Check a non-existing sibling path so
  # symlinked parent directories are resolved without following the final link.
  is_under_managed_root "$parent/.pm-dispatch-uninstall-parent-check-$basename"
}

echo "pm-dispatch uninstaller"
echo "  repo:     $REPO_ROOT"
echo "  manifest: $MANIFEST"
if [[ "$DRY_RUN" -eq 1 ]]; then echo "  mode:     DRY RUN"; fi
echo

echo "==> manifest entries"
parsed_any=0
while IFS= read -r line; do
  [[ "$line" == *'"src"'* ]] || continue
  [[ "$line" == *'"dst"'* ]] || continue
  parsed_any=1

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
      if ! is_symlink_dst_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      if [[ -L "$dst" ]]; then
        link_target="$(readlink "$dst")"
        if is_manifest_symlink_target "$src" "$dst" "$link_target"; then
          remove_item "$dst"
        else
          skipped=$((skipped + 1))
          safety_skipped=$((safety_skipped + 1))
          echo "  skip $dst (not our symlink — skipping)"
        fi
      elif [[ -e "$dst" ]]; then
        # Path exists but is not a symlink — unexpected state
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (not our symlink — skipping)"
      else
        # Path is gone entirely — not a safety concern
        skipped=$((skipped + 1))
        echo "  skip $dst (already gone)"
      fi
      ;;
    copy)
      if ! is_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      if [[ -f "$dst" || ( -d "$dst" && ! -L "$dst" ) ]]; then
        curr_sha="$(_portable_sha256_path "$dst")"
        if [[ "$curr_sha" == "$sha256" ]]; then
          remove_item "$dst"
        else
          skipped=$((skipped + 1))
          safety_skipped=$((safety_skipped + 1))
          echo "  skip $dst (modified since install — skipping)"
        fi
      else
        # Path not found — not a safety concern (normal after partial rerun)
        skipped=$((skipped + 1))
        echo "  skip $dst (already gone)"
      fi
      ;;
    *)
      if ! is_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      skipped=$((skipped + 1))
      safety_skipped=$((safety_skipped + 1))
      echo "  skip $dst (unknown mode: $mode)"
      ;;
  esac
done < <(grep '"src"' "$MANIFEST" | grep '"dst"' || true)

# Fail closed: manifest has entries but nothing matched the grep-based parser
if [[ "$parsed_any" -eq 0 ]] && grep -q '"mode"' "$MANIFEST" 2>/dev/null; then
  echo "  warning: manifest entries could not be parsed (check format — expected compact JSON)"
  skipped=$((skipped + 1))
  safety_skipped=$((safety_skipped + 1))
fi

echo
echo "==> hooks"
if [[ "$DRY_RUN" -eq 1 ]]; then
  bash "$REPO_ROOT/scripts/uninstall-hooks.sh" --dry-run
else
  bash "$REPO_ROOT/scripts/uninstall-hooks.sh"
fi

if [[ "$DRY_RUN" -ne 1 ]]; then
  if [[ "$safety_skipped" -eq 0 ]]; then
    rm -rf "$HOME/.claude/.pm-dispatch"
  else
    echo "  note: $safety_skipped item(s) require manual attention — manifest preserved for re-run"
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
  echo "Done. Removed $removed items, skipped $skipped items ($safety_skipped safety-skip)."
fi
